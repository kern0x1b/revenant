// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Store, identify and manage reusable portable and native JIT
// artifacts.

#pragma once

#include <algorithm>
#include <array>
#include <atomic>
#include <condition_variable>
#include <cstddef>
#include <cstdint>
#include <deque>
#include <filesystem>
#include <functional>
#include <limits>
#include <list>
#include <memory>
#include <mutex>
#include <optional>
#include <thread>
#include <unordered_map>
#include <vector>

#include "foundation/arm_cpu_model.hpp"
#include "foundation/content_identity.hpp"

namespace Dynarmic::A32 {
class NativeCodeSlab;
}

namespace Dynarmic::IR {
class Block;
}

namespace emulator {

enum class JitHostIsa : std::uint8_t {
    Unknown,
    X86_64,
    Arm64,
};

enum class JitArtifactRetention : std::uint8_t {
    Normal,
    BootWorkingSet,
};

enum class JitArtifactValidationRejection : std::uint8_t {
    Unavailable,
    NoExactArtifact,
    EmptyIr,
    DependencyMismatch,
    DeserializeFailed,
    DescriptorMismatch,
    Exception,
    Count,
};

inline constexpr auto jit_artifact_validation_rejection_count =
    static_cast<std::size_t>(JitArtifactValidationRejection::Count);

struct JitArtifactKey {
    PortableExecutableIdentity content_identity;
    PortableLayoutIdentity layout_identity;
    std::uint32_t guest_pc { };
    bool thumb { };
    std::uint64_t location_descriptor { };
    ArmArchitectureVersion architecture { ArmArchitectureVersion::Armv6K };
    ArmCpuModelKind cpu_model { ArmCpuModelKind::Arm1176JzfS };
    std::uint32_t timing_model_version { };
    std::uint32_t guest_ticks_per_second { };
    std::uint32_t image_slide { };
    std::uint32_t hle_abi_version { };
    std::uint32_t backend_abi_version { };
    std::uint64_t dynarmic_build_fingerprint { };
    std::uint64_t codegen_options { };
    JitHostIsa host_isa { JitHostIsa::Unknown };
    std::uint64_t host_feature_mask { };
    std::uint32_t artifact_format_version { };

    friend bool operator==(
        const JitArtifactKey&, const JitArtifactKey&) = default;
};

struct JitArtifactKeyHash {
    [[nodiscard]] std::size_t operator()(
        const JitArtifactKey& key) const noexcept;
};

struct JitCodeDependency {
    std::uint32_t address { };
    std::uint32_t size { };
    PortableExecutableIdentity content_identity;
    PortableLayoutIdentity layout_identity;
};

struct JitConstantDependency {
    std::uint32_t address { };
    std::uint32_t size { };
    std::uint64_t value { };
    PortableExecutableIdentity content_identity;
    PortableLayoutIdentity layout_identity;
};

struct JitArtifactData {
    std::vector<std::byte> normalized_ir;
    std::vector<std::uint64_t> relocation_targets;
    std::vector<std::uint64_t> exit_locations;
    std::uint32_t instruction_count { };
    std::uint64_t translation_nanoseconds { };
    std::vector<JitCodeDependency> code_dependencies;
    std::vector<JitConstantDependency> constant_dependencies;
};

struct JitArtifactLimits {
    std::size_t resident_bytes { 64U * 1024U * 1024U };
    std::size_t persistence_bytes { };
    bool persistence_enabled { true };
    std::uintmax_t minimum_free_bytes { };
    std::size_t compaction_bytes { 64U * 1024U * 1024U };
    std::size_t writeback_bytes { 16U * 1024U * 1024U };
    std::size_t startup_prefetch_entries { 256U };
    std::size_t startup_prefetch_bytes { 8U * 1024U * 1024U };
};

struct JitArtifactStoreStats {
    std::uint64_t lookups { };
    std::uint64_t memory_hits { };
    std::uint64_t disk_hits { };
    std::uint64_t disk_hit_key_fingerprint_count { };
    std::array<std::uint64_t, 16> disk_hit_key_fingerprints { };
    std::uint64_t disk_read_retries { };
    std::uint64_t disk_read_waits { };
    std::uint64_t misses { };
    std::uint64_t publish_calls { };
    std::uint64_t deduplicated_publishes { };
    std::uint64_t disk_records_indexed { };
    std::uint64_t index_bytes { };
    std::uint64_t startup_payloads_prefetched { };
    std::uint64_t startup_prefetch_bytes { };
    std::uint64_t hotset_candidates { };
    std::uint64_t hotset_selected { };
    std::uint64_t hotset_skipped_byte_limit { };
    std::uint64_t prefetched_useful { };
    std::uint64_t prefetched_unused { };
    std::uint64_t saved_translation_nanoseconds { };
    std::uint64_t validation_successes { };
    std::uint64_t staged { };
    std::uint64_t native_imported { };
    std::uint64_t already_present { };
    std::uint64_t demand_native_emitted { };
    std::uint64_t demand_emit_failed { };
    std::uint64_t demand_consumed { };
    std::uint64_t staged_unused { };
    std::uint64_t duplicate_consumptions { };
    std::uint64_t unique_stage_attempts { };
    std::uint64_t negative_probe_hits { };
    std::uint64_t generation_retries { };
    std::uint64_t transient_retries { };
    std::uint64_t probe_fingerprint_hits { };
    std::uint64_t probe_fingerprint_collisions { };
    std::uint64_t probe_evictions { };
    std::uint64_t probe_table_entries { };
    std::uint64_t probe_table_peak_entries { };
    std::uint64_t memory_published_lookups { };
    std::uint64_t disk_demand_lookups { };
    std::uint64_t disk_prefetched_lookups { };
    std::uint64_t load_cost_nanoseconds { };
    std::int64_t net_benefit_nanoseconds { };
    std::uint64_t demand_payload_disk_loads { };
    std::uint64_t demand_deserialization_nanoseconds { };
    std::uint64_t background_prepare_requests { };
    std::uint64_t background_prepare_deduplicated { };
    std::uint64_t background_prepare_rejected { };
    std::uint64_t background_prepare_completed { };
    std::uint64_t background_prepare_failed { };
    std::uint64_t background_prepare_unused { };
    std::uint64_t background_prepare_queue_entries { };
    std::uint64_t background_prepare_queue_peak_entries { };
    std::uint64_t background_prepared_entries { };
    std::uint64_t background_prepared_peak_entries { };
    std::uint64_t background_ir_deserialization_nanoseconds { };
    std::uint64_t initialization_nanoseconds { };
    std::uint64_t admission_attempts { };
    std::uint64_t admission_rejected { };
    std::uint64_t admission_positive { };
    std::uint64_t admission_low_confidence { };
    std::uint64_t admission_estimated_load_nanoseconds { };
    std::uint64_t admission_estimated_saved_nanoseconds { };
    std::uint64_t finalizations { };
    std::uint64_t finalization_failures { };
    std::uint64_t disk_loaded_entries { };
    std::uint64_t evictions { };
    std::uint64_t payload_evictions { };
    std::uint64_t compactions { };
    std::uint64_t quota_evictions { };
    std::uint64_t boot_working_set_artifacts { };
    std::uint64_t writeback_enqueued { };
    std::uint64_t writeback_saved { };
    std::uint64_t writeback_dropped { };
    std::uint64_t writeback_failures { };
    std::uint64_t writeback_cancellations { };
    std::array<std::uint64_t, jit_artifact_validation_rejection_count>
        validation_rejections { };
    std::size_t resident_bytes { };
    std::size_t writeback_pending_bytes { };
    std::uintmax_t disk_bytes { };
};

enum class JitArtifactBackgroundPrepareResult : std::uint8_t {
    Ready,
    Queued,
    Pending,
    ExactMiss,
    Unavailable,
};

enum class JitDemandArtifactStageResult : std::uint8_t {
    Staged,
    ExactMiss,
    PermanentValidationFailure,
    TransientFailure,
};

class JitDemandArtifactTransientBackoff {
public:
    [[nodiscard]] bool retry_due(
        std::uint64_t attempt_generation) const noexcept
    {
        return attempt_generation >= next_attempt_generation_;
    }

    void record_failure(std::uint64_t attempt_generation) noexcept
    {
        retry_count_ = static_cast<std::uint8_t>(
            std::min<unsigned>(static_cast<unsigned>(retry_count_) + 1U, 7U));
        const auto delay = std::uint64_t { 1 }
                           << std::min<unsigned>(retry_count_ - 1U, 6U);
        next_attempt_generation_ =
            attempt_generation >
                    std::numeric_limits<std::uint64_t>::max() - delay
                ? std::numeric_limits<std::uint64_t>::max()
                : attempt_generation + delay;
    }

    void reset() noexcept
    {
        retry_count_ = 0U;
        next_attempt_generation_ = 0U;
    }

    [[nodiscard]] std::uint8_t retry_count() const noexcept
    {
        return retry_count_;
    }

private:
    std::uint64_t next_attempt_generation_ { };
    std::uint8_t retry_count_ { };
};

struct BlockArtifact {
    JitArtifactKey key;
    JitArtifactData data;
};

enum class JitArtifactLookupProvenance : std::uint8_t {
    MemoryPublished,
    DiskDemand,
    DiskPrefetched,
};

struct JitArtifactLookupToken {
    std::atomic<std::uint8_t> state { };
};

struct JitArtifactLookup {
    std::shared_ptr<const BlockArtifact> artifact;
    JitArtifactLookupProvenance provenance {
        JitArtifactLookupProvenance::MemoryPublished
    };
    std::shared_ptr<JitArtifactLookupToken> token;
    bool transient_failure { };

    [[nodiscard]] explicit operator bool() const noexcept
    {
        return artifact != nullptr;
    }
};

struct JitArtifactPreparedLookup {
    JitArtifactLookup lookup;
    std::shared_ptr<Dynarmic::IR::Block> block;
    std::uint64_t preparation_nanoseconds { };
    JitDemandArtifactStageResult result {
        JitDemandArtifactStageResult::TransientFailure
    };
    JitArtifactValidationRejection rejection {
        JitArtifactValidationRejection::Exception
    };

    [[nodiscard]] explicit operator bool() const noexcept
    {
        return lookup && block != nullptr;
    }
};

struct JitArtifactCompactionResult {
    bool completed { };
    bool cancelled { };
    bool failed { };
    bool temporary_cleanup { };
    bool temporary_cleanup_attempted { };
    bool temporary_cleanup_succeeded { };
    bool temporary_cleanup_failed { };
    bool temporary_residue_found { };
    std::uint64_t temporary_cleanup_attempts { };
    std::uint64_t temporary_cleanup_successes { };
    std::uint64_t temporary_cleanup_failures { };
    std::uint64_t temporary_residues { };
    std::uint64_t lock_wait_nanoseconds { };
    std::uint64_t snapshot_nanoseconds { };
    std::uint64_t save_nanoseconds { };
    std::uint64_t cleanup_nanoseconds { };
    std::uint64_t rename_nanoseconds { };
    std::uint64_t return_nanoseconds { };
    std::uint64_t first_cancellation_observed_nanoseconds { };
    std::uint64_t bytes_before_cancel { };
    std::uint64_t records_before_cancel { };
};

class JitArtifactStore {
public:
    using CancellationCheck = std::function<bool()>;

    explicit JitArtifactStore(std::filesystem::path persistence_path = { },
        JitArtifactLimits limits = { });
    ~JitArtifactStore();

    JitArtifactStore(const JitArtifactStore&) = delete;
    JitArtifactStore& operator=(const JitArtifactStore&) = delete;

    [[nodiscard]] JitArtifactLookup lookup(const JitArtifactKey& key,
        JitArtifactRetention retention = JitArtifactRetention::Normal,
        bool allow_disk_payload = true) const;
    [[nodiscard]] JitArtifactBackgroundPrepareResult request_background_prepare(
        const JitArtifactKey& key,
        JitArtifactRetention retention =
            JitArtifactRetention::Normal) const noexcept;
    [[nodiscard]] std::optional<JitArtifactPreparedLookup>
    take_background_prepared(const JitArtifactKey& key) const noexcept;
    [[nodiscard]] std::shared_ptr<const BlockArtifact> find(
        const JitArtifactKey& key,
        JitArtifactRetention retention = JitArtifactRetention::Normal) const;
    void record_validation_success() const noexcept;
    void record_staged(const JitArtifactLookup& lookup) const noexcept;
    void record_native_imported(const JitArtifactLookup& lookup) const noexcept;
    void record_already_present(const JitArtifactLookup& lookup) const noexcept;
    void record_demand_native_emitted() const noexcept;
    void record_demand_emit_failed() const noexcept;
    void record_demand_consumed(const JitArtifactLookup& lookup) const noexcept;
    void record_staged_unused(const JitArtifactLookup& lookup) const noexcept;
    void record_demand_stage_attempt() const noexcept;
    void record_demand_negative_probe_hit() const noexcept;
    void record_demand_generation_retry() const noexcept;
    void record_demand_transient_retry() const noexcept;
    void record_demand_probe_fingerprint_hit() const noexcept;
    void record_demand_probe_fingerprint_collision() const noexcept;
    void record_demand_probe_eviction() const noexcept;
    void record_demand_probe_size(std::size_t entries) const noexcept;
    [[nodiscard]] bool admit_demand_artifact(
        std::uint64_t estimated_load_nanoseconds,
        std::uint64_t estimated_saved_nanoseconds,
        std::uint8_t confidence) const noexcept;
    [[nodiscard]] std::shared_ptr<const BlockArtifact> publish(
        JitArtifactKey key, JitArtifactData data,
        JitArtifactRetention retention = JitArtifactRetention::Normal);
    [[nodiscard]] std::size_t size() const;
    [[nodiscard]] JitArtifactStoreStats stats() const;
    [[nodiscard]] std::uint64_t publication_generation() const noexcept;
    void record_validation_rejection(
        JitArtifactValidationRejection rejection) const noexcept;
    std::size_t trim_resident_bytes(std::size_t target_bytes) noexcept;
    void cancel_writeback() noexcept;
    [[nodiscard]] bool compaction_needed() const noexcept;
    [[nodiscard]] JitArtifactCompactionResult compact_with_result(
        CancellationCheck cancellation_check) const noexcept;
    [[nodiscard]] bool compact() const noexcept;
    [[nodiscard]] bool compact(
        CancellationCheck cancellation_check) const noexcept;

    [[nodiscard]] bool load(const std::filesystem::path& path) noexcept;
    [[nodiscard]] bool save() const noexcept;
    [[nodiscard]] bool save(const std::filesystem::path& path) const noexcept;
    [[nodiscard]] bool finalize() const noexcept;

private:
    struct DiskArtifactRecord {
        std::uint64_t offset { };
        std::uint64_t serialized_bytes { };
        bool append_log { };
        ContentIdentity checksum;
        bool checksum_valid { };
        std::uint64_t generation { };
        std::uint64_t benefit_generation { };
        std::uint64_t benefit_hits { };
        std::uint64_t translation_nanoseconds { };
        bool boot_working_set { };
    };
    struct ArtifactRecord {
        std::shared_ptr<const BlockArtifact> artifact;
        std::size_t serialized_bytes { };
        std::list<const JitArtifactKey*>::iterator lru_position;
        bool loaded_from_disk { };
        bool startup_prefetched { };
        bool startup_prefetch_used { };
        std::uint64_t benefit_generation { };
        std::uint64_t benefit_hits { };
        bool boot_working_set { };
    };
    struct PendingWriteback {
        std::shared_ptr<const BlockArtifact> artifact;
        std::size_t serialized_bytes { };
        std::list<const JitArtifactKey*>::iterator queue_position;
        std::uint64_t benefit_generation { };
        std::uint64_t benefit_hits { };
        bool boot_working_set { };
    };
    struct DiskReadFlight {
        std::condition_variable condition;
        std::shared_ptr<const BlockArtifact> artifact;
        bool complete { };
        bool disk_hit { };
        bool transient_failure { };
    };
    struct BackgroundPreparedRecord {
        JitArtifactPreparedLookup prepared;
        std::list<JitArtifactKey>::iterator order_position;
    };
    struct HotsetCandidate {
        JitArtifactKey key;
        std::uint64_t benefit_generation { };
        std::uint64_t benefit_hits { };
        std::uint64_t translation_nanoseconds { };
    };
    struct HotsetSnapshot {
        std::vector<HotsetCandidate> candidates;
        ContentIdentity snapshot_id;
        std::uint64_t disk_index_generation { };
        std::uint64_t benefit_generation { };
        std::uint64_t mutation_generation { };
    };
    struct JitArtifactKeyPointerHash {
        using is_transparent = void;
        [[nodiscard]] std::size_t operator()(
            const JitArtifactKey* key) const noexcept
        {
            return JitArtifactKeyHash { }(*key);
        }
        [[nodiscard]] std::size_t operator()(
            const JitArtifactKey& key) const noexcept
        {
            return JitArtifactKeyHash { }(key);
        }
    };
    struct JitArtifactKeyPointerEqual {
        using is_transparent = void;
        [[nodiscard]] bool operator()(const JitArtifactKey* left,
            const JitArtifactKey* right) const noexcept
        {
            return *left == *right;
        }
        [[nodiscard]] bool operator()(const JitArtifactKey* left,
            const JitArtifactKey& right) const noexcept
        {
            return *left == right;
        }
        [[nodiscard]] bool operator()(const JitArtifactKey& left,
            const JitArtifactKey* right) const noexcept
        {
            return left == *right;
        }
    };
    using ArtifactMap = std::unordered_map<const JitArtifactKey*,
        ArtifactRecord, JitArtifactKeyPointerHash, JitArtifactKeyPointerEqual>;
    using DiskArtifactMap = std::unordered_map<JitArtifactKey,
        DiskArtifactRecord, JitArtifactKeyHash>;
    using PendingWritebackMap =
        std::unordered_map<const JitArtifactKey*, PendingWriteback,
            JitArtifactKeyPointerHash, JitArtifactKeyPointerEqual>;
    using DiskReadFlightMap = std::unordered_map<JitArtifactKey,
        std::shared_ptr<DiskReadFlight>, JitArtifactKeyHash>;
    enum class AppendResult : std::uint8_t {
        NotApplicable,
        Saved,
        Failed,
    };

    void touch_locked(ArtifactMap::iterator iterator) const;
    [[nodiscard]] std::uint64_t next_disk_generation_locked() const noexcept;
    [[nodiscard]] std::uint64_t next_benefit_generation_locked() const noexcept;
    void note_artifact_consumed_locked(
        const JitArtifactLookup& lookup) const noexcept;
    void mark_hotset_dirty_locked() const noexcept;
    [[nodiscard]] std::optional<HotsetSnapshot> hotset_snapshot_locked() const;
    void promote_retention_locked(
        const JitArtifactKey& key, JitArtifactRetention retention) const;
    void promote_resident_retention_locked(
        ArtifactMap::iterator iterator) const;
    void evict_until_fit_locked(std::size_t required_bytes) const;
    void insert_locked(std::shared_ptr<const BlockArtifact> artifact,
        std::size_t serialized_bytes, bool loaded_from_disk = false,
        bool startup_prefetched = false,
        JitArtifactRetention retention = JitArtifactRetention::Normal) const;
    [[nodiscard]] bool enqueue_writeback_locked(
        const std::shared_ptr<const BlockArtifact>& artifact,
        std::size_t serialized_bytes, JitArtifactRetention retention) const;
    void retire_writeback_locked(const JitArtifactKey& key) const;
    void writeback_loop();
    void perform_background_prepare(
        JitArtifactKey key, JitArtifactRetention retention) noexcept;
    [[nodiscard]] bool append_writeback_batch(
        const std::vector<std::shared_ptr<const BlockArtifact>>& batch)
        const noexcept;
    [[nodiscard]] bool load_coordinated(
        const std::filesystem::path& path) const noexcept;
    [[nodiscard]] AppendResult append_new_artifacts(
        const std::filesystem::path& path) const noexcept;
    [[nodiscard]] bool save_full(
        const std::filesystem::path& path) const noexcept;
    [[nodiscard]] bool save_full(const std::filesystem::path& path,
        const CancellationCheck& cancellation_check) const noexcept;
    [[nodiscard]] bool save_full(const std::filesystem::path& path,
        const CancellationCheck& cancellation_check,
        JitArtifactCompactionResult* compaction_result) const noexcept;

    mutable std::mutex mutex_;
    mutable ArtifactMap artifacts_;
    mutable std::list<const JitArtifactKey*> lru_;
    mutable std::list<const JitArtifactKey*>::iterator boot_lru_begin_;
    mutable PendingWritebackMap pending_writebacks_;
    mutable std::list<const JitArtifactKey*> writeback_order_;
    mutable DiskReadFlightMap disk_read_flights_;
    mutable DiskArtifactMap disk_artifacts_;
    mutable std::unordered_map<JitArtifactKey, JitArtifactRetention,
        JitArtifactKeyHash>
        background_prepare_pending_;
    mutable std::deque<JitArtifactKey> background_prepare_queue_;
    mutable std::unordered_map<JitArtifactKey, BackgroundPreparedRecord,
        JitArtifactKeyHash>
        background_prepared_;
    mutable std::list<JitArtifactKey> background_prepared_order_;
    mutable std::vector<const JitArtifactKey*> disk_order_;
    JitArtifactLimits limits_;
    mutable std::size_t resident_bytes_ { };
    mutable std::size_t pending_writeback_bytes_ { };
    std::filesystem::path persistence_path_;
    mutable std::filesystem::path disk_source_path_;
    mutable std::filesystem::path disk_append_path_;
    mutable std::uint64_t disk_append_valid_bytes_ { };
    mutable bool disk_append_indexed_ { true };
    mutable std::uint64_t disk_index_generation_ { };
    mutable std::uint64_t benefit_generation_ { };
    mutable std::uint64_t external_writer_generation_ { };
    mutable ContentIdentity disk_snapshot_id_;
    mutable bool hotset_dirty_ { };
    mutable std::uint64_t hotset_mutation_generation_ { };
    mutable std::mutex persistence_mutex_;
    mutable std::condition_variable writeback_condition_;
    mutable bool writeback_stopping_ { };
    mutable bool writeback_disabled_ { };
    mutable bool background_worker_started_ { };
    mutable std::atomic<bool> writeback_cancel_requested_ { };
    mutable std::atomic<std::uint64_t> publication_generation_ { };
    mutable std::atomic<std::uint64_t> unique_stage_attempts_ { };
    mutable std::atomic<std::uint64_t> negative_probe_hits_ { };
    mutable std::atomic<std::uint64_t> generation_retries_ { };
    mutable std::atomic<std::uint64_t> transient_retries_ { };
    std::thread writeback_thread_;
    mutable JitArtifactStoreStats stats_;
};

struct ImageCodeRegion {
    std::string identity;
    std::uint32_t begin { };
    std::uint32_t end { };
    std::size_t cache_bytes { };
    std::uint32_t second_begin { };
    std::uint32_t second_end { };
};

void set_machine_image_code_region(ImageCodeRegion region);
[[nodiscard]] ImageCodeRegion machine_image_code_region();
[[nodiscard]] Dynarmic::A32::NativeCodeSlab* machine_image_code_slab();
void service_machine_image_code_slab();
class ExecutionContext;
[[nodiscard]] Dynarmic::A32::NativeCodeSlab* machine_image_code_slab_for(
    const ExecutionContext& context);

class ExecutionContext {
public:
    ExecutionContext();
    explicit ExecutionContext(std::uint32_t process_id);
    ~ExecutionContext();

    ExecutionContext(const ExecutionContext&) = delete;
    ExecutionContext& operator=(const ExecutionContext&) = delete;

    [[nodiscard]] std::uint64_t context_id() const noexcept
    {
        return context_id_;
    }
    [[nodiscard]] std::uint32_t process_id() const noexcept
    {
        return process_id_.load(std::memory_order_acquire);
    }

    void bind_process_id(std::uint32_t process_id);
    [[nodiscard]] std::size_t create_link_cell();
    void link(std::size_t cell, std::uint64_t target_token);
    void unlink(std::size_t cell);
    [[nodiscard]] std::uint64_t linked_target(std::size_t cell) const;
    [[nodiscard]] std::atomic<std::uint64_t>* link_cell_address(
        std::size_t cell) const;
    [[nodiscard]] Dynarmic::A32::NativeCodeSlab*
    native_code_slab() const noexcept;

    [[nodiscard]] std::uint64_t request_cache_clear();
    [[nodiscard]] std::uint64_t request_cache_range(
        std::uint32_t address, std::size_t length);
    [[nodiscard]] std::uint64_t cache_invalidation_epoch() const noexcept
    {
        return cache_invalidation_epoch_.load(std::memory_order_acquire);
    }
    [[nodiscard]] std::uint64_t cache_clear_epoch() const noexcept
    {
        return cache_clear_epoch_.load(std::memory_order_acquire);
    }
    [[nodiscard]] bool image_private() const noexcept
    {
        return image_private_.load(std::memory_order_acquire);
    }
    [[nodiscard]] bool observe_slab_generation(
        std::uint64_t generation) noexcept;
    [[nodiscard]] std::uint64_t observed_slab_generation() const noexcept
    {
        return observed_slab_generation_.load(std::memory_order_acquire);
    }

private:
    struct LinkCell {
        std::atomic<std::uint64_t> target_token { };
    };

    std::uint64_t context_id_ { };
    std::atomic<std::uint32_t> process_id_ { };
    std::shared_ptr<Dynarmic::A32::NativeCodeSlab> native_code_slab_;
    mutable std::mutex mutex_;
    bool process_id_bound_ { };
    std::atomic<std::uint64_t> cache_invalidation_epoch_ { };
    std::atomic<std::uint64_t> cache_clear_epoch_ { };
    std::atomic<bool> image_private_ { false };
    std::atomic<std::uint64_t> observed_slab_generation_ { };
    mutable std::mutex invalidation_mutex_;
    std::vector<std::unique_ptr<LinkCell>> link_cells_;
};

[[nodiscard]] std::string disk_hit_fingerprint_text(const JitArtifactStoreStats& stats);

}
