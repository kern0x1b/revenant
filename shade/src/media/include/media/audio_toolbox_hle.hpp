// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Adapt guest AudioToolbox system-sound calls to emulator audio
// services.

#pragma once

namespace shade {

class UserlandHleRegistry;

class AudioToolboxHle {
public:
    explicit AudioToolboxHle(UserlandHleRegistry& registry);

private:
    void play_system_sound(class UserlandHleCall& call);
};

} // namespace shade
