// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Aggregate per-runtime JIT memory and work snapshots for session
// diagnostics.

#pragma once

#include "process.hpp"

namespace shade::runtime_detail {

struct RuntimeJitMemoryAggregate {
    std::size_t runtime_count { };
    std::size_t runtime_scan_iterations { };
    std::size_t stats_samples { };
    std::size_t queue_lock_acquisitions { };
    JitPrecompileMemoryStats final_before_retirement { };
    JitPrecompileMemoryStats concurrent_live_current { };
    JitPrecompileMemoryStats concurrent_live_peak { };
    JitPrecompileMemoryStats per_runtime_peak_sum_upper_bound { };

    static void add_saturating(std::size_t& target, std::size_t value) noexcept
    {
        target = value > std::numeric_limits<std::size_t>::max() - target
                     ? std::numeric_limits<std::size_t>::max()
                     : target + value;
    }

    static void add_current(JitPrecompileMemoryStats& target,
        const JitPrecompileMemoryStats& stats) noexcept
    {
        add_saturating(target.profile_queue_capacity_entries,
            stats.profile_queue_capacity_entries);
        add_saturating(
            target.profile_queue_entries, stats.profile_queue_entries);
        add_saturating(
            target.catalog_queue_entries, stats.catalog_queue_entries);
        add_saturating(
            target.generic_queue_entries, stats.generic_queue_entries);
        add_saturating(target.pending_entries, stats.pending_entries);
        add_saturating(target.inflight_entries, stats.inflight_entries);
        add_saturating(target.deferred_entries, stats.deferred_entries);
        add_saturating(target.completed_entries, stats.completed_entries);
        add_saturating(target.estimated_queue_entry_bytes,
            stats.estimated_queue_entry_bytes);
        add_saturating(target.queue_bucket_bytes, stats.queue_bucket_bytes);
        add_saturating(target.queue_node_bytes, stats.queue_node_bytes);
        add_saturating(target.queue_block_bytes, stats.queue_block_bytes);
        add_saturating(
            target.profile_recorder_bytes, stats.profile_recorder_bytes);
        add_saturating(target.native_profile_prediction_bytes,
            stats.native_profile_prediction_bytes);
        add_saturating(target.native_preimport_tracker_bytes,
            stats.native_preimport_tracker_bytes);
        for (std::size_t index = 0; index < jit_precompile_source_count;
            ++index) {
            const auto& source = stats.by_source[index];
            auto& destination = target.by_source[index];
            add_saturating(destination.queued_entries, source.queued_entries);
            add_saturating(destination.pending_entries, source.pending_entries);
            add_saturating(
                destination.inflight_entries, source.inflight_entries);
            add_saturating(
                destination.deferred_entries, source.deferred_entries);
            add_saturating(
                destination.completed_entries, source.completed_entries);
            add_saturating(destination.estimated_queue_entry_bytes,
                source.estimated_queue_entry_bytes);
            add_saturating(
                destination.queue_bucket_bytes, source.queue_bucket_bytes);
            add_saturating(
                destination.queue_node_bytes, source.queue_node_bytes);
            add_saturating(
                destination.queue_block_bytes, source.queue_block_bytes);
        }
    }

    static void subtract_current(JitPrecompileMemoryStats& target,
        const JitPrecompileMemoryStats& stats) noexcept
    {
        const auto subtract = [](std::size_t& value,
                                  std::size_t amount) noexcept {
            value = amount > value ? 0U : value - amount;
        };
        subtract(target.profile_queue_capacity_entries,
            stats.profile_queue_capacity_entries);
        subtract(target.profile_queue_entries, stats.profile_queue_entries);
        subtract(target.catalog_queue_entries, stats.catalog_queue_entries);
        subtract(target.generic_queue_entries, stats.generic_queue_entries);
        subtract(target.pending_entries, stats.pending_entries);
        subtract(target.inflight_entries, stats.inflight_entries);
        subtract(target.deferred_entries, stats.deferred_entries);
        subtract(target.completed_entries, stats.completed_entries);
        subtract(target.estimated_queue_entry_bytes,
            stats.estimated_queue_entry_bytes);
        subtract(target.queue_bucket_bytes, stats.queue_bucket_bytes);
        subtract(target.queue_node_bytes, stats.queue_node_bytes);
        subtract(target.queue_block_bytes, stats.queue_block_bytes);
        subtract(target.profile_recorder_bytes, stats.profile_recorder_bytes);
        subtract(target.native_profile_prediction_bytes,
            stats.native_profile_prediction_bytes);
        subtract(target.native_preimport_tracker_bytes,
            stats.native_preimport_tracker_bytes);
        for (std::size_t index = 0; index < jit_precompile_source_count;
            ++index) {
            const auto& source = stats.by_source[index];
            auto& destination = target.by_source[index];
            subtract(destination.queued_entries, source.queued_entries);
            subtract(destination.pending_entries, source.pending_entries);
            subtract(destination.inflight_entries, source.inflight_entries);
            subtract(destination.deferred_entries, source.deferred_entries);
            subtract(destination.completed_entries, source.completed_entries);
            subtract(destination.estimated_queue_entry_bytes,
                source.estimated_queue_entry_bytes);
            subtract(destination.queue_bucket_bytes, source.queue_bucket_bytes);
            subtract(destination.queue_node_bytes, source.queue_node_bytes);
            subtract(destination.queue_block_bytes, source.queue_block_bytes);
        }
    }

    static void add_runtime_peak(JitPrecompileMemoryStats& target,
        const JitPrecompileMemoryStats& stats) noexcept
    {
        add_saturating(
            target.profile_queue_entries, stats.profile_queue_entries_peak);
        add_saturating(
            target.catalog_queue_entries, stats.catalog_queue_entries_peak);
        add_saturating(
            target.generic_queue_entries, stats.generic_queue_entries_peak);
        add_saturating(target.pending_entries, stats.pending_entries_peak);
        add_saturating(target.inflight_entries, stats.inflight_entries_peak);
        add_saturating(target.deferred_entries, stats.deferred_entries_peak);
        add_saturating(target.completed_entries, stats.completed_entries_peak);
        add_saturating(target.estimated_queue_entry_bytes,
            stats.estimated_queue_entry_bytes_peak);
        add_saturating(
            target.queue_bucket_bytes, stats.queue_bucket_bytes_peak);
        add_saturating(target.queue_node_bytes, stats.queue_node_bytes_peak);
        add_saturating(target.queue_block_bytes, stats.queue_block_bytes_peak);
        add_saturating(
            target.profile_recorder_bytes, stats.profile_recorder_bytes_peak);
        add_saturating(target.native_profile_prediction_bytes,
            stats.native_profile_prediction_bytes_peak);
        add_saturating(target.native_preimport_tracker_bytes,
            stats.native_preimport_tracker_bytes_peak);
        for (std::size_t index = 0; index < jit_precompile_source_count;
            ++index) {
            const auto& source = stats.by_source[index];
            auto& destination = target.by_source[index];
            add_saturating(
                destination.queued_entries, source.queued_entries_peak);
            add_saturating(
                destination.pending_entries, source.pending_entries_peak);
            add_saturating(
                destination.inflight_entries, source.inflight_entries_peak);
            add_saturating(
                destination.deferred_entries, source.deferred_entries_peak);
            add_saturating(
                destination.completed_entries, source.completed_entries_peak);
            add_saturating(destination.estimated_queue_entry_bytes,
                source.estimated_queue_entry_bytes_peak);
            add_saturating(
                destination.queue_bucket_bytes, source.queue_bucket_bytes_peak);
            add_saturating(
                destination.queue_node_bytes, source.queue_node_bytes_peak);
            add_saturating(
                destination.queue_block_bytes, source.queue_block_bytes_peak);
        }
    }

    static void max_current(JitPrecompileMemoryStats& target,
        const JitPrecompileMemoryStats& current) noexcept
    {
        target.profile_queue_entries = std::max(
            target.profile_queue_entries, current.profile_queue_entries);
        target.catalog_queue_entries = std::max(
            target.catalog_queue_entries, current.catalog_queue_entries);
        target.generic_queue_entries = std::max(
            target.generic_queue_entries, current.generic_queue_entries);
        target.pending_entries =
            std::max(target.pending_entries, current.pending_entries);
        target.inflight_entries =
            std::max(target.inflight_entries, current.inflight_entries);
        target.deferred_entries =
            std::max(target.deferred_entries, current.deferred_entries);
        target.completed_entries =
            std::max(target.completed_entries, current.completed_entries);
        target.estimated_queue_entry_bytes =
            std::max(target.estimated_queue_entry_bytes,
                current.estimated_queue_entry_bytes);
        target.queue_bucket_bytes =
            std::max(target.queue_bucket_bytes, current.queue_bucket_bytes);
        target.queue_node_bytes =
            std::max(target.queue_node_bytes, current.queue_node_bytes);
        target.queue_block_bytes =
            std::max(target.queue_block_bytes, current.queue_block_bytes);
        target.profile_recorder_bytes = std::max(
            target.profile_recorder_bytes, current.profile_recorder_bytes);
        target.native_profile_prediction_bytes =
            std::max(target.native_profile_prediction_bytes,
                current.native_profile_prediction_bytes);
        target.native_preimport_tracker_bytes =
            std::max(target.native_preimport_tracker_bytes,
                current.native_preimport_tracker_bytes);
        for (std::size_t index = 0; index < jit_precompile_source_count;
            ++index) {
            const auto& source = current.by_source[index];
            auto& peak = target.by_source[index];
            peak.queued_entries =
                std::max(peak.queued_entries, source.queued_entries);
            peak.pending_entries =
                std::max(peak.pending_entries, source.pending_entries);
            peak.inflight_entries =
                std::max(peak.inflight_entries, source.inflight_entries);
            peak.deferred_entries =
                std::max(peak.deferred_entries, source.deferred_entries);
            peak.completed_entries =
                std::max(peak.completed_entries, source.completed_entries);
            peak.estimated_queue_entry_bytes =
                std::max(peak.estimated_queue_entry_bytes,
                    source.estimated_queue_entry_bytes);
            peak.queue_bucket_bytes =
                std::max(peak.queue_bucket_bytes, source.queue_bucket_bytes);
            peak.queue_node_bytes =
                std::max(peak.queue_node_bytes, source.queue_node_bytes);
            peak.queue_block_bytes =
                std::max(peak.queue_block_bytes, source.queue_block_bytes);
        }
    }

    void note_stats_sample() noexcept
    {
        ++stats_samples;
        // CpuCluster::precompile_memory_stats() reads the published fixed-size
        // snapshot without taking the queue mutex or walking any container
        // node.
    }

    void observe(const void* runtime_key, const JitPrecompileMemoryStats& stats)
    {
        note_stats_sample();
        const auto [entry, inserted] =
            live_by_runtime.try_emplace(runtime_key, stats);
        if (!inserted) {
            subtract_current(concurrent_live_current, entry->second);
            entry->second = stats;
        }
        add_current(concurrent_live_current, stats);
        max_current(concurrent_live_peak, concurrent_live_current);
    }

    void retire(const void* runtime_key,
        std::optional<JitPrecompileMemoryStats> stats = std::nullopt) noexcept
    {
        const auto found = live_by_runtime.find(runtime_key);
        if (!stats && found != live_by_runtime.end())
            stats = found->second;
        const auto final_stats = stats.value_or(JitPrecompileMemoryStats { });
        add_current(final_before_retirement, final_stats);
        add_runtime_peak(per_runtime_peak_sum_upper_bound, final_stats);
        if (found != live_by_runtime.end()) {
            subtract_current(concurrent_live_current, found->second);
            live_by_runtime.erase(found);
        }
        ++runtime_count;
    }

private:
    std::unordered_map<const void*, JitPrecompileMemoryStats> live_by_runtime;
};

} // namespace shade::runtime_detail
