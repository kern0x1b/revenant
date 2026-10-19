// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Read and update guest ARM thread register-state flavors.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/thread_act.defs

#include "kernel/kernel.hpp"

#include "kernel/mach_arm_thread_abi.hpp"
#include "kernel/mach_thread_info_abi.hpp"
#include "mach/mig_wire_abi.hpp"
#include "mach/thread_act_mig_ids.hpp"
#include "mach/xnu_scheduler.hpp"

#include <algorithm>
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
    constexpr std::uint32_t state_reply_prefix_size = 40;

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

} // namespace

bool CompatibilityKernel::dispatch_mach_thread_state_message(
    Cpu& cpu, const MachMessageRequest& request)
{
    const auto gets_info =
        request.identifier ==
        mig_message_id(xnu::mig::thread_act::Routine::thread_info);
    const auto gets_state =
        request.identifier ==
        mig_message_id(xnu::mig::thread_act::Routine::thread_get_state);
    const auto sets_state =
        request.identifier ==
            mig_message_id(
                xnu::mig::thread_act::Routine::thread_set_state) ||
        request.identifier ==
            mig_message_id(xnu::mig::thread_act::Routine::act_set_state);
    if (!gets_info && !gets_state && !sets_state) {
        return false;
    }

    auto& registers = cpu.registers();
    if (gets_info) {
        const auto& arguments = xnu::mig::thread_act::thread_info_arguments;
        const auto flavor =
            memory_.read32(request.address + arguments[1].request_offset);
        const auto capacity =
            memory_.read32(request.address + arguments[2].request_count_offset);
        std::optional<std::pair<std::uint32_t, std::uint32_t>> target_owner;
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            const auto object = resolve_name_with_right(*shared_state_,
                process_.pid, request.remote_port, xnu::ipc::Right::Send);
            if (object) {
                target_owner = find_thread_owner(*shared_state_, *object);
            }
        }

        const auto requested_word_count =
            flavor && *flavor == darwin::mach::thread_info::basic_flavor
                ? darwin::mach::thread_info::basic_word_count
            : flavor &&
                    *flavor == darwin::mach::thread_info::sched_timeshare_flavor
                ? darwin::mach::thread_info::sched_timeshare_word_count
                : 0U;
        if (!flavor || !capacity || !target_owner ||
            requested_word_count == 0U || *capacity < requested_word_count) {
            const std::array<std::uint32_t,
                simple_reply_size / sizeof(std::uint32_t)>
                reply { darwin::mig_wire::message_bits(
                            darwin::mig_wire::disposition_move_send_once),
                    simple_reply_size, request.local_port, 0, 0,
                    request.identifier + 100, 0, 1, kernel_invalid_argument };
            registers[0] = write_words(memory_, request.address, reply)
                               ? mach_message_success
                               : mach_receive_invalid_data;
            output_.write(
                "[mach] thread_info caller=" + std::to_string(process_.pid) +
                " flavor=" + std::to_string(flavor.value_or(0)) + " capacity=" +
                std::to_string(capacity.value_or(0)) + " result=4\n");
            return true;
        }

        const auto reply_size = static_cast<std::uint32_t>(
            state_reply_prefix_size +
            requested_word_count * sizeof(std::uint32_t));
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
            static_cast<std::uint32_t>(requested_word_count),
        };
        if (*flavor == darwin::mach::thread_info::basic_flavor) {
            const std::array<std::uint32_t,
                darwin::mach::thread_info::basic_word_count>
                basic_info {
                    0, // user_time.seconds
                    0, // user_time.microseconds
                    0, // system_time.seconds
                    0, // system_time.microseconds
                    0, // cpu_usage
                    darwin::mach::thread_info::standard_policy,
                    darwin::mach::thread_info::waiting_state,
                    0, // flags
                    0, // suspend_count
                    0, // sleep_time
                };
            reply.insert(reply.end(), basic_info.begin(), basic_info.end());
        } else {
            const auto priority = static_cast<std::uint32_t>(
                target_owner->first == process_.pid
                    ? std::clamp(process_.thread_base_priority,
                          xnu::scheduler::minimum_priority,
                          xnu::scheduler::maximum_user_priority)
                    : xnu::scheduler::default_base_priority);
            const std::array<std::uint32_t,
                darwin::mach::thread_info::sched_timeshare_word_count>
                timeshare_info {
                    static_cast<std::uint32_t>(
                        xnu::scheduler::maximum_user_priority),
                    priority,
                    priority,
                    0, // depressed
                    priority,
                };
            reply.insert(
                reply.end(), timeshare_info.begin(), timeshare_info.end());
        }
        registers[0] = write_words(memory_, request.address, reply)
                           ? mach_message_success
                           : mach_receive_invalid_data;
        output_.write(
            "[mach] thread_info caller=" + std::to_string(process_.pid) +
            " flavor=" + std::to_string(*flavor) +
            " count=" + std::to_string(requested_word_count) + " result=0\n");
        return true;
    }

    const auto& arguments =
        gets_state ? xnu::mig::thread_act::thread_get_state_arguments
                   : xnu::mig::thread_act::thread_set_state_arguments;
    const auto flavor =
        memory_.read32(request.address + arguments[1].request_offset);
    const auto capacity =
        memory_.read32(request.address + arguments[2].request_count_offset);

    std::optional<std::pair<std::uint32_t, std::uint32_t>> owner;
    {
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        const auto object = resolve_name_with_right(*shared_state_,
            process_.pid, request.remote_port, xnu::ipc::Right::Send);
        if (object) {
            owner = find_thread_owner(*shared_state_, *object);
        }
    }

    if (sets_state) {
        darwin::arm_thread::GeneralState state { };
        bool readable =
            flavor && capacity && owner &&
            *flavor == darwin::arm_thread::general_state_flavor &&
            *capacity >= darwin::arm_thread::general_state_word_count;
        for (std::size_t index = 0; readable && index < state.size(); ++index) {
            const auto value = memory_.read32(
                request.address + arguments[2].request_offset +
                static_cast<std::uint32_t>(index * sizeof(std::uint32_t)));
            if (!value) {
                readable = false;
            } else {
                state[index] = *value;
            }
        }
        const auto updated =
            readable && thread_state_update_handler_ &&
            thread_state_update_handler_(owner->first, owner->second, state);
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
                updated ? mach_message_success : kernel_invalid_argument,
            };
        registers[0] = write_words(memory_, request.address, reply)
                           ? mach_message_success
                           : mach_receive_invalid_data;
        if (updated) {
            output_.write("[mach] thread_set_state caller=" +
                          std::to_string(process_.pid) +
                          " target=" + std::to_string(owner->first) + ":" +
                          std::to_string(owner->second) +
                          " flavor=" + std::to_string(*flavor) + "\n");
        }
        return true;
    }

    std::optional<darwin::arm_thread::GeneralState> state;
    if (flavor && capacity && owner &&
        *flavor == darwin::arm_thread::general_state_flavor &&
        *capacity >= darwin::arm_thread::general_state_word_count) {
        if (thread_state_query_) {
            state = thread_state_query_(owner->first, owner->second, *flavor);
        } else if (owner->first == process_.pid &&
                   owner->second == cpu.processor_id()) {
            darwin::arm_thread::GeneralState current { };
            std::copy(cpu.registers().begin(), cpu.registers().end(),
                current.begin());
            current[darwin::arm_thread::cpsr_index] = cpu.cpsr();
            state = current;
        }
    }

    if (!state) {
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
        return true;
    }

    constexpr auto reply_size =
        state_reply_prefix_size +
        darwin::arm_thread::general_state_word_count * sizeof(std::uint32_t);
    if (registers[3] < reply_size) {
        registers[0] = mach_receive_invalid_data;
        return true;
    }

    const std::array<std::uint32_t,
        state_reply_prefix_size / sizeof(std::uint32_t)>
        prefix {
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
            static_cast<std::uint32_t>(
                darwin::arm_thread::general_state_word_count),
        };
    bool written = write_words(memory_, request.address, prefix);
    for (std::size_t index = 0; written && index < state->size(); ++index) {
        written = memory_.write32(
            request.address + state_reply_prefix_size +
                static_cast<std::uint32_t>(index * sizeof(std::uint32_t)),
            (*state)[index]);
    }
    registers[0] = written ? mach_message_success : mach_receive_invalid_data;
    output_.write(
        "[mach] thread_get_state caller=" + std::to_string(process_.pid) +
        " target=" + std::to_string(owner->first) + ":" +
        std::to_string(owner->second) + " flavor=" + std::to_string(*flavor) +
        "\n");
    return true;
}

} // namespace shade
