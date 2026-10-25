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
#include "foundation/snapshot_io.hpp"
#include "foundation/vm_map.hpp"

namespace emulator {

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

struct MaterializedPageCounts {
    std::uint64_t anonymous { };
    std::uint64_t file_cached { };
    std::uint64_t copy_on_write_possible { };
    std::uint64_t shared_writable { };

    [[nodiscard]] std::uint64_t total() const noexcept
    {
        return anonymous + file_cached + copy_on_write_possible +
               shared_writable;
    }

    MaterializedPageCounts& operator+=(
        const MaterializedPageCounts& other) noexcept
    {
        anonymous += other.anonymous;
        file_cached += other.file_cached;
        copy_on_write_possible += other.copy_on_write_possible;
        shared_writable += other.shared_writable;
        return *this;
    }
};

struct FileMappingBatchContext {
    std::shared_ptr<GuestFileBacking> backing;
};

[[nodiscard]] AddressSpaceWriteStats address_space_write_stats() noexcept;

class AddressSpace {
    friend struct CompatibilityKernelSnapshot;

public:
    using MappingRegion = VmMap::MappingRegion;
    static constexpr std::uint32_t page_size = guest_memory_page_size;
    static constexpr std::size_t page_count =
        (std::uint64_t { 1 } << 32U) / page_size;

    AddressSpace();
    ~AddressSpace();

    void set_file_generation_registry(
        std::shared_ptr<GuestFileGenerationRegistry> generation_registry);

    void set_parallel_access(bool enabled);
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
    void set_exclusive_write_observer(std::function<void()> observer);
    [[nodiscard]] std::uint8_t** jit_page_table();
    [[nodiscard]] std::uint8_t** jit_read_page_table();
    [[nodiscard]] std::uint8_t** jit_write_page_table();
    void disable_jit_page_table();
    void disable_jit_write_page_table();
    enum class JitSlowPathReason : std::size_t {
        Exclusive,
        Misaligned,
        TableDisabled,
        Unbacked,
        CodeWrite,
        ReservationWrite,
        FileOrCopyOnWrite,
        SharedWrite,
        Unmapped,
        ParallelChecked,
        Other,
        Count,
    };
    [[nodiscard]] JitSlowPathReason jit_slow_path_reason(
        std::uint32_t address, std::size_t size, bool write) const;
    void track_exclusive_access(std::uint32_t address, std::size_t size);
    void clear_exclusive_access_tracking();
    void synchronize_shared_write_tracking();

    bool map(std::uint32_t address, std::uint32_t size,
        MemoryPermission permissions);
    struct UnmapResult {
        bool succeeded { };
        bool executable_unmapped { };
    };
    [[nodiscard]] UnmapResult unmap_with_result(
        std::uint32_t address, std::uint32_t size);
    bool unmap(std::uint32_t address, std::uint32_t size);
    enum class FileSyncResult { Success, Unmapped, IoError };
    [[nodiscard]] FileSyncResult synchronize_file_mappings(
        std::uint32_t address, std::uint32_t size, bool synchronous);
    void clear();
    void save(snapshot::Writer& out) const;
    void load(snapshot::Reader& in);
    struct ProtectResult {
        bool succeeded { };
        bool executable_permissions_changed { };
    };
    [[nodiscard]] ProtectResult protect_with_result(std::uint32_t address,
        std::uint32_t size, MemoryPermission permissions);
    bool protect(std::uint32_t address, std::uint32_t size,
        MemoryPermission permissions);
    bool inherit(std::uint32_t address, std::uint32_t size,
        VmInheritance inheritance);
    struct CopyInOperation {
        std::uint32_t address { };
        std::span<const std::byte> data;
    };
    bool copy_in(std::uint32_t address, std::span<const std::byte> data);
    bool copy_in_batch(std::span<const CopyInOperation> operations);
    [[nodiscard]] bool copy_out(
        std::uint32_t address, std::span<std::byte> data) const;
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
    [[nodiscard]] std::optional<std::vector<std::shared_ptr<GuestPageBacking>>>
    share_pages(std::uint32_t address, std::uint32_t size);
    bool map_page_backings(std::uint32_t address, std::uint32_t size,
        MemoryPermission permissions,
        std::span<const std::shared_ptr<GuestPageBacking>> backings,
        PageMappingMode mode, std::uint64_t* mapping_lease_token = nullptr);
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
    [[nodiscard]] bool is_read_only_executable(
        std::uint32_t address, std::size_t size) const;
    [[nodiscard]] std::optional<ExecutableBackingIdentity>
    executable_backing_identity(std::uint32_t address, std::size_t size) const;
    [[nodiscard]] std::uint64_t executable_content_generation() const noexcept;
    [[nodiscard]] std::uint64_t
    translation_profile_mapping_generation() const noexcept;
    [[nodiscard]] std::uint64_t exclusive_reservation_key(
        std::uint32_t address) const noexcept;
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
    bool track_write_generation(std::uint32_t address, std::size_t size);
    [[nodiscard]] std::optional<std::uint64_t> range_write_generation(
        std::uint32_t address, std::size_t size) const;
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
    [[nodiscard]] std::optional<WriteGenerationChanges>
    write_generation_changes(std::uint32_t address, std::size_t size,
        std::uint64_t after_generation) const;
    [[nodiscard]] std::optional<SharedWriteGenerationChanges>
    shared_write_generation_changes(std::uint32_t address, std::size_t size,
        std::span<const std::uint64_t> after_page_generations = { }) const;
    [[nodiscard]] std::size_t mapped_page_count() const;
    [[nodiscard]] std::size_t resident_page_count() const;
    [[nodiscard]] std::size_t shared_page_count() const;
    [[nodiscard]] MaterializedPageCounts materialized_page_counts() const;
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
        bool file_writeback { };
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

    mutable std::mutex mutex_;
    bool parallel_access_ { true };
    VmMap vm_map_;
    VmMap translation_profile_map_;
    std::shared_ptr<PageMap> pages_ { std::make_shared<PageMap>() };
    std::map<std::uint32_t, FileMapping> file_mappings_;
    std::array<std::unique_ptr<PageLookupChunk>, page_lookup_chunk_count>
        page_lookup_ { };
    std::array<std::shared_ptr<PagePermissionChunk>,
        page_permission_chunk_count>
        page_permissions_ { };
    std::unique_ptr<JitPageTableStorage> jit_read_page_table_;
    std::unique_ptr<JitPageTableStorage> jit_write_page_table_;
    std::unordered_set<std::uint32_t> direct_jit_write_pages_;
    bool jit_page_table_enabled_ { };
    bool jit_write_page_table_enabled_ { true };
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

}
