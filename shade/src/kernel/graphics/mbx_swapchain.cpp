// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Track MBX surface swaps, retained composition and presentation
// state.

#include "kernel/mbx2d_hle.hpp"

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <vector>

#include "graphics/display.hpp"
#include "graphics/gles_renderer.hpp"
#include "foundation/userland_hle.hpp"

namespace shade {

void Mbx2dHle::initialize_destination(UserlandHleCall& call, RenderState& state)
{
    const auto destination = resolve(state.destination);
    if (!destination || destination->framebuffer || !display_ ||
        destination->width != display_->width() ||
        destination->height != display_->height()) {
        return;
    }
    const auto surface = state.destination->surface;
    if (initialized_destinations_.contains(surface))
        return;

    // CoreGraphics can rasterize static LayerKit content into a newly-created
    // CoreSurface before MBX2D binds it as the render destination.  Keep that
    // CPU-rendered backing store; replacing it with the previous scanout would
    // erase layers such as the lock-screen bottom bar before the first GPU
    // dirty update arrives.
    const auto existing = read_region(
        *destination, 0, 0, destination->width, destination->height, call);
    if (existing && std::any_of(existing->begin(), existing->end(),
                        [](std::uint32_t pixel) { return pixel != 0; })) {
        initialized_destinations_.insert(surface);
        destination_frame_sequences_[surface] =
            display_ ? display_->presented_frames() : 0;
        return;
    }

    auto initial = display_ && display_->presented_frames() != 0
                       ? display_->snapshot().pixels
                       : std::vector<std::uint32_t> { };
    const auto pixel_count =
        static_cast<std::size_t>(destination->width) * destination->height;
    if (initial.size() != pixel_count) {
        initial.assign(pixel_count, 0xff000000U);
    }
    if (write_region(*destination, 0, 0, destination->width,
            destination->height, initial, call)) {
        initialized_destinations_.insert(surface);
        destination_frame_sequences_[surface] =
            display_ ? display_->presented_frames() : 0;
    }
}

void Mbx2dHle::prepare_destination_for_frame(UserlandHleCall& call,
    RenderState& state, DamageRegion damage, std::uint32_t source_surface)
{
    initialize_destination(call, state);
    const auto destination = resolve(state.destination);
    if (!destination || destination->framebuffer || !display_ ||
        destination->width != display_->width() ||
        destination->height != display_->height()) {
        return;
    }
    const auto surface = state.destination->surface;
    const auto sequence = display_ ? display_->presented_frames() : 0;
    const auto prepared = destination_frame_sequences_.find(surface);
    if (prepared != destination_frame_sequences_.end() &&
        prepared->second == sequence) {
        if (const auto current = destination_scene_damage_.find(surface);
            current != destination_scene_damage_.end()) {
            current->second.left = std::min(current->second.left, damage.left);
            current->second.top = std::min(current->second.top, damage.top);
            current->second.right =
                std::max(current->second.right, damage.right);
            current->second.bottom =
                std::max(current->second.bottom, damage.bottom);
        } else {
            destination_scene_damage_[surface] = damage;
        }
        return;
    }
    damage.left = std::clamp<std::int64_t>(damage.left, 0, destination->width);
    damage.top = std::clamp<std::int64_t>(damage.top, 0, destination->height);
    damage.right =
        std::clamp<std::int64_t>(damage.right, damage.left, destination->width);
    damage.bottom = std::clamp<std::int64_t>(
        damage.bottom, damage.top, destination->height);
    const auto current_damage = damage;
    const auto previous_source = destination_scene_sources_.find(surface);
    if (const auto previous = destination_scene_damage_.find(surface);
        previous != destination_scene_damage_.end() &&
        previous_source != destination_scene_sources_.end() &&
        previous_source->second == source_surface &&
        !(damage.left >= previous->second.left &&
            damage.top >= previous->second.top &&
            damage.right <= previous->second.right &&
            damage.bottom <= previous->second.bottom)) {
        damage.left = std::min(damage.left, previous->second.left);
        damage.top = std::min(damage.top, previous->second.top);
        damage.right = std::max(damage.right, previous->second.right);
        damage.bottom = std::max(damage.bottom, previous->second.bottom);
    }
    const auto width = damage.right - damage.left;
    const auto height = damage.bottom - damage.top;
    // LayerKit retains unchanged sibling layers in the swap backing. Extend
    // invalidation across old and new bounds while the same large source moves,
    // but not when it contracts inside its old bounds: the exposed area has
    // already been composed from retained siblings in the current pass.
    // Clearing that area here would replace those pixels with black after they
    // were drawn. A replacement source likewise starts a new scene generation.
    bool cleared { };
    if (width > 0 && height > 0 && host_graphics_->accelerated() &&
        destination->host_surface && destination->backing &&
        destination->backing->pixel_format == surface_pixel_format_bgra &&
        damage.left <= std::numeric_limits<std::int32_t>::max() &&
        damage.top <= std::numeric_limits<std::int32_t>::max() &&
        static_cast<std::uint64_t>(width) <=
            std::numeric_limits<std::uint32_t>::max() &&
        static_cast<std::uint64_t>(height) <=
            std::numeric_limits<std::uint32_t>::max()) {
        cleared = command_encoder_->fill(destination->host_surface,
            { static_cast<std::int32_t>(damage.left),
                static_cast<std::int32_t>(damage.top),
                static_cast<std::uint32_t>(width),
                static_cast<std::uint32_t>(height) },
            0xff000000U, HostCompositeMode::Copy);
    }
    if (!cleared && width > 0 && height > 0) {
        const auto pixel_count =
            static_cast<std::size_t>(width) * static_cast<std::size_t>(height);
        const std::vector<std::uint32_t> clear(pixel_count, 0xff000000U);
        cleared = write_region(
            *destination, damage.left, damage.top, width, height, clear, call);
    }
    if (cleared) {
        destination_frame_sequences_[surface] = sequence;
        destination_scene_damage_[surface] = current_damage;
        destination_scene_sources_[surface] = source_surface;
    }
}

} // namespace shade
