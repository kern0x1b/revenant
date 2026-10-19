// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Return current guest thread and task capabilities through Mach
// traps.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/thread_act.defs

#include "kernel/kernel.hpp"

#include "kernel/kernel_shared_state.hpp"
#include "mach/mach_namespace.hpp"

#include <cstdint>
#include <mutex>

namespace shade {

void CompatibilityKernel::dispatch_mach_thread_self_trap(Cpu& cpu)
{
    const auto slot = static_cast<std::uint32_t>(cpu.processor_id());
    std::uint32_t name = xnu::ipc::null_name;
    {
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        const auto task =
            shared_state_->task_thread_port_objects.find(process_.pid);
        if (task != shared_state_->task_thread_port_objects.end()) {
            const auto thread = task->second.find(slot);
            if (thread != task->second.end()) {
                name = shared_state_->mach_namespaces
                           .copyout(process_.pid, thread->second,
                               xnu::ipc::type_mask(xnu::ipc::Right::Send))
                           .value_or(xnu::ipc::null_name);
            }
        }
    }
    if (name != xnu::ipc::null_name)
        thread_ports_[cpu.processor_id()] = name;
    cpu.registers()[0] = name;
}

} // namespace shade
