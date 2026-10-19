// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Dispatch guest Mach port allocation, destruction and attribute
// messages.
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

bool CompatibilityKernel::dispatch_mach_port_message(
    Cpu& cpu, const MachMessageRequest& request)
{
    if (dispatch_mach_port_limit_message(cpu, request) ||
        dispatch_mach_port_membership_message(cpu, request) ||
        dispatch_mach_port_query_message(cpu, request))
        return true;
    auto& registers = cpu.registers();
    const auto message_address = request.address;
    const std::optional<std::uint32_t> bits { request.bits };
    const std::optional<std::uint32_t> remote_port { request.remote_port };
    const std::optional<std::uint32_t> local_port { request.local_port };
    const std::optional<std::uint32_t> message_id { request.identifier };
    if (*message_id ==
            mig_message_id(xnu::mig::mach_port::Routine::mach_port_type) &&
        registers[3] >= 40) {
        const auto name =
            memory_
                .read32(message_address +
                        xnu::mig::mach_port::mach_port_type_arguments[1]
                            .request_offset)
                .value_or(0);
        std::uint32_t result = 15; // KERN_INVALID_NAME
        std::uint32_t port_type = 0;
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            if (const auto task = target_task_for_port(
                    *shared_state_, process_.pid, *remote_port)) {
                if (const auto type =
                        shared_state_->mach_namespaces.type(*task, name)) {
                    port_type = *type;
                    result = 0;
                }
            }
        }
        const std::array<std::uint32_t, 10> reply {
            18,
            40,
            *local_port,
            0,
            0,
            *message_id + 100,
            0x00000000U,
            0x00000001U,
            result,
            port_type,
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
    if (*message_id ==
            mig_message_id(xnu::mig::mach_port::Routine::mach_port_rename) &&
        registers[3] >= 36) {
        const auto old_name =
            memory_
                .read32(message_address +
                        xnu::mig::mach_port::mach_port_rename_arguments[1]
                            .request_offset)
                .value_or(0);
        const auto new_name =
            memory_
                .read32(message_address +
                        xnu::mig::mach_port::mach_port_rename_arguments[2]
                            .request_offset)
                .value_or(0);
        std::uint32_t result = 0;
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            const auto target = target_task_for_port(
                *shared_state_, process_.pid, *remote_port);
            if (!target) {
                result = 4;
            } else if (new_name == xnu::ipc::null_name ||
                       new_name == xnu::ipc::dead_name) {
                result = 18; // KERN_INVALID_VALUE
            } else if (!shared_state_->mach_namespaces.contains(
                           *target, old_name)) {
                result = 15; // KERN_INVALID_NAME
            } else if (shared_state_->mach_namespaces.contains(
                           *target, new_name)) {
                result = darwin::mach::name_exists;
            } else if (!shared_state_->mach_namespaces.rename(
                           *target, old_name, new_name)) {
                result = 5; // KERN_FAILURE
            } else if (const auto notification =
                           shared_state_->mach_dead_name_notifications.find(
                               std::pair { *target, old_name });
                notification !=
                shared_state_->mach_dead_name_notifications.end()) {
                auto notification_request = notification->second;
                shared_state_->mach_dead_name_notifications.erase(notification);
                shared_state_->mach_dead_name_notifications.emplace(
                    std::pair { *target, new_name }, notification_request);
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
            result,
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
    if (*message_id ==
            mig_message_id(
                xnu::mig::mach_port::Routine::mach_port_allocate_name) &&
        registers[3] >= 36) {
        // mach_port_allocate_name(task, right, name)
        const auto right =
            memory_
                .read32(
                    message_address +
                    xnu::mig::mach_port::mach_port_allocate_name_arguments[1]
                        .request_offset)
                .value_or(0);
        const auto name =
            memory_
                .read32(
                    message_address +
                    xnu::mig::mach_port::mach_port_allocate_name_arguments[2]
                        .request_offset)
                .value_or(0);
        std::uint32_t result = 0;
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            const auto target = target_task_for_port(
                *shared_state_, process_.pid, *remote_port);
            const auto valid_right = right == 1U || right == 3U || right == 4U;
            if (!target) {
                result = 4;
            } else if (!valid_right || name == xnu::ipc::null_name ||
                       name == xnu::ipc::dead_name) {
                result = 18;
            } else if (shared_state_->mach_namespaces.contains(*target, name)) {
                result = 16;
            } else {
                const auto object = shared_state_->allocate_mach_object();
                if (!shared_state_->mach_namespaces.install(
                        *target, name, object, 1U << (right + 16U))) {
                    result = 3;
                } else if (right == 1U) {
                    static_cast<void>(shared_state_->mach_port_objects.create(
                        object, *target));
                    shared_state_->mach_queues.try_emplace(object);
                } else if (right == 3U) {
                    static_cast<void>(
                        shared_state_->create_mach_port_set_locked(object));
                }
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
            result,
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
    if (*message_id ==
            mig_message_id(
                xnu::mig::mach_port::Routine::mach_port_allocate) &&
        registers[3] >= 40) {
        const auto right =
            memory_
                .read32(message_address +
                        xnu::mig::mach_port::mach_port_allocate_arguments[1]
                            .request_offset)
                .value_or(0);
        std::uint32_t allocated_port = 0;
        std::uint32_t result = 0;
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            const auto target = target_task_for_port(
                *shared_state_, process_.pid, *remote_port);
            const auto valid_right = right == 1U || right == 3U || right == 4U;
            if (!target || !valid_right) {
                result = !target ? 4U // KERN_INVALID_ARGUMENT / task
                                 : 18U; // KERN_INVALID_VALUE
            } else {
                const auto object = shared_state_->allocate_mach_object();
                const auto name = shared_state_->mach_namespaces.allocate(
                    *target, object, 1U << (right + 16U));
                if (!name) {
                    result = 3U; // KERN_NO_SPACE
                } else {
                    allocated_port = *name;
                    if (right == 1U) {
                        static_cast<void>(
                            shared_state_->mach_port_objects.create(
                                object, *target));
                        shared_state_->mach_queues.try_emplace(object);
                    } else if (right == 3U) {
                        static_cast<void>(
                            shared_state_->create_mach_port_set_locked(object));
                    }
                }
            }
        }
        const std::array<std::uint32_t, 10> reply {
            18,
            40,
            *local_port,
            0,
            0,
            *message_id + 100,
            0x00000000U,
            0x00000001U,
            result,
            allocated_port,
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
    if (*message_id ==
            mig_message_id(
                xnu::mig::mach_port::Routine::mach_port_destroy) &&
        registers[3] >= 36) {
        const auto name =
            memory_
                .read32(message_address +
                        xnu::mig::mach_port::mach_port_destroy_arguments[1]
                            .request_offset)
                .value_or(0);
        std::uint32_t result = 0;
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            const auto target = target_task_for_port(
                *shared_state_, process_.pid, *remote_port);
            if (!target) {
                result = 4; // KERN_INVALID_ARGUMENT
            } else if (name != xnu::ipc::null_name &&
                       name != xnu::ipc::dead_name) {
                if (!destroy_port_name_locked(*shared_state_, *target, name)) {
                    result = 15; // KERN_INVALID_NAME
                }
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
            result,
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
    if (*message_id ==
            mig_message_id(
                xnu::mig::mach_port::Routine::mach_port_get_refs) &&
        registers[3] >= 40) {
        const auto name =
            memory_
                .read32(message_address +
                        xnu::mig::mach_port::mach_port_get_refs_arguments[1]
                            .request_offset)
                .value_or(0);
        const auto right =
            memory_
                .read32(message_address +
                        xnu::mig::mach_port::mach_port_get_refs_arguments[2]
                            .request_offset)
                .value_or(5);
        std::uint32_t result = 0;
        std::uint32_t references = 0;
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            const auto target = target_task_for_port(
                *shared_state_, process_.pid, *remote_port);
            if (!target) {
                result = 4;
            } else if (right > 4U) {
                result = 18;
            } else if (const auto count =
                           shared_state_->mach_namespaces.user_references(
                               *target, name,
                               static_cast<xnu::ipc::Right>(right))) {
                references = *count;
            } else if (!shared_state_->mach_namespaces.contains(
                           *target, name)) {
                result = 15;
            } else {
                result = 17;
            }
        }
        const std::array<std::uint32_t, 10> reply {
            18,
            40,
            *local_port,
            0,
            0,
            *message_id + 100,
            0x00000000U,
            0x00000001U,
            result,
            references,
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
    if (*message_id ==
            mig_message_id(
                xnu::mig::mach_port::Routine::mach_port_mod_refs) &&
        registers[3] >= 44) {
        const auto name =
            memory_
                .read32(message_address +
                        xnu::mig::mach_port::mach_port_mod_refs_arguments[1]
                            .request_offset)
                .value_or(0);
        const auto right =
            memory_
                .read32(message_address +
                        xnu::mig::mach_port::mach_port_mod_refs_arguments[2]
                            .request_offset)
                .value_or(5);
        const auto delta = static_cast<std::int32_t>(memory_
                .read32(message_address +
                        xnu::mig::mach_port::mach_port_mod_refs_arguments[3]
                            .request_offset)
                .value_or(0));
        std::uint32_t result = 0;
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            const auto target = target_task_for_port(
                *shared_state_, process_.pid, *remote_port);
            if (!target) {
                result = 4;
            } else if (right > 4U) {
                result = 18;
            } else {
                result = modify_port_references_locked(*shared_state_, *target,
                    name, static_cast<xnu::ipc::Right>(right), delta);
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
            result,
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
    if (*message_id ==
            mig_message_id(
                xnu::mig::mach_port::Routine::mach_port_set_mscount) &&
        registers[3] >= 36) {
        // mach_port_set_mscount. mach_port.defs deliberately skips one
        // wire ID before this routine, so its Darwin 8 ID is 3210.
        const auto name =
            memory_
                .read32(
                    message_address +
                    xnu::mig::mach_port::mach_port_set_mscount_arguments[1]
                        .request_offset)
                .value_or(0);
        const auto mscount =
            memory_
                .read32(
                    message_address +
                    xnu::mig::mach_port::mach_port_set_mscount_arguments[2]
                        .request_offset)
                .value_or(0);
        std::uint32_t result = 15; // KERN_INVALID_NAME
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            const auto target = target_task_for_port(
                *shared_state_, process_.pid, *remote_port);
            const auto entry =
                target ? shared_state_->mach_namespaces.lookup(*target, name)
                       : std::nullopt;
            if (entry) {
                if ((entry->type & xnu::ipc::type_mask(
                                       xnu::ipc::Right::Receive)) != 0) {
                    static_cast<void>(
                        shared_state_->mach_port_objects.set_make_send_count(
                            entry->object, mscount));
                    result = 0;
                } else {
                    result = 17; // KERN_INVALID_RIGHT
                }
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
            result,
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
    if (*message_id ==
            mig_message_id(
                xnu::mig::mach_port::Routine::mach_port_get_set_status) &&
        registers[3] >= 52) { // mach_port_get_set_status
        const auto set_name =
            memory_
                .read32(
                    message_address + xnu::mig::mach_port::
                                          mach_port_get_set_status_arguments[1]
                                              .request_offset)
                .value_or(0);
        std::vector<std::uint32_t> members;
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            const auto target = target_task_for_port(
                *shared_state_, process_.pid, *remote_port);
            const auto set_entry =
                target
                    ? shared_state_->mach_namespaces.lookup(*target, set_name)
                    : std::nullopt;
            if (target && set_entry &&
                (set_entry->type &
                    xnu::ipc::type_mask(xnu::ipc::Right::PortSet)) != 0) {
                if (const auto set =
                        shared_state_->mach_port_sets.find(set_entry->object);
                    set != shared_state_->mach_port_sets.end()) {
                    for (const auto object : set->second) {
                        if (const auto local =
                                shared_state_->mach_namespaces.name_for(
                                    *target, object)) {
                            members.push_back(*local);
                        }
                    }
                }
            }
        }
        std::uint32_t members_address = 0;
        if (!members.empty()) {
            members_address = 0x1f000000U;
            while (memory_.mapped(members_address, AddressSpace::page_size)) {
                members_address += AddressSpace::page_size;
            }
            if (!memory_.map(members_address, AddressSpace::page_size,
                    MemoryPermission::Read | MemoryPermission::Write)) {
                registers[0] = 0x10004008U;
                return true;
            }
            for (std::size_t index = 0; index < members.size(); ++index) {
                if (!memory_.write32(members_address +
                                         static_cast<std::uint32_t>(index * 4U),
                        members[index])) {
                    registers[0] = 0x10004008U;
                    return true;
                }
            }
        }
        const std::array<std::uint32_t, 13> reply {
            0x80000012U,
            52,
            *local_port,
            0,
            0,
            *message_id + 100,
            1,
            members_address,
            static_cast<std::uint32_t>(members.size() * 4U),
            0x01000100U,
            0x00000000U,
            0x00000001U,
            static_cast<std::uint32_t>(members.size()),
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
