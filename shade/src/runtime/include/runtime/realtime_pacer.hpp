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

namespace shade {

// Mach absolute time is the guest DeviceMonotonicTime domain. Interactive
// execution maps it to host steady time; instruction ticks remain a separate
// CPU/scheduler accounting domain and must not advance this clock.
using DeviceMonotonicTime = std::uint64_t;

enum class DeviceTimePolicy : std::uint8_t {
    DeterministicExecution,
    HostMappedInteractive,
};

// Relates guest DeviceMonotonicTime to one fixed host steady-clock origin for
// interactive emulator sessions. Bounded test runs intentionally do not use
// this class so their deterministic-time behavior remains fast and repeatable.
class RealtimePacer {
public:
    // A scale above one runs the guest's clock that many times slower than the
    // host's, which is how a host that cannot emulate the device in real time
    // still meets the guest's own watchdogs and RPC deadlines.
    explicit RealtimePacer(DeviceMonotonicTime initial_device_monotonic_time,
        double time_scale = 1.0);

    [[nodiscard]] double time_scale() const { return time_scale_; }

    [[nodiscard]] DeviceMonotonicTime allowed_device_monotonic_time() const;
    [[nodiscard]] std::chrono::nanoseconds delay_until(
        DeviceMonotonicTime device_monotonic_time) const;
    // Return the stable host deadline corresponding to a future device time.
    // Unlike now()+delay_until(), this does not drift when the caller refreshes
    // the same guest deadline on every idle-loop iteration.
    [[nodiscard]] std::chrono::steady_clock::time_point host_deadline_for(
        DeviceMonotonicTime device_monotonic_time) const;
    [[nodiscard]] std::chrono::nanoseconds limit_delay(
        std::chrono::nanoseconds delay,
        std::optional<std::chrono::steady_clock::time_point> host_deadline)
        const;

private:
    // Guest nanoseconds take time_scale times as long on the host.
    [[nodiscard]] std::uint64_t host_duration_for(
        std::uint64_t guest_nanoseconds) const;

    DeviceMonotonicTime initial_device_monotonic_time_ { };
    std::chrono::steady_clock::time_point initial_host_time_;
    double time_scale_ { 1.0 };
};

} // namespace shade
