// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Pace guest monotonic time against host time using the selected
// device policy.

#include "runtime/realtime_pacer.hpp"

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <limits>

namespace shade {

RealtimePacer::RealtimePacer(
    DeviceMonotonicTime initial_device_monotonic_time, double time_scale)
    : initial_device_monotonic_time_ { initial_device_monotonic_time }
    , initial_host_time_ { std::chrono::steady_clock::now() }
    , time_scale_ { time_scale >= 1.0 ? time_scale : 1.0 }
{
}

std::uint64_t RealtimePacer::host_duration_for(
    std::uint64_t guest_nanoseconds) const
{
    if (time_scale_ <= 1.0)
        return guest_nanoseconds;
    const auto scaled = static_cast<double>(guest_nanoseconds) * time_scale_;
    return scaled >= static_cast<double>(
               std::numeric_limits<std::uint64_t>::max())
        ? std::numeric_limits<std::uint64_t>::max()
        : static_cast<std::uint64_t>(scaled);
}

DeviceMonotonicTime RealtimePacer::allowed_device_monotonic_time() const
{
    // iPhone OS 1.0's mach_timebase_info is exposed as 1:1, so one Mach
    // absolute-time unit is one nanosecond in the compatibility kernel.
    const auto elapsed =
        std::max(std::chrono::steady_clock::now() - initial_host_time_,
            std::chrono::steady_clock::duration::zero());
    const auto elapsed_nanoseconds =
        std::chrono::duration_cast<std::chrono::nanoseconds>(elapsed).count();
    const auto positive_elapsed = time_scale_ > 1.0
        ? static_cast<std::uint64_t>(
              static_cast<double>(elapsed_nanoseconds) / time_scale_)
        : static_cast<std::uint64_t>(elapsed_nanoseconds);
    if (positive_elapsed > std::numeric_limits<DeviceMonotonicTime>::max() -
                               initial_device_monotonic_time_) {
        return std::numeric_limits<std::uint64_t>::max();
    }
    return initial_device_monotonic_time_ + positive_elapsed;
}

std::chrono::nanoseconds RealtimePacer::delay_until(
    DeviceMonotonicTime device_monotonic_time) const
{
    const auto allowed = allowed_device_monotonic_time();
    if (device_monotonic_time <= allowed) {
        return std::chrono::nanoseconds::zero();
    }
    const auto delay = host_duration_for(device_monotonic_time - allowed);
    const auto maximum =
        static_cast<std::uint64_t>(std::chrono::nanoseconds::max().count());
    return std::chrono::nanoseconds {
        static_cast<std::chrono::nanoseconds::rep>(std::min(delay, maximum))
    };
}

std::chrono::steady_clock::time_point RealtimePacer::host_deadline_for(
    DeviceMonotonicTime device_monotonic_time) const
{
    if (device_monotonic_time <= initial_device_monotonic_time_)
        return initial_host_time_;
    const auto delta =
        host_duration_for(device_monotonic_time - initial_device_monotonic_time_);
    const auto maximum = static_cast<std::uint64_t>(
        std::chrono::steady_clock::duration::max().count());
    if (delta >= maximum)
        return std::chrono::steady_clock::time_point::max();
    return initial_host_time_ +
           std::chrono::nanoseconds { static_cast<std::int64_t>(delta) };
}

std::chrono::nanoseconds RealtimePacer::limit_delay(
    std::chrono::nanoseconds delay,
    std::optional<std::chrono::steady_clock::time_point> host_deadline) const
{
    if (delay <= std::chrono::nanoseconds::zero() || !host_deadline)
        return std::max(delay, std::chrono::nanoseconds::zero());
    const auto until_host_deadline =
        std::chrono::duration_cast<std::chrono::nanoseconds>(
            *host_deadline - std::chrono::steady_clock::now());
    return std::min(
        delay, std::max(until_host_deadline, std::chrono::nanoseconds::zero()));
}

} // namespace shade
