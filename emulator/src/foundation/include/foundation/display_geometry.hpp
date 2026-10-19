// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Represent panel geometry, application orientation and presentation
// coordinate transforms.

#pragma once

#include <algorithm>
#include <cstddef>
#include <cstdint>

namespace emulator {

enum class DisplayOrientation : std::uint8_t {
    Portrait,
    PortraitUpsideDown,
    LandscapeLeft,
    LandscapeRight,
};

[[nodiscard]] constexpr bool is_landscape(DisplayOrientation orientation)
{
    return orientation == DisplayOrientation::LandscapeLeft ||
           orientation == DisplayOrientation::LandscapeRight;
}

struct DisplayGeometry {
    std::uint32_t width { };
    std::uint32_t height { };

    [[nodiscard]] constexpr bool valid() const
    {
        return width != 0U && height != 0U;
    }

    [[nodiscard]] constexpr std::size_t pixel_count() const
    {
        return static_cast<std::size_t>(width) * height;
    }
};

[[nodiscard]] constexpr std::uint32_t display_scale_factor(
    DisplayGeometry native, DisplayGeometry logical)
{
    if (!native.valid() || !logical.valid() ||
        native.width % logical.width != 0U ||
        native.height % logical.height != 0U) {
        return 1U;
    }
    const auto width_scale = native.width / logical.width;
    const auto height_scale = native.height / logical.height;
    return width_scale != 0U && width_scale == height_scale ? width_scale
                                                              : 1U;
}

struct DisplayViewport {
    std::int32_t x { };
    std::int32_t y { };
    std::uint32_t width { };
    std::uint32_t height { };
};

[[nodiscard]] constexpr DisplayViewport fit_display_viewport(
    DisplayGeometry source, DisplayGeometry output)
{
    if (!source.valid() || !output.valid())
        return { };
    const auto scaled_extent = [](std::uint32_t output_extent,
                                   std::uint32_t source_extent,
                                   std::uint32_t source_axis) {
        return std::max(
            1U, static_cast<std::uint32_t>(
                    (static_cast<std::uint64_t>(output_extent) * source_extent +
                        source_axis / 2U) /
                    source_axis));
    };
    std::uint32_t width { };
    std::uint32_t height { };
    if (static_cast<std::uint64_t>(output.width) * source.height <=
        static_cast<std::uint64_t>(output.height) * source.width) {
        width = output.width;
        height = scaled_extent(output.width, source.height, source.width);
    } else {
        height = output.height;
        width = scaled_extent(output.height, source.width, source.height);
    }
    return { static_cast<std::int32_t>((output.width - width) / 2U),
        static_cast<std::int32_t>((output.height - height) / 2U), width,
        height };
}

inline constexpr DisplayGeometry default_display_geometry { 320U, 480U };
inline constexpr std::uint32_t default_display_width =
    default_display_geometry.width;
inline constexpr std::uint32_t default_display_height =
    default_display_geometry.height;

}
