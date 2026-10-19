// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Deliver emulator PCM audio to the SDL audio device.

#pragma once

#include <memory>
#include <mutex>
#include <string>

#include "media/audio.hpp"

namespace shade {

class SdlAudioSink final : public AudioSink {
public:
    SdlAudioSink();
    ~SdlAudioSink() override;

    SdlAudioSink(const SdlAudioSink&) = delete;
    SdlAudioSink& operator=(const SdlAudioSink&) = delete;

    [[nodiscard]] static bool available();
    [[nodiscard]] bool play(const AudioBuffer& buffer) override;
    [[nodiscard]] bool has_pending_audio() const override;
    void set_gain(float gain) override;
    void stop(AudioStopMode mode = AudioStopMode::Immediate) override;
    [[nodiscard]] std::string last_error() const override;

private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};

} // namespace shade
