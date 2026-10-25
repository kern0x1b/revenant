// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Carry the scheduling state that the run loop keeps from one slice to the
// next, and save and load it with the session snapshot.

#pragma once

#include <cstdint>
#include <optional>

#include "foundation/snapshot_io.hpp"
#include "mach/xnu_scheduler.hpp"

namespace emulator {

struct LoopCarriedState {
    std::optional<XnuThreadId> last_serial_thread;
    std::optional<XnuThreadId> scheduler_handoff_thread;
    std::optional<XnuThreadId> display_urgent_thread;
    std::optional<XnuThreadId> display_urgent_receiver_thread;
    std::optional<XnuThreadId> display_yielded_thread;
    std::uint64_t display_inflight_callback_sequence { };
    std::uint64_t diagnostic_display_yield_count { };
    std::uint64_t remaining_ticks { };
    std::uint64_t executed_ticks_since_catch_up { };
    std::uint64_t interaction_generation { 1U };
    std::optional<std::uint32_t> input_receiver_process;

    friend bool operator==(const LoopCarriedState&,
        const LoopCarriedState&) = default;
};

void save_loop_carried_state(
    snapshot::Writer& out, const LoopCarriedState& state);
[[nodiscard]] LoopCarriedState load_loop_carried_state(snapshot::Reader& in);

}
