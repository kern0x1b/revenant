// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Recognize the guest ARM32 prime-field context used by modular
// arithmetic.

#include "prime_field_layout.hpp"

#include "foundation/address_space.hpp"
#include <limits>

namespace shade {

std::optional<PrimeFieldLayout> PrimeFieldLayout::resolve(
    const AddressSpace& memory, std::uint32_t context,
    std::uint32_t standard_reduction)
{
    if (context > std::numeric_limits<std::uint32_t>::max() - 8U ||
        standard_reduction == 0U) {
        return std::nullopt;
    }
    constexpr PrimeFieldLayout compact_arm32 { 8U };
    const auto reduction = memory.read32(context + sizeof(std::uint32_t));
    if (reduction && (*reduction & ~1U) == (standard_reduction & ~1U))
        return compact_arm32;
    return std::nullopt;
}

} // namespace shade
