// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Monitor filesystem structure changes and report bounded executable-
// catalog invalidations.

#include "foundation/host_file_watcher.hpp"

#include "foundation/host_resource_controller.hpp"

#include <algorithm>
#include <array>
#include <cerrno>
#include <chrono>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <string>
#include <string_view>
#include <system_error>

#if defined(__linux__)
#include <fcntl.h>
#include <sys/inotify.h>
#include <sys/stat.h>
#include <unistd.h>

#if defined(__APPLE__)
#define st_atim st_atimespec
#define st_mtim st_mtimespec
#define st_ctim st_ctimespec
#endif
#endif

namespace shade {
namespace {

    constexpr auto stable_delay = std::chrono::milliseconds { 50 };
    constexpr std::size_t maximum_watches = 16'384;
    constexpr std::size_t maximum_dirty_subtrees = 64;

    [[nodiscard]] int mutation_priority(GuestFileMutationKind mutation)
    {
        switch (mutation) {
        case GuestFileMutationKind::InstallReplace:
        case GuestFileMutationKind::Rename:
        case GuestFileMutationKind::Unlink:
            return 3;
        case GuestFileMutationKind::SubtreeCreate:
        case GuestFileMutationKind::SubtreeRemove:
            return 4;
        case GuestFileMutationKind::Truncate:
        case GuestFileMutationKind::SharedWriteback:
            return 2;
        case GuestFileMutationKind::Write:
            return 1;
        case GuestFileMutationKind::Observation:
            return 0;
        }
        return 0;
    }

    [[nodiscard]] std::filesystem::path normalize_path(
        const std::filesystem::path& path)
    {
        std::error_code error;
        const auto absolute = std::filesystem::absolute(path, error);
        return (error ? path : absolute).lexically_normal();
    }

    [[nodiscard]] bool is_in_subtree(
        const std::filesystem::path& path, const std::filesystem::path& subtree)
    {
        if (path == subtree)
            return true;
        const auto relative = path.lexically_relative(subtree);
        return !relative.empty() && relative != "." &&
               relative.begin() != relative.end() && *relative.begin() != "..";
    }

#if defined(__linux__)
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

    class OwnedFileDescriptor {
    public:
        explicit OwnedFileDescriptor(int descriptor)
            : descriptor_ { descriptor }
        {
        }
        ~OwnedFileDescriptor()
        {
            if (descriptor_ >= 0)
                static_cast<void>(::close(descriptor_));
        }

        OwnedFileDescriptor(const OwnedFileDescriptor&) = delete;
        OwnedFileDescriptor& operator=(const OwnedFileDescriptor&) = delete;

        [[nodiscard]] int get() const noexcept { return descriptor_; }

    private:
        int descriptor_ { };
    };
#endif

} // namespace

HostFileWatcher::HostFileWatcher(
    std::filesystem::path root, std::size_t maximum_pending)
    : root_ { normalize_path(root) }
    , maximum_pending_ { std::max<std::size_t>(maximum_pending, 1U) }
{
#if defined(__linux__)
    std::error_code error;
    if (!std::filesystem::is_directory(root_, error) || error)
        return;
    notification_descriptor_ = ::inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
    if (notification_descriptor_ < 0)
        return;
    add_watch(root_);
    // Cover the high-value mutable roots immediately without walking them.
    // Descriptor-generation validation remains the correctness fallback until
    // idle registration reaches their descendants.
    constexpr std::array<std::string_view, 4> mutable_roots { "Applications",
        "private/var", "private/var/mobile/Applications",
        "private/var/staging" };
    for (const auto relative : mutable_roots) {
        const auto directory = root_ / relative;
        std::error_code directory_error;
        if (std::filesystem::is_directory(directory, directory_error) &&
            !directory_error) {
            add_watch(directory);
            queue_watch_tree(directory);
        }
    }
    queue_watch_tree(root_);
#else
    static_cast<void>(root);
#endif
}

HostFileWatcher::~HostFileWatcher()
{
#if defined(__linux__)
    if (notification_descriptor_ >= 0) {
        static_cast<void>(::close(notification_descriptor_));
        notification_descriptor_ = -1;
    }
#endif
}

bool HostFileWatcher::enabled() const noexcept
{
    return notification_descriptor_ >= 0;
}

std::size_t HostFileWatcher::pending_count() const noexcept
{
    return pending_.size() + structural_events_.size();
}

std::size_t HostFileWatcher::watch_count() const noexcept
{
    return watches_.size();
}

bool HostFileWatcher::registration_pending() const noexcept
{
    return active_registration_.has_value() || !registration_queue_.empty();
}

HostFileWatchStats HostFileWatcher::stats() const noexcept { return stats_; }

void HostFileWatcher::queue_watch_tree(const std::filesystem::path& directory)
{
#if defined(__linux__)
    if (notification_descriptor_ < 0)
        return;
    const auto normalized = directory.lexically_normal();
    if (active_registration_ && active_registration_->directory == normalized) {
        return;
    }
    if (completed_registrations_.contains(normalized) ||
        !queued_registrations_.insert(normalized).second) {
        return;
    }
    registration_queue_.push_back(normalized);
#else
    static_cast<void>(directory);
#endif
}

void HostFileWatcher::advance_registration(
    std::size_t maximum_entries, std::chrono::steady_clock::duration budget)
{
#if defined(__linux__)
    if (notification_descriptor_ < 0 || maximum_entries == 0U ||
        budget <= std::chrono::steady_clock::duration::zero()) {
        return;
    }
    const auto deadline = std::chrono::steady_clock::now() + budget;
    std::size_t inspected { };
    while (inspected < maximum_entries &&
           std::chrono::steady_clock::now() < deadline) {
        if (!active_registration_) {
            while (!registration_queue_.empty() && !active_registration_) {
                auto directory = std::move(registration_queue_.front());
                registration_queue_.pop_front();
                queued_registrations_.erase(directory);
                if (completed_registrations_.contains(directory))
                    continue;
                if (watches_.size() >= maximum_watches) {
                    queue_dirty_subtree(directory);
                    return;
                }
                add_watch(directory);
                ++inspected;
                std::error_code iterator_error;
                std::filesystem::directory_iterator iterator { directory,
                    std::filesystem::directory_options::skip_permission_denied,
                    iterator_error };
                if (iterator_error) {
                    queue_dirty_subtree(directory);
                    completed_registrations_.insert(std::move(directory));
                    continue;
                }
                active_registration_.emplace(ActiveRegistration {
                    std::move(directory), std::move(iterator), { } });
                if (inspected >= maximum_entries)
                    return;
            }
            if (!active_registration_)
                return;
        }

        auto& registration = *active_registration_;
        if (registration.iterator == registration.end) {
            completed_registrations_.insert(registration.directory);
            active_registration_.reset();
            continue;
        }
        const auto entry = *registration.iterator;
        std::error_code status_error;
        const auto status = entry.symlink_status(status_error);
        if (!status_error && std::filesystem::is_directory(status)) {
            queue_watch_tree(entry.path());
        } else if (status_error) {
            queue_dirty_subtree(registration.directory);
        }
        std::error_code increment_error;
        registration.iterator.increment(increment_error);
        if (increment_error) {
            queue_dirty_subtree(registration.directory);
            completed_registrations_.insert(registration.directory);
            active_registration_.reset();
        }
        ++inspected;
        if ((inspected & 0x1FU) == 0U &&
            std::chrono::steady_clock::now() >= deadline) {
            return;
        }
    }
#else
    static_cast<void>(maximum_entries);
    static_cast<void>(budget);
#endif
}

void HostFileWatcher::add_watch(const std::filesystem::path& directory)
{
#if defined(__linux__)
    const auto normalized = directory.lexically_normal();
    if (watched_directories_.contains(normalized))
        return;
    if (notification_descriptor_ < 0 || watches_.size() >= maximum_watches) {
        queue_dirty_subtree(directory);
        return;
    }
    constexpr auto mask = IN_MODIFY | IN_CLOSE_WRITE | IN_ATTRIB | IN_CREATE |
                          IN_DELETE | IN_MOVED_FROM | IN_MOVED_TO |
                          IN_DELETE_SELF | IN_MOVE_SELF;
    const auto watch_descriptor =
        ::inotify_add_watch(notification_descriptor_, normalized.c_str(), mask);
    if (watch_descriptor < 0) {
        queue_dirty_subtree(directory);
        return;
    }
    // Keep the watched directory as a namespace path. Resolving a symlink here
    // would make an inotify event for the alias indistinguishable from an event
    // for its target before the catalog can update both records.
    watches_[watch_descriptor] = normalized;
    watched_directories_.insert(normalized);
#else
    static_cast<void>(directory);
#endif
}

void HostFileWatcher::remove_watch(int watch_descriptor)
{
#if defined(__linux__)
    if (notification_descriptor_ >= 0) {
        static_cast<void>(
            ::inotify_rm_watch(notification_descriptor_, watch_descriptor));
    }
#else
    static_cast<void>(watch_descriptor);
#endif
    if (const auto watch = watches_.find(watch_descriptor);
        watch != watches_.end()) {
        watched_directories_.erase(watch->second);
        watches_.erase(watch);
    }
}

void HostFileWatcher::queue_dirty_subtree(const std::filesystem::path& path)
{
    if (root_.empty())
        return;
    auto normalized = normalize_path(path.empty() ? root_ : path);
    if (!is_in_subtree(normalized, root_))
        normalized = root_;
    if (std::find(dirty_subtrees_.begin(), dirty_subtrees_.end(), normalized) !=
        dirty_subtrees_.end()) {
        overflow_ = true;
        return;
    }
    if (dirty_subtrees_.size() >= maximum_dirty_subtrees) {
        dirty_subtrees_.clear();
        dirty_subtrees_.push_back(root_);
    } else {
        dirty_subtrees_.push_back(std::move(normalized));
    }
    overflow_ = true;
}

void HostFileWatcher::queue_path(
    const std::filesystem::path& path, GuestFileMutationKind mutation)
{
    if (root_.empty())
        return;
    const auto normalized = normalize_path(path);
    if (!is_in_subtree(normalized, root_))
        return;
    const auto now = std::chrono::steady_clock::now();
    if (const auto existing = pending_.find(normalized);
        existing != pending_.end()) {
        if (mutation_priority(mutation) >
            mutation_priority(existing->second.mutation)) {
            existing->second.mutation = mutation;
        }
        existing->second.last_event = now;
        existing->second.sample.reset();
        existing->second.event_sequence = next_event_sequence_++;
        return;
    }
    if (pending_.size() >= maximum_pending_) {
        queue_dirty_subtree(normalized.parent_path());
        return;
    }
    pending_.emplace(normalized, PendingPath { mutation, now, std::nullopt,
                                     next_event_sequence_++, false });
}

void HostFileWatcher::queue_structural_event(
    const std::filesystem::path& path, GuestFileMutationKind mutation)
{
    if (root_.empty())
        return;
    const auto normalized = normalize_path(path);
    if (!is_in_subtree(normalized, root_))
        return;
    for (const auto& event : structural_events_) {
        if (event.path == normalized && event.mutation == mutation)
            return;
    }
    if (structural_events_.size() >= maximum_pending_) {
        structural_events_.clear();
        queue_dirty_subtree(root_);
        return;
    }
    structural_events_.push_back(
        HostFileWatchDrain::StructuralEvent { normalized, mutation });
}

void HostFileWatcher::poll()
{
#if defined(__linux__)
    if (notification_descriptor_ < 0)
        return;
    std::array<std::byte, 64U * 1024U> buffer { };
    for (;;) {
        const auto received =
            ::read(notification_descriptor_, buffer.data(), buffer.size());
        if (received < 0) {
            if (errno == EINTR)
                continue;
            if (errno == EAGAIN || errno == EWOULDBLOCK)
                break;
            queue_dirty_subtree(root_);
            break;
        }
        if (received == 0)
            break;
        std::size_t offset = 0;
        const auto available = static_cast<std::size_t>(received);
        while (offset + sizeof(inotify_event) <= available) {
            const auto* event = reinterpret_cast<const inotify_event*>(
                buffer.data() + static_cast<std::ptrdiff_t>(offset));
            const auto event_size = sizeof(inotify_event) + event->len;
            if (event_size > available - offset) {
                queue_dirty_subtree(root_);
                break;
            }
            handle_event(event, available - offset);
            offset += event_size;
        }
    }
#endif
}

void HostFileWatcher::handle_event(
    const void* event_data, std::size_t available_bytes)
{
#if defined(__linux__)
    if (event_data == nullptr || available_bytes < sizeof(inotify_event))
        return;
    const auto& event = *static_cast<const inotify_event*>(event_data);
    if (event.mask & IN_Q_OVERFLOW) {
        pending_.clear();
        queue_dirty_subtree(root_);
        return;
    }
    const auto watch = watches_.find(event.wd);
    if (watch == watches_.end())
        return;
    const auto watched_directory = watch->second;
    if (event.mask & IN_IGNORED) {
        watched_directories_.erase(watch->second);
        watches_.erase(watch);
        return;
    }

    std::filesystem::path path = watched_directory;
    if (event.len != 0U) {
        const auto length = std::min<std::size_t>(
            event.len, available_bytes - sizeof(inotify_event));
        const auto name_length = ::strnlen(event.name, length);
        if (name_length != 0U)
            path /= std::string { event.name, name_length };
    }
    path = normalize_path(path);

    const auto is_directory = (event.mask & IN_ISDIR) != 0U;
    if (event.mask & (IN_DELETE_SELF | IN_MOVE_SELF)) {
        // The watch itself was a directory.  IN_DELETE_SELF/IN_MOVE_SELF has no
        // name payload, so retain the watched directory as an explicit subtree
        // removal instead of manufacturing a file mutation for its parent.
        queue_structural_event(
            watched_directory, GuestFileMutationKind::SubtreeRemove);
        remove_watch(event.wd);
        return;
    }

    GuestFileMutationKind mutation = GuestFileMutationKind::Write;
    if (event.mask & (IN_DELETE | IN_MOVED_FROM)) {
        mutation = GuestFileMutationKind::Unlink;
    } else if (event.mask & (IN_CREATE | IN_MOVED_TO)) {
        mutation = GuestFileMutationKind::InstallReplace;
    }
    if (is_directory && (event.mask & (IN_CREATE | IN_MOVED_TO))) {
        add_watch(path);
        queue_watch_tree(path);
        queue_structural_event(path, GuestFileMutationKind::SubtreeCreate);
        return;
    }
    if (is_directory && (event.mask & (IN_DELETE | IN_MOVED_FROM))) {
        queue_structural_event(path, GuestFileMutationKind::SubtreeRemove);
        return;
    }
    queue_path(path, mutation);
#else
    static_cast<void>(event_data);
    static_cast<void>(available_bytes);
#endif
}

HostFileWatcher::AsyncCompletion HostFileWatcher::inspect_path(
    const std::filesystem::path& path, GuestFileMutationKind mutation,
    std::uint64_t event_sequence,
    const std::optional<StableSample>& expected_sample,
    GuestFileGenerationRegistry& registry)
{
    AsyncCompletion completion { path, event_sequence,
        AsyncCompletionKind::Retry, std::nullopt, false, 0 };
#if defined(__linux__)
    int descriptor_value = -1;
    do {
        descriptor_value = ::open(path.c_str(), O_RDONLY | O_CLOEXEC);
    } while (descriptor_value < 0 && errno == EINTR);
    const OwnedFileDescriptor descriptor { descriptor_value };
    if (descriptor.get() < 0) {
        if (errno == ENOENT || errno == ENOTDIR) {
            static_cast<void>(
                registry.publish(path, GuestFileMutationKind::Unlink));
            completion.kind = AsyncCompletionKind::Changed;
        }
        return completion;
    }

    struct stat before { };
    if (::fstat(descriptor.get(), &before) != 0)
        return completion;
    const auto observed_generation = generation_from_stat(before);
    const auto current_generation = registry.current(path);
    if (!S_ISREG(before.st_mode)) {
        static_cast<void>(registry.publish(path, mutation));
        completion.kind = AsyncCompletionKind::Changed;
        return completion;
    }

    struct stat after { };
    std::optional<std::uint64_t> generation_revision;
    if (current_generation && current_generation->generation &&
        *current_generation->generation == observed_generation) {
        generation_revision = current_generation->revision;
    }
    const auto identity_result = shared_file_identity(
        path, descriptor.get(), observed_generation, generation_revision, true);
    const auto& identity = identity_result.content_identity;
    if (identity && identity_result.computed) {
        completion.sha_computed = true;
        if (before.st_size > 0) {
            completion.sha_bytes = static_cast<std::uint64_t>(before.st_size);
        }
    }
    const auto stable =
        identity && ::fstat(descriptor.get(), &after) == 0 &&
        generation_from_stat(before) == generation_from_stat(after);
    if (!stable)
        return completion;
    const StableSample sample { generation_from_stat(after), *identity };
    completion.sample = sample;
    if (!expected_sample || *expected_sample != sample) {
        completion.kind = AsyncCompletionKind::Sample;
        return completion;
    }
    const auto current = registry.current(path);
    const auto already_published =
        current && current->generation &&
        *current->generation == sample.generation &&
        current->content_identity &&
        *current->content_identity == sample.content_identity &&
        current->last_mutation != GuestFileMutationKind::Observation;
    if (already_published) {
        completion.kind = AsyncCompletionKind::Discarded;
    } else {
        static_cast<void>(registry.publish_descriptor(
            path, descriptor.get(), mutation, sample.content_identity));
        completion.kind = AsyncCompletionKind::Changed;
    }
#else
    static_cast<void>(expected_sample);
    static_cast<void>(registry.publish(path, mutation));
    completion.kind = AsyncCompletionKind::Changed;
#endif
    return completion;
}

HostFileWatchDrain HostFileWatcher::publish_stable(
    HostResourceController& host_resources,
    GuestFileGenerationRegistry& registry, std::size_t maximum_events,
    bool include_dirty_subtrees)
{
    HostFileWatchDrain drain;
    drain.overflow = overflow_;

    std::deque<AsyncCompletion> completions;
    {
        const std::lock_guard lock { async_state_->mutex };
        completions.swap(async_state_->completions);
    }
    const auto now = std::chrono::steady_clock::now();
    for (auto& completion : completions) {
        ++stats_.completed;
        if (completion.sha_computed) {
            ++stats_.sha_computations;
            stats_.sha_bytes += completion.sha_bytes;
        }
        const auto pending = pending_.find(completion.path);
        if (pending == pending_.end())
            continue;
        pending->second.in_flight = false;
        if (pending->second.event_sequence != completion.event_sequence)
            continue;
        switch (completion.kind) {
        case AsyncCompletionKind::Sample:
            pending->second.sample = std::move(completion.sample);
            pending->second.last_event = now;
            break;
        case AsyncCompletionKind::Retry:
            pending->second.sample.reset();
            pending->second.last_event = now;
            break;
        case AsyncCompletionKind::Changed:
            confirmed_paths_.push_back(completion.path);
            if (completion.sample) {
                confirmed_identities_[completion.path] =
                    HostFileWatchDrain::StableIdentity {
                        completion.sample->generation,
                        completion.sample->content_identity
                    };
            }
            ++stats_.confirmed_changes;
            pending_.erase(pending);
            break;
        case AsyncCompletionKind::Discarded:
            pending_.erase(pending);
            break;
        }
    }

    while (drain.changed_paths.size() < maximum_events &&
           !confirmed_paths_.empty()) {
        auto path = std::move(confirmed_paths_.front());
        confirmed_paths_.pop_front();
        if (const auto identity = confirmed_identities_.find(path);
            identity != confirmed_identities_.end()) {
            drain.stable_identities.emplace(path, std::move(identity->second));
            confirmed_identities_.erase(identity);
        }
        drain.changed_paths.push_back(std::move(path));
    }

    while (drain.structural_events.size() < maximum_events &&
           !structural_events_.empty()) {
        drain.structural_events.push_back(
            std::move(structural_events_.front()));
        structural_events_.pop_front();
    }

    constexpr std::size_t maximum_concurrent_hashes = 2;
    const auto in_flight =
        static_cast<std::size_t>(std::count_if(pending_.begin(), pending_.end(),
            [](const auto& entry) { return entry.second.in_flight; }));
    const auto available_hash_slots =
        now >= next_hash_submission_ && in_flight < maximum_concurrent_hashes
            ? maximum_concurrent_hashes - in_flight
            : 0U;
    std::size_t scheduled { };
    std::size_t attempted { };
    for (auto& [path, pending] : pending_) {
        if (scheduled >= maximum_events || attempted >= available_hash_slots)
            break;
        if (pending.in_flight || now - pending.last_event < stable_delay)
            continue;
        const auto event_sequence = pending.event_sequence;
        const auto mutation = pending.mutation;
        const auto expected_sample = pending.sample;
        const auto state = async_state_;
        auto* registry_pointer = &registry;
        ++attempted;
        const auto token = host_resources.submit(
            HostWorkKind::Maintenance, std::nullopt,
            [state, path, mutation, event_sequence, expected_sample,
                registry_pointer] {
                AsyncCompletion completion { path, event_sequence,
                    AsyncCompletionKind::Retry, std::nullopt, false, 0 };
                try {
                    completion = inspect_path(path, mutation, event_sequence,
                        expected_sample, *registry_pointer);
                } catch (...) {
                    // A failed maintenance observation remains pending for a
                    // later bounded retry; it must never strand the path as
                    // in-flight.
                }
                const std::lock_guard lock { state->mutex };
                state->completions.push_back(std::move(completion));
            },
            std::chrono::milliseconds { 5 });
        if (token) {
            pending.in_flight = true;
            ++stats_.scheduled;
            ++scheduled;
        } else {
            ++stats_.rejected;
            pending.last_event = now;
            next_hash_submission_ = now + stable_delay;
            break;
        }
    }

    if (include_dirty_subtrees) {
        constexpr std::size_t maximum_returned_dirty_subtrees = 16;
        const auto count =
            std::min(maximum_returned_dirty_subtrees, dirty_subtrees_.size());
        drain.dirty_subtrees.insert(drain.dirty_subtrees.end(),
            dirty_subtrees_.begin(),
            dirty_subtrees_.begin() + static_cast<std::ptrdiff_t>(count));
        dirty_subtrees_.erase(dirty_subtrees_.begin(),
            dirty_subtrees_.begin() + static_cast<std::ptrdiff_t>(count));
        if (dirty_subtrees_.empty())
            overflow_ = false;
    }
    drain.overflow = drain.overflow || overflow_;
    return drain;
}

} // namespace shade
