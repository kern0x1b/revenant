// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Manage guest address mappings, permissions, memory access and
// executable backing identities.

#pragma once

#include <array>
#include <atomic>
#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <span>
#include <string>
#include <unordered_set>
#include <vector>

#include "foundation/file_page_cache.hpp"
#include "foundation/memory_permission.hpp"
#include "foundation/vm_map.hpp"

namespace shade {

struct MemoryFault {
    std::uint32_t address { };
    std::size_t size { };
    MemoryPermission access { MemoryPermission::None };
    std::string message;
};

struct ExecutableBackingIdentity {
    PortableExecutableIdentity content;
    PortableLayoutIdentity layout;

    friend constexpr bool operator==(const ExecutableBackingIdentity&,
        const ExecutableBackingIdentity&) = default;
};

struct AddressSpaceWriteStats {
    std::uint64_t batch_calls { };
    std::uint64_t batch_operations { };
    std::uint64_t batch_failures { };
    std::uint64_t touched_pages { };
    std::uint64_t copy_on_write_detaches { };
};

// A shared-region syscall maps several file ranges from one descriptor. Keep
// the first validated backing as a batch context so subsequent ranges reuse
// its descriptor, generation, and content identity without weakening the
// existing per-mapping validation path used by ordinary callers.
struct FileMappingBatchContext {
    std::shared_ptr<GuestFileBacking> backing;
};

[[nodiscard]] AddressSpaceWriteStats address_space_write_stats() noexcept;

class AddressSpace {
public:
    using MappingRegion = VmMap::MappingRegion;
    static constexpr std::uint32_t page_size = guest_memory_page_size;
    static constexpr std::size_t page_count =
        (std::uint64_t { 1 } << 32U) / page_size;

    AddressSpace();
    ~AddressSpace();

    // VFS and lazy file-backed mappings share one generation registry so a
    // writeback or pathname mutation cannot leave another mapping on a stale
    // file-generation view.
    void set_file_generation_registry(
        std::shared_ptr<GuestFileGenerationRegistry> generation_registry);

    // Selects the synchronization policy before guest execution starts. The
    // physical single-core device runs all memory access on the scheduler
    // thread; multi-core sessions synchronize memory accesses. Direct JIT
    // access is available only inside a serialized exclusive scope.
    void set_parallel_access(bool enabled);
    // A serialized execution slice can hold the memory lock once. Nested
    // accesses on its own thread reuse that lock; other host readers retain
    // ordinary exclusion. Parallel guest lanes must not use this scope.
    class ExclusiveAccess {
    public:
        explicit ExclusiveAccess(AddressSpace& memory);
        ~ExclusiveAccess();
        ExclusiveAccess(const ExclusiveAccess&) = delete;
        ExclusiveAccess& operator=(const ExclusiveAccess&) = delete;

    private:
        friend class AddressSpace;
        AddressSpace& memory_;
        std::unique_lock<std::mutex> lock_;
        const ExclusiveAccess* previous_;
    };
    // A shared Umbra monitor can conservatively invalidate all reservations
    // whenever this address space performs a checked Guest write. Direct JIT
    // writes are only installed for private pages, so shared/COW writes pass
    // through this boundary before another execution slice begins.
    void set_exclusive_write_observer(std::function<void()> observer);
    // Legacy alias for the direct-write table.
    [[nodiscard]] std::uint8_t** jit_page_table();
    // Read and write tables are separate: immutable/file/COW pages may be read
    // directly, while only private/shared-writable pages bypass write
    // callbacks. Null entries transparently fall back to the checked callbacks.
    // Tables remain valid for this AddressSpace's lifetime. Re-select the
    // tables at each execution entry: parallel lanes use checked tables,
    // while an exclusive serialized scope may expose guarded private accesses.
    [[nodiscard]] std::uint8_t** jit_read_page_table();
    [[nodiscard]] std::uint8_t** jit_write_page_table();
    // Debug watchpoints can require every access to pass through callbacks.
    // Existing JITs retain a valid all-null table after this call.
    void disable_jit_page_table();
    // Exact exclusive reservation tracking needs checked writes so each store
    // can advance its backing identity; immutable/read-only direct accesses may
    // continue using the read table.
    void disable_jit_write_page_table();
    // Umbra calls this immediately before establishing an LDREX reservation.
    // Keep the touched pages on the checked-write path from that point onward;
    // otherwise a later ordinary store could bypass reservation invalidation
    // through an already compiled direct-write block.
    void track_exclusive_access(std::uint32_t address, std::size_t size);
    // A serialized processor loses its local reservation at a real Guest
    // thread switch. Restore direct writes for pages that no longer need the
    // checked exclusive-monitor path; every other write restriction remains.
    void clear_exclusive_access_tracking();
    // A physical page can become write-tracked after another AddressSpace has
    // already cached a direct JIT write pointer to it. The execution boundary
    // calls this safe point before re-entering Umbra so those old aliases
    // are redirected through the checked write callbacks.
    void synchronize_shared_write_tracking();

    bool map(std::uint32_t address, std::uint32_t size,
        MemoryPermission permissions);
    struct UnmapResult {
        bool succeeded { };
        // True when at least one removed mapping allowed instruction
        // execution. Callers use this to retire translated code, since a later
        // mapping at the same address may hold different instructions.
        bool executable_unmapped { };
    };
    [[nodiscard]] UnmapResult unmap_with_result(
        std::uint32_t address, std::uint32_t size);
    bool unmap(std::uint32_t address, std::uint32_t size);
    enum class FileSyncResult { Success, Unmapped, IoError };
    // Writes shared file pages through their retained backing descriptors.
    // Synchronous requests additionally flush each backing file once. Private
    // and anonymous pages have no persistent writeback obligation.
    [[nodiscard]] FileSyncResult synchronize_file_mappings(
        std::uint32_t address, std::uint32_t size, bool synchronous);
    void clear();
    struct ProtectResult {
        bool succeeded { };
        // True when at least one affected mapping changed permissions and
        // either its old or new permissions allowed instruction execution.
        // Callers use this to retire translated code without invalidating
        // data-only changes.
        bool executable_permissions_changed { };
    };
    [[nodiscard]] ProtectResult protect_with_result(std::uint32_t address,
        std::uint32_t size, MemoryPermission permissions);
    bool protect(std::uint32_t address, std::uint32_t size,
        MemoryPermission permissions);
    // Applies Mach vm_inherit metadata to a fully mapped, page-rounded range.
    // clone() consumes it to select shared, copy-on-write, or absent child
    // mappings.
    bool inherit(std::uint32_t address, std::uint32_t size,
        VmInheritance inheritance);
    struct CopyInOperation {
        std::uint32_t address { };
        std::span<const std::byte> data;
    };
    bool copy_in(std::uint32_t address, std::span<const std::byte> data);
    // Applies a preflighted set of writes under one address-space lock. File
    // backed pages are detached at most once per touched page and executable
    // generation/JIT write bookkeeping is coalesced across the batch.
    bool copy_in_batch(std::span<const CopyInOperation> operations);
    [[nodiscard]] bool copy_out(
        std::uint32_t address, std::span<std::byte> data) const;
    // Installs page-aligned immutable file backing. A guest write automatically
    // detaches that page, providing MAP_PRIVATE/shared-region COW semantics.
    bool map_file(std::uint32_t address, std::uint32_t size,
        MemoryPermission permissions, const std::filesystem::path& path,
        std::uint64_t file_offset,
        std::optional<GuestFileGeneration> expected_generation = std::nullopt,
        std::optional<ContentIdentity> expected_content_identity = std::nullopt,
        std::shared_ptr<const std::vector<std::byte>> immutable_snapshot = { },
        std::shared_ptr<const ImmutableFileView> immutable_file_view = { },
        FileMappingBatchContext* batch_context = nullptr);
    enum class PageMappingMode {
        CopyOnWrite,
        Shared,
        SharedFile,
    };
    // Exposes an existing page-aligned range as a Mach named-memory object.
    // Existing fork/file-cache COW backings are detached first; subsequent
    // mappings of the returned pages observe shared writes like XNU vm_map.
    [[nodiscard]] std::optional<std::vector<std::shared_ptr<GuestPageBacking>>>
    share_pages(std::uint32_t address, std::uint32_t size);
    // Installs backings owned by a Mach named-memory object. CopyOnWrite keeps
    // vm_map(copy=TRUE) private while Shared preserves cross-mapping writes.
    bool map_page_backings(std::uint32_t address, std::uint32_t size,
        MemoryPermission permissions,
        std::span<const std::shared_ptr<GuestPageBacking>> backings,
        PageMappingMode mode, std::uint64_t* mapping_lease_token = nullptr);
    // A mapping lease is created atomically with a shared-page mapping. Any
    // guest unmap touching that range invalidates the token, so a later owner
    // release cannot erase unrelated pages remapped at the same virtual
    // address.
    bool unmap_mapping_lease(std::uint64_t mapping_lease_token);
    [[nodiscard]] std::optional<std::vector<std::byte>> read_bytes(
        std::uint32_t address, std::size_t size) const;
    [[nodiscard]] std::optional<std::string> read_c_string(
        std::uint32_t address, std::size_t maximum_size = 4096) const;

    [[nodiscard]] std::optional<std::uint8_t> read8(std::uint32_t address,
        MemoryPermission access = MemoryPermission::Read) const;
    [[nodiscard]] std::optional<std::uint16_t> read16(std::uint32_t address,
        MemoryPermission access = MemoryPermission::Read) const;
    [[nodiscard]] std::optional<std::uint32_t> read32(std::uint32_t address,
        MemoryPermission access = MemoryPermission::Read) const;
    [[nodiscard]] std::optional<std::uint64_t> read64(std::uint32_t address,
        MemoryPermission access = MemoryPermission::Read) const;

    bool write8(std::uint32_t address, std::uint8_t value);
    bool write16(std::uint32_t address, std::uint16_t value);
    bool write32(std::uint32_t address, std::uint32_t value);
    bool write64(std::uint32_t address, std::uint64_t value);

    [[nodiscard]] bool accessible(
        std::uint32_t address, std::size_t size, MemoryPermission access) const;
    // Returns true only for executable, non-writable file-backed pages whose
    // resident backing has not entered shared-write or copy-on-write state.
    // Anonymous and dynamically shared code remains conservative and mutable.
    [[nodiscard]] bool is_read_only_executable(
        std::uint32_t address, std::size_t size) const;
    // Returns portable content and mapping-layout identities for an immutable
    // file-backed executable range. The layout identity includes Guest/file
    // offsets, so the same bytes mapped at a different slide cannot reuse a
    // layout-sensitive artifact accidentally. Host path, vnode generation and
    // registry revision are runtime backing state and are intentionally absent.
    [[nodiscard]] std::optional<ExecutableBackingIdentity>
    executable_backing_identity(std::uint32_t address, std::size_t size) const;
    // Monotonic, lock-free content/mapping stamp for cheap JIT probe validity.
    // It changes on mapping mutations and writes to executable ranges; it is a
    // validity token only, never an artifact identity or a hash filter.
    [[nodiscard]] std::uint64_t executable_content_generation() const noexcept;
    // Monotonic notification stamp for executable ranges that have become
    // eligible for persistent translation-profile reuse. Unlike the broader
    // executable content generation, this advances only when a newly stable
    // range is published, so deferred profile work is not retried for ordinary
    // writes, protection changes, or invalidations.
    [[nodiscard]] std::uint64_t
    translation_profile_mapping_generation() const noexcept;
    // Resolves an exclusive-access address to the physical GuestPageBacking
    // identity when resident. Shared aliases therefore reserve the same
    // monitor granule, while unmapped/lazy pages conservatively retain a
    // virtual-address key until their backing is materialized.
    [[nodiscard]] std::uint64_t exclusive_reservation_key(
        std::uint32_t address) const noexcept;
    // Persistent translation hints may only retain code whose guest address is
    // invariant across process launches. Fixed Mach-O mappings opt into this
    // range separately from ordinary executable permission; slid bundles,
    // arbitrary mmap code, and generated trampolines remain session-local.
    void mark_translation_profile_stable(
        std::uint32_t address, std::uint32_t size);
    [[nodiscard]] bool translation_profile_stable(
        std::uint32_t address, std::size_t size) const;
    bool compare_exchange8(
        std::uint32_t address, std::uint8_t expected, std::uint8_t value);
    bool compare_exchange16(
        std::uint32_t address, std::uint16_t expected, std::uint16_t value);
    bool compare_exchange32(
        std::uint32_t address, std::uint32_t expected, std::uint32_t value);
    bool compare_exchange64(
        std::uint32_t address, std::uint64_t expected, std::uint64_t value);
    [[nodiscard]] std::optional<std::uint8_t> exchange8(
        std::uint32_t address, std::uint8_t value);
    [[nodiscard]] std::optional<std::uint32_t> exchange32(
        std::uint32_t address, std::uint32_t value);

    [[nodiscard]] bool mapped(
        std::uint32_t address, std::size_t size = 1) const;
    // Write generations are only needed by memory consumers that poll a
    // specific range (for example, a legacy scanout buffer). Registering that
    // range keeps ordinary Guest stores out of the dirty-generation path.
    bool track_write_generation(std::uint32_t address, std::size_t size);
    // Returns the newest write generation among pages intersecting the range.
    // Graphics scanout uses this to avoid copying an unchanged framebuffer.
    [[nodiscard]] std::optional<std::uint64_t> range_write_generation(
        std::uint32_t address, std::size_t size) const;
    // Publishes direct Guest writes at a firmware-provided synchronization
    // boundary. Every resident page in the range receives one local and shared
    // generation update, independent of per-store write tracking.
    bool publish_write_generation(std::uint32_t address, std::size_t size);
    struct WrittenRange {
        std::uint32_t address { };
        std::uint32_t size { };
    };
    struct WriteGenerationChanges {
        std::uint64_t generation { };
        std::vector<WrittenRange> ranges;
    };
    struct SharedWriteGenerationChanges {
        std::vector<std::uint64_t> page_generations;
        std::vector<WrittenRange> ranges;
    };
    // Returns page-granular ranges written after a consumer's last generation,
    // clipped to the requested byte range. Tracking remains opt-in so unrelated
    // Guest stores keep the direct JIT write path.
    [[nodiscard]] std::optional<WriteGenerationChanges>
    write_generation_changes(std::uint32_t address, std::size_t size,
        std::uint64_t after_generation) const;
    // Shared page generations are attached to physical backings rather than a
    // process-local vm_map, so writes through another task remain visible.
    [[nodiscard]] std::optional<SharedWriteGenerationChanges>
    shared_write_generation_changes(std::uint32_t address, std::size_t size,
        std::span<const std::uint64_t> after_page_generations = { }) const;
    [[nodiscard]] std::size_t mapped_page_count() const;
    // Demand-zero mappings do not become resident until their first write.
    [[nodiscard]] std::size_t resident_page_count() const;
    // Resident backings shared by fork clones or the immutable file cache.
    [[nodiscard]] std::size_t shared_page_count() const;
    [[nodiscard]] std::size_t cached_file_mapping_count() const;
    [[nodiscard]] std::size_t cached_file_page_count() const;
    [[nodiscard]] FilePageCacheStats file_page_cache_stats() const;
    [[nodiscard]] std::size_t mapping_region_count() const;
    [[nodiscard]] std::optional<MappingRegion> mapping_region_at_or_after(
        std::uint32_t address) const;
    [[nodiscard]] std::unique_ptr<AddressSpace> clone() const;

private:
    struct Page {
        std::shared_ptr<GuestPageBacking> backing;
        std::uint64_t write_generation { };
        bool file_cached { };
        bool shared_writable { };
        bool file_writeback_capable { };
        // Writable file-backed MAP_SHARED mappings use coarse release-time
        // writeback so ordinary guest stores retain the direct JIT path.
        bool file_writeback { };
        // Avoid an atomic shared_ptr use-count read on every guest store. This
        // is set only when fork/file/private-object sharing can require a
        // detach.
        mutable bool copy_on_write_possible { };
    };
    struct FileMapping {
        std::uint64_t end { };
        std::uint64_t file_offset { };
        std::shared_ptr<GuestFileBacking> backing;
    };
    struct TrackedWriteRange {
        std::uint32_t begin { };
        std::uint64_t end { };
    };
    struct MappingLease {
        std::uint32_t begin { };
        std::uint64_t end { };
    };
    struct JitPageTableStorage;
    static constexpr std::size_t page_lookup_chunk_size = 1024;
    static constexpr std::size_t page_lookup_chunk_count =
        page_count / page_lookup_chunk_size;
    static constexpr std::size_t page_permission_chunk_size = 4096;
    static constexpr std::size_t page_permission_chunk_count =
        page_count / page_permission_chunk_size;
    using PageMap = std::map<std::uint32_t, Page>;
    using PageLookupChunk = std::array<Page*, page_lookup_chunk_size>;
    using PagePermissionChunk =
        std::array<std::uint8_t, page_permission_chunk_size>;
    using ReadLock = std::unique_lock<std::mutex>;
    using WriteLock = std::unique_lock<std::mutex>;

    template <typename T>
    [[nodiscard]] std::optional<T> read_integer(
        std::uint32_t address, MemoryPermission access) const;
    template <typename T> bool write_integer(std::uint32_t address, T value);
    template <typename T>
    bool compare_exchange_integer(std::uint32_t address, T expected, T value);
    template <typename T>
    [[nodiscard]] std::optional<T> exchange_integer(
        std::uint32_t address, T value);

    [[nodiscard]] bool range_accessible_locked(
        std::uint32_t address, std::size_t size, MemoryPermission access) const;
    [[nodiscard]] const Page* find_page_locked(std::uint32_t address) const;
    [[nodiscard]] Page* find_page_locked(std::uint32_t address);
    [[nodiscard]] const FileMapping* find_file_mapping_locked(
        std::uint32_t address) const;
    [[nodiscard]] Page& ensure_page_locked(std::uint32_t address);
    [[nodiscard]] bool range_needs_file_fault_locked(
        std::uint32_t address, std::size_t size) const;
    [[nodiscard]] bool fault_file_pages(
        std::uint32_t address, std::size_t size);
    void unmap_file_mappings_locked(std::uint32_t address, std::uint64_t end);
    bool flush_shared_file_pages_locked(
        std::uint32_t address, std::uint64_t end, bool synchronous = false);
    void unmap_range_locked(std::uint32_t address, std::uint64_t end,
        bool flush_shared_files = true);
    void invalidate_mapping_leases_locked(
        std::uint32_t address, std::uint64_t end);
    void share_pages_locked(std::uint32_t address, std::uint64_t end,
        std::vector<std::shared_ptr<GuestPageBacking>>* output);
    void cache_page_locked(std::uint32_t address, Page& page);
    void uncache_page_locked(std::uint32_t address);
    void ensure_unique_page_map_locked();
    void rebuild_page_lookup_locked();
    void ensure_jit_page_tables_locked();
    void refresh_jit_page_locked(std::uint32_t address);
    void refresh_jit_page_range_locked(
        std::uint32_t address, std::uint64_t end);
    void finish_shared_write_tracking_locked(std::uint64_t initial_epoch,
        std::size_t local_transitions, bool backing_may_have_aliases);
    void invalidate_shared_write_jit_pages_locked();
    void clear_jit_page_table_locked();
    [[nodiscard]] static std::byte read_byte_locked(
        const Page* page, std::uint32_t offset);
    [[nodiscard]] static GuestPageBacking& writable_backing_locked(
        Page& page, bool* jit_eligibility_changed = nullptr);
    [[nodiscard]] bool reservation_invalidation_required_locked(
        const Page& page) const noexcept;
    void release_exclusive_write_tracking_locked(
        std::uint32_t address, std::size_t size);
    void mark_shared_backing_written_locked(
        Page& page, std::uint32_t offset, std::size_t size);
    [[nodiscard]] bool tracks_write_locked(
        std::uint32_t address, std::size_t size) const;
    void mark_written_locked(std::uint32_t address, std::size_t size);
    void mark_written_batch_locked(std::span<const WrittenRange> ranges);
    void bump_executable_content_generation_locked() noexcept;
    void add_page_permissions_locked(
        std::uint32_t address, std::uint64_t end, MemoryPermission permissions);
    void set_page_permissions_locked(
        std::uint32_t address, std::uint64_t end, MemoryPermission permissions);
    void clear_page_permissions_locked(
        std::uint32_t address, std::uint64_t end);
    [[nodiscard]] std::uint8_t page_permission_locked(
        std::size_t page_index) const;
    [[nodiscard]] PagePermissionChunk& writable_page_permission_chunk_locked(
        std::size_t page_index);
    [[nodiscard]] ReadLock read_lock() const;
    [[nodiscard]] WriteLock write_lock();
    [[nodiscard]] bool owns_exclusive_access() const noexcept;
    static thread_local const ExclusiveAccess* exclusive_access_;

    // Scalar guest accesses are short and interleave reads with writes. A
    // single mutex avoids the reader-accounting overhead of a reader/writer
    // lock while retaining mutual exclusion for parallel execution/faults.
    mutable std::mutex mutex_;
    bool parallel_access_ { true };
    VmMap vm_map_;
    VmMap translation_profile_map_;
    std::shared_ptr<PageMap> pages_ { std::make_shared<PageMap>() };
    // File-backed vm_map entries remain range metadata until a guest access
    // faults an individual page into pages_. This mirrors XNU's vnode pager and
    // avoids constructing thousands of page objects during mmap.
    std::map<std::uint32_t, FileMapping> file_mappings_;
    // Sparse two-level lookup for resident pages. Tree ownership preserves
    // efficient range unmap while CPU callbacks avoid a tree search.
    std::array<std::unique_ptr<PageLookupChunk>, page_lookup_chunk_count>
        page_lookup_ { };
    // The interval map remains the source of truth for VM operations. A sparse
    // chunked byte index keeps callback permission checks O(1) while fork
    // clones share untouched chunks and detach only metadata ranges they
    // modify.
    std::array<std::shared_ptr<PagePermissionChunk>,
        page_permission_chunk_count>
        page_permissions_ { };
    std::unique_ptr<JitPageTableStorage> jit_read_page_table_;
    std::unique_ptr<JitPageTableStorage> jit_write_page_table_;
    // Only pages with a live direct-write entry can need invalidation when a
    // physical backing becomes write-tracked in another address space.  Keep a
    // sparse index instead of rescanning every resident guest page at each
    // CoreSurface/Mach shared-memory publication.
    std::unordered_set<std::uint32_t> direct_jit_write_pages_;
    bool jit_page_table_enabled_ { };
    bool jit_write_page_table_enabled_ { true };
    // Each page carries a mask of live physical reservation granules. Keep
    // writes guarded until every marked granule is invalidated or the serial
    // processor switches Guest threads. Unmapping drops its markers too.
    std::unordered_map<std::uint32_t, std::uint64_t>
        exclusive_write_tracked_pages_;
    std::atomic<bool> exclusive_write_tracking_active_ { };
    std::atomic<std::uint64_t> observed_shared_write_tracking_epoch_ { };
    std::vector<TrackedWriteRange> tracked_write_ranges_;
    std::unordered_set<std::uint32_t> write_tracked_pages_;
    std::uint64_t write_generation_ { };
    std::atomic<std::uint64_t> executable_content_generation_ { 1U };
    std::atomic<std::uint64_t> translation_profile_mapping_generation_ { 1U };
    std::map<std::uint64_t, MappingLease> mapping_leases_;
    std::uint64_t next_mapping_lease_token_ { 1 };
    std::shared_ptr<FilePageCache> file_page_cache_;
    std::function<void()> exclusive_write_observer_;
};

} // namespace shade
