// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Cache file-backed guest pages while tracking host-file generations
// and writeback identity.

#pragma once

#include <array>
#include <atomic>
#include <compare>
#include <cstddef>
#include <cstdint>
#include <deque>
#include <filesystem>
#include <list>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <span>
#include <string>
#include <utility>
#include <vector>

#include "foundation/content_identity.hpp"

namespace shade {

inline constexpr std::uint32_t guest_memory_page_size = 4096;
inline constexpr std::uint32_t guest_exclusive_granule_size = 64;
inline constexpr std::size_t guest_file_prefetch_pages = 32;
using GuestPageBytes = std::array<std::byte, guest_memory_page_size>;

// Runtime-only identity of the host file object and metadata generation
// observed while its descriptor was opened. ContentIdentity alone is
// insufficient: an atomic replacement can preserve bytes while changing the
// vnode that a shared mapping must write back to. This type must never be
// folded into PortableExecutableIdentity or PortableLayoutIdentity.
struct RuntimeBackingGeneration {
    std::uint64_t device { };
    std::uint64_t inode { };
    std::uint64_t file_size { };
    std::int64_t modified_seconds { };
    std::int64_t modified_nanoseconds { };
    std::int64_t changed_seconds { };
    std::int64_t changed_nanoseconds { };

    friend constexpr bool operator==(const RuntimeBackingGeneration&,
        const RuntimeBackingGeneration&) = default;
    friend constexpr auto operator<=>(const RuntimeBackingGeneration&,
        const RuntimeBackingGeneration&) = default;
};

// Keep the existing public spelling source-compatible while callers migrate
// to the explicit runtime-generation name.
using GuestFileGeneration = RuntimeBackingGeneration;

// Cross-process immutable backing for a validated file generation. The
// backing file is content-addressed and opened read-only, then mapped with
// MAP_SHARED so independent emulator processes fault the same host page-cache
// pages instead of allocating one heap snapshot per process. The lease keeps
// the backing pathname alive until every process using it has released its
// mapping; stale leases are reclaimed after a crashed process exits.
class ImmutableFileView {
public:
    ~ImmutableFileView();

    ImmutableFileView(const ImmutableFileView&) = delete;
    ImmutableFileView& operator=(const ImmutableFileView&) = delete;
    ImmutableFileView(ImmutableFileView&&) = delete;
    ImmutableFileView& operator=(ImmutableFileView&&) = delete;

    [[nodiscard]] static std::shared_ptr<const ImmutableFileView> open(
        const std::filesystem::path& source_path,
        const GuestFileGeneration& generation,
        const ContentIdentity& content_identity, std::uint64_t byte_size);

    [[nodiscard]] std::uint64_t size() const noexcept { return byte_size_; }
    [[nodiscard]] std::span<const std::byte> bytes() const noexcept;
    [[nodiscard]] std::span<const std::byte> range(
        std::uint64_t offset, std::uint64_t size) const noexcept;
    [[nodiscard]] const std::filesystem::path& backing_path() const noexcept
    {
        return backing_path_;
    }
    [[nodiscard]] const GuestFileGeneration& generation() const noexcept
    {
        return generation_;
    }
    [[nodiscard]] const ContentIdentity& content_identity() const noexcept
    {
        return content_identity_;
    }

private:
    ImmutableFileView(int file_descriptor, void* mapping,
        std::uint64_t byte_size, std::filesystem::path backing_path,
        std::filesystem::path lease_path, GuestFileGeneration generation,
        ContentIdentity content_identity) noexcept;

    int file_descriptor_ { -1 };
    void* mapping_ { };
    std::uint64_t byte_size_ { };
    std::filesystem::path backing_path_;
    std::filesystem::path lease_path_;
    GuestFileGeneration generation_;
    ContentIdentity content_identity_;
};

enum class GuestFileMutationKind : std::uint8_t {
    Observation,
    Write,
    Truncate,
    Rename,
    Unlink,
    SharedWriteback,
    InstallReplace,
    // Structural notifications describe a directory entry namespace change.
    // They are consumed by the executable catalog as subtree boundaries and
    // must not be filtered by the old executable-path index.
    SubtreeCreate,
    SubtreeRemove,
};

struct GuestFileGenerationSnapshot {
    std::uint64_t revision { };
    std::optional<GuestFileGeneration> generation;
    GuestFileMutationKind last_mutation { GuestFileMutationKind::Observation };
    // The watcher records the stable bytes observed for this namespace path.
    // Guest writes clear this value until a subsequent stable observation; this
    // lets a duplicate inotify event be merged without hiding a same-generation
    // external content change.
    std::optional<ContentIdentity> content_identity;
};

struct GuestFileMutationEvent {
    std::uint64_t sequence { };
    std::filesystem::path path;
    GuestFileMutationKind mutation { GuestFileMutationKind::Observation };
    // The bounded event queue overflowed.  The path is advisory; consumers
    // must rescan their own authoritative root rather than trust individual
    // events that were evicted before this marker was published.
    bool dirty_subtree { };
};

// One emulator-wide view of pathname generations. A pathname is only a lookup
// key: mappings retain their own GuestFileBacking and therefore keep an old
// vnode/generation alive after replacement or unlink. Mutations advance the
// revision even when coarse host timestamps do not change.
class GuestFileGenerationRegistry {
public:
    [[nodiscard]] GuestFileGenerationSnapshot observe(
        const std::filesystem::path& path);
    [[nodiscard]] GuestFileGenerationSnapshot publish(
        const std::filesystem::path& path, GuestFileMutationKind mutation);
    [[nodiscard]] GuestFileGenerationSnapshot publish_descriptor(
        const std::filesystem::path& path, int file_descriptor,
        GuestFileMutationKind mutation,
        std::optional<ContentIdentity> content_identity = std::nullopt);
    void publish_rename(const std::filesystem::path& source,
        const std::filesystem::path& destination);
    void publish_subtree_create(const std::filesystem::path& path);
    void publish_subtree_remove(const std::filesystem::path& path);
    void publish_subtree_rename(const std::filesystem::path& source,
        const std::filesystem::path& destination);
    // Mutation notifications are deliberately bounded and coalesced by path.
    // Consumers may drain them from the emulator's serialized control loop;
    // pathname generations remain authoritative even if a non-critical event
    // is evicted under sustained write load.
    [[nodiscard]] std::vector<GuestFileMutationEvent> take_mutations(
        std::size_t maximum_events);
    [[nodiscard]] std::size_t pending_mutation_count() const;
    [[nodiscard]] std::optional<GuestFileGenerationSnapshot> current(
        const std::filesystem::path& path) const;
    [[nodiscard]] std::size_t tracked_path_count() const;
    // Advances for every published mutation, including coalesced catalog
    // events. Readiness consumers can avoid pathname probes while unchanged.
    [[nodiscard]] std::uint64_t mutation_generation() const noexcept
    {
        return mutation_generation_.load(std::memory_order_acquire);
    }

private:
    friend class FilePageCache;

    struct Entry {
        GuestFileGenerationSnapshot snapshot;
        std::list<std::string>::iterator lru_position;
    };

    [[nodiscard]] static std::string normalize_path(
        const std::filesystem::path& path);
    [[nodiscard]] static std::optional<GuestFileGeneration> read_generation(
        const std::filesystem::path& path);
    [[nodiscard]] GuestFileGenerationSnapshot record(
        const std::filesystem::path& path,
        std::optional<GuestFileGeneration> generation,
        GuestFileMutationKind mutation, bool force_revision,
        std::optional<ContentIdentity> content_identity = std::nullopt);
    [[nodiscard]] GuestFileGenerationSnapshot observe_normalized(
        std::string normalized_path, const GuestFileGeneration& generation);
    [[nodiscard]] GuestFileGenerationSnapshot record_descriptor(
        const std::filesystem::path& path,
        const GuestFileGeneration& generation, GuestFileMutationKind mutation,
        std::optional<ContentIdentity> content_identity = std::nullopt);
    [[nodiscard]] std::map<std::string, Entry>::iterator ensure_entry_locked(
        const std::string& normalized_path);
    void touch_entry_locked(std::map<std::string, Entry>::iterator iterator);
    void erase_entry_locked(std::map<std::string, Entry>::iterator iterator);
    void erase_subtree_entries_locked(const std::string& normalized_path);
    void evict_entries_locked();
    void enqueue_mutation_locked(
        const std::string& normalized_path, GuestFileMutationKind mutation);

    mutable std::mutex mutex_;
    std::uint64_t next_revision_ { 1 };
    std::uint64_t next_mutation_sequence_ { 1 };
    std::atomic_uint64_t mutation_generation_ { 1 };
    std::map<std::string, Entry> entries_;
    std::list<std::string> entry_lru_;
    static constexpr std::size_t maximum_tracked_paths = 32U * 1024U;
    static constexpr std::size_t maximum_pending_mutations = 512;
    std::deque<GuestFileMutationEvent> pending_mutations_;
};

struct GuestFileIoState {
    ~GuestFileIoState();
    [[nodiscard]] bool synchronize();

    mutable std::mutex mutex;
    int file_descriptor { -1 };
    // A shared-file mapping keeps this descriptor open so writeback remains
    // attached to the original vnode/file object after pathname replacement.
    mutable std::map<std::uint64_t, GuestPageBytes> prefetched_pages;
};

struct GuestFileBacking {
    GuestFileBacking(std::filesystem::path file_path,
        std::uint64_t mapping_start, std::uint64_t mapping_end)
        : path(std::move(file_path))
        , io_state { std::make_shared<GuestFileIoState>() }
        , first_offset(mapping_start)
        , end_offset(mapping_end)
    {
    }

    std::filesystem::path path;
    std::string cache_path;
    std::uintmax_t file_size { };
    std::filesystem::file_time_type modified;
    GuestFileGeneration generation;
    std::uint64_t generation_revision { };
    ContentIdentity content_identity;
    // Executable loaders that already captured a validated file generation can
    // retain that immutable image for byte-lazy faults. Ordinary mmap keeps the
    // descriptor-backed path and its normal live-file semantics.
    std::shared_ptr<const std::vector<std::byte>> immutable_snapshot;
    std::shared_ptr<const ImmutableFileView> immutable_file_view;
    std::weak_ptr<GuestFileGenerationRegistry> generation_registry;
    // The descriptor is opened when the mapping is created and shared by range
    // splits. This preserves the old vnode/file object across atomic rename.
    std::shared_ptr<GuestFileIoState> io_state;
    std::uint64_t first_offset { };
    std::uint64_t end_offset { };
};

struct GuestPageBacking {
    mutable GuestPageBytes bytes { };

    GuestPageBacking();
    ~GuestPageBacking();
    GuestPageBacking(const GuestPageBacking& other);
    GuestPageBacking& operator=(const GuestPageBacking&) = delete;

    // Shared aliases use the same physical granule identity. Only writes to
    // that granule revoke it; copy-on-write starts a fresh set of identities.
    [[nodiscard]] std::uint64_t reservation_identity(
        std::uint32_t offset = 0) const noexcept;
    void invalidate_reservation_identity(std::uint32_t offset = 0,
        std::size_t size = guest_memory_page_size) noexcept;

    // File-backed mappings are materialized on first guest access. Anonymous
    // and IPC-backed pages have no source and remain ordinary byte arrays.
    void materialize() const;
    // A consumer of a shared mapping can opt its physical page into a common
    // write generation. Later aliases then retain cross-address-space dirty
    // visibility without observing or copying each individual store.
    [[nodiscard]] bool enable_shared_write_tracking();
    [[nodiscard]] bool shared_write_tracking_enabled() const;
    [[nodiscard]] static std::uint64_t shared_write_tracking_epoch();
    [[nodiscard]] std::uint64_t shared_write_generation() const;
    void mark_shared_write();
    // A firmware synchronization boundary can publish a completed range of
    // direct Guest writes once, without keeping every individual store on the
    // checked callback path.
    void publish_shared_write() noexcept;
    [[nodiscard]] bool file_backed() const;
    // Persists a MAP_SHARED page without affecting private file mappings.
    [[nodiscard]] bool flush_file();
    [[nodiscard]] std::shared_ptr<GuestFileIoState> writeback_io_state() const;

private:
    friend class FilePageCache;

    mutable std::mutex mutex_;
    mutable std::shared_ptr<GuestFileBacking> file_backing_;
    std::shared_ptr<GuestFileBacking> file_writeback_;
    std::uint64_t file_offset_ { };
    std::uint32_t file_byte_count_ { };
    std::atomic<std::uint64_t> reservation_identity_ { };
    using ReservationGranules = std::array<std::atomic<std::uint64_t>,
        guest_memory_page_size / guest_exclusive_granule_size>;
    // Most pages never participate in exclusives. Publish this lazily and
    // retain it until the physical backing dies so readers need no page lock.
    mutable std::atomic<ReservationGranules*> reservation_granules_ { };
    // Set before this page is published and never changed afterwards. This
    // avoids taking the page lock for anonymous and already-private pages.
    bool has_file_source_ { };
    std::atomic<bool> shared_write_tracking_ { };
    std::atomic<std::uint64_t> shared_write_generation_ { };
};

// Process-family cache for immutable firmware file pages. AddressSpace keeps a
// strong reference to the cache across fork, while a private write detaches the
// corresponding GuestPageBacking through its normal copy-on-write path.
struct FilePageCacheLimits {
    // Zero means unbounded. Eviction only drops the cache's reference; an
    // AddressSpace that still maps a page keeps the backing alive.
    std::size_t maximum_pages { 32U * 1024U };
    // The identity index is metadata-only. A mapping retains its immutable
    // generation and content identity independently after this entry is
    // evicted.
    std::size_t maximum_identity_entries { 32U * 1024U };
};

struct FilePageCacheStats {
    std::uint64_t identity_queries { };
    std::uint64_t sha_computations { };
    std::uint64_t sha_bytes { };
    std::uint64_t identity_hits { };
    std::uint64_t generation_invalidations { };
};

struct SharedFileIdentityResult {
    std::optional<ContentIdentity> content_identity;
    bool computed { };
};

// Process-wide content identity lookup shared by the file page cache,
// catalog, Mach-O parser, and host watcher. Hashing is single-flight per
// canonical path/generation and never runs while the global cache mutex is
// held. A missing revision means the caller has an independently stable file
// generation and the published identity is revision-agnostic.
[[nodiscard]] SharedFileIdentityResult shared_file_identity(
    const std::filesystem::path& path, int descriptor,
    const GuestFileGeneration& generation,
    std::optional<std::uint64_t> generation_revision = std::nullopt,
    bool force_recompute = false);
[[nodiscard]] SharedFileIdentityResult shared_file_identity(
    const std::filesystem::path& path,
    std::optional<std::uint64_t> generation_revision = std::nullopt);
void seed_shared_file_identity(const std::filesystem::path& path,
    const GuestFileGeneration& generation,
    const ContentIdentity& content_identity,
    std::optional<std::uint64_t> generation_revision = std::nullopt);

// Small immutable metadata artifacts use the same owner-only shared-cache
// directory as immutable file views.  The named path is deterministic across
// emulator processes; publishing is atomic and readers accept only regular,
// read-only files.  Large guest-file bytes continue to use ImmutableFileView
// and its lease/reclamation policy.
[[nodiscard]] std::filesystem::path shared_immutable_artifact_root();
[[nodiscard]] std::filesystem::path shared_immutable_artifact_named_path(
    std::string_view name);

// Read-only, lease-backed mmap for cross-process immutable metadata.  The
// mapping keeps the artifact generation alive until every typed view releases
// it; callers must not copy the returned bytes into process-local metadata
// containers.
class ImmutableArtifactView {
public:
    [[nodiscard]] static std::shared_ptr<const ImmutableArtifactView> open(
        const std::filesystem::path& path,
        std::size_t maximum_size = 256U * 1024U * 1024U);
    ~ImmutableArtifactView();

    ImmutableArtifactView(const ImmutableArtifactView&) = delete;
    ImmutableArtifactView& operator=(const ImmutableArtifactView&) = delete;

    [[nodiscard]] std::span<const std::byte> bytes() const noexcept;

private:
    ImmutableArtifactView(int descriptor, void* mapping, std::size_t byte_size,
        std::filesystem::path lease_path) noexcept;

    int descriptor_ { -1 };
    void* mapping_ { };
    std::size_t byte_size_ { };
    std::filesystem::path lease_path_;
};

[[nodiscard]] bool publish_shared_immutable_artifact(
    const std::filesystem::path& path, std::span<const std::byte> bytes);
[[nodiscard]] std::optional<std::vector<std::byte>>
read_shared_immutable_artifact(const std::filesystem::path& path,
    std::size_t maximum_size = 256U * 1024U * 1024U);

// Interns immutable Mach-O byte snapshots by content identity, host file
// generation, and parser layout tag. The bounded LRU only drops its own
// reference: mappings and page-cache entries retain the old generation until
// their shared_ptr references are gone, so a replacement can never retarget
// an existing mapping to newer bytes.
enum class ImmutableSnapshotKind : std::uint8_t {
    RuntimeHot,
    CatalogScan,
};

[[nodiscard]] std::shared_ptr<const std::vector<std::byte>>
share_immutable_snapshot(const GuestFileGeneration& generation,
    const ContentIdentity& identity,
    std::shared_ptr<const std::vector<std::byte>> snapshot,
    std::uint64_t layout_tag = 0,
    ImmutableSnapshotKind kind = ImmutableSnapshotKind::RuntimeHot);

// Returns an already-published immutable snapshot without taking ownership
// from a caller. Runtime parsers use this before allocating a second buffer
// for another view of the same file generation.
[[nodiscard]] std::shared_ptr<const std::vector<std::byte>>
find_immutable_snapshot(const GuestFileGeneration& generation,
    const ContentIdentity& identity, std::uint64_t byte_size,
    std::uint64_t layout_tag = 0,
    ImmutableSnapshotKind kind = ImmutableSnapshotKind::RuntimeHot);

struct ImmutableSnapshotStats {
    std::uint64_t entries { };
    std::uint64_t bytes { };
    std::uint64_t runtime_hot_entries { };
    std::uint64_t runtime_hot_bytes { };
    std::uint64_t catalog_scan_entries { };
    std::uint64_t catalog_scan_bytes { };
    std::uint64_t budget_bytes { };
    std::uint64_t catalog_scan_budget_bytes { };
    std::uint64_t hits { };
    std::uint64_t evictions { };
};

[[nodiscard]] ImmutableSnapshotStats immutable_snapshot_stats();

class FilePageCache {
public:
    explicit FilePageCache(FilePageCacheLimits limits = { },
        std::shared_ptr<GuestFileGenerationRegistry> generation_registry = { });

    void set_generation_registry(
        std::shared_ptr<GuestFileGenerationRegistry> generation_registry);

    // Validates a file-backed range and records the immutable identity used by
    // later page faults. No per-page objects or file contents are created here.
    [[nodiscard]] std::optional<std::shared_ptr<GuestFileBacking>> open_mapping(
        const std::filesystem::path& path, std::uint64_t file_offset,
        std::uint32_t size,
        std::optional<GuestFileGeneration> expected_generation = std::nullopt,
        std::optional<ContentIdentity> expected_content_identity = std::nullopt,
        std::shared_ptr<const std::vector<std::byte>> immutable_snapshot = { },
        std::shared_ptr<const ImmutableFileView> immutable_file_view = { },
        std::shared_ptr<const GuestFileBacking> reusable_mapping = { });

    // Creates or reuses one page for an already validated mapping. The page
    // remains byte-lazy; GuestPageBacking::materialize performs clustered I/O.
    [[nodiscard]] std::shared_ptr<GuestPageBacking> load_page(
        const std::shared_ptr<GuestFileBacking>& mapping,
        std::uint64_t file_offset, std::uint32_t byte_count);

    [[nodiscard]] std::optional<std::vector<std::shared_ptr<GuestPageBacking>>>
    load_pages(const std::filesystem::path& path, std::uint64_t file_offset,
        std::uint32_t size);

    // Host descriptor writes bypass GuestPageBacking. Reflect their completed
    // byte range into every live MAP_SHARED page for the same file object.
    [[nodiscard]] std::size_t reflect_descriptor_write(int file_descriptor,
        std::uint64_t file_offset, std::span<const std::byte> bytes);

    [[nodiscard]] std::size_t page_count() const;
    [[nodiscard]] FilePageCacheStats stats() const;

private:
    struct Identity {
        GuestFileGeneration generation;
        std::uint64_t generation_revision { };
        ContentIdentity content_identity;
        std::list<std::string>::iterator lru_position;
    };

    struct Key {
        std::string path;
        GuestFileGeneration generation;
        std::uint64_t generation_revision { };
        ContentIdentity content_identity;
        std::uint64_t file_offset { };
        std::uint32_t byte_count { };
        bool immutable_snapshot { };

        [[nodiscard]] bool operator<(const Key& other) const;
    };

    struct PageRecord {
        std::shared_ptr<GuestPageBacking> page;
        std::list<Key>::iterator lru_position;
    };

    struct MutablePageKey {
        std::uint64_t device { };
        std::uint64_t inode { };
        std::uint64_t file_offset { };

        friend constexpr auto operator<=>(
            const MutablePageKey&, const MutablePageKey&) = default;
    };

    void touch_locked(std::map<Key, PageRecord>::iterator iterator);
    void erase_path_locked(const std::string& path);
    void touch_identity_locked(
        std::map<std::string, Identity>::iterator iterator);
    void store_identity_locked(const std::string& path, Identity identity);
    void erase_identity_locked(
        std::map<std::string, Identity>::iterator iterator);
    void evict_identity_locked();
    void evict_locked();
    void prune_mutable_pages_locked();

    mutable std::mutex mutex_;
    FilePageCacheLimits limits_;
    std::shared_ptr<GuestFileGenerationRegistry> generation_registry_;
    std::map<std::string, Identity> identities_;
    std::list<std::string> identity_lru_;
    std::map<Key, PageRecord> pages_;
    std::list<Key> lru_;
    std::multimap<MutablePageKey, std::weak_ptr<GuestPageBacking>>
        mutable_pages_;
    std::size_t mutable_page_insertions_since_prune_ { };
    FilePageCacheStats stats_;
};

} // namespace shade
