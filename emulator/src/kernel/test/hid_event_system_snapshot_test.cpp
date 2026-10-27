// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "kernel/hid_accelerometer.hpp"
#include "kernel/hid_event_system_hle.hpp"

#include "foundation/address_space.hpp"
#include "foundation/output.hpp"
#include "foundation/snapshot_io.hpp"
#include "foundation/snapshot_member.hpp"
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

void descriptors_name_the_saved_fields_in_order()
{
    std::vector<std::string> names;
    for (const auto& member : HidEventSystemHle::snapshot_members())
        names.emplace_back(member.name);
    const std::vector<std::string> expected {
        "hid.consumer_process_",
        "hid.consumer_processor_",
        "hid.accelerometer_",
    };
    expect(names == expected, "the HID members are named in save order");
}

void fresh_layout_is_fixed()
{
    std::ostringstream log;
    Output output { log };
    AddressSpace memory;
    UserlandHleRegistry registry { memory, output };
    const HidEventSystemHle fresh { registry };
    Writer expected;
    emulator::snapshot::save(expected, static_cast<std::uint32_t>(0));
    emulator::snapshot::save(expected, static_cast<std::uint64_t>(0));
    emulator::snapshot::save(expected, std::optional<std::uint64_t> {});
    expect(save_state(fresh) == expected.bytes(),
        "the HID state saves its consumer, its consumer processor, then the accelerometer");
}

void running_accelerometer_is_populated_and_saved_again()
{
    std::ostringstream log;
    Output output { log };
    AddressSpace memory;
    UserlandHleRegistry registry { memory, output };
    Writer stream;
    emulator::snapshot::save(stream, static_cast<std::uint32_t>(7));
    emulator::snapshot::save(stream, static_cast<std::uint64_t>(3));
    emulator::snapshot::save(stream, std::optional<std::uint64_t> { 12'345U });
    const auto bytes = stream.bytes();

    HidEventSystemHle restored { registry };
    Reader in { bytes };
    restored.load(in);
    expect(in.at_end(), "the HID stream with a running accelerometer is consumed");
    expect(save_state(restored) == bytes,
        "a restored HID state with a running accelerometer is saved again in the same stream");
    std::vector<std::string> populated;
    emulator::snapshot::note_populated_members(
        populated, restored, HidEventSystemHle::snapshot_members());
    const std::vector<std::string> expected {
        "hid.consumer_process_",
        "hid.consumer_processor_",
        "hid.accelerometer_",
    };
    expect(populated == expected,
        "a HID state with a consumer and a running accelerometer populates all three members");
}

}

int main()
{
    accelerometer_round_trip_keeps_the_deadline();
    event_system_round_trip_keeps_the_idle_state();
    truncated_event_system_is_a_format_error();
    descriptors_name_the_saved_fields_in_order();
    fresh_layout_is_fixed();
    running_accelerometer_is_populated_and_saved_again();
    if (failures != 0) {
        std::cerr << failures << " HID event system snapshot checks failed\n";
        return 1;
    }
    std::cout << "HID event system snapshot checks passed\n";
    return 0;
}
