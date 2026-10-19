// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Manage guest address mappings, permissions, memory access and
// executable backing identities.

#include "foundation/address_space.hpp"

#include <algorithm>
#include <cstring>
#include <iterator>
#include <limits>
#include <mutex>
#include <new>
#include <set>
#include <type_traits>
#include <utility>

#include <sys/mman.h>

#include "foundation/performance.hpp"

namespace shade {
namespace {

    std::atomic<std::uint64_t> write_batch_calls { };
    std::atomic<std::uint64_t> write_batch_operations { };
    std::atomic<std::uint64_t> write_batch_failures { };
    std::atomic<std::uint64_t> write_touched_pages { };
    std::atomic<std::uint64_t> write_copy_on_write_detaches { };

    constexpr std::uint32_t page_base(std::uint32_t address)
    {
        return address & ~(AddressSpace::page_size - 1U);
    }

    constexpr std::uint8_t mapped_page_flag = 0x80U;
    constexpr std::uint32_t exclusive_granule_mask = ~std::uint32_t { 63U };
    constexpr std::uint64_t backing_reservation_tag = std::uint64_t { 1 }
                                                      << 63U;
    constexpr std::uint64_t maximum_backing_reservation_identity =
        (std::uint64_t { 1 } << 52U) - 1U;

    constexpr std::uint8_t permission_bits(MemoryPermission permissions)
    {
        return static_cast<std::uint8_t>(permissions);
    }

    bool range_overflows(std::uint32_t address, std::size_t size)
    {
        if (size == 0) {
            return false;
        }
        return size - 1 > std::numeric_limits<std::uint32_t>::max() - address;
    }

    std::uint64_t page_range_end(std::uint32_t address, std::size_t size)
    {
        return static_cast<std::uint64_t>(
                   page_base(address + static_cast<std::uint32_t>(size - 1U))) +
               AddressSpace::page_size;
    }

    [[nodiscard]] std::uint64_t reservation_granule_mask(
        std::uint32_t address, std::size_t size, std::uint32_t page)
    {
        const auto begin = std::max<std::uint64_t>(address, page) - page;
        const auto end =
            std::min<std::uint64_t>(static_cast<std::uint64_t>(address) + size,
                static_cast<std::uint64_t>(page) + AddressSpace::page_size) -
            page;
        const auto first = begin / guest_exclusive_granule_size;
        const auto last = (end - 1U) / guest_exclusive_granule_size;
        return (~std::uint64_t { 0 } << first) &
               (~std::uint64_t { 0 } >> (63U - last));
    }

    [[nodiscard]] std::uint8_t* jit_page_pointer(
        const GuestPageBacking& backing, std::uint32_t guest_page) noexcept
    {
        const auto host_page =
            reinterpret_cast<std::uintptr_t>(backing.bytes.data());
        if constexpr (sizeof(std::uintptr_t) >= sizeof(std::uint64_t)) {
            // Umbra's absolute-offset page-table mode adds the full Guest
            // address to this entry. Keep the arithmetic in uintptr_t so the
            // deliberately-before-object pointer is never formed by C++ pointer
            // arithmetic; the generated access always lands inside bytes.
            return reinterpret_cast<std::uint8_t*>(host_page - guest_page);
        } else {
            static_cast<void>(guest_page);
            return reinterpret_cast<std::uint8_t*>(host_page);
        }
    }

    [[nodiscard]] std::uint64_t backing_reservation_key(
        const GuestPageBacking& backing, std::uint32_t address) noexcept
    {
        const auto identity = backing.reservation_identity(
            address & (AddressSpace::page_size - 1U));
        if (identity == 0 || identity > maximum_backing_reservation_identity) {
            return static_cast<std::uint64_t>(address & exclusive_granule_mask);
        }
        const auto page_offset = static_cast<std::uint64_t>(
            address & (AddressSpace::page_size - 1U) & exclusive_granule_mask);
        return backing_reservation_tag | (identity << 12U) | page_offset;
    }

    void append_u64(std::vector<std::byte>& bytes, std::uint64_t value)
    {
        for (std::size_t index = 0; index < sizeof(value); ++index) {
            bytes.push_back(static_cast<std::byte>(value >> (index * 8U)));
        }
    }

    void append_identity(
        std::vector<std::byte>& bytes, const ContentIdentity& identity)
    {
        bytes.insert(
            bytes.end(), identity.digest.begin(), identity.digest.end());
    }

} // namespace

struct AddressSpace::JitPageTableStorage {
    static constexpr std::size_t byte_size =
        AddressSpace::page_count * sizeof(std::uint8_t*);

    JitPageTableStorage()
    {
        mapping = ::mmap(nullptr, byte_size, PROT_READ | PROT_WRITE,
            MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        if (mapping == MAP_FAILED) {
            mapping = nullptr;
            throw std::bad_alloc { };
        }
    }

    ~JitPageTableStorage()
    {
        if (mapping != nullptr) {
            static_cast<void>(::munmap(mapping, byte_size));
        }
    }

    [[nodiscard]] std::uint8_t** entries() const
    {
        return static_cast<std::uint8_t**>(mapping);
    }

    void clear()
    {
#if defined(__linux__)
        if (::madvise(mapping, byte_size, MADV_DONTNEED) != 0) {
            std::memset(mapping, 0, byte_size);
        }
#else
        if (::mmap(mapping, byte_size, PROT_READ | PROT_WRITE,
                MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED, -1, 0) != mapping) {
            std::memset(mapping, 0, byte_size);
        }
#endif
    }

    void* mapping { };
};

AddressSpace::AddressSpace()
    : observed_shared_write_tracking_epoch_ {
        GuestPageBacking::shared_write_tracking_epoch()
    }
    , file_page_cache_ { std::make_shared<FilePageCache>() }
{
}

AddressSpace::~AddressSpace()
{
    auto lock = write_lock();
    flush_shared_file_pages_locked(0,
        static_cast<std::uint64_t>(std::numeric_limits<std::uint32_t>::max()) +
            1U);
}

void AddressSpace::set_file_generation_registry(
    std::shared_ptr<GuestFileGenerationRegistry> generation_registry)
{
    file_page_cache_->set_generation_registry(std::move(generation_registry));
}

std::uint64_t AddressSpace::exclusive_reservation_key(
    std::uint32_t address) const noexcept
{
    try {
        auto lock = read_lock();
        const auto* page = find_page_locked(address);
        if (page != nullptr && page->backing) {
            return backing_reservation_key(*page->backing, address);
        }
    } catch (...) {
        // A resolver is called from generated guest code. If a host allocation
        // or lock operation fails, preserve the safe legacy virtual-address key
        // and let the ordinary memory callback report the actual fault.
    }
    return static_cast<std::uint64_t>(address & exclusive_granule_mask);
}

void AddressSpace::set_parallel_access(bool enabled)
{
    std::unique_lock lock { mutex_, std::defer_lock };
    if (!owns_exclusive_access())
        lock.lock();
    parallel_access_ = enabled;
    jit_page_table_enabled_ = true;
    if (!jit_read_page_table_ && !jit_write_page_table_)
        return;
    for (const auto& [address, page] : *pages_) {
        static_cast<void>(page);
        refresh_jit_page_locked(address);
    }
}

void AddressSpace::set_exclusive_write_observer(std::function<void()> observer)
{
    auto lock = write_lock();
    exclusive_write_observer_ = std::move(observer);
}

std::uint8_t** AddressSpace::jit_page_table() { return jit_write_page_table(); }

std::uint8_t** AddressSpace::jit_read_page_table()
{
    auto lock = write_lock();
    if (!jit_page_table_enabled_)
        return nullptr;
    ensure_jit_page_tables_locked();
    bool direct_reads = !parallel_access_;
#if defined(__x86_64__) || defined(_M_X64)
    direct_reads = direct_reads || owns_exclusive_access();
#endif
    if (!direct_reads) {
        // Checked stores update scalar values under the address-space lock.
        // A raw load on another lane could otherwise observe a partial store.
        static JitPageTableStorage checked_reads;
        return checked_reads.entries();
    }
    return jit_read_page_table_->entries();
}

std::uint8_t** AddressSpace::jit_write_page_table()
{
    auto lock = write_lock();
    if (!jit_page_table_enabled_ || !jit_write_page_table_enabled_)
        return nullptr;
    ensure_jit_page_tables_locked();
    bool direct_writes = !parallel_access_;
#if defined(__x86_64__) || defined(_M_X64)
    // The x64 backend reloads executor page-table links on every JIT entry.
    direct_writes = direct_writes || owns_exclusive_access();
#endif
    if (!direct_writes) {
        // Shared by every parallel lane. Serialized slices can select the
        // guarded private-write table through their executor's runtime link.
        static JitPageTableStorage checked_writes;
        return checked_writes.entries();
    }
    return jit_write_page_table_->entries();
}

void AddressSpace::disable_jit_page_table()
{
    auto lock = write_lock();
    jit_page_table_enabled_ = false;
    jit_write_page_table_enabled_ = false;
    clear_jit_page_table_locked();
}

void AddressSpace::disable_jit_write_page_table()
{
    auto lock = write_lock();
    jit_write_page_table_enabled_ = false;
    if (jit_write_page_table_)
        jit_write_page_table_->clear();
    direct_jit_write_pages_.clear();
    exclusive_write_tracked_pages_.clear();
    exclusive_write_tracking_active_.store(false, std::memory_order_release);
}

void AddressSpace::track_exclusive_access(
    std::uint32_t address, std::size_t size)
{
    if (size == 0 || range_overflows(address, size))
        return;
    const auto first = page_base(address);
    const auto end = page_range_end(address, size);
    auto lock = write_lock();
    if (!jit_write_page_table_enabled_)
        return;
    for (std::uint64_t base = first; base < end; base += page_size) {
        const auto page_address = static_cast<std::uint32_t>(base);
        const auto mask = reservation_granule_mask(address, size, page_address);
        const auto inserted =
            exclusive_write_tracked_pages_.try_emplace(page_address, 0U).second;
        exclusive_write_tracked_pages_.at(page_address) |= mask;
        const auto* page = find_page_locked(page_address);
        if (inserted)
            refresh_jit_page_locked(page_address);
        if (page == nullptr || !page->shared_writable || !page->backing)
            continue;

        // Keep every local alias guarded, including already guarded aliases
        // when another granule on the physical page acquires a reservation.
        const auto* backing = page->backing.get();
        for (auto& [alias_address, alias_mask] :
            exclusive_write_tracked_pages_) {
            const auto* alias = find_page_locked(alias_address);
            if (alias != nullptr && alias->shared_writable &&
                alias->backing.get() == backing)
                alias_mask |= mask;
        }
        std::vector<std::uint32_t> aliases;
        for (const auto alias_address : direct_jit_write_pages_) {
            const auto* alias = find_page_locked(alias_address);
            if (alias != nullptr && alias->shared_writable &&
                alias->backing.get() == backing)
                aliases.push_back(alias_address);
        }
        for (const auto alias_address : aliases) {
            exclusive_write_tracked_pages_[alias_address] |= mask;
            refresh_jit_page_locked(alias_address);
        }
    }
    exclusive_write_tracking_active_.store(
        !exclusive_write_tracked_pages_.empty(), std::memory_order_release);
}

void AddressSpace::clear_exclusive_access_tracking()
{
    if (!exclusive_write_tracking_active_.load(std::memory_order_acquire))
        return;
    auto lock = write_lock();
    for (auto page = exclusive_write_tracked_pages_.begin();
        page != exclusive_write_tracked_pages_.end();) {
        const auto address = page->first;
        page = exclusive_write_tracked_pages_.erase(page);
        refresh_jit_page_locked(address);
    }
    exclusive_write_tracking_active_.store(false, std::memory_order_release);
}

void AddressSpace::release_exclusive_write_tracking_locked(
    std::uint32_t address, std::size_t size)
{
    if (size == 0 || range_overflows(address, size) ||
        !exclusive_write_tracking_active_.load(std::memory_order_relaxed))
        return;
    const auto first = page_base(address);
    const auto end = page_range_end(address, size);
    for (auto marker = exclusive_write_tracked_pages_.begin();
        marker != exclusive_write_tracked_pages_.end();) {
        const auto page_address = marker->first;
        const auto* marker_page = find_page_locked(page_address);
        for (std::uint64_t base = first; base < end; base += page_size) {
            const auto written_address = static_cast<std::uint32_t>(base);
            const auto* written_page = find_page_locked(written_address);
            if (page_address == written_address ||
                (marker_page != nullptr && marker_page->shared_writable &&
                    marker_page->backing && written_page != nullptr &&
                    written_page->shared_writable &&
                    written_page->backing == marker_page->backing)) {
                marker->second &=
                    ~reservation_granule_mask(address, size, written_address);
            }
        }
        if (marker->second != 0U) {
            ++marker;
            continue;
        }
        marker = exclusive_write_tracked_pages_.erase(marker);
        refresh_jit_page_locked(page_address);
    }
    if (exclusive_write_tracked_pages_.empty())
        exclusive_write_tracking_active_.store(
            false, std::memory_order_release);
}

void AddressSpace::synchronize_shared_write_tracking()
{
    auto target = GuestPageBacking::shared_write_tracking_epoch();
    if (target ==
        observed_shared_write_tracking_epoch_.load(std::memory_order_acquire)) {
        return;
    }
    auto lock = write_lock();
    // Capture the target again after serializing parallel address-space users.
    // A still newer epoch published during the scan remains pending for the
    // next safe point rather than being accidentally acknowledged here.
    target = GuestPageBacking::shared_write_tracking_epoch();
    if (target ==
        observed_shared_write_tracking_epoch_.load(std::memory_order_relaxed)) {
        return;
    }
    invalidate_shared_write_jit_pages_locked();
    observed_shared_write_tracking_epoch_.store(
        target, std::memory_order_release);
}

AddressSpace::ReadLock AddressSpace::read_lock() const
{
    ReadLock lock { mutex_, std::defer_lock };
    if (parallel_access_ && !owns_exclusive_access())
        lock.lock();
    return lock;
}

AddressSpace::WriteLock AddressSpace::write_lock()
{
    WriteLock lock { mutex_, std::defer_lock };
    if (parallel_access_ && !owns_exclusive_access())
        lock.lock();
    return lock;
}

thread_local const AddressSpace::ExclusiveAccess*
    AddressSpace::exclusive_access_ = nullptr;

bool AddressSpace::owns_exclusive_access() const noexcept
{
    for (auto* scope = exclusive_access_; scope != nullptr;
        scope = scope->previous_) {
        if (&scope->memory_ == this)
            return true;
    }
    return false;
}

AddressSpace::ExclusiveAccess::ExclusiveAccess(AddressSpace& memory)
    : memory_ { memory }
    , lock_ { memory.mutex_, std::defer_lock }
    , previous_ { exclusive_access_ }
{
    if (memory.parallel_access_ && !memory.owns_exclusive_access())
        lock_.lock();
    exclusive_access_ = this;
}

AddressSpace::ExclusiveAccess::~ExclusiveAccess()
{
    exclusive_access_ = previous_;
}

bool AddressSpace::map(
    std::uint32_t address, std::uint32_t size, MemoryPermission permissions)
{
    if (size == 0 || range_overflows(address, size)) {
        return size == 0;
    }
    const auto first = page_base(address);
    const auto end = page_range_end(address, size);
    auto lock = write_lock();
    invalidate_mapping_leases_locked(first, end);
    vm_map_.map_or(first, end, permissions);
    add_page_permissions_locked(first, end, permissions);
    refresh_jit_page_range_locked(first, end);
    bump_executable_content_generation_locked();
    return true;
}

AddressSpace::UnmapResult AddressSpace::unmap_with_result(
    std::uint32_t address, std::uint32_t size)
{
    if (size == 0 || range_overflows(address, size)) {
        return UnmapResult { .succeeded = size == 0 };
    }
    const auto first = page_base(address);
    const auto end = page_range_end(address, size);
    auto lock = write_lock();
    bool executable_unmapped = false;
    for (std::uint64_t cursor = first; cursor < end;) {
        const auto region =
            vm_map_.region_at_or_after(static_cast<std::uint32_t>(cursor));
        if (!region || region->address >= end)
            break;
        if (has_permission(region->permissions, MemoryPermission::Execute)) {
            executable_unmapped = true;
            break;
        }
        cursor = region->end;
    }
    invalidate_mapping_leases_locked(first, end);
    unmap_range_locked(first, end);
    return UnmapResult {
        .succeeded = true,
        .executable_unmapped = executable_unmapped,
    };
}

bool AddressSpace::unmap(std::uint32_t address, std::uint32_t size)
{
    return unmap_with_result(address, size).succeeded;
}

void AddressSpace::unmap_range_locked(
    std::uint32_t address, std::uint64_t end, bool flush_shared_files)
{
    if (flush_shared_files)
        flush_shared_file_pages_locked(address, end);
    vm_map_.unmap(address, end);
    translation_profile_map_.unmap(address, end);
    unmap_file_mappings_locked(address, end);
    ensure_unique_page_map_locked();
    auto page = pages_->lower_bound(address);
    while (page != pages_->end() && page->first < end) {
        uncache_page_locked(page->first);
        page = pages_->erase(page);
    }
    for (std::uint64_t base = address; base < end; base += page_size) {
        exclusive_write_tracked_pages_.erase(static_cast<std::uint32_t>(base));
    }
    if (exclusive_write_tracked_pages_.empty()) {
        exclusive_write_tracking_active_.store(
            false, std::memory_order_release);
    }
    clear_page_permissions_locked(address, end);
    refresh_jit_page_range_locked(address, end);
    bump_executable_content_generation_locked();
}

AddressSpace::FileSyncResult AddressSpace::synchronize_file_mappings(
    std::uint32_t address, std::uint32_t size, bool synchronous)
{
    if (size == 0 || range_overflows(address, size))
        return FileSyncResult::Unmapped;
    const auto first = page_base(address);
    const auto end = page_range_end(address, size);
    auto lock = write_lock();
    if (!vm_map_.accessible(first, end, MemoryPermission::None))
        return FileSyncResult::Unmapped;
    return flush_shared_file_pages_locked(first, end, synchronous)
               ? FileSyncResult::Success
               : FileSyncResult::IoError;
}

bool AddressSpace::flush_shared_file_pages_locked(
    std::uint32_t address, std::uint64_t end, bool synchronous)
{
    bool succeeded = true;
    std::set<std::shared_ptr<GuestFileIoState>> files;
    auto page = pages_->lower_bound(address);
    while (page != pages_->end() && page->first < end) {
        if (page->second.file_writeback && page->second.backing &&
            page->second.backing->file_backed()) {
            if (!page->second.backing->flush_file())
                succeeded = false;
            if (synchronous)
                files.insert(page->second.backing->writeback_io_state());
        }
        ++page;
    }
    for (const auto& file : files) {
        if (!file->synchronize())
            succeeded = false;
    }
    return succeeded;
}

void AddressSpace::invalidate_mapping_leases_locked(
    std::uint32_t address, std::uint64_t end)
{
    std::erase_if(mapping_leases_, [address, end](const auto& entry) {
        return static_cast<std::uint64_t>(entry.second.begin) < end &&
               entry.second.end > address;
    });
}

void AddressSpace::clear()
{
    auto lock = write_lock();
    flush_shared_file_pages_locked(0,
        static_cast<std::uint64_t>(std::numeric_limits<std::uint32_t>::max()) +
            1U);
    vm_map_.clear();
    translation_profile_map_.clear();
    pages_ = std::make_shared<PageMap>();
    file_mappings_.clear();
    for (auto& chunk : page_lookup_)
        chunk.reset();
    for (auto& chunk : page_permissions_)
        chunk.reset();
    clear_jit_page_table_locked();
    exclusive_write_tracked_pages_.clear();
    exclusive_write_tracking_active_.store(false, std::memory_order_release);
    tracked_write_ranges_.clear();
    write_tracked_pages_.clear();
    mapping_leases_.clear();
    bump_executable_content_generation_locked();
}

AddressSpace::ProtectResult AddressSpace::protect_with_result(
    std::uint32_t address, std::uint32_t size, MemoryPermission permissions)
{
    if (size == 0 || range_overflows(address, size)) {
        return ProtectResult { .succeeded = size == 0 };
    }
    const auto first = page_base(address);
    const auto end = page_range_end(address, size);
    auto lock = write_lock();
    if (!vm_map_.accessible(first, end, MemoryPermission::None))
        return { };

    bool executable_permissions_changed = false;
    for (std::uint64_t cursor = first; cursor < end;) {
        const auto region =
            vm_map_.region_at_or_after(static_cast<std::uint32_t>(cursor));
        if (!region || region->address > cursor || region->end <= cursor) {
            return { };
        }
        if (region->permissions != permissions &&
            (has_permission(region->permissions, MemoryPermission::Execute) ||
                has_permission(permissions, MemoryPermission::Execute))) {
            executable_permissions_changed = true;
        }
        cursor = std::min(region->end, end);
    }

    if (!vm_map_.protect(first, end, permissions))
        return { };
    set_page_permissions_locked(first, end, permissions);
    if (has_permission(permissions, MemoryPermission::Write)) {
        ensure_unique_page_map_locked();
        auto page = pages_->lower_bound(first);
        while (page != pages_->end() && page->first < end) {
            if (page->second.file_writeback_capable) {
                page->second.file_writeback = true;
            }
            ++page;
        }
    }
    refresh_jit_page_range_locked(first, end);
    if (executable_permissions_changed)
        bump_executable_content_generation_locked();
    return ProtectResult {
        .succeeded = true,
        .executable_permissions_changed = executable_permissions_changed,
    };
}

bool AddressSpace::protect(
    std::uint32_t address, std::uint32_t size, MemoryPermission permissions)
{
    return protect_with_result(address, size, permissions).succeeded;
}

bool AddressSpace::inherit(std::uint32_t address, std::uint32_t size,
    VmInheritance inheritance)
{
    if (size == 0 || range_overflows(address, size))
        return size == 0;
    const auto first = page_base(address);
    const auto end = page_range_end(address, size);
    auto lock = write_lock();
    return vm_map_.inherit(first, end, inheritance);
}

void AddressSpace::mark_translation_profile_stable(
    std::uint32_t address, std::uint32_t size)
{
    if (size == 0 || range_overflows(address, size))
        return;
    const auto first = page_base(address);
    const auto end = page_range_end(address, size);
    auto lock = write_lock();
    if (!vm_map_.accessible(first, end, MemoryPermission::Execute))
        return;
    if (translation_profile_map_.accessible(
            first, end, MemoryPermission::Execute)) {
        return;
    }
    translation_profile_map_.map_or(first, end, MemoryPermission::Execute);
    auto generation =
        translation_profile_mapping_generation_.load(std::memory_order_relaxed);
    if (++generation == 0U)
        generation = 1U;
    translation_profile_mapping_generation_.store(
        generation, std::memory_order_release);
}

bool AddressSpace::translation_profile_stable(
    std::uint32_t address, std::size_t size) const
{
    if (size == 0 || range_overflows(address, size))
        return false;
    const auto end = static_cast<std::uint64_t>(address) + size;
    auto lock = read_lock();
    return vm_map_.accessible(address, end, MemoryPermission::Execute) &&
           translation_profile_map_.accessible(
               address, end, MemoryPermission::Execute);
}

bool AddressSpace::copy_in(
    std::uint32_t address, std::span<const std::byte> data)
{
    const CopyInOperation operation { address, data };
    return copy_in_batch(std::span<const CopyInOperation> { &operation, 1U });
}

bool AddressSpace::copy_in_batch(std::span<const CopyInOperation> operations)
{
    if (operations.empty())
        return true;
    const bool collect_stats = performance_counters().enabled();
    if (collect_stats) {
        write_batch_calls.fetch_add(1, std::memory_order_relaxed);
        write_batch_operations.fetch_add(
            operations.size(), std::memory_order_relaxed);
    }
    auto lock = write_lock();
    for (const auto& operation : operations) {
        if (operation.data.size() > std::numeric_limits<std::uint32_t>::max() ||
            range_overflows(operation.address, operation.data.size()) ||
            !range_accessible_locked(operation.address, operation.data.size(),
                MemoryPermission::None)) {
            if (collect_stats)
                write_batch_failures.fetch_add(1, std::memory_order_relaxed);
            return false;
        }
    }

    // Small host-to-guest spans commonly stay on one page. Preserve the same
    // copy-on-write, reservation and generation updates without allocating
    // vectors and sorting a one-element page set for each scanline.
    if (operations.size() == 1U) {
        const auto& operation = operations.front();
        const auto offset = operation.address & (page_size - 1U);
        if (!operation.data.empty() &&
            operation.data.size() <= page_size - offset) {
            ensure_unique_page_map_locked();
            auto* resident = find_page_locked(operation.address);
            auto& page = resident != nullptr && resident->backing
                             ? *resident
                             : ensure_page_locked(operation.address);
            auto& backing = writable_backing_locked(page);
            std::copy(operation.data.begin(), operation.data.end(),
                backing.bytes.begin() + offset);
            mark_shared_backing_written_locked(
                page, offset, operation.data.size());
            refresh_jit_page_locked(operation.address);
            mark_written_locked(operation.address, operation.data.size());
            if (collect_stats)
                write_touched_pages.fetch_add(1U, std::memory_order_relaxed);
            return true;
        }
    }

    std::vector<std::uint32_t> touched_pages;
    touched_pages.reserve(operations.size());
    std::vector<WrittenRange> written_ranges;
    written_ranges.reserve(operations.size());
    for (const auto& operation : operations) {
        if (operation.data.empty())
            continue;
        written_ranges.push_back(WrittenRange { operation.address,
            static_cast<std::uint32_t>(operation.data.size()) });
        std::size_t copied = 0;
        while (copied < operation.data.size()) {
            const auto current =
                operation.address + static_cast<std::uint32_t>(copied);
            auto& page = ensure_page_locked(current);
            const auto offset = current & (page_size - 1U);
            const auto chunk = std::min<std::size_t>(
                page_size - offset, operation.data.size() - copied);
            auto& backing = writable_backing_locked(page);
            std::copy_n(
                operation.data.begin() + static_cast<std::ptrdiff_t>(copied),
                chunk, backing.bytes.begin() + offset);
            mark_shared_backing_written_locked(page, offset, chunk);
            touched_pages.push_back(page_base(current));
            copied += chunk;
        }
    }
    std::sort(touched_pages.begin(), touched_pages.end());
    touched_pages.erase(std::unique(touched_pages.begin(), touched_pages.end()),
        touched_pages.end());
    if (collect_stats)
        write_touched_pages.fetch_add(
            touched_pages.size(), std::memory_order_relaxed);
    for (const auto page_address : touched_pages) {
        auto* page = find_page_locked(page_address);
        if (page == nullptr)
            continue;
        refresh_jit_page_locked(page_address);
    }
    mark_written_batch_locked(written_ranges);
    return true;
}

bool AddressSpace::copy_out(
    std::uint32_t address, std::span<std::byte> data) const
{
    if (range_overflows(address, data.size())) {
        return false;
    }
    if (data.empty())
        return true;
    for (;;) {
        {
            auto lock = read_lock();
            if (!range_accessible_locked(
                    address, data.size(), MemoryPermission::Read)) {
                return false;
            }
            if (!range_needs_file_fault_locked(address, data.size())) {
                std::size_t copied = 0;
                while (copied < data.size()) {
                    const auto current =
                        address + static_cast<std::uint32_t>(copied);
                    const auto* page = find_page_locked(current);
                    const auto offset = current & (page_size - 1U);
                    const auto chunk = std::min<std::size_t>(
                        page_size - offset, data.size() - copied);
                    if (page != nullptr && page->backing) {
                        std::copy_n(page->backing->bytes.begin() + offset,
                            chunk,
                            data.begin() + static_cast<std::ptrdiff_t>(copied));
                    } else {
                        std::fill_n(
                            data.begin() + static_cast<std::ptrdiff_t>(copied),
                            chunk, std::byte { });
                    }
                    copied += chunk;
                }
                return true;
            }
        }
        if (!const_cast<AddressSpace*>(this)->fault_file_pages(
                address, data.size())) {
            return false;
        }
    }
}

bool AddressSpace::map_file(std::uint32_t address, std::uint32_t size,
    MemoryPermission permissions, const std::filesystem::path& path,
    std::uint64_t file_offset,
    std::optional<GuestFileGeneration> expected_generation,
    std::optional<ContentIdentity> expected_content_identity,
    std::shared_ptr<const std::vector<std::byte>> immutable_snapshot,
    std::shared_ptr<const ImmutableFileView> immutable_file_view,
    FileMappingBatchContext* batch_context)
{
    if (size == 0 || range_overflows(address, size) ||
        address % page_size != 0 || file_offset % page_size != 0) {
        return false;
    }
    const auto backing = file_page_cache_->open_mapping(path, file_offset, size,
        std::move(expected_generation), std::move(expected_content_identity),
        std::move(immutable_snapshot), std::move(immutable_file_view),
        batch_context ? batch_context->backing
                      : std::shared_ptr<const GuestFileBacking> { });
    if (!backing)
        return false;

    auto lock = write_lock();
    const auto end = page_range_end(address, size);
    if (vm_map_.overlaps(address, end))
        return false;
    invalidate_mapping_leases_locked(address, end);
    const auto [mapping, inserted] = file_mappings_.emplace(
        address, FileMapping { end, file_offset, *backing });
    static_cast<void>(mapping);
    if (!inserted)
        return false;
    vm_map_.map_or(address, end, permissions);
    // map_file rejects any overlapping VM range, so the new pages have no
    // permissions to preserve. Use the range setter; unlike the OR path used
    // by map(), it can fill sparse permission chunks in bulk.
    set_page_permissions_locked(address, end, permissions);
    bump_executable_content_generation_locked();
    if (batch_context && !batch_context->backing)
        batch_context->backing = *backing;
    return true;
}

std::optional<std::vector<std::shared_ptr<GuestPageBacking>>>
AddressSpace::share_pages(std::uint32_t address, std::uint32_t size)
{
    if (size == 0 || address % page_size != 0 || size % page_size != 0 ||
        range_overflows(address, size)) {
        return std::nullopt;
    }

    auto lock = write_lock();
    const auto end = page_range_end(address, size);
    if (!range_accessible_locked(address, size, MemoryPermission::None))
        return std::nullopt;

    std::vector<std::shared_ptr<GuestPageBacking>> result;
    result.reserve(size / page_size);
    share_pages_locked(address, end, &result);
    return result;
}

void AddressSpace::share_pages_locked(std::uint32_t address, std::uint64_t end,
    std::vector<std::shared_ptr<GuestPageBacking>>* output)
{
    const auto initial_tracking_epoch =
        GuestPageBacking::shared_write_tracking_epoch();
    std::size_t tracking_transitions = 0;
    bool has_tracked_shared_backing = false;
    bool tracked_backing_may_have_aliases = false;
    for (std::uint64_t base = address; base < end; base += page_size) {
        auto& page = ensure_page_locked(static_cast<std::uint32_t>(base));
        if (!page.backing) {
            page.backing = std::make_shared<GuestPageBacking>();
        } else if (page.file_cached ||
                   (page.copy_on_write_possible && !page.shared_writable &&
                       page.backing.use_count() != 1)) {
            page.backing = std::make_shared<GuestPageBacking>(*page.backing);
        }
        page.file_cached = false;
        page.shared_writable = true;
        page.copy_on_write_possible = false;
        if (tracks_write_locked(static_cast<std::uint32_t>(base), page_size)) {
            // A private page has no other virtual alias whose direct JIT write
            // entry can become stale. refresh_jit_page_locked below handles
            // this mapping directly; retain the full scan only for genuinely
            // shared backings or a concurrently published tracking transition.
            tracked_backing_may_have_aliases |= page.backing.use_count() != 1;
            if (page.backing->enable_shared_write_tracking())
                ++tracking_transitions;
            has_tracked_shared_backing = true;
        }
        refresh_jit_page_locked(static_cast<std::uint32_t>(base));
        if (output)
            output->push_back(page.backing);
    }
    if (has_tracked_shared_backing) {
        finish_shared_write_tracking_locked(initial_tracking_epoch,
            tracking_transitions, tracked_backing_may_have_aliases);
    }
    bump_executable_content_generation_locked();
}

bool AddressSpace::map_page_backings(std::uint32_t address, std::uint32_t size,
    MemoryPermission permissions,
    std::span<const std::shared_ptr<GuestPageBacking>> backings,
    PageMappingMode mode, std::uint64_t* mapping_lease_token)
{
    if (mapping_lease_token)
        *mapping_lease_token = 0;
    if (size == 0 || address % page_size != 0 || size % page_size != 0 ||
        range_overflows(address, size) || backings.size() != size / page_size ||
        std::any_of(backings.begin(), backings.end(),
            [](const auto& backing) { return !backing; })) {
        return false;
    }

    auto lock = write_lock();
    const auto end = page_range_end(address, size);
    if (vm_map_.overlaps(address, end))
        return false;
    invalidate_mapping_leases_locked(address, end);
    const auto shared_writable = mode != PageMappingMode::CopyOnWrite;
    const auto initial_tracking_epoch =
        GuestPageBacking::shared_write_tracking_epoch();
    std::size_t tracking_transitions = 0;
    ensure_unique_page_map_locked();
    for (std::size_t index = 0; index < backings.size(); ++index) {
        const auto base =
            address + static_cast<std::uint32_t>(index * page_size);
        if (pages_->contains(base))
            return false;
    }
    bool has_tracked_shared_backing = false;
    for (std::size_t index = 0; index < backings.size(); ++index) {
        const auto base =
            address + static_cast<std::uint32_t>(index * page_size);
        const auto file_writeback_capable =
            mode == PageMappingMode::SharedFile &&
            backings[index]->file_backed();
        const auto file_writeback =
            file_writeback_capable &&
            has_permission(permissions, MemoryPermission::Write);
        auto [page, inserted] = pages_->emplace(base,
            Page { backings[index], 0, false, shared_writable,
                file_writeback_capable, file_writeback, !shared_writable });
        static_cast<void>(inserted);
        if (shared_writable && tracks_write_locked(base, page_size)) {
            if (page->second.backing->enable_shared_write_tracking())
                ++tracking_transitions;
            has_tracked_shared_backing = true;
        }
        cache_page_locked(base, page->second);
    }
    vm_map_.map_or(address, end, permissions);
    add_page_permissions_locked(address, end, permissions);
    if (has_tracked_shared_backing) {
        // Imported backings are supplied by an existing shared object and can
        // already have aliases in this task.
        finish_shared_write_tracking_locked(
            initial_tracking_epoch, tracking_transitions, true);
    }
    refresh_jit_page_range_locked(address, end);
    bump_executable_content_generation_locked();
    if (mapping_lease_token) {
        auto token = next_mapping_lease_token_++;
        if (token == 0U)
            token = next_mapping_lease_token_++;
        while (mapping_leases_.contains(token)) {
            token = next_mapping_lease_token_++;
            if (token == 0U)
                token = next_mapping_lease_token_++;
        }
        mapping_leases_.emplace(token, MappingLease { address, end });
        *mapping_lease_token = token;
    }
    return true;
}

bool AddressSpace::unmap_mapping_lease(std::uint64_t mapping_lease_token)
{
    if (mapping_lease_token == 0U)
        return false;
    auto lock = write_lock();
    const auto lease = mapping_leases_.find(mapping_lease_token);
    if (lease == mapping_leases_.end())
        return false;
    const auto range = lease->second;
    mapping_leases_.erase(lease);
    invalidate_mapping_leases_locked(range.begin, range.end);
    unmap_range_locked(range.begin, range.end);
    return true;
}

std::optional<std::vector<std::byte>> AddressSpace::read_bytes(
    std::uint32_t address, std::size_t size) const
{
    for (;;) {
        {
            auto lock = read_lock();
            if (!range_accessible_locked(
                    address, size, MemoryPermission::Read)) {
                return std::nullopt;
            }
            if (!range_needs_file_fault_locked(address, size)) {
                std::vector<std::byte> result(size);
                std::size_t copied = 0;
                while (copied < size) {
                    const auto current =
                        address + static_cast<std::uint32_t>(copied);
                    const auto* page = find_page_locked(current);
                    const auto offset = current & (page_size - 1U);
                    const auto chunk = std::min<std::size_t>(
                        page_size - offset, size - copied);
                    if (page != nullptr && page->backing) {
                        std::copy_n(page->backing->bytes.begin() + offset,
                            chunk,
                            result.begin() +
                                static_cast<std::ptrdiff_t>(copied));
                    } else {
                        std::fill_n(result.begin() +
                                        static_cast<std::ptrdiff_t>(copied),
                            chunk, std::byte { });
                    }
                    copied += chunk;
                }
                return result;
            }
        }
        if (!const_cast<AddressSpace*>(this)->fault_file_pages(address, size)) {
            return std::nullopt;
        }
    }
}

std::optional<std::string> AddressSpace::read_c_string(
    std::uint32_t address, std::size_t maximum_size) const
{
    std::string result;
    result.reserve(std::min<std::size_t>(maximum_size, 256));
    std::size_t consumed = 0;
    while (consumed < maximum_size) {
        if (range_overflows(address, consumed + 1U))
            return std::nullopt;
        const auto current = address + static_cast<std::uint32_t>(consumed);
        bool needs_fault = false;
        {
            auto lock = read_lock();
            if (!range_accessible_locked(current, 1, MemoryPermission::Read)) {
                return std::nullopt;
            }
            const auto* page = find_page_locked(current);
            if ((page == nullptr || !page->backing) &&
                find_file_mapping_locked(current) != nullptr) {
                needs_fault = true;
            } else {
                const auto offset = current & (page_size - 1U);
                const auto chunk = std::min<std::size_t>(
                    page_size - offset, maximum_size - consumed);
                if (page == nullptr || !page->backing)
                    return result;
                for (std::size_t index = 0; index < chunk; ++index) {
                    const auto value = std::to_integer<char>(
                        page->backing->bytes[offset + index]);
                    if (value == '\0')
                        return result;
                    result.push_back(value);
                }
                consumed += chunk;
            }
        }
        if (needs_fault &&
            !const_cast<AddressSpace*>(this)->fault_file_pages(current, 1)) {
            return std::nullopt;
        }
    }
    return std::nullopt;
}

const AddressSpace::Page* AddressSpace::find_page_locked(
    std::uint32_t address) const
{
    const auto index = static_cast<std::size_t>(address / page_size);
    const auto& chunk = page_lookup_[index / page_lookup_chunk_size];
    return chunk ? (*chunk)[index % page_lookup_chunk_size] : nullptr;
}

AddressSpace::Page* AddressSpace::find_page_locked(std::uint32_t address)
{
    const auto index = static_cast<std::size_t>(address / page_size);
    const auto& chunk = page_lookup_[index / page_lookup_chunk_size];
    return chunk ? (*chunk)[index % page_lookup_chunk_size] : nullptr;
}

const AddressSpace::FileMapping* AddressSpace::find_file_mapping_locked(
    std::uint32_t address) const
{
    const auto after = file_mappings_.upper_bound(address);
    if (after == file_mappings_.begin())
        return nullptr;
    const auto mapping = std::prev(after);
    return address < mapping->second.end ? &mapping->second : nullptr;
}

AddressSpace::Page& AddressSpace::ensure_page_locked(std::uint32_t address)
{
    ensure_unique_page_map_locked();
    const auto base = page_base(address);
    auto [page, inserted] = pages_->try_emplace(base);
    if (!page->second.backing) {
        if (const auto* mapping = find_file_mapping_locked(base)) {
            performance_counters().record_page_miss();
            const auto mapping_start = static_cast<std::uint64_t>(
                std::prev(file_mappings_.upper_bound(base))->first);
            const auto file_offset =
                mapping->file_offset +
                (static_cast<std::uint64_t>(base) - mapping_start);
            const auto byte_count =
                static_cast<std::uint32_t>(std::min<std::uint64_t>(
                    page_size, mapping->backing->end_offset - file_offset));
            auto backing = file_page_cache_->load_page(
                mapping->backing, file_offset, byte_count);
            // A resident AddressSpace page always owns fully initialized bytes.
            // Page-in remains lazy at the range level, while ordinary guest
            // reads no longer re-enter GuestPageBacking's one-time
            // materialization lock.
            backing->materialize();
            page->second.backing = std::move(backing);
            page->second.file_cached = true;
            page->second.copy_on_write_possible = true;
        }
    }
    if (inserted)
        cache_page_locked(base, page->second);
    return page->second;
}

bool AddressSpace::range_needs_file_fault_locked(
    std::uint32_t address, std::size_t size) const
{
    if (size == 0 || range_overflows(address, size))
        return false;
    const auto first = page_base(address);
    const auto end = page_range_end(address, size);
    for (std::uint64_t base = first; base < end; base += page_size) {
        const auto current = static_cast<std::uint32_t>(base);
        const auto* page = find_page_locked(current);
        if ((page == nullptr || !page->backing) &&
            find_file_mapping_locked(current) != nullptr) {
            return true;
        }
    }
    return false;
}

bool AddressSpace::fault_file_pages(std::uint32_t address, std::size_t size)
{
    if (size == 0 || range_overflows(address, size))
        return size == 0;
    auto lock = write_lock();
    if (!range_accessible_locked(address, size, MemoryPermission::None)) {
        return false;
    }
    ensure_unique_page_map_locked();
    const auto first = page_base(address);
    const auto end = page_range_end(address, size);
    for (std::uint64_t base = first; base < end; base += page_size) {
        const auto current = static_cast<std::uint32_t>(base);
        const auto* page = find_page_locked(current);
        if (page != nullptr && page->backing)
            continue;

        const auto mapping_after = file_mappings_.upper_bound(current);
        if (mapping_after == file_mappings_.begin())
            continue;
        const auto mapping_entry = std::prev(mapping_after);
        const auto mapping_start = mapping_entry->first;
        const auto& mapping = mapping_entry->second;
        if (current >= mapping.end)
            continue;
        performance_counters().record_page_miss();

        constexpr std::uint64_t cluster_bytes =
            guest_file_prefetch_pages * page_size;
        const auto current_file_offset =
            mapping.file_offset +
            (static_cast<std::uint64_t>(current) - mapping_start);
        const auto cluster_file_start =
            std::max<std::uint64_t>(mapping.backing->first_offset,
                current_file_offset & ~(cluster_bytes - 1U));
        const auto cluster_file_end = std::min<std::uint64_t>(
            mapping.backing->end_offset, cluster_file_start + cluster_bytes);
        const auto cluster_guest_start =
            static_cast<std::uint64_t>(mapping_start) +
            (cluster_file_start - mapping.file_offset);

        for (std::uint64_t file_page = cluster_file_start,
                           guest_page = cluster_guest_start;
            file_page < cluster_file_end && guest_page < mapping.end;
            file_page += page_size, guest_page += page_size) {
            const auto guest_base = static_cast<std::uint32_t>(guest_page);
            auto [resident, inserted] = pages_->try_emplace(guest_base);
            if (!resident->second.backing) {
                const auto byte_count =
                    static_cast<std::uint32_t>(std::min<std::uint64_t>(
                        page_size, cluster_file_end - file_page));
                auto backing = file_page_cache_->load_page(
                    mapping.backing, file_page, byte_count);
                // The vnode-style cluster fault publishes ready pages as one
                // unit. Descriptor-backed mappings perform one host read for
                // the cluster; immutable executable mappings copy each page
                // from their snapshot.
                backing->materialize();
                resident->second.backing = std::move(backing);
                resident->second.file_cached = true;
                resident->second.copy_on_write_possible = true;
            }
            if (inserted)
                cache_page_locked(guest_base, resident->second);
            refresh_jit_page_locked(guest_base);
        }
    }
    return true;
}

void AddressSpace::unmap_file_mappings_locked(
    std::uint32_t address, std::uint64_t end)
{
    if (file_mappings_.empty())
        return;
    auto mapping = file_mappings_.lower_bound(address);
    if (mapping != file_mappings_.begin()) {
        const auto previous = std::prev(mapping);
        if (previous->second.end > address)
            mapping = previous;
    }

    std::vector<std::pair<std::uint32_t, FileMapping>> replacements;
    const auto make_backing = [](const GuestFileBacking& source,
                                  std::uint64_t first_offset,
                                  std::uint64_t end_offset) {
        auto backing = std::make_shared<GuestFileBacking>(
            source.path, first_offset, end_offset);
        backing->cache_path = source.cache_path;
        backing->file_size = source.file_size;
        backing->modified = source.modified;
        backing->generation = source.generation;
        backing->generation_revision = source.generation_revision;
        backing->content_identity = source.content_identity;
        backing->immutable_snapshot = source.immutable_snapshot;
        backing->immutable_file_view = source.immutable_file_view;
        backing->generation_registry = source.generation_registry;
        backing->io_state = source.io_state;
        return backing;
    };

    while (mapping != file_mappings_.end() && mapping->first < end) {
        const auto start = mapping->first;
        const auto source = mapping->second;
        if (source.end <= address) {
            ++mapping;
            continue;
        }
        mapping = file_mappings_.erase(mapping);

        if (start < address) {
            const auto left_file_end =
                std::min<std::uint64_t>(source.backing->end_offset,
                    source.file_offset +
                        (static_cast<std::uint64_t>(address) - start));
            replacements.emplace_back(
                start, FileMapping { address, source.file_offset,
                           make_backing(*source.backing, source.file_offset,
                               left_file_end) });
        }
        if (source.end > end) {
            const auto right_start = static_cast<std::uint32_t>(end);
            const auto right_file_offset =
                source.file_offset + (end - static_cast<std::uint64_t>(start));
            replacements.emplace_back(right_start,
                FileMapping { source.end, right_file_offset,
                    make_backing(*source.backing, right_file_offset,
                        source.backing->end_offset) });
        }
    }
    for (auto& replacement : replacements) {
        file_mappings_.emplace(
            replacement.first, std::move(replacement.second));
    }
}

void AddressSpace::cache_page_locked(std::uint32_t address, Page& page)
{
    const auto index = static_cast<std::size_t>(address / page_size);
    auto& chunk = page_lookup_[index / page_lookup_chunk_size];
    if (!chunk)
        chunk = std::make_unique<PageLookupChunk>();
    (*chunk)[index % page_lookup_chunk_size] = &page;
}

void AddressSpace::uncache_page_locked(std::uint32_t address)
{
    const auto index = static_cast<std::size_t>(address / page_size);
    auto& chunk = page_lookup_[index / page_lookup_chunk_size];
    if (chunk)
        (*chunk)[index % page_lookup_chunk_size] = nullptr;
}

void AddressSpace::ensure_unique_page_map_locked()
{
    if (pages_.use_count() == 1)
        return;
    pages_ = std::make_shared<PageMap>(*pages_);
    rebuild_page_lookup_locked();
}

void AddressSpace::rebuild_page_lookup_locked()
{
    for (auto& chunk : page_lookup_)
        chunk.reset();
    for (auto& [address, page] : *pages_)
        cache_page_locked(address, page);
}

void AddressSpace::ensure_jit_page_tables_locked()
{
    if (jit_read_page_table_ && jit_write_page_table_)
        return;
    if (!jit_read_page_table_)
        jit_read_page_table_ = std::make_unique<JitPageTableStorage>();
    if (!jit_write_page_table_)
        jit_write_page_table_ = std::make_unique<JitPageTableStorage>();
    direct_jit_write_pages_.clear();
    for (const auto& [address, page] : *pages_) {
        static_cast<void>(page);
        refresh_jit_page_locked(address);
    }
}

void AddressSpace::refresh_jit_page_locked(std::uint32_t address)
{
    if (!jit_read_page_table_ && !jit_write_page_table_)
        return;
    const auto base = page_base(address);
    auto* read_entry = jit_read_page_table_
                           ? &jit_read_page_table_->entries()[base / page_size]
                           : nullptr;
    auto* write_entry =
        jit_write_page_table_
            ? &jit_write_page_table_->entries()[base / page_size]
            : nullptr;
    if (read_entry)
        *read_entry = nullptr;
    if (write_entry) {
        if (*write_entry != nullptr) {
            *write_entry = nullptr;
            direct_jit_write_pages_.erase(base);
        }
    }
    if (!jit_page_table_enabled_)
        return;

    const auto flags = page_permission_locked(base / page_size);
    constexpr auto read_required = static_cast<std::uint8_t>(
        mapped_page_flag | permission_bits(MemoryPermission::Read));
    const auto* page = find_page_locked(base);
    // The table is selected only while this address space is exclusively
    // owned. Shared mappings still require their backing's synchronization.
    const bool direct_read_safe = !parallel_access_ ||
        (page != nullptr && !page->shared_writable && page->backing &&
            !page->backing->shared_write_tracking_enabled());
    if (read_entry && direct_read_safe &&
        (flags & read_required) == read_required && page != nullptr &&
        page->backing) {
        *read_entry = jit_page_pointer(*page->backing, base);
    }

    constexpr auto write_required = static_cast<std::uint8_t>(
        mapped_page_flag | permission_bits(MemoryPermission::Read) |
        permission_bits(MemoryPermission::Write));
    if (!jit_write_page_table_enabled_ || !write_entry ||
        (parallel_access_ && page != nullptr && page->shared_writable) ||
        (flags & write_required) != write_required ||
        tracks_write_locked(base, page_size) ||
        (page != nullptr && page->backing &&
            page->backing->shared_write_tracking_enabled())) {
        return;
    }
    if (page == nullptr || !page->backing || page->file_cached ||
        (page->copy_on_write_possible && !page->shared_writable)) {
        return;
    }
    if (exclusive_write_tracked_pages_.contains(base))
        return;
    *write_entry = jit_page_pointer(*page->backing, base);
    direct_jit_write_pages_.insert(base);
}

void AddressSpace::refresh_jit_page_range_locked(
    std::uint32_t address, std::uint64_t end)
{
    if ((!jit_read_page_table_ && !jit_write_page_table_) || end <= address) {
        return;
    }
    const auto first = page_base(address);
    for (std::uint64_t base = first; base < end; base += page_size) {
        refresh_jit_page_locked(static_cast<std::uint32_t>(base));
    }
}

void AddressSpace::invalidate_shared_write_jit_pages_locked()
{
    if (!jit_write_page_table_)
        return;
    auto** entries = jit_write_page_table_->entries();
    for (auto address = direct_jit_write_pages_.begin();
        address != direct_jit_write_pages_.end();) {
        const auto* page = find_page_locked(*address);
        if (page && page->backing &&
            page->backing->shared_write_tracking_enabled()) {
            entries[*address / page_size] = nullptr;
            address = direct_jit_write_pages_.erase(address);
        } else {
            ++address;
        }
    }
}

void AddressSpace::finish_shared_write_tracking_locked(
    std::uint64_t initial_epoch, std::size_t local_transitions,
    bool backing_may_have_aliases)
{
    // Capture before scanning. A transition racing after this point retains a
    // newer epoch and is handled by the next execution safe point.
    const auto observed_epoch = GuestPageBacking::shared_write_tracking_epoch();
    const auto expected_epoch =
        initial_epoch + static_cast<std::uint64_t>(local_transitions);
    if (backing_may_have_aliases || observed_epoch != expected_epoch)
        invalidate_shared_write_jit_pages_locked();
    observed_shared_write_tracking_epoch_.store(
        observed_epoch, std::memory_order_release);
}

void AddressSpace::clear_jit_page_table_locked()
{
    if (jit_read_page_table_)
        jit_read_page_table_->clear();
    if (jit_write_page_table_)
        jit_write_page_table_->clear();
    direct_jit_write_pages_.clear();
}

std::byte AddressSpace::read_byte_locked(const Page* page, std::uint32_t offset)
{
    if (page == nullptr || !page->backing)
        return std::byte { };
    return page->backing->bytes[offset];
}

GuestPageBacking& AddressSpace::writable_backing_locked(
    Page& page, bool* jit_eligibility_changed)
{
    const bool eligibility_changed =
        !page.backing || page.file_cached || page.copy_on_write_possible;
    if (!page.backing) {
        page.backing = std::make_shared<GuestPageBacking>();
    } else {
        if (page.file_cached ||
            (page.copy_on_write_possible && !page.shared_writable &&
                page.backing.use_count() != 1)) {
            if (performance_counters().enabled())
                write_copy_on_write_detaches.fetch_add(
                    1, std::memory_order_relaxed);
            page.backing = std::make_shared<GuestPageBacking>(*page.backing);
        }
    }
    page.file_cached = false;
    page.copy_on_write_possible = false;
    if (jit_eligibility_changed)
        *jit_eligibility_changed = eligibility_changed;
    return *page.backing;
}

AddressSpaceWriteStats address_space_write_stats() noexcept
{
    return AddressSpaceWriteStats { write_batch_calls.load(
                                        std::memory_order_relaxed),
        write_batch_operations.load(std::memory_order_relaxed),
        write_batch_failures.load(std::memory_order_relaxed),
        write_touched_pages.load(std::memory_order_relaxed),
        write_copy_on_write_detaches.load(std::memory_order_relaxed) };
}

bool AddressSpace::reservation_invalidation_required_locked(
    const Page& page) const noexcept
{
    // A serialized address space has no reservation to invalidate once its
    // last exclusive page marker is consumed. Shared physical pages can carry
    // a reservation from another address-space alias, while parallel execution
    // and modes without the guarded direct-write table cannot make that proof.
    return page.shared_writable ||
           (page.backing && page.backing->shared_write_tracking_enabled()) ||
           parallel_access_ || !jit_write_page_table_enabled_ ||
           exclusive_write_tracking_active_.load(std::memory_order_relaxed);
}

void AddressSpace::mark_shared_backing_written_locked(
    Page& page, std::uint32_t offset, std::size_t size)
{
    if (page.backing) {
        if (reservation_invalidation_required_locked(page))
            page.backing->invalidate_reservation_identity(offset, size);
        page.backing->mark_shared_write();
    }
    if (exclusive_write_observer_)
        exclusive_write_observer_();
}

bool AddressSpace::tracks_write_locked(
    std::uint32_t address, std::size_t size) const
{
    if (write_tracked_pages_.empty() || size == 0)
        return false;
    const auto end = static_cast<std::uint64_t>(address) + size;
    for (std::uint64_t base = page_base(address); base < end;
        base += page_size) {
        if (write_tracked_pages_.contains(static_cast<std::uint32_t>(base)))
            return true;
    }
    return false;
}

void AddressSpace::mark_written_locked(std::uint32_t address, std::size_t size)
{
    if (size == 0)
        return;
    const auto range =
        WrittenRange { address, static_cast<std::uint32_t>(size) };
    mark_written_batch_locked(std::span<const WrittenRange> { &range, 1U });
}

void AddressSpace::mark_written_batch_locked(
    std::span<const WrittenRange> ranges)
{
    bool executable_write = false;
    for (const auto& range : ranges) {
        if (range.size == 0U)
            continue;
        const auto end = static_cast<std::uint64_t>(range.address) + range.size;
        if (vm_map_.accessible(range.address, end, MemoryPermission::Execute)) {
            executable_write = true;
        }
        if (!tracks_write_locked(range.address, range.size))
            continue;
        ++write_generation_;
        const auto first = page_base(range.address);
        const auto last = page_base(
            range.address + static_cast<std::uint32_t>(range.size - 1U));
        for (std::uint64_t base = first; base <= last; base += page_size) {
            auto* page = find_page_locked(static_cast<std::uint32_t>(base));
            if (page != nullptr)
                page->write_generation = write_generation_;
        }
    }
    if (executable_write)
        bump_executable_content_generation_locked();
}

void AddressSpace::bump_executable_content_generation_locked() noexcept
{
    const auto previous =
        executable_content_generation_.fetch_add(1U, std::memory_order_release);
    if (previous == std::numeric_limits<std::uint64_t>::max()) {
        executable_content_generation_.store(1U, std::memory_order_release);
    }
}

bool AddressSpace::range_accessible_locked(
    std::uint32_t address, std::size_t size, MemoryPermission access) const
{
    if (range_overflows(address, size)) {
        return false;
    }
    if (size == 0) {
        return true;
    }
    const auto first = page_base(address);
    const auto end = page_range_end(address, size);
    const auto required = permission_bits(access);
    for (std::uint64_t base = first; base < end; base += page_size) {
        const auto flags = page_permission_locked(base / page_size);
        if ((flags & mapped_page_flag) == 0U || (flags & required) != required)
            return false;
    }
    return true;
}

template <typename T>
std::optional<T> AddressSpace::read_integer(
    std::uint32_t address, MemoryPermission access) const
{
    static_assert(std::is_unsigned_v<T>);
    for (;;) {
        {
            auto lock = read_lock();
            if (!range_accessible_locked(address, sizeof(T), access)) {
                return std::nullopt;
            }
            const auto offset = address & (page_size - 1U);
            if (offset <= page_size - sizeof(T)) {
                const auto* page = find_page_locked(address);
                if (page != nullptr && page->backing) {
                    T value = 0;
                    for (std::size_t index = 0; index < sizeof(T); ++index) {
                        value |= static_cast<T>(
                            std::to_integer<T>(
                                page->backing->bytes[offset + index])
                            << (index * 8U));
                    }
                    return value;
                }
                if (find_file_mapping_locked(address) == nullptr)
                    return T { };
            } else if (!range_needs_file_fault_locked(address, sizeof(T))) {
                T value = 0;
                for (std::size_t i = 0; i < sizeof(T); ++i) {
                    const auto current =
                        address + static_cast<std::uint32_t>(i);
                    const auto* page = find_page_locked(current);
                    const auto byte = std::to_integer<T>(
                        read_byte_locked(page, current & (page_size - 1U)));
                    value |= static_cast<T>(byte << (i * 8U));
                }
                return value;
            }
        }
        if (!const_cast<AddressSpace*>(this)->fault_file_pages(
                address, sizeof(T))) {
            return std::nullopt;
        }
    }
}

template <typename T>
bool AddressSpace::write_integer(std::uint32_t address, T value)
{
    static_assert(std::is_unsigned_v<T>);
    auto lock = write_lock();
    if (!range_accessible_locked(address, sizeof(T), MemoryPermission::Write)) {
        return false;
    }
    ensure_unique_page_map_locked();
    const auto offset = address & (page_size - 1U);
    if (offset <= page_size - sizeof(T)) {
        auto* resident = find_page_locked(address);
        auto& page = resident != nullptr && resident->backing
                         ? *resident
                         : ensure_page_locked(address);
        bool jit_eligibility_changed = false;
        auto& backing = writable_backing_locked(page, &jit_eligibility_changed);
        if (jit_eligibility_changed)
            refresh_jit_page_locked(address);
        for (std::size_t index = 0; index < sizeof(T); ++index) {
            backing.bytes[offset + index] = static_cast<std::byte>(
                (value >> (index * 8U)) & static_cast<T>(0xffU));
        }
        mark_shared_backing_written_locked(page, offset, sizeof(T));
        if (tracks_write_locked(address, sizeof(T))) {
            page.write_generation = ++write_generation_;
        }
        // Invalidate the physical reservation before removing its virtual
        // page guard. The refresh can then restore only an otherwise eligible
        // direct-write entry without a second AddressSpace pass.
        release_exclusive_write_tracking_locked(address, sizeof(T));
        return true;
    }
    for (std::size_t i = 0; i < sizeof(T); ++i) {
        const auto current = address + static_cast<std::uint32_t>(i);
        auto* resident = find_page_locked(current);
        auto& page = resident != nullptr && resident->backing
                         ? *resident
                         : ensure_page_locked(current);
        bool jit_eligibility_changed = false;
        auto& backing = writable_backing_locked(page, &jit_eligibility_changed);
        if (jit_eligibility_changed)
            refresh_jit_page_locked(current);
        backing.bytes[current & (page_size - 1U)] =
            static_cast<std::byte>((value >> (i * 8U)) & static_cast<T>(0xffU));
        mark_shared_backing_written_locked(
            page, current & (page_size - 1U), 1U);
    }
    mark_written_locked(address, sizeof(T));
    release_exclusive_write_tracking_locked(address, sizeof(T));
    return true;
}

template <typename T>
bool AddressSpace::compare_exchange_integer(
    std::uint32_t address, T expected, T value)
{
    static_assert(std::is_unsigned_v<T>);
    auto lock = write_lock();
    if (!range_accessible_locked(address, sizeof(T),
            MemoryPermission::Read | MemoryPermission::Write)) {
        release_exclusive_write_tracking_locked(address, sizeof(T));
        return false;
    }
    ensure_unique_page_map_locked();
    const auto offset = address & (page_size - 1U);
    if (offset <= page_size - sizeof(T)) {
        auto* resident = find_page_locked(address);
        auto& page = resident != nullptr && resident->backing
                         ? *resident
                         : ensure_page_locked(address);
        T current_value = 0;
        for (std::size_t index = 0; index < sizeof(T); ++index) {
            current_value |=
                static_cast<T>(std::to_integer<T>(read_byte_locked(&page,
                                   offset + static_cast<std::uint32_t>(index)))
                               << (index * 8U));
        }
        if (current_value != expected) {
            release_exclusive_write_tracking_locked(address, sizeof(T));
            return false;
        }
        bool jit_eligibility_changed = false;
        auto& backing = writable_backing_locked(page, &jit_eligibility_changed);
        if (jit_eligibility_changed)
            refresh_jit_page_locked(address);
        for (std::size_t index = 0; index < sizeof(T); ++index) {
            backing.bytes[offset + index] = static_cast<std::byte>(
                (value >> (index * 8U)) & static_cast<T>(0xffU));
        }
        mark_shared_backing_written_locked(page, offset, sizeof(T));
        if (tracks_write_locked(address, sizeof(T))) {
            page.write_generation = ++write_generation_;
        }
        release_exclusive_write_tracking_locked(address, sizeof(T));
        return true;
    }
    T current_value = 0;
    for (std::size_t i = 0; i < sizeof(T); ++i) {
        const auto current = address + static_cast<std::uint32_t>(i);
        auto* resident = find_page_locked(current);
        auto& page = resident != nullptr && resident->backing
                         ? *resident
                         : ensure_page_locked(current);
        current_value |= static_cast<T>(std::to_integer<T>(read_byte_locked(
                                            &page, current & (page_size - 1U)))
                                        << (i * 8U));
    }
    if (current_value != expected) {
        release_exclusive_write_tracking_locked(address, sizeof(T));
        return false;
    }
    for (std::size_t i = 0; i < sizeof(T); ++i) {
        const auto current = address + static_cast<std::uint32_t>(i);
        auto* resident = find_page_locked(current);
        auto& page = resident != nullptr && resident->backing
                         ? *resident
                         : ensure_page_locked(current);
        bool jit_eligibility_changed = false;
        auto& backing = writable_backing_locked(page, &jit_eligibility_changed);
        if (jit_eligibility_changed)
            refresh_jit_page_locked(current);
        backing.bytes[current & (page_size - 1U)] =
            static_cast<std::byte>((value >> (i * 8U)) & static_cast<T>(0xffU));
        mark_shared_backing_written_locked(
            page, current & (page_size - 1U), 1U);
    }
    mark_written_locked(address, sizeof(T));
    release_exclusive_write_tracking_locked(address, sizeof(T));
    return true;
}

template <typename T>
std::optional<T> AddressSpace::exchange_integer(std::uint32_t address, T value)
{
    static_assert(std::is_unsigned_v<T>);
    auto lock = write_lock();
    if (!range_accessible_locked(address, sizeof(T),
            MemoryPermission::Read | MemoryPermission::Write)) {
        return std::nullopt;
    }
    ensure_unique_page_map_locked();
    const auto offset = address & (page_size - 1U);
    if (offset <= page_size - sizeof(T)) {
        auto* resident = find_page_locked(address);
        auto& page = resident != nullptr && resident->backing
                         ? *resident
                         : ensure_page_locked(address);
        T previous = 0;
        for (std::size_t index = 0; index < sizeof(T); ++index) {
            previous |=
                static_cast<T>(std::to_integer<T>(read_byte_locked(&page,
                                   offset + static_cast<std::uint32_t>(index)))
                               << (index * 8U));
        }
        bool jit_eligibility_changed = false;
        auto& backing = writable_backing_locked(page, &jit_eligibility_changed);
        if (jit_eligibility_changed)
            refresh_jit_page_locked(address);
        for (std::size_t index = 0; index < sizeof(T); ++index) {
            backing.bytes[offset + index] = static_cast<std::byte>(
                (value >> (index * 8U)) & static_cast<T>(0xffU));
        }
        mark_shared_backing_written_locked(page, offset, sizeof(T));
        if (tracks_write_locked(address, sizeof(T))) {
            page.write_generation = ++write_generation_;
        }
        release_exclusive_write_tracking_locked(address, sizeof(T));
        return previous;
    }
    T previous = 0;
    for (std::size_t index = 0; index < sizeof(T); ++index) {
        const auto current = address + static_cast<std::uint32_t>(index);
        auto* resident = find_page_locked(current);
        auto& page = resident != nullptr && resident->backing
                         ? *resident
                         : ensure_page_locked(current);
        previous |= static_cast<T>(std::to_integer<T>(read_byte_locked(
                                       &page, current & (page_size - 1U)))
                                   << (index * 8U));
    }
    for (std::size_t index = 0; index < sizeof(T); ++index) {
        const auto current = address + static_cast<std::uint32_t>(index);
        auto* resident = find_page_locked(current);
        auto& page = resident != nullptr && resident->backing
                         ? *resident
                         : ensure_page_locked(current);
        bool jit_eligibility_changed = false;
        auto& backing = writable_backing_locked(page, &jit_eligibility_changed);
        if (jit_eligibility_changed)
            refresh_jit_page_locked(current);
        backing.bytes[current & (page_size - 1U)] = static_cast<std::byte>(
            (value >> (index * 8U)) & static_cast<T>(0xffU));
        mark_shared_backing_written_locked(
            page, current & (page_size - 1U), 1U);
    }
    mark_written_locked(address, sizeof(T));
    release_exclusive_write_tracking_locked(address, sizeof(T));
    return previous;
}

std::optional<std::uint8_t> AddressSpace::read8(
    std::uint32_t address, MemoryPermission access) const
{
    return read_integer<std::uint8_t>(address, access);
}
std::optional<std::uint16_t> AddressSpace::read16(
    std::uint32_t address, MemoryPermission access) const
{
    return read_integer<std::uint16_t>(address, access);
}
std::optional<std::uint32_t> AddressSpace::read32(
    std::uint32_t address, MemoryPermission access) const
{
    return read_integer<std::uint32_t>(address, access);
}
std::optional<std::uint64_t> AddressSpace::read64(
    std::uint32_t address, MemoryPermission access) const
{
    return read_integer<std::uint64_t>(address, access);
}

bool AddressSpace::write8(std::uint32_t address, std::uint8_t value)
{
    return write_integer(address, value);
}
bool AddressSpace::write16(std::uint32_t address, std::uint16_t value)
{
    return write_integer(address, value);
}
bool AddressSpace::write32(std::uint32_t address, std::uint32_t value)
{
    return write_integer(address, value);
}
bool AddressSpace::write64(std::uint32_t address, std::uint64_t value)
{
    return write_integer(address, value);
}

bool AddressSpace::accessible(
    std::uint32_t address, std::size_t size, MemoryPermission access) const
{
    auto lock = read_lock();
    return range_accessible_locked(address, size, access);
}

bool AddressSpace::is_read_only_executable(
    std::uint32_t address, std::size_t size) const
{
    if (size == 0 || range_overflows(address, size))
        return false;
    const auto end = page_range_end(address, size);
    auto lock = read_lock();
    if (!range_accessible_locked(address, size, MemoryPermission::Execute) ||
        range_accessible_locked(address, size, MemoryPermission::Write)) {
        return false;
    }
    for (std::uint64_t base = page_base(address); base < end;
        base += page_size) {
        const auto page_address = static_cast<std::uint32_t>(base);
        const auto* page = find_page_locked(page_address);
        if (page == nullptr || !page->backing) {
            if (find_file_mapping_locked(page_address) == nullptr)
                return false;
            continue;
        }
        if ((!page->file_cached && !page->backing->file_backed()) ||
            page->shared_writable ||
            page->backing->shared_write_tracking_enabled()) {
            return false;
        }
    }
    return true;
}

std::optional<ExecutableBackingIdentity>
AddressSpace::executable_backing_identity(
    std::uint32_t address, std::size_t size) const
{
    if (size == 0 || range_overflows(address, size))
        return std::nullopt;
    const auto end = page_range_end(address, size);
    auto lock = read_lock();
    if (!range_accessible_locked(address, size, MemoryPermission::Execute) ||
        range_accessible_locked(address, size, MemoryPermission::Write)) {
        return std::nullopt;
    }

    std::vector<ContentIdentity> source_identities;
    std::vector<std::byte> layout_material;
    for (std::uint64_t base = page_base(address); base < end;
        base += page_size) {
        const auto page_address = static_cast<std::uint32_t>(base);
        const auto mapping_after = file_mappings_.upper_bound(page_address);
        if (mapping_after == file_mappings_.begin())
            return std::nullopt;
        const auto mapping_iterator = std::prev(mapping_after);
        const auto& mapping = mapping_iterator->second;
        if (page_address >= mapping.end || !mapping.backing) {
            return std::nullopt;
        }

        // The file mapping remains as range metadata after a private write.  A
        // later mprotect(PROT_EXEC) must not make that detached page look like
        // the original immutable file cache again.  Shared aliases are likewise
        // mutable even when this particular virtual mapping is currently RX.
        const auto* page = find_page_locked(page_address);
        if (page != nullptr &&
            (!page->backing || !page->file_cached || page->shared_writable ||
                page->backing->shared_write_tracking_enabled())) {
            return std::nullopt;
        }

        const auto file_offset =
            mapping.file_offset + (static_cast<std::uint64_t>(page_address) -
                                      mapping_iterator->first);
        const auto identity = mapping.backing->content_identity;
        if (std::find(source_identities.begin(), source_identities.end(),
                identity) == source_identities.end()) {
            source_identities.push_back(identity);
        }
        append_u64(layout_material, base);
        append_u64(layout_material, mapping.end);
        append_u64(layout_material, file_offset);
        append_identity(layout_material, identity);
        // ContentIdentity protects the bytes. Runtime file generation remains
        // on GuestFileBacking for vnode/mutation/writeback isolation, but it is
        // not portable Guest execution semantics and must not affect this
        // digest.
    }

    if (source_identities.empty())
        return std::nullopt;
    std::vector<std::byte> content_material;
    content_material.reserve(
        source_identities.size() * ContentIdentity { }.digest.size());
    for (const auto& identity : source_identities) {
        append_identity(content_material, identity);
    }
    return ExecutableBackingIdentity { sha256(content_material),
        sha256(layout_material) };
}

std::uint64_t AddressSpace::executable_content_generation() const noexcept
{
    return executable_content_generation_.load(std::memory_order_acquire);
}

std::uint64_t
AddressSpace::translation_profile_mapping_generation() const noexcept
{
    return translation_profile_mapping_generation_.load(
        std::memory_order_acquire);
}

bool AddressSpace::compare_exchange8(
    std::uint32_t address, std::uint8_t expected, std::uint8_t value)
{
    return compare_exchange_integer(address, expected, value);
}
bool AddressSpace::compare_exchange16(
    std::uint32_t address, std::uint16_t expected, std::uint16_t value)
{
    return compare_exchange_integer(address, expected, value);
}
bool AddressSpace::compare_exchange32(
    std::uint32_t address, std::uint32_t expected, std::uint32_t value)
{
    return compare_exchange_integer(address, expected, value);
}
bool AddressSpace::compare_exchange64(
    std::uint32_t address, std::uint64_t expected, std::uint64_t value)
{
    return compare_exchange_integer(address, expected, value);
}

std::optional<std::uint8_t> AddressSpace::exchange8(
    std::uint32_t address, std::uint8_t value)
{
    return exchange_integer(address, value);
}

std::optional<std::uint32_t> AddressSpace::exchange32(
    std::uint32_t address, std::uint32_t value)
{
    return exchange_integer(address, value);
}

bool AddressSpace::mapped(std::uint32_t address, std::size_t size) const
{
    auto lock = read_lock();
    return range_accessible_locked(address, size, MemoryPermission::None);
}

bool AddressSpace::track_write_generation(
    std::uint32_t address, std::size_t size)
{
    if (size == 0 || range_overflows(address, size))
        return false;
    auto lock = write_lock();
    if (!range_accessible_locked(address, size, MemoryPermission::None)) {
        return false;
    }
    TrackedWriteRange tracked { address,
        static_cast<std::uint64_t>(address) + size };
    for (std::size_t index = 0; index < tracked_write_ranges_.size();) {
        const auto& existing = tracked_write_ranges_[index];
        if (tracked.end < existing.begin || existing.end < tracked.begin) {
            ++index;
            continue;
        }
        tracked.begin = std::min(tracked.begin, existing.begin);
        tracked.end = std::max(tracked.end, existing.end);
        tracked_write_ranges_.erase(
            tracked_write_ranges_.begin() + static_cast<std::ptrdiff_t>(index));
        index = 0;
    }
    tracked_write_ranges_.push_back(tracked);
    std::ranges::sort(tracked_write_ranges_, { },
        [](const TrackedWriteRange& range) { return range.begin; });
    const auto initial_tracking_epoch =
        GuestPageBacking::shared_write_tracking_epoch();
    std::size_t tracking_transitions = 0;
    bool has_shared_backing = false;
    const auto tracking_end = page_range_end(address, size);
    for (std::uint64_t base = page_base(address); base < tracking_end;
        base += page_size) {
        write_tracked_pages_.insert(static_cast<std::uint32_t>(base));
        auto* page = find_page_locked(static_cast<std::uint32_t>(base));
        if (page == nullptr || !page->shared_writable || !page->backing)
            continue;
        if (page->backing->enable_shared_write_tracking())
            ++tracking_transitions;
        has_shared_backing = true;
    }
    if (has_shared_backing) {
        finish_shared_write_tracking_locked(
            initial_tracking_epoch, tracking_transitions, true);
    }
    refresh_jit_page_range_locked(page_base(address), tracking_end);
    return true;
}

std::optional<std::uint64_t> AddressSpace::range_write_generation(
    std::uint32_t address, std::size_t size) const
{
    if (size == 0 || range_overflows(address, size))
        return std::nullopt;
    const auto first = page_base(address);
    const auto last =
        page_base(address + static_cast<std::uint32_t>(size - 1U));
    auto lock = read_lock();
    if (!range_accessible_locked(address, size, MemoryPermission::None)) {
        return std::nullopt;
    }
    std::uint64_t generation = 0;
    for (std::uint64_t base = first; base <= last; base += page_size) {
        const auto* page = find_page_locked(static_cast<std::uint32_t>(base));
        if (page != nullptr)
            generation = std::max(generation, page->write_generation);
    }
    return generation;
}

bool AddressSpace::publish_write_generation(
    std::uint32_t address, std::size_t size)
{
    if (size == 0 || range_overflows(address, size))
        return size == 0;
    const auto end = static_cast<std::uint64_t>(address) + size;
    auto lock = write_lock();
    if (!range_accessible_locked(address, size, MemoryPermission::None))
        return false;

    ensure_unique_page_map_locked();
    const auto generation = ++write_generation_;
    const auto first = page_base(address);
    const auto page_end = page_range_end(address, size);
    for (std::uint64_t base = first; base < page_end; base += page_size) {
        auto* page = find_page_locked(static_cast<std::uint32_t>(base));
        if (page == nullptr || !page->backing)
            continue;
        page->write_generation = generation;
        page->backing->publish_shared_write();
    }
    if (vm_map_.accessible(address, end, MemoryPermission::Execute))
        bump_executable_content_generation_locked();
    return true;
}

std::optional<AddressSpace::WriteGenerationChanges>
AddressSpace::write_generation_changes(std::uint32_t address, std::size_t size,
    std::uint64_t after_generation) const
{
    if (size == 0 || range_overflows(address, size))
        return std::nullopt;
    const auto requested_begin = static_cast<std::uint64_t>(address);
    const auto requested_end = requested_begin + size;
    const auto first = page_base(address);
    const auto end = page_range_end(address, size);
    auto lock = read_lock();
    if (!range_accessible_locked(address, size, MemoryPermission::None))
        return std::nullopt;

    WriteGenerationChanges result;
    for (std::uint64_t base = first; base < end; base += page_size) {
        const auto* page = find_page_locked(static_cast<std::uint32_t>(base));
        const auto generation = page ? page->write_generation : 0U;
        result.generation = std::max(result.generation, generation);
        if (generation <= after_generation)
            continue;
        const auto dirty_begin = std::max(base, requested_begin);
        const auto dirty_end = std::min(base + page_size, requested_end);
        if (dirty_end <= dirty_begin)
            continue;
        if (!result.ranges.empty()) {
            auto& previous = result.ranges.back();
            const auto previous_end =
                static_cast<std::uint64_t>(previous.address) + previous.size;
            if (previous_end == dirty_begin) {
                previous.size +=
                    static_cast<std::uint32_t>(dirty_end - dirty_begin);
                continue;
            }
        }
        result.ranges.push_back(
            WrittenRange { static_cast<std::uint32_t>(dirty_begin),
                static_cast<std::uint32_t>(dirty_end - dirty_begin) });
    }
    return result;
}

std::optional<AddressSpace::SharedWriteGenerationChanges>
AddressSpace::shared_write_generation_changes(std::uint32_t address,
    std::size_t size,
    std::span<const std::uint64_t> after_page_generations) const
{
    if (size == 0 || range_overflows(address, size))
        return std::nullopt;
    const auto requested_begin = static_cast<std::uint64_t>(address);
    const auto requested_end = requested_begin + size;
    const auto first = page_base(address);
    const auto end = page_range_end(address, size);
    auto lock = read_lock();
    if (!range_accessible_locked(address, size, MemoryPermission::None))
        return std::nullopt;

    SharedWriteGenerationChanges result;
    const auto range_page_count =
        static_cast<std::size_t>((end - first) / page_size);
    result.page_generations.reserve(range_page_count);
    const auto has_baseline = after_page_generations.size() == range_page_count;
    std::size_t page_index = 0;
    for (std::uint64_t base = first; base < end; base += page_size) {
        const auto* page = find_page_locked(static_cast<std::uint32_t>(base));
        const auto generation = page && page->backing
                                    ? page->backing->shared_write_generation()
                                    : 0U;
        result.page_generations.push_back(generation);
        const auto changed =
            !has_baseline || generation != after_page_generations[page_index];
        ++page_index;
        if (!changed)
            continue;
        const auto dirty_begin = std::max(base, requested_begin);
        const auto dirty_end = std::min(base + page_size, requested_end);
        if (dirty_end <= dirty_begin)
            continue;
        if (!result.ranges.empty()) {
            auto& previous = result.ranges.back();
            const auto previous_end =
                static_cast<std::uint64_t>(previous.address) + previous.size;
            if (previous_end == dirty_begin) {
                previous.size +=
                    static_cast<std::uint32_t>(dirty_end - dirty_begin);
                continue;
            }
        }
        result.ranges.push_back(
            WrittenRange { static_cast<std::uint32_t>(dirty_begin),
                static_cast<std::uint32_t>(dirty_end - dirty_begin) });
    }
    return result;
}

std::size_t AddressSpace::mapped_page_count() const
{
    auto lock = read_lock();
    return vm_map_.page_count(page_size);
}

std::size_t AddressSpace::resident_page_count() const
{
    auto lock = read_lock();
    return static_cast<std::size_t>(
        std::count_if(pages_->begin(), pages_->end(), [](const auto& entry) {
            return static_cast<bool>(entry.second.backing);
        }));
}

std::size_t AddressSpace::shared_page_count() const
{
    auto lock = read_lock();
    const auto shared_metadata = pages_.use_count() != 1;
    return static_cast<std::size_t>(std::count_if(
        pages_->begin(), pages_->end(), [shared_metadata](const auto& entry) {
            return entry.second.backing &&
                   (shared_metadata || entry.second.backing.use_count() != 1);
        }));
}

std::size_t AddressSpace::cached_file_mapping_count() const
{
    auto lock = read_lock();
    return static_cast<std::size_t>(
        std::count_if(pages_->begin(), pages_->end(),
            [](const auto& entry) { return entry.second.file_cached; }));
}

std::size_t AddressSpace::cached_file_page_count() const
{
    return file_page_cache_->page_count();
}

FilePageCacheStats AddressSpace::file_page_cache_stats() const
{
    return file_page_cache_->stats();
}

std::size_t AddressSpace::mapping_region_count() const
{
    auto lock = read_lock();
    return vm_map_.region_count();
}

std::optional<AddressSpace::MappingRegion>
AddressSpace::mapping_region_at_or_after(std::uint32_t address) const
{
    auto lock = read_lock();
    return vm_map_.region_at_or_after(address);
}

std::unique_ptr<AddressSpace> AddressSpace::clone() const
{
    auto result = std::make_unique<AddressSpace>();
    std::unique_lock source_lock { mutex_, std::defer_lock };
    if (!owns_exclusive_access())
        source_lock.lock();
    std::unique_lock destination_lock { result->mutex_ };

    constexpr auto address_space_end = std::uint64_t { 1 } << 32U;
    std::vector<MappingRegion> non_copy_regions;
    for (std::uint64_t cursor = 0; cursor < address_space_end;) {
        const auto region =
            vm_map_.region_at_or_after(static_cast<std::uint32_t>(cursor));
        if (!region)
            break;
        if (region->inheritance != VmInheritance::Copy)
            non_copy_regions.push_back(*region);
        if (region->end >= address_space_end)
            break;
        cursor = region->end;
    }

    // VM_INHERIT_SHARE makes anonymous/private pages aliases in the new task.
    // Materialize demand-zero or lazy file pages before publishing the clone so
    // a later first write in either address space observes the same backing.
    for (const auto& region : non_copy_regions) {
        if (region.inheritance == VmInheritance::Share) {
            const_cast<AddressSpace*>(this)->share_pages_locked(
                region.address, region.end, nullptr);
        }
    }

    result->vm_map_ = vm_map_;
    result->translation_profile_map_ = translation_profile_map_;
    std::size_t non_copy_index = 0;
    for (const auto& [address, page] : *pages_) {
        while (non_copy_index < non_copy_regions.size() &&
               non_copy_regions[non_copy_index].end <= address) {
            ++non_copy_index;
        }
        const auto absent_from_child =
            non_copy_index < non_copy_regions.size() &&
            non_copy_regions[non_copy_index].address <= address &&
            non_copy_regions[non_copy_index].end > address &&
            non_copy_regions[non_copy_index].inheritance ==
                VmInheritance::None;
        if (!absent_from_child && page.backing && !page.shared_writable) {
            page.copy_on_write_possible = true;
            const_cast<AddressSpace*>(this)->refresh_jit_page_locked(address);
        }
    }
    result->pages_ = pages_;
    result->file_mappings_ = file_mappings_;
    result->rebuild_page_lookup_locked();
    result->page_permissions_ = page_permissions_;
    result->tracked_write_ranges_ = tracked_write_ranges_;
    result->write_tracked_pages_ = write_tracked_pages_;
    result->write_generation_ = write_generation_;
    result->executable_content_generation_.store(
        executable_content_generation_.load(std::memory_order_acquire),
        std::memory_order_release);
    result->translation_profile_mapping_generation_.store(
        translation_profile_mapping_generation_.load(
            std::memory_order_acquire),
        std::memory_order_release);
    result->mapping_leases_ = mapping_leases_;
    result->next_mapping_lease_token_ = next_mapping_lease_token_;
    result->file_page_cache_ = file_page_cache_;
    result->exclusive_write_tracked_pages_ = exclusive_write_tracked_pages_;
    result->exclusive_write_tracking_active_.store(
        !result->exclusive_write_tracked_pages_.empty(),
        std::memory_order_release);
    result->parallel_access_ = parallel_access_;
    result->jit_page_table_enabled_ = jit_page_table_enabled_;

    // VM_INHERIT_NONE removes the complete mapping from the child while the
    // parent's interval and resident backing remain intact.
    for (const auto& region : non_copy_regions) {
        if (region.inheritance != VmInheritance::None)
            continue;
        result->invalidate_mapping_leases_locked(region.address, region.end);
        result->unmap_range_locked(region.address, region.end, false);
    }
    return result;
}

void AddressSpace::add_page_permissions_locked(
    std::uint32_t address, std::uint64_t end, MemoryPermission permissions)
{
    const auto bits = permission_bits(permissions);
    const auto first_page = static_cast<std::size_t>(address / page_size);
    const auto after_page = static_cast<std::size_t>(end / page_size);
    for (auto page = first_page; page < after_page;) {
        const auto chunk_index = page / page_permission_chunk_size;
        const auto chunk_begin = page % page_permission_chunk_size;
        const auto chunk_end = std::min(
            page_permission_chunk_size - chunk_begin, after_page - page);
        auto& chunk = page_permissions_[chunk_index];
        if (!chunk) {
            chunk = std::make_shared<PagePermissionChunk>();
            std::fill(chunk->begin() + static_cast<std::ptrdiff_t>(chunk_begin),
                chunk->begin() +
                    static_cast<std::ptrdiff_t>(chunk_begin + chunk_end),
                static_cast<std::uint8_t>(mapped_page_flag | bits));
        } else {
            if (chunk.use_count() != 1)
                chunk = std::make_shared<PagePermissionChunk>(*chunk);
            for (auto index = chunk_begin; index < chunk_begin + chunk_end;
                ++index)
                (*chunk)[index] |=
                    static_cast<std::uint8_t>(mapped_page_flag | bits);
        }
        page += chunk_end;
    }
}

void AddressSpace::set_page_permissions_locked(
    std::uint32_t address, std::uint64_t end, MemoryPermission permissions)
{
    const auto flags = static_cast<std::uint8_t>(
        mapped_page_flag | permission_bits(permissions));
    const auto first_page = static_cast<std::size_t>(address / page_size);
    const auto after_page = static_cast<std::size_t>(end / page_size);
    for (auto page = first_page; page < after_page;) {
        const auto chunk_index = page / page_permission_chunk_size;
        const auto chunk_begin = page % page_permission_chunk_size;
        const auto chunk_end = std::min(
            page_permission_chunk_size - chunk_begin, after_page - page);
        auto& chunk = page_permissions_[chunk_index];
        if (!chunk) {
            chunk = std::make_shared<PagePermissionChunk>();
        } else if (chunk.use_count() != 1) {
            chunk = std::make_shared<PagePermissionChunk>(*chunk);
        }
        std::fill(chunk->begin() + static_cast<std::ptrdiff_t>(chunk_begin),
            chunk->begin() +
                static_cast<std::ptrdiff_t>(chunk_begin + chunk_end),
            flags);
        page += chunk_end;
    }
}

void AddressSpace::clear_page_permissions_locked(
    std::uint32_t address, std::uint64_t end)
{
    const auto first_page = static_cast<std::size_t>(address / page_size);
    const auto after_page = static_cast<std::size_t>(end / page_size);
    for (auto page = first_page; page < after_page;) {
        const auto chunk_index = page / page_permission_chunk_size;
        const auto chunk_begin = page % page_permission_chunk_size;
        const auto chunk_end = std::min(
            page_permission_chunk_size - chunk_begin, after_page - page);
        auto& chunk = page_permissions_[chunk_index];
        if (chunk) {
            if (chunk.use_count() != 1)
                chunk = std::make_shared<PagePermissionChunk>(*chunk);
            std::fill(chunk->begin() + static_cast<std::ptrdiff_t>(chunk_begin),
                chunk->begin() +
                    static_cast<std::ptrdiff_t>(chunk_begin + chunk_end),
                std::uint8_t { });
        }
        page += chunk_end;
    }
}

std::uint8_t AddressSpace::page_permission_locked(std::size_t page_index) const
{
    const auto& chunk =
        page_permissions_[page_index / page_permission_chunk_size];
    return chunk ? (*chunk)[page_index % page_permission_chunk_size] : 0U;
}

AddressSpace::PagePermissionChunk&
AddressSpace::writable_page_permission_chunk_locked(std::size_t page_index)
{
    auto& chunk = page_permissions_[page_index / page_permission_chunk_size];
    if (!chunk) {
        chunk = std::make_shared<PagePermissionChunk>();
    } else if (chunk.use_count() != 1) {
        chunk = std::make_shared<PagePermissionChunk>(*chunk);
    }
    return *chunk;
}

} // namespace shade
