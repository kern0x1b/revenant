// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Preserve retained scanout content across partial compositor
// updates.

#pragma once

#include <cstdint>
#include <map>
#include <memory>
#include <span>

#include "graphics/gles_rasterizer.hpp"
#include "graphics/gles_renderer.hpp"
#include "graphics/gles_resources.hpp"
#include "graphics/local_scene_background.hpp"

namespace shade {

// Tracks retained scanout pages used by legacy compositors. A compositor may
// build a translucent scene in a local render target and source-over it onto
// alternating scanout surfaces. The physical driver preserves the compositor
// background without carrying the previous transition result into the next
// page; model that boundary independently of the host rendering backend.
class ScanoutComposition {
public:
    void reset();

    void begin_draw(GlesRenderTargetKey key,
        const std::shared_ptr<HostSurface>& surface, std::uint32_t screen_width,
        std::uint32_t screen_height);

    [[nodiscard]] bool restore_background(std::uint32_t process_id,
        GlesRenderTargetKey key, const std::shared_ptr<HostSurface>& surface,
        std::uint32_t screen_width, std::uint32_t screen_height,
        const GlesRasterState& state, const GlesResourceStore& resources,
        std::span<const GlesRasterVertex> vertices, std::uint32_t mode,
        CommandEncoder& encoder, bool& restored);

    // Records a direct source layer beneath later translucent draws in a local
    // scene texture. When that scene is translated onto scanout, the same
    // source-space layer can be replayed instead of sampling the background at
    // the scene's destination coordinates.
    void observe_local_background_draw(
        const std::shared_ptr<HostSurface>& target,
        const GlesRasterState& state, const GlesResourceStore& resources,
        std::span<const GlesRasterVertex> vertices, std::uint32_t mode);
    void invalidate_local_background(
        const std::shared_ptr<HostSurface>& target);

    [[nodiscard]] bool is_background_draw(
        const std::shared_ptr<HostSurface>& surface, std::uint32_t screen_width,
        std::uint32_t screen_height, const GlesRasterState& state,
        std::span<const GlesRasterVertex> vertices) const;

    [[nodiscard]] bool capture_background(std::uint32_t process_id,
        std::uint64_t renderer_owner, GlesRenderTargetKey key,
        const std::shared_ptr<HostSurface>& surface, GlesRenderer& renderer,
        CommandEncoder& encoder, bool textured_candidate);

private:
    struct FrameState {
        std::shared_ptr<HostSurface> surface;
        std::uint64_t observed_presentation { };
        bool active { };
        bool scene_composited { };
        bool primary_background_restored { };
        bool textured_background_drawn { };
        bool previous_scene_composited { };
        bool solid_background_deferred { };
        bool previous_solid_background_deferred { };
    };

    struct BackgroundState {
        std::shared_ptr<HostSurface> surface;
        bool valid { };
        bool textured { };
    };

    [[nodiscard]] static bool is_screen_surface(
        const std::shared_ptr<HostSurface>& surface, std::uint32_t screen_width,
        std::uint32_t screen_height);
    [[nodiscard]] static bool copy_surface(
        const std::shared_ptr<HostSurface>& source,
        const std::shared_ptr<HostSurface>& destination, HostRectangle region,
        CommandEncoder& encoder);
    std::map<GlesRenderTargetKey, FrameState> frames_;
    std::map<std::uint32_t, BackgroundState> backgrounds_;
    LocalSceneBackground local_scene_background_;
};

} // namespace shade
