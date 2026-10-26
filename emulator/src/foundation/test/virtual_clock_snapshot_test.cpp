// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "foundation/snapshot_io.hpp"
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

}

int main()
{
    default_clock_round_trips();
    set_wall_time_round_trips();
    large_initial_time_round_trips();
    truncated_clock_is_a_format_error();
    if (failures != 0) {
        std::cerr << failures << " virtual clock snapshot checks failed\n";
        return 1;
    }
    std::cout << "virtual clock snapshot checks passed\n";
    return 0;
}
