// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Write headless display frames atomically to image files.

#include "graphics/frame_file_presenter.hpp"

#include <cstdint>
#include <filesystem>
#include <fstream>
#include <limits>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

#include <png.h>

#include "foundation/application_display.hpp"
#include "graphics/display.hpp"

namespace shade {
namespace {

    constexpr std::uint32_t bitmap_file_header_size = 14;
    constexpr std::uint32_t bitmap_info_header_size = 40;
    constexpr std::uint32_t bitmap_pixel_offset =
        bitmap_file_header_size + bitmap_info_header_size;
    constexpr std::uint16_t bitmap_bits_per_pixel = 32;
    constexpr std::uint32_t bitmap_bytes_per_pixel = bitmap_bits_per_pixel / 8U;

    void write_u16(std::ostream& output, std::uint16_t value)
    {
        const char bytes[] { static_cast<char>(value & 0xffU),
            static_cast<char>((value >> 8U) & 0xffU) };
        output.write(bytes, sizeof(bytes));
    }

    void write_u32(std::ostream& output, std::uint32_t value)
    {
        const char bytes[] { static_cast<char>(value & 0xffU),
            static_cast<char>((value >> 8U) & 0xffU),
            static_cast<char>((value >> 16U) & 0xffU),
            static_cast<char>((value >> 24U) & 0xffU) };
        output.write(bytes, sizeof(bytes));
    }

    void write_portable_pixmap(std::ostream& output, const DisplayFrame& frame)
    {
        output << "P6\n" << frame.width << ' ' << frame.height << "\n255\n";
        for (const auto pixel : frame.pixels) {
            const char rgb[] { static_cast<char>((pixel >> 16U) & 0xffU),
                static_cast<char>((pixel >> 8U) & 0xffU),
                static_cast<char>(pixel & 0xffU) };
            output.write(rgb, sizeof(rgb));
        }
    }

    void write_bitmap(std::ostream& output, const DisplayFrame& frame)
    {
        const auto pixel_bytes = static_cast<std::uint64_t>(frame.width) *
                                 frame.height * bitmap_bytes_per_pixel;
        const auto file_bytes = pixel_bytes + bitmap_pixel_offset;
        if (file_bytes > std::numeric_limits<std::uint32_t>::max()) {
            throw std::runtime_error { "frame is too large for BMP output" };
        }

        output.put('B');
        output.put('M');
        write_u32(output, static_cast<std::uint32_t>(file_bytes));
        write_u16(output, 0);
        write_u16(output, 0);
        write_u32(output, bitmap_pixel_offset);

        write_u32(output, bitmap_info_header_size);
        write_u32(output, frame.width);
        write_u32(output, frame.height);
        write_u16(output, 1);
        write_u16(output, bitmap_bits_per_pixel);
        write_u32(output, 0);
        write_u32(output, static_cast<std::uint32_t>(pixel_bytes));
        write_u32(output, 0);
        write_u32(output, 0);
        write_u32(output, 0);
        write_u32(output, 0);

        for (std::uint32_t row = frame.height; row != 0; --row) {
            const auto offset =
                static_cast<std::size_t>(row - 1U) * frame.width;
            for (std::uint32_t column = 0; column < frame.width; ++column) {
                const auto pixel = frame.pixels[offset + column];
                const char bgra[] { static_cast<char>(pixel & 0xffU),
                    static_cast<char>((pixel >> 8U) & 0xffU),
                    static_cast<char>((pixel >> 16U) & 0xffU),
                    static_cast<char>(0xffU) };
                output.write(bgra, sizeof(bgra));
            }
        }
    }

    void write_png(const std::filesystem::path& path, const DisplayFrame& frame)
    {
        // A DisplayFrame is a physical scanout, not another compositing layer.
        // Its RGB channels already contain the completed guest composition;
        // any retained framebuffer alpha is internal coverage metadata and
        // must not make screenshots depend on the host viewer background.
        std::vector<std::uint8_t> rgb;
        rgb.reserve(frame.pixels.size() * 3U);
        for (const auto pixel : frame.pixels) {
            rgb.push_back(static_cast<std::uint8_t>((pixel >> 16U) & 0xffU));
            rgb.push_back(static_cast<std::uint8_t>((pixel >> 8U) & 0xffU));
            rgb.push_back(static_cast<std::uint8_t>(pixel & 0xffU));
        }

        png_image image { };
        image.version = PNG_IMAGE_VERSION;
        image.width = frame.width;
        image.height = frame.height;
        image.format = PNG_FORMAT_RGB;
        const auto path_string = path.string();
        if (png_image_write_to_file(
                &image, path_string.c_str(), 0, rgb.data(), 0, nullptr) == 0) {
            const std::string reason = image.message[0] == '\0'
                                           ? "unknown libpng error"
                                           : image.message;
            png_image_free(&image);
            throw std::runtime_error { "could not write PNG frame output: " +
                                       reason };
        }
        png_image_free(&image);
    }

} // namespace

FrameFilePresenter::FrameFilePresenter(std::filesystem::path path)
    : path_ { std::move(path) }
{
    if (path_.empty()) {
        throw std::invalid_argument { "frame output path is empty" };
    }
}

void FrameFilePresenter::present(const DisplayFrame& frame)
{
    if (!enabled())
        return;
    DisplayFrame materialized = frame;
    auto expected = static_cast<std::size_t>(frame.width) * frame.height;
    if (materialized.pixels.size() != expected && materialized.read_pixels) {
        materialized.pixels = materialized.read_pixels();
    }
    if (materialized.width == 0 || materialized.height == 0 ||
        materialized.pixels.size() != expected) {
        return;
    }
    if (materialized.orientation != DisplayOrientation::Portrait) {
        const auto oriented =
            orient_display_pixels({ materialized.width, materialized.height },
                materialized.pixels, materialized.orientation);
        if (oriented.empty())
            return;
        if (is_landscape(materialized.orientation))
            std::swap(materialized.width, materialized.height);
        materialized.pixels = oriented;
        materialized.host_surface.reset();
        materialized.read_pixels = { };
        expected =
            static_cast<std::size_t>(materialized.width) * materialized.height;
    }
    const std::scoped_lock lock { mutex_ };
    auto temporary = path_;
    temporary += ".tmp";
    if (path_.extension() == ".png") {
        write_png(temporary, materialized);
    } else {
        std::ofstream output { temporary, std::ios::binary | std::ios::trunc };
        if (!output) {
            throw std::runtime_error { "could not open frame output: " +
                                       temporary.string() };
        }
        if (path_.extension() == ".bmp") {
            write_bitmap(output, materialized);
        } else {
            write_portable_pixmap(output, materialized);
        }
        output.close();
        if (!output) {
            throw std::runtime_error { "could not write frame output: " +
                                       temporary.string() };
        }
    }
    std::error_code error;
    std::filesystem::rename(temporary, path_, error);
    if (error) {
        std::filesystem::remove(path_, error);
        error.clear();
        std::filesystem::rename(temporary, path_, error);
    }
    if (error) {
        throw std::runtime_error { "could not replace frame output: " +
                                   path_.string() };
    }
}

void FrameFilePresenter::set_enabled(bool enabled) noexcept
{
    enabled_.store(enabled, std::memory_order_relaxed);
}

bool FrameFilePresenter::enabled() const noexcept
{
    return enabled_.load(std::memory_order_relaxed);
}

} // namespace shade
