// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Derive session code-cache and optional-work budgets from available
// host resources.

#include "resource_policy.hpp"
#include "foundation/jit_code_cache_governor.hpp"
#include "foundation/jit_work_policy.hpp"
#include <algorithm>

namespace shade::runtime_detail {

std::filesystem::path nearest_existing_filesystem_path(
    const std::filesystem::path& path)
{
    std::error_code error;
    auto candidate = std::filesystem::absolute(path, error);
    if (error || candidate.empty())
        candidate = path;
    for (;;) {
        const auto status = std::filesystem::status(candidate, error);
        if (!error && status.type() != std::filesystem::file_type::not_found) {
            return candidate;
        }
        const auto parent = candidate.parent_path();
        if (parent.empty() || parent == candidate)
            return { };
        candidate = parent;
        error.clear();
    }
}

[[nodiscard]] JitCodeCacheBudget jit_code_cache_budget(
    std::optional<std::size_t> configured,
    const HostMemoryBudgetSnapshot& memory)
{
    if (configured)
        return JitCodeCacheBudget { *configured, memory, true };

    const auto effective_limit_value = effective_host_memory_limit(memory);
    const auto effective_limit =
        effective_limit_value.value_or(static_cast<std::uint64_t>(
            JitCodeCacheGovernor::maximum_adaptive_budget_bytes));
    bool headroom_known = memory.available_known;
    auto headroom = memory.available_bytes;
    if (memory.cgroup_limit_known && memory.cgroup_current_known) {
        const auto cgroup_headroom =
            memory.cgroup_current_bytes >= memory.cgroup_limit_bytes
                ? std::uint64_t { 0 }
                : memory.cgroup_limit_bytes - memory.cgroup_current_bytes;
        if (!headroom_known) {
            headroom = cgroup_headroom;
            headroom_known = true;
        } else {
            headroom = std::min(headroom, cgroup_headroom);
        }
    }
    if (effective_limit_value && memory.rss_known) {
        const auto rss_headroom =
            memory.rss_bytes >= *effective_limit_value
                ? std::uint64_t { 0 }
                : *effective_limit_value - memory.rss_bytes;
        if (!headroom_known) {
            headroom = rss_headroom;
            headroom_known = true;
        } else {
            headroom = std::min(headroom, rss_headroom);
        }
    }
    const auto target =
        JitCodeCacheGovernor::recommended_total_budget(effective_limit,
            effective_limit_value.has_value(), headroom, headroom_known);
    return JitCodeCacheBudget { target, memory, false };
}

std::size_t adaptive_jit_code_cache_size(const HostMemoryBudgetSnapshot& memory)
{
    const auto effective = effective_host_memory_limit(memory);
    return JitWorkPolicy::recommended_native_slab_bytes(effective.value_or(0U),
        effective.has_value(), memory.available_bytes, memory.available_known);
}

} // namespace shade::runtime_detail
