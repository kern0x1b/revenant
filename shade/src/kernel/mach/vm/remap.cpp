// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Remap guest virtual-memory ranges between address spaces.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/vm_map.defs
// https://github.com/apple-oss-distributions/xnu/blob/xnu-1699.22.73/osfmk/mach/mach_vm.defs

#include "kernel/kernel.hpp"

#include "kernel/darwin_abi.hpp"
#include "mach/mig_wire_abi.hpp"
#include "mach/vm_map_mig_ids.hpp"

#include <array>
#include <cstdint>
#include <limits>
#include <memory>
#include <optional>
#include <span>
#include <string>
#include <vector>

#include "../support.hpp"
#include "wire_format.hpp"
#include "wire_reply.hpp"

namespace shade {
namespace {

    using namespace mach_support;
    using namespace mach_vm_support;

    constexpr std::uint32_t mach_vm_remap_identifier = 4813U;
    constexpr std::uint32_t descriptor_count = 1U;
    constexpr std::uint32_t kern_no_space = 3U;
    constexpr std::uint32_t kern_invalid_argument = 4U;
    constexpr std::uint32_t vm_protection_read = 1U;
    constexpr std::uint32_t vm_protection_write = 2U;
    constexpr std::uint32_t vm_protection_execute = 4U;
    constexpr std::uint32_t maximum_inheritance = 2U;
    constexpr std::uint32_t vm_flags_return_data_address = 0x00100000U;

    [[nodiscard]] std::optional<std::uint32_t> round_page_size(
        std::uint32_t size)
    {
        constexpr auto mask = AddressSpace::page_size - 1U;
        if (size == 0U ||
            size > std::numeric_limits<std::uint32_t>::max() - mask) {
            return std::nullopt;
        }
        return (size + mask) & ~mask;
    }

    [[nodiscard]] std::uint32_t darwin_permissions(MemoryPermission permissions)
    {
        std::uint32_t result = 0U;
        if (has_permission(permissions, MemoryPermission::Read))
            result |= vm_protection_read;
        if (has_permission(permissions, MemoryPermission::Write))
            result |= vm_protection_write;
        if (has_permission(permissions, MemoryPermission::Execute))
            result |= vm_protection_execute;
        return result;
    }

} // namespace

CompatibilityKernel::RemapResult CompatibilityKernel::remap_into(
    AddressSpace& memory, RemapPlacement placement)
{
    auto address = placement.requested_address;
    if (placement.anywhere) {
        address = find_free_guest_region(
            memory, default_dynamic_base, placement.size, placement.mask)
                      .value_or(0U);
    }
    if (address == 0U || address % AddressSpace::page_size != 0U ||
        (address & placement.mask) != 0U ||
        guest_region_overlaps(memory, address, placement.size)) {
        return { kern_no_space, address };
    }
    auto pages = std::move(placement.source.pages);
    if (placement.copy) {
        for (auto& page : pages)
            page = std::make_shared<GuestPageBacking>(*page);
    }
    bool mapped = memory.map_page_backings(address, placement.size,
        placement.source.permissions, pages,
        placement.copy ? AddressSpace::PageMappingMode::CopyOnWrite
                       : AddressSpace::PageMappingMode::Shared);
    if (mapped && !memory.inherit(address, placement.size,
                      static_cast<VmInheritance>(placement.inheritance))) {
        static_cast<void>(memory.unmap(address, placement.size));
        mapped = false;
    }
    return { mapped ? kern_success : kern_no_space, address };
}

bool CompatibilityKernel::dispatch_mach_vm_remap_message(
    Cpu& cpu, const MachMessageRequest& request)
{
    const auto is_mach_vm = request.identifier == mach_vm_remap_identifier;
    if (!is_mach_vm &&
        request.identifier != mach_support::mig_message_id(
                                  xnu::mig::vm_map::Routine::vm_remap)) {
        return false;
    }

    auto& registers = cpu.registers();
    const auto profile = MachVmWireFormat::for_interface(
        is_mach_vm, shared_state_->darwin_abi.mach_vm_address);
    const auto width = profile.address_size();
    constexpr auto payload = darwin::mig_wire::complex_request_word(1, 0);
    const auto request_size = payload + 4U * width + 12U;
    const auto reply_size =
        darwin::mig_wire::simple_reply_payload_base + width + 8U;
    const auto fail_transport = [&] {
        registers[0] = mach_receive_invalid_data;
        return true;
    };
    if (registers[2] < request_size || registers[3] < reply_size ||
        (request.bits & darwin::mig_wire::message_complex_bit) == 0U) {
        return fail_transport();
    }

    const auto body_count = memory_.read32(
        request.address + darwin::mig_wire::complex_descriptor_count_offset);
    const auto source_task_name = memory_.read32(
        request.address + darwin::mig_wire::descriptor_name_offset(0));
    const auto descriptor_metadata = memory_.read32(
        request.address + darwin::mig_wire::descriptor_metadata_offset(0));
    const auto target_wire =
        profile.read_address(memory_, request.address + payload);
    const auto size_wire =
        profile.read_address(memory_, request.address + payload + width);
    const auto mask_wire =
        profile.read_address(memory_, request.address + payload + 2U * width);
    const auto flags = memory_.read32(request.address + payload + 3U * width);
    const auto source_wire = profile.read_address(
        memory_, request.address + payload + 3U * width + 4U);
    const auto copy =
        memory_.read32(request.address + payload + 4U * width + 4U);
    const auto inheritance =
        memory_.read32(request.address + payload + 4U * width + 8U);
    if (!body_count || !source_task_name || !descriptor_metadata ||
        !target_wire || !size_wire || !mask_wire || !flags || !source_wire ||
        !copy || !inheritance) {
        return fail_transport();
    }
    if ((*target_wire | *size_wire | *mask_wire | *source_wire) > UINT32_MAX) {
        if (!write_simple_reply(memory_, request.address, request.local_port,
                request.identifier, kern_invalid_argument))
            return fail_transport();
        registers[0] = kern_success;
        return true;
    }
    constexpr auto page_mask = AddressSpace::page_size - 1U;
    auto target_address = static_cast<std::uint32_t>(*target_wire) & ~page_mask;
    const auto requested_size = static_cast<std::uint32_t>(*size_wire);
    const auto mask = static_cast<std::uint32_t>(*mask_wire);
    const auto requested_source_address = static_cast<std::uint32_t>(*source_wire);
    const auto source_address = requested_source_address & ~page_mask;
    const auto data_offset = (*flags & vm_flags_return_data_address) != 0U
        ? requested_source_address & page_mask : 0U;

    // XNU rounds the source down even for the legacy interface. When callers
    // request the data address, include its page offset in the covered extent
    // so a small byte range crossing a page boundary maps both pages.
    const auto requested_target_address = static_cast<std::uint32_t>(*target_wire);
    const auto size = requested_size <= UINT32_MAX - data_offset
        ? round_page_size(requested_size + data_offset) : std::nullopt;
    const auto descriptor_type =
        *descriptor_metadata >> darwin::mig_wire::descriptor_type_shift;
    const auto descriptor_disposition =
        (*descriptor_metadata >>
            darwin::mig_wire::descriptor_disposition_shift) &
        0xffU;
    std::optional<std::uint32_t> target_pid;
    std::optional<std::uint32_t> source_pid;
    {
        std::lock_guard lock { shared_state_->mach_mutex };
        target_pid = target_task_for_port(
            *shared_state_, process_.pid, request.remote_port);
        source_pid = target_task_for_port(
            *shared_state_, process_.pid, *source_task_name);
    }

    std::uint32_t result = kern_success;
    if (*body_count != descriptor_count || descriptor_type != 0U ||
        descriptor_disposition != darwin::mig_wire::disposition_copy_send ||
        requested_size == 0U || !size ||
        static_cast<std::uint64_t>(source_address) + size.value_or(0U) >
            (std::uint64_t { 1 } << 32U) ||
        *inheritance > maximum_inheritance || !target_pid || !source_pid ||
        (*target_pid != process_.pid && !task_memory_remap_handler_)) {
        result = kern_invalid_argument;
    }

    std::optional<SharedTaskMemoryRange> source;
    if (result == kern_success && *source_pid == process_.pid) {
        const auto region = memory_.mapping_region_at_or_after(source_address);
        const auto end = static_cast<std::uint64_t>(source_address) + *size;
        if (region && region->address <= source_address && region->end >= end) {
            if (auto pages = memory_.share_pages(source_address, *size)) {
                source = SharedTaskMemoryRange { std::move(*pages),
                    region->permissions };
            }
        }
    } else if (result == kern_success && task_memory_share_query_) {
        source = task_memory_share_query_(*source_pid, source_address, *size);
    }
    if (result == kern_success && !source)
        result = kern_invalid_address;

    const bool anywhere = (*flags & darwin::mach::vm_flags_anywhere) != 0U;
    const auto protection =
        source ? darwin_permissions(source->permissions) : 0U;
    if (result == kern_success && *target_pid != process_.pid) {
        // Another task's mappings are not unmapped from here, so an overwrite
        // that would replace one is refused like any other overlap.
        const auto placed = task_memory_remap_handler_(*target_pid,
            RemapPlacement { target_address, *size, mask, anywhere,
                *copy != 0U, *inheritance, std::move(*source) });
        result = placed ? placed->result : kern_invalid_argument;
        if (placed)
            target_address = placed->address;
    } else if (result == kern_success) {
        if (!anywhere && (*flags & darwin::mach::vm_flags_overwrite) != 0U &&
            target_address != 0U &&
            target_address % AddressSpace::page_size == 0U &&
            (target_address & mask) == 0U &&
            guest_region_overlaps(memory_, target_address, *size) &&
            !unmap_memory(cpu, target_address, *size)) {
            result = kern_no_space;
        }
        if (result == kern_success) {
            auto placed = remap_into(memory_,
                RemapPlacement { target_address, *size, mask, anywhere,
                    *copy != 0U, *inheritance, std::move(*source) });
            result = placed.result;
            target_address = placed.address;
        }
    }

    std::vector<std::uint32_t> reply {
        darwin::mig_wire::message_bits(
            darwin::mig_wire::disposition_move_send_once),
        reply_size,
        request.local_port,
        0U,
        0U,
        request.identifier + 100U,
        0U,
        1U,
        result,
    };
    profile.append_address(reply, result == kern_success
        ? target_address + data_offset : requested_target_address);
    reply.push_back(protection);
    reply.push_back(protection);
    if (!write_words(memory_, request.address, reply))
        return fail_transport();

    output_.write("[vm] " + std::string { is_mach_vm ? "mach_vm" : "vm_map" } +
                  " remap pid=" + std::to_string(process_.pid) +
                  " target=" + std::to_string(target_pid.value_or(0U)) +
                  " requested=" + std::to_string(requested_target_address) +
                  " address=" + std::to_string(target_address) +
                  " size=" + std::to_string(size.value_or(0U)) + " mask=" +
                  std::to_string(mask) + " flags=" + std::to_string(*flags) +
                  " source-pid=" + std::to_string(source_pid.value_or(0U)) +
                  " source=" + std::to_string(requested_source_address) +
                  " copy=" + std::to_string(*copy != 0U) +
                  " inheritance=" + std::to_string(*inheritance) +
                  " protection=" + std::to_string(protection) +
                  " result=" + std::to_string(result) + "\n");
    registers[0] = kern_success;
    return true;
}

} // namespace shade
