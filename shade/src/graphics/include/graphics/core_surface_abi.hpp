// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define observed guest CoreSurface layouts and surface API
// constants.

#pragma once

#include <cstdint>

namespace shade::core_surface_abi {

// Confirmed from the iPhone OS 1.0 CoreSurface ARM framework. Public
// CoreSurfaceBuffer accessors load the private client-buffer pointer from
// offset 8 of the CFRuntime object before calling _CoreSurfaceClientBuffer*.
inline constexpr std::uint32_t public_client_buffer_offset = 8;

// Layout of the private client-buffer object returned by the intercepted
// _CoreSurfaceClientBuffer* transport implementation.
inline constexpr std::uint32_t client_buffer_structure_size = 432;
inline constexpr std::uint32_t client_reference_count_offset = 0;
inline constexpr std::uint32_t client_identifier_offset = 4;
inline constexpr std::uint32_t client_base_address_offset = 8;
inline constexpr std::uint32_t client_allocation_size_offset = 12;
inline constexpr std::uint32_t client_width_offset = 16;
inline constexpr std::uint32_t client_height_offset = 20;
inline constexpr std::uint32_t client_pitch_offset = 24;
inline constexpr std::uint32_t client_data_offset_offset = 28;
inline constexpr std::uint32_t client_pixel_format_offset = 32;
inline constexpr std::uint32_t client_plane_count_offset = 40;

inline constexpr std::uint32_t bytes_per_bgra_pixel = 4;
// CoreSurface predates the public IOSurface API but uses the same lock bits.
// The iPhone OS 1.0 framework forwards these bits unchanged to IOKit method 2.
inline constexpr std::uint32_t lock_read_only = 0x00000001U;
inline constexpr std::uint32_t lock_avoid_sync = 0x00000002U;

} // namespace shade::core_surface_abi
