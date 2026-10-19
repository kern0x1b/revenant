// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Describe guest-visible processors, instruction capabilities and
// cache topology.

#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <limits>

namespace shade {

// These bits describe the ISA visible to the guest. They are deliberately
// independent of the host CPU feature set: a host may execute an ARMv6 guest
// with a newer backend, but the guest must still observe the selected profile.
namespace guest_cpu_isa {

    inline constexpr std::uint64_t armv6k = 1ULL << 0U;
    inline constexpr std::uint64_t armv7 = 1ULL << 1U;
    inline constexpr std::uint64_t thumb = 1ULL << 2U;
    inline constexpr std::uint64_t thumb2 = 1ULL << 3U;

} // namespace guest_cpu_isa

enum class GuestCpuPerformanceClass : std::uint8_t {
    Unknown,
    Legacy,
    Efficiency,
    Performance,
};

struct GuestCpuCluster {
    std::uint32_t first_logical_cpu { };
    std::uint32_t logical_cpu_count { };
    std::uint64_t affinity_mask { };
    std::uint32_t frequency_hz { };
    GuestCpuPerformanceClass performance_class {
        GuestCpuPerformanceClass::Unknown
    };
    std::uint64_t cache_topology_id { };
};

struct GuestCpuTopology {
    static constexpr std::size_t maximum_clusters = 8;

    std::uint32_t physical_core_count { };
    std::uint32_t logical_cpu_count { };
    std::uint64_t isa_feature_mask { };
    std::array<GuestCpuCluster, maximum_clusters> clusters { };
    std::uint32_t cluster_count { };
    std::uint64_t cache_topology_id { };

    [[nodiscard]] constexpr bool valid() const noexcept;

    [[nodiscard]] static constexpr GuestCpuTopology symmetric_cores(
        std::uint32_t core_count, std::uint32_t frequency_hz,
        GuestCpuPerformanceClass performance_class,
        std::uint64_t isa_feature_mask, std::uint64_t cache_topology_id);

    [[nodiscard]] static constexpr GuestCpuTopology single_core(
        std::uint32_t frequency_hz, GuestCpuPerformanceClass performance_class,
        std::uint64_t isa_feature_mask, std::uint64_t cache_topology_id);
};

namespace detail {

    [[nodiscard]] constexpr std::uint64_t guest_cpu_contiguous_mask(
        std::uint32_t first_cpu, std::uint32_t cpu_count) noexcept
    {
        if (cpu_count == 0U || first_cpu >= 64U ||
            cpu_count > 64U - first_cpu) {
            return 0;
        }
        if (cpu_count == 64U) {
            return std::numeric_limits<std::uint64_t>::max();
        }
        return ((std::uint64_t { 1 } << cpu_count) - 1U) << first_cpu;
    }

} // namespace detail

constexpr bool GuestCpuTopology::valid() const noexcept
{
    if (physical_core_count == 0U || logical_cpu_count == 0U ||
        physical_core_count > logical_cpu_count || cluster_count == 0U ||
        cluster_count > maximum_clusters || logical_cpu_count > 64U ||
        cache_topology_id == 0U || isa_feature_mask == 0U) {
        return false;
    }

    std::uint32_t next_logical_cpu = 0;
    for (std::size_t index = 0; index < cluster_count; ++index) {
        const auto& cluster = clusters[index];
        if (cluster.first_logical_cpu != next_logical_cpu ||
            cluster.logical_cpu_count == 0U || cluster.frequency_hz == 0U ||
            cluster.cache_topology_id == 0U ||
            cluster.affinity_mask !=
                detail::guest_cpu_contiguous_mask(
                    cluster.first_logical_cpu, cluster.logical_cpu_count)) {
            return false;
        }
        next_logical_cpu += cluster.logical_cpu_count;
    }
    return next_logical_cpu == logical_cpu_count;
}

constexpr GuestCpuTopology GuestCpuTopology::symmetric_cores(
    std::uint32_t core_count, std::uint32_t frequency_hz,
    GuestCpuPerformanceClass performance_class,
    std::uint64_t isa_feature_mask, std::uint64_t cache_topology_id)
{
    GuestCpuTopology topology;
    topology.physical_core_count = core_count;
    topology.logical_cpu_count = core_count;
    topology.isa_feature_mask = isa_feature_mask;
    topology.cluster_count = 1U;
    topology.cache_topology_id = cache_topology_id;
    topology.clusters[0] = GuestCpuCluster {
        .first_logical_cpu = 0U,
        .logical_cpu_count = core_count,
        .affinity_mask = detail::guest_cpu_contiguous_mask(0U, core_count),
        .frequency_hz = frequency_hz,
        .performance_class = performance_class,
        .cache_topology_id = cache_topology_id,
    };
    return topology;
}

constexpr GuestCpuTopology GuestCpuTopology::single_core(
    std::uint32_t frequency_hz, GuestCpuPerformanceClass performance_class,
    std::uint64_t isa_feature_mask, std::uint64_t cache_topology_id)
{
    return symmetric_cores(1U, frequency_hz, performance_class,
        isa_feature_mask, cache_topology_id);
}

} // namespace shade
