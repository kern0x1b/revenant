// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "graphics/boot_logo.hpp"
#include "boot_placeholder.hpp"

#include <stdexcept>
#include <string>

#include <png.h>

namespace shade {
namespace {

    struct PngImage {
        png_image value { };
        PngImage() { value.version = PNG_IMAGE_VERSION; }
        ~PngImage() { png_image_free(&value); }
    };

    std::vector<std::uint32_t> render(png_image& png, DisplayGeometry panel)
    {
        if (!panel.valid())
            throw std::runtime_error { "invalid boot panel geometry" };
        // Firmware logos are small. Bound allocations even for corrupt assets.
        if (png.width == 0 || png.height == 0 || png.width > 4096 ||
            png.height > 4096)
            throw std::runtime_error {
                "boot logo dimensions exceed 4096x4096"
            };
        png.format = PNG_FORMAT_RGBA;
        std::vector<png_byte> rgba(PNG_IMAGE_SIZE(png));
        if (!png_image_finish_read(&png, nullptr, rgba.data(), 0, nullptr))
            throw std::runtime_error { png.message };

        std::vector<std::uint32_t> pixels(panel.pixel_count(), 0xff000000U);
        const auto offset_x =
            (static_cast<int>(panel.width) - static_cast<int>(png.width)) / 2;
        const auto offset_y =
            (static_cast<int>(panel.height) - static_cast<int>(png.height)) / 2;
        for (std::uint32_t y = 0; y < png.height; ++y) {
            const auto dy = offset_y + static_cast<int>(y);
            if (dy < 0 || dy >= static_cast<int>(panel.height))
                continue;
            for (std::uint32_t x = 0; x < png.width; ++x) {
                const auto dx = offset_x + static_cast<int>(x);
                if (dx < 0 || dx >= static_cast<int>(panel.width))
                    continue;
                const auto source =
                    (static_cast<std::size_t>(y) * png.width + x) * 4;
                const auto alpha = rgba[source + 3];
                const auto channel = [&](std::size_t index) {
                    return (static_cast<std::uint32_t>(rgba[source + index]) *
                                   alpha +
                               127U) /
                           255U;
                };
                pixels[static_cast<std::size_t>(dy) * panel.width +
                       static_cast<std::size_t>(dx)] =
                    0xff000000U | (channel(0) << 16U) | (channel(1) << 8U) |
                    channel(2);
            }
        }
        return pixels;
    }

} // namespace

std::vector<std::uint32_t> BootLogo::load(
    const std::filesystem::path& path, DisplayGeometry panel)
{
    PngImage image;
    if (!png_image_begin_read_from_file(&image.value, path.string().c_str()))
        throw std::runtime_error { image.value.message };
    return render(image.value, panel);
}

std::vector<std::uint32_t> BootLogo::placeholder(DisplayGeometry panel)
{
    PngImage image;
    if (!png_image_begin_read_from_memory(
            &image.value, boot_placeholder_png, sizeof(boot_placeholder_png)))
        throw std::runtime_error { image.value.message };
    return render(image.value, panel);
}

} // namespace shade
