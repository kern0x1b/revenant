// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Retain background-layer provenance for local scene composition.

#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <map>
#include <memory>
#include <span>

#include "graphics/gles_rasterizer.hpp"
#include "graphics/gles_renderer.hpp"
#include "graphics/gles_resources.hpp"

namespace shade {

// Retains the provenance of a local scene's direct background layer. A scene
// that later moves across scanout can replay that layer in source coordinates
// before applying its translucent, premultiplied contents.
class LocalSceneBackground {
public:
    void reset();
    void invalidate(const std::shared_ptr<HostSurface>& target);

    void observe(const std::shared_ptr<HostSurface>& target,
        const GlesRasterState& state, const GlesResourceStore& resources,
        std::span<const GlesRasterVertex> vertices, std::uint32_t mode);

    [[nodiscard]] bool restore(const std::shared_ptr<HostSurface>& scene,
        const std::shared_ptr<HostSurface>& destination,
        std::size_t scene_unit_index, const GlesRasterState& state,
        std::span<const GlesRasterVertex> vertices, std::uint32_t mode,
        HostRectangle scissor, CommandEncoder& encoder, bool& restored);

private:
    struct State {
        std::shared_ptr<HostSurface> target;
        std::shared_ptr<HostSurface> source;
        // left, top, right, bottom in the local target's host pixel space.
        std::array<float, 4> target_bounds { };
        // source x = [0] * target x + [1], source y = [2] * target y + [3].
        std::array<float, 4> source_from_target { };
        std::uint64_t source_generation { };
    };

    std::map<HostSurfaceKey, State> states_;
};

} // namespace shade
