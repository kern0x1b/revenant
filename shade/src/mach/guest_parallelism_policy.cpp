// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Choose parallel guest execution lanes from CPU and syscall
// activity.

#include "mach/guest_parallelism_policy.hpp"

#include <algorithm>

namespace shade {

GuestParallelismPolicy::GuestParallelismPolicy(
    std::uint64_t guest_ticks_per_second)
    : minimum_parallel_ticks_per_svc_ { std::max<std::uint64_t>(
          1, guest_ticks_per_second / minimum_parallel_intervals_per_second) }
{
}

bool GuestParallelismPolicy::should_serialize(XnuThreadId thread) const
{
    const auto history = histories_.find(thread);
    return history != histories_.end() &&
           history->second.syscall_density_score >= serialize_score;
}

void GuestParallelismPolicy::observe(
    XnuThreadId thread, std::uint64_t ticks_consumed, std::uint64_t svc_calls)
{
    auto history = histories_.find(thread);
    const auto dense = svc_calls != 0 && ticks_consumed / svc_calls <
                                             minimum_parallel_ticks_per_svc_;
    if (dense) {
        if (history == histories_.end()) {
            history = histories_.try_emplace(thread).first;
        }
        history->second.syscall_density_score = std::min<std::uint8_t>(
            maximum_score, history->second.syscall_density_score + 1U);
        return;
    }
    if (history == histories_.end())
        return;
    if (history->second.syscall_density_score > 1U) {
        --history->second.syscall_density_score;
    } else {
        histories_.erase(history);
    }
}

void GuestParallelismPolicy::forget(XnuThreadId thread)
{
    histories_.erase(thread);
}

void GuestParallelismPolicy::forget_process(std::uint32_t process_id)
{
    std::erase_if(histories_, [process_id](const auto& entry) {
        return entry.first.process == process_id;
    });
}

} // namespace shade
