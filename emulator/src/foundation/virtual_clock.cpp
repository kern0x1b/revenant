// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Maintain guest monotonic and calendar time and convert between
// device time domains.

#include "foundation/virtual_clock.hpp"

#include <algorithm>
#include <limits>

namespace emulator {
namespace {

    constexpr std::uint64_t maximum_positive_offset =
        static_cast<std::uint64_t>(std::numeric_limits<std::int64_t>::max());

    std::int64_t calendar_offset(
        std::uint64_t calendar_time, std::uint64_t monotonic_time)
    {
        if (calendar_time >= monotonic_time) {
            return static_cast<std::int64_t>(std::min(
                calendar_time - monotonic_time, maximum_positive_offset));
        }
        const auto magnitude = monotonic_time - calendar_time;
        if (magnitude > maximum_positive_offset) {
            return std::numeric_limits<std::int64_t>::min();
        }
        return -static_cast<std::int64_t>(magnitude);
    }

}

VirtualClock::VirtualClock(std::uint64_t initial_time)
    : now_ { initial_time }
    , wall_time_offset_ { calendar_offset(
          default_wall_time_epoch_seconds * nanoseconds_per_second,
          initial_time) }
{
}

std::uint64_t VirtualClock::now() const
{
    return now_.load(std::memory_order_relaxed);
}

std::uint64_t VirtualClock::wall_time() const
{
    const auto monotonic_time = now();
    const auto offset = wall_time_offset_.load(std::memory_order_relaxed);
    if (offset < 0) {
        const auto magnitude =
            offset == std::numeric_limits<std::int64_t>::min()
                ? maximum_positive_offset + 1U
                : static_cast<std::uint64_t>(-offset);
        return monotonic_time > magnitude ? monotonic_time - magnitude : 0;
    }
    const auto positive_offset = static_cast<std::uint64_t>(offset);
    if (monotonic_time >
        std::numeric_limits<std::uint64_t>::max() - positive_offset) {
        return std::numeric_limits<std::uint64_t>::max();
    }
    return positive_offset + monotonic_time;
}

std::uint64_t VirtualClock::boot_time() const
{
    const auto offset = wall_time_offset_.load(std::memory_order_relaxed);
    return offset > 0 ? static_cast<std::uint64_t>(offset) : 0U;
}

void VirtualClock::set_wall_time(std::uint64_t unix_time_nanoseconds)
{
    wall_time_offset_.store(calendar_offset(unix_time_nanoseconds, now()),
        std::memory_order_relaxed);
}

void VirtualClock::synchronize_wall_time(std::uint64_t unix_time_nanoseconds)
{
    set_wall_time(unix_time_nanoseconds);
}

std::uint64_t VirtualClock::tick(std::uint64_t increment)
{
    return now_.fetch_add(increment, std::memory_order_relaxed) + increment;
}

void VirtualClock::advance_to(std::uint64_t deadline)
{
    auto current = now();
    while (current < deadline && !now_.compare_exchange_weak(current, deadline,
                                     std::memory_order_relaxed)) { }
}

const std::array<snapshot::Member<VirtualClock>, 2>& VirtualClock::snapshot_members()
{
    static constexpr std::array<snapshot::Member<VirtualClock>, 2> members {{
        {"clock.now",
            [](const VirtualClock& clock) { return clock.now() == 0; },
            [](snapshot::Writer& out, const VirtualClock& clock) {
                snapshot::save(out, clock.now());
            },
            [](snapshot::Reader& in, VirtualClock& clock) {
                std::uint64_t value { };
                snapshot::load(in, value);
                clock.now_.store(value, std::memory_order_relaxed);
            }},
        {"clock.wall_time",
            [](const VirtualClock& clock) {
                return clock.wall_time_offset_.load(std::memory_order_relaxed) == 0;
            },
            [](snapshot::Writer& out, const VirtualClock& clock) {
                snapshot::save(out, clock.wall_time_offset_.load(std::memory_order_relaxed));
            },
            [](snapshot::Reader& in, VirtualClock& clock) {
                std::int64_t offset { };
                snapshot::load(in, offset);
                clock.wall_time_offset_.store(offset, std::memory_order_relaxed);
            }},
    }};
    return members;
}

void VirtualClock::save(snapshot::Writer& out) const
{
    snapshot::save_members(out, *this, snapshot_members());
}

void VirtualClock::load(snapshot::Reader& in)
{
    snapshot::restore_members(in, *this, snapshot_members());
}

}
