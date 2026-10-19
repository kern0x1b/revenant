// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Select optional JIT work classes and limits from backend and
// runtime conditions.

#include "foundation/jit_work_policy.hpp"

#include <algorithm>
#include <limits>

#include "foundation/jit_code_cache_governor.hpp"
#include "foundation/jit_translation_profile.hpp"

namespace shade {
namespace {

    constexpr std::size_t minimum_native_slab_bytes = 64U * 1024U * 1024U;
    constexpr std::size_t expanded_native_slab_bytes = 128U * 1024U * 1024U;
    constexpr std::size_t spacious_native_slab_bytes = 256U * 1024U * 1024U;
    constexpr std::size_t ample_native_slab_bytes = 512U * 1024U * 1024U;
    constexpr std::size_t large_native_slab_bytes = 1024ULL * 1024ULL * 1024ULL;
    constexpr std::size_t maximum_x64_native_slab_bytes =
        1536ULL * 1024ULL * 1024ULL;
    constexpr std::uint64_t expanded_effective_memory_floor =
        4ULL * 1024ULL * 1024ULL * 1024ULL;
    constexpr std::uint64_t expanded_available_memory_floor =
        1ULL * 1024ULL * 1024ULL * 1024ULL;
    constexpr std::uint64_t spacious_effective_memory_floor =
        8ULL * 1024ULL * 1024ULL * 1024ULL;
    constexpr std::uint64_t spacious_available_memory_floor =
        2ULL * 1024ULL * 1024ULL * 1024ULL;
    constexpr std::uint64_t ample_effective_memory_floor =
        12ULL * 1024ULL * 1024ULL * 1024ULL;
    constexpr std::uint64_t ample_available_memory_floor =
        4ULL * 1024ULL * 1024ULL * 1024ULL;
    constexpr std::uint64_t large_effective_memory_floor =
        16ULL * 1024ULL * 1024ULL * 1024ULL;
    constexpr std::uint64_t large_available_memory_floor =
        6ULL * 1024ULL * 1024ULL * 1024ULL;
    constexpr std::uint64_t maximum_effective_memory_floor =
        24ULL * 1024ULL * 1024ULL * 1024ULL;
    constexpr std::uint64_t maximum_available_memory_floor =
        8ULL * 1024ULL * 1024ULL * 1024ULL;
    constexpr std::uint64_t activation_budget_nanoseconds = 8'000'000U;
    constexpr std::uint64_t activation_portable_budget_nanoseconds =
        8'000'000U;
    // Same-slab prediction for a live interactive image is deliberately a
    // micro-batch. It can make progress between display callbacks without
    // becoming a frame-sized lock or host-CPU tenant.
    constexpr std::uint64_t interactive_budget_nanoseconds = 1'000'000U;
    constexpr std::uint64_t predictive_budget_nanoseconds = 2'000'000U;
    constexpr std::uint64_t offline_budget_nanoseconds = 500'000U;
    constexpr std::uint64_t minimum_useful_budget_nanoseconds = 100'000U;
    constexpr std::uint64_t interactive_reserve_floor_nanoseconds = 500'000U;
    constexpr std::uint64_t compile_reserve_margin_nanoseconds = 250'000U;
    constexpr std::uint64_t offline_reserve_floor_nanoseconds = 20'000'000U;
    constexpr auto offline_display_quiet = std::chrono::milliseconds { 100 };
    constexpr auto offline_guest_quiet = std::chrono::milliseconds { 20 };
    constexpr std::size_t activation_block_limit = 256U;
    constexpr std::size_t interactive_block_limit = 32U;
    constexpr std::size_t predictive_block_limit = 64U;
    constexpr std::size_t offline_block_limit = 16U;

    [[nodiscard]] std::uint64_t saturating_add(
        std::uint64_t left, std::uint64_t right) noexcept
    {
        return right > std::numeric_limits<std::uint64_t>::max() - left
                   ? std::numeric_limits<std::uint64_t>::max()
                   : left + right;
    }

    [[nodiscard]] std::uint64_t duration_nanoseconds(
        std::chrono::nanoseconds duration) noexcept
    {
        return duration <= std::chrono::nanoseconds::zero()
                   ? 0U
                   : static_cast<std::uint64_t>(duration.count());
    }

} // namespace

JitNativePredictionPolicy JitWorkPolicy::native_prediction_policy(
    std::size_t native_slab_bytes) noexcept
{
    constexpr std::size_t maximum_prediction_bytes =
        256U * 1024U * 1024U;
    // Native output varies by block. One KiB is deliberately conservative for
    // choosing an ordering horizon; the emitter's measured byte cap below is
    // authoritative and stops prediction before it can consume demand space.
    constexpr std::size_t estimated_native_bytes_per_location = 1024U;
    const auto demand_floor =
        JitCodeCacheGovernor::minimum_demand_working_set_bytes;
    const auto spare = native_slab_bytes > demand_floor
                           ? native_slab_bytes - demand_floor
                           : std::size_t { 0U };
    const auto maximum_code_bytes = std::min(
        { spare, native_slab_bytes / 4U, maximum_prediction_bytes });
    auto remaining_locations = std::min(
        jit_translation_profile_maximum_locations,
        maximum_code_bytes / estimated_native_bytes_per_location);

    JitNativePredictionPolicy result;
    result.maximum_code_bytes = maximum_code_bytes;
    result.activation_locations = std::min(
        remaining_locations,
        jit_translation_profile_activation_prediction_capacity);
    remaining_locations -= result.activation_locations;
    result.recent_locations = std::min(remaining_locations,
        jit_translation_profile_recent_prediction_capacity);
    remaining_locations -= result.recent_locations;
    result.historical_locations = remaining_locations;
    return result;
}

std::size_t JitWorkPolicy::recommended_native_slab_bytes(
    std::uint64_t effective_memory_bytes, bool effective_memory_known,
    std::uint64_t available_memory_bytes, bool available_memory_known) noexcept
{
    if (!effective_memory_known ||
        effective_memory_bytes < expanded_effective_memory_floor ||
        (available_memory_known &&
            available_memory_bytes < expanded_available_memory_floor)) {
        return minimum_native_slab_bytes;
    }
    std::size_t desired = expanded_native_slab_bytes;
    if (effective_memory_bytes >= spacious_effective_memory_floor &&
        (!available_memory_known ||
            available_memory_bytes >= spacious_available_memory_floor)) {
        desired = spacious_native_slab_bytes;
    }
    if (effective_memory_bytes >= ample_effective_memory_floor &&
        (!available_memory_known ||
            available_memory_bytes >= ample_available_memory_floor)) {
        desired = ample_native_slab_bytes;
    }
    if (effective_memory_bytes >= large_effective_memory_floor &&
        (!available_memory_known ||
            available_memory_bytes >= large_available_memory_floor)) {
        desired = large_native_slab_bytes;
    }
    if (effective_memory_bytes >= maximum_effective_memory_floor &&
        (!available_memory_known ||
            available_memory_bytes >= maximum_available_memory_floor)) {
        desired = maximum_x64_native_slab_bytes;
    }
    return std::min(desired, JitWorkPolicy::maximum_native_slab_bytes());
}

std::size_t JitWorkPolicy::recommended_translation_lanes(
    std::size_t host_worker_count) noexcept
{
    if (host_worker_count <= 1U)
        return host_worker_count;
    return std::min(jit_work_policy_maximum_translation_lanes,
        std::max<std::size_t>(2U, host_worker_count / 2U));
}

std::chrono::milliseconds JitWorkPolicy::activation_preparation_window(
    std::size_t translation_lanes) noexcept
{
    constexpr auto per_lane = std::chrono::milliseconds { 16 };
    const auto lanes =
        std::min(translation_lanes, jit_work_policy_maximum_translation_lanes);
    return per_lane * static_cast<std::chrono::milliseconds::rep>(lanes);
}

JitWorkDecision JitWorkPolicy::decide(
    JitWorkClass work, const JitWorkObservation& observation) const noexcept
{
    if (observation.memory_pressure) {
        return { 0U, 0U, JitWorkBlockReason::MemoryPressure };
    }

    const auto historical_block =
        std::max(observation.block_compile_p95_nanoseconds,
            observation.block_compile_p99_nanoseconds);
    std::uint64_t maximum_budget { };
    std::uint64_t deadline_reserve { };
    std::size_t maximum_blocks { };
    std::uint64_t deadline_budget_divisor = 1U;
    if (work == JitWorkClass::ActivationNative) {
        maximum_budget = activation_budget_nanoseconds;
        deadline_reserve = std::max(interactive_reserve_floor_nanoseconds,
            saturating_add(
                historical_block, compile_reserve_margin_nanoseconds));
        maximum_blocks = activation_block_limit;
        deadline_budget_divisor = 2U;
    } else if (work == JitWorkClass::InteractiveNative) {
        if (observation.realtime_work_pending ||
            !observation.interaction_quiet_for ||
            *observation.interaction_quiet_for <
                interactive_native_quiet_period()) {
            return { 0U, 0U, JitWorkBlockReason::GuestBusy };
        }
        maximum_budget = interactive_budget_nanoseconds;
        deadline_reserve = std::max(interactive_reserve_floor_nanoseconds,
            saturating_add(
                historical_block, compile_reserve_margin_nanoseconds));
        maximum_blocks = interactive_block_limit;
        // Live-image prediction is strictly spare-deadline work. Retain most
        // of the available slack even after the fixed reserve is satisfied.
        deadline_budget_divisor = 4U;
    } else if (work == JitWorkClass::ActivationPortable) {
        maximum_budget = activation_portable_budget_nanoseconds;
        deadline_reserve = std::max(interactive_reserve_floor_nanoseconds,
            saturating_add(
                historical_block, compile_reserve_margin_nanoseconds));
        maximum_blocks = activation_block_limit;
        // Interactive translation runs on an independent executor. Native
        // publication is serialized per slab, while portable workers avoid
        // the slab entirely; both retain half of short deadline slack.
        deadline_budget_divisor = 2U;
    } else if (work == JitWorkClass::PredictiveNative) {
        maximum_budget = predictive_budget_nanoseconds;
        deadline_reserve = std::max(interactive_reserve_floor_nanoseconds,
            saturating_add(
                historical_block, compile_reserve_margin_nanoseconds));
        maximum_blocks = predictive_block_limit;
        deadline_budget_divisor = 4U;
    } else {
        if (!observation.display_started || !observation.display_quiet_for ||
            *observation.display_quiet_for < offline_display_quiet) {
            return { 0U, 0U, JitWorkBlockReason::DisplayBusy };
        }
        // Without a finite timer, explicit guest quiescence is the only
        // evidence that portable persistence will not compete with useful
        // work. A finite deadline is protected by the larger reserve below.
        if (!observation.deadline_remaining &&
            (!observation.guest_idle_for ||
                *observation.guest_idle_for < offline_guest_quiet)) {
            return { 0U, 0U, JitWorkBlockReason::GuestBusy };
        }
        maximum_budget = offline_budget_nanoseconds;
        deadline_reserve = std::max(offline_reserve_floor_nanoseconds,
            saturating_add(
                historical_block, compile_reserve_margin_nanoseconds));
        maximum_blocks = offline_block_limit;
    }

    auto budget = maximum_budget;
    if (observation.deadline_remaining) {
        const auto remaining =
            duration_nanoseconds(*observation.deadline_remaining);
        if (remaining <= deadline_reserve) {
            return { 0U, 0U, JitWorkBlockReason::DeadlineReserve };
        }
        budget = std::min(
            budget, (remaining - deadline_reserve) / deadline_budget_divisor);
    }
    if (budget < minimum_useful_budget_nanoseconds) {
        return { 0U, 0U, JitWorkBlockReason::ZeroBudget };
    }
    return { budget, maximum_blocks, JitWorkBlockReason::None };
}

} // namespace shade
