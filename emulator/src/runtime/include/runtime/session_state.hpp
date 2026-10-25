// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Save the guest state of a stopped session. State that the snapshot does
// not cover is refused by name before anything is written.

#pragma once

#include <cstddef>
#include <cstdint>

#include "foundation/snapshot_io.hpp"
#include "mach/xnu_scheduler.hpp"
#include "runtime/loop_carried_state.hpp"

namespace emulator {

namespace runtime_detail {
struct Runtime;
}

void save_session_state(snapshot::Writer& out,
    runtime_detail::Runtime& initial, std::size_t runtime_count,
    const XnuScheduler& scheduler, const LoopCarriedState& loop_state,
    std::uint32_t next_pid);

void load_session_state(snapshot::Reader& in,
    runtime_detail::Runtime& initial, XnuScheduler& scheduler,
    LoopCarriedState& loop_state, std::uint32_t& next_pid);

}
