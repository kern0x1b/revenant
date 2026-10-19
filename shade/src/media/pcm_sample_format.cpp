// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Interpret the LPCM fraction field before passing normalized samples to a sink.

#include "media/pcm_sample_format.hpp"

#include <algorithm>
#include <bit>
#include <cmath>
#include <type_traits>

namespace shade {
namespace {
    // CoreAudio's six-bit sample-fraction field starts at bit seven.
    // https://developer.apple.com/documentation/coreaudiotypes/klinearpcmformatflagssamplefractionshift
    constexpr std::uint32_t fraction_shift = 7;
    constexpr std::uint32_t fraction_mask = 0x3f;

    template <class Sample, class Convert>
    AudioSamples decode_samples(std::span<const std::byte> bytes,
        std::uint32_t width, Convert convert, std::uint32_t& peak)
    {
        std::vector<Sample> samples;
        samples.reserve(bytes.size() / width);
        for (std::size_t offset = 0; offset + width <= bytes.size(); offset += width) {
            std::uint32_t encoded = 0;
            for (std::uint32_t index = 0; index < width; ++index)
                encoded |= std::to_integer<std::uint32_t>(bytes[offset + index])
                           << (index * 8U);
            const auto sample = convert(encoded);
            samples.push_back(sample);
            const double magnitude = [&] {
                if constexpr (std::is_same_v<Sample, float>)
                    return std::abs(static_cast<double>(sample)) * 32768.0;
                else if constexpr (sizeof(Sample) == 4)
                    return std::abs(static_cast<double>(sample)) / 65536.0;
                else
                    return std::abs(static_cast<double>(sample));
            }();
            peak = std::max(peak, static_cast<std::uint32_t>(
                std::clamp(magnitude, 0.0, 32768.0)));
        }
        return samples;
    }
}

std::optional<PcmSampleFormat> PcmSampleFormat::from_lpcm(
    std::uint32_t flags, std::uint32_t bits)
{
    PcmSampleFormat format;
    format.floating_point_ = (flags & 1U) != 0;
    format.fractional_bits_ = (flags >> fraction_shift) & fraction_mask;
    if ((flags & (2U | 16U)) != 0 || (flags & 8U) == 0 ||
        (format.floating_point_ ? bits != 32U || format.fractional_bits_ != 0
                               : (bits != 16U && bits != 32U) ||
                                     (flags & 4U) == 0 || format.fractional_bits_ >= bits))
        return std::nullopt;
    format.sample_bytes_ = bits / 8U;
    return format;
}

AudioSamples PcmSampleFormat::decode(
    std::span<const std::byte> bytes, std::uint32_t& peak) const
{
    peak = 0;
    if (floating_point_ || fractional_bits_ != 0) {
        return decode_samples<float>(bytes, sample_bytes_, [this](std::uint32_t encoded) {
            float value;
            if (floating_point_) {
                value = std::bit_cast<float>(encoded);
            } else {
                const auto integer = sample_bytes_ == 2
                    ? static_cast<std::int32_t>(std::bit_cast<std::int16_t>(
                          static_cast<std::uint16_t>(encoded)))
                    : std::bit_cast<std::int32_t>(encoded);
                value = std::ldexp(static_cast<float>(integer),
                    -static_cast<int>(fractional_bits_));
            }
            return std::isfinite(value) ? std::clamp(value, -1.0F, 1.0F) : 0.0F;
        }, peak);
    }
    if (sample_bytes_ == 2) {
        return decode_samples<std::int16_t>(bytes, sample_bytes_, [](std::uint32_t encoded) {
            return std::bit_cast<std::int16_t>(static_cast<std::uint16_t>(encoded));
        }, peak);
    }
    return decode_samples<std::int32_t>(bytes, sample_bytes_, [](std::uint32_t encoded) {
        return std::bit_cast<std::int32_t>(encoded);
    }, peak);
}

} // namespace shade
