// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Preserve retained scanout content across partial compositor
// updates.

#include "graphics/scanout_composition.hpp"

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <optional>

#include "graphics/gles_abi.hpp"

namespace shade {
namespace {

    constexpr std::uint64_t scanout_background_namespace = 2ULL << 32U;
    constexpr std::uint64_t primary_scene_height_numerator = 2U;
    constexpr std::uint64_t primary_scene_height_denominator = 3U;

    std::optional<HostRectangle> draw_rectangle(std::uint32_t width,
        std::uint32_t height, const GlesRasterState& state,
        std::span<const GlesRasterVertex> vertices)
    {
        if (vertices.empty())
            return std::nullopt;

        auto minimum_x = std::numeric_limits<float>::infinity();
        auto maximum_x = -std::numeric_limits<float>::infinity();
        auto minimum_y = std::numeric_limits<float>::infinity();
        auto maximum_y = -std::numeric_limits<float>::infinity();
        for (const auto& vertex : vertices) {
            if (!std::isfinite(vertex.position[3]) ||
                std::abs(vertex.position[3]) <= 1.0e-6F) {
                return std::nullopt;
            }
            const auto inverse_w = 1.0F / vertex.position[3];
            const auto window_x =
                static_cast<float>(state.viewport_x) +
                (vertex.position[0] * inverse_w * 0.5F + 0.5F) *
                    static_cast<float>(state.viewport_width);
            const auto window_y =
                static_cast<float>(state.viewport_y) +
                (vertex.position[1] * inverse_w * 0.5F + 0.5F) *
                    static_cast<float>(state.viewport_height);
            const auto host_y = state.render_target_inverted_vertical
                                    ? window_y
                                    : static_cast<float>(height) - window_y;
            minimum_x = std::min(minimum_x, window_x);
            maximum_x = std::max(maximum_x, window_x);
            minimum_y = std::min(minimum_y, host_y);
            maximum_y = std::max(maximum_y, host_y);
        }

        auto left = static_cast<std::int32_t>(std::floor(minimum_x));
        auto right = static_cast<std::int32_t>(std::ceil(maximum_x));
        auto top = static_cast<std::int32_t>(std::floor(minimum_y));
        auto bottom = static_cast<std::int32_t>(std::ceil(maximum_y));
        left = std::clamp(left, 0, static_cast<std::int32_t>(width));
        right = std::clamp(right, 0, static_cast<std::int32_t>(width));
        top = std::clamp(top, 0, static_cast<std::int32_t>(height));
        bottom = std::clamp(bottom, 0, static_cast<std::int32_t>(height));

        if (state.scissor_enabled) {
            const auto scissor_left = state.scissor_box[0];
            const auto scissor_right =
                state.scissor_box[0] + state.scissor_box[2];
            const auto scissor_top = state.render_target_inverted_vertical
                                         ? state.scissor_box[1]
                                         : static_cast<std::int32_t>(height) -
                                               state.scissor_box[1] -
                                               state.scissor_box[3];
            const auto scissor_bottom = scissor_top + state.scissor_box[3];
            left = std::max(left, scissor_left);
            right = std::min(right, scissor_right);
            top = std::max(top, scissor_top);
            bottom = std::min(bottom, scissor_bottom);
        }
        if (left >= right || top >= bottom)
            return std::nullopt;
        return HostRectangle { left, top,
            static_cast<std::uint32_t>(right - left),
            static_cast<std::uint32_t>(bottom - top) };
    }

} // namespace

void ScanoutComposition::reset()
{
    frames_.clear();
    backgrounds_.clear();
    local_scene_background_.reset();
}

bool ScanoutComposition::is_screen_surface(
    const std::shared_ptr<HostSurface>& surface, std::uint32_t screen_width,
    std::uint32_t screen_height)
{
    if (!surface)
        return false;
    const auto descriptor = surface->descriptor();
    return descriptor.width == screen_width &&
           descriptor.height == screen_height;
}

bool ScanoutComposition::copy_surface(
    const std::shared_ptr<HostSurface>& source,
    const std::shared_ptr<HostSurface>& destination, HostRectangle region,
    CommandEncoder& encoder)
{
    if (!source || !destination)
        return false;
    if (source == destination)
        return true;
    const auto source_descriptor = source->descriptor();
    const auto destination_descriptor = destination->descriptor();
    if (source_descriptor.width != destination_descriptor.width ||
        source_descriptor.height != destination_descriptor.height) {
        return false;
    }
    return encoder.copy(source, destination, region, region) &&
           encoder.submit(PerfSubmitReason::GlesSync);
}

void ScanoutComposition::invalidate_local_background(
    const std::shared_ptr<HostSurface>& target)
{
    local_scene_background_.invalidate(target);
}

void ScanoutComposition::observe_local_background_draw(
    const std::shared_ptr<HostSurface>& target, const GlesRasterState& state,
    const GlesResourceStore& resources,
    std::span<const GlesRasterVertex> vertices, std::uint32_t mode)
{
    local_scene_background_.observe(target, state, resources, vertices, mode);
}

void ScanoutComposition::begin_draw(GlesRenderTargetKey key,
    const std::shared_ptr<HostSurface>& surface, std::uint32_t screen_width,
    std::uint32_t screen_height)
{
    if (!is_screen_surface(surface, screen_width, screen_height))
        return;

    for (auto& [frame_key, frame] : frames_) {
        static_cast<void>(frame_key);
        if (!frame.surface)
            continue;
        const auto presentation =
            frame.surface->scanout_presentation_sequence();
        if (presentation == frame.observed_presentation)
            continue;
        frame.previous_scene_composited = frame.scene_composited;
        frame.previous_solid_background_deferred =
            frame.solid_background_deferred;
        frame.observed_presentation = presentation;
        frame.active = false;
    }

    auto& frame = frames_[key];
    if (frame.surface != surface) {
        frame = { };
        frame.surface = surface;
        frame.observed_presentation = surface->scanout_presentation_sequence();
    }
    if (frame.active)
        return;
    frame.active = true;
    frame.scene_composited = false;
    frame.primary_background_restored = false;
    frame.textured_background_drawn = false;
    frame.solid_background_deferred = false;
}

bool ScanoutComposition::restore_background(std::uint32_t process_id,
    GlesRenderTargetKey key, const std::shared_ptr<HostSurface>& surface,
    std::uint32_t screen_width, std::uint32_t screen_height,
    const GlesRasterState& state, const GlesResourceStore& resources,
    std::span<const GlesRasterVertex> vertices, std::uint32_t mode,
    CommandEncoder& encoder, bool& restored)
{
    restored = false;
    if (!is_screen_surface(surface, screen_width, screen_height) ||
        !state.blend_enabled || state.blend_source != gles_abi::one ||
        state.blend_destination != gles_abi::one_minus_source_alpha) {
        return true;
    }

    const auto rectangle =
        draw_rectangle(screen_width, screen_height, state, vertices);
    if (!rectangle || rectangle->width + 1U < screen_width)
        return true;

    const auto descriptor = surface->descriptor();
    const GlesResourceStore::TextureLevel* scene_level = nullptr;
    std::size_t scene_unit_index = 0;
    for (std::size_t unit_index = 0; unit_index < state.texture_units.size();
        ++unit_index) {
        const auto& unit = state.texture_units[unit_index];
        if (!unit.enabled)
            continue;
        const auto* texture = resources.texture(unit.texture);
        if (!texture)
            continue;
        const auto level = texture->levels.find(0U);
        if (level == texture->levels.end() || level->second.surface_id ||
            !level->second.host_surface ||
            level->second.internal_format != gles_abi::rgba ||
            level->second.width < descriptor.width) {
            continue;
        }
        scene_level = &level->second;
        scene_unit_index = unit_index;
        break;
    }
    if (!scene_level)
        return true;

    const auto frame = frames_.find(key);
    if (frame == frames_.end())
        return true;
    const auto primary_scene = static_cast<std::uint64_t>(scene_level->height) *
                                   primary_scene_height_denominator >=
                               static_cast<std::uint64_t>(descriptor.height) *
                                   primary_scene_height_numerator;
    const auto covers_scanout_from_origin =
        static_cast<std::uint64_t>(scene_level->height) +
            static_cast<std::uint32_t>(rectangle->y) >=
        descriptor.height;
    // A primary local scene may begin below a system bar while still containing
    // the transition's complete composition. Injecting an older scanout
    // background into it reintroduces pixels outside the scene's own geometry;
    // background reconstruction is for smaller moving scene slices only.
    if (primary_scene && covers_scanout_from_origin) {
        frame->second.scene_composited = true;
        return true;
    }

    const auto background = backgrounds_.find(process_id);
    if (background == backgrounds_.end() || !background->second.valid)
        return true;
    if (!local_scene_background_.restore(scene_level->host_surface, surface,
            scene_unit_index, state, vertices, mode, *rectangle, encoder,
            restored)) {
        return false;
    }
    if (restored) {
        frame->second.scene_composited = true;
        frame->second.primary_background_restored |= primary_scene;
        return true;
    }
    // A small render target may contain only an effect, such as a shadow.
    // Retained scanout pixels are a fallback for a primary scene and its
    // companion slices, not a background beneath every translucent effect.
    if (!primary_scene && !frame->second.primary_background_restored)
        return true;
    // A freshly drawn textured base and its later layers are already on
    // scanout. Replaying the retained base would erase those later layers.
    // Preserve it unless a preceding primary slice required reconstruction.
    if (frame->second.textured_background_drawn &&
        !frame->second.primary_background_restored) {
        frame->second.scene_composited |= primary_scene;
        return true;
    }
    // Each local scene is self-contained. Adjacent scene slices can overlap
    // while their separator moves, so the later slice must rebuild its whole
    // destination instead of inheriting pixels from the earlier slice.
    if (!copy_surface(background->second.surface, surface, *rectangle, encoder))
        return false;
    restored = true;
    frame->second.scene_composited = true;
    frame->second.primary_background_restored |= primary_scene;
    return true;
}

bool ScanoutComposition::is_background_draw(
    const std::shared_ptr<HostSurface>& surface, std::uint32_t screen_width,
    std::uint32_t screen_height, const GlesRasterState& state,
    std::span<const GlesRasterVertex> vertices) const
{
    if (!is_screen_surface(surface, screen_width, screen_height) ||
        vertices.empty() || state.blend_enabled || state.scissor_enabled ||
        state.viewport_x != 0 || state.viewport_y != 0 ||
        state.viewport_width != screen_width ||
        state.viewport_height != screen_height) {
        return false;
    }

    auto minimum_x = std::numeric_limits<float>::infinity();
    auto maximum_x = -std::numeric_limits<float>::infinity();
    auto minimum_y = std::numeric_limits<float>::infinity();
    auto maximum_y = -std::numeric_limits<float>::infinity();
    for (const auto& vertex : vertices) {
        if (!std::isfinite(vertex.position[3]) ||
            std::abs(vertex.position[3]) <= 1.0e-6F) {
            return false;
        }
        const auto inverse_w = 1.0F / vertex.position[3];
        const auto x = vertex.position[0] * inverse_w;
        const auto y = vertex.position[1] * inverse_w;
        minimum_x = std::min(minimum_x, x);
        maximum_x = std::max(maximum_x, x);
        minimum_y = std::min(minimum_y, y);
        maximum_y = std::max(maximum_y, y);
    }
    constexpr auto edge_tolerance = 0.001F;
    return minimum_x <= -1.0F + edge_tolerance &&
           maximum_x >= 1.0F - edge_tolerance &&
           minimum_y <= -1.0F + edge_tolerance &&
           maximum_y >= 1.0F - edge_tolerance;
}

bool ScanoutComposition::capture_background(std::uint32_t process_id,
    std::uint64_t renderer_owner, GlesRenderTargetKey key,
    const std::shared_ptr<HostSurface>& surface, GlesRenderer& renderer,
    CommandEncoder& encoder, bool textured_candidate)
{
    const auto frame = frames_.find(key);
    // The draw reached scanout even when retaining its pixels is deferred.
    if (surface && frame != frames_.end())
        frame->second.textured_background_drawn = textured_candidate;
    if (!surface || (frame != frames_.end() && frame->second.scene_composited))
        return true;

    const auto descriptor = surface->descriptor();
    auto& background = backgrounds_[process_id];
    if (!background.surface ||
        background.surface->descriptor().width != descriptor.width ||
        background.surface->descriptor().height != descriptor.height) {
        const auto backing_key = HostSurfaceKey { renderer_owner,
            scanout_background_namespace | process_id };
        background.surface = renderer.create_surface(backing_key, descriptor);
        background.valid = false;
        background.textured = false;
    }
    const auto confirmed_solid_background =
        frame != frames_.end() &&
        frame->second.previous_solid_background_deferred &&
        !frame->second.previous_scene_composited;
    // Legacy compositors clear each scanout page to a solid before replaying
    // translucent transition scenes. Defer that solid while a textured base is
    // retained. A later texture cancels the deferral; a real solid-only base is
    // accepted after the preceding presentation completed without a scene.
    if (!textured_candidate && background.valid && background.textured &&
        !confirmed_solid_background) {
        if (frame != frames_.end())
            frame->second.solid_background_deferred = true;
        return true;
    }
    const auto whole_surface =
        HostRectangle { 0, 0, descriptor.width, descriptor.height };
    background.valid =
        background.surface &&
        copy_surface(surface, background.surface, whole_surface, encoder);
    background.textured = background.valid && textured_candidate;
    if (background.valid && frame != frames_.end())
        frame->second.solid_background_deferred = false;
    return background.valid;
}

} // namespace shade
