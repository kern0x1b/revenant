// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Initialize and inherit guest task-port identities and capabilities.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/kern/ipc_tt.c

#pragma once

#include <cstdint>

namespace shade {

struct KernelSharedState;
struct ProcessContext;

namespace mach_task_identity {

    // libSystem exposes these task-local names during the earliest iPhoneOS 1.0
    // startup. They may repeat in every ipc_space; they are never global object
    // identifiers.
    inline constexpr std::uint32_t initial_task_self_name = 0x103U;
    inline constexpr std::uint32_t initial_thread_self_name = 0x203U;
    inline constexpr std::uint32_t initial_host_self_name = 0x303U;
    inline constexpr std::uint32_t initial_bootstrap_name = 0x503U;
    inline constexpr std::uint32_t initial_clock_name = 0x603U;
    inline constexpr std::uint32_t initial_calendar_clock_name = 0x613U;
    inline constexpr std::uint32_t initial_io_master_name = 0x703U;
    inline constexpr std::uint32_t initial_io_registry_options_name = 0x713U;

    // Installs the task-local names for PID 1 while allocating distinct global
    // ipc_port objects for its task, thread, and bootstrap/job ports.
    [[nodiscard]] bool initialize_root(
        KernelSharedState& state, ProcessContext& process);

    // Creates a child ipc_space. Task/thread self names intentionally reuse the
    // initial local ABI values; the parent receives a separately copied-out
    // child task capability, and the bootstrap special-port object is inherited
    // without treating either task's local name as an object identifier.
    [[nodiscard]] bool inherit_child(KernelSharedState& state,
        const ProcessContext& parent, ProcessContext& child,
        bool inherit_registered_ports);

} // namespace mach_task_identity
} // namespace shade
