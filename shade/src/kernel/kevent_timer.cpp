// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "kernel/kevent_timer.hpp"
#include "kernel/darwin_kqueue_abi.hpp"
#include <algorithm>
#include <limits>

namespace shade {
namespace {
    constexpr auto maximum = std::numeric_limits<std::uint64_t>::max();

    std::uint64_t add_saturated(std::uint64_t left, std::uint64_t right)
    {
        return right > maximum - left ? maximum : left + right;
    }
}

std::optional<KeventTimer> KeventTimer::create(
    std::int64_t data, std::uint32_t flags, const VirtualClock& clock, bool one_shot)
{
    using namespace darwin::kqueue;
    std::uint64_t multiplier;
    switch (flags & (timer_note_seconds | timer_note_microseconds |
                       timer_note_nanoseconds)) {
    case 0: multiplier = 1'000'000; break;
    case timer_note_seconds: multiplier = nanoseconds_per_second; break;
    case timer_note_microseconds: multiplier = 1000; break;
    case timer_note_nanoseconds: multiplier = 1; break;
    default: return std::nullopt;
    }
    const auto raw = static_cast<std::uint64_t>(data);
    const auto duration = raw > maximum / multiplier ? maximum : raw * multiplier;
    KeventTimer timer;
    const auto now = clock.now();
    if ((flags & timer_note_absolute) != 0U) {
        // Darwin NOTE_ABSOLUTE is calendar time, converted at registration.
        const auto calendar = clock.wall_time();
        timer.deadline_ = add_saturated(now,
            duration > calendar ? duration - calendar : 0U);
    } else {
        timer.interval_ = one_shot ? 0U : duration;
        timer.deadline_ = add_saturated(now, duration);
    }
    // Leeway and priority flags permit coalescing; firing at the requested
    // deadline is valid and keeps this model independent of host scheduling.
    return timer;
}

std::optional<std::uint64_t> KeventTimer::deadline() const
{
    return deadline_;
}

std::int64_t KeventTimer::expirations(std::uint64_t now) const
{
    if (!deadline_ || now < *deadline_)
        return 0;
    const auto additional = interval_ == 0U ? 0U : (now - *deadline_) / interval_;
    return static_cast<std::int64_t>(std::min(additional,
               static_cast<std::uint64_t>(std::numeric_limits<std::int64_t>::max() - 1))) + 1;
}

void KeventTimer::consume(std::uint64_t now)
{
    if (!deadline_ || now < *deadline_)
        return;
    if (interval_ == 0U) {
        deadline_.reset();
        return;
    }
    const auto remainder = (now - *deadline_) % interval_;
    const auto delay = interval_ - remainder;
    if (delay > maximum - now)
        deadline_.reset();
    else
        deadline_ = now + delay;
}

} // namespace shade
