// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Convert host cooperation targets into adaptive guest execution
// budgets.

#include "foundation/jit_execution_budget.hpp"

#include <algorithm>
#include <limits>

namespace shade {

std::uint32_t JitHostExecutionBudget::next(
    std::chrono::nanoseconds target) const noexcept
{
    if (target <= std::chrono::nanoseconds::zero())
        return 0U;

    const auto target_nanoseconds = static_cast<std::uint64_t>(target.count());
    const auto usable_nanoseconds = target_nanoseconds /
                                    target_utilization_denominator *
                                    target_utilization_numerator;
    const auto predicted = std::max<std::uint64_t>(
        1U, usable_nanoseconds / estimated_nanoseconds_per_block_);
    return static_cast<std::uint32_t>(
        std::min<std::uint64_t>(predicted, maximum_blocks));
}

void JitHostExecutionBudget::observe(
    std::uint32_t blocks_executed, std::chrono::nanoseconds elapsed) noexcept
{
    if (blocks_executed == 0U || elapsed <= std::chrono::nanoseconds::zero())
        return;

    const auto elapsed_nanoseconds =
        static_cast<std::uint64_t>(elapsed.count());
    auto sample =
        std::max<std::uint64_t>(1U, elapsed_nanoseconds / blocks_executed);

    // A callback, signal, or one unusually costly translation should tighten
    // the next run promptly without permanently poisoning the predictor.
    // Likewise, cached execution may increase throughput by at most one
    // quarter of the measured gap per observation.
    const auto lower =
        std::max<std::uint64_t>(1U, estimated_nanoseconds_per_block_ / 8U);
    const auto upper = estimated_nanoseconds_per_block_ >
                               std::numeric_limits<std::uint64_t>::max() / 8U
                           ? std::numeric_limits<std::uint64_t>::max()
                           : estimated_nanoseconds_per_block_ * 8U;
    sample = std::clamp(sample, lower, upper);
    if (sample > estimated_nanoseconds_per_block_) {
        estimated_nanoseconds_per_block_ +=
            (sample - estimated_nanoseconds_per_block_ + 1U) / 2U;
    } else {
        estimated_nanoseconds_per_block_ -=
            (estimated_nanoseconds_per_block_ - sample) / 4U;
    }
}

} // namespace shade
