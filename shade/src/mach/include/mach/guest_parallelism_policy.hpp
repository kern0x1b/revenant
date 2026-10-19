// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Choose parallel guest execution lanes from CPU and syscall
// activity.

#pragma once

#include <cstdint>
#include <map>

#include "mach/xnu_scheduler.hpp"

namespace shade {

// Core execution policy for a guest hardware profile with multiple CPUs.
// Compute-heavy threads may run together, while syscall-dense threads stay on
// the main executor so a serial compatibility-kernel call does not become a
// worker barrier for every SVC.
class GuestParallelismPolicy {
public:
    explicit GuestParallelismPolicy(std::uint64_t guest_ticks_per_second);

    [[nodiscard]] bool should_serialize(XnuThreadId thread) const;
    void observe(XnuThreadId thread, std::uint64_t ticks_consumed,
        std::uint64_t svc_calls);
    void forget(XnuThreadId thread);
    void forget_process(std::uint32_t process_id);

private:
    struct ThreadHistory {
        std::uint8_t syscall_density_score { };
    };

    static constexpr std::uint8_t serialize_score = 2;
    static constexpr std::uint8_t maximum_score = 4;
    static constexpr std::uint64_t minimum_parallel_intervals_per_second =
        4'000;

    std::uint64_t minimum_parallel_ticks_per_svc_ { };
    std::map<XnuThreadId, ThreadHistory> histories_;
};

} // namespace shade
