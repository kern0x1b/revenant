// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Describe firmware userland surface transport capability profiles.

#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <span>
#include <string_view>

namespace shade::surface_transport {

// Firmware-facing user-space surface transports.  Selection follows the
// private symbol family exported by the loaded framework, never an OS build,
// application, or page.  Both profiles publish the same SurfaceStore backing
// while preserving their own client-object layout for native firmware code.
enum class Kind : std::uint8_t {
    CoreSurfaceClientBuffer,
    IOSurfaceClient,
    IOSurfaceClientExtendedMetadata,
};

struct ClientAbi {
    std::string_view name;
    std::string_view image_suffix;
    std::string_view symbol_prefix;
    std::uint32_t public_client_pointer_offset;
    std::uint32_t client_structure_size;
    std::uint32_t reference_count_offset;
    std::uint32_t identifier_offset;
    std::uint32_t base_address_offset;
    std::uint32_t allocation_size_offset;
    std::uint32_t width_offset;
    std::uint32_t height_offset;
    std::uint32_t bytes_per_row_offset;
    std::uint32_t data_offset_offset;
    std::uint32_t pixel_format_offset;
    std::uint32_t plane_count_offset;
    bool lock_seed_output;
    std::array<std::string_view, 7> create_property_symbols;
};

inline constexpr ClientAbi core_surface_client_buffer {
    .name = "core-surface-client-buffer",
    .image_suffix = "/CoreSurface.framework/CoreSurface",
    .symbol_prefix = "_CoreSurfaceClientBuffer",
    .public_client_pointer_offset = 8,
    .client_structure_size = 432,
    .reference_count_offset = 0,
    .identifier_offset = 4,
    .base_address_offset = 8,
    .allocation_size_offset = 12,
    .width_offset = 16,
    .height_offset = 20,
    .bytes_per_row_offset = 24,
    .data_offset_offset = 28,
    .pixel_format_offset = 32,
    .plane_count_offset = 40,
    .lock_seed_output = false,
    .create_property_symbols = { "_kCoreSurfaceBufferClientAddress",
        "_kCoreSurfaceBufferAllocSize", "_kCoreSurfaceBufferWidth",
        "_kCoreSurfaceBufferHeight", "_kCoreSurfaceBufferPitch",
        "_kCoreSurfaceBufferPixelFormat", "_kCoreSurfaceBufferOffset" },
};

// iPhoneOS builds with a separate IOSurface framework keep a 1,216-byte
// private client object.  CoreSurface remains a native compatibility wrapper
// and forwards into this symbol family.
inline constexpr ClientAbi io_surface_client {
    .name = "io-surface-client",
    .image_suffix = "/IOSurface.framework/IOSurface",
    .symbol_prefix = "_IOSurfaceClient",
    .public_client_pointer_offset = 8,
    .client_structure_size = 1216,
    .reference_count_offset = 0,
    .identifier_offset = 12,
    .base_address_offset = 8,
    .allocation_size_offset = 16,
    .width_offset = 20,
    .height_offset = 24,
    .bytes_per_row_offset = 28,
    .data_offset_offset = 32,
    .pixel_format_offset = 36,
    .plane_count_offset = 44,
    .lock_seed_output = true,
    .create_property_symbols = { "", "_kIOSurfaceAllocSize", "_kIOSurfaceWidth",
        "_kIOSurfaceHeight", "_kIOSurfaceBytesPerRow", "_kIOSurfacePixelFormat",
        "_kIOSurfaceOffset" },
};

// The extended metadata transport retains the public CFRuntime wrapper and
// reference header, but expands both the metadata prefix and client storage.
inline constexpr ClientAbi io_surface_client_extended_metadata = [] {
    auto profile = io_surface_client;
    profile.name = "io-surface-client-extended-metadata";
    profile.client_structure_size = 1360;
    profile.identifier_offset = 24;
    profile.allocation_size_offset = 28;
    profile.width_offset = 32;
    profile.height_offset = 36;
    profile.bytes_per_row_offset = 40;
    profile.data_offset_offset = 44;
    profile.pixel_format_offset = 48;
    profile.plane_count_offset = 56;
    return profile;
}();

// Decode only a leaf word accessor returning r0 from [r0 + immediate].
// Both audited instruction forms return directly, without a prologue or
// additional computation. Other functions cannot identify a client layout.
[[nodiscard]] constexpr std::optional<std::uint32_t> accessor_offset(
    std::span<const std::byte> code)
{
    const auto word = [&](std::size_t offset, std::size_t size) {
        std::uint32_t value = 0;
        for (std::size_t i = 0; i < size; ++i)
            value |= std::to_integer<std::uint32_t>(code[offset + i]) << (8 * i);
        return value;
    };
    if (code.size() >= 4 && (word(0, 2) & 0xf83fU) == 0x6800U &&
        word(2, 2) == 0x4770U)
        return ((word(0, 2) >> 6) & 0x1fU) * 4U;
    if (code.size() >= 8 && (word(0, 4) & 0xfffff000U) == 0xe5900000U &&
        word(4, 4) == 0xe12fff1eU)
        return word(0, 4) & 0xfffU;
    return std::nullopt;
}

[[nodiscard]] constexpr Kind io_surface_kind(
    std::span<const std::byte> width, std::span<const std::byte> height)
{
    if (accessor_offset(width) ==
            io_surface_client_extended_metadata.width_offset &&
        accessor_offset(height) ==
            io_surface_client_extended_metadata.height_offset)
        return Kind::IOSurfaceClientExtendedMetadata;
    return Kind::IOSurfaceClient;
}

[[nodiscard]] constexpr const ClientAbi& for_kind(Kind kind)
{
    switch (kind) {
    case Kind::IOSurfaceClientExtendedMetadata:
        return io_surface_client_extended_metadata;
    case Kind::IOSurfaceClient:
        return io_surface_client;
    case Kind::CoreSurfaceClientBuffer:
        return core_surface_client_buffer;
    }
    return core_surface_client_buffer;
}

} // namespace shade::surface_transport
