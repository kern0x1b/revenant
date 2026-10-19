// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define observed MBX2D surface, clipping, transform and blend
// contracts.

#pragma once

#include <cstdint>

namespace shade::mbx2d_abi {

inline constexpr std::uint32_t success = 0;
inline constexpr std::uint32_t failure = 1;

// Both the early monolithic and later private MBX2D frameworks expose an
// eight-megabyte maximum backing allocation through
// mbx2DGetMaxSurfaceSize. This is a byte limit, not a width/height pair.
inline constexpr std::uint32_t maximum_surface_size = 8U * 1024U * 1024U;

// Firmware writes this value to both fields of the caller's width/height
// result in mbx2DGetMaxSurfaceDimensions. The ABI and limit are shared by the
// early monolithic and later private MBX2D frameworks.
inline constexpr std::uint32_t maximum_surface_dimension = 2032;

// Defensive host-side limit for the surface-pointer arrays accepted by the
// firmware FlushSurfaces entry points. LayerKit submits one or a small batch;
// bounding the guest-controlled count avoids an unbounded validation walk.
inline constexpr std::uint32_t maximum_flush_surface_count = 4096;

// LayerKit's firmware mapping from CoreSurface 'BGRA' to the MBX2D internal
// format word passed to SetSource/SetDestinationSurface.
inline constexpr std::uint32_t pixel_format_bgra = 0x00060000U;

// LayerKit uses RGB555 for opaque, memory-efficient image strips such as the
// rows in the Settings wallpaper picker.
inline constexpr std::uint32_t pixel_format_rgb555 = 0x00048000U;

// The firmware MBX2D implementation accepts exactly these two capability
// words in mbx2DEnable/Disable. LayerKit uses them for alpha composition and
// the right-angle source transform respectively.
inline constexpr std::uint32_t feature_blend = 0x10000000U;
inline constexpr std::uint32_t feature_rotation = 0x10000001U;

// Values emitted by the iPhoneOS 1.0 LayerKit affine fast path. The upper-byte
// sequence represents successive clockwise quarter turns.
inline constexpr std::uint32_t rotation_identity = 0x00000000U;
inline constexpr std::uint32_t rotation_clockwise_90 = 0x02000000U;
inline constexpr std::uint32_t rotation_180 = 0x04000000U;
inline constexpr std::uint32_t rotation_clockwise_270 = 0x06000000U;

inline constexpr std::uint32_t float_one_bits = 0x3f800000U;

// Validation masks used by the real MBX2D client library before it records a
// simple or complex blend equation in its 124-byte context structure.
inline constexpr std::uint32_t simple_source_factor_mask = 0x00700000U;
inline constexpr std::uint32_t simple_destination_factor_mask = 0x07000000U;
inline constexpr std::uint32_t complex_source_factor_mask = 0x00000007U;
inline constexpr std::uint32_t complex_destination_factor_mask = 0x00000070U;
inline constexpr std::uint32_t complex_operation_mask = 0x00000700U;

// The most common equation emitted by LayerKit for premultiplied BGRA
// source-over composition.
inline constexpr std::uint32_t layerkit_source_over_source_word = 0x00000000U;
inline constexpr std::uint32_t layerkit_source_over_destination_word =
    0x09000000U;

// Source-over with an additional global-alpha multiplier. LayerKit uses the
// same source factor as its crossfade equation, but keeps the ordinary
// one-minus-source-alpha destination factor. This is still premultiplied
// source-over; the global alpha scales both the source colour and alpha.
inline constexpr std::uint32_t layerkit_global_alpha_source_over_source_word =
    0x00500000U;
inline constexpr std::uint32_t
    layerkit_global_alpha_source_over_destination_word = 0x09000000U;

// LayerKit uses this pair while animating between complete scene snapshots.
// Unlike source-over, both factors are derived from the equation's global
// alpha: source * alpha + destination * (1 - alpha).  In particular, the
// source pixel's own alpha must not be folded into the destination factor.
inline constexpr std::uint32_t layerkit_crossfade_source_word = 0x00500000U;
inline constexpr std::uint32_t layerkit_crossfade_destination_word =
    0x0d000000U;

// Complex equation tuple used when LayerKit composites a straight-alpha
// texture. It is the non-premultiplied source-over path; LayerKit selects the
// simple equation above for surfaces marked premultiplied.
inline constexpr std::uint32_t layerkit_mask_source_word = 0x00000006U;
inline constexpr std::uint32_t layerkit_mask_destination_word = 0x00000010U;
inline constexpr std::uint32_t layerkit_mask_operation_word = 0x00000a00U;

} // namespace shade::mbx2d_abi
