// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Return guest process metadata and resource-information records.

#include "kernel/kernel.hpp"

#include "kernel/darwin_abi.hpp"
#include "kernel/darwin_proc_info_abi.hpp"

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <mutex>
#include <string>
#include <vector>

namespace shade {

bool CompatibilityKernel::dispatch_bsd_process_information(
    Cpu& cpu, std::uint32_t number)
{
    if (number != darwin::proc_info::syscall_number)
        return false;

    const auto& registers = cpu.registers();
    const auto call = registers[0];
    const auto target_pid = static_cast<std::int32_t>(registers[1]);
    const auto flavor = registers[2];
    const auto output_address = registers[5];
    const auto output_size = registers[6];

    if (call == darwin::proc_info::call_pid_info &&
        flavor == darwin::proc_info::flavor_pid_short_bsd_info) {
        constexpr auto size = darwin::proc_info::short_bsd_info_size;
        if (output_size < size) {
            bsd_error(cpu, darwin::error::no_memory);
            return true;
        }
        std::vector<std::byte> output(size, std::byte { 0 });
        const auto word = [&](std::size_t offset, std::uint32_t value) {
            for (std::size_t byte = 0; byte < 4; ++byte)
                output[offset + byte] = static_cast<std::byte>(value >> (8U * byte));
        };
        {
            std::lock_guard lock { shared_state_->mach_mutex };
            const auto target = shared_state_->processes.find(
                static_cast<std::uint32_t>(target_pid));
            if (target_pid <= 0 || target == shared_state_->processes.end()) {
                bsd_error(cpu, darwin::error::no_such_process);
                return true;
            }
            const auto& record = target->second;
            word(0, static_cast<std::uint32_t>(target_pid));
            word(4, record.parent_pid);
            word(8, record.process_group);
            // BSD p_stat records job-control stops, independently of the
            // task suspension used by the host scheduler.
            word(12, record.exited ? 5U : record.signal_stopped ? 4U : 2U);
            const auto count = std::min<std::size_t>(record.command.size(), 15U);
            for (std::size_t index = 0; index < count; ++index)
                output[16U + index] = static_cast<std::byte>(record.command[index]);
            word(32, (record.exited ? 4U : 0U) |
                         (record.importance_donor
                                 ? darwin::proc_info::flag_importance_donor
                                 : 0U));
            word(36, record.effective_uid);
            word(40, record.effective_gid);
            word(44, record.uid);
            word(48, record.gid);
            // The current credential model has no separate saved-ID state.
            word(52, record.effective_uid);
            word(56, record.effective_gid);
        }
        if (output_address == 0 || !memory_.copy_in(output_address, output)) {
            bsd_error(cpu, darwin::error::bad_address);
            return true;
        }
        bsd_success(cpu, size);
        return true;
    }



    const auto include_bsd =
        flavor == darwin::proc_info::flavor_pid_bsd_info_with_identity;
    if (call == darwin::proc_info::call_pid_info &&
        (include_bsd ||
            flavor == darwin::proc_info::flavor_pid_unique_identifier_info)) {
        const auto identity_offset = include_bsd
            ? darwin::proc_info::bsd_info_size : 0U;
        const auto size = identity_offset +
            darwin::proc_info::unique_identifier_info_size;
        if (output_size < size) {
            bsd_error(cpu, darwin::error::no_memory);
            return true;
        }
        std::vector<std::byte> output(size, std::byte { 0 });
        const auto integer = [&](std::size_t offset, std::uint64_t value,
                                 unsigned bytes = 4U) {
            for (unsigned index = 0; index < bytes; ++index)
                output[offset + index] =
                    static_cast<std::byte>(value >> (8U * index));
        };
        {
            std::lock_guard lock { shared_state_->mach_mutex };
            const auto target = shared_state_->processes.find(
                static_cast<std::uint32_t>(target_pid));
            if (target_pid <= 0 || target == shared_state_->processes.end() ||
                target->second.exited) {
                bsd_error(cpu, darwin::error::no_such_process);
                return true;
            }
            const auto& record = target->second;
            std::copy(record.executable_uuid.begin(), record.executable_uuid.end(),
                output.begin() + identity_offset);
            integer(identity_offset + 16U, record.incarnation, 8U);
            integer(identity_offset + 24U, record.parent_incarnation, 8U);
            if (include_bsd) {
                integer(0, record.importance_donor
                    ? darwin::proc_info::flag_importance_donor : 0U);
                integer(4, record.signal_stopped ? 4U : 2U);
                integer(12, static_cast<std::uint32_t>(target_pid));
                integer(16, record.parent_pid);
                integer(20, record.effective_uid);
                integer(24, record.effective_gid);
                integer(28, record.uid);
                integer(32, record.gid);
                integer(36, record.effective_uid);
                integer(40, record.effective_gid);
                const auto count = std::min<std::size_t>(record.command.size(), 15U);
                for (std::size_t index = 0; index < count; ++index)
                    output[48U + index] = static_cast<std::byte>(record.command[index]);
                integer(100, record.process_group);
                integer(108, UINT32_MAX); // NODEV: no controlling terminal.
                integer(112, UINT32_MAX);
                integer(116, static_cast<std::uint32_t>(record.nice_value));
                integer(120, record.start_wall_nanoseconds / 1'000'000'000ULL, 8U);
                integer(128, record.start_wall_nanoseconds / 1'000ULL % 1'000'000ULL, 8U);
            }
        }
        if (output_address == 0 || !memory_.copy_in(output_address, output)) {
            bsd_error(cpu, darwin::error::bad_address);
            return true;
        }
        bsd_success(cpu, size);
        return true;
    }

    if (call != darwin::proc_info::call_pid_info ||
        flavor != darwin::proc_info::flavor_pid_path_info) {
        bsd_error(cpu, darwin::error::invalid_argument);
        return true;
    }
    if (output_size < darwin::proc_info::path_info_size) {
        bsd_error(cpu, darwin::error::no_memory);
        return true;
    }
    if (output_size > darwin::proc_info::path_info_max_size) {
        bsd_error(cpu, darwin::error::value_too_large);
        return true;
    }

    std::string executable_path;
    {
        std::lock_guard lock { shared_state_->mach_mutex };
        const auto target = target_pid > 0
                                ? shared_state_->processes.find(
                                      static_cast<std::uint32_t>(target_pid))
                                : shared_state_->processes.end();
        if (target == shared_state_->processes.end() || target->second.exited ||
            target->second.executable_path.empty()) {
            bsd_error(cpu, darwin::error::no_such_process);
            return true;
        }
        executable_path = target->second.executable_path;
    }

    if (executable_path.size() >= output_size) {
        bsd_error(cpu, darwin::error::no_memory);
        return true;
    }
    std::vector<std::byte> output(output_size, std::byte { 0 });
    for (std::size_t index = 0; index < executable_path.size(); ++index) {
        output[index] = static_cast<std::byte>(
            static_cast<unsigned char>(executable_path[index]));
    }
    if (output_address == 0 || !memory_.copy_in(output_address, output)) {
        bsd_error(cpu, darwin::error::bad_address);
        return true;
    }

    output_.write("[process] pid-path caller=" + std::to_string(process_.pid) +
                  " target=" + std::to_string(target_pid) +
                  " path=" + executable_path + "\n");
    bsd_success(cpu, 0);
    return true;
}

} // namespace shade
