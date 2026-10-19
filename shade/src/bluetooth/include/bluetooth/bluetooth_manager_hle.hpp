// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Expose the offline Bluetooth controller state at the guest session
// API boundary.

#pragma once

namespace shade {

class UserlandHleRegistry;

// Reports the absence of a controller at MobileBluetooth's public session
// boundary so guest clients can take their native offline path.
void register_bluetooth_manager_hle(UserlandHleRegistry& registry);

} // namespace shade
