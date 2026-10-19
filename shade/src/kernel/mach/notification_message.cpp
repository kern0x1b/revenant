// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Handle Mach port notification registration and reply metadata.
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

bool CompatibilityKernel::dispatch_mach_notification_message(
    Cpu& cpu, const MachMessageRequest& request)
{
    auto& registers = cpu.registers();
    const auto message_address = request.address;
    const std::optional<std::uint32_t> bits { request.bits };
    const std::optional<std::uint32_t> remote_port { request.remote_port };
    const std::optional<std::uint32_t> local_port { request.local_port };
    const std::optional<std::uint32_t> message_id { request.identifier };
    if (*message_id == mig_message_id(xnu::mig::mach_port::Routine::
                               mach_port_request_notification) &&
        registers[3] >= 40) {
        // mach_port_request_notification(task, name, id, sync, notify).
        // Darwin 8 MIG places the notify descriptor before NDR/scalars.
        std::uint32_t result = 0;
        std::uint32_t previous_name = 0;
        if (registers[2] < 60) {
            result = 4; // KERN_INVALID_ARGUMENT
        } else {
            const auto& notification_arguments = xnu::mig::mach_port::
                mach_port_request_notification_arguments;
            const auto notify_name =
                memory_
                    .read32(message_address +
                            notification_arguments[4].request_offset)
                    .value_or(0);
            const auto descriptor_word =
                memory_
                    .read32(message_address +
                            notification_arguments[4].request_offset +
                            2U * sizeof(std::uint32_t))
                    .value_or(0);
            const auto name =
                memory_
                    .read32(message_address +
                            notification_arguments[1].request_offset)
                    .value_or(0);
            const auto notification =
                memory_
                    .read32(message_address +
                            notification_arguments[2].request_offset)
                    .value_or(0);
            const auto sync =
                memory_
                    .read32(message_address +
                            notification_arguments[3].request_offset)
                    .value_or(0);
            const auto disposition =
                (descriptor_word >>
                    darwin::mig_wire::descriptor_disposition_shift) &
                0xffU;
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            const auto target = target_task_for_port(
                *shared_state_, process_.pid, *remote_port);
            const auto entry =
                target ? shared_state_->mach_namespaces.lookup(*target, name)
                       : std::nullopt;
            const auto receive_type =
                xnu::ipc::type_mask(xnu::ipc::Right::Receive);
            const auto dead_name_types =
                receive_type |
                xnu::ipc::type_mask(xnu::ipc::Right::Send) |
                xnu::ipc::type_mask(xnu::ipc::Right::SendOnce) |
                xnu::ipc::type_mask(xnu::ipc::Right::DeadName);
            if (!target) {
                result = 4;
            } else if (notification != mach_notify_port_destroyed &&
                       notification != mach_notify_no_senders &&
                       notification != mach_notify_dead_name &&
                       notification != mach_notify_send_possible) {
                result = 18; // KERN_INVALID_VALUE
            } else if (!entry) {
                result = 15; // KERN_INVALID_NAME
            } else if ((notification == mach_notify_port_destroyed ||
                           notification == mach_notify_no_senders) &&
                       (entry->type & receive_type) == 0) {
                result = 17; // KERN_INVALID_RIGHT
            } else if ((notification == mach_notify_dead_name ||
                           notification == mach_notify_send_possible) &&
                       (entry->type & dead_name_types) == 0) {
                result = 17;
            } else if (notification == mach_notify_port_destroyed &&
                       sync != 0) {
                result = 18;
            } else {
                std::uint32_t notify_object = 0;
                if (notify_name != 0) {
                    const auto right = right_for_disposition(disposition);
                    const auto source_right =
                        source_right_for_disposition(disposition);
                    const auto object =
                        source_right
                            ? resolve_name_with_right(*shared_state_,
                                  process_.pid, notify_name, *source_right)
                            : std::nullopt;
                    if (!right || *right != xnu::ipc::Right::SendOnce ||
                        !object) {
                        result = 20; // KERN_INVALID_CAPABILITY
                    } else {
                        notify_object = *object;
                    }
                }
                if (result == 0) {
                    const auto dead_type =
                        xnu::ipc::type_mask(xnu::ipc::Right::DeadName);
                    if (notification == mach_notify_dead_name ||
                        notification == mach_notify_send_possible) {
                        const auto key = std::pair { *target, name };
                        if (const auto previous = shared_state_
                                ->mach_dead_name_notifications.find(key);
                            previous !=
                            shared_state_->mach_dead_name_notifications.end()) {
                            if (previous->second.notify_object != 0) {
                                previous_name =
                                    shared_state_->mach_namespaces
                                        .copyout(process_.pid,
                                            previous->second.notify_object,
                                            xnu::ipc::type_mask(
                                                xnu::ipc::Right::SendOnce))
                                        .value_or(0);
                            }
                            shared_state_->mach_dead_name_notifications.erase(
                                previous);
                        }
                        if ((entry->type & dead_type) != 0) {
                            if ((sync == 0 && notification == mach_notify_dead_name) ||
                                notify_object == 0) {
                                result = 4; // KERN_INVALID_ARGUMENT
                            } else {
                                static_cast<void>(
                                    shared_state_->mach_namespaces.install(
                                        *target, name, entry->object,
                                        dead_type));
                                enqueue_dead_name_notification_locked(
                                    *shared_state_, notify_object, name);
                            }
                        } else if (notify_object != 0) {
                            shared_state_->mach_dead_name_notifications.emplace(
                                key,
                                KernelSharedState::
                                    MachDeadNameNotificationRequest {
                                        entry->object, notify_object, sync,
                                        notification == mach_notify_send_possible,
                                        sync != 0U });
                            if (notification == mach_notify_send_possible &&
                                sync != 0U) {
                                shared_state_->mach_send_possible_armed_destinations.insert(entry->object);
                                shared_state_->notify_send_possible_locked(entry->object);
                            }
                        }
                    } else {
                        const auto key =
                            std::pair { entry->object, notification };
                        if (const auto previous =
                                shared_state_->mach_notifications.find(key);
                            previous !=
                            shared_state_->mach_notifications.end()) {
                            if (previous->second.notify_object != 0) {
                                previous_name =
                                    shared_state_->mach_namespaces
                                        .copyout(process_.pid,
                                            previous->second.notify_object,
                                            xnu::ipc::type_mask(
                                                xnu::ipc::Right::SendOnce))
                                        .value_or(0);
                            }
                            shared_state_->mach_notifications.erase(previous);
                        }
                        if (notify_object != 0) {
                            shared_state_->mach_notifications.emplace(key,
                                KernelSharedState::MachNotificationRequest {
                                    notify_object, sync });
                            if (notification == mach_notify_no_senders) {
                                static_cast<void>(
                                    enqueue_no_senders_notification_locked(
                                        *shared_state_, entry->object));
                            }
                        }
                    }
                    if (result == 0 && disposition == 18U && notify_name != 0) {
                        static_cast<void>(consume_moved_right_locked(
                            *shared_state_, process_.pid, notify_name,
                            xnu::ipc::Right::SendOnce, true));
                    }
                }
            }
        }
        if (result != 0) {
            const std::array<std::uint32_t, 9> reply {
                18,
                36,
                *local_port,
                0,
                0,
                *message_id + 100,
                0x00000000U,
                0x00000001U,
                result,
            };
            for (std::size_t index = 0; index < reply.size(); ++index) {
                if (!memory_.write32(message_address +
                                         static_cast<std::uint32_t>(index * 4U),
                        reply[index])) {
                    registers[0] = 0x10004008U;
                    return true;
                }
            }
        } else {
            const std::array<std::uint32_t, 10> reply {
                0x80000012U,
                40,
                *local_port,
                0,
                0,
                *message_id + 100,
                1,
                previous_name,
                0,
                0x00120000U, // MOVE_SEND_ONCE port descriptor
            };
            for (std::size_t index = 0; index < reply.size(); ++index) {
                if (!memory_.write32(message_address +
                                         static_cast<std::uint32_t>(index * 4U),
                        reply[index])) {
                    registers[0] = 0x10004008U;
                    return true;
                }
            }
        }
        registers[0] = 0;
        return true;
    }
    return false;
}

} // namespace shade
