// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Track executable files, mappings and generations for loading and
// translation reuse.

#include "foundation/executable_catalog.hpp"

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <fstream>
#include <iterator>
#include <limits>
#include <span>
#include <sstream>
#include <stdexcept>
#include <string_view>
#include <system_error>
#include <utility>

#include <sys/stat.h>

#if defined(__APPLE__)
#define st_atim st_atimespec
#define st_mtim st_mtimespec
#define st_ctim st_ctimespec
#endif

namespace {

using shade::ContentIdentity;
using shade::DyldCacheImage;
using shade::DyldCacheImageView;
using shade::DyldSharedCache;

constexpr std::array<char, 8> catalog_magic { 'i', 'L', 'E', 'M', 'C', 'A', 'T',
    '1' };
constexpr std::uint32_t catalog_schema_version = 8U;
constexpr std::size_t catalog_checksum_size = 32U;
constexpr std::uint32_t maximum_manifest_entries = 100'000U;
constexpr std::uint32_t maximum_manifest_items = 65'536U;
constexpr std::uint32_t maximum_manifest_string = 1U << 20U;
constexpr std::uintmax_t maximum_manifest_file_size = 256U * 1024U * 1024U;

void append_u32(std::vector<std::byte>& bytes, std::uint32_t value)
{
    for (std::size_t index = 0; index < sizeof(value); ++index) {
        bytes.push_back(static_cast<std::byte>(value >> (index * 8U)));
    }
}

void append_u64(std::vector<std::byte>& bytes, std::uint64_t value)
{
    for (std::size_t index = 0; index < sizeof(value); ++index) {
        bytes.push_back(static_cast<std::byte>(value >> (index * 8U)));
    }
}

void append_string(std::vector<std::byte>& bytes, std::string_view value)
{
    append_u64(bytes, static_cast<std::uint64_t>(value.size()));
    bytes.insert(bytes.end(), reinterpret_cast<const std::byte*>(value.data()),
        reinterpret_cast<const std::byte*>(value.data() + value.size()));
}

void append_identity(
    std::vector<std::byte>& bytes, const ContentIdentity& identity)
{
    bytes.insert(bytes.end(), identity.digest.begin(), identity.digest.end());
}

void write_u32(std::ostream& stream, std::uint32_t value)
{
    for (unsigned shift = 0; shift < 32U; shift += 8U) {
        stream.put(static_cast<char>(value >> shift));
    }
}

void write_u64(std::ostream& stream, std::uint64_t value)
{
    for (unsigned shift = 0; shift < 64U; shift += 8U) {
        stream.put(static_cast<char>(value >> shift));
    }
}

void write_u8(std::ostream& stream, std::uint8_t value)
{
    stream.put(static_cast<char>(value));
}

void write_string(std::ostream& stream, std::string_view value)
{
    write_u32(stream, static_cast<std::uint32_t>(value.size()));
    stream.write(value.data(), static_cast<std::streamsize>(value.size()));
}

[[nodiscard]] std::optional<std::uint8_t> read_u8(std::istream& stream)
{
    const auto value = stream.get();
    if (value == std::char_traits<char>::eof())
        return std::nullopt;
    return static_cast<std::uint8_t>(static_cast<unsigned char>(value));
}

[[nodiscard]] std::optional<std::uint32_t> read_u32(std::istream& stream)
{
    std::uint32_t value = 0;
    for (unsigned shift = 0; shift < 32U; shift += 8U) {
        const auto byte = stream.get();
        if (byte == std::char_traits<char>::eof())
            return std::nullopt;
        value |= static_cast<std::uint32_t>(static_cast<unsigned char>(byte))
                 << shift;
    }
    return value;
}

[[nodiscard]] std::optional<std::uint64_t> read_u64(std::istream& stream)
{
    std::uint64_t value = 0;
    for (unsigned shift = 0; shift < 64U; shift += 8U) {
        const auto byte = stream.get();
        if (byte == std::char_traits<char>::eof())
            return std::nullopt;
        value |= static_cast<std::uint64_t>(static_cast<unsigned char>(byte))
                 << shift;
    }
    return value;
}

[[nodiscard]] std::optional<shade::ExecutableCatalogFileGeneration>
read_file_generation(const std::filesystem::path& path)
{
    struct stat file_stat { };
    if (::stat(path.c_str(), &file_stat) != 0 || !S_ISREG(file_stat.st_mode) ||
        file_stat.st_size < 0) {
        return std::nullopt;
    }
    return shade::ExecutableCatalogFileGeneration { static_cast<std::uint64_t>(
                                                        file_stat.st_dev),
        static_cast<std::uint64_t>(file_stat.st_ino),
        static_cast<std::uint64_t>(file_stat.st_size),
        static_cast<std::int64_t>(file_stat.st_mtim.tv_sec),
        static_cast<std::int64_t>(file_stat.st_mtim.tv_nsec),
        static_cast<std::int64_t>(file_stat.st_ctim.tv_sec),
        static_cast<std::int64_t>(file_stat.st_ctim.tv_nsec) };
}

void write_identity(std::ostream& stream, const ContentIdentity& identity)
{
    stream.write(reinterpret_cast<const char*>(identity.digest.data()),
        static_cast<std::streamsize>(identity.digest.size()));
}

[[nodiscard]] bool read_identity(
    std::istream& stream, ContentIdentity& identity)
{
    stream.read(reinterpret_cast<char*>(identity.digest.data()),
        static_cast<std::streamsize>(identity.digest.size()));
    return static_cast<bool>(stream);
}

[[nodiscard]] std::optional<std::string> read_string(std::istream& stream)
{
    const auto size = read_u32(stream);
    if (!size || *size > maximum_manifest_string)
        return std::nullopt;
    std::string value(*size, '\0');
    stream.read(value.data(), static_cast<std::streamsize>(value.size()));
    if (!stream)
        return std::nullopt;
    return value;
}

[[nodiscard]] std::optional<shade::ExecutableCatalogEntry> read_manifest_entry(
    std::istream& stream, std::uint32_t schema)
{
    shade::ExecutableCatalogEntry entry;
    if (!read_identity(stream, entry.content_identity))
        return std::nullopt;

    const auto alias_count = read_u32(stream);
    if (!alias_count || *alias_count > maximum_manifest_items) {
        return std::nullopt;
    }
    entry.aliases.reserve(*alias_count);
    for (std::uint32_t index = 0; index < *alias_count; ++index) {
        const auto alias = read_string(stream);
        if (!alias)
            return std::nullopt;
        entry.aliases.emplace_back(*alias);
    }

    const auto generation_count = read_u32(stream);
    if (!generation_count || *generation_count > maximum_manifest_items) {
        return std::nullopt;
    }
    entry.file_generations.reserve(*generation_count);
    for (std::uint32_t index = 0; index < *generation_count; ++index) {
        const auto path = read_string(stream);
        const auto device = read_u64(stream);
        const auto inode = read_u64(stream);
        const auto file_size = read_u64(stream);
        const auto modified_seconds = read_u64(stream);
        const auto modified_nanoseconds = read_u64(stream);
        const auto changed_seconds = read_u64(stream);
        const auto changed_nanoseconds = read_u64(stream);
        if (!path || !device || !inode || !file_size || !modified_seconds ||
            !modified_nanoseconds || !changed_seconds || !changed_nanoseconds) {
            return std::nullopt;
        }
        entry.file_generations.push_back(
            shade::ExecutableCatalogPathGeneration { *path,
                shade::ExecutableCatalogFileGeneration { *device, *inode,
                    *file_size, static_cast<std::int64_t>(*modified_seconds),
                    static_cast<std::int64_t>(*modified_nanoseconds),
                    static_cast<std::int64_t>(*changed_seconds),
                    static_cast<std::int64_t>(*changed_nanoseconds) } });
    }

    const auto kind_count = read_u32(stream);
    if (!kind_count || *kind_count > maximum_manifest_items) {
        return std::nullopt;
    }
    for (std::uint32_t index = 0; index < *kind_count; ++index) {
        const auto kind = read_u8(stream);
        if (!kind ||
            *kind > static_cast<std::uint8_t>(
                        shade::ExecutableCatalogKind::DynamicMapping)) {
            return std::nullopt;
        }
        entry.kinds.insert(static_cast<shade::ExecutableCatalogKind>(*kind));
    }

    const auto has_uuid = read_u8(stream);
    if (!has_uuid || *has_uuid > 1U)
        return std::nullopt;
    if (*has_uuid != 0U) {
        std::array<std::byte, 16> uuid { };
        stream.read(reinterpret_cast<char*>(uuid.data()),
            static_cast<std::streamsize>(uuid.size()));
        if (!stream)
            return std::nullopt;
        entry.uuid = uuid;
    }

    const auto cpu_type = read_u32(stream);
    const auto cpu_subtype = read_u32(stream);
    const auto file_type = read_u32(stream);
    const auto file_size = read_u64(stream);
    if (!cpu_type || !cpu_subtype || !file_type || !file_size) {
        return std::nullopt;
    }
    entry.cpu_type = *cpu_type;
    entry.cpu_subtype = *cpu_subtype;
    entry.file_type = *file_type;
    entry.file_size = *file_size;

    const auto fat_container = read_u8(stream);
    if (!fat_container || *fat_container > 1U)
        return std::nullopt;
    entry.fat_container = *fat_container != 0U;

    const auto dependency_count = read_u32(stream);
    if (!dependency_count || *dependency_count > maximum_manifest_items) {
        return std::nullopt;
    }
    entry.dependencies.reserve(*dependency_count);
    for (std::uint32_t index = 0; index < *dependency_count; ++index) {
        const auto dependency = read_string(stream);
        if (!dependency)
            return std::nullopt;
        entry.dependencies.push_back(*dependency);
    }

    const auto mapping_count = read_u32(stream);
    if (!mapping_count || *mapping_count > maximum_manifest_items) {
        return std::nullopt;
    }
    entry.mappings.reserve(*mapping_count);
    for (std::uint32_t index = 0; index < *mapping_count; ++index) {
        const auto file_offset = read_u64(stream);
        const auto byte_count = read_u64(stream);
        if (!file_offset || !byte_count)
            return std::nullopt;
        std::uint64_t guest_address = 0;
        std::uint64_t guest_byte_count = 0;
        if (schema >= 6U) {
            const auto serialized_guest_address = read_u64(stream);
            const auto serialized_guest_byte_count = read_u64(stream);
            if (!serialized_guest_address || !serialized_guest_byte_count) {
                return std::nullopt;
            }
            guest_address = *serialized_guest_address;
            guest_byte_count = *serialized_guest_byte_count;
        }
        entry.mappings.push_back(shade::ExecutableMappingIdentity {
            *file_offset, *byte_count, guest_address, guest_byte_count });
    }
    if (schema >= 5U) {
        const auto entry_point_count = read_u32(stream);
        if (!entry_point_count || *entry_point_count > maximum_manifest_items) {
            return std::nullopt;
        }
        entry.reliable_entry_points.reserve(*entry_point_count);
        for (std::uint32_t index = 0; index < *entry_point_count; ++index) {
            const auto entry_point = read_u64(stream);
            if (!entry_point || *entry_point == 0U ||
                (*entry_point & ~(std::uint64_t { 1 } << 32U)) >
                    std::numeric_limits<std::uint32_t>::max()) {
                return std::nullopt;
            }
            entry.reliable_entry_points.push_back(*entry_point);
        }
    }
    if (entry.aliases.empty() || entry.kinds.empty())
        return std::nullopt;
    return entry;
}

struct FilePrefix {
    std::array<std::byte, 16> bytes { };
    std::size_t size { };
};

std::optional<FilePrefix> read_file_prefix(const std::filesystem::path& path)
{
    std::ifstream input { path, std::ios::binary };
    if (!input)
        return std::nullopt;
    FilePrefix prefix;
    input.read(reinterpret_cast<char*>(prefix.bytes.data()),
        static_cast<std::streamsize>(prefix.bytes.size()));
    if (input.bad())
        return std::nullopt;
    prefix.size = static_cast<std::size_t>(input.gcount());
    return prefix;
}

bool has_dyld_cache_magic(const FilePrefix& prefix)
{
    constexpr std::string_view magic_prefix = "dyld_v1";
    if (prefix.size < magic_prefix.size())
        return false;
    return std::equal(magic_prefix.begin(), magic_prefix.end(),
        reinterpret_cast<const char*>(prefix.bytes.data()));
}

bool has_macho_magic(const FilePrefix& prefix)
{
    if (prefix.size < sizeof(std::uint32_t))
        return false;
    const auto little_endian_word =
        std::to_integer<std::uint32_t>(prefix.bytes[0]) |
        (std::to_integer<std::uint32_t>(prefix.bytes[1]) << 8U) |
        (std::to_integer<std::uint32_t>(prefix.bytes[2]) << 16U) |
        (std::to_integer<std::uint32_t>(prefix.bytes[3]) << 24U);
    const auto big_endian_word =
        (std::to_integer<std::uint32_t>(prefix.bytes[0]) << 24U) |
        (std::to_integer<std::uint32_t>(prefix.bytes[1]) << 16U) |
        (std::to_integer<std::uint32_t>(prefix.bytes[2]) << 8U) |
        std::to_integer<std::uint32_t>(prefix.bytes[3]);
    constexpr auto mh_magic = std::uint32_t { 0xfeedfaceU };
    constexpr auto fat_magic = std::uint32_t { 0xcafebabeU };
    return little_endian_word == mh_magic || big_endian_word == fat_magic;
}

[[nodiscard]] bool path_is_within(
    const std::filesystem::path& path, const std::filesystem::path& root)
{
    const auto relative = path.lexically_relative(root);
    return path == root ||
           (!relative.empty() && relative != "." &&
               relative.begin() != relative.end() && *relative.begin() != "..");
}

[[nodiscard]] std::optional<std::filesystem::path> resolve_catalog_symlink(
    const std::filesystem::path& alias, const std::filesystem::path& root)
{
    std::error_code error;
    const auto status = std::filesystem::symlink_status(alias, error);
    if (error || !std::filesystem::is_symlink(status))
        return std::nullopt;
    const auto resolved_root = std::filesystem::weakly_canonical(root, error);
    if (error)
        return std::nullopt;
    error.clear();
    const auto resolved = std::filesystem::weakly_canonical(alias, error);
    if (error || !path_is_within(resolved, resolved_root)) {
        return std::nullopt;
    }
    error.clear();
    if (!std::filesystem::is_regular_file(
            std::filesystem::symlink_status(resolved, error)) ||
        error) {
        return std::nullopt;
    }
    return resolved;
}

ContentIdentity shared_cache_image_identity(
    const DyldSharedCache& cache, const DyldCacheImageView& image)
{
    std::vector<std::byte> key;
    key.reserve(
        128U + image.path.size() + image.executable_ranges.size() * 40U);
    append_identity(key, cache.generation_identity());
    append_u32(key, image.index);
    append_string(key, image.path);
    append_u64(key, image.unslid_load_address);
    append_u64(key, image.text_segment_size);
    key.push_back(static_cast<std::byte>(image.text_uuid.has_value()));
    if (image.text_uuid) {
        key.insert(key.end(), image.text_uuid->begin(), image.text_uuid->end());
    }
    key.push_back(static_cast<std::byte>(image.text_identity.has_value()));
    if (image.text_identity)
        append_identity(key, *image.text_identity);
    append_u64(key, static_cast<std::uint64_t>(image.executable_ranges.size()));
    for (const auto& range : image.executable_ranges) {
        append_u64(key, range.address);
        append_u64(key, range.size);
        append_u64(key, range.file_offset);
        append_u32(key, range.file_index);
        append_u32(key, range.initial_protection);
        append_u32(key, range.maximum_protection);
    }
    return shade::sha256(key);
}

shade::ExecutableCatalogKind classify_shared_cache_image(std::string_view path)
{
    if (path.find(".framework/") != std::string_view::npos ||
        path.ends_with(".framework")) {
        return shade::ExecutableCatalogKind::Framework;
    }
    if (path.find("/PlugIns/") != std::string_view::npos ||
        path.ends_with(".plugin") || path.ends_with(".appex")) {
        return shade::ExecutableCatalogKind::PlugIn;
    }
    return shade::ExecutableCatalogKind::Dylib;
}

bool executable_address(const shade::MachOImage& image, std::uint32_t address)
{
    for (const auto& segment : image.segments()) {
        if ((segment.initial_protection & 4) == 0 ||
            address < segment.vm_address ||
            address - segment.vm_address >= segment.vm_size) {
            continue;
        }
        return true;
    }
    return false;
}

bool executable_instruction_address(
    const shade::MachOImage& image, std::uint32_t address)
{
    constexpr std::uint32_t pure_instructions = 0x80000000U;
    constexpr std::uint32_t some_instructions = 0x00000400U;
    for (const auto& segment : image.segments()) {
        if ((segment.initial_protection & 4) == 0 ||
            address < segment.vm_address ||
            address - segment.vm_address >= segment.vm_size) {
            continue;
        }
        for (const auto& section : segment.sections) {
            if ((section.flags & (pure_instructions | some_instructions)) ==
                    0U ||
                section.size == 0U || address < section.address ||
                address - section.address >= section.size) {
                continue;
            }
            return true;
        }
    }
    return false;
}

bool instruction_symbol(
    const shade::MachOImage& image, const shade::MachSymbol& symbol)
{
    // n_sect is a one-based ordinal over every section in load-command order.
    // Segment execute permission is not sufficient: __TEXT commonly contains
    // __cstring, constants, and unwind metadata alongside __text.
    constexpr std::uint32_t pure_instructions = 0x80000000U;
    constexpr std::uint32_t some_instructions = 0x00000400U;
    if (symbol.section == 0U)
        return false;
    std::size_t ordinal = 1U;
    for (const auto& segment : image.segments()) {
        for (const auto& section : segment.sections) {
            if (ordinal++ != symbol.section)
                continue;
            if ((section.flags & (pure_instructions | some_instructions)) ==
                    0U ||
                section.size == 0U || symbol.value < section.address ||
                symbol.value - section.address >= section.size) {
                return false;
            }
            return executable_address(image, symbol.value);
        }
    }
    return false;
}

void collect_reliable_entry_points(
    const shade::MachOImage& image, std::vector<std::uint64_t>& entry_points)
{
    constexpr std::uint64_t thumb_descriptor_bit = std::uint64_t { 1 } << 32U;
    constexpr std::size_t maximum_entry_points = 65'536U;
    const auto add = [&](std::uint32_t address, bool thumb,
                         bool instruction_range = false) {
        if (address == 0 ||
            !(instruction_range ? executable_instruction_address(image, address)
                                : executable_address(image, address)) ||
            entry_points.size() >= maximum_entry_points) {
            return;
        }
        const auto descriptor = static_cast<std::uint64_t>(address) |
                                (thumb ? thumb_descriptor_bit : 0U);
        if (std::find(entry_points.begin(), entry_points.end(), descriptor) ==
            entry_points.end()) {
            entry_points.push_back(descriptor);
        }
    };
    if (image.entry_point())
        add(*image.entry_point(), false);
    for (const auto& symbol : image.symbols()) {
        // N_SECT definitions are the only symbol records with an image-local
        // address. Require the referenced section itself to carry Mach-O's
        // instruction attribute; an executable __TEXT segment also contains
        // data.
        if ((symbol.type & 0x0eU) == 0x0eU &&
            instruction_symbol(image, symbol)) {
            add(symbol.value, symbol.thumb_definition());
        }
    }
    for (const auto address : image.function_starts()) {
        // On 32-bit ARM, LC_FUNCTION_STARTS stores the Thumb state in bit zero
        // of the cumulative address. Normalize the address before checking the
        // instruction range and retain the mode in the descriptor; otherwise an
        // odd Thumb start becomes an invalid ARM entry one byte into the code.
        const auto thumb = (address & 1U) != 0U;
        add(address & ~1U, thumb, true);
    }
    for (const auto& stub : image.stubs())
        add(stub.address, false);
}

} // namespace

namespace shade {

const ExecutableCatalogEntry& ExecutableCatalog::register_image(
    const MachOImage& image)
{
    const auto normalized = normalize_path(image.path());
    remove_path(normalized);
    auto& entry = upsert(
        image.content_identity(), normalized, classify(image, normalized));
    entry.uuid = image.uuid();
    entry.cpu_type = image.cpu_type();
    entry.cpu_subtype = image.cpu_subtype();
    entry.file_type = image.file_type();
    entry.file_size = image.file_size();
    entry.fat_container = image.fat_container();
    entry.reliable_entry_points.clear();
    collect_reliable_entry_points(image, entry.reliable_entry_points);
    if (const auto generation = read_file_generation(normalized)) {
        const auto existing = std::find_if(entry.file_generations.begin(),
            entry.file_generations.end(),
            [&normalized](const ExecutableCatalogPathGeneration& record) {
                return record.path == normalized;
            });
        if (existing == entry.file_generations.end()) {
            entry.file_generations.push_back(
                ExecutableCatalogPathGeneration { normalized, *generation });
        } else {
            existing->generation = *generation;
        }
    }
    for (const auto& segment : image.segments()) {
        if ((segment.initial_protection & 4) == 0 || segment.file_size == 0) {
            continue;
        }
        const auto mapping = ExecutableMappingIdentity { segment.file_offset,
            segment.file_size, segment.vm_address, segment.vm_size };
        if (std::find(entry.mappings.begin(), entry.mappings.end(), mapping) ==
            entry.mappings.end()) {
            entry.mappings.push_back(mapping);
        }
    }
    for (const auto& dylib : image.dylibs()) {
        if (std::find(entry.dependencies.begin(), entry.dependencies.end(),
                dylib.path) == entry.dependencies.end()) {
            entry.dependencies.push_back(dylib.path);
        }
    }
    return entry;
}

const ExecutableCatalogEntry& ExecutableCatalog::register_path(
    const std::filesystem::path& path, ArmArchitectureVersion architecture,
    std::optional<ContentIdentity> known_identity)
{
    return register_image(MachOImage::parse(path, architecture,
        std::move(known_identity), ImmutableSnapshotKind::CatalogScan));
}

const ExecutableCatalogEntry& ExecutableCatalog::register_path_alias(
    const std::filesystem::path& alias, const std::filesystem::path& target,
    ArmArchitectureVersion architecture,
    std::optional<ContentIdentity> known_identity)
{
    const auto image = MachOImage::parse(target, architecture,
        std::move(known_identity), ImmutableSnapshotKind::CatalogScan);
    const auto target_path = normalize_path(target);
    const auto alias_path = normalize_path(alias);
    const auto& target_entry = register_image(image);
    if (alias_path == target_path)
        return target_entry;
    // Removing an existing alias can erase an earlier vector element and move
    // the target entry. Copy the identity before that mutation invalidates the
    // reference returned by register_image.
    const auto identity = target_entry.content_identity;
    remove_path(alias_path);
    auto& entry = upsert(identity, alias_path, classify(image, alias_path));
    if (const auto generation = read_file_generation(alias_path)) {
        const auto existing = std::find_if(entry.file_generations.begin(),
            entry.file_generations.end(),
            [&alias_path](const ExecutableCatalogPathGeneration& record) {
                return record.path == alias_path;
            });
        if (existing == entry.file_generations.end()) {
            entry.file_generations.push_back(
                ExecutableCatalogPathGeneration { alias_path, *generation });
        } else {
            existing->generation = *generation;
        }
    }
    return entry;
}

const ExecutableCatalogEntry& ExecutableCatalog::register_mapping(
    const std::filesystem::path& path, std::uint64_t file_offset,
    std::uint64_t byte_count)
{
    const auto identity_result = shared_file_identity(path);
    if (!identity_result.content_identity) {
        throw std::runtime_error { "cannot hash dynamic executable mapping: " +
                                   path.string() };
    }
    const auto normalized_path = normalize_path(path);
    remove_path(normalized_path);
    auto& entry = upsert(*identity_result.content_identity, normalized_path,
        ExecutableCatalogKind::DynamicMapping);
    if (entry.file_size == 0) {
        std::error_code size_error;
        const auto size = std::filesystem::file_size(path, size_error);
        if (!size_error)
            entry.file_size = size;
    }
    if (const auto generation = read_file_generation(normalized_path)) {
        const auto existing = std::find_if(entry.file_generations.begin(),
            entry.file_generations.end(),
            [&normalized_path](const ExecutableCatalogPathGeneration& record) {
                return record.path == normalized_path;
            });
        if (existing == entry.file_generations.end()) {
            entry.file_generations.push_back(ExecutableCatalogPathGeneration {
                normalized_path, *generation });
        } else {
            existing->generation = *generation;
        }
    }
    const auto mapping =
        ExecutableMappingIdentity { file_offset, byte_count, 0U, 0U };
    if (std::find(entry.mappings.begin(), entry.mappings.end(), mapping) ==
        entry.mappings.end()) {
        entry.mappings.push_back(mapping);
    }
    return entry;
}

std::size_t ExecutableCatalog::register_shared_cache(
    const DyldSharedCache& cache)
{
    std::size_t registered = 0;
    for (const auto& image : cache.images()) {
        auto& entry = upsert(shared_cache_image_identity(cache, image),
            std::filesystem::path { image.path },
            classify_shared_cache_image(image.path));
        entry.uuid = image.text_uuid;
        entry.file_type = 6U; // MH_DYLIB: shared-cache images are dylib code.
        for (const auto& range : image.executable_ranges) {
            const auto mapping = ExecutableMappingIdentity { range.file_offset,
                range.size, range.address, range.size };
            if (std::find(entry.mappings.begin(), entry.mappings.end(),
                    mapping) == entry.mappings.end()) {
                entry.mappings.push_back(mapping);
            }
            if (range.file_index < cache.files().size()) {
                const auto file_path = std::filesystem::path {
                    cache.files()[range.file_index].path
                };
                if (std::find(entry.aliases.begin(), entry.aliases.end(),
                        file_path) == entry.aliases.end()) {
                    entry.aliases.push_back(file_path);
                }
            }
        }
        ++registered;
    }
    return registered;
}

ExecutableCatalogScanSummary ExecutableCatalog::register_tree(
    const std::filesystem::path& root, ArmArchitectureVersion architecture)
{
    entries_.clear();
    identity_index_.clear();
    return scan_tree(root, architecture, nullptr);
}

ExecutableCatalogScanSummary ExecutableCatalog::refresh_tree(
    const std::filesystem::path& root, ArmArchitectureVersion architecture)
{
    ExecutableCatalog previous = std::move(*this);
    entries_.clear();
    identity_index_.clear();
    return scan_tree(root, architecture, &previous);
}

ExecutableCatalogScanSummary ExecutableCatalog::refresh_paths(
    const std::filesystem::path& root,
    const std::vector<std::filesystem::path>& paths,
    ArmArchitectureVersion architecture,
    const std::map<std::filesystem::path, ExecutableCatalogKnownIdentity>&
        known_identities)
{
    std::error_code root_error;
    const auto normalized_root = normalize_path(root);
    if (!std::filesystem::is_directory(normalized_root, root_error) ||
        root_error) {
        throw std::runtime_error { "catalog root is not a directory: " +
                                   normalized_root.string() };
    }

    const auto is_in_scope = [&normalized_root](
                                 const std::filesystem::path& path) {
        if (path == normalized_root)
            return true;
        const auto relative = path.lexically_relative(normalized_root);
        return !relative.empty() && relative != "." &&
               relative.begin() != relative.end() && *relative.begin() != "..";
    };
    const auto is_in_subtree = [](const std::filesystem::path& path,
                                   const std::filesystem::path& subtree) {
        if (path == subtree)
            return true;
        const auto relative = path.lexically_relative(subtree);
        return !relative.empty() && relative != "." &&
               relative.begin() != relative.end() && *relative.begin() != "..";
    };

    std::set<std::filesystem::path> requested_files;
    std::set<std::filesystem::path> requested_subtrees;
    const auto has_catalog_descendant =
        [this, &is_in_subtree](const std::filesystem::path& subtree) {
            for (const auto& entry : entries_) {
                for (const auto& alias : entry.aliases) {
                    if (alias != subtree && is_in_subtree(alias, subtree))
                        return true;
                }
            }
            return false;
        };
    for (const auto& path : paths) {
        const auto normalized = normalize_path(path);
        if (!is_in_scope(normalized))
            continue;
        std::error_code status_error;
        const auto status =
            std::filesystem::symlink_status(normalized, status_error);
        const bool current_directory =
            !status_error && std::filesystem::is_directory(status);
        const bool replaced_catalog_subtree =
            has_catalog_descendant(normalized);
        // A removed directory has no status to inspect.  Existing catalog
        // aliases are the authoritative shape of that old subtree, so retain
        // the directory scope even after the host path has disappeared.  This
        // also covers the source side of an atomic directory rename.  If an
        // installation replaced a directory with a regular file, retain the old
        // subtree scope as well as the new file request so stale descendants
        // are removed without losing the replacement image.
        if (current_directory || replaced_catalog_subtree) {
            requested_subtrees.insert(normalized);
            if (!current_directory && !status_error)
                requested_files.insert(normalized);
        } else {
            requested_files.insert(normalized);
        }
    }

    ExecutableCatalogScanSummary summary;
    std::set<std::filesystem::path> files = requested_files;
    for (const auto& subtree : requested_subtrees) {
        std::error_code iterator_error;
        std::filesystem::recursive_directory_iterator iterator { subtree,
            std::filesystem::directory_options::skip_permission_denied,
            iterator_error };
        const std::filesystem::recursive_directory_iterator end;
        while (iterator != end) {
            if (iterator_error) {
                ++summary.failed_files;
                iterator_error.clear();
                iterator.increment(iterator_error);
                continue;
            }
            std::error_code status_error;
            const auto status = iterator->symlink_status(status_error);
            if (!status_error && std::filesystem::is_regular_file(status)) {
                files.insert(normalize_path(iterator->path()));
            } else if (!status_error && std::filesystem::is_symlink(status)) {
                if (const auto target = resolve_catalog_symlink(
                        iterator->path(), normalized_root)) {
                    files.insert(normalize_path(iterator->path()));
                }
            } else if (status_error) {
                ++summary.failed_files;
            }
            iterator.increment(iterator_error);
        }
        if (iterator_error)
            ++summary.failed_files;
    }

    std::set<std::filesystem::path> old_paths;
    for (const auto& entry : entries_) {
        for (const auto& alias : entry.aliases) {
            if (requested_files.contains(alias) ||
                std::any_of(requested_subtrees.begin(),
                    requested_subtrees.end(),
                    [&alias, &is_in_subtree](const auto& subtree) {
                        return is_in_subtree(alias, subtree);
                    })) {
                old_paths.insert(alias);
            }
        }
    }
    for (const auto& old_path : old_paths) {
        if (!files.contains(old_path))
            remove_path(old_path);
    }

    for (const auto& path : files) {
        std::error_code status_error;
        const auto status = std::filesystem::symlink_status(path, status_error);
        const auto symlink_target =
            !status_error && std::filesystem::is_symlink(status)
                ? resolve_catalog_symlink(path, normalized_root)
                : std::nullopt;
        const auto target = symlink_target.value_or(path);
        if (status_error ||
            (!std::filesystem::is_regular_file(status) && !symlink_target)) {
            remove_path(path);
            if (status_error)
                ++summary.failed_files;
            continue;
        }
        ++summary.regular_files;
        const auto generation = read_file_generation(path);
        if (!generation) {
            remove_path(path);
            ++summary.failed_files;
            continue;
        }
        const auto* old_entry = find_path(path);
        bool unchanged = false;
        if (old_entry != nullptr) {
            unchanged = std::any_of(old_entry->file_generations.begin(),
                old_entry->file_generations.end(),
                [&path, &generation](
                    const ExecutableCatalogPathGeneration& record) {
                    return record.path == path &&
                           record.generation == *generation;
                });
        }
        if (unchanged)
            continue;

        remove_path(path);
        const auto prefix = read_file_prefix(target);
        if (!prefix) {
            ++summary.failed_files;
        } else if (has_dyld_cache_magic(*prefix)) {
            // Shared-cache generations remain outside this incremental path.
            // The ordinary firmware catalog command is still the explicit full
            // rebuild for those inputs; do not synchronously rescan the whole
            // root here.
        } else if (has_macho_magic(*prefix)) {
            try {
                std::optional<ContentIdentity> known_identity;
                if (const auto known = known_identities.find(path);
                    known != known_identities.end() &&
                    known->second.generation == *generation) {
                    known_identity = known->second.content_identity;
                }
                if (symlink_target) {
                    static_cast<void>(register_path_alias(
                        path, target, architecture, std::move(known_identity)));
                } else {
                    static_cast<void>(register_path(
                        path, architecture, std::move(known_identity)));
                }
                ++summary.mach_o_images;
            } catch (const std::exception&) {
                ++summary.failed_files;
            }
        }
    }
    reliable_entry_points_current_ = true;
    return summary;
}

ExecutableCatalogScanSummary ExecutableCatalog::scan_tree(
    const std::filesystem::path& root, ArmArchitectureVersion architecture,
    const ExecutableCatalog* previous)
{
    std::error_code error;
    if (!std::filesystem::is_directory(root, error) || error) {
        throw std::runtime_error { "catalog root is not a directory: " +
                                   root.string() };
    }

    ExecutableCatalogScanSummary summary;
    std::set<std::filesystem::path> cache_files;
    struct ScanCandidate {
        std::filesystem::path alias;
        std::filesystem::path target;
        bool symlink { };
    };
    std::vector<ScanCandidate> regular_files;
    const auto normalized_root = normalize_path(root);
    std::filesystem::recursive_directory_iterator iterator { root,
        std::filesystem::directory_options::skip_permission_denied, error };
    const std::filesystem::recursive_directory_iterator end;
    while (iterator != end) {
        if (error) {
            ++summary.failed_files;
            error.clear();
            iterator.increment(error);
            continue;
        }

        const auto path = normalize_path(iterator->path());
        std::error_code status_error;
        const auto status = iterator->symlink_status(status_error);
        if (status_error) {
            ++summary.failed_files;
        } else if (std::filesystem::is_regular_file(status)) {
            ++summary.regular_files;
            regular_files.push_back(ScanCandidate { path, path, false });
        } else if (std::filesystem::is_symlink(status)) {
            const auto target = resolve_catalog_symlink(path, normalized_root);
            if (target) {
                ++summary.regular_files;
                regular_files.push_back(ScanCandidate { path, *target, true });
            }
        }
        iterator.increment(error);
    }
    if (error)
        ++summary.failed_files;

    // Filesystem enumeration order is not part of the recursive-directory
    // iterator contract. Sort the candidates so a main shared cache (whose
    // subcache suffix is lexically appended to the main name) is discovered
    // before its subcaches and can claim the complete generation atomically.
    std::sort(regular_files.begin(), regular_files.end(),
        [](const ScanCandidate& left, const ScanCandidate& right) {
            return left.alias < right.alias;
        });
    for (const auto& candidate : regular_files) {
        const auto& alias = candidate.alias;
        const auto& path = candidate.target;
        if (cache_files.contains(path))
            continue;
        const auto normalized = alias;
        if (previous != nullptr && !candidate.symlink) {
            const auto* old_entry = previous->find_path(normalized);
            const auto current_generation = read_file_generation(normalized);
            const ExecutableCatalogPathGeneration* old_generation = nullptr;
            if (old_entry != nullptr) {
                const auto existing =
                    std::find_if(old_entry->file_generations.begin(),
                        old_entry->file_generations.end(),
                        [&normalized](
                            const ExecutableCatalogPathGeneration& record) {
                            return record.path == normalized;
                        });
                if (existing != old_entry->file_generations.end())
                    old_generation = &*existing;
            }
            if (old_entry != nullptr && current_generation &&
                old_generation != nullptr &&
                previous->reliable_entry_points_current_ &&
                !old_entry->kinds.empty() && old_entry->file_size != 0U &&
                old_entry->uuid &&
                !old_entry->kinds.contains(
                    ExecutableCatalogKind::DynamicMapping) &&
                std::all_of(old_entry->mappings.begin(),
                    old_entry->mappings.end(),
                    [](const ExecutableMappingIdentity& mapping) {
                        return mapping.guest_byte_count != 0U;
                    }) &&
                old_generation->generation == *current_generation) {
                auto& entry = upsert(old_entry->content_identity, normalized,
                    *old_entry->kinds.begin());
                entry.kinds.insert(
                    old_entry->kinds.begin(), old_entry->kinds.end());
                entry.uuid = old_entry->uuid;
                entry.cpu_type = old_entry->cpu_type;
                entry.cpu_subtype = old_entry->cpu_subtype;
                entry.file_type = old_entry->file_type;
                entry.file_size = old_entry->file_size;
                entry.fat_container = old_entry->fat_container;
                entry.dependencies = old_entry->dependencies;
                entry.mappings = old_entry->mappings;
                entry.reliable_entry_points = old_entry->reliable_entry_points;
                entry.file_generations.push_back(
                    ExecutableCatalogPathGeneration {
                        normalized, *current_generation });
                ++summary.mach_o_images;
                ++summary.reused_mach_o_images;
                continue;
            }
        }
        const auto prefix = read_file_prefix(path);
        if (!prefix) {
            ++summary.failed_files;
        } else if (has_dyld_cache_magic(*prefix)) {
            DyldSharedCacheOptions options;
            options.architecture = architecture == ArmArchitectureVersion::Armv7
                                       ? "armv7"
                                       : "armv6k";
            const auto cache = DyldSharedCache::parse(path, options);
            if (!cache) {
                ++summary.failed_files;
            } else {
                for (const auto& file : cache->files())
                    cache_files.insert(normalize_path(file.path));
                ++summary.dyld_shared_cache_generations;
                summary.dyld_shared_cache_images +=
                    register_shared_cache(*cache);
            }
        } else if (has_macho_magic(*prefix)) {
            try {
                if (candidate.symlink) {
                    static_cast<void>(
                        register_path_alias(alias, path, architecture));
                } else {
                    static_cast<void>(register_path(path, architecture));
                }
                ++summary.mach_o_images;
            } catch (const std::exception&) {
                ++summary.failed_files;
            }
        }
    }
    reliable_entry_points_current_ = true;
    return summary;
}

bool ExecutableCatalog::load(const std::filesystem::path& path) noexcept
{
    try {
        std::error_code size_error;
        const auto file_size = std::filesystem::file_size(path, size_error);
        if (size_error || file_size > maximum_manifest_file_size ||
            file_size < catalog_checksum_size) {
            return false;
        }
        std::ifstream input { path, std::ios::binary };
        if (!input)
            return false;
        std::vector<std::byte> bytes(static_cast<std::size_t>(file_size));
        input.read(reinterpret_cast<char*>(bytes.data()),
            static_cast<std::streamsize>(bytes.size()));
        if (input.gcount() != static_cast<std::streamsize>(bytes.size())) {
            return false;
        }
        const auto payload_size = bytes.size() - catalog_checksum_size;
        ContentIdentity expected_checksum;
        std::copy_n(bytes.begin() + static_cast<std::ptrdiff_t>(payload_size),
            expected_checksum.digest.size(), expected_checksum.digest.begin());
        const auto payload =
            std::span<const std::byte> { bytes.data(), payload_size };
        if (shade::sha256(payload) != expected_checksum)
            return false;
        std::string serialized { reinterpret_cast<const char*>(bytes.data()),
            payload_size };
        std::istringstream stream { std::move(serialized) };

        std::array<char, catalog_magic.size()> magic { };
        stream.read(magic.data(), static_cast<std::streamsize>(magic.size()));
        if (!stream || magic != catalog_magic)
            return false;
        const auto schema = read_u32(stream);
        const auto count = read_u32(stream);
        if (!schema ||
            (*schema != 4U && *schema != 5U && *schema != 6U &&
                *schema != catalog_schema_version) ||
            !count || *count > maximum_manifest_entries) {
            return false;
        }

        std::vector<ExecutableCatalogEntry> entries;
        entries.reserve(*count);
        std::unordered_map<ContentIdentity, std::size_t, ContentIdentityHash>
            identity_index;
        identity_index.reserve(*count);
        for (std::uint32_t index = 0; index < *count; ++index) {
            const auto entry = read_manifest_entry(stream, *schema);
            if (!entry ||
                !identity_index.emplace(entry->content_identity, entries.size())
                    .second) {
                return false;
            }
            entries.push_back(*entry);
        }
        if (stream.peek() != std::char_traits<char>::eof())
            return false;

        const auto reliable_entry_points_current =
            *schema == catalog_schema_version;
        if (!reliable_entry_points_current) {
            for (auto& entry : entries)
                entry.reliable_entry_points.clear();
        }
        entries_ = std::move(entries);
        identity_index_ = std::move(identity_index);
        reliable_entry_points_current_ = reliable_entry_points_current;
        ++mutation_revision_;
        return true;
    } catch (...) {
        return false;
    }
}

bool ExecutableCatalog::save(const std::filesystem::path& path) const noexcept
{
    std::filesystem::path temporary;
    try {
        if (path.empty() || entries_.size() > maximum_manifest_entries) {
            return false;
        }
        const auto parent = path.parent_path();
        if (!parent.empty())
            std::filesystem::create_directories(parent);
        temporary = path.string() + ".tmp";
        const auto fail = [&]() noexcept {
            std::error_code error;
            std::filesystem::remove(temporary, error);
            return false;
        };
        std::ofstream stream { temporary, std::ios::binary | std::ios::trunc };
        if (!stream)
            return fail();
        stream.write(catalog_magic.data(),
            static_cast<std::streamsize>(catalog_magic.size()));
        write_u32(stream, catalog_schema_version);
        write_u32(stream, static_cast<std::uint32_t>(entries_.size()));
        for (const auto& entry : entries_) {
            if (entry.aliases.size() > maximum_manifest_items ||
                entry.file_generations.size() > maximum_manifest_items ||
                entry.kinds.size() > maximum_manifest_items ||
                entry.dependencies.size() > maximum_manifest_items ||
                entry.mappings.size() > maximum_manifest_items ||
                entry.reliable_entry_points.size() > maximum_manifest_items) {
                return fail();
            }
            write_identity(stream, entry.content_identity);
            write_u32(stream, static_cast<std::uint32_t>(entry.aliases.size()));
            for (const auto& alias : entry.aliases) {
                const auto text = alias.generic_string();
                if (text.size() > maximum_manifest_string)
                    return fail();
                write_string(stream, text);
            }
            write_u32(stream,
                static_cast<std::uint32_t>(entry.file_generations.size()));
            for (const auto& record : entry.file_generations) {
                const auto text = record.path.generic_string();
                if (text.size() > maximum_manifest_string)
                    return fail();
                write_string(stream, text);
                write_u64(stream, record.generation.device);
                write_u64(stream, record.generation.inode);
                write_u64(stream, record.generation.file_size);
                write_u64(stream, static_cast<std::uint64_t>(
                                      record.generation.modified_seconds));
                write_u64(stream, static_cast<std::uint64_t>(
                                      record.generation.modified_nanoseconds));
                write_u64(stream, static_cast<std::uint64_t>(
                                      record.generation.changed_seconds));
                write_u64(stream, static_cast<std::uint64_t>(
                                      record.generation.changed_nanoseconds));
            }
            write_u32(stream, static_cast<std::uint32_t>(entry.kinds.size()));
            for (const auto kind : entry.kinds) {
                write_u8(stream, static_cast<std::uint8_t>(kind));
            }
            write_u8(stream, static_cast<std::uint8_t>(entry.uuid.has_value()));
            if (entry.uuid) {
                stream.write(reinterpret_cast<const char*>(entry.uuid->data()),
                    static_cast<std::streamsize>(entry.uuid->size()));
            }
            write_u32(stream, entry.cpu_type);
            write_u32(stream, entry.cpu_subtype);
            write_u32(stream, entry.file_type);
            write_u64(stream, entry.file_size);
            write_u8(stream, static_cast<std::uint8_t>(entry.fat_container));
            write_u32(
                stream, static_cast<std::uint32_t>(entry.dependencies.size()));
            for (const auto& dependency : entry.dependencies) {
                if (dependency.size() > maximum_manifest_string)
                    return fail();
                write_string(stream, dependency);
            }
            write_u32(
                stream, static_cast<std::uint32_t>(entry.mappings.size()));
            for (const auto& mapping : entry.mappings) {
                write_u64(stream, mapping.file_offset);
                write_u64(stream, mapping.byte_count);
                write_u64(stream, mapping.guest_address);
                write_u64(stream, mapping.guest_byte_count);
            }
            write_u32(stream,
                static_cast<std::uint32_t>(entry.reliable_entry_points.size()));
            for (const auto entry_point : entry.reliable_entry_points) {
                write_u64(stream, entry_point);
            }
        }
        stream.flush();
        if (!stream)
            return fail();
        stream.close();

        std::ifstream payload_stream { temporary, std::ios::binary };
        if (!payload_stream)
            return fail();
        const std::string payload { std::istreambuf_iterator<char> {
                                        payload_stream },
            std::istreambuf_iterator<char> { } };
        if (payload_stream.bad())
            return fail();
        const auto checksum = shade::sha256(std::span<const std::byte> {
            reinterpret_cast<const std::byte*>(payload.data()),
            payload.size() });
        std::ofstream checksum_stream { temporary,
            std::ios::binary | std::ios::app };
        if (!checksum_stream)
            return fail();
        checksum_stream.write(
            reinterpret_cast<const char*>(checksum.digest.data()),
            static_cast<std::streamsize>(checksum.digest.size()));
        checksum_stream.flush();
        if (!checksum_stream)
            return fail();
        checksum_stream.close();

        std::error_code error;
        std::filesystem::rename(temporary, path, error);
        if (error)
            return fail();
        return true;
    } catch (...) {
        if (!temporary.empty()) {
            std::error_code error;
            std::filesystem::remove(temporary, error);
        }
        return false;
    }
}

const ExecutableCatalogEntry* ExecutableCatalog::find(
    const ContentIdentity& identity) const
{
    const auto iterator = identity_index_.find(identity);
    return iterator == identity_index_.end() ? nullptr
                                             : &entries_[iterator->second];
}

const ExecutableCatalogEntry* ExecutableCatalog::find_path(
    const std::filesystem::path& path) const
{
    const auto normalized = normalize_path(path);
    const ExecutableCatalogEntry* fallback = nullptr;
    for (const auto& entry : entries_) {
        if (std::find(entry.aliases.begin(), entry.aliases.end(), normalized) ==
            entry.aliases.end()) {
            continue;
        }
        if (entry.file_size != 0U &&
            !entry.kinds.contains(ExecutableCatalogKind::DynamicMapping)) {
            return &entry;
        }
        fallback = &entry;
    }
    return fallback;
}

bool ExecutableCatalog::path_is_current(const std::filesystem::path& path) const
{
    const auto normalized = normalize_path(path);
    const auto* entry = find_path(normalized);
    const auto current = read_file_generation(normalized);
    if (entry == nullptr || !current)
        return false;
    return std::any_of(entry->file_generations.begin(),
        entry->file_generations.end(),
        [&normalized, &current](const ExecutableCatalogPathGeneration& record) {
            return record.path == normalized && record.generation == *current;
        });
}

std::vector<std::uint64_t> ExecutableCatalog::fixed_mapping_entry_points(
    const std::filesystem::path& path, std::uint32_t mapping_address,
    std::uint32_t mapping_size, std::uint64_t file_offset) const
{
    std::vector<std::uint64_t> result;
    if (mapping_size == 0U)
        return result;
    const auto* entry = find_path(path);
    if (entry == nullptr || !path_is_current(path))
        return result;

    const auto mapping =
        std::find_if(entry->mappings.begin(), entry->mappings.end(),
            [mapping_address, mapping_size, file_offset](
                const ExecutableMappingIdentity& candidate) {
                return candidate.file_offset == file_offset &&
                       candidate.guest_address == mapping_address &&
                       candidate.byte_count != 0U &&
                       candidate.byte_count <= mapping_size &&
                       candidate.guest_byte_count != 0U;
            });
    if (mapping == entry->mappings.end() ||
        mapping->guest_address >
            std::numeric_limits<std::uint64_t>::max() -
                std::min<std::uint64_t>(
                    mapping->guest_byte_count, mapping_size)) {
        return result;
    }
    const auto mapping_end =
        mapping->guest_address +
        std::min<std::uint64_t>(mapping->guest_byte_count, mapping_size);
    constexpr auto thumb_descriptor_bit = std::uint64_t { 1 } << 32U;
    constexpr auto descriptor_mask =
        thumb_descriptor_bit | std::numeric_limits<std::uint32_t>::max();
    result.reserve(std::min<std::size_t>(
        entry->reliable_entry_points.size(), std::size_t { 4096 }));
    for (const auto descriptor : entry->reliable_entry_points) {
        if ((descriptor & ~descriptor_mask) != 0U)
            continue;
        const auto address = static_cast<std::uint32_t>(descriptor);
        if (address >= mapping->guest_address && address < mapping_end) {
            result.push_back(descriptor);
        }
    }
    return result;
}

std::size_t ExecutableCatalog::reliable_entry_point_count() const noexcept
{
    std::size_t count = 0;
    for (const auto& entry : entries_) {
        if (entry.reliable_entry_points.size() <=
            std::numeric_limits<std::size_t>::max() - count) {
            count += entry.reliable_entry_points.size();
        } else {
            return std::numeric_limits<std::size_t>::max();
        }
    }
    return count;
}

std::vector<ContentIdentity> ExecutableCatalog::content_identities() const
{
    std::vector<ContentIdentity> identities;
    identities.reserve(entries_.size());
    for (const auto& entry : entries_) {
        identities.push_back(entry.content_identity);
    }
    return identities;
}

std::span<const ExecutableCatalogEntry>
ExecutableCatalog::entries() const noexcept
{
    return entries_;
}

std::filesystem::path ExecutableCatalog::normalize_path(
    const std::filesystem::path& path)
{
    std::error_code error;
    const auto absolute = std::filesystem::absolute(path, error);
    return (error ? path : absolute).lexically_normal();
}

ExecutableCatalogKind ExecutableCatalog::classify(
    const MachOImage& image, const std::filesystem::path& path)
{
    for (const auto& component : path) {
        const auto text = component.string();
        if (text.ends_with(".framework"))
            return ExecutableCatalogKind::Framework;
        if (text == "PlugIns" || text.ends_with(".plugin") ||
            text.ends_with(".appex")) {
            return ExecutableCatalogKind::PlugIn;
        }
    }
    if (image.file_type() == 6U)
        return ExecutableCatalogKind::Dylib;
    return ExecutableCatalogKind::MachO;
}

ExecutableCatalogEntry& ExecutableCatalog::upsert(ContentIdentity identity,
    const std::filesystem::path& path, ExecutableCatalogKind kind)
{
    ++mutation_revision_;
    const auto existing = identity_index_.find(identity);
    if (existing == identity_index_.end()) {
        const auto index = entries_.size();
        entries_.push_back(ExecutableCatalogEntry {
            .content_identity = identity,
            .aliases = { path },
            .file_generations = { },
            .kinds = { kind },
            .uuid = std::nullopt,
            .cpu_type = 0U,
            .cpu_subtype = 0U,
            .file_type = 0U,
            .file_size = 0U,
            .fat_container = false,
            .dependencies = { },
            .mappings = { },
            .reliable_entry_points = { },
        });
        identity_index_.emplace(std::move(identity), index);
        return entries_.back();
    }
    auto& entry = entries_[existing->second];
    if (std::find(entry.aliases.begin(), entry.aliases.end(), path) ==
        entry.aliases.end()) {
        entry.aliases.push_back(path);
    }
    entry.kinds.insert(kind);
    return entry;
}

void ExecutableCatalog::remove_path(const std::filesystem::path& path)
{
    ++mutation_revision_;
    for (auto entry = entries_.begin(); entry != entries_.end();) {
        entry->aliases.erase(
            std::remove(entry->aliases.begin(), entry->aliases.end(), path),
            entry->aliases.end());
        entry->file_generations.erase(
            std::remove_if(entry->file_generations.begin(),
                entry->file_generations.end(),
                [&path](const ExecutableCatalogPathGeneration& record) {
                    return record.path == path;
                }),
            entry->file_generations.end());
        if (entry->aliases.empty()) {
            entry = entries_.erase(entry);
        } else {
            ++entry;
        }
    }
    identity_index_.clear();
    identity_index_.reserve(entries_.size());
    for (std::size_t index = 0; index < entries_.size(); ++index) {
        identity_index_.emplace(entries_[index].content_identity, index);
    }
}

std::size_t ExecutableCatalog::resident_bytes_estimate() const noexcept
{
    std::size_t total = entries_.capacity() * sizeof(ExecutableCatalogEntry);
    const auto add = [&total](std::size_t bytes) {
        total = bytes > std::numeric_limits<std::size_t>::max() - total
                    ? std::numeric_limits<std::size_t>::max()
                    : total + bytes;
    };
    const auto add_path = [&add](const std::filesystem::path& path) {
        add(path.native().capacity() *
            sizeof(std::filesystem::path::value_type));
    };
    for (const auto& entry : entries_) {
        add(entry.aliases.capacity() * sizeof(std::filesystem::path));
        for (const auto& alias : entry.aliases)
            add_path(alias);
        add(entry.file_generations.capacity() *
            sizeof(ExecutableCatalogPathGeneration));
        for (const auto& generation : entry.file_generations)
            add_path(generation.path);
        add(entry.kinds.size() *
            (sizeof(ExecutableCatalogKind) + 3U * sizeof(void*)));
        add(entry.dependencies.capacity() * sizeof(std::string));
        for (const auto& dependency : entry.dependencies)
            add(dependency.capacity());
        add(entry.mappings.capacity() * sizeof(ExecutableMappingIdentity));
        add(entry.reliable_entry_points.capacity() * sizeof(std::uint64_t));
    }
    add(identity_index_.bucket_count() * sizeof(void*));
    add(identity_index_.size() *
        (sizeof(typename decltype(identity_index_)::value_type) +
            2U * sizeof(void*)));
    return total;
}

} // namespace shade
