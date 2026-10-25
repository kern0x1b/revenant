// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "kernel/kernel_shared_state.hpp"

#include "foundation/snapshot_io.hpp"

#include <cstddef>
#include <cstdint>
#include <iostream>
#include <string>
#include <vector>

namespace {

using emulator::KernelSharedState;
using emulator::snapshot::FormatError;
using emulator::snapshot::Reader;
using emulator::snapshot::Writer;

int failures = 0;

void expect(bool condition, const std::string& what)
{
    if (condition)
        return;
    std::cerr << "FAIL: " << what << '\n';
    ++failures;
}

void populate(KernelSharedState& state)
{
    state.hostname = "snapshot-host";
    state.desired_vnodes = 4096;
    state.next_kernel_event_identifier = 11;
    state.next_route_message_identifier = 12;
    state.next_route_socket_identifier = 13;
    state.next_mach_object = 0x20100;
    state.next_mach_wait_queue_sequence = 14;
    state.mach_queue_generation = 15;
    state.kernel_event_generation = 16;
    state.shared_timer_deadline_cache_generation = 17;
    state.shared_timer_deadline_cache = 18;
    state.shared_timer_deadline_cache_valid = true;
    state.io_event_generation = 19;
    state.next_graphics_input_sequence = 20;
    state.next_application_launch_token = 21;
    state.next_process_incarnation = 22;
    state.next_audit_identity_version = 23;
    state.next_foreground_transition_generation = 24;
    state.next_foreground_layer_sequence = 25;
    state.next_clock_alarm = 26;
    state.next_keybag_handle = 27;
    state.wifi_service_available = true;
    state.next_socket_pair = 28;
    state.next_shared_memory_object = 29;
}

std::vector<std::byte> save_scalars(const KernelSharedState& state)
{
    Writer out;
    state.save_scalar_state(out);
    return out.bytes();
}

void round_trip_restores_the_scalars()
{
    KernelSharedState source;
    populate(source);
    const auto bytes = save_scalars(source);

    KernelSharedState restored;
    expect(save_scalars(restored) != bytes,
        "a fresh state saves differently from the populated one");
    Reader in { bytes };
    restored.load_scalar_state(in);
    expect(in.at_end(), "the scalar stream is consumed");
    expect(restored.hostname == "snapshot-host", "the host name is restored");
    expect(restored.mach_queue_generation.load() == 15,
        "an atomic generation is restored");
    expect(restored.wifi_service_available, "the wifi flag is restored");
    expect(save_scalars(restored) == bytes,
        "saving the restored state reproduces the same stream");
}

void truncated_stream_is_a_format_error()
{
    KernelSharedState source;
    populate(source);
    const auto bytes = save_scalars(source);
    const std::vector<std::byte> truncated { bytes.begin(),
        bytes.begin() + static_cast<std::ptrdiff_t>(bytes.size() / 2) };
    KernelSharedState restored;
    bool threw = false;
    try {
        Reader in { truncated };
        restored.load_scalar_state(in);
    } catch (const FormatError&) {
        threw = true;
    }
    expect(threw, "a truncated scalar stream throws FormatError");
}

}

int main()
{
    round_trip_restores_the_scalars();
    truncated_stream_is_a_format_error();
    if (failures != 0) {
        std::cerr << failures << " kernel shared state snapshot checks failed\n";
        return 1;
    }
    std::cout << "kernel shared state snapshot checks passed\n";
    return 0;
}
