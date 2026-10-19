// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Manage guest task exception-port masks, behaviors and replies.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/task.defs

#include "kernel/kernel.hpp"

#include "mach/mig_wire_abi.hpp"
#include "mach/task_mig_ids.hpp"

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <mutex>
#include <optional>
#include <span>
#include <sstream>
#include <string>
#include <vector>

#include "../support.hpp"

namespace shade {
namespace {

    using namespace mach_support;

    constexpr std::uint32_t mach_message_success = 0;
    constexpr std::uint32_t mach_receive_invalid_data = 0x10004008U;
    constexpr std::uint32_t kernel_resource_shortage = 3;
    constexpr std::uint32_t kernel_invalid_argument = 4;
    constexpr std::uint32_t kernel_invalid_right = 17;
    constexpr std::uint32_t kernel_invalid_capability = 20;
    constexpr std::uint32_t simple_reply_size = 36;
    constexpr std::uint32_t task_get_request_size = 36;
    constexpr std::uint32_t task_set_request_size = 60;
    constexpr std::size_t maximum_exception_handlers = 32;
    // Darwin 9 MIG reserves the complete array of 32 port descriptors before
    // NDR/masksCnt, then compacts only the three scalar arrays to masksCnt.
    constexpr std::uint32_t exception_reply_array_base_size =
        darwin::mig_wire::complex_descriptor_base +
        static_cast<std::uint32_t>(maximum_exception_handlers) *
            darwin::mig_wire::descriptor_size +
        darwin::mig_wire::ndr_record_size + sizeof(std::uint32_t);
    constexpr std::uint32_t exception_reply_entry_size =
        3U * sizeof(std::uint32_t);
    constexpr std::size_t first_exception_type = 1;
    constexpr std::uint32_t mach_exception_codes = 0x80000000U;
    constexpr std::uint32_t valid_exception_mask =
        (1U << KernelSharedState::task_exception_type_count) - 2U;

    static_assert(exception_reply_array_base_size == 424);
    static_assert(exception_reply_array_base_size +
                      maximum_exception_handlers * exception_reply_entry_size ==
                  808);

    struct ExceptionGroup {
        std::uint32_t mask { };
        KernelSharedState::TaskExceptionAction action;
    };

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

    std::uint32_t write_simple_reply(AddressSpace& memory,
        std::uint32_t address, std::uint32_t local_port,
        std::uint32_t message_id, std::uint32_t kernel_result)
    {
        const std::array<std::uint32_t,
            simple_reply_size / sizeof(std::uint32_t)>
            reply {
                darwin::mig_wire::message_bits(
                    darwin::mig_wire::disposition_move_send_once),
                simple_reply_size,
                local_port,
                0,
                0,
                message_id + 100,
                0,
                1,
                kernel_result,
            };
        return write_words(memory, address, reply) ? mach_message_success
                                                   : mach_receive_invalid_data;
    }

    std::string hexadecimal(std::uint32_t value)
    {
        std::ostringstream stream;
        stream << std::hex << value;
        return stream.str();
    }

    std::optional<std::uint32_t> task_object_for_name_locked(
        const KernelSharedState& state, std::uint32_t caller,
        std::uint32_t name)
    {
        const auto object = resolve_name_with_right(
            state, caller, name, xnu::ipc::Right::Send);
        if (!object || !state.task_port_pids.contains(*object))
            return std::nullopt;
        return object;
    }

    std::vector<ExceptionGroup> group_exception_actions(
        const KernelSharedState::TaskExceptionActions& actions,
        std::uint32_t mask)
    {
        std::vector<ExceptionGroup> groups;
        for (std::size_t type = first_exception_type;
            type < KernelSharedState::task_exception_type_count; ++type) {
            const auto type_mask = 1U << type;
            if ((mask & type_mask) == 0)
                continue;
            const auto existing = std::find_if(
                groups.begin(), groups.end(), [&](const auto& group) {
                    return group.action == actions[type];
                });
            if (existing == groups.end()) {
                groups.push_back(ExceptionGroup { type_mask, actions[type] });
            } else {
                existing->mask |= type_mask;
            }
        }
        return groups;
    }

} // namespace

bool CompatibilityKernel::dispatch_mach_task_exception_message(
    Cpu& cpu, const MachMessageRequest& request)
{
    const auto set_id =
        mig_message_id(xnu::mig::task::Routine::task_set_exception_ports);
    const auto get_id =
        mig_message_id(xnu::mig::task::Routine::task_get_exception_ports);
    if (request.identifier != set_id && request.identifier != get_id)
        return false;

    auto& registers = cpu.registers();
    if (registers[3] < simple_reply_size) {
        registers[0] = mach_receive_invalid_data;
        return true;
    }

    if (request.identifier == set_id) {
        const auto& arguments =
            xnu::mig::task::task_set_exception_ports_arguments;
        const auto descriptor_count =
            memory_.read32(request.address +
                           darwin::mig_wire::complex_descriptor_count_offset);
        const auto port_name =
            memory_.read32(request.address + arguments[2].request_offset);
        const auto descriptor =
            memory_.read32(request.address + arguments[2].request_offset +
                           2U * sizeof(std::uint32_t));
        const auto exception_mask =
            memory_.read32(request.address + arguments[1].request_offset);
        const auto behavior =
            memory_.read32(request.address + arguments[3].request_offset);
        const auto flavor =
            memory_.read32(request.address + arguments[4].request_offset);
        const auto descriptor_type =
            descriptor ? *descriptor >> darwin::mig_wire::descriptor_type_shift
                       : std::numeric_limits<std::uint32_t>::max();
        const auto disposition =
            descriptor ? (*descriptor >>
                             darwin::mig_wire::descriptor_disposition_shift) &
                             0xffU
                       : 0U;
        const auto received_right = right_for_disposition(disposition);
        const auto source_right = source_right_for_disposition(disposition);
        std::uint32_t result = mach_message_success;
        std::uint32_t task_object = 0;
        std::uint32_t port_object = 0;
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            const auto task = task_object_for_name_locked(
                *shared_state_, process_.pid, request.remote_port);
            task_object = task.value_or(0);
            const auto port =
                port_name && *port_name == xnu::ipc::null_name
                    ? std::optional<std::uint32_t> { xnu::ipc::null_name }
                : port_name && source_right
                    ? resolve_name_with_right(*shared_state_, process_.pid,
                          *port_name, *source_right)
                    : std::nullopt;
            port_object = port.value_or(0);
            const auto valid_wire =
                registers[2] >= task_set_request_size &&
                (request.bits & darwin::mig_wire::message_complex_bit) != 0 &&
                descriptor_count && *descriptor_count == 1 && descriptor &&
                descriptor_type == darwin::mig_wire::port_descriptor_type;
            const auto valid_behavior =
                port_object == xnu::ipc::null_name ||
                (behavior && (*behavior & ~mach_exception_codes) >= 1U &&
                    (*behavior & ~mach_exception_codes) <= 3U);
            const auto valid_port_right =
                port_object == xnu::ipc::null_name ||
                (received_right && source_right &&
                    *received_right == xnu::ipc::Right::Send);
            if (!valid_wire || !exception_mask || !behavior || !flavor ||
                !task || (*exception_mask & ~valid_exception_mask) != 0) {
                result = kernel_invalid_argument;
            } else if (!port || !valid_port_right) {
                result = kernel_invalid_capability;
            } else if (!valid_behavior) {
                result = kernel_invalid_argument;
            } else if (disposition == darwin::mig_wire::disposition_move_send &&
                       *port_name != xnu::ipc::null_name &&
                       !consume_moved_right_locked(*shared_state_, process_.pid,
                           *port_name, xnu::ipc::Right::Send, true)) {
                result = kernel_invalid_right;
            } else {
                auto& actions = shared_state_->task_exception_actions[*task];
                for (std::size_t type = first_exception_type;
                    type < KernelSharedState::task_exception_type_count;
                    ++type) {
                    if ((*exception_mask & (1U << type)) == 0)
                        continue;
                    auto& action = actions[type];
                    if (action.port_object != port_object) {
                        retain_kernel_send_right_locked(
                            *shared_state_, port_object);
                        const auto previous_port = action.port_object;
                        action.port_object = port_object;
                        release_kernel_send_right_locked(
                            *shared_state_, previous_port);
                    }
                    action.behavior = *behavior;
                    action.flavor = *flavor;
                }
                if (disposition == darwin::mig_wire::disposition_make_send &&
                    port_object != xnu::ipc::null_name) {
                    static_cast<void>(shared_state_->mach_port_objects
                            .increment_make_send_count(port_object));
                }
            }
        }
        registers[0] = write_simple_reply(memory_, request.address,
            request.local_port, request.identifier, result);
        output_.write("[mach] task_set_exception_ports caller=" +
                      std::to_string(process_.pid) +
                      " task=" + std::to_string(task_object) + " mask=0x" +
                      hexadecimal(exception_mask.value_or(0)) +
                      " port=" + std::to_string(port_object) +
                      " behavior=" + std::to_string(behavior.value_or(0)) +
                      " flavor=" + std::to_string(flavor.value_or(0)) +
                      " result=" + std::to_string(result) + "\n");
        return true;
    }

    const auto& arguments =
        xnu::mig::task::task_get_exception_ports_arguments;
    const auto exception_mask =
        memory_.read32(request.address + arguments[1].request_offset);
    std::uint32_t task_object = 0;
    std::uint32_t result = mach_message_success;
    std::vector<ExceptionGroup> groups;
    std::vector<std::uint32_t> handler_names;
    {
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        const auto task = task_object_for_name_locked(
            *shared_state_, process_.pid, request.remote_port);
        task_object = task.value_or(0);
        if (registers[2] < task_get_request_size || !exception_mask || !task ||
            (*exception_mask & ~valid_exception_mask) != 0) {
            result = kernel_invalid_argument;
        } else {
            const auto actions =
                shared_state_->task_exception_actions.find(*task);
            const KernelSharedState::TaskExceptionActions defaults { };
            groups = group_exception_actions(
                actions == shared_state_->task_exception_actions.end()
                    ? defaults
                    : actions->second,
                *exception_mask);
            const auto reply_size = exception_reply_array_base_size +
                                    static_cast<std::uint32_t>(groups.size()) *
                                        exception_reply_entry_size;
            if (registers[3] < reply_size) {
                registers[0] = mach_receive_invalid_data;
                return true;
            }
            handler_names.reserve(groups.size());
            for (const auto& group : groups) {
                if (group.action.port_object == xnu::ipc::null_name) {
                    handler_names.push_back(xnu::ipc::null_name);
                    continue;
                }
                const auto name = shared_state_->mach_namespaces.copyout(
                    process_.pid, group.action.port_object,
                    xnu::ipc::type_mask(xnu::ipc::Right::Send));
                if (!name) {
                    result = kernel_resource_shortage;
                    handler_names.clear();
                    groups.clear();
                    break;
                }
                handler_names.push_back(*name);
            }
        }
    }
    if (result != mach_message_success) {
        registers[0] = write_simple_reply(memory_, request.address,
            request.local_port, request.identifier, result);
    } else {
        const auto count = static_cast<std::uint32_t>(groups.size());
        const auto reply_size = exception_reply_array_base_size +
                                count * exception_reply_entry_size;
        std::vector<std::uint32_t> reply {
            darwin::mig_wire::message_bits(
                darwin::mig_wire::disposition_move_send_once, 0, true),
            reply_size,
            request.local_port,
            0,
            0,
            request.identifier + 100,
            maximum_exception_handlers,
        };
        for (std::size_t index = 0; index < maximum_exception_handlers;
            ++index) {
            reply.push_back(index < handler_names.size()
                                ? handler_names[index]
                                : xnu::ipc::null_name);
            reply.push_back(0);
            reply.push_back(darwin::mig_wire::port_descriptor_metadata(
                darwin::mig_wire::disposition_move_send));
        }
        reply.push_back(0);
        reply.push_back(1);
        reply.push_back(count);
        for (const auto& group : groups)
            reply.push_back(group.mask);
        for (const auto& group : groups)
            reply.push_back(group.action.behavior);
        for (const auto& group : groups)
            reply.push_back(group.action.flavor);
        registers[0] = write_words(memory_, request.address, reply)
                           ? mach_message_success
                           : mach_receive_invalid_data;
    }
    output_.write("[mach] task_get_exception_ports caller=" +
                  std::to_string(process_.pid) +
                  " task=" + std::to_string(task_object) + " mask=0x" +
                  hexadecimal(exception_mask.value_or(0)) +
                  " count=" + std::to_string(groups.size()) +
                  " result=" + std::to_string(result) + "\n");
    return true;
}

} // namespace shade
