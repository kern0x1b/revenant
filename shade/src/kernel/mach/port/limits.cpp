// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Handle guest Mach port queue-limit and attribute operations.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/mach_port.defs

#include "kernel/kernel.hpp"

#include "kernel/darwin_abi.hpp"
#include "mach/mach_port_mig_ids.hpp"
#include "mach/mach_port_object.hpp"
#include "mach/mig_wire_abi.hpp"

#include <array>
#include <cstddef>
#include <cstdint>

#include "../support.hpp"

namespace shade {

bool CompatibilityKernel::dispatch_mach_port_limit_message(
    Cpu& cpu, const MachMessageRequest& request)
{
    if (request.identifier !=
        mach_support::mig_message_id(
            xnu::mig::mach_port::Routine::mach_port_set_attributes)) {
        return false;
    }

    auto& registers = cpu.registers();
    const auto& arguments =
        xnu::mig::mach_port::mach_port_set_attributes_arguments;
    // The inline attribute array may be empty (MACH_PORT_TEMPOWNER).
    constexpr std::uint32_t minimum_request_size = 44;
    std::uint32_t result = darwin::mach::success;
    std::uint32_t name = xnu::ipc::null_name;
    std::uint32_t flavor = 0;
    std::uint32_t count = 0;
    std::uint32_t queue_limit = 0;
    if (registers[2] < minimum_request_size) {
        result = darwin::mach::invalid_argument;
    } else {
        name = memory_.read32(request.address + arguments[1].request_offset)
                   .value_or(xnu::ipc::null_name);
        flavor = memory_.read32(request.address + arguments[2].request_offset)
                     .value_or(0);
        count =
            memory_.read32(request.address + arguments[3].request_count_offset)
                .value_or(0);
        queue_limit = count == 0U ? 0U :
            memory_.read32(request.address + arguments[3].request_offset)
                .value_or(xnu::ipc::maximum_queue_limit + 1U);
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        const auto target = mach_support::target_task_for_port(
            *shared_state_, process_.pid, request.remote_port);
        const auto entry =
            target ? shared_state_->mach_namespaces.lookup(*target, name)
                   : std::nullopt;
        if (count > (registers[2] - minimum_request_size) / 4U) {
            result = darwin::mach::invalid_argument;
        } else if (!target) {
            result = darwin::mach::invalid_task;
        } else if (flavor != 1U && flavor != 4U) {
            result = darwin::mach::invalid_argument;
        } else if (flavor == 1U && count < 1U) {
            result = darwin::mach::failure;
        } else if (flavor == 1U && queue_limit > xnu::ipc::maximum_queue_limit) {
            result = darwin::mach::invalid_value;
        } else if (name == xnu::ipc::null_name ||
                   name == xnu::ipc::dead_name) {
            result = darwin::mach::invalid_right;
        } else if (!entry) {
            result = darwin::mach::invalid_name;
        } else if ((entry->type & xnu::ipc::type_mask(
                                      xnu::ipc::Right::Receive)) == 0) {
            result = darwin::mach::invalid_right;
        } else if (flavor == 4U) { // MACH_PORT_TEMPOWNER
            if (!shared_state_->mach_port_objects.set_temporary_owner(
                    entry->object))
                result = darwin::mach::invalid_argument;
        } else if (!shared_state_->mach_port_objects.set_queue_limit(
                       entry->object, queue_limit)) {
            result = darwin::mach::failure;
        } else {
            shared_state_->notify_send_possible_locked(entry->object);
        }
    }

    const std::array<std::uint32_t, 9> reply {
        darwin::mig_wire::disposition_move_send_once,
        36,
        request.local_port,
        0,
        0,
        request.identifier + 100U,
        0,
        1,
        result,
    };
    for (std::size_t index = 0; index < reply.size(); ++index) {
        if (!memory_.write32(
                request.address +
                    static_cast<std::uint32_t>(index * sizeof(std::uint32_t)),
                reply[index])) {
            registers[0] = 0x10004008U; // MACH_RCV_INVALID_DATA
            return true;
        }
    }
    output_.write("[mach] port-limit pid=" + std::to_string(process_.pid) +
                  " name=" + std::to_string(name) + " flavor=" +
                  std::to_string(flavor) + " count=" + std::to_string(count) +
                  " limit=" + std::to_string(queue_limit) +
                  " result=" + std::to_string(result) + "\n");
    registers[0] = 0;
    return true;
}

} // namespace shade
