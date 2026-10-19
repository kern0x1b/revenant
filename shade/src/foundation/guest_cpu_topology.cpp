// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Describe guest-visible processors, instruction capabilities and
// cache topology.

#include "foundation/guest_cpu_topology.hpp"

namespace shade {
static_assert(GuestCpuTopology::single_core(400'000'000U,
    GuestCpuPerformanceClass::Legacy,
    guest_cpu_isa::armv6k | guest_cpu_isa::thumb, 1U)
        .valid());

} // namespace shade
