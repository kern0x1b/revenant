// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Build stable guest process snapshots for live diagnostics.

#include "kernel/kernel.hpp"

#include <mutex>
#include <vector>

namespace shade {

std::vector<ProcessSnapshot> CompatibilityKernel::process_snapshots() const
{
    const std::lock_guard lock { shared_state_->mach_mutex };
    std::vector<ProcessSnapshot> snapshots;
    snapshots.reserve(shared_state_->processes.size());
    for (const auto& [pid, process] : shared_state_->processes) {
        snapshots.push_back(ProcessSnapshot { pid, process.parent_pid,
            process.command, process.executable_path, process.exited,
            process.pid_suspended, process.signal_stopped,
            process.exit_status, process.termination_signal });
    }
    return snapshots;
}

} // namespace shade
