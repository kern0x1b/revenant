// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Decode audio files into emulator PCM buffers using FFmpeg.

#pragma once

#include <memory>

#include "media/audio.hpp"

namespace shade {

class FfmpegAudioDecoder final : public AudioDecoder {
public:
    FfmpegAudioDecoder();
    ~FfmpegAudioDecoder() override;

    FfmpegAudioDecoder(const FfmpegAudioDecoder&) = delete;
    FfmpegAudioDecoder& operator=(const FfmpegAudioDecoder&) = delete;

    [[nodiscard]] static bool available();
    [[nodiscard]] std::optional<AudioBuffer> decode(
        const std::filesystem::path& path) override;
    [[nodiscard]] std::string last_error() const override;

private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};

} // namespace shade
