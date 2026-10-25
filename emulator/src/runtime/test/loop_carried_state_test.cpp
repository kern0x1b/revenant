// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "runtime/loop_carried_state.hpp"

#include <cstddef>
#include <cstdint>
#include <iostream>
#include <span>
#include <string>
#include <vector>

#include "foundation/snapshot_io.hpp"

namespace {

using emulator::LoopCarriedState;
using emulator::XnuThreadId;

int failures = 0;

void expect(bool condition, const std::string& what)
{
    if (condition)
        return;
    std::cerr << "FAIL: " << what << '\n';
    ++failures;
}

LoopCarriedState populated_state()
{
    LoopCarriedState state;
    state.last_serial_thread = XnuThreadId { 1U, 2U };
    state.scheduler_handoff_thread = XnuThreadId { 3U, 4U };
    state.display_urgent_thread = XnuThreadId { 5U, 6U };
    state.display_urgent_receiver_thread = XnuThreadId { 7U, 8U };
    state.display_yielded_thread = XnuThreadId { 9U, 10U };
    state.display_inflight_callback_sequence = 11;
    state.diagnostic_display_yield_count = 12;
    state.remaining_ticks = 13;
    state.executed_ticks = 18;
    state.executed_ticks_since_catch_up = 14;
    state.interaction_generation = 15;
    state.input_receiver_process = 16U;
    return state;
}

std::vector<std::byte> save(const LoopCarriedState& state)
{
    emulator::snapshot::Writer out;
    emulator::save_loop_carried_state(out, state);
    return std::move(out.bytes());
}

void round_trip_restores_every_field()
{
    const auto original = populated_state();
    const auto bytes = save(original);
    emulator::snapshot::Reader in { bytes };
    const auto restored = emulator::load_loop_carried_state(in);
    expect(restored == original, "every loop field survives the round trip");
    expect(in.at_end(), "the loop state stream is consumed exactly");
    expect(save(restored) == bytes, "save, load and save reproduce the bytes");
}

void round_trip_keeps_absent_threads_absent()
{
    const LoopCarriedState original;
    const auto bytes = save(original);
    emulator::snapshot::Reader in { bytes };
    const auto restored = emulator::load_loop_carried_state(in);
    expect(restored == original, "a fresh loop state round trips");
    expect(!restored.last_serial_thread && !restored.display_yielded_thread &&
            !restored.input_receiver_process,
        "absent optionals stay absent");
    expect(restored.interaction_generation == 1U,
        "the first interaction generation is 1");
    expect(in.at_end(), "a fresh loop state stream is consumed exactly");
}

void truncated_stream_is_a_format_error()
{
    const auto bytes = save(populated_state());
    const std::vector<std::byte> truncated(bytes.begin(), bytes.end() - 1);
    bool rejected = false;
    try {
        emulator::snapshot::Reader in { truncated };
        static_cast<void>(emulator::load_loop_carried_state(in));
    } catch (const emulator::snapshot::FormatError&) {
        rejected = true;
    }
    expect(rejected, "a truncated loop state is a format error");
}

}

int main()
{
    round_trip_restores_every_field();
    round_trip_keeps_absent_threads_absent();
    truncated_stream_is_a_format_error();

    if (failures != 0) {
        std::cerr << failures << " loop carried state checks failed\n";
        return 1;
    }
    std::cout << "loop carried state checks passed\n";
    return 0;
}
