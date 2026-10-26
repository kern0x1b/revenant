// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Encode guest HFS attributes, ownership, timestamps and volume
// metadata.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/sys/attr.h
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/hfs/hfs_attrlist.c

#include "filesystem/hfs_metadata.hpp"

#include <algorithm>
#include <bit>
#include <charconv>
#include <cerrno>
#include <cstring>
#include <fstream>
#include <limits>
#include <set>
#include <span>
#include <string_view>
#include <system_error>
#include <utility>

#include <sys/stat.h>
#include <sys/xattr.h>

#if defined(__APPLE__)
#define st_atim st_atimespec
#define st_mtim st_mtimespec
#define st_ctim st_ctimespec
#endif

namespace emulator::hfs {
namespace {

    constexpr std::uint32_t hfs_root_catalog_id = 2;
    constexpr std::uint32_t hfs_root_parent_id = 1;
    constexpr std::uint32_t first_user_catalog_id = 16;
    constexpr std::uint32_t last_user_catalog_id = 0x7fff'ffffU;
    constexpr std::uint32_t hfs_vnode_tag = 16;
    constexpr std::uint32_t hfs_device = 1;
    constexpr std::uint32_t hfs_block_size = allocation_block_size;
    constexpr std::size_t max_cached_xattr_bytes = 4096;
    constexpr std::size_t max_cached_xattrs = 65'536;

#if defined(__APPLE__)
    ssize_t host_getxattr(const char* path, const char* name, void* value,
        std::size_t size, bool follow)
    {
        const std::string_view full { name };
        const auto bare = full.starts_with("user.") ? full.substr(5) : full;
        return ::getxattr(path, std::string { bare }.c_str(), value, size, 0,
            follow ? 0 : XATTR_NOFOLLOW);
    }

    ssize_t host_listxattr(
        const char* path, char* buffer, std::size_t size, bool follow)
    {
        const auto length =
            ::listxattr(path, nullptr, 0, follow ? 0 : XATTR_NOFOLLOW);
        if (length <= 0)
            return length;
        std::vector<char> bare(static_cast<std::size_t>(length));
        const auto received = ::listxattr(
            path, bare.data(), bare.size(), follow ? 0 : XATTR_NOFOLLOW);
        if (received <= 0)
            return received;
        std::string prefixed;
        for (std::size_t cursor = 0;
             cursor < static_cast<std::size_t>(received);) {
            const std::string_view entry { bare.data() + cursor };
            prefixed.append("user.").append(entry).push_back('\0');
            cursor += entry.size() + 1U;
        }
        if (buffer == nullptr)
            return static_cast<ssize_t>(prefixed.size());
        if (size < prefixed.size()) {
            errno = ERANGE;
            return -1;
        }
        std::memcpy(buffer, prefixed.data(), prefixed.size());
        return static_cast<ssize_t>(prefixed.size());
    }
#else
    ssize_t host_getxattr(const char* path, const char* name, void* value,
        std::size_t size, bool follow)
    {
        return follow ? ::getxattr(path, name, value, size)
                      : ::lgetxattr(path, name, value, size);
    }

    ssize_t host_listxattr(
        const char* path, char* buffer, std::size_t size, bool follow)
    {
        return follow ? ::listxattr(path, buffer, size)
                      : ::llistxattr(path, buffer, size);
    }
#endif

    std::optional<std::vector<std::byte>> read_host_xattr(
        const std::filesystem::path& path, std::string_view name, bool follow)
    {
        const auto size = host_getxattr(
            path.c_str(), std::string { name }.c_str(), nullptr, 0, follow);
        if (size < 0)
            return std::nullopt;
        std::vector<std::byte> result(static_cast<std::size_t>(size));
        if (size != 0 &&
            host_getxattr(path.c_str(), std::string { name }.c_str(),
                result.data(), result.size(), follow) != size) {
            return std::nullopt;
        }
        return result;
    }

    std::uint32_t fnv_catalog_id(std::span<const std::byte> bytes)
    {
        std::uint32_t hash = 2'166'136'261U;
        for (const auto byte : bytes) {
            hash ^= std::to_integer<std::uint8_t>(byte);
            hash *= 16'777'619U;
        }
        hash &= 0x7fff'ffffU;
        return hash < first_user_catalog_id ? hash + first_user_catalog_id
                                            : hash;
    }

    std::uint32_t path_catalog_id(
        const std::filesystem::path& root, const std::filesystem::path& path)
    {
        const auto relative = path.lexically_normal().lexically_relative(root);
        const auto text = relative.generic_string();
        return fnv_catalog_id(
            std::as_bytes(std::span { text.data(), text.size() }));
    }

    std::uint32_t inode_catalog_id(const struct stat& status)
    {
        std::array<std::uint64_t, 2> identity { static_cast<std::uint64_t>(
                                                    status.st_dev),
            static_cast<std::uint64_t>(status.st_ino) };
        return fnv_catalog_id(std::as_bytes(std::span { identity }));
    }

    bool is_within_root(
        const std::filesystem::path& root, const std::filesystem::path& path)
    {
        const auto normalized_root = root.lexically_normal();
        const auto normalized_path = path.lexically_normal();
        if (normalized_path == normalized_root)
            return true;
        const auto relative =
            normalized_path.lexically_relative(normalized_root);
        return !relative.empty() && relative != "." &&
               relative.begin()->string() != "..";
    }

    constexpr std::int64_t days_from_civil(
        int year, unsigned month, unsigned day)
    {
        year -= month <= 2U;
        const auto era = (year >= 0 ? year : year - 399) / 400;
        const auto year_of_era = static_cast<unsigned>(year - era * 400);
        const auto shifted_month = month > 2U ? month - 3U : month + 9U;
        const auto day_of_year = (153U * shifted_month + 2U) / 5U + day - 1U;
        const auto day_of_era = year_of_era * 365U + year_of_era / 4U -
                                year_of_era / 100U + day_of_year;
        return era * 146097 + static_cast<int>(day_of_era) - 719468;
    }

    std::optional<Timestamp> parse_hfs_time(std::span<const std::byte> bytes)
    {
        if (bytes.size() < 19)
            return std::nullopt;
        const std::string_view value {
            reinterpret_cast<const char*>(bytes.data()), bytes.size()
        };
        const auto number = [&](std::size_t offset,
                                std::size_t count) -> std::optional<int> {
            int result = 0;
            const auto parsed = std::from_chars(
                value.data() + offset, value.data() + offset + count, result);
            return parsed.ec == std::errc { } ? std::optional { result }
                                              : std::nullopt;
        };
        const auto year = number(0, 4);
        const auto month = number(5, 2);
        const auto day = number(8, 2);
        const auto hour = number(11, 2);
        const auto minute = number(14, 2);
        const auto second = number(17, 2);
        if (!year || !month || !day || !hour || !minute || !second) {
            return std::nullopt;
        }
        std::int64_t epoch =
            days_from_civil(*year, static_cast<unsigned>(*month),
                static_cast<unsigned>(*day)) *
                86'400 +
            *hour * 3'600 + *minute * 60 + *second;
        if (value.size() >= 24 && (value[19] == '+' || value[19] == '-')) {
            const auto zone_hour = number(20, 2).value_or(0);
            const auto zone_minute = number(22, 2).value_or(0);
            const auto offset = zone_hour * 3'600 + zone_minute * 60;
            epoch += value[19] == '+' ? -offset : offset;
        }
        return Timestamp { static_cast<std::int32_t>(std::clamp<std::int64_t>(
                               epoch, std::numeric_limits<std::int32_t>::min(),
                               std::numeric_limits<std::int32_t>::max())),
            0 };
    }

    void write32(
        std::span<std::byte> bytes, std::size_t offset, std::uint32_t value)
    {
        for (std::size_t index = 0; index < 4; ++index) {
            bytes[offset + index] =
                static_cast<std::byte>(value >> (index * 8U));
        }
    }

    void write64(
        std::span<std::byte> bytes, std::size_t offset, std::uint64_t value)
    {
        for (std::size_t index = 0; index < 8; ++index) {
            bytes[offset + index] =
                static_cast<std::byte>(value >> (index * 8U));
        }
    }

    std::size_t common_fixed_size(std::uint32_t mask)
    {
        using namespace attribute;
        std::size_t size = 0;
        if (mask & common_name)
            size += 8;
        if (mask & common_device)
            size += 4;
        if (mask & common_fsid)
            size += 8;
        if (mask & common_object_type)
            size += 4;
        if (mask & common_object_tag)
            size += 4;
        if (mask & common_object_id)
            size += 8;
        if (mask & common_permanent_id)
            size += 8;
        if (mask & common_parent_id)
            size += 8;
        if (mask & common_script)
            size += 4;
        if (mask & common_creation_time)
            size += 8;
        if (mask & common_modification_time)
            size += 8;
        if (mask & common_change_time)
            size += 8;
        if (mask & common_access_time)
            size += 8;
        if (mask & common_backup_time)
            size += 8;
        if (mask & common_finder_info)
            size += 32;
        if (mask & common_owner_id)
            size += 4;
        if (mask & common_group_id)
            size += 4;
        if (mask & common_access_mask)
            size += 4;
        if (mask & common_flags)
            size += 4;
        if (mask & common_user_access)
            size += 4;
        if (mask & common_file_id)
            size += 8;
        if (mask & common_parent_file_id)
            size += 8;
        if (mask & common_full_path)
            size += 8;
        if (mask & common_returned_attributes)
            size += 20;
        return size;
    }

    std::size_t directory_fixed_size(std::uint32_t mask)
    {
        return static_cast<std::size_t>(
                   std::popcount(mask & attribute::directory_supported_mask)) *
               4U;
    }

    std::size_t file_fixed_size(std::uint32_t mask)
    {
        using namespace attribute;
        std::size_t size = 0;
        for (const auto bit :
            { file_link_count, file_io_block_size, file_device_type }) {
            if (mask & bit)
                size += 4;
        }
        for (const auto bit : { file_total_size, file_allocation_size,
                 file_data_length, file_data_allocation_size,
                 file_resource_length, file_resource_allocation_size }) {
            if (mask & bit)
                size += 8;
        }
        return size;
    }

    std::size_t volume_fixed_size(std::uint32_t mask)
    {
        using namespace attribute;
        std::size_t size = 0;
        for (const auto bit :
            { volume_filesystem_type, volume_signature, volume_io_block_size,
                volume_object_count, volume_file_count, volume_directory_count,
                volume_max_object_count, volume_mount_flags }) {
            if (mask & bit)
                size += 4;
        }
        for (const auto bit : { volume_size, volume_space_free,
                 volume_space_available, volume_minimum_allocation,
                 volume_allocation_clump, volume_encodings_used }) {
            if (mask & bit)
                size += 8;
        }
        for (const auto bit :
            { volume_mount_point, volume_name, volume_mounted_device }) {
            if (mask & bit)
                size += 8;
        }
        if (mask & volume_capabilities)
            size += 32;
        if (mask & volume_attributes)
            size += 40;
        return size;
    }

    std::size_t padded_string_size(std::string_view value)
    {
        return (value.size() + 1U + 3U) & ~3U;
    }

}

std::uint32_t GuestIdTable::id_for(
    const Identity& identity, std::string_view guest_path)
{
    std::lock_guard lock { mutex_ };
    if (const auto known = ids_.find(identity); known != ids_.end())
        return known->second;
    auto id = fnv_catalog_id(
        std::as_bytes(std::span { guest_path.data(), guest_path.size() }));
    if (owners_.contains(id))
        ++collisions_;
    while (owners_.contains(id))
        id = id == last_user_catalog_id ? first_user_catalog_id : id + 1U;
    ids_.emplace(identity, id);
    owners_.emplace(id, identity);
    return id;
}

void GuestIdTable::forget(const Identity& identity)
{
    std::lock_guard lock { mutex_ };
    const auto known = ids_.find(identity);
    if (known == ids_.end())
        return;
    owners_.erase(known->second);
    ids_.erase(known);
}

std::size_t GuestIdTable::collisions() const
{
    std::lock_guard lock { mutex_ };
    return collisions_;
}

MetadataProvider::MetadataProvider(
    std::filesystem::path root, std::shared_ptr<GuestIdTable> guest_ids)
    : root_ { std::move(root) }
    , guest_ids_ { std::move(guest_ids) }
{
}

std::optional<std::uint32_t> MetadataProvider::table_id(std::uint64_t device,
    std::uint64_t inode, const std::filesystem::path& path) const
{
    if (!guest_ids_)
        return std::nullopt;
    const auto guest_path =
        path.lexically_normal().lexically_relative(root_).generic_string();
    return guest_ids_->id_for(
        GuestIdTable::Identity { device, inode }, guest_path);
}

std::optional<GuestIdTable::Identity> MetadataProvider::last_link_identity(
    const std::filesystem::path& path) const
{
    if (!guest_ids_)
        return std::nullopt;
    struct stat status { };
    if (::lstat(path.c_str(), &status) != 0)
        return std::nullopt;
    if (!S_ISDIR(status.st_mode) && status.st_nlink > 1)
        return std::nullopt;
    return GuestIdTable::Identity { static_cast<std::uint64_t>(status.st_dev),
        static_cast<std::uint64_t>(status.st_ino) };
}

bool MetadataProvider::remove_name(
    const std::filesystem::path& path, std::error_code& error) const
{
    const auto freed = last_link_identity(path);
    const auto removed = std::filesystem::remove(path, error);
    invalidate_xattrs();
    if (!removed)
        return false;
    if (freed)
        forget(*freed);
    return true;
}

void MetadataProvider::forget(const GuestIdTable::Identity& identity) const
{
    if (guest_ids_)
        guest_ids_->forget(identity);
}

std::uint64_t XattrCache::epoch() const
{
    const std::lock_guard lock { mutex_ };
    return epoch_;
}

std::optional<XattrCache::Value> XattrCache::find(const std::string& key) const
{
    const std::lock_guard lock { mutex_ };
    const auto found = entries_.find(key);
    if (found == entries_.end() || found->second.epoch != epoch_)
        return std::nullopt;
    return found->second.value;
}

void XattrCache::store(std::string key, Value value, std::uint64_t epoch)
{
    const std::lock_guard lock { mutex_ };
    if (epoch != epoch_)
        return;
    if (entries_.size() >= max_cached_xattrs)
        entries_.clear();
    entries_.insert_or_assign(
        std::move(key), Entry { epoch, std::move(value) });
}

void XattrCache::invalidate()
{
    const std::lock_guard lock { mutex_ };
    ++epoch_;
}

void MetadataProvider::invalidate_xattrs() const
{
    xattrs_->invalidate();
}

std::optional<std::vector<std::byte>> MetadataProvider::read_xattr(
    const std::filesystem::path& path, std::string_view name, bool follow) const
{
    std::string key { path.string() };
    key.push_back('\0');
    key.push_back(follow ? 'f' : 'l');
    key.append(name);
    if (const auto cached = xattrs_->find(key))
        return *cached;
    const auto epoch = xattrs_->epoch();
    auto value = read_host_xattr(path, name, follow);
    if (!value || value->size() <= max_cached_xattr_bytes)
        xattrs_->store(std::move(key), value, epoch);
    return value;
}

std::optional<std::uint32_t> MetadataProvider::numeric_xattr(
    const std::filesystem::path& path, std::string_view name, bool follow) const
{
    const auto bytes = read_xattr(path, name, follow);
    if (!bytes || bytes->empty())
        return std::nullopt;
    const std::string_view text {
        reinterpret_cast<const char*>(bytes->data()), bytes->size()
    };
    const auto terminator = text.find('\0');
    const auto length =
        terminator == std::string_view::npos ? text.size() : terminator;
    std::uint32_t result = 0;
    const auto parsed =
        std::from_chars(text.data(), text.data() + length, result, 10);
    return parsed.ec == std::errc { } && parsed.ptr == text.data() + length
               ? std::optional { result }
               : std::nullopt;
}

std::optional<std::uint32_t> MetadataProvider::inherited_identity(
    const std::filesystem::path& root, const std::filesystem::path& path,
    std::string_view name) const
{
    auto current = path.lexically_normal();
    while (is_within_root(root, current) && current != root) {
        current = current.parent_path();
        if (const auto value = numeric_xattr(current, name, true))
            return value;
    }
    return std::nullopt;
}

std::optional<Metadata> MetadataProvider::query(
    const std::filesystem::path& path, bool follow_symlink,
    bool include_directory_entry_count) const
{
    struct stat status { };
    if ((follow_symlink ? ::stat(path.c_str(), &status)
                        : ::lstat(path.c_str(), &status)) != 0) {
        return std::nullopt;
    }
    const auto is_root = path.lexically_normal() == root_.lexically_normal();
    Metadata result;
    result.name = is_root ? "/" : path.filename().string();
    result.directory = S_ISDIR(status.st_mode);
    result.object_type = result.directory          ? 2U
                         : S_ISLNK(status.st_mode) ? 5U
                                                   : 1U;
    result.mode =
        numeric_xattr(path, "user.hfsfuse.record.file_mode", follow_symlink)
            .value_or(static_cast<std::uint32_t>(status.st_mode));
    result.owner =
        numeric_xattr(path, "user.hfsfuse.record.owner_id", follow_symlink)
            .value_or(
                inherited_identity(root_, path, "user.hfsfuse.record.owner_id")
                    .value_or(0));
    result.group =
        numeric_xattr(path, "user.hfsfuse.record.group_id", follow_symlink)
            .value_or(
                inherited_identity(root_, path, "user.hfsfuse.record.group_id")
                    .value_or(0));
    result.flags =
        numeric_xattr(path, "user.hfsfuse.record.bsd_flags", follow_symlink)
            .value_or(0);
    result.link_count = static_cast<std::uint32_t>(status.st_nlink);
    result.permanent_id = table_id(status.st_dev, status.st_ino, path)
                              .value_or(inode_catalog_id(status));
    result.catalog_id =
        is_root ? hfs_root_catalog_id
        : status.st_nlink > 1
            ? path_catalog_id(root_, path)
            : numeric_xattr(path, "user.hfsfuse.record.cnid", follow_symlink)
                  .value_or(result.permanent_id);
    if (is_root) {
        result.parent_catalog_id = hfs_root_parent_id;
    } else {
        struct stat parent_status { };
        const auto parent = path.parent_path();
        if (::stat(parent.c_str(), &parent_status) != 0) {
            result.parent_catalog_id = hfs_root_catalog_id;
        } else if (const auto cnid =
                       numeric_xattr(parent, "user.hfsfuse.record.cnid", true)) {
            result.parent_catalog_id = *cnid;
        } else if (parent == root_) {
            result.parent_catalog_id = hfs_root_catalog_id;
        } else {
            result.parent_catalog_id =
                table_id(parent_status.st_dev, parent_status.st_ino, parent)
                    .value_or(inode_catalog_id(parent_status));
        }
    }
    result.data_length = S_ISREG(status.st_mode)
                             ? static_cast<std::uint64_t>(status.st_size)
                             : 0;
    result.data_allocation_size =
        static_cast<std::uint64_t>(status.st_blocks) * 512U;
    const auto sidecar = resource_sidecar(path);
    std::error_code resource_error;
    if (std::filesystem::is_regular_file(sidecar, resource_error)) {
        result.resource_length =
            std::filesystem::file_size(sidecar, resource_error);
        result.resource_allocation_size =
            (result.resource_length + hfs_block_size - 1U) &
            ~(static_cast<std::uint64_t>(hfs_block_size) - 1U);
    } else if (const auto fork = read_xattr(
                   path, "user.com.apple.ResourceFork", follow_symlink)) {
        result.resource_length = fork->size();
        result.resource_allocation_size =
            (result.resource_length + hfs_block_size - 1U) &
            ~(static_cast<std::uint64_t>(hfs_block_size) - 1U);
    }
    result.modification_time =
        Timestamp { static_cast<std::int32_t>(status.st_mtim.tv_sec),
            static_cast<std::int32_t>(status.st_mtim.tv_nsec) };
    result.change_time =
        Timestamp { static_cast<std::int32_t>(status.st_ctim.tv_sec),
            static_cast<std::int32_t>(status.st_ctim.tv_nsec) };
    result.access_time =
        Timestamp { static_cast<std::int32_t>(status.st_atim.tv_sec),
            static_cast<std::int32_t>(status.st_atim.tv_nsec) };
    result.creation_time = parse_hfs_time(
        read_xattr(path, "user.hfsfuse.record.date_created", follow_symlink)
            .value_or(std::vector<std::byte> { }))
                               .value_or(result.change_time);
    result.backup_time = parse_hfs_time(
        read_xattr(path, "user.hfsfuse.record.date_backedup", follow_symlink)
            .value_or(std::vector<std::byte> { }))
                             .value_or(Timestamp { });
    if (const auto finder =
            read_xattr(path, "user.com.apple.FinderInfo", follow_symlink)) {
        std::copy_n(finder->begin(),
            std::min(finder->size(), result.finder_info.size()),
            result.finder_info.begin());
    }
    if (result.directory && include_directory_entry_count) {
        std::error_code error;
        for (std::filesystem::directory_iterator iterator { path, error }, end;
            !error && iterator != end; iterator.increment(error)) {
            if (!is_resource_sidecar(iterator->path())) {
                ++result.directory_entry_count;
            }
        }
    }
    return result;
}

bool MetadataProvider::valid_request(const AttributeRequest& request)
{
    using namespace attribute;
    if ((request.common & ~common_supported_mask) != 0 || request.fork != 0) {
        return false;
    }
    if (request.volume != 0) {
        return (request.common & ~volume_common_supported_mask) == 0 &&
               (request.volume & ~volume_valid_mask) == 0 &&
               (request.volume & volume_info) != 0 && request.directory == 0 &&
               request.file == 0;
    }
    return (request.directory & ~directory_supported_mask) == 0 &&
           (request.file & ~file_supported_mask) == 0;
}

std::size_t MetadataProvider::fixed_block_size(const AttributeRequest& request)
{
    return 4U + common_fixed_size(request.common) +
           directory_fixed_size(request.directory) +
           file_fixed_size(request.file);
}

std::vector<std::byte> MetadataProvider::pack_attributes(
    const Metadata& metadata, const AttributeRequest& request,
    std::string_view guest_path)
{
    using namespace attribute;
    const auto fixed_size =
        4U + common_fixed_size(request.common) +
        (metadata.directory ? directory_fixed_size(request.directory)
                            : file_fixed_size(request.file));
    const auto name_size = (request.common & common_name) != 0
                               ? (metadata.name.size() + 1U + 3U) & ~3U
                               : 0U;
    const auto path_size = (request.common & common_full_path) != 0
                               ? padded_string_size(guest_path) : 0U;
    std::vector<std::byte> result(fixed_size + name_size + path_size);
    write32(result, 0, static_cast<std::uint32_t>(result.size()));
    std::size_t cursor = 4;
    auto word = [&](std::uint32_t value) {
        write32(result, cursor, value);
        cursor += 4;
    };
    auto wide = [&](std::uint64_t value) {
        write64(result, cursor, value);
        cursor += 8;
    };
    auto object_id = [&](std::uint32_t value) {
        word(value);
        word(0);
    };
    auto timestamp = [&](Timestamp value) {
        word(static_cast<std::uint32_t>(value.seconds));
        word(static_cast<std::uint32_t>(value.nanoseconds));
    };
    if (request.common & common_returned_attributes) {
        word(request.common);
        word(0);
        word(metadata.directory ? request.directory : 0);
        word(metadata.directory ? 0 : request.file);
        word(0);
    }
    if (request.common & common_name) {
        word(static_cast<std::uint32_t>(fixed_size - cursor));
        word(static_cast<std::uint32_t>(metadata.name.size() + 1U));
    }
    if (request.common & common_device)
        word(hfs_device);
    if (request.common & common_fsid) {
        word(hfs_device);
        word(0);
    }
    if (request.common & common_object_type)
        word(metadata.object_type);
    if (request.common & common_object_tag)
        word(hfs_vnode_tag);
    if (request.common & common_object_id)
        object_id(metadata.catalog_id);
    if (request.common & common_permanent_id)
        object_id(metadata.permanent_id);
    if (request.common & common_parent_id)
        object_id(metadata.parent_catalog_id);
    if (request.common & common_script)
        word(0);
    if (request.common & common_creation_time)
        timestamp(metadata.creation_time);
    if (request.common & common_modification_time)
        timestamp(metadata.modification_time);
    if (request.common & common_change_time)
        timestamp(metadata.change_time);
    if (request.common & common_access_time)
        timestamp(metadata.access_time);
    if (request.common & common_backup_time)
        timestamp(metadata.backup_time);
    if (request.common & common_finder_info) {
        std::copy(metadata.finder_info.begin(), metadata.finder_info.end(),
            result.begin() + static_cast<std::ptrdiff_t>(cursor));
        cursor += metadata.finder_info.size();
    }
    if (request.common & common_owner_id)
        word(metadata.owner);
    if (request.common & common_group_id)
        word(metadata.group);
    if (request.common & common_access_mask)
        word(metadata.mode);
    if (request.common & common_flags)
        word(metadata.flags);
    if (request.common & common_user_access)
        word(7);
    if (request.common & common_file_id)
        wide(metadata.permanent_id);
    if (request.common & common_parent_file_id)
        wide(metadata.parent_catalog_id);
    if (request.common & common_full_path) {
        word(static_cast<std::uint32_t>(fixed_size + name_size - cursor));
        word(static_cast<std::uint32_t>(guest_path.size() + 1U));
    }

    if (metadata.directory) {
        const auto directory_value = [&](std::uint32_t bit,
                                         std::uint32_t value) {
            if (request.directory & bit)
                word(value);
        };
        directory_value(directory_link_count, metadata.link_count);
        directory_value(directory_entry_count, metadata.directory_entry_count);
        directory_value(directory_mount_status, 0);
    }

    if (!metadata.directory) {
        const auto file_word = [&](std::uint32_t bit, std::uint32_t value) {
            if (request.file & bit)
                word(value);
        };
        const auto file_wide = [&](std::uint32_t bit, std::uint64_t value) {
            if (request.file & bit)
                wide(value);
        };
        file_word(file_link_count, metadata.link_count);
        file_wide(
            file_total_size, metadata.data_length + metadata.resource_length);
        file_wide(file_allocation_size,
            metadata.data_allocation_size + metadata.resource_allocation_size);
        file_word(file_io_block_size, hfs_block_size);
        file_word(file_device_type, 0);
        file_wide(file_data_length, metadata.data_length);
        file_wide(file_data_allocation_size, metadata.data_allocation_size);
        file_wide(file_resource_length, metadata.resource_length);
        file_wide(
            file_resource_allocation_size, metadata.resource_allocation_size);
    }

    if (name_size != 0) {
        std::memcpy(result.data() + fixed_size, metadata.name.c_str(),
            metadata.name.size() + 1U);
    }
    if (path_size != 0)
        std::memcpy(result.data() + fixed_size + name_size,
            guest_path.data(), guest_path.size());
    return result;
}

std::vector<std::byte> MetadataProvider::pack_volume_attributes(
    const Metadata& root, const VolumeMetadata& volume,
    const AttributeRequest& request)
{
    using namespace attribute;
    const auto fixed_size = 4U + common_fixed_size(request.common) +
                            volume_fixed_size(request.volume);
    std::size_t variable_size = 0;
    if (request.common & common_name) {
        variable_size += padded_string_size(volume.name);
    }
    if (request.volume & volume_mount_point) {
        variable_size += padded_string_size(volume.mount_point);
    }
    if (request.volume & volume_name) {
        variable_size += padded_string_size(volume.name);
    }
    if (request.volume & volume_mounted_device) {
        variable_size += padded_string_size(volume.mounted_device);
    }
    std::vector<std::byte> result(fixed_size + variable_size);
    write32(result, 0, static_cast<std::uint32_t>(result.size()));
    std::size_t cursor = 4;
    std::size_t variable_cursor = fixed_size;
    auto word = [&](std::uint32_t value) {
        write32(result, cursor, value);
        cursor += 4;
    };
    auto wide = [&](std::uint64_t value) {
        write64(result, cursor, value);
        cursor += 8;
    };
    auto object_id = [&](std::uint32_t value) {
        word(value);
        word(0);
    };
    auto timestamp = [&](Timestamp value) {
        word(static_cast<std::uint32_t>(value.seconds));
        word(static_cast<std::uint32_t>(value.nanoseconds));
    };
    auto string = [&](std::string_view value) {
        word(static_cast<std::uint32_t>(variable_cursor - cursor));
        word(static_cast<std::uint32_t>(value.size() + 1U));
        std::memcpy(
            result.data() + variable_cursor, value.data(), value.size());
        variable_cursor += padded_string_size(value);
    };

    if (request.common & common_returned_attributes) {
        word(request.common);
        word(request.volume);
        word(0);
        word(0);
        word(0);
    }

    if (request.common & common_name)
        string(volume.name);
    if (request.common & common_device)
        word(hfs_device);
    if (request.common & common_fsid) {
        word(hfs_device);
        word(volume.filesystem_type);
    }
    if (request.common & common_object_type)
        word(0);
    if (request.common & common_object_tag)
        word(hfs_vnode_tag);
    if (request.common & common_object_id)
        object_id(0);
    if (request.common & common_permanent_id)
        object_id(0);
    if (request.common & common_parent_id)
        object_id(0);
    if (request.common & common_script)
        word(0);
    if (request.common & common_creation_time)
        timestamp(root.creation_time);
    if (request.common & common_modification_time)
        timestamp(root.modification_time);
    if (request.common & common_change_time)
        timestamp(root.modification_time);
    if (request.common & common_access_time)
        timestamp(root.access_time);
    if (request.common & common_backup_time)
        timestamp(root.backup_time);
    if (request.common & common_finder_info) {
        std::copy(root.finder_info.begin(), root.finder_info.end(),
            result.begin() + static_cast<std::ptrdiff_t>(cursor));
        cursor += root.finder_info.size();
    }
    if (request.common & common_owner_id)
        word(root.owner);
    if (request.common & common_group_id)
        word(root.group);
    if (request.common & common_access_mask)
        word(root.mode);
    if (request.common & common_flags)
        word(root.flags);
    if (request.common & common_user_access)
        word(7);

    const auto mask = request.volume;
    if (mask & volume_filesystem_type)
        word(volume.filesystem_type);
    if (mask & volume_signature)
        word(volume.signature);
    if (mask & volume_size) {
        wide(static_cast<std::uint64_t>(volume.block_size) *
             volume.total_blocks);
    }
    if (mask & volume_space_free) {
        wide(
            static_cast<std::uint64_t>(volume.block_size) * volume.free_blocks);
    }
    if (mask & volume_space_available) {
        wide(
            static_cast<std::uint64_t>(volume.block_size) * volume.free_blocks);
    }
    if (mask & volume_minimum_allocation)
        wide(volume.block_size);
    if (mask & volume_allocation_clump)
        wide(volume.allocation_clump);
    if (mask & volume_io_block_size)
        word(volume.io_block_size);
    if (mask & volume_object_count) {
        word(volume.file_count + volume.directory_count);
    }
    if (mask & volume_file_count)
        word(volume.file_count);
    if (mask & volume_directory_count)
        word(volume.directory_count);
    if (mask & volume_max_object_count)
        word(0xffff'ffffU);
    if (mask & volume_mount_point)
        string(volume.mount_point);
    if (mask & volume_name)
        string(volume.name);
    if (mask & volume_mount_flags)
        word(volume.mount_flags);
    if (mask & volume_mounted_device)
        string(volume.mounted_device);
    if (mask & volume_encodings_used)
        wide(volume.encodings_used);
    if (mask & volume_capabilities) {
        constexpr std::array<std::uint32_t, 8> capabilities { 0x00000f0fU,
            0x000003dfU, 0, 0, 0x00000fffU, 0x000003ffU, 0, 0 };
        for (const auto value : capabilities)
            word(value);
    }
    if (mask & volume_attributes) {
        constexpr std::array<std::uint32_t, 5> attributes { 0x003f'ffffU,
            volume_valid_mask, directory_supported_mask, 0x0000'7fffU,
            0x0000'0003U };
        for (const auto value : attributes)
            word(value);
        for (const auto value : attributes)
            word(value);
    }
    return result;
}

void MetadataProvider::apply_override(
    Metadata& metadata, const MetadataOverride& override)
{
    if (override.mode)
        metadata.mode = *override.mode;
    if (override.owner)
        metadata.owner = *override.owner;
    if (override.group)
        metadata.group = *override.group;
    if (override.flags)
        metadata.flags = *override.flags;
    if (override.creation_time)
        metadata.creation_time = *override.creation_time;
    if (override.modification_time) {
        metadata.modification_time = *override.modification_time;
    }
    if (override.change_time)
        metadata.change_time = *override.change_time;
    if (override.access_time)
        metadata.access_time = *override.access_time;
    if (override.backup_time)
        metadata.backup_time = *override.backup_time;
    if (override.finder_info)
        metadata.finder_info = *override.finder_info;
    if (override.resource_length) {
        metadata.resource_length = *override.resource_length;
    }
    if (override.resource_allocation_size) {
        metadata.resource_allocation_size = *override.resource_allocation_size;
    }
}

std::optional<std::vector<std::byte>> MetadataProvider::named_attribute(
    const std::filesystem::path& path, std::string_view name,
    bool follow_symlink) const
{
    if (name.empty() || name.size() > 127U)
        return std::nullopt;
    if (name == "com.apple.ResourceFork") {
        const auto sidecar = resource_sidecar(path);
        std::error_code error;
        if (std::filesystem::is_regular_file(sidecar, error)) {
            const auto size = std::filesystem::file_size(sidecar, error);
            if (error || size == 0 ||
                size > static_cast<std::uint64_t>(
                           std::numeric_limits<std::size_t>::max())) {
                return std::nullopt;
            }
            std::vector<std::byte> result(static_cast<std::size_t>(size));
            std::ifstream stream { sidecar, std::ios::binary };
            if (!stream.read(reinterpret_cast<char*>(result.data()),
                    static_cast<std::streamsize>(result.size()))) {
                return std::nullopt;
            }
            return result;
        }
    }
    const auto host_name = std::string { "user." } + std::string { name };
    auto result = read_xattr(path, host_name, follow_symlink);
    if (result && name == "com.apple.FinderInfo" &&
        std::all_of(result->begin(), result->end(),
            [](std::byte value) { return value == std::byte { }; })) {
        return std::nullopt;
    }
    if (result && result->empty())
        return std::nullopt;
    return result;
}

std::vector<std::string> MetadataProvider::named_attributes(
    const std::filesystem::path& path, bool follow_symlink) const
{
    std::set<std::string> names;
    const auto size = host_listxattr(path.c_str(), nullptr, 0, follow_symlink);
    if (size > 0) {
        std::vector<char> buffer(static_cast<std::size_t>(size));
        const auto received = host_listxattr(
            path.c_str(), buffer.data(), buffer.size(), follow_symlink);
        std::size_t cursor = 0;
        while (received > 0 && cursor < static_cast<std::size_t>(received)) {
            const std::string_view host_name { buffer.data() + cursor };
            cursor += host_name.size() + 1U;
            constexpr std::string_view prefix { "user." };
            if (!host_name.starts_with(prefix))
                continue;
            const auto guest_name = host_name.substr(prefix.size());
            if (guest_name.starts_with("hfsfuse.record."))
                continue;
            if (named_attribute(path, guest_name, follow_symlink)) {
                names.emplace(guest_name);
            }
        }
    }
    if (named_attribute(path, "com.apple.ResourceFork", follow_symlink)) {
        names.emplace("com.apple.ResourceFork");
    }
    return { names.begin(), names.end() };
}

bool MetadataProvider::is_resource_sidecar(const std::filesystem::path& path)
{
    return path.filename().string().ends_with(resource_sidecar_suffix);
}

std::filesystem::path MetadataProvider::resource_sidecar(
    const std::filesystem::path& path)
{
    auto result = path;
    result += resource_sidecar_suffix;
    return result;
}

}
