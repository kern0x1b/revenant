// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Describe texture filtering, addressing and sampling state.

#pragma once

#include "graphics/gles_abi.hpp"

#include <compare>
#include <cstdint>
#include <map>

namespace shade {

struct GlesSamplerState {
    std::uint32_t min_filter { gles_abi::nearest_mipmap_linear };
    std::uint32_t mag_filter { gles_abi::linear };
    std::uint32_t wrap_s { gles_abi::repeat };
    std::uint32_t wrap_t { gles_abi::repeat };

    auto operator<=>(const GlesSamplerState&) const = default;

    [[nodiscard]] static bool linear_filter(std::uint32_t filter)
    {
        return filter == gles_abi::linear ||
               filter == gles_abi::linear_mipmap_nearest ||
               filter == gles_abi::linear_mipmap_linear;
    }

    [[nodiscard]] static GlesSamplerState from_parameters(
        const std::map<std::uint32_t, std::uint32_t>& parameters,
        bool rectangle)
    {
        GlesSamplerState result;
        if (rectangle) {
            result.min_filter = gles_abi::linear;
            result.wrap_s = result.wrap_t = gles_abi::clamp_to_edge;
        }
        const auto read = [&](auto key, auto fallback) {
            const auto found = parameters.find(key);
            return found == parameters.end() ? fallback : found->second;
        };
        const auto min = read(gles_abi::texture_min_filter, result.min_filter);
        const auto mag = read(gles_abi::texture_mag_filter, result.mag_filter);
        if (min == gles_abi::nearest || min == gles_abi::linear ||
            (min >= gles_abi::nearest_mipmap_nearest &&
                min <= gles_abi::linear_mipmap_linear))
            result.min_filter = min;
        if (mag == gles_abi::nearest || mag == gles_abi::linear)
            result.mag_filter = mag;
        const auto wrap = [&](auto key, auto fallback) {
            const auto value = read(key, fallback);
            return value == gles_abi::repeat ||
                           value == gles_abi::mirrored_repeat ||
                           value == gles_abi::clamp_to_edge
                       ? value
                       : fallback;
        };
        result.wrap_s = wrap(gles_abi::texture_wrap_s, result.wrap_s);
        result.wrap_t = wrap(gles_abi::texture_wrap_t, result.wrap_t);
        return result;
    }
};

} // namespace shade
