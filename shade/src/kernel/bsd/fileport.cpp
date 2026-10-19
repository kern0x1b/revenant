// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Convert supported file descriptions to and from guest Mach
// fileports.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-1699.22.73/bsd/kern/kern_descrip.c

#include "kernel/kernel.hpp"

#include "kernel/darwin_abi.hpp"

#include <cstdint>
#include <mutex>
#include <utility>

#include "../mach/support.hpp"
#include "support.hpp"

namespace shade {

void CompatibilityKernel::dispatch_bsd_fileport(
    Cpu& cpu, std::uint32_t number)
{
    constexpr auto send_right = xnu::ipc::type_mask(
        xnu::ipc::Right::Send);
    auto& registers = cpu.registers();

    if (number == darwin::syscall::fileport_makeport) {
        const auto descriptor = registers[0];
        const auto output_address = registers[1];
        if (reject_guarded_descriptor(cpu, descriptor, DarwinFileGuard::fileport))
            return;
        const auto transfer = export_descriptor(descriptor);
        if (!transfer) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
            return;
        }
        // XNU does not allow a kqueue's event registrations to escape through
        // fileport_makeport. Other descriptor kinds already have a complete
        // DescriptorTransfer representation and share the existing HLE state.
        if (transfer->virtual_type == "kqueue") {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        if (!memory_.accessible(
                output_address, sizeof(std::uint32_t), MemoryPermission::Write)) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }

        std::lock_guard mach_lock { shared_state_->mach_mutex };
        const auto object = shared_state_->allocate_mach_object();
        if (!shared_state_->mach_port_objects.create(object)) {
            bsd_error(cpu, darwin::error::no_memory);
            return;
        }
        const auto name = shared_state_->mach_namespaces.copyout(
            process_.pid, object, send_right);
        if (!name) {
            static_cast<void>(shared_state_->mach_port_objects.erase(object));
            bsd_error(cpu, darwin::error::no_memory);
            return;
        }
        const auto [fileport, inserted] =
            shared_state_->mach_fileports.emplace(object, std::move(*transfer));
        if (!inserted || !memory_.write32(output_address, *name)) {
            if (inserted)
                shared_state_->mach_fileports.erase(fileport);
            static_cast<void>(
                shared_state_->mach_namespaces.destroy_name(process_.pid, *name));
            static_cast<void>(shared_state_->mach_port_objects.erase(object));
            bsd_error(cpu, inserted ? bsd_support::bad_address
                                    : darwin::error::no_memory);
            return;
        }
        bsd_success(cpu, 0);
        return;
    }

    const auto name = registers[0];
    std::lock_guard mach_lock { shared_state_->mach_mutex };
    const auto entry = shared_state_->mach_namespaces.lookup(process_.pid, name);
    if (!entry || (entry->type & send_right) == 0) {
        bsd_error(cpu, bsd_support::invalid_argument);
        return;
    }
    const auto fileport = shared_state_->mach_fileports.find(entry->object);
    if (fileport == shared_state_->mach_fileports.end()) {
        bsd_error(cpu, bsd_support::invalid_argument);
        return;
    }
    const auto descriptor = import_descriptor(fileport->second);
    if (!descriptor) {
        bsd_error(cpu, 24); // EMFILE
        return;
    }
    // fileport_makefd returns a descriptor with FD_CLOEXEC set. This is
    // distinct from SCM_RIGHTS, whose import path intentionally clears it.
    descriptor_flags_[*descriptor] = 1U;
    bsd_success(cpu, *descriptor);
}

} // namespace shade
