// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
#pragma once

#include <cstdint>

namespace shade {
class AddressSpace;
struct KernelSharedState;
struct ProcessContext;
namespace kernel_bsd::resource_monitor {
inline constexpr std::uint32_t syscall_number = 446;

// Returns a Darwin errno (zero on success). Resource accounting is guest
// state; host process limits must never be consulted or modified here.
std::uint32_t control(AddressSpace& memory, KernelSharedState& state,
    const ProcessContext& caller, std::uint32_t pid, std::uint32_t flavor,
    std::uint32_t argument);
}
} // namespace shade
