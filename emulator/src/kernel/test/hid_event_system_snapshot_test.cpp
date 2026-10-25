// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "kernel/hid_accelerometer.hpp"
#include "kernel/hid_event_system_hle.hpp"

#include "foundation/address_space.hpp"
#include "foundation/output.hpp"
#include "foundation/snapshot_io.hpp"
#include "foundation/userland_hle.hpp"

#include <cstddef>
#include <cstdint>
#include <iostream>
#include <optional>
#include <sstream>
#include <string>
#include <vector>

namespace {

using emulator::AddressSpace;
using emulator::HidAccelerometer;
using emulator::HidEventSystemHle;
using emulator::Output;
using emulator::UserlandHleRegistry;
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

template <typename T> std::vector<std::byte> save_state(const T& state)
{
    Writer out;
    state.save(out);
    return out.bytes();
}

void accelerometer_round_trip_keeps_the_deadline()
{
    HidAccelerometer source;
    source.start(12'345U);
    const auto bytes = save_state(source);
    HidAccelerometer restored;
    Reader in { bytes };
    restored.load(in);
    expect(in.at_end(), "the accelerometer stream is consumed");
    expect(restored.next_deadline() == source.next_deadline(),
        "a running accelerometer keeps its next deadline");
    expect(restored.next_deadline().has_value(),
        "the restored accelerometer is running");

    source.stop();
    const auto stopped_bytes = save_state(source);
    HidAccelerometer stopped;
    Reader stopped_in { stopped_bytes };
    stopped.load(stopped_in);
    expect(!stopped.next_deadline().has_value(),
        "a stopped accelerometer stays stopped");
}

void event_system_round_trip_keeps_the_idle_state()
{
    std::ostringstream log;
    Output output { log };
    AddressSpace memory;
    UserlandHleRegistry source_registry { memory, output };
    UserlandHleRegistry restored_registry { memory, output };
    HidEventSystemHle source { source_registry };
    HidEventSystemHle restored { restored_registry };
    const auto bytes = save_state(source);
    Reader in { bytes };
    restored.load(in);
    expect(in.at_end(), "the HID stream is consumed");
    expect(save_state(restored) == bytes,
        "saving the restored HID state reproduces the same stream");
    expect(restored.next_sample_deadline() == source.next_sample_deadline(),
        "the restored HID state has the same sample deadline");
}

void truncated_event_system_is_a_format_error()
{
    std::ostringstream log;
    Output output { log };
    AddressSpace memory;
    UserlandHleRegistry registry { memory, output };
    HidEventSystemHle source { registry };
    const auto bytes = save_state(source);
    const std::vector<std::byte> truncated { bytes.begin(),
        bytes.begin() + static_cast<std::ptrdiff_t>(bytes.size() - 1U) };

    UserlandHleRegistry restored_registry { memory, output };
    HidEventSystemHle restored { restored_registry };
    bool threw = false;
    try {
        Reader in { truncated };
        restored.load(in);
    } catch (const FormatError&) {
        threw = true;
    }
    expect(threw, "a truncated HID stream throws FormatError");
}

}

int main()
{
    accelerometer_round_trip_keeps_the_deadline();
    event_system_round_trip_keeps_the_idle_state();
    truncated_event_system_is_a_format_error();
    if (failures != 0) {
        std::cerr << failures << " HID event system snapshot checks failed\n";
        return 1;
    }
    std::cout << "HID event system snapshot checks passed\n";
    return 0;
}
