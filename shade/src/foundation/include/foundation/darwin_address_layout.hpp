// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#pragma once

#include <cstdint>

namespace shade {

// Keep the initial stack below the reserved shared-cache interval. These
// addresses are a process ABI contract, independent of host memory layout.
enum class DarwinAddressLayout { ClassicArm, ExpandedArmSharedRegion };

struct DarwinAddressBounds {
    std::uint32_t stack_top;
    std::uint32_t shared_region_base;
    std::uint32_t shared_region_end;
};

constexpr DarwinAddressBounds darwin_address_bounds(DarwinAddressLayout layout)
{
    if (layout == DarwinAddressLayout::ExpandedArmSharedRegion)
        return { 0x27e00000U, 0x2c000000U, 0x40000000U };
    return { 0x30000000U, 0x30000000U, 0x40000000U };
}

} // namespace shade
