// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "foundation/snapshot_io.hpp"
#include "foundation/snapshot_member.hpp"
#include "foundation/virtual_clock.hpp"

#include <cstddef>
#include <cstdint>
#include <iostream>
#include <string>
#include <vector>

namespace {

using emulator::VirtualClock;
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

std::vector<std::byte> save_clock(const VirtualClock& clock)
{
    Writer out;
    clock.save(out);
    return out.bytes();
}

void expect_same_clock(
    const VirtualClock& expected, const VirtualClock& actual, const std::string& what)
{
    expect(actual.now() == expected.now(), what + ": now");
    expect(actual.wall_time() == expected.wall_time(), what + ": wall time");
    expect(actual.boot_time() == expected.boot_time(), what + ": boot time");
}

void round_trip_keeps_both_clocks(VirtualClock& source, const std::string& what)
{
    const auto bytes = save_clock(source);
    VirtualClock restored { 0 };
    Reader in { bytes };
    restored.load(in);
    expect(in.at_end(), what + ": the stream is consumed");
    expect_same_clock(source, restored, what);

    source.advance_to(source.now() + 4000);
    restored.advance_to(restored.now() + 4000);
    expect_same_clock(source, restored, what + " after advancing");
}

void default_clock_round_trips()
{
    VirtualClock clock {};
    round_trip_keeps_both_clocks(clock, "default clock");
}

void set_wall_time_round_trips()
{
    VirtualClock clock { 123'456'789ULL };
    clock.set_wall_time(1'700'000'000'000'000'000ULL);
    clock.tick(999);
    round_trip_keeps_both_clocks(clock, "set wall time");
}

void large_initial_time_round_trips()
{
    VirtualClock clock { 9'000'000'000'000'000'000ULL };
    round_trip_keeps_both_clocks(clock, "large initial time");
}

void truncated_clock_is_a_format_error()
{
    const auto bytes = save_clock(VirtualClock {});
    std::vector<std::byte> truncated { bytes.begin(), bytes.begin() + 5 };
    bool threw = false;
    try {
        VirtualClock restored { 0 };
        Reader in { truncated };
        restored.load(in);
    } catch (const FormatError&) {
        threw = true;
    }
    expect(threw, "a truncated clock throws FormatError");
}

void descriptors_name_the_saved_fields_in_order()
{
    const auto& members = VirtualClock::snapshot_members();
    expect(members.size() == 2, "the clock has two saved members");
    expect(members[0].name == "clock.now", "the first saved member is clock.now");
    expect(members[1].name == "clock.wall_time",
        "the second saved member is clock.wall_time");
}

void save_writes_now_then_the_wall_time_offset()
{
    const VirtualClock clock { 1'234'567ULL };
    emulator::snapshot::Writer expected;
    emulator::snapshot::save(expected, clock.now());
    emulator::snapshot::save(expected, static_cast<std::int64_t>(clock.boot_time()));
    expect(save_clock(clock) == expected.bytes(),
        "the clock saves its time, then its wall time offset, as 16 bytes");
}

void is_default_follows_the_saved_fields()
{
    const auto& members = VirtualClock::snapshot_members();
    const VirtualClock at_zero { 0 };
    expect(members[0].is_default(at_zero),
        "a clock at time zero has a default now");
    expect(!members[1].is_default(at_zero),
        "a clock at boot has a wall time offset, which is not default");
    const VirtualClock running { 5 };
    expect(!members[0].is_default(running),
        "a clock that has a time is not default");
}

void populated_members_name_the_fields_that_hold_state()
{
    const VirtualClock at_zero { 0 };
    std::vector<std::string> populated;
    emulator::snapshot::note_populated_members(
        populated, at_zero, VirtualClock::snapshot_members());
    expect(populated.size() == 1 && populated[0] == "clock.wall_time",
        "a clock at time zero populates only its wall time offset");
}

}

int main()
{
    default_clock_round_trips();
    set_wall_time_round_trips();
    large_initial_time_round_trips();
    truncated_clock_is_a_format_error();
    descriptors_name_the_saved_fields_in_order();
    save_writes_now_then_the_wall_time_offset();
    is_default_follows_the_saved_fields();
    populated_members_name_the_fields_that_hold_state();
    if (failures != 0) {
        std::cerr << failures << " virtual clock snapshot checks failed\n";
        return 1;
    }
    std::cout << "virtual clock snapshot checks passed\n";
    return 0;
}
