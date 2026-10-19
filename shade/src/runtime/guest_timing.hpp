// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Provide runtime helpers for guest tick clocks and deadline
// conversion.

#pragma once

#include "kernel/mach_thread_policy_abi.hpp"
#include <cstdint>
#include <limits>
#include <stdexcept>

namespace shade::runtime_detail {

class GuestTickClock {
public:
    explicit GuestTickClock(std::uint32_t ticks_per_second)
        : ticks_per_second_ { ticks_per_second }
    {
        if (ticks_per_second_ == 0) {
            throw std::invalid_argument { "guest tick rate must be non-zero" };
        }
    }

    [[nodiscard]] std::uint64_t absolute_time_units(std::uint64_t ticks)
    {
        constexpr auto units_per_second =
            darwin::mach::thread_policy::absolute_time_units_per_second;
        const auto whole_seconds = ticks / ticks_per_second_;
        if (whole_seconds >
            std::numeric_limits<std::uint64_t>::max() / units_per_second) {
            throw std::overflow_error { "guest time conversion overflow" };
        }
        const auto fractional_ticks = ticks % ticks_per_second_;
        const auto scaled_fraction =
            fractional_ticks * units_per_second + remainder_;
        remainder_ = scaled_fraction % ticks_per_second_;
        return whole_seconds * units_per_second +
               scaled_fraction / ticks_per_second_;
    }

private:
    std::uint64_t ticks_per_second_ { };
    std::uint64_t remainder_ { };
};

[[nodiscard]] inline std::uint64_t duration_to_guest_ticks(std::uint64_t value,
    std::uint64_t units_per_second, std::uint32_t guest_ticks_per_second)
{
    if (units_per_second == 0 || guest_ticks_per_second == 0) {
        throw std::invalid_argument { "time conversion rate must be non-zero" };
    }
    const auto whole_seconds = value / units_per_second;
    const auto fractional_units = value % units_per_second;
    if (whole_seconds > std::numeric_limits<std::uint64_t>::max() /
                            guest_ticks_per_second ||
        fractional_units > std::numeric_limits<std::uint64_t>::max() /
                               guest_ticks_per_second) {
        throw std::overflow_error { "guest tick conversion overflow" };
    }
    const auto whole_ticks = whole_seconds * guest_ticks_per_second;
    const auto fractional_ticks =
        fractional_units * guest_ticks_per_second / units_per_second;
    if (fractional_ticks >
        std::numeric_limits<std::uint64_t>::max() - whole_ticks) {
        throw std::overflow_error { "guest tick conversion overflow" };
    }
    return whole_ticks + fractional_ticks;
}

} // namespace shade::runtime_detail
