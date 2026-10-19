// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Sample host process CPU, memory and storage resource usage.

#include "host/resource_usage.hpp"

#include <array>
#if defined(__APPLE__)
#include <mach/mach.h>
#include <sys/sysctl.h>
#endif
#include <filesystem>
#include <fstream>
#include <limits>
#include <sstream>
#include <string>

namespace shade {
namespace {

    [[nodiscard]] std::optional<std::uint64_t> read_decimal_file(
        const std::filesystem::path& path)
    {
        std::ifstream input { path };
        std::string value;
        input >> value;
        if (!input || value.empty() || value == "max")
            return std::nullopt;
        std::size_t consumed { };
        try {
            const auto parsed = std::stoull(value, &consumed, 10);
            if (consumed != value.size())
                return std::nullopt;
            return static_cast<std::uint64_t>(parsed);
        } catch (const std::exception&) {
            return std::nullopt;
        }
    }

} // namespace

[[nodiscard]] HostMemorySnapshot host_memory_snapshot()
{
    HostMemorySnapshot snapshot;
#if defined(__linux__)
    std::ifstream status { "/proc/self/status" };
    std::string line;
    while (std::getline(status, line)) {
        std::istringstream fields { line };
        std::string label;
        std::uint64_t value { };
        std::string unit;
        fields >> label >> value >> unit;
        if (!fields || unit != "kB")
            continue;
        if (value > std::numeric_limits<std::uint64_t>::max() / 1024U)
            continue;
        const auto bytes = value * 1024U;
        if (label == "VmRSS:") {
            snapshot.rss_bytes = bytes;
            snapshot.rss_known = true;
        }
        if (label == "VmHWM:") {
            snapshot.peak_rss_bytes = bytes;
            snapshot.peak_rss_known = true;
        }
        if (label == "VmSize:") {
            snapshot.virtual_bytes = bytes;
            snapshot.virtual_known = true;
        }
        if (label == "RssFile:") {
            snapshot.file_mapped_bytes = bytes;
            snapshot.file_mapped_known = true;
        }
    }
#elif defined(__APPLE__)
    // Darwin keeps this in the task rather than in a file: the kernel answers
    // for the process itself, and what it calls resident and virtual is what
    // /proc/self/status calls VmRSS and VmSize. How much of the resident set is
    // file-mapped it does not say, so that stays unknown rather than guessed.
    mach_task_basic_info_data_t task_memory { };
    mach_msg_type_number_t task_memory_count = MACH_TASK_BASIC_INFO_COUNT;
    if (::task_info(mach_task_self(), MACH_TASK_BASIC_INFO,
                    reinterpret_cast<task_info_t>(&task_memory),
                    &task_memory_count) == KERN_SUCCESS) {
        snapshot.rss_bytes = task_memory.resident_size;
        snapshot.rss_known = true;
        snapshot.peak_rss_bytes = task_memory.resident_size_max;
        snapshot.peak_rss_known = true;
        snapshot.virtual_bytes = task_memory.virtual_size;
        snapshot.virtual_known = true;
    }
#endif
    return snapshot;
}

[[nodiscard]] HostMemoryBudgetSnapshot host_memory_budget_snapshot()
{
    HostMemoryBudgetSnapshot snapshot;
    const auto process_memory = host_memory_snapshot();
    snapshot.rss_bytes = process_memory.rss_bytes;
    snapshot.rss_known = process_memory.rss_known;
#if defined(__linux__)
    {
        std::ifstream meminfo { "/proc/meminfo" };
        std::string line;
        while (std::getline(meminfo, line)) {
            std::istringstream fields { line };
            std::string label;
            std::uint64_t value { };
            std::string unit;
            fields >> label >> value >> unit;
            if (!fields || unit != "kB" ||
                value > std::numeric_limits<std::uint64_t>::max() / 1024U) {
                continue;
            }
            const auto bytes = value * 1024U;
            if (label == "MemTotal:") {
                snapshot.physical_bytes = bytes;
                snapshot.physical_known = true;
            }
            if (label == "MemAvailable:") {
                snapshot.available_bytes = bytes;
                snapshot.available_known = true;
            }
        }
    }

    std::filesystem::path cgroup_path;
    {
        std::ifstream groups { "/proc/self/cgroup" };
        std::string line;
        while (std::getline(groups, line)) {
            constexpr std::string_view unified_prefix = "0::";
            if (!line.starts_with(unified_prefix))
                continue;
            auto relative = line.substr(unified_prefix.size());
            while (!relative.empty() && relative.front() == '/')
                relative.erase(relative.begin());
            cgroup_path = std::filesystem::path { "/sys/fs/cgroup" };
            if (!relative.empty())
                cgroup_path /= relative;
            break;
        }
    }

    const auto read_first =
        [](const std::array<std::filesystem::path, 3>& paths)
        -> std::optional<std::uint64_t> {
        for (const auto& path : paths) {
            if (path.empty())
                continue;
            if (const auto value = read_decimal_file(path))
                return value;
        }
        return std::nullopt;
    };
    const std::array<std::filesystem::path, 3> limit_paths {
        cgroup_path.empty() ? std::filesystem::path { }
                            : cgroup_path / "memory.max",
        cgroup_path.empty() ? std::filesystem::path { }
                            : cgroup_path / "memory.limit_in_bytes",
        std::filesystem::path { "/sys/fs/cgroup/memory.max" },
    };
    const std::array<std::filesystem::path, 3> current_paths {
        cgroup_path.empty() ? std::filesystem::path { }
                            : cgroup_path / "memory.current",
        cgroup_path.empty() ? std::filesystem::path { }
                            : cgroup_path / "memory.usage_in_bytes",
        std::filesystem::path { "/sys/fs/cgroup/memory.current" },
    };
    if (const auto limit = read_first(limit_paths)) {
        snapshot.cgroup_limit_bytes = *limit;
        snapshot.cgroup_limit_known = true;
    }
    if (const auto current = read_first(current_paths)) {
        snapshot.cgroup_current_bytes = *current;
        snapshot.cgroup_current_known = true;
    }
    // cgroup-v1 uses a very large sentinel for "unlimited". Treat any limit
    // many times larger than physical memory as equivalent to no finite limit.
    if (snapshot.cgroup_limit_known && snapshot.physical_known &&
        snapshot.cgroup_limit_bytes != 0U && snapshot.physical_bytes != 0U &&
        snapshot.physical_bytes <=
            std::numeric_limits<std::uint64_t>::max() / 2U &&
        snapshot.cgroup_limit_bytes >
            snapshot.physical_bytes * std::uint64_t { 2U }) {
        snapshot.cgroup_limit_bytes = 0U;
        snapshot.cgroup_limit_known = false;
    }
#elif defined(__APPLE__)
    // Darwin has no /proc/meminfo: the machine's memory is a sysctl, and what
    // of it is available the kernel reports as page counts. Free and inactive
    // pages are the ones a new mapping can have without pushing anything out,
    // and the speculative ones are read-ahead the kernel drops first, so those
    // three are what "available" means here. Without them the JIT sizes its
    // code cache from a machine it believes has no memory at all.
    {
        std::uint64_t physical = 0;
        std::size_t physical_size = sizeof physical;
        if (::sysctlbyname("hw.memsize", &physical, &physical_size, nullptr,
                           0) == 0 &&
            physical != 0U) {
            snapshot.physical_bytes = physical;
            snapshot.physical_known = true;
        }
        vm_statistics64_data_t pages { };
        mach_msg_type_number_t page_count = HOST_VM_INFO64_COUNT;
        if (::host_statistics64(mach_host_self(), HOST_VM_INFO64,
                                reinterpret_cast<host_info64_t>(&pages),
                                &page_count) == KERN_SUCCESS) {
            const auto page_size =
                static_cast<std::uint64_t>(::vm_kernel_page_size);
            snapshot.available_bytes =
                (static_cast<std::uint64_t>(pages.free_count) +
                 static_cast<std::uint64_t>(pages.inactive_count) +
                 static_cast<std::uint64_t>(pages.speculative_count)) *
                page_size;
            snapshot.available_known = true;
        }
    }
#endif
    return snapshot;
}

} // namespace shade
