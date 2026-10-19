// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Adapt guest framebuffer layer configuration, swaps and display
// notifications.

#pragma once

#include <cstddef>
#include <cstdint>
#include <functional>
#include <map>
#include <memory>
#include <optional>
#include <set>
#include <vector>

#include "graphics/host_graphics.hpp"

namespace shade {

class DisplayState;
class GlesRenderer;
class PresentationTracker;
class SceneCoordinator;
struct KernelSharedState;
class SurfaceTransportLease;
class UserlandHleCall;
class UserlandHleRegistry;
class SurfaceStore;

class MobileFramebufferHle {
public:
    MobileFramebufferHle(UserlandHleRegistry& registry,
        std::shared_ptr<DisplayState> display,
        std::shared_ptr<SurfaceStore> surfaces = { },
        std::shared_ptr<PresentationTracker> presentations = { });

    void reset();
    void inherit_state(const MobileFramebufferHle& parent);
    void set_display(std::shared_ptr<DisplayState> display);
    void set_shared_state(std::shared_ptr<KernelSharedState> shared_state);
    void set_presentation_tracker(
        std::shared_ptr<PresentationTracker> presentations);
    void set_scene_coordinator(std::shared_ptr<SceneCoordinator> scenes);
    void set_frame_presented_handler(
        std::function<void(std::uint32_t)> handler);
    // A compositor-owned panel submission can still contain an active
    // client's layers. Keep that semantic client observation separate from
    // the physical process that owns DisplayState's scanout.
    void set_semantic_presentation_handler(
        std::function<void(std::uint32_t)> handler);
    [[nodiscard]] bool has_active_layers() const;

private:
    enum class SubmissionResult : std::uint8_t {
        Failed,
        Submitted,
        Deferred,
    };

    void register_device_functions(UserlandHleRegistry& registry);
    [[nodiscard]] bool is_external_framebuffer(UserlandHleCall& call) const;
    void set_background_color(UserlandHleCall& call);
    void set_layer(UserlandHleCall& call);
    [[nodiscard]] SubmissionResult submit_layers(UserlandHleCall& call);
    [[nodiscard]] std::optional<std::uint32_t> record_presentation(
        UserlandHleCall& call);
    [[nodiscard]] bool display_write_allowed(UserlandHleCall& call) const;
    [[nodiscard]] bool application_surface_allowed(
        std::uint32_t producer_process_id,
        std::uint64_t publication_sequence) const;
    [[nodiscard]] SubmissionResult submit_host_layers(UserlandHleCall& call);
    void ensure_scanout_surface();
    [[nodiscard]] std::shared_ptr<HostSurface> acquire_composition_surface();

    struct Rectangle {
        float x { };
        float y { };
        float width { };
        float height { };

        bool operator==(const Rectangle&) const = default;
    };
    struct LayerState {
        std::uint32_t surface_id { };
        Rectangle source;
        Rectangle destination;
        std::uint32_t flags { };

        bool operator==(const LayerState&) const = default;
    };
    void apply_application_display(LayerState& state,
        std::uint32_t producer_process_id, std::uint32_t source_width,
        std::uint32_t source_height) const;
    struct SubmittedLayer {
        LayerState state;
        HostSurfaceKey surface_key;
        std::uint64_t generation { };
    };
    struct DeferredForegroundFrame {
        std::uint32_t scene_process_id { };
        std::uint64_t generation { };
    };

    std::shared_ptr<DisplayState> display_;
    std::shared_ptr<SurfaceStore> surface_store_;
    std::shared_ptr<PresentationTracker> presentation_tracker_;
    std::shared_ptr<KernelSharedState> shared_state_;
    std::shared_ptr<SceneCoordinator> scene_coordinator_;
    std::function<void(std::uint32_t)> frame_presented_handler_;
    std::function<void(std::uint32_t)> semantic_presentation_handler_;
    std::shared_ptr<GlesRenderer> host_graphics_;
    std::unique_ptr<CommandEncoder> command_encoder_;
    std::shared_ptr<HostSurface> scanout_surface_;
    // Keep the last published target immutable while the host presenter can
    // still consume it. The ring is independent of guest model/firmware; the
    // software path below continues to compose into DisplayState pixels.
    std::vector<std::shared_ptr<HostSurface>> composition_surfaces_;
    std::size_t composition_surface_index_ { };
    std::map<std::uint32_t, LayerState> layers_;
    std::set<std::uint32_t> external_framebuffers_;
    // A hardware layer retains its IOSurface independently of the process
    // that created the backing. The lease is presentation state, not a host
    // renderer concern, and is released when that layer is replaced/removed.
    std::map<std::uint32_t, std::shared_ptr<SurfaceTransportLease>>
        layer_surface_leases_;
    std::map<std::uint32_t, SubmittedLayer> submitted_layers_;
    std::uint32_t next_swap_id_ { 1 };
    std::uint32_t background_argb_ { 0xff000000U };
    std::uint32_t submitted_background_argb_ { 0xff000000U };
    bool scanout_contents_valid_ { };
    std::optional<DeferredForegroundFrame> deferred_foreground_frame_;
};

} // namespace shade
