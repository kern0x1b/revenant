// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Measure host memory availability and derive memory-pressure budget
// snapshots.

#pragma once

#include <cstdint>
#include <optional>
#include <string_view>

namespace shade {

struct HostMemorySnapshot {
    std::uint64_t rss_bytes { };
    std::uint64_t peak_rss_bytes { };
    std::uint64_t virtual_bytes { };
    std::uint64_t file_mapped_bytes { };
    bool rss_known { };
    bool peak_rss_known { };
    bool virtual_known { };
    bool file_mapped_known { };
};

struct HostMemoryBudgetSnapshot {
    std::uint64_t physical_bytes { };
    std::uint64_t available_bytes { };
    std::uint64_t rss_bytes { };
    std::uint64_t cgroup_limit_bytes { };
    std::uint64_t cgroup_current_bytes { };
    bool physical_known { };
    bool available_known { };
    bool rss_known { };
    bool cgroup_limit_known { };
    bool cgroup_current_known { };
};

enum class HostMemoryPressureLevel : std::uint8_t {
    Unknown,
    Normal,
    Constrained,
    Critical,
};

[[nodiscard]] std::optional<std::uint64_t> effective_host_memory_limit(
    const HostMemoryBudgetSnapshot& memory);
[[nodiscard]] HostMemoryPressureLevel host_memory_pressure_level(
    const HostMemoryBudgetSnapshot& memory);
[[nodiscard]] bool host_memory_is_pressured(
    const HostMemoryBudgetSnapshot& memory);
[[nodiscard]] std::string_view host_memory_pressure_name(
    const HostMemoryBudgetSnapshot& memory);

} // namespace shade
