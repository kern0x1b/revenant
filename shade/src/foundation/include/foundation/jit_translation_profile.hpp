// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Record and persist bounded translation working sets for future JIT
// preparation.

#pragma once

#include <array>
#include <atomic>
#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <map>
#include <memory>
#include <mutex>
#include <span>
#include <string>
#include <string_view>
#include <unordered_set>
#include <utility>
#include <vector>

#include "foundation/content_identity.hpp"
#include "foundation/jit_work_signal.hpp"

namespace shade {

inline constexpr std::size_t jit_translation_profile_maximum_locations =
    262'144;

inline constexpr std::size_t jit_translation_profile_recorder_capacity =
    131'072;
inline constexpr std::size_t jit_translation_profile_recorder_prefix_capacity =
    jit_translation_profile_recorder_capacity / 2U;
inline constexpr std::size_t jit_translation_profile_recorder_recent_capacity =
    jit_translation_profile_recorder_capacity / 4U;
inline constexpr std::size_t
    jit_translation_profile_activation_prediction_capacity =
        jit_translation_profile_recorder_prefix_capacity;
inline constexpr std::size_t
    jit_translation_profile_recent_prediction_capacity =
        jit_translation_profile_recorder_recent_capacity * 2U;
inline constexpr std::size_t jit_translation_profile_recorder_prefix_hash_capacity =
    jit_translation_profile_recorder_prefix_capacity * 2U;
inline constexpr std::size_t jit_translation_profile_recorder_recent_hash_capacity =
    jit_translation_profile_recorder_recent_capacity * 2U;

inline constexpr std::size_t jit_translation_profile_maximum_profiles = 256;
inline constexpr std::size_t jit_translation_profile_maximum_file_bytes =
    4U * 1024U * 1024U;
inline constexpr std::size_t jit_translation_profile_maximum_storage_bytes =
    64U * 1024U * 1024U;

enum class JitTranslationProfileRecordResult : std::uint8_t {
    Recorded,
    Deduplicated,
    DroppedCapacity,
    Ignored,
};

class JitTranslationProfileRecorder {
public:
    JitTranslationProfileRecorder() noexcept = default;

    void set_work_signal(
        std::shared_ptr<JitWorkObservationSignal> signal) noexcept
    {
        work_signal_ = std::move(signal);
    }

    [[nodiscard]] JitTranslationProfileRecordResult record(
        std::uint64_t location_descriptor) noexcept;
    [[nodiscard]] std::vector<std::uint64_t> snapshot() const;
    [[nodiscard]] std::size_t size() const noexcept
    {
        return prefix_size_ + recent_sizes_[0] + recent_sizes_[1];
    }
    [[nodiscard]] std::size_t prefix_size() const noexcept
    {
        return prefix_size_;
    }
    [[nodiscard]] std::uint64_t deduplicated() const noexcept
    {
        return deduplicated_;
    }
    [[nodiscard]] std::uint64_t dropped_capacity() const noexcept
    {
        return dropped_capacity_;
    }
    void reset() noexcept;

private:
    [[nodiscard]] static std::size_t hash(
        std::uint64_t location_descriptor) noexcept;
    [[nodiscard]] static bool contains(
        std::span<const std::uint64_t> table,
        std::uint64_t location_descriptor) noexcept;
    [[nodiscard]] static bool insert(std::span<std::uint64_t> table,
        std::uint64_t location_descriptor) noexcept;

    std::array<std::uint64_t,
        jit_translation_profile_recorder_prefix_capacity>
        prefix_locations_ { };
    std::array<std::array<std::uint64_t,
                   jit_translation_profile_recorder_recent_capacity>,
        2>
        recent_locations_ { };
    std::array<std::uint64_t,
        jit_translation_profile_recorder_prefix_hash_capacity>
        prefix_hash_ { };
    std::array<std::array<std::uint64_t,
                   jit_translation_profile_recorder_recent_hash_capacity>,
        2>
        recent_hashes_ { };
    std::array<std::size_t, 2> recent_sizes_ { };
    std::array<std::uint64_t, 2> recent_sequences_ { 1U, 0U };
    std::size_t prefix_size_ { };
    std::size_t active_recent_bank_ { };
    std::uint64_t next_recent_sequence_ { 2U };
    std::uint64_t deduplicated_ { };
    std::uint64_t dropped_capacity_ { };
    std::shared_ptr<JitWorkObservationSignal> work_signal_;
};

struct JitTranslationProfileStats {
    std::uint64_t recorded { };
    std::uint64_t recorded_descriptors { };
    std::uint64_t newly_recorded_descriptors { };
    std::uint64_t deduplicated { };
    std::uint64_t recorder_deduplicated { };
    std::uint64_t recorder_dropped_capacity { };
    std::uint64_t dropped_capacity { };
    std::uint64_t working_set_evicted { };
    std::uint64_t unstable_dropped { };
    std::uint64_t profile_loaded { };
    std::uint64_t disk_descriptors_loaded { };
    std::uint64_t profile_files_loaded { };
    std::uint64_t disk_files_loaded { };
    std::uint64_t profile_enqueued_portable { };
    std::uint64_t profile_native_enqueued { };
    std::uint64_t profile_native_attempted { };
    std::uint64_t profile_native_executed { };
    std::uint64_t profile_portable_attempted { };
    std::uint64_t profile_portable_executed { };
    std::uint64_t profile_portable_generated { };
    std::uint64_t portable_existence_hits { };
    std::uint64_t native_preimport_attempted { };
    std::uint64_t native_preimport_imported { };
    std::uint64_t native_preimport_already_present { };
    std::uint64_t native_preimport_before_first_demand { };
    std::uint64_t native_preimport_used { };
    std::uint64_t native_preimport_first_use_distance_samples { };
    std::uint64_t native_preimport_first_use_distance_total { };
    std::uint64_t demand_artifact_staged { };
    std::uint64_t demand_artifact_consumed { };
    std::uint64_t profile_portable_artifact_consumed { };
    std::uint64_t ordinary_demand_artifact_consumed { };
    std::uint64_t demand_artifact_stage_unused { };
    std::uint64_t profile_imported_before_first_run { };
    std::uint64_t merge_calls { };
    std::uint64_t merge_nanoseconds { };
    std::uint64_t save_calls { };
    std::uint64_t save_nanoseconds { };
    std::uint64_t profile_save_failures { };
    std::uint64_t load_nanoseconds { };
    std::uint64_t profile_bytes { };
    std::size_t profile_object_bytes { };
    std::size_t location_vector_bytes { };
    std::size_t known_set_bucket_bytes { };
    std::size_t known_set_node_bytes { };
    std::size_t discarded_set_bucket_bytes { };
    std::size_t discarded_set_node_bytes { };
    std::size_t portable_ready_set_bucket_bytes { };
    std::size_t portable_ready_set_node_bytes { };
    std::size_t resident_bytes { };
};

struct JitTranslationProfilePrediction {
    std::vector<std::uint64_t> ordered_locations;
    std::vector<std::uint64_t> recent_locations;
};

struct JitTranslationProfilePredictionLimits {
    std::size_t activation_locations { };
    std::size_t recent_locations { };
    std::size_t historical_locations { };
};

class JitTranslationProfile {
public:
    JitTranslationProfile() = default;
    explicit JitTranslationProfile(
        std::vector<std::uint64_t> location_descriptors);

    void record(std::uint64_t location_descriptor) noexcept;
    void merge(std::span<const std::uint64_t> location_descriptors,
        std::uint64_t recorder_deduplicated = 0,
        std::uint64_t recorder_dropped_capacity = 0,
        std::size_t activation_prefix_locations = 0) noexcept;
    void discard(std::uint64_t location_descriptor) noexcept;
    [[nodiscard]] std::vector<std::uint64_t> snapshot() const;
    [[nodiscard]] JitTranslationProfilePrediction snapshot_prediction() const;
    [[nodiscard]] JitTranslationProfilePrediction snapshot_prediction(
        JitTranslationProfilePredictionLimits limits) const;
    [[nodiscard]] std::pair<std::vector<std::uint64_t>, std::size_t>
    snapshot_range(std::size_t offset, std::size_t maximum) const;
    [[nodiscard]] std::pair<std::vector<std::uint64_t>, std::size_t>
    snapshot_recent_range(std::size_t offset, std::size_t maximum) const;
    [[nodiscard]] std::pair<std::vector<std::uint64_t>, std::size_t>
    snapshot_recent_missing_portable_range(
        std::size_t offset, std::size_t maximum) const;
    [[nodiscard]] std::size_t storage_size() const noexcept;
    [[nodiscard]] std::uint64_t revision() const noexcept
    {
        return revision_.load(std::memory_order_acquire);
    }
    [[nodiscard]] JitTranslationProfileStats stats() const noexcept;

    void note_profile_loaded(std::uint64_t descriptors) noexcept;
    void note_profile_enqueued_portable(std::uint64_t count = 1) noexcept;
    void note_profile_native_enqueued(std::uint64_t count = 1) noexcept;
    void note_profile_native_attempted() noexcept;
    void note_profile_native_executed() noexcept;
    void note_profile_portable_attempted() noexcept;
    void note_profile_portable_executed() noexcept;
    void note_portable_existence_hit() noexcept;
    void note_profile_portable_generated() noexcept;
    void note_profile_portable_artifact_ready(
        std::uint64_t location_descriptor) noexcept;
    void note_native_preimport_attempted() noexcept;
    void note_native_preimport_before_first_demand() noexcept;
    void note_native_preimport_imported() noexcept;
    void note_native_preimport_already_present() noexcept;
    void note_native_preimport_used(
        std::uint64_t first_use_distance = 0U) noexcept;
    void note_demand_artifact_staged() noexcept;
    void note_demand_artifact_consumed() noexcept;
    [[nodiscard]] bool consume_profile_portable_artifact(
        std::uint64_t location_descriptor) noexcept;
    void note_ordinary_demand_artifact_consumed() noexcept;
    void note_demand_artifact_stage_unused() noexcept;
    void note_profile_imported_before_first_run() noexcept;
    void note_unstable_dropped(std::uint64_t count = 1) noexcept;
    void note_save(std::uint64_t nanoseconds, std::uint64_t bytes) noexcept;
    void note_save_failure() noexcept;
    void note_profile_bytes(std::uint64_t bytes) noexcept;
    void note_load(std::uint64_t nanoseconds) noexcept;

private:
    mutable std::mutex mutex_;
    std::vector<std::uint64_t> locations_;
    std::unordered_set<std::uint64_t> known_locations_;
    std::unordered_set<std::uint64_t> discarded_locations_;
    std::atomic<std::uint64_t> recorded_ { };
    std::atomic<std::uint64_t> deduplicated_ { };
    std::atomic<std::uint64_t> recorder_deduplicated_ { };
    std::atomic<std::uint64_t> recorder_dropped_capacity_ { };
    std::atomic<std::uint64_t> dropped_capacity_ { };
    std::atomic<std::uint64_t> working_set_evicted_ { };
    std::atomic<std::uint64_t> unstable_dropped_ { };
    std::atomic<std::uint64_t> profile_loaded_ { };
    std::atomic<std::uint64_t> profile_files_loaded_ { };
    std::atomic<std::uint64_t> profile_enqueued_portable_ { };
    std::atomic<std::uint64_t> profile_native_enqueued_ { };
    std::atomic<std::uint64_t> profile_native_attempted_ { };
    std::atomic<std::uint64_t> profile_native_executed_ { };
    std::atomic<std::uint64_t> profile_portable_attempted_ { };
    std::atomic<std::uint64_t> profile_portable_executed_ { };
    std::atomic<std::uint64_t> profile_portable_generated_ { };
    std::atomic<std::uint64_t> portable_existence_hits_ { };
    std::atomic<std::uint64_t> native_preimport_attempted_ { };
    std::atomic<std::uint64_t> native_preimport_imported_ { };
    std::atomic<std::uint64_t> native_preimport_already_present_ { };
    std::atomic<std::uint64_t> native_preimport_before_first_demand_ { };
    std::atomic<std::uint64_t> native_preimport_used_ { };
    std::atomic<std::uint64_t> native_preimport_first_use_distance_samples_ { };
    std::atomic<std::uint64_t> native_preimport_first_use_distance_total_ { };
    std::atomic<std::uint64_t> demand_artifact_staged_ { };
    std::atomic<std::uint64_t> demand_artifact_consumed_ { };
    std::atomic<std::uint64_t> profile_portable_artifact_consumed_ { };
    std::atomic<std::uint64_t> ordinary_demand_artifact_consumed_ { };
    std::atomic<std::uint64_t> demand_artifact_stage_unused_ { };
    std::atomic<std::uint64_t> profile_imported_before_first_run_ { };
    std::atomic<std::uint64_t> merge_calls_ { };
    std::atomic<std::uint64_t> merge_nanoseconds_ { };
    std::atomic<std::uint64_t> save_calls_ { };
    std::atomic<std::uint64_t> save_nanoseconds_ { };
    std::atomic<std::uint64_t> load_nanoseconds_ { };
    std::atomic<std::uint64_t> profile_bytes_ { };
    std::atomic<std::uint64_t> profile_save_failures_ { };
    std::atomic<std::uint64_t> revision_ { 1U };
    std::unordered_set<std::uint64_t> profile_portable_artifact_locations_;
};

class JitTranslationProfileStore {
public:
    explicit JitTranslationProfileStore(
        std::filesystem::path data_directory, bool save_enabled = true);
    ~JitTranslationProfileStore();

    JitTranslationProfileStore(const JitTranslationProfileStore&) = delete;
    JitTranslationProfileStore& operator=(
        const JitTranslationProfileStore&) = delete;

    [[nodiscard]] std::shared_ptr<JitTranslationProfile> profile_for(
        const ContentIdentity& executable_identity, bool load_from_disk = true);
    void save() noexcept;
    [[nodiscard]] JitTranslationProfileStats stats() const noexcept;

private:
    std::filesystem::path data_directory_;
    std::map<ContentIdentity, std::shared_ptr<JitTranslationProfile>> profiles_;
    std::map<ContentIdentity, std::uint64_t> profile_access_order_;
    std::map<ContentIdentity, std::size_t> known_profile_bytes_;
    std::uint64_t next_access_order_ { 1 };
    std::size_t known_storage_bytes_ { };
    std::uint64_t profile_loads_ { };
    std::uint64_t profile_save_failures_ { };
    bool save_enabled_ { true };
};

}
