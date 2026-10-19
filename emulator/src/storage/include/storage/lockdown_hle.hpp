// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Expose configured virtual-device activation state through guest
// liblockdown calls.

#pragma once

#include <optional>

#include "device_state/lockdown_state.hpp"

namespace emulator {

class UserlandHleRegistry;

void register_lockdown_hle(UserlandHleRegistry& registry,
    std::optional<bool> activated, LockdownCapabilities profile);

}
