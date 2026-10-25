// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "runtime/loop_carried_state.hpp"

namespace emulator {

namespace {

void save_thread(snapshot::Writer& out, const std::optional<XnuThreadId>& thread)
{
    snapshot::save(out, thread.has_value());
    if (!thread)
        return;
    snapshot::save(out, thread->process);
    snapshot::save(out, thread->thread);
}

void load_thread(snapshot::Reader& in, std::optional<XnuThreadId>& thread)
{
    bool present { };
    snapshot::load(in, present);
    if (!present) {
        thread.reset();
        return;
    }
    XnuThreadId loaded { };
    snapshot::load(in, loaded.process);
    snapshot::load(in, loaded.thread);
    thread = loaded;
}

}

void save_loop_carried_state(
    snapshot::Writer& out, const LoopCarriedState& state)
{
    save_thread(out, state.last_serial_thread);
    save_thread(out, state.scheduler_handoff_thread);
    save_thread(out, state.display_urgent_thread);
    save_thread(out, state.display_urgent_receiver_thread);
    save_thread(out, state.display_yielded_thread);
    snapshot::save(out, state.display_inflight_callback_sequence);
    snapshot::save(out, state.diagnostic_display_yield_count);
    snapshot::save(out, state.remaining_ticks);
    snapshot::save(out, state.executed_ticks);
    snapshot::save(out, state.executed_ticks_since_catch_up);
    snapshot::save(out, state.interaction_generation);
    snapshot::save(out, state.input_receiver_process);
}

LoopCarriedState load_loop_carried_state(snapshot::Reader& in)
{
    LoopCarriedState state;
    load_thread(in, state.last_serial_thread);
    load_thread(in, state.scheduler_handoff_thread);
    load_thread(in, state.display_urgent_thread);
    load_thread(in, state.display_urgent_receiver_thread);
    load_thread(in, state.display_yielded_thread);
    snapshot::load(in, state.display_inflight_callback_sequence);
    snapshot::load(in, state.diagnostic_display_yield_count);
    snapshot::load(in, state.remaining_ticks);
    snapshot::load(in, state.executed_ticks);
    snapshot::load(in, state.executed_ticks_since_catch_up);
    snapshot::load(in, state.interaction_generation);
    snapshot::load(in, state.input_receiver_process);
    return state;
}

}
