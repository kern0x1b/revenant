// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Handle guest Mach port context reads and updates.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/mach_port.defs
// https://github.com/apple-oss-distributions/xnu/blob/xnu-1228.15.4/osfmk/mach/mach_port.defs

#include "kernel/kernel.hpp"

#include "kernel/darwin_abi.hpp"
#include "mach/mig_wire_abi.hpp"

#include "../support.hpp"
#include "../vm/wire_format.hpp"

#include <cstddef>
#include <cstdint>
#include <mutex>
#include <optional>
#include <vector>

namespace shade {
namespace {

    // Context accessors extend the base mach_port subsystem used for the
    // adapter table. MIG represents the context as mach_vm_address_t, even
    // when the public ARM32 wrapper exposes a natural-sized context pointer.
    constexpr std::uint32_t mach_port_get_context_identifier = 3228U;
    constexpr std::uint32_t mach_port_set_context_identifier = 3229U;
    constexpr std::uint32_t get_request_size = 36U;
    constexpr std::uint32_t simple_reply_size = 36U;
    constexpr std::uint32_t name_offset = 32U;
    constexpr std::uint32_t context_offset = 36U;

} // namespace

bool CompatibilityKernel::dispatch_mach_port_context_message(
    Cpu& cpu, const MachMessageRequest& request)
{
    const auto is_get = request.identifier == mach_port_get_context_identifier;
    if (!is_get && request.identifier != mach_port_set_context_identifier)
        return false;

    auto& registers = cpu.registers();
    const auto wire = mach_vm_support::MachVmWireFormat::for_interface(
        true, shared_state_->darwin_abi.mach_port_context);
    const auto set_request_size = context_offset + wire.address_size();
    const auto get_success_reply_size = simple_reply_size + wire.address_size();
    const auto required_request_size =
        is_get ? get_request_size : set_request_size;
    const auto required_reply_size =
        is_get ? get_success_reply_size : simple_reply_size;
    if (registers[2] < required_request_size ||
        registers[3] < required_reply_size) {
        registers[0] = darwin::mach_message::receive_invalid_data;
        return true;
    }
    const auto name = memory_.read32(request.address + name_offset);
    const auto supplied_context =
        is_get ? std::optional<std::uint64_t> { 0U }
               : wire.read_address(memory_, request.address + context_offset);
    if (!name || !supplied_context) {
        registers[0] = darwin::mach_message::receive_invalid_data;
        return true;
    }

    auto result = darwin::mach::success;
    std::uint64_t returned_context = 0U;
    {
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        const auto target = mach_support::target_task_for_port(
            *shared_state_, process_.pid, request.remote_port);
        const auto entry =
            target ? shared_state_->mach_namespaces.lookup(*target, *name)
                   : std::nullopt;
        if (!target) {
            result = darwin::mach::invalid_task;
        } else if (!entry) {
            result = darwin::mach::invalid_name;
        } else if ((entry->type & xnu::ipc::type_mask(
                                      xnu::ipc::Right::Receive)) == 0U) {
            result = darwin::mach::invalid_right;
        } else if (is_get) {
            const auto port = shared_state_->mach_port_objects.lookup(entry->object);
            const auto context =
                shared_state_->mach_port_contexts.find(entry->object);
            if (context != shared_state_->mach_port_contexts.end() &&
                (!port || !port->strict_guard)) {
                returned_context = context->second;
            }
        } else {
            const auto port = shared_state_->mach_port_objects.lookup(entry->object);
            if (port && port->strict_guard) {
                result = darwin::mach::invalid_argument;
            } else {
                shared_state_->mach_port_contexts[entry->object] = *supplied_context;
                if (port && port->guard)
                    static_cast<void>(shared_state_->mach_port_objects.set_guard(
                        entry->object, *supplied_context));
            }
        }
    }

    std::vector<std::uint32_t> reply {
            darwin::mig_wire::message_bits(
                darwin::mig_wire::disposition_move_send_once),
            is_get && result == darwin::mach::success ? get_success_reply_size
                                                      : simple_reply_size,
            request.local_port,
            0U,
            0U,
            request.identifier + 100U,
            0U,
            1U,
            result,
        };
    if (is_get && result == darwin::mach::success)
        wire.append_address(reply, returned_context);
    const auto reply_word_count =
        (is_get && result == darwin::mach::success ? get_success_reply_size
                                                   : simple_reply_size) /
        sizeof(std::uint32_t);
    for (std::size_t index = 0; index < reply_word_count; ++index) {
        if (!memory_.write32(
                request.address +
                    static_cast<std::uint32_t>(index * sizeof(std::uint32_t)),
                reply[index])) {
            registers[0] = darwin::mach_message::receive_invalid_data;
            return true;
        }
    }
    registers[0] = darwin::mach::success;
    return true;
}

} // namespace shade
