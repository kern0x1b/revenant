// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Keep guest memory-priority metadata in the guest process table. This does
// not change host thread priorities or invent host-driven jetsam kills.
// https://github.com/apple-oss-distributions/xnu/blob/xnu-2422.1.72/bsd/kern/kern_memorystatus.c

#include "kernel/kernel.hpp"

#include "kernel/darwin_abi.hpp"
#include "kernel/darwin_memorystatus_abi.hpp"

#include <algorithm>
#include <array>
#include <mutex>
#include <vector>

namespace shade {

bool CompatibilityKernel::dispatch_bsd_memorystatus(
    Cpu& cpu, std::uint32_t number)
{
    using namespace darwin::memorystatus;
    if (number != syscall_number)
        return false;

    const auto priority_abi = shared_state_->darwin_abi.memory_status_priority;
    if (priority_abi == DarwinMemoryStatusPriorityAbi::Unsupported)
        return false;

    const auto& registers = cpu.registers();
    const auto command = registers[0];
    const auto pid = registers[1];
    const auto buffer = registers[3];
    const auto size = registers[4];
    if (process_.effective_uid != 0U) {
        bsd_error(cpu, darwin::error::operation_not_permitted);
        return true;
    }
    if (size > maximum_buffer_size) {
        bsd_error(cpu, darwin::error::invalid_argument);
        return true;
    }

    if (command == set_priority_properties) {
        if (pid == 0U || buffer == 0U || size == 0U ||
            size % properties_size != 0U ||
            size / properties_size > maximum_property_count) {
            bsd_error(cpu, darwin::error::invalid_argument);
            return true;
        }
        if (!memory_.accessible(buffer, size, MemoryPermission::Read)) {
            bsd_error(cpu, darwin::error::bad_address);
            return true;
        }
        for (std::uint32_t offset = 0; offset < size;
            offset += properties_size) {
            const auto priority_word = memory_.read32(buffer + offset);
            const auto user_data = memory_.read64(buffer + offset + 4U);
            if (!priority_word || !user_data) {
                bsd_error(cpu, darwin::error::bad_address);
                return true;
            }
            auto priority = static_cast<std::int32_t>(*priority_word);
            if (priority_abi == DarwinMemoryStatusPriorityAbi::PriorityBands) {
                if (priority == -1)
                    priority = default_band;
                else if (priority == deferred_idle_priority)
                    priority = idle_priority;
                if (priority < 0 || priority > maximum_priority) {
                    bsd_error(cpu, darwin::error::invalid_argument);
                    return true;
                }
            }
            std::lock_guard lock { shared_state_->mach_mutex };
            const auto target = shared_state_->processes.find(pid);
            if (target == shared_state_->processes.end() ||
                target->second.exited) {
                bsd_error(cpu, darwin::error::no_such_process);
                return true;
            }
            target->second.memory_status = { priority, *user_data };
            output_.write("[memorystatus] priority caller=" +
                          std::to_string(process_.pid) +
                          " target=" + std::to_string(pid) +
                          " priority=" + std::to_string(priority) +
                          " user-data=" + std::to_string(*user_data) + "\n");
        }
        bsd_success(cpu, 0);
        return true;
    }

    if (command == get_priority_list) {
        std::vector<std::array<std::uint32_t, 6>> entries;
        {
            std::lock_guard lock { shared_state_->mach_mutex };
            for (const auto& [entry_pid, record] : shared_state_->processes) {
                if (record.exited)
                    continue;
                const auto& state = record.memory_status;
                entries.push_back(
                    { entry_pid, static_cast<std::uint32_t>(state.priority),
                        static_cast<std::uint32_t>(state.user_data),
                        static_cast<std::uint32_t>(state.user_data >> 32U),
                        0xffffffffU, record.pid_suspended ? 1U : 0U });
            }
        }
        std::stable_sort(entries.begin(), entries.end(),
            [priority_abi](const auto& left, const auto& right) {
                const auto lhs = static_cast<std::int32_t>(left[1]);
                const auto rhs = static_cast<std::int32_t>(right[1]);
                return priority_abi ==
                               DarwinMemoryStatusPriorityAbi::SignedPriority
                           ? lhs > rhs
                           : lhs < rhs;
            });
        const auto required =
            static_cast<std::uint32_t>(entries.size()) * priority_entry_size;
        if (buffer != 0U) {
            if (size < required) {
                bsd_error(cpu, darwin::error::invalid_argument);
                return true;
            }
            std::vector<std::byte> bytes(required);
            std::size_t cursor = 0;
            for (const auto& entry : entries) {
                for (const auto word : entry) {
                    for (unsigned byte = 0; byte < 4U; ++byte)
                        bytes[cursor++] =
                            static_cast<std::byte>(word >> (byte * 8U));
                }
            }
            if (!memory_.copy_in(buffer, bytes)) {
                bsd_error(cpu, darwin::error::bad_address);
                return true;
            }
        }
        bsd_success(cpu, required);
        return true;
    }

    bsd_error(cpu, darwin::error::invalid_argument);
    return true;
}

} // namespace shade
