// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Manage GLES textures, framebuffers and their backing surface
// lifetimes.

#include "graphics/gles_resources.hpp"

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <span>
#include <utility>
#include <vector>

#include "foundation/address_space.hpp"
#include "graphics/gles_abi.hpp"
#include "graphics/host_graphics.hpp"
#include "graphics/surface_store.hpp"

namespace shade {
namespace {

    struct PixelLayout {
        std::uint32_t bytes_per_pixel { };
    };

    std::optional<PixelLayout> pixel_layout(
        std::uint32_t format, std::uint32_t type)
    {
        using namespace gles_abi;
        if (type == unsigned_byte) {
            switch (format) {
            case alpha:
            case luminance:
                return PixelLayout { 1 };
            case luminance_alpha:
                return PixelLayout { 2 };
            case rgb:
                return PixelLayout { 3 };
            case rgba:
            case bgra_apple:
                return PixelLayout { 4 };
            default:
                return std::nullopt;
            }
        }
        if ((type == unsigned_short_5_6_5 && format == rgb) ||
            ((type == unsigned_short_4_4_4_4 ||
                 type == unsigned_short_5_5_5_1) &&
                format == rgba)) {
            return PixelLayout { 2 };
        }
        return std::nullopt;
    }

    std::uint32_t expand(std::uint32_t value, std::uint32_t maximum)
    {
        return (value * 255U + maximum / 2U) / maximum;
    }

    std::uint32_t decode_pixel(std::span<const std::byte> bytes,
        std::uint32_t format, std::uint32_t type)
    {
        using namespace gles_abi;
        const auto byte = [&](std::size_t index) {
            return std::to_integer<std::uint32_t>(bytes[index]);
        };
        std::uint32_t red { };
        std::uint32_t green { };
        std::uint32_t blue { };
        std::uint32_t alpha_value { 255 };
        if (type == unsigned_byte) {
            if (format == rgba) {
                red = byte(0);
                green = byte(1);
                blue = byte(2);
                alpha_value = byte(3);
            } else if (format == bgra_apple) {
                blue = byte(0);
                green = byte(1);
                red = byte(2);
                alpha_value = byte(3);
            } else if (format == rgb) {
                red = byte(0);
                green = byte(1);
                blue = byte(2);
            } else if (format == luminance) {
                red = green = blue = byte(0);
            } else if (format == luminance_alpha) {
                red = green = blue = byte(0);
                alpha_value = byte(1);
            } else if (format == alpha) {
                red = green = blue = 255U;
                alpha_value = byte(0);
            }
        } else {
            const auto packed = byte(0) | (byte(1) << 8U);
            if (type == unsigned_short_5_6_5) {
                red = expand((packed >> 11U) & 0x1fU, 0x1fU);
                green = expand((packed >> 5U) & 0x3fU, 0x3fU);
                blue = expand(packed & 0x1fU, 0x1fU);
            } else if (type == unsigned_short_4_4_4_4) {
                red = expand((packed >> 12U) & 0x0fU, 0x0fU);
                green = expand((packed >> 8U) & 0x0fU, 0x0fU);
                blue = expand((packed >> 4U) & 0x0fU, 0x0fU);
                alpha_value = expand(packed & 0x0fU, 0x0fU);
            } else {
                red = expand((packed >> 11U) & 0x1fU, 0x1fU);
                green = expand((packed >> 6U) & 0x1fU, 0x1fU);
                blue = expand((packed >> 1U) & 0x1fU, 0x1fU);
                alpha_value = (packed & 1U) != 0 ? 255U : 0U;
            }
        }
        return (alpha_value << 24U) | (red << 16U) | (green << 8U) | blue;
    }

    bool valid_alignment(std::uint32_t alignment)
    {
        return alignment == 1 || alignment == 2 || alignment == 4 ||
               alignment == 8;
    }

    std::optional<std::vector<std::uint32_t>> decode_image(AddressSpace& memory,
        std::uint32_t width, std::uint32_t height, std::uint32_t format,
        std::uint32_t type, std::uint32_t pixels, const GlesPixelUnpack& unpack)
    {
        const auto layout = pixel_layout(format, type);
        if (!layout || !valid_alignment(unpack.alignment))
            return std::nullopt;
        std::vector<std::uint32_t> result(
            static_cast<std::size_t>(width) * height, 0);
        if (pixels == 0 || width == 0 || height == 0)
            return result;
        const auto row_bytes =
            static_cast<std::uint64_t>(width) * layout->bytes_per_pixel;
        const auto row_length =
            unpack.row_length != 0U ? unpack.row_length : width;
        const auto source_row_bytes =
            static_cast<std::uint64_t>(row_length) * layout->bytes_per_pixel;
        const auto stride =
            unpack.row_bytes != 0U
                ? static_cast<std::uint64_t>(unpack.row_bytes)
                : (source_row_bytes + unpack.alignment - 1U) &
                      ~static_cast<std::uint64_t>(unpack.alignment - 1U);
        if (stride > gles_abi::maximum_resource_bytes)
            return std::nullopt;
        const auto start = static_cast<std::uint64_t>(pixels) +
                           stride * unpack.skip_rows +
                           static_cast<std::uint64_t>(unpack.skip_pixels) *
                               layout->bytes_per_pixel;
        const auto total = stride * (height - 1U) + row_bytes;
        if (total > gles_abi::maximum_resource_bytes ||
            start > std::numeric_limits<std::uint32_t>::max() ||
            start + total > static_cast<std::uint64_t>(
                                std::numeric_limits<std::uint32_t>::max()) +
                                1U) {
            return std::nullopt;
        }
        const auto source = memory.read_bytes(
            static_cast<std::uint32_t>(start), static_cast<std::size_t>(total));
        if (!source)
            return std::nullopt;
        for (std::uint32_t y = 0; y < height; ++y) {
            for (std::uint32_t x = 0; x < width; ++x) {
                const auto offset = static_cast<std::size_t>(
                    static_cast<std::uint64_t>(y) * stride +
                    static_cast<std::uint64_t>(x) * layout->bytes_per_pixel);
                result[static_cast<std::size_t>(y) * width + x] =
                    decode_pixel(std::span<const std::byte> { *source }.subspan(
                                     offset, layout->bytes_per_pixel),
                        format, type);
            }
        }
        return result;
    }

    // PVRTC stores one 64-bit word per 4x4 (4bpp) or 8x4 (2bpp) texel region.
    // The guest firmware normally lets the PowerVR driver decode these words;
    // keeping the decoder here makes compressed uploads follow the same
    // resource lifetime and host-surface path as ordinary GLES textures.
    constexpr std::uint32_t compressed_rgb_pvrtc_2bpp = 0x8c01;
    constexpr std::uint32_t compressed_rgba_pvrtc_2bpp = 0x8c03;
    constexpr std::uint32_t compressed_rgb_pvrtc_4bpp = 0x8c00;
    constexpr std::uint32_t compressed_rgba_pvrtc_4bpp = 0x8c02;

    struct PvrtcColour {
        int red { };
        int green { };
        int blue { };
        int alpha { };
    };

    struct PvrtcWord {
        std::uint32_t modulation { };
        std::uint32_t colour { };
    };

    int expand_channel(int value, int maximum)
    {
        return (value * 255 + maximum / 2) / maximum;
    }

    PvrtcColour pvrtc_colour_a(std::uint32_t value)
    {
        if ((value & 0x8000U) != 0) {
            return { expand_channel((value >> 10U) & 0x1fU, 0x1f),
                expand_channel((value >> 5U) & 0x1fU, 0x1f),
                expand_channel((value >> 1U) & 0x0fU, 0x0f), 255 };
        }
        return { expand_channel((value >> 8U) & 0x0fU, 0x0f),
            expand_channel((value >> 4U) & 0x0fU, 0x0f),
            expand_channel((value >> 1U) & 0x07U, 0x07),
            expand_channel((value >> 11U) & 0x07U, 0x07) };
    }

    PvrtcColour pvrtc_colour_b(std::uint32_t value)
    {
        if ((value & 0x80000000U) != 0) {
            return { expand_channel((value >> 26U) & 0x1fU, 0x1f),
                expand_channel((value >> 21U) & 0x1fU, 0x1f),
                expand_channel((value >> 16U) & 0x1fU, 0x1f), 255 };
        }
        return { expand_channel((value >> 23U) & 0x0fU, 0x0f),
            expand_channel((value >> 19U) & 0x0fU, 0x0f),
            expand_channel((value >> 15U) & 0x0fU, 0x0f),
            expand_channel((value >> 27U) & 0x07U, 0x07) };
    }

    PvrtcColour interpolate_colour(const PvrtcColour& top_left,
        const PvrtcColour& top_right, const PvrtcColour& bottom_left,
        const PvrtcColour& bottom_right, std::uint32_t x, std::uint32_t y,
        std::uint32_t width, std::uint32_t height)
    {
        const auto blend = [](int first, int second, std::uint32_t position,
                               std::uint32_t extent) {
            return (first * static_cast<int>(extent - position) +
                       second * static_cast<int>(position) +
                       static_cast<int>(extent / 2U)) /
                   static_cast<int>(extent);
        };
        const auto top =
            PvrtcColour { blend(top_left.red, top_right.red, x, width),
                blend(top_left.green, top_right.green, x, width),
                blend(top_left.blue, top_right.blue, x, width),
                blend(top_left.alpha, top_right.alpha, x, width) };
        const auto bottom =
            PvrtcColour { blend(bottom_left.red, bottom_right.red, x, width),
                blend(bottom_left.green, bottom_right.green, x, width),
                blend(bottom_left.blue, bottom_right.blue, x, width),
                blend(bottom_left.alpha, bottom_right.alpha, x, width) };
        return { blend(top.red, bottom.red, y, height),
            blend(top.green, bottom.green, y, height),
            blend(top.blue, bottom.blue, y, height),
            blend(top.alpha, bottom.alpha, y, height) };
    }

    std::uint32_t pvrtc_twiddle(std::uint32_t width, std::uint32_t height,
        std::uint32_t x, std::uint32_t y)
    {
        auto minimum = width;
        auto maximum = y;
        if (height < width) {
            minimum = height;
            maximum = x;
        }
        std::uint32_t result = 0;
        std::uint32_t source_bit = 1;
        std::uint32_t destination_bit = 1;
        std::uint32_t shift = 0;
        while (source_bit < minimum) {
            if ((y & source_bit) != 0)
                result |= destination_bit;
            if ((x & source_bit) != 0)
                result |= destination_bit << 1U;
            source_bit <<= 1U;
            destination_bit <<= 2U;
            ++shift;
        }
        maximum >>= shift;
        return result | (maximum << (shift * 2U));
    }

    bool is_power_of_two(std::uint32_t value)
    {
        return value != 0 && (value & (value - 1U)) == 0;
    }

    std::optional<std::vector<std::uint32_t>> decode_pvrtc(AddressSpace& memory,
        std::uint32_t width, std::uint32_t height, std::uint32_t format,
        std::uint32_t image_size, std::uint32_t pixels)
    {
        const auto two_bpp = format == compressed_rgb_pvrtc_2bpp ||
                             format == compressed_rgba_pvrtc_2bpp;
        const auto has_alpha = format == compressed_rgba_pvrtc_2bpp ||
                               format == compressed_rgba_pvrtc_4bpp;
        const auto block_width = two_bpp ? 8U : 4U;
        const auto minimum_width = two_bpp ? 16U : 8U;
        const auto minimum_height = 8U;
        if (width == 0 || height == 0 ||
            width > gles_abi::maximum_texture_dimension ||
            height > gles_abi::maximum_texture_dimension) {
            return std::nullopt;
        }

        const auto padded_width = std::max(width, minimum_width);
        const auto padded_height = std::max(height, minimum_height);
        const auto word_count_x =
            std::max(2U, (padded_width + block_width - 1U) / block_width);
        const auto word_count_y = std::max(2U, (padded_height + 3U) / 4U);
        const auto decoded_width = word_count_x * block_width;
        const auto decoded_height = word_count_y * 4U;
        const auto word_count =
            static_cast<std::uint64_t>(word_count_x) * word_count_y;
        const auto compressed_bytes = word_count * 8U;
        const auto decoded_pixels =
            static_cast<std::uint64_t>(decoded_width) * decoded_height;
        if (compressed_bytes > image_size ||
            compressed_bytes > gles_abi::maximum_resource_bytes ||
            decoded_pixels >
                gles_abi::maximum_resource_bytes / sizeof(std::uint32_t) ||
            compressed_bytes > std::numeric_limits<std::uint32_t>::max()) {
            return std::nullopt;
        }
        if (pixels == 0 || compressed_bytes == 0)
            return std::nullopt;
        const auto source = memory.read_bytes(
            pixels, static_cast<std::size_t>(compressed_bytes));
        if (!source)
            return std::nullopt;

        const auto read_word = [&](std::uint64_t byte_offset) {
            const auto read32 = [&](std::uint64_t offset) {
                return std::to_integer<std::uint32_t>((*source)[offset]) |
                       (std::to_integer<std::uint32_t>((*source)[offset + 1U])
                           << 8U) |
                       (std::to_integer<std::uint32_t>((*source)[offset + 2U])
                           << 16U) |
                       (std::to_integer<std::uint32_t>((*source)[offset + 3U])
                           << 24U);
            };
            return PvrtcWord { read32(byte_offset), read32(byte_offset + 4U) };
        };

        const auto wrap = [](int value, std::uint32_t extent) {
            const auto signed_extent = static_cast<int>(extent);
            value %= signed_extent;
            return value < 0 ? value + signed_extent : value;
        };
        const auto twiddled =
            is_power_of_two(word_count_x) && is_power_of_two(word_count_y);
        const auto word_at = [&](int x, int y) {
            const auto wrapped_x =
                static_cast<std::uint32_t>(wrap(x, word_count_x));
            const auto wrapped_y =
                static_cast<std::uint32_t>(wrap(y, word_count_y));
            const auto index = twiddled
                                   ? pvrtc_twiddle(word_count_x, word_count_y,
                                         wrapped_x, wrapped_y)
                                   : wrapped_y * word_count_x + wrapped_x;
            return read_word(static_cast<std::uint64_t>(index) * 8U);
        };

        std::vector<std::uint32_t> decoded(
            static_cast<std::size_t>(decoded_pixels), 0U);
        const auto word_height = 4U;
        const auto half_width = block_width / 2U;
        const auto half_height = word_height / 2U;
        const auto modulation_index = [](std::uint32_t x, std::uint32_t y) {
            return static_cast<std::size_t>(x) * 8U + y;
        };
        const int replication[4] = { 0, 3, 5, 8 };

        for (int word_y = -1; word_y < static_cast<int>(word_count_y) - 1;
            ++word_y) {
            for (int word_x = -1; word_x < static_cast<int>(word_count_x) - 1;
                ++word_x) {
                const auto p = word_at(word_x, word_y);
                const auto q = word_at(word_x + 1, word_y);
                const auto r = word_at(word_x, word_y + 1);
                const auto s = word_at(word_x + 1, word_y + 1);
                std::array<int, 16 * 8> modulation_values { };
                std::array<int, 16 * 8> modulation_modes { };

                const auto unpack = [&](const PvrtcWord& word,
                                        std::uint32_t offset_x,
                                        std::uint32_t offset_y) {
                    auto mode = word.colour & 1U;
                    auto bits = word.modulation;
                    if (two_bpp) {
                        if (mode != 0) {
                            if ((bits & 1U) != 0)
                                mode = (bits & (1U << 20U)) != 0 ? 3U : 2U;
                            if ((bits & (1U << 21U)) != 0)
                                bits |= 1U << 20U;
                            else
                                bits &= ~(1U << 20U);
                            bits = (bits & 2U) != 0 ? bits | 1U : bits & ~1U;
                            for (std::uint32_t y = 0; y < 4; ++y) {
                                for (std::uint32_t x = 0; x < 8; ++x) {
                                    modulation_modes[modulation_index(
                                        x + offset_x, y + offset_y)] =
                                        static_cast<int>(mode);
                                    if (((x ^ y) & 1U) == 0) {
                                        modulation_values[modulation_index(
                                            x + offset_x, y + offset_y)] =
                                            static_cast<int>(bits & 3U);
                                        bits >>= 2U;
                                    }
                                }
                            }
                        } else {
                            for (std::uint32_t y = 0; y < 4; ++y) {
                                for (std::uint32_t x = 0; x < 8; ++x) {
                                    modulation_modes[modulation_index(
                                        x + offset_x, y + offset_y)] = 0;
                                    modulation_values[modulation_index(
                                        x + offset_x, y + offset_y)] =
                                        (bits & 1U) != 0 ? 3 : 0;
                                    bits >>= 1U;
                                }
                            }
                        }
                        return;
                    }
                    for (std::uint32_t y = 0; y < 4; ++y) {
                        for (std::uint32_t x = 0; x < 4; ++x) {
                            modulation_modes[modulation_index(x + offset_x,
                                y + offset_y)] = static_cast<int>(mode);
                            auto value = static_cast<int>(bits & 3U);
                            if (mode != 0) {
                                static constexpr int values[4] = { 0, 4, 14,
                                    8 };
                                value = values[value];
                            } else {
                                value *= 3;
                                if (value > 3)
                                    --value;
                            }
                            modulation_values[modulation_index(
                                x + offset_x, y + offset_y)] = value;
                            bits >>= 2U;
                        }
                    }
                };
                unpack(p, 0, 0);
                unpack(q, block_width, 0);
                unpack(r, 0, word_height);
                unpack(s, block_width, word_height);

                const auto modulation_at = [&](std::uint32_t x,
                                               std::uint32_t y) {
                    const auto index = modulation_index(x, y);
                    if (!two_bpp)
                        return modulation_values[index];
                    const auto mode = modulation_modes[index];
                    if (mode == 0 || ((x ^ y) & 1U) == 0)
                        return replication[modulation_values[index]];
                    const auto value_at = [&](int nx, int ny) {
                        return replication[modulation_values[modulation_index(
                            static_cast<std::uint32_t>(nx),
                            static_cast<std::uint32_t>(ny))]];
                    };
                    if (mode == 1)
                        return (value_at(static_cast<int>(x) - 1,
                                    static_cast<int>(y)) +
                                   value_at(static_cast<int>(x) + 1,
                                       static_cast<int>(y)) +
                                   value_at(static_cast<int>(x),
                                       static_cast<int>(y) - 1) +
                                   value_at(static_cast<int>(x),
                                       static_cast<int>(y) + 1) +
                                   2) /
                               4;
                    if (mode == 2)
                        return (value_at(static_cast<int>(x) - 1,
                                    static_cast<int>(y)) +
                                   value_at(static_cast<int>(x) + 1,
                                       static_cast<int>(y)) +
                                   1) /
                               2;
                    return (value_at(
                                static_cast<int>(x), static_cast<int>(y) - 1) +
                               value_at(static_cast<int>(x),
                                   static_cast<int>(y) + 1) +
                               1) /
                           2;
                };

                std::array<PvrtcColour, 32> upscaled_a { };
                std::array<PvrtcColour, 32> upscaled_b { };
                for (std::uint32_t y = 0; y < word_height; ++y) {
                    for (std::uint32_t x = 0; x < block_width; ++x) {
                        const auto colour_a = interpolate_colour(
                            pvrtc_colour_a(p.colour), pvrtc_colour_a(q.colour),
                            pvrtc_colour_a(r.colour), pvrtc_colour_a(s.colour),
                            x, y, block_width, word_height);
                        const auto colour_b = interpolate_colour(
                            pvrtc_colour_b(p.colour), pvrtc_colour_b(q.colour),
                            pvrtc_colour_b(r.colour), pvrtc_colour_b(s.colour),
                            x, y, block_width, word_height);
                        const auto index =
                            static_cast<std::size_t>(y * block_width + x);
                        upscaled_a[index] = colour_a;
                        upscaled_b[index] = colour_b;
                    }
                }
                const auto blend_pixel = [&](const PvrtcColour& a,
                                             const PvrtcColour& b, int value) {
                    const auto punch_through = value > 10;
                    if (punch_through)
                        value -= 10;
                    value = std::clamp(value, 0, 8);
                    PvrtcColour result { (a.red * (8 - value) + b.red * value) /
                                             8,
                        (a.green * (8 - value) + b.green * value) / 8,
                        (a.blue * (8 - value) + b.blue * value) / 8,
                        punch_through
                            ? 0
                            : (a.alpha * (8 - value) + b.alpha * value) / 8 };
                    if (!has_alpha)
                        result.alpha = 255;
                    return result;
                };
                std::array<PvrtcColour, 32> pixels_in_word { };
                for (std::uint32_t y = 0; y < word_height; ++y) {
                    for (std::uint32_t x = 0; x < block_width; ++x) {
                        const auto value =
                            modulation_at(x + half_width, y + half_height);
                        const auto index =
                            static_cast<std::size_t>(y * block_width + x);
                        const auto result = blend_pixel(
                            upscaled_a[index], upscaled_b[index], value);
                        pixels_in_word[two_bpp ? index
                                               : static_cast<std::size_t>(
                                                     x * word_height + y)] =
                            result;
                    }
                }
                const auto store = [&](int x, int y,
                                       const PvrtcColour& colour) {
                    const auto red = static_cast<std::uint32_t>(
                        std::clamp(colour.red, 0, 255));
                    const auto green = static_cast<std::uint32_t>(
                        std::clamp(colour.green, 0, 255));
                    const auto blue = static_cast<std::uint32_t>(
                        std::clamp(colour.blue, 0, 255));
                    const auto alpha = static_cast<std::uint32_t>(
                        std::clamp(colour.alpha, 0, 255));
                    decoded[static_cast<std::size_t>(y) * decoded_width + x] =
                        (alpha << 24U) | (red << 16U) | (green << 8U) | blue;
                };
                for (std::uint32_t y = 0; y < half_height; ++y) {
                    for (std::uint32_t x = 0; x < half_width; ++x) {
                        const auto p_x = static_cast<int>(
                            wrap(word_x, word_count_x) * block_width + x +
                            half_width);
                        const auto p_y = static_cast<int>(
                            wrap(word_y, word_count_y) * word_height + y +
                            half_height);
                        const auto q_x = static_cast<int>(
                            wrap(word_x + 1, word_count_x) * block_width + x);
                        const auto q_y = p_y;
                        const auto r_x = p_x;
                        const auto r_y = static_cast<int>(
                            wrap(word_y + 1, word_count_y) * word_height + y);
                        const auto s_x = q_x;
                        const auto s_y = r_y;
                        store(p_x, p_y, pixels_in_word[y * block_width + x]);
                        store(q_x, q_y,
                            pixels_in_word[y * block_width + x + half_width]);
                        store(r_x, r_y,
                            pixels_in_word[(y + half_height) * block_width +
                                           x]);
                        store(s_x, s_y,
                            pixels_in_word[(y + half_height) * block_width + x +
                                           half_width]);
                    }
                }
            }
        }

        std::vector<std::uint32_t> result(
            static_cast<std::size_t>(width) * height, 0U);
        for (std::uint32_t y = 0; y < height; ++y) {
            std::copy_n(
                decoded.begin() + static_cast<std::size_t>(y) * decoded_width,
                width, result.begin() + static_cast<std::size_t>(y) * width);
        }
        return result;
    }

    std::optional<GlesResourceStore::TextureLevel> decode_surface(
        AddressSpace& memory, const SurfaceStore& surfaces,
        const SurfaceStore::Backing& backing)
    {
        if (backing.width > gles_abi::maximum_texture_dimension ||
            backing.height > gles_abi::maximum_texture_dimension) {
            return std::nullopt;
        }
        const auto pixel_count =
            static_cast<std::uint64_t>(backing.width) * backing.height;
        if (pixel_count >
            gles_abi::maximum_resource_bytes / sizeof(std::uint32_t)) {
            return std::nullopt;
        }
        auto pixels = surfaces.read_argb(memory, backing.id);
        if (!pixels || pixels->size() != pixel_count)
            return std::nullopt;
        return GlesResourceStore::TextureLevel { backing.width, backing.height,
            gles_abi::bgra_apple, std::move(*pixels), backing.id, 0, { }, 0 };
    }

} // namespace

std::uint64_t GlesResourceStore::allocate_texture_revision()
{
    const auto revision = next_texture_revision_++;
    if (next_texture_revision_ == 0)
        next_texture_revision_ = 1;
    return revision;
}

void GlesResourceStore::reset()
{
    textures_.clear();
    buffers_.clear();
    generated_textures_.clear();
    generated_buffers_.clear();
    next_texture_ = 1;
    next_buffer_ = 1;
    next_texture_revision_ = 1;
}

void GlesResourceStore::inherit_state(const GlesResourceStore& parent)
{
    textures_ = parent.textures_;
    buffers_ = parent.buffers_;
    generated_textures_ = parent.generated_textures_;
    generated_buffers_ = parent.generated_buffers_;
    next_texture_ = parent.next_texture_;
    next_buffer_ = parent.next_buffer_;
    next_texture_revision_ = parent.next_texture_revision_;
}

std::uint32_t GlesResourceStore::generate_texture()
{
    const auto name = next_texture_++;
    generated_textures_.insert(name);
    return name;
}

std::uint32_t GlesResourceStore::generate_buffer()
{
    const auto name = next_buffer_++;
    generated_buffers_.insert(name);
    return name;
}

void GlesResourceStore::ensure_texture(std::uint32_t name)
{
    if (name == 0)
        return;
    generated_textures_.insert(name);
    textures_.try_emplace(name, Texture { name, { }, { } });
    next_texture_ = std::max(next_texture_, name + 1U);
}

void GlesResourceStore::ensure_buffer(std::uint32_t name)
{
    if (name == 0)
        return;
    generated_buffers_.insert(name);
    buffers_.try_emplace(name, Buffer { name, 0, { } });
    next_buffer_ = std::max(next_buffer_, name + 1U);
}

void GlesResourceStore::erase_texture(std::uint32_t name)
{
    textures_.erase(name);
    generated_textures_.erase(name);
}

void GlesResourceStore::erase_buffer(std::uint32_t name)
{
    buffers_.erase(name);
    generated_buffers_.erase(name);
}

bool GlesResourceStore::has_texture(std::uint32_t name) const
{
    return textures_.contains(name);
}

bool GlesResourceStore::has_buffer(std::uint32_t name) const
{
    return buffers_.contains(name);
}

std::uint32_t GlesResourceStore::upload_texture_2d(AddressSpace& memory,
    std::uint32_t name, std::uint32_t level, std::uint32_t internal_format,
    std::uint32_t width, std::uint32_t height, std::uint32_t format,
    std::uint32_t type, std::uint32_t pixels, const GlesPixelUnpack& unpack)
{
    if (name == 0 || !textures_.contains(name)) {
        return gles_abi::invalid_operation;
    }
    if (width > gles_abi::maximum_texture_dimension ||
        height > gles_abi::maximum_texture_dimension ||
        static_cast<std::uint64_t>(width) * height * sizeof(std::uint32_t) >
            gles_abi::maximum_resource_bytes) {
        return gles_abi::invalid_value;
    }
    if (!pixel_layout(format, type))
        return gles_abi::invalid_enum;
    auto decoded =
        decode_image(memory, width, height, format, type, pixels, unpack);
    if (!decoded)
        return gles_abi::invalid_value;
    textures_.at(name).levels.insert_or_assign(level,
        TextureLevel { width, height, internal_format, std::move(*decoded),
            std::nullopt, allocate_texture_revision(), { }, 0 });
    return gles_abi::no_error;
}

std::uint32_t GlesResourceStore::allocate_texture_2d(std::uint32_t name,
    std::uint32_t level, std::uint32_t internal_format, std::uint32_t width,
    std::uint32_t height)
{
    if (name == 0U || !textures_.contains(name))
        return gles_abi::invalid_operation;
    if (width == 0U || height == 0U ||
        width > gles_abi::maximum_texture_dimension ||
        height > gles_abi::maximum_texture_dimension ||
        static_cast<std::uint64_t>(width) * height * sizeof(std::uint32_t) >
            gles_abi::maximum_resource_bytes) {
        return gles_abi::invalid_value;
    }
    textures_.at(name).levels.insert_or_assign(
        level, TextureLevel { width, height, internal_format,
                   std::vector<std::uint32_t>(
                       static_cast<std::size_t>(width) * height),
                   std::nullopt, allocate_texture_revision(), { }, 0 });
    return gles_abi::no_error;
}

std::uint32_t GlesResourceStore::upload_compressed_texture_2d(
    AddressSpace& memory, std::uint32_t name, std::uint32_t level,
    std::uint32_t internal_format, std::uint32_t width, std::uint32_t height,
    std::uint32_t image_size, std::uint32_t pixels)
{
    if (name == 0 || !textures_.contains(name))
        return gles_abi::invalid_operation;
    if (internal_format != compressed_rgb_pvrtc_2bpp &&
        internal_format != compressed_rgba_pvrtc_2bpp &&
        internal_format != compressed_rgb_pvrtc_4bpp &&
        internal_format != compressed_rgba_pvrtc_4bpp) {
        return gles_abi::invalid_enum;
    }
    auto decoded = decode_pvrtc(
        memory, width, height, internal_format, image_size, pixels);
    if (!decoded)
        return gles_abi::invalid_value;
    textures_.at(name).levels.insert_or_assign(level,
        TextureLevel { width, height, internal_format, std::move(*decoded),
            std::nullopt, allocate_texture_revision(), { }, 0 });
    return gles_abi::no_error;
}

std::uint32_t GlesResourceStore::update_texture_2d(AddressSpace& memory,
    std::uint32_t name, std::uint32_t level, std::uint32_t x, std::uint32_t y,
    std::uint32_t width, std::uint32_t height, std::uint32_t format,
    std::uint32_t type, std::uint32_t pixels, const GlesPixelUnpack& unpack)
{
    auto texture = textures_.find(name);
    if (name == 0 || texture == textures_.end()) {
        return gles_abi::invalid_operation;
    }
    auto destination = texture->second.levels.find(level);
    if (destination == texture->second.levels.end()) {
        return gles_abi::invalid_operation;
    }
    if (x > destination->second.width || y > destination->second.height ||
        width > destination->second.width - x ||
        height > destination->second.height - y || pixels == 0) {
        return gles_abi::invalid_value;
    }
    if (!pixel_layout(format, type))
        return gles_abi::invalid_enum;
    const auto decoded =
        decode_image(memory, width, height, format, type, pixels, unpack);
    if (!decoded)
        return gles_abi::invalid_value;
    for (std::uint32_t row = 0; row < height; ++row) {
        std::copy_n(decoded->begin() + static_cast<std::size_t>(row) * width,
            width,
            destination->second.argb.begin() +
                static_cast<std::size_t>(y + row) * destination->second.width +
                x);
    }
    destination->second.revision = allocate_texture_revision();
    return gles_abi::no_error;
}

std::uint32_t GlesResourceStore::set_texture_parameter(
    std::uint32_t name, std::uint32_t parameter, std::uint32_t value)
{
    auto texture = textures_.find(name);
    if (name == 0 || texture == textures_.end()) {
        return gles_abi::invalid_operation;
    }
    texture->second.parameters.insert_or_assign(parameter, value);
    return gles_abi::no_error;
}

std::uint32_t GlesResourceStore::import_surface_texture(AddressSpace& memory,
    std::uint32_t name, const SurfaceStore& surfaces, std::uint32_t surface_id,
    bool render_target_inverted_vertical)
{
    auto texture = textures_.find(name);
    if (name == 0 || texture == textures_.end()) {
        return gles_abi::invalid_operation;
    }
    const auto backing = surfaces.find(surface_id);
    if (!backing)
        return gles_abi::invalid_value;
    if (surface_bytes_per_pixel(backing->pixel_format) == 0U) {
        return gles_abi::invalid_enum;
    }
    const auto host_surface = surfaces.host_surface(surface_id);
    if (host_surface &&
        host_surface->gpu_generation() > host_surface->cpu_generation()) {
        TextureLevel imported;
        imported.width = backing->width;
        imported.height = backing->height;
        imported.internal_format = gles_abi::bgra_apple;
        imported.surface_id = backing->id;
        imported.revision = allocate_texture_revision();
        imported.host_generation = host_surface->gpu_generation();
        imported.host_surface = host_surface;
        imported.render_target_inverted_vertical =
            render_target_inverted_vertical;
        texture->second.levels.insert_or_assign(0, std::move(imported));
        return gles_abi::no_error;
    }
    auto decoded = decode_surface(memory, surfaces, *backing);
    if (!decoded)
        return gles_abi::invalid_value;
    decoded->host_surface = host_surface;
    decoded->host_generation =
        host_surface ? host_surface->cpu_generation() : 0;
    decoded->revision = allocate_texture_revision();
    decoded->render_target_inverted_vertical = render_target_inverted_vertical;
    texture->second.levels.insert_or_assign(0, std::move(*decoded));
    return gles_abi::no_error;
}

std::uint32_t GlesResourceStore::refresh_surface_texture(
    AddressSpace& memory, std::uint32_t name, const SurfaceStore& surfaces)
{
    auto texture = textures_.find(name);
    if (name == 0 || texture == textures_.end()) {
        return gles_abi::no_error;
    }
    auto level = texture->second.levels.find(0);
    if (level == texture->second.levels.end() || !level->second.surface_id) {
        return gles_abi::no_error;
    }
    const auto backing = surfaces.find(*level->second.surface_id);
    if (!backing)
        return gles_abi::invalid_operation;
    const auto render_target_inverted_vertical =
        level->second.render_target_inverted_vertical;
    const auto host_surface = surfaces.host_surface(*level->second.surface_id);
    if (host_surface &&
        host_surface->gpu_generation() > host_surface->cpu_generation()) {
        const auto generation = host_surface->gpu_generation();
        if (level->second.host_surface == host_surface &&
            level->second.host_generation == generation &&
            level->second.width == backing->width &&
            level->second.height == backing->height) {
            return gles_abi::no_error;
        }
        TextureLevel refreshed;
        refreshed.width = backing->width;
        refreshed.height = backing->height;
        refreshed.internal_format = gles_abi::bgra_apple;
        refreshed.surface_id = backing->id;
        refreshed.revision = allocate_texture_revision();
        refreshed.host_surface = host_surface;
        refreshed.host_generation = generation;
        refreshed.render_target_inverted_vertical =
            render_target_inverted_vertical;
        level->second = std::move(refreshed);
        return gles_abi::no_error;
    }
    if (host_surface && level->second.host_surface == host_surface &&
        level->second.host_generation == host_surface->cpu_generation() &&
        level->second.width == backing->width &&
        level->second.height == backing->height &&
        level->second.internal_format == gles_abi::bgra_apple &&
        level->second.surface_id == backing->id &&
        level->second.render_target_inverted_vertical ==
            render_target_inverted_vertical) {
        return gles_abi::no_error;
    }
    auto decoded = decode_surface(memory, surfaces, *backing);
    if (!decoded) {
        return surface_bytes_per_pixel(backing->pixel_format) != 0U
                   ? gles_abi::invalid_value
                   : gles_abi::invalid_enum;
    }
    decoded->host_surface = host_surface;
    decoded->host_generation =
        host_surface ? host_surface->cpu_generation() : 0;
    decoded->render_target_inverted_vertical = render_target_inverted_vertical;
    if (decoded->width == level->second.width &&
        decoded->height == level->second.height &&
        decoded->internal_format == level->second.internal_format &&
        decoded->surface_id == level->second.surface_id &&
        decoded->host_surface == level->second.host_surface &&
        decoded->host_generation == level->second.host_generation &&
        decoded->render_target_inverted_vertical ==
            level->second.render_target_inverted_vertical &&
        decoded->argb == level->second.argb) {
        return gles_abi::no_error;
    }
    decoded->revision = allocate_texture_revision();
    level->second = std::move(*decoded);
    return gles_abi::no_error;
}

std::shared_ptr<HostSurface> GlesResourceStore::ensure_texture_render_target(
    std::uint32_t name, std::uint32_t level_index, HostGraphicsDevice& graphics,
    std::uint64_t owner, std::uint64_t surface)
{
    auto texture = textures_.find(name);
    if (name == 0U || texture == textures_.end())
        return nullptr;
    auto level = texture->second.levels.find(level_index);
    if (level == texture->second.levels.end() || level->second.width == 0U ||
        level->second.height == 0U || level->second.surface_id ||
        level->second.argb.size() !=
            static_cast<std::size_t>(level->second.width) *
                level->second.height) {
        return nullptr;
    }
    const auto key = HostSurfaceKey { owner, surface };
    const auto descriptor = HostSurfaceDescriptor { level->second.width,
        level->second.height, level->second.width * 4U,
        surface_pixel_format_bgra, PerfSurfaceKind::GlesRenderTarget };
    if (!level->second.host_surface ||
        level->second.host_surface->key() != key ||
        level->second.host_surface->descriptor().width != descriptor.width ||
        level->second.host_surface->descriptor().height != descriptor.height) {
        level->second.host_surface =
            graphics.create_surface(key, descriptor, level->second.argb);
        if (!level->second.host_surface)
            return nullptr;
        level->second.host_generation =
            level->second.host_surface->cpu_generation();
    }
    // A texture's first row is its GL lower edge. Native host targets use a
    // top-left row origin, so ordinary framebuffer rendering reverses Y.
    level->second.render_target_inverted_vertical = true;
    return level->second.host_surface;
}

bool GlesResourceStore::commit_texture_render_target(std::uint32_t name,
    std::uint32_t level_index, std::span<const std::uint32_t> pixels)
{
    auto texture = textures_.find(name);
    if (name == 0U || texture == textures_.end())
        return false;
    auto level = texture->second.levels.find(level_index);
    if (level == texture->second.levels.end() || level->second.surface_id ||
        !level->second.host_surface ||
        pixels.size() != static_cast<std::size_t>(level->second.width) *
                             level->second.height) {
        return false;
    }
    level->second.argb.assign(pixels.begin(), pixels.end());
    level->second.host_surface->replace_cpu(level->second.argb);
    level->second.host_generation =
        level->second.host_surface->cpu_generation();
    level->second.revision = allocate_texture_revision();
    return true;
}

void GlesResourceStore::update_texture_render_target_generation(
    std::uint32_t name, std::uint32_t level_index)
{
    auto texture = textures_.find(name);
    if (name == 0U || texture == textures_.end())
        return;
    auto level = texture->second.levels.find(level_index);
    if (level == texture->second.levels.end() || !level->second.host_surface) {
        return;
    }
    level->second.host_generation =
        std::max(level->second.host_surface->cpu_generation(),
            level->second.host_surface->gpu_generation());
}

bool GlesResourceStore::synchronize_texture_to_cpu(std::uint32_t name,
    std::uint32_t level_index, HostGraphicsDevice& graphics)
{
    auto texture = textures_.find(name);
    if (name == 0U || texture == textures_.end())
        return true;
    auto level = texture->second.levels.find(level_index);
    if (level == texture->second.levels.end() || !level->second.host_surface)
        return true;
    auto& image = level->second;
    const auto expected = static_cast<std::size_t>(image.width) * image.height;
    const auto gpu_ahead = image.host_surface->gpu_generation() >
                           image.host_surface->cpu_generation();
    if (!gpu_ahead && image.argb.size() == expected)
        return true;
    if (gpu_ahead &&
        graphics.native_image(*image.host_surface).api ==
            HostNativeImage::Api::None) {
        return false;
    }
    if (!graphics.map_cpu(
            *image.host_surface, true, PerfCpuMapReason::SoftwareFallback)) {
        return false;
    }
    std::vector<std::uint32_t> pixels;
    {
        // The mapping holds the surface's lock: leave it before asking the
        // surface for its generations.
        auto mapping = image.host_surface->map_cpu(
            false, PerfCpuMapReason::SoftwareFallback);
        const auto& frame = mapping.frame();
        if (frame.width != image.width || frame.height != image.height ||
            frame.pixels.size() != expected) {
            return false;
        }
        pixels = frame.pixels;
    }
    image.argb = std::move(pixels);
    image.host_generation = std::max(image.host_surface->cpu_generation(),
        image.host_surface->gpu_generation());
    image.revision = allocate_texture_revision();
    return true;
}

bool GlesResourceStore::materialize_surface_textures(
    HostGraphicsDevice& graphics)
{
    for (auto& [name, texture] : textures_) {
        static_cast<void>(name);
        for (auto& [index, level] : texture.levels) {
            static_cast<void>(index);
            if (!level.host_surface ||
                level.argb.size() ==
                    static_cast<std::size_t>(level.width) * level.height) {
                continue;
            }
            if (level.host_surface->gpu_generation() >
                    level.host_surface->cpu_generation() &&
                graphics.native_image(*level.host_surface).api ==
                    HostNativeImage::Api::None) {
                return false;
            }
            if (!graphics.map_cpu(*level.host_surface, true,
                    PerfCpuMapReason::SoftwareFallback)) {
                return false;
            }
            auto mapping = level.host_surface->map_cpu(
                false, PerfCpuMapReason::SoftwareFallback);
            const auto& frame = mapping.frame();
            if (frame.width != level.width || frame.height != level.height ||
                frame.pixels.size() !=
                    static_cast<std::size_t>(level.width) * level.height) {
                return false;
            }
            level.argb = frame.pixels;
            level.host_generation =
                std::max(level.host_surface->cpu_generation(),
                    level.host_surface->gpu_generation());
            level.revision = allocate_texture_revision();
        }
    }
    return true;
}

std::uint32_t GlesResourceStore::upload_buffer(AddressSpace& memory,
    std::uint32_t name, std::uint32_t size, std::uint32_t data,
    std::uint32_t usage)
{
    auto buffer = buffers_.find(name);
    if (name == 0 || buffer == buffers_.end()) {
        return gles_abi::invalid_operation;
    }
    if (size > gles_abi::maximum_resource_bytes) {
        return gles_abi::out_of_memory;
    }
    std::vector<std::byte> bytes(size);
    if (data != 0 && size != 0) {
        const auto source = memory.read_bytes(data, size);
        if (!source)
            return gles_abi::invalid_value;
        bytes = *source;
    }
    buffer->second.usage = usage;
    buffer->second.bytes = std::move(bytes);
    return gles_abi::no_error;
}

std::uint32_t GlesResourceStore::update_buffer(AddressSpace& memory,
    std::uint32_t name, std::uint32_t offset, std::uint32_t size,
    std::uint32_t data)
{
    auto buffer = buffers_.find(name);
    if (name == 0 || buffer == buffers_.end()) {
        return gles_abi::invalid_operation;
    }
    if (offset > buffer->second.bytes.size() ||
        size > buffer->second.bytes.size() - offset || data == 0) {
        return gles_abi::invalid_value;
    }
    const auto source = memory.read_bytes(data, size);
    if (!source)
        return gles_abi::invalid_value;
    std::copy(
        source->begin(), source->end(), buffer->second.bytes.begin() + offset);
    return gles_abi::no_error;
}

GlesResourceStore::Texture* GlesResourceStore::texture(std::uint32_t name)
{
    const auto found = textures_.find(name);
    return found == textures_.end() ? nullptr : &found->second;
}

const GlesResourceStore::Texture* GlesResourceStore::texture(
    std::uint32_t name) const
{
    const auto found = textures_.find(name);
    return found == textures_.end() ? nullptr : &found->second;
}

const GlesResourceStore::Buffer* GlesResourceStore::buffer(
    std::uint32_t name) const
{
    const auto found = buffers_.find(name);
    return found == buffers_.end() ? nullptr : &found->second;
}

} // namespace shade
