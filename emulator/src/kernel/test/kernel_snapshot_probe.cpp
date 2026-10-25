// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "kernel/kernel.hpp"

#include "kernel/snapshot_census.hpp"

#include <string>
#include <vector>

namespace emulator {

void CompatibilityKernelSnapshot::add_pending_timer(CompatibilityKernel& kernel)
{
    kernel.pending_timers_.emplace(1U, PendingTimer { });
}

void CompatibilityKernelSnapshot::advance_clock(CompatibilityKernel& kernel,
    std::uint64_t deadline)
{
    kernel.shared_state_->clock.advance_to(deadline);
}

}
