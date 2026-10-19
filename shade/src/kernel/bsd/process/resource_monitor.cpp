// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "resource_monitor.hpp"
#include "foundation/address_space.hpp"
#include "foundation/darwin_errno.hpp"
#include "kernel/kernel_shared_state.hpp"
#include <mutex>

namespace shade::kernel_bsd::resource_monitor {

std::uint32_t control(AddressSpace& memory, KernelSharedState& state,
    const ProcessContext& caller, std::uint32_t pid, std::uint32_t flavor,
    std::uint32_t argument)
{
    // XNU proc_rlimit_control uses an explicit PID, including for self.
    {
        std::lock_guard lock { state.mach_mutex };
        const auto target = state.processes.find(pid);
        if (target == state.processes.end() || target->second.exited)
            return darwin::error::no_such_process;
        if (pid != caller.pid && caller.effective_uid != 0U && caller.uid != 0U &&
            caller.effective_uid != target->second.effective_uid &&
            caller.uid != target->second.effective_uid)
            return darwin::error::permission_denied;
    }
    constexpr std::uint32_t wakeups_monitor = 1;
    constexpr std::uint32_t cpu_monitor = 2;
    constexpr std::uint32_t enable = 1;
    constexpr std::uint32_t disable = 2;
    constexpr std::uint32_t get_parameters = 4;
    constexpr std::uint32_t set_defaults = 8;
    constexpr std::uint32_t cpu_make_fatal = 0x1000;
    if (flavor == cpu_monitor)
        return (argument & cpu_make_fatal) != 0U
            ? darwin::error::not_supported : darwin::error::invalid_argument;
    if (flavor != wakeups_monitor)
        return darwin::error::invalid_argument;
    if (argument == 0U ||
        !memory.accessible(argument, 8U, MemoryPermission::Read))
        return darwin::error::bad_address;
    auto flags = *memory.read32(argument);
    auto rate = *memory.read32(argument + 4U);
    if ((flags & get_parameters) != 0U) {
        // No interrupt-wakeup ledger is active. GET takes precedence over
        // the other flags and reports the native disabled representation.
        flags = disable;
        rate = 0xffff'ffffU;
    } else if ((flags & enable) != 0U) {
        if ((flags & set_defaults) == 0U && static_cast<std::int32_t>(rate) < 0)
            return darwin::error::invalid_argument;
        // Do not claim enforcement when there is no guest accounting source.
        return darwin::error::not_supported;
    }
    if (!memory.accessible(argument, 8U, MemoryPermission::Write) ||
        !memory.write32(argument, flags) || !memory.write32(argument + 4U, rate))
        return darwin::error::bad_address;
    return 0;
}

} // namespace shade::kernel_bsd::resource_monitor
