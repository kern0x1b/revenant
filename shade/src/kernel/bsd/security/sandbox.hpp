// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Declare guest sandbox query results and dispatch interfaces.

#pragma once

#include <cstdint>
#include "device_state/darwin_abi.hpp"

namespace shade {

class AddressSpace;

namespace bsd::sandbox {

enum class CallResult {
    Unsupported,
    Success,
    BadAddress,
    InvalidArgument,
    NoMemory,
};

[[nodiscard]] CallResult dispatch(
    AddressSpace& memory, DarwinSandboxAbi abi, std::uint32_t operation,
    std::uint32_t argument);

} // namespace bsd::sandbox
} // namespace shade
