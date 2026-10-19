// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Adapt guest MBX2D drawing, clipping and blend operations to
// emulator surfaces.

#pragma once

#include <cstddef>
#include <cstdint>
#include <map>
#include <memory>
#include <optional>
#include <set>
#include <vector>

#include "graphics/host_graphics.hpp"
#include "graphics/mbx2d_abi.hpp"
#include "graphics/surface_store.hpp"

namespace shade {

class UserlandHleCall;
class UserlandHleRegistry;
class DisplayState;
class GlesRenderer;
struct KernelSharedState;
class PresentationTracker;

// User-mode compatibility implementation for the MBX2D API consumed by
// LayerKit. Handles are opaque because every operation stays at this HLE
// boundary; no PowerVR command buffer or GPU register is interpreted.
class Mbx2dHle {
public:
    Mbx2dHle(UserlandHleRegistry& registry,
        std::shared_ptr<DisplayState> display,
        std::shared_ptr<SurfaceStore> surfaces = { },
        std::shared_ptr<PresentationTracker> presentations = { });
    ~Mbx2dHle();

    void reset();
    void inherit_state(const Mbx2dHle& parent);
    void set_display(std::shared_ptr<DisplayState> display);
    void set_presentation_tracker(
        std::shared_ptr<PresentationTracker> presentations);
    void set_shared_state(std::shared_ptr<KernelSharedState> shared_state);

private:
    struct Surface {
        std::uint32_t handle { };
        std::uint32_t core_surface_id { };
        bool framebuffer { };
        bool retains_core_surface { };
        std::optional<SurfaceStore::Backing> client_backing;
        // Raw client memory is CPU-owned. A source-only host snapshot is
        // refreshed at the firmware's FlushSurfaces publication boundary and
        // never exposed as an MBX destination.
        std::shared_ptr<HostSurface> client_host_source;
        bool client_host_source_dirty { true };
    };
    struct Binding {
        std::uint32_t surface { };
        std::uint32_t pitch { };
        std::uint32_t format { };
        std::uint32_t flags { };
    };
    struct Scissor {
        std::int32_t left { };
        std::int32_t top { };
        std::int32_t right { };
        std::int32_t bottom { };
        bool enabled { };
    };
    struct BlendState {
        std::uint32_t source_factor { };
        std::uint32_t destination_factor { };
        std::uint32_t operation { };
        std::uint8_t global_alpha { 0xffU };
        bool complex { };
    };
    struct RenderState {
        std::optional<Binding> source;
        std::optional<Binding> destination;
        Scissor scissor;
        BlendState blend;
        std::uint32_t scale_x_bits { mbx2d_abi::float_one_bits };
        std::uint32_t scale_y_bits { mbx2d_abi::float_one_bits };
        std::uint32_t rotation { };
        std::set<std::uint32_t> enabled_features;
    };
    struct ResolvedSurface {
        std::uint32_t core_surface_id { };
        std::optional<SurfaceStore::Backing> backing;
        std::shared_ptr<HostSurface> host_surface;
        bool framebuffer { };
        std::uint32_t width { };
        std::uint32_t height { };
        std::uint32_t surface_handle { };
    };
    struct BlitRegion {
        std::int64_t source_x { };
        std::int64_t source_y { };
        std::int64_t destination_x { };
        std::int64_t destination_y { };
        std::int64_t width { };
        std::int64_t height { };
    };
    struct DamageRegion {
        std::int64_t left { };
        std::int64_t top { };
        std::int64_t right { };
        std::int64_t bottom { };
    };

    [[nodiscard]] std::uint32_t allocate_surface(
        std::uint32_t core_surface_id = 0, bool framebuffer = false);
    void release_core_surface_reference(Surface& surface);
    void release_core_surface_references();
    [[nodiscard]] std::uint32_t allocate_client_surface(
        std::uint32_t base, std::uint32_t allocation_size, std::uint32_t width);
    [[nodiscard]] std::optional<ResolvedSurface> resolve_source(
        UserlandHleCall& call, const std::optional<Binding>& binding);
    void retire_client_host_source(Surface& surface);
    void release_retired_client_host_sources();
    void release_client_renderer_resources();
    [[nodiscard]] std::uint32_t allocate_context();
    [[nodiscard]] RenderState* select_state(
        UserlandHleCall& call, bool context_api);
    void bind_surface(UserlandHleCall& call, bool source, bool context_api);
    void initialize_destination(UserlandHleCall& call, RenderState& state);
    void prepare_destination_for_frame(UserlandHleCall& call,
        RenderState& state, DamageRegion damage, std::uint32_t source_surface);
    void set_scissor(UserlandHleCall& call, bool context_api);
    void set_blend_equation(
        UserlandHleCall& call, bool context_api, bool complex);
    void set_scale_factor(UserlandHleCall& call, bool context_api);
    void set_rotation(UserlandHleCall& call, bool context_api);
    void set_feature(UserlandHleCall& call, bool context_api, bool enabled);
    void blit_color(UserlandHleCall& call, bool context_api);
    void blit_copy(UserlandHleCall& call, bool context_api);
    void quad_color(UserlandHleCall& call);
    void quad_copy(UserlandHleCall& call, bool context_api = false,
        bool perspective_api = false);
    void flush_surfaces(UserlandHleCall& call);
    void terminate(UserlandHleCall& call);
    [[nodiscard]] std::optional<ResolvedSurface> resolve(
        const std::optional<Binding>& binding) const;
    [[nodiscard]] bool synchronize_host_source(
        UserlandHleCall& call, const ResolvedSurface& surface) const;
    [[nodiscard]] bool source_surface_allowed(
        const ResolvedSurface& surface) const;
    [[nodiscard]] bool clip_region(BlitRegion& region,
        const ResolvedSurface* source, const ResolvedSurface& destination,
        const Scissor& scissor) const;
    [[nodiscard]] std::optional<std::vector<std::uint32_t>> read_region(
        const ResolvedSurface& surface, std::int64_t x, std::int64_t y,
        std::int64_t width, std::int64_t height, UserlandHleCall& call) const;
    [[nodiscard]] bool write_region(const ResolvedSurface& surface,
        std::int64_t x, std::int64_t y, std::int64_t width, std::int64_t height,
        const std::vector<std::uint32_t>& pixels, UserlandHleCall& call);
    [[nodiscard]] std::optional<std::vector<std::uint32_t>> composite(
        const RenderState& state, const ResolvedSurface& destination,
        std::int64_t x, std::int64_t y, std::int64_t width, std::int64_t height,
        const std::vector<std::uint32_t>& source, UserlandHleCall& call) const;
    [[nodiscard]] std::optional<std::vector<std::uint32_t>> transform_copy(
        const RenderState& state, std::int64_t source_width,
        std::int64_t source_height, const std::vector<std::uint32_t>& source,
        std::int64_t& output_width, std::int64_t& output_height,
        UserlandHleCall& call);
    [[nodiscard]] std::optional<HostCompositeMode> host_composite_mode(
        const RenderState& state) const;
    [[nodiscard]] bool submit_host_commands(bool wait, PerfSubmitReason reason);
    void submit_destination(UserlandHleCall& call, bool context_api);
    void deferred(UserlandHleCall& call);

    static constexpr std::uint32_t first_context_handle = 0x00020001U;
    static constexpr std::uint32_t first_surface_handle = 0x00030001U;
    std::map<std::uint32_t, RenderState> contexts_;
    std::uint32_t next_context_ { first_context_handle };
    std::map<std::uint32_t, Surface> surfaces_;
    std::set<std::uint32_t> initialized_destinations_;
    std::map<std::uint32_t, std::uint64_t> destination_frame_sequences_;
    std::map<std::uint32_t, DamageRegion> destination_scene_damage_;
    std::map<std::uint32_t, std::uint32_t> destination_scene_sources_;
    std::uint32_t next_surface_ { first_surface_handle };
    std::uint32_t framebuffer_surface_ { };
    RenderState state_;
    bool initialized_ { };
    std::size_t deferred_trace_count_ { };
    std::shared_ptr<DisplayState> display_;
    std::shared_ptr<SurfaceStore> surface_store_;
    std::shared_ptr<PresentationTracker> presentation_tracker_;
    std::shared_ptr<KernelSharedState> shared_state_;
    std::uint64_t renderer_owner_ { };
    std::uint64_t next_client_host_source_ { 1 };
    std::vector<HostSurfaceKey> retired_client_host_sources_;
    std::shared_ptr<GlesRenderer> host_graphics_;
    std::unique_ptr<CommandEncoder> command_encoder_;
};

} // namespace shade
