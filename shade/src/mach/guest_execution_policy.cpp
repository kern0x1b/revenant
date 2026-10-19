// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Select host cooperation budgets for scheduler-selected guest
// threads.

#include "mach/guest_execution_policy.hpp"
#include "foundation/performance.hpp"

#include <algorithm>
#include <stdexcept>

namespace shade {

namespace {

    constexpr auto host_check_resolution =
        std::chrono::duration_cast<std::chrono::nanoseconds>(
            std::chrono::microseconds { 250 });
    constexpr auto translation_safety =
        std::chrono::duration_cast<std::chrono::nanoseconds>(
            std::chrono::microseconds { 100 });

} // namespace

GuestExecutionPolicy::GuestExecutionPolicy(
    std::chrono::nanoseconds response_period)
    : response_period_ { response_period }
    , minimum_budget_ { std::min(response_period, host_check_resolution) }
    , initial_budget_ { std::max(minimum_budget_, response_period / 4) }
    , latency_budget_ { std::max(initial_budget_, response_period / 2) }
    , throughput_budget_ { std::max(
          latency_budget_, response_period - response_period / 4) }
{
    if (response_period_ <= std::chrono::nanoseconds::zero()) {
        throw std::invalid_argument { "response period must be positive" };
    }
}

std::chrono::nanoseconds GuestExecutionPolicy::budget(
    const XnuScheduler& scheduler,
    const GuestExecutionBudgetRequest& request) const
{
    PerformanceLatencyScope latency { PerfLatencyKind::GuestExecutionBudget,
        performance_counters().cpu_source_diagnostics_enabled() };
    const auto scheduling_info = scheduler.info(request.thread);
    if (!scheduling_info) {
        throw std::invalid_argument {
            "guest execution budget requires a registered XNU thread"
        };
    }
    const auto history = histories_.find(request.thread);
    const auto saturation_level =
        history == histories_.end() ? 0U : history->second.saturation_level;
    auto policy_cap = throughput_budget_;

    const auto equal_or_higher_competitors =
        scheduler.runnable_count_at_or_above_priority(
            scheduling_info->scheduled_priority);
    if (equal_or_higher_competitors != 0U) {
        // Complete one round of equal-priority host cooperation inside one
        // response period. As contention grows, each share converges on the
        // established low-latency initial budget.
        const auto contender_count = equal_or_higher_competitors + 1U;
        policy_cap = std::min(policy_cap,
            std::max(initial_budget_,
                response_period_ / static_cast<std::chrono::nanoseconds::rep>(
                                       contender_count)));
    }
    if (scheduler.highest_runnable_priority() >
        scheduling_info->scheduled_priority) {
        // A client preference can temporarily select below the XNU queue head.
        // Return quickly so the higher-priority guest thread can win the next
        // ordinary scheduler selection.
        policy_cap = initial_budget_;
    }
    if (request.latency_sensitive)
        policy_cap = std::min(policy_cap, latency_budget_);

    const auto adaptive_target = std::min(throughput_budget_,
        initial_budget_ * static_cast<std::int64_t>(saturation_level + 1U));
    const auto translation_floor = std::min(policy_cap,
        std::max(initial_budget_, request.jit_block_p99 + translation_safety));
    auto result =
        std::min(policy_cap, std::max(adaptive_target, translation_floor));

    const auto deadline_guard = std::max(
        translation_safety, request.jit_block_p99 + translation_safety);
    const auto limit_for_deadline = [&](const auto& delay) {
        if (!delay)
            return;
        if (*delay <= deadline_guard) {
            result = minimum_budget_;
            return;
        }
        // The cooperative stop is checked at translated-block boundaries. Keep
        // the measured translation overrun as headroom, but spend the rest of
        // the available interval instead of unconditionally discarding half.
        result = std::min(
            result, std::max(minimum_budget_, *delay - deadline_guard));
    };
    limit_for_deadline(request.host_control_delay);
    limit_for_deadline(request.guest_realtime_deadline_delay);
    return std::clamp(result, minimum_budget_, throughput_budget_);
}

void GuestExecutionPolicy::observe(
    XnuThreadId thread, XnuSliceCompletion completion)
{
    if (completion == XnuSliceCompletion::Terminate) {
        histories_.erase(thread);
        return;
    }
    auto history = histories_.find(thread);
    if (completion == XnuSliceCompletion::HostCooperate) {
        if (history == histories_.end())
            history = histories_.try_emplace(thread).first;
        history->second.saturation_level = std::min<std::uint8_t>(
            maximum_saturation_level, history->second.saturation_level + 1U);
        return;
    }
    if (history == histories_.end())
        return;
    if (history->second.saturation_level > 1U) {
        --history->second.saturation_level;
    } else {
        histories_.erase(history);
    }
}

void GuestExecutionPolicy::forget(XnuThreadId thread)
{
    histories_.erase(thread);
}

void GuestExecutionPolicy::forget_process(std::uint32_t process_id)
{
    std::erase_if(histories_, [process_id](const auto& entry) {
        return entry.first.process == process_id;
    });
}

} // namespace shade
