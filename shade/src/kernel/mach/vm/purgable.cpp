// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Handle guest purgeable-memory state queries and transitions.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/vm_map.defs
// https://github.com/apple-oss-distributions/xnu/blob/xnu-1699.22.73/osfmk/mach/mach_vm.defs

#include "kernel/kernel.hpp"

#include "mach/mig_wire_abi.hpp"
#include "mach/vm_map_mig_ids.hpp"

#include <array>
#include <cstdint>
#include <string>

#include "../support.hpp"
#include "wire_reply.hpp"

namespace shade {
namespace {

    // Darwin also publishes this routine in the mach_vm subsystem. ARM32 keeps
    // the same scalar request/reply layout while the subsystem-relative ID
    // moves.
    constexpr std::uint32_t mach_vm_purgable_control_identifier = 4818U;
    constexpr std::uint32_t request_size = 44U;
    constexpr std::uint32_t reply_size = 40U;
    constexpr std::uint32_t kern_invalid_argument = 4U;

    constexpr std::uint32_t vm_purgable_set_state = 0U;
    constexpr std::uint32_t vm_purgable_get_state = 1U;
    constexpr std::uint32_t vm_purgable_nonvolatile = 0U;
    constexpr std::uint32_t vm_purgable_state_mask = 3U;
    // A state word also carries a volatile group (bits 8-10), a behavior
    // (bit 6), an ordering (bit 5), an obsolete order flag (bit 4) and debug
    // flags (bits 12-13); osfmk/mach/vm_purgable.h in xnu-2050.48.11 names
    // them VM_PURGABLE_ALL_MASKS together with the state. vm_map_purgable_control
    // refuses a set request with any other bit, and the object keeps only the
    // state: the queue a volatile object waits in is not part of what a state
    // query or the previous state answers.
    constexpr std::uint32_t vm_purgable_all_masks =
        vm_purgable_state_mask | (1U << 4U) | (1U << 5U) | (1U << 6U) |
        (7U << 8U) | (3U << 12U);

    constexpr std::uint32_t page_base(std::uint32_t address)
    {
        return address & ~(AddressSpace::page_size - 1U);
    }

} // namespace

bool CompatibilityKernel::dispatch_mach_vm_purgable_message(
    Cpu& cpu, const MachMessageRequest& request)
{
    using namespace mach_support;
    using namespace mach_vm_support;

    const auto is_mach_vm =
        request.identifier == mach_vm_purgable_control_identifier;
    if (request.identifier !=
            mig_message_id(xnu::mig::vm_map::Routine::vm_purgable_control) &&
        !is_mach_vm) {
        return false;
    }

    auto& registers = cpu.registers();
    const auto fail_transport = [&] {
        registers[0] = mach_receive_invalid_data;
        return true;
    };
    if (registers[2] < request_size || registers[3] < reply_size)
        return fail_transport();

    const auto& arguments = xnu::mig::vm_map::vm_purgable_control_arguments;
    const auto address =
        memory_.read32(request.address + arguments[1].request_offset);
    const auto control =
        memory_.read32(request.address + arguments[2].request_offset);
    const auto input_state =
        memory_.read32(request.address + arguments[3].request_offset);
    if (!address || !control || !input_state)
        return fail_transport();

    std::uint32_t result = kern_success;
    std::uint32_t output_state = *input_state;
    bool targets_current_task = false;
    {
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        targets_current_task =
            target_task_for_port(*shared_state_, process_.pid,
                request.remote_port) == process_.pid;
    }

    if (!targets_current_task) {
        result = kern_invalid_argument;
    } else if (!memory_.mapped(*address)) {
        result = kern_invalid_address;
    } else if (*control == vm_purgable_get_state) {
        const auto state = vm_purgable_states_.find(page_base(*address));
        output_state = state == vm_purgable_states_.end()
                           ? vm_purgable_nonvolatile
                           : state->second;
    } else if (*control == vm_purgable_set_state &&
               (*input_state & ~vm_purgable_all_masks) == 0U) {
        const auto key = page_base(*address);
        const auto previous = vm_purgable_states_.find(key);
        output_state = previous == vm_purgable_states_.end()
                           ? vm_purgable_nonvolatile
                           : previous->second;
        vm_purgable_states_[key] = *input_state & vm_purgable_state_mask;
    } else {
        result = kern_invalid_argument;
    }

    const std::array<std::uint32_t, reply_size / sizeof(std::uint32_t)> reply {
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
        output_state,
    };
    if (!write_words(memory_, request.address, reply))
        return fail_transport();

    output_.write(
        "[vm] purgable pid=" + std::to_string(process_.pid) + " interface=" +
        (is_mach_vm ? std::string { "mach_vm" } : std::string { "vm_map" }) +
        " address=" + std::to_string(*address) +
        " control=" + std::to_string(*control) +
        " input-state=" + std::to_string(*input_state) +
        " output-state=" + std::to_string(output_state) +
        " result=" + std::to_string(result) + "\n");
    registers[0] = kern_success;
    return true;
}

} // namespace shade
