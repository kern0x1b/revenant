// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Manage guest MBX client surface bindings and memory
// synchronization.

#include "kernel/mbx2d_hle.hpp"

#include <cstdint>
#include <limits>
#include <span>
#include <utility>

#include "graphics/gles_renderer.hpp"
#include "foundation/userland_hle.hpp"

namespace shade {

std::uint32_t Mbx2dHle::allocate_client_surface(
    std::uint32_t base, std::uint32_t allocation_size, std::uint32_t width)
{
    if (base == 0 || width == 0 ||
        width > std::numeric_limits<std::uint32_t>::max() / 2U ||
        allocation_size < width * 2U ||
        allocation_size - 1U >
            std::numeric_limits<std::uint32_t>::max() - base) {
        return 0;
    }
    const auto handle = next_surface_++;
    surfaces_.emplace(handle, Surface { handle, 0, false, false,
                                  SurfaceStore::Backing { 0, base,
                                      allocation_size, width, 0, 0, 0, { } },
                                  { }, true });
    return handle;
}

std::optional<Mbx2dHle::ResolvedSurface> Mbx2dHle::resolve_source(
    UserlandHleCall& call, const std::optional<Binding>& binding)
{
    auto resolved = resolve(binding);
    if (!resolved || !binding || !resolved->backing ||
        resolved->core_surface_id != 0 || resolved->framebuffer ||
        resolved->backing->pixel_format != surface_pixel_format_bgra ||
        !host_graphics_->accelerated()) {
        return resolved;
    }

    const auto found = surfaces_.find(binding->surface);
    if (found == surfaces_.end() || !found->second.client_backing)
        return resolved;
    auto& client = found->second;
    const HostSurfaceDescriptor descriptor { resolved->width, resolved->height,
        resolved->backing->bytes_per_row, surface_pixel_format_bgra,
        PerfSurfaceKind::Unknown };
    if (client.client_host_source) {
        const auto current = client.client_host_source->descriptor();
        if (current.width != descriptor.width ||
            current.height != descriptor.height ||
            current.bytes_per_row != descriptor.bytes_per_row ||
            current.pixel_format != descriptor.pixel_format) {
            retire_client_host_source(client);
        }
    }

    if (client.client_host_source_dirty) {
        const auto pixels = read_region(
            *resolved, 0, 0, resolved->width, resolved->height, call);
        if (!pixels)
            return resolved;
        if (!client.client_host_source) {
            auto sequence = next_client_host_source_++;
            if (sequence == 0)
                sequence = next_client_host_source_++;
            client.client_host_source = host_graphics_->create_surface(
                { renderer_owner_, sequence }, descriptor, *pixels);
        } else {
            client.client_host_source->replace_cpu(*pixels);
        }
        if (!client.client_host_source)
            return resolved;
        client.client_host_source_dirty = false;
    }
    resolved->host_surface = client.client_host_source;
    return resolved;
}

void Mbx2dHle::retire_client_host_source(Surface& surface)
{
    if (surface.client_host_source) {
        retired_client_host_sources_.push_back(
            surface.client_host_source->key());
        surface.client_host_source.reset();
    }
    surface.client_host_source_dirty = true;
}

void Mbx2dHle::release_retired_client_host_sources()
{
    if (retired_client_host_sources_.empty())
        return;
    host_graphics_->release(
        std::span<const HostSurfaceKey> { retired_client_host_sources_ });
    retired_client_host_sources_.clear();
}

void Mbx2dHle::release_client_renderer_resources()
{
    if (renderer_owner_ != 0 && host_graphics_)
        host_graphics_->release_owner(renderer_owner_);
    retired_client_host_sources_.clear();
}

} // namespace shade
