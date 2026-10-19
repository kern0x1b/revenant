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

namespace Umbra::A32 {
class NativeCodeSlab;
}

namespace Umbra::IR {
class Block;
}

namespace shade {

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

// Every field that can change the generated block or its calling convention
// belongs in this key. In particular, no path or mtime participates in cache
// identity.
struct JitArtifactKey {
    PortableExecutableIdentity content_identity;
    PortableLayoutIdentity layout_identity;
    std::uint32_t guest_pc { };
    bool thumb { };
    // Umbra's complete block location. guest_pc/thumb remain as readable
    // fields for diagnostics, but this value is the cache identity for all
    // CPSR/FPSCR/IT/single-step state that affects translation.
    std::uint64_t location_descriptor { };
    ArmArchitectureVersion architecture { ArmArchitectureVersion::Armv6K };
    ArmCpuModelKind cpu_model { ArmCpuModelKind::Arm1176JzfS };
    std::uint32_t timing_model_version { };
    std::uint32_t guest_ticks_per_second { };
    std::uint32_t image_slide { };
    std::uint32_t hle_abi_version { };
    std::uint32_t backend_abi_version { };
    std::uint64_t umbra_build_fingerprint { };
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
    // This is a normalized, portable representation. It is deliberately not a
    // copy of Umbra's native code cache.
    std::vector<std::byte> normalized_ir;
    std::vector<std::uint64_t> relocation_targets;
    std::vector<std::uint64_t> exit_locations;
    std::uint32_t instruction_count { };
    // Translation timing is advisory metadata. It is useful for deciding
    // whether an entry was produced by a real translation rather than a
    // speculative profile hint, but it does not participate in executable
    // artifact identity.
    std::uint64_t translation_nanoseconds { };
    // Every executable page observed by Umbra while translating the block.
    // Empty dependencies are not importable by the CPU integration.
    std::vector<JitCodeDependency> code_dependencies;
    // Read-only values folded by Umbra's constant-memory pass.
    std::vector<JitConstantDependency> constant_dependencies;
};

struct JitArtifactLimits {
    // Zero means unbounded. The default resident target matches the initial
    // metadata budget; native code is still owned by Umbra's live cache.
    std::size_t resident_bytes { 64U * 1024U * 1024U };
    std::size_t persistence_bytes { };
    // A disabled persistence store is a successful no-op on save and a cache
    // miss on load. This lets the host disable optional storage under pressure
    // without affecting Guest execution.
    bool persistence_enabled { true };
    // Zero disables the filesystem free-space safety check.
    std::uintmax_t minimum_free_bytes { };
    // A journal at or above this size is eligible for low-priority compaction.
    // Zero disables automatic compaction.
    std::size_t compaction_bytes { 64U * 1024U * 1024U };
    // Newly translated artifacts enter this bounded queue before the resident
    // LRU can evict them. Zero disables asynchronous writeback.
    std::size_t writeback_bytes { 16U * 1024U * 1024U };
    // Only persisted boot-working-set marks are eligible for startup payload
    // prefetch. Both limits are hard caps so a seed cannot turn index startup
    // back into an unbounded payload load.
    std::size_t startup_prefetch_entries { 256U };
    std::size_t startup_prefetch_bytes { 8U * 1024U * 1024U };
};

struct JitArtifactStoreStats {
    std::uint64_t lookups { };
    std::uint64_t memory_hits { };
    std::uint64_t disk_hits { };
    // Bounded, optional diagnostic breadcrumbs for reproducing a seeded hit.
    // These are only populated for the first few hits and do not affect lookup
    // admission or identity validation.
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

// Executor-local retry state. The caller supplies a monotonically increasing
// slice/attempt generation, so transient recovery never requires a clock read
// or store access on a suppressed slice.
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
    std::shared_ptr<Umbra::IR::Block> block;
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
    // Guest execution only submits and polls this bounded queue. The existing
    // low-priority persistence worker performs payload I/O and IR
    // deserialization, then publishes a one-shot prepared block for a later
    // executor safe boundary.
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
    // Benefit-driven admission for runtime demand artifacts. The caller has
    // already validated the payload; this method only records the estimate and
    // rejects entries whose predicted saved translation cannot pay for loading.
    [[nodiscard]] bool admit_demand_artifact(
        std::uint64_t estimated_load_nanoseconds,
        std::uint64_t estimated_saved_nanoseconds,
        std::uint8_t confidence) const noexcept;
    [[nodiscard]] std::shared_ptr<const BlockArtifact> publish(
        JitArtifactKey key, JitArtifactData data,
        JitArtifactRetention retention = JitArtifactRetention::Normal);
    [[nodiscard]] std::size_t size() const;
    [[nodiscard]] JitArtifactStoreStats stats() const;
    // Changes whenever a new artifact becomes available to runtime lookups.
    // Executors use this to retry a previously negative probe without polling
    // the store on every CPU slice.
    [[nodiscard]] std::uint64_t publication_generation() const noexcept;
    void record_validation_rejection(
        JitArtifactValidationRejection rejection) const noexcept;
    // Pressure reclamation removes only non-boot artifacts that have no
    // external users. It never changes artifact validity or Guest execution;
    // later runtime lookup simply falls back to the disk record or demand JIT.
    std::size_t trim_resident_bytes(std::size_t target_bytes) noexcept;
    // Stops optional background persistence and releases queued artifacts.
    // Guest execution and resident-cache lookups remain available.
    void cancel_writeback() noexcept;
    [[nodiscard]] bool compaction_needed() const noexcept;
    [[nodiscard]] JitArtifactCompactionResult compact_with_result(
        CancellationCheck cancellation_check) const noexcept;
    [[nodiscard]] bool compact() const noexcept;
    [[nodiscard]] bool compact(
        CancellationCheck cancellation_check) const noexcept;

    // Persistence is metadata-only. Initial snapshots carry an authenticated
    // tail index and per-record checksums; incremental publications use a
    // journal of authenticated compact indexes with per-record checksums.
    // Loading malformed data leaves the existing store unchanged and lets
    // execution fall back to JIT.
    [[nodiscard]] bool load(const std::filesystem::path& path) noexcept;
    [[nodiscard]] bool save() const noexcept;
    [[nodiscard]] bool save(const std::filesystem::path& path) const noexcept;
    // Force a complete authenticated snapshot. Unlike save(), this never
    // leaves a newly prepared seed dependent on an append journal.
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
    // Pointer-keyed resident and pending metadata is anchored by the immutable
    // artifact shared_ptr in each value. Their order lists borrow the same key.
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
    // unordered_map rehash preserves element addresses; wholesale index swaps
    // always install the matching pointer order while holding mutex_.
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

// Per-process mutable execution state. CPU registers, AddressSpace and HLE
// tables remain owned by their existing runtime objects; this class only
// supplies context identity and writable link cells for immutable artifacts.
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

    // A CpuExecutionPool is created before the guest task receives its PID.
    // Bind that metadata exactly once without replacing the context or any
    // stable link-cell addresses already handed to executors.
    void bind_process_id(std::uint32_t process_id);
    [[nodiscard]] std::size_t create_link_cell();
    void link(std::size_t cell, std::uint64_t target_token);
    void unlink(std::size_t cell);
    [[nodiscard]] std::uint64_t linked_target(std::size_t cell) const;
    [[nodiscard]] std::atomic<std::uint64_t>* link_cell_address(
        std::size_t cell) const;
    [[nodiscard]] Umbra::A32::NativeCodeSlab*
    native_code_slab() const noexcept;

    // Guest address-space changes are published once per process context. The
    // slab owns the actual generation transition; this epoch lets each
    // executor retire its private artifact probes at its next safe boundary.
    [[nodiscard]] std::uint64_t request_cache_clear();
    [[nodiscard]] std::uint64_t request_cache_range(
        std::uint32_t address, std::size_t length);
    [[nodiscard]] std::uint64_t cache_invalidation_epoch() const noexcept
    {
        return cache_invalidation_epoch_.load(std::memory_order_acquire);
    }
    // Range invalidations retire only overlapping native blocks. Prediction
    // plans use this narrower epoch so one local executable-page change does
    // not restart a complete process-image scan.
    [[nodiscard]] std::uint64_t cache_clear_epoch() const noexcept
    {
        return cache_clear_epoch_.load(std::memory_order_acquire);
    }
    // Returns true exactly once for each observed post-initial slab generation.
    // Executors may call this concurrently; the shared context owns the
    // observation so metrics are not multiplied by executor count.
    [[nodiscard]] bool observe_slab_generation(
        std::uint64_t generation) noexcept;
    // The last generation observed at a safe executor boundary. Unlike the
    // Umbra NativeCodeSlab::generation() query, this snapshot never waits
    // for an outstanding invalidation to finish.
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
    std::shared_ptr<Umbra::A32::NativeCodeSlab> native_code_slab_;
    mutable std::mutex mutex_;
    bool process_id_bound_ { };
    std::atomic<std::uint64_t> cache_invalidation_epoch_ { };
    std::atomic<std::uint64_t> cache_clear_epoch_ { };
    std::atomic<std::uint64_t> observed_slab_generation_ { };
    mutable std::mutex invalidation_mutex_;
    std::vector<std::unique_ptr<LinkCell>> link_cells_;
};

[[nodiscard]] std::string disk_hit_fingerprint_text(const JitArtifactStoreStats& stats);

} // namespace shade
