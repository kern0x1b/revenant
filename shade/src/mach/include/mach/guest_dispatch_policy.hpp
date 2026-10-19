// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Choose bounded guest dispatch hints while preserving scheduler
// eligibility.

#pragma once

#include <chrono>
#include <cstddef>
#include <cstdint>
#include <optional>

#include "mach/xnu_scheduler.hpp"

namespace shade {

// Stable simulator facts supplied by a client. "Realtime" can represent a
// display callback, audio callback or another bounded Guest dependency chain;
// the policy never sees a renderer, executable path, App or firmware identity.
struct GuestDispatchObservation {
    std::chrono::steady_clock::time_point now;
    std::optional<XnuThreadId> debugger_thread;
    std::optional<XnuThreadId> explicit_handoff_thread;
    std::optional<std::uint32_t> realtime_process;
    std::optional<XnuThreadId> realtime_callback_thread;
    std::optional<XnuThreadId> realtime_receiver_thread;
    std::optional<XnuThreadId> realtime_yielded_thread;
    std::optional<XnuThreadId> realtime_inflight_thread;
    std::optional<XnuThreadId> input_target_thread;
    std::optional<std::uint32_t> input_receiver_process;
    std::optional<std::uint32_t> foreground_transition_process;
    std::optional<std::uint32_t> active_process;
    std::uint64_t interaction_generation { };
    bool realtime_notification_pending { };
    bool realtime_work_pending { };
    bool realtime_inflight { };
    bool realtime_lease_active { };
};

enum class GuestDispatchReason : std::uint8_t {
    Ordinary,
    Debugger,
    ExplicitHandoff,
    RealtimeYieldDependency,
    RealtimeInflight,
    RealtimeReceiver,
    RealtimeCallback,
    RealtimeDependency,
    InputTarget,
    ForegroundTransition,
    InputProcess,
    InteractiveProcess,
};

struct GuestDispatchDecision {
    std::optional<XnuThreadId> preferred_thread;
    GuestDispatchReason reason { GuestDispatchReason::Ordinary };
    bool explicit_handoff_stale { };
};

// Core host-dispatch policy layered above XNU runnable selection. A preferred
// thread is a bounded handoff hint only: XnuScheduler still owns eligibility,
// Guest priority, quantum, realtime deadlines and queue order.
class GuestDispatchPolicy {
public:
    explicit GuestDispatchPolicy(
        std::chrono::nanoseconds response_period =
            std::chrono::nanoseconds { 16'666'667 });

    [[nodiscard]] GuestDispatchDecision decide(const XnuScheduler& scheduler,
        const GuestDispatchObservation& observation);

private:
    [[nodiscard]] GuestDispatchDecision decide_interactive_process(
        const XnuScheduler& scheduler, std::uint32_t process,
        GuestDispatchReason reason);

    static constexpr std::size_t preferred_process_burst_limit = 3U;

    std::chrono::nanoseconds interaction_lease_;
    std::chrono::steady_clock::time_point interaction_deadline_ { };
    std::uint64_t observed_interaction_generation_ { };
    std::optional<std::uint32_t> input_process_;
    std::optional<std::uint32_t> preferred_process_;
    std::size_t preferred_process_burst_ { };
};

} // namespace shade
