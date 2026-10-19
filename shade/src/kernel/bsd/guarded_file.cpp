// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// Guarded file descriptors reuse the normal VFS and descriptor lifecycle.
// ABI reference: XNU bsd/kern/kern_guarded.c, guarded_open_np/guarded_close_np.
#include "kernel/kernel.hpp"
#include "kernel/darwin_abi.hpp"
#include "support.hpp"
#include <string>
namespace shade {
bool CompatibilityKernel::reject_guarded_descriptor(
    Cpu& cpu, std::uint32_t fd, std::uint32_t flags)
{
    const auto guard = descriptor_guards_.find(fd);
    if (guard == descriptor_guards_.end() || (guard->second.flags & flags) == 0U)
        return false;
    output_.line("[guard] fatal descriptor violation pid=" + std::to_string(process_.pid) +
        " fd=" + std::to_string(fd));
    // Preserve the fatal default disposition without performing the forbidden
    // operation. Mach EXC_GUARD exception-port delivery is not modeled yet.
    exit_process(0U, darwin::signal::kill);
    cpu.halt(Umbra::HaltReason::UserDefined1);
    return true;
}

void CompatibilityKernel::dispatch_bsd_guarded_file(Cpu& cpu, std::uint32_t number)
{
    auto& registers = cpu.registers();
    if (number == 443U) {
        const auto attributes = registers[1];
        if ((attributes & DarwinFileGuard::duplicate) == 0U ||
            (attributes & ~0x0fU) != 0U) {
            bsd_error(cpu, darwin::error::invalid_argument);
            return;
        }
        const auto guard = memory_.read64(registers[0]);
        if (!guard || *guard == 0U) {
            bsd_error(cpu, guard ? darwin::error::invalid_argument
                                : darwin::error::bad_address);
            return;
        }
        dispatch_bsd_kqueue(cpu, darwin::syscall::kqueue);
        if ((cpu.cpsr() & bsd_support::carry_flag) != 0U)
            return;
        const auto fd = registers[0];
        descriptor_guards_.emplace(fd, DarwinFileGuard { *guard, attributes });
        descriptor_flags_[fd] = 1U;
        output_.write("[guard] kqueue pid=" + std::to_string(process_.pid) +
            " fd=" + std::to_string(fd) + "\n");
        return;
    }
    const auto guard = memory_.read64(registers[1]);
    if (!guard) {
        bsd_error(cpu, darwin::error::bad_address);
        return;
    }
    if (number == 441U) {
        const auto attributes = registers[2];
        const auto flags = registers[3];
        const auto mode = registers[4];
        constexpr std::uint32_t close_on_exec = 0x01000000U;
        if (*guard == 0U || (flags & close_on_exec) == 0U ||
            (attributes & DarwinFileGuard::duplicate) == 0U ||
            (attributes & ~0x0fU) != 0U) {
            bsd_error(cpu, darwin::error::invalid_argument);
            return;
        }
        registers[1] = flags;
        registers[2] = mode;
        dispatch_bsd_filesystem(cpu, 5U);
        if ((cpu.cpsr() & bsd_support::carry_flag) != 0U)
            return;
        const auto fd = registers[0];
        descriptor_guards_.emplace(fd, DarwinFileGuard { *guard, attributes });
        descriptor_flags_[fd] = 1U;
        output_.write("[guard] open pid=" + std::to_string(process_.pid) +
            " fd=" + std::to_string(fd) + "\n");
        return;
    }
    const auto fd = registers[0];
    const auto found = descriptor_guards_.find(fd);
    if (found == descriptor_guards_.end()) {
        bsd_error(cpu, export_descriptor(fd) ? darwin::error::invalid_argument
                                           : bsd_support::bad_file_descriptor);
        return;
    }
    if (found->second.identifier != *guard) {
        // A mismatched guarded close is fatal even if ordinary close is allowed.
        reject_guarded_descriptor(cpu, fd, DarwinFileGuard::duplicate);
        return;
    }
    if (release_file_descriptor(fd))
        bsd_success(cpu, 0U);
    else
        bsd_error(cpu, bsd_support::bad_file_descriptor);
}
} // namespace shade
