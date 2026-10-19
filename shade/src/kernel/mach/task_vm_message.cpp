// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Route guest task, thread and virtual-memory MIG requests.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/task.defs

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
#include "kernel/mach_descriptor_transport.hpp"
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
#include <sstream>
#include <string_view>
#include <utility>
#include <vector>

#include "support.hpp"

namespace shade {

using namespace mach_support;

bool CompatibilityKernel::dispatch_mach_task_vm_message(
    Cpu& cpu, const MachMessageRequest& request)
{
    if (dispatch_mach_vm_allocate_message(cpu, request) ||
        dispatch_mach_vm_deallocate_message(cpu, request) ||
        dispatch_mach_vm_protect_message(cpu, request) ||
        dispatch_mach_vm_inherit_message(cpu, request) ||
        dispatch_mach_vm_copy_message(cpu, request) ||
        dispatch_mach_vm_read_message(cpu, request) ||
        dispatch_mach_vm_purgable_message(cpu, request) ||
        dispatch_mach_vm_memory_entry_message(cpu, request) ||
        dispatch_mach_vm_map_message(cpu, request) ||
        dispatch_mach_vm_remap_message(cpu, request) ||
        dispatch_mach_vm_region_message(cpu, request))
        return true;

    auto& registers = cpu.registers();
    const auto message_address = request.address;
    const std::optional<std::uint32_t> bits { request.bits };
    const std::optional<std::uint32_t> remote_port { request.remote_port };
    const std::optional<std::uint32_t> local_port { request.local_port };
    const std::optional<std::uint32_t> message_id { request.identifier };
    const auto write_simple_reply = [&](std::uint32_t result) {
        if (registers[3] < 36U) {
            registers[0] = darwin::mach_message::receive_invalid_data;
            return true;
        }
        const std::array<std::uint32_t, 9> reply {
            darwin::mig_wire::disposition_move_send_once,
            36U,
            *local_port,
            0,
            0,
            *message_id + 100U,
            0,
            1,
            result,
        };
        for (std::size_t index = 0; index < reply.size(); ++index) {
            if (!memory_.write32(
                    message_address + static_cast<std::uint32_t>(index * 4U),
                    reply[index])) {
                registers[0] = darwin::mach_message::receive_invalid_data;
                return true;
            }
        }
        registers[0] = darwin::mach::success;
        return true;
    };
    if (*message_id ==
            mig_message_id(xnu::mig::task::Routine::mach_ports_register) &&
        registers[3] >= 36U) {
        std::uint32_t result = darwin::mach::invalid_argument;
        std::array<std::uint32_t, 3> registered_objects { };
        std::array<std::uint32_t, 3> requested_names { };
        bool valid = false;
        const auto bytes = memory_.read_bytes(message_address, registers[2]);
        if (bytes) {
            const auto descriptors = mach_transport::parse_descriptors(*bytes);
            if (descriptors && descriptors->size() == 1U &&
                descriptors->front().kind ==
                    mach_transport::DescriptorKind::OutOfLinePorts) {
                const auto& descriptor = descriptors->front();
                const auto descriptor_count = descriptor.count_or_size;
                const auto request_count_offset =
                    xnu::mig::task::mach_ports_register_arguments[1]
                        .request_count_offset;
                const auto requested_count =
                    request_count_offset + sizeof(std::uint32_t) <=
                            bytes->size()
                        ? std::optional<std::uint32_t> { read_little_word(
                              *bytes, request_count_offset) }
                        : std::nullopt;
                const auto disposition = descriptor.disposition();
                const auto move_send =
                    disposition == darwin::mig_wire::disposition_move_send;
                const auto copy_send =
                    disposition == darwin::mig_wire::disposition_copy_send;
                valid = requested_count &&
                        *requested_count == descriptor_count &&
                        descriptor_count <= requested_names.size() &&
                        (move_send || copy_send) &&
                        (descriptor_count == 0U ||
                            descriptor.address_or_name != 0U);
                if (valid && descriptor_count != 0U) {
                    const auto ool_size =
                        static_cast<std::size_t>(descriptor_count) *
                        sizeof(std::uint32_t);
                    const auto ool_end =
                        static_cast<std::uint64_t>(descriptor.address_or_name) +
                        ool_size;
                    const auto ool_bytes =
                        ool_end <=
                                std::numeric_limits<std::uint32_t>::max() + 1ULL
                            ? memory_.read_bytes(
                                  descriptor.address_or_name, ool_size)
                            : std::nullopt;
                    if (!ool_bytes) {
                        valid = false;
                    } else {
                        for (std::uint32_t index = 0; index < descriptor_count;
                            ++index) {
                            requested_names[index] = read_little_word(
                                *ool_bytes, static_cast<std::size_t>(index) *
                                                sizeof(std::uint32_t));
                        }
                    }
                }
                if (valid) {
                    std::lock_guard mach_lock { shared_state_->mach_mutex };
                    const auto target = target_task_for_port(
                        *shared_state_, process_.pid, *remote_port);
                    valid = target.has_value();
                    const auto source_right = xnu::ipc::Right::Send;
                    if (valid) {
                        for (std::uint32_t index = 0; index < descriptor_count;
                            ++index) {
                            const auto name = requested_names[index];
                            if (name == xnu::ipc::null_name)
                                continue;
                            const auto entry =
                                shared_state_->mach_namespaces.lookup(
                                    process_.pid, name);
                            if (!entry ||
                                (entry->type & xnu::ipc::type_mask(
                                                   source_right)) == 0 ||
                                !shared_state_->mach_port_objects.contains(
                                    entry->object)) {
                                valid = false;
                                break;
                            }
                            registered_objects[index] = entry->object;
                            if (move_send) {
                                // Preflight every duplicate before changing any
                                // uref. The commit below runs under the same
                                // mach_mutex, so a valid plan cannot fail
                                // halfway through and leave the old stash or
                                // caller namespace partially changed.
                                std::uint32_t occurrences = 1;
                                for (std::uint32_t prior = 0; prior < index;
                                    ++prior) {
                                    if (requested_names[prior] == name)
                                        ++occurrences;
                                }
                                const auto references =
                                    shared_state_->mach_namespaces
                                        .user_references(
                                            process_.pid, name, source_right);
                                if (!references || *references < occurrences) {
                                    valid = false;
                                    break;
                                }
                            }
                        }
                    }
                    if (valid) {
                        const auto target_pid = *target;
                        const auto previous =
                            shared_state_->mach_registered_ports.find(
                                target_pid);
                        for (const auto object : registered_objects) {
                            if (object != xnu::ipc::null_name)
                                retain_kernel_send_right_locked(
                                    *shared_state_, object);
                        }
                        std::vector<std::pair<std::uint32_t, std::uint32_t>>
                            consumed_rights;
                        bool commit_succeeded = true;
                        if (move_send) {
                            for (std::uint32_t index = 0;
                                index < descriptor_count; ++index) {
                                const auto name = requested_names[index];
                                if (name == xnu::ipc::null_name)
                                    continue;
                                if (!consume_moved_right_locked(*shared_state_,
                                        process_.pid, name, source_right,
                                        false)) {
                                    commit_succeeded = false;
                                    break;
                                }
                                consumed_rights.emplace_back(
                                    name, registered_objects[index]);
                            }
                        }
                        if (!commit_succeeded) {
                            // The preflight and commit share mach_mutex, so
                            // this is an invariant failure rather than an
                            // expected path. Still restore every successful
                            // MOVE_SEND and release all temporary holds so the
                            // old stash remains the only committed state.
                            for (const auto& [name, object] : consumed_rights) {
                                const auto restored =
                                    shared_state_->mach_namespaces.install(
                                        process_.pid, name, object,
                                        xnu::ipc::type_mask(source_right));
                                if (!restored) {
                                    // The name/object was validated while
                                    // holding the same mutex; reaching this
                                    // branch indicates a broken namespace
                                    // invariant that cannot be repaired by
                                    // another IPC path.
                                    valid = false;
                                }
                            }
                            for (const auto object : registered_objects) {
                                if (object != xnu::ipc::null_name)
                                    release_kernel_send_right_locked(
                                        *shared_state_, object);
                            }
                            valid = false;
                        } else {
                            // Every MOVE_SEND was preflighted while holding
                            // mach_mutex; COPY_SEND deliberately leaves the
                            // caller's uref untouched.
                            if (previous !=
                                shared_state_->mach_registered_ports.end()) {
                                for (const auto object : previous->second) {
                                    if (object != xnu::ipc::null_name)
                                        release_kernel_send_right_locked(
                                            *shared_state_, object);
                                }
                            }
                            shared_state_->mach_registered_ports[target_pid] =
                                registered_objects;
                        }
                    }
                }
            }
        }
        result = valid ? darwin::mach::success : darwin::mach::invalid_argument;
        return write_simple_reply(result);
    }
    const auto creates_suspended_thread =
        *message_id ==
        mig_message_id(xnu::mig::task::Routine::thread_create);
    const auto creates_running_thread =
        *message_id ==
        mig_message_id(xnu::mig::task::Routine::thread_create_running);
    if ((creates_suspended_thread || creates_running_thread) &&
        registers[3] >= 40) {
        const auto write_create_error = [&](std::uint32_t result) {
            const std::array<std::uint32_t, 9> reply {
                18,
                36,
                *local_port,
                0,
                0,
                *message_id + 100,
                0,
                1,
                result,
            };
            for (std::size_t index = 0; index < reply.size(); ++index) {
                if (!memory_.write32(message_address +
                                         static_cast<std::uint32_t>(index * 4U),
                        reply[index])) {
                    registers[0] = darwin::mach_message::receive_invalid_data;
                    return true;
                }
            }
            registers[0] = darwin::mach::success;
            return true;
        };
        const auto& create_arguments =
            xnu::mig::task::thread_create_running_arguments;
        std::array<std::uint32_t, 16> state { };
        std::uint32_t state_count = 0;
        std::uint32_t guest_cpsr = 0x10U;
        bool valid_state = creates_suspended_thread;
        if (creates_running_thread) {
            const auto flavor = memory_
                                    .read32(message_address +
                                            create_arguments[1].request_offset)
                                    .value_or(0);
            state_count = memory_
                              .read32(message_address +
                                      create_arguments[2].request_count_offset)
                              .value_or(0);
            valid_state = flavor == 1 && state_count >= 17;
            for (std::size_t index = 0; valid_state && index < state.size();
                ++index) {
                const auto value = memory_.read32(
                    message_address + create_arguments[2].request_offset +
                    static_cast<std::uint32_t>(index * sizeof(std::uint32_t)));
                if (!value) {
                    valid_state = false;
                } else {
                    state[index] = *value;
                }
            }
            guest_cpsr = memory_
                             .read32(message_address +
                                     create_arguments[2].request_offset +
                                     16U * sizeof(std::uint32_t))
                             .value_or(0);
        }
        if (valid_state && thread_trace_count_ < 16) {
            output_.write("[thread] create-" +
                          std::string(creates_suspended_thread ? "suspended"
                                                               : "running") +
                          " pid=" + std::to_string(process_.pid) +
                          " pc=" + std::to_string(state[15]) +
                          " sp=" + std::to_string(state[13]) +
                          " lr=" + std::to_string(state[14]) +
                          " cpsr=" + std::to_string(guest_cpsr) +
                          " r0=" + std::to_string(state[0]) +
                          " r1=" + std::to_string(state[1]) +
                          " r2=" + std::to_string(state[2]) +
                          " r3=" + std::to_string(state[3]) +
                          " count=" + std::to_string(state_count) + "\n");
            ++thread_trace_count_;
        }
        if (!valid_state) {
            return write_create_error(darwin::mach::invalid_argument);
        }
        std::uint32_t create_error { };
        const auto created = create_guest_thread(
            state, guest_cpsr, creates_suspended_thread, create_error);
        if (!created)
            return write_create_error(create_error);
        start_thread_signals(created->processor, cpu.processor_id());
        const std::array<std::uint32_t, 10> reply {
            0x80000012U,
            40,
            *local_port,
            0,
            0,
            *message_id + 100,
            1,
            created->port_name,
            0,
            0x00110000U,
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
        if (creates_running_thread && scheduler_preemption_query_ &&
            scheduler_preemption_query_(cpu.processor_id())) {
            // Scheduler AST boundary. Unlike an explicit yield, this preserves
            // the remainder of the current first timeslice.
            cpu.request_guest_preemption();
        }
        return true;
    }
    if (*message_id ==
            mig_message_id(xnu::mig::task::Routine::mach_ports_lookup) &&
        registers[3] >= 52) {
        std::uint32_t result = darwin::mach::invalid_argument;
        std::array<std::uint32_t, 3> registered_objects { };
        std::array<std::uint32_t, 3> port_names { };
        std::uint32_t ports_address = 0;
        bool ports_mapped = false;
        const auto rollback_lookup = [&] {
            if (ports_mapped) {
                static_cast<void>(
                    memory_.unmap(ports_address, AddressSpace::page_size));
                ports_mapped = false;
            }
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            for (auto& name : port_names) {
                if (name != xnu::ipc::null_name &&
                    name != xnu::ipc::dead_name)
                    static_cast<void>(shared_state_->mach_namespaces.deallocate(
                        process_.pid, name));
                name = xnu::ipc::null_name;
            }
        };
        const auto fail_lookup_transport = [&] {
            rollback_lookup();
            registers[0] = darwin::mach_message::receive_invalid_data;
            return true;
        };
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            if (const auto target = target_task_for_port(
                    *shared_state_, process_.pid, *remote_port)) {
                result = darwin::mach::success;
                if (const auto registered =
                        shared_state_->mach_registered_ports.find(*target);
                    registered != shared_state_->mach_registered_ports.end()) {
                    registered_objects = registered->second;
                }
                for (std::size_t index = 0; index < registered_objects.size();
                    ++index) {
                    const auto object = registered_objects[index];
                    if (object == xnu::ipc::null_name)
                        continue;
                    if (!shared_state_->mach_port_objects.contains(object)) {
                        // ipc_port_copy_send() returns IP_DEAD for an inactive
                        // port. The lookup ABI exposes that result as
                        // MACH_PORT_DEAD rather than failing the whole
                        // three-slot copyout or resurrecting a Send name for a
                        // retired object.
                        port_names[index] = xnu::ipc::dead_name;
                        continue;
                    }
                    const auto copied_name =
                        shared_state_->mach_namespaces.copyout(process_.pid,
                            object,
                            xnu::ipc::type_mask(xnu::ipc::Right::Send));
                    if (!copied_name) {
                        result = darwin::mach::resource_shortage;
                        break;
                    }
                    port_names[index] = *copied_name;
                }
                if (result != darwin::mach::success) {
                    for (const auto name : port_names) {
                        if (name != xnu::ipc::null_name &&
                            name != xnu::ipc::dead_name)
                            static_cast<void>(
                                shared_state_->mach_namespaces.deallocate(
                                    process_.pid, name));
                    }
                    port_names.fill(xnu::ipc::null_name);
                }
            }
        }
        if (result == darwin::mach::success) {
            const auto region = find_free_guest_region(
                memory_, ool_results_base, AddressSpace::page_size);
            if (!region ||
                !memory_.map(*region, AddressSpace::page_size,
                    MemoryPermission::Read | MemoryPermission::Write)) {
                result = darwin::mach::resource_shortage;
            } else {
                ports_address = *region;
                ports_mapped = true;
                for (std::size_t index = 0; index < port_names.size();
                    ++index) {
                    if (!memory_.write32(
                            ports_address +
                                static_cast<std::uint32_t>(index * 4U),
                            port_names[index])) {
                        return fail_lookup_transport();
                    }
                }
            }
        }
        if (result != darwin::mach::success) {
            rollback_lookup();
            return write_simple_reply(result);
        }
        const std::array<std::uint32_t, 13> reply {
            0x80000012U,
            52U,
            *local_port,
            0,
            0,
            *message_id + 100U,
            1U,
            ports_address,
            3U,
            0x02110000U, // OOL_PORTS, MOVE_SEND
            0U,
            1U,
            3U, // init_port_setCnt
        };
        for (std::size_t index = 0; index < reply.size(); ++index) {
            if (!memory_.write32(
                    message_address + static_cast<std::uint32_t>(index * 4U),
                    reply[index])) {
                return fail_lookup_transport();
            }
        }
        registers[0] = 0;
        return true;
    }
    if (*message_id ==
            mig_message_id(
                xnu::mig::mach_port::Routine::mach_port_get_attributes) &&
        registers[3] >= 44) {
        // mach_port_get_attributes.
        const auto& attribute_arguments =
            xnu::mig::mach_port::mach_port_get_attributes_arguments;
        const auto flavor =
            memory_
                .read32(message_address + attribute_arguments[2].request_offset)
                .value_or(0);
        const auto requested_count =
            memory_
                .read32(message_address +
                        attribute_arguments[3].request_count_offset)
                .value_or(0);
        if (flavor == 1 && requested_count >= 1) {
            // MACH_PORT_LIMITS_INFO: one natural_t queue limit.
            const auto name = memory_
                                  .read32(message_address +
                                          attribute_arguments[1].request_offset)
                                  .value_or(0);
            std::uint32_t result = 15;
            std::uint32_t queue_limit = xnu::ipc::default_queue_limit;
            {
                std::lock_guard mach_lock { shared_state_->mach_mutex };
                const auto target = target_task_for_port(
                    *shared_state_, process_.pid, *remote_port);
                const auto entry =
                    target
                        ? shared_state_->mach_namespaces.lookup(*target, name)
                        : std::nullopt;
                if (entry &&
                    (entry->type & xnu::ipc::type_mask(
                                       xnu::ipc::Right::Receive)) != 0) {
                    result = 0;
                    queue_limit =
                        shared_state_->mach_port_objects.lookup(entry->object)
                            .value_or(xnu::ipc::PortObject { })
                            .queue_limit;
                } else if (entry) {
                    result = 17;
                }
            }
            const std::array<std::uint32_t, 11> reply {
                18,
                44,
                *local_port,
                0,
                0,
                *message_id + 100,
                0x00000000U,
                0x00000001U,
                result,
                1, // port_info_outCnt
                queue_limit,
            };
            for (std::size_t index = 0; index < reply.size(); ++index) {
                if (!memory_.write32(message_address +
                                         static_cast<std::uint32_t>(index * 4U),
                        reply[index])) {
                    registers[0] = 0x10004008U;
                    return true;
                }
            }
            registers[0] = 0;
            return true;
        }
        if (flavor == 2 && requested_count >= 10 && registers[3] >= 80) {
            // MACH_PORT_RECEIVE_STATUS. launchd's demand thread uses the
            // real queue depth to select one member after its zero-length
            // MACH_RCV_LARGE probe reports MACH_RCV_TOO_LARGE.
            const auto name = memory_
                                  .read32(message_address +
                                          attribute_arguments[1].request_offset)
                                  .value_or(0);
            std::uint32_t port_set = 0;
            std::uint32_t mscount = 0;
            std::uint32_t msgcount = 0;
            bool has_send_rights = false;
            std::uint32_t result = 15; // KERN_INVALID_NAME
            {
                std::lock_guard mach_lock { shared_state_->mach_mutex };
                const auto target = target_task_for_port(
                    *shared_state_, process_.pid, *remote_port);
                const auto entry =
                    target
                        ? shared_state_->mach_namespaces.lookup(*target, name)
                        : std::nullopt;
                if (target && entry &&
                    (entry->type & xnu::ipc::type_mask(
                                       xnu::ipc::Right::PortSet)) != 0) {
                    // A port-set name has a receive right for the set itself,
                    // not for an individual queue.  Darwin reports the
                    // aggregate pending depth here; GraphicsServices uses it to
                    // decide whether its heartbeat may remain paused after a
                    // timeout.
                    if (const auto set =
                            shared_state_->mach_port_sets.find(entry->object);
                        set != shared_state_->mach_port_sets.end()) {
                        for (const auto member : set->second) {
                            if (const auto queue =
                                    shared_state_->mach_queues.find(member);
                                queue != shared_state_->mach_queues.end()) {
                                msgcount += static_cast<std::uint32_t>(
                                    queue->second.size());
                            }
                        }
                    }
                    result = 0;
                } else if (target && entry &&
                           (entry->type & xnu::ipc::type_mask(
                                              xnu::ipc::Right::Receive)) !=
                               0) {
                    for (const auto& [set_name, members] :
                        shared_state_->mach_port_sets) {
                        if (std::find(members.begin(), members.end(),
                                entry->object) != members.end()) {
                            port_set = shared_state_->mach_namespaces
                                           .name_for(*target, set_name)
                                           .value_or(0);
                            break;
                        }
                    }
                    if (const auto object =
                            shared_state_->mach_port_objects.lookup(
                                entry->object)) {
                        mscount = object->make_send_count;
                    }
                    // Include rights held by messages and kernel services as
                    // well as task namespaces, just like no-senders delivery.
                    // Native transaction fences depend on this becoming false
                    // when their last sender releases the port.
                    has_send_rights = port_has_send_rights_locked(
                        *shared_state_, entry->object);
                    if (const auto queue =
                            shared_state_->mach_queues.find(entry->object);
                        queue != shared_state_->mach_queues.end()) {
                        msgcount =
                            static_cast<std::uint32_t>(queue->second.size());
                    }
                    result = 0;
                } else if (entry) {
                    result = 17;
                }
            }
            const std::array<std::uint32_t, 20> reply {
                18,
                80,
                *local_port,
                0,
                0,
                *message_id + 100,
                0x00000000U,
                0x00000001U,
                result,
                10, // port_info_outCnt
                port_set, // mps_pset
                0, // mps_seqno
                mscount, // mps_mscount
                5, // mps_qlimit
                msgcount, // mps_msgcount
                0, // mps_sorights
                has_send_rights ? 1U : 0U, // mps_srights
                0, // mps_pdrequest
                0, // mps_nsrequest
                0, // mps_flags
            };
            if (process_.pid == 1 && port_status_trace_count_ < 64) {
                output_.write(
                    "[mach] receive-status name=" + std::to_string(name) +
                    " pset=" + std::to_string(port_set) +
                    " msgcount=" + std::to_string(msgcount) +
                    " result=" + std::to_string(result) + "\n");
                ++port_status_trace_count_;
            }
            for (std::size_t index = 0; index < reply.size(); ++index) {
                if (!memory_.write32(message_address +
                                         static_cast<std::uint32_t>(index * 4U),
                        reply[index])) {
                    registers[0] = 0x10004008U;
                    return true;
                }
            }
            registers[0] = 0;
            return true;
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
            4, // KERN_INVALID_ARGUMENT
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
    if (*message_id == darwin::mach::thread_policy::policy_set_message &&
        registers[3] >= darwin::mach::thread_policy::minimum_request_size) {
        using namespace darwin::mach::thread_policy;
        const auto flavor =
            memory_.read32(message_address + request_flavor_offset);
        const auto count =
            memory_.read32(message_address + request_count_offset);
        std::optional<std::size_t> target_thread;
        for (const auto& [processor, port] : thread_ports_) {
            if (port == *remote_port) {
                target_thread = processor;
                break;
            }
        }

        std::vector<std::uint32_t> policy;
        bool valid = flavor && count && target_thread &&
                     *count <= maximum_policy_word_count &&
                     request_policy_offset + static_cast<std::size_t>(*count) *
                                                 sizeof(std::uint32_t) <=
                         registers[3];
        if (valid) {
            policy.reserve(*count);
            for (std::uint32_t index = 0; index < *count; ++index) {
                const auto value = memory_.read32(
                    message_address +
                    static_cast<std::uint32_t>(request_policy_offset +
                                               static_cast<std::size_t>(index) *
                                                   sizeof(std::uint32_t)));
                if (!value) {
                    valid = false;
                    break;
                }
                policy.push_back(*value);
            }
        }
        const auto policy_applied =
            valid && thread_policy_handler_ &&
            thread_policy_handler_(*target_thread, *flavor,
                std::span<const std::uint32_t> { policy });
        const auto kernel_result = policy_applied
                                       ? darwin::mach::success
                                       : darwin::mach::invalid_argument;
        const std::array<std::uint32_t, simple_reply_word_count> reply {
            18,
            simple_reply_size,
            *local_port,
            0,
            0,
            *message_id + mig_reply_id_delta,
            0,
            1,
            kernel_result,
        };
        for (std::size_t index = 0; index < reply.size(); ++index) {
            if (!memory_.write32(
                    message_address + static_cast<std::uint32_t>(
                                          index * sizeof(std::uint32_t)),
                    reply[index])) {
                registers[0] = 0x10004008U;
                return true;
            }
        }
        registers[0] = 0;
        if (policy_applied && scheduler_preemption_query_ &&
            scheduler_preemption_query_(cpu.processor_id())) {
            cpu.request_guest_preemption();
        }
        return true;
    }
    return false;
}

} // namespace shade
