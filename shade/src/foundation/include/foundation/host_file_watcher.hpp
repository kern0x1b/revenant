// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Monitor filesystem structure changes and report bounded executable-
// catalog invalidations.

#pragma once

#include <chrono>
#include <cstddef>
#include <cstdint>
#include <deque>
#include <filesystem>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <set>
#include <vector>

#include "foundation/content_identity.hpp"
#include "foundation/file_page_cache.hpp"

namespace shade {

class HostResourceController;

struct HostFileWatchDrain {
    std::vector<std::filesystem::path> changed_paths;
    struct StructuralEvent {
        std::filesystem::path path;
        GuestFileMutationKind mutation { GuestFileMutationKind::SubtreeCreate };
    };
    std::vector<StructuralEvent> structural_events;
    struct StableIdentity {
        GuestFileGeneration generation;
        ContentIdentity content_identity;
    };
    std::map<std::filesystem::path, StableIdentity> stable_identities;
    std::vector<std::filesystem::path> dirty_subtrees;
    bool overflow { };
};

struct HostFileWatchStats {
    std::uint64_t scheduled { };
    std::uint64_t rejected { };
    std::uint64_t completed { };
    std::uint64_t sha_computations { };
    std::uint64_t sha_bytes { };
    std::uint64_t confirmed_changes { };
};

// A bounded, serialized host filesystem watcher. Notifications are only dirty
// hints: a file is published after two matching descriptor observations with
// a stable generation and content identity. All confirmed changes enter the
// same GuestFileGenerationRegistry used by guest VFS operations.
class HostFileWatcher {
public:
    explicit HostFileWatcher(
        std::filesystem::path root, std::size_t maximum_pending = 512);
    ~HostFileWatcher();

    HostFileWatcher(const HostFileWatcher&) = delete;
    HostFileWatcher& operator=(const HostFileWatcher&) = delete;

    // Polls the non-blocking notification queue and returns immediately.
    void poll();

    // Installs recursive watches incrementally. The caller supplies an entry
    // budget and a strict wall-clock budget. The caller should run this only
    // after the first frame in idle/background maintenance windows.
    void advance_registration(std::size_t maximum_entries = 256,
        std::chrono::steady_clock::duration budget = std::chrono::milliseconds {
            1 });

    // Publishes only stable paths. Dirty subtrees from an overflow are drained
    // only when requested by an idle/background caller.
    [[nodiscard]] HostFileWatchDrain publish_stable(
        HostResourceController& host_resources,
        GuestFileGenerationRegistry& registry, std::size_t maximum_events = 64,
        bool include_dirty_subtrees = true);

    [[nodiscard]] bool enabled() const noexcept;
    [[nodiscard]] std::size_t pending_count() const noexcept;
    [[nodiscard]] std::size_t watch_count() const noexcept;
    [[nodiscard]] bool registration_pending() const noexcept;
    [[nodiscard]] HostFileWatchStats stats() const noexcept;

private:
    struct StableSample {
        GuestFileGeneration generation;
        ContentIdentity content_identity;

        friend constexpr bool operator==(
            const StableSample&, const StableSample&) = default;
    };

    struct PendingPath {
        GuestFileMutationKind mutation { GuestFileMutationKind::Write };
        std::chrono::steady_clock::time_point last_event { };
        std::optional<StableSample> sample;
        std::uint64_t event_sequence { };
        bool in_flight { };
    };

    enum class AsyncCompletionKind : std::uint8_t {
        Sample,
        Changed,
        Discarded,
        Retry,
    };

    struct AsyncCompletion {
        std::filesystem::path path;
        std::uint64_t event_sequence { };
        AsyncCompletionKind kind { AsyncCompletionKind::Retry };
        std::optional<StableSample> sample;
        bool sha_computed { };
        std::uint64_t sha_bytes { };
    };

    struct AsyncState {
        std::mutex mutex;
        std::deque<AsyncCompletion> completions;
    };

    struct ActiveRegistration {
        std::filesystem::path directory;
        std::filesystem::directory_iterator iterator;
        std::filesystem::directory_iterator end;
    };

    void queue_watch_tree(const std::filesystem::path& directory);
    void add_watch(const std::filesystem::path& directory);
    void remove_watch(int watch_descriptor);
    void queue_path(
        const std::filesystem::path& path, GuestFileMutationKind mutation);
    void queue_structural_event(
        const std::filesystem::path& path, GuestFileMutationKind mutation);
    void queue_dirty_subtree(const std::filesystem::path& path);
    void handle_event(const void* event, std::size_t available_bytes);
    [[nodiscard]] static AsyncCompletion inspect_path(
        const std::filesystem::path& path, GuestFileMutationKind mutation,
        std::uint64_t event_sequence,
        const std::optional<StableSample>& expected_sample,
        GuestFileGenerationRegistry& registry);

    std::filesystem::path root_;
    std::size_t maximum_pending_ { };
    int notification_descriptor_ { -1 };
    std::map<int, std::filesystem::path> watches_;
    std::set<std::filesystem::path> watched_directories_;
    std::deque<std::filesystem::path> registration_queue_;
    std::set<std::filesystem::path> queued_registrations_;
    std::set<std::filesystem::path> completed_registrations_;
    std::optional<ActiveRegistration> active_registration_;
    std::map<std::filesystem::path, PendingPath> pending_;
    std::shared_ptr<AsyncState> async_state_ { std::make_shared<AsyncState>() };
    std::deque<std::filesystem::path> confirmed_paths_;
    std::map<std::filesystem::path, HostFileWatchDrain::StableIdentity>
        confirmed_identities_;
    std::deque<HostFileWatchDrain::StructuralEvent> structural_events_;
    std::uint64_t next_event_sequence_ { 1 };
    std::chrono::steady_clock::time_point next_hash_submission_ { };
    HostFileWatchStats stats_;
    std::vector<std::filesystem::path> dirty_subtrees_;
    bool overflow_ { false };
};

} // namespace shade
