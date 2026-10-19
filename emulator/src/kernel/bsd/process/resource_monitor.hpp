// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
#pragma once

#include <cstdint>

namespace emulator {
class AddressSpace;
struct KernelSharedState;
struct ProcessContext;
namespace kernel_bsd::resource_monitor {
inline constexpr std::uint32_t syscall_number = 446;

std::uint32_t control(AddressSpace& memory, KernelSharedState& state,
    const ProcessContext& caller, std::uint32_t pid, std::uint32_t flavor,
    std::uint32_t argument);
}
}
