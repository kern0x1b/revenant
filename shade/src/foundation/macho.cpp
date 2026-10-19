// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Parse ARM Mach-O images, sections, symbols, relocations and
// embedded entitlements.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-1699.22.73/EXTERNAL_HEADERS/mach-o/loader.h

#include "foundation/macho.hpp"

#include <algorithm>
#include <array>
#include <cerrno>
#include <cstring>
#include <limits>
#include <set>
#include <span>
#include <sstream>
#include <stdexcept>

#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

#include "foundation/file_page_cache.hpp"

#if defined(__APPLE__)
#define st_atim st_atimespec
#define st_mtim st_mtimespec
#define st_ctim st_ctimespec
#endif

namespace shade {
namespace {

    constexpr std::uint32_t mh_magic = 0xfeedfaceU;
    constexpr std::uint32_t fat_magic = 0xcafebabeU;
    constexpr std::uint32_t cpu_type_arm = 12;
    constexpr std::uint32_t cpu_subtype_arm_v6 = 6U;
    constexpr std::uint32_t cpu_subtype_arm_v7 = 9U;
    constexpr std::uint32_t lc_segment = 0x1;
    constexpr std::uint32_t lc_symtab = 0x2;
    constexpr std::uint32_t lc_dysymtab = 0xb;
    constexpr std::uint32_t lc_thread = 0x4;
    constexpr std::uint32_t lc_unixthread = 0x5;
    constexpr std::uint32_t lc_load_dylib = 0xc;
    constexpr std::uint32_t lc_id_dylib = 0xd;
    constexpr std::uint32_t lc_load_dylinker = 0xe;
    constexpr std::uint32_t lc_id_dylinker = 0xf;
    constexpr std::uint32_t lc_prebound_dylib = 0x10;
    constexpr std::uint32_t lc_load_weak_dylib = 0x80000018U;
    constexpr std::uint32_t lc_reexport_dylib = 0x8000001fU;
    constexpr std::uint32_t lc_lazy_load_dylib = 0x20;
    constexpr std::uint32_t lc_load_upward_dylib = 0x80000023U;
    constexpr std::uint32_t lc_code_signature = 0x1d;
    constexpr std::uint32_t lc_uuid = 0x1b;
    constexpr std::uint32_t lc_function_starts = 0x26;
    constexpr std::uint32_t lc_main = 0x80000028U;
    constexpr std::uint32_t arm_thread_state = 1;
    constexpr std::uint32_t section_type_mask = 0xff;
    constexpr std::uint32_t s_symbol_stubs = 0x8;
    constexpr std::uint32_t indirect_symbol_local = 0x80000000U;
    constexpr std::uint32_t indirect_symbol_abs = 0x40000000U;
    constexpr std::uint32_t code_signature_super_blob_magic = 0xfade0cc0U;
    constexpr std::uint32_t code_signature_entitlements_magic = 0xfade7171U;
    constexpr std::uint32_t code_signature_entitlements_slot = 5U;
    constexpr std::size_t maximum_function_starts = 65'536U;

    std::uint32_t read_u32(std::span<const std::byte> bytes, std::size_t offset)
    {
        if (offset > bytes.size() || bytes.size() - offset < 4) {
            throw std::runtime_error { "truncated Mach-O integer" };
        }
        return std::to_integer<std::uint32_t>(bytes[offset]) |
               (std::to_integer<std::uint32_t>(bytes[offset + 1]) << 8U) |
               (std::to_integer<std::uint32_t>(bytes[offset + 2]) << 16U) |
               (std::to_integer<std::uint32_t>(bytes[offset + 3]) << 24U);
    }

    std::int32_t read_i32(std::span<const std::byte> bytes, std::size_t offset)
    {
        return static_cast<std::int32_t>(read_u32(bytes, offset));
    }

    std::uint64_t read_u64(std::span<const std::byte> bytes, std::size_t offset)
    {
        return static_cast<std::uint64_t>(read_u32(bytes, offset)) |
               (static_cast<std::uint64_t>(read_u32(bytes, offset + 4U))
                   << 32U);
    }

    std::optional<std::uint32_t> read_be_u32(
        std::span<const std::byte> bytes, std::size_t offset)
    {
        if (offset > bytes.size() || bytes.size() - offset < 4U)
            return std::nullopt;
        return (std::to_integer<std::uint32_t>(bytes[offset]) << 24U) |
               (std::to_integer<std::uint32_t>(bytes[offset + 1U]) << 16U) |
               (std::to_integer<std::uint32_t>(bytes[offset + 2U]) << 8U) |
               std::to_integer<std::uint32_t>(bytes[offset + 3U]);
    }

    std::vector<std::byte> extract_code_signature_entitlements(
        std::span<const std::byte> image, std::uint32_t signature_offset,
        std::uint32_t signature_size)
    {
        constexpr std::size_t super_blob_header_size = 12U;
        constexpr std::size_t blob_index_size = 8U;
        constexpr std::size_t generic_blob_header_size = 8U;
        if (signature_offset > image.size() ||
            signature_size > image.size() - signature_offset)
            return { };
        const auto signature = image.subspan(signature_offset, signature_size);
        const auto magic = read_be_u32(signature, 0U);
        const auto encoded_size = read_be_u32(signature, 4U);
        const auto blob_count = read_be_u32(signature, 8U);
        if (!magic || !encoded_size || !blob_count ||
            *magic != code_signature_super_blob_magic ||
            *encoded_size < super_blob_header_size ||
            *encoded_size > signature.size() ||
            *blob_count >
                (*encoded_size - super_blob_header_size) / blob_index_size) {
            return { };
        }
        const auto super_blob = signature.first(*encoded_size);
        for (std::uint32_t index = 0; index < *blob_count; ++index) {
            const auto entry_offset =
                super_blob_header_size + index * blob_index_size;
            const auto type = read_be_u32(super_blob, entry_offset);
            const auto blob_offset = read_be_u32(super_blob, entry_offset + 4U);
            if (!type || !blob_offset ||
                *type != code_signature_entitlements_slot) {
                continue;
            }
            const auto blob_header_offset =
                static_cast<std::size_t>(*blob_offset);
            const auto blob_magic = read_be_u32(super_blob, blob_header_offset);
            const auto blob_size =
                read_be_u32(super_blob, blob_header_offset + 4U);
            if (!blob_magic || !blob_size ||
                *blob_magic != code_signature_entitlements_magic ||
                *blob_size < generic_blob_header_size ||
                blob_header_offset > super_blob.size() ||
                *blob_size > super_blob.size() - blob_header_offset) {
                return { };
            }
            const auto payload = super_blob.subspan(
                blob_header_offset + generic_blob_header_size,
                *blob_size - generic_blob_header_size);
            return { payload.begin(), payload.end() };
        }
        return { };
    }

    std::optional<std::size_t> vm_file_offset(
        std::span<const MachSegment> segments, std::uint32_t address,
        std::size_t required_size)
    {
        for (const auto& segment : segments) {
            if (address < segment.vm_address ||
                address - segment.vm_address >= segment.file_size) {
                continue;
            }
            const auto delta = address - segment.vm_address;
            if (required_size > segment.file_size - delta)
                return std::nullopt;
            return static_cast<std::size_t>(segment.file_offset) + delta;
        }
        return std::nullopt;
    }

    std::optional<std::uint32_t> vm_address_for_file_offset(
        std::span<const MachSegment> segments, std::uint64_t file_offset)
    {
        for (const auto& segment : segments) {
            const auto segment_file_offset =
                static_cast<std::uint64_t>(segment.file_offset);
            const auto segment_file_size =
                static_cast<std::uint64_t>(segment.file_size);
            if (file_offset < segment_file_offset ||
                file_offset - segment_file_offset >= segment_file_size) {
                continue;
            }
            const auto address =
                static_cast<std::uint64_t>(segment.vm_address) +
                file_offset - segment_file_offset;
            if (address > std::numeric_limits<std::uint32_t>::max())
                return std::nullopt;
            return static_cast<std::uint32_t>(address);
        }
        return std::nullopt;
    }

    std::optional<std::string_view> vm_c_string(
        std::span<const std::byte> bytes, std::span<const MachSegment> segments,
        std::uint32_t address)
    {
        const auto offset = vm_file_offset(segments, address, 1U);
        if (!offset || *offset >= bytes.size())
            return std::nullopt;
        auto end = *offset;
        while (end < bytes.size() && bytes[end] != std::byte { 0 })
            ++end;
        if (end == bytes.size())
            return std::nullopt;
        return std::string_view {
            reinterpret_cast<const char*>(bytes.data() + *offset), end - *offset
        };
    }

    std::string fixed_string(std::span<const std::byte> bytes,
        std::size_t offset, std::size_t length)
    {
        if (offset > bytes.size() || bytes.size() - offset < length) {
            throw std::runtime_error { "truncated Mach-O string" };
        }
        std::size_t actual = 0;
        while (actual < length && bytes[offset + actual] != std::byte { 0 }) {
            ++actual;
        }
        return std::string {
            reinterpret_cast<const char*>(bytes.data() + offset), actual
        };
    }

    std::string command_string(std::span<const std::byte> bytes,
        std::size_t command_offset, std::uint32_t command_size,
        std::uint32_t string_offset)
    {
        if (string_offset >= command_size) {
            throw std::runtime_error {
                "invalid Mach-O load-command string offset"
            };
        }
        const auto start = command_offset + string_offset;
        const auto end = command_offset + command_size;
        std::size_t cursor = start;
        while (cursor < end && bytes[cursor] != std::byte { 0 }) {
            ++cursor;
        }
        if (cursor == end) {
            throw std::runtime_error {
                "unterminated Mach-O load-command string"
            };
        }
        return std::string {
            reinterpret_cast<const char*>(bytes.data() + start), cursor - start
        };
    }

    std::string table_string(std::span<const std::byte> bytes,
        std::uint32_t table_offset, std::uint32_t table_size,
        std::uint32_t string_offset)
    {
        if (string_offset >= table_size || table_offset > bytes.size() ||
            table_size > bytes.size() - table_offset) {
            throw std::runtime_error { "invalid Mach-O string-table offset" };
        }
        const auto start =
            static_cast<std::size_t>(table_offset) + string_offset;
        const auto end = static_cast<std::size_t>(table_offset) + table_size;
        std::size_t cursor = start;
        while (cursor < end && bytes[cursor] != std::byte { 0 }) {
            ++cursor;
        }
        if (cursor == end) {
            throw std::runtime_error { "unterminated Mach-O symbol name" };
        }
        return std::string {
            reinterpret_cast<const char*>(bytes.data() + start), cursor - start
        };
    }

    bool is_dylib_command(std::uint32_t command)
    {
        return command == lc_load_dylib || command == lc_id_dylib ||
               command == lc_load_weak_dylib || command == lc_reexport_dylib ||
               command == lc_lazy_load_dylib || command == lc_load_upward_dylib;
    }

    MemoryPermission vm_protection(std::int32_t protection)
    {
        MemoryPermission result = MemoryPermission::None;
        if ((protection & 1) != 0)
            result |= MemoryPermission::Read;
        if ((protection & 2) != 0)
            result |= MemoryPermission::Write;
        if ((protection & 4) != 0)
            result |= MemoryPermission::Execute;
        return result;
    }

    std::uint32_t align_down(std::uint32_t value)
    {
        return value & ~(AddressSpace::page_size - 1U);
    }

    std::uint32_t align_up(std::uint64_t value)
    {
        const auto aligned =
            (value + AddressSpace::page_size - 1U) &
            ~(static_cast<std::uint64_t>(AddressSpace::page_size) - 1U);
        if (aligned > std::numeric_limits<std::uint32_t>::max()) {
            throw std::runtime_error {
                "Mach-O mapping exceeds 32-bit address space"
            };
        }
        return static_cast<std::uint32_t>(aligned);
    }

    void decode_function_starts(std::span<const std::byte> bytes,
        std::uint32_t data_offset, std::uint32_t data_size,
        std::span<const MachSegment> segments,
        std::vector<std::uint32_t>& starts)
    {
        if (data_offset > bytes.size() ||
            data_size > bytes.size() - data_offset) {
            return;
        }

        std::optional<std::uint32_t> text_address;
        for (const auto& segment : segments) {
            if (segment.name == "__TEXT") {
                text_address = segment.vm_address;
                break;
            }
        }
        if (!text_address && !segments.empty()) {
            text_address = segments.front().vm_address;
        }
        if (!text_address)
            return;

        const auto data_end = static_cast<std::size_t>(data_offset) + data_size;
        std::size_t cursor = data_offset;
        std::uint64_t address = *text_address;
        std::vector<std::uint32_t> decoded;
        decoded.reserve(
            std::min<std::size_t>(data_size, maximum_function_starts));
        bool terminated = false;
        while (cursor < data_end && decoded.size() < maximum_function_starts) {
            std::uint64_t delta = 0;
            bool complete = false;
            for (unsigned byte_index = 0; byte_index < 10U && cursor < data_end;
                ++byte_index) {
                const auto value =
                    std::to_integer<std::uint8_t>(bytes[cursor++]);
                const auto payload = static_cast<std::uint64_t>(value & 0x7fU);
                if (byte_index == 9U && payload > 1U)
                    return;
                delta |= payload << (byte_index * 7U);
                if ((value & 0x80U) == 0U) {
                    complete = true;
                    break;
                }
                if (byte_index == 9U)
                    return;
            }
            if (!complete)
                return;
            if (delta == 0U) {
                terminated = true;
                break;
            }
            if (address > std::numeric_limits<std::uint32_t>::max() - delta) {
                return;
            }
            address += delta;
            decoded.push_back(static_cast<std::uint32_t>(address));
        }
        // The cap itself is a valid bounded result: once the maximum trusted
        // starts are decoded, do not scan an untrusted tail merely to find its
        // terminator.
        if (!terminated && decoded.size() != maximum_function_starts)
            return;
        starts = std::move(decoded);
    }

    struct ScopedFileDescriptor {
        int value { -1 };

        ScopedFileDescriptor() = default;

        ~ScopedFileDescriptor()
        {
            if (value >= 0)
                static_cast<void>(::close(value));
        }

        ScopedFileDescriptor(const ScopedFileDescriptor&) = delete;
        ScopedFileDescriptor& operator=(const ScopedFileDescriptor&) = delete;
    };

    GuestFileGeneration file_generation_from_stat(const struct stat& file_stat)
    {
        return GuestFileGeneration { static_cast<std::uint64_t>(
                                         file_stat.st_dev),
            static_cast<std::uint64_t>(file_stat.st_ino),
            static_cast<std::uint64_t>(file_stat.st_size),
            static_cast<std::int64_t>(file_stat.st_mtim.tv_sec),
            static_cast<std::int64_t>(file_stat.st_mtim.tv_nsec),
            static_cast<std::int64_t>(file_stat.st_ctim.tv_sec),
            static_cast<std::int64_t>(file_stat.st_ctim.tv_nsec) };
    }

} // namespace

MachOImage MachOImage::parse(const std::filesystem::path& path,
    ArmArchitectureVersion architecture,
    std::optional<ContentIdentity> known_identity,
    ImmutableSnapshotKind snapshot_kind,
    std::optional<std::uint64_t> image_header_offset,
    std::shared_ptr<const std::vector<std::byte>> immutable_snapshot,
    std::optional<GuestFileGeneration> known_generation,
    std::shared_ptr<const ImmutableFileView> immutable_file_view)
{
    MachOImage image;
    image.path_ = path;
    std::shared_ptr<const std::vector<std::byte>> image_bytes =
        std::move(immutable_snapshot);
    image.immutable_file_view_ = std::move(immutable_file_view);
    if (image.immutable_file_view_) {
        if (!known_identity || !known_generation ||
            image.immutable_file_view_->content_identity() != *known_identity ||
            image.immutable_file_view_->generation() != *known_generation) {
            throw std::runtime_error { "immutable Mach-O file view requires "
                                       "matching identity and generation" };
        }
        image.file_generation_ = *known_generation;
    } else if (image_bytes) {
        if (!known_identity || !known_generation) {
            throw std::runtime_error {
                "immutable Mach-O snapshot requires identity and generation"
            };
        }
        image.file_generation_ = *known_generation;
    }

    ScopedFileDescriptor input;
    if (!image_bytes && !image.immutable_file_view_) {
        do {
            input.value = ::open(path.c_str(), O_RDONLY | O_CLOEXEC);
        } while (input.value < 0 && errno == EINTR);
        if (input.value < 0) {
            throw std::runtime_error { "cannot open Mach-O: " + path.string() };
        }
        struct stat file_stat { };
        if (::fstat(input.value, &file_stat) != 0 ||
            !S_ISREG(file_stat.st_mode) || file_stat.st_size < 0 ||
            static_cast<std::uintmax_t>(file_stat.st_size) >
                std::numeric_limits<std::size_t>::max()) {
            throw std::runtime_error { "cannot determine Mach-O size: " +
                                       path.string() };
        }
        image.file_generation_ = file_generation_from_stat(file_stat);
        if (known_identity) {
            image_bytes = find_immutable_snapshot(*image.file_generation_,
                *known_identity, static_cast<std::uint64_t>(file_stat.st_size),
                static_cast<std::uint64_t>(architecture), snapshot_kind);
        }
        if (!image_bytes) {
            auto loaded_bytes = std::make_shared<std::vector<std::byte>>(
                static_cast<std::size_t>(file_stat.st_size));
            std::size_t received = 0;
            while (received < loaded_bytes->size()) {
                const auto remaining = loaded_bytes->size() - received;
                const auto requested =
                    std::min<std::size_t>(remaining, 64U * 1024U);
                ssize_t count = -1;
                do {
                    count =
                        ::pread(input.value, loaded_bytes->data() + received,
                            requested, static_cast<off_t>(received));
                } while (count < 0 && errno == EINTR);
                if (count <= 0) {
                    throw std::runtime_error { "failed to read Mach-O: " +
                                               path.string() };
                }
                received += static_cast<std::size_t>(count);
            }
            image_bytes = std::move(loaded_bytes);
        }
        struct stat final_file_stat { };
        if (::fstat(input.value, &final_file_stat) != 0 ||
            file_generation_from_stat(final_file_stat) !=
                *image.file_generation_) {
            throw std::runtime_error { "Mach-O changed while reading: " +
                                       path.string() };
        }
    }

    const auto header_offset = image_header_offset.value_or(0U);
    const auto source_bytes = image.immutable_file_view_
                                  ? image.immutable_file_view_->bytes()
                                  : std::span<const std::byte> { *image_bytes };
    if (header_offset > source_bytes.size() ||
        source_bytes.size() - static_cast<std::size_t>(header_offset) < 28U) {
        throw std::runtime_error {
            "Mach-O header offset is outside the file: " + path.string()
        };
    }
    if (image_header_offset &&
        *image_header_offset > std::numeric_limits<std::uint32_t>::max()) {
        throw std::runtime_error {
            "shared-cache Mach-O header offset exceeds 32-bit file offsets"
        };
    }

    // App bundles may carry a classic FAT container. Select the best slice for
    // the guest architecture instead of making each caller know how to unpack
    // it; ARMv7 remains compatible with an ARMv6 slice when no v7 slice exists.
    // A shared-cache image is already an ARM slice inside a larger container,
    // so its header offset must remain absolute and FAT selection is skipped.
    const std::span<const std::byte> container = source_bytes;
    // ContentIdentity names the bytes on disk, not the architecture-specific
    // view selected below.  The watcher and file identity cache hash the
    // complete container, so using the same identity here is required for
    // cold catalog scans, loader lookups, and hot refreshes to agree.  FAT
    // images always compute this value locally because a caller-provided
    // identity from an older catalog may have named only a selected slice.
    const auto container_magic = read_be_u32(container, 0U);
    const bool fat_container =
        !image_header_offset.has_value() && container_magic == fat_magic;
    if (fat_container && image.immutable_file_view_) {
        throw std::runtime_error {
            "FAT Mach-O cannot use a shared cache file view"
        };
    }
    const ContentIdentity container_identity =
        known_identity && !fat_container ? *known_identity : sha256(container);
    if (fat_container) {
        image.fat_container_ = true;
        const auto architecture_count = read_be_u32(container, 4U);
        constexpr std::size_t fat_arch_size = 20U;
        if (container.size() < 8U || !architecture_count ||
            *architecture_count > (container.size() - 8U) / fat_arch_size) {
            throw std::runtime_error { "truncated FAT Mach-O header" };
        }
        const auto requested_subtype =
            architecture == ArmArchitectureVersion::Armv7 ? cpu_subtype_arm_v7
                                                          : cpu_subtype_arm_v6;
        std::optional<std::pair<std::uint32_t, std::uint32_t>> selected;
        std::optional<std::pair<std::uint32_t, std::uint32_t>> compatible;
        std::optional<std::pair<std::uint32_t, std::uint32_t>> fallback;
        for (std::uint32_t index = 0; index < *architecture_count; ++index) {
            const auto offset =
                8U + static_cast<std::size_t>(index) * fat_arch_size;
            const auto fat_architecture = read_be_u32(container, offset);
            const auto subtype = read_be_u32(container, offset + 4U);
            const auto slice_offset = read_be_u32(container, offset + 8U);
            const auto slice_size = read_be_u32(container, offset + 12U);
            if (!fat_architecture || !subtype || !slice_offset || !slice_size ||
                *fat_architecture != cpu_type_arm ||
                *slice_offset > container.size() ||
                *slice_size > container.size() - *slice_offset) {
                continue;
            }
            if ((*subtype & 0xffU) == requested_subtype) {
                selected = std::pair { *slice_offset, *slice_size };
                break;
            }
            if (architecture == ArmArchitectureVersion::Armv7 &&
                (*subtype & 0xffU) == cpu_subtype_arm_v6 && !compatible) {
                compatible = std::pair { *slice_offset, *slice_size };
            }
            if ((*subtype & 0xffU) == 0U && !fallback)
                fallback = std::pair { *slice_offset, *slice_size };
        }
        if (!selected)
            selected = compatible ? compatible : fallback;
        if (!selected) {
            throw std::runtime_error {
                "FAT Mach-O has no compatible 32-bit ARM slice"
            };
        }
        const auto [slice_offset, slice_size] = *selected;
        image_bytes = std::make_shared<std::vector<std::byte>>(
            image_bytes->begin() + static_cast<std::ptrdiff_t>(slice_offset),
            image_bytes->begin() +
                static_cast<std::ptrdiff_t>(slice_offset + slice_size));
    }

    image.bytes_ = std::move(image_bytes);
    image.content_identity_ = container_identity;
    if (image.file_generation_ && image.bytes_) {
        if (!image.fat_container_) {
            image.bytes_ = share_immutable_snapshot(*image.file_generation_,
                image.content_identity_, image.bytes_,
                static_cast<std::uint64_t>(architecture), snapshot_kind);
        }
        seed_shared_file_identity(
            path, *image.file_generation_, image.content_identity_);
    }
    // share_immutable_snapshot may return an older shared_ptr held by another
    // parser. Rebind the span after that publication so it can never retain a
    // pointer into a replaced vector.
    const auto bytes = image.byte_span();
    if (read_u32(bytes, static_cast<std::size_t>(header_offset)) != mh_magic) {
        throw std::runtime_error { "expected a little-endian 32-bit Mach-O: " +
                                   path.string() };
    }
    const auto header = static_cast<std::size_t>(header_offset);
    image.cpu_type_ = read_u32(bytes, header + 4U);
    image.cpu_subtype_ = read_u32(bytes, header + 8U);
    image.file_type_ = read_u32(bytes, header + 12U);
    image.command_count_ = read_u32(bytes, header + 16U);
    const auto command_bytes = read_u32(bytes, header + 20U);
    image.flags_ = read_u32(bytes, header + 24U);
    if (image.cpu_type_ != cpu_type_arm) {
        throw std::runtime_error {
            "only 32-bit ARM Mach-O images are supported"
        };
    }
    if (command_bytes > bytes.size() - header - 28U) {
        throw std::runtime_error { "Mach-O load command area is truncated" };
    }

    std::size_t offset = header + 28U;
    const auto commands_end = offset + command_bytes;
    std::optional<std::pair<std::uint32_t, std::uint32_t>> indirect_symbols;
    std::optional<std::pair<std::uint32_t, std::uint32_t>> code_signature;
    std::optional<std::pair<std::uint32_t, std::uint32_t>> function_starts;
    std::optional<std::uint64_t> main_entry_offset;
    std::set<std::uint32_t> known_generic {
        0x2,
        0x3,
        0x6,
        0x7,
        0x8,
        0x9,
        0xa,
        0xb,
        0x11,
        0x12,
        0x13,
        0x14,
        0x15,
        0x16,
        0x17,
        0x19,
        0x1a,
        0x1b,
        0x1d,
        0x1e,
        0x21,
        0x80000022U,
        0x24,
        0x25,
        0x26,
        0x29,
        0x2a,
        0x2b,
        0x2c,
        0x2d,
        0x2e,
        0x2f,
        0x30,
        0x31,
        0x32,
        0x80000033U,
        0x34,
        0x35,
    };

    for (std::uint32_t index = 0; index < image.command_count_; ++index) {
        if (offset > commands_end || commands_end - offset < 8) {
            throw std::runtime_error { "truncated Mach-O load command header" };
        }
        const auto command = read_u32(bytes, offset);
        const auto command_size = read_u32(bytes, offset + 4);
        if (command_size < 8 || command_size > commands_end - offset) {
            throw std::runtime_error { "invalid Mach-O load command size" };
        }

        if (command == lc_segment) {
            if (command_size < 56) {
                throw std::runtime_error { "truncated LC_SEGMENT" };
            }
            MachSegment segment;
            segment.name = fixed_string(bytes, offset + 8, 16);
            segment.vm_address = read_u32(bytes, offset + 24);
            segment.vm_size = read_u32(bytes, offset + 28);
            segment.file_offset = read_u32(bytes, offset + 32);
            segment.file_size = read_u32(bytes, offset + 36);
            segment.max_protection = read_i32(bytes, offset + 40);
            segment.initial_protection = read_i32(bytes, offset + 44);
            const auto section_count = read_u32(bytes, offset + 48);
            segment.flags = read_u32(bytes, offset + 52);
            if (section_count > (command_size - 56) / 68) {
                throw std::runtime_error {
                    "LC_SEGMENT section array is truncated"
                };
            }
            for (std::uint32_t section_index = 0; section_index < section_count;
                ++section_index) {
                const auto section_offset = offset + 56 + section_index * 68;
                MachSection section;
                section.name = fixed_string(bytes, section_offset, 16);
                section.segment = fixed_string(bytes, section_offset + 16, 16);
                section.address = read_u32(bytes, section_offset + 32);
                section.size = read_u32(bytes, section_offset + 36);
                section.file_offset = read_u32(bytes, section_offset + 40);
                section.flags = read_u32(bytes, section_offset + 56);
                section.reserved1 = read_u32(bytes, section_offset + 60);
                section.reserved2 = read_u32(bytes, section_offset + 64);
                segment.sections.push_back(std::move(section));
            }
            if (image_header_offset && segment.name == "__TEXT") {
                const auto header_offset_32 =
                    static_cast<std::uint32_t>(*image_header_offset);
                if (segment.file_offset >
                    std::numeric_limits<std::uint32_t>::max() -
                        header_offset_32) {
                    throw std::runtime_error {
                        "shared-cache __TEXT file offset overflows"
                    };
                }
                segment.file_offset += header_offset_32;
                for (auto& section : segment.sections) {
                    if (section.file_offset >
                        std::numeric_limits<std::uint32_t>::max() -
                            header_offset_32) {
                        throw std::runtime_error {
                            "shared-cache __TEXT section offset overflows"
                        };
                    }
                    section.file_offset += header_offset_32;
                }
            }
            image.segments_.push_back(std::move(segment));
        } else if (command == lc_symtab) {
            if (command_size < 24) {
                throw std::runtime_error { "truncated LC_SYMTAB" };
            }
            const auto symbol_offset = read_u32(bytes, offset + 8);
            const auto symbol_count = read_u32(bytes, offset + 12);
            const auto string_offset = read_u32(bytes, offset + 16);
            const auto string_size = read_u32(bytes, offset + 20);
            const auto symbol_bytes =
                static_cast<std::uint64_t>(symbol_count) * 12U;
            if (symbol_offset > bytes.size() ||
                symbol_bytes > bytes.size() - symbol_offset ||
                string_offset > bytes.size() ||
                string_size > bytes.size() - string_offset) {
                throw std::runtime_error {
                    "LC_SYMTAB points outside the Mach-O"
                };
            }
            image.symbols_.reserve(symbol_count);
            for (std::uint32_t symbol_index = 0; symbol_index < symbol_count;
                ++symbol_index) {
                const auto symbol = static_cast<std::size_t>(symbol_offset) +
                                    symbol_index * 12U;
                const auto name_offset = read_u32(bytes, symbol);
                MachSymbol result;
                if (name_offset != 0) {
                    result.name = table_string(
                        bytes, string_offset, string_size, name_offset);
                }
                result.type = std::to_integer<std::uint8_t>(bytes[symbol + 4]);
                result.section =
                    std::to_integer<std::uint8_t>(bytes[symbol + 5]);
                result.description = static_cast<std::uint16_t>(
                    std::to_integer<std::uint16_t>(bytes[symbol + 6]) |
                    (std::to_integer<std::uint16_t>(bytes[symbol + 7]) << 8U));
                result.value = read_u32(bytes, symbol + 8);
                image.symbols_.push_back(std::move(result));
            }
        } else if (command == lc_dysymtab) {
            if (command_size < 80) {
                throw std::runtime_error { "truncated LC_DYSYMTAB" };
            }
            indirect_symbols = std::pair { read_u32(bytes, offset + 56),
                read_u32(bytes, offset + 60) };
        } else if (command == lc_thread || command == lc_unixthread) {
            std::size_t cursor = offset + 8;
            const auto end_offset = offset + command_size;
            while (cursor + 8 <= end_offset) {
                const auto flavor = read_u32(bytes, cursor);
                const auto count = read_u32(bytes, cursor + 4);
                cursor += 8;
                const auto state_bytes = static_cast<std::uint64_t>(count) * 4U;
                if (state_bytes > end_offset - cursor) {
                    throw std::runtime_error {
                        "truncated LC_UNIXTHREAD state"
                    };
                }
                if (flavor == arm_thread_state && count >= 17) {
                    image.entry_point_ = read_u32(bytes, cursor + 15 * 4U);
                }
                cursor += static_cast<std::size_t>(state_bytes);
            }
        } else if (command == lc_main) {
            if (command_size < 24U) {
                throw std::runtime_error { "truncated LC_MAIN" };
            }
            main_entry_offset = read_u64(bytes, offset + 8U);
        } else if (is_dylib_command(command)) {
            if (command_size < 24) {
                throw std::runtime_error { "truncated dylib load command" };
            }
            image.dylibs_.push_back(
                MachDylib { command_string(bytes, offset, command_size,
                                read_u32(bytes, offset + 8)),
                    command, false,
                    MachDylibVersion { read_u32(bytes, offset + 16),
                        read_u32(bytes, offset + 20) } });
        } else if (command == lc_prebound_dylib) {
            if (command_size < 20) {
                throw std::runtime_error { "truncated LC_PREBOUND_DYLIB" };
            }
            image.dylibs_.push_back(
                MachDylib { command_string(bytes, offset, command_size,
                                read_u32(bytes, offset + 8)),
                    command, true, std::nullopt });
        } else if (command == lc_load_dylinker || command == lc_id_dylinker) {
            if (command_size < 12) {
                throw std::runtime_error { "truncated dylinker load command" };
            }
            image.dynamic_linker_ = command_string(
                bytes, offset, command_size, read_u32(bytes, offset + 8));
        } else if (command == lc_code_signature) {
            if (command_size < 16U) {
                throw std::runtime_error { "truncated LC_CODE_SIGNATURE" };
            }
            code_signature = std::pair { read_u32(bytes, offset + 8U),
                read_u32(bytes, offset + 12U) };
        } else if (command == lc_function_starts) {
            if (command_size < 16U) {
                throw std::runtime_error { "truncated LC_FUNCTION_STARTS" };
            }
            function_starts = std::pair { read_u32(bytes, offset + 8U),
                read_u32(bytes, offset + 12U) };
        } else if (command == lc_uuid) {
            if (command_size < 24U) {
                throw std::runtime_error { "truncated LC_UUID" };
            }
            std::array<std::byte, 16> uuid { };
            std::copy_n(
                bytes.begin() + static_cast<std::ptrdiff_t>(offset + 8U),
                uuid.size(), uuid.begin());
            image.uuid_ = uuid;
        } else if (!known_generic.contains(command)) {
            image.unknown_commands_.push_back(command);
        }
        offset += command_size;
    }
    if (offset != commands_end) {
        throw std::runtime_error {
            "Mach-O load command sizes do not match sizeofcmds"
        };
    }
    if (main_entry_offset) {
        const auto entry_point = vm_address_for_file_offset(
            image.segments_, *main_entry_offset);
        if (!entry_point) {
            throw std::runtime_error {
                "LC_MAIN entryoff is outside a file-backed segment"
            };
        }
        image.entry_point_ = *entry_point;
    }
    if (function_starts) {
        decode_function_starts(bytes, function_starts->first,
            function_starts->second, image.segments_, image.function_starts_);
    }
    if (indirect_symbols) {
        const auto [table_offset, table_count] = *indirect_symbols;
        const auto table_bytes = static_cast<std::uint64_t>(table_count) * 4U;
        if (table_offset > bytes.size() ||
            table_bytes > bytes.size() - table_offset) {
            throw std::runtime_error {
                "LC_DYSYMTAB indirect table points outside the Mach-O"
            };
        }
        for (const auto& segment : image.segments_) {
            for (const auto& section : segment.sections) {
                if ((section.flags & section_type_mask) != s_symbol_stubs ||
                    section.reserved2 == 0) {
                    continue;
                }
                const auto stub_count = section.size / section.reserved2;
                if (section.reserved1 > table_count ||
                    stub_count > table_count - section.reserved1) {
                    throw std::runtime_error {
                        "symbol stub section exceeds indirect symbol table"
                    };
                }
                for (std::uint32_t stub_index = 0; stub_index < stub_count;
                    ++stub_index) {
                    const auto indirect_index = read_u32(bytes,
                        table_offset + (section.reserved1 + stub_index) * 4U);
                    if ((indirect_index & (indirect_symbol_local |
                                              indirect_symbol_abs)) != 0 ||
                        indirect_index >= image.symbols_.size()) {
                        continue;
                    }
                    image.stubs_.push_back(MachStub {
                        section.address + stub_index * section.reserved2,
                        section.reserved2,
                        image.symbols_[indirect_index].name });
                }
            }
        }
    }
    if (code_signature) {
        image.code_signature_entitlements_ =
            extract_code_signature_entitlements(
                bytes, code_signature->first, code_signature->second);
    }
    image.symbol_file_locations_.reserve(image.symbols_.size());
    for (std::size_t index = 0; index < image.symbols_.size(); ++index) {
        const auto& symbol = image.symbols_[index];
        if (symbol.value == 0U)
            continue;
        const auto segment = std::find_if(image.segments_.begin(),
            image.segments_.end(), [&](const MachSegment& candidate) {
                return symbol.value >= candidate.vm_address &&
                       symbol.value - candidate.vm_address <
                           candidate.file_size;
            });
        if (segment == image.segments_.end())
            continue;
        image.symbol_file_locations_.push_back(
            MachSymbolFileLocation { static_cast<std::uint32_t>(index),
                static_cast<std::uint64_t>(segment->file_offset) +
                    (symbol.value - segment->vm_address) });
    }
    std::sort(image.symbol_file_locations_.begin(),
        image.symbol_file_locations_.end(),
        [](const MachSymbolFileLocation& left,
            const MachSymbolFileLocation& right) {
            if (left.file_offset != right.file_offset)
                return left.file_offset < right.file_offset;
            return left.symbol_index < right.symbol_index;
        });
    return image;
}

std::span<const std::byte> MachOImage::byte_span() const noexcept
{
    if (bytes_)
        return *bytes_;
    if (immutable_file_view_)
        return immutable_file_view_->bytes();
    return { };
}

const MachDylib* MachOImage::dylib_identity() const
{
    for (const auto& dylib : dylibs_) {
        if (dylib.command == lc_id_dylib)
            return &dylib;
    }
    return nullptr;
}

const MachSymbol* MachOImage::find_symbol(std::string_view name) const
{
    const auto it = std::find_if(symbols_.begin(), symbols_.end(),
        [name](const MachSymbol& symbol) { return symbol.name == name; });
    return it == symbols_.end() ? nullptr : &*it;
}

const MachStub* MachOImage::find_stub(std::uint32_t address) const
{
    const auto it = std::find_if(
        stubs_.begin(), stubs_.end(), [address](const MachStub& stub) {
            return address >= stub.address &&
                   address - stub.address < stub.size;
        });
    return it == stubs_.end() ? nullptr : &*it;
}

std::optional<std::uint32_t> MachOImage::read_vm_u32(
    std::uint32_t address) const
{
    for (const auto& segment : segments_) {
        if (address < segment.vm_address ||
            address - segment.vm_address > segment.file_size ||
            segment.file_size - (address - segment.vm_address) < 4) {
            continue;
        }
        const auto offset = static_cast<std::size_t>(segment.file_offset) +
                            (address - segment.vm_address);
        return read_u32(byte_span(), offset);
    }
    return std::nullopt;
}

std::optional<std::uint16_t> MachOImage::read_vm_u16(
    std::uint32_t address) const
{
    for (const auto& segment : segments_) {
        if (address < segment.vm_address ||
            address - segment.vm_address > segment.file_size ||
            segment.file_size - (address - segment.vm_address) < 2) {
            continue;
        }
        const auto offset = static_cast<std::size_t>(segment.file_offset) +
                            (address - segment.vm_address);
        const auto bytes = byte_span();
        return static_cast<std::uint16_t>(
            std::to_integer<std::uint16_t>(bytes[offset]) |
            (std::to_integer<std::uint16_t>(bytes[offset + 1]) << 8U));
    }
    return std::nullopt;
}

std::optional<std::uint32_t> MachOImage::find_objc_instance_method(
    std::string_view class_name, std::string_view selector,
    VmStringResolver external_string) const
{
    return find_objc_method(class_name, selector, false, external_string);
}

std::optional<std::uint32_t> MachOImage::find_objc_class_method(
    std::string_view class_name, std::string_view selector,
    VmStringResolver external_string) const
{
    return find_objc_method(class_name, selector, true, external_string);
}

std::optional<std::uint32_t> MachOImage::find_objc_method(
    std::string_view class_name, std::string_view selector, bool class_method,
    const VmStringResolver& external_string) const
{
    constexpr std::uint32_t objc1_class_name_offset = 8U;
    constexpr std::uint32_t objc1_class_method_lists_offset = 28U;
    constexpr std::uint32_t objc2_class_data_offset = 16U;
    constexpr std::uint32_t objc2_class_ro_name_offset = 16U;
    constexpr std::uint32_t objc2_class_ro_methods_offset = 20U;
    constexpr std::uint32_t objc2_data_pointer_flags = 0x3U;
    constexpr std::uint32_t objc2_category_class_offset = 4U;
    constexpr std::uint32_t objc2_category_instance_methods_offset = 8U;
    constexpr std::uint32_t objc2_category_class_methods_offset = 12U;
    constexpr std::uint32_t method_list_header_size = 8U;
    constexpr std::uint32_t method_size = 12U;
    constexpr std::uint32_t method_entry_size_mask = 0x0000fffcU;
    constexpr std::uint32_t maximum_method_lists = 4096U;
    constexpr std::uint32_t maximum_methods_per_list = 4096U;

    const auto string_equals = [&](std::uint32_t address,
                                   std::string_view expected) {
        if (const auto local = vm_c_string(byte_span(), segments_, address)) {
            return *local == expected;
        }
        if (!external_string)
            return false;
        const auto external = external_string(address);
        return external && *external == expected;
    };

    const auto executable = [&](std::uint32_t implementation) {
        const auto address = implementation & ~1U;
        return std::any_of(segments_.begin(), segments_.end(),
            [&](const MachSegment& segment) {
                return (segment.initial_protection & 4) != 0 &&
                       address >= segment.vm_address &&
                       address - segment.vm_address < segment.file_size;
            });
    };
    const auto search_list =
        [&](std::uint32_t list,
            std::uint32_t entry_size) -> std::optional<std::uint32_t> {
        if (entry_size < method_size || entry_size > maximum_methods_per_list) {
            return std::nullopt;
        }
        if (list > std::numeric_limits<std::uint32_t>::max() - 4U) {
            return std::nullopt;
        }
        const auto count = read_vm_u32(list + 4U);
        if (!count || *count > maximum_methods_per_list)
            return std::nullopt;
        for (std::uint32_t index = 0; index < *count; ++index) {
            const auto entry64 = static_cast<std::uint64_t>(list) +
                                 method_list_header_size +
                                 static_cast<std::uint64_t>(index) * entry_size;
            if (entry64 > std::numeric_limits<std::uint32_t>::max() - 8U) {
                return std::nullopt;
            }
            const auto entry = static_cast<std::uint32_t>(entry64);
            const auto name = read_vm_u32(entry);
            const auto implementation = read_vm_u32(entry + 8U);
            if (!name || !implementation)
                continue;
            if (string_equals(*name, selector) && executable(*implementation)) {
                return implementation;
            }
        }
        return std::nullopt;
    };
    const auto class_has_name = [&](std::uint32_t object) {
        if (object == 0U || object > std::numeric_limits<std::uint32_t>::max() -
                                         objc2_class_data_offset) {
            return false;
        }
        const auto data = read_vm_u32(object + objc2_class_data_offset);
        if (!data)
            return false;
        const auto class_ro = *data & ~objc2_data_pointer_flags;
        if (class_ro == 0U ||
            class_ro > std::numeric_limits<std::uint32_t>::max() -
                           objc2_class_ro_name_offset) {
            return false;
        }
        const auto name = read_vm_u32(class_ro + objc2_class_ro_name_offset);
        if (!name)
            return false;
        return string_equals(*name, class_name);
    };

    // Objective-C 2 stores pointers to class_t records in a dedicated
    // class-list section. Follow class_t -> class_ro_t -> method_list_t and
    // honor the entry stride published by the runtime metadata.
    for (const auto& segment : segments_) {
        for (const auto& section : segment.sections) {
            if (section.name != "__objc_classlist")
                continue;
            for (std::uint64_t section_offset = 0;
                section_offset + sizeof(std::uint32_t) <= section.size;
                section_offset += sizeof(std::uint32_t)) {
                const auto pointer64 =
                    static_cast<std::uint64_t>(section.address) +
                    section_offset;
                if (pointer64 > std::numeric_limits<std::uint32_t>::max()) {
                    break;
                }
                auto object =
                    read_vm_u32(static_cast<std::uint32_t>(pointer64));
                if (!object || *object == 0U ||
                    *object > std::numeric_limits<std::uint32_t>::max() -
                                  objc2_class_data_offset) {
                    continue;
                }
                if (class_method) {
                    object = read_vm_u32(*object);
                    if (!object || *object == 0U ||
                        *object > std::numeric_limits<std::uint32_t>::max() -
                                      objc2_class_data_offset) {
                        continue;
                    }
                }
                const auto data =
                    read_vm_u32(*object + objc2_class_data_offset);
                if (!data)
                    continue;
                const auto class_ro = *data & ~objc2_data_pointer_flags;
                if (class_ro == 0U ||
                    class_ro > std::numeric_limits<std::uint32_t>::max() -
                                   objc2_class_ro_methods_offset) {
                    continue;
                }
                const auto name =
                    read_vm_u32(class_ro + objc2_class_ro_name_offset);
                if (!name)
                    continue;
                if (!string_equals(*name, class_name))
                    continue;
                const auto methods =
                    read_vm_u32(class_ro + objc2_class_ro_methods_offset);
                if (!methods || *methods == 0U)
                    break;
                const auto entsize_and_flags = read_vm_u32(*methods);
                if (!entsize_and_flags)
                    break;
                const auto entry_size =
                    *entsize_and_flags & method_entry_size_mask;
                if (const auto method = search_list(*methods, entry_size)) {
                    return method;
                }
                break;
            }
        }
    }

    // Objective-C 2 categories carry additional methods outside the class's
    // primary method list.  Framework-private API is commonly published this
    // way, so include category lists in semantic HLE lookup as well.
    for (const auto& segment : segments_) {
        for (const auto& section : segment.sections) {
            if (section.name != "__objc_catlist")
                continue;
            for (std::uint64_t section_offset = 0;
                section_offset + sizeof(std::uint32_t) <= section.size;
                section_offset += sizeof(std::uint32_t)) {
                const auto pointer64 =
                    static_cast<std::uint64_t>(section.address) +
                    section_offset;
                if (pointer64 > std::numeric_limits<std::uint32_t>::max()) {
                    break;
                }
                const auto category =
                    read_vm_u32(static_cast<std::uint32_t>(pointer64));
                if (!category || *category == 0U ||
                    *category > std::numeric_limits<std::uint32_t>::max() -
                                    objc2_category_class_methods_offset) {
                    continue;
                }
                const auto object =
                    read_vm_u32(*category + objc2_category_class_offset);
                if (!object || !class_has_name(*object))
                    continue;
                const auto methods_offset =
                    class_method ? objc2_category_class_methods_offset
                                 : objc2_category_instance_methods_offset;
                const auto methods = read_vm_u32(*category + methods_offset);
                if (!methods || *methods == 0U)
                    continue;
                const auto entsize_and_flags = read_vm_u32(*methods);
                if (!entsize_and_flags)
                    continue;
                const auto entry_size =
                    *entsize_and_flags & method_entry_size_mask;
                if (const auto method = search_list(*methods, entry_size)) {
                    return method;
                }
            }
        }
    }

    for (const auto& segment : segments_) {
        for (const auto& section : segment.sections) {
            if (section.segment != "__OBJC" || section.name != "__class") {
                continue;
            }
            // Objective-C 1 class records retained the offsets used below,
            // but their trailing runtime fields make the total record stride
            // vary between old toolchains. Scan aligned record candidates so
            // semantic lookup does not bake in either the 40- or 48-byte form.
            for (std::uint64_t section_offset = 0;
                section_offset + objc1_class_method_lists_offset +
                    sizeof(std::uint32_t) <=
                section.size;
                section_offset += alignof(std::uint32_t)) {
                const auto object64 =
                    static_cast<std::uint64_t>(section.address) +
                    section_offset;
                if (object64 > std::numeric_limits<std::uint32_t>::max()) {
                    break;
                }
                const auto object = static_cast<std::uint32_t>(object64);
                const auto name = read_vm_u32(object + objc1_class_name_offset);
                if (!name)
                    continue;
                if (!string_equals(*name, class_name))
                    continue;
                const auto method_object =
                    class_method ? read_vm_u32(object)
                                 : std::optional<std::uint32_t> { object };
                if (!method_object || *method_object == 0U ||
                    *method_object > std::numeric_limits<std::uint32_t>::max() -
                                         objc1_class_method_lists_offset) {
                    continue;
                }
                const auto lists = read_vm_u32(
                    *method_object + objc1_class_method_lists_offset);
                if (!lists || *lists == 0U || *lists == 0xffffffffU) {
                    continue;
                }
                // The common Objective-C 1.x form points directly at one
                // method list. Some images instead use a null-terminated array
                // of list pointers; accept both layouts.
                if (const auto direct = search_list(*lists, method_size))
                    return direct;
                for (std::uint32_t list_index = 0;
                    list_index < maximum_method_lists; ++list_index) {
                    const auto pointer_address =
                        static_cast<std::uint64_t>(*lists) +
                        static_cast<std::uint64_t>(list_index) *
                            sizeof(std::uint32_t);
                    if (pointer_address >
                        std::numeric_limits<std::uint32_t>::max()) {
                        break;
                    }
                    const auto pointer = read_vm_u32(
                        static_cast<std::uint32_t>(pointer_address));
                    if (!pointer || *pointer == 0U || *pointer == 0xffffffffU) {
                        break;
                    }
                    if (const auto found = search_list(*pointer, method_size)) {
                        return found;
                    }
                }
                continue;
            }
        }
    }
    return std::nullopt;
}

void MachOImage::map_into(
    AddressSpace& memory, FileMappingBatchContext* batch_context) const
{
    const auto bytes = byte_span();
    for (const auto& segment : segments_) {
        if (segment.vm_size == 0 || segment.name == "__PAGEZERO") {
            continue;
        }
        if (segment.file_size > segment.vm_size ||
            segment.file_offset > bytes.size() ||
            segment.file_size > bytes.size() - segment.file_offset) {
            throw std::runtime_error { "invalid file range in segment " +
                                       segment.name };
        }
        const auto base = align_down(segment.vm_address);
        const auto prefix = segment.vm_address - base;
        const auto mapping_size =
            align_up(static_cast<std::uint64_t>(prefix) + segment.vm_size);
        const auto permissions = vm_protection(segment.initial_protection);

        const auto map_anonymous = [&](std::uint32_t range_start,
                                       std::uint32_t range_end) {
            if (range_start >= range_end)
                return;
            if (!memory.map(
                    range_start, range_end - range_start, permissions)) {
                throw std::runtime_error { "failed to map segment " +
                                           segment.name };
            }

            const auto copy_start =
                std::max<std::uint64_t>(range_start, segment.vm_address);
            const auto copy_end = std::min<std::uint64_t>(
                range_end, static_cast<std::uint64_t>(segment.vm_address) +
                               segment.file_size);
            if (copy_start >= copy_end)
                return;
            const auto file_offset =
                static_cast<std::uint64_t>(segment.file_offset) +
                (copy_start - segment.vm_address);
            const auto copy_size = copy_end - copy_start;
            if (file_offset > bytes.size() ||
                copy_size > bytes.size() - file_offset) {
                throw std::runtime_error { "invalid file range in segment " +
                                           segment.name };
            }
            if (!memory.copy_in(static_cast<std::uint32_t>(copy_start),
                    bytes.subspan(static_cast<std::size_t>(file_offset),
                        static_cast<std::size_t>(copy_size)))) {
                throw std::runtime_error { "failed to populate segment " +
                                           segment.name };
            }
        };

        const bool immutable_executable =
            !fat_container_ && segment.file_size != 0 &&
            has_permission(permissions, MemoryPermission::Execute) &&
            !has_permission(permissions, MemoryPermission::Write) &&
            segment.file_offset % AddressSpace::page_size ==
                segment.vm_address % AddressSpace::page_size;
        const auto mapping_end = base + mapping_size;
        if (!immutable_executable) {
            map_anonymous(base, mapping_end);
        } else {
            const auto file_guest_start =
                (static_cast<std::uint64_t>(segment.vm_address) +
                    AddressSpace::page_size - 1U) &
                ~(static_cast<std::uint64_t>(AddressSpace::page_size) - 1U);
            const auto file_guest_end =
                (static_cast<std::uint64_t>(segment.vm_address) +
                    segment.file_size) &
                ~(static_cast<std::uint64_t>(AddressSpace::page_size) - 1U);
            if (file_guest_end <= file_guest_start ||
                file_guest_start > mapping_end ||
                file_guest_end > mapping_end) {
                map_anonymous(base, mapping_end);
            } else {
                map_anonymous(
                    base, static_cast<std::uint32_t>(file_guest_start));
                const auto file_offset =
                    static_cast<std::uint64_t>(segment.file_offset) +
                    (file_guest_start - segment.vm_address);
                if (!memory.map_file(
                        static_cast<std::uint32_t>(file_guest_start),
                        static_cast<std::uint32_t>(
                            file_guest_end - file_guest_start),
                        permissions, path_, file_offset, file_generation_,
                        content_identity_,
                        batch_context && batch_context->backing
                            ? std::shared_ptr<const std::vector<std::byte>> { }
                            : bytes_,
                        immutable_file_view_, batch_context)) {
                    // File backing is an optimization for immutable text, not
                    // part of the Mach-O loading contract. A transient host
                    // mapping failure must retain the original anonymous-copy
                    // behavior instead of terminating the whole emulator.
                    map_anonymous(static_cast<std::uint32_t>(file_guest_start),
                        static_cast<std::uint32_t>(file_guest_end));
                }
                map_anonymous(
                    static_cast<std::uint32_t>(file_guest_end), mapping_end);
            }
        }
        if (has_permission(permissions, MemoryPermission::Execute)) {
            memory.mark_translation_profile_stable(base, mapping_size);
        }
    }
}

std::string mach_file_type_name(std::uint32_t file_type)
{
    switch (file_type) {
    case 1:
        return "object";
    case 2:
        return "executable";
    case 3:
        return "fixed-vm shared library";
    case 4:
        return "core";
    case 5:
        return "preloaded executable";
    case 6:
        return "dynamic library";
    case 7:
        return "dynamic linker";
    case 8:
        return "bundle";
    default:
        return "type-" + std::to_string(file_type);
    }
}

std::string mach_cpu_name(std::uint32_t cpu_type, std::uint32_t cpu_subtype)
{
    if (cpu_type != cpu_type_arm) {
        return "cpu-" + std::to_string(cpu_type);
    }
    switch (cpu_subtype & 0xffU) {
    case 5:
        return "ARMv4T";
    case 6:
        return "ARMv6";
    case 7:
        return "ARMv5TEJ";
    case 8:
        return "ARM-XScale";
    case 9:
        return "ARMv7";
    default:
        return "ARM-subtype-" + std::to_string(cpu_subtype & 0xffU);
    }
}

} // namespace shade
