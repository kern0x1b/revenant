// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Adapt guest AudioToolbox system-sound calls to emulator audio
// services.

#include "media/audio_toolbox_hle.hpp"

#include <string>
#include <string_view>

#include "foundation/output.hpp"
#include "foundation/userland_hle.hpp"

namespace shade {
namespace {

    constexpr std::string_view audio_toolbox_image {
        "/AudioToolbox.framework/AudioToolbox"
    };

} // namespace

AudioToolboxHle::AudioToolboxHle(UserlandHleRegistry& registry)
{
    const auto register_play = [&](std::string symbol) {
        registry.register_function(std::string { audio_toolbox_image },
            std::move(symbol),
            [this](UserlandHleCall& call) { play_system_sound(call); });
    };
    register_play("_AudioServicesPlaySystemSound");
    register_play("_AudioServicesPlayInterfaceSound");
    register_play("_AudioServicesPlayAlertSound");
}

void AudioToolboxHle::play_system_sound(UserlandHleCall& call)
{
    const auto sound_id = call.argument(0);
    call.output().line(
        "[audio] system-sound pid=" + std::to_string(call.process_id()) +
        " id=" + std::to_string(sound_id) + " service=native");
    // The firmware service owns the system-sound registry and resource
    // selection. Keeping this boundary native avoids duplicating either IDs or
    // paths in the emulator as new system sounds appear.
    call.resume_original();
}

} // namespace shade
