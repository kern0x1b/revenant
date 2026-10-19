// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Measure host memory availability and derive memory-pressure budget
// snapshots.

#include "foundation/host_memory.hpp"

#include <algorithm>

namespace shade {

[[nodiscard]] std::optional<std::uint64_t> effective_host_memory_limit(
    const HostMemoryBudgetSnapshot& memory)
{
    std::optional<std::uint64_t> limit;
    if (memory.physical_known)
        limit = memory.physical_bytes;
    if (memory.cgroup_limit_known) {
        limit =
            limit ? std::min(*limit, memory.cgroup_limit_bytes)
                  : std::optional<std::uint64_t> { memory.cgroup_limit_bytes };
    }
    return limit;
}

[[nodiscard]] HostMemoryPressureLevel host_memory_pressure_level(
    const HostMemoryBudgetSnapshot& memory)
{
    bool observed { };
    bool constrained { };
    bool critical { };
    if (memory.available_known) {
        observed = true;
        critical = critical || memory.available_bytes == 0U;
        if (memory.physical_known && memory.physical_bytes != 0U &&
            memory.available_bytes < memory.physical_bytes / 8U) {
            constrained = true;
        }
    }
    if (memory.cgroup_limit_known && memory.cgroup_current_known) {
        observed = true;
        if (memory.cgroup_current_bytes >= memory.cgroup_limit_bytes) {
            critical = true;
        } else if (memory.cgroup_limit_bytes != 0U &&
                   memory.cgroup_limit_bytes - memory.cgroup_current_bytes <
                       memory.cgroup_limit_bytes / 8U) {
            constrained = true;
        }
    }
    if (const auto limit = effective_host_memory_limit(memory);
        limit && memory.rss_known) {
        observed = true;
        if (*limit == 0U ? memory.rss_bytes != 0U
                         : memory.rss_bytes >= *limit) {
            critical = true;
        } else if (*limit != 0U && memory.rss_bytes > *limit - *limit / 4U) {
            constrained = true;
        }
    }
    if (critical)
        return HostMemoryPressureLevel::Critical;
    if (constrained)
        return HostMemoryPressureLevel::Constrained;
    return observed ? HostMemoryPressureLevel::Normal
                    : HostMemoryPressureLevel::Unknown;
}

[[nodiscard]] bool host_memory_is_pressured(
    const HostMemoryBudgetSnapshot& memory)
{
    const auto level = host_memory_pressure_level(memory);
    return level == HostMemoryPressureLevel::Constrained ||
           level == HostMemoryPressureLevel::Critical;
}

[[nodiscard]] std::string_view host_memory_pressure_name(
    const HostMemoryBudgetSnapshot& memory)
{
    switch (host_memory_pressure_level(memory)) {
    case HostMemoryPressureLevel::Unknown:
        return "unknown";
    case HostMemoryPressureLevel::Normal:
        return "normal";
    case HostMemoryPressureLevel::Constrained:
        return "constrained";
    case HostMemoryPressureLevel::Critical:
        return "critical";
    }
    return "unknown";
}

} // namespace shade
