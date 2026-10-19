// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Maintain the session executable catalog and background generation
// updates.

#include "session_catalog.hpp"

#include <algorithm>
#include <chrono>
#include <exception>
#include <utility>

#include "foundation/application_path.hpp"
#include "foundation/output.hpp"
#include "kernel/kernel.hpp"

namespace shade::runtime_detail {

SessionCatalog::SessionCatalog(std::filesystem::path rootfs,
    ArmArchitectureVersion architecture, std::string manifest, Output& output)
    : rootfs_ { std::move(rootfs) }
    , manifest_ { std::move(manifest) }
    , output_ { output }
{
    loaded_ = entries_.load(manifest_);
    std::string catalog_source = loaded_ ? "manifest" : "fallback";
    if (!loaded_) {
        try {
            const auto summary = entries_.register_tree(rootfs_, architecture);
            loaded_ = true;
            catalog_source = "startup-scan";
            const auto manifest_saved = entries_.save(manifest_);
            output_.line(
                "[catalog] startup-scan=complete regular-files=" +
                std::to_string(summary.regular_files) +
                " macho-images=" + std::to_string(summary.mach_o_images) +
                " failed-files=" + std::to_string(summary.failed_files) +
                " entries=" + std::to_string(entries_.size()) +
                " reliable-entry-points=" +
                std::to_string(entries_.reliable_entry_point_count()) +
                " manifest-save=" + (manifest_saved ? "ok" : "failed"));
        } catch (const std::exception& error) {
            output_.line("[catalog] startup-scan=failed error=" +
                         std::string { error.what() });
        }
    }
    output_.line("[catalog] manifest=" + manifest_ +
                 " status=" + (loaded_ ? "loaded" : "fallback") +
                 " source=" + catalog_source +
                 " entries=" + std::to_string(entries_.size()));
}

void SessionCatalog::save() const
{
    if (loaded_ && !entries_.save(manifest_))
        output_.line("[catalog] manifest-save=failed");
}

CatalogMaintenance::CatalogMaintenance(SessionCatalog& catalog,
    ArmArchitectureVersion architecture, HostResourceController& host_resources)
    : catalog_ { catalog }
    , architecture_ { architecture }
    , host_resources_ { host_resources }
    , output_ { catalog.output_ }
    , root_ { std::filesystem::absolute(catalog.rootfs_, root_error_)
            .lexically_normal() }
    , watcher_ { root_error_ ? catalog.rootfs_ : root_ }
    , registration_reported_ { !watcher_.registration_pending() }
{
    output_.line(std::string { "[host-watch] enabled=" } +
                 (watcher_.enabled() ? "true" : "false") +
                 " startup-watches=" + std::to_string(watcher_.watch_count()));
}

void CatalogMaintenance::queue_path(const std::filesystem::path& path,
    std::optional<ExecutableCatalogKnownIdentity> known_identity)
{
    if (std::find(refresh_paths_.begin(), refresh_paths_.end(), path) ==
        refresh_paths_.end()) {
        refresh_paths_.push_back(path);
    }
    if (known_identity) {
        refresh_identities_[path] = std::move(*known_identity);
    }
}

void CatalogMaintenance::accept_completion()
{
    std::optional<Completion> catalog_completion;
    {
        const std::lock_guard lock { state_->mutex };
        if (state_->completion) {
            catalog_completion = std::move(state_->completion);
            state_->completion.reset();
        }
    }
    if (catalog_completion) {
        task_.reset();
        const auto requeue_completion_paths = [&] {
            for (const auto& path : catalog_completion->paths) {
                if (const auto known =
                        catalog_completion->known_identities.find(path);
                    known != catalog_completion->known_identities.end()) {
                    queue_path(path, known->second);
                } else {
                    queue_path(path);
                }
            }
            refresh_pending_ = !refresh_paths_.empty();
        };
        if (!catalog_completion->error.empty()) {
            requeue_completion_paths();
            output_.line("[catalog] mutation-refresh failed error=" +
                         catalog_completion->error);
        } else if (catalog_.entries_.revision() !=
                   catalog_completion->base_revision) {
            ++stale_;
            requeue_completion_paths();
            std::error_code remove_error;
            std::filesystem::remove(
                catalog_completion->staged_manifest, remove_error);
        } else {
            catalog_.entries_ = std::move(*catalog_completion->catalog);
            catalog_.loaded_ = true;
            bool manifest_published = false;
            if (catalog_completion->manifest_staged) {
                std::error_code rename_error;
                std::filesystem::rename(catalog_completion->staged_manifest,
                    catalog_.manifest_, rename_error);
                manifest_published = !rename_error;
                if (rename_error) {
                    std::error_code remove_error;
                    std::filesystem::remove(
                        catalog_completion->staged_manifest, remove_error);
                }
            }
            if (!manifest_published) {
                output_.line("[catalog] mutation-refresh manifest-save=failed");
            }
            output_.line(
                "[catalog] mutation-refresh regular-files=" +
                std::to_string(catalog_completion->summary.regular_files) +
                " macho-images=" +
                std::to_string(catalog_completion->summary.mach_o_images) +
                " failed-files=" +
                std::to_string(catalog_completion->summary.failed_files) +
                " paths=" + std::to_string(catalog_completion->paths.size()) +
                " warming=no-enqueue async=true");
            ++refresh_count_;
        }
    }
}

bool CatalogMaintenance::collect_mutations(
    CompatibilityKernel& kernel, bool refresh_when_idle)
{
    constexpr std::size_t maximum_mutations_per_poll = 128;
    watcher_.poll();
    const auto host_changes = watcher_.publish_stable(host_resources_,
        *kernel.guest_file_generation_registry(), 64, refresh_when_idle);
    for (const auto& path : host_changes.changed_paths) {
        if (const auto known = host_changes.stable_identities.find(path);
            known != host_changes.stable_identities.end()) {
            const auto& generation = known->second.generation;
            queue_path(
                path, ExecutableCatalogKnownIdentity {
                          ExecutableCatalogFileGeneration { generation.device,
                              generation.inode, generation.file_size,
                              generation.modified_seconds,
                              generation.modified_nanoseconds,
                              generation.changed_seconds,
                              generation.changed_nanoseconds },
                          known->second.content_identity });
        } else {
            queue_path(path);
        }
        refresh_pending_ = true;
    }
    bool structural_boundary = !host_changes.changed_paths.empty() ||
                               !host_changes.structural_events.empty() ||
                               !host_changes.dirty_subtrees.empty();
    for (const auto& event : host_changes.structural_events) {
        // Directory structure events are authoritative subtree boundaries.
        // They must reach the catalog even when the directory did not
        // previously contain a known executable.
        queue_path(event.path);
        refresh_pending_ = true;
    }
    for (const auto& subtree : host_changes.dirty_subtrees) {
        queue_path(subtree);
        refresh_pending_ = true;
    }
    const auto mutations =
        kernel.take_guest_file_mutations(maximum_mutations_per_poll);
    for (const auto& mutation : mutations) {
        ++refresh_events_;
        if (mutation.dirty_subtree) {
            // The registry deliberately coalesces an overflow into a
            // structural marker.  Individual paths before this marker were
            // evicted, so refresh the catalog root instead of pretending
            // the remaining event list is complete.
            if (!root_error_) {
                queue_path(root_);
                refresh_pending_ = true;
                structural_boundary = true;
            }
            continue;
        }
        const auto relative = mutation.path.lexically_relative(root_);
        if (root_error_ || relative.empty() || relative == "." ||
            relative.begin() == relative.end() || *relative.begin() == "..") {
            continue;
        }
        const auto guest_path = "/" + relative.generic_string();
        const auto application_path =
            is_application_executable_path(guest_path);
        const auto known_executable =
            catalog_.index() != nullptr &&
            catalog_.index()->find_path(mutation.path) != nullptr;
        switch (mutation.mutation) {
        case GuestFileMutationKind::SubtreeCreate:
        case GuestFileMutationKind::SubtreeRemove:
            // Namespace changes are already subtree-scoped.  Do not consult
            // the old catalog index: this is how a newly installed bundle
            // becomes visible to the next exec/mmap refresh.
            queue_path(mutation.path);
            refresh_pending_ = true;
            structural_boundary = true;
            break;
        case GuestFileMutationKind::InstallReplace:
        case GuestFileMutationKind::Rename:
        case GuestFileMutationKind::Unlink:
            if (known_executable || application_path ||
                catalog_.index() == nullptr) {
                queue_path(mutation.path);
                refresh_pending_ = true;
                structural_boundary = true;
            }
            break;
        case GuestFileMutationKind::Truncate:
        case GuestFileMutationKind::Write:
        case GuestFileMutationKind::SharedWriteback:
            if (known_executable || application_path) {
                queue_path(mutation.path);
                refresh_pending_ = true;
            }
            break;
        case GuestFileMutationKind::Observation:
            break;
        }
    }
    return structural_boundary;
}

void CatalogMaintenance::schedule()
{
    if (task_ || HostResourceController::Clock::now() < next_submission_) {
        return;
    }
    auto refresh_paths = std::make_shared<std::vector<std::filesystem::path>>(
        std::move(refresh_paths_));
    refresh_paths_.clear();
    auto refresh_identities = std::make_shared<
        std::map<std::filesystem::path, ExecutableCatalogKnownIdentity>>(
        std::move(refresh_identities_));
    refresh_identities_.clear();
    refresh_pending_ = false;
    auto catalog_snapshot =
        std::make_shared<ExecutableCatalog>(catalog_.entries_);
    const auto base_revision = catalog_.entries_.revision();
    const auto sequence = ++sequence_;
    const auto staged_manifest = std::filesystem::path {
        catalog_.manifest_ + ".refresh-" + std::to_string(sequence)
    };
    task_ = host_resources_.submit(
        HostWorkKind::Maintenance, std::nullopt,
        [state = state_, catalog = std::move(catalog_snapshot),
            paths = refresh_paths, root = catalog_.rootfs_,
            architecture = architecture_, base_revision, staged_manifest,
            known_identities = refresh_identities]() mutable {
            Completion completion;
            completion.base_revision = base_revision;
            completion.paths = std::move(*paths);
            completion.known_identities = *known_identities;
            completion.catalog = std::move(catalog);
            completion.staged_manifest = staged_manifest;
            try {
                completion.summary = completion.catalog->refresh_paths(
                    root, completion.paths, architecture, *known_identities);
                completion.manifest_staged =
                    completion.catalog->save(staged_manifest);
            } catch (const std::exception& error) {
                completion.error = error.what();
            } catch (...) {
                completion.error = "unknown background refresh failure";
            }
            const std::lock_guard lock { state->mutex };
            state->completion = std::move(completion);
        },
        std::chrono::milliseconds { 50 });
    if (task_) {
        ++scheduled_;
    } else {
        ++rejected_;
        next_submission_ = HostResourceController::Clock::now() +
                           std::chrono::milliseconds { 50 };
        for (const auto& path : *refresh_paths) {
            if (const auto known = refresh_identities->find(path);
                known != refresh_identities->end()) {
                queue_path(path, known->second);
            } else {
                queue_path(path);
            }
        }
        refresh_pending_ = !refresh_paths_.empty();
    }
}

void CatalogMaintenance::poll(
    CompatibilityKernel& kernel, bool refresh_when_idle, bool allow_schedule)
{
    if (refresh_when_idle && kernel.display_submitted_frames() != 0U) {
        watcher_.advance_registration(256);
        if (!registration_reported_ && !watcher_.registration_pending()) {
            output_.line("[host-watch] registration=complete watches=" +
                         std::to_string(watcher_.watch_count()));
            registration_reported_ = true;
        }
    }
    accept_completion();
    if (!allow_schedule)
        return;
    const auto structural_boundary =
        collect_mutations(kernel, refresh_when_idle);
    if (!refresh_pending_ || refresh_paths_.empty() ||
        (!refresh_when_idle && !structural_boundary))
        return;
    schedule();
}

void CatalogMaintenance::publish_stable(CompatibilityKernel& kernel)
{
    static_cast<void>(watcher_.publish_stable(
        host_resources_, *kernel.guest_file_generation_registry(), 0, false));
}

void CatalogMaintenance::report_watch_stats() const
{
    const auto host_watch_stats = watcher_.stats();
    output_.line("[host-watch] async-scheduled=" +
                 std::to_string(host_watch_stats.scheduled) +
                 " rejected=" + std::to_string(host_watch_stats.rejected) +
                 " completed=" + std::to_string(host_watch_stats.completed) +
                 " sha-computations=" +
                 std::to_string(host_watch_stats.sha_computations) +
                 " sha-bytes=" + std::to_string(host_watch_stats.sha_bytes) +
                 " confirmed-changes=" +
                 std::to_string(host_watch_stats.confirmed_changes));
}

void CatalogMaintenance::report_refresh_stats() const
{
    if (refresh_events_ != 0 || refresh_count_ != 0 || scheduled_ != 0 ||
        rejected_ != 0) {
        output_.line(
            "[catalog] mutation-events=" + std::to_string(refresh_events_) +
            " refreshes=" + std::to_string(refresh_count_) +
            " warming=no-enqueue"
            " async-scheduled=" +
            std::to_string(scheduled_) +
            " async-rejected=" + std::to_string(rejected_) +
            " async-stale=" + std::to_string(stale_));
    }
}

} // namespace shade::runtime_detail
