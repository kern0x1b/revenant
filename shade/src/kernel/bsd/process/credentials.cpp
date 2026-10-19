// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Handle guest process user, group and privilege state changes.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/kern/kern_prot.c

#include "kernel/kernel.hpp"

#include "kernel/darwin_abi.hpp"

#include <array>
#include <cstdint>
#include <limits>
#include <string>

namespace shade {
namespace {

    constexpr std::uint32_t maximum_supplementary_groups = 16;

} // namespace

bool CompatibilityKernel::dispatch_bsd_process_credentials(
    Cpu& cpu, std::uint32_t number)
{
    if (number != darwin::syscall::set_groups &&
        number != darwin::syscall::set_user_id &&
        number != darwin::syscall::set_real_effective_user_id &&
        number != darwin::syscall::set_real_effective_group_id &&
        number != darwin::syscall::set_group_id &&
        number != darwin::syscall::set_effective_group_id &&
        number != darwin::syscall::set_effective_user_id &&
        number != darwin::syscall::init_groups)
        return false;

    if (number == darwin::syscall::set_groups ||
        number == darwin::syscall::init_groups) {
        const auto requested_count = cpu.registers()[0];
        const auto group_address = cpu.registers()[1];
        if (requested_count > maximum_supplementary_groups) {
            bsd_error(cpu, darwin::error::invalid_argument);
            return true;
        }

        std::array<std::uint32_t, maximum_supplementary_groups> groups { };
        if (requested_count > 0) {
            if (group_address == 0 ||
                group_address > std::numeric_limits<std::uint32_t>::max() -
                                    requested_count * sizeof(std::uint32_t)) {
                bsd_error(cpu, darwin::error::bad_address);
                return true;
            }
            for (std::uint32_t index = 0; index < requested_count; ++index) {
                const auto group = memory_.read32(group_address + index * 4U);
                if (!group) {
                    bsd_error(cpu, darwin::error::bad_address);
                    return true;
                }
                groups[index] = *group;
            }
        }

        if (process_.effective_uid != 0) {
            bsd_error(cpu, darwin::error::operation_not_permitted);
            return true;
        }

        // The compatibility model currently only consumes the effective group.
        // Darwin stores it in cr_groups[0], so keep that observable part while
        // leaving supplementary membership unexpanded until VFS authorization
        // actually needs it.
        process_.effective_gid = groups[0];
        if (const auto record = shared_state_->processes.find(process_.pid);
            record != shared_state_->processes.end()) {
            record->second.effective_gid = groups[0];
        }

        output_.write(
            "[process] " +
            std::string(number == darwin::syscall::init_groups ? "initgroups"
                                                               : "setgroups") +
            " pid=" + std::to_string(process_.pid) +
            " count=" + std::to_string(requested_count) +
            " egid=" + std::to_string(groups[0]) + "\n");
        bsd_success(cpu, 0);
        return true;
    }

    if (number == darwin::syscall::set_real_effective_group_id) {
        constexpr std::uint32_t unchanged =
            std::numeric_limits<std::uint32_t>::max();
        const auto requested_real = cpu.registers()[0];
        const auto requested_effective = cpu.registers()[1];
        const auto old_real = process_.gid;
        const auto old_effective = process_.effective_gid;
        const auto privileged = process_.effective_uid == 0;
        const auto permitted = [&](std::uint32_t requested) {
            // Set-id image transitions are not modeled yet, so the saved group
            // ID has the same observable value as the real group ID.
            return requested == unchanged || privileged ||
                   requested == old_real || requested == old_effective;
        };
        if (!permitted(requested_real) || !permitted(requested_effective)) {
            bsd_error(cpu, darwin::error::operation_not_permitted);
            return true;
        }

        if (requested_real != unchanged)
            process_.gid = requested_real;
        if (requested_effective != unchanged)
            process_.effective_gid = requested_effective;
        if (const auto record = shared_state_->processes.find(process_.pid);
            record != shared_state_->processes.end()) {
            if (requested_real != unchanged)
                record->second.gid = requested_real;
            if (requested_effective != unchanged)
                record->second.effective_gid = requested_effective;
        }
        output_.write("[process] setregid pid=" + std::to_string(process_.pid) +
                      " gid=" + std::to_string(process_.gid) +
                      " egid=" + std::to_string(process_.effective_gid) + "\n");
        bsd_success(cpu, 0);
        return true;
    }

    if (number == darwin::syscall::set_real_effective_user_id) {
        constexpr std::uint32_t unchanged =
            std::numeric_limits<std::uint32_t>::max();
        const auto requested_real = cpu.registers()[0];
        const auto requested_effective = cpu.registers()[1];
        const auto old_real = process_.uid;
        const auto old_effective = process_.effective_uid;
        const auto privileged = old_effective == 0;
        const auto permitted = [&](std::uint32_t requested) {
            // Set-id image transitions are not modeled yet, so the saved user
            // ID has the same observable value as the real user ID.
            return requested == unchanged || privileged ||
                   requested == old_real || requested == old_effective;
        };
        if (!permitted(requested_real) || !permitted(requested_effective)) {
            bsd_error(cpu, darwin::error::operation_not_permitted);
            return true;
        }

        if (requested_real != unchanged)
            process_.uid = requested_real;
        if (requested_effective != unchanged)
            process_.effective_uid = requested_effective;
        if (const auto record = shared_state_->processes.find(process_.pid);
            record != shared_state_->processes.end()) {
            if (requested_real != unchanged)
                record->second.uid = requested_real;
            if (requested_effective != unchanged)
                record->second.effective_uid = requested_effective;
        }
        output_.write("[process] setreuid pid=" + std::to_string(process_.pid) +
                      " uid=" + std::to_string(process_.uid) +
                      " euid=" + std::to_string(process_.effective_uid) + "\n");
        bsd_success(cpu, 0);
        return true;
    }

    if (number == darwin::syscall::set_user_id ||
        number == darwin::syscall::set_effective_user_id) {
        const auto requested_user = cpu.registers()[0];
        // As with the saved group below, the saved user currently equals the
        // real user because set-id executable transitions are not modeled yet.
        if (process_.effective_uid != 0 && requested_user != process_.uid) {
            bsd_error(cpu, darwin::error::operation_not_permitted);
            return true;
        }
        if (number == darwin::syscall::set_user_id &&
            process_.effective_uid == 0) {
            process_.uid = requested_user;
        }
        process_.effective_uid = requested_user;
        if (const auto record = shared_state_->processes.find(process_.pid);
            record != shared_state_->processes.end()) {
            if (number == darwin::syscall::set_user_id &&
                record->second.effective_uid == 0) {
                record->second.uid = requested_user;
            }
            record->second.effective_uid = requested_user;
        }
        output_.write(
            "[process] " +
            std::string(
                number == darwin::syscall::set_user_id ? "setuid" : "seteuid") +
            " pid=" + std::to_string(process_.pid) +
            " uid=" + std::to_string(requested_user) + "\n");
        bsd_success(cpu, 0);
        return true;
    }

    const auto requested_group = cpu.registers()[0];
    // XNU permits the real or saved group without privilege. The current
    // loader has no set-id image transition yet, so the saved group equals the
    // real group. Root may select any effective group.
    if (process_.effective_uid != 0 && requested_group != process_.gid) {
        bsd_error(cpu, darwin::error::operation_not_permitted);
        return true;
    }

    if (number == darwin::syscall::set_group_id) {
        process_.gid = requested_group;
    }
    process_.effective_gid = requested_group;
    if (const auto record = shared_state_->processes.find(process_.pid);
        record != shared_state_->processes.end()) {
        if (number == darwin::syscall::set_group_id) {
            record->second.gid = requested_group;
        }
        record->second.effective_gid = requested_group;
    }
    output_.write(
        "[process] " +
        std::string(
            number == darwin::syscall::set_group_id ? "setgid" : "setegid") +
        " pid=" + std::to_string(process_.pid) +
        " gid=" + std::to_string(requested_group) + "\n");
    bsd_success(cpu, 0);
    return true;
}

} // namespace shade
