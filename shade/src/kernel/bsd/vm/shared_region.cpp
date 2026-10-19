// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Map guest dyld shared regions and apply firmware-provided
// relocation metadata.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/vm/vm_unix.c
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/vm/vm_shared_memory_server.c
// https://github.com/apple-oss-distributions/xnu/blob/xnu-1699.22.73/bsd/vm/vm_unix.c

#include "kernel/kernel.hpp"

#include "../support.hpp"

#include <algorithm>
#include <array>
#include <chrono>
#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <limits>
#include <optional>
#include <string>
#include <system_error>
#include <utility>
#include <vector>

namespace shade {
namespace {

    // The iPhoneOS 1 ARM dyld uses five 32-bit words here.  This differs from
    // xnu's desktop 32-bit ABI, whose mach_vm_* members make the entry 32
    // bytes.  The layout below is confirmed by the firmware dyld's syscall 299
    // call site and matches the ARM split-segment addresses in the system
    // dylibs.
    constexpr std::uint32_t arm_mapping_size = 5U * sizeof(std::uint32_t);
    constexpr std::uint32_t mach_vm_mapping_size =
        (3U * sizeof(std::uint64_t)) + (2U * sizeof(std::uint32_t));
    constexpr std::uint32_t arm_shared_half_size = 0x0800'0000U;
    constexpr std::uint32_t vm_protection_copy_on_write = 0x08U;
    constexpr std::uint32_t vm_protection_zero_fill = 0x10U;
    constexpr std::uint32_t vm_protection_slide = 0x20U;
    constexpr std::uint32_t shared_region_range_size =
        2U * sizeof(std::uint64_t);
    constexpr std::uint32_t map_and_slide_maximum_mapping_count = 8U;
    constexpr std::uint32_t maximum_slide_info_size = 1024U * 1024U;
    constexpr std::uint32_t slide_info_header_size =
        5U * sizeof(std::uint32_t);
    constexpr std::uint32_t slide_bitmap_size =
        AddressSpace::page_size / sizeof(std::uint32_t) / 8U;
    constexpr std::uint32_t maximum_mapping_count =
        (2U * arm_shared_half_size) / AddressSpace::page_size;

    struct Mapping {
        std::uint32_t address { };
        std::uint32_t size { };
        std::uint64_t file_offset { };
        std::uint32_t maximum_protection { };
        std::uint32_t initial_protection { };
    };

    struct AppliedMapping {
        std::uint32_t address { };
        std::uint32_t size { };
    };

    struct SharedRegionRange {
        std::uint32_t address { };
        std::uint32_t end { };
    };

    struct SharedRegionRangeRead {
        std::vector<SharedRegionRange> ranges;
        std::uint32_t error { };
    };

    struct MappingSource {
        std::filesystem::path path;
        std::uint64_t file_offset { };
        std::optional<GuestFileGeneration> expected_generation;
        std::optional<ContentIdentity> expected_content_identity;
        std::shared_ptr<const ImmutableFileView> immutable_file_view;
    };

    struct SlideInfoHeaderV1 {
        std::uint32_t version { };
        std::uint32_t table_offset { };
        std::uint32_t table_count { };
        std::uint32_t entries_offset { };
        std::uint32_t entries_count { };
    };

    enum class MappingLayout {
        Arm32Words,
        MachVm64,
    };

    enum class SharedRegionDiagnosticPhase : std::uint32_t {
        Preflight = 1,
        CacheProbe,
        CacheParse,
        ReadMappings,
        ChooseSlide,
        ResolveSource,
        Map,
        InstallImage,
    };

    class SharedRegionDiagnostics {
    public:
        explicit SharedRegionDiagnostics(std::uint32_t process_id)
            : enabled_ {
                performance_counters().cpu_source_diagnostics_enabled()
            }
            , process_id_ { process_id }
        {
            if (enabled_)
                phase_started_ = std::chrono::steady_clock::now();
        }

        void checkpoint(SharedRegionDiagnosticPhase phase)
        {
            if (!enabled_)
                return;
            const auto now = std::chrono::steady_clock::now();
            record(phase, now - phase_started_);
            phase_started_ = now;
        }

        template <typename Duration>
        void record(SharedRegionDiagnosticPhase phase, Duration elapsed)
        {
            if (!enabled_)
                return;
            const auto nanoseconds =
                std::chrono::duration_cast<std::chrono::nanoseconds>(elapsed);
            performance_counters().record_diagnostic_svc_dispatch(
                PerfDiagnosticSourceKind::SharedRegionPhase, process_id_,
                static_cast<std::uint32_t>(phase),
                static_cast<std::uint64_t>(nanoseconds.count()));
        }

        [[nodiscard]] bool enabled() const { return enabled_; }

    private:
        bool enabled_ { };
        std::uint32_t process_id_ { };
        std::chrono::steady_clock::time_point phase_started_;
    };

    [[nodiscard]] bool add_overflows(std::uint32_t left, std::uint32_t right)
    {
        return right > std::numeric_limits<std::uint32_t>::max() - left;
    }

    [[nodiscard]] bool page_aligned(std::uint64_t value)
    {
        return value % AddressSpace::page_size == 0;
    }

    [[nodiscard]] bool in_arm_shared_region(
        std::uint32_t address, std::uint32_t size, DarwinAddressBounds bounds)
    {
        if (size == 0 || add_overflows(address, size))
            return false;
        const auto end = address + size;
        // XNU validates these mappings against the complete ARM shared-region
        // VM map.  The pmap nesting boundary is an implementation detail, not
        // a forbidden gap: newer unslid caches legitimately have a mapping
        // that crosses the older 0x38000000 nesting boundary.
        return address >= bounds.shared_region_base &&
               end <= bounds.shared_region_end;
    }

    [[nodiscard]] SharedRegionRangeRead read_shared_region_ranges(
        const AddressSpace& memory, std::uint32_t range_count,
        std::uint32_t ranges_address, DarwinAddressBounds bounds)
    {
        const auto maximum_range_count =
            (bounds.shared_region_end - bounds.shared_region_base) /
            AddressSpace::page_size;
        if (range_count > maximum_range_count ||
            (range_count != 0 && ranges_address == 0)) {
            return { { }, bsd_support::invalid_argument };
        }

        std::vector<SharedRegionRange> ranges;
        ranges.reserve(range_count);
        for (std::uint32_t index = 0; index < range_count; ++index) {
            const auto offset =
                static_cast<std::uint64_t>(index) * shared_region_range_size;
            if (offset > std::numeric_limits<std::uint32_t>::max() -
                             ranges_address ||
                ranges_address + static_cast<std::uint32_t>(offset) >
                    std::numeric_limits<std::uint32_t>::max() -
                        shared_region_range_size + 1U) {
                return { { }, bsd_support::bad_address };
            }
            const auto address =
                ranges_address + static_cast<std::uint32_t>(offset);
            const auto range_address = memory.read64(address);
            const auto range_size =
                memory.read64(address + sizeof(std::uint64_t));
            if (!range_address || !range_size) {
                return { { }, bsd_support::bad_address };
            }
            if (*range_address > std::numeric_limits<std::uint32_t>::max() ||
                *range_size > std::numeric_limits<std::uint32_t>::max() ||
                *range_size == 0 || !page_aligned(*range_address) ||
                !page_aligned(*range_size) ||
                !in_arm_shared_region(
                    static_cast<std::uint32_t>(*range_address),
                    static_cast<std::uint32_t>(*range_size), bounds)) {
                return { { }, bsd_support::invalid_argument };
            }
            const auto start = static_cast<std::uint32_t>(*range_address);
            ranges.push_back(
                { start, start + static_cast<std::uint32_t>(*range_size) });
        }

        std::sort(ranges.begin(), ranges.end(),
            [](const SharedRegionRange& left, const SharedRegionRange& right) {
                return left.address < right.address;
            });
        std::vector<SharedRegionRange> merged;
        merged.reserve(ranges.size());
        for (const auto& range : ranges) {
            if (!merged.empty() && range.address <= merged.back().end) {
                merged.back().end = std::max(merged.back().end, range.end);
            } else {
                merged.push_back(range);
            }
        }
        return { std::move(merged), 0 };
    }

    [[nodiscard]] std::vector<SharedRegionRange> ranges_to_release(
        const AddressSpace& memory, const std::vector<SharedRegionRange>& keep,
        DarwinAddressBounds bounds)
    {
        std::vector<SharedRegionRange> release;
        std::size_t keep_index = 0;
        for (std::uint64_t cursor = bounds.shared_region_base;
            cursor < bounds.shared_region_end;) {
            const auto region = memory.mapping_region_at_or_after(
                static_cast<std::uint32_t>(cursor));
            if (!region)
                break;
            const auto mapped_start = std::max<std::uint64_t>(
                cursor, std::max<std::uint64_t>(
                            region->address, bounds.shared_region_base));
            if (mapped_start >= bounds.shared_region_end)
                break;
            const auto mapped_end =
                std::min<std::uint64_t>(region->end, bounds.shared_region_end);
            if (mapped_end <= mapped_start) {
                cursor = std::max<std::uint64_t>(
                    cursor + AddressSpace::page_size, region->end);
                continue;
            }

            while (keep_index < keep.size() &&
                   keep[keep_index].end <= mapped_start)
                ++keep_index;
            auto position = mapped_start;
            for (std::size_t index = keep_index;
                index < keep.size() && keep[index].address < mapped_end;
                ++index) {
                if (keep[index].address > position) {
                    release.push_back({ static_cast<std::uint32_t>(position),
                        static_cast<std::uint32_t>(std::min<std::uint64_t>(
                            keep[index].address, mapped_end)) });
                }
                position = std::max<std::uint64_t>(position, keep[index].end);
                if (position >= mapped_end)
                    break;
            }
            if (position < mapped_end) {
                release.push_back({ static_cast<std::uint32_t>(position),
                    static_cast<std::uint32_t>(mapped_end) });
            }
            cursor = mapped_end;
        }
        return release;
    }

    [[nodiscard]] MemoryPermission permissions(std::uint32_t protection)
    {
        MemoryPermission result = MemoryPermission::None;
        if ((protection & 1U) != 0)
            result |= MemoryPermission::Read;
        if ((protection & 2U) != 0)
            result |= MemoryPermission::Write;
        if ((protection & 4U) != 0)
            result |= MemoryPermission::Execute;
        return result;
    }

    [[nodiscard]] std::optional<Mapping> read_mapping(
        const AddressSpace& memory, std::uint32_t base, std::uint32_t index,
        MappingLayout layout)
    {
        const auto entry_size = layout == MappingLayout::Arm32Words
                                    ? arm_mapping_size
                                    : mach_vm_mapping_size;
        const auto offset = static_cast<std::uint64_t>(index) * entry_size;
        if (offset > std::numeric_limits<std::uint32_t>::max() - base) {
            return std::nullopt;
        }
        const auto address = base + static_cast<std::uint32_t>(offset);
        if (layout == MappingLayout::Arm32Words) {
            const auto mapping_address = memory.read32(address);
            const auto size = memory.read32(address + 4U);
            const auto file_offset = memory.read32(address + 8U);
            const auto maximum_protection = memory.read32(address + 12U);
            const auto initial_protection = memory.read32(address + 16U);
            if (!mapping_address || !size || !file_offset ||
                !maximum_protection || !initial_protection) {
                return std::nullopt;
            }
            return Mapping { *mapping_address, *size, *file_offset,
                *maximum_protection, *initial_protection };
        }

        const auto mapping_address = memory.read64(address);
        const auto size = memory.read64(address + 8U);
        const auto file_offset = memory.read64(address + 16U);
        const auto maximum_protection = memory.read32(address + 24U);
        const auto initial_protection = memory.read32(address + 28U);
        if (!mapping_address || !size || !file_offset || !maximum_protection ||
            !initial_protection ||
            *mapping_address > std::numeric_limits<std::uint32_t>::max() ||
            *size > std::numeric_limits<std::uint32_t>::max()) {
            return std::nullopt;
        }
        return Mapping { static_cast<std::uint32_t>(*mapping_address),
            static_cast<std::uint32_t>(*size), *file_offset,
            *maximum_protection, *initial_protection };
    }

    [[nodiscard]] bool fits_page_rounded_file_range(std::uint64_t file_offset,
        std::uint32_t size, std::uintmax_t file_size)
    {
        if (file_offset > file_size)
            return false;
        const auto available = file_size - file_offset;
        if (size <= available)
            return true;
        const auto remainder = available % AddressSpace::page_size;
        const auto padding = remainder == 0U
                                 ? 0U
                                 : AddressSpace::page_size - remainder;
        return available <=
                   std::numeric_limits<std::uintmax_t>::max() - padding &&
               size <= available + padding;
    }

    [[nodiscard]] bool valid_mapping(
        const Mapping& mapping, std::uintmax_t file_size, DarwinAddressBounds bounds)
    {
        return in_arm_shared_region(mapping.address, mapping.size, bounds) &&
               page_aligned(mapping.address) &&
               page_aligned(mapping.file_offset) &&
               (mapping.initial_protection &
                   ~(1U | 2U | 4U | vm_protection_copy_on_write |
                       vm_protection_zero_fill | vm_protection_slide)) == 0 &&
               (mapping.initial_protection & ~mapping.maximum_protection &
                   (1U | 2U | 4U)) == 0 &&
               ((mapping.initial_protection & vm_protection_zero_fill) != 0 ||
                   fits_page_rounded_file_range(mapping.file_offset,
                       mapping.size, file_size));
    }

    [[nodiscard]] bool looks_like_dyld_shared_cache(
        const std::filesystem::path& path)
    {
        std::ifstream input { path, std::ios::binary };
        if (!input)
            return false;
        std::array<char, 7> magic { };
        input.read(magic.data(), static_cast<std::streamsize>(magic.size()));
        return input.gcount() == static_cast<std::streamsize>(magic.size()) &&
               std::string_view { magic.data(), magic.size() } == "dyld_v1";
    }

    [[nodiscard]] std::optional<std::vector<Mapping>> read_mappings(
        const AddressSpace& memory, std::uint32_t address, std::uint32_t count,
        std::uintmax_t file_size, MappingLayout layout, DarwinAddressBounds bounds)
    {
        std::vector<Mapping> mappings;
        mappings.reserve(count);
        for (std::uint32_t index = 0; index < count; ++index) {
            const auto mapping = read_mapping(memory, address, index, layout);
            if (!mapping || !valid_mapping(*mapping, file_size, bounds)) {
                return std::nullopt;
            }
            mappings.push_back(*mapping);
        }
        return mappings;
    }

    [[nodiscard]] const char* layout_name(MappingLayout layout)
    {
        switch (layout) {
        case MappingLayout::Arm32Words:
            return "arm32";
        case MappingLayout::MachVm64:
            return "mach-vm64";
        }
        return "unknown";
    }

    [[nodiscard]] std::optional<std::uint32_t> first_mapped_shared_region_page(
        const AddressSpace& memory, DarwinAddressBounds bounds)
    {
        for (std::uint64_t address = bounds.shared_region_base;
            address < bounds.shared_region_end;
            address += AddressSpace::page_size) {
            const auto page = static_cast<std::uint32_t>(address);
            if (memory.mapped(page, AddressSpace::page_size))
                return page;
        }
        return std::nullopt;
    }

    [[nodiscard]] bool mappings_fit(const AddressSpace& memory,
        const std::vector<Mapping>& mappings, std::uint32_t slide,
        DarwinAddressBounds bounds)
    {
        for (const auto& mapping : mappings) {
            if (add_overflows(mapping.address, slide))
                return false;
            const auto address = mapping.address + slide;
            if (!in_arm_shared_region(address, mapping.size, bounds) ||
                memory.mapped(address, mapping.size)) {
                return false;
            }
        }
        return true;
    }

    [[nodiscard]] std::optional<std::uint32_t> choose_slide(
        const AddressSpace& memory, const std::vector<Mapping>& mappings,
        bool may_slide, DarwinAddressBounds bounds)
    {
        if (mappings_fit(memory, mappings, 0, bounds))
            return 0;
        if (!may_slide || mappings.empty())
            return std::nullopt;

        // XNU's map_shared_file() applies one slide to both ARM halves.  Search
        // by page so TEXT/DATA retain their 0x08000000 relationship.
        for (std::uint64_t slide = AddressSpace::page_size;
            slide < arm_shared_half_size; slide += AddressSpace::page_size) {
            if (mappings_fit(
                    memory, mappings, static_cast<std::uint32_t>(slide), bounds)) {
                return static_cast<std::uint32_t>(slide);
            }
        }
        return std::nullopt;
    }

    void rollback(
        AddressSpace& memory, const std::vector<AppliedMapping>& mappings)
    {
        for (auto iterator = mappings.rbegin(); iterator != mappings.rend();
            ++iterator) {
            static_cast<void>(memory.unmap(iterator->address, iterator->size));
        }
    }

    [[nodiscard]] bool slide_info_range_valid(std::uint32_t offset,
        std::uint64_t byte_count, std::uint32_t slide_info_size)
    {
        return offset <= slide_info_size &&
               byte_count <= slide_info_size - offset;
    }

    [[nodiscard]] std::optional<SlideInfoHeaderV1> read_slide_info_header(
        const AddressSpace& memory, std::uint32_t address,
        std::uint32_t size)
    {
        if (address == 0 || size < slide_info_header_size ||
            size > maximum_slide_info_size || add_overflows(address, size) ||
            !memory.accessible(address, size, MemoryPermission::Read)) {
            return std::nullopt;
        }
        const auto version = memory.read32(address);
        const auto table_offset = memory.read32(address + 4U);
        const auto table_count = memory.read32(address + 8U);
        const auto entries_offset = memory.read32(address + 12U);
        const auto entries_count = memory.read32(address + 16U);
        if (!version || !table_offset || !table_count || !entries_offset ||
            !entries_count || *version != 1U ||
            !slide_info_range_valid(*table_offset,
                static_cast<std::uint64_t>(*table_count) *
                    sizeof(std::uint16_t),
                size) ||
            !slide_info_range_valid(*entries_offset,
                static_cast<std::uint64_t>(*entries_count) *
                    slide_bitmap_size,
                size)) {
            return std::nullopt;
        }
        return SlideInfoHeaderV1 { *version, *table_offset, *table_count,
            *entries_offset, *entries_count };
    }

    [[nodiscard]] std::uint32_t apply_slide_info_v1(AddressSpace& memory,
        const std::vector<Mapping>& mappings, std::uint32_t slide,
        std::uint32_t slide_info_address, std::uint32_t slide_info_size)
    {
        if (slide == 0)
            return 0;

        const auto mapping = std::find_if(mappings.begin(), mappings.end(),
            [](const Mapping& candidate) {
                return (candidate.initial_protection & vm_protection_slide) !=
                       0;
            });
        const auto header = read_slide_info_header(
            memory, slide_info_address, slide_info_size);
        if (mapping == mappings.end() || !header)
            return bsd_support::invalid_argument;

        const auto mapped_page_count =
            (static_cast<std::uint64_t>(mapping->size) +
                AddressSpace::page_size - 1U) /
            AddressSpace::page_size;
        if (header->table_count > mapped_page_count)
            return bsd_support::invalid_argument;

        // XNU consumes the firmware-provided bitmap to rebase only the marked
        // 32-bit words in the VM_PROT_SLIDE mapping. Eagerly applying the same
        // bitmap preserves those semantics without leaking the host memory
        // backend into the Darwin ABI layer.
        auto writable_permissions = permissions(mapping->initial_protection);
        writable_permissions |= MemoryPermission::Write;
        if (!memory.protect(
                mapping->address, mapping->size, writable_permissions)) {
            return bsd_support::invalid_argument;
        }
        const auto restore_permissions = [&] {
            static_cast<void>(memory.protect(mapping->address, mapping->size,
                permissions(mapping->initial_protection)));
        };

        for (std::uint32_t page = 0; page < header->table_count; ++page) {
            const auto table_address =
                static_cast<std::uint64_t>(slide_info_address) +
                header->table_offset +
                static_cast<std::uint64_t>(page) * sizeof(std::uint16_t);
            const auto entry_index =
                memory.read16(static_cast<std::uint32_t>(table_address));
            if (!entry_index || *entry_index >= header->entries_count) {
                restore_permissions();
                return bsd_support::bad_address;
            }
            const auto bitmap_address =
                static_cast<std::uint64_t>(slide_info_address) +
                header->entries_offset +
                static_cast<std::uint64_t>(*entry_index) * slide_bitmap_size;
            for (std::uint32_t byte = 0; byte < slide_bitmap_size; ++byte) {
                const auto bitmap = memory.read8(
                    static_cast<std::uint32_t>(bitmap_address + byte));
                if (!bitmap) {
                    restore_permissions();
                    return bsd_support::bad_address;
                }
                for (std::uint32_t bit = 0; bit < 8U; ++bit) {
                    if ((*bitmap & (1U << bit)) == 0)
                        continue;
                    const auto offset =
                        static_cast<std::uint64_t>(page) *
                            AddressSpace::page_size +
                        static_cast<std::uint64_t>(byte * 8U + bit) *
                            sizeof(std::uint32_t);
                    if (offset + sizeof(std::uint32_t) > mapping->size) {
                        restore_permissions();
                        return bsd_support::invalid_argument;
                    }
                    const auto pointer_address = static_cast<std::uint32_t>(
                        static_cast<std::uint64_t>(mapping->address) + offset);
                    const auto pointer = memory.read32(pointer_address);
                    if (!pointer ||
                        !memory.write32(pointer_address, *pointer + slide)) {
                        restore_permissions();
                        return bsd_support::bad_address;
                    }
                }
            }
        }
        restore_permissions();
        return 0;
    }

} // namespace

const DyldSharedCache* CompatibilityKernel::dyld_shared_cache_for(
    const std::filesystem::path& path)
{
    if (dyld_shared_cache_attempted_ && dyld_shared_cache_path_ != path) {
        std::error_code equivalent_error;
        if (!std::filesystem::equivalent(
                dyld_shared_cache_path_, path, equivalent_error)) {
            return nullptr;
        }
    }

    if (!looks_like_dyld_shared_cache(path)) {
        dyld_shared_cache_.reset();
        return nullptr;
    }

    dyld_shared_cache_attempted_ = true;
    dyld_shared_cache_path_ = path;
    DyldSharedCacheOptions options;
    options.architecture =
        arm_architecture_for_model(device_model_.processor.model) ==
                ArmArchitectureVersion::Armv7
            ? "armv7"
            : "armv6k";
    if (const auto parsed = DyldSharedCache::parse(path, options)) {
        const auto previous_generation = dyld_shared_cache_;
        dyld_shared_cache_ = parsed.shared();
        if (previous_generation != parsed.shared()) {
            output_.write(
                "[shared-region] parsed dyld cache generation files=" +
                std::to_string(dyld_shared_cache_->files().size()) +
                " images=" +
                std::to_string(dyld_shared_cache_->images().size()) + "\n");
        }
        userland_hle_.prepare_shared_cache_plan(*dyld_shared_cache_,
            arm_architecture_for_model(device_model_.processor.model));
    }
    return dyld_shared_cache_ ? dyld_shared_cache_.get() : nullptr;
}

bool CompatibilityKernel::dispatch_bsd_shared_region(
    Cpu& cpu, std::uint32_t number)
{
    auto& registers = cpu.registers();
    const auto bounds = darwin_address_bounds(shared_state_->darwin_abi.address_layout);
    if (number == 294) { // shared_region_check_np
        const auto start_address = first_mapped_shared_region_page(memory_, bounds);
        if (!start_address) {
            bsd_error(cpu, 12); // ENOMEM: shared region exists but is empty.
        } else if (!memory_.write64(registers[0], *start_address)) {
            bsd_error(cpu, bsd_support::bad_address);
        } else {
            bsd_success(cpu, 0);
        }
        return true;
    }
    if (number == 300) { // shared_region_make_private_np
        // The old ARM ABI passes (rangeCount, ranges), where each range
        // contains two mach_vm_* (64-bit) fields.  AddressSpace is already
        // process-local; map_file() gives retained file pages private-on-write
        // semantics.  The observable part of privatization is therefore
        // releasing every mapped shared-region interval outside the requested
        // ranges.
        const auto parsed =
            read_shared_region_ranges(memory_, registers[0], registers[1], bounds);
        if (parsed.error != 0) {
            bsd_error(cpu, parsed.error);
            return true;
        }
        const auto release = ranges_to_release(memory_, parsed.ranges, bounds);
        for (const auto& range : release) {
            static_cast<void>(
                unmap_memory(cpu, range.address, range.end - range.address));
        }
        std::uint64_t released_bytes = 0;
        for (const auto& range : release)
            released_bytes += range.end - range.address;
        output_.write(
            "[shared-region] private pid=" + std::to_string(process_.pid) +
            " keep-ranges=" + std::to_string(parsed.ranges.size()) +
            " released-bytes=" + std::to_string(released_bytes) + "\n");
        bsd_success(cpu, 0);
        return true;
    }
    if (number != 299 && number != 295 && number != 438)
        return false;

    SharedRegionDiagnostics diagnostics { process_.pid };
    const auto fixed_mapping_contract = number == 438;

    auto descriptor_number = registers[0];
    if (const auto duplicate = duplicated_descriptors_.find(descriptor_number);
        duplicate != duplicated_descriptors_.end()) {
        descriptor_number = duplicate->second;
    }
    const auto descriptor = file_descriptors_.find(descriptor_number);
    if (descriptor == file_descriptors_.end()) {
        bsd_error(cpu, bsd_support::bad_file_descriptor);
        return true;
    }
    const auto mapping_count = registers[1];
    const auto mappings_address = registers[2];
    const auto slide_address = number == 299 ? registers[3] : 0U;
    const auto content_slide = fixed_mapping_contract ? registers[3] : 0U;
    const auto slide_info_address =
        fixed_mapping_contract ? registers[4] : 0U;
    const auto slide_info_size = fixed_mapping_contract ? registers[5] : 0U;
    if (mapping_count == 0) {
        if (slide_address != 0 && !memory_.write64(slide_address, 0)) {
            bsd_error(cpu, bsd_support::bad_address);
        } else {
            bsd_success(cpu, 0);
        }
        return true;
    }
    const auto mapping_count_limit = fixed_mapping_contract
                                         ? map_and_slide_maximum_mapping_count
                                         : maximum_mapping_count;
    if (mapping_count > mapping_count_limit || mappings_address == 0) {
        bsd_error(cpu, bsd_support::invalid_argument);
        return true;
    }

    std::error_code file_error;
    const auto file_size =
        std::filesystem::file_size(descriptor->second, file_error);
    if (file_error) {
        bsd_error(cpu, bsd_support::invalid_argument);
        return true;
    }
    diagnostics.checkpoint(SharedRegionDiagnosticPhase::Preflight);

    const auto is_shared_cache =
        looks_like_dyld_shared_cache(descriptor->second);
    diagnostics.checkpoint(SharedRegionDiagnosticPhase::CacheProbe);
    const auto* shared_cache =
        is_shared_cache ? dyld_shared_cache_for(descriptor->second) : nullptr;
    diagnostics.checkpoint(SharedRegionDiagnosticPhase::CacheParse);
    // A split cache can place an executable mapping in a subcache. The parser
    // validates each file independently; use an intentionally permissive bound
    // here and perform the source-file bounds check after correlating the
    // range.
    const auto mapping_validation_size =
        shared_cache ? std::numeric_limits<std::uintmax_t>::max() : file_size;

    auto layout = fixed_mapping_contract ? MappingLayout::MachVm64
                                         : MappingLayout::Arm32Words;
    auto mappings = read_mappings(memory_, mappings_address, mapping_count,
        mapping_validation_size, layout, bounds);
    if (!mappings && !fixed_mapping_contract) {
        layout = MappingLayout::MachVm64;
        mappings = read_mappings(memory_, mappings_address, mapping_count,
            mapping_validation_size, layout, bounds);
    }
    if (!mappings) {
        bsd_error(cpu, bsd_support::invalid_argument);
        return true;
    }
    diagnostics.checkpoint(SharedRegionDiagnosticPhase::ReadMappings);

    const auto address_slide = choose_slide(
        memory_, *mappings, !fixed_mapping_contract && slide_address != 0, bounds);
    if (!address_slide) {
        bsd_error(cpu, 12); // ENOMEM / KERN_NO_SPACE
        return true;
    }
    diagnostics.checkpoint(SharedRegionDiagnosticPhase::ChooseSlide);

    const auto mapping_source =
        [&](const Mapping& mapping) -> std::optional<MappingSource> {
        if (shared_cache == nullptr) {
            return MappingSource { descriptor->second, mapping.file_offset,
                std::nullopt, std::nullopt, { } };
        }
        const auto files = shared_cache->files();
        for (std::size_t file_index = 0; file_index < files.size();
            ++file_index) {
            const auto file = files[file_index];
            for (const auto& range : file.mappings) {
                if (mapping.address < range.address ||
                    mapping.address - range.address > range.size ||
                    mapping.size >
                        range.size - (mapping.address - range.address) ||
                    mapping.file_offset < range.file_offset ||
                    mapping.file_offset - range.file_offset > range.size ||
                    mapping.size > range.size - (mapping.file_offset -
                                                    range.file_offset)) {
                    continue;
                }
                const auto source_offset = mapping.file_offset;
                std::error_code source_error;
                const auto source_path = std::filesystem::path { file.path };
                const auto source_size =
                    std::filesystem::file_size(source_path, source_error);
                if (source_error || source_offset > source_size ||
                    mapping.size > source_size - source_offset) {
                    return std::nullopt;
                }
                return MappingSource { source_path, source_offset,
                    file.file_generation, file.content_identity,
                    shared_cache->immutable_file_view_at(file_index) };
            }
        }

        // dyld may include an auxiliary range, such as the code-signature
        // tail, in the shared-region request even though it is not listed in
        // the cache member's VM mapping table. XNU rounds vnode mappings to a
        // page and zeroes bytes beyond EOF, so accept only that final partial
        // page while retaining the exact immutable cache generation.
        const auto descriptor_file = std::find_if(files.begin(), files.end(),
            [&](const DyldCacheFileView& file) {
                // Parsed generations may retain an absolute catalog path
                // while the guest descriptor was opened through a relative
                // rootfs or a symlink. Match the file, not its spelling.
                std::error_code equivalent_error;
                return std::filesystem::equivalent(
                    std::filesystem::path { file.path }, descriptor->second,
                    equivalent_error);
            });
        if (descriptor_file != files.end()) {
            const auto cache_file = *descriptor_file;
            const auto source_size = cache_file.file_size;
            if (fits_page_rounded_file_range(
                    mapping.file_offset, mapping.size, source_size)) {
                const auto file_index = static_cast<std::size_t>(
                    std::distance(files.begin(), descriptor_file));
                return MappingSource { cache_file.path, mapping.file_offset,
                    cache_file.file_generation, cache_file.content_identity,
                    shared_cache->immutable_file_view_at(file_index) };
            }
        }
        return std::nullopt;
    };

    std::vector<AppliedMapping> applied;
    applied.reserve(mappings->size());
    // Non-cache shared-region calls describe several ranges of the same
    // descriptor. Reuse the first validated backing across those ranges so a
    // cold App launch does not reopen, canonicalize, and re-identify the same
    // executable for every segment. Dyld-cache mappings already carry their
    // immutable file view and keep the ordinary path disabled.
    FileMappingBatchContext file_mapping_context;
    std::chrono::nanoseconds source_resolution_time { };
    std::chrono::nanoseconds map_time { };
    std::chrono::nanoseconds install_time { };
    for (const auto& mapping : *mappings) {
        const auto address = mapping.address + *address_slide;
        const auto zero_fill =
            (mapping.initial_protection & vm_protection_zero_fill) != 0;
        const auto mapping_permissions =
            permissions(mapping.initial_protection);
        const auto source_started =
            diagnostics.enabled() ? std::chrono::steady_clock::now()
                                  : std::chrono::steady_clock::time_point { };
        const auto source = zero_fill ? std::optional<MappingSource> { }
                                      : mapping_source(mapping);
        if (diagnostics.enabled()) {
            source_resolution_time +=
                std::chrono::steady_clock::now() - source_started;
        }
        if (!zero_fill && !source) {
            rollback(memory_, applied);
            bsd_error(cpu, bsd_support::invalid_argument);
            return true;
        }
        const auto map_started =
            diagnostics.enabled() ? std::chrono::steady_clock::now()
                                  : std::chrono::steady_clock::time_point { };
        const auto mapped =
            zero_fill ? memory_.map(address, mapping.size, mapping_permissions)
                      : memory_.map_file(address, mapping.size,
                            mapping_permissions, source->path,
                            source->file_offset, source->expected_generation,
                            source->expected_content_identity, { },
                            source->immutable_file_view,
                            shared_cache == nullptr ? &file_mapping_context
                                                    : nullptr);
        if (diagnostics.enabled())
            map_time += std::chrono::steady_clock::now() - map_started;
        if (!mapped) {
            rollback(memory_, applied);
            bsd_error(cpu, zero_fill ? 12 : bsd_support::invalid_argument);
            return true;
        }
        applied.push_back({ address, mapping.size });
        if (*address_slide == 0U &&
            has_permission(mapping_permissions, MemoryPermission::Execute)) {
            memory_.mark_translation_profile_stable(address, mapping.size);
        }
    }

    if (fixed_mapping_contract) {
        const auto slide_error = apply_slide_info_v1(memory_, *mappings,
            content_slide, slide_info_address, slide_info_size);
        if (slide_error != 0) {
            rollback(memory_, applied);
            bsd_error(cpu, slide_error);
            return true;
        }
    }

    if (slide_address != 0 &&
        !memory_.write64(slide_address, *address_slide)) {
        rollback(memory_, applied);
        bsd_error(cpu, bsd_support::bad_address);
        return true;
    }
    for (const auto& mapping : *mappings) {
        if ((mapping.initial_protection & vm_protection_zero_fill) != 0)
            continue;
        const auto executable = has_permission(
            permissions(mapping.initial_protection), MemoryPermission::Execute);
        const auto source_started =
            diagnostics.enabled() ? std::chrono::steady_clock::now()
                                  : std::chrono::steady_clock::time_point { };
        const auto source = mapping_source(mapping);
        if (diagnostics.enabled()) {
            source_resolution_time +=
                std::chrono::steady_clock::now() - source_started;
        }
        if (!source)
            continue;
        if (shared_cache != nullptr) {
            static_cast<void>(
                userland_hle_.resolve_mapped_shared_cache_data_symbols(
                    source->path, mapping.address + *address_slide,
                    mapping.size,
                    source->file_offset));
        }
        // Image installation discovers and patches guest functions, publishes
        // executable catalog hints, and detects framework ABI profiles. Keep it
        // restricted to executable ranges except for standalone images with an
        // explicitly registered data export: those symbols reside in __DATA and
        // still need their runtime address published. Shared-cache data exports
        // were resolved above without parsing or patching the data mapping.
        if (!executable && (shared_cache != nullptr ||
                               !userland_hle_.needs_data_symbol_mapping(
                                   source->path.generic_string()))) {
            continue;
        }
        const auto install_started =
            diagnostics.enabled() ? std::chrono::steady_clock::now()
                                  : std::chrono::steady_clock::time_point { };
        static_cast<void>(install_mapped_user_image(cpu, source->path,
            mapping.address + *address_slide, mapping.size,
            source->file_offset,
            shared_cache != nullptr));
        if (diagnostics.enabled())
            install_time += std::chrono::steady_clock::now() - install_started;
    }
    diagnostics.record(
        SharedRegionDiagnosticPhase::ResolveSource, source_resolution_time);
    diagnostics.record(SharedRegionDiagnosticPhase::Map, map_time);
    diagnostics.record(SharedRegionDiagnosticPhase::InstallImage, install_time);
    output_.write("[shared-region] map pid=" + std::to_string(process_.pid) +
                  " file=" + descriptor->second.string() +
                  " entries=" + std::to_string(mapping_count) +
                  " layout=" + layout_name(layout) +
                  " address-slide=" + std::to_string(*address_slide) +
                  " content-slide=" + std::to_string(content_slide) + "\n");
    bsd_success(cpu, 0);
    return true;
}

} // namespace shade
