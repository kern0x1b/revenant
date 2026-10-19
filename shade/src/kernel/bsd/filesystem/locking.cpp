// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Implement guest flock and process-owned byte-range locking.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/kern/kern_descrip.c
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/kern/kern_lockf.c

#include "filesystem/bsd_file_lock.hpp"

#include "kernel/darwin_abi.hpp"
#include "kernel/kernel.hpp"

#include <limits>
#include <memory>
#include <string>
#include <vector>

#include <fcntl.h>
#include <unistd.h>

#include <umbra/interface/A32/a32.h>

#include "../support.hpp"

namespace shade::bsd {
namespace {

    bool ranges_overlap(const RecordLockRange& lhs, const RecordLockRange& rhs)
    {
        const auto lhs_before_rhs = lhs.end && *lhs.end <= rhs.start;
        const auto rhs_before_lhs = rhs.end && *rhs.end <= lhs.start;
        return !lhs_before_rhs && !rhs_before_lhs;
    }

    bool locks_conflict(AdvisoryLockKind lhs, AdvisoryLockKind rhs)
    {
        return lhs == AdvisoryLockKind::Exclusive ||
               rhs == AdvisoryLockKind::Exclusive;
    }

} // namespace

RegularFileOpenDescription::RegularFileOpenDescription(std::uint64_t identifier,
    std::uint32_t permanent_file_id, int host_descriptor,
    std::weak_ptr<AdvisoryFileLockRegistry> lock_registry)
    : identifier_ { identifier }
    , permanent_file_id_ { permanent_file_id }
    , host_descriptor_ { host_descriptor }
    , lock_registry_ { std::move(lock_registry) }
{
}

RegularFileOpenDescription::~RegularFileOpenDescription()
{
    if (const auto registry = lock_registry_.lock())
        registry->release(*this);
    if (host_descriptor_ >= 0)
        static_cast<void>(::close(host_descriptor_));
}

std::shared_ptr<RegularFileOpenDescription> AdvisoryFileLockRegistry::open(
    std::uint32_t permanent_file_id, int host_descriptor)
{
    std::lock_guard lock { mutex_ };
    return std::make_shared<RegularFileOpenDescription>(
        next_description_identifier_++, permanent_file_id, host_descriptor,
        weak_from_this());
}

bool AdvisoryFileLockRegistry::try_acquire(
    const RegularFileOpenDescription& description, AdvisoryLockKind kind)
{
    std::lock_guard lock { mutex_ };
    auto& file_lock = locks_[description.permanent_file_id()];
    const auto owner = description.identifier();

    if (kind == AdvisoryLockKind::Shared) {
        if (file_lock.exclusive_owner && *file_lock.exclusive_owner != owner)
            return false;
        file_lock.exclusive_owner.reset();
        file_lock.shared_owners.insert(owner);
        return true;
    }

    if ((file_lock.exclusive_owner && *file_lock.exclusive_owner != owner) ||
        (!file_lock.shared_owners.empty() &&
            !(file_lock.shared_owners.size() == 1 &&
                file_lock.shared_owners.contains(owner)))) {
        return false;
    }
    file_lock.shared_owners.erase(owner);
    file_lock.exclusive_owner = owner;
    return true;
}

void AdvisoryFileLockRegistry::release(
    const RegularFileOpenDescription& description)
{
    std::lock_guard lock { mutex_ };
    const auto found = locks_.find(description.permanent_file_id());
    if (found == locks_.end())
        return;
    const auto owner = description.identifier();
    if (found->second.exclusive_owner == owner)
        found->second.exclusive_owner.reset();
    found->second.shared_owners.erase(owner);
    if (!found->second.exclusive_owner && found->second.shared_owners.empty())
        locks_.erase(found);
}

std::optional<RecordLockConflict> AdvisoryFileLockRegistry::record_conflict(
    std::uint32_t permanent_file_id, std::uint32_t owner_pid,
    const RecordLockRange& request) const
{
    std::lock_guard lock { mutex_ };
    const auto file = record_locks_.find(permanent_file_id);
    if (file == record_locks_.end())
        return std::nullopt;
    for (const auto& candidate : file->second) {
        if (candidate.owner_pid != owner_pid &&
            ranges_overlap(candidate, request) &&
            locks_conflict(candidate.kind, request.kind)) {
            return RecordLockConflict { candidate.kind, candidate.start,
                candidate.end, candidate.owner_pid };
        }
    }
    return std::nullopt;
}

bool AdvisoryFileLockRegistry::try_set_record_lock(
    std::uint32_t permanent_file_id, std::uint32_t owner_pid,
    const RecordLockRange& request)
{
    std::lock_guard lock { mutex_ };
    auto& file = record_locks_[permanent_file_id];
    for (const auto& candidate : file) {
        if (candidate.owner_pid != owner_pid &&
            ranges_overlap(candidate, request) &&
            locks_conflict(candidate.kind, request.kind)) {
            return false;
        }
    }

    // POSIX replaces the caller's locks only within the requested byte range.
    // Preserve any non-overlapping prefix/suffix when changing lock type.
    std::vector<OwnedRecordLock> replacement;
    replacement.reserve(file.size() + 1U);
    for (const auto& candidate : file) {
        if (candidate.owner_pid != owner_pid ||
            !ranges_overlap(candidate, request)) {
            replacement.push_back(candidate);
            continue;
        }
        if (candidate.start < request.start) {
            replacement.push_back(OwnedRecordLock {
                candidate.kind, candidate.start, request.start, owner_pid });
        }
        if (request.end && (!candidate.end || *request.end < *candidate.end)) {
            replacement.push_back(OwnedRecordLock {
                candidate.kind, *request.end, candidate.end, owner_pid });
        }
    }
    replacement.push_back(OwnedRecordLock {
        request.kind, request.start, request.end, owner_pid });
    file = std::move(replacement);
    return true;
}

void AdvisoryFileLockRegistry::unlock_record_lock(
    std::uint32_t permanent_file_id, std::uint32_t owner_pid,
    const RecordLockRange& range)
{
    std::lock_guard lock { mutex_ };
    const auto found = record_locks_.find(permanent_file_id);
    if (found == record_locks_.end())
        return;
    std::vector<OwnedRecordLock> replacement;
    replacement.reserve(found->second.size() + 1U);
    for (const auto& candidate : found->second) {
        if (candidate.owner_pid != owner_pid ||
            !ranges_overlap(candidate, range)) {
            replacement.push_back(candidate);
            continue;
        }
        if (candidate.start < range.start) {
            replacement.push_back(OwnedRecordLock {
                candidate.kind, candidate.start, range.start, owner_pid });
        }
        if (range.end && (!candidate.end || *range.end < *candidate.end)) {
            replacement.push_back(OwnedRecordLock {
                candidate.kind, *range.end, candidate.end, owner_pid });
        }
    }
    if (replacement.empty()) {
        record_locks_.erase(found);
    } else {
        found->second = std::move(replacement);
    }
}

void AdvisoryFileLockRegistry::release_process_record_locks(
    std::uint32_t owner_pid)
{
    std::lock_guard lock { mutex_ };
    for (auto file = record_locks_.begin(); file != record_locks_.end();) {
        std::erase_if(file->second, [owner_pid](const auto& candidate) {
            return candidate.owner_pid == owner_pid;
        });
        if (file->second.empty()) {
            file = record_locks_.erase(file);
        } else {
            ++file;
        }
    }
}

} // namespace shade::bsd

namespace shade {
namespace {

    struct GuestRecordLock {
        std::int64_t start { };
        std::int64_t length { };
        std::uint32_t pid { };
        std::uint16_t type { };
        std::uint16_t whence { };
    };

    std::optional<GuestRecordLock> read_guest_record_lock(
        AddressSpace& memory, std::uint32_t address)
    {
        const auto start =
            memory.read64(address + darwin::record_lock::start_offset);
        const auto length =
            memory.read64(address + darwin::record_lock::length_offset);
        const auto pid =
            memory.read32(address + darwin::record_lock::pid_offset);
        const auto type =
            memory.read16(address + darwin::record_lock::type_offset);
        const auto whence =
            memory.read16(address + darwin::record_lock::whence_offset);
        if (!start || !length || !pid || !type || !whence)
            return std::nullopt;
        return GuestRecordLock { static_cast<std::int64_t>(*start),
            static_cast<std::int64_t>(*length), *pid, *type, *whence };
    }

} // namespace

std::shared_ptr<bsd::RegularFileOpenDescription>
CompatibilityKernel::ensure_regular_file_open_description(std::uint32_t fd)
{
    if (const auto found = regular_file_open_descriptions_.find(fd);
        found != regular_file_open_descriptions_.end()) {
        return found->second;
    }
    const auto file = file_descriptors_.find(fd);
    if (file == file_descriptors_.end())
        return { };
    const auto metadata = query_hfs_metadata(file->second, true);
    if (!metadata)
        return { };
    const auto guest_flags = file_status_flags_.contains(fd)
                                 ? file_status_flags_.at(fd)
                                 : darwin::open_flag::read_only;
    const auto access = guest_flags & darwin::open_flag::access_mode;
    const auto host_access = access == darwin::open_flag::write_only ? O_WRONLY
                             : access == darwin::open_flag::read_write
                                 ? O_RDWR
                                 : O_RDONLY;
    const auto host_descriptor =
        ::open(file->second.c_str(), host_access | O_CLOEXEC);
    if (host_descriptor < 0)
        return { };
    auto description = shared_state_->advisory_file_locks->open(
        metadata->permanent_id, host_descriptor);
    regular_file_open_descriptions_[fd] = description;
    return description;
}

void CompatibilityKernel::release_record_locks_for_descriptor(std::uint32_t fd)
{
    const auto description = regular_file_open_descriptions_.find(fd);
    if (description != regular_file_open_descriptions_.end()) {
        shared_state_->advisory_file_locks->unlock_record_lock(
            description->second->permanent_file_id(), process_.pid,
            bsd::RecordLockRange {
                bsd::AdvisoryLockKind::Shared, 0, std::nullopt });
        return;
    }
    if (file_descriptors_.contains(fd)) {
        if (const auto created = ensure_regular_file_open_description(fd)) {
            shared_state_->advisory_file_locks->unlock_record_lock(
                created->permanent_file_id(), process_.pid,
                bsd::RecordLockRange {
                    bsd::AdvisoryLockKind::Shared, 0, std::nullopt });
        }
    }
}

bool CompatibilityKernel::dispatch_bsd_record_locking(
    Cpu& cpu, std::uint32_t command)
{
    if (command != darwin::fcntl_command::get_record_lock &&
        command != darwin::fcntl_command::set_record_lock &&
        command != darwin::fcntl_command::set_record_lock_wait) {
        return false;
    }

    auto fd = cpu.registers()[0];
    if (const auto duplicate = duplicated_descriptors_.find(fd);
        duplicate != duplicated_descriptors_.end()) {
        fd = duplicate->second;
    }
    const auto file = file_descriptors_.find(fd);
    const auto description = ensure_regular_file_open_description(fd);
    if (file == file_descriptors_.end() || !description) {
        bsd_error(cpu, bsd_support::bad_file_descriptor);
        return true;
    }

    const auto address = cpu.registers()[2];
    const auto guest = read_guest_record_lock(memory_, address);
    if (!guest) {
        bsd_error(cpu, bsd_support::bad_address);
        return true;
    }
    if (guest->type != darwin::record_lock::read &&
        guest->type != darwin::record_lock::write &&
        guest->type != darwin::record_lock::unlock) {
        bsd_error(cpu, bsd_support::invalid_argument);
        return true;
    }
    if (command == darwin::fcntl_command::get_record_lock &&
        guest->type == darwin::record_lock::unlock) {
        bsd_error(cpu, bsd_support::invalid_argument);
        return true;
    }

    std::int64_t base = 0;
    switch (guest->whence) {
    case 0: // SEEK_SET
        break;
    case 1: { // SEEK_CUR
        const auto current = file_offsets_.find(fd);
        if (current == file_offsets_.end() ||
            current->second > static_cast<std::uint64_t>(
                                  std::numeric_limits<std::int64_t>::max())) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return true;
        }
        base = static_cast<std::int64_t>(current->second);
        break;
    }
    case 2: { // SEEK_END
        std::error_code error;
        const auto size = std::filesystem::file_size(file->second, error);
        if (error || size > static_cast<std::uint64_t>(
                                std::numeric_limits<std::int64_t>::max())) {
            bsd_error(cpu, darwin::error::io);
            return true;
        }
        base = static_cast<std::int64_t>(size);
        break;
    }
    default:
        bsd_error(cpu, bsd_support::invalid_argument);
        return true;
    }
    if (guest->start == std::numeric_limits<std::int64_t>::min() ||
        (guest->start > 0 &&
            base > std::numeric_limits<std::int64_t>::max() - guest->start) ||
        (guest->start < 0 && base < -guest->start)) {
        bsd_error(cpu, bsd_support::invalid_argument);
        return true;
    }
    auto start = base + guest->start;
    auto length = guest->length;
    if (start < 0 || length == std::numeric_limits<std::int64_t>::min()) {
        bsd_error(cpu, bsd_support::invalid_argument);
        return true;
    }
    if (length < 0) {
        if (start < -length) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return true;
        }
        start += length;
        length = -length;
    }
    if (length > 0 &&
        start > std::numeric_limits<std::int64_t>::max() - length) {
        bsd_error(cpu, bsd_support::invalid_argument);
        return true;
    }

    const auto kind = guest->type == darwin::record_lock::write
                          ? bsd::AdvisoryLockKind::Exclusive
                          : bsd::AdvisoryLockKind::Shared;
    const bsd::RecordLockRange range { kind, static_cast<std::uint64_t>(start),
        length == 0
            ? std::nullopt
            : std::optional { static_cast<std::uint64_t>(start + length) } };
    const auto permanent_file_id = description->permanent_file_id();

    if (command == darwin::fcntl_command::get_record_lock) {
        if (!memory_.accessible(
                address, darwin::record_lock::size, MemoryPermission::Write)) {
            bsd_error(cpu, bsd_support::bad_address);
            return true;
        }
        const auto conflict =
            shared_state_->advisory_file_locks->record_conflict(
                permanent_file_id, process_.pid, range);
        if (!conflict) {
            static_cast<void>(
                memory_.write16(address + darwin::record_lock::type_offset,
                    darwin::record_lock::unlock));
        } else {
            const auto conflict_length =
                conflict->end ? *conflict->end - conflict->start : 0;
            static_cast<void>(memory_.write64(
                address + darwin::record_lock::start_offset, conflict->start));
            static_cast<void>(memory_.write64(
                address + darwin::record_lock::length_offset, conflict_length));
            static_cast<void>(
                memory_.write32(address + darwin::record_lock::pid_offset,
                    conflict->owner_pid));
            static_cast<void>(
                memory_.write16(address + darwin::record_lock::type_offset,
                    conflict->kind == bsd::AdvisoryLockKind::Exclusive
                        ? darwin::record_lock::write
                        : darwin::record_lock::read));
            static_cast<void>(memory_.write16(
                address + darwin::record_lock::whence_offset, 0));
        }
        bsd_success(cpu, 0);
        return true;
    }

    if (guest->type == darwin::record_lock::unlock) {
        shared_state_->advisory_file_locks->unlock_record_lock(
            permanent_file_id, process_.pid, range);
        shared_state_->note_io_event_transition();
        output_.write("[vfs] fcntl unlock pid=" + std::to_string(process_.pid) +
                      " fd=" + std::to_string(fd) + "\n");
        bsd_success(cpu, 0);
        return true;
    }

    const auto access_flags = file_status_flags_.contains(fd)
                                  ? file_status_flags_.at(fd)
                                  : darwin::open_flag::read_only;
    const auto access_mode = access_flags & darwin::open_flag::access_mode;
    if ((kind == bsd::AdvisoryLockKind::Shared &&
            access_mode == darwin::open_flag::write_only) ||
        (kind == bsd::AdvisoryLockKind::Exclusive &&
            access_mode == darwin::open_flag::read_only)) {
        bsd_error(cpu, bsd_support::bad_file_descriptor);
        return true;
    }
    if (shared_state_->advisory_file_locks->try_set_record_lock(
            permanent_file_id, process_.pid, range)) {
        output_.write(
            "[vfs] fcntl lock pid=" + std::to_string(process_.pid) +
            " fd=" + std::to_string(fd) + " mode=" +
            (kind == bsd::AdvisoryLockKind::Exclusive ? "write" : "read") +
            "\n");
        bsd_success(cpu, 0);
        return true;
    }
    if (command == darwin::fcntl_command::set_record_lock) {
        bsd_error(cpu, bsd_support::would_block);
        return true;
    }

    pending_record_locks_[cpu.processor_id()] =
        PendingRecordLock { fd, permanent_file_id, range, cpu.processor_id() };
    process_.waiting_for_events = true;
    output_.write("[vfs] fcntl lock wait pid=" + std::to_string(process_.pid) +
                  " fd=" + std::to_string(fd) + "\n");
    cpu.halt(Umbra::HaltReason::UserDefined5);
    return true;
}

bool CompatibilityKernel::dispatch_bsd_filesystem_locking(
    Cpu& cpu, std::uint32_t number)
{
    if (number != darwin::syscall::flock)
        return false;

    const auto fd = cpu.registers()[0];
    const auto how = cpu.registers()[1];
    const auto description = ensure_regular_file_open_description(fd);
    if (!description) {
        bsd_error(cpu, bsd_support::bad_file_descriptor);
        return true;
    }

    if ((how & darwin::flock_operation::unlock) != 0) {
        shared_state_->advisory_file_locks->release(*description);
        shared_state_->note_io_event_transition();
        output_.write("[vfs] flock unlock pid=" + std::to_string(process_.pid) +
                      " fd=" + std::to_string(fd) + "\n");
        bsd_success(cpu, 0);
        return true;
    }

    const auto kind = (how & darwin::flock_operation::exclusive) != 0
                          ? std::optional { bsd::AdvisoryLockKind::Exclusive }
                      : (how & darwin::flock_operation::shared) != 0
                          ? std::optional { bsd::AdvisoryLockKind::Shared }
                          : std::nullopt;
    if (!kind) {
        // Darwin 8's flock implementation returns EBADF when neither lock mode
        // bit is present, even though later APIs often use EINVAL here.
        bsd_error(cpu, bsd_support::bad_file_descriptor);
        return true;
    }

    if (shared_state_->advisory_file_locks->try_acquire(*description, *kind)) {
        output_.write(
            "[vfs] flock acquired pid=" + std::to_string(process_.pid) +
            " fd=" + std::to_string(fd) + " mode=" +
            (*kind == bsd::AdvisoryLockKind::Exclusive ? "exclusive"
                                                       : "shared") +
            "\n");
        bsd_success(cpu, 0);
        return true;
    }

    if ((how & darwin::flock_operation::non_blocking) != 0) {
        bsd_error(cpu, bsd_support::would_block);
        return true;
    }

    pending_flocks_[cpu.processor_id()] =
        PendingFlock { fd, *kind, description, cpu.processor_id() };
    process_.waiting_for_events = true;
    output_.write("[vfs] flock wait pid=" + std::to_string(process_.pid) +
                  " fd=" + std::to_string(fd) + "\n");
    cpu.halt(Umbra::HaltReason::UserDefined5);
    return true;
}

} // namespace shade
