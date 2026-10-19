// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Parse and expose guest dyld cache mappings and cached Mach-O
// images.

#include "foundation/dyld_shared_cache.hpp"
#include "foundation/macho.hpp"

#include <algorithm>
#include <array>
#include <atomic>
#include <cstring>
#include <exception>
#include <fstream>
#include <iterator>
#include <limits>
#include <map>
#include <mutex>
#include <string>
#include <string_view>
#include <type_traits>
#include <utility>

#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

#if defined(__APPLE__)
#define st_atim st_atimespec
#define st_mtim st_mtimespec
#define st_ctim st_ctimespec
#endif

namespace shade {

struct DyldSharedCache::ImageStore {
    std::mutex mutex;
    std::map<std::pair<std::uint32_t, std::uint8_t>,
        std::shared_ptr<const MachOImage>>
        images;
};

struct DyldSharedCache::FileViewStore {
    std::mutex mutex;
    // A null value records a failed open for this immutable generation too;
    // callers must not repeatedly retry a member after an atomic failure.
    std::map<std::uint32_t, std::shared_ptr<const ImmutableFileView>> views;
};

struct DyldSharedCache::GenerationArtifactView {
    static std::shared_ptr<const GenerationArtifactView> open(
        const std::filesystem::path& path);

    [[nodiscard]] std::span<const std::byte> bytes() const noexcept;
    [[nodiscard]] std::uint32_t file_count() const noexcept;
    [[nodiscard]] std::uint32_t image_count() const noexcept;
    [[nodiscard]] std::uint32_t index_count() const noexcept;
    [[nodiscard]] std::uint32_t platform() const noexcept;
    [[nodiscard]] std::uint8_t format_version() const noexcept;
    [[nodiscard]] std::uint64_t shared_region_start() const noexcept;
    [[nodiscard]] std::uint64_t shared_region_size() const noexcept;
    [[nodiscard]] std::uint64_t max_slide() const noexcept;
    [[nodiscard]] const ContentIdentity& generation_identity() const noexcept;
    [[nodiscard]] std::optional<DyldCacheFileView> file(
        std::size_t index) const;
    [[nodiscard]] std::optional<DyldCacheImageView> image(
        std::size_t index) const;
    [[nodiscard]] std::optional<DyldSharedCache::ImageRangeIndexEntry>
    index_entry(std::size_t index) const;

private:
    std::shared_ptr<const ImmutableArtifactView> backing_;
    std::uint32_t file_count_ { };
    std::uint32_t image_count_ { };
    std::uint32_t index_count_ { };
    std::uint32_t mapping_count_ { };
    std::uint32_t range_count_ { };
    std::uint64_t file_records_offset_ { };
    std::uint64_t image_records_offset_ { };
    std::uint64_t mapping_records_offset_ { };
    std::uint64_t range_records_offset_ { };
    std::uint64_t index_records_offset_ { };
    std::uint64_t string_offset_ { };
    std::uint64_t string_size_ { };
    std::uint32_t platform_ { };
    std::uint8_t format_version_ { };
    std::uint64_t shared_region_start_ { };
    std::uint64_t shared_region_size_ { };
    std::uint64_t max_slide_ { };
    ContentIdentity generation_identity_ { };

    [[nodiscard]] bool table_fits(std::uint64_t offset, std::uint64_t count,
        std::uint64_t element_size) const noexcept;
    [[nodiscard]] std::optional<std::string_view> string_at(
        std::uint32_t offset, std::uint32_t size) const noexcept;
    friend class DyldSharedCache;
};

namespace {

    // These offsets mirror the public dyld_cache_header layout. The parser uses
    // mappingOffset as the header-availability boundary, matching dyld's own
    // version gating instead of assuming every cache has the newest fields.
    constexpr std::size_t magic_offset = 0;
    constexpr std::size_t magic_size = 16;
    constexpr std::size_t mapping_offset_field = 16;
    constexpr std::size_t mapping_count_field = 20;
    constexpr std::size_t images_offset_old_field = 24;
    constexpr std::size_t images_count_old_field = 28;
    constexpr std::size_t uuid_field = 88;
    constexpr std::size_t images_text_offset_field = 136;
    constexpr std::size_t images_text_count_field = 144;
    constexpr std::size_t platform_field = 216;
    constexpr std::size_t format_version_field = 220;
    constexpr std::size_t shared_region_start_field = 224;
    constexpr std::size_t shared_region_size_field = 232;
    constexpr std::size_t max_slide_field = 240;
    constexpr std::size_t mapping_with_slide_offset_field = 312;
    constexpr std::size_t subcache_array_offset_field = 392;
    constexpr std::size_t subcache_array_count_field = 396;
    constexpr std::size_t images_offset_field = 448;
    constexpr std::size_t images_count_field = 452;
    constexpr std::size_t cache_subtype_field = 456;

    constexpr std::size_t mapping_info_size = 32;
    constexpr std::size_t mapping_with_slide_info_size = 56;
    constexpr std::size_t image_info_size = 32;
    constexpr std::size_t image_text_info_size = 32;
    constexpr std::size_t subcache_v1_size = 24;
    constexpr std::size_t subcache_size = 56;
    constexpr std::size_t maximum_mapping_count = 64;
    constexpr std::size_t maximum_image_count = 1'000'000;
    constexpr std::size_t maximum_subcache_count = 64;
    constexpr std::uint32_t mach_header_magic = 0xfeedfaceU;
    constexpr std::uint32_t lc_segment = 0x1U;
    constexpr std::uint32_t lc_uuid = 0x1bU;

    struct TextInfo {
        DyldCacheUuid uuid { };
        std::uint64_t load_address { };
        std::uint32_t segment_size { };
        std::string path;
    };

    struct ParsedFile {
        DyldCacheFile file;
        std::string magic;
        std::uint32_t mapping_offset { };
        std::vector<TextInfo> text_infos;
    };

    [[nodiscard]] std::optional<GuestFileGeneration> read_file_generation(
        const std::filesystem::path& path)
    {
        struct stat file_stat { };
        if (::stat(path.c_str(), &file_stat) != 0 ||
            !S_ISREG(file_stat.st_mode) || file_stat.st_size < 0) {
            return std::nullopt;
        }
        return GuestFileGeneration { static_cast<std::uint64_t>(
                                         file_stat.st_dev),
            static_cast<std::uint64_t>(file_stat.st_ino),
            static_cast<std::uint64_t>(file_stat.st_size),
            static_cast<std::int64_t>(file_stat.st_mtim.tv_sec),
            static_cast<std::int64_t>(file_stat.st_mtim.tv_nsec),
            static_cast<std::int64_t>(file_stat.st_ctim.tv_sec),
            static_cast<std::int64_t>(file_stat.st_ctim.tv_nsec) };
    }

    [[nodiscard]] bool add_overflows(std::uint64_t left, std::uint64_t right)
    {
        return right > std::numeric_limits<std::uint64_t>::max() - left;
    }

    [[nodiscard]] bool table_fits(std::uint64_t offset, std::uint64_t count,
        std::uint64_t element_size, std::uintmax_t file_size,
        std::uint64_t maximum_count)
    {
        if (element_size == 0U || count > maximum_count ||
            count > std::numeric_limits<std::uint64_t>::max() / element_size) {
            return false;
        }
        const auto byte_count = count * element_size;
        return offset <= file_size && byte_count <= file_size - offset;
    }

    [[nodiscard]] bool read_exact(std::ifstream& input, std::uint64_t offset,
        std::span<std::byte> destination)
    {
        if (offset > static_cast<std::uint64_t>(
                         std::numeric_limits<std::streamoff>::max()) ||
            destination.size() >
                static_cast<std::size_t>(
                    std::numeric_limits<std::streamsize>::max())) {
            return false;
        }
        input.clear();
        input.seekg(static_cast<std::streamoff>(offset));
        if (!input)
            return false;
        input.read(reinterpret_cast<char*>(destination.data()),
            static_cast<std::streamsize>(destination.size()));
        return input && input.gcount() ==
                            static_cast<std::streamsize>(destination.size());
    }

    [[nodiscard]] std::optional<std::uint32_t> read_u32(
        std::ifstream& input, std::uint64_t offset)
    {
        std::array<std::byte, sizeof(std::uint32_t)> bytes { };
        if (!read_exact(input, offset, bytes))
            return std::nullopt;
        return static_cast<std::uint32_t>(
                   std::to_integer<std::uint8_t>(bytes[0])) |
               (static_cast<std::uint32_t>(
                    std::to_integer<std::uint8_t>(bytes[1]))
                   << 8U) |
               (static_cast<std::uint32_t>(
                    std::to_integer<std::uint8_t>(bytes[2]))
                   << 16U) |
               (static_cast<std::uint32_t>(
                    std::to_integer<std::uint8_t>(bytes[3]))
                   << 24U);
    }

    [[nodiscard]] std::optional<std::uint64_t> read_u64(
        std::ifstream& input, std::uint64_t offset)
    {
        std::array<std::byte, sizeof(std::uint64_t)> bytes { };
        if (!read_exact(input, offset, bytes))
            return std::nullopt;
        std::uint64_t result = 0;
        for (std::size_t index = 0; index < bytes.size(); ++index) {
            result |= static_cast<std::uint64_t>(
                          std::to_integer<std::uint8_t>(bytes[index]))
                      << static_cast<unsigned>(index * 8U);
        }
        return result;
    }

    [[nodiscard]] std::optional<std::vector<std::byte>> read_blob(
        std::ifstream& input, std::uint64_t offset, std::size_t size)
    {
        std::vector<std::byte> bytes(size);
        if (!read_exact(input, offset, bytes))
            return std::nullopt;
        return bytes;
    }

    [[nodiscard]] std::optional<std::string> read_string(
        std::ifstream& input, std::uint64_t offset, std::uintmax_t file_size)
    {
        if (offset >= file_size)
            return std::nullopt;
        constexpr std::size_t chunk_size = 256;
        std::string result;
        for (std::uint64_t cursor = offset; cursor < file_size;) {
            const auto remaining = file_size - cursor;
            const auto count = static_cast<std::size_t>(
                std::min<std::uint64_t>(remaining, chunk_size));
            const auto chunk = read_blob(input, cursor, count);
            if (!chunk)
                return std::nullopt;
            for (const auto byte : *chunk) {
                if (byte == std::byte { })
                    return result;
                result.push_back(
                    static_cast<char>(std::to_integer<unsigned char>(byte)));
            }
            if (result.size() > 4096U)
                return std::nullopt;
            cursor += count;
        }
        return std::nullopt;
    }

    [[nodiscard]] bool valid_magic(std::string_view magic)
    {
        return magic.size() == magic_size && magic.starts_with("dyld_v1");
    }

    [[nodiscard]] bool field_available(std::uint32_t mapping_offset,
        std::size_t field_offset, std::size_t field_size)
    {
        return mapping_offset > field_offset &&
               mapping_offset - field_offset >= field_size;
    }

    [[nodiscard]] std::optional<DyldCacheUuid> read_uuid(
        std::ifstream& input, std::uint64_t offset)
    {
        DyldCacheUuid uuid { };
        if (!read_exact(input, offset, uuid))
            return std::nullopt;
        return uuid;
    }

    [[nodiscard]] std::optional<ParsedFile> parse_file(
        const std::filesystem::path& path, std::uint32_t file_index,
        std::uint64_t cache_vm_offset, std::string file_suffix,
        bool parse_images)
    {
        std::error_code error;
        const auto file_size = std::filesystem::file_size(path, error);
        if (error || file_size < magic_size)
            return std::nullopt;
        const auto file_generation = read_file_generation(path);
        const auto content_identity =
            shared_file_identity(path).content_identity;
        if (!file_generation || !content_identity)
            return std::nullopt;

        std::ifstream input { path, std::ios::binary };
        if (!input)
            return std::nullopt;
        const auto magic_bytes = read_blob(input, magic_offset, magic_size);
        if (!magic_bytes)
            return std::nullopt;
        const std::string magic { reinterpret_cast<const char*>(
                                      magic_bytes->data()),
            magic_bytes->size() };
        if (!valid_magic(magic))
            return std::nullopt;

        const auto mapping_offset = read_u32(input, mapping_offset_field);
        const auto mapping_count = read_u32(input, mapping_count_field);
        if (!mapping_offset || !mapping_count || *mapping_offset > 1024U ||
            *mapping_count == 0U || *mapping_count > maximum_mapping_count) {
            return std::nullopt;
        }
        const bool has_mapping_with_slide = field_available(*mapping_offset,
            mapping_with_slide_offset_field, sizeof(std::uint32_t));
        const auto mapping_size = has_mapping_with_slide
                                      ? mapping_with_slide_info_size
                                      : mapping_info_size;
        const auto mapping_table_offset =
            has_mapping_with_slide
                ? read_u32(input, mapping_with_slide_offset_field)
                : std::optional<std::uint32_t> { *mapping_offset };
        if (!mapping_table_offset || *mapping_table_offset == 0U ||
            !table_fits(*mapping_table_offset, *mapping_count, mapping_size,
                file_size, maximum_mapping_count)) {
            return std::nullopt;
        }

        ParsedFile parsed;
        parsed.file.path = path;
        parsed.file.file_size = file_size;
        parsed.file.file_generation = *file_generation;
        parsed.file.content_identity = *content_identity;
        parsed.file.cache_vm_offset = cache_vm_offset;
        parsed.file.file_suffix = std::move(file_suffix);
        parsed.magic = magic;
        parsed.mapping_offset = *mapping_offset;
        if (field_available(*mapping_offset, uuid_field, 16U)) {
            const auto uuid = read_uuid(input, uuid_field);
            if (!uuid)
                return std::nullopt;
            parsed.file.uuid = *uuid;
        }

        parsed.file.mappings.reserve(*mapping_count);
        for (std::uint32_t index = 0; index < *mapping_count; ++index) {
            const auto offset =
                static_cast<std::uint64_t>(*mapping_table_offset) +
                static_cast<std::uint64_t>(index) * mapping_size;
            const auto address = read_u64(input, offset);
            const auto size = read_u64(input, offset + 8U);
            const auto file_offset = read_u64(input, offset + 16U);
            if (!address || !size || !file_offset || *size == 0U ||
                add_overflows(*address, *size) ||
                add_overflows(*file_offset, *size) ||
                *file_offset + *size > file_size) {
                return std::nullopt;
            }
            const auto max_protection =
                read_u32(input, offset + (has_mapping_with_slide ? 48U : 24U));
            const auto initial_protection =
                read_u32(input, offset + (has_mapping_with_slide ? 52U : 28U));
            if (!max_protection || !initial_protection)
                return std::nullopt;

            DyldCacheMapping mapping;
            mapping.address = *address;
            mapping.size = *size;
            mapping.file_offset = *file_offset;
            mapping.file_index = file_index;
            mapping.maximum_protection = *max_protection;
            mapping.initial_protection = *initial_protection;
            if (has_mapping_with_slide) {
                const auto slide_offset = read_u64(input, offset + 24U);
                const auto slide_size = read_u64(input, offset + 32U);
                const auto flags = read_u64(input, offset + 40U);
                if (!slide_offset || !slide_size || !flags ||
                    (*slide_size != 0U &&
                        (add_overflows(*slide_offset, *slide_size) ||
                            *slide_offset + *slide_size > file_size))) {
                    return std::nullopt;
                }
                mapping.slide_info_offset = *slide_offset;
                mapping.slide_info_size = *slide_size;
                mapping.flags = *flags;
                if (*slide_size >= sizeof(std::uint32_t)) {
                    const auto version = read_u32(input, *slide_offset);
                    if (!version)
                        return std::nullopt;
                    mapping.slide_info_version = *version;
                }
            }

            for (const auto& previous : parsed.file.mappings) {
                const auto overlaps =
                    mapping.address < previous.address + previous.size &&
                    previous.address < mapping.address + mapping.size;
                if (overlaps)
                    return std::nullopt;
            }
            parsed.file.mappings.push_back(std::move(mapping));
        }

        if (!parse_images)
            return parsed;
        if (field_available(*mapping_offset, images_text_count_field,
                sizeof(std::uint64_t))) {
            const auto text_offset = read_u64(input, images_text_offset_field);
            const auto text_count = read_u64(input, images_text_count_field);
            if (!text_offset || !text_count ||
                !table_fits(*text_offset, *text_count, image_text_info_size,
                    file_size, maximum_image_count)) {
                return std::nullopt;
            }
            parsed.text_infos.reserve(static_cast<std::size_t>(*text_count));
            for (std::uint64_t index = 0; index < *text_count; ++index) {
                const auto offset = *text_offset + index * image_text_info_size;
                const auto uuid = read_uuid(input, offset);
                const auto load_address = read_u64(input, offset + 16U);
                const auto segment_size = read_u32(input, offset + 24U);
                const auto path_offset = read_u32(input, offset + 28U);
                if (!uuid || !load_address || !segment_size || !path_offset) {
                    return std::nullopt;
                }
                const auto text_path =
                    read_string(input, *path_offset, file_size);
                if (!text_path)
                    return std::nullopt;
                parsed.text_infos.push_back(TextInfo {
                    *uuid, *load_address, *segment_size, *text_path });
            }
        }
        return parsed;
    }

    struct CacheFileRange {
        std::uint32_t file_index { };
        std::uint64_t file_offset { };
    };

    [[nodiscard]] std::optional<CacheFileRange> cache_file_for_vm(
        std::span<const DyldCacheFile> files, std::uint64_t address,
        std::uint64_t size = 1U)
    {
        for (std::size_t index = 0; index < files.size(); ++index) {
            for (const auto& mapping : files[index].mappings) {
                if (address < mapping.address ||
                    address - mapping.address > mapping.size ||
                    size > mapping.size - (address - mapping.address)) {
                    continue;
                }
                return CacheFileRange { static_cast<std::uint32_t>(index),
                    mapping.file_offset + (address - mapping.address) };
            }
        }
        return std::nullopt;
    }

    [[nodiscard]] std::optional<std::uint32_t> cache_file_index_for_file_range(
        std::span<const DyldCacheFile> files, std::uint64_t file_offset,
        std::uint64_t size)
    {
        for (std::size_t index = 0; index < files.size(); ++index) {
            for (const auto& mapping : files[index].mappings) {
                if (file_offset < mapping.file_offset ||
                    file_offset - mapping.file_offset > mapping.size ||
                    size > mapping.size - (file_offset - mapping.file_offset)) {
                    continue;
                }
                return static_cast<std::uint32_t>(index);
            }
        }
        return std::nullopt;
    }

    [[nodiscard]] std::uint32_t read_span_u32(
        std::span<const std::byte> bytes, std::size_t offset)
    {
        if (offset > bytes.size() ||
            bytes.size() - offset < sizeof(std::uint32_t))
            return 0U;
        return static_cast<std::uint32_t>(
                   std::to_integer<std::uint8_t>(bytes[offset])) |
               (static_cast<std::uint32_t>(
                    std::to_integer<std::uint8_t>(bytes[offset + 1U]))
                   << 8U) |
               (static_cast<std::uint32_t>(
                    std::to_integer<std::uint8_t>(bytes[offset + 2U]))
                   << 16U) |
               (static_cast<std::uint32_t>(
                    std::to_integer<std::uint8_t>(bytes[offset + 3U]))
                   << 24U);
    }

    [[nodiscard]] std::optional<std::string> read_span_fixed_string(
        std::span<const std::byte> bytes, std::size_t offset, std::size_t size)
    {
        if (offset > bytes.size() || size > bytes.size() - offset)
            return std::nullopt;
        const auto end =
            std::find(bytes.begin() + static_cast<std::ptrdiff_t>(offset),
                bytes.begin() + static_cast<std::ptrdiff_t>(offset + size),
                std::byte { });
        return std::string { reinterpret_cast<const char*>(
                                 bytes.data() + offset),
            static_cast<std::size_t>(
                end - (bytes.begin() + static_cast<std::ptrdiff_t>(offset))) };
    }

    // Old shared caches predate the imagesText table. Their image records still
    // provide the load address, so recover the image's Mach-O segments from the
    // cache itself. This keeps HLE, catalog and shared-region mapping on one
    // metadata path without identifying a particular firmware build.
    bool populate_legacy_image_ranges(
        DyldCacheImage& image, std::span<const DyldCacheFile> files)
    {
        if (!image.executable_ranges.empty())
            return true;
        const auto header_source =
            cache_file_for_vm(files, image.unslid_load_address);
        if (!header_source || header_source->file_index >= files.size())
            return false;
        const auto& header_file = files[header_source->file_index];
        std::ifstream input { header_file.path, std::ios::binary };
        if (!input)
            return false;
        const auto magic = read_u32(input, header_source->file_offset);
        const auto command_count =
            read_u32(input, header_source->file_offset + 16U);
        const auto command_bytes =
            read_u32(input, header_source->file_offset + 20U);
        if (!magic || !command_count || !command_bytes ||
            *magic != mach_header_magic ||
            *command_bytes > header_file.file_size ||
            header_source->file_offset > header_file.file_size - 28U ||
            *command_bytes >
                header_file.file_size - header_source->file_offset - 28U) {
            return false;
        }
        const auto command_blob =
            read_blob(input, header_source->file_offset + 28U, *command_bytes);
        if (!command_blob)
            return false;
        const std::span<const std::byte> commands { *command_blob };
        std::size_t cursor = 0;
        std::optional<DyldCacheRange> text_range;
        for (std::uint32_t index = 0; index < *command_count; ++index) {
            if (cursor > commands.size() || commands.size() - cursor < 8U)
                return false;
            const auto command = read_span_u32(commands, cursor);
            const auto size = read_span_u32(commands, cursor + 4U);
            if (size < 8U || size > commands.size() - cursor)
                return false;
            if (command == lc_segment && size >= 56U) {
                const auto name =
                    read_span_fixed_string(commands, cursor + 8U, 16U);
                if (!name)
                    return false;
                const auto address = read_span_u32(commands, cursor + 24U);
                const auto vm_size = read_span_u32(commands, cursor + 28U);
                const auto file_offset = read_span_u32(commands, cursor + 32U);
                const auto file_size = read_span_u32(commands, cursor + 36U);
                const auto maximum_protection =
                    read_span_u32(commands, cursor + 40U);
                const auto initial_protection =
                    read_span_u32(commands, cursor + 44U);
                if (file_size != 0U && (initial_protection & 4U) != 0U) {
                    // In the legacy cache format __TEXT's fileoff is relative
                    // to the image header, while the later segments use
                    // absolute cache offsets. Keep this rule tied to the Mach-O
                    // segment contract rather than to a firmware/build
                    // identifier.
                    const bool image_relative = *name == "__TEXT";
                    if (image_relative &&
                        add_overflows(
                            header_source->file_offset, file_offset)) {
                        return false;
                    }
                    const auto actual_file_offset =
                        image_relative
                            ? header_source->file_offset + file_offset
                            : file_offset;
                    const auto source = cache_file_index_for_file_range(
                        files, actual_file_offset, file_size);
                    if (source) {
                        const auto range = DyldCacheRange { address, file_size,
                            actual_file_offset, *source, initial_protection,
                            maximum_protection };
                        image.executable_ranges.push_back(range);
                        if (*name == "__TEXT")
                            text_range = range;
                    }
                }
                if (*name == "__TEXT")
                    image.text_segment_size = vm_size;
            } else if (command == lc_uuid && size >= 24U) {
                DyldCacheUuid uuid { };
                std::copy_n(
                    commands.begin() + static_cast<std::ptrdiff_t>(cursor + 8U),
                    uuid.size(), uuid.begin());
                image.text_uuid = uuid;
            }
            cursor += size;
        }
        if (cursor != commands.size())
            return false;
        if (text_range) {
            if (text_range->file_index >= files.size())
                return false;
            if (const auto identity =
                    sha256_file(files[text_range->file_index].path,
                        text_range->file_offset, text_range->size)) {
                image.text_identity = *identity;
            }
        }
        return !image.executable_ranges.empty();
    }

    [[nodiscard]] std::filesystem::path discover_subcache(
        const std::filesystem::path& main_path, std::string_view suffix,
        std::size_t index)
    {
        if (!suffix.empty()) {
            return main_path.parent_path() /
                   (main_path.filename().string() + std::string { suffix });
        }
        const auto number = index + 1U;
        std::string fallback = main_path.filename().string() + ".";
        fallback.push_back(static_cast<char>('0' + (number / 10U) % 10U));
        fallback.push_back(static_cast<char>('0' + number % 10U));
        return main_path.parent_path() / fallback;
    }

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

    void append_identity(
        std::vector<std::byte>& bytes, const ContentIdentity& identity)
    {
        bytes.insert(
            bytes.end(), identity.digest.begin(), identity.digest.end());
    }

    void append_uuid(std::vector<std::byte>& bytes, const DyldCacheUuid& uuid)
    {
        bytes.insert(bytes.end(), uuid.begin(), uuid.end());
    }

    void append_generation(
        std::vector<std::byte>& bytes, const GuestFileGeneration& generation)
    {
        append_u64(bytes, generation.device);
        append_u64(bytes, generation.inode);
        append_u64(bytes, generation.file_size);
        append_u64(
            bytes, static_cast<std::uint64_t>(generation.modified_seconds));
        append_u64(
            bytes, static_cast<std::uint64_t>(generation.modified_nanoseconds));
        append_u64(
            bytes, static_cast<std::uint64_t>(generation.changed_seconds));
        append_u64(
            bytes, static_cast<std::uint64_t>(generation.changed_nanoseconds));
    }

    void append_u8(std::vector<std::byte>& bytes, std::uint8_t value)
    {
        bytes.push_back(static_cast<std::byte>(value));
    }

    void append_presence(std::vector<std::byte>& bytes, bool present)
    {
        append_u8(bytes, present ? 1U : 0U);
    }

    [[nodiscard]] std::string normalize_cache_path(
        const std::filesystem::path& path);

    [[nodiscard]] std::string generation_artifact_name(
        const std::filesystem::path& path,
        const DyldSharedCacheOptions& options,
        const GuestFileGeneration& main_generation,
        const ContentIdentity& main_identity)
    {
        std::vector<std::byte> key;
        const auto append_key_string = [&key](std::string_view value) {
            append_u32(key, static_cast<std::uint32_t>(value.size()));
            key.insert(key.end(),
                reinterpret_cast<const std::byte*>(value.data()),
                reinterpret_cast<const std::byte*>(
                    value.data() + value.size()));
        };
        append_key_string("shade-dyld-generation-v1");
        append_u32(key, DyldSharedCache::parser_schema_version);
        append_u32(key, DyldSharedCache::hle_profile_schema_version);
        append_key_string(normalize_cache_path(path));
        append_key_string(options.architecture);
        for (const auto& subcache : options.subcache_paths)
            append_key_string(normalize_cache_path(subcache));
        append_identity(key, main_identity);
        append_generation(key, main_generation);
        return "dyld-generation-" + sha256(key).hex() + ".artifact";
    }

    [[nodiscard]] std::string normalize_cache_path(
        const std::filesystem::path& path)
    {
        std::error_code error;
        const auto absolute = std::filesystem::absolute(path, error);
        return (error ? path : absolute).lexically_normal().generic_string();
    }

    struct GenerationCacheEntry {
        std::weak_ptr<const DyldSharedCache> generation;
        struct FileStamp {
            std::filesystem::path path;
            std::uintmax_t file_size { };
            std::optional<GuestFileGeneration> file_generation;
            ContentIdentity content_identity;
        };
        std::vector<FileStamp> files;
    };

    std::mutex generation_cache_mutex;
    std::map<std::string, GenerationCacheEntry, std::less<>> generation_cache;
    std::uint64_t generation_builds { };
    std::uint64_t generation_hits { };
    std::uint64_t generation_artifact_builds { };
    std::uint64_t generation_artifact_hits { };
    std::uint64_t file_view_builds { };
    std::uint64_t file_view_hits { };
    std::uint64_t image_builds { };
    std::uint64_t image_hits { };

    [[nodiscard]] std::string generation_cache_key(
        const std::filesystem::path& path,
        const DyldSharedCacheOptions& options)
    {
        std::string key =
            std::to_string(DyldSharedCache::parser_schema_version);
        key.push_back('\n');
        key += std::to_string(DyldSharedCache::hle_profile_schema_version);
        key.push_back('\n');
        key += normalize_cache_path(path);
        key.push_back('\n');
        key += options.architecture;
        for (const auto& subcache : options.subcache_paths) {
            key.push_back('\n');
            key += normalize_cache_path(subcache);
        }
        return key;
    }

    [[nodiscard]] bool generation_files_are_current(
        const GenerationCacheEntry& entry)
    {
        for (const auto& file : entry.files) {
            const auto generation = read_file_generation(file.path);
            if (!generation || !file.file_generation ||
                *generation != *file.file_generation) {
                return false;
            }
            const auto identity =
                shared_file_identity(file.path).content_identity;
            if (!identity || *identity != file.content_identity ||
                generation->file_size != file.file_size) {
                return false;
            }
        }
        return true;
    }

    [[nodiscard]] std::shared_ptr<const ImmutableFileView>
    read_immutable_file_view(const DyldCacheFile& file)
    {
        if (!file.file_generation ||
            file.file_size > std::numeric_limits<std::size_t>::max()) {
            return { };
        }
        return ImmutableFileView::open(file.path, *file.file_generation,
            file.content_identity, static_cast<std::uint64_t>(file.file_size));
    }

    constexpr std::string_view dyld_generation_magic { "SHADE-DYLD-GEN" };
    constexpr std::uint32_t dyld_generation_artifact_version = 2U;
    constexpr std::size_t dyld_generation_header_size = 155U;
    constexpr std::size_t dyld_file_record_size = 145U;
    constexpr std::size_t dyld_image_record_size = 86U;

    constexpr std::size_t dyld_header_version_offset = 14U;
    constexpr std::size_t dyld_header_file_count_offset = 18U;
    constexpr std::size_t dyld_header_image_count_offset = 22U;
    constexpr std::size_t dyld_header_index_count_offset = 26U;
    constexpr std::size_t dyld_header_mapping_count_offset = 30U;
    constexpr std::size_t dyld_header_range_count_offset = 34U;
    constexpr std::size_t dyld_header_file_records_offset = 38U;
    constexpr std::size_t dyld_header_image_records_offset = 46U;
    constexpr std::size_t dyld_header_mapping_records_offset = 54U;
    constexpr std::size_t dyld_header_range_records_offset = 62U;
    constexpr std::size_t dyld_header_index_records_offset = 70U;
    constexpr std::size_t dyld_header_string_offset = 78U;
    constexpr std::size_t dyld_header_string_size_offset = 86U;
    constexpr std::size_t dyld_header_platform_offset = 94U;
    constexpr std::size_t dyld_header_format_offset = 98U;
    constexpr std::size_t dyld_header_shared_start_offset = 99U;
    constexpr std::size_t dyld_header_shared_size_offset = 107U;
    constexpr std::size_t dyld_header_max_slide_offset = 115U;
    constexpr std::size_t dyld_header_generation_identity_offset = 123U;

    static_assert(std::is_trivially_copyable_v<DyldCacheMapping>);
    static_assert(std::is_trivially_copyable_v<DyldCacheRange>);

    [[nodiscard]] std::optional<std::uint32_t> read_artifact_u32(
        std::span<const std::byte> bytes, std::uint64_t offset) noexcept
    {
        if (offset > bytes.size() ||
            sizeof(std::uint32_t) > bytes.size() - offset)
            return std::nullopt;
        std::uint32_t value = 0;
        for (std::size_t index = 0; index < sizeof(value); ++index) {
            value |= static_cast<std::uint32_t>(
                         std::to_integer<std::uint8_t>(bytes[offset + index]))
                     << static_cast<unsigned>(index * 8U);
        }
        return value;
    }

    [[nodiscard]] std::optional<std::uint64_t> read_artifact_u64(
        std::span<const std::byte> bytes, std::uint64_t offset) noexcept
    {
        if (offset > bytes.size() ||
            sizeof(std::uint64_t) > bytes.size() - offset)
            return std::nullopt;
        std::uint64_t value = 0;
        for (std::size_t index = 0; index < sizeof(value); ++index) {
            value |= static_cast<std::uint64_t>(
                         std::to_integer<std::uint8_t>(bytes[offset + index]))
                     << static_cast<unsigned>(index * 8U);
        }
        return value;
    }

    [[nodiscard]] bool artifact_table_fits(std::span<const std::byte> bytes,
        std::uint64_t offset, std::uint64_t count,
        std::uint64_t element_size) noexcept
    {
        return element_size != 0U && count <= (bytes.size() / element_size) &&
               offset <= bytes.size() &&
               count * element_size <= bytes.size() - offset;
    }

    template <typename T>
    [[nodiscard]] const T* artifact_native_table(
        std::span<const std::byte> bytes, std::uint64_t offset,
        std::uint64_t count) noexcept
    {
        if (offset % alignof(T) != 0U ||
            !artifact_table_fits(bytes, offset, count, sizeof(T))) {
            return nullptr;
        }
        return reinterpret_cast<const T*>(bytes.data() + offset);
    }

    void write_artifact_u32(
        std::vector<std::byte>& bytes, std::size_t offset, std::uint32_t value)
    {
        for (std::size_t index = 0; index < sizeof(value); ++index)
            bytes[offset + index] =
                static_cast<std::byte>(value >> (index * 8U));
    }

    void write_artifact_u64(
        std::vector<std::byte>& bytes, std::size_t offset, std::uint64_t value)
    {
        for (std::size_t index = 0; index < sizeof(value); ++index)
            bytes[offset + index] =
                static_cast<std::byte>(value >> (index * 8U));
    }

    [[nodiscard]] std::size_t align_artifact_offset(
        std::size_t offset, std::size_t alignment)
    {
        const auto remainder = offset % alignment;
        return remainder == 0U ? offset : offset + alignment - remainder;
    }

    template <typename T>
    [[nodiscard]] std::uint64_t append_artifact_native_table(
        std::vector<std::byte>& bytes, std::span<const T> values)
    {
        const auto offset = align_artifact_offset(bytes.size(), alignof(T));
        bytes.resize(offset);
        const auto byte_count = values.size() * sizeof(T);
        const auto old_size = bytes.size();
        bytes.resize(old_size + byte_count);
        if (byte_count != 0U)
            std::memcpy(bytes.data() + old_size, values.data(), byte_count);
        return offset;
    }

} // namespace

std::shared_ptr<const DyldSharedCache::GenerationArtifactView>
DyldSharedCache::GenerationArtifactView::open(const std::filesystem::path& path)
{
    const auto backing = ImmutableArtifactView::open(path);
    if (!backing)
        return { };
    const auto bytes = backing->bytes();
    if (bytes.size() < dyld_generation_header_size ||
        std::string_view { reinterpret_cast<const char*>(bytes.data()),
            dyld_generation_magic.size() } != dyld_generation_magic ||
        !read_artifact_u32(bytes, dyld_header_version_offset) ||
        *read_artifact_u32(bytes, dyld_header_version_offset) !=
            dyld_generation_artifact_version) {
        return { };
    }

    auto result = std::shared_ptr<GenerationArtifactView> {
        new GenerationArtifactView { }
    };
    result->backing_ = backing;
    const auto read_u32_field =
        [&](std::size_t offset) -> std::optional<std::uint32_t> {
        return read_artifact_u32(bytes, offset);
    };
    const auto read_u64_field =
        [&](std::size_t offset) -> std::optional<std::uint64_t> {
        return read_artifact_u64(bytes, offset);
    };
    const auto file_count = read_u32_field(dyld_header_file_count_offset);
    const auto image_count = read_u32_field(dyld_header_image_count_offset);
    const auto index_count = read_u32_field(dyld_header_index_count_offset);
    const auto mapping_count = read_u32_field(dyld_header_mapping_count_offset);
    const auto range_count = read_u32_field(dyld_header_range_count_offset);
    const auto file_records_offset =
        read_u64_field(dyld_header_file_records_offset);
    const auto image_records_offset =
        read_u64_field(dyld_header_image_records_offset);
    const auto mapping_records_offset =
        read_u64_field(dyld_header_mapping_records_offset);
    const auto range_records_offset =
        read_u64_field(dyld_header_range_records_offset);
    const auto index_records_offset =
        read_u64_field(dyld_header_index_records_offset);
    const auto string_offset = read_u64_field(dyld_header_string_offset);
    const auto string_size = read_u64_field(dyld_header_string_size_offset);
    const auto platform = read_u32_field(dyld_header_platform_offset);
    if (!file_count || !image_count || !index_count || !mapping_count ||
        !range_count || !file_records_offset || !image_records_offset ||
        !mapping_records_offset || !range_records_offset ||
        !index_records_offset || !string_offset || !string_size || !platform ||
        *file_count == 0U || *file_count > maximum_subcache_count + 1U ||
        *image_count > maximum_image_count ||
        *mapping_count >
            maximum_mapping_count * (maximum_subcache_count + 1U) ||
        *range_count > maximum_image_count * maximum_mapping_count * 16U ||
        !artifact_table_fits(
            bytes, *file_records_offset, *file_count, dyld_file_record_size) ||
        !artifact_table_fits(bytes, *image_records_offset, *image_count,
            dyld_image_record_size) ||
        !artifact_table_fits(bytes, *mapping_records_offset, *mapping_count,
            sizeof(DyldCacheMapping)) ||
        !artifact_table_fits(bytes, *range_records_offset, *range_count,
            sizeof(DyldCacheRange)) ||
        !artifact_table_fits(bytes, *index_records_offset, *index_count,
            sizeof(DyldSharedCache::ImageRangeIndexEntry)) ||
        !artifact_table_fits(bytes, *string_offset, *string_size, 1U)) {
        return { };
    }

    const auto format =
        std::to_integer<std::uint8_t>(bytes[dyld_header_format_offset]);
    const auto shared_region_start =
        read_u64_field(dyld_header_shared_start_offset);
    const auto shared_region_size =
        read_u64_field(dyld_header_shared_size_offset);
    const auto max_slide = read_u64_field(dyld_header_max_slide_offset);
    if (!shared_region_start || !shared_region_size || !max_slide)
        return { };

    result->file_count_ = *file_count;
    result->image_count_ = *image_count;
    result->index_count_ = *index_count;
    result->mapping_count_ = *mapping_count;
    result->range_count_ = *range_count;
    result->file_records_offset_ = *file_records_offset;
    result->image_records_offset_ = *image_records_offset;
    result->mapping_records_offset_ = *mapping_records_offset;
    result->range_records_offset_ = *range_records_offset;
    result->index_records_offset_ = *index_records_offset;
    result->string_offset_ = *string_offset;
    result->string_size_ = *string_size;
    result->platform_ = *platform;
    result->format_version_ = format;
    result->shared_region_start_ = *shared_region_start;
    result->shared_region_size_ = *shared_region_size;
    result->max_slide_ = *max_slide;
    std::memcpy(result->generation_identity_.digest.data(),
        bytes.data() + dyld_header_generation_identity_offset,
        result->generation_identity_.digest.size());

    for (std::uint32_t file_index = 0; file_index < result->file_count_;
        ++file_index) {
        if (!result->file(file_index))
            return { };
    }
    for (std::uint32_t image_index = 0; image_index < result->image_count_;
        ++image_index) {
        const auto image = result->image(image_index);
        if (!image || image->index != image_index)
            return { };
    }
    for (std::uint32_t index = 0; index < result->index_count_; ++index) {
        if (!result->index_entry(index))
            return { };
    }
    return std::shared_ptr<const GenerationArtifactView> { std::move(result) };
}

std::span<const std::byte>
DyldSharedCache::GenerationArtifactView::bytes() const noexcept
{
    return backing_ ? backing_->bytes() : std::span<const std::byte> { };
}

std::uint32_t
DyldSharedCache::GenerationArtifactView::file_count() const noexcept
{
    return file_count_;
}

std::uint32_t
DyldSharedCache::GenerationArtifactView::image_count() const noexcept
{
    return image_count_;
}

std::uint32_t
DyldSharedCache::GenerationArtifactView::index_count() const noexcept
{
    return index_count_;
}

std::uint32_t DyldSharedCache::GenerationArtifactView::platform() const noexcept
{
    return platform_;
}

std::uint8_t
DyldSharedCache::GenerationArtifactView::format_version() const noexcept
{
    return format_version_;
}

std::uint64_t
DyldSharedCache::GenerationArtifactView::shared_region_start() const noexcept
{
    return shared_region_start_;
}

std::uint64_t
DyldSharedCache::GenerationArtifactView::shared_region_size() const noexcept
{
    return shared_region_size_;
}

std::uint64_t
DyldSharedCache::GenerationArtifactView::max_slide() const noexcept
{
    return max_slide_;
}

const ContentIdentity&
DyldSharedCache::GenerationArtifactView::generation_identity() const noexcept
{
    return generation_identity_;
}

bool DyldSharedCache::GenerationArtifactView::table_fits(std::uint64_t offset,
    std::uint64_t count, std::uint64_t element_size) const noexcept
{
    return artifact_table_fits(bytes(), offset, count, element_size);
}

std::optional<std::string_view>
DyldSharedCache::GenerationArtifactView::string_at(
    std::uint32_t offset, std::uint32_t size) const noexcept
{
    if (offset > string_size_ || size > string_size_ - offset)
        return std::nullopt;
    const auto bytes_view = bytes();
    const auto absolute = string_offset_ + offset;
    if (absolute < string_offset_ || absolute > bytes_view.size() ||
        size > bytes_view.size() - absolute)
        return std::nullopt;
    return std::string_view {
        reinterpret_cast<const char*>(bytes_view.data() + absolute), size
    };
}

std::optional<DyldCacheFileView> DyldSharedCache::GenerationArtifactView::file(
    std::size_t index) const
{
    if (index >= file_count_)
        return std::nullopt;
    const auto base = file_records_offset_ + index * dyld_file_record_size;
    const auto path_offset = read_artifact_u32(bytes(), base);
    const auto path_size = read_artifact_u32(bytes(), base + 4U);
    const auto file_size = read_artifact_u64(bytes(), base + 8U);
    if (!path_offset || !path_size || !file_size ||
        base >
            std::numeric_limits<std::uint64_t>::max() - dyld_file_record_size ||
        !string_at(*path_offset, *path_size)) {
        return std::nullopt;
    }
    DyldCacheFileView result;
    result.path = *string_at(*path_offset, *path_size);
    result.file_size = static_cast<std::uintmax_t>(*file_size);
    const auto generation_present =
        std::to_integer<std::uint8_t>(bytes()[base + 16U]);
    if (generation_present > 1U)
        return std::nullopt;
    if (generation_present != 0U) {
        const auto generation_base = base + 17U;
        const auto read_generation = [&](std::size_t field) {
            return read_artifact_u64(bytes(), generation_base + field * 8U);
        };
        const auto device = read_generation(0U);
        const auto inode = read_generation(1U);
        const auto size = read_generation(2U);
        const auto modified_seconds = read_generation(3U);
        const auto modified_nanoseconds = read_generation(4U);
        const auto changed_seconds = read_generation(5U);
        const auto changed_nanoseconds = read_generation(6U);
        if (!device || !inode || !size || !modified_seconds ||
            !modified_nanoseconds || !changed_seconds || !changed_nanoseconds)
            return std::nullopt;
        result.file_generation = GuestFileGeneration { *device, *inode, *size,
            static_cast<std::int64_t>(*modified_seconds),
            static_cast<std::int64_t>(*modified_nanoseconds),
            static_cast<std::int64_t>(*changed_seconds),
            static_cast<std::int64_t>(*changed_nanoseconds) };
    }
    if (!result.file_generation)
        return std::nullopt;
    std::memcpy(result.content_identity.digest.data(),
        bytes().data() + base + 73U, result.content_identity.digest.size());
    std::memcpy(
        result.uuid.data(), bytes().data() + base + 105U, result.uuid.size());
    const auto cache_vm_offset = read_artifact_u64(bytes(), base + 121U);
    const auto suffix_offset = read_artifact_u32(bytes(), base + 129U);
    const auto suffix_size = read_artifact_u32(bytes(), base + 133U);
    const auto mapping_begin = read_artifact_u32(bytes(), base + 137U);
    const auto mapping_count = read_artifact_u32(bytes(), base + 141U);
    if (!cache_vm_offset || !suffix_offset || !suffix_size || !mapping_begin ||
        !mapping_count || *mapping_begin > mapping_count_ ||
        *mapping_count > mapping_count_ - *mapping_begin) {
        return std::nullopt;
    }
    const auto suffix = string_at(*suffix_offset, *suffix_size);
    if (!suffix)
        return std::nullopt;
    result.cache_vm_offset = *cache_vm_offset;
    result.file_suffix = *suffix;
    const auto* mappings = artifact_native_table<DyldCacheMapping>(bytes(),
        mapping_records_offset_ + static_cast<std::uint64_t>(*mapping_begin) *
                                      sizeof(DyldCacheMapping),
        *mapping_count);
    if (mappings == nullptr)
        return std::nullopt;
    result.mappings = { mappings, *mapping_count };
    for (const auto& mapping : result.mappings) {
        if (mapping.file_index != index || mapping.size == 0U ||
            add_overflows(mapping.file_offset, mapping.size) ||
            mapping.file_offset + mapping.size > *file_size) {
            return std::nullopt;
        }
    }
    return result;
}

std::optional<DyldCacheImageView>
DyldSharedCache::GenerationArtifactView::image(std::size_t index) const
{
    if (index >= image_count_)
        return std::nullopt;
    const auto base = image_records_offset_ + index * dyld_image_record_size;
    const auto serialized_index = read_artifact_u32(bytes(), base);
    const auto path_offset = read_artifact_u32(bytes(), base + 4U);
    const auto path_size = read_artifact_u32(bytes(), base + 8U);
    const auto load_address = read_artifact_u64(bytes(), base + 12U);
    if (!serialized_index || !path_offset || !path_size || !load_address ||
        !string_at(*path_offset, *path_size) || *serialized_index != index)
        return std::nullopt;
    DyldCacheImageView result;
    result.index = *serialized_index;
    result.path = *string_at(*path_offset, *path_size);
    result.unslid_load_address = *load_address;
    const auto uuid_present =
        std::to_integer<std::uint8_t>(bytes()[base + 20U]);
    if (uuid_present > 1U)
        return std::nullopt;
    if (uuid_present != 0U) {
        DyldCacheUuid uuid;
        std::memcpy(uuid.data(), bytes().data() + base + 21U, uuid.size());
        result.text_uuid = uuid;
    }
    const auto text_segment_size = read_artifact_u64(bytes(), base + 37U);
    const auto range_begin = read_artifact_u32(bytes(), base + 45U);
    const auto range_count = read_artifact_u32(bytes(), base + 49U);
    if (!text_segment_size || !range_begin || !range_count ||
        *range_begin > range_count_ ||
        *range_count > range_count_ - *range_begin) {
        return std::nullopt;
    }
    result.text_segment_size = *text_segment_size;
    const auto* ranges = artifact_native_table<DyldCacheRange>(bytes(),
        range_records_offset_ +
            static_cast<std::uint64_t>(*range_begin) * sizeof(DyldCacheRange),
        *range_count);
    if (ranges == nullptr)
        return std::nullopt;
    result.executable_ranges = { ranges, *range_count };
    for (const auto& range : result.executable_ranges) {
        if (range.file_index >= file_count_ || range.size == 0U ||
            add_overflows(range.file_offset, range.size)) {
            return std::nullopt;
        }
        const auto file_view = file(range.file_index);
        if (!file_view || range.file_offset + range.size > file_view->file_size)
            return std::nullopt;
    }
    const auto identity_present =
        std::to_integer<std::uint8_t>(bytes()[base + 53U]);
    if (identity_present > 1U)
        return std::nullopt;
    if (identity_present != 0U) {
        ContentIdentity identity;
        std::memcpy(identity.digest.data(), bytes().data() + base + 54U,
            identity.digest.size());
        result.text_identity = identity;
    }
    return result;
}

std::optional<DyldSharedCache::ImageRangeIndexEntry>
DyldSharedCache::GenerationArtifactView::index_entry(std::size_t index) const
{
    if (index >= index_count_)
        return std::nullopt;
    const auto* entries =
        artifact_native_table<DyldSharedCache::ImageRangeIndexEntry>(
            bytes(), index_records_offset_, index_count_);
    if (entries == nullptr)
        return std::nullopt;
    return entries[index];
}

DyldSharedCache::ParseResult::ParseResult(
    std::shared_ptr<const DyldSharedCache> generation) noexcept
    : generation_ { std::move(generation) }
{
}

bool DyldSharedCache::ParseResult::has_value() const noexcept
{
    return generation_ != nullptr;
}

DyldSharedCache::ParseResult::operator bool() const noexcept
{
    return has_value();
}

const DyldSharedCache* DyldSharedCache::ParseResult::operator->() const noexcept
{
    return generation_.get();
}

const DyldSharedCache& DyldSharedCache::ParseResult::operator*() const noexcept
{
    return *generation_;
}

std::shared_ptr<const DyldSharedCache>
DyldSharedCache::ParseResult::shared() const noexcept
{
    return generation_;
}

DyldSharedCache::DyldSharedCache()
    : image_store_ { std::make_shared<ImageStore>() }
    , file_view_store_ { std::make_shared<FileViewStore>() }
{
}

DyldSharedCache::~DyldSharedCache() = default;

DyldSharedCache::DyldSharedCache(DyldSharedCache&& other) noexcept = default;

DyldSharedCache& DyldSharedCache::operator=(
    DyldSharedCache&& other) noexcept = default;

std::shared_ptr<const DyldSharedCache>
DyldSharedCache::load_shared_generation_artifact(
    const std::filesystem::path& path, const DyldSharedCacheOptions& options,
    const GuestFileGeneration& main_generation,
    const ContentIdentity& main_identity)
{
    const auto artifact = GenerationArtifactView::open(
        shared_immutable_artifact_named_path(generation_artifact_name(
            path, options, main_generation, main_identity)));
    if (!artifact)
        return { };

    // Artifact loads retain only the typed mmap-backed view; image and file
    // records are never deserialized into process-local owning vectors.
    DyldSharedCache mapped_result;
    mapped_result.generation_artifact_view_ = artifact;
    mapped_result.generation_identity_ = artifact->generation_identity();
    mapped_result.platform_ = artifact->platform();
    mapped_result.format_version_ = artifact->format_version();
    mapped_result.shared_region_start_ = artifact->shared_region_start();
    mapped_result.shared_region_size_ = artifact->shared_region_size();
    mapped_result.max_slide_ = artifact->max_slide();
    const auto main_file = artifact->file(0U);
    if (!main_file || normalize_cache_path(std::filesystem::path {
                          main_file->path }) != normalize_cache_path(path)) {
        return { };
    }
    if (!options.subcache_paths.empty() &&
        options.subcache_paths.size() + 1U != artifact->file_count()) {
        return { };
    }
    for (std::uint32_t file_index = 0; file_index < artifact->file_count();
        ++file_index) {
        const auto file = artifact->file(file_index);
        if (!file || !file->file_generation)
            return { };
        const auto file_path = std::filesystem::path { file->path };
        const auto current_generation = read_file_generation(file_path);
        const auto current_identity =
            shared_file_identity(file_path).content_identity;
        if (!current_generation || !current_identity ||
            *current_generation != *file->file_generation ||
            *current_identity != file->content_identity ||
            current_generation->file_size != file->file_size) {
            return { };
        }
        if (file_index != 0U && !options.subcache_paths.empty() &&
            normalize_cache_path(options.subcache_paths[file_index - 1U]) !=
                normalize_cache_path(file_path)) {
            return { };
        }
    }
    for (std::uint32_t image_index = 0; image_index < artifact->image_count();
        ++image_index) {
        if (!artifact->image(image_index))
            return { };
    }
    return std::make_shared<const DyldSharedCache>(std::move(mapped_result));
}

void DyldSharedCache::publish_shared_generation_artifact(
    const std::filesystem::path& path, const DyldSharedCacheOptions& options,
    const GuestFileGeneration& main_generation,
    const ContentIdentity& main_identity) const
{
    std::vector<std::byte> file_table;
    std::vector<std::byte> image_table;
    std::vector<DyldCacheMapping> mapping_table;
    std::vector<DyldCacheRange> range_table;
    std::vector<ImageRangeIndexEntry> index_table;
    std::vector<std::byte> strings;
    const auto add_string = [&strings](std::string_view value) {
        const auto offset = strings.size();
        strings.insert(strings.end(),
            reinterpret_cast<const std::byte*>(value.data()),
            reinterpret_cast<const std::byte*>(value.data() + value.size()));
        return std::pair { static_cast<std::uint32_t>(offset),
            static_cast<std::uint32_t>(value.size()) };
    };
    const auto append_optional_generation_fixed =
        [](std::vector<std::byte>& output,
            const std::optional<GuestFileGeneration>& generation) {
            append_presence(output, generation.has_value());
            if (generation) {
                append_generation(output, *generation);
            } else {
                for (std::size_t index = 0; index < 7U; ++index)
                    append_u64(output, 0U);
            }
        };
    for (const auto& file : files_) {
        const auto native_path = file.path.native();
        const auto path_string = add_string(native_path);
        const auto suffix_string = add_string(file.file_suffix);
        append_u32(file_table, path_string.first);
        append_u32(file_table, path_string.second);
        append_u64(file_table, static_cast<std::uint64_t>(file.file_size));
        append_optional_generation_fixed(file_table, file.file_generation);
        append_identity(file_table, file.content_identity);
        append_uuid(file_table, file.uuid);
        append_u64(file_table, file.cache_vm_offset);
        append_u32(file_table, suffix_string.first);
        append_u32(file_table, suffix_string.second);
        const auto mapping_begin = mapping_table.size();
        mapping_table.insert(
            mapping_table.end(), file.mappings.begin(), file.mappings.end());
        append_u32(file_table, static_cast<std::uint32_t>(mapping_begin));
        append_u32(
            file_table, static_cast<std::uint32_t>(file.mappings.size()));
    }
    for (const auto& image : images_) {
        const auto path_string = add_string(image.path);
        append_u32(image_table, image.index);
        append_u32(image_table, path_string.first);
        append_u32(image_table, path_string.second);
        append_u64(image_table, image.unslid_load_address);
        append_presence(image_table, image.text_uuid.has_value());
        if (image.text_uuid) {
            append_uuid(image_table, *image.text_uuid);
        } else {
            append_uuid(image_table, DyldCacheUuid { });
        }
        append_u64(image_table, image.text_segment_size);
        const auto range_begin = range_table.size();
        range_table.insert(range_table.end(), image.executable_ranges.begin(),
            image.executable_ranges.end());
        append_u32(image_table, static_cast<std::uint32_t>(range_begin));
        append_u32(image_table,
            static_cast<std::uint32_t>(image.executable_ranges.size()));
        append_presence(image_table, image.text_identity.has_value());
        if (image.text_identity) {
            append_identity(image_table, *image.text_identity);
        } else {
            append_identity(image_table, ContentIdentity { });
        }
    }
    for (const auto& entries : image_range_index_) {
        index_table.insert(index_table.end(), entries.begin(), entries.end());
    }

    std::vector<std::byte> bytes(dyld_generation_header_size);
    std::memcpy(bytes.data(), dyld_generation_magic.data(),
        dyld_generation_magic.size());
    const auto file_records_offset = append_artifact_native_table(
        bytes, std::span<const std::byte> { file_table });
    const auto image_records_offset = append_artifact_native_table(
        bytes, std::span<const std::byte> { image_table });
    const auto mapping_records_offset = append_artifact_native_table(
        bytes, std::span<const DyldCacheMapping> { mapping_table });
    const auto range_records_offset = append_artifact_native_table(
        bytes, std::span<const DyldCacheRange> { range_table });
    const auto index_records_offset = append_artifact_native_table(
        bytes, std::span<const ImageRangeIndexEntry> { index_table });
    const auto string_offset = append_artifact_native_table(
        bytes, std::span<const std::byte> { strings });

    write_artifact_u32(
        bytes, dyld_header_version_offset, dyld_generation_artifact_version);
    write_artifact_u32(bytes, dyld_header_file_count_offset,
        static_cast<std::uint32_t>(files_.size()));
    write_artifact_u32(bytes, dyld_header_image_count_offset,
        static_cast<std::uint32_t>(images_.size()));
    write_artifact_u32(bytes, dyld_header_index_count_offset,
        static_cast<std::uint32_t>(index_table.size()));
    write_artifact_u32(bytes, dyld_header_mapping_count_offset,
        static_cast<std::uint32_t>(mapping_table.size()));
    write_artifact_u32(bytes, dyld_header_range_count_offset,
        static_cast<std::uint32_t>(range_table.size()));
    write_artifact_u64(
        bytes, dyld_header_file_records_offset, file_records_offset);
    write_artifact_u64(
        bytes, dyld_header_image_records_offset, image_records_offset);
    write_artifact_u64(
        bytes, dyld_header_mapping_records_offset, mapping_records_offset);
    write_artifact_u64(
        bytes, dyld_header_range_records_offset, range_records_offset);
    write_artifact_u64(
        bytes, dyld_header_index_records_offset, index_records_offset);
    write_artifact_u64(bytes, dyld_header_string_offset, string_offset);
    write_artifact_u64(bytes, dyld_header_string_size_offset, strings.size());
    write_artifact_u32(bytes, dyld_header_platform_offset, platform_);
    bytes[dyld_header_format_offset] = static_cast<std::byte>(format_version_);
    write_artifact_u64(
        bytes, dyld_header_shared_start_offset, shared_region_start_);
    write_artifact_u64(
        bytes, dyld_header_shared_size_offset, shared_region_size_);
    write_artifact_u64(bytes, dyld_header_max_slide_offset, max_slide_);
    std::memcpy(bytes.data() + dyld_header_generation_identity_offset,
        generation_identity_.digest.data(), generation_identity_.digest.size());
    static_cast<void>(publish_shared_immutable_artifact(
        shared_immutable_artifact_named_path(generation_artifact_name(
            path, options, main_generation, main_identity)),
        bytes));
    return;
}

DyldSharedCache::ParseResult DyldSharedCache::parse(
    const std::filesystem::path& path, DyldSharedCacheOptions options)
{
    const auto cache_key = generation_cache_key(path, options);
    const auto file_stamps = [](const DyldCacheFileRange& range) {
        std::vector<GenerationCacheEntry::FileStamp> stamps;
        stamps.reserve(range.size());
        for (const auto file : range) {
            stamps.push_back(GenerationCacheEntry::FileStamp {
                std::filesystem::path { file.path }, file.file_size,
                file.file_generation, file.content_identity });
        }
        return stamps;
    };
    // Keep construction single-flight. The parser only holds this lock while a
    // generation is absent; once published, all callers retain the same
    // immutable object and do not copy its metadata.
    std::unique_lock generation_lock { generation_cache_mutex };
    if (const auto cached = generation_cache.find(cache_key);
        cached != generation_cache.end() &&
        generation_files_are_current(cached->second)) {
        if (const auto generation = cached->second.generation.lock()) {
            ++generation_hits;
            return generation;
        }
    }

    // A process-local weak pointer is only the fast path.  Independent
    // emulator processes acquire the same read-only serialized generation
    // metadata after validating the current main member's generation and
    // content identity; the loader then validates every subcache before
    // publishing the local handle.
    const auto main_generation = read_file_generation(path);
    const auto main_identity = shared_file_identity(path).content_identity;
    if (main_generation && main_identity) {
        if (const auto generation = load_shared_generation_artifact(
                path, options, *main_generation, *main_identity)) {
            generation_cache[cache_key] = GenerationCacheEntry { generation,
                file_stamps(generation->files()) };
            ++generation_hits;
            ++generation_artifact_hits;
            return generation;
        }
    }

    const auto main = parse_file(path, 0, 0, { }, true);
    if (!main)
        return { };

    std::ifstream header_input { path, std::ios::binary };
    if (!header_input)
        return { };
    DyldSharedCache result;
    result.main_cache_ = main->file;
    result.files_.push_back(main->file);

    const auto read_optional_u32 = [&](std::size_t offset) {
        return field_available(
                   main->mapping_offset, offset, sizeof(std::uint32_t))
                   ? read_u32(header_input, offset)
                   : std::optional<std::uint32_t> { 0U };
    };
    const auto read_optional_u64 = [&](std::size_t offset) {
        return field_available(
                   main->mapping_offset, offset, sizeof(std::uint64_t))
                   ? read_u64(header_input, offset)
                   : std::optional<std::uint64_t> { 0U };
    };
    const auto platform = read_optional_u32(platform_field);
    const auto format = read_optional_u32(format_version_field);
    const auto shared_start = read_optional_u64(shared_region_start_field);
    const auto shared_size = read_optional_u64(shared_region_size_field);
    const auto max_slide = read_optional_u64(max_slide_field);
    if (!platform || !format || !shared_start || !shared_size || !max_slide) {
        return { };
    }
    result.platform_ = *platform;
    result.format_version_ = static_cast<std::uint8_t>(*format & 0xffU);
    result.shared_region_start_ = *shared_start;
    result.shared_region_size_ = *shared_size;
    result.max_slide_ = *max_slide;

    std::uint32_t subcache_count = 0;
    std::uint32_t subcache_offset = 0;
    if (field_available(main->mapping_offset, subcache_array_count_field,
            sizeof(std::uint32_t))) {
        const auto offset = read_u32(header_input, subcache_array_offset_field);
        const auto count = read_u32(header_input, subcache_array_count_field);
        if (!offset || !count)
            return { };
        subcache_offset = *offset;
        subcache_count = *count;
    }
    if (subcache_count > maximum_subcache_count)
        return { };
    const bool has_extended_subcache_entry = field_available(
        main->mapping_offset, cache_subtype_field, sizeof(std::uint32_t));
    const auto subcache_entry_size =
        has_extended_subcache_entry ? subcache_size : subcache_v1_size;
    if (subcache_count != 0U &&
        !table_fits(subcache_offset, subcache_count, subcache_entry_size,
            main->file.file_size, maximum_subcache_count)) {
        return { };
    }
    if (!options.subcache_paths.empty() &&
        options.subcache_paths.size() != subcache_count) {
        return { };
    }

    for (std::uint32_t index = 0; index < subcache_count; ++index) {
        const auto entry_offset =
            static_cast<std::uint64_t>(subcache_offset) +
            static_cast<std::uint64_t>(index) * subcache_entry_size;
        const auto uuid = read_uuid(header_input, entry_offset);
        const auto vm_offset = read_u64(header_input, entry_offset + 16U);
        if (!uuid || !vm_offset)
            return { };
        std::string suffix;
        if (has_extended_subcache_entry) {
            const auto suffix_bytes =
                read_blob(header_input, entry_offset + 24U, 32U);
            if (!suffix_bytes)
                return { };
            const auto end = std::find(
                suffix_bytes->begin(), suffix_bytes->end(), std::byte { });
            suffix.assign(reinterpret_cast<const char*>(suffix_bytes->data()),
                static_cast<std::size_t>(end - suffix_bytes->begin()));
            if (suffix.find('/') != std::string::npos ||
                suffix.find('\\') != std::string::npos) {
                return { };
            }
        }
        const auto subcache_path = options.subcache_paths.empty()
                                       ? discover_subcache(path, suffix, index)
                                       : options.subcache_paths[index];
        const auto subcache =
            parse_file(subcache_path, index + 1U, *vm_offset, suffix, false);
        if (!subcache || subcache->file.uuid != *uuid)
            return { };
        result.files_.push_back(subcache->file);
    }

    // Capture every member before publishing the generation. The shared
    // pointer is retained by the generation, so delayed image/HLE consumers
    // cannot accidentally reopen a replacement at the same pathname.
    for (auto& file : result.files_) {
        file.immutable_file_view = read_immutable_file_view(file);
        if (!file.immutable_file_view)
            return { };
    }
    result.main_cache_ = result.files_.front();

    std::uint32_t image_offset = 0;
    std::uint32_t image_count = 0;
    if (field_available(
            main->mapping_offset, images_count_field, sizeof(std::uint32_t))) {
        const auto offset = read_u32(header_input, images_offset_field);
        const auto count = read_u32(header_input, images_count_field);
        if (!offset || !count)
            return { };
        image_offset = *offset;
        image_count = *count;
    } else {
        const auto offset = read_u32(header_input, images_offset_old_field);
        const auto count = read_u32(header_input, images_count_old_field);
        if (!offset || !count)
            return { };
        image_offset = *offset;
        image_count = *count;
    }
    if (!table_fits(image_offset, image_count, image_info_size,
            main->file.file_size, maximum_image_count)) {
        return { };
    }
    result.images_.reserve(image_count);
    for (std::uint32_t index = 0; index < image_count; ++index) {
        const auto offset = static_cast<std::uint64_t>(image_offset) +
                            static_cast<std::uint64_t>(index) * image_info_size;
        const auto load_address = read_u64(header_input, offset);
        const auto path_offset = read_u32(header_input, offset + 24U);
        if (!load_address || !path_offset)
            return { };
        const auto image_path =
            read_string(header_input, *path_offset, main->file.file_size);
        if (!image_path)
            return { };
        DyldCacheImage image;
        image.index = index;
        image.path = *image_path;
        image.unslid_load_address = *load_address;
        result.images_.push_back(std::move(image));
    }

    for (const auto& info : main->text_infos) {
        const auto image = std::find_if(result.images_.begin(),
            result.images_.end(), [&](const auto& candidate) {
                return candidate.path == info.path ||
                       candidate.unslid_load_address == info.load_address;
            });
        if (image == result.images_.end())
            continue;
        image->text_uuid = info.uuid;
        image->text_segment_size = info.segment_size;

        const DyldCacheMapping* mapping = nullptr;
        for (const auto& file : result.files_) {
            const auto candidate = std::find_if(file.mappings.begin(),
                file.mappings.end(), [&](const auto& range) {
                    return (range.maximum_protection & 4U) != 0U &&
                           info.load_address >= range.address &&
                           info.load_address - range.address < range.size;
                });
            if (candidate != file.mappings.end()) {
                mapping = &*candidate;
                break;
            }
        }
        if (!mapping)
            continue;
        const auto size = std::min<std::uint64_t>(info.segment_size,
            mapping->size - (info.load_address - mapping->address));
        if (size == 0U || mapping->file_index >= result.files_.size() ||
            add_overflows(
                mapping->file_offset, info.load_address - mapping->address)) {
            return { };
        }
        const auto file_offset =
            mapping->file_offset + (info.load_address - mapping->address);
        image->executable_ranges.push_back(DyldCacheRange { info.load_address,
            size, file_offset, mapping->file_index, mapping->initial_protection,
            mapping->maximum_protection });
        const auto identity = sha256_file(
            result.files_[mapping->file_index].path, file_offset, size);
        if (!identity)
            return { };
        image->text_identity = *identity;
    }

    for (auto& image : result.images_) {
        static_cast<void>(populate_legacy_image_ranges(image, result.files_));
    }
    result.image_range_index_.resize(result.files_.size());
    for (const auto& image : result.images_) {
        for (const auto& range : image.executable_ranges) {
            if (range.file_index >= result.image_range_index_.size() ||
                add_overflows(range.file_offset, range.size)) {
                continue;
            }
            result.image_range_index_[range.file_index].push_back(
                ImageRangeIndexEntry { range.file_offset,
                    range.file_offset + range.size, 0, image.index,
                    range.file_index });
        }
    }
    for (auto& entries : result.image_range_index_) {
        std::sort(entries.begin(), entries.end(),
            [](const ImageRangeIndexEntry& left,
                const ImageRangeIndexEntry& right) {
                if (left.file_offset != right.file_offset)
                    return left.file_offset < right.file_offset;
                return left.image_index < right.image_index;
            });
        std::uint64_t prefix_file_end = 0;
        for (auto& entry : entries) {
            prefix_file_end = std::max(prefix_file_end, entry.file_end);
            entry.prefix_file_end = prefix_file_end;
        }
    }

    std::vector<std::byte> generation_key;
    generation_key.reserve(
        96U + result.files_.size() * 64U + options.architecture.size());
    append_u32(generation_key, DyldSharedCache::parser_schema_version);
    append_u32(generation_key, DyldSharedCache::hle_profile_schema_version);
    const auto architecture =
        options.architecture.empty() ? main->magic : options.architecture;
    generation_key.insert(generation_key.end(),
        reinterpret_cast<const std::byte*>(architecture.data()),
        reinterpret_cast<const std::byte*>(
            architecture.data() + architecture.size()));
    append_u32(generation_key, result.platform_);
    append_u32(generation_key, result.format_version_);
    append_u64(generation_key, result.shared_region_start_);
    append_u64(generation_key, result.shared_region_size_);
    append_identity(generation_key, main->file.content_identity);
    if (main->file.file_generation) {
        append_generation(generation_key, *main->file.file_generation);
    }
    append_uuid(generation_key, main->file.uuid);
    append_u64(generation_key, main->file.cache_vm_offset);
    for (std::size_t index = 1; index < result.files_.size(); ++index) {
        const auto& file = result.files_[index];
        append_identity(generation_key, file.content_identity);
        if (file.file_generation) {
            append_generation(generation_key, *file.file_generation);
        }
        append_uuid(generation_key, file.uuid);
        append_u64(generation_key, file.cache_vm_offset);
    }
    result.generation_identity_ = sha256(generation_key);
    auto generation =
        std::make_shared<const DyldSharedCache>(std::move(result));
    generation_cache[cache_key] =
        GenerationCacheEntry { generation, file_stamps(generation->files()) };
    generation->publish_shared_generation_artifact(path, options,
        *main->file.file_generation, main->file.content_identity);
    ++generation_artifact_builds;
    ++generation_builds;
    return generation;
}

DyldSharedCache::ParseStats DyldSharedCache::parse_stats() noexcept
{
    std::lock_guard lock { generation_cache_mutex };
    return ParseStats { generation_builds, generation_hits,
        generation_artifact_builds, generation_artifact_hits, file_view_builds,
        file_view_hits, image_builds, image_hits };
}

std::shared_ptr<const ImmutableFileView>
DyldSharedCache::immutable_file_view_at(std::size_t index) const
{
    if (file_view_store_ == nullptr ||
        index > std::numeric_limits<std::uint32_t>::max()) {
        return { };
    }
    std::lock_guard lock { file_view_store_->mutex };
    const auto member_index = static_cast<std::uint32_t>(index);
    if (const auto cached = file_view_store_->views.find(member_index);
        cached != file_view_store_->views.end()) {
        ++file_view_hits;
        return cached->second;
    }

    std::shared_ptr<const ImmutableFileView> view;
    if (generation_artifact_view_) {
        const auto source = file_view_at(index);
        if (source.file_generation &&
            source.file_size <= std::numeric_limits<std::size_t>::max()) {
            view =
                ImmutableFileView::open(std::filesystem::path { source.path },
                    *source.file_generation, source.content_identity,
                    static_cast<std::uint64_t>(source.file_size));
        }
        ++file_view_builds;
    } else if (index < files_.size()) {
        // A newly built generation captured these views before publication. The
        // accessor still records their reuse in the same per-member store so
        // the lifetime and failure behavior match artifact-loaded generations.
        view = files_[index].immutable_file_view;
        ++file_view_hits;
    }
    file_view_store_->views.emplace(member_index, view);
    return view;
}

std::optional<std::string> DyldSharedCache::read_vm_c_string(
    std::uint64_t address) const
{
    constexpr std::size_t maximum_string_size = 4096U;
    for (std::size_t file_index = 0; file_index < files().size();
        ++file_index) {
        const auto file = file_view_at(file_index);
        for (const auto& mapping : file.mappings) {
            if (address < mapping.address ||
                address - mapping.address >= mapping.size)
                continue;
            const auto delta = address - mapping.address;
            if (mapping.file_offset >
                std::numeric_limits<std::uint64_t>::max() - delta) {
                return std::nullopt;
            }
            const auto offset = mapping.file_offset + delta;
            const auto view = immutable_file_view_at(file_index);
            if (!view || offset >= view->size())
                return std::nullopt;
            const auto available =
                static_cast<std::size_t>(std::min<std::uint64_t>(
                    view->size() - offset, maximum_string_size));
            const auto bytes = view->range(offset, available);
            const auto terminator =
                std::find(bytes.begin(), bytes.end(), std::byte { 0 });
            if (terminator == bytes.end())
                return std::nullopt;
            return std::string { reinterpret_cast<const char*>(bytes.data()),
                static_cast<std::size_t>(terminator - bytes.begin()) };
        }
    }
    return std::nullopt;
}

std::shared_ptr<const MachOImage> DyldSharedCache::parse_image(
    std::uint32_t image_index, ArmArchitectureVersion architecture) const
{
    if (image_store_ == nullptr || image_index >= images().size())
        return { };
    const auto architecture_tag = static_cast<std::uint8_t>(architecture);
    const auto key = std::pair { image_index, architecture_tag };
    std::unique_lock generation_lock { generation_cache_mutex };
    std::lock_guard image_lock { image_store_->mutex };
    if (const auto cached = image_store_->images.find(key);
        cached != image_store_->images.end()) {
        ++image_hits;
        return cached->second;
    }

    const auto image = image_view_at(image_index);
    const DyldCacheRange* header = nullptr;
    for (const auto& range : image.executable_ranges) {
        if (range.address == image.unslid_load_address &&
            range.file_index < files().size()) {
            header = &range;
            break;
        }
    }
    if (header == nullptr)
        return { };
    DyldCacheFile source;
    if (generation_artifact_view_) {
        const auto source_view = file_view_at(header->file_index);
        if (!source_view.file_generation)
            return { };
        source.path = std::filesystem::path { source_view.path };
        source.file_size = source_view.file_size;
        source.file_generation = source_view.file_generation;
        source.content_identity = source_view.content_identity;
        source.immutable_file_view = immutable_file_view_at(header->file_index);
        if (!source.immutable_file_view)
            return { };
    } else {
        source = files_[header->file_index];
    }
    try {
        auto parsed = std::make_shared<const MachOImage>(
            MachOImage::parse(source.path, architecture,
                source.content_identity, ImmutableSnapshotKind::RuntimeHot,
                header->file_offset, source.immutable_snapshot,
                source.file_generation, source.immutable_file_view));
        image_store_->images.emplace(key, parsed);
        ++image_builds;
        return parsed;
    } catch (const std::exception&) {
        // Do not publish an incomplete image. A later request may retry against
        // a stable file generation, while existing generations remain
        // untouched.
        return { };
    }
}

std::vector<std::uint32_t> DyldSharedCache::images_intersecting_file_range(
    std::uint32_t file_index, std::uint64_t file_offset,
    std::uint64_t size) const
{
    if (size == 0U || file_index >= files().size() ||
        add_overflows(file_offset, size)) {
        return { };
    }
    const auto file_end = file_offset + size;
    if (generation_artifact_view_) {
        std::vector<std::uint32_t> image_indices;
        for (std::size_t index = 0;
            index < generation_artifact_view_->index_count(); ++index) {
            const auto entry = generation_artifact_view_->index_entry(index);
            if (!entry || entry->file_index != file_index ||
                entry->file_offset >= file_end ||
                entry->file_end <= file_offset) {
                continue;
            }
            image_indices.push_back(entry->image_index);
        }
        std::sort(image_indices.begin(), image_indices.end());
        image_indices.erase(
            std::unique(image_indices.begin(), image_indices.end()),
            image_indices.end());
        return image_indices;
    }
    if (file_index >= image_range_index_.size())
        return { };
    const auto& entries = image_range_index_[file_index];
    auto first = std::lower_bound(entries.begin(), entries.end(), file_offset,
        [](const ImageRangeIndexEntry& entry, std::uint64_t offset) {
            return entry.file_offset < offset;
        });
    while (first != entries.begin() &&
           std::prev(first)->prefix_file_end > file_offset)
        --first;

    std::vector<std::uint32_t> image_indices;
    for (auto iterator = first;
        iterator != entries.end() && iterator->file_offset < file_end;
        ++iterator) {
        if (iterator->file_end <= file_offset)
            continue;
        image_indices.push_back(iterator->image_index);
    }
    std::sort(image_indices.begin(), image_indices.end());
    image_indices.erase(std::unique(image_indices.begin(), image_indices.end()),
        image_indices.end());
    return image_indices;
}

DyldCacheFileView DyldSharedCache::file_view_at(std::size_t index) const
{
    if (generation_artifact_view_) {
        const auto file = generation_artifact_view_->file(index);
        if (!file)
            return { };
        return *file;
    }
    if (index >= files_.size())
        return { };
    const auto& file = files_[index];
    return DyldCacheFileView { std::string_view { file.path.native() },
        file.file_size, file.file_generation, file.content_identity, file.uuid,
        file.cache_vm_offset, std::string_view { file.file_suffix },
        std::span<const DyldCacheMapping> { file.mappings } };
}

DyldCacheImageView DyldSharedCache::image_view_at(std::size_t index) const
{
    if (generation_artifact_view_) {
        const auto image = generation_artifact_view_->image(index);
        if (!image)
            return { };
        return *image;
    }
    if (index >= images_.size())
        return { };
    const auto& image = images_[index];
    return DyldCacheImageView { image.index, std::string_view { image.path },
        image.unslid_load_address, image.text_uuid, image.text_segment_size,
        std::span<const DyldCacheRange> { image.executable_ranges },
        image.text_identity };
}

DyldCacheFileView DyldSharedCache::main_cache() const
{
    return file_view_at(0U);
}

DyldCacheFileRange DyldSharedCache::files() const noexcept
{
    return DyldCacheFileRange { this };
}

DyldCacheImageRange DyldSharedCache::images() const noexcept
{
    return DyldCacheImageRange { this };
}

const ContentIdentity& DyldSharedCache::generation_identity() const noexcept
{
    return generation_identity_;
}

std::uint32_t DyldSharedCache::platform() const noexcept { return platform_; }

std::uint8_t DyldSharedCache::format_version() const noexcept
{
    return format_version_;
}

std::uint64_t DyldSharedCache::shared_region_start() const noexcept
{
    return shared_region_start_;
}

std::uint64_t DyldSharedCache::shared_region_size() const noexcept
{
    return shared_region_size_;
}

std::uint64_t DyldSharedCache::max_slide() const noexcept { return max_slide_; }

std::optional<DyldCacheImageView> DyldSharedCache::find_image(
    std::string_view install_name) const
{
    for (std::size_t index = 0; index < images().size(); ++index) {
        const auto image = image_view_at(index);
        if (image.path == install_name)
            return image;
    }
    return std::nullopt;
}

DyldCacheFileView DyldCacheFileRange::iterator::operator*() const
{
    return cache_->file_view_at(index_);
}

DyldCacheFileView DyldCacheFileRange::iterator::operator[](
    difference_type offset) const
{
    return cache_->file_view_at(index_ + offset);
}

DyldCacheFileRange::iterator& DyldCacheFileRange::iterator::operator++()
{
    ++index_;
    return *this;
}

DyldCacheFileRange::iterator& DyldCacheFileRange::iterator::operator--()
{
    --index_;
    return *this;
}

DyldCacheFileRange::iterator& DyldCacheFileRange::iterator::operator+=(
    difference_type offset)
{
    index_ += offset;
    return *this;
}

DyldCacheFileRange::iterator& DyldCacheFileRange::iterator::operator-=(
    difference_type offset)
{
    index_ -= offset;
    return *this;
}

DyldCacheFileRange::iterator DyldCacheFileRange::begin() const noexcept
{
    return iterator { cache_, 0U };
}

DyldCacheFileRange::iterator DyldCacheFileRange::end() const noexcept
{
    return iterator { cache_, size() };
}

std::size_t DyldCacheFileRange::size() const noexcept
{
    if (cache_ == nullptr)
        return 0U;
    return cache_->generation_artifact_view_
               ? cache_->generation_artifact_view_->file_count()
               : cache_->files_.size();
}

DyldCacheFileView DyldCacheFileRange::operator[](std::size_t index) const
{
    return cache_->file_view_at(index);
}

DyldCacheImageView DyldCacheImageRange::iterator::operator*() const
{
    return cache_->image_view_at(index_);
}

DyldCacheImageView DyldCacheImageRange::iterator::operator[](
    difference_type offset) const
{
    return cache_->image_view_at(index_ + offset);
}

DyldCacheImageRange::iterator& DyldCacheImageRange::iterator::operator++()
{
    ++index_;
    return *this;
}

DyldCacheImageRange::iterator& DyldCacheImageRange::iterator::operator--()
{
    --index_;
    return *this;
}

DyldCacheImageRange::iterator& DyldCacheImageRange::iterator::operator+=(
    difference_type offset)
{
    index_ += offset;
    return *this;
}

DyldCacheImageRange::iterator& DyldCacheImageRange::iterator::operator-=(
    difference_type offset)
{
    index_ -= offset;
    return *this;
}

DyldCacheImageRange::iterator DyldCacheImageRange::begin() const noexcept
{
    return iterator { cache_, 0U };
}

DyldCacheImageRange::iterator DyldCacheImageRange::end() const noexcept
{
    return iterator { cache_, size() };
}

std::size_t DyldCacheImageRange::size() const noexcept
{
    if (cache_ == nullptr)
        return 0U;
    return cache_->generation_artifact_view_
               ? cache_->generation_artifact_view_->image_count()
               : cache_->images_.size();
}

DyldCacheImageView DyldCacheImageRange::operator[](std::size_t index) const
{
    return cache_->image_view_at(index);
}

} // namespace shade
