// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Model open-description flock ownership and process-owned byte-range
// locks.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/kern/kern_descrip.c
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/kern/kern_lockf.c

#pragma once

#include <cstdint>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <set>
#include <vector>

namespace shade::bsd {

enum class AdvisoryLockKind : std::uint8_t {
    Shared,
    Exclusive,
};

struct RecordLockRange {
    AdvisoryLockKind kind { AdvisoryLockKind::Shared };
    std::uint64_t start { };
    // A disengaged end is the POSIX l_len == 0 form extending through EOF.
    std::optional<std::uint64_t> end;
};

struct RecordLockConflict : RecordLockRange {
    std::uint32_t owner_pid { };
};

class AdvisoryFileLockRegistry;

// XNU attaches flock locks to struct fileglob (the open file description),
// rather than to a process or an fd-table slot.  This object is consequently
// shared by dup(2), fork(2), and SCM_RIGHTS transfers.
class RegularFileOpenDescription {
public:
    RegularFileOpenDescription(std::uint64_t identifier,
        std::uint32_t permanent_file_id, int host_descriptor,
        std::weak_ptr<AdvisoryFileLockRegistry> lock_registry);
    RegularFileOpenDescription(const RegularFileOpenDescription&) = delete;
    RegularFileOpenDescription& operator=(
        const RegularFileOpenDescription&) = delete;
    ~RegularFileOpenDescription();

    [[nodiscard]] std::uint64_t identifier() const { return identifier_; }
    [[nodiscard]] std::uint32_t permanent_file_id() const
    {
        return permanent_file_id_;
    }
    [[nodiscard]] int host_descriptor() const { return host_descriptor_; }

private:
    std::uint64_t identifier_ { };
    std::uint32_t permanent_file_id_ { };
    int host_descriptor_ { -1 };
    std::weak_ptr<AdvisoryFileLockRegistry> lock_registry_;
};

class AdvisoryFileLockRegistry
    : public std::enable_shared_from_this<AdvisoryFileLockRegistry> {
public:
    [[nodiscard]] std::shared_ptr<RegularFileOpenDescription> open(
        std::uint32_t permanent_file_id, int host_descriptor);

    // Returns false only when another open description owns an incompatible
    // lock.  Conversion of a description's own lock is atomic.
    [[nodiscard]] bool try_acquire(
        const RegularFileOpenDescription& description, AdvisoryLockKind kind);
    void release(const RegularFileOpenDescription& description);

    [[nodiscard]] std::optional<RecordLockConflict> record_conflict(
        std::uint32_t permanent_file_id, std::uint32_t owner_pid,
        const RecordLockRange& request) const;
    [[nodiscard]] bool try_set_record_lock(std::uint32_t permanent_file_id,
        std::uint32_t owner_pid, const RecordLockRange& request);
    void unlock_record_lock(std::uint32_t permanent_file_id,
        std::uint32_t owner_pid, const RecordLockRange& range);
    void release_process_record_locks(std::uint32_t owner_pid);

private:
    struct FileLock {
        std::optional<std::uint64_t> exclusive_owner;
        std::set<std::uint64_t> shared_owners;
    };

    struct OwnedRecordLock : RecordLockRange {
        std::uint32_t owner_pid { };
    };

    mutable std::mutex mutex_;
    std::uint64_t next_description_identifier_ { 1 };
    std::map<std::uint32_t, FileLock> locks_;
    std::map<std::uint32_t, std::vector<OwnedRecordLock>> record_locks_;
};

} // namespace shade::bsd
