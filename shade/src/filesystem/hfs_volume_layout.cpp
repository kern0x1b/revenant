// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Discover guest HFS mount identities and geometry from the firmware
// filesystem.

#include "filesystem/hfs_volume_layout.hpp"

#include <algorithm>
#include <fstream>
#include <limits>
#include <sstream>
#include <string>
#include <system_error>

namespace shade::hfs {
namespace {

    constexpr std::uint32_t mount_read_only = 0x00000001U;
    constexpr std::uint32_t mount_no_execute = 0x00000004U;
    constexpr std::uint32_t mount_no_suid = 0x00000008U;
    constexpr std::uint32_t mount_no_devices = 0x00000010U;
    constexpr std::uint32_t mount_local = 0x00001000U;
    constexpr std::uint32_t mount_rootfs = 0x00004000U;

    struct DataUsage {
        std::uint64_t bytes { };
        std::uint32_t files { };
        std::uint32_t directories { };
    };

    DataUsage data_usage(const std::filesystem::path& path)
    {
        DataUsage usage;
        std::error_code error;
        if (!std::filesystem::exists(path, error))
            return usage;
        for (std::filesystem::recursive_directory_iterator iterator { path,
                 std::filesystem::directory_options::skip_permission_denied,
                 error },
            end;
            !error && iterator != end; iterator.increment(error)) {
            const auto status = iterator->symlink_status(error);
            if (error)
                break;
            if (std::filesystem::is_directory(status)) {
                ++usage.directories;
            } else if (std::filesystem::is_regular_file(status)) {
                usage.bytes += iterator->file_size(error);
                if (error)
                    break;
                ++usage.files;
            }
        }
        return usage;
    }

    std::uint32_t mount_flags(
        std::string_view mount_point, std::string_view options)
    {
        auto result = mount_local;
        if (mount_point == "/")
            result |= mount_rootfs;
        std::size_t cursor = 0;
        while (cursor <= options.size()) {
            const auto separator = options.find(',', cursor);
            const auto option = options.substr(cursor,
                separator == std::string_view::npos ? options.size() - cursor
                                                    : separator - cursor);
            if (option == "ro")
                result |= mount_read_only;
            else if (option == "noexec")
                result |= mount_no_execute;
            else if (option == "nosuid")
                result |= mount_no_suid;
            else if (option == "nodev")
                result |= mount_no_devices;
            if (separator == std::string_view::npos)
                break;
            cursor = separator + 1;
        }
        return result;
    }

    bool contains_path(std::string_view mount_point, std::string_view path)
    {
        if (mount_point == "/")
            return !path.empty() && path.front() == '/';
        return path == mount_point || (path.size() > mount_point.size() &&
                                          path.starts_with(mount_point) &&
                                          path[mount_point.size()] == '/');
    }

    std::string normalize_guest_path(std::string_view path)
    {
        if (path == "/var")
            return "/private/var";
        if (path.starts_with("/var/"))
            return "/private" + std::string { path };
        if (path.empty() || path.front() != '/')
            return "/" + std::string { path };
        return std::string { path };
    }

    VolumeMetadata data_volume(std::string source, std::string mount_point,
        std::string_view options, const std::filesystem::path& rootfs,
        std::uint64_t storage_bytes, std::uint32_t system_blocks)
    {
        VolumeMetadata volume;
        volume.name = "Data";
        volume.mount_point = std::move(mount_point);
        volume.mounted_device = std::move(source);
        volume.mount_flags = mount_flags(volume.mount_point, options);
        const auto storage_blocks =
            std::min<std::uint64_t>(storage_bytes / volume.block_size,
                std::numeric_limits<std::uint32_t>::max());
        volume.total_blocks = static_cast<std::uint32_t>(
            storage_blocks > system_blocks ? storage_blocks - system_blocks
                                           : 1U);
        const auto relative =
            std::filesystem::path { volume.mount_point }.relative_path();
        const auto usage = data_usage(rootfs / relative);
        const auto used_blocks = std::min<std::uint64_t>(
            (usage.bytes + volume.block_size - 1U) / volume.block_size,
            volume.total_blocks);
        volume.free_blocks =
            volume.total_blocks - static_cast<std::uint32_t>(used_blocks);
        volume.file_count = usage.files;
        volume.directory_count = usage.directories + 1U;
        volume.next_catalog_id =
            16U + volume.file_count + volume.directory_count;
        return volume;
    }

} // namespace

VolumeLayout::VolumeLayout(
    std::filesystem::path rootfs, std::uint64_t storage_bytes)
{
    volumes_.push_back(VolumeMetadata { });
    const auto fstab = rootfs / "private/etc/fstab";
    std::ifstream input { fstab };
    if (!input)
        input.open(rootfs / "etc/fstab");

    std::string line;
    while (std::getline(input, line)) {
        const auto comment = line.find('#');
        if (comment != std::string::npos)
            line.erase(comment);
        std::istringstream parser { line };
        std::string source;
        std::string mount_point;
        std::string type;
        std::string options;
        if (!(parser >> source >> mount_point >> type >> options) ||
            type != "hfs")
            continue;
        if (mount_point == "/") {
            auto& system = volumes_.front();
            system.mount_point = mount_point;
            system.mounted_device = source;
            system.mount_flags = mount_flags(mount_point, options);
            continue;
        }
        if (std::ranges::any_of(volumes_, [&](const auto& volume) {
                return volume.mount_point == mount_point;
            })) {
            continue;
        }
        volumes_.push_back(
            data_volume(std::move(source), std::move(mount_point), options,
                rootfs, storage_bytes, volumes_.front().total_blocks));
    }
}

const VolumeMetadata& VolumeLayout::for_guest_path(std::string_view path) const
{
    const auto normalized = normalize_guest_path(path);
    const VolumeMetadata* result = nullptr;
    for (const auto& volume : volumes_) {
        if (contains_path(volume.mount_point, normalized) &&
            (!result ||
                volume.mount_point.size() > result->mount_point.size())) {
            result = &volume;
        }
    }
    return result ? *result : volumes_.front();
}

const VolumeMetadata& VolumeLayout::for_mounted_device(
    std::string_view device) const
{
    const auto found = std::ranges::find_if(volumes_,
        [&](const auto& volume) { return volume.mounted_device == device; });
    return found == volumes_.end() ? for_guest_path("/") : *found;
}

bool VolumeLayout::is_mount_root(std::string_view path) const
{
    const auto normalized =
        std::filesystem::path { normalize_guest_path(path) }.lexically_normal();
    return normalized.generic_string() == for_guest_path(path).mount_point;
}

} // namespace shade::hfs
