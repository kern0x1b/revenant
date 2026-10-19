// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Handle guest tracing, debug controls and debugger-attachment
// policy.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/kern/kdebug.c
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/kern/mach_process.c

#include "kernel/kernel.hpp"

#include "kernel/darwin_abi.hpp"

#include "../support.hpp"

#include <cstdint>
#include <string>

namespace emulator {

bool CompatibilityKernel::dispatch_bsd_debug(Cpu& cpu, std::uint32_t number)
{
    if (number == darwin::syscall::ptrace) {
        const auto request = cpu.registers()[0];
        const auto target_pid = cpu.registers()[1];

        if (request == darwin::ptrace_request::deny_attach) {
            output_.write("[debug] ptrace PT_DENY_ATTACH pid=" +
                          std::to_string(process_.pid) + "\n");
            bsd_success(cpu, 0);
            return true;
        }

        if (request == darwin::ptrace_request::attach && target_pid < 2) {
            bsd_error(cpu, darwin::error::operation_not_permitted);
            return true;
        }

        output_.write(
            "[debug] unsupported ptrace request=" + std::to_string(request) +
            " target=" + std::to_string(target_pid) + "\n");
        bsd_error(cpu, 45);
        return true;
    }

    if (number != 180)
        return false;

    bsd_error(cpu, bsd_support::invalid_argument);
    return true;
}

}
