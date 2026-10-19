// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Dispatch guest Mach right insertion, extraction and release
// operations.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/mach_port.defs

#include "mach/bootstrap_mig_ids.hpp"
#include "kernel/darwin_abi.hpp"
#include "kernel/darwin_kqueue_abi.hpp"
#include "network/darwin_network_abi.hpp"
#include "kernel/darwin_resource_abi.hpp"
#include "network/darwin_route_socket.hpp"
#include "kernel/kernel.hpp"
#include "kernel/kernel_clock.hpp"
#include "kernel/kernel_iokit.hpp"
#include "kernel/kernel_mach_ipc.hpp"
#include "kernel/kernel_network.hpp"
#include "kernel/mach_clock_abi.hpp"
#include "mach/mach_host_mig_ids.hpp"
#include "mach/mach_port_mig_ids.hpp"
#include "kernel/mach_scheduler_abi.hpp"
#include "kernel/mach_thread_policy_abi.hpp"
#include "mach/mig_wire_abi.hpp"
#include "mach/task_mig_ids.hpp"
#include "mach/thread_act_mig_ids.hpp"
#include "mach/vm_map_mig_ids.hpp"
#include "mach/xnu_mig_adapter.hpp"

#include <algorithm>
#include <array>
#include <bit>
#include <cstddef>
#include <cstdint>
#include <fstream>
#include <iterator>
#include <limits>
#include <span>
#include <string_view>
#include <utility>
#include <vector>

#include "support.hpp"

namespace shade {

using namespace mach_support;

bool CompatibilityKernel::dispatch_mach_rights_message(
    Cpu& cpu, const MachMessageRequest& request)
{
    auto& registers = cpu.registers();
    const auto message_address = request.address;
    const std::optional<std::uint32_t> bits { request.bits };
    const std::optional<std::uint32_t> remote_port { request.remote_port };
    const std::optional<std::uint32_t> local_port { request.local_port };
    const std::optional<std::uint32_t> message_id { request.identifier };
    if (*message_id ==
        mig_message_id(
            xnu::mig::mach_port::Routine::mach_port_extract_right)) {
        constexpr std::uint32_t request_size = 40;
        constexpr std::uint32_t simple_reply_size = 36;
        constexpr std::uint32_t complex_reply_size = 40;
        auto write_reply = [&](std::span<const std::uint32_t> reply) {
            for (std::size_t index = 0; index < reply.size(); ++index) {
                if (!memory_.write32(
                        message_address + static_cast<std::uint32_t>(
                                              index * sizeof(std::uint32_t)),
                        reply[index])) {
                    registers[0] = 0x10004008U; // MACH_RCV_INVALID_DATA
                    return false;
                }
            }
            registers[0] = darwin::mach::success;
            return true;
        };

        if (registers[3] < simple_reply_size) {
            registers[0] = 0x10004008U; // MACH_RCV_INVALID_DATA
            return true;
        }

        const auto& arguments =
            xnu::mig::mach_port::mach_port_extract_right_arguments;
        const auto name =
            memory_.read32(message_address + arguments[1].request_offset);
        const auto disposition =
            memory_.read32(message_address + arguments[2].request_offset);
        std::uint32_t result = darwin::mach::success;
        std::uint32_t extracted_name = xnu::ipc::null_name;
        std::uint32_t acquired_disposition = 0;
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            const auto task = target_task_for_port(
                *shared_state_, process_.pid, *remote_port);
            const auto source_right =
                disposition ? source_right_for_disposition(*disposition)
                            : std::nullopt;
            const auto extracted_right =
                disposition ? right_for_disposition(*disposition)
                            : std::nullopt;
            const auto entry =
                task && name
                    ? shared_state_->mach_namespaces.lookup(*task, *name)
                    : std::nullopt;
            if (registers[2] < request_size || !name || !disposition) {
                result = darwin::mach::invalid_argument;
            } else if (!task) {
                result = darwin::mach::invalid_task;
            } else if (!source_right || !extracted_right) {
                result = darwin::mach::invalid_value;
            } else if (*name == xnu::ipc::null_name ||
                       *name == xnu::ipc::dead_name) {
                result = darwin::mach::invalid_right;
            } else if (!entry) {
                result = darwin::mach::invalid_name;
            } else if ((entry->type & xnu::ipc::type_mask(*source_right)) ==
                       0) {
                result = darwin::mach::invalid_right;
            } else if (registers[3] < complex_reply_size) {
                result = darwin::mach::resource_shortage;
            } else {
                const auto moved =
                    *disposition ==
                        darwin::mig_wire::disposition_move_receive ||
                    *disposition == darwin::mig_wire::disposition_move_send ||
                    *disposition ==
                        darwin::mig_wire::disposition_move_send_once;
                auto consumed = true;
                if (moved) {
                    consumed = consume_moved_right_locked(
                        *shared_state_, *task, *name, *source_right, true);
                }
                if (!consumed) {
                    result = darwin::mach::invalid_right;
                } else {
                    const auto copied_out =
                        shared_state_->mach_namespaces.copyout(process_.pid,
                            entry->object,
                            xnu::ipc::type_mask(*extracted_right));
                    if (!copied_out) {
                        result = darwin::mach::resource_shortage;
                        if (moved) {
                            static_cast<void>(
                                shared_state_->mach_namespaces.install(*task,
                                    *name, entry->object,
                                    xnu::ipc::type_mask(*source_right)));
                            if (*source_right == xnu::ipc::Right::Receive) {
                                static_cast<void>(shared_state_
                                        ->mach_port_objects.set_receive_owner(
                                            entry->object, *task));
                            }
                        }
                    } else {
                        extracted_name = *copied_out;
                        acquired_disposition =
                            darwin::mig_wire::received_port_disposition(
                                *disposition);
                        if (*extracted_right == xnu::ipc::Right::Receive) {
                            static_cast<void>(shared_state_->mach_port_objects
                                    .set_receive_owner(
                                        entry->object, process_.pid));
                        }
                        if (*disposition ==
                            darwin::mig_wire::disposition_make_send) {
                            static_cast<void>(shared_state_->mach_port_objects
                                    .increment_make_send_count(entry->object));
                        }
                    }
                }
            }
        }

        if (result != darwin::mach::success) {
            const std::array<std::uint32_t,
                simple_reply_size / sizeof(std::uint32_t)>
                reply {
                    darwin::mig_wire::message_bits(
                        darwin::mig_wire::disposition_move_send_once),
                    simple_reply_size,
                    *local_port,
                    0,
                    0,
                    *message_id + 100,
                    0,
                    1,
                    result,
                };
            static_cast<void>(write_reply(reply));
            return true;
        }

        const std::array<std::uint32_t,
            complex_reply_size / sizeof(std::uint32_t)>
            reply {
                darwin::mig_wire::message_bits(
                    darwin::mig_wire::disposition_move_send_once, 0, true),
                complex_reply_size,
                *local_port,
                0,
                0,
                *message_id + 100,
                1,
                extracted_name,
                0,
                darwin::mig_wire::port_descriptor_metadata(
                    acquired_disposition),
            };
        static_cast<void>(write_reply(reply));
        return true;
    }
    if ((*message_id ==
                mig_message_id(
                    xnu::mig::mach_port::Routine::mach_port_deallocate) ||
            *message_id ==
                mig_message_id(
                    xnu::mig::mach_port::Routine::mach_port_insert_right) ||
            *message_id ==
                mig_message_id(
                    xnu::mig::task::Routine::task_set_special_port) ||
            *message_id ==
                mig_message_id(xnu::mig::task::Routine::semaphore_destroy) ||
            *message_id ==
                mig_message_id(
                    xnu::mig::thread_act::Routine::thread_policy)) &&
        registers[3] >= 36) {
        // mach_port_deallocate / mach_port_insert_right / semaphore_destroy /
        // thread_policy
        std::uint32_t kernel_result = 0;
        if (*message_id ==
            mig_message_id(
                xnu::mig::mach_port::Routine::mach_port_deallocate)) {
            const auto name = memory_
                                  .read32(message_address +
                                          xnu::mig::mach_port::
                                              mach_port_deallocate_arguments[1]
                                                  .request_offset)
                                  .value_or(0);
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            const auto task = target_task_for_port(
                *shared_state_, process_.pid, *remote_port);
            if (!task) {
                kernel_result = 4; // KERN_INVALID_ARGUMENT
            } else if (name == xnu::ipc::null_name ||
                       name == xnu::ipc::dead_name) {
                kernel_result = 0;
            } else {
                const auto entry =
                    shared_state_->mach_namespaces.lookup(*task, name);
                if (!entry) {
                    kernel_result = 15; // KERN_INVALID_NAME
                } else {
                    const auto has = [&](xnu::ipc::Right right) {
                        return (entry->type & xnu::ipc::type_mask(right)) !=
                               0;
                    };
                    const auto right = has(xnu::ipc::Right::Send)
                                           ? xnu::ipc::Right::Send
                                       : has(xnu::ipc::Right::SendOnce)
                                           ? xnu::ipc::Right::SendOnce
                                       : has(xnu::ipc::Right::DeadName)
                                           ? xnu::ipc::Right::DeadName
                                           : xnu::ipc::Right::Receive;
                    if (right == xnu::ipc::Right::Receive) {
                        kernel_result = 17;
                    } else {
                        kernel_result = modify_port_references_locked(
                            *shared_state_, *task, name, right, -1);
                    }
                }
                if (kernel_result == 18 || kernel_result == 19) {
                    // ipc_right_dealloc reports a wrong kind of right for
                    // this interface, not a delta-validation error.
                    kernel_result = 17; // KERN_INVALID_RIGHT
                }
            }
        } else if (*message_id ==
                   mig_message_id(
                       xnu::mig::task::Routine::semaphore_destroy)) {
            constexpr std::uint32_t semaphore_destroy_request_size =
                darwin::mig_wire::complex_descriptor_base +
                darwin::mig_wire::descriptor_size;
            const auto descriptor_count = memory_.read32(
                message_address +
                darwin::mig_wire::complex_descriptor_count_offset);
            const auto semaphore_name =
                memory_.read32(message_address +
                               xnu::mig::task::semaphore_destroy_arguments[1]
                                   .request_offset);
            const auto descriptor_word =
                memory_.read32(message_address +
                               darwin::mig_wire::descriptor_metadata_offset(0));
            const auto disposition =
                descriptor_word
                    ? (*descriptor_word >>
                          darwin::mig_wire::descriptor_disposition_shift) &
                          0xffU
                    : 0U;
            const auto descriptor_type =
                descriptor_word ? *descriptor_word >>
                                      darwin::mig_wire::descriptor_type_shift
                                : std::numeric_limits<std::uint32_t>::max();
            const auto valid_wire =
                registers[2] == semaphore_destroy_request_size &&
                (*bits & darwin::mig_wire::message_complex_bit) != 0 &&
                descriptor_count == 1 && semaphore_name && descriptor_word &&
                disposition == darwin::mig_wire::disposition_move_send &&
                descriptor_type == darwin::mig_wire::port_descriptor_type;
            if (!valid_wire) {
                kernel_result = darwin::mach::invalid_argument;
            } else {
                std::lock_guard mach_lock { shared_state_->mach_mutex };
                const auto target = target_task_for_port(
                    *shared_state_, process_.pid, *remote_port);
                const auto semaphore_object =
                    resolve_name_with_right(*shared_state_, process_.pid,
                        *semaphore_name, xnu::ipc::Right::Send);
                const auto semaphore =
                    semaphore_object
                        ? shared_state_->mach_semaphores.find(*semaphore_object)
                        : shared_state_->mach_semaphores.end();

                // semaphore_consume_ref_t is a MOVE_SEND descriptor. Its send
                // right is consumed by message transport even when the kernel
                // operation fails; this direct kernel-server path performs that
                // transport step here.
                if (semaphore_object) {
                    static_cast<void>(
                        consume_moved_right_locked(*shared_state_, process_.pid,
                            *semaphore_name, xnu::ipc::Right::Send, false));
                }
                if (!target ||
                    semaphore == shared_state_->mach_semaphores.end() ||
                    semaphore->second.owner_pid != *target) {
                    kernel_result = darwin::mach::invalid_argument;
                } else {
                    const auto object = *semaphore_object;
                    for (const auto& waiter : semaphore->second.waiters) {
                        shared_state_->semaphore_terminations.insert(waiter);
                    }
                    output_.write(
                        "[semaphore] destroy pid=" +
                        std::to_string(process_.pid) +
                        " port=" + std::to_string(object) + " waiters=" +
                        std::to_string(semaphore->second.waiters.size()) +
                        "\n");
                    terminate_receive_object_locked(*shared_state_, object);
                }
            }
        } else if (*message_id == mig_message_id(xnu::mig::mach_port::
                                          Routine::mach_port_insert_right)) {
            if (registers[2] < 52) {
                kernel_result = 4;
            } else {
                const auto& insert_arguments =
                    xnu::mig::mach_port::mach_port_insert_right_arguments;
                const auto poly_name =
                    memory_
                        .read32(message_address +
                                insert_arguments[2].request_offset)
                        .value_or(0);
                const auto descriptor_word =
                    memory_
                        .read32(message_address +
                                insert_arguments[2].request_offset +
                                2U * sizeof(std::uint32_t))
                        .value_or(0);
                const auto target_name =
                    memory_
                        .read32(message_address +
                                insert_arguments[1].request_offset)
                        .value_or(0);
                const auto disposition =
                    (descriptor_word >>
                        darwin::mig_wire::descriptor_disposition_shift) &
                    0xffU;
                std::lock_guard mach_lock { shared_state_->mach_mutex };
                const auto task = target_task_for_port(
                    *shared_state_, process_.pid, *remote_port);
                if (!task) {
                    kernel_result = darwin::mach::invalid_task;
                } else {
                    kernel_result = insert_port_right_locked(*shared_state_,
                        process_.pid, *task, target_name, poly_name,
                        disposition);
                }
            }
        } else if (*message_id ==
                   mig_message_id(
                       xnu::mig::thread_act::Routine::thread_policy)) {
            using namespace darwin::mach::thread_policy;
            bool applied = false;
            if (registers[3] >= legacy_minimum_request_size) {
                const auto policy = memory_.read32(
                    message_address + legacy_request_policy_offset);
                const auto count = memory_.read32(
                    message_address + legacy_request_count_offset);
                const auto base = memory_.read32(
                    message_address + legacy_request_base_offset);
                const auto set_limit = memory_.read32(
                    message_address + legacy_request_set_limit_offset);
                std::optional<std::size_t> target_thread;
                for (const auto& [processor, port] : thread_ports_) {
                    if (port == *remote_port) {
                        target_thread = processor;
                        break;
                    }
                }
                if (policy && count && *count == legacy_policy_word_count &&
                    base && set_limit && target_thread &&
                    legacy_thread_policy_handler_) {
                    applied = legacy_thread_policy_handler_(*target_thread,
                        *policy, std::bit_cast<std::int32_t>(*base),
                        *set_limit != 0);
                }
            }
            if (!applied) {
                kernel_result = darwin::mach::invalid_argument;
            } else if (scheduler_preemption_query_ &&
                       scheduler_preemption_query_(cpu.processor_id())) {
                // Legacy thread_policy can change a runnable candidate's
                // priority or realtime deadline. Check the complete scheduler
                // ordering before the current HLE dispatch returns to guest
                // code.
                cpu.request_guest_preemption();
            }
        } else if (*message_id ==
                   mig_message_id(
                       xnu::mig::task::Routine::task_set_special_port)) {
            // task_set_special_port operates on the task named by the
            // destination port, which is commonly a newly forked child,
            // not on launchd's own task.
            const auto& special_arguments =
                xnu::mig::task::task_set_special_port_arguments;
            const auto which = memory_
                                   .read32(message_address +
                                           special_arguments[1].request_offset)
                                   .value_or(0);
            const auto port_name =
                memory_
                    .read32(
                        message_address + special_arguments[2].request_offset)
                    .value_or(0);
            const auto descriptor_word =
                memory_
                    .read32(message_address +
                            special_arguments[2].request_offset +
                            2U * sizeof(std::uint32_t))
                    .value_or(0);
            const auto disposition =
                (descriptor_word >>
                    darwin::mig_wire::descriptor_disposition_shift) &
                0xffU;
            const auto transferred_right = right_for_disposition(disposition);
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            const auto task_object = resolve_name_with_right(*shared_state_,
                process_.pid, *remote_port, xnu::ipc::Right::Send);
            const auto target = target_task_for_port(
                *shared_state_, process_.pid, *remote_port);
            const auto port =
                port_name == xnu::ipc::null_name
                    ? std::optional<std::uint32_t> { 0 }
                : transferred_right
                    ? resolve_name_with_right(*shared_state_, process_.pid,
                          port_name, *transferred_right)
                    : std::nullopt;
            if (!task_object || !target) {
                kernel_result = 4; // KERN_INVALID_ARGUMENT
            } else if (!port || (port_name != xnu::ipc::null_name &&
                                    (!transferred_right ||
                                        *transferred_right !=
                                            xnu::ipc::Right::Send))) {
                kernel_result = 20; // KERN_INVALID_CAPABILITY
            } else {
                const auto previous =
                    shared_state_->task_special_ports.find(*task_object);
                const auto previous_port =
                    previous == shared_state_->task_special_ports.end()
                        ? std::optional<std::uint32_t> { }
                        : [&]() -> std::optional<std::uint32_t> {
                    const auto slot = previous->second.find(which);
                    return slot == previous->second.end()
                               ? std::optional<std::uint32_t> { }
                               : std::optional { slot->second };
                }();
                bool consumed = true;
                if (disposition == 17U || disposition == 18U) {
                    consumed = consume_moved_right_locked(*shared_state_,
                        process_.pid, port_name, *transferred_right, true);
                }
                if (!consumed) {
                    kernel_result = 17; // KERN_INVALID_RIGHT
                } else {
                    if (*port != 0U &&
                        (!previous_port || *previous_port != *port)) {
                        // task_set_special_port takes a kernel-owned Send
                        // reference. For MOVE_SEND the guest reference was
                        // consumed above; for COPY_SEND it remains in the
                        // caller's ipc_space.
                        retain_kernel_send_right_locked(*shared_state_, *port);
                    }
                    if (*port == 0U) {
                        if (previous !=
                            shared_state_->task_special_ports.end()) {
                            previous->second.erase(which);
                            if (previous->second.empty())
                                shared_state_->task_special_ports.erase(
                                    previous);
                        }
                    } else {
                        shared_state_->task_special_ports[*task_object][which] =
                            *port;
                    }
                    if (previous_port && *previous_port != *port) {
                        release_kernel_send_right_locked(
                            *shared_state_, *previous_port);
                    }
                }
            }
            const auto owner =
                task_object
                    ? shared_state_->mach_port_objects.lookup(*task_object)
                    : std::nullopt;
            output_.write(
                "[mach] task_set_special_port caller=" +
                std::to_string(process_.pid) +
                " task=" + std::to_string(task_object.value_or(0)) +
                " owner=" + std::to_string(owner ? owner->receive_owner : 0U) +
                " which=" + std::to_string(which) +
                " port=" + std::to_string(port.value_or(0)) + "\n");
            const auto own_task_object = shared_state_->mach_namespaces.resolve(
                process_.pid, process_.task_port);
            if (kernel_result == 0 && task_object == own_task_object &&
                which == 4) {
                const auto still_local =
                    port && *port != 0
                        ? resolve_name_with_right(*shared_state_, process_.pid,
                              port_name, xnu::ipc::Right::Send)
                        : std::optional<std::uint32_t> { };
                process_.bootstrap_port = still_local && *still_local == *port
                                              ? port_name
                                              : xnu::ipc::null_name;
            }
        }
        const std::array<std::uint32_t, 9> reply {
            18,
            36,
            *local_port,
            0,
            0,
            *message_id + 100,
            0x00000000U,
            0x00000001U,
            kernel_result,
        };
        for (std::size_t index = 0; index < reply.size(); ++index) {
            if (!memory_.write32(
                    message_address + static_cast<std::uint32_t>(index * 4U),
                    reply[index])) {
                registers[0] = 0x10004008U;
                return true;
            }
        }
        registers[0] = 0;
        return true;
    }
    if ((*message_id ==
                mig_message_id(
                    xnu::mig::mach_host::Routine::host_get_io_master) ||
            *message_id ==
                mig_message_id(
                    xnu::mig::mach_host::Routine::host_get_clock_service) ||
            *message_id ==
                mig_message_id(
                    xnu::mig::task::Routine::task_get_special_port) ||
            *message_id ==
                mig_message_id(xnu::mig::task::Routine::semaphore_create)) &&
        registers[3] >= 40) {
        // host_get_io_master, host_get_clock_service,
        // task_get_special_port, and semaphore_create return a port.
        const auto which =
            *message_id ==
                    mig_message_id(
                        xnu::mig::task::Routine::task_get_special_port)
                ? memory_.read32(
                      message_address +
                      xnu::mig::task::task_get_special_port_arguments[1]
                          .request_offset)
                : std::optional<std::uint32_t> { };
        const auto clock_id =
            *message_id ==
                    mig_message_id(
                        xnu::mig::mach_host::Routine::host_get_clock_service)
                ? memory_.read32(
                      message_address + xnu::mig::mach_host::
                                            host_get_clock_service_arguments[1]
                                                .request_offset)
                : std::optional<std::uint32_t> { };
        std::uint32_t port = 0;
        bool port_already_copied_out = false;
        bool update_process_bootstrap = false;
        if (*message_id ==
            mig_message_id(
                xnu::mig::mach_host::Routine::host_get_io_master)) {
            port = process_.io_master_port;
        } else if (*message_id == mig_message_id(xnu::mig::mach_host::
                                          Routine::host_get_clock_service)) {
            if (clock_id == darwin::mach::clock::system_clock_id) {
                port = process_.clock_port;
            } else if (clock_id == darwin::mach::clock::calendar_clock_id) {
                port = process_.calendar_clock_port;
            }
        } else if (*message_id ==
                   mig_message_id(
                       xnu::mig::task::Routine::semaphore_create)) {
            const auto policy =
                memory_
                    .read32(message_address +
                            xnu::mig::task::semaphore_create_arguments[2]
                                .request_offset)
                    .value_or(8);
            const auto initial_value = static_cast<std::int32_t>(memory_
                    .read32(message_address +
                            xnu::mig::task::semaphore_create_arguments[3]
                                .request_offset)
                    .value_or(0xffffffffU));
            if (policy <= 7 && initial_value >= 0) {
                std::lock_guard mach_lock { shared_state_->mach_mutex };
                // semaphore_create(task, ...) charges the semaphore to the
                // named task, not necessarily to the caller. Keep the owner
                // identity in sync with XNU so task teardown can terminate
                // exactly its objects.
                const auto owner = target_task_for_port(
                    *shared_state_, process_.pid, *remote_port);
                if (owner) {
                    const auto object = shared_state_->allocate_mach_object();
                    shared_state_->mach_semaphores.emplace(
                        object, KernelSharedState::MachSemaphore {
                                    initial_value, *owner, { } });
                    if (shared_state_->mach_port_objects.create(object)) {
                        const auto name =
                            shared_state_->mach_namespaces.copyout(process_.pid,
                                object,
                                xnu::ipc::type_mask(
                                    xnu::ipc::Right::Send));
                        if (name) {
                            port = *name;
                            port_already_copied_out = true;
                            output_.write("[semaphore] create pid=" +
                                          std::to_string(process_.pid) +
                                          " owner=" + std::to_string(*owner) +
                                          " object=" + std::to_string(object) +
                                          " name=" + std::to_string(port) +
                                          " value=" +
                                          std::to_string(initial_value) + "\n");
                        } else {
                            shared_state_->mach_semaphores.erase(object);
                            remove_port_object_locked(*shared_state_, object);
                        }
                    } else {
                        shared_state_->mach_semaphores.erase(object);
                    }
                }
            }
        } else if (which) {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            const auto resolved_task_object =
                resolve_name_with_right(*shared_state_, process_.pid,
                    *remote_port, xnu::ipc::Right::Send);
            const auto task_object =
                resolved_task_object && target_task_for_port(*shared_state_,
                                            process_.pid, *remote_port)
                    ? *resolved_task_object
                    : 0U;
            const auto own_task_object = shared_state_->mach_namespaces.resolve(
                process_.pid, process_.task_port);
            update_process_bootstrap = *which == 4 && task_object != 0U &&
                                       own_task_object &&
                                       task_object == *own_task_object;
            if (const auto task =
                    task_object != 0U
                        ? shared_state_->task_special_ports.find(task_object)
                        : shared_state_->task_special_ports.end();
                task != shared_state_->task_special_ports.end()) {
                if (const auto special = task->second.find(*which);
                    special != task->second.end()) {
                    if (shared_state_->mach_port_objects.contains(
                            special->second)) {
                        port = special->second;
                    } else {
                        // A task may have exited after installing a raw
                        // special-port metadata entry. Never copy out a
                        // capability for that dead object; remove the stale
                        // slot while the Mach lock is held.
                        task->second.erase(special);
                        if (task->second.empty())
                            shared_state_->task_special_ports.erase(task);
                    }
                }
            }
            if (*which == 4) {
                output_.write("[mach] task_get_special_port pid=" +
                              std::to_string(process_.pid) +
                              " task=" + std::to_string(task_object) +
                              " port=" + std::to_string(port) + "\n");
            }
        }
        if (port != 0 && !port_already_copied_out) {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            port = shared_state_->mach_namespaces
                       .copyout(process_.pid, port,
                           xnu::ipc::type_mask(xnu::ipc::Right::Send))
                       .value_or(0);
        }
        if (update_process_bootstrap && port != 0) {
            process_.bootstrap_port = port;
        }
        const std::array<std::uint32_t, 10> reply {
            0x80000012U, // complex + MOVE_SEND_ONCE
            40,
            *local_port,
            0,
            0,
            *message_id + 100,
            1, // one descriptor
            port, // port descriptor name
            0,
            0x00110000U, // MOVE_SEND disposition, port descriptor
        };
        for (std::size_t index = 0; index < reply.size(); ++index) {
            if (!memory_.write32(
                    message_address + static_cast<std::uint32_t>(index * 4U),
                    reply[index])) {
                registers[0] = 0x10004008U;
                return true;
            }
        }
        registers[0] = 0;
        return true;
    }
    return false;
}

} // namespace shade
