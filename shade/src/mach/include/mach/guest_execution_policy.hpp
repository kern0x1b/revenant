// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Select host cooperation budgets for scheduler-selected guest
// threads.

#pragma once

#include <chrono>
#include <cstdint>
#include <map>
#include <optional>

#include "mach/xnu_scheduler.hpp"

namespace shade {

struct GuestExecutionBudgetRequest {
    XnuThreadId thread;
    std::chrono::nanoseconds jit_block_p99 { };
    std::optional<std::chrono::nanoseconds> host_control_delay;
    std::optional<std::chrono::nanoseconds> guest_realtime_deadline_delay;
    bool latency_sensitive { };
};

// Core host-execution policy for an XNU-selected guest thread. It chooses only
// the wall-clock boundary passed to Umbra; XNU remains the owner of runnable
// selection, priorities, quanta, realtime policy and guest preemption.
class GuestExecutionPolicy {
public:
    explicit GuestExecutionPolicy(std::chrono::nanoseconds response_period);

    [[nodiscard]] std::chrono::nanoseconds budget(const XnuScheduler& scheduler,
        const GuestExecutionBudgetRequest& request) const;
    void observe(XnuThreadId thread, XnuSliceCompletion completion);
    void forget(XnuThreadId thread);
    void forget_process(std::uint32_t process_id);

private:
    struct ThreadHistory {
        std::uint8_t saturation_level { };
    };

    static constexpr std::uint8_t maximum_saturation_level = 2;

    std::chrono::nanoseconds response_period_;
    std::chrono::nanoseconds minimum_budget_;
    std::chrono::nanoseconds initial_budget_;
    std::chrono::nanoseconds latency_budget_;
    std::chrono::nanoseconds throughput_budget_;
    std::map<XnuThreadId, ThreadHistory> histories_;
};

} // namespace shade
