// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Pace guest monotonic time against host time using the selected
// device policy.

#pragma once

#include <chrono>
#include <cstdint>
#include <optional>

namespace emulator {

using DeviceMonotonicTime = std::uint64_t;

enum class DeviceTimePolicy : std::uint8_t {
    DeterministicExecution,
    HostMappedInteractive,
};

class RealtimePacer {
public:
    explicit RealtimePacer(DeviceMonotonicTime initial_device_monotonic_time,
        double time_scale = 1.0);

    [[nodiscard]] double time_scale() const { return time_scale_; }

    [[nodiscard]] DeviceMonotonicTime allowed_device_monotonic_time() const;
    [[nodiscard]] std::chrono::nanoseconds delay_until(
        DeviceMonotonicTime device_monotonic_time) const;
    [[nodiscard]] std::chrono::steady_clock::time_point host_deadline_for(
        DeviceMonotonicTime device_monotonic_time) const;
    [[nodiscard]] std::chrono::nanoseconds limit_delay(
        std::chrono::nanoseconds delay,
        std::optional<std::chrono::steady_clock::time_point> host_deadline)
        const;

private:
    [[nodiscard]] std::uint64_t host_duration_for(
        std::uint64_t guest_nanoseconds) const;

    DeviceMonotonicTime initial_device_monotonic_time_ { };
    std::chrono::steady_clock::time_point initial_host_time_;
    double time_scale_ { 1.0 };
};

}
