// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "../guest_timing.hpp"

#include <array>
#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <string>

namespace {

using emulator::runtime_detail::GuestTickClock;
using emulator::runtime_detail::duration_to_guest_ticks;

constexpr std::uint32_t guest_ticks_per_second = 400'000'000U;
constexpr std::uint64_t units_per_second = 1'000'000'000ULL;
constexpr std::uint64_t saved_ticks = 1'048'581U;
constexpr std::uint64_t executed_ticks = 4'194'307U;

int failures = 0;

void expect(bool condition, const std::string& what)
{
    if (condition)
        return;
    std::cerr << "FAIL: " << what << '\n';
    ++failures;
}

std::uint64_t convert_in_two_segments(std::uint64_t first,
    std::uint64_t second, bool carry_remainder)
{
    GuestTickClock before { guest_ticks_per_second };
    const auto first_units = before.absolute_time_units(first);
    GuestTickClock after { guest_ticks_per_second };
    if (carry_remainder)
        after.set_remainder(before.remainder());
    return first_units + after.absolute_time_units(second);
}

void odd_tick_leaves_half_a_nanosecond_to_carry()
{
    GuestTickClock clock { guest_ticks_per_second };
    expect(clock.absolute_time_units(1) == 2,
        "one tick at 400 MHz is 2 ns, rounded down");
    expect(clock.remainder() == 200'000'000U,
        "the half nanosecond is carried as 2e8 of the 4e8 units per second");
}

void carried_remainder_matches_continuous_conversion_at_the_save_boundary()
{
    GuestTickClock continuous { guest_ticks_per_second };
    const auto whole = continuous.absolute_time_units(executed_ticks);
    for (const auto split : std::array<std::uint64_t, 4> {
             1U, saved_ticks, 2'097'152U, 2'097'153U }) {
        expect(convert_in_two_segments(split, executed_ticks - split, true) == whole,
            "a clock that carries its remainder across a split at " +
                std::to_string(split) + " matches one continuous conversion");
    }
}

void restore_without_the_remainder_is_one_nanosecond_short_on_an_odd_tail()
{
    const auto tail_ticks = executed_ticks + 1 - saved_ticks;
    GuestTickClock continuous { guest_ticks_per_second };
    const auto whole = continuous.absolute_time_units(executed_ticks + 1);
    const auto carried =
        convert_in_two_segments(saved_ticks, tail_ticks, true);
    const auto dropped =
        convert_in_two_segments(saved_ticks, tail_ticks, false);
    expect(carried == whole,
        "the carried remainder reproduces the continuous nanoseconds");
    expect(dropped + 1 == whole,
        "a restored clock with no remainder is one nanosecond short");
}

void one_nanosecond_short_is_one_guest_realtime_tick()
{
    expect(duration_to_guest_ticks(10'485'770U, units_per_second,
               guest_ticks_per_second) == 4'194'308U,
        "10485770 ns is 4194308 guest ticks at 400 MHz");
    expect(duration_to_guest_ticks(10'485'769U, units_per_second,
               guest_ticks_per_second) == 4'194'307U,
        "10485769 ns, one short, is 4194307 guest ticks");
}

void remainder_must_be_a_fraction_of_a_second()
{
    GuestTickClock clock { guest_ticks_per_second };
    bool rejected = false;
    try {
        clock.set_remainder(guest_ticks_per_second);
    } catch (const std::invalid_argument&) {
        rejected = true;
    }
    expect(rejected, "a remainder of a whole second is rejected");
    expect(clock.remainder() == 0, "a rejected remainder leaves the clock alone");
}

}

int main()
{
    odd_tick_leaves_half_a_nanosecond_to_carry();
    carried_remainder_matches_continuous_conversion_at_the_save_boundary();
    restore_without_the_remainder_is_one_nanosecond_short_on_an_odd_tail();
    one_nanosecond_short_is_one_guest_realtime_tick();
    remainder_must_be_a_fraction_of_a_second();

    if (failures != 0) {
        std::cerr << failures << " guest timing checks failed\n";
        return 1;
    }
    std::cout << "guest timing checks passed\n";
    return 0;
}
