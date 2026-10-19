// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Manage shared guest surfaces, pixel formats and host presentation
// leases.

#pragma once

#include <cstddef>
#include <cstdint>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <span>
#include <vector>

#include "foundation/file_page_cache.hpp"

namespace emulator {

class AddressSpace;
class HostSurface;
class SurfaceTransportLease;
struct HostRectangle;

constexpr std::uint32_t surface_fourcc(char a, char b, char c, char d)
{
    return (static_cast<std::uint32_t>(a) << 24U) |
           (static_cast<std::uint32_t>(b) << 16U) |
           (static_cast<std::uint32_t>(c) << 8U) |
           static_cast<std::uint32_t>(d);
}

inline constexpr std::uint32_t surface_pixel_format_bgra =
    surface_fourcc('B', 'G', 'R', 'A');
inline constexpr std::uint32_t surface_pixel_format_rgb555 =
    surface_fourcc('R', 'G', '1', '5');
inline constexpr std::uint32_t surface_pixel_format_rgb555_le =
    surface_fourcc('L', '5', '5', '5');
inline constexpr std::uint32_t surface_pixel_format_argb1555 =
    surface_fourcc('s', '5', '5', '1');
inline constexpr std::uint32_t surface_pixel_format_yuvs =
    surface_fourcc('y', 'u', 'v', 's');
inline constexpr std::uint32_t surface_pixel_format_2vuy =
    surface_fourcc('2', 'v', 'u', 'y');

constexpr bool surface_is_yuv422(std::uint32_t pixel_format)
{
    return pixel_format == surface_pixel_format_yuvs ||
           pixel_format == surface_pixel_format_2vuy;
}

constexpr bool surface_is_rgb555(std::uint32_t pixel_format)
{
    return pixel_format == surface_pixel_format_rgb555 ||
           pixel_format == surface_pixel_format_rgb555_le;
}

constexpr bool surface_is_packed_555(std::uint32_t pixel_format)
{
    return surface_is_rgb555(pixel_format) ||
           pixel_format == surface_pixel_format_argb1555;
}

constexpr std::uint32_t surface_decode_packed_555(
    std::uint32_t pixel_format, std::uint16_t packed)
{
    const auto red =
        (static_cast<std::uint32_t>(packed >> 10U) & 0x1fU) * 255U / 31U;
    const auto green =
        (static_cast<std::uint32_t>(packed >> 5U) & 0x1fU) * 255U / 31U;
    const auto blue = (static_cast<std::uint32_t>(packed) & 0x1fU) * 255U / 31U;
    const auto alpha =
        pixel_format == surface_pixel_format_argb1555 && (packed & 0x8000U) == 0
            ? 0U
            : 0xffU;
    return (alpha << 24U) | (red << 16U) | (green << 8U) | blue;
}

constexpr std::uint16_t surface_encode_packed_555(
    std::uint32_t pixel_format, std::uint32_t argb)
{
    const auto red = ((argb >> 16U) & 0xffU) * 31U / 255U;
    const auto green = ((argb >> 8U) & 0xffU) * 31U / 255U;
    const auto blue = (argb & 0xffU) * 31U / 255U;
    const auto alpha =
        pixel_format == surface_pixel_format_argb1555 && (argb >> 24U) >= 0x80U
            ? 0x8000U
            : 0U;
    return static_cast<std::uint16_t>(
        alpha | (red << 10U) | (green << 5U) | blue);
}

constexpr std::uint32_t surface_bytes_per_pixel(std::uint32_t pixel_format)
{
    if (pixel_format == surface_pixel_format_bgra)
        return 4U;
    if (surface_is_rgb555(pixel_format) ||
        pixel_format == surface_pixel_format_argb1555 ||
        surface_is_yuv422(pixel_format)) {
        return 2U;
    }
    return 0U;
}

class SurfaceStore {
public:
    struct CpuSynchronizationOptions {
        bool avoid_sync { };
        bool read_only { };
    };

    ~SurfaceStore();

    struct Provenance {
        std::uint32_t producer_process_id { };
        std::uint64_t publication_sequence { };
    };

    struct Backing {
        std::uint32_t id { };
        std::uint32_t base { };
        std::uint32_t allocation_size { };
        std::uint32_t width { };
        std::uint32_t height { };
        std::uint32_t bytes_per_row { };
        std::uint32_t pixel_format { };
        Provenance provenance;
    };

    struct SharedMapping {
        Backing metadata;
        std::uint32_t mapping_size { };
    };

    void reset();
    void inherit_state(const SurfaceStore& parent);
    void share_registry(const SurfaceStore& peer);
    [[nodiscard]] std::uint32_t allocate_identifier();
    [[nodiscard]] std::uint64_t publication_watermark() const;
    [[nodiscard]] bool publish(AddressSpace& memory, Backing backing);
    [[nodiscard]] std::optional<SharedMapping> shared_mapping(
        std::uint32_t id) const;
    [[nodiscard]] std::shared_ptr<SurfaceTransportLease>
    acquire_transport_lease(std::uint32_t id) const;
    [[nodiscard]] std::optional<Backing> import(
        AddressSpace& memory, std::uint32_t id, std::uint32_t mapping_address);
    [[nodiscard]] std::optional<Backing> import(AddressSpace& memory,
        const SharedMapping& expected, std::uint32_t mapping_address,
        std::uint64_t* mapping_lease_token);
    [[nodiscard]] bool retain(std::uint32_t id);
    void release(std::uint32_t id);
    [[nodiscard]] std::optional<Backing> find(std::uint32_t id) const;
    [[nodiscard]] std::shared_ptr<HostSurface> host_surface(
        std::uint32_t id) const;
    [[nodiscard]] std::optional<std::vector<std::uint32_t>> read_argb(
        AddressSpace& memory, std::uint32_t id) const;
    [[nodiscard]] bool synchronize_for_cpu(AddressSpace& memory,
        std::uint32_t id, CpuSynchronizationOptions options) const;
    [[nodiscard]] bool synchronize_from_guest(
        AddressSpace& memory, std::uint32_t id) const;
    [[nodiscard]] bool write_argb(AddressSpace& memory, std::uint32_t id,
        std::span<const std::uint32_t> pixels) const;
    [[nodiscard]] bool write_bytes(AddressSpace& memory, std::uint32_t id,
        std::span<const std::byte> bytes) const;
    [[nodiscard]] bool transfer_scaled(AddressSpace& memory,
        std::uint32_t source_id, std::uint32_t destination_id) const;

private:
    friend class SurfaceTransportLease;
    struct SyncState {
        std::mutex mutex;
        std::vector<std::uint64_t> shared_page_generations;
        std::vector<std::uint32_t> guest_pixel_snapshot;
    };
    struct SharedObject {
        Backing metadata;
        std::uint32_t page_offset { };
        std::uint32_t mapping_size { };
        std::vector<std::shared_ptr<GuestPageBacking>> pages;
        std::shared_ptr<HostSurface> host_surface;
        std::shared_ptr<SyncState> sync_state;
        std::size_t store_references { };
    };
    struct SharedRegistry {
        mutable std::mutex mutex;
        std::map<std::uint32_t, SharedObject> objects;
        std::uint32_t next_identifier { 1 };
        std::uint64_t publication_watermark { };
    };

    [[nodiscard]] std::optional<std::vector<std::uint32_t>> read_guest_argb(
        AddressSpace& memory, const Backing& backing) const;
    [[nodiscard]] std::optional<std::vector<std::uint32_t>>
    read_guest_argb_region(AddressSpace& memory, const Backing& backing,
        HostRectangle rectangle) const;
    [[nodiscard]] bool write_argb_region_to_guest(AddressSpace& memory,
        const Backing& backing, HostRectangle rectangle,
        std::span<const std::uint32_t> pixels) const;
    [[nodiscard]] std::shared_ptr<SyncState> shared_sync_state(
        std::uint32_t id) const;
    void update_guest_sync_generation(
        AddressSpace& memory, const Backing& backing) const;
    void update_guest_snapshot(const Backing& backing, HostRectangle rectangle,
        std::span<const std::uint32_t> pixels) const;

    mutable std::mutex mutex_;
    std::map<std::uint32_t, Backing> backings_;
    std::map<std::uint32_t, std::size_t> backing_references_;
    std::shared_ptr<SharedRegistry> registry_ {
        std::make_shared<SharedRegistry>()
    };
};

}
