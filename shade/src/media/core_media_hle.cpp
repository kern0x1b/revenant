// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Expose the emulated hardware audio-route state to guest CoreMedia
// sessions.

#include "media/core_media_hle.hpp"

#include <string>
#include <string_view>

#include "foundation/userland_hle.hpp"

namespace shade {
namespace {

    constexpr std::string_view core_media_image {
        "/System/Library/PrivateFrameworks/CoreMedia.framework/CoreMedia"
    };
} // namespace

CoreMediaHle::CoreMediaHle(UserlandHleRegistry& registry)
{
    registry.register_function(std::string { core_media_image },
        "_CMSessionMgrCopyDeviceRouteForAudioCategory",
        &CoreMediaHle::copy_device_route_for_audio_category);
}

void CoreMediaHle::copy_device_route_for_audio_category(UserlandHleCall& call)
{
    call.resume_original_persistently();
}

} // namespace shade
