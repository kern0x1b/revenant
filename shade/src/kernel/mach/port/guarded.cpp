// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "guarded.hpp"

#include "../support.hpp"
#include "foundation/address_space.hpp"
#include "kernel/darwin_abi.hpp"
#include "kernel/kernel_shared_state.hpp"
#include "mach/mig_wire_abi.hpp"

#include <bit>

namespace shade {

std::uint32_t dispatch_guarded_port_trap(KernelSharedState& state,
    AddressSpace& memory, std::uint32_t task,
    const std::array<std::uint32_t, 16>& registers, std::uint32_t trap)
{
    using namespace mach_support;
    using namespace xnu::ipc;
    constexpr std::uint32_t context_as_guard = 0x01U;
    constexpr std::uint32_t queue_limit_option = 0x02U;
    constexpr std::uint32_t temporary_owner = 0x04U;
    constexpr std::uint32_t insert_send = 0x10U;
    constexpr std::uint32_t strict = 0x20U;
    const auto wide = [&](std::size_t index) {
        return static_cast<std::uint64_t>(registers[index]) |
               (static_cast<std::uint64_t>(registers[index + 1]) << 32U);
    };

    if (trap == 24U) { // mach_port_construct
        const auto options = registers[1];
        const auto output = registers[4];
        if (!memory.accessible(options, 16U, MemoryPermission::Read) ||
            !memory.accessible(output, 4U, MemoryPermission::Write))
            return darwin::mach::invalid_address;
        const auto flags = *memory.read32(options);
        const auto limit = *memory.read32(options + 4U);
        if ((flags & ~0x7fU) != 0 ||
            ((flags & strict) != 0 && (flags & context_as_guard) == 0))
            return darwin::mach::invalid_argument;
        if ((flags & queue_limit_option) != 0 && limit > maximum_queue_limit)
            return darwin::mach::invalid_value;

        const auto object = state.allocate_mach_object();
        const auto name = state.mach_namespaces.allocate(
            task, object, type_mask(Right::Receive));
        if (!name)
            return darwin::mach::no_space;
        static_cast<void>(state.mach_port_objects.create(object, task));
        state.mach_queues.try_emplace(object);
        state.mach_port_contexts[object] = wide(2);
        if ((flags & context_as_guard) != 0)
            static_cast<void>(state.mach_port_objects.set_guard(
                object, wide(2), (flags & strict) != 0));
        if ((flags & queue_limit_option) != 0)
            static_cast<void>(
                state.mach_port_objects.set_queue_limit(object, limit));
        if ((flags & temporary_owner) != 0)
            static_cast<void>(
                state.mach_port_objects.set_temporary_owner(object));
        // Importance/de-nap receivers use the kernel's existing queued-message
        // importance accounting; no additional host scheduling is required.
        auto result = darwin::mach::success;
        if ((flags & insert_send) != 0)
            result = insert_port_right_locked(state, task, task, *name, *name,
                darwin::mig_wire::disposition_make_send);
        if (result == darwin::mach::success && !memory.write32(output, *name))
            result = darwin::mach::invalid_address;
        if (result != darwin::mach::success)
            static_cast<void>(destroy_port_name_locked(state, task, *name));
        return result;
    }

    const auto name = registers[1];
    const auto entry = state.mach_namespaces.lookup(task, name);
    if (!entry)
        return darwin::mach::invalid_name;
    if ((entry->type & type_mask(Right::Receive)) == 0)
        return darwin::mach::invalid_right;
    const auto port = state.mach_port_objects.lookup(entry->object);
    if (!port)
        return darwin::mach::invalid_right;
    const auto guard = wide(trap == 25U ? 3U : 2U);
    if (trap == 41U) { // mach_port_guard
        if (port->guard || state.mach_port_contexts[entry->object] != 0)
            return darwin::mach::invalid_argument;
        static_cast<void>(state.mach_port_objects.set_guard(
            entry->object, guard, registers[4] != 0));
        state.mach_port_contexts[entry->object] = guard;
        return darwin::mach::success;
    }
    if ((port->guard && *port->guard != guard) || (trap == 42U && !port->guard))
        return darwin::mach::invalid_argument;
    if (trap == 42U) { // mach_port_unguard
        static_cast<void>(
            state.mach_port_objects.set_guard(entry->object, std::nullopt));
        state.mach_port_contexts[entry->object] = 0;
        return darwin::mach::success;
    }

    // Destruct drops the receive right and only the requested send references.
    // The common right-lifetime path handles queued rights and notifications.
    const auto delta = std::bit_cast<std::int32_t>(registers[2]);
    if (delta > 0)
        return darwin::mach::invalid_value;
    if (delta != 0) {
        const auto result = modify_port_references_locked(
            state, task, name, Right::Send, delta);
        if (result != darwin::mach::success)
            return result;
    }
    return modify_port_references_locked(state, task, name, Right::Receive, -1);
}

} // namespace shade
