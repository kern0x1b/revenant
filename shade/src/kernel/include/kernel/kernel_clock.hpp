// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Implement guest Mach clock services and clock-related message
// replies.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/clock.defs
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/kern/clock.c

#pragma once

#include <cstdint>
#include <optional>

namespace shade {

struct KernelSharedState;
struct ProcessContext;
class AddressSpace;

[[nodiscard]] std::optional<std::uint32_t> handle_clock_mach_request(
    AddressSpace& memory, KernelSharedState& state, ProcessContext& process,
    std::uint32_t message_id, std::uint32_t message_address,
    std::uint32_t send_size, std::uint32_t receive_size,
    std::uint32_t remote_port, std::uint32_t local_port);

// The caller holds KernelSharedState::mach_mutex for every locked operation.
void enqueue_clock_alarm_reply_locked(KernelSharedState& state,
    std::uint32_t reply_object, std::uint32_t code, std::uint32_t alarm_type,
    std::uint64_t alarm_time);

[[nodiscard]] std::optional<std::uint64_t> next_clock_alarm_deadline_locked(
    const KernelSharedState& state);

void deliver_due_clock_alarms_locked(
    KernelSharedState& state, std::uint64_t deadline);

} // namespace shade
