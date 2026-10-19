// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Expose the emulated hardware audio-route state to guest CoreMedia
// sessions.

#pragma once

namespace shade {

class UserlandHleRegistry;

class CoreMediaHle {
public:
    explicit CoreMediaHle(UserlandHleRegistry& registry);

private:
    static void copy_device_route_for_audio_category(
        class UserlandHleCall& call);
};

}
