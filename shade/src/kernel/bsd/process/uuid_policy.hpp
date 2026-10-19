// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#pragma once

#include <cstdint>

namespace shade {
class AddressSpace;
struct ProcessContext;

namespace kernel_bsd::uuid_policy {
inline constexpr std::uint32_t syscall_number = 452;

[[nodiscard]] std::uint32_t control(AddressSpace& memory,
    const ProcessContext& caller, std::uint32_t operation,
    std::uint32_t uuid_address, std::uint32_t uuid_length);
} // namespace kernel_bsd::uuid_policy
} // namespace shade
