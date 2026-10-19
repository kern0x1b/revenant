// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Declare shared Mach dispatch, right-lifetime and virtual-memory
// helpers.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/ipc/ipc_right.c
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/kern/ipc_tt.c

#pragma once

#include "kernel/kernel_shared_state.hpp"

#include <cstddef>
#include <cstdint>
#include <optional>
#include <span>
#include <string>

namespace shade {

class AddressSpace;
class SurfaceStore;

namespace mach_support {

    template <typename Routine>
    constexpr std::uint32_t mig_message_id(Routine routine)
    {
        return static_cast<std::uint32_t>(routine);
    }

    inline constexpr std::size_t maximum_message_io = 16U * 1024U * 1024U;
    // OOL memory descriptors describe VM-backed data and are not part of the
    // inline Mach message size. Keep a separate host-allocation guard large
    // enough for the fixed-size buffers used by system MIG servers.
    inline constexpr std::size_t maximum_ool_payload = 64U * 1024U * 1024U;
    inline constexpr std::uint32_t default_dynamic_base = 0x10000000U;
    inline constexpr std::uint32_t ool_receive_base = 0x1d000000U;
    inline constexpr std::uint32_t ool_results_base = 0x1f000000U;
    inline constexpr std::uint32_t mach_notify_port_deleted = 65;
    inline constexpr std::uint32_t mach_notify_port_destroyed = 69;
    inline constexpr std::uint32_t mach_notify_no_senders = 70;
    inline constexpr std::uint32_t mach_notify_send_possible = 66;
    inline constexpr std::uint32_t mach_notify_send_once = 71;
    inline constexpr std::uint32_t mach_notify_dead_name = 72;

    [[nodiscard]] std::string mig_message_label(std::uint32_t identifier);
    [[nodiscard]] bool guest_region_overlaps(
        const AddressSpace& memory, std::uint32_t address, std::uint32_t size);
    [[nodiscard]] std::optional<std::uint32_t> find_free_guest_region(
        const AddressSpace& memory, std::uint32_t start, std::uint32_t size,
        std::uint32_t alignment_mask = 0U);

    struct VmAllocationResult {
        std::uint32_t result { };
        std::uint32_t address { };
    };

    // vm_allocate is exposed through both MIG and Darwin's direct kernel-RPC
    // traps. Keep address selection and overlap handling identical at both
    // entry points.
    [[nodiscard]] VmAllocationResult allocate_guest_vm_region(
        AddressSpace& memory, std::uint32_t requested_address,
        std::uint32_t size, std::uint32_t flags,
        std::uint32_t alignment_mask = 0U);

    [[nodiscard]] std::uint32_t read_little_word(
        std::span<const std::byte> bytes, std::size_t offset);
    void write_little_word(
        std::span<std::byte> bytes, std::size_t offset, std::uint32_t value);

    [[nodiscard]] std::optional<xnu::ipc::Right> right_for_disposition(
        std::uint32_t disposition);
    [[nodiscard]] std::optional<xnu::ipc::Right>
    source_right_for_disposition(std::uint32_t disposition);
    [[nodiscard]] std::optional<std::uint32_t> target_task_for_port(
        const KernelSharedState& state, std::uint32_t caller,
        std::uint32_t task_name);
    [[nodiscard]] std::optional<std::uint32_t> target_task_name_for_port(
        const KernelSharedState& state, std::uint32_t caller,
        std::uint32_t task_name);
    [[nodiscard]] std::optional<std::pair<std::uint32_t, std::uint32_t>>
    find_thread_owner(const KernelSharedState& state, std::uint32_t object);
    [[nodiscard]] std::optional<std::uint32_t> resolve_name_with_right(
        const KernelSharedState& state, std::uint32_t task, std::uint32_t name,
        xnu::ipc::Right right);
    // mach_msg receive accepts only a task-local receive right or port-set
    // right. A generic namespace resolve is intentionally insufficient because
    // send-only names resolve to the same global object but are not receive
    // capabilities.
    [[nodiscard]] std::optional<std::uint32_t> resolve_receive_object(
        const KernelSharedState& state, std::uint32_t task, std::uint32_t name);
    [[nodiscard]] bool receive_name_is_in_set(
        const KernelSharedState& state, std::uint32_t task, std::uint32_t name);
    [[nodiscard]] std::optional<std::uint32_t> resolve_message_object(
        const KernelSharedState& state, std::uint32_t sender,
        std::uint32_t name);

    [[nodiscard]] std::uint32_t create_surface_transport_send_right_locked(
        KernelSharedState& state, SurfaceStore& surfaces,
        std::uint32_t process_id, std::uint32_t surface_id);
    [[nodiscard]] std::optional<std::uint32_t> resolve_surface_transport_locked(
        const KernelSharedState& state, std::uint32_t process_id,
        std::uint32_t port_name);

    [[nodiscard]] bool port_has_send_rights_locked(
        const KernelSharedState& state, std::uint32_t object);
    [[nodiscard]] bool enqueue_no_senders_notification_locked(
        KernelSharedState& state, std::uint32_t object);
    void enqueue_dead_name_notification_locked(KernelSharedState& state,
        std::uint32_t notify_object, std::uint32_t dead_name);
    void enqueue_port_deleted_notification_locked(KernelSharedState& state,
        std::uint32_t notify_object, std::uint32_t deleted_name);
    void enqueue_send_once_notification_locked(
        KernelSharedState& state, std::uint32_t object);
    [[nodiscard]] bool enqueue_port_destroyed_notification_locked(
        KernelSharedState& state, std::uint32_t notify_object,
        std::uint32_t receive_object);
    void discard_mach_message_rights_locked(KernelSharedState& state,
        const KernelSharedState::MachMessage& message);
    void remove_port_object_locked(
        KernelSharedState& state, std::uint32_t object);
    // Named VM entries are kernel-owned send-only ports. Reclaim them only
    // after the last namespace/in-flight Send reference disappears; unlike
    // generic ipc_port objects this cannot invalidate a receive right or a
    // service port.
    void release_unreferenced_memory_entry_locked(
        KernelSharedState& state, std::uint32_t object);
    void release_unreferenced_fileport_locked(
        KernelSharedState& state, std::uint32_t object);
    // Task and thread ports are kernel-owned objects. When their task exits,
    // all outstanding Send names must become DeadName before the backing
    // indexes are dropped, matching ipc_space/task termination in XNU.
    void terminate_exited_task_ports_locked(
        KernelSharedState& state, std::uint32_t pid);
    void terminate_exited_semaphores_locked(
        KernelSharedState& state, std::uint32_t pid);
    void cleanup_exited_process_metadata_locked(
        KernelSharedState& state, std::uint32_t pid);
    void release_unreferenced_iokit_object_locked(
        KernelSharedState& state, std::uint32_t object);
    void cancel_dead_name_notification_locked(
        KernelSharedState& state, std::uint32_t task, std::uint32_t name);
    [[nodiscard]] bool consume_moved_right_locked(KernelSharedState& state,
        std::uint32_t task, std::uint32_t name, xnu::ipc::Right right,
        bool remains_in_flight);
    void terminate_receive_object_locked(
        KernelSharedState& state, std::uint32_t object);
    void release_inflight_send_right_locked(
        KernelSharedState& state, std::uint32_t object);
    void retain_kernel_send_right_locked(
        KernelSharedState& state, std::uint32_t object);
    void release_kernel_send_right_locked(
        KernelSharedState& state, std::uint32_t object);
    [[nodiscard]] bool destroy_port_name_locked(
        KernelSharedState& state, std::uint32_t task, std::uint32_t name);
    [[nodiscard]] std::uint32_t modify_port_references_locked(
        KernelSharedState& state, std::uint32_t task, std::uint32_t name,
        xnu::ipc::Right right, std::int32_t delta);
    [[nodiscard]] std::uint32_t insert_port_right_locked(
        KernelSharedState& state, std::uint32_t caller,
        std::uint32_t target_task, std::uint32_t target_name,
        std::uint32_t source_name, std::uint32_t disposition);

    enum class PortMembershipOperation : std::uint8_t {
        Move,
        Insert,
        Extract,
    };
    struct PortMembershipResult {
        std::uint32_t result { };
        std::uint32_t member_object { };
        std::uint32_t set_object { };
        std::size_t set_member_count { };
    };
    [[nodiscard]] PortMembershipResult modify_port_membership_locked(
        KernelSharedState& state, std::uint32_t target_task,
        std::uint32_t member_name, std::uint32_t set_name,
        PortMembershipOperation operation);

} // namespace mach_support
} // namespace shade
