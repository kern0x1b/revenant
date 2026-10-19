// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Perform bounded fixed-width big-integer arithmetic through the host
// crypto library.

#pragma once

#include <cstddef>
#include <span>

namespace shade {

// Unsigned, little-endian integers. The caller owns the fixed-width result.
class BigNumberArithmetic {
public:
    [[nodiscard]] static bool greatest_common_divisor(
        std::span<const std::byte> first, std::span<const std::byte> second,
        std::span<std::byte> result);
    [[nodiscard]] static bool power_modulo(std::span<const std::byte> base,
        std::span<const std::byte> exponent, std::span<const std::byte> modulus,
        std::span<std::byte> result);
};

} // namespace shade
