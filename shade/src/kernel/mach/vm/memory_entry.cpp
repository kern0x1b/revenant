// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Create and share named guest memory-entry capabilities.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/vm_map.defs
// https://github.com/apple-oss-distributions/xnu/blob/xnu-1699.22.73/osfmk/mach/mach_vm.defs

#include "kernel/kernel.hpp"

#include "mach/mig_wire_abi.hpp"
#include "mach/vm_map_mig_ids.hpp"

#include <array>
#include <cstdint>
#include <limits>
#include <memory>
#include <new>
#include <string>

#include "../support.hpp"
#include "wire_reply.hpp"

namespace shade {
namespace {

    using namespace mach_support;
    using namespace mach_vm_support;

    constexpr std::uint32_t request_size = 68U;
    constexpr std::uint32_t success_reply_size = 56U;
    // XNU also publishes the same ARM32 memory-entry wire contract through
    // its mach_vm subsystem. Its routine number is relative to the 4800
    // mach_vm base rather than the vm_map subsystem's generated IDs.
    constexpr std::uint32_t mach_vm_make_memory_entry_identifier = 4817U;
    constexpr std::uint32_t kern_invalid_argument = 4U;
    constexpr std::uint32_t kern_invalid_value = 18U;
    constexpr std::uint32_t vm_protection_mask = 0x7U;
    constexpr std::uint32_t map_memory_flag_mask = 0x000f'0000U;
    constexpr std::uint32_t map_memory_named_create = 0x0002'0000U;
    constexpr std::uint32_t map_memory_purgable = 0x0004'0000U;

    [[nodiscard]] std::optional<std::uint32_t> round_page_size(
        std::uint64_t size)
    {
        constexpr auto mask = std::uint64_t { AddressSpace::page_size - 1U };
        if (size == 0 || size > maximum_message_io ||
            size > std::numeric_limits<std::uint32_t>::max() - mask)
            return std::nullopt;
        return static_cast<std::uint32_t>((size + mask) & ~mask);
    }

} // namespace

bool CompatibilityKernel::dispatch_mach_vm_memory_entry_message(
    Cpu& cpu, const MachMessageRequest& request)
{
    using xnu::mig::vm_map::Routine;
    const auto is_mach_vm =
        request.identifier == mach_vm_make_memory_entry_identifier;
    if (request.identifier !=
            mig_message_id(Routine::mach_make_memory_entry_64) &&
        !is_mach_vm)
        return false;

    auto& registers = cpu.registers();
    const auto fail_transport = [&] {
        registers[0] = mach_receive_invalid_data;
        return true;
    };
    const auto fail_kernel = [&](std::uint32_t result) {
        if (!write_simple_reply(memory_, request.address, request.local_port,
                request.identifier, result)) {
            return fail_transport();
        }
        registers[0] = kern_success;
        return true;
    };

    if (registers[2] < request_size || registers[3] < simple_reply_size)
        return fail_transport();

    const auto& arguments =
        xnu::mig::vm_map::mach_make_memory_entry_64_arguments;
    const auto requested_size =
        memory_.read64(request.address + arguments[1].request_offset);
    const auto requested_offset =
        memory_.read64(request.address + arguments[2].request_offset);
    const auto permission =
        memory_.read32(request.address + arguments[3].request_offset);
    const auto parent_name =
        memory_.read32(request.address + arguments[5].request_offset);
    if (!requested_size || !requested_offset || !permission || !parent_name)
        return fail_transport();

    const auto rounded_size = round_page_size(*requested_size);
    if (!rounded_size)
        return fail_kernel(kern_resource_shortage);
    if ((*permission & map_memory_flag_mask) &
        ~(map_memory_named_create | map_memory_purgable)) {
        return fail_kernel(kern_invalid_value);
    }

    bool targets_current_task = false;
    std::optional<KernelSharedState::MachMemoryEntry> parent;
    {
        std::lock_guard lock { shared_state_->mach_mutex };
        targets_current_task =
            target_task_for_port(*shared_state_, process_.pid,
                request.remote_port) == process_.pid;
        if (*parent_name != 0) {
            const auto object = resolve_name_with_right(*shared_state_,
                process_.pid, *parent_name, xnu::ipc::Right::Send);
            const auto entry =
                object ? shared_state_->mach_memory_entries.find(*object)
                       : shared_state_->mach_memory_entries.end();
            if (entry == shared_state_->mach_memory_entries.end())
                return fail_kernel(kern_invalid_argument);
            parent = entry->second;
        }
    }
    if (!targets_current_task)
        return fail_kernel(kern_invalid_argument);

    KernelSharedState::MachMemoryEntry entry;
    entry.size = *rounded_size;
    entry.protection = *permission & vm_protection_mask;
    entry.purgable = (*permission & map_memory_purgable) != 0;

    if ((*permission & map_memory_named_create) != 0) {
        entry.object = std::make_shared<KernelSharedState::MachMemoryObject>();
        try {
            entry.object->pages.reserve(
                *rounded_size / AddressSpace::page_size);
            for (std::uint32_t offset = 0; offset < *rounded_size;
                offset += AddressSpace::page_size) {
                entry.object->pages.push_back(
                    std::make_shared<GuestPageBacking>());
            }
        } catch (const std::bad_alloc&) {
            return fail_kernel(kern_resource_shortage);
        }
    } else if (parent) {
        if (*requested_offset % AddressSpace::page_size != 0 ||
            *requested_offset > parent->size ||
            *rounded_size > parent->size - *requested_offset ||
            (entry.protection & parent->protection) != entry.protection) {
            return fail_kernel(kern_invalid_argument);
        }
        entry.object = parent->object;
        entry.first_page =
            parent->first_page + *requested_offset / AddressSpace::page_size;
    } else {
        if (*requested_offset > std::numeric_limits<std::uint32_t>::max())
            return fail_kernel(kern_invalid_address);
        const auto source = static_cast<std::uint32_t>(*requested_offset) &
                            ~(AddressSpace::page_size - 1U);
        auto pages = memory_.share_pages(source, *rounded_size);
        if (!pages)
            return fail_kernel(kern_invalid_address);
        entry.object = std::make_shared<KernelSharedState::MachMemoryObject>();
        entry.object->pages = std::move(*pages);
    }

    if (registers[3] < success_reply_size)
        return fail_transport();

    std::uint32_t object_name = 0;
    std::uint32_t object_identifier = 0;
    {
        std::lock_guard lock { shared_state_->mach_mutex };
        object_identifier = shared_state_->allocate_mach_object();
        if (!shared_state_->mach_port_objects.create(object_identifier))
            return fail_kernel(kern_resource_shortage);
        shared_state_->mach_queues.try_emplace(object_identifier);
        shared_state_->mach_memory_entries.emplace(object_identifier, entry);
        object_name = shared_state_->mach_namespaces
                          .copyout(process_.pid, object_identifier,
                              xnu::ipc::type_mask(xnu::ipc::Right::Send))
                          .value_or(0);
        if (object_name == 0) {
            remove_port_object_locked(*shared_state_, object_identifier);
            return fail_kernel(kern_resource_shortage);
        }
    }

    const std::array<std::uint32_t, success_reply_size / sizeof(std::uint32_t)>
        reply {
            darwin::mig_wire::message_bits(
                darwin::mig_wire::disposition_move_send_once, 0, true),
            success_reply_size,
            request.local_port,
            0U,
            0U,
            request.identifier + 100U,
            1U,
            object_name,
            0U,
            darwin::mig_wire::port_descriptor_metadata(
                darwin::mig_wire::disposition_move_send),
            0U,
            1U,
            *rounded_size,
            0U,
        };
    if (!write_words(memory_, request.address, reply))
        return fail_transport();

    output_.write("[vm] memory-entry pid=" + std::to_string(process_.pid) +
                  " object=" + std::to_string(object_identifier) +
                  " name=" + std::to_string(object_name) +
                  " offset=" + std::to_string(*requested_offset) +
                  " size=" + std::to_string(*rounded_size) + " protection=" +
                  std::to_string(entry.protection) + " named=" +
                  std::to_string((*permission & map_memory_named_create) != 0) +
                  " result=0\n");
    registers[0] = kern_success;
    return true;
}

} // namespace shade
