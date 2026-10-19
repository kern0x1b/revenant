// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Describe guest hardware-button events independently of host input
// APIs.

#pragma once

namespace shade {

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

struct RingerSwitchInput { };

}
