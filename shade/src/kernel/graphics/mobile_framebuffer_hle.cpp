// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Adapt guest framebuffer layer configuration, swaps and display
// notifications.

#include "kernel/mobile_framebuffer_hle.hpp"

#include <algorithm>
#include <atomic>
#include <bit>
#include <cmath>
#include <cstdint>
#include <limits>
#include <mutex>
#include <optional>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "foundation/address_space.hpp"
#include "foundation/application_display.hpp"
#include "foundation/application_path.hpp"
#include "graphics/core_surface_abi.hpp"
#include "foundation/cpu.hpp"
#include "graphics/display.hpp"
#include "graphics/gles_renderer.hpp"
#include "kernel/iokit_abi.hpp"
#include "kernel/kernel_shared_state.hpp"
#include "graphics/mobile_framebuffer_abi.hpp"
#include "foundation/output.hpp"
#include "foundation/performance.hpp"
#include "graphics/presentation_tracker.hpp"
#include "foundation/scene_coordinator.hpp"
#include "graphics/surface_store.hpp"
#include "graphics/surface_transport_abi.hpp"
#include "foundation/userland_hle.hpp"
#include "surface_transport_hle.hpp"

namespace shade {
namespace {

    constexpr std::string_view framebuffer_image {
        "/IOMobileFramebuffer.framework/"
        "IOMobileFramebuffer"
    };
    std::atomic<std::uint64_t> next_scanout_surface { 1 };

    std::optional<ApplicationDisplay> application_display_for_process(
        const std::shared_ptr<KernelSharedState>& shared_state,
        std::uint32_t process_id)
    {
        if (!shared_state)
            return std::nullopt;
        std::lock_guard lock { shared_state->mach_mutex };
        const auto process = shared_state->processes.find(process_id);
        return process == shared_state->processes.end()
                   ? std::nullopt
                   : std::optional<ApplicationDisplay> {
                         process->second.application_display };
    }

} // namespace

MobileFramebufferHle::MobileFramebufferHle(UserlandHleRegistry& registry,
    std::shared_ptr<DisplayState> display,
    std::shared_ptr<SurfaceStore> surfaces,
    std::shared_ptr<PresentationTracker> presentations)
    : display_ { std::move(display) }
    , surface_store_ { surfaces ? std::move(surfaces)
                                : std::make_shared<SurfaceStore>() }
    , presentation_tracker_ { presentations
                                  ? std::move(presentations)
                                  : std::make_shared<PresentationTracker>() }
    , host_graphics_ { shared_gles_renderer() }
    , command_encoder_ { host_graphics_->create_command_encoder() }
{
    const auto add = [&](std::string symbol,
                         UserlandHleRegistry::Handler handler) {
        registry.register_function(std::string { framebuffer_image },
            std::move(symbol), std::move(handler));
    };
    register_device_functions(registry);
    // NotifyFunc begins by calling this firmware routine before it examines or
    // dispatches the notification. Observe that boundary, then immediately run
    // the original routine. The VSync/IONotificationPort entry points, callback
    // dispatch, coalescing, arguments, and object lifetime remain firmware
    // code.
    add("_IOMobileFramebufferGetNotifyMessageCount",
        [this](UserlandHleCall& call) {
            const auto callback_processor =
                static_cast<std::uint32_t>(call.cpu().processor_id());
            std::optional<std::uint64_t> callback_sequence;
            if (shared_state_) {
                std::lock_guard lock { shared_state_->mach_mutex };
                // This records the processor and consumes the host-only pending
                // watermark at the real firmware callback boundary, after Mach
                // delivery and before the original routine resumes. Guest
                // callback semantics are unchanged.
                callback_sequence =
                    shared_state_->observe_display_vsync_callback_locked(
                    call.process_id(), call.argument(0), callback_processor);
            }
            performance_counters().record_vsync_callback(call.process_id(),
                call.argument(0), callback_sequence.value_or(0),
                callback_processor);
            call.resume_original_persistently();
        });
    // GetLayerDefaultSurface intentionally remains firmware code. It calls
    // IOConnectCallScalarMethod(selector 3) and then CoreSurfaceBufferLookup,
    // preserving the real CFRuntime wrapper around our client-buffer HLE.
    add("_IOMobileFramebufferSwapBegin", [this](UserlandHleCall& call) {
        const auto callback_processor =
            static_cast<std::uint32_t>(call.cpu().processor_id());
        std::optional<std::uint64_t> callback_sequence;
        if (shared_state_) {
            std::lock_guard lock { shared_state_->mach_mutex };
            callback_sequence =
                shared_state_->observe_display_vsync_frame_begin_locked(
                    call.process_id(), call.argument(0), callback_processor);
        }
        if (callback_sequence) {
            performance_counters().record_vsync_callback(
                call.process_id(), call.argument(0), *callback_sequence,
                callback_processor);
        }
        const auto swap_id = next_swap_id_++;
        call.set_return(call.write32(call.argument(1), swap_id)
                            ? iokit_abi::success
                            : iokit_abi::bad_argument);
    });
    add("_IOMobileFramebufferSwapSetBackgroundColor",
        [this](UserlandHleCall& call) { set_background_color(call); });
    add("_IOMobileFramebufferSwapEnd", [this](UserlandHleCall& call) {
        if (display_write_allowed(call)) {
            if (shared_state_) {
                std::lock_guard lock { shared_state_->mach_mutex };
                shared_state_->observe_display_vsync_swap_end_locked(
                    call.process_id(), call.argument(0));
            }
            performance_counters().record_vsync_swap_end(call.process_id(),
                call.argument(0),
                static_cast<std::uint32_t>(call.cpu().processor_id()));
            const auto submission = submit_layers(call);
            if (submission == SubmissionResult::Deferred) {
                // Keep the firmware's display cadence alive with the last
                // accepted surface, but leave ownership and transition
                // callbacks untouched until the candidate is actually ready.
                if (display_)
                    display_->present();
            } else {
                const auto semantic_process_id = record_presentation(call);
                if (display_) {
                    display_->present(call.process_id());
                    performance_counters().record_vsync_guest_submit(
                        call.process_id(), call.argument(0));
                    if (frame_presented_handler_)
                        frame_presented_handler_(call.process_id());
                    if (semantic_process_id && semantic_presentation_handler_)
                        semantic_presentation_handler_(*semantic_process_id);
                }
            }
        }
        call.set_return(iokit_abi::success);
    });
    add("_IOMobileFramebufferSwapSurface", [this](UserlandHleCall& call) {
        if (display_ && display_write_allowed(call))
            display_->present(call.process_id());
        call.set_return(iokit_abi::success);
    });
    const auto success = [](UserlandHleCall& call) {
        call.set_return(iokit_abi::success);
    };
    add("_IOMobileFramebufferWaitSurface", success);
    add("_IOMobileFramebufferEnableStatistics", success);
    // GetNotifyMessageCount's observed original implementation asks the Mach
    // port layer for MACH_PORT_RECEIVE_STATUS and returns mps_msgcount so the
    // native callback can coalesce queued notifications accurately.
    add("_IOMobileFramebufferSetDebugFlags", success);
    add("_IOMobileFramebufferSetTVOutMode", success);
    add("_IOMobileFramebufferSetWSSInfo", success);
    add("_IOMobileFramebufferSwapSetGammaTable", success);
    add("_IOMobileFramebufferSwapSetLayer",
        [this](UserlandHleCall& call) { set_layer(call); });
    add("_IOMobileFramebufferSwapWait", success);
    add("_IOMobileFramebufferCreateStatistics",
        [](UserlandHleCall& call) { call.set_return(0); });
}

void MobileFramebufferHle::reset()
{
    external_framebuffers_.clear();
    layers_.clear();
    layer_surface_leases_.clear();
    // The HLE is shared by all guest processes. An exec of a helper process
    // must not erase the panel's last submitted frame while SpringBoard is
    // being relaunched; preserve scanout until the new owner presents.
    next_swap_id_ = 1;
    background_argb_ = 0xff000000U;
    submitted_background_argb_ = background_argb_;
    composition_surface_index_ = 0;
    deferred_foreground_frame_.reset();
    // Keep submitted_layers_ and scanout_contents_valid_ across process exec.
}

void MobileFramebufferHle::inherit_state(const MobileFramebufferHle& parent)
{
    external_framebuffers_ = parent.external_framebuffers_;
    layers_ = parent.layers_;
    layer_surface_leases_ = parent.layer_surface_leases_;
    submitted_layers_ = parent.submitted_layers_;
    next_swap_id_ = parent.next_swap_id_;
    background_argb_ = parent.background_argb_;
    submitted_background_argb_ = parent.submitted_background_argb_;
    scanout_surface_ = parent.scanout_surface_;
    // The published scanout is read-only from the child's point of view. Do
    // not inherit the writable composition targets: forked kernels can submit
    // concurrently, so each instance must own the targets it may modify.
    composition_surfaces_.clear();
    composition_surface_index_ = 0;
    scanout_contents_valid_ = parent.scanout_contents_valid_;
    deferred_foreground_frame_.reset();
}

void MobileFramebufferHle::set_display(std::shared_ptr<DisplayState> display)
{
    display_ = std::move(display);
    if (scanout_surface_ && display_) {
        const auto descriptor = scanout_surface_->descriptor();
        if (descriptor.width != display_->width() ||
            descriptor.height != display_->height()) {
            scanout_surface_.reset();
            composition_surfaces_.clear();
            composition_surface_index_ = 0;
            submitted_layers_.clear();
            scanout_contents_valid_ = false;
            deferred_foreground_frame_.reset();
        }
    }
}

void MobileFramebufferHle::set_shared_state(
    std::shared_ptr<KernelSharedState> shared_state)
{
    shared_state_ = std::move(shared_state);
}

void MobileFramebufferHle::set_presentation_tracker(
    std::shared_ptr<PresentationTracker> presentations)
{
    presentation_tracker_ = std::move(presentations);
}

void MobileFramebufferHle::set_scene_coordinator(
    std::shared_ptr<SceneCoordinator> scenes)
{
    scene_coordinator_ = std::move(scenes);
}

void MobileFramebufferHle::set_frame_presented_handler(
    std::function<void(std::uint32_t)> handler)
{
    frame_presented_handler_ = std::move(handler);
}

void MobileFramebufferHle::set_semantic_presentation_handler(
    std::function<void(std::uint32_t)> handler)
{
    semantic_presentation_handler_ = std::move(handler);
}

bool MobileFramebufferHle::display_write_allowed(UserlandHleCall& call) const
{
    if (is_external_framebuffer(call))
        return false;
    if (!shared_state_)
        return true;
    std::lock_guard lock { shared_state_->mach_mutex };
    const auto process = shared_state_->processes.find(call.process_id());
    if (process == shared_state_->processes.end() ||
        !is_application_executable_path(process->second.executable_path)) {
        return true;
    }
    if (is_setup_assistant_executable_path(process->second.executable_path))
        return true;
    return active_application_owns_display_locked(*shared_state_,
        call.process_id(),
        scene_coordinator_
            ? std::optional<bool> { scene_coordinator_
                      ->client_scene_presentable(call.process_id()) }
            : std::nullopt);
}

bool MobileFramebufferHle::has_active_layers() const
{
    return !layers_.empty();
}

void MobileFramebufferHle::apply_application_display(
    LayerState& state, std::uint32_t producer_process_id,
    std::uint32_t source_width, std::uint32_t source_height) const
{
    if (!display_ || producer_process_id == 0U)
        return;
    const auto profile = application_display_for_process(
        shared_state_, producer_process_id);
    if (!profile || profile->kind == ApplicationDisplayMode::Native)
        return;
    const auto output = display_->geometry();
    const auto logical = application_display_geometry(*profile, output);
    if (!logical.valid() || source_width == 0U || source_height == 0U)
        return;
    const auto is_origin = [](float value) { return value == 0.0F; };
    const auto is_full_rectangle = [&](const Rectangle& rectangle,
                                       DisplayGeometry geometry) {
        return is_origin(rectangle.x) && is_origin(rectangle.y) &&
               rectangle.width == static_cast<float>(geometry.width) &&
               rectangle.height == static_cast<float>(geometry.height);
    };
    if (!is_origin(state.source.x) || !is_origin(state.source.y) ||
        (!is_full_rectangle(state.destination, logical) &&
            !is_full_rectangle(state.destination, output))) {
        return;
    }
    const auto viewport = application_display_viewport(*profile, output);
    const auto width = std::min(logical.width, source_width);
    const auto height = std::min(logical.height, source_height);
    if (viewport.width == 0U || viewport.height == 0U || width == 0U ||
        height == 0U) {
        return;
    }
    state.source = { 0.0F, 0.0F, static_cast<float>(width),
        static_cast<float>(height) };
    state.destination = { static_cast<float>(viewport.x),
        static_cast<float>(viewport.y), static_cast<float>(viewport.width),
        static_cast<float>(viewport.height) };
}

bool MobileFramebufferHle::application_surface_allowed(
    std::uint32_t producer_process_id, std::uint64_t publication_sequence) const
{
    if (!shared_state_ || producer_process_id == 0U ||
        publication_sequence == 0U) {
        return true;
    }
    if (!shared_state_->application_fullscreen_surface_suppression_active.load(
            std::memory_order_acquire)) {
        return true;
    }
    std::lock_guard lock { shared_state_->mach_mutex };
    return !shared_state_
                ->suppressed_application_fullscreen_surface_publications
                .contains({ producer_process_id, publication_sequence });
}

void MobileFramebufferHle::ensure_scanout_surface()
{
    if (!display_)
        return;
    if (scanout_surface_) {
        const auto descriptor = scanout_surface_->descriptor();
        if (descriptor.width == display_->width() &&
            descriptor.height == display_->height()) {
            return;
        }
    }
    const auto pixels =
        static_cast<std::size_t>(display_->width()) * display_->height();
    const std::vector<std::uint32_t> initial(pixels, background_argb_);
    scanout_surface_ = host_graphics_->create_surface(
        { 0x4d464253U,
            next_scanout_surface.fetch_add(1, std::memory_order_relaxed) },
        HostSurfaceDescriptor { display_->width(), display_->height(),
            display_->width() * core_surface_abi::bytes_per_bgra_pixel,
            surface_pixel_format_bgra, PerfSurfaceKind::Scanout },
        initial);
    submitted_layers_.clear();
    submitted_background_argb_ = background_argb_;
    scanout_contents_valid_ = false;
}

std::shared_ptr<HostSurface> MobileFramebufferHle::acquire_composition_surface()
{
    constexpr std::size_t composition_ring_size = 8;
    const auto descriptor =
        HostSurfaceDescriptor { display_->width(), display_->height(),
            display_->width() * core_surface_abi::bytes_per_bgra_pixel,
            surface_pixel_format_bgra, PerfSurfaceKind::Scanout };
    while (composition_surfaces_.size() < composition_ring_size) {
        auto surface = host_graphics_->create_surface(
            { 0x434f4d50U,
                next_scanout_surface.fetch_add(1, std::memory_order_relaxed) },
            descriptor);
        composition_surfaces_.push_back(std::move(surface));
    }
    for (std::size_t attempt = 0; attempt < composition_surfaces_.size();
        ++attempt) {
        const auto index =
            composition_surface_index_ % composition_surfaces_.size();
        composition_surface_index_ =
            (index + 1U) % composition_surfaces_.size();
        const auto& candidate = composition_surfaces_[index];
        if (candidate && candidate != scanout_surface_ &&
            !candidate->presentation_leased())
            return candidate;
    }
    // All ring targets may still be referenced by the ordered presenter. Grow
    // the host-only pool for this submission instead of reusing a mutable
    // surface and changing the pixels of an older queued DisplayFrame.
    auto surface = host_graphics_->create_surface(
        { 0x434f4d50U,
            next_scanout_surface.fetch_add(1, std::memory_order_relaxed) },
        descriptor);
    composition_surfaces_.push_back(surface);
    return surface;
}

MobileFramebufferHle::SubmissionResult
MobileFramebufferHle::submit_host_layers(UserlandHleCall& call)
{
    constexpr bool debug_submission = false;
    if (!display_ || !host_graphics_->accelerated() || !command_encoder_)
        return SubmissionResult::Failed;
    ensure_scanout_surface();
    if (!scanout_surface_)
        return SubmissionResult::Failed;
    const auto exact_rectangle =
        [](const Rectangle& rectangle) -> std::optional<HostRectangle> {
        const auto exact = [](float value) {
            return std::isfinite(value) && std::trunc(value) == value;
        };
        if (!exact(rectangle.x) || !exact(rectangle.y) ||
            !exact(rectangle.width) || !exact(rectangle.height) ||
            rectangle.x < 0.0F || rectangle.y < 0.0F ||
            rectangle.width <= 0.0F || rectangle.height <= 0.0F ||
            static_cast<double>(rectangle.x) >
                static_cast<double>(std::numeric_limits<std::int32_t>::max()) ||
            static_cast<double>(rectangle.y) >
                static_cast<double>(std::numeric_limits<std::int32_t>::max()) ||
            static_cast<double>(rectangle.width) >
                static_cast<double>(
                    std::numeric_limits<std::uint32_t>::max()) ||
            static_cast<double>(rectangle.height) >
                static_cast<double>(
                    std::numeric_limits<std::uint32_t>::max())) {
            return std::nullopt;
        }
        return HostRectangle { static_cast<std::int32_t>(rectangle.x),
            static_cast<std::int32_t>(rectangle.y),
            static_cast<std::uint32_t>(rectangle.width),
            static_cast<std::uint32_t>(rectangle.height) };
    };

    struct PreparedLayer {
        std::uint32_t order { };
        LayerState state;
        std::shared_ptr<HostSurface> source;
        HostRectangle source_rectangle;
        HostRectangle destination_rectangle;
        std::uint64_t generation { };
    };
    std::vector<PreparedLayer> prepared_layers;
    prepared_layers.reserve(layers_.size());
    for (const auto& [layer, state] : layers_) {
        const auto backing = surface_store_->find(state.surface_id);
        const auto allowed =
            !backing || application_surface_allowed(
                            backing->provenance.producer_process_id,
                            backing->provenance.publication_sequence);
        if (!allowed) {
            continue;
        }
        auto effective_state = state;
        if (backing) {
            apply_application_display(effective_state,
                backing->provenance.producer_process_id, backing->width,
                backing->height);
        }
        const auto source =
            surface_store_->host_surface(effective_state.surface_id);
        if (debug_submission) {
            std::string message =
                "[mfb-debug] layer pid=" + std::to_string(call.process_id()) +
                " order=" + std::to_string(layer) +
                " id=" + std::to_string(state.surface_id) +
                " allowed=" + (allowed ? "1" : "0") +
                " src=" + std::to_string(state.source.x) + "," +
                std::to_string(state.source.y) + "," +
                std::to_string(state.source.width) + "," +
                std::to_string(state.source.height) +
                " dst=" + std::to_string(state.destination.x) + "," +
                std::to_string(state.destination.y) + "," +
                std::to_string(state.destination.width) + "," +
                std::to_string(state.destination.height);
            if (backing) {
                message += " backing=" + std::to_string(backing->width) +
                           "x" + std::to_string(backing->height) +
                           " pitch=" + std::to_string(backing->bytes_per_row) +
                           " fmt=" + std::to_string(backing->pixel_format) +
                           " producer=" +
                           std::to_string(backing->provenance.producer_process_id) +
                           " publication=" +
                           std::to_string(backing->provenance.publication_sequence);
            } else {
                message += " backing=missing";
            }
            if (source) {
                const auto descriptor = source->descriptor();
                message += " host=" + std::to_string(descriptor.width) + "x" +
                           std::to_string(descriptor.height) +
                           " hostfmt=" + std::to_string(descriptor.pixel_format) +
                           " cpu=" + std::to_string(source->cpu_generation()) +
                           " gpu=" + std::to_string(source->gpu_generation()) +
                           " damage=" +
                           std::to_string(source->cpu_damage_rectangles().size());
            } else {
                message += " host=missing";
            }
            call.output().write(message + "\n");
        }
        // Page-granular guest dirtiness cannot be merged safely into a surface
        // whose complete contents are newer on the GPU. CPU-owned layers still
        // need their direct mapped writes imported before presentation.
        if (source && source->gpu_generation() <= source->cpu_generation() &&
            !surface_store_->synchronize_from_guest(
                call.memory(), effective_state.surface_id)) {
            return SubmissionResult::Failed;
        }
        const auto source_rectangle = exact_rectangle(effective_state.source);
        const auto destination_rectangle =
            exact_rectangle(effective_state.destination);
        if (!backing ||
            (backing->pixel_format != surface_pixel_format_bgra &&
                !surface_is_packed_555(backing->pixel_format)) ||
            !source || !source_rectangle || !destination_rectangle ||
            static_cast<std::uint32_t>(source_rectangle->x) >
                backing->width -
                    std::min(backing->width, source_rectangle->width) ||
            source_rectangle->width > backing->width ||
            static_cast<std::uint32_t>(source_rectangle->y) >
                backing->height -
                    std::min(backing->height, source_rectangle->height) ||
            source_rectangle->height > backing->height ||
            static_cast<std::uint32_t>(destination_rectangle->x) >
                display_->width() -
                    std::min(display_->width(), destination_rectangle->width) ||
            destination_rectangle->width > display_->width() ||
            static_cast<std::uint32_t>(destination_rectangle->y) >
                display_->height() - std::min(display_->height(),
                                         destination_rectangle->height) ||
            destination_rectangle->height > display_->height()) {
            return SubmissionResult::Failed;
        }
        prepared_layers.push_back(
            { layer, effective_state, source, *source_rectangle,
                *destination_rectangle,
                std::max(source->cpu_generation(), source->gpu_generation()) });
    }

    if (debug_submission) {
        call.output().write(
            "[mfb-debug] submit pid=" + std::to_string(call.process_id()) +
            " layers=" + std::to_string(layers_.size()) +
            " prepared=" + std::to_string(prepared_layers.size()) +
            " scanout-valid=" + (scanout_contents_valid_ ? "1" : "0") +
            " background=" + std::to_string(background_argb_) + "\n");
    }

    const auto right = [](const HostRectangle& rectangle) {
        return static_cast<std::int64_t>(rectangle.x) + rectangle.width;
    };
    const auto bottom = [](const HostRectangle& rectangle) {
        return static_cast<std::int64_t>(rectangle.y) + rectangle.height;
    };
    const auto intersection = [&](const HostRectangle& left,
                                  const HostRectangle& right_rectangle)
        -> std::optional<HostRectangle> {
        const auto x = std::max(left.x, right_rectangle.x);
        const auto y = std::max(left.y, right_rectangle.y);
        const auto x_end = std::min(right(left), right(right_rectangle));
        const auto y_end = std::min(bottom(left), bottom(right_rectangle));
        if (x_end <= x || y_end <= y)
            return std::nullopt;
        return HostRectangle { x, y, static_cast<std::uint32_t>(x_end - x),
            static_cast<std::uint32_t>(y_end - y) };
    };
    const auto full_display =
        HostRectangle { 0, 0, display_->width(), display_->height() };

    const auto active_scene = scene_coordinator_
                                  ? scene_coordinator_->active_client_scene()
                                  : std::nullopt;
    const auto active_scene_process_id =
        active_scene && active_scene->state == ClientSceneState::Active
            ? active_scene->client_process_id
            : 0U;
    const auto foreground_handoff_pending = [&] {
        if (!shared_state_ || active_scene_process_id == 0U)
            return false;
        std::lock_guard lock { shared_state_->mach_mutex };
        const auto& transition =
            shared_state_->foreground_transition_snapshot;
        if (!transition ||
            transition->terminal_state !=
                KernelSharedState::ForegroundTransitionTerminalState::Pending ||
            !transition->destination ||
            transition->destination->process_id != active_scene_process_id ||
            transition->destination_first_frame) {
            return false;
        }
        const auto process =
            shared_state_->processes.find(active_scene_process_id);
        return process != shared_state_->processes.end() &&
               process->second.incarnation ==
                   transition->destination->incarnation;
    }();
    const auto covers_display = [&](const PreparedLayer& layer) {
        const auto descriptor = layer.source->descriptor();
        return layer.destination_rectangle == full_display &&
               layer.source_rectangle.x == 0 &&
               layer.source_rectangle.y == 0 &&
               layer.source_rectangle.width == descriptor.width &&
               layer.source_rectangle.height == descriptor.height &&
               descriptor.width == display_->width() &&
               descriptor.height == display_->height();
    };
    const auto foreground_candidate =
        std::find_if(prepared_layers.begin(), prepared_layers.end(),
            [&](const PreparedLayer& layer) {
                return covers_display(layer);
            });
    const auto is_new_foreground_surface = [&] {
        if (!foreground_handoff_pending || active_scene_process_id == 0U ||
            !scanout_contents_valid_ ||
            foreground_candidate == prepared_layers.end()) {
            return false;
        }
        const auto submitted = submitted_layers_.find(
            foreground_candidate->order);
        return submitted == submitted_layers_.end() ||
               submitted->second.surface_key != foreground_candidate->source->key();
    };

    if (deferred_foreground_frame_ &&
        (!foreground_handoff_pending ||
            deferred_foreground_frame_->scene_process_id !=
                active_scene_process_id ||
            !scanout_contents_valid_)) {
        deferred_foreground_frame_.reset();
    }
    bool release_deferred_foreground_frame = false;
    bool defer_foreground_publication = false;
    if (deferred_foreground_frame_) {
        const auto ready_generation = std::find_if(prepared_layers.begin(),
            prepared_layers.end(), [&](const PreparedLayer& layer) {
                return covers_display(layer) && layer.generation >
                                                   deferred_foreground_frame_
                                                       ->generation;
            });
        if (ready_generation != prepared_layers.end()) {
            deferred_foreground_frame_.reset();
            release_deferred_foreground_frame = true;
        } else {
            // Keep the last accepted scanout visible while the destination's
            // first real GPU update is still pending. Continue through the
            // compositor below so guest rendering and the native command
            // stream are not stalled by the publication guard.
            defer_foreground_publication = true;
        }
    }
    if (!release_deferred_foreground_frame && !deferred_foreground_frame_ &&
        is_new_foreground_surface()) {
        deferred_foreground_frame_ = DeferredForegroundFrame {
            active_scene_process_id, foreground_candidate->generation };
        defer_foreground_publication = true;
    }
    if (!defer_foreground_publication) {
        for (const auto& layer : prepared_layers)
            layer.source->mark_scanout_presentation();
    }

    std::vector<HostRectangle> damage;
    const auto add_damage = [&](HostRectangle rectangle) {
        const auto clipped = intersection(rectangle, full_display);
        if (!clipped)
            return;
        rectangle = *clipped;
        for (std::size_t index = 0; index < damage.size();) {
            const auto touches =
                static_cast<std::int64_t>(rectangle.x) <=
                    right(damage[index]) &&
                static_cast<std::int64_t>(damage[index].x) <=
                    right(rectangle) &&
                static_cast<std::int64_t>(rectangle.y) <=
                    bottom(damage[index]) &&
                static_cast<std::int64_t>(damage[index].y) <= bottom(rectangle);
            if (!touches) {
                ++index;
                continue;
            }
            const auto x = std::min(rectangle.x, damage[index].x);
            const auto y = std::min(rectangle.y, damage[index].y);
            const auto x_end = std::max(right(rectangle), right(damage[index]));
            const auto y_end =
                std::max(bottom(rectangle), bottom(damage[index]));
            rectangle = { x, y, static_cast<std::uint32_t>(x_end - x),
                static_cast<std::uint32_t>(y_end - y) };
            damage.erase(damage.begin() + static_cast<std::ptrdiff_t>(index));
            index = 0;
        }
        damage.push_back(rectangle);
        // Keep command growth bounded if a pathological producer updates many
        // isolated regions in one SwapEnd. The fallback remains a conservative
        // union, not a layer-driven full-screen expansion.
        constexpr std::size_t maximum_damage_rectangles = 32;
        if (damage.size() > maximum_damage_rectangles) {
            auto merged = damage.front();
            for (std::size_t index = 1; index < damage.size(); ++index) {
                const auto x = std::min(merged.x, damage[index].x);
                const auto y = std::min(merged.y, damage[index].y);
                const auto x_end =
                    std::max(right(merged), right(damage[index]));
                const auto y_end =
                    std::max(bottom(merged), bottom(damage[index]));
                merged = { x, y, static_cast<std::uint32_t>(x_end - x),
                    static_cast<std::uint32_t>(y_end - y) };
            }
            damage.assign(1, merged);
        }
    };
    const auto propagate_source_damage =
        [&](HostRectangle source_damage, HostRectangle source_rectangle,
            HostRectangle destination_rectangle)
        -> std::optional<HostRectangle> {
        const auto affected = intersection(source_damage, source_rectangle);
        if (!affected)
            return std::nullopt;
        const auto relative_left =
            static_cast<std::uint64_t>(affected->x - source_rectangle.x);
        const auto relative_top =
            static_cast<std::uint64_t>(affected->y - source_rectangle.y);
        const auto relative_right =
            static_cast<std::uint64_t>(right(*affected) - source_rectangle.x);
        const auto relative_bottom =
            static_cast<std::uint64_t>(bottom(*affected) - source_rectangle.y);
        const auto scale_floor =
            [](std::uint64_t value, std::uint32_t destination,
                std::uint32_t source) { return value * destination / source; };
        const auto scale_ceil = [](std::uint64_t value,
                                    std::uint32_t destination,
                                    std::uint32_t source) {
            return (value * destination + source - 1U) / source;
        };
        const auto x =
            static_cast<std::int64_t>(destination_rectangle.x) +
            static_cast<std::int64_t>(scale_floor(relative_left,
                destination_rectangle.width, source_rectangle.width));
        const auto y =
            static_cast<std::int64_t>(destination_rectangle.y) +
            static_cast<std::int64_t>(scale_floor(relative_top,
                destination_rectangle.height, source_rectangle.height));
        const auto x_end =
            static_cast<std::int64_t>(destination_rectangle.x) +
            static_cast<std::int64_t>(scale_ceil(relative_right,
                destination_rectangle.width, source_rectangle.width));
        const auto y_end =
            static_cast<std::int64_t>(destination_rectangle.y) +
            static_cast<std::int64_t>(scale_ceil(relative_bottom,
                destination_rectangle.height, source_rectangle.height));
        if (x_end <= x || y_end <= y ||
            x < std::numeric_limits<std::int32_t>::min() ||
            y < std::numeric_limits<std::int32_t>::min() ||
            x > std::numeric_limits<std::int32_t>::max() ||
            y > std::numeric_limits<std::int32_t>::max()) {
            return std::nullopt;
        }
        return HostRectangle { static_cast<std::int32_t>(x),
            static_cast<std::int32_t>(y), static_cast<std::uint32_t>(x_end - x),
            static_cast<std::uint32_t>(y_end - y) };
    };
    if (!scanout_contents_valid_ ||
        submitted_background_argb_ != background_argb_) {
        add_damage(full_display);
    } else {
        for (const auto& [order, submitted] : submitted_layers_) {
            const auto current = std::find_if(prepared_layers.begin(),
                prepared_layers.end(), [order](const PreparedLayer& layer) {
                    return layer.order == order;
                });
            if (current == prepared_layers.end()) {
                if (const auto old_destination =
                        exact_rectangle(submitted.state.destination)) {
                    add_damage(*old_destination);
                }
                continue;
            }
            if (current->state != submitted.state ||
                current->source->key() != submitted.surface_key) {
                if (const auto old_destination =
                        exact_rectangle(submitted.state.destination)) {
                    add_damage(*old_destination);
                }
                add_damage(current->destination_rectangle);
            } else if (current->generation != submitted.generation) {
                const auto source_damage =
                    current->source->damage_since(submitted.generation);
                for (const auto rectangle : source_damage) {
                    if (const auto transformed = propagate_source_damage(
                            rectangle, current->source_rectangle,
                            current->destination_rectangle)) {
                        add_damage(*transformed);
                    }
                }
            }
        }
        for (const auto& current : prepared_layers) {
            if (!submitted_layers_.contains(current.order))
                add_damage(current.destination_rectangle);
        }
    }

    if (debug_submission) {
        call.output().write(
            "[mfb-debug] damage pid=" + std::to_string(call.process_id()) +
            " rects=" + std::to_string(damage.size()) +
            " submitted=" + std::to_string(submitted_layers_.size()) + "\n");
    }

    auto composition_surface = scanout_surface_;
    if (!damage.empty()) {
        composition_surface = acquire_composition_surface();
        if (!composition_surface)
            return SubmissionResult::Failed;
        const auto full_display_rectangle =
            HostRectangle { 0, 0, display_->width(), display_->height() };
        if (scanout_contents_valid_ &&
            !command_encoder_->copy(scanout_surface_, composition_surface,
                full_display_rectangle, full_display_rectangle,
                HostCompositeMode::Copy, 0xffU, HostFilter::Nearest,
                HostRotation::Identity)) {
            scanout_contents_valid_ = false;
            return SubmissionResult::Failed;
        }
        for (const auto rectangle : damage) {
            if (!command_encoder_->fill(
                    composition_surface, rectangle, background_argb_)) {
                scanout_contents_valid_ = false;
                return SubmissionResult::Failed;
            }
        }
        for (const auto& layer : prepared_layers) {
            for (const auto rectangle : damage) {
                const auto clip =
                    intersection(rectangle, layer.destination_rectangle);
                if (!clip)
                    continue;
                if (!command_encoder_->copy(layer.source, composition_surface,
                        layer.source_rectangle, layer.destination_rectangle,
                        HostCompositeMode::PremultipliedSourceOver, 0xffU,
                        HostFilter::Nearest, HostRotation::Identity, *clip)) {
                    scanout_contents_valid_ = false;
                    return SubmissionResult::Failed;
                }
            }
        }
        if (!command_encoder_->submit(PerfSubmitReason::Compositor)) {
            scanout_contents_valid_ = false;
            return SubmissionResult::Failed;
        }
        if (!defer_foreground_publication)
            scanout_surface_ = composition_surface;
    }

    if (!defer_foreground_publication) {
        submitted_layers_.clear();
        for (const auto& layer : prepared_layers) {
            submitted_layers_.emplace(
                layer.order, SubmittedLayer { layer.state, layer.source->key(),
                                 layer.generation });
        }
        submitted_background_argb_ = background_argb_;
        scanout_contents_valid_ = true;
        auto graphics = host_graphics_;
        auto scanout = scanout_surface_;
        display_->replace_surface(
            scanout,
            [graphics, scanout] {
                if (!graphics->map_cpu(
                        *scanout, true, PerfCpuMapReason::DeferredDisplayRead))
                    return std::vector<std::uint32_t> { };
                auto mapping = scanout->map_cpu(
                    false, PerfCpuMapReason::DeferredDisplayRead);
                return mapping.frame().pixels;
            },
            call.process_id(),
            [scanout] {
                return std::max(
                    scanout->cpu_generation(), scanout->gpu_generation());
            });
    }
    return defer_foreground_publication ? SubmissionResult::Deferred
                                        : SubmissionResult::Submitted;
}

void MobileFramebufferHle::set_layer(UserlandHleCall& call)
{
    const auto layer = call.argument(1);
    const auto surface = call.argument(2);
    if (layer > mobile_framebuffer_abi::maximum_layer_index) {
        call.set_return(iokit_abi::bad_argument);
        return;
    }
    if (is_external_framebuffer(call)) {
        call.set_return(iokit_abi::success);
        return;
    }
    if (surface == 0) {
        layers_.erase(layer);
        layer_surface_leases_.erase(layer);
        call.set_return(iokit_abi::success);
        return;
    }
    // CoreSurface-era firmware stores a CoreSurfaceClientBuffer here. When the
    // IOSurface symbol family is loaded, the genuine CoreSurface CFRuntime
    // wrapper forwards to an IOSurfaceClient instead. Select by that exported
    // transport capability, not by firmware build or calling application.
    const auto& transport = surface_transport::loaded_client_abi(call);
    if (surface > std::numeric_limits<std::uint32_t>::max() -
                      transport.public_client_pointer_offset) {
        call.set_return(iokit_abi::bad_argument);
        return;
    }
    const auto client =
        call.memory().read32(surface + transport.public_client_pointer_offset);
    if (!client || *client == 0 ||
        *client > std::numeric_limits<std::uint32_t>::max() -
                      transport.identifier_offset) {
        call.set_return(iokit_abi::bad_argument);
        return;
    }
    const auto identifier =
        call.memory().read32(*client + transport.identifier_offset);
    if (!identifier || *identifier == 0 || !surface_store_->find(*identifier)) {
        call.set_return(iokit_abi::bad_argument);
        return;
    }
    const auto surface_lease =
        surface_store_->acquire_transport_lease(*identifier);
    if (!surface_lease) {
        call.set_return(iokit_abi::bad_argument);
        return;
    }
    const auto float_argument = [&](std::size_t index) {
        return std::bit_cast<float>(call.argument(index));
    };
    const Rectangle source { float_argument(
                                 mobile_framebuffer_abi::source_x_argument),
        float_argument(mobile_framebuffer_abi::source_y_argument),
        float_argument(mobile_framebuffer_abi::source_width_argument),
        float_argument(mobile_framebuffer_abi::source_height_argument) };
    const Rectangle destination {
        float_argument(mobile_framebuffer_abi::destination_x_argument),
        float_argument(mobile_framebuffer_abi::destination_y_argument),
        float_argument(mobile_framebuffer_abi::destination_width_argument),
        float_argument(mobile_framebuffer_abi::destination_height_argument)
    };
    const auto valid_rectangle = [](const Rectangle& rectangle) {
        return std::isfinite(rectangle.x) && std::isfinite(rectangle.y) &&
               std::isfinite(rectangle.width) &&
               std::isfinite(rectangle.height) && rectangle.width > 0.0F &&
               rectangle.height > 0.0F;
    };
    if (!valid_rectangle(source) || !valid_rectangle(destination)) {
        call.set_return(iokit_abi::bad_argument);
        return;
    }
    layers_.insert_or_assign(
        layer, LayerState { *identifier, source, destination,
                   call.argument(mobile_framebuffer_abi::flags_argument) });
    layer_surface_leases_.insert_or_assign(layer, surface_lease);
    call.set_return(iokit_abi::success);
}

MobileFramebufferHle::SubmissionResult
MobileFramebufferHle::submit_layers(UserlandHleCall& call)
{
    if (display_ == nullptr)
        return SubmissionResult::Failed;
    const auto host_submission = submit_host_layers(call);
    if (host_submission != SubmissionResult::Failed)
        return host_submission;
    scanout_contents_valid_ = false;
    submitted_layers_.clear();
    const auto geometry = display_->geometry();
    std::vector<std::uint32_t> composed(
        geometry.pixel_count(), background_argb_);
    const auto blend_channel = [](std::uint32_t source,
                                   std::uint32_t destination,
                                   std::uint32_t inverse_alpha) {
        return std::min(
            255U, source + (destination * inverse_alpha + 127U) / 255U);
    };
    for (const auto& [layer, state] : layers_) {
        static_cast<void>(layer);
        const auto backing = surface_store_->find(state.surface_id);
        if (backing && !application_surface_allowed(
                           backing->provenance.producer_process_id,
                           backing->provenance.publication_sequence)) {
            continue;
        }
        auto effective_state = state;
        if (backing) {
            apply_application_display(effective_state,
                backing->provenance.producer_process_id, backing->width,
                backing->height);
        }
        const auto source_surface =
            surface_store_->host_surface(effective_state.surface_id);
        if (source_surface)
            source_surface->mark_scanout_presentation();
        auto source_pixels =
            surface_store_->read_argb(call.memory(), effective_state.surface_id);
        if (!backing || !source_pixels || backing->width == 0 ||
            backing->height == 0) {
            continue;
        }
        const auto clipped_edge = [](double value, std::uint32_t maximum) {
            return static_cast<int>(std::clamp(
                std::floor(value + 0.5), 0.0, static_cast<double>(maximum)));
        };
        const auto destination_left =
            clipped_edge(effective_state.destination.x, geometry.width);
        const auto destination_top =
            clipped_edge(effective_state.destination.y, geometry.height);
        const auto destination_right = clipped_edge(
            static_cast<double>(effective_state.destination.x) +
                effective_state.destination.width,
            geometry.width);
        const auto destination_bottom = clipped_edge(
            static_cast<double>(effective_state.destination.y) +
                effective_state.destination.height,
            geometry.height);
        if (destination_right <= destination_left ||
            destination_bottom <= destination_top) {
            continue;
        }
        const auto full_surface_copy =
            destination_left == 0 && destination_top == 0 &&
            destination_right == static_cast<int>(geometry.width) &&
            destination_bottom == static_cast<int>(geometry.height) &&
            effective_state.destination.x == 0.0F &&
            effective_state.destination.y == 0.0F &&
            effective_state.destination.width ==
                static_cast<float>(geometry.width) &&
            effective_state.destination.height ==
                static_cast<float>(geometry.height) &&
            effective_state.source.x == 0.0F &&
            effective_state.source.y == 0.0F &&
            effective_state.source.width == static_cast<float>(backing->width) &&
            effective_state.source.height ==
                static_cast<float>(backing->height) &&
            backing->width == geometry.width &&
            backing->height == geometry.height &&
            std::all_of(source_pixels->begin(), source_pixels->end(),
                [](std::uint32_t pixel) { return (pixel >> 24U) == 255U; });
        if (full_surface_copy) {
            composed = std::move(*source_pixels);
            continue;
        }
        std::vector<std::uint32_t> source_columns(
            static_cast<std::size_t>(destination_right - destination_left));
        for (auto x = destination_left; x < destination_right; ++x) {
            const auto horizontal =
                (static_cast<float>(x) + 0.5F - effective_state.destination.x) /
                effective_state.destination.width;
            source_columns[static_cast<std::size_t>(x - destination_left)] =
                static_cast<std::uint32_t>(
                    std::floor(std::clamp(
                        static_cast<double>(effective_state.source.x) +
                            horizontal * effective_state.source.width,
                        0.0, static_cast<double>(backing->width - 1U))));
        }
        for (auto y = destination_top; y < destination_bottom; ++y) {
            const auto vertical =
                (static_cast<float>(y) + 0.5F - effective_state.destination.y) /
                effective_state.destination.height;
            const auto source_y = static_cast<std::uint32_t>(
                std::floor(std::clamp(
                    static_cast<double>(effective_state.source.y) +
                        vertical * effective_state.source.height,
                    0.0, static_cast<double>(backing->height - 1U))));
            for (auto x = destination_left; x < destination_right; ++x) {
                const auto source_x = source_columns[static_cast<std::size_t>(
                    x - destination_left)];
                const auto source_pixel =
                    (*source_pixels)[static_cast<std::size_t>(source_y) *
                                         backing->width +
                                     static_cast<std::size_t>(source_x)];
                auto& destination_pixel =
                    composed[static_cast<std::size_t>(y) * geometry.width +
                             static_cast<std::size_t>(x)];
                const auto alpha = source_pixel >> 24U;
                if (alpha == 255U) {
                    destination_pixel = source_pixel;
                    continue;
                }
                const auto inverse_alpha = 255U - alpha;
                const auto output_alpha = blend_channel(
                    alpha, destination_pixel >> 24U, inverse_alpha);
                const auto output_red =
                    blend_channel((source_pixel >> 16U) & 0xffU,
                        (destination_pixel >> 16U) & 0xffU, inverse_alpha);
                const auto output_green =
                    blend_channel((source_pixel >> 8U) & 0xffU,
                        (destination_pixel >> 8U) & 0xffU, inverse_alpha);
                const auto output_blue = blend_channel(source_pixel & 0xffU,
                    destination_pixel & 0xffU, inverse_alpha);
                destination_pixel = (output_alpha << 24U) |
                                    (output_red << 16U) | (output_green << 8U) |
                                    output_blue;
            }
        }
    }
    display_->replace_pixels(std::move(composed), call.process_id());
    return SubmissionResult::Submitted;
}

std::optional<std::uint32_t> MobileFramebufferHle::record_presentation(
    UserlandHleCall& call)
{
    if (!presentation_tracker_)
        return std::nullopt;
    std::vector<PresentationLayer> presented_layers;
    presented_layers.reserve(layers_.size());
    for (const auto& [order, state] : layers_) {
        const auto backing = surface_store_->find(state.surface_id);
        if (!backing || !application_surface_allowed(
                            backing->provenance.producer_process_id,
                            backing->provenance.publication_sequence))
            continue;
        auto effective_state = state;
        apply_application_display(effective_state,
            backing->provenance.producer_process_id, backing->width,
            backing->height);
        const auto scale_x =
            effective_state.source.width / effective_state.destination.width;
        const auto scale_y =
            effective_state.source.height / effective_state.destination.height;
        presented_layers.push_back(PresentationLayer { order, state.surface_id,
            backing->provenance,
            PresentationRectangle { effective_state.source.x,
                effective_state.source.y, effective_state.source.width,
                effective_state.source.height },
            PresentationRectangle { effective_state.destination.x,
                effective_state.destination.y, effective_state.destination.width,
                effective_state.destination.height },
            PresentationTransform { scale_x, 0.0F, 0.0F, scale_y,
                effective_state.source.x -
                    effective_state.destination.x * scale_x,
                effective_state.source.y -
                    effective_state.destination.y * scale_y },
            effective_state.flags });
    }
    auto logical_client_scene = scene_coordinator_
                                    ? scene_coordinator_->active_client_scene()
                                    : std::nullopt;
    const auto semantic_process_id =
        logical_client_scene && !presented_layers.empty() &&
                logical_client_scene->state == ClientSceneState::Active
            ? std::optional<std::uint32_t> { logical_client_scene
                      ->client_process_id }
            : std::nullopt;
    static_cast<void>(presentation_tracker_->record(call.process_id(),
        std::move(presented_layers), std::move(logical_client_scene)));
    return semantic_process_id;
}

void MobileFramebufferHle::set_background_color(UserlandHleCall& call)
{
    if (is_external_framebuffer(call)) {
        call.set_return(iokit_abi::success);
        return;
    }
    const auto channel = [](std::uint32_t bits) {
        const auto value = std::clamp(std::bit_cast<float>(bits), 0.0F, 1.0F);
        return static_cast<std::uint32_t>(std::lround(value * 255.0F));
    };
    const auto red = channel(call.argument(1));
    const auto green = channel(call.argument(2));
    const auto blue = channel(call.argument(3));
    const auto alpha = channel(call.argument(4));
    background_argb_ = (alpha << 24U) | (red << 16U) | (green << 8U) | blue;
    // This updates the pending swap transaction.  Publishing the clear here
    // exposes an incomplete frame when SpringBoard sets the background before
    // its layers and SwapEnd, notably during Lock/wake handoff.
    call.set_return(iokit_abi::success);
}

} // namespace shade
