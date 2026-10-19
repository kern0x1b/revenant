// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Expose the emulated hardware audio-route state to guest CoreMedia
// sessions.

#pragma once

namespace shade {

class UserlandHleRegistry;

// CoreMedia asks its session manager for the current hardware audio route
// while MediaToolbox brings up the remote player service. The emulated device
// has no physical route, so this adapter returns the firmware's supported
// empty-route result and leaves all other media logic in the guest.
class CoreMediaHle {
public:
    explicit CoreMediaHle(UserlandHleRegistry& registry);

private:
    static void copy_device_route_for_audio_category(
        class UserlandHleCall& call);
};

} // namespace shade
