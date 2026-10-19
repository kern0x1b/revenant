// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Adapt guest MBX connection calls and command-buffer access.

#include "kernel/mbx_connect_hle.hpp"

#include <array>
#include <string>
#include <string_view>

#include "foundation/userland_hle.hpp"

namespace shade {
namespace {

    constexpr std::string_view mbx_connect_image {
        "/MBXConnect.framework/MBXConnect"
    };
    constexpr std::uint32_t success = 0;
    constexpr std::array<std::string_view, 5> control_symbols {
        "_mbxSetClockGateWorkaroundMode",
        "_mbxDisableCommandBufferMutex",
        "_mbxEnableCommandBufferMutex",
        "_mbxDisableSurfaceHashMutex",
        "_mbxEnableSurfaceHashMutex",
    };

} // namespace

void register_mbx_connect_hle(UserlandHleRegistry& registry)
{
    for (const auto symbol : control_symbols) {
        registry.register_function(std::string { mbx_connect_image },
            std::string { symbol },
            [](UserlandHleCall& call) { call.set_return(success); });
    }
}

} // namespace shade
