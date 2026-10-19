// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Decode packed guest PCM while preserving its declared sample precision.

#pragma once

#include "media/audio.hpp"

#include <cstddef>
#include <cstdint>
#include <optional>
#include <span>

namespace shade {

class PcmSampleFormat {
public:
    // Default hardware format: packed little-endian signed 16-bit PCM.
    PcmSampleFormat() = default;
    [[nodiscard]] static std::optional<PcmSampleFormat> from_lpcm(
        std::uint32_t flags, std::uint32_t bits);
    [[nodiscard]] std::uint32_t bytes_per_sample() const { return sample_bytes_; }
    [[nodiscard]] AudioSamples decode(
        std::span<const std::byte> bytes, std::uint32_t& peak) const;

private:
    std::uint32_t sample_bytes_ { 2 };
    std::uint32_t fractional_bits_ { };
    bool floating_point_ { };
};

} // namespace shade
