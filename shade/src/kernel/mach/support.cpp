// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Manage shared Mach rights, object teardown, notifications and
// memory helpers.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/ipc/ipc_right.c
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/kern/ipc_tt.c

#include "mach/bootstrap_mig_ids.hpp"
#include "kernel/darwin_abi.hpp"
#include "kernel/darwin_kqueue_abi.hpp"
#include "network/darwin_network_abi.hpp"
#include "kernel/darwin_resource_abi.hpp"
#include "network/darwin_route_socket.hpp"
#include "kernel/kernel.hpp"
#include "kernel/kernel_clock.hpp"
#include "kernel/kernel_iokit.hpp"
#include "kernel/kernel_iokit_display.hpp"
#include "kernel/kernel_mach_ipc.hpp"
#include "kernel/kernel_network.hpp"
#include "kernel/mach_clock_abi.hpp"
#include "mach/mach_host_mig_ids.hpp"
#include "mach/mach_port_mig_ids.hpp"
#include "kernel/mach_scheduler_abi.hpp"
#include "kernel/mach_thread_policy_abi.hpp"
#include "mach/mig_wire_abi.hpp"
#include "graphics/surface_store.hpp"
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

namespace mach_support {

    static_assert(
        darwin::mach::thread_policy::policy_set_message ==
        mig_message_id(xnu::mig::thread_act::Routine::thread_policy_set));

    std::string mig_message_label(std::uint32_t identifier)
    {
        const auto routine = xnu::mig::lookup_routine(identifier);
        if (!routine)
            return { };
        return " mig=" + std::string { routine->subsystem_name } + '.' +
               std::string { routine->routine_name };
    }

    bool guest_region_overlaps(
        const AddressSpace& memory, std::uint32_t address, std::uint32_t size)
    {
        if (size == 0 ||
            size - 1U > std::numeric_limits<std::uint32_t>::max() - address) {
            return true;
        }
        for (std::uint64_t offset = 0; offset < size;
            offset += AddressSpace::page_size) {
            if (memory.mapped(address + static_cast<std::uint32_t>(offset))) {
                return true;
            }
        }
        return false;
    }

    std::optional<std::uint32_t> find_free_guest_region(
        const AddressSpace& memory, std::uint32_t start, std::uint32_t size,
        std::uint32_t alignment_mask)
    {
        if (size == 0U)
            return std::nullopt;

        const auto align_candidate = [alignment_mask](std::uint64_t value)
            -> std::optional<std::uint32_t> {
            const auto aligned =
                (value + alignment_mask) & ~std::uint64_t { alignment_mask };
            if (aligned > std::numeric_limits<std::uint32_t>::max())
                return std::nullopt;
            return static_cast<std::uint32_t>(aligned);
        };

        auto candidate = align_candidate(
            start & ~(AddressSpace::page_size - 1U));
        while (candidate &&
               size - 1U <=
                   std::numeric_limits<std::uint32_t>::max() - *candidate) {
            if (!guest_region_overlaps(memory, *candidate, size))
                return candidate;

            const auto next_page = static_cast<std::uint64_t>(*candidate) +
                                   AddressSpace::page_size;
            if (next_page > std::numeric_limits<std::uint32_t>::max())
                break;
            const auto next = align_candidate(next_page);
            if (!next || *next <= *candidate)
                break;
            candidate = next;
        }
        return std::nullopt;
    }

    VmAllocationResult allocate_guest_vm_region(AddressSpace& memory,
        std::uint32_t requested_address, std::uint32_t size,
        std::uint32_t flags, std::uint32_t alignment_mask)
    {
        auto address = requested_address;
        if ((flags & darwin::mach::vm_flags_anywhere) != 0U) {
            address = find_free_guest_region(
                memory, default_dynamic_base, size, alignment_mask)
                          .value_or(0U);
        }
        const auto mapped = address != 0U && size != 0U &&
                            (address & alignment_mask) == 0U &&
                            !guest_region_overlaps(memory, address, size) &&
                            memory.map(address, size,
                                MemoryPermission::Read |
                                    MemoryPermission::Write);
        return { mapped ? darwin::mach::success : darwin::mach::no_space,
            address };
    }

    std::uint32_t create_surface_transport_send_right_locked(
        KernelSharedState& state, SurfaceStore& surfaces,
        std::uint32_t process_id, std::uint32_t surface_id)
    {
        auto port = state.surface_transport_surface_ports.find(surface_id);
        auto object = std::uint32_t { };
        auto created = false;
        if (port == state.surface_transport_surface_ports.end()) {
            auto lease = surfaces.acquire_transport_lease(surface_id);
            if (!lease)
                return 0U;
            object = state.allocate_mach_object();
            if (!state.mach_port_objects.create(object))
                return 0U;
            state.surface_transport_port_surfaces.emplace(object, surface_id);
            state.surface_transport_surface_ports.emplace(surface_id, object);
            state.surface_transport_port_leases.emplace(
                object, std::move(lease));
            created = true;
        } else {
            object = port->second;
        }

        const auto name =
            state.mach_namespaces
                .copyout(process_id, object,
                    xnu::ipc::type_mask(xnu::ipc::Right::Send))
                .value_or(0U);
        if (name == 0U && created) {
            state.surface_transport_port_surfaces.erase(object);
            state.surface_transport_surface_ports.erase(surface_id);
            state.surface_transport_port_leases.erase(object);
            static_cast<void>(state.mach_port_objects.erase(object));
        }
        return name;
    }

    std::optional<std::uint32_t> resolve_surface_transport_locked(
        const KernelSharedState& state, std::uint32_t process_id,
        std::uint32_t port_name)
    {
        const auto object =
            state.mach_namespaces.resolve(process_id, port_name);
        if (!object)
            return std::nullopt;
        const auto surface =
            state.surface_transport_port_surfaces.find(*object);
        return surface == state.surface_transport_port_surfaces.end()
                   ? std::nullopt
                   : std::optional<std::uint32_t> { surface->second };
    }

    std::uint32_t read_little_word(
        std::span<const std::byte> bytes, std::size_t offset)
    {
        if (offset + sizeof(std::uint32_t) > bytes.size())
            return 0;
        std::uint32_t value = 0;
        for (std::size_t byte = 0; byte < sizeof(value); ++byte) {
            value |= std::to_integer<std::uint32_t>(bytes[offset + byte])
                     << (byte * 8U);
        }
        return value;
    }

    void write_little_word(
        std::span<std::byte> bytes, std::size_t offset, std::uint32_t value)
    {
        if (offset + sizeof(value) > bytes.size())
            return;
        for (std::size_t byte = 0; byte < sizeof(value); ++byte) {
            bytes[offset + byte] = static_cast<std::byte>(value >> (byte * 8U));
        }
    }

    std::optional<xnu::ipc::Right> right_for_disposition(
        std::uint32_t disposition)
    {
        switch (disposition) {
        case 16:
            return xnu::ipc::Right::Receive; // MOVE_RECEIVE
        case 17: // MOVE_SEND
        case 19: // COPY_SEND
        case 20:
            return xnu::ipc::Right::Send; // MAKE_SEND
        case 18: // MOVE_SEND_ONCE
        case 21:
            return xnu::ipc::Right::SendOnce; // MAKE_SEND_ONCE
        default:
            return std::nullopt;
        }
    }

    std::optional<xnu::ipc::Right> source_right_for_disposition(
        std::uint32_t disposition)
    {
        switch (disposition) {
        case 16:
            return xnu::ipc::Right::Receive; // MOVE_RECEIVE
        case 17:
            return xnu::ipc::Right::Send; // MOVE_SEND
        case 18:
            return xnu::ipc::Right::SendOnce; // MOVE_SEND_ONCE
        case 19:
            return xnu::ipc::Right::Send; // COPY_SEND
        case 20: // MAKE_SEND
        case 21:
            return xnu::ipc::Right::Receive; // MAKE_SEND_ONCE
        default:
            return std::nullopt;
        }
    }

    std::optional<std::uint32_t> target_task_for_port(
        const KernelSharedState& state, std::uint32_t caller,
        std::uint32_t task_name)
    {
        // A task name is a capability, not merely an object identifier.  XNU's
        // task/semaphore traps require a send right in the caller's ipc_space;
        // accepting a receive or dead-name entry here lets an unrelated port be
        // used as an owner and leaves teardown metadata attached to the wrong
        // PID.
        const auto task_object = resolve_name_with_right(
            state, caller, task_name, xnu::ipc::Right::Send);
        if (!task_object)
            return std::nullopt;
        const auto task = state.task_port_pids.find(*task_object);
        if (task == state.task_port_pids.end())
            return std::nullopt;
        if (const auto process = state.processes.find(task->second);
            process != state.processes.end() && process->second.exited) {
            return std::nullopt;
        }
        return task->second;
    }

    std::optional<std::uint32_t> target_task_name_for_port(
        const KernelSharedState& state, std::uint32_t caller,
        std::uint32_t task_name)
    {
        const auto object = resolve_name_with_right(
            state, caller, task_name, xnu::ipc::Right::Send);
        if (!object)
            return std::nullopt;
        if (const auto task = state.task_port_pids.find(*object);
            task != state.task_port_pids.end()) {
            if (const auto process = state.processes.find(task->second);
                process != state.processes.end() && process->second.exited) {
                return std::nullopt;
            }
            return task->second;
        }
        if (const auto task_name_port = state.task_name_port_pids.find(*object);
            task_name_port != state.task_name_port_pids.end()) {
            if (const auto process =
                    state.processes.find(task_name_port->second);
                process != state.processes.end() && process->second.exited) {
                return std::nullopt;
            }
            return task_name_port->second;
        }
        return std::nullopt;
    }

    std::optional<std::pair<std::uint32_t, std::uint32_t>> find_thread_owner(
        const KernelSharedState& state, std::uint32_t object)
    {
        for (const auto& [pid, threads] : state.task_thread_port_objects) {
            for (const auto& [slot, thread_object] : threads) {
                if (thread_object == object)
                    return std::pair { pid, slot };
            }
        }
        return std::nullopt;
    }

    std::optional<std::uint32_t> resolve_name_with_right(
        const KernelSharedState& state, std::uint32_t task, std::uint32_t name,
        xnu::ipc::Right right)
    {
        const auto entry = state.mach_namespaces.lookup(task, name);
        if (!entry || (entry->type & xnu::ipc::type_mask(right)) == 0) {
            return std::nullopt;
        }
        return entry->object;
    }

    std::optional<std::uint32_t> resolve_receive_object(
        const KernelSharedState& state, std::uint32_t task, std::uint32_t name)
    {
        const auto entry = state.mach_namespaces.lookup(task, name);
        if (!entry)
            return std::nullopt;
        if ((entry->type &
                xnu::ipc::type_mask(xnu::ipc::Right::Receive)) != 0 &&
            state.mach_port_objects.contains(entry->object)) {
            return entry->object;
        }
        if ((entry->type &
                xnu::ipc::type_mask(xnu::ipc::Right::PortSet)) != 0 &&
            state.mach_port_sets.contains(entry->object)) {
            return entry->object;
        }
        return std::nullopt;
    }

    bool receive_name_is_in_set(
        const KernelSharedState& state, std::uint32_t task, std::uint32_t name)
    {
        const auto object = resolve_name_with_right(
            state, task, name, xnu::ipc::Right::Receive);
        return object && state.mach_port_set_links_by_member.contains(*object);
    }

    std::optional<std::uint32_t> resolve_message_object(
        const KernelSharedState& state, std::uint32_t sender,
        std::uint32_t name)
    {
        // Kernel-originated notification messages store global object
        // identifiers directly. Every user-originated message must cross an
        // ipc_space lookup.
        if (sender == 0)
            return name;
        return state.mach_namespaces.resolve(sender, name);
    }

    bool port_has_send_rights_locked(
        const KernelSharedState& state, std::uint32_t object)
    {
        const auto inflight = state.mach_inflight_send_rights.find(object);
        const auto has_inflight =
            inflight != state.mach_inflight_send_rights.end() &&
            inflight->second != 0;
        const auto kernel_hold = state.mach_kernel_send_rights.find(object);
        const auto has_kernel_hold =
            kernel_hold != state.mach_kernel_send_rights.end() &&
            kernel_hold->second != 0;
        return state.mach_namespaces.right_reference_count(
                   object, xnu::ipc::Right::Send) != 0 ||
               has_inflight || has_kernel_hold;
    }

    bool enqueue_no_senders_notification_locked(
        KernelSharedState& state, std::uint32_t object)
    {
        const auto key = std::pair { object, mach_notify_no_senders };
        const auto request = state.mach_notifications.find(key);
        const auto port_object = state.mach_port_objects.lookup(object);
        if (request == state.mach_notifications.end() || !port_object ||
            request->second.notify_object == xnu::ipc::null_name ||
            port_has_send_rights_locked(state, object) ||
            port_object->make_send_count < request->second.sync) {
            return false;
        }
        // A notification request can outlive the task that supplied its
        // send-once right. XNU drops such a request when the notify port is
        // dead; do not recreate an unowned queue merely to hold an
        // undeliverable message.
        if (!state.mach_port_objects.contains(request->second.notify_object)) {
            state.mach_notifications.erase(request);
            return false;
        }

        KernelSharedState::MachMessage message;
        message.bytes.resize(36);
        write_little_word(message.bytes, 0, 18); // MOVE_SEND_ONCE
        write_little_word(
            message.bytes, 4, static_cast<std::uint32_t>(message.bytes.size()));
        write_little_word(message.bytes, 8, request->second.notify_object);
        write_little_word(message.bytes, 20, mach_notify_no_senders);
        write_little_word(message.bytes, 24, 0); // native NDR
        write_little_word(message.bytes, 28, 1); // little-endian NDR
        write_little_word(message.bytes, 32, port_object->make_send_count);
        message.destination = request->second.notify_object;
        const auto destination = message.destination;
        state.enqueue_mach_message_locked(destination, std::move(message));
        state.mach_notifications.erase(request);
        return true;
    }

    void enqueue_dead_name_notification_locked(KernelSharedState& state,
        std::uint32_t notify_object, std::uint32_t dead_name)
    {
        if (!state.mach_port_objects.contains(notify_object)) {
            return;
        }
        KernelSharedState::MachMessage message;
        message.bytes.resize(36);
        write_little_word(message.bytes, 0, 18); // MOVE_SEND_ONCE
        write_little_word(
            message.bytes, 4, static_cast<std::uint32_t>(message.bytes.size()));
        write_little_word(message.bytes, 8, notify_object);
        write_little_word(message.bytes, 20, mach_notify_dead_name);
        write_little_word(message.bytes, 24, 0);
        write_little_word(message.bytes, 28, 1);
        write_little_word(message.bytes, 32, dead_name);
        message.destination = notify_object;
        state.enqueue_mach_message_locked(notify_object, std::move(message));
    }

    void enqueue_port_deleted_notification_locked(KernelSharedState& state,
        std::uint32_t notify_object, std::uint32_t deleted_name)
    {
        if (!state.mach_port_objects.contains(notify_object)) {
            return;
        }
        KernelSharedState::MachMessage message;
        message.bytes.resize(36);
        write_little_word(message.bytes, 0, 18); // MOVE_SEND_ONCE
        write_little_word(
            message.bytes, 4, static_cast<std::uint32_t>(message.bytes.size()));
        write_little_word(message.bytes, 8, notify_object);
        write_little_word(message.bytes, 20, mach_notify_port_deleted);
        write_little_word(message.bytes, 24, 0);
        write_little_word(message.bytes, 28, 1);
        write_little_word(message.bytes, 32, deleted_name);
        message.destination = notify_object;
        state.enqueue_mach_message_locked(notify_object, std::move(message));
    }

    void enqueue_send_once_notification_locked(
        KernelSharedState& state, std::uint32_t object)
    {
        if (!state.mach_port_objects.contains(object)) {
            return;
        }
        KernelSharedState::MachMessage message;
        message.bytes.resize(24);
        write_little_word(message.bytes, 0, 18); // MOVE_SEND_ONCE
        write_little_word(
            message.bytes, 4, static_cast<std::uint32_t>(message.bytes.size()));
        write_little_word(message.bytes, 8, object);
        write_little_word(message.bytes, 20, mach_notify_send_once);
        message.destination = object;
        state.enqueue_mach_message_locked(object, std::move(message));
    }

    bool enqueue_port_destroyed_notification_locked(KernelSharedState& state,
        std::uint32_t notify_object, std::uint32_t receive_object)
    {
        if (!state.mach_port_objects.contains(notify_object)) {
            return false;
        }
        KernelSharedState::MachMessage message;
        message.bytes.resize(40);
        write_little_word(message.bytes, 0, 0x80000012U);
        write_little_word(
            message.bytes, 4, static_cast<std::uint32_t>(message.bytes.size()));
        write_little_word(message.bytes, 8, notify_object);
        write_little_word(message.bytes, 20, mach_notify_port_destroyed);
        write_little_word(message.bytes, 24, 1); // one port descriptor
        write_little_word(message.bytes, 28, receive_object);
        write_little_word(message.bytes, 36, 0x00100000U); // MOVE_RECEIVE
        message.destination = notify_object;
        // Keep the transferred receive right in the semantic sidecar as well as
        // in the wire descriptor.  Queue discard must terminate this right
        // instead of losing it when the notification endpoint disappears.
        message.port_transfers.push_back(
            KernelSharedState::MachMessage::PortTransfer { 28U, receive_object,
                std::nullopt, receive_object, xnu::ipc::Right::Receive,
                16U });
        state.enqueue_mach_message_locked(notify_object, std::move(message));
        return true;
    }

    void discard_mach_message_rights_locked(KernelSharedState& state,
        const KernelSharedState::MachMessage& message);

    void remove_port_object_locked(
        KernelSharedState& state, std::uint32_t object)
    {
        if (!state.mach_ports_being_removed.insert(object).second)
            return;
        // A receive may be asleep on this object without any queued message.
        // Make the scheduler revisit its cached namespace capability on the
        // next poll.
        state.note_mach_queue_topology_change_locked();
        state.mach_send_possible_armed_destinations.erase(object);
        struct RemovalGuard {
            KernelSharedState& state;
            std::uint32_t object;
            ~RemovalGuard() { state.mach_ports_being_removed.erase(object); }
        } removal_guard { state, object };

        static_cast<void>(
            state.remove_mach_port_set_member_from_all_locked(object));
        static_cast<void>(state.erase_mach_port_set_locked(object));
        if (auto queue = state.mach_queues.find(object);
            queue != state.mach_queues.end()) {
            auto discarded = std::move(queue->second);
            state.mach_queues.erase(queue);
            for (const auto& message : discarded) {
                discard_mach_message_rights_locked(state, message);
            }
            // A send-once notification aimed back at the dying object is itself
            // undeliverable and must not recreate the receive queue.
            state.mach_queues.erase(object);
        }
        if (const auto surface =
                state.surface_transport_port_surfaces.find(object);
            surface != state.surface_transport_port_surfaces.end()) {
            if (const auto port =
                    state.surface_transport_surface_ports.find(surface->second);
                port != state.surface_transport_surface_ports.end() &&
                port->second == object) {
                state.surface_transport_surface_ports.erase(port);
            }
            state.surface_transport_port_surfaces.erase(surface);
        }
        state.surface_transport_port_leases.erase(object);
        state.mach_port_contexts.erase(object);
        std::erase_if(state.audit_session_port_objects,
            [object](const auto& session) { return session.second == object; });
        static_cast<void>(state.mach_port_objects.erase(object));
        // Keep an in-flight count until every queued message carrying this
        // object is delivered or discarded.
        if (const auto inflight = state.mach_inflight_send_rights.find(object);
            inflight != state.mach_inflight_send_rights.end() &&
            inflight->second == 0) {
            state.mach_inflight_send_rights.erase(inflight);
        }
        state.task_port_pids.erase(object);
        state.task_name_port_pids.erase(object);
        for (auto task = state.task_thread_port_objects.begin();
            task != state.task_thread_port_objects.end();) {
            std::erase_if(task->second,
                [object](const auto& entry) { return entry.second == object; });
            if (task->second.empty()) {
                task = state.task_thread_port_objects.erase(task);
            } else {
                ++task;
            }
        }
        // A task special-port table stores raw global objects rather than
        // task-local names. Remove both entries owned by this task object and
        // references from surviving tasks when the backing ipc_port dies.
        for (auto special = state.task_special_ports.begin();
            special != state.task_special_ports.end();) {
            std::erase_if(special->second,
                [object](const auto& entry) { return entry.second == object; });
            if (special->first == object || special->second.empty()) {
                special = state.task_special_ports.erase(special);
            } else {
                ++special;
            }
        }
        if (auto task = state.task_exception_actions.find(object);
            task != state.task_exception_actions.end()) {
            std::vector<std::uint32_t> held_ports;
            for (const auto& action : task->second) {
                if (action.port_object != xnu::ipc::null_name &&
                    action.port_object != object) {
                    held_ports.push_back(action.port_object);
                }
            }
            state.task_exception_actions.erase(task);
            for (const auto held_port : held_ports)
                release_kernel_send_right_locked(state, held_port);
        }
        for (auto& [task_object, actions] : state.task_exception_actions) {
            static_cast<void>(task_object);
            for (auto& action : actions) {
                if (action.port_object == object)
                    action.port_object = xnu::ipc::null_name;
            }
        }
        // Kernel-held special-port references cannot outlive their backing
        // port. In-flight message holds are tracked separately and are
        // deliberately retained until their queue sidecar is delivered or
        // discarded.
        state.mach_kernel_send_rights.erase(object);
        state.mach_semaphores.erase(object);
        state.mach_timers.erase(object);
        state.mach_memory_entries.erase(object);
        state.mach_fileports.erase(object);
        state.iokit_iterators.erase(object);
        // Every IOServiceClose and receive-right teardown converges here.
        // Retire display timer registrations before erasing the generic
        // connection so a closed user client cannot keep scheduling VSync
        // callbacks indefinitely.
        kernel_iokit::display::close_connection_locked(state, object);
        state.iokit_connections.erase(object);
        state.iokit_audio_connections.erase(object);
        state.iokit_mbx_connections.erase(object);
        state.iokit_services.erase(object);
        state.iokit_interest_notifications.erase(object);
        if (state.mobile_framebuffer_service == object) {
            state.mobile_framebuffer_service = 0;
        }
        std::erase_if(state.ioaudio2_services,
            [object](const auto& service) { return service.second == object; });
        if (state.wifi_service == object) {
            state.wifi_service = 0;
        }
        if (state.wifi_interface_service == object) {
            state.wifi_interface_service = 0;
        }
        state.mach_notifications.erase(
            std::pair { object, mach_notify_port_destroyed });
        state.mach_notifications.erase(
            std::pair { object, mach_notify_no_senders });
    }

    void release_unreferenced_memory_entry_locked(
        KernelSharedState& state, std::uint32_t object)
    {
        if (!state.mach_memory_entries.contains(object) ||
            state.mach_namespaces.right_reference_count(
                object, xnu::ipc::Right::Send) != 0) {
            return;
        }
        const auto inflight = state.mach_inflight_send_rights.find(object);
        if (inflight != state.mach_inflight_send_rights.end() &&
            inflight->second != 0) {
            return;
        }
        const auto kernel_hold = state.mach_kernel_send_rights.find(object);
        if (kernel_hold != state.mach_kernel_send_rights.end() &&
            kernel_hold->second != 0) {
            return;
        }
        // Erase the backing entry before queue teardown (see the recursion
        // guard in remove_port_object_locked). Shared page mappings retain
        // their own GuestPageBacking references, so reclaiming the named port
        // is harmless to an already-established vm_map.
        state.mach_memory_entries.erase(object);
        remove_port_object_locked(state, object);
    }

    void release_unreferenced_fileport_locked(
        KernelSharedState& state, std::uint32_t object)
    {
        if (!state.mach_fileports.contains(object) ||
            state.mach_namespaces.right_reference_count(
                object, xnu::ipc::Right::Send) != 0) {
            return;
        }
        const auto inflight = state.mach_inflight_send_rights.find(object);
        if (inflight != state.mach_inflight_send_rights.end() &&
            inflight->second != 0) {
            return;
        }
        const auto kernel_hold = state.mach_kernel_send_rights.find(object);
        if (kernel_hold != state.mach_kernel_send_rights.end() &&
            kernel_hold->second != 0) {
            return;
        }
        state.mach_fileports.erase(object);
        remove_port_object_locked(state, object);
    }

    void terminate_exited_task_ports_locked(
        KernelSharedState& state, std::uint32_t pid)
    {
        std::vector<std::uint32_t> objects;
        for (const auto& [object, owner] : state.task_port_pids) {
            if (owner == pid)
                objects.push_back(object);
        }
        for (const auto& [object, owner] : state.task_name_port_pids) {
            if (owner == pid)
                objects.push_back(object);
        }
        if (const auto threads = state.task_thread_port_objects.find(pid);
            threads != state.task_thread_port_objects.end()) {
            for (const auto& [slot, object] : threads->second) {
                static_cast<void>(slot);
                objects.push_back(object);
            }
        }
        std::sort(objects.begin(), objects.end());
        objects.erase(
            std::unique(objects.begin(), objects.end()), objects.end());
        for (const auto object : objects) {
            if (state.mach_port_objects.contains(object))
                terminate_receive_object_locked(state, object);
        }
    }

    void terminate_exited_semaphores_locked(
        KernelSharedState& state, std::uint32_t pid)
    {
        std::vector<std::uint32_t> owned;
        for (const auto& [object, semaphore] : state.mach_semaphores) {
            if (semaphore.owner_pid == pid)
                owned.push_back(object);
        }
        for (const auto object : owned) {
            const auto semaphore = state.mach_semaphores.find(object);
            if (semaphore == state.mach_semaphores.end())
                continue;
            // semaphore_destroy on task teardown wakes every blocked thread
            // with KERN_TERMINATED, just as XNU's task-owned semaphore port
            // destruction.
            for (const auto waiter : semaphore->second.waiters)
                state.semaphore_terminations.insert(waiter);
            semaphore->second.waiters.clear();
            terminate_receive_object_locked(state, object);
        }

        // A process may have been waiting on a semaphore owned by another task.
        // Remove that waiter identity and any already-queued wake result so a
        // PID reuse cannot wake the wrong thread later.
        std::erase_if(state.semaphore_wakeups,
            [pid](const auto& waiter) { return waiter.first == pid; });
        std::erase_if(state.semaphore_terminations,
            [pid](const auto& waiter) { return waiter.first == pid; });
        for (auto& [object, semaphore] : state.mach_semaphores) {
            static_cast<void>(object);
            std::erase_if(semaphore.waiters,
                [pid](const auto& waiter) { return waiter.first == pid; });
        }
    }

    void cleanup_exited_process_metadata_locked(
        KernelSharedState& state, std::uint32_t pid)
    {
        // terminate_exited_task_ports_locked normally removes these entries via
        // remove_port_object_locked. The explicit erases make cleanup
        // idempotent for partially initialized/failing tasks as well.
        std::vector<std::uint32_t> task_objects;
        for (const auto& [object, owner] : state.task_port_pids) {
            if (owner == pid)
                task_objects.push_back(object);
        }
        std::vector<std::uint32_t> released_kernel_ports;
        for (const auto object : task_objects) {
            const auto special = state.task_special_ports.find(object);
            if (special == state.task_special_ports.end())
                continue;
            for (const auto& [which, port] : special->second) {
                static_cast<void>(which);
                if (port != xnu::ipc::null_name)
                    released_kernel_ports.push_back(port);
            }
            state.task_special_ports.erase(special);
        }
        for (const auto object : released_kernel_ports)
            release_kernel_send_right_locked(state, object);
        state.task_thread_port_objects.erase(pid);
        std::erase_if(state.task_port_pids,
            [pid](const auto& entry) { return entry.second == pid; });
        std::erase_if(state.task_name_port_pids,
            [pid](const auto& entry) { return entry.second == pid; });
        // Ordinary notification requests are owned by the target
        // ipc_entry/port, not by the task that supplied the send-once right. Do
        // not cancel them merely because that supplying task exits; XNU keeps
        // the kernel-held send-once alive until the target event or port
        // teardown.  Dead-name requests are different: their ipc_entry belongs
        // to this task's space. Run the normal cancellation path so a surviving
        // notify port receives MACH_NOTIFY_PORT_DELETED instead of silently
        // losing its send-once right.
        std::vector<std::pair<std::uint32_t, std::uint32_t>> dead_name_requests;
        for (const auto& [key, request] : state.mach_dead_name_notifications) {
            static_cast<void>(request);
            if (key.first == pid)
                dead_name_requests.push_back(key);
        }
        for (const auto& [task, name] : dead_name_requests)
            cancel_dead_name_notification_locked(state, task, name);

        // Bootstrap request/retry records are task-local observer state, not
        // Mach rights. Drop both sides on exit so a recycled PID cannot inherit
        // a stale service request or wake a retry belonging to its predecessor.
        for (auto pending = state.pending_bootstrap_service_requests.begin();
            pending != state.pending_bootstrap_service_requests.end();) {
            std::erase_if(pending->second, [pid](const auto& request) {
                return request.requester_process_id == pid;
            });
            if (pending->second.empty()) {
                pending =
                    state.pending_bootstrap_service_requests.erase(pending);
            } else {
                ++pending;
            }
        }
        state.pending_bootstrap_retries.erase(pid);

        // The ordinary namespace walk removes the backing objects through their
        // final Send/Receive names. Cover partially initialized calls as well:
        // an owner PID must not survive in IOKit/timer metadata after its
        // ipc_space is gone, otherwise a reused PID can inherit callbacks from
        // the old task.
        std::vector<std::uint32_t> owned_objects;
        for (const auto& [object, timer] : state.mach_timers) {
            if (timer.owner_pid == pid)
                owned_objects.push_back(object);
        }
        for (const auto& [object, connection] : state.iokit_connections) {
            if (connection.owner_pid == pid)
                owned_objects.push_back(object);
        }
        for (const auto& [object, notification] :
            state.iokit_interest_notifications) {
            if (notification.owner_pid == pid)
                owned_objects.push_back(object);
        }
        std::sort(owned_objects.begin(), owned_objects.end());
        owned_objects.erase(
            std::unique(owned_objects.begin(), owned_objects.end()),
            owned_objects.end());
        for (const auto object : owned_objects) {
            if (state.mach_port_objects.contains(object))
                terminate_receive_object_locked(state, object);
        }
        std::erase_if(
            state.iokit_notifications, [pid](const auto& notification) {
                return notification.owner_pid == pid;
            });
        for (auto it = state.iokit_display_vsync.begin();
            it != state.iokit_display_vsync.end();) {
            if (it->second.owner_pid != pid) {
                ++it;
                continue;
            }
            const auto connection_object = it->first;
            ++it;
            kernel_iokit::display::close_connection_locked(
                state, connection_object);
        }
    }

    void release_unreferenced_iokit_object_locked(
        KernelSharedState& state, std::uint32_t object)
    {
        const auto transient_iokit_object =
            state.iokit_iterators.contains(object) ||
            state.iokit_connections.contains(object) ||
            state.iokit_interest_notifications.contains(object);
        if (!transient_iokit_object ||
            state.mach_namespaces.right_reference_count(
                object, xnu::ipc::Right::Send) != 0) {
            return;
        }
        const auto inflight = state.mach_inflight_send_rights.find(object);
        if (inflight != state.mach_inflight_send_rights.end() &&
            inflight->second != 0) {
            return;
        }
        const auto kernel_hold = state.mach_kernel_send_rights.find(object);
        if (kernel_hold != state.mach_kernel_send_rights.end() &&
            kernel_hold->second != 0) {
            return;
        }
        // These objects model kernel-owned IOKit ports. Their receive right is
        // not present in a guest ipc_space, so ordinary task teardown can only
        // observe the final send right disappearing. Match IOKit's no-senders
        // lifetime and retire the backing object once no task or in-flight
        // message references it.
        remove_port_object_locked(state, object);
    }

    void cancel_dead_name_notification_locked(
        KernelSharedState& state, std::uint32_t task, std::uint32_t name)
    {
        const auto key = std::pair { task, name };
        const auto request = state.mach_dead_name_notifications.find(key);
        if (request == state.mach_dead_name_notifications.end())
            return;
        if (request->second.notify_object != xnu::ipc::null_name) {
            enqueue_port_deleted_notification_locked(
                state, request->second.notify_object, name);
        }
        state.mach_dead_name_notifications.erase(request);
    }

    bool consume_moved_right_locked(KernelSharedState& state,
        std::uint32_t task, std::uint32_t name, xnu::ipc::Right right,
        bool remains_in_flight)
    {
        const auto entry = state.mach_namespaces.lookup(task, name);
        if (!entry || (entry->type & xnu::ipc::type_mask(right)) == 0) {
            return false;
        }
        if (right == xnu::ipc::Right::Receive) {
            if (!state.mach_namespaces.remove_type(
                    task, name, xnu::ipc::type_mask(right))) {
                return false;
            }
            static_cast<void>(state.remove_mach_port_set_member_from_all_locked(
                entry->object));
            // XNU ipc_port_clear_receiver discards receiver-local state when
            // MOVE_RECEIVE puts the port in transit. The next receiver may
            // install its own context/guard without inheriting the old one.
            state.mach_port_contexts.erase(entry->object);
            static_cast<void>(
                state.mach_port_objects.clear_receiver(entry->object));
            return true;
        }
        if (right != xnu::ipc::Right::Send &&
            right != xnu::ipc::Right::SendOnce) {
            return false;
        }
        if (!state.mach_namespaces.modify_references(task, name, right, -1)) {
            return false;
        }
        if (!state.mach_namespaces.contains(task, name)) {
            cancel_dead_name_notification_locked(state, task, name);
        }
        if (right == xnu::ipc::Right::Send && !remains_in_flight) {
            static_cast<void>(
                enqueue_no_senders_notification_locked(state, entry->object));
        }
        return true;
    }

    void terminate_receive_object_locked(
        KernelSharedState& state, std::uint32_t object)
    {
        if (state.mach_ports_being_removed.contains(object))
            return;
        static_cast<void>(
            state.remove_mach_port_set_member_from_all_locked(object));

        const auto destroyed_key =
            std::pair { object, mach_notify_port_destroyed };
        const auto destroyed_request =
            state.mach_notifications.find(destroyed_key);
        if (destroyed_request != state.mach_notifications.end() &&
            destroyed_request->second.notify_object != xnu::ipc::null_name) {
            if (enqueue_port_destroyed_notification_locked(
                    state, destroyed_request->second.notify_object, object)) {
                state.mach_notifications.erase(destroyed_request);
                // The port remains active without a receiver until the
                // MOVE_RECEIVE descriptor is copied out by the notification
                // receiver.
                state.mach_port_contexts.erase(object);
                static_cast<void>(
                    state.mach_port_objects.clear_receiver(object));
                return;
            }
            // A dead notification endpoint cannot consume the receive right.
            // Drop the request and continue with ordinary ipc_right_terminate
            // semantics.
            state.mach_notifications.erase(destroyed_request);
        }
        state.mach_notifications.erase(destroyed_key);

        static_cast<void>(state.mach_namespaces.mark_object_dead(object));
        for (auto request = state.mach_dead_name_notifications.begin();
            request != state.mach_dead_name_notifications.end();) {
            if (request->second.target_object != object) {
                ++request;
                continue;
            }
            const auto task = request->first.first;
            const auto name = request->first.second;
            // XNU adds one dead-name uref for every generated notification.
            static_cast<void>(state.mach_namespaces.modify_references(
                task, name, xnu::ipc::Right::DeadName, 1));
            enqueue_dead_name_notification_locked(
                state, request->second.notify_object, name);
            request = state.mach_dead_name_notifications.erase(request);
        }
        remove_port_object_locked(state, object);
    }

    void release_inflight_send_right_locked(
        KernelSharedState& state, std::uint32_t object)
    {
        const auto inflight = state.mach_inflight_send_rights.find(object);
        if (inflight == state.mach_inflight_send_rights.end())
            return;
        if (inflight->second > 1) {
            --inflight->second;
        } else {
            state.mach_inflight_send_rights.erase(inflight);
        }
        static_cast<void>(
            enqueue_no_senders_notification_locked(state, object));
        release_unreferenced_fileport_locked(state, object);
    }

    void retain_kernel_send_right_locked(
        KernelSharedState& state, std::uint32_t object)
    {
        if (object != xnu::ipc::null_name)
            ++state.mach_kernel_send_rights[object];
    }

    void release_kernel_send_right_locked(
        KernelSharedState& state, std::uint32_t object)
    {
        const auto held = state.mach_kernel_send_rights.find(object);
        if (held == state.mach_kernel_send_rights.end())
            return;
        if (held->second > 1U) {
            --held->second;
            return;
        }
        state.mach_kernel_send_rights.erase(held);
        // The final kernel-held Send reference participates in no-senders just
        // like the final guest ipc_entry reference. Transient named entries and
        // IOKit ports may now be reclaimed, while ordinary service ports remain
        // owned by their explicit receive/send rights.
        static_cast<void>(
            enqueue_no_senders_notification_locked(state, object));
        release_unreferenced_memory_entry_locked(state, object);
        release_unreferenced_iokit_object_locked(state, object);
        release_unreferenced_fileport_locked(state, object);
    }

    void discard_mach_message_rights_locked(
        KernelSharedState& state, const KernelSharedState::MachMessage& message)
    {
        const auto discard = [&](std::uint32_t object,
                                 xnu::ipc::Right right) {
            switch (right) {
            case xnu::ipc::Right::Send:
                release_inflight_send_right_locked(state, object);
                break;
            case xnu::ipc::Right::Receive:
                terminate_receive_object_locked(state, object);
                break;
            case xnu::ipc::Right::SendOnce:
                enqueue_send_once_notification_locked(state, object);
                break;
            case xnu::ipc::Right::PortSet:
            case xnu::ipc::Right::DeadName:
                break;
            }
        };
        if (message.reply_object && message.reply_right) {
            discard(*message.reply_object, *message.reply_right);
        }
        if (message.destination_send_object) {
            release_inflight_send_right_locked(
                state, *message.destination_send_object);
        }
        for (const auto& transfer : message.port_transfers) {
            discard(transfer.object, transfer.right);
        }
    }

    bool destroy_port_name_locked(
        KernelSharedState& state, std::uint32_t task, std::uint32_t name)
    {
        const auto entry = state.mach_namespaces.lookup(task, name);
        if (!entry)
            return false;

        cancel_dead_name_notification_locked(state, task, name);
        if (!state.mach_namespaces.destroy_name(task, name))
            return false;

        const auto has = [&](xnu::ipc::Right right) {
            return (entry->type & xnu::ipc::type_mask(right)) != 0;
        };
        if (has(xnu::ipc::Right::Send)) {
            static_cast<void>(
                enqueue_no_senders_notification_locked(state, entry->object));
        }
        if (has(xnu::ipc::Right::SendOnce)) {
            enqueue_send_once_notification_locked(state, entry->object);
        }
        if (has(xnu::ipc::Right::Receive)) {
            terminate_receive_object_locked(state, entry->object);
        } else if (has(xnu::ipc::Right::PortSet)) {
            remove_port_object_locked(state, entry->object);
        }
        if (has(xnu::ipc::Right::Send)) {
            release_unreferenced_fileport_locked(state, entry->object);
        }
        return true;
    }

    std::uint32_t modify_port_references_locked(KernelSharedState& state,
        std::uint32_t task, std::uint32_t name, xnu::ipc::Right right,
        std::int32_t delta)
    {
        constexpr std::uint32_t kern_success = 0;
        constexpr std::uint32_t kern_invalid_name = 15;
        constexpr std::uint32_t kern_invalid_right = 17;
        constexpr std::uint32_t kern_invalid_value = 18;
        constexpr std::uint32_t kern_urefs_overflow = 19;

        if (name == xnu::ipc::null_name || name == xnu::ipc::dead_name) {
            return right == xnu::ipc::Right::Send ||
                           right == xnu::ipc::Right::SendOnce
                       ? kern_success
                       : kern_invalid_name;
        }
        const auto entry = state.mach_namespaces.lookup(task, name);
        if (!entry)
            return kern_invalid_name;
        const auto mask = xnu::ipc::type_mask(right);
        if ((entry->type & mask) == 0)
            return kern_invalid_right;
        const auto references =
            state.mach_namespaces.user_references(task, name, right)
                .value_or(0);

        if (right == xnu::ipc::Right::Receive ||
            right == xnu::ipc::Right::PortSet) {
            if (delta == 0)
                return kern_success;
            if (delta != -1)
                return kern_invalid_value;
            const auto remaining_type = entry->type & ~mask;
            if (right == xnu::ipc::Right::Receive && remaining_type == 0) {
                cancel_dead_name_notification_locked(state, task, name);
            }
            static_cast<void>(
                state.mach_namespaces.remove_type(task, name, mask));
            if (right == xnu::ipc::Right::Receive) {
                terminate_receive_object_locked(state, entry->object);
            } else {
                remove_port_object_locked(state, entry->object);
            }
            return kern_success;
        }

        if (right == xnu::ipc::Right::SendOnce) {
            if (delta == 0)
                return kern_success;
            if (delta != -1)
                return kern_invalid_value;
            static_cast<void>(
                state.mach_namespaces.remove_type(task, name, mask));
            // A receive name may temporarily be composite with a send-once
            // right when it is also used as a notification endpoint.  Releasing
            // only that send-once right does not delete the name, so its
            // dead-name request must remain registered.
            if (!state.mach_namespaces.contains(task, name)) {
                cancel_dead_name_notification_locked(state, task, name);
            }
            enqueue_send_once_notification_locked(state, entry->object);
            return kern_success;
        }

        const auto updated = static_cast<std::int64_t>(references) + delta;
        if (updated < 0)
            return kern_invalid_value;
        const auto maximum = right == xnu::ipc::Right::Send
                                 ? xnu::ipc::maximum_send_user_references
                                 : xnu::ipc::maximum_user_references;
        if (updated > maximum)
            return kern_urefs_overflow;
        if (!state.mach_namespaces.modify_references(
                task, name, right, delta)) {
            return kern_invalid_value;
        }
        if (updated == 0 && !state.mach_namespaces.contains(task, name)) {
            cancel_dead_name_notification_locked(state, task, name);
        }
        if (right == xnu::ipc::Right::Send && updated == 0) {
            static_cast<void>(
                enqueue_no_senders_notification_locked(state, entry->object));
            release_unreferenced_fileport_locked(state, entry->object);
        }
        return kern_success;
    }

    std::uint32_t insert_port_right_locked(KernelSharedState& state,
        std::uint32_t caller, std::uint32_t target_task,
        std::uint32_t target_name, std::uint32_t source_name,
        std::uint32_t disposition)
    {
        const auto right = right_for_disposition(disposition);
        const auto source_right = source_right_for_disposition(disposition);
        const auto source_object =
            source_right ? resolve_name_with_right(
                               state, caller, source_name, *source_right)
                         : std::nullopt;
        const auto existing =
            state.mach_namespaces.lookup(target_task, target_name);
        const auto existing_name = source_object
                                       ? state.mach_namespaces.name_for(
                                             target_task, *source_object)
                                       : std::nullopt;
        if (!right || !source_right || !source_object ||
            target_name == xnu::ipc::null_name ||
            target_name == xnu::ipc::dead_name) {
            return darwin::mach::invalid_value;
        }
        if (existing &&
            (existing->object != *source_object ||
                *right == xnu::ipc::Right::SendOnce)) {
            return darwin::mach::name_exists;
        }
        if (existing_name && *existing_name != target_name &&
            *right != xnu::ipc::Right::SendOnce) {
            return darwin::mach::right_exists;
        }

        const auto moved = disposition == 16U || disposition == 17U ||
                           disposition == 18U;
        if (!moved && existing && *right == xnu::ipc::Right::Send &&
            existing->user_references[static_cast<std::size_t>(
                xnu::ipc::Right::Send)] >=
                xnu::ipc::maximum_send_user_references) {
            return darwin::mach::user_references_overflow;
        }

        auto consumed = true;
        if (moved) {
            consumed = consume_moved_right_locked(
                state, caller, source_name, *source_right, true);
            if (!consumed)
                return darwin::mach::invalid_right;
        }
        const auto installed = state.mach_namespaces.install(target_task,
            target_name, *source_object, xnu::ipc::type_mask(*right));
        if (!installed) {
            if (moved && consumed) {
                static_cast<void>(state.mach_namespaces.install(caller,
                    source_name, *source_object,
                    xnu::ipc::type_mask(*source_right)));
            }
            if (moved && consumed &&
                *source_right == xnu::ipc::Right::Receive) {
                static_cast<void>(state.mach_port_objects.set_receive_owner(
                    *source_object, caller));
            }
            return darwin::mach::invalid_right;
        }

        if (disposition == darwin::mig_wire::disposition_make_send) {
            static_cast<void>(
                state.mach_port_objects.increment_make_send_count(
                    *source_object));
        }
        if (*right == xnu::ipc::Right::Receive) {
            static_cast<void>(state.mach_port_objects.set_receive_owner(
                *source_object, target_task));
        }
        return darwin::mach::success;
    }

    PortMembershipResult modify_port_membership_locked(KernelSharedState& state,
        std::uint32_t target_task, std::uint32_t member_name,
        std::uint32_t set_name, PortMembershipOperation operation)
    {
        constexpr std::uint32_t already_in_set = 11U;
        constexpr std::uint32_t not_in_set = 12U;
        PortMembershipResult result;
        const auto member =
            state.mach_namespaces.lookup(target_task, member_name);
        const auto set = set_name != xnu::ipc::null_name
                             ? state.mach_namespaces.lookup(
                                   target_task, set_name)
                             : std::nullopt;
        result.member_object = member ? member->object : 0U;
        result.set_object = set ? set->object : 0U;
        const auto has = [](const xnu::ipc::NameEntry& entry,
                             xnu::ipc::Right right) {
            return (entry.type & xnu::ipc::type_mask(right)) != 0U;
        };
        if (!member) {
            result.result = member_name == xnu::ipc::null_name
                                ? darwin::mach::invalid_right
                                : darwin::mach::invalid_name;
        } else if (!has(*member, xnu::ipc::Right::Receive)) {
            result.result = darwin::mach::invalid_right;
        } else if (operation != PortMembershipOperation::Move ||
                   set_name != xnu::ipc::null_name) {
            if (!set) {
                result.result = set_name == xnu::ipc::null_name
                                    ? darwin::mach::invalid_right
                                    : darwin::mach::invalid_name;
            } else if (!has(*set, xnu::ipc::Right::PortSet)) {
                result.result = darwin::mach::invalid_right;
            }
        }

        if (result.result == darwin::mach::success) {
            if (operation == PortMembershipOperation::Move) {
                const auto removed =
                    state.remove_mach_port_set_member_from_all_locked(
                        member->object);
                if (set) {
                    static_cast<void>(state.insert_mach_port_set_member_locked(
                        set->object, member->object));
                } else if (!removed) {
                    result.result = not_in_set;
                }
            } else if (operation == PortMembershipOperation::Insert) {
                if (!state.insert_mach_port_set_member_locked(
                        set->object, member->object)) {
                    result.result = already_in_set;
                }
            } else if (!state.extract_mach_port_set_member_locked(
                           set->object, member->object)) {
                result.result = not_in_set;
            }
        }
        if (result.set_object != 0U) {
            const auto members = state.mach_port_sets.find(result.set_object);
            if (members != state.mach_port_sets.end())
                result.set_member_count = members->second.size();
        }
        return result;
    }

} // namespace mach_support

} // namespace shade
