// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Expose virtual telephony and carrier state to guest CoreTelephony
// clients.

#pragma once

#include <functional>
#include <memory>

namespace shade {

class UserlandHleRegistry;
class WifiState;
struct WifiSnapshot;

using WifiStateProvider = std::function<std::shared_ptr<WifiState>()>;

// Supplies the high-level telephony state needed by SpringBoard without
// emulating a baseband device or the CommCenter transport protocol. When the
// device uses the offline transport profile, the HLE exposes a stable
// SIM-ready capability so stock SpringBoard does not manufacture a missing-
// SIM modal from an intentionally absent modem. A replay/virtual transport
// leaves the firmware's own SIM result untouched.
void register_core_telephony_hle(UserlandHleRegistry& registry);
void register_core_telephony_hle(UserlandHleRegistry& registry,
    WifiStateProvider wifi_state,
    std::function<void(const WifiSnapshot&, const WifiSnapshot&)>
        wifi_state_changed = { },
    bool offline_transport = true);

} // namespace shade
