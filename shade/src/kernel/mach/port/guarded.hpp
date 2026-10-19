// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#pragma once

#include <array>
#include <cstdint>

namespace shade {
class AddressSpace;
struct KernelSharedState;

// Caller holds the shared Mach lock and has resolved the target task.
std::uint32_t dispatch_guarded_port_trap(KernelSharedState& state,
    AddressSpace& memory, std::uint32_t task,
    const std::array<std::uint32_t, 16>& registers, std::uint32_t trap);
}
