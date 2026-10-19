// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Dispatch guest mandatory-access-control policy queries and
// supported operations.

#include "kernel/kernel.hpp"

#include "kernel/darwin_abi.hpp"

#include "../support.hpp"
#include "sandbox.hpp"
#include "extensions.hpp"

#include <cstdint>
#include <string>

namespace shade {

bool CompatibilityKernel::dispatch_bsd_security(Cpu& cpu, std::uint32_t number)
{
    if (number != darwin::syscall::mac_syscall)
        return false;

    const auto& registers = cpu.registers();
    const auto policy = memory_.read_c_string(registers[0], 128U);
    if (!policy) {
        bsd_error(cpu, darwin::error::bad_address);
        return true;
    }

    if (*policy == "Sandbox") {
        auto result = bsd::sandbox::dispatch(
            memory_, shared_state_->darwin_abi.sandbox_abi,
            registers[1], registers[2]);
        if (result == bsd::sandbox::CallResult::Unsupported &&
            shared_state_->darwin_abi.sandbox_abi == DarwinSandboxAbi::Wide64Arguments &&
            registers[1] >= 5U && registers[1] <= 7U) {
            const std::lock_guard lock { shared_state_->mach_mutex };
            if (!shared_state_->sandbox_extensions)
                shared_state_->sandbox_extensions =
                    std::make_shared<bsd::sandbox::Extensions>();
            result = shared_state_->sandbox_extensions->dispatch(
                memory_, process_.pid, registers[1], registers[2]);
            output_.write("[security] sandbox-extension pid=" +
                std::to_string(process_.pid) + " call=" + std::to_string(registers[1]) +
                " result=" + std::to_string(static_cast<int>(result)) + "\n");
        }
        switch (result) {
        case bsd::sandbox::CallResult::Success:
            bsd_success(cpu, 0);
            return true;
        case bsd::sandbox::CallResult::BadAddress:
            bsd_error(cpu, darwin::error::bad_address);
            return true;
        case bsd::sandbox::CallResult::InvalidArgument:
            bsd_error(cpu, darwin::error::invalid_argument);
            return true;
        case bsd::sandbox::CallResult::NoMemory:
            bsd_error(cpu, darwin::error::no_memory);
            return true;
        case bsd::sandbox::CallResult::Unsupported:
            break;
        }
    }

    // Preserve ENOSYS for policy operations whose ABI or state is not
    // represented by an emulated provider.
    output_.write("[security] unsupported mac_syscall pid=" +
                  std::to_string(process_.pid) + " policy=" + *policy +
                  " call=" + std::to_string(registers[1]) + "\n");
    bsd_error(cpu, bsd_support::not_implemented); // ENOSYS
    return true;
}

} // namespace shade
