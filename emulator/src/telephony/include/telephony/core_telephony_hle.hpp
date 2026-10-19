// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Expose virtual telephony and carrier state to guest CoreTelephony
// clients.

#pragma once

#include <functional>
#include <memory>

namespace emulator {

class UserlandHleRegistry;
class WifiState;
struct WifiSnapshot;

using WifiStateProvider = std::function<std::shared_ptr<WifiState>()>;

void register_core_telephony_hle(UserlandHleRegistry& registry);
void register_core_telephony_hle(UserlandHleRegistry& registry,
    WifiStateProvider wifi_state,
    std::function<void(const WifiSnapshot&, const WifiSnapshot&)>
        wifi_state_changed = { },
    bool offline_transport = true);

}
