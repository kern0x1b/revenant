// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Expose the offline Bluetooth controller state at the guest session
// API boundary.

#include "bluetooth/bluetooth_manager_hle.hpp"

#include <string>
#include <string_view>

#include "foundation/userland_hle.hpp"

namespace shade {
namespace {

    constexpr std::string_view mobile_bluetooth_image {
        "/MobileBluetooth.framework/MobileBluetooth"
    };

} // namespace

void register_bluetooth_manager_hle(UserlandHleRegistry& registry)
{
    registry.register_function(std::string { mobile_bluetooth_image },
        "_BTSessionAttachWithRunLoop", [](UserlandHleCall& call) {
            // There is no emulated Bluetooth controller. Report attachment
            // failure at the public MobileBluetooth backend boundary so every
            // daemon and framework takes its native no-Bluetooth fallback.
            call.set_return(1);
        });
}

} // namespace shade
