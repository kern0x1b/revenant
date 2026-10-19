// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Apply guest filesystem ownership, permission and flag changes.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/vfs/vfs_syscalls.c

#include "kernel/kernel.hpp"

#include "kernel/darwin_abi.hpp"

#include <algorithm>
#include <cstdint>
#include <limits>
#include <mutex>
#include <optional>
#include <string>

#include "../support.hpp"

namespace shade {
namespace {

    constexpr std::uint32_t unchanged_identity =
        std::numeric_limits<std::uint32_t>::max();
    constexpr std::uint32_t permission_bits = 07777U;

} // namespace

bool CompatibilityKernel::dispatch_bsd_filesystem_ownership(
    Cpu& cpu, std::uint32_t number)
{
    auto& registers = cpu.registers();
    const auto change_owner = [&](const hfs::Metadata& metadata,
                                  std::uint32_t requested_owner,
                                  std::uint32_t requested_group) {
        if (process_.effective_uid != 0) {
            const bool owns_vnode = process_.effective_uid == metadata.owner;
            const bool owner_unchanged =
                requested_owner == unchanged_identity ||
                requested_owner == metadata.owner;
            const bool group_allowed =
                requested_group == unchanged_identity ||
                requested_group == metadata.group ||
                requested_group == process_.effective_gid;
            if (!owns_vnode || !owner_unchanged || !group_allowed) {
                bsd_error(cpu, darwin::error::operation_not_permitted);
                return false;
            }
        }
        const std::lock_guard filesystem_lock {
            shared_state_->filesystem_mutex
        };
        auto& metadata_override =
            shared_state_->hfs_metadata_overrides[metadata.permanent_id];
        if (requested_owner != unchanged_identity)
            metadata_override.owner = requested_owner;
        if (requested_group != unchanged_identity)
            metadata_override.group = requested_group;
        metadata_override.change_time =
            bsd_support::guest_filesystem_timestamp(shared_state_->clock);
        return true;
    };
    const auto change_mode = [&](const hfs::Metadata& metadata,
                                 std::uint32_t requested_mode) {
        if (process_.effective_uid != 0 &&
            process_.effective_uid != metadata.owner) {
            bsd_error(cpu, darwin::error::operation_not_permitted);
            return false;
        }
        const std::lock_guard filesystem_lock {
            shared_state_->filesystem_mutex
        };
        auto& metadata_override =
            shared_state_->hfs_metadata_overrides[metadata.permanent_id];
        metadata_override.mode = (metadata.mode & ~permission_bits) |
                                 (requested_mode & permission_bits);
        metadata_override.change_time =
            bsd_support::guest_filesystem_timestamp(shared_state_->clock);
        return true;
    };
    switch (number) {
    case darwin::syscall::change_mode: {
        const auto path = memory_.read_c_string(registers[0]);
        if (!path) {
            bsd_error(cpu, bsd_support::bad_address);
            return true;
        }
        const auto virtual_socket =
            std::any_of(bound_socket_names_.begin(), bound_socket_names_.end(),
                [&](const auto& entry) { return entry.second == *path; });
        std::error_code error;
        const auto host = resolve_guest_path(*path);
        const auto metadata = virtual_socket ? std::optional<hfs::Metadata> { }
                                             : query_hfs_metadata(host, true);
        if (!virtual_socket &&
            (!std::filesystem::exists(host, error) || !metadata)) {
            bsd_error(cpu, darwin::error::no_entry);
            return true;
        }
        if (metadata) {
            if (!change_mode(*metadata, registers[1]))
                return true;
        }
        output_.write("[vfs] chmod " + *path + " mode=" +
                      std::to_string(registers[1] & permission_bits) + "\n");
        bsd_success(cpu, 0);
        return true;
    }
    case darwin::syscall::change_mode_fd: {
        auto fd = registers[0];
        if (const auto duplicate = duplicated_descriptors_.find(fd);
            duplicate != duplicated_descriptors_.end()) {
            fd = duplicate->second;
        }
        const auto descriptor = file_descriptors_.find(fd);
        if (descriptor == file_descriptors_.end()) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
            return true;
        }
        const auto metadata = query_hfs_metadata(descriptor->second, true);
        if (!metadata) {
            bsd_error(cpu, darwin::error::no_entry);
            return true;
        }
        if (!change_mode(*metadata, registers[1]))
            return true;
        output_.write("[vfs] fchmod fd=" + std::to_string(fd) + " mode=" +
                      std::to_string(registers[1] & permission_bits) + "\n");
        bsd_success(cpu, 0);
        return true;
    }
    case darwin::syscall::change_mode_extended: {
        const auto requested_owner = registers[1];
        const auto requested_group = registers[2];
        const auto requested_mode = registers[3];
        const auto extended_security = registers[4];
        // Unlike fchmod_extended, the extended permission ABI uses NULL for no ACL
        // mutation and the sentinel pointer 1 to remove an ACL.
        constexpr std::uint32_t remove_acl = 1;
        if (extended_security != 0 && extended_security != remove_acl) {
            bsd_error(cpu, darwin::error::operation_not_supported);
            return true;
        }

        const auto path = memory_.read_c_string(registers[0]);
        if (!path) {
            bsd_error(cpu, bsd_support::bad_address);
            return true;
        }
        const auto host = resolve_guest_path(*path);
        std::error_code error;
        const auto metadata = query_hfs_metadata(host, true);
        if (!std::filesystem::exists(host, error) || !metadata) {
            bsd_error(cpu, darwin::error::no_entry);
            return true;
        }

        if (process_.effective_uid != 0) {
            const bool owns_vnode = process_.effective_uid == metadata->owner;
            const bool owner_unchanged =
                requested_owner == unchanged_identity ||
                requested_owner == metadata->owner;
            const bool group_allowed =
                requested_group == unchanged_identity ||
                requested_group == metadata->group ||
                requested_group == process_.effective_gid;
            if (!owns_vnode || !owner_unchanged || !group_allowed) {
                bsd_error(cpu, darwin::error::operation_not_permitted);
                return true;
            }
        }

        {
            const std::lock_guard filesystem_lock {
                shared_state_->filesystem_mutex
            };
            auto& metadata_override =
                shared_state_->hfs_metadata_overrides[metadata->permanent_id];
            if (requested_mode != unchanged_identity) {
                metadata_override.mode = (metadata->mode & ~permission_bits) |
                                         (requested_mode & permission_bits);
            }
            if (requested_owner != unchanged_identity)
                metadata_override.owner = requested_owner;
            if (requested_group != unchanged_identity)
                metadata_override.group = requested_group;
            metadata_override.change_time =
                bsd_support::guest_filesystem_timestamp(shared_state_->clock);
        }
        output_.write("[vfs] chmod_extended " + *path +
                      " uid=" + std::to_string(requested_owner) +
                      " gid=" + std::to_string(requested_group) + " mode=" +
                      std::to_string(requested_mode & permission_bits) + "\n");
        bsd_success(cpu, 0);
        return true;
    }
    case darwin::syscall::change_mode_extended_fd: {
        auto fd = registers[0];
        if (const auto duplicate = duplicated_descriptors_.find(fd);
            duplicate != duplicated_descriptors_.end()) {
            fd = duplicate->second;
        }
        const auto descriptor = file_descriptors_.find(fd);
        if (descriptor == file_descriptors_.end()) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
            return true;
        }
        const auto metadata = query_hfs_metadata(descriptor->second, true);
        if (!metadata) {
            bsd_error(cpu, darwin::error::no_entry);
            return true;
        }

        const auto requested_owner = registers[1];
        const auto requested_group = registers[2];
        const auto requested_mode = registers[3];
        const auto extended_security = registers[4];
        // the extended permission ABI uses NULL to remove the ACL and -1 to leave it
        // unchanged. ACLs are not exposed by the current HFS metadata
        // projection, so both operations are representable as no-ops. Refuse a
        // real filesec payload instead of reporting a silently incomplete
        // mutation.
        if (extended_security != 0 && extended_security != unchanged_identity) {
            bsd_error(cpu, darwin::error::operation_not_supported);
            return true;
        }

        if (process_.effective_uid != 0) {
            const bool owns_vnode = process_.effective_uid == metadata->owner;
            const bool owner_unchanged =
                requested_owner == unchanged_identity ||
                requested_owner == metadata->owner;
            const bool group_allowed =
                requested_group == unchanged_identity ||
                requested_group == metadata->group ||
                requested_group == process_.effective_gid;
            const bool mode_allowed =
                requested_mode == unchanged_identity || owns_vnode;
            if (!owns_vnode || !owner_unchanged || !group_allowed ||
                !mode_allowed) {
                bsd_error(cpu, darwin::error::operation_not_permitted);
                return true;
            }
        }

        {
            const std::lock_guard filesystem_lock {
                shared_state_->filesystem_mutex
            };
            auto& metadata_override =
                shared_state_->hfs_metadata_overrides[metadata->permanent_id];
            if (requested_mode != unchanged_identity) {
                metadata_override.mode = (metadata->mode & ~permission_bits) |
                                         (requested_mode & permission_bits);
            }
            if (requested_owner != unchanged_identity)
                metadata_override.owner = requested_owner;
            if (requested_group != unchanged_identity)
                metadata_override.group = requested_group;
            metadata_override.change_time =
                bsd_support::guest_filesystem_timestamp(shared_state_->clock);
        }
        output_.write("[vfs] fchmod_extended fd=" + std::to_string(fd) +
                      " uid=" + std::to_string(requested_owner) +
                      " gid=" + std::to_string(requested_group) + " mode=" +
                      std::to_string(requested_mode & permission_bits) + "\n");
        bsd_success(cpu, 0);
        return true;
    }
    case darwin::syscall::change_owner: {
        const auto path = memory_.read_c_string(registers[0]);
        if (!path) {
            bsd_error(cpu, bsd_support::bad_address);
            return true;
        }
        const auto host = resolve_guest_path(*path);
        std::error_code error;
        const auto metadata = query_hfs_metadata(host, true);
        if (!std::filesystem::exists(host, error) || !metadata) {
            bsd_error(cpu, darwin::error::no_entry);
            return true;
        }
        const auto requested_owner = registers[1];
        const auto requested_group = registers[2];
        if (!change_owner(*metadata, requested_owner, requested_group))
            return true;
        output_.write("[vfs] chown " + *path +
                      " uid=" + std::to_string(requested_owner) +
                      " gid=" + std::to_string(requested_group) + "\n");
        bsd_success(cpu, 0);
        return true;
    }
    case darwin::syscall::change_owner_link: {
        // lchown(2) changes the owner of a symbolic link itself rather than
        // the file it names.
        const auto path = memory_.read_c_string(registers[0]);
        if (!path) {
            bsd_error(cpu, bsd_support::bad_address);
            return true;
        }
        const auto host = resolve_guest_path(*path, false);
        std::error_code error;
        const auto status = std::filesystem::symlink_status(host, error);
        const auto metadata = query_hfs_metadata(host, false);
        if (error || status.type() == std::filesystem::file_type::not_found ||
            !metadata) {
            bsd_error(cpu, darwin::error::no_entry);
            return true;
        }
        const auto requested_owner = registers[1];
        const auto requested_group = registers[2];
        if (!change_owner(*metadata, requested_owner, requested_group))
            return true;
        output_.write("[vfs] lchown " + *path +
                      " uid=" + std::to_string(requested_owner) +
                      " gid=" + std::to_string(requested_group) + "\n");
        bsd_success(cpu, 0);
        return true;
    }
    case darwin::syscall::change_owner_fd: {
        auto fd = registers[0];
        if (const auto duplicate = duplicated_descriptors_.find(fd);
            duplicate != duplicated_descriptors_.end()) {
            fd = duplicate->second;
        }
        const auto descriptor = file_descriptors_.find(fd);
        if (descriptor == file_descriptors_.end()) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
            return true;
        }
        const auto metadata = query_hfs_metadata(descriptor->second, true);
        if (!metadata) {
            bsd_error(cpu, darwin::error::no_entry);
            return true;
        }
        if (!change_owner(*metadata, registers[1], registers[2]))
            return true;
        output_.write("[vfs] fchown fd=" + std::to_string(fd) +
                      " uid=" + std::to_string(registers[1]) +
                      " gid=" + std::to_string(registers[2]) + "\n");
        bsd_success(cpu, 0);
        return true;
    }
    case darwin::syscall::change_flags: {
        const auto path = memory_.read_c_string(registers[0]);
        if (!path) {
            bsd_error(cpu, bsd_support::bad_address);
            return true;
        }
        std::error_code error;
        const auto host = resolve_guest_path(*path);
        const auto metadata = query_hfs_metadata(host, true);
        if (!std::filesystem::exists(host, error) || !metadata) {
            bsd_error(cpu, darwin::error::no_entry);
            return true;
        }
        if (process_.effective_uid != 0 &&
            process_.effective_uid != metadata->owner) {
            bsd_error(cpu, darwin::error::operation_not_permitted);
            return true;
        }
        const std::lock_guard filesystem_lock {
            shared_state_->filesystem_mutex
        };
        auto& metadata_override =
            shared_state_->hfs_metadata_overrides[metadata->permanent_id];
        metadata_override.flags = registers[1];
        metadata_override.change_time =
            bsd_support::guest_filesystem_timestamp(shared_state_->clock);
        bsd_success(cpu, 0);
        return true;
    }
    case darwin::syscall::change_flags_fd: {
        auto fd = registers[0];
        if (const auto duplicate = duplicated_descriptors_.find(fd);
            duplicate != duplicated_descriptors_.end()) {
            fd = duplicate->second;
        }
        if (const auto descriptor = file_descriptors_.find(fd);
            descriptor != file_descriptors_.end()) {
            const auto metadata = query_hfs_metadata(descriptor->second, true);
            if (!metadata) {
                bsd_error(cpu, darwin::error::no_entry);
                return true;
            }
            if (process_.effective_uid != 0 &&
                process_.effective_uid != metadata->owner) {
                bsd_error(cpu, darwin::error::operation_not_permitted);
                return true;
            }
            const std::lock_guard filesystem_lock {
                shared_state_->filesystem_mutex
            };
            auto& metadata_override =
                shared_state_->hfs_metadata_overrides[metadata->permanent_id];
            metadata_override.flags = registers[1];
            metadata_override.change_time =
                bsd_support::guest_filesystem_timestamp(shared_state_->clock);
            bsd_success(cpu, 0);
        } else if (fd > 2 && !virtual_descriptors_.contains(fd)) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
        } else {
            bsd_success(cpu, 0);
        }
        return true;
    }
    default:
        return false;
    }
}

} // namespace shade
