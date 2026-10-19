// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Schedule optional translation work across guest runtimes using
// shared activity signals.

#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <span>

#include "foundation/jit_work_policy.hpp"

namespace shade {

enum class JitScheduledTarget : std::uint8_t {
    NativeCode,
    PortableIr,
};

// A frontend describes simulator runtimes only through stable scheduler facts.
// No renderer, window, executable path, App or firmware identity enters the
// core selection algorithm.
struct JitWorkCandidate {
    std::uint64_t identity { };
    bool exited { };
    bool image_activation_pending { };
    bool foreground_transition_destination { };
    bool active_client { };
    bool scanout_owner { };
    bool guest_runnable { };
    std::size_t active_native_workers { };
    std::size_t active_portable_workers { };
    std::size_t worker_capacity { };
    std::optional<std::size_t> native_phase_priority;
    std::optional<std::size_t> portable_phase_priority;
};

enum class JitWorkScheduleSkip : std::uint8_t {
    NoCandidate,
    WorkerBusy,
    NoWork,
    MemoryPressure,
    DisplayBusy,
    GuestBusy,
    DeadlineReserve,
    ZeroBudget,
    Count,
};

inline constexpr std::size_t jit_work_schedule_skip_count =
    static_cast<std::size_t>(JitWorkScheduleSkip::Count);

struct JitScheduledWork {
    std::uint64_t candidate_identity { };
    JitWorkClass work_class { JitWorkClass::InteractiveNative };
    JitScheduledTarget target { JitScheduledTarget::NativeCode };
    std::size_t phase_priority { };
    JitWorkDecision decision;
};

inline constexpr std::size_t jit_work_maximum_translation_lanes =
    jit_work_policy_maximum_translation_lanes;
// One core-owned admission boundary never creates more work than the bounded
// aggregate translation-lane budget, regardless of candidate count.
inline constexpr std::size_t jit_work_schedule_maximum_entries =
    jit_work_maximum_translation_lanes;

struct JitWorkSchedule {
    std::array<JitScheduledWork, jit_work_schedule_maximum_entries> entries;
    std::size_t size { };
    std::array<std::uint64_t, jit_work_schedule_skip_count> skipped { };

    [[nodiscard]] std::span<const JitScheduledWork> work() const noexcept
    {
        return { entries.data(), size };
    }
};

struct JitWorkScheduleRequest {
    std::span<const JitWorkCandidate> candidates;
    JitWorkObservation observation;
    bool interactive_native_enabled { true };
    bool activation_portable_enabled { true };
    bool predictive_native_enabled { true };
    bool offline_portable_enabled { };
    std::size_t maximum_translation_lanes { 1U };
};

// Cheap facts sampled before the frontend constructs JitWorkCandidate and the
// full JitWorkObservation. The monotonically changing generation can combine
// demand-recorder, worker-completion and runtime-lifecycle signals.
struct JitWorkObservationGateRequest {
    std::chrono::steady_clock::time_point now;
    std::uint64_t work_generation { };
    bool guest_quiet { };
    bool activation_pending { };
    bool worker_active { };
};

// Simulator-core selector and admission controller. The frontend performs the
// returned work through its host resource implementation; it does not choose
// runtime priority, target fallback, budgets or deadline reserves.
class JitWorkScheduler {
public:
    [[nodiscard]] static std::size_t recommended_translation_lanes(
        std::size_t host_worker_count) noexcept
    {
        return JitWorkPolicy::recommended_translation_lanes(host_worker_count);
    }
    [[nodiscard]] static std::chrono::milliseconds
    activation_preparation_window(std::size_t translation_lanes) noexcept
    {
        return JitWorkPolicy::activation_preparation_window(translation_lanes);
    }
    [[nodiscard]] JitWorkSchedule schedule(
        const JitWorkScheduleRequest& request) const noexcept;
    // Coalesce hot-path change notifications into bounded observations. This
    // is deliberately stateful core policy: clients publish facts but do not
    // choose polling periods or special-case interactive workloads.
    [[nodiscard]] bool observation_due(
        const JitWorkObservationGateRequest& request) noexcept;

private:
    JitWorkPolicy policy_;
    bool observation_gate_initialized_ { };
    bool observation_gate_guest_quiet_ { };
    bool observation_gate_activation_pending_ { };
    std::uint64_t observation_gate_work_generation_ { };
    std::chrono::steady_clock::time_point last_observation_;
};

} // namespace shade
