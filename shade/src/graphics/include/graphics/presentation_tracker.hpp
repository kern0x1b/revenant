// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Track presented layers, geometry and hit-test information across
// completed frames.

#pragma once

#include <cstddef>
#include <cstdint>
#include <map>
#include <mutex>
#include <optional>
#include <utility>
#include <vector>

#include "foundation/scene_coordinator.hpp"
#include "graphics/surface_store.hpp"

namespace shade {

// Host-backend-independent description of a surface placement in one completed
// display transaction. OS-specific adapters translate their native transaction
// formats into this stable representation.
struct PresentationRectangle {
    float x { };
    float y { };
    float width { };
    float height { };
};

// Maps host/display coordinates into the primary surface's coordinate space.
// Keeping the full affine form avoids baking an early LayerKit translation-only
// assumption into the common scene representation.
using PresentationTransform = SceneTransform;

struct PresentationLayer {
    std::uint32_t order { };
    std::uint32_t surface_id { };
    SurfaceStore::Provenance surface_provenance;
    PresentationRectangle source;
    PresentationRectangle destination;
    std::optional<PresentationTransform> screen_to_surface;
    std::uint32_t flags { };
};

struct PresentationFrame {
    std::uint64_t sequence { };
    std::uint32_t submitting_process_id { };
    // Semantic client composited into this frame, if an OS-version adapter has
    // established one. This remains distinct from physical Surface provenance:
    // early SpringBoard flattens App pixels into its own swap backing.
    std::optional<ClientScene> logical_client_scene;
    std::vector<PresentationLayer> layers;
};

struct PresentationScene {
    std::uint64_t frame_sequence { };
    std::uint32_t producer_process_id { };
    std::size_t layer_count { };
    std::uint32_t primary_surface_id { };
    std::uint64_t primary_surface_sequence { };
    PresentationRectangle destination_bounds;
    std::optional<PresentationTransform> screen_to_surface;
};

struct PresentationHit {
    std::uint32_t order { };
    std::uint32_t surface_id { };
    SurfaceStore::Provenance surface_provenance;
};

// One immutable point query against a completed display transaction. Layers
// are returned front-to-back so consumers can skip non-interactive assets
// without racing a newer transaction between successive queries.
struct PresentationHitTest {
    std::uint64_t frame_sequence { };
    std::uint32_t submitting_process_id { };
    // Preserve the semantic client from the same immutable frame. Early
    // compositors can flatten App pixels into system-owned physical surfaces,
    // so provenance alone does not describe the interactive scene.
    std::optional<ClientScene> logical_client_scene;
    std::vector<PresentationHit> layers_front_to_back;
};

// Recording remains observational and never controls rendering. Consumers can
// query the completed snapshot without coupling the common presentation model
// to LayerKit, MobileFramebuffer, QuartzCore, IOSurface, or SDL.
class PresentationTracker {
public:
    [[nodiscard]] std::uint64_t record(std::uint32_t submitting_process_id,
        std::vector<PresentationLayer> layers,
        std::optional<ClientScene> logical_client_scene = std::nullopt);
    [[nodiscard]] std::optional<PresentationFrame> latest() const;
    [[nodiscard]] std::vector<PresentationScene> latest_scenes() const;
    [[nodiscard]] std::optional<PresentationScene> latest_scene(
        std::uint32_t producer_process_id) const;
    [[nodiscard]] std::optional<PresentationHitTest> hit_test(
        float x, float y) const;
    [[nodiscard]] bool has_presented_frame() const;

    // Ignore surfaces from this process incarnation at or below the publication
    // watermark. A reused PID becomes eligible automatically after it publishes
    // a new backing with a later immutable sequence.
    void retire_process(
        std::uint32_t process_id, std::uint64_t publication_watermark);

private:
    [[nodiscard]] std::uint64_t allocate_sequence_locked();
    [[nodiscard]] std::vector<PresentationScene> latest_scenes_locked() const;

    mutable std::mutex mutex_;
    std::uint64_t next_sequence_ { 1 };
    std::optional<PresentationFrame> latest_;
    std::map<std::uint32_t, std::uint64_t> retired_process_watermarks_;
};

} // namespace shade
