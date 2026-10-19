// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Represent guest memory protection flags and their combinations.

#pragma once

#include <cstdint>

namespace shade {

enum class MemoryPermission : std::uint8_t {
    None = 0,
    Read = 1,
    Write = 2,
    Execute = 4,
};

constexpr MemoryPermission operator|(MemoryPermission lhs, MemoryPermission rhs)
{
    return static_cast<MemoryPermission>(
        static_cast<unsigned>(lhs) | static_cast<unsigned>(rhs));
}

constexpr MemoryPermission& operator|=(
    MemoryPermission& lhs, MemoryPermission rhs)
{
    lhs = lhs | rhs;
    return lhs;
}

constexpr bool has_permission(MemoryPermission value, MemoryPermission required)
{
    return (static_cast<unsigned>(value) & static_cast<unsigned>(required)) ==
           static_cast<unsigned>(required);
}

} // namespace shade
