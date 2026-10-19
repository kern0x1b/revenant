// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Encode emulated image-device output through the host JPEG codec.

#include "media/jpeg_encoder.hpp"

#include <csetjmp>
#include <cstdio>
#include <cstdlib>
#include <limits>
#include <vector>

extern "C" {
#include <jpeglib.h>
}

namespace shade {
namespace {

    struct JpegErrorState {
        jpeg_error_mgr manager;
        std::jmp_buf jump;
    };

    extern "C" void jpeg_error_exit(j_common_ptr context)
    {
        auto* error = reinterpret_cast<JpegErrorState*>(context->err);
        std::longjmp(error->jump, 1);
    }

} // namespace

std::optional<std::vector<std::byte>> encode_jpeg_argb(
    std::span<const std::uint32_t> pixels, std::uint32_t width,
    std::uint32_t height, int quality)
{
    if (width == 0U || height == 0U ||
        static_cast<std::uint64_t>(width) * height != pixels.size() ||
        width > std::numeric_limits<JDIMENSION>::max() ||
        height > std::numeric_limits<JDIMENSION>::max()) {
        return std::nullopt;
    }

    std::vector<JSAMPLE> rgb(pixels.size() * 3U);
    for (std::size_t index = 0; index < pixels.size(); ++index) {
        const auto pixel = pixels[index];
        rgb[index * 3U] = static_cast<JSAMPLE>((pixel >> 16U) & 0xffU);
        rgb[index * 3U + 1U] = static_cast<JSAMPLE>((pixel >> 8U) & 0xffU);
        rgb[index * 3U + 2U] = static_cast<JSAMPLE>(pixel & 0xffU);
    }

    jpeg_compress_struct compressor { };
    JpegErrorState error { };
    unsigned char* encoded = nullptr;
    unsigned long encoded_size = 0;
    compressor.err = jpeg_std_error(&error.manager);
    error.manager.error_exit = jpeg_error_exit;
    if (setjmp(error.jump) != 0) {
        jpeg_destroy_compress(&compressor);
        std::free(encoded);
        return std::nullopt;
    }

    jpeg_create_compress(&compressor);
    jpeg_mem_dest(&compressor, &encoded, &encoded_size);
    compressor.image_width = static_cast<JDIMENSION>(width);
    compressor.image_height = static_cast<JDIMENSION>(height);
    compressor.input_components = 3;
    compressor.in_color_space = JCS_RGB;
    jpeg_set_defaults(&compressor);
    jpeg_set_quality(&compressor, quality, TRUE);
    jpeg_start_compress(&compressor, TRUE);
    const auto row_size = static_cast<std::size_t>(width) * 3U;
    while (compressor.next_scanline < compressor.image_height) {
        auto* row =
            rgb.data() +
            static_cast<std::size_t>(compressor.next_scanline) * row_size;
        JSAMPROW rows[] { row };
        static_cast<void>(jpeg_write_scanlines(&compressor, rows, 1U));
    }
    jpeg_finish_compress(&compressor);

    std::vector<std::byte> result(encoded_size);
    for (std::size_t index = 0; index < result.size(); ++index)
        result[index] = static_cast<std::byte>(encoded[index]);
    jpeg_destroy_compress(&compressor);
    std::free(encoded);
    return result;
}

} // namespace shade
