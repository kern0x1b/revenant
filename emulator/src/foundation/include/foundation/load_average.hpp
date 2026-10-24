// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
#pragma once

#include <array>
#include <cstddef>
#include <cstdint>

namespace emulator::foundation {

using fixpt = std::uint32_t;

inline constexpr unsigned load_average_shift = 11;
inline constexpr fixpt load_average_scale = 1U << load_average_shift;
inline constexpr unsigned load_average_period_seconds = 5;

inline constexpr std::array<fixpt, 3> load_average_decay {
    static_cast<fixpt>(0.9200444146293232 * load_average_scale),
    static_cast<fixpt>(0.9834714538216174 * load_average_scale),
    static_cast<fixpt>(0.9944598480048967 * load_average_scale),
};

struct LoadAverage {
    std::array<fixpt, 3> ldavg { 0, 0, 0 };
    std::int32_t fscale = static_cast<std::int32_t>(load_average_scale);

    void sample(std::uint32_t runnable)
    {
        for (std::size_t index = 0; index < ldavg.size(); ++index) {
            const fixpt decay = load_average_decay[index];
            ldavg[index] = static_cast<fixpt>(
                (decay * ldavg[index] +
                    runnable * load_average_scale * (load_average_scale - decay))
                >> load_average_shift);
        }
    }
};

[[nodiscard]] inline std::array<std::byte, 16> encode_user32_loadavg(
    const LoadAverage& average)
{
    std::array<std::byte, 16> bytes { };
    const auto put32 = [&bytes](std::size_t offset, std::uint32_t value) {
        for (std::size_t shift = 0; shift < 32; shift += 8)
            bytes[offset + shift / 8] = static_cast<std::byte>(value >> shift);
    };
    for (std::size_t index = 0; index < average.ldavg.size(); ++index)
        put32(index * 4, average.ldavg[index]);
    put32(12, static_cast<std::uint32_t>(average.fscale));
    return bytes;
}

}
