// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Cache file-backed guest pages while tracking host-file generations
// and writeback identity.

#include "foundation/file_page_cache.hpp"

#include <algorithm>
#include <cerrno>
#include <charconv>
#include <chrono>
#include <condition_variable>
#include <fstream>
#include <iterator>
#include <limits>
#include <string_view>
#include <tuple>

#include <fcntl.h>
#include <signal.h>
#include <sys/mman.h>
#include <sys/stat.h>
#if defined(__linux__)
#include <sys/sysinfo.h>
#elif defined(__APPLE__)
#include <sys/sysctl.h>
#endif
#include <sys/types.h>
#include <unistd.h>

#if defined(__linux__)
#include <linux/fs.h>
#include <sys/ioctl.h>
#endif

#if defined(__APPLE__)
#define st_atim st_atimespec
#define st_mtim st_mtimespec
#define st_ctim st_ctimespec
#endif

namespace shade {
namespace {

    constexpr std::uint64_t file_prefetch_bytes =
        guest_file_prefetch_pages * guest_memory_page_size;

    std::atomic<std::uint64_t> global_shared_write_tracking_epoch { };
    std::atomic<std::uint64_t> next_reservation_identity { 1 };

    [[nodiscard]] int open_file_descriptor(const std::filesystem::path& path)
    {
        auto descriptor = ::open(path.c_str(), O_RDWR | O_CLOEXEC);
        if (descriptor < 0) {
            descriptor = ::open(path.c_str(), O_RDONLY | O_CLOEXEC);
        }
        return descriptor;
    }

    [[nodiscard]] std::filesystem::file_time_type file_time_from_stat(
        const struct stat& file_stat)
    {
        using namespace std::chrono;
        const auto duration = seconds { file_stat.st_mtim.tv_sec } +
                              nanoseconds { file_stat.st_mtim.tv_nsec };
        return std::filesystem::file_time_type {
            duration_cast<std::filesystem::file_time_type::duration>(duration)
        };
    }

    [[nodiscard]] GuestFileGeneration generation_from_stat(
        const struct stat& file_stat)
    {
        return GuestFileGeneration { static_cast<std::uint64_t>(
                                         file_stat.st_dev),
            static_cast<std::uint64_t>(file_stat.st_ino),
            static_cast<std::uint64_t>(file_stat.st_size),
            static_cast<std::int64_t>(file_stat.st_mtim.tv_sec),
            static_cast<std::int64_t>(file_stat.st_mtim.tv_nsec),
            static_cast<std::int64_t>(file_stat.st_ctim.tv_sec),
            static_cast<std::int64_t>(file_stat.st_ctim.tv_nsec) };
    }

    constexpr std::uint64_t shared_immutable_file_budget_bytes =
        std::uint64_t { 1 } * 1024U * 1024U * 1024U;

    [[nodiscard]] std::filesystem::path shared_immutable_file_root()
    {
        return std::filesystem::temp_directory_path() /
               ("shade-shared-cache-" + std::to_string(::getuid()));
    }

    [[nodiscard]] std::filesystem::path shared_immutable_file_path(
        const ContentIdentity& content_identity, std::uint64_t byte_size)
    {
        return shared_immutable_file_root() /
               (content_identity.hex() + "-" + std::to_string(byte_size) +
                   ".bin");
    }

    [[nodiscard]] bool process_is_alive(std::uint64_t process_id)
    {
        if (process_id == 0U ||
            process_id >
                static_cast<std::uint64_t>(std::numeric_limits<pid_t>::max())) {
            return false;
        }
        if (::kill(static_cast<pid_t>(process_id), 0) == 0)
            return true;
        return errno == EPERM;
    }

    [[nodiscard]] bool has_live_shared_file_lease(
        const std::filesystem::path& backing_path)
    {
        const auto root = backing_path.parent_path();
        const auto prefix = backing_path.filename().string() + ".lease-";
        std::error_code error;
        for (const auto& entry :
            std::filesystem::directory_iterator(root, error)) {
            if (error)
                return true;
            const auto name = entry.path().filename().string();
            if (!name.starts_with(prefix))
                continue;
            const auto process_text = name.substr(prefix.size());
            const auto process_separator = process_text.find('-');
            const auto process_end = process_separator == std::string::npos
                                         ? process_text.size()
                                         : process_separator;
            std::uint64_t process_id { };
            const auto [end, parse_error] = std::from_chars(process_text.data(),
                process_text.data() + process_end, process_id);
            if (parse_error == std::errc { } &&
                end == process_text.data() + process_end &&
                process_is_alive(process_id)) {
                return true;
            }
            std::filesystem::remove(entry.path(), error);
            error.clear();
        }
        return false;
    }

    void reclaim_shared_immutable_files(const std::filesystem::path& root,
        const std::filesystem::path& preserve_path = { })
    {
        struct Candidate {
            std::filesystem::path path;
            std::uint64_t bytes { };
            std::filesystem::file_time_type modified { };
        };
        std::vector<Candidate> candidates;
        std::uint64_t total_bytes { };
        std::error_code error;
        for (const auto& entry :
            std::filesystem::directory_iterator(root, error)) {
            if (error)
                return;
            if (entry.path().extension() != ".bin")
                continue;
            const auto size = entry.file_size(error);
            if (error) {
                error.clear();
                continue;
            }
            const auto modified = entry.last_write_time(error);
            if (error) {
                error.clear();
                continue;
            }
            candidates.push_back(Candidate { entry.path(), size, modified });
            total_bytes += size;
        }
        if (total_bytes <= shared_immutable_file_budget_bytes)
            return;
        std::sort(candidates.begin(), candidates.end(),
            [](const Candidate& left, const Candidate& right) {
                return left.modified < right.modified;
            });
        for (const auto& candidate : candidates) {
            if (total_bytes <= shared_immutable_file_budget_bytes)
                break;
            if (candidate.path == preserve_path ||
                has_live_shared_file_lease(candidate.path)) {
                continue;
            }
            if (std::filesystem::remove(candidate.path, error)) {
                total_bytes -= candidate.bytes;
            }
            error.clear();
        }
    }

    [[nodiscard]] bool write_all(
        int descriptor, const std::byte* data, std::size_t size)
    {
        std::size_t written = 0;
        while (written < size) {
            const auto count = ::write(descriptor,
                reinterpret_cast<const char*>(data + written), size - written);
            if (count < 0 && errno == EINTR)
                continue;
            if (count <= 0)
                return false;
            written += static_cast<std::size_t>(count);
        }
        return true;
    }

    [[nodiscard]] bool create_shared_immutable_file(
        const std::filesystem::path& source_path,
        const GuestFileGeneration& generation,
        const std::filesystem::path& backing_path)
    {
        int source_descriptor = -1;
        do {
            source_descriptor =
                ::open(source_path.c_str(), O_RDONLY | O_CLOEXEC);
        } while (source_descriptor < 0 && errno == EINTR);
        if (source_descriptor < 0)
            return false;

        struct stat source_stat { };
        if (::fstat(source_descriptor, &source_stat) != 0 ||
            !S_ISREG(source_stat.st_mode) ||
            generation_from_stat(source_stat) != generation) {
            static_cast<void>(::close(source_descriptor));
            return false;
        }

        const auto root = backing_path.parent_path();
        std::error_code error;
        std::filesystem::create_directories(root, error);
        if (error) {
            static_cast<void>(::close(source_descriptor));
            return false;
        }
        std::filesystem::permissions(root, std::filesystem::perms::owner_all,
            std::filesystem::perm_options::replace, error);
        error.clear();

        const auto temporary_path =
            backing_path.string() + ".tmp-" + std::to_string(::getpid()) + "-" +
            std::to_string(next_reservation_identity.fetch_add(
                1, std::memory_order_relaxed));
        const auto temporary = std::filesystem::path { temporary_path };
        int temporary_descriptor = ::open(
            temporary.c_str(), O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0600);
        if (temporary_descriptor < 0) {
            static_cast<void>(::close(source_descriptor));
            return false;
        }

        bool copied = false;
#if defined(FICLONE)
        copied = ::ioctl(temporary_descriptor, FICLONE, source_descriptor) == 0;
#endif
        if (!copied) {
            if (::ftruncate(temporary_descriptor, 0) != 0 ||
                ::lseek(temporary_descriptor, 0, SEEK_SET) < 0) {
                static_cast<void>(::close(temporary_descriptor));
                static_cast<void>(::close(source_descriptor));
                std::filesystem::remove(temporary, error);
                return false;
            }
            std::array<std::byte, 1024U * 1024U> buffer { };
            std::uint64_t offset = 0;
            copied = true;
            while (offset < generation.file_size) {
                const auto requested =
                    static_cast<std::size_t>(std::min<std::uint64_t>(
                        buffer.size(), generation.file_size - offset));
                ssize_t count = -1;
                do {
                    count = ::pread(source_descriptor, buffer.data(), requested,
                        static_cast<off_t>(offset));
                } while (count < 0 && errno == EINTR);
                if (count != static_cast<ssize_t>(requested) ||
                    !write_all(
                        temporary_descriptor, buffer.data(), requested)) {
                    copied = false;
                    break;
                }
                offset += requested;
            }
        }
        struct stat final_source_stat { };
        if (copied && ::fstat(source_descriptor, &final_source_stat) == 0 &&
            generation_from_stat(final_source_stat) == generation &&
            ::fsync(temporary_descriptor) == 0) {
            static_cast<void>(::fchmod(temporary_descriptor, 0444));
        } else {
            copied = false;
        }
        static_cast<void>(::close(temporary_descriptor));
        static_cast<void>(::close(source_descriptor));
        if (!copied) {
            std::filesystem::remove(temporary, error);
            return false;
        }

        if (::rename(temporary.c_str(), backing_path.c_str()) != 0 &&
            errno != EEXIST) {
            std::filesystem::remove(temporary, error);
            return false;
        }
        std::filesystem::remove(temporary, error);
        return true;
    }

    [[nodiscard]] bool same_file_stat(
        const struct stat& first, const struct stat& second)
    {
        return generation_from_stat(first) == generation_from_stat(second);
    }

    [[nodiscard]] std::string stable_path(const std::filesystem::path& path)
    {
        std::error_code error;
        const auto canonical = std::filesystem::canonical(path, error);
        return (error ? path.lexically_normal() : canonical).string();
    }

    [[nodiscard]] std::string namespace_path(const std::filesystem::path& path)
    {
        std::error_code error;
        const auto absolute = std::filesystem::absolute(path, error);
        return (error ? path : absolute).lexically_normal().string();
    }

    struct GlobalIdentityRecord {
        GuestFileGeneration generation;
        std::optional<std::uint64_t> generation_revision;
        ContentIdentity content_identity;
        std::weak_ptr<GuestFileIoState> io_state;
        std::list<std::string>::iterator lru_position;
    };

    struct GlobalIdentityFlight {
        GuestFileGeneration generation;
        std::optional<std::uint64_t> generation_revision;
        std::mutex mutex;
        std::condition_variable condition;
        bool complete { };
        bool computed { };
        std::optional<ContentIdentity> content_identity;
    };

    std::mutex global_identity_mutex;
    std::map<std::string, GlobalIdentityRecord> global_identities;
    std::list<std::string> global_identity_lru;
    std::map<std::string, std::shared_ptr<GlobalIdentityFlight>>
        global_identity_flights;

    constexpr std::size_t maximum_global_identity_entries = 32U * 1024U;

    struct ImmutableSnapshotKey {
        GuestFileGeneration generation;
        ContentIdentity content_identity;
        std::uint64_t byte_size { };
        std::uint64_t layout_tag { };
        ImmutableSnapshotKind kind { ImmutableSnapshotKind::RuntimeHot };

        friend constexpr auto operator<=>(
            const ImmutableSnapshotKey&, const ImmutableSnapshotKey&) = default;
    };

    struct ImmutableSnapshotRecord {
        std::shared_ptr<const std::vector<std::byte>> snapshot;
        std::uint64_t byte_size { };
        std::list<ImmutableSnapshotKey>::iterator lru_position;
    };

    constexpr std::uint64_t maximum_immutable_snapshot_bytes =
        std::uint64_t { 256 } * 1024U * 1024U;
    constexpr std::uint64_t minimum_immutable_snapshot_bytes =
        std::uint64_t { 8 } * 1024U * 1024U;
    constexpr std::uint64_t immutable_snapshot_budget_divisor = 32U;
    constexpr std::uint64_t immutable_snapshot_available_divisor = 8U;
    constexpr std::uint64_t immutable_snapshot_scan_fraction = 4U;
    constexpr std::uint64_t immutable_snapshot_entry_granularity =
        std::uint64_t { 64 } * 1024U;
    constexpr std::size_t minimum_immutable_snapshot_entries = 128U;
    constexpr std::size_t maximum_immutable_snapshot_entries = 4096U;
    std::mutex immutable_snapshot_mutex;
    std::map<ImmutableSnapshotKey, ImmutableSnapshotRecord> immutable_snapshots;
    std::list<ImmutableSnapshotKey> immutable_snapshot_lru;
    std::uint64_t immutable_snapshot_bytes { };
    std::uint64_t immutable_snapshot_runtime_hot_entries { };
    std::uint64_t immutable_snapshot_runtime_hot_bytes { };
    std::uint64_t immutable_snapshot_catalog_scan_entries { };
    std::uint64_t immutable_snapshot_catalog_scan_bytes { };
    std::uint64_t immutable_snapshot_hits { };
    std::uint64_t immutable_snapshot_evictions { };

    struct ImmutableSnapshotLimits {
        std::uint64_t bytes { };
        std::uint64_t catalog_scan_bytes { };
        std::size_t entries { };
    };

    [[nodiscard]] std::optional<std::uint64_t> read_uint64_file(
        const char* path)
    {
        std::ifstream input { path };
        std::string value;
        if (!(input >> value) || value == "max")
            return std::nullopt;
        std::uint64_t result { };
        const auto [end, error] =
            std::from_chars(value.data(), value.data() + value.size(), result);
        if (error != std::errc { } || end != value.data() + value.size())
            return std::nullopt;
        return result;
    }

    [[nodiscard]] std::optional<std::uint64_t> proc_meminfo_bytes(
        std::string_view wanted_key)
    {
        std::ifstream input { "/proc/meminfo" };
        std::string key;
        std::uint64_t value { };
        std::string unit;
        while (input >> key >> value >> unit) {
            if (key != wanted_key)
                continue;
            if (unit == "kB" &&
                value <= std::numeric_limits<std::uint64_t>::max() / 1024U)
                return value * 1024U;
            return value;
        }
        return std::nullopt;
    }

    struct HostMemoryAvailability {
        std::uint64_t total_bytes { };
        std::uint64_t available_bytes { };
    };

    [[nodiscard]] HostMemoryAvailability host_memory_availability()
    {
        HostMemoryAvailability result;
#if defined(__linux__)
        struct sysinfo information { };
        if (::sysinfo(&information) == 0) {
            result.total_bytes =
                static_cast<std::uint64_t>(information.totalram) *
                static_cast<std::uint64_t>(information.mem_unit);
        }
#elif defined(__APPLE__)
        std::uint64_t memory = 0;
        std::size_t length = sizeof memory;
        if (::sysctlbyname("hw.memsize", &memory, &length, nullptr, 0) == 0)
            result.total_bytes = memory;
#endif
        result.available_bytes =
            proc_meminfo_bytes("MemAvailable:").value_or(result.total_bytes);

        // Use the cgroup limit when the emulator runs in a memory-constrained
        // container. The /proc value describes the host and can otherwise make
        // the snapshot cache claim far more memory than this process can
        // actually use.
        const auto cgroup_limit =
            read_uint64_file("/sys/fs/cgroup/memory.max")
                .value_or(read_uint64_file(
                    "/sys/fs/cgroup/memory/memory.limit_in_bytes")
                        .value_or(0));
        const auto cgroup_current =
            read_uint64_file("/sys/fs/cgroup/memory.current")
                .value_or(read_uint64_file(
                    "/sys/fs/cgroup/memory/memory.usage_in_bytes")
                        .value_or(0));
        if (cgroup_limit &&
            (!result.total_bytes || cgroup_limit < result.total_bytes))
            result.total_bytes = cgroup_limit;
        if (cgroup_limit && cgroup_current < cgroup_limit) {
            const auto cgroup_available = cgroup_limit - cgroup_current;
            if (!result.available_bytes ||
                cgroup_available < result.available_bytes)
                result.available_bytes = cgroup_available;
        }
        return result;
    }

    [[nodiscard]] ImmutableSnapshotLimits immutable_snapshot_limits()
    {
        const auto memory = host_memory_availability();
        const auto total_based =
            memory.total_bytes
                ? memory.total_bytes / immutable_snapshot_budget_divisor
                : maximum_immutable_snapshot_bytes;
        const auto available_based =
            memory.available_bytes
                ? memory.available_bytes / immutable_snapshot_available_divisor
                : maximum_immutable_snapshot_bytes;
        const auto bytes = std::clamp(
            std::min({ maximum_immutable_snapshot_bytes, total_based,
                available_based }),
            minimum_immutable_snapshot_bytes, maximum_immutable_snapshot_bytes);
        const auto entries = std::clamp<std::size_t>(
            static_cast<std::size_t>(
                bytes / immutable_snapshot_entry_granularity),
            minimum_immutable_snapshot_entries,
            maximum_immutable_snapshot_entries);
        return ImmutableSnapshotLimits { bytes,
            std::max<std::uint64_t>(
                1U, bytes / immutable_snapshot_scan_fraction),
            entries };
    }

    [[nodiscard]] bool is_catalog_scan(const ImmutableSnapshotKey& key)
    {
        return key.kind == ImmutableSnapshotKind::CatalogScan;
    }

    [[nodiscard]] bool identity_revision_matches(
        const std::optional<std::uint64_t>& published_revision,
        const std::optional<std::uint64_t>& requested_revision)
    {
        return !requested_revision || !published_revision ||
               *published_revision == *requested_revision;
    }

    void touch_global_identity_locked(
        std::map<std::string, GlobalIdentityRecord>::iterator iterator)
    {
        global_identity_lru.splice(global_identity_lru.end(),
            global_identity_lru, iterator->second.lru_position);
        iterator->second.lru_position = std::prev(global_identity_lru.end());
    }

    void evict_global_identities_locked()
    {
        while (global_identities.size() > maximum_global_identity_entries &&
               !global_identity_lru.empty()) {
            const auto key = std::move(global_identity_lru.front());
            global_identity_lru.pop_front();
            const auto identity = global_identities.find(key);
            if (identity != global_identities.end()) {
                global_identities.erase(identity);
            }
        }
    }

    void store_global_identity_locked(
        const std::string& normalized_path, GlobalIdentityRecord record)
    {
        const auto existing = global_identities.find(normalized_path);
        if (existing == global_identities.end()) {
            global_identity_lru.push_back(normalized_path);
            record.lru_position = std::prev(global_identity_lru.end());
            global_identities.emplace(normalized_path, std::move(record));
        } else {
            record.lru_position = existing->second.lru_position;
            existing->second = std::move(record);
            touch_global_identity_locked(existing);
        }
        evict_global_identities_locked();
    }

    void erase_global_identity_locked(const std::string& normalized_path)
    {
        const auto identity = global_identities.find(normalized_path);
        if (identity == global_identities.end())
            return;
        global_identity_lru.erase(identity->second.lru_position);
        global_identities.erase(identity);
    }

    void publish_global_identity(const std::string& normalized_path,
        const GuestFileGeneration& generation,
        std::optional<std::uint64_t> generation_revision,
        const ContentIdentity& content_identity)
    {
        std::shared_ptr<GlobalIdentityFlight> flight;
        {
            const std::scoped_lock lock { global_identity_mutex };
            std::weak_ptr<GuestFileIoState> io_state;
            const auto existing_identity =
                global_identities.find(normalized_path);
            if (existing_identity != global_identities.end() &&
                existing_identity->second.generation == generation &&
                identity_revision_matches(
                    existing_identity->second.generation_revision,
                    generation_revision) &&
                existing_identity->second.content_identity ==
                    content_identity) {
                io_state = existing_identity->second.io_state;
            }
            store_global_identity_locked(normalized_path,
                GlobalIdentityRecord { generation,
                    std::move(generation_revision), content_identity,
                    std::move(io_state), { } });
            const auto existing = global_identity_flights.find(normalized_path);
            const auto published = global_identities.find(normalized_path);
            if (existing != global_identity_flights.end() &&
                published != global_identities.end() &&
                existing->second->generation == generation &&
                identity_revision_matches(existing->second->generation_revision,
                    published->second.generation_revision)) {
                flight = existing->second;
                global_identity_flights.erase(existing);
            }
        }
        if (!flight)
            return;
        {
            const std::scoped_lock flight_lock { flight->mutex };
            if (!flight->complete) {
                flight->content_identity = content_identity;
                flight->complete = true;
            }
        }
        flight->condition.notify_all();
    }

    void invalidate_global_identity(const std::string& normalized_path)
    {
        const std::scoped_lock lock { global_identity_mutex };
        erase_global_identity_locked(normalized_path);
        global_identity_flights.erase(normalized_path);
        // Generation-registry keys intentionally retain the lexical namespace
        // path, while the shared identity cache is keyed by the resolved file
        // object. Invalidate both views for an existing path.  If the path is a
        // symlink, this resolves the current target without changing the
        // namespace key.
        const auto object_path = stable_path(normalized_path);
        if (object_path == normalized_path)
            return;
        erase_global_identity_locked(object_path);
        global_identity_flights.erase(object_path);
    }

    [[nodiscard]] unsigned mutation_priority(GuestFileMutationKind mutation)
    {
        switch (mutation) {
        case GuestFileMutationKind::Observation:
            return 0;
        case GuestFileMutationKind::SharedWriteback:
        case GuestFileMutationKind::Write:
            return 1;
        case GuestFileMutationKind::Truncate:
            return 2;
        case GuestFileMutationKind::InstallReplace:
            return 3;
        case GuestFileMutationKind::Rename:
        case GuestFileMutationKind::Unlink:
            return 4;
        case GuestFileMutationKind::SubtreeCreate:
        case GuestFileMutationKind::SubtreeRemove:
            return 5;
        }
        return 0;
    }

} // namespace

ImmutableFileView::ImmutableFileView(int file_descriptor, void* mapping,
    std::uint64_t byte_size, std::filesystem::path backing_path,
    std::filesystem::path lease_path, GuestFileGeneration generation,
    ContentIdentity content_identity) noexcept
    : file_descriptor_ { file_descriptor }
    , mapping_ { mapping }
    , byte_size_ { byte_size }
    , backing_path_ { std::move(backing_path) }
    , lease_path_ { std::move(lease_path) }
    , generation_ { generation }
    , content_identity_ { content_identity }
{
}

ImmutableFileView::~ImmutableFileView()
{
    if (mapping_ && byte_size_ != 0U) {
        static_cast<void>(
            ::munmap(mapping_, static_cast<std::size_t>(byte_size_)));
    }
    if (file_descriptor_ >= 0)
        static_cast<void>(::close(file_descriptor_));
    if (!lease_path_.empty()) {
        std::error_code error;
        std::filesystem::remove(lease_path_, error);
    }
}

std::span<const std::byte> ImmutableFileView::bytes() const noexcept
{
    if (!mapping_ || byte_size_ == 0U)
        return { };
    return { reinterpret_cast<const std::byte*>(mapping_),
        static_cast<std::size_t>(byte_size_) };
}

std::span<const std::byte> ImmutableFileView::range(
    std::uint64_t offset, std::uint64_t size) const noexcept
{
    if (offset > byte_size_ || size > byte_size_ - offset ||
        offset > std::numeric_limits<std::size_t>::max() ||
        size > std::numeric_limits<std::size_t>::max()) {
        return { };
    }
    return bytes().subspan(
        static_cast<std::size_t>(offset), static_cast<std::size_t>(size));
}

std::shared_ptr<const ImmutableFileView> ImmutableFileView::open(
    const std::filesystem::path& source_path,
    const GuestFileGeneration& generation,
    const ContentIdentity& content_identity, std::uint64_t byte_size)
{
    if (byte_size == 0U ||
        byte_size > std::numeric_limits<std::size_t>::max() ||
        byte_size != generation.file_size) {
        return { };
    }

    const auto backing_path =
        shared_immutable_file_path(content_identity, byte_size);
    std::error_code error;
    std::filesystem::create_directories(backing_path.parent_path(), error);
    if (error)
        return { };
    std::filesystem::permissions(backing_path.parent_path(),
        std::filesystem::perms::owner_all,
        std::filesystem::perm_options::replace, error);
    error.clear();

    int descriptor = ::open(backing_path.c_str(), O_RDONLY | O_CLOEXEC);
    if (descriptor < 0 && errno == ENOENT) {
        if (!create_shared_immutable_file(
                source_path, generation, backing_path)) {
            return { };
        }
        descriptor = ::open(backing_path.c_str(), O_RDONLY | O_CLOEXEC);
    }
    if (descriptor < 0)
        return { };

    struct stat backing_stat { };
    if (::fstat(descriptor, &backing_stat) != 0 ||
        !S_ISREG(backing_stat.st_mode) ||
        (backing_stat.st_mode & (S_IWUSR | S_IWGRP | S_IWOTH)) != 0 ||
        static_cast<std::uint64_t>(backing_stat.st_size) != byte_size) {
        static_cast<void>(::close(descriptor));
        return { };
    }

    void* mapping = ::mmap(nullptr, static_cast<std::size_t>(byte_size),
        PROT_READ, MAP_SHARED, descriptor, 0);
    if (mapping == MAP_FAILED) {
        static_cast<void>(::close(descriptor));
        return { };
    }

    std::filesystem::path lease_path;
    const auto candidate_lease =
        backing_path.string() + ".lease-" + std::to_string(::getpid()) + "-" +
        std::to_string(
            next_reservation_identity.fetch_add(1, std::memory_order_relaxed));
    const auto lease_descriptor = ::open(
        candidate_lease.c_str(), O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0600);
    if (lease_descriptor < 0) {
        static_cast<void>(
            ::munmap(mapping, static_cast<std::size_t>(byte_size)));
        static_cast<void>(::close(descriptor));
        return { };
    }
    static_cast<void>(::close(lease_descriptor));
    lease_path = candidate_lease;
    reclaim_shared_immutable_files(backing_path.parent_path(), backing_path);
    return std::shared_ptr<const ImmutableFileView> { new ImmutableFileView(
        descriptor, mapping, byte_size, backing_path, std::move(lease_path),
        generation, content_identity) };
}

SharedFileIdentityResult shared_file_identity(const std::filesystem::path& path,
    int descriptor, const GuestFileGeneration& generation,
    std::optional<std::uint64_t> generation_revision, bool force_recompute)
{
    if (descriptor < 0)
        return { };
    const auto normalized_path = stable_path(path);
    std::optional<ContentIdentity> content_identity;
    std::shared_ptr<GlobalIdentityFlight> flight;
    bool compute = false;
    {
        const std::scoped_lock lock { global_identity_mutex };
        const auto identity = global_identities.find(normalized_path);
        if (!force_recompute && identity != global_identities.end() &&
            identity->second.generation == generation &&
            identity_revision_matches(
                identity->second.generation_revision, generation_revision)) {
            touch_global_identity_locked(identity);
            content_identity = identity->second.content_identity;
        } else {
            const auto existing_flight =
                global_identity_flights.find(normalized_path);
            if (existing_flight != global_identity_flights.end() &&
                existing_flight->second->generation == generation &&
                identity_revision_matches(
                    existing_flight->second->generation_revision,
                    generation_revision)) {
                flight = existing_flight->second;
            } else {
                flight = std::make_shared<GlobalIdentityFlight>();
                flight->generation = generation;
                flight->generation_revision = generation_revision;
                global_identity_flights[normalized_path] = flight;
                compute = true;
            }
        }
    }
    if (content_identity)
        return { content_identity, false };

    if (compute) {
        // Full-file I/O deliberately stays outside global_identity_mutex. The
        // second locked section only publishes if this flight still owns the
        // same generation/revision key; replacement invalidation can discard
        // it.
        const auto computed_identity = sha256_file(descriptor);
        {
            const std::scoped_lock lock { global_identity_mutex };
            const auto existing_flight =
                global_identity_flights.find(normalized_path);
            if (existing_flight != global_identity_flights.end() &&
                existing_flight->second == flight &&
                existing_flight->second->generation == generation &&
                identity_revision_matches(
                    existing_flight->second->generation_revision,
                    generation_revision)) {
                if (computed_identity) {
                    store_global_identity_locked(normalized_path,
                        GlobalIdentityRecord { generation, generation_revision,
                            *computed_identity, { }, { } });
                }
                global_identity_flights.erase(existing_flight);
            }
        }
        bool flight_computed = false;
        {
            const std::scoped_lock flight_lock { flight->mutex };
            if (!flight->complete) {
                flight->content_identity = computed_identity;
                flight->computed = true;
                flight->complete = true;
            }
            content_identity = flight->content_identity;
            flight_computed = flight->computed;
        }
        flight->condition.notify_all();
        return { content_identity, flight_computed };
    }

    if (!flight)
        return { };
    bool flight_computed = false;
    {
        std::unique_lock flight_lock { flight->mutex };
        flight->condition.wait(
            flight_lock, [&flight] { return flight->complete; });
        content_identity = flight->content_identity;
        flight_computed = flight->computed;
    }
    return { content_identity, flight_computed };
}

SharedFileIdentityResult shared_file_identity(const std::filesystem::path& path,
    std::optional<std::uint64_t> generation_revision)
{
    // Identity queries never write. A writable descriptor would emit a
    // write-close notification even without a write, causing the file watcher
    // to rehash and potentially invalidate an unchanged backing generation.
    const auto descriptor = ::open(path.c_str(), O_RDONLY | O_CLOEXEC);
    if (descriptor < 0)
        return { };
    struct stat file_stat { };
    if (::fstat(descriptor, &file_stat) != 0 || !S_ISREG(file_stat.st_mode) ||
        file_stat.st_size < 0) {
        static_cast<void>(::close(descriptor));
        return { };
    }
    const auto result = shared_file_identity(
        path, descriptor, generation_from_stat(file_stat), generation_revision);
    static_cast<void>(::close(descriptor));
    return result;
}

void seed_shared_file_identity(const std::filesystem::path& path,
    const GuestFileGeneration& generation,
    const ContentIdentity& content_identity,
    std::optional<std::uint64_t> generation_revision)
{
    publish_global_identity(stable_path(path), generation,
        std::move(generation_revision), content_identity);
}

ImmutableArtifactView::ImmutableArtifactView(int descriptor, void* mapping,
    std::size_t byte_size, std::filesystem::path lease_path) noexcept
    : descriptor_ { descriptor }
    , mapping_ { mapping }
    , byte_size_ { byte_size }
    , lease_path_ { std::move(lease_path) }
{
}

ImmutableArtifactView::~ImmutableArtifactView()
{
    if (mapping_ != nullptr && byte_size_ != 0U)
        static_cast<void>(::munmap(mapping_, byte_size_));
    if (descriptor_ >= 0)
        static_cast<void>(::close(descriptor_));
    if (!lease_path_.empty()) {
        std::error_code error;
        std::filesystem::remove(lease_path_, error);
    }
}

std::shared_ptr<const ImmutableArtifactView> ImmutableArtifactView::open(
    const std::filesystem::path& path, std::size_t maximum_size)
{
    const auto descriptor =
        ::open(path.c_str(), O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
    if (descriptor < 0)
        return { };
    struct stat artifact_stat { };
    if (::fstat(descriptor, &artifact_stat) != 0 ||
        !S_ISREG(artifact_stat.st_mode) ||
        (artifact_stat.st_mode & (S_IWUSR | S_IWGRP | S_IWOTH)) != 0 ||
        artifact_stat.st_size <= 0 ||
        static_cast<std::uint64_t>(artifact_stat.st_size) > maximum_size) {
        static_cast<void>(::close(descriptor));
        return { };
    }
    const auto byte_size = static_cast<std::size_t>(artifact_stat.st_size);
    void* mapping =
        ::mmap(nullptr, byte_size, PROT_READ, MAP_SHARED, descriptor, 0);
    if (mapping == MAP_FAILED) {
        static_cast<void>(::close(descriptor));
        return { };
    }
    const auto lease_path = std::filesystem::path {
        path.string() + ".lease-" + std::to_string(::getpid()) + "-" +
        std::to_string(
            next_reservation_identity.fetch_add(1, std::memory_order_relaxed))
    };
    const auto lease_descriptor = ::open(
        lease_path.c_str(), O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0600);
    if (lease_descriptor < 0) {
        static_cast<void>(::munmap(mapping, byte_size));
        static_cast<void>(::close(descriptor));
        return { };
    }
    static_cast<void>(::close(lease_descriptor));
    return std::shared_ptr<const ImmutableArtifactView> {
        new ImmutableArtifactView { descriptor, mapping, byte_size, lease_path }
    };
}

std::span<const std::byte> ImmutableArtifactView::bytes() const noexcept
{
    return { reinterpret_cast<const std::byte*>(mapping_), byte_size_ };
}

std::filesystem::path shared_immutable_artifact_root()
{
    return shared_immutable_file_root();
}

std::filesystem::path shared_immutable_artifact_named_path(
    std::string_view name)
{
    return shared_immutable_artifact_root() / std::string { name };
}

bool publish_shared_immutable_artifact(
    const std::filesystem::path& path, std::span<const std::byte> bytes)
{
    if (path.filename().empty() || bytes.empty())
        return false;

    std::error_code error;
    std::filesystem::create_directories(path.parent_path(), error);
    if (error)
        return false;
    std::filesystem::permissions(path.parent_path(),
        std::filesystem::perms::owner_all,
        std::filesystem::perm_options::replace, error);
    error.clear();

    const auto existing =
        ::open(path.c_str(), O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
    if (existing >= 0) {
        struct stat existing_stat { };
        const bool valid =
            ::fstat(existing, &existing_stat) == 0 &&
            S_ISREG(existing_stat.st_mode) &&
            (existing_stat.st_mode & (S_IWUSR | S_IWGRP | S_IWOTH)) == 0 &&
            static_cast<std::uint64_t>(existing_stat.st_size) == bytes.size();
        static_cast<void>(::close(existing));
        if (valid)
            return true;
    }

    const auto temporary = std::filesystem::path {
        path.string() + ".tmp-artifact-" + std::to_string(::getpid()) + "-" +
        std::to_string(
            next_reservation_identity.fetch_add(1, std::memory_order_relaxed))
    };
    const auto descriptor = ::open(
        temporary.c_str(), O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0600);
    if (descriptor < 0)
        return false;

    bool published = write_all(descriptor, bytes.data(), bytes.size()) &&
                     ::fsync(descriptor) == 0;
    if (published)
        static_cast<void>(::fchmod(descriptor, 0444));
    static_cast<void>(::close(descriptor));
    if (!published) {
        std::filesystem::remove(temporary, error);
        return false;
    }

    if (::rename(temporary.c_str(), path.c_str()) != 0) {
        std::filesystem::remove(temporary, error);
        return false;
    }
    return true;
}

std::optional<std::vector<std::byte>> read_shared_immutable_artifact(
    const std::filesystem::path& path, std::size_t maximum_size)
{
    const auto descriptor =
        ::open(path.c_str(), O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
    if (descriptor < 0)
        return std::nullopt;
    struct stat artifact_stat { };
    if (::fstat(descriptor, &artifact_stat) != 0 ||
        !S_ISREG(artifact_stat.st_mode) ||
        (artifact_stat.st_mode & (S_IWUSR | S_IWGRP | S_IWOTH)) != 0 ||
        artifact_stat.st_size <= 0 ||
        static_cast<std::uint64_t>(artifact_stat.st_size) > maximum_size) {
        static_cast<void>(::close(descriptor));
        return std::nullopt;
    }

    std::vector<std::byte> bytes(
        static_cast<std::size_t>(artifact_stat.st_size));
    std::size_t offset = 0;
    while (offset < bytes.size()) {
        const auto count = ::pread(descriptor,
            bytes.data() + static_cast<std::ptrdiff_t>(offset),
            bytes.size() - offset, static_cast<off_t>(offset));
        if (count < 0 && errno == EINTR)
            continue;
        if (count <= 0) {
            static_cast<void>(::close(descriptor));
            return std::nullopt;
        }
        offset += static_cast<std::size_t>(count);
    }
    static_cast<void>(::close(descriptor));
    return bytes;
}

std::shared_ptr<const std::vector<std::byte>> share_immutable_snapshot(
    const GuestFileGeneration& generation, const ContentIdentity& identity,
    std::shared_ptr<const std::vector<std::byte>> snapshot,
    std::uint64_t layout_tag, ImmutableSnapshotKind kind)
{
    if (!snapshot)
        return { };
    const auto byte_size = static_cast<std::uint64_t>(snapshot->size());
    const ImmutableSnapshotKey key { generation, identity, byte_size,
        layout_tag, kind };
    const auto limits = immutable_snapshot_limits();
    std::lock_guard lock { immutable_snapshot_mutex };
    if (const auto existing = immutable_snapshots.find(key);
        existing != immutable_snapshots.end()) {
        ++immutable_snapshot_hits;
        immutable_snapshot_lru.splice(immutable_snapshot_lru.end(),
            immutable_snapshot_lru, existing->second.lru_position);
        existing->second.lru_position = std::prev(immutable_snapshot_lru.end());
        return existing->second.snapshot;
    }

    immutable_snapshot_lru.push_back(key);
    const auto lru_position = std::prev(immutable_snapshot_lru.end());
    immutable_snapshots.emplace(
        key, ImmutableSnapshotRecord { snapshot, byte_size, lru_position });
    immutable_snapshot_bytes += byte_size;
    if (is_catalog_scan(key)) {
        ++immutable_snapshot_catalog_scan_entries;
        immutable_snapshot_catalog_scan_bytes += byte_size;
    } else {
        ++immutable_snapshot_runtime_hot_entries;
        immutable_snapshot_runtime_hot_bytes += byte_size;
    }
    while (
        (immutable_snapshot_bytes > limits.bytes ||
            immutable_snapshot_catalog_scan_bytes > limits.catalog_scan_bytes ||
            immutable_snapshots.size() > limits.entries) &&
        !immutable_snapshot_lru.empty()) {
        // Catalog scans are disposable metadata work. Prefer evicting them
        // while the combined cache is full so runtime mappings retain their hot
        // bytes.
        auto eviction_position = immutable_snapshot_lru.begin();
        if (const auto catalog_scan = std::find_if(
                immutable_snapshot_lru.begin(), immutable_snapshot_lru.end(),
                [](const ImmutableSnapshotKey& candidate) {
                    return is_catalog_scan(candidate);
                });
            catalog_scan != immutable_snapshot_lru.end()) {
            eviction_position = catalog_scan;
        }
        const auto evict_key = *eviction_position;
        immutable_snapshot_lru.erase(eviction_position);
        const auto evicted = immutable_snapshots.find(evict_key);
        if (evicted == immutable_snapshots.end())
            continue;
        immutable_snapshot_bytes -= evicted->second.byte_size;
        if (is_catalog_scan(evicted->first)) {
            --immutable_snapshot_catalog_scan_entries;
            immutable_snapshot_catalog_scan_bytes -= evicted->second.byte_size;
        } else {
            --immutable_snapshot_runtime_hot_entries;
            immutable_snapshot_runtime_hot_bytes -= evicted->second.byte_size;
        }
        ++immutable_snapshot_evictions;
        immutable_snapshots.erase(evicted);
    }
    return snapshot;
}

std::shared_ptr<const std::vector<std::byte>> find_immutable_snapshot(
    const GuestFileGeneration& generation, const ContentIdentity& identity,
    std::uint64_t byte_size, std::uint64_t layout_tag,
    ImmutableSnapshotKind kind)
{
    const ImmutableSnapshotKey key { generation, identity, byte_size,
        layout_tag, kind };
    std::lock_guard lock { immutable_snapshot_mutex };
    const auto existing = immutable_snapshots.find(key);
    if (existing == immutable_snapshots.end())
        return { };
    ++immutable_snapshot_hits;
    immutable_snapshot_lru.splice(immutable_snapshot_lru.end(),
        immutable_snapshot_lru, existing->second.lru_position);
    existing->second.lru_position = std::prev(immutable_snapshot_lru.end());
    return existing->second.snapshot;
}

ImmutableSnapshotStats immutable_snapshot_stats()
{
    std::lock_guard lock { immutable_snapshot_mutex };
    const auto limits = immutable_snapshot_limits();
    return ImmutableSnapshotStats { static_cast<std::uint64_t>(
                                        immutable_snapshots.size()),
        immutable_snapshot_bytes, immutable_snapshot_runtime_hot_entries,
        immutable_snapshot_runtime_hot_bytes,
        immutable_snapshot_catalog_scan_entries,
        immutable_snapshot_catalog_scan_bytes, limits.bytes,
        limits.catalog_scan_bytes, immutable_snapshot_hits,
        immutable_snapshot_evictions };
}

std::string GuestFileGenerationRegistry::normalize_path(
    const std::filesystem::path& path)
{
    std::error_code error;
    const auto absolute = std::filesystem::absolute(path, error);
    return (error ? path : absolute).lexically_normal().string();
}

std::optional<GuestFileGeneration> GuestFileGenerationRegistry::read_generation(
    const std::filesystem::path& path)
{
    struct stat file_stat { };
    if (::stat(path.c_str(), &file_stat) != 0)
        return std::nullopt;
    return generation_from_stat(file_stat);
}

std::map<std::string, GuestFileGenerationRegistry::Entry>::iterator
GuestFileGenerationRegistry::ensure_entry_locked(
    const std::string& normalized_path)
{
    const auto [iterator, inserted] = entries_.try_emplace(normalized_path);
    if (inserted) {
        entry_lru_.push_back(normalized_path);
        iterator->second.lru_position = std::prev(entry_lru_.end());
    } else {
        touch_entry_locked(iterator);
    }
    return iterator;
}

void GuestFileGenerationRegistry::touch_entry_locked(
    std::map<std::string, Entry>::iterator iterator)
{
    entry_lru_.splice(
        entry_lru_.end(), entry_lru_, iterator->second.lru_position);
    iterator->second.lru_position = std::prev(entry_lru_.end());
}

void GuestFileGenerationRegistry::erase_entry_locked(
    std::map<std::string, Entry>::iterator iterator)
{
    entry_lru_.erase(iterator->second.lru_position);
    entries_.erase(iterator);
}

void GuestFileGenerationRegistry::erase_subtree_entries_locked(
    const std::string& normalized_path)
{
    const std::filesystem::path subtree { normalized_path };
    for (auto iterator = entries_.begin(); iterator != entries_.end();) {
        const std::filesystem::path candidate { iterator->first };
        const auto relative = candidate.lexically_relative(subtree);
        const bool inside =
            candidate == subtree || (!relative.empty() && relative != "." &&
                                        relative.begin() != relative.end() &&
                                        *relative.begin() != "..");
        if (!inside) {
            ++iterator;
            continue;
        }
        const auto path = iterator->first;
        erase_entry_locked(iterator++);
        invalidate_global_identity(path);
    }
}

void GuestFileGenerationRegistry::evict_entries_locked()
{
    while (entries_.size() > maximum_tracked_paths && !entry_lru_.empty()) {
        const auto key = std::move(entry_lru_.front());
        entry_lru_.pop_front();
        const auto entry = entries_.find(key);
        if (entry != entries_.end())
            entries_.erase(entry);
    }
}

GuestFileGenerationSnapshot GuestFileGenerationRegistry::record(
    const std::filesystem::path& path,
    std::optional<GuestFileGeneration> generation,
    GuestFileMutationKind mutation, bool force_revision,
    std::optional<ContentIdentity> content_identity)
{
    const auto key = normalize_path(path);
    std::lock_guard lock { mutex_ };
    auto& entry = ensure_entry_locked(key)->second;
    if (!force_revision && entry.snapshot.revision != 0 &&
        entry.snapshot.generation == generation) {
        return entry.snapshot;
    }
    entry.snapshot = GuestFileGenerationSnapshot { next_revision_++,
        std::move(generation), mutation, std::move(content_identity) };
    invalidate_global_identity(key);
    enqueue_mutation_locked(key, mutation);
    evict_entries_locked();
    return entry.snapshot;
}

void GuestFileGenerationRegistry::enqueue_mutation_locked(
    const std::string& normalized_path, GuestFileMutationKind mutation)
{
    if (mutation == GuestFileMutationKind::Observation)
        return;
    mutation_generation_.fetch_add(1U, std::memory_order_release);
    for (auto event = pending_mutations_.rbegin();
        event != pending_mutations_.rend(); ++event) {
        if (event->path.string() != normalized_path)
            continue;
        if (mutation_priority(mutation) > mutation_priority(event->mutation)) {
            event->mutation = mutation;
        }
        return;
    }
    if (pending_mutations_.size() >= maximum_pending_mutations) {
        // Once an event is evicted, retaining the remaining path-level queue is
        // no longer a complete description of the tree.  Publish one structural
        // marker instead; the catalog consumer will rescan its bounded root and
        // recover every lost create, rename, and unlink deterministically.
        pending_mutations_.clear();
        pending_mutations_.push_back(GuestFileMutationEvent {
            next_mutation_sequence_++, std::filesystem::path { "/" },
            GuestFileMutationKind::Rename, true });
        return;
    }
    pending_mutations_.push_back(
        GuestFileMutationEvent { next_mutation_sequence_++,
            std::filesystem::path { normalized_path }, mutation });
}

GuestFileGenerationSnapshot GuestFileGenerationRegistry::observe_normalized(
    std::string normalized_path, const GuestFileGeneration& generation)
{
    const auto key = normalized_path;
    std::lock_guard lock { mutex_ };
    auto& entry = ensure_entry_locked(normalized_path)->second;
    if (entry.snapshot.revision != 0 &&
        entry.snapshot.generation == generation) {
        return entry.snapshot;
    }
    entry.snapshot = GuestFileGenerationSnapshot { next_revision_++, generation,
        GuestFileMutationKind::Observation, std::nullopt };
    invalidate_global_identity(key);
    evict_entries_locked();
    return entry.snapshot;
}

GuestFileGenerationSnapshot GuestFileGenerationRegistry::record_descriptor(
    const std::filesystem::path& path, const GuestFileGeneration& generation,
    GuestFileMutationKind mutation,
    std::optional<ContentIdentity> content_identity)
{
    const auto key = normalize_path(path);
    // The descriptor may have outlived an atomic replacement or unlink.  A
    // descriptor opened by the watcher is current only if the pathname still
    // resolves to the same vnode when publication reaches this point; this
    // check prevents detached Guest writeback from resurrecting an old path.
    const auto current_path_generation = read_generation(path);
    std::lock_guard lock { mutex_ };
    const auto current_entry = entries_.find(key);
    if (!current_path_generation || *current_path_generation != generation) {
        if (current_entry != entries_.end())
            return current_entry->second.snapshot;
        return { };
    }
    std::optional<GuestFileGenerationSnapshot> result;
    bool matched_key = false;
    for (auto iterator = entries_.begin(); iterator != entries_.end();
        ++iterator) {
        auto& [entry_path, entry] = *iterator;
        if (!entry.snapshot.generation ||
            entry.snapshot.generation->device != generation.device ||
            entry.snapshot.generation->inode != generation.inode) {
            continue;
        }
        if (entry_path == key)
            matched_key = true;
        touch_entry_locked(iterator);
        entry.snapshot = GuestFileGenerationSnapshot { next_revision_++,
            generation, mutation, content_identity };
        invalidate_global_identity(entry_path);
        enqueue_mutation_locked(entry_path, mutation);
        if (entry_path == key || !result)
            result = entry.snapshot;
    }
    if (!matched_key) {
        // Descriptor identity and namespace identity are separate. A descriptor
        // may refer to an inode already known through another alias, but the
        // event's pathname still needs its own generation record. The
        // current-path check above has already ruled out a detached old vnode.
        auto& entry = ensure_entry_locked(key)->second;
        entry.snapshot = GuestFileGenerationSnapshot { next_revision_++,
            generation, mutation, std::move(content_identity) };
        invalidate_global_identity(key);
        enqueue_mutation_locked(key, mutation);
        result = entry.snapshot;
    }
    evict_entries_locked();
    return *result;
}

GuestFileGenerationSnapshot GuestFileGenerationRegistry::observe(
    const std::filesystem::path& path)
{
    return record(
        path, read_generation(path), GuestFileMutationKind::Observation, false);
}

GuestFileGenerationSnapshot GuestFileGenerationRegistry::publish(
    const std::filesystem::path& path, GuestFileMutationKind mutation)
{
    return record(path, read_generation(path), mutation, true);
}

GuestFileGenerationSnapshot GuestFileGenerationRegistry::publish_descriptor(
    const std::filesystem::path& path, int file_descriptor,
    GuestFileMutationKind mutation,
    std::optional<ContentIdentity> content_identity)
{
    struct stat file_stat { };
    if (file_descriptor < 0 || ::fstat(file_descriptor, &file_stat) != 0) {
        return publish(path, mutation);
    }
    auto result = record_descriptor(path, generation_from_stat(file_stat),
        mutation, std::move(content_identity));
    if (result.generation && result.content_identity) {
        seed_shared_file_identity(path, *result.generation,
            *result.content_identity, result.revision);
    }
    return result;
}

void GuestFileGenerationRegistry::publish_rename(
    const std::filesystem::path& source,
    const std::filesystem::path& destination)
{
    static_cast<void>(publish(source, GuestFileMutationKind::Rename));
    static_cast<void>(publish(destination, GuestFileMutationKind::Rename));
}

void GuestFileGenerationRegistry::publish_subtree_create(
    const std::filesystem::path& path)
{
    const auto normalized = normalize_path(path);
    {
        std::lock_guard lock { mutex_ };
        erase_subtree_entries_locked(normalized);
    }
    static_cast<void>(publish(path, GuestFileMutationKind::SubtreeCreate));
}

void GuestFileGenerationRegistry::publish_subtree_remove(
    const std::filesystem::path& path)
{
    const auto normalized = normalize_path(path);
    {
        std::lock_guard lock { mutex_ };
        erase_subtree_entries_locked(normalized);
    }
    static_cast<void>(publish(path, GuestFileMutationKind::SubtreeRemove));
}

void GuestFileGenerationRegistry::publish_subtree_rename(
    const std::filesystem::path& source,
    const std::filesystem::path& destination)
{
    publish_subtree_remove(source);
    publish_subtree_create(destination);
}

std::vector<GuestFileMutationEvent> GuestFileGenerationRegistry::take_mutations(
    std::size_t maximum_events)
{
    std::vector<GuestFileMutationEvent> result;
    if (maximum_events == 0)
        return result;
    std::lock_guard lock { mutex_ };
    const auto count = std::min(maximum_events, pending_mutations_.size());
    result.reserve(count);
    for (std::size_t index = 0; index < count; ++index) {
        result.push_back(std::move(pending_mutations_.front()));
        pending_mutations_.pop_front();
    }
    return result;
}

std::size_t GuestFileGenerationRegistry::pending_mutation_count() const
{
    std::lock_guard lock { mutex_ };
    return pending_mutations_.size();
}

std::optional<GuestFileGenerationSnapshot> GuestFileGenerationRegistry::current(
    const std::filesystem::path& path) const
{
    const auto key = normalize_path(path);
    std::lock_guard lock { mutex_ };
    const auto entry = entries_.find(key);
    if (entry == entries_.end())
        return std::nullopt;
    return entry->second.snapshot;
}

std::size_t GuestFileGenerationRegistry::tracked_path_count() const
{
    std::lock_guard lock { mutex_ };
    return entries_.size();
}

GuestFileIoState::~GuestFileIoState()
{
    if (file_descriptor >= 0) {
        static_cast<void>(::close(file_descriptor));
    }
}

bool GuestFileIoState::synchronize()
{
    const std::scoped_lock file_lock { mutex };
    if (file_descriptor < 0)
        return false;
    int result;
    do {
        result = ::fsync(file_descriptor);
    } while (result < 0 && errno == EINTR);
    return result == 0;
}

GuestPageBacking::GuestPageBacking()
    : reservation_identity_ { next_reservation_identity.fetch_add(
          1, std::memory_order_relaxed) }
{
}

GuestPageBacking::GuestPageBacking(const GuestPageBacking& other)
{
    other.materialize();
    const std::scoped_lock lock { other.mutex_ };
    bytes = other.bytes;
    reservation_identity_.store(
        next_reservation_identity.fetch_add(1, std::memory_order_relaxed),
        std::memory_order_release);
}

GuestPageBacking::~GuestPageBacking()
{
    delete reservation_granules_.load(std::memory_order_relaxed);
}

std::uint64_t GuestPageBacking::reservation_identity(
    std::uint32_t offset) const noexcept
{
    auto* granules = reservation_granules_.load(std::memory_order_acquire);
    if (granules == nullptr) {
        auto candidate = std::make_unique<ReservationGranules>();
        const auto identity =
            reservation_identity_.load(std::memory_order_relaxed);
        for (auto& granule : *candidate)
            granule.store(identity, std::memory_order_relaxed);
        granules = nullptr;
        if (reservation_granules_.compare_exchange_strong(granules,
                candidate.get(), std::memory_order_release,
                std::memory_order_acquire))
            granules = candidate.release();
    }
    return (*granules)[offset / guest_exclusive_granule_size].load(
        std::memory_order_acquire);
}

void GuestPageBacking::invalidate_reservation_identity(
    std::uint32_t offset, std::size_t size) noexcept
{
    auto* granules = reservation_granules_.load(std::memory_order_acquire);
    if (granules == nullptr || size == 0)
        return;
    const auto end =
        std::min<std::size_t>(guest_memory_page_size, offset + size);
    const auto identity =
        next_reservation_identity.fetch_add(1, std::memory_order_relaxed);
    for (auto index = offset / guest_exclusive_granule_size;
        index <
        (end + guest_exclusive_granule_size - 1) / guest_exclusive_granule_size;
        ++index)
        (*granules)[index].store(identity, std::memory_order_release);
}

void GuestPageBacking::materialize() const
{
    if (!has_file_source_)
        return;
    const std::scoped_lock page_lock { mutex_ };
    if (!file_backing_)
        return;

    const auto file = file_backing_;
    std::fill(bytes.begin(), bytes.end(), std::byte { });
    if (file->immutable_file_view) {
        const auto snapshot =
            file->immutable_file_view->range(file_offset_, file_byte_count_);
        std::copy(snapshot.begin(), snapshot.end(), bytes.begin());
        file_backing_.reset();
        return;
    }
    if (file->immutable_snapshot) {
        const auto& snapshot = *file->immutable_snapshot;
        if (file_offset_ < snapshot.size()) {
            const auto available =
                snapshot.size() - static_cast<std::size_t>(file_offset_);
            const auto copied =
                std::min<std::size_t>(file_byte_count_, available);
            std::copy_n(
                snapshot.begin() + static_cast<std::ptrdiff_t>(file_offset_),
                copied, bytes.begin());
        }
        file_backing_.reset();
        return;
    }
    const auto io_state = file->io_state;
    const std::scoped_lock file_lock { io_state->mutex };
    if (const auto prefetched_page =
            io_state->prefetched_pages.find(file_offset_);
        prefetched_page != io_state->prefetched_pages.end()) {
        bytes = prefetched_page->second;
        io_state->prefetched_pages.erase(prefetched_page);
    } else {
        const auto aligned_start = file_offset_ & ~(file_prefetch_bytes - 1U);
        const auto read_start = std::max(file->first_offset, aligned_start);
        const auto read_size =
            std::min(file->end_offset - read_start, file_prefetch_bytes);
        const auto read_pages = static_cast<std::size_t>(
            (read_size + guest_memory_page_size - 1U) / guest_memory_page_size);
        if (io_state->file_descriptor >= 0 &&
            read_start <=
                static_cast<std::uint64_t>(std::numeric_limits<off_t>::max())) {
            std::vector<std::byte> batch(static_cast<std::size_t>(read_size));
            std::size_t received = 0;
            while (received < batch.size()) {
                ssize_t count = -1;
                do {
                    count = ::pread(io_state->file_descriptor,
                        batch.data() + received, batch.size() - received,
                        static_cast<off_t>(read_start + received));
                } while (count < 0 && errno == EINTR);
                if (count <= 0)
                    break;
                received += static_cast<std::size_t>(count);
            }
            for (std::size_t index = 0; index < read_pages; ++index) {
                const auto offset = index * guest_memory_page_size;
                GuestPageBytes page_bytes { };
                if (offset < batch.size()) {
                    const auto count = std::min<std::size_t>(
                        guest_memory_page_size, batch.size() - offset);
                    std::copy_n(
                        batch.begin() + static_cast<std::ptrdiff_t>(offset),
                        count, page_bytes.begin());
                }
                const auto page_offset =
                    read_start + static_cast<std::uint64_t>(offset);
                if (page_offset == file_offset_) {
                    bytes = page_bytes;
                } else if (received > offset) {
                    io_state->prefetched_pages.emplace(
                        page_offset, std::move(page_bytes));
                }
            }
        }
    }
    file_backing_.reset();
}

bool GuestPageBacking::enable_shared_write_tracking()
{
    bool expected = false;
    if (!shared_write_tracking_.compare_exchange_strong(expected, true,
            std::memory_order_acq_rel, std::memory_order_acquire)) {
        return false;
    }
    static_cast<void>(global_shared_write_tracking_epoch.fetch_add(
        1, std::memory_order_release));
    return true;
}

bool GuestPageBacking::shared_write_tracking_enabled() const
{
    return shared_write_tracking_.load(std::memory_order_acquire);
}

std::uint64_t GuestPageBacking::shared_write_tracking_epoch()
{
    return global_shared_write_tracking_epoch.load(std::memory_order_acquire);
}

std::uint64_t GuestPageBacking::shared_write_generation() const
{
    return shared_write_generation_.load(std::memory_order_acquire);
}

void GuestPageBacking::mark_shared_write()
{
    if (!shared_write_tracking_enabled())
        return;
    publish_shared_write();
}

void GuestPageBacking::publish_shared_write() noexcept
{
    static_cast<void>(
        shared_write_generation_.fetch_add(1, std::memory_order_release));
}

bool GuestPageBacking::file_backed() const
{
    return static_cast<bool>(file_writeback_);
}

std::shared_ptr<GuestFileIoState> GuestPageBacking::writeback_io_state() const
{
    return file_writeback_ ? file_writeback_->io_state : nullptr;
}

bool GuestPageBacking::flush_file()
{
    if (!file_writeback_)
        return true;

    GuestPageBytes snapshot { };
    {
        const std::scoped_lock page_lock { mutex_ };
        snapshot = bytes;
    }

    const auto file = file_writeback_;
    const auto io_state = file->io_state;
    const std::scoped_lock file_lock { io_state->mutex };
    const auto descriptor = io_state->file_descriptor;
    if (descriptor < 0)
        return false;

    std::size_t written = 0;
    while (written < file_byte_count_) {
        const auto result = ::pwrite(descriptor,
            reinterpret_cast<const char*>(snapshot.data()) + written,
            file_byte_count_ - written,
            static_cast<off_t>(file_offset_ + written));
        if (result < 0 && errno == EINTR)
            continue;
        if (result <= 0)
            break;
        written += static_cast<std::size_t>(result);
    }
    const bool complete = written == file_byte_count_;
    if (complete) {
        if (const auto registry = file->generation_registry.lock()) {
            static_cast<void>(registry->publish_descriptor(file->path,
                descriptor, GuestFileMutationKind::SharedWriteback));
        }
    }
    return complete;
}

bool FilePageCache::Key::operator<(const Key& other) const
{
    return std::tie(path, generation, generation_revision, content_identity,
               file_offset, byte_count, immutable_snapshot) <
           std::tie(other.path, other.generation, other.generation_revision,
               other.content_identity, other.file_offset, other.byte_count,
               other.immutable_snapshot);
}

void FilePageCache::touch_locked(std::map<Key, PageRecord>::iterator iterator)
{
    lru_.splice(lru_.end(), lru_, iterator->second.lru_position);
    iterator->second.lru_position = std::prev(lru_.end());
}

void FilePageCache::touch_identity_locked(
    std::map<std::string, Identity>::iterator iterator)
{
    identity_lru_.splice(
        identity_lru_.end(), identity_lru_, iterator->second.lru_position);
    iterator->second.lru_position = std::prev(identity_lru_.end());
}

void FilePageCache::store_identity_locked(
    const std::string& path, Identity identity)
{
    const auto existing = identities_.find(path);
    if (existing == identities_.end()) {
        identity_lru_.push_back(path);
        identity.lru_position = std::prev(identity_lru_.end());
        identities_.emplace(path, std::move(identity));
    } else {
        identity.lru_position = existing->second.lru_position;
        existing->second = std::move(identity);
        touch_identity_locked(existing);
    }
    evict_identity_locked();
}

void FilePageCache::erase_identity_locked(
    std::map<std::string, Identity>::iterator iterator)
{
    identity_lru_.erase(iterator->second.lru_position);
    identities_.erase(iterator);
}

void FilePageCache::evict_identity_locked()
{
    if (limits_.maximum_identity_entries == 0U)
        return;
    while (identities_.size() > limits_.maximum_identity_entries &&
           !identity_lru_.empty()) {
        const auto key = std::move(identity_lru_.front());
        identity_lru_.pop_front();
        const auto identity = identities_.find(key);
        if (identity != identities_.end())
            identities_.erase(identity);
    }
}

void FilePageCache::erase_path_locked(const std::string& path)
{
    if (const auto identity = identities_.find(path);
        identity != identities_.end()) {
        erase_identity_locked(identity);
    }
    for (auto page = pages_.begin(); page != pages_.end();) {
        if (page->first.path != path) {
            ++page;
            continue;
        }
        lru_.erase(page->second.lru_position);
        page = pages_.erase(page);
    }
}

void FilePageCache::evict_locked()
{
    if (limits_.maximum_pages == 0U)
        return;
    while (pages_.size() > limits_.maximum_pages && !lru_.empty()) {
        const auto key = lru_.front();
        lru_.pop_front();
        const auto page = pages_.find(key);
        if (page != pages_.end())
            pages_.erase(page);
    }
}

void FilePageCache::prune_mutable_pages_locked()
{
    std::erase_if(mutable_pages_,
        [](const auto& entry) { return entry.second.expired(); });
    mutable_page_insertions_since_prune_ = 0;
}

FilePageCache::FilePageCache(FilePageCacheLimits limits,
    std::shared_ptr<GuestFileGenerationRegistry> generation_registry)
    : limits_ { limits }
    , generation_registry_ {
        generation_registry ? std::move(generation_registry)
                            : std::make_shared<GuestFileGenerationRegistry>()
    }
{
}

void FilePageCache::set_generation_registry(
    std::shared_ptr<GuestFileGenerationRegistry> generation_registry)
{
    if (!generation_registry) {
        generation_registry = std::make_shared<GuestFileGenerationRegistry>();
    }
    std::lock_guard lock { mutex_ };
    generation_registry_ = std::move(generation_registry);
}

std::optional<std::shared_ptr<GuestFileBacking>> FilePageCache::open_mapping(
    const std::filesystem::path& path, std::uint64_t file_offset,
    std::uint32_t size, std::optional<GuestFileGeneration> expected_generation,
    std::optional<ContentIdentity> expected_content_identity,
    std::shared_ptr<const std::vector<std::byte>> immutable_snapshot,
    std::shared_ptr<const ImmutableFileView> immutable_file_view,
    std::shared_ptr<const GuestFileBacking> reusable_mapping)
{
    if (size == 0 || file_offset % guest_memory_page_size != 0) {
        return std::nullopt;
    }

    const auto reusable =
        reusable_mapping && !immutable_file_view && !immutable_snapshot &&
                !reusable_mapping->immutable_file_view &&
                !reusable_mapping->immutable_snapshot &&
                reusable_mapping->path == path &&
                (!expected_generation ||
                    *expected_generation == reusable_mapping->generation) &&
                (!expected_content_identity ||
                    *expected_content_identity ==
                        reusable_mapping->content_identity)
            ? std::move(reusable_mapping)
            : std::shared_ptr<const GuestFileBacking> { };
    bool borrowed_descriptor = false;
    int descriptor = -1;
    if (reusable) {
        const auto& io_state = reusable->io_state;
        if (!io_state)
            return std::nullopt;
        const std::scoped_lock lock { io_state->mutex };
        descriptor = io_state->file_descriptor;
        if (descriptor < 0)
            return std::nullopt;
        borrowed_descriptor = true;
    } else if (!immutable_file_view) {
        descriptor = open_file_descriptor(path);
        if (descriptor < 0)
            return std::nullopt;
    }
    const auto close_descriptor = [&]() {
        if (descriptor >= 0 && !borrowed_descriptor) {
            static_cast<void>(::close(descriptor));
        }
        descriptor = -1;
    };

    struct stat file_stat { };
    std::uintmax_t file_size { };
    GuestFileGeneration generation { };
    std::filesystem::file_time_type modified { };
    if (immutable_file_view) {
        file_size = immutable_file_view->size();
        generation = immutable_file_view->generation();
    } else {
        if (::fstat(descriptor, &file_stat) != 0 ||
            !S_ISREG(file_stat.st_mode) || file_stat.st_size < 0) {
            close_descriptor();
            return std::nullopt;
        }
        file_size = static_cast<std::uintmax_t>(file_stat.st_size);
        generation = generation_from_stat(file_stat);
        modified = file_time_from_stat(file_stat);
    }
    if (reusable && generation != reusable->generation) {
        close_descriptor();
        return std::nullopt;
    }
    if (immutable_snapshot && immutable_snapshot->size() != file_size) {
        close_descriptor();
        return std::nullopt;
    }
    if (expected_generation && *expected_generation != generation) {
        close_descriptor();
        return std::nullopt;
    }
    if (file_offset > file_size) {
        close_descriptor();
        return std::nullopt;
    }
    const auto available = file_size - file_offset;
    const auto page_rounded_available =
        (available + guest_memory_page_size - 1U) &
        ~(static_cast<std::uintmax_t>(guest_memory_page_size) - 1U);
    if (size > page_rounded_available) {
        close_descriptor();
        return std::nullopt;
    }
    // An immutable view already carries the exact generation and content
    // identity. Use its content-addressed backing as the page-cache key and
    // avoid rebuilding the guest namespace path for every shared-cache range.
    // Ordinary mappings retain the namespace/canonical split below because
    // their path can be replaced while a descriptor remains alive.
    const auto normalized_path =
        immutable_file_view ? immutable_file_view->backing_path().string()
        : reusable          ? reusable->cache_path
                            : stable_path(path);
    const auto namespace_key = immutable_file_view || reusable
                                   ? std::string { }
                                   : namespace_path(path);
    std::shared_ptr<GuestFileGenerationRegistry> generation_registry;
    std::uint64_t generation_revision = 0;
    {
        const std::scoped_lock lock { mutex_ };
        generation_registry = generation_registry_;
    }
    if (reusable) {
        generation_revision = reusable->generation_revision;
    } else if (generation_registry && !immutable_file_view) {
        generation_revision =
            generation_registry->observe_normalized(namespace_key, generation)
                .revision;
    }
    std::optional<ContentIdentity> content_identity;
    if (immutable_file_view) {
        content_identity = immutable_file_view->content_identity();
    } else if (reusable) {
        const std::scoped_lock lock { mutex_ };
        ++stats_.identity_queries;
        ++stats_.identity_hits;
        content_identity = reusable->content_identity;
    } else {
        const std::scoped_lock lock { mutex_ };
        ++stats_.identity_queries;
        const auto identity = identities_.find(normalized_path);
        if (identity != identities_.end() &&
            identity->second.generation == generation &&
            identity->second.generation_revision == generation_revision) {
            touch_identity_locked(identity);
            content_identity = identity->second.content_identity;
            ++stats_.identity_hits;
        } else {
            if (identity != identities_.end()) {
                erase_path_locked(normalized_path);
                ++stats_.generation_invalidations;
            }
        }
    }
    if (!content_identity && expected_content_identity && immutable_snapshot) {
        // MachOImage has already read and generation-validated this immutable
        // snapshot. Reuse its identity directly so mapping the parsed image
        // does not hash the same bytes a second time.
        content_identity = *expected_content_identity;
        seed_shared_file_identity(normalized_path, generation,
            *content_identity, generation_revision);
        const std::scoped_lock lock { mutex_ };
        store_identity_locked(
            normalized_path, Identity { generation, generation_revision,
                                 *content_identity, { } });
        ++stats_.identity_hits;
    }
    if (!content_identity) {
        const auto identity_result = shared_file_identity(
            normalized_path, descriptor, generation, generation_revision);
        content_identity = identity_result.content_identity;
        if (!content_identity) {
            close_descriptor();
            return std::nullopt;
        }
        const std::scoped_lock lock { mutex_ };
        if (identity_result.computed) {
            ++stats_.sha_computations;
            stats_.sha_bytes += static_cast<std::uint64_t>(file_size);
        } else {
            ++stats_.identity_hits;
        }
        store_identity_locked(
            normalized_path, Identity { generation, generation_revision,
                                 *content_identity, { } });
    }
    if (!immutable_file_view) {
        struct stat final_file_stat { };
        if (::fstat(descriptor, &final_file_stat) != 0 ||
            !same_file_stat(file_stat, final_file_stat)) {
            close_descriptor();
            return std::nullopt;
        }
    }
    if (expected_content_identity &&
        *expected_content_identity != *content_identity) {
        close_descriptor();
        return std::nullopt;
    }

    // Every immutable executable mapping used to retain its own descriptor.
    // Firmware fork fan-out maps the same binaries into many AddressSpaces and
    // can therefore exhaust a normal host RLIMIT_NOFILE even though only a
    // modest number of distinct vnodes are in use. Share the descriptor for an
    // unchanged canonical path/generation; replacement installs a new record
    // while existing mappings keep the old vnode alive through their shared
    // state.
    std::shared_ptr<GuestFileIoState> io_state;
    if (reusable) {
        io_state = reusable->io_state;
    } else if (!immutable_file_view) {
        const std::scoped_lock lock { global_identity_mutex };
        const auto identity = global_identities.find(normalized_path);
        if (identity != global_identities.end() &&
            identity->second.generation == generation &&
            identity_revision_matches(
                identity->second.generation_revision, generation_revision) &&
            identity->second.content_identity == *content_identity) {
            touch_global_identity_locked(identity);
            io_state = identity->second.io_state.lock();
            if (!io_state) {
                io_state = std::make_shared<GuestFileIoState>();
                io_state->file_descriptor = descriptor;
                descriptor = -1;
                identity->second.io_state = io_state;
            }
        }
    }
    if (!io_state) {
        io_state = std::make_shared<GuestFileIoState>();
        io_state->file_descriptor = descriptor;
        descriptor = -1;
    } else {
        close_descriptor();
    }

    auto mapping = std::make_shared<GuestFileBacking>(path, file_offset,
        file_offset + std::min<std::uintmax_t>(size, available));
    mapping->cache_path = normalized_path;
    mapping->file_size = file_size;
    mapping->modified = modified;
    mapping->generation = generation;
    mapping->generation_revision = generation_revision;
    mapping->content_identity = *content_identity;
    mapping->immutable_snapshot = std::move(immutable_snapshot);
    mapping->immutable_file_view = std::move(immutable_file_view);
    mapping->generation_registry = generation_registry;
    mapping->io_state = std::move(io_state);
    return mapping;
}

std::shared_ptr<GuestPageBacking> FilePageCache::load_page(
    const std::shared_ptr<GuestFileBacking>& mapping, std::uint64_t file_offset,
    std::uint32_t byte_count)
{
    const Key key { mapping->cache_path, mapping->generation,
        mapping->generation_revision, mapping->content_identity, file_offset,
        byte_count,
        static_cast<bool>(mapping->immutable_snapshot) ||
            static_cast<bool>(mapping->immutable_file_view) };
    {
        const std::scoped_lock lock { mutex_ };
        if (const auto cached = pages_.find(key); cached != pages_.end()) {
            touch_locked(cached);
            return cached->second.page;
        }
    }

    auto page = std::make_shared<GuestPageBacking>();
    page->file_backing_ = mapping;
    page->file_writeback_ = mapping;
    page->file_offset_ = file_offset;
    page->file_byte_count_ = byte_count;
    page->has_file_source_ = true;
    {
        const std::scoped_lock lock { mutex_ };
        const auto [entry, inserted] = pages_.try_emplace(key, PageRecord { });
        if (!inserted) {
            touch_locked(entry);
            return entry->second.page;
        }
        entry->second.page = page;
        lru_.push_back(key);
        entry->second.lru_position = std::prev(lru_.end());
        if (!key.immutable_snapshot) {
            mutable_pages_.emplace(MutablePageKey { mapping->generation.device,
                                       mapping->generation.inode, file_offset },
                page);
            if (++mutable_page_insertions_since_prune_ >= 1024U)
                prune_mutable_pages_locked();
        }
        evict_locked();
        return page;
    }
}

std::optional<std::vector<std::shared_ptr<GuestPageBacking>>>
FilePageCache::load_pages(const std::filesystem::path& path,
    std::uint64_t file_offset, std::uint32_t size)
{
    const auto mapping = open_mapping(path, file_offset, size);
    if (!mapping)
        return std::nullopt;

    std::vector<std::shared_ptr<GuestPageBacking>> result;
    result.reserve(static_cast<std::size_t>(
        (static_cast<std::uint64_t>(size) + guest_memory_page_size - 1U) /
        guest_memory_page_size));
    for (std::uint64_t offset = file_offset; offset < file_offset + size;
        offset += guest_memory_page_size) {
        const auto byte_count =
            static_cast<std::uint32_t>(std::min<std::uint64_t>(
                guest_memory_page_size, file_offset + size - offset));
        if (offset > static_cast<std::uint64_t>(
                         std::numeric_limits<std::streamoff>::max())) {
            return std::nullopt;
        }
        result.push_back(load_page(*mapping, offset, byte_count));
    }
    return result;
}

std::size_t FilePageCache::reflect_descriptor_write(int file_descriptor,
    std::uint64_t file_offset, std::span<const std::byte> bytes)
{
    if (file_descriptor < 0 || bytes.empty() ||
        bytes.size() - 1U >
            std::numeric_limits<std::uint64_t>::max() - file_offset) {
        return 0;
    }

    struct stat status { };
    if (::fstat(file_descriptor, &status) != 0)
        return 0;

    const auto device = static_cast<std::uint64_t>(status.st_dev);
    const auto inode = static_cast<std::uint64_t>(status.st_ino);
    const auto last_offset = file_offset + bytes.size() - 1U;
    const auto first_page =
        file_offset & ~(std::uint64_t { guest_memory_page_size } - 1U);
    const auto last_page =
        last_offset & ~(std::uint64_t { guest_memory_page_size } - 1U);

    std::vector<std::shared_ptr<GuestPageBacking>> pages;
    {
        const std::scoped_lock lock { mutex_ };
        for (auto page_offset = first_page;;
            page_offset += guest_memory_page_size) {
            const auto [begin, end] = mutable_pages_.equal_range(
                MutablePageKey { device, inode, page_offset });
            for (auto page = begin; page != end;) {
                if (auto backing = page->second.lock()) {
                    pages.push_back(std::move(backing));
                    ++page;
                } else {
                    page = mutable_pages_.erase(page);
                }
            }
            if (page_offset == last_page)
                break;
        }
    }

    std::size_t updated_pages = 0;
    for (const auto& page : pages) {
        page->materialize();
        const auto page_begin = page->file_offset_;
        const auto page_end = page_begin + page->file_byte_count_;
        const auto update_begin = std::max(file_offset, page_begin);
        const auto update_end = std::min(file_offset + bytes.size(), page_end);
        if (update_begin >= update_end)
            continue;

        const auto source_offset =
            static_cast<std::size_t>(update_begin - file_offset);
        const auto page_offset =
            static_cast<std::size_t>(update_begin - page_begin);
        const auto count = static_cast<std::size_t>(update_end - update_begin);
        {
            const std::scoped_lock page_lock { page->mutex_ };
            std::copy_n(
                bytes.begin() + static_cast<std::ptrdiff_t>(source_offset),
                count,
                page->bytes.begin() + static_cast<std::ptrdiff_t>(page_offset));
        }
        page->invalidate_reservation_identity(
            static_cast<std::uint32_t>(page_offset), count);
        page->publish_shared_write();
        ++updated_pages;
    }
    return updated_pages;
}

std::size_t FilePageCache::page_count() const
{
    const std::scoped_lock lock { mutex_ };
    return pages_.size();
}

FilePageCacheStats FilePageCache::stats() const
{
    const std::scoped_lock lock { mutex_ };
    return stats_;
}

} // namespace shade
