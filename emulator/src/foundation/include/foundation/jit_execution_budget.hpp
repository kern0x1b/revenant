// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Convert host cooperation targets into adaptive guest execution
// budgets.

#pragma once

#include <chrono>
#include <cstdint>

namespace emulator {

class JitHostExecutionBudget {
public:
    [[nodiscard]] std::uint32_t next(
        std::chrono::nanoseconds target) const noexcept;

    void observe(std::uint32_t blocks_executed,
        std::chrono::nanoseconds elapsed) noexcept;

    [[nodiscard]] std::uint64_t estimated_nanoseconds_per_block() const noexcept
    {
        return estimated_nanoseconds_per_block_;
    }

private:
    static constexpr std::uint64_t initial_nanoseconds_per_block = 15'000U;
    static constexpr std::uint32_t maximum_blocks = 262'144U;
    static constexpr std::uint32_t target_utilization_numerator = 7U;
    static constexpr std::uint32_t target_utilization_denominator = 8U;

    std::uint64_t estimated_nanoseconds_per_block_ {
        initial_nanoseconds_per_block
    };
};

}
