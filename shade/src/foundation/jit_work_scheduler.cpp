// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Schedule optional translation work across guest runtimes using
// shared activity signals.

#include "foundation/jit_work_scheduler.hpp"

#include <algorithm>

namespace shade {
namespace {

    [[nodiscard]] JitWorkScheduleSkip skip_for(
        JitWorkBlockReason reason) noexcept
    {
        switch (reason) {
        case JitWorkBlockReason::MemoryPressure:
            return JitWorkScheduleSkip::MemoryPressure;
        case JitWorkBlockReason::DisplayBusy:
            return JitWorkScheduleSkip::DisplayBusy;
        case JitWorkBlockReason::GuestBusy:
            return JitWorkScheduleSkip::GuestBusy;
        case JitWorkBlockReason::DeadlineReserve:
            return JitWorkScheduleSkip::DeadlineReserve;
        case JitWorkBlockReason::None:
        case JitWorkBlockReason::ZeroBudget:
            return JitWorkScheduleSkip::ZeroBudget;
        }
        return JitWorkScheduleSkip::ZeroBudget;
    }

    void note_skip(
        JitWorkSchedule& schedule, JitWorkScheduleSkip reason) noexcept
    {
        ++schedule.skipped[static_cast<std::size_t>(reason)];
    }

} // namespace

bool JitWorkScheduler::observation_due(
    const JitWorkObservationGateRequest& request) noexcept
{
    const auto admit = [&]() {
        observation_gate_initialized_ = true;
        observation_gate_guest_quiet_ = request.guest_quiet;
        observation_gate_activation_pending_ = request.activation_pending;
        observation_gate_work_generation_ = request.work_generation;
        last_observation_ = request.now;
        return true;
    };
    if (!observation_gate_initialized_ || request.now < last_observation_)
        return admit();

    const auto elapsed = request.now - last_observation_;
    constexpr auto minimum_coalesce_period = std::chrono::milliseconds { 1 };
    if (elapsed < minimum_coalesce_period)
        return false;

    const auto lifecycle_changed =
        request.guest_quiet != observation_gate_guest_quiet_ ||
        request.activation_pending !=
            observation_gate_activation_pending_;
    const auto work_changed = request.work_generation !=
                              observation_gate_work_generation_;
    // A held image has only a bounded preparation window, so refill its
    // independent translation lanes at the smallest coalescing cadence.
    const auto period =
        request.activation_pending
            ? minimum_coalesce_period
        : lifecycle_changed
            ? minimum_coalesce_period
        : work_changed
            ? (request.guest_quiet ? std::chrono::milliseconds { 2 }
                                   : std::chrono::milliseconds { 16 })
        : request.worker_active
            ? (request.guest_quiet ? std::chrono::milliseconds { 2 }
                                   : std::chrono::milliseconds { 8 })
        : request.guest_quiet ? std::chrono::milliseconds { 20 }
                              : std::chrono::milliseconds { 100 };
    return elapsed >= period ? admit() : false;
}

JitWorkSchedule JitWorkScheduler::schedule(
    const JitWorkScheduleRequest& request) const noexcept
{
    JitWorkSchedule result;
    const auto find_first = [&](auto predicate) -> const JitWorkCandidate* {
        const auto found = std::find_if(
            request.candidates.begin(), request.candidates.end(), predicate);
        return found == request.candidates.end() ? nullptr : &*found;
    };
    const auto transition = find_first([](const JitWorkCandidate& candidate) {
        return candidate.foreground_transition_destination;
    });
    // A pending foreground transition is demand-only. Even independent
    // Portable workers share host cores, memory bandwidth and the artifact
    // store with the Guest, while Native prediction additionally publishes
    // into the demand slab. Defer every speculative candidate until the
    // transition reaches a terminal state rather than attempting to infer
    // spare frame time from an incomplete animation.
    if (transition != nullptr) {
        note_skip(result, JitWorkScheduleSkip::GuestBusy);
        return result;
    }
    const auto activation = find_first([](const JitWorkCandidate& candidate) {
        return candidate.image_activation_pending;
    });
    const auto active =
        activation != nullptr
            ? activation
            : find_first([](const JitWorkCandidate& candidate) {
                  return candidate.active_client;
              });
    const auto scanout = find_first([](const JitWorkCandidate& candidate) {
        return candidate.scanout_owner;
    });

    const auto lane_limit = std::min(
        request.maximum_translation_lanes, jit_work_schedule_maximum_entries);
    const auto active_worker_count = [](const JitWorkCandidate& candidate) {
        return candidate.active_native_workers +
               candidate.active_portable_workers;
    };
    std::size_t occupied_lanes { };
    for (const auto& candidate : request.candidates) {
        occupied_lanes +=
            std::min(active_worker_count(candidate), candidate.worker_capacity);
    }
    std::size_t available_lanes =
        occupied_lanes >= lane_limit ? 0U : lane_limit - occupied_lanes;
    const auto planned_worker_count =
        [&result](std::uint64_t identity,
            std::optional<JitScheduledTarget> target = std::nullopt) {
            std::size_t count { };
            for (std::size_t index = 0; index < result.size; ++index) {
                if (result.entries[index].candidate_identity == identity &&
                    (!target || result.entries[index].target == *target)) {
                    ++count;
                }
            }
            return count;
        };

    const auto admit = [&](const JitWorkCandidate* candidate,
                           bool count_missing, JitWorkClass work_class) {
        if (candidate == nullptr || candidate->exited) {
            if (count_missing)
                note_skip(result, JitWorkScheduleSkip::NoCandidate);
            return;
        }
        const auto candidate_capacity = std::min(
            candidate->worker_capacity, jit_work_maximum_translation_lanes);
        const auto candidate_active = active_worker_count(*candidate) +
                                      planned_worker_count(candidate->identity);
        if (candidate_capacity == 0U ||
            candidate_active >= candidate_capacity || available_lanes == 0U) {
            note_skip(result, JitWorkScheduleSkip::WorkerBusy);
            return;
        }
        JitScheduledTarget target { JitScheduledTarget::NativeCode };
        std::optional<std::size_t> phase;
        if (work_class == JitWorkClass::PredictiveNative) {
            if (request.predictive_native_enabled)
                phase = candidate->native_phase_priority;
        } else if (work_class == JitWorkClass::ActivationPortable) {
            target = JitScheduledTarget::PortableIr;
            if (request.activation_portable_enabled)
                phase = candidate->portable_phase_priority;
        } else if (work_class == JitWorkClass::OfflinePortable) {
            if (request.offline_portable_enabled) {
                target = JitScheduledTarget::PortableIr;
                phase = candidate->portable_phase_priority;
            }
        } else if (request.interactive_native_enabled &&
                   candidate->native_phase_priority) {
            phase = candidate->native_phase_priority;
        }
        if (!phase) {
            note_skip(result, JitWorkScheduleSkip::NoWork);
            return;
        }
        // Native prediction publishes into the same slab and invalidates the
        // same dispatch structures as demand translation. A generic
        // prediction target remains idle-only. The active/scanout path uses
        // InteractiveNative, whose core policy requires an interaction quiet
        // period, no realtime dependency and bounded deadline slack.
        const auto live_image_native =
            work_class == JitWorkClass::InteractiveNative;
        if (target == JitScheduledTarget::NativeCode &&
            candidate->guest_runnable && !candidate->image_activation_pending &&
            !live_image_native) {
            note_skip(result, JitWorkScheduleSkip::GuestBusy);
            return;
        }
        const auto decision = policy_.decide(work_class, request.observation);
        if (!decision) {
            note_skip(result, skip_for(decision.blocked_by));
            return;
        }
        const auto native_target = target == JitScheduledTarget::NativeCode;
        const auto planned_native = planned_worker_count(candidate->identity,
            JitScheduledTarget::NativeCode);
        const auto native_workers =
            candidate->active_native_workers + planned_native;
        if (native_target && native_workers != 0U) {
            note_skip(result, JitWorkScheduleSkip::WorkerBusy);
            return;
        }
        const auto exclusively_idle =
            work_class == JitWorkClass::PredictiveNative ||
            work_class == JitWorkClass::OfflinePortable;
        if (exclusively_idle && candidate_active != 0U) {
            note_skip(result, JitWorkScheduleSkip::WorkerBusy);
            return;
        }
        const auto candidate_available = candidate_capacity - candidate_active;
        const auto desired_lanes =
            work_class == JitWorkClass::ActivationPortable
                ? candidate_available
                : std::size_t { 1U };
        const auto admitted_lanes = std::min({ desired_lanes, available_lanes,
            result.entries.size() - result.size });
        if (admitted_lanes == 0U) {
            note_skip(result, JitWorkScheduleSkip::WorkerBusy);
            return;
        }
        for (std::size_t lane = 0; lane < admitted_lanes; ++lane) {
            result.entries[result.size++] =
                JitScheduledWork { candidate->identity, work_class, target,
                    *phase, decision };
        }
        available_lanes -= admitted_lanes;
    };

    const auto active_native_class =
        active != nullptr && active->image_activation_pending
            ? JitWorkClass::ActivationNative
            : JitWorkClass::InteractiveNative;
    admit(active, false, active_native_class);
    if (active != nullptr && active->image_activation_pending)
        admit(active, false, JitWorkClass::ActivationPortable);
    if (scanout != nullptr &&
        (active == nullptr || scanout->identity != active->identity)) {
        admit(scanout, false, JitWorkClass::InteractiveNative);
    }
    const auto already_scheduled = [&result](std::uint64_t identity) {
        for (std::size_t index = 0; index < result.size; ++index) {
            if (result.entries[index].candidate_identity == identity)
                return true;
        }
        return false;
    };

    if (request.predictive_native_enabled) {
        const JitWorkCandidate* predictive = nullptr;
        bool predictive_worker_busy = false;
        for (const auto& candidate : request.candidates) {
            const auto interactive_role =
                candidate.foreground_transition_destination ||
                candidate.active_client || candidate.scanout_owner;
            if (candidate.exited || interactive_role ||
                candidate.guest_runnable ||
                already_scheduled(candidate.identity))
                continue;
            if (active_worker_count(candidate) != 0U) {
                predictive_worker_busy = true;
                continue;
            }
            if (!candidate.native_phase_priority)
                continue;
            if (predictive == nullptr ||
                *candidate.native_phase_priority <
                    *predictive->native_phase_priority) {
                predictive = &candidate;
            }
        }
        if (predictive != nullptr) {
            admit(predictive, false, JitWorkClass::PredictiveNative);
        } else if (active == nullptr && scanout == nullptr) {
            note_skip(result, predictive_worker_busy
                                  ? JitWorkScheduleSkip::WorkerBusy
                                  : JitWorkScheduleSkip::NoCandidate);
        }
    }

    if (request.offline_portable_enabled) {
        const JitWorkCandidate* offline = nullptr;
        bool offline_worker_busy = false;
        for (const auto& candidate : request.candidates) {
            const auto interactive_role =
                candidate.foreground_transition_destination ||
                candidate.active_client || candidate.scanout_owner;
            if (candidate.exited || interactive_role ||
                already_scheduled(candidate.identity))
                continue;
            if (active_worker_count(candidate) != 0U) {
                offline_worker_busy = true;
                continue;
            }
            if (!candidate.portable_phase_priority)
                continue;
            if (offline == nullptr || *candidate.portable_phase_priority <
                                          *offline->portable_phase_priority) {
                offline = &candidate;
            }
        }
        if (offline != nullptr) {
            admit(offline, false, JitWorkClass::OfflinePortable);
        } else {
            note_skip(result, offline_worker_busy
                                  ? JitWorkScheduleSkip::WorkerBusy
                                  : JitWorkScheduleSkip::NoCandidate);
        }
    }
    return result;
}

} // namespace shade
