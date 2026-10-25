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

void CompatibilityKernelSnapshot::perturb_bookkeeping(CompatibilityKernel& kernel)
{
    kernel.process_.pid = 7;
    kernel.process_.login_name = "mobile";
    kernel.process_.resource_limits[0].current = 42;
    kernel.process_.thread_disk_io_policies.emplace(3U, 1U);
    kernel.load_average_.sample(4);
    auto attributes = kernel.offline_serial_state_.attributes();
    attributes.input_flags = 0x1234U;
    kernel.offline_serial_state_.set_attributes(attributes);
}

}
