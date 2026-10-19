// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Maintain the session executable catalog and background generation
// updates.

#pragma once

#include <filesystem>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <vector>

#include "foundation/executable_catalog.hpp"
#include "foundation/host_file_watcher.hpp"
#include "foundation/host_resource_controller.hpp"

namespace shade {
class CompatibilityKernel;
class Output;
}

namespace shade::runtime_detail {

// Owns the session's stable catalog object. Loaders can register mappings in
// it; a completed refresh replaces its contents only at the runtime poll point.
class SessionCatalog {
public:
    SessionCatalog(std::filesystem::path rootfs,
        ArmArchitectureVersion architecture, std::string manifest,
        Output& output);
    SessionCatalog(const SessionCatalog&) = delete;
    SessionCatalog& operator=(const SessionCatalog&) = delete;
    [[nodiscard]] bool available() const { return loaded_; }
    [[nodiscard]] ExecutableCatalog* index()
    {
        return loaded_ ? &entries_ : nullptr;
    }
    [[nodiscard]] std::size_t resident_bytes_estimate() const
    {
        return entries_.resident_bytes_estimate();
    }
    void save() const;

private:
    friend class CatalogMaintenance;
    std::filesystem::path rootfs_;
    std::string manifest_;
    Output& output_;
    ExecutableCatalog entries_;
    bool loaded_ { };
};

// Bounded file observation and asynchronous catalog refresh. Worker captures
// own their snapshots and completion state, never this object or a kernel.
class CatalogMaintenance {
public:
    CatalogMaintenance(SessionCatalog& catalog,
        ArmArchitectureVersion architecture,
        HostResourceController& host_resources);
    CatalogMaintenance(const CatalogMaintenance&) = delete;
    CatalogMaintenance& operator=(const CatalogMaintenance&) = delete;

    void poll(CompatibilityKernel& kernel, bool refresh_when_idle,
        bool allow_schedule = true);
    void publish_stable(CompatibilityKernel& kernel);
    void report_watch_stats() const;
    void report_refresh_stats() const;

private:
    struct Completion {
        std::uint64_t base_revision { };
        std::vector<std::filesystem::path> paths;
        std::map<std::filesystem::path, ExecutableCatalogKnownIdentity>
            known_identities;
        std::shared_ptr<ExecutableCatalog> catalog;
        ExecutableCatalogScanSummary summary;
        std::filesystem::path staged_manifest;
        bool manifest_staged { };
        std::string error;
    };
    struct SharedState {
        std::mutex mutex;
        std::optional<Completion> completion;
    };

    void queue_path(const std::filesystem::path& path,
        std::optional<ExecutableCatalogKnownIdentity> known_identity =
            std::nullopt);
    void accept_completion();
    [[nodiscard]] bool collect_mutations(
        CompatibilityKernel& kernel, bool refresh_when_idle);
    void schedule();

    SessionCatalog& catalog_;
    ArmArchitectureVersion architecture_;
    HostResourceController& host_resources_;
    Output& output_;
    std::error_code root_error_;
    std::filesystem::path root_;
    HostFileWatcher watcher_;
    bool registration_reported_ { };
    bool refresh_pending_ { };
    std::vector<std::filesystem::path> refresh_paths_;
    std::map<std::filesystem::path, ExecutableCatalogKnownIdentity>
        refresh_identities_;
    std::shared_ptr<SharedState> state_ { std::make_shared<SharedState>() };
    std::shared_ptr<HostWorkToken> task_;
    HostResourceController::Clock::time_point next_submission_ { };
    std::uint64_t refresh_events_ { };
    std::uint64_t refresh_count_ { };
    std::uint64_t sequence_ { };
    std::uint64_t scheduled_ { };
    std::uint64_t rejected_ { };
    std::uint64_t stale_ { };
};

} // namespace shade::runtime_detail
