// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Reply to guest Mach task-information and accounting queries.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/task.defs

#include "kernel/kernel.hpp"

#include "kernel/mach_task_info_abi.hpp"
#include "mach/mig_wire_abi.hpp"
#include "mach/task_mig_ids.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <mutex>
#include <optional>
#include <span>
#include <string>
#include <vector>

#include "../support.hpp"

namespace shade {
namespace {

    using namespace mach_support;

    constexpr std::uint32_t mach_message_success = 0;
    constexpr std::uint32_t mach_receive_invalid_data = 0x10004008U;
    constexpr std::uint32_t kernel_invalid_argument = 4;
    constexpr std::uint32_t simple_reply_size = 36;
    constexpr std::uint32_t info_reply_prefix_size = 40;

    bool write_words(AddressSpace& memory, std::uint32_t address,
        std::span<const std::uint32_t> words)
    {
        for (std::size_t index = 0; index < words.size(); ++index) {
            if (!memory.write32(address + static_cast<std::uint32_t>(
                                              index * sizeof(std::uint32_t)),
                    words[index])) {
                return false;
            }
        }
        return true;
    }

    std::size_t requested_word_count(std::uint32_t flavor)
    {
        switch (flavor) {
        case darwin::mach::task_info::absolute_time_flavor:
            return darwin::mach::task_info::absolute_time_word_count;
        case darwin::mach::task_info::events_flavor:
            return darwin::mach::task_info::events_word_count;
        case darwin::mach::task_info::thread_times_flavor:
            return darwin::mach::task_info::thread_times_word_count;
        case darwin::mach::task_info::basic_32_flavor:
            return darwin::mach::task_info::basic_32_word_count;
        case darwin::mach::task_info::basic_64_flavor:
            return darwin::mach::task_info::basic_64_word_count;
        case darwin::mach::task_info::dyld_info_flavor:
            return darwin::mach::task_info::dyld_info_word_count;
        default:
            return 0;
        }
    }

} // namespace

bool CompatibilityKernel::dispatch_mach_task_info_message(
    Cpu& cpu, const MachMessageRequest& request)
{
    if (request.identifier !=
        mig_message_id(xnu::mig::task::Routine::task_info)) {
        return false;
    }

    auto& registers = cpu.registers();
    const auto& arguments = xnu::mig::task::task_info_arguments;
    const auto flavor =
        memory_.read32(request.address + arguments[1].request_offset);
    const auto capacity =
        memory_.read32(request.address + arguments[2].request_count_offset);
    std::optional<std::uint32_t> target_pid;
    {
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        target_pid = target_task_name_for_port(
            *shared_state_, process_.pid, request.remote_port);
    }
    const auto word_count = flavor ? requested_word_count(*flavor) : 0U;
    const auto target_record = target_pid
                                   ? shared_state_->processes.find(*target_pid)
                                   : shared_state_->processes.end();
    const bool missing_dyld_info =
        flavor && *flavor == darwin::mach::task_info::dyld_info_flavor &&
        (target_record == shared_state_->processes.end() ||
            target_record->second.dyld_all_image_info_address == 0U);
    if (!flavor || !capacity || !target_pid || word_count == 0U ||
        *capacity < word_count || missing_dyld_info) {
        const std::array<std::uint32_t,
            simple_reply_size / sizeof(std::uint32_t)>
            reply {
                darwin::mig_wire::message_bits(
                    darwin::mig_wire::disposition_move_send_once),
                simple_reply_size,
                request.local_port,
                0,
                0,
                request.identifier + 100,
                0,
                1,
                kernel_invalid_argument,
            };
        registers[0] = write_words(memory_, request.address, reply)
                           ? mach_message_success
                           : mach_receive_invalid_data;
        output_.write(
            "[mach] task_info caller=" + std::to_string(process_.pid) +
            " flavor=" + std::to_string(flavor.value_or(0)) + " capacity=" +
            std::to_string(capacity.value_or(0)) + " result=4\n");
        return true;
    }

    const auto reply_size = static_cast<std::uint32_t>(
        info_reply_prefix_size + word_count * sizeof(std::uint32_t));
    if (registers[3] < reply_size) {
        registers[0] = mach_receive_invalid_data;
        return true;
    }
    std::vector<std::uint32_t> reply {
        darwin::mig_wire::message_bits(
            darwin::mig_wire::disposition_move_send_once),
        reply_size,
        request.local_port,
        0,
        0,
        request.identifier + 100,
        0,
        1,
        mach_message_success,
        static_cast<std::uint32_t>(word_count),
    };
    std::vector<std::uint32_t> info(word_count);
    if (*flavor == darwin::mach::task_info::basic_32_flavor &&
        *target_pid == process_.pid) {
        info[1] = static_cast<std::uint32_t>(
            memory_.mapped_page_count() * AddressSpace::page_size);
        info[2] = static_cast<std::uint32_t>(
            memory_.resident_page_count() * AddressSpace::page_size);
        info[7] = darwin::mach::task_info::timeshare_policy;
    } else if (*flavor == darwin::mach::task_info::basic_64_flavor) {
        if (*target_pid == process_.pid) {
            const auto virtual_size =
                static_cast<std::uint64_t>(memory_.mapped_page_count()) *
                AddressSpace::page_size;
            const auto resident_size =
                static_cast<std::uint64_t>(memory_.resident_page_count()) *
                AddressSpace::page_size;
            info[1] = static_cast<std::uint32_t>(virtual_size);
            info[2] = static_cast<std::uint32_t>(virtual_size >> 32U);
            info[3] = static_cast<std::uint32_t>(resident_size);
            info[4] = static_cast<std::uint32_t>(resident_size >> 32U);
        }
        if (info.size() > 9)
            info[9] = darwin::mach::task_info::timeshare_policy;
    }
    if (*flavor == darwin::mach::task_info::dyld_info_flavor) {
        // mach_vm_address_t and mach_vm_size_t are 64-bit even on ARM32.
        info[0] = target_record->second.dyld_all_image_info_address;
        info[2] = target_record->second.dyld_all_image_info_size;
        info[4] = 0; // TASK_DYLD_ALL_IMAGE_INFO_32
    }
    reply.insert(reply.end(), info.begin(), info.end());
    registers[0] = write_words(memory_, request.address, reply)
                       ? mach_message_success
                       : mach_receive_invalid_data;
    output_.write("[mach] task_info caller=" + std::to_string(process_.pid) +
                  " target=" + std::to_string(*target_pid) +
                  " flavor=" + std::to_string(*flavor) +
                  " count=" + std::to_string(word_count) + " result=0\n");
    return true;
}

} // namespace shade
