// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
#pragma once
#include <cstdint>
namespace shade {
struct DarwinFileGuard {
    static constexpr std::uint32_t close = 1U;
    static constexpr std::uint32_t duplicate = 2U;
    static constexpr std::uint32_t socket_ipc = 4U;
    static constexpr std::uint32_t fileport = 8U;
    std::uint64_t identifier;
    std::uint32_t flags;
};
} // namespace shade
