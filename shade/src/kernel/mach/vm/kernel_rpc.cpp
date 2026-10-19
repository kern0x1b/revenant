// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Dispatch direct kernel RPC traps for guest virtual-memory
// operations.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/vm_map.defs
// https://github.com/apple-oss-distributions/xnu/blob/xnu-1699.22.73/osfmk/mach/mach_vm.defs
// https://github.com/apple-oss-distributions/xnu/blob/xnu-1699.22.73/osfmk/kern/ipc_mig.c

#include "kernel/kernel.hpp"

#include "kernel/darwin_abi.hpp"

#include "../support.hpp"

#include <cstdint>
#include <mutex>

namespace shade {

using namespace mach_support;

namespace {

    MemoryPermission memory_permissions(std::uint32_t protection)
    {
        MemoryPermission result = MemoryPermission::None;
        if ((protection & 1U) != 0)
            result |= MemoryPermission::Read;
        if ((protection & 2U) != 0)
            result |= MemoryPermission::Write;
        if ((protection & 4U) != 0)
            result |= MemoryPermission::Execute;
        return result;
    }

} // namespace

bool CompatibilityKernel::dispatch_mach_vm_kernel_rpc_trap(
    Cpu& cpu, std::uint32_t trap)
{
    // ARM32 libsystem exports both 64-bit mach_vm_* and pointer-sized
    // vm_* direct traps. Keep their fast paths in one handler;
    // the MIG entry points remain the fallback when the target is not valid.
    if (trap != 10U && trap != 11U && trap != 12U && trap != 13U &&
        trap != 14U && trap != 15U)
        return false;

    auto& registers = cpu.registers();
    if (shared_state_->darwin_abi.mach_kernel_rpc ==
            DarwinMachKernelRpcAbi::DirectWideVmAndPortTraps &&
        (trap == 11U || trap == 13U || trap == 15U)) {
        // The wide-only trap table removed vm_allocate/vm_deallocate and
        // repurposed slot 15 from vm_protect to mach_vm_map. Let libsystem's
        // native slow path use the complete MIG mapping implementation.
        registers[0] = darwin::mach_message::send_invalid_destination;
        return true;
    }
    {
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        const auto target = target_task_for_port(
            *shared_state_, process_.pid, registers[0]);
        if (!target || *target != process_.pid) {
            registers[0] = darwin::mach_message::send_invalid_destination;
            return true;
        }
    }

    if (trap == 10U || trap == 11U) {
        const auto address_pointer = registers[1];
        const bool wide = trap == 10U;
        const auto requested_address = wide
            ? memory_.read64(address_pointer)
            : std::optional<std::uint64_t> { memory_.read32(address_pointer) };
        const auto size = static_cast<std::uint64_t>(registers[2]) |
            (wide ? static_cast<std::uint64_t>(registers[3]) << 32U : 0U);
        const auto flags = registers[wide ? 4 : 3];
        if (!requested_address ||
            !memory_.accessible(address_pointer, wide ? 8U : 4U,
                MemoryPermission::Write)) {
            registers[0] = darwin::mach::invalid_address;
            return true;
        }

        if (*requested_address > UINT32_MAX || size > UINT32_MAX) {
            registers[0] = darwin::mach::invalid_argument;
            return true;
        }
        const auto allocation = allocate_guest_vm_region(memory_,
            static_cast<std::uint32_t>(*requested_address),
            static_cast<std::uint32_t>(size), flags);
        if (allocation.result == darwin::mach::success &&
            !(wide ? memory_.write64(address_pointer, allocation.address)
                   : memory_.write32(address_pointer, allocation.address))) {
            static_cast<void>(memory_.unmap(
                allocation.address, static_cast<std::uint32_t>(size)));
            registers[0] = darwin::mach::invalid_address;
            return true;
        }
        registers[0] = allocation.result;
        return true;
    }

    if (trap == 14U) {
        // _kernelrpc_mach_vm_protect_trap uses two 64-bit arguments in the
        // ARM32 register image: address r1:r2 and size r3:r4, followed by
        // set_maximum and new_protection in r5/r6.  The guest address space is
        // 32-bit, so reject values that cannot be represented before touching
        // the mapping.
        const auto address = static_cast<std::uint64_t>(registers[1]) |
                             (static_cast<std::uint64_t>(registers[2]) << 32U);
        const auto size = static_cast<std::uint64_t>(registers[3]) |
                          (static_cast<std::uint64_t>(registers[4]) << 32U);
        const auto result =
            address <= UINT32_MAX && size <= UINT32_MAX &&
                    protect_memory(cpu, static_cast<std::uint32_t>(address),
                        static_cast<std::uint32_t>(size),
                        memory_permissions(registers[6]))
                ? darwin::mach::success
                : darwin::mach::invalid_address;
        registers[0] = result;
        return true;
    }

    if (trap == 15U) {
        // _kernelrpc_vm_protect_trap takes the address by value. The fifth
        // argument (new_protection) is moved from the stack into r4 by the
        // native ARM32 trampoline; r3 is set_maximum.
        registers[0] = protect_memory(cpu, registers[1], registers[2],
                           memory_permissions(registers[4]))
                           ? darwin::mach::success
                           : darwin::mach::invalid_address;
        return true;
    }

    // XNU's direct deallocation traps are 12 and 13 across the supported
    // ARM32 variants. Treat already-unmapped pages as successful and reuse the
    // same AddressSpace operation as the MIG vm_deallocate path.
    const bool wide = trap == 12U;
    const auto address = static_cast<std::uint64_t>(registers[1]) |
        (wide ? static_cast<std::uint64_t>(registers[2]) << 32U : 0U);
    const auto size = wide
        ? static_cast<std::uint64_t>(registers[3]) |
              (static_cast<std::uint64_t>(registers[4]) << 32U)
        : registers[2];
    if (address > UINT32_MAX || size > UINT32_MAX) {
        registers[0] = darwin::mach::invalid_argument;
        return true;
    }
    static_cast<void>(memory_.unmap(static_cast<std::uint32_t>(address),
        static_cast<std::uint32_t>(size)));
    registers[0] = darwin::mach::success;
    return true;
}

} // namespace shade
