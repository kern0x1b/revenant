// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define observed MBX2D surface, clipping, transform and blend
// contracts.

#pragma once

#include <cstdint>

namespace emulator::mbx2d_abi {

inline constexpr std::uint32_t success = 0;
inline constexpr std::uint32_t failure = 1;

inline constexpr std::uint32_t maximum_surface_size = 8U * 1024U * 1024U;

inline constexpr std::uint32_t maximum_surface_dimension = 2032;

inline constexpr std::uint32_t maximum_flush_surface_count = 4096;

inline constexpr std::uint32_t pixel_format_bgra = 0x00060000U;

inline constexpr std::uint32_t pixel_format_rgb555 = 0x00048000U;

inline constexpr std::uint32_t feature_blend = 0x10000000U;
inline constexpr std::uint32_t feature_rotation = 0x10000001U;

inline constexpr std::uint32_t rotation_identity = 0x00000000U;
inline constexpr std::uint32_t rotation_clockwise_90 = 0x02000000U;
inline constexpr std::uint32_t rotation_180 = 0x04000000U;
inline constexpr std::uint32_t rotation_clockwise_270 = 0x06000000U;

inline constexpr std::uint32_t float_one_bits = 0x3f800000U;

inline constexpr std::uint32_t simple_source_factor_mask = 0x00700000U;
inline constexpr std::uint32_t simple_destination_factor_mask = 0x07000000U;
inline constexpr std::uint32_t complex_source_factor_mask = 0x00000007U;
inline constexpr std::uint32_t complex_destination_factor_mask = 0x00000070U;
inline constexpr std::uint32_t complex_operation_mask = 0x00000700U;

inline constexpr std::uint32_t layerkit_source_over_source_word = 0x00000000U;
inline constexpr std::uint32_t layerkit_source_over_destination_word =
    0x09000000U;

inline constexpr std::uint32_t layerkit_global_alpha_source_over_source_word =
    0x00500000U;
inline constexpr std::uint32_t
    layerkit_global_alpha_source_over_destination_word = 0x09000000U;

inline constexpr std::uint32_t layerkit_crossfade_source_word = 0x00500000U;
inline constexpr std::uint32_t layerkit_crossfade_destination_word =
    0x0d000000U;

inline constexpr std::uint32_t layerkit_mask_source_word = 0x00000006U;
inline constexpr std::uint32_t layerkit_mask_destination_word = 0x00000010U;
inline constexpr std::uint32_t layerkit_mask_operation_word = 0x00000a00U;

}
