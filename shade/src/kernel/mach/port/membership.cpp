// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Update guest Mach port-set membership and readiness linkage.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/mach_port.defs

#include "kernel/kernel.hpp"

#include "kernel/darwin_abi.hpp"
#include "mach/mach_port_mig_ids.hpp"
#include "mach/mach_port_object.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <mutex>
#include <string>

#include "../support.hpp"

namespace shade {
namespace {

    using namespace mach_support;

    constexpr std::uint32_t mach_message_success = 0;
    constexpr std::uint32_t mach_receive_invalid_data = 0x10004008U;
    constexpr std::uint32_t reply_size = 36;

} // namespace

bool CompatibilityKernel::dispatch_mach_port_membership_message(
    Cpu& cpu, const MachMessageRequest& request)
{
    using Routine = xnu::mig::mach_port::Routine;
    const auto routine = static_cast<Routine>(request.identifier);
    if (routine != Routine::mach_port_move_member &&
        routine != Routine::mach_port_insert_member &&
        routine != Routine::mach_port_extract_member) {
        return false;
    }

    auto& registers = cpu.registers();
    if (registers[3] < reply_size) {
        return false;
    }
    const auto& arguments =
        routine == Routine::mach_port_move_member
            ? xnu::mig::mach_port::mach_port_move_member_arguments
        : routine == Routine::mach_port_insert_member
            ? xnu::mig::mach_port::mach_port_insert_member_arguments
            : xnu::mig::mach_port::mach_port_extract_member_arguments;
    const auto member =
        memory_.read32(request.address + arguments[1].request_offset)
            .value_or(0);
    const auto set_name =
        memory_.read32(request.address + arguments[2].request_offset)
            .value_or(0);

    PortMembershipResult membership;
    std::uint32_t target_pid = 0;
    {
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        const auto target = target_task_for_port(
            *shared_state_, process_.pid, request.remote_port);
        target_pid = target.value_or(0);
        if (!target) {
            membership.result = darwin::mach::invalid_task;
        } else {
            const auto operation =
                routine == Routine::mach_port_move_member
                    ? PortMembershipOperation::Move
                : routine == Routine::mach_port_insert_member
                    ? PortMembershipOperation::Insert
                    : PortMembershipOperation::Extract;
            membership = modify_port_membership_locked(
                *shared_state_, *target, member, set_name, operation);
        }
    }

    const std::array<std::uint32_t, 9> reply {
        18,
        reply_size,
        request.local_port,
        0,
        0,
        request.identifier + 100,
        0,
        1,
        membership.result,
    };
    for (std::size_t index = 0; index < reply.size(); ++index) {
        if (!memory_.write32(
                request.address + static_cast<std::uint32_t>(index * 4U),
                reply[index])) {
            registers[0] = mach_receive_invalid_data;
            return true;
        }
    }
    registers[0] = mach_message_success;
    output_.write("[mach] port-membership pid=" + std::to_string(process_.pid) +
                  " target=" + std::to_string(target_pid) +
                  " id=" + std::to_string(request.identifier) +
                  " member=" + std::to_string(member) +
                  " member-object=" +
                  std::to_string(membership.member_object) +
                  " set=" + std::to_string(set_name) +
                  " set-object=" + std::to_string(membership.set_object) +
                  " set-members=" +
                  std::to_string(membership.set_member_count) +
                  " result=" + std::to_string(membership.result) + "\n");
    return true;
}

} // namespace shade
