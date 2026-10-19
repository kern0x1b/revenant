// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Adapt guest MBX2D drawing, clipping and blend operations to
// emulator surfaces.

#include "kernel/mbx2d_hle.hpp"

#include <algorithm>
#include <bit>
#include <chrono>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <limits>
#include <mutex>
#include <span>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "foundation/address_space.hpp"
#include "graphics/display.hpp"
#include "graphics/gles_renderer.hpp"
#include "kernel/kernel_shared_state.hpp"
#include "graphics/mbx2d_abi.hpp"
#include "foundation/output.hpp"
#include "foundation/performance.hpp"
#include "graphics/presentation_tracker.hpp"
#include "foundation/userland_hle.hpp"

namespace shade {
namespace {

    constexpr std::string_view mbx2d_image { "/MBX2D.framework/MBX2D" };
    constexpr std::size_t maximum_deferred_traces = 64;
    constexpr std::uint32_t mbx_success = mbx2d_abi::success;
    constexpr std::uint32_t mbx_failure = mbx2d_abi::failure;
    constexpr std::uint32_t bytes_per_pixel = 4;
    constexpr std::uint64_t maximum_transformed_pixels = 16U * 1024U * 1024U;

    std::int64_t signed_argument(UserlandHleCall& call, std::size_t index)
    {
        return static_cast<std::int32_t>(call.argument(index));
    }

} // namespace

Mbx2dHle::Mbx2dHle(UserlandHleRegistry& registry,
    std::shared_ptr<DisplayState> display,
    std::shared_ptr<SurfaceStore> surfaces,
    std::shared_ptr<PresentationTracker> presentations)
    : display_ { std::move(display) }
    , surface_store_ { surfaces ? std::move(surfaces)
                                : std::make_shared<SurfaceStore>() }
    , presentation_tracker_ { std::move(presentations) }
    , renderer_owner_ { allocate_gles_renderer_owner() }
    , host_graphics_ { shared_gles_renderer() }
    , command_encoder_ { host_graphics_->create_command_encoder() }
{
    const auto add = [&](std::string symbol,
                         UserlandHleRegistry::Handler handler) {
        registry.register_function(
            std::string { mbx2d_image }, std::move(symbol), std::move(handler));
    };
    add("_mbx2DInitialize", [this](UserlandHleCall& call) {
        initialized_ = true;
        call.set_return(mbx_success);
    });
    add("_mbx2DTerminate", [this](UserlandHleCall& call) { terminate(call); });
    add("_mbx2DGetMaxSurfaceDimensions", [](UserlandHleCall& call) {
        const auto output = call.argument(0);
        call.set_return(output != 0U &&
                                call.write32(output,
                                    mbx2d_abi::maximum_surface_dimension) &&
                                call.write32(output + sizeof(std::uint32_t),
                                    mbx2d_abi::maximum_surface_dimension)
                            ? mbx_success
                            : mbx_failure);
    });
    add("_mbx2DGetMaxSurfaceSize", [](UserlandHleCall& call) {
        const auto output = call.argument(0);
        call.set_return(output != 0U && call.write32(output,
                                            mbx2d_abi::maximum_surface_size)
                            ? mbx_success
                            : mbx_failure);
    });
    add("_mbx2DCtxInitialize",
        [this](UserlandHleCall& call) { call.set_return(allocate_context()); });
    add("_mbx2DCtxTerminate", [this](UserlandHleCall& call) {
        call.set_return(
            contexts_.erase(call.argument(0)) != 0 ? mbx_success : mbx_failure);
    });
    add("_mbx2DCreateSurface", [this](UserlandHleCall& call) {
        call.set_return(allocate_surface(call.argument(0)));
    });
    add("_mbx2DAddClientSurface", [this](UserlandHleCall& call) {
        const auto surface = allocate_client_surface(
            call.argument(0), call.argument(1), call.argument(3));
        call.set_return(surface != 0 && call.write32(call.argument(2), surface)
                            ? mbx_success
                            : mbx_failure);
    });
    add("_mbx2DGetFramebufferSurface", [this](UserlandHleCall& call) {
        if (framebuffer_surface_ == 0) {
            framebuffer_surface_ = allocate_surface(0, true);
        }
        call.set_return(call.write32(call.argument(0), framebuffer_surface_)
                            ? mbx_success
                            : mbx_failure);
    });
    const auto release = [this](UserlandHleCall& call) {
        const auto surface = call.argument(0);
        if (const auto found = surfaces_.find(surface);
            found != surfaces_.end()) {
            retire_client_host_source(found->second);
            release_core_surface_reference(found->second);
        }
        surfaces_.erase(surface);
        initialized_destinations_.erase(surface);
        destination_frame_sequences_.erase(surface);
        destination_scene_damage_.erase(surface);
        destination_scene_sources_.erase(surface);
        const auto unbind = [surface](RenderState& state) {
            if (state.source && state.source->surface == surface) {
                state.source.reset();
            }
            if (state.destination && state.destination->surface == surface) {
                state.destination.reset();
            }
        };
        unbind(state_);
        for (auto& [handle, state] : contexts_) {
            static_cast<void>(handle);
            unbind(state);
        }
        call.set_return(mbx_success);
    };
    add("_mbx2DReleaseSurface", release);
    add("_mbx2DRemoveClientSurface", release);

    add("_mbx2DSetSourceSurface",
        [this](UserlandHleCall& call) { bind_surface(call, true, false); });
    add("_mbx2DSetDestinationSurface",
        [this](UserlandHleCall& call) { bind_surface(call, false, false); });
    add("_mbx2DCtxSetSourceSurface",
        [this](UserlandHleCall& call) { bind_surface(call, true, true); });
    add("_mbx2DCtxSetDestinationSurface",
        [this](UserlandHleCall& call) { bind_surface(call, false, true); });
    add("_mbx2DSetScissor",
        [this](UserlandHleCall& call) { set_scissor(call, false); });
    add("_mbx2DCtxSetScissor",
        [this](UserlandHleCall& call) { set_scissor(call, true); });
    add("_mbx2DSetBlendEquation", [this](UserlandHleCall& call) {
        set_blend_equation(call, false, false);
    });
    add("_mbx2DCtxSetBlendEquation", [this](UserlandHleCall& call) {
        set_blend_equation(call, true, false);
    });
    add("_mbx2DSetBlendEquationComplex", [this](UserlandHleCall& call) {
        set_blend_equation(call, false, true);
    });
    add("_mbx2DCtxSetBlendEquationComplex", [this](UserlandHleCall& call) {
        set_blend_equation(call, true, true);
    });
    add("_mbx2DSetScaleFactor",
        [this](UserlandHleCall& call) { set_scale_factor(call, false); });
    add("_mbx2DCtxSetScaleFactor",
        [this](UserlandHleCall& call) { set_scale_factor(call, true); });
    add("_mbx2DSetRotation",
        [this](UserlandHleCall& call) { set_rotation(call, false); });
    add("_mbx2DCtxSetRotation",
        [this](UserlandHleCall& call) { set_rotation(call, true); });
    add("_mbx2DEnable",
        [this](UserlandHleCall& call) { set_feature(call, false, true); });
    add("_mbx2DCtxEnable",
        [this](UserlandHleCall& call) { set_feature(call, true, true); });
    add("_mbx2DDisable",
        [this](UserlandHleCall& call) { set_feature(call, false, false); });
    add("_mbx2DCtxDisable",
        [this](UserlandHleCall& call) { set_feature(call, true, false); });
    add("_mbx2DBlitColor",
        [this](UserlandHleCall& call) { blit_color(call, false); });
    add("_mbx2DCtxBlitColor",
        [this](UserlandHleCall& call) { blit_color(call, true); });
    add("_mbx2DBlitCopy",
        [this](UserlandHleCall& call) { blit_copy(call, false); });
    add("_mbx2DCtxBlitCopy",
        [this](UserlandHleCall& call) { blit_copy(call, true); });
    add("_mbx3DQuadColor", [this](UserlandHleCall& call) { quad_color(call); });
    add("_mbx3DQuadCopy", [this](UserlandHleCall& call) { quad_copy(call); });
    add("_mbx3DQuadCopyPerspective",
        [this](UserlandHleCall& call) { quad_copy(call, false, true); });
    add("_mbx3DCtxQuadCopyPerspective",
        [this](UserlandHleCall& call) { quad_copy(call, true, true); });

    add("_mbx2DFinish", [this](UserlandHleCall& call) {
        static_cast<void>(
            submit_host_commands(true, PerfSubmitReason::MbxFinish));
        release_retired_client_host_sources();
        submit_destination(call, false);
        call.set_return(mbx_success);
    });
    add("_mbx2DFlush", [this](UserlandHleCall& call) {
        static_cast<void>(
            submit_host_commands(false, PerfSubmitReason::MbxFlush));
        submit_destination(call, false);
        call.set_return(mbx_success);
    });
    add("_mbx2DFlushSurfaces",
        [this](UserlandHleCall& call) { flush_surfaces(call); });
    add("_mbx2DFlushInvalidateSurfaces",
        [this](UserlandHleCall& call) { flush_surfaces(call); });
    add("_mbx2DCtxFlush", [this](UserlandHleCall& call) {
        static_cast<void>(
            submit_host_commands(false, PerfSubmitReason::MbxFlush));
        submit_destination(call, true);
        call.set_return(mbx_success);
    });
    const auto present = [this](UserlandHleCall& call) {
        static_cast<void>(
            submit_host_commands(false, PerfSubmitReason::MbxFlush));
        submit_destination(call, false);
        if (display_ && (!presentation_tracker_ ||
                            !presentation_tracker_->has_presented_frame()))
            display_->present(call.process_id());
        call.set_return(mbx_success);
    };
    add("_mbx2DSwapSurface", present);
    add("_mbx2DSwapNotification", [](UserlandHleCall& call) {
        // This is the completion callback attached to an enclosing
        // IOMobileFramebuffer transaction. SwapEnd owns presentation after
        // all layer surfaces have been installed.
        call.set_return(mbx_success);
    });

    registry.register_prefix(std::string { mbx2d_image }, "_mbx2D",
        [this](UserlandHleCall& call) { deferred(call); });
    registry.register_prefix(std::string { mbx2d_image }, "_mbx3D",
        [this](UserlandHleCall& call) { deferred(call); });
    registry.register_prefix(std::string { mbx2d_image }, "_mbxYUV",
        [this](UserlandHleCall& call) { deferred(call); });
}

Mbx2dHle::~Mbx2dHle()
{
    release_client_renderer_resources();
    release_core_surface_references();
}

void Mbx2dHle::reset()
{
    release_client_renderer_resources();
    release_core_surface_references();
    renderer_owner_ = allocate_gles_renderer_owner();
    next_client_host_source_ = 1;
    contexts_.clear();
    next_context_ = first_context_handle;
    surfaces_.clear();
    initialized_destinations_.clear();
    destination_frame_sequences_.clear();
    destination_scene_damage_.clear();
    destination_scene_sources_.clear();
    next_surface_ = first_surface_handle;
    framebuffer_surface_ = 0;
    state_ = { };
    initialized_ = false;
    deferred_trace_count_ = 0;
}

void Mbx2dHle::inherit_state(const Mbx2dHle& parent)
{
    release_client_renderer_resources();
    release_core_surface_references();
    renderer_owner_ = allocate_gles_renderer_owner();
    next_client_host_source_ = 1;
    contexts_ = parent.contexts_;
    next_context_ = parent.next_context_;
    surfaces_ = parent.surfaces_;
    initialized_destinations_ = parent.initialized_destinations_;
    destination_frame_sequences_ = parent.destination_frame_sequences_;
    destination_scene_damage_ = parent.destination_scene_damage_;
    destination_scene_sources_ = parent.destination_scene_sources_;
    next_surface_ = parent.next_surface_;
    framebuffer_surface_ = parent.framebuffer_surface_;
    state_ = parent.state_;
    initialized_ = parent.initialized_;
    deferred_trace_count_ = parent.deferred_trace_count_;
    for (auto& [handle, surface] : surfaces_) {
        static_cast<void>(handle);
        if (surface.client_backing) {
            surface.client_host_source.reset();
            surface.client_host_source_dirty = true;
        }
    }
    presentation_tracker_ = parent.presentation_tracker_;
    surface_store_->inherit_state(*parent.surface_store_);
}

void Mbx2dHle::set_display(std::shared_ptr<DisplayState> display)
{
    display_ = std::move(display);
}

void Mbx2dHle::set_presentation_tracker(
    std::shared_ptr<PresentationTracker> presentations)
{
    presentation_tracker_ = std::move(presentations);
}

void Mbx2dHle::set_shared_state(std::shared_ptr<KernelSharedState> shared_state)
{
    shared_state_ = std::move(shared_state);
}

std::uint32_t Mbx2dHle::allocate_surface(
    std::uint32_t core_surface_id, bool framebuffer)
{
    const auto handle = next_surface_++;
    const auto retains_core_surface =
        core_surface_id != 0U && surface_store_->retain(core_surface_id);
    surfaces_.emplace(
        handle, Surface { handle, core_surface_id, framebuffer,
                    retains_core_surface, std::nullopt, { }, true });
    return handle;
}

void Mbx2dHle::release_core_surface_reference(Surface& surface)
{
    if (!surface.retains_core_surface)
        return;
    surface_store_->release(surface.core_surface_id);
    surface.retains_core_surface = false;
}

void Mbx2dHle::release_core_surface_references()
{
    for (auto& [handle, surface] : surfaces_) {
        static_cast<void>(handle);
        release_core_surface_reference(surface);
    }
}

std::uint32_t Mbx2dHle::allocate_context()
{
    const auto handle = next_context_++;
    contexts_.emplace(handle, RenderState { });
    return handle;
}

Mbx2dHle::RenderState* Mbx2dHle::select_state(
    UserlandHleCall& call, bool context_api)
{
    if (!context_api)
        return &state_;
    const auto context = contexts_.find(call.argument(0));
    return context == contexts_.end() ? nullptr : &context->second;
}

void Mbx2dHle::bind_surface(
    UserlandHleCall& call, bool source, bool context_api)
{
    auto* state = select_state(call, context_api);
    if (state == nullptr) {
        call.set_return(mbx_failure);
        return;
    }
    const auto first = context_api ? 1U : 0U;
    const auto handle = call.argument(first);
    auto& binding = source ? state->source : state->destination;
    if (handle == 0) {
        binding.reset();
        call.set_return(mbx_success);
        return;
    }
    if (!surfaces_.contains(handle)) {
        call.set_return(mbx_failure);
        return;
    }
    binding = Binding { handle, call.argument(first + 1U),
        call.argument(first + 2U), call.argument(first + 3U) };
    if (!source)
        initialize_destination(call, *state);
    call.set_return(mbx_success);
}

void Mbx2dHle::set_scissor(UserlandHleCall& call, bool context_api)
{
    auto* state = select_state(call, context_api);
    if (state == nullptr) {
        call.set_return(mbx_failure);
        return;
    }
    const auto first = context_api ? 1U : 0U;
    state->scissor = Scissor { static_cast<std::int32_t>(call.argument(first)),
        static_cast<std::int32_t>(call.argument(first + 1U)),
        static_cast<std::int32_t>(call.argument(first + 2U)),
        static_cast<std::int32_t>(call.argument(first + 3U)), true };
    call.set_return(mbx_success);
}

void Mbx2dHle::set_blend_equation(
    UserlandHleCall& call, bool context_api, bool complex)
{
    auto* state = select_state(call, context_api);
    if (state == nullptr) {
        call.set_return(mbx_failure);
        return;
    }
    const auto first = context_api ? 1U : 0U;
    const auto source = call.argument(first);
    const auto destination = call.argument(first + 1U);
    if (complex) {
        const auto operation = call.argument(first + 2U);
        const auto alpha = static_cast<std::uint8_t>(call.argument(first + 3U));
        if ((source & mbx2d_abi::complex_source_factor_mask) == 0 ||
            (destination & mbx2d_abi::complex_destination_factor_mask) == 0 ||
            (operation & mbx2d_abi::complex_operation_mask) == 0) {
            call.set_return(mbx_failure);
            return;
        }
        state->blend =
            BlendState { source, destination, operation, alpha, true };
        call.set_return(mbx_success);
        return;
    }

    const auto source_is_extended =
        (source & mbx2d_abi::simple_source_factor_mask) ==
        mbx2d_abi::simple_source_factor_mask;
    const auto destination_is_extended =
        (destination & mbx2d_abi::simple_destination_factor_mask) ==
        mbx2d_abi::simple_destination_factor_mask;
    if (source_is_extended != destination_is_extended) {
        call.set_return(mbx_failure);
        return;
    }
    state->blend = BlendState { source, destination, 0,
        static_cast<std::uint8_t>(call.argument(first + 2U)), false };
    call.set_return(mbx_success);
}

void Mbx2dHle::set_scale_factor(UserlandHleCall& call, bool context_api)
{
    auto* state = select_state(call, context_api);
    if (state == nullptr) {
        call.set_return(mbx_failure);
        return;
    }
    const auto first = context_api ? 1U : 0U;
    state->scale_x_bits = call.argument(first);
    state->scale_y_bits = call.argument(first + 1U);
    call.set_return(mbx_success);
}

void Mbx2dHle::set_rotation(UserlandHleCall& call, bool context_api)
{
    auto* state = select_state(call, context_api);
    if (state == nullptr) {
        call.set_return(mbx_failure);
        return;
    }
    state->rotation = call.argument(context_api ? 1U : 0U);
    call.set_return(mbx_success);
}

void Mbx2dHle::set_feature(
    UserlandHleCall& call, bool context_api, bool enabled)
{
    auto* state = select_state(call, context_api);
    if (state == nullptr) {
        call.set_return(mbx_failure);
        return;
    }
    const auto feature = call.argument(context_api ? 1U : 0U);
    if (feature != mbx2d_abi::feature_blend &&
        feature != mbx2d_abi::feature_rotation) {
        call.set_return(mbx_failure);
        return;
    }
    if (enabled) {
        state->enabled_features.insert(feature);
    } else {
        state->enabled_features.erase(feature);
        // LayerKit brackets its affine/quad pass with the rotation feature.
        // The scissor programmed for that pass must not leak into the regular
        // 2D blits which follow (notably the lock-screen bottom bar).
        if (feature == mbx2d_abi::feature_rotation) {
            state->scissor.enabled = false;
        }
    }
    call.set_return(mbx_success);
}

std::optional<Mbx2dHle::ResolvedSurface> Mbx2dHle::resolve(
    const std::optional<Binding>& binding) const
{
    if (!binding)
        return std::nullopt;
    const auto surface = surfaces_.find(binding->surface);
    if (surface == surfaces_.end())
        return std::nullopt;
    if (surface->second.framebuffer) {
        const auto geometry =
            display_ ? display_->geometry() : default_display_geometry;
        return ResolvedSurface { 0, std::nullopt, { }, true, geometry.width,
            geometry.height, binding->surface };
    }
    if (surface->second.client_backing) {
        auto backing = *surface->second.client_backing;
        const auto pitch = binding->pitch;
        std::uint32_t client_bytes_per_pixel { };
        if (binding->format == mbx2d_abi::pixel_format_bgra) {
            backing.pixel_format = surface_pixel_format_bgra;
            client_bytes_per_pixel = bytes_per_pixel;
        } else if (binding->format == mbx2d_abi::pixel_format_rgb555) {
            backing.pixel_format = surface_pixel_format_rgb555;
            client_bytes_per_pixel = 2U;
        } else {
            return std::nullopt;
        }
        const auto row_bytes =
            static_cast<std::uint64_t>(backing.width) * client_bytes_per_pixel;
        if (pitch < row_bytes || backing.allocation_size < row_bytes) {
            return std::nullopt;
        }
        backing.bytes_per_row = pitch;
        backing.height = static_cast<std::uint32_t>(
            (backing.allocation_size - row_bytes) / pitch + 1U);
        return ResolvedSurface { 0, backing, { }, false, backing.width,
            backing.height, binding->surface };
    }
    const auto backing = surface_store_->find(surface->second.core_surface_id);
    if (!backing)
        return std::nullopt;
    return ResolvedSurface { surface->second.core_surface_id, backing,
        surface_store_->host_surface(surface->second.core_surface_id), false,
        backing->width, backing->height, binding->surface };
}

bool Mbx2dHle::synchronize_host_source(
    UserlandHleCall& call, const ResolvedSurface& surface) const
{
    if (!surface.host_surface || surface.core_surface_id == 0)
        return true;
    // LayerKit can retain an MBX handle across multiple guest-side revisions
    // without issuing another FlushSurfaces call. Publish exact guest changes
    // when that handle is consumed, preserving unrelated GPU-owned pixels.
    const auto started = std::chrono::steady_clock::now();
    const auto synchronized = surface_store_->synchronize_from_guest(
        call.memory(), surface.core_surface_id);
    performance_counters().record_diagnostic_graphics_hle(
        PerfDiagnosticGraphicsHleKind::SynchronizeHostSource,
        static_cast<std::uint64_t>(
            std::chrono::duration_cast<std::chrono::nanoseconds>(
                std::chrono::steady_clock::now() - started)
                .count()));
    return synchronized;
}

bool Mbx2dHle::source_surface_allowed(const ResolvedSurface& surface) const
{
    if (!shared_state_ || !surface.backing)
        return true;
    if (!shared_state_->application_fullscreen_surface_suppression_active.load(
            std::memory_order_acquire)) {
        return true;
    }
    const auto& provenance = surface.backing->provenance;
    if (provenance.producer_process_id == 0U ||
        provenance.publication_sequence == 0U) {
        return true;
    }
    std::lock_guard lock { shared_state_->mach_mutex };
    return !shared_state_
                ->suppressed_application_fullscreen_surface_publications
                .contains({ provenance.producer_process_id,
                    provenance.publication_sequence });
}

bool Mbx2dHle::clip_region(BlitRegion& region, const ResolvedSurface* source,
    const ResolvedSurface& destination, const Scissor& scissor) const
{
    if (region.width <= 0 || region.height <= 0)
        return false;
    const auto clip_destination_axis =
        [](std::int64_t& destination_position, std::int64_t& source_position,
            std::int64_t& size, std::int64_t lower, std::int64_t upper) {
            if (destination_position < lower) {
                const auto difference = lower - destination_position;
                destination_position += difference;
                source_position += difference;
                size -= difference;
            }
            if (destination_position + size > upper) {
                size = upper - destination_position;
            }
        };
    const auto clip_source_axis = [](std::int64_t& source_position,
                                      std::int64_t& destination_position,
                                      std::int64_t& size, std::int64_t upper) {
        if (source_position < 0) {
            const auto difference = -source_position;
            source_position += difference;
            destination_position += difference;
            size -= difference;
        }
        if (source_position + size > upper) {
            size = upper - source_position;
        }
    };

    std::int64_t left = 0;
    std::int64_t top = 0;
    std::int64_t right = destination.width;
    std::int64_t bottom = destination.height;
    if (scissor.enabled) {
        left = std::max(left, static_cast<std::int64_t>(scissor.left));
        top = std::max(top, static_cast<std::int64_t>(scissor.top));
        right = std::min(right, static_cast<std::int64_t>(scissor.right));
        bottom = std::min(bottom, static_cast<std::int64_t>(scissor.bottom));
    }
    if (right <= left || bottom <= top)
        return false;
    clip_destination_axis(
        region.destination_x, region.source_x, region.width, left, right);
    clip_destination_axis(
        region.destination_y, region.source_y, region.height, top, bottom);
    if (source) {
        clip_source_axis(
            region.source_x, region.destination_x, region.width, source->width);
        clip_source_axis(region.source_y, region.destination_y, region.height,
            source->height);
        // Source clipping can move the destination; apply destination bounds
        // once more without changing the already-clipped source origin twice.
        clip_destination_axis(
            region.destination_x, region.source_x, region.width, left, right);
        clip_destination_axis(
            region.destination_y, region.source_y, region.height, top, bottom);
    }
    return region.width > 0 && region.height > 0;
}

std::optional<std::vector<std::uint32_t>> Mbx2dHle::read_region(
    const ResolvedSurface& surface, std::int64_t x, std::int64_t y,
    std::int64_t width, std::int64_t height, UserlandHleCall& call) const
{
    if (x < 0 || y < 0 || width <= 0 || height <= 0 ||
        x + width > surface.width || y + height > surface.height) {
        return std::nullopt;
    }
    std::vector<std::uint32_t> pixels(static_cast<std::size_t>(width * height));
    if (surface.framebuffer) {
        if (!display_)
            return std::nullopt;
        const auto frame = display_->snapshot();
        for (std::int64_t row = 0; row < height; ++row) {
            const auto source =
                static_cast<std::size_t>((y + row) * frame.width + x);
            const auto destination = static_cast<std::size_t>(row * width);
            std::copy_n(frame.pixels.begin() + source,
                static_cast<std::size_t>(width), pixels.begin() + destination);
        }
        return pixels;
    }
    if (!surface.backing ||
        (surface.backing->pixel_format != surface_pixel_format_bgra &&
            !surface_is_packed_555(surface.backing->pixel_format))) {
        return std::nullopt;
    }
    if (surface.host_surface &&
        (surface.backing->pixel_format == surface_pixel_format_bgra ||
            surface_is_packed_555(surface.backing->pixel_format)) &&
        surface.host_surface->gpu_generation() >
            surface.host_surface->cpu_generation() &&
        !surface_store_->synchronize_for_cpu(
            call.memory(), surface.core_surface_id, { })) {
        return std::nullopt;
    }
    const auto& backing = *surface.backing;
    const auto backing_bytes_per_pixel =
        surface_bytes_per_pixel(backing.pixel_format);
    if (backing.bytes_per_row < surface.width * backing_bytes_per_pixel)
        return std::nullopt;
    const auto final_byte =
        static_cast<std::uint64_t>(y + height - 1) * backing.bytes_per_row +
        static_cast<std::uint64_t>(x + width) * backing_bytes_per_pixel;
    if (final_byte > backing.allocation_size)
        return std::nullopt;
    for (std::int64_t row = 0; row < height; ++row) {
        const auto address =
            backing.base +
            static_cast<std::uint32_t>((y + row) * backing.bytes_per_row +
                                       x * backing_bytes_per_pixel);
        const auto bytes = call.memory().read_bytes(
            address, static_cast<std::size_t>(width) * backing_bytes_per_pixel);
        if (!bytes)
            return std::nullopt;
        if (surface_is_packed_555(backing.pixel_format)) {
            for (std::int64_t column = 0; column < width; ++column) {
                const auto byte = static_cast<std::size_t>(column) * 2U;
                const auto packed =
                    std::to_integer<std::uint32_t>((*bytes)[byte]) |
                    (std::to_integer<std::uint32_t>((*bytes)[byte + 1U]) << 8U);
                pixels[static_cast<std::size_t>(row * width + column)] =
                    surface_decode_packed_555(backing.pixel_format,
                        static_cast<std::uint16_t>(packed));
            }
            continue;
        }
        if constexpr (std::endian::native == std::endian::little) {
            std::memcpy(pixels.data() + static_cast<std::size_t>(row * width),
                bytes->data(),
                static_cast<std::size_t>(width) * bytes_per_pixel);
            continue;
        }
        for (std::int64_t column = 0; column < width; ++column) {
            const auto byte =
                static_cast<std::size_t>(column) * bytes_per_pixel;
            pixels[static_cast<std::size_t>(row * width + column)] =
                std::to_integer<std::uint32_t>((*bytes)[byte]) |
                (std::to_integer<std::uint32_t>((*bytes)[byte + 1U]) << 8U) |
                (std::to_integer<std::uint32_t>((*bytes)[byte + 2U]) << 16U) |
                (std::to_integer<std::uint32_t>((*bytes)[byte + 3U]) << 24U);
        }
    }
    return pixels;
}

bool Mbx2dHle::write_region(const ResolvedSurface& surface, std::int64_t x,
    std::int64_t y, std::int64_t width, std::int64_t height,
    const std::vector<std::uint32_t>& pixels, UserlandHleCall& call)
{
    if (x < 0 || y < 0 || width <= 0 || height <= 0 ||
        x + width > surface.width || y + height > surface.height ||
        pixels.size() != static_cast<std::size_t>(width * height)) {
        return false;
    }
    if (surface.framebuffer) {
        if (!display_)
            return false;
        auto frame = display_->snapshot();
        for (std::int64_t row = 0; row < height; ++row) {
            const auto source = static_cast<std::size_t>(row * width);
            const auto destination =
                static_cast<std::size_t>((y + row) * frame.width + x);
            std::copy_n(pixels.begin() + source,
                static_cast<std::size_t>(width),
                frame.pixels.begin() + destination);
        }
        display_->replace_pixels(std::move(frame.pixels), call.process_id());
        return true;
    }
    if (!surface.backing ||
        (surface.backing->pixel_format != surface_pixel_format_bgra &&
            !surface_is_packed_555(surface.backing->pixel_format))) {
        return false;
    }
    const auto& backing = *surface.backing;
    const auto replaces_entire_surface =
        x == 0 && y == 0 && width == surface.width && height == surface.height;
    if (!replaces_entire_surface && surface.host_surface &&
        backing.pixel_format == surface_pixel_format_bgra &&
        surface.host_surface->gpu_generation() >
            surface.host_surface->cpu_generation() &&
        !surface_store_->synchronize_for_cpu(
            call.memory(), surface.core_surface_id, { })) {
        return false;
    }
    const auto backing_bytes_per_pixel =
        surface_bytes_per_pixel(backing.pixel_format);
    if (backing.bytes_per_row < surface.width * backing_bytes_per_pixel)
        return false;
    const auto final_byte =
        static_cast<std::uint64_t>(y + height - 1) * backing.bytes_per_row +
        static_cast<std::uint64_t>(x + width) * backing_bytes_per_pixel;
    if (final_byte > backing.allocation_size)
        return false;
    std::vector<std::byte> encoded(
        static_cast<std::size_t>(width) * backing_bytes_per_pixel);
    for (std::int64_t row = 0; row < height; ++row) {
        if (surface_is_packed_555(backing.pixel_format)) {
            for (std::int64_t column = 0; column < width; ++column) {
                const auto pixel =
                    pixels[static_cast<std::size_t>(row * width + column)];
                const auto packed =
                    surface_encode_packed_555(backing.pixel_format, pixel);
                const auto byte = static_cast<std::size_t>(column) * 2U;
                encoded[byte] = static_cast<std::byte>(packed & 0xffU);
                encoded[byte + 1U] = static_cast<std::byte>(packed >> 8U);
            }
        } else if constexpr (std::endian::native == std::endian::little) {
            std::memcpy(encoded.data(),
                pixels.data() + static_cast<std::size_t>(row * width),
                encoded.size());
        } else {
            for (std::int64_t column = 0; column < width; ++column) {
                const auto pixel =
                    pixels[static_cast<std::size_t>(row * width + column)];
                const auto byte =
                    static_cast<std::size_t>(column) * backing_bytes_per_pixel;
                encoded[byte] = static_cast<std::byte>(pixel & 0xffU);
                encoded[byte + 1U] =
                    static_cast<std::byte>((pixel >> 8U) & 0xffU);
                encoded[byte + 2U] =
                    static_cast<std::byte>((pixel >> 16U) & 0xffU);
                encoded[byte + 3U] =
                    static_cast<std::byte>((pixel >> 24U) & 0xffU);
            }
        }
        const auto address =
            backing.base +
            static_cast<std::uint32_t>((y + row) * backing.bytes_per_row +
                                       x * backing_bytes_per_pixel);
        if (!call.memory().copy_in(address, encoded))
            return false;
    }
    if (surface.core_surface_id == 0 && surface.surface_handle != 0) {
        const auto client = surfaces_.find(surface.surface_handle);
        if (client != surfaces_.end() && client->second.client_backing)
            client->second.client_host_source_dirty = true;
    }
    if (surface.host_surface &&
        (backing.pixel_format == surface_pixel_format_bgra ||
            surface_is_packed_555(backing.pixel_format))) {
        surface.host_surface->replace_cpu_region(
            HostRectangle { static_cast<std::int32_t>(x),
                static_cast<std::int32_t>(y), static_cast<std::uint32_t>(width),
                static_cast<std::uint32_t>(height) },
            pixels);
    }
    return true;
}

std::optional<std::vector<std::uint32_t>> Mbx2dHle::composite(
    const RenderState& state, const ResolvedSurface& destination,
    std::int64_t x, std::int64_t y, std::int64_t width, std::int64_t height,
    const std::vector<std::uint32_t>& source, UserlandHleCall& call) const
{
    if (!state.enabled_features.contains(mbx2d_abi::feature_blend)) {
        return source;
    }
    auto destination_pixels =
        read_region(destination, x, y, width, height, call);
    if (!destination_pixels || destination_pixels->size() != source.size()) {
        return std::nullopt;
    }
    const auto scale_byte = [](std::uint32_t value, std::uint32_t factor) {
        return (value * factor + 127U) / 255U;
    };
    const auto alpha = static_cast<std::uint32_t>(state.blend.global_alpha);
    const auto is_constant_alpha_crossfade =
        !state.blend.complex &&
        state.blend.source_factor ==
            mbx2d_abi::layerkit_crossfade_source_word &&
        state.blend.destination_factor ==
            mbx2d_abi::layerkit_crossfade_destination_word;
    const auto is_straight_alpha_source_over =
        state.blend.complex &&
        state.blend.source_factor == mbx2d_abi::layerkit_mask_source_word &&
        state.blend.destination_factor ==
            mbx2d_abi::layerkit_mask_destination_word &&
        state.blend.operation == mbx2d_abi::layerkit_mask_operation_word;
    for (std::size_t index = 0; index < source.size(); ++index) {
        const auto source_pixel = source[index];
        const auto destination_pixel = (*destination_pixels)[index];
        if (is_constant_alpha_crossfade) {
            const auto inverse_alpha = 255U - alpha;
            std::uint32_t result { };
            for (std::uint32_t shift = 0; shift < 32U; shift += 8U) {
                const auto source_channel =
                    scale_byte((source_pixel >> shift) & 0xffU, alpha);
                const auto destination_channel = scale_byte(
                    (destination_pixel >> shift) & 0xffU, inverse_alpha);
                result |= std::min(255U, source_channel + destination_channel)
                          << shift;
            }
            (*destination_pixels)[index] = result;
            continue;
        }
        const auto source_alpha = scale_byte(source_pixel >> 24U, alpha);
        const auto inverse_alpha = 255U - source_alpha;
        std::uint32_t result { };
        for (std::uint32_t shift = 0; shift < 24U; shift += 8U) {
            const auto source_channel =
                scale_byte((source_pixel >> shift) & 0xffU,
                    is_straight_alpha_source_over ? source_alpha : alpha);
            const auto destination_channel =
                scale_byte((destination_pixel >> shift) & 0xffU, inverse_alpha);
            const auto channel =
                std::min(255U, source_channel + destination_channel);
            result |= channel << shift;
        }
        const auto destination_alpha =
            scale_byte(destination_pixel >> 24U, inverse_alpha);
        result |= std::min(255U, source_alpha + destination_alpha) << 24U;
        (*destination_pixels)[index] = result;
    }
    return destination_pixels;
}

std::optional<std::vector<std::uint32_t>> Mbx2dHle::transform_copy(
    const RenderState& state, std::int64_t source_width,
    std::int64_t source_height, const std::vector<std::uint32_t>& source,
    std::int64_t& output_width, std::int64_t& output_height,
    UserlandHleCall& call)
{
    const auto scale_x = std::bit_cast<float>(state.scale_x_bits);
    const auto scale_y = std::bit_cast<float>(state.scale_y_bits);
    if (!std::isfinite(scale_x) || !std::isfinite(scale_y) || scale_x == 0.0F ||
        scale_y == 0.0F || source_width <= 0 || source_height <= 0 ||
        source.size() !=
            static_cast<std::size_t>(source_width * source_height)) {
        return std::nullopt;
    }
    const auto scaled_width_value =
        static_cast<double>(source_width) * std::abs(scale_x);
    const auto scaled_height_value =
        static_cast<double>(source_height) * std::abs(scale_y);
    if (!std::isfinite(scaled_width_value) ||
        !std::isfinite(scaled_height_value) ||
        scaled_width_value > static_cast<double>(maximum_transformed_pixels) ||
        scaled_height_value > static_cast<double>(maximum_transformed_pixels)) {
        return std::nullopt;
    }
    const auto scaled_width =
        static_cast<std::int64_t>(std::llround(scaled_width_value));
    const auto scaled_height =
        static_cast<std::int64_t>(std::llround(scaled_height_value));
    if (scaled_width <= 0 || scaled_height <= 0 ||
        static_cast<std::uint64_t>(scaled_width) >
            maximum_transformed_pixels /
                static_cast<std::uint64_t>(scaled_height)) {
        return std::nullopt;
    }
    std::vector<std::uint32_t> scaled(
        static_cast<std::size_t>(scaled_width * scaled_height));
    for (std::int64_t y = 0; y < scaled_height; ++y) {
        auto source_y = std::min(
            source_height - 1, static_cast<std::int64_t>(
                                   static_cast<double>(y) / std::abs(scale_y)));
        if (scale_y < 0.0F)
            source_y = source_height - 1 - source_y;
        for (std::int64_t x = 0; x < scaled_width; ++x) {
            auto source_x = std::min(source_width - 1,
                static_cast<std::int64_t>(
                    static_cast<double>(x) / std::abs(scale_x)));
            if (scale_x < 0.0F)
                source_x = source_width - 1 - source_x;
            scaled[static_cast<std::size_t>(y * scaled_width + x)] =
                source[static_cast<std::size_t>(
                    source_y * source_width + source_x)];
        }
    }

    auto rotation = mbx2d_abi::rotation_identity;
    if (state.enabled_features.contains(mbx2d_abi::feature_rotation)) {
        rotation = state.rotation;
    }
    if (rotation == mbx2d_abi::rotation_identity) {
        output_width = scaled_width;
        output_height = scaled_height;
        return scaled;
    }
    if (rotation != mbx2d_abi::rotation_clockwise_90 &&
        rotation != mbx2d_abi::rotation_180 &&
        rotation != mbx2d_abi::rotation_clockwise_270) {
        if (deferred_trace_count_ < maximum_deferred_traces) {
            call.output().write(
                "[mbx2d-hle] unsupported rotation=" + std::to_string(rotation) +
                " pid=" + std::to_string(call.process_id()) + "\n");
            ++deferred_trace_count_;
        }
        output_width = scaled_width;
        output_height = scaled_height;
        return scaled;
    }

    const auto quarter_turn = rotation == mbx2d_abi::rotation_clockwise_90 ||
                              rotation == mbx2d_abi::rotation_clockwise_270;
    output_width = quarter_turn ? scaled_height : scaled_width;
    output_height = quarter_turn ? scaled_width : scaled_height;
    std::vector<std::uint32_t> transformed(
        static_cast<std::size_t>(output_width * output_height));
    for (std::int64_t y = 0; y < output_height; ++y) {
        for (std::int64_t x = 0; x < output_width; ++x) {
            std::int64_t source_x { };
            std::int64_t source_y { };
            if (rotation == mbx2d_abi::rotation_clockwise_90) {
                source_x = y;
                source_y = scaled_height - 1 - x;
            } else if (rotation == mbx2d_abi::rotation_180) {
                source_x = scaled_width - 1 - x;
                source_y = scaled_height - 1 - y;
            } else {
                source_x = scaled_width - 1 - y;
                source_y = x;
            }
            transformed[static_cast<std::size_t>(y * output_width + x)] =
                scaled[static_cast<std::size_t>(
                    source_y * scaled_width + source_x)];
        }
    }
    return transformed;
}

std::optional<HostCompositeMode> Mbx2dHle::host_composite_mode(
    const RenderState& state) const
{
    if (!state.enabled_features.contains(mbx2d_abi::feature_blend))
        return HostCompositeMode::Copy;
    if (!state.blend.complex &&
        state.blend.source_factor ==
            mbx2d_abi::layerkit_source_over_source_word &&
        state.blend.destination_factor ==
            mbx2d_abi::layerkit_source_over_destination_word) {
        return HostCompositeMode::PremultipliedSourceOver;
    }
    if (!state.blend.complex &&
        state.blend.source_factor ==
            mbx2d_abi::layerkit_global_alpha_source_over_source_word &&
        state.blend.destination_factor ==
            mbx2d_abi::layerkit_global_alpha_source_over_destination_word) {
        return HostCompositeMode::PremultipliedSourceOver;
    }
    if (!state.blend.complex &&
        state.blend.source_factor ==
            mbx2d_abi::layerkit_crossfade_source_word &&
        state.blend.destination_factor ==
            mbx2d_abi::layerkit_crossfade_destination_word) {
        return HostCompositeMode::ConstantAlphaCrossfade;
    }
    if (state.blend.complex &&
        state.blend.source_factor == mbx2d_abi::layerkit_mask_source_word &&
        state.blend.destination_factor ==
            mbx2d_abi::layerkit_mask_destination_word &&
        state.blend.operation == mbx2d_abi::layerkit_mask_operation_word) {
        return HostCompositeMode::SourceOver;
    }
    return std::nullopt;
}

bool Mbx2dHle::submit_host_commands(bool wait, PerfSubmitReason reason)
{
    if (!command_encoder_)
        return false;
    return wait ? command_encoder_->finish(reason)
                : command_encoder_->submit(reason);
}

void Mbx2dHle::blit_color(UserlandHleCall& call, bool context_api)
{
    auto* state = select_state(call, context_api);
    if (state == nullptr) {
        call.set_return(mbx_failure);
        return;
    }
    const auto first = context_api ? 1U : 0U;
    const auto destination = resolve(state->destination);
    if (!destination) {
        call.set_return(mbx_failure);
        return;
    }
    BlitRegion region { 0, 0, signed_argument(call, first),
        signed_argument(call, first + 1U), signed_argument(call, first + 2U),
        signed_argument(call, first + 3U) };
    if (!clip_region(region, nullptr, *destination, state->scissor)) {
        call.set_return(mbx_success);
        return;
    }
    const auto color = call.argument(first + 4U);
    const auto composite_mode = host_composite_mode(*state);
    if (host_graphics_->accelerated() && destination->host_surface &&
        destination->backing &&
        destination->backing->pixel_format == surface_pixel_format_bgra &&
        composite_mode &&
        region.destination_x <= std::numeric_limits<std::int32_t>::max() &&
        region.destination_y <= std::numeric_limits<std::int32_t>::max() &&
        static_cast<std::uint64_t>(region.width) <=
            std::numeric_limits<std::uint32_t>::max() &&
        static_cast<std::uint64_t>(region.height) <=
            std::numeric_limits<std::uint32_t>::max() &&
        command_encoder_->fill(destination->host_surface,
            { static_cast<std::int32_t>(region.destination_x),
                static_cast<std::int32_t>(region.destination_y),
                static_cast<std::uint32_t>(region.width),
                static_cast<std::uint32_t>(region.height) },
            color, *composite_mode, state->blend.global_alpha)) {
        call.set_return(mbx_success);
        return;
    }
    const std::vector<std::uint32_t> source_pixels(
        static_cast<std::size_t>(region.width * region.height), color);
    const auto pixels = composite(*state, *destination, region.destination_x,
        region.destination_y, region.width, region.height, source_pixels, call);
    call.set_return(pixels && write_region(*destination, region.destination_x,
                                  region.destination_y, region.width,
                                  region.height, *pixels, call)
                        ? mbx_success
                        : mbx_failure);
}

void Mbx2dHle::blit_copy(UserlandHleCall& call, bool context_api)
{
    auto* state = select_state(call, context_api);
    if (state == nullptr) {
        call.set_return(mbx_failure);
        return;
    }
    const auto first = context_api ? 1U : 0U;
    const auto source = resolve_source(call, state->source);
    const auto destination = resolve(state->destination);
    if (!source || !destination) {
        call.set_return(mbx_failure);
        return;
    }
    if (!source_surface_allowed(*source)) {
        call.set_return(mbx_success);
        return;
    }
    BlitRegion region { signed_argument(call, first),
        signed_argument(call, first + 1U), signed_argument(call, first + 2U),
        signed_argument(call, first + 3U), signed_argument(call, first + 4U),
        signed_argument(call, first + 5U) };
    const auto composite_mode = host_composite_mode(*state);
    const auto host_source_current = synchronize_host_source(call, *source);
    const auto try_host_copy = [&](HostRectangle source_rectangle,
                                   HostRectangle destination_rectangle,
                                   HostRotation rotation) {
        if (!host_graphics_->accelerated() || !host_source_current ||
            !source->host_surface || !destination->host_surface ||
            !source->backing || !destination->backing ||
            source->backing->pixel_format != surface_pixel_format_bgra ||
            destination->backing->pixel_format != surface_pixel_format_bgra ||
            !composite_mode) {
            return false;
        }
        const auto started = std::chrono::steady_clock::now();
        const auto encoded = command_encoder_->copy(source->host_surface,
            destination->host_surface, source_rectangle, destination_rectangle,
            *composite_mode, state->blend.global_alpha, HostFilter::Nearest,
            rotation);
        performance_counters().record_diagnostic_graphics_hle(
            PerfDiagnosticGraphicsHleKind::HostCopyEncode,
            static_cast<std::uint64_t>(
                std::chrono::duration_cast<std::chrono::nanoseconds>(
                    std::chrono::steady_clock::now() - started)
                    .count()));
        return encoded;
    };
    const auto transform_enabled =
        state->scale_x_bits != mbx2d_abi::float_one_bits ||
        state->scale_y_bits != mbx2d_abi::float_one_bits ||
        (state->enabled_features.contains(mbx2d_abi::feature_rotation) &&
            state->rotation != mbx2d_abi::rotation_identity);
    if (!transform_enabled) {
        if (!clip_region(region, &*source, *destination, state->scissor)) {
            call.set_return(mbx_success);
            return;
        }
        if (region.source_x <= std::numeric_limits<std::int32_t>::max() &&
            region.source_y <= std::numeric_limits<std::int32_t>::max() &&
            region.destination_x <= std::numeric_limits<std::int32_t>::max() &&
            region.destination_y <= std::numeric_limits<std::int32_t>::max() &&
            static_cast<std::uint64_t>(region.width) <=
                std::numeric_limits<std::uint32_t>::max() &&
            static_cast<std::uint64_t>(region.height) <=
                std::numeric_limits<std::uint32_t>::max() &&
            try_host_copy({ static_cast<std::int32_t>(region.source_x),
                              static_cast<std::int32_t>(region.source_y),
                              static_cast<std::uint32_t>(region.width),
                              static_cast<std::uint32_t>(region.height) },
                { static_cast<std::int32_t>(region.destination_x),
                    static_cast<std::int32_t>(region.destination_y),
                    static_cast<std::uint32_t>(region.width),
                    static_cast<std::uint32_t>(region.height) },
                HostRotation::Identity)) {
            call.set_return(mbx_success);
            return;
        }
        const auto source_pixels = read_region(*source, region.source_x,
            region.source_y, region.width, region.height, call);
        const auto pixels =
            source_pixels
                ? composite(*state, *destination, region.destination_x,
                      region.destination_y, region.width, region.height,
                      *source_pixels, call)
                : std::nullopt;
        call.set_return(
            pixels && write_region(*destination, region.destination_x,
                          region.destination_y, region.width, region.height,
                          *pixels, call)
                ? mbx_success
                : mbx_failure);
        return;
    }

    if (region.source_x < 0 || region.source_y < 0 || region.width <= 0 ||
        region.height <= 0 || region.source_x + region.width > source->width ||
        region.source_y + region.height > source->height) {
        call.set_return(mbx_failure);
        return;
    }
    const auto scale_x = std::bit_cast<float>(state->scale_x_bits);
    const auto scale_y = std::bit_cast<float>(state->scale_y_bits);
    const auto rotation =
        state->enabled_features.contains(mbx2d_abi::feature_rotation)
            ? state->rotation
            : mbx2d_abi::rotation_identity;
    const auto scaled_dimension = [](std::int64_t dimension, float scale) {
        if (!std::isfinite(scale) || scale <= 0.0F)
            return std::int64_t { 0 };
        const auto value = static_cast<double>(dimension) * scale;
        if (!std::isfinite(value) ||
            value >
                static_cast<double>(std::numeric_limits<std::int64_t>::max())) {
            return std::int64_t { 0 };
        }
        return static_cast<std::int64_t>(std::llround(value));
    };
    const auto scaled_width = scaled_dimension(region.width, scale_x);
    const auto scaled_height = scaled_dimension(region.height, scale_y);
    std::optional<HostRotation> host_rotation;
    if (rotation == mbx2d_abi::rotation_identity) {
        host_rotation = HostRotation::Identity;
    } else if (rotation == mbx2d_abi::rotation_clockwise_90) {
        host_rotation = HostRotation::Clockwise90;
    } else if (rotation == mbx2d_abi::rotation_180) {
        host_rotation = HostRotation::Rotate180;
    } else if (rotation == mbx2d_abi::rotation_clockwise_270) {
        host_rotation = HostRotation::Clockwise270;
    }
    const auto quarter_turn = rotation == mbx2d_abi::rotation_clockwise_90 ||
                              rotation == mbx2d_abi::rotation_clockwise_270;
    const auto output_width = quarter_turn ? scaled_height : scaled_width;
    const auto output_height = quarter_turn ? scaled_width : scaled_height;
    const auto destination_inside_scissor =
        !state->scissor.enabled ||
        (region.destination_x >= state->scissor.left &&
            region.destination_y >= state->scissor.top &&
            region.destination_x + output_width <= state->scissor.right &&
            region.destination_y + output_height <= state->scissor.bottom);
    if (host_rotation && output_width > 0 && output_height > 0 &&
        region.destination_x >= 0 && region.destination_y >= 0 &&
        region.destination_x + output_width <= destination->width &&
        region.destination_y + output_height <= destination->height &&
        destination_inside_scissor &&
        region.source_x <= std::numeric_limits<std::int32_t>::max() &&
        region.source_y <= std::numeric_limits<std::int32_t>::max() &&
        region.destination_x <= std::numeric_limits<std::int32_t>::max() &&
        region.destination_y <= std::numeric_limits<std::int32_t>::max() &&
        static_cast<std::uint64_t>(region.width) <=
            std::numeric_limits<std::uint32_t>::max() &&
        static_cast<std::uint64_t>(region.height) <=
            std::numeric_limits<std::uint32_t>::max() &&
        static_cast<std::uint64_t>(output_width) <=
            std::numeric_limits<std::uint32_t>::max() &&
        static_cast<std::uint64_t>(output_height) <=
            std::numeric_limits<std::uint32_t>::max() &&
        try_host_copy({ static_cast<std::int32_t>(region.source_x),
                          static_cast<std::int32_t>(region.source_y),
                          static_cast<std::uint32_t>(region.width),
                          static_cast<std::uint32_t>(region.height) },
            { static_cast<std::int32_t>(region.destination_x),
                static_cast<std::int32_t>(region.destination_y),
                static_cast<std::uint32_t>(output_width),
                static_cast<std::uint32_t>(output_height) },
            *host_rotation)) {
        call.set_return(mbx_success);
        return;
    }
    const auto source_pixels = read_region(*source, region.source_x,
        region.source_y, region.width, region.height, call);
    std::int64_t transformed_width { };
    std::int64_t transformed_height { };
    const auto transformed =
        source_pixels
            ? transform_copy(*state, region.width, region.height,
                  *source_pixels, transformed_width, transformed_height, call)
            : std::nullopt;
    if (!transformed) {
        call.set_return(mbx_failure);
        return;
    }
    BlitRegion transformed_region { 0, 0, region.destination_x,
        region.destination_y, transformed_width, transformed_height };
    if (!clip_region(
            transformed_region, nullptr, *destination, state->scissor)) {
        call.set_return(mbx_success);
        return;
    }
    std::vector<std::uint32_t> clipped(static_cast<std::size_t>(
        transformed_region.width * transformed_region.height));
    for (std::int64_t y = 0; y < transformed_region.height; ++y) {
        const auto source_offset = static_cast<std::size_t>(
            (transformed_region.source_y + y) * transformed_width +
            transformed_region.source_x);
        const auto destination_offset =
            static_cast<std::size_t>(y * transformed_region.width);
        std::copy_n(transformed->begin() + source_offset,
            static_cast<std::size_t>(transformed_region.width),
            clipped.begin() + destination_offset);
    }
    const auto pixels = composite(*state, *destination,
        transformed_region.destination_x, transformed_region.destination_y,
        transformed_region.width, transformed_region.height, clipped, call);
    call.set_return(
        pixels &&
                write_region(*destination, transformed_region.destination_x,
                    transformed_region.destination_y, transformed_region.width,
                    transformed_region.height, *pixels, call)
            ? mbx_success
            : mbx_failure);
}

void Mbx2dHle::submit_destination(UserlandHleCall& call, bool context_api)
{
    auto* state = select_state(call, context_api);
    if (state == nullptr)
        return;
    const auto destination = resolve(state->destination);
    if (!destination || destination->framebuffer || !display_ ||
        destination->width != display_->width() ||
        destination->height != display_->height()) {
        return;
    }
    // Once firmware has completed a transactional hardware-layer frame,
    // IOMobileFramebuffer SwapEnd owns scanout. MBX finish/swap still commits
    // pixels to its CoreSurface backing, but presenting that individual render
    // target would bypass the other retained layers.
    if (presentation_tracker_ && presentation_tracker_->has_presented_frame()) {
        return;
    }
    if (host_graphics_->accelerated() && destination->host_surface) {
        auto graphics = host_graphics_;
        auto surface = destination->host_surface;
        display_->replace_surface(
            surface,
            [graphics, surface] {
                if (!graphics->map_cpu(
                        *surface, true, PerfCpuMapReason::DeferredDisplayRead))
                    return std::vector<std::uint32_t> { };
                auto mapping = surface->map_cpu(
                    false, PerfCpuMapReason::DeferredDisplayRead);
                return mapping.frame().pixels;
            },
            call.process_id(),
            [surface] {
                return std::max(
                    surface->cpu_generation(), surface->gpu_generation());
            });
        return;
    }
    const auto pixels = read_region(
        *destination, 0, 0, destination->width, destination->height, call);
    if (pixels) {
        display_->replace_pixels(*pixels, call.process_id());
    }
}

void Mbx2dHle::flush_surfaces(UserlandHleCall& call)
{
    const auto array = call.argument(0);
    const auto count = call.argument(1);
    if (count == 0) {
        call.set_return(mbx_success);
        return;
    }
    if (array == 0 || count > mbx2d_abi::maximum_flush_surface_count) {
        call.set_return(mbx_failure);
        return;
    }
    for (std::uint32_t index = 0; index < count; ++index) {
        const auto address =
            static_cast<std::uint64_t>(array) +
            static_cast<std::uint64_t>(index) * sizeof(std::uint32_t);
        if (address > std::numeric_limits<std::uint32_t>::max()) {
            call.set_return(mbx_failure);
            return;
        }
        const auto surface =
            call.memory().read32(static_cast<std::uint32_t>(address));
        const auto found = surface ? surfaces_.find(*surface) : surfaces_.end();
        if (found == surfaces_.end()) {
            call.set_return(mbx_failure);
            return;
        }
        const auto core_surface_id = found->second.core_surface_id;
        if (found->second.client_backing)
            found->second.client_host_source_dirty = true;
        // Both lists are unified-memory visibility barriers. Source publication
        // makes CPU-rendered pixels available to a retained handle; destination
        // invalidation does the same before GPU commands consume prior
        // contents. Exact merging preserves unrelated native pixels in either
        // direction.
        if (core_surface_id != 0 && !surface_store_->synchronize_from_guest(
                                        call.memory(), core_surface_id)) {
            call.set_return(mbx_failure);
            return;
        }
    }
    // FlushSurfaces publishes unified-memory changes; it is not a command
    // queue flush. Pending GPU work remains ordered until mbx2DFlush,
    // mbx2DFinish, or a host consumer submits it.
    call.set_return(mbx_success);
}

void Mbx2dHle::terminate(UserlandHleCall& call)
{
    if (!initialized_) {
        call.set_return(mbx_failure);
        return;
    }
    static_cast<void>(submit_host_commands(true, PerfSubmitReason::MbxFinish));
    reset();
    call.set_return(mbx_success);
}

void Mbx2dHle::deferred(UserlandHleCall& call)
{
    if (deferred_trace_count_ < maximum_deferred_traces) {
        call.output().write(
            "[mbx2d-hle] deferred symbol=" + std::string { call.symbol() } +
            " pid=" + std::to_string(call.process_id()) + "\n");
        ++deferred_trace_count_;
    }
    call.set_return(mbx_success);
}

} // namespace shade
