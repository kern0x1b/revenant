// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Map guest virtual-memory objects and requested address ranges.
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
#include <span>
#include <string>

#include "../support.hpp"
#include "wire_reply.hpp"
#include "wire_format.hpp"

namespace shade {
namespace {

    using namespace mach_support;
    using namespace mach_vm_support;

    constexpr std::uint32_t vm_map_request_size = 84U;
    constexpr std::uint32_t vm_map_64_request_size = 88U;
    // Darwin 8 also publishes the same ARM32 wire contract through the
    // mach_vm subsystem.  Its mach_vm_map routine is numbered relative to the
    // 4800 subsystem base instead of vm_map's 3800 base.
    constexpr std::uint32_t mach_vm_map_identifier = 4811U;
    constexpr std::uint32_t reply_size = 40U;
    constexpr std::uint32_t kern_protection_failure = 2U;
    constexpr std::uint32_t kern_no_space = 3U;
    constexpr std::uint32_t kern_invalid_argument = 4U;
    constexpr std::uint32_t vm_protection_mask = 0x7U;
    constexpr std::uint32_t vm_protection_is_mask = 0x40U;
    constexpr std::uint32_t vm_flags_user_map =
        0x00000001U | 0x00000002U | 0x00000010U | 0x00070000U |
        0xff000000U;

    [[nodiscard]] MemoryPermission memory_permissions(std::uint32_t protection)
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

    [[nodiscard]] std::optional<std::uint32_t> round_page_size(
        std::uint32_t size)
    {
        constexpr auto mask = AddressSpace::page_size - 1U;
        if (size == 0 ||
            size > std::numeric_limits<std::uint32_t>::max() - mask)
            return std::nullopt;
        return (size + mask) & ~mask;
    }

} // namespace

bool CompatibilityKernel::dispatch_mach_vm_map_message(
    Cpu& cpu, const MachMessageRequest& request)
{
    using xnu::mig::vm_map::Routine;
    const auto is_mach_vm = request.identifier == mach_vm_map_identifier;
    const auto is_64 =
        request.identifier == mig_message_id(Routine::vm_map_64) || is_mach_vm;
    if (!is_64 && request.identifier != mig_message_id(Routine::vm_map))
        return false;

    auto& registers = cpu.registers();
    const auto wire = MachVmWireFormat::for_interface(
        is_mach_vm, shared_state_->darwin_abi.mach_vm_address);
    const auto width_delta = wire.address_size() - 4U;
    const auto address_reply_size = reply_size + width_delta;
    const auto required_request_size =
        (is_64 ? vm_map_64_request_size : vm_map_request_size) + 3U * width_delta;
    if (registers[2] < required_request_size || registers[3] < address_reply_size) {
        registers[0] = mach_receive_invalid_data;
        return true;
    }

    const auto& arguments = is_64 ? xnu::mig::vm_map::vm_map_64_arguments
                                  : xnu::mig::vm_map::vm_map_arguments;
    // The object port remains a descriptor. Only the three address-sized
    // inline fields before flags expand in the wide mach_vm interface.
    const auto request_offset = [&](std::size_t index) {
        const auto expanded_fields = index == 5U ? 0U
            : index <= 1U ? 0U : index <= 3U ? index - 1U : 3U;
        return request.address + arguments[index].request_offset +
            static_cast<std::uint32_t>(expanded_fields) * width_delta;
    };
    const auto wide_address = wire.read_address(memory_, request_offset(1));
    const auto wide_size = wire.read_address(memory_, request_offset(2));
    const auto wide_mask = wire.read_address(memory_, request_offset(3));
    if (!wide_address || !wide_size || !wide_mask) {
        registers[0] = mach_receive_invalid_data;
        return true;
    }
    std::optional<std::uint32_t> address { static_cast<std::uint32_t>(*wide_address) };
    const auto requested_size = static_cast<std::uint32_t>(*wide_size);
    const auto alignment_mask = static_cast<std::uint32_t>(*wide_mask);
    const auto flags = memory_.read32(request_offset(4));
    const auto object_name =
        memory_.read32(request_offset(5));
    std::optional<std::uint64_t> object_offset;
    if (is_64) {
        object_offset =
            memory_.read64(request_offset(6));
    } else if (const auto value = memory_.read32(
                   request_offset(6))) {
        object_offset = *value;
    }
    const auto copy =
        memory_.read32(request_offset(7));
    const auto protection =
        memory_.read32(request_offset(8));
    const auto maximum_protection =
        memory_.read32(request_offset(9));
    const auto inheritance =
        memory_.read32(request_offset(10));
    if (!flags || !object_name ||
        !object_offset || !copy || !protection || !maximum_protection ||
        !inheritance) {
        registers[0] = mach_receive_invalid_data;
        return true;
    }

    const auto requested_address = *address;
    auto effective_protection = *protection & ~vm_protection_is_mask;
    auto effective_maximum_protection =
        *maximum_protection & ~vm_protection_is_mask;
    const auto size = round_page_size(requested_size);
    std::uint32_t result = kern_success;
    if (*wide_address > UINT32_MAX || *wide_size > UINT32_MAX ||
        *wide_mask > UINT32_MAX || !size ||
        ((*flags & ~vm_flags_user_map) != 0) ||
        ((effective_protection | effective_maximum_protection) &
            ~vm_protection_mask) != 0 ||
        *inheritance > static_cast<std::uint32_t>(VmInheritance::None)) {
        result = kern_invalid_argument;
    }

    bool targets_current_task = false;
    std::optional<KernelSharedState::MachMemoryEntry> entry;
    if (result == kern_success) {
        std::lock_guard lock { shared_state_->mach_mutex };
        targets_current_task =
            target_task_for_port(*shared_state_, process_.pid,
                request.remote_port) == process_.pid;
        if (*object_name != 0) {
            const auto object = resolve_name_with_right(*shared_state_,
                process_.pid, *object_name, xnu::ipc::Right::Send);
            const auto found =
                object ? shared_state_->mach_memory_entries.find(*object)
                       : shared_state_->mach_memory_entries.end();
            if (found != shared_state_->mach_memory_entries.end())
                entry = found->second;
        }
    }
    if (result == kern_success && !targets_current_task)
        result = kern_invalid_argument;
    if (result == kern_success && *object_name != 0 && !entry)
        result = kern_invalid_argument;

    if (result == kern_success &&
        (*flags & darwin::mach::vm_flags_anywhere) != 0) {
        *address = find_free_guest_region(
            memory_, default_dynamic_base, *size, alignment_mask)
                       .value_or(0);
    }
    if (result == kern_success &&
        (*address == 0 || *address % AddressSpace::page_size != 0 ||
            (*address & alignment_mask) != 0U ||
            guest_region_overlaps(memory_, *address, *size))) {
        result = kern_no_space;
    }

    bool map_ok = false;
    if (result == kern_success && entry) {
        // VM_PROT_IS_MASK requests the intersection with a named entry's
        // permissions. Without it, exceeding those permissions remains an
        // error. The flag is a mapping operation, never a page permission.
        if ((*protection & vm_protection_is_mask) != 0U)
            effective_protection &= entry->protection;
        if ((*maximum_protection & vm_protection_is_mask) != 0U)
            effective_maximum_protection &= entry->protection;
        if (*object_offset % AddressSpace::page_size != 0 ||
            *object_offset > entry->size ||
            *size > entry->size - *object_offset) {
            result = kern_invalid_argument;
        } else if ((effective_protection & entry->protection) !=
                       effective_protection ||
                   (effective_maximum_protection & entry->protection) !=
                       effective_maximum_protection) {
            result = kern_protection_failure;
        } else {
            const auto first_page =
                entry->first_page + *object_offset / AddressSpace::page_size;
            const auto page_count = *size / AddressSpace::page_size;
            if (!entry->object || first_page > entry->object->pages.size() ||
                page_count > entry->object->pages.size() - first_page) {
                result = kern_invalid_argument;
            } else {
                const std::span<const std::shared_ptr<GuestPageBacking>> pages {
                    entry->object->pages.data() + first_page, page_count
                };
                const auto mode =
                    *copy != 0 ? AddressSpace::PageMappingMode::CopyOnWrite
                               : AddressSpace::PageMappingMode::Shared;
                map_ok = memory_.map_page_backings(*address, *size,
                    memory_permissions(effective_protection), pages, mode);
            }
        }
    } else if (result == kern_success) {
        map_ok = memory_.map(
            *address, *size, memory_permissions(effective_protection));
    }
    if (result == kern_success && !map_ok)
        result = kern_no_space;
    if (result == kern_success &&
        !memory_.inherit(*address, *size,
            static_cast<VmInheritance>(*inheritance))) {
        static_cast<void>(memory_.unmap(*address, *size));
        result = kern_invalid_argument;
    }

    std::vector<std::uint32_t> reply {
        darwin::mig_wire::message_bits(
            darwin::mig_wire::disposition_move_send_once),
        address_reply_size,
        request.local_port,
        0U,
        0U,
        request.identifier + 100U,
        0U,
        1U,
        result,
    };
    wire.append_address(reply, *address);
    if (!write_words(memory_, request.address, reply)) {
        registers[0] = mach_receive_invalid_data;
        return true;
    }

    output_.write(
        "[vm] map pid=" + std::to_string(process_.pid) + " interface=" +
        (is_mach_vm ? std::string { "mach_vm" } : std::string { "vm_map" }) +
        " requested=" + std::to_string(requested_address) + " address=" +
        std::to_string(*address) + " size=" + std::to_string(size.value_or(0)) +
        " mask=" + std::to_string(alignment_mask) +
        " flags=" + std::to_string(*flags) +
        " object=" + std::to_string(*object_name) + " offset=" +
        std::to_string(*object_offset) + " copy=" + std::to_string(*copy != 0) +
        " protection=" + std::to_string(*protection) +
        " effective-protection=" + std::to_string(effective_protection) +
        " inheritance=" + std::to_string(*inheritance) +
        " result=" + std::to_string(result) + "\n");
    registers[0] = kern_success;
    return true;
}

} // namespace shade
