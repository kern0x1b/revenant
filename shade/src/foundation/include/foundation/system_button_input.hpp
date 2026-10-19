// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Describe guest hardware-button events independently of host input
// APIs.

#pragma once

namespace shade {

// Physical iPhone controls as exposed through the iPhone OS 1.0 GSEvent ABI.
// "Home" is named "Menu" by the firmware but uses the user-facing name here.
enum class SystemButton {
    Home,
    Lock,
    VolumeUp,
    VolumeDown,
};

enum class SystemButtonPhase {
    Down,
    Up,
};

struct SystemButtonInput {
    SystemButton button { SystemButton::Home };
    SystemButtonPhase phase { SystemButtonPhase::Down };
};

// A host key represents movement of the physical two-position switch, not an
// independently cached target state. The device model is the sole state owner.
struct RingerSwitchInput { };

} // namespace shade
