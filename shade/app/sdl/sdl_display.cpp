// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Present guest frames in an SDL window and coordinate native
// presentation.

#include "app/sdl_display.hpp"

#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <deque>
#include <exception>
#include <limits>
#include <mutex>
#include <optional>
#include <stdexcept>
#include <string>
#include <string_view>
#include <thread>
#include <utility>
#include <vector>

#include "foundation/application_display.hpp"
#include "graphics/display.hpp"
#include "graphics/gles_renderer.hpp"
#include "foundation/performance.hpp"
#include "sdl_input.hpp"

#if defined(SHADE_HAS_SDL2)
#include <SDL.h>
#if defined(SHADE_HAS_VULKAN)
#include <SDL_vulkan.h>
#endif
#endif

namespace shade {
namespace {

#if defined(SHADE_HAS_SDL2)
    // sdl2-compat defaults to emulating X11's non-DPI-aware behavior on
    // Wayland. Opt into logical window coordinates backed by the compositor's
    // full pixel density. Classic SDL2 and non-Wayland backends safely retain
    // this unknown/backend-specific hint without changing their behavior.
    constexpr auto sdl_wayland_scale_to_display_hint =
        "SDL_VIDEO_WAYLAND_SCALE_TO_DISPLAY";

    void configure_sdl_dpi_awareness()
    {
        SDL_SetHintWithPriority(sdl_wayland_scale_to_display_hint, "0",
            SDL_HINT_OVERRIDE);
    }

    DisplayGeometry configure_renderer_coordinates(SDL_Renderer* renderer)
    {
        int width { };
        int height { };
        if (SDL_GetRendererOutputSize(renderer, &width, &height) != 0) {
            throw std::runtime_error { "SDL renderer output query failed: " +
                                       std::string { SDL_GetError() } };
        }
        int logical_width { };
        int logical_height { };
        SDL_RenderGetLogicalSize(renderer, &logical_width, &logical_height);
        // Explicit logical coordinates make SDL2 and sdl2-compat transform
        // mouse events consistently. Keep drawing in output pixels, with our
        // own aspect-fit viewport, including after a resize or DPI change.
        if (width > 0 && height > 0 &&
            (logical_width != width || logical_height != height) &&
            SDL_RenderSetLogicalSize(renderer, width, height) != 0) {
            throw std::runtime_error { "SDL renderer logical size failed: " +
                                       std::string { SDL_GetError() } };
        }
        return { static_cast<std::uint32_t>(std::max(width, 0)),
            static_cast<std::uint32_t>(std::max(height, 0)) };
    }
#endif

    // Guest owners and firmware surface identifiers are narrower than the host
    // surface key. Reserve this owner for frames synthesized by the SDL
    // presenter itself, such as the black panel emitted while display power is
    // off.
    constexpr auto sdl_presenter_surface_owner =
        std::numeric_limits<std::uint64_t>::max();
    std::atomic<std::uint64_t> next_sdl_presenter_surface { 1 };
    constexpr std::size_t presentation_queue_capacity = 8;
    constexpr std::size_t presentation_queue_lease_capacity =
        presentation_queue_capacity + 1;
    // Keep one extra surface slot for the repaint copy retained by
    // last_presented_frame. Frame admission has the eight-slot ordered queue
    // plus one bounded latest-only overflow slot below; it never grows with a
    // burst.
    constexpr std::size_t presentation_surface_capacity =
        presentation_queue_lease_capacity;
    constexpr auto presentation_flush_timeout = std::chrono::seconds { 5 };

} // namespace

struct SdlDisplay::Impl {
    struct PresentationSurfaceSlot {
        HostSurfaceKey key { };
        std::shared_ptr<HostSurface> surface;
        bool in_use { };
        bool held_by_last { };
    };

    struct CpuPresentationFrame {
        DisplayFrame frame;
        bool queued { };
        bool native_failed { };
        bool repainting { };
    };

    Impl(DisplayGeometry initial_geometry, DisplayGeometry input_geometry)
        : geometry { initial_geometry }
        , guest_geometry { initial_geometry }
        , input_geometry { input_geometry }
        , host_geometry { input_geometry }
        , input { input_geometry }
    {
        input.set_display_geometry(geometry);
        for (auto& slot : cpu_present_surfaces)
            slot.key = { sdl_presenter_surface_owner,
                next_sdl_presenter_surface.fetch_add(
                    1, std::memory_order_relaxed) };
        for (auto& slot : oriented_present_surfaces)
            slot.key = { sdl_presenter_surface_owner,
                next_sdl_presenter_surface.fetch_add(
                    1, std::memory_order_relaxed) };
    }

    DisplayGeometry geometry;
    DisplayGeometry guest_geometry;
    // The SDL toplevel follows the logical UI size. The guest scanout and
    // texture remain native-sized, allowing a Retina panel to render at 2x
    // while presenting at its logical half-size.
    DisplayGeometry input_geometry;
    DisplayGeometry host_geometry;
    DisplayOrientation orientation { DisplayOrientation::Portrait };
#if defined(SHADE_HAS_SDL2)
    SDL_Window* window { };
    SDL_Renderer* renderer { };
    SDL_Texture* texture { };
    SDL_Window* retired_window { };
    // SDL's X11 backend and the Vulkan/XCB stack share the host display
    // connection. Keep the scheduler's event pump and the CPU presenter from
    // allocating X11 resources concurrently.
    std::recursive_mutex sdl_mutex;
    bool vulkan_library_loaded { };
    bool vulkan_window { };
    std::atomic<bool> surface_created { };

    [[nodiscard]] static Uint32 window_flags(bool vulkan)
    {
        return SDL_WINDOW_RESIZABLE | SDL_WINDOW_ALLOW_HIGHDPI |
               (vulkan ? static_cast<Uint32>(SDL_WINDOW_VULKAN) : 0U);
    }

    [[nodiscard]] SDL_Window* create_window(bool vulkan) const
    {
        return SDL_CreateWindow("Shade", SDL_WINDOWPOS_CENTERED,
            SDL_WINDOWPOS_CENTERED, static_cast<int>(host_geometry.width),
            static_cast<int>(host_geometry.height), window_flags(vulkan));
    }

    [[nodiscard]] static SDL_Renderer* create_renderer(SDL_Window* target)
    {
        // SDL applies this hint when a texture is created. Linear filtering
        // removes nearest-neighbour stair stepping while retaining the host
        // renderer's accelerated path and software fallback.
        SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "1");
        auto* result = SDL_CreateRenderer(target, -1, SDL_RENDERER_ACCELERATED);
        if (result == nullptr)
            result = SDL_CreateRenderer(target, -1, SDL_RENDERER_SOFTWARE);
        if (result != nullptr) {
            try {
                static_cast<void>(configure_renderer_coordinates(result));
            } catch (...) {
                SDL_DestroyRenderer(result);
                throw;
            }
        }
        return result;
    }

    void ensure_cpu_window()
    {
        std::lock_guard lock { sdl_mutex };
        if (window != nullptr && !vulkan_window)
            return;
        auto* replacement = create_window(false);
        if (replacement == nullptr)
            return;
        auto* previous = window;
        window = replacement;
        vulkan_window = false;
        surface_created = false;
        if (previous != nullptr)
            SDL_DestroyWindow(previous);
    }

    void ensure_cpu_presenter()
    {
        std::lock_guard lock { sdl_mutex };
        if (renderer == nullptr) {
            // SDL renderers are thread-affine. The CPU presenter calls this
            // method from its worker, so create the renderer and texture there
            // rather than in the scheduler thread that owns the SDL event pump.
            if (window == nullptr || vulkan_window)
                ensure_cpu_window();
            renderer = create_renderer(window);
        }
        if (renderer == nullptr) {
            throw std::runtime_error { "SDL renderer creation failed: " +
                                       std::string { SDL_GetError() } };
        }
        if (texture != nullptr)
            return;
        texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888,
            SDL_TEXTUREACCESS_STREAMING, static_cast<int>(geometry.width),
            static_cast<int>(geometry.height));
        if (texture == nullptr) {
            throw std::runtime_error { "SDL texture creation failed: " +
                                       std::string { SDL_GetError() } };
        }
#if SDL_VERSION_ATLEAST(2, 0, 12)
        if (SDL_SetTextureScaleMode(texture, SDL_ScaleModeLinear) != 0) {
            throw std::runtime_error { "SDL texture scale mode failed: " +
                                       std::string { SDL_GetError() } };
        }
#endif
        if (SDL_SetTextureBlendMode(texture, SDL_BLENDMODE_NONE) != 0) {
            throw std::runtime_error { "SDL texture blend mode failed: " +
                                       std::string { SDL_GetError() } };
        }
    }

    // Wayland configures a toplevel's size asynchronously and does not
    // generally honor SDL_SetWindowSize after the initial configure. An
    // orientation change therefore needs a fresh toplevel so its initial
    // request carries the new aspect ratio. The native presenter is rebound by
    // the caller while the previous toplevel is still alive.
    bool recreate_wayland_window()
    {
        std::lock_guard lock { sdl_mutex };
        if (window == nullptr ||
            std::string_view { SDL_GetCurrentVideoDriver() != nullptr
                                   ? SDL_GetCurrentVideoDriver()
                                   : "" } != "wayland") {
            return false;
        }
        if (retired_window != nullptr) {
            SDL_DestroyWindow(retired_window);
            retired_window = nullptr;
        }
        auto* replacement = create_window(vulkan_window);
        if (replacement == nullptr)
            return false;

        SDL_Renderer* replacement_renderer = nullptr;
        if (!vulkan_window) {
            replacement_renderer = create_renderer(replacement);
            if (replacement_renderer == nullptr) {
                SDL_DestroyWindow(replacement);
                return false;
            }
        }

        auto* old_window = window;
        if (texture != nullptr)
            SDL_DestroyTexture(texture);
        if (renderer != nullptr)
            SDL_DestroyRenderer(renderer);
        window = replacement;
        renderer = replacement_renderer;
        texture = nullptr;
        surface_created = false;
        // Keep the old toplevel alive until the Vulkan backend has released its
        // surface. Wayland display queues may still contain protocol work for
        // the previous surface while the guest orientation transition is
        // handled.
        retired_window = old_window;
        if (!vulkan_window)
            ensure_cpu_presenter();
        return true;
    }

    void destroy_retired_window()
    {
        std::lock_guard lock { sdl_mutex };
        if (retired_window != nullptr) {
            SDL_DestroyWindow(retired_window);
            retired_window = nullptr;
        }
    }
#endif
    std::mutex frame_mutex;
    std::condition_variable presentation_available;
    std::condition_variable presentation_space_available;
    std::condition_variable presentation_idle;
    std::condition_variable cpu_presentation_available;
    std::condition_variable cpu_presentation_idle;
    // Preserve ordered submissions until the SDL thread presents them while
    // the queue has room. If a producer burst outruns event-loop pumping, the
    // bounded admission policy below replaces the oldest pending frame and
    // records that loss as display-mailbox coalescing.
    std::deque<DisplayFrame> pending_frames;
    // Admission must not park the guest execution thread behind a slow window
    // compositor. When all regular queue slots are occupied, retain one latest
    // frame behind the ordered queue. Replacing this slot is an explicit,
    // counted coalescing event; normal 60 Hz operation never uses it.
    std::optional<DisplayFrame> overflow_frame;
    // Keep native submissions ordered as well. Frames are staged on this
    // worker before acquire/present; a skipped/failed native attempt moves to
    // the software fallback queue instead of disappearing.
    std::deque<DisplayFrame> pending_native_frames;
    std::deque<DisplayFrame> native_fallback_frames;
    bool native_fallback_active { };
    std::deque<CpuPresentationFrame> pending_cpu_frames;
    // SDL windows can lose their compositor back buffer while hidden or
    // covered. Retain the last host-ready frame so an expose/restore event can
    // repaint without waiting for the guest to submit another frame.
    std::optional<DisplayFrame> last_presented_frame;
    std::shared_ptr<HostGraphicsDevice> host_graphics;
    std::array<PresentationSurfaceSlot, presentation_surface_capacity>
        cpu_present_surfaces;
    std::array<PresentationSurfaceSlot, presentation_surface_capacity>
        oriented_present_surfaces;
    std::unique_ptr<CommandEncoder> orientation_encoder;
    std::thread presentation_thread;
    std::thread cpu_presentation_thread;
    std::atomic<std::uint64_t> presented_frames { };
    std::size_t queued_frame_count { };
    bool presentation_stopping { };
    bool presentation_failed { };
    bool presentation_active { };
    bool cpu_presentation_stopping { };
    bool cpu_presentation_active { };
    std::exception_ptr cpu_presentation_error;
    SdlInput input;
    bool running { true };

    template <std::size_t N>
    static void set_surface_in_use_locked(
        std::array<PresentationSurfaceSlot, N>& slots,
        const std::shared_ptr<HostSurface>& surface, bool in_use)
    {
        if (!surface)
            return;
        for (auto& slot : slots) {
            if (slot.surface == surface) {
                slot.in_use = in_use;
                return;
            }
        }
    }

    template <std::size_t N>
    static void set_surface_held_locked(
        std::array<PresentationSurfaceSlot, N>& slots,
        const std::shared_ptr<HostSurface>& surface, bool held)
    {
        if (!surface)
            return;
        for (auto& slot : slots) {
            if (slot.surface == surface) {
                slot.held_by_last = held;
                return;
            }
        }
    }

    void set_frame_surface_in_use_locked(const DisplayFrame& frame, bool in_use)
    {
        set_surface_in_use_locked(
            cpu_present_surfaces, frame.host_surface, in_use);
        set_surface_in_use_locked(
            cpu_present_surfaces, frame.presentation_staging_surface, in_use);
        set_surface_in_use_locked(
            oriented_present_surfaces, frame.host_surface, in_use);
        set_surface_in_use_locked(oriented_present_surfaces,
            frame.presentation_staging_surface, in_use);
    }

    void set_frame_surface_held_locked(const DisplayFrame& frame, bool held)
    {
        set_surface_held_locked(cpu_present_surfaces, frame.host_surface, held);
        set_surface_held_locked(
            cpu_present_surfaces, frame.presentation_staging_surface, held);
        set_surface_held_locked(
            oriented_present_surfaces, frame.host_surface, held);
        set_surface_held_locked(oriented_present_surfaces,
            frame.presentation_staging_surface, held);
    }

    void set_last_presented_frame_locked(DisplayFrame frame)
    {
        if (last_presented_frame)
            set_frame_surface_held_locked(*last_presented_frame, false);
        last_presented_frame = std::move(frame);
        set_frame_surface_held_locked(*last_presented_frame, true);
    }

    void release_frame_surface_in_use_locked(const DisplayFrame& frame)
    {
        set_frame_surface_in_use_locked(frame, false);
    }

    void reset_presentation_surface_pool_locked()
    {
        for (auto& slot : cpu_present_surfaces) {
            slot.in_use = false;
            slot.held_by_last = false;
            slot.surface.reset();
        }
        for (auto& slot : oriented_present_surfaces) {
            slot.in_use = false;
            slot.held_by_last = false;
            slot.surface.reset();
        }
    }

    void release_queued_frame(const DisplayFrame* frame = nullptr)
    {
        std::uint64_t depth { };
        {
            std::lock_guard lock { frame_mutex };
            if (frame != nullptr)
                release_frame_surface_in_use_locked(*frame);
            if (queued_frame_count == 0)
                return;
            --queued_frame_count;
            depth = queued_frame_count;
        }
        presentation_space_available.notify_all();
        presentation_idle.notify_all();
        performance_counters().record_display_queue_depth(depth);
    }

    void fail_presentation_locked()
    {
        presentation_failed = true;
        presentation_stopping = true;
        cpu_presentation_stopping = true;
        running = false;
        presentation_available.notify_all();
        cpu_presentation_available.notify_all();
    }

    void abandon_queued_frames_locked()
    {
        pending_frames.clear();
        overflow_frame.reset();
        pending_native_frames.clear();
        native_fallback_frames.clear();
        native_fallback_active = false;
        pending_cpu_frames.clear();
        queued_frame_count = 0;
        if (last_presented_frame)
            set_frame_surface_held_locked(*last_presented_frame, false);
        last_presented_frame.reset();
        reset_presentation_surface_pool_locked();
    }

    void update_orientation(DisplayOrientation next_orientation)
    {
        if (orientation == next_orientation)
            return;
#if defined(SHADE_HAS_SDL2)
        if (!flush_cpu_presenter())
            return;
#endif
        orientation = next_orientation;
        geometry = is_landscape(orientation)
                       ? DisplayGeometry { guest_geometry.height,
                             guest_geometry.width }
                       : guest_geometry;
        host_geometry = is_landscape(orientation)
                            ? DisplayGeometry { input_geometry.height,
                                  input_geometry.width }
                            : input_geometry;
        input.set_display_geometry(geometry);
        input.set_orientation(orientation);
#if defined(SHADE_HAS_SDL2)
        if (window != nullptr) {
            const auto native_presentation =
                host_graphics && host_graphics->native_presentation_available();
            if (native_presentation)
                stop_native_presenter();
            if (recreate_wayland_window()) {
                if (native_presentation) {
                    static_cast<void>(
                        host_graphics->refresh_presentation_surface());
                    start_native_presenter();
                }
                destroy_retired_window();
            } else {
                {
                    std::lock_guard lock { sdl_mutex };
                    SDL_SetWindowSize(window,
                        static_cast<int>(host_geometry.width),
                        static_cast<int>(host_geometry.height));
                }
                if (native_presentation)
                    start_native_presenter();
            }
        }
        if (texture != nullptr) {
            std::lock_guard lock { sdl_mutex };
            SDL_DestroyTexture(texture);
            texture = nullptr;
        }
#endif
    }

    bool stage_cpu_frame_for_native_present(DisplayFrame& frame)
    {
        if (frame.host_surface || !host_graphics ||
            !host_graphics->native_presentation_available()) {
            return frame.host_surface != nullptr;
        }
        const auto expected =
            static_cast<std::size_t>(frame.width) * frame.height;
        if (frame.pixels.size() != expected && frame.read_pixels)
            frame.pixels = frame.read_pixels();
        if (frame.pixels.size() != expected)
            return false;
        const auto descriptor =
            HostSurfaceDescriptor { frame.width, frame.height,
                frame.width * static_cast<std::uint32_t>(sizeof(std::uint32_t)),
                0U, PerfSurfaceKind::Scanout };
        auto graphics = host_graphics;
        std::size_t slot_index { };
        std::shared_ptr<HostSurface> reusable_surface;
        HostSurfaceKey slot_key { };
        {
            std::lock_guard lock { frame_mutex };
            bool found_slot { };
            for (std::size_t index = 0; index < cpu_present_surfaces.size();
                ++index) {
                auto& candidate = cpu_present_surfaces[index];
                if (!candidate.in_use && !candidate.held_by_last) {
                    slot_index = index;
                    slot_key = candidate.key;
                    reusable_surface = candidate.surface;
                    candidate.in_use = true;
                    found_slot = true;
                    break;
                }
            }
            if (!found_slot)
                return false;
        }

        std::shared_ptr<HostSurface> staged_surface;
        try {
            if (!reusable_surface ||
                reusable_surface->descriptor().width != descriptor.width ||
                reusable_surface->descriptor().height != descriptor.height ||
                reusable_surface->descriptor().bytes_per_row !=
                    descriptor.bytes_per_row) {
                staged_surface = graphics->create_surface(
                    slot_key, descriptor, frame.pixels);
            } else {
                reusable_surface->replace_cpu(frame.pixels);
                staged_surface = reusable_surface;
            }
        } catch (...) {
            std::lock_guard lock { frame_mutex };
            cpu_present_surfaces[slot_index].in_use = false;
            throw;
        }

        {
            std::lock_guard lock { frame_mutex };
            auto& slot = cpu_present_surfaces[slot_index];
            slot.surface = staged_surface;
            if (slot.surface == nullptr) {
                slot.in_use = false;
                return false;
            }
            staged_surface = slot.surface;
        }
        frame.host_surface = staged_surface;
        frame.presentation_staging_surface = staged_surface;
        frame.presentation_lease =
            make_host_surface_presentation_lease(staged_surface);
        frame.presentation_staging_lease = frame.presentation_lease;
        return frame.host_surface != nullptr;
    }

    bool stage_oriented_frame_for_native_present(
        DisplayFrame& frame, DisplayOrientation requested_orientation)
    {
        if (!frame.host_surface || !host_graphics || !orientation_encoder ||
            !host_graphics->native_presentation_available() ||
            requested_orientation == DisplayOrientation::Portrait) {
            return false;
        }
        const auto source = frame.host_surface;
        const auto source_descriptor = source->descriptor();
        if (source_descriptor.width != frame.width ||
            source_descriptor.height != frame.height) {
            return false;
        }
        const auto output_geometry =
            is_landscape(requested_orientation)
                ? DisplayGeometry { frame.height, frame.width }
                : DisplayGeometry { frame.width, frame.height };
        const auto descriptor = HostSurfaceDescriptor { output_geometry.width,
            output_geometry.height,
            output_geometry.width *
                static_cast<std::uint32_t>(sizeof(std::uint32_t)),
            source_descriptor.pixel_format, PerfSurfaceKind::Scanout };
        std::size_t slot_index { };
        HostSurfaceKey slot_key { };
        std::shared_ptr<HostSurface> oriented_surface;
        {
            std::lock_guard lock { frame_mutex };
            PresentationSurfaceSlot* slot { };
            for (std::size_t index = 0;
                index < oriented_present_surfaces.size(); ++index) {
                auto& candidate = oriented_present_surfaces[index];
                if (!candidate.in_use && !candidate.held_by_last) {
                    slot_index = index;
                    slot_key = candidate.key;
                    slot = &candidate;
                    break;
                }
            }
            if (slot == nullptr)
                return false;
            slot->in_use = true;
            oriented_surface = slot->surface;
        }

        const auto surface_matches =
            oriented_surface &&
            oriented_surface->descriptor().width == descriptor.width &&
            oriented_surface->descriptor().height == descriptor.height &&
            oriented_surface->descriptor().bytes_per_row ==
                descriptor.bytes_per_row &&
            oriented_surface->descriptor().pixel_format ==
                descriptor.pixel_format;
        if (!surface_matches) {
            try {
                oriented_surface =
                    host_graphics->create_surface(slot_key, descriptor);
            } catch (...) {
                std::lock_guard lock { frame_mutex };
                oriented_present_surfaces[slot_index].in_use = false;
                throw;
            }
        }
        {
            std::lock_guard lock { frame_mutex };
            auto& slot = oriented_present_surfaces[slot_index];
            if (!slot.in_use) {
                return false;
            }
            slot.surface = oriented_surface;
            if (slot.surface == nullptr) {
                slot.in_use = false;
                return false;
            }
            oriented_surface = slot.surface;
        }

        if (!oriented_surface) {
            return false;
        }

        const auto source_width = static_cast<float>(frame.width);
        const auto source_height = static_cast<float>(frame.height);
        const auto output_width = static_cast<float>(output_geometry.width);
        const auto output_height = static_cast<float>(output_geometry.height);
        std::array<HostPoint, 4> texture_coordinates { };
        switch (requested_orientation) {
        case DisplayOrientation::Portrait:
            return false;
        case DisplayOrientation::PortraitUpsideDown:
            texture_coordinates = { { { source_width, source_height },
                { 0.0F, source_height }, { 0.0F, 0.0F },
                { source_width, 0.0F } } };
            break;
        case DisplayOrientation::LandscapeLeft:
            texture_coordinates = { { { 0.0F, 0.0F }, { 0.0F, source_height },
                { source_width, source_height }, { source_width, 0.0F } } };
            break;
        case DisplayOrientation::LandscapeRight:
            texture_coordinates = { { { source_width, source_height },
                { source_width, 0.0F }, { 0.0F, 0.0F },
                { 0.0F, source_height } } };
            break;
        }
        const std::array<HostPoint, 4> positions { {
            { 0.0F, 0.0F },
            { output_width, 0.0F },
            { output_width, output_height },
            { 0.0F, output_height },
        } };
        std::array<HostTexturedVertex, 4> quad { };
        for (std::size_t index = 0; index < quad.size(); ++index)
            quad[index] = { positions[index], texture_coordinates[index] };
        const auto source_rectangle =
            HostRectangle { 0, 0, frame.width, frame.height };
        const auto destination_rectangle = HostRectangle { 0, 0,
            output_geometry.width, output_geometry.height };
        if (!orientation_encoder->copy_quad(source, oriented_surface, quad,
                source_rectangle, destination_rectangle,
                HostCompositeMode::Copy, 0xffU, HostFilter::Nearest) ||
            !orientation_encoder->submit(PerfSubmitReason::Presentation)) {
            std::lock_guard lock { frame_mutex };
            set_surface_in_use_locked(
                oriented_present_surfaces, oriented_surface, false);
            return false;
        }

        auto graphics = host_graphics;
        auto oriented = oriented_surface;
        frame.presentation_staging_surface = source;
        frame.presentation_staging_lease = frame.presentation_lease;
        frame.width = output_geometry.width;
        frame.height = output_geometry.height;
        frame.pixels.clear();
        frame.host_surface = oriented;
        frame.presentation_lease =
            make_host_surface_presentation_lease(oriented);
        frame.read_pixels = [graphics = std::move(graphics),
                                oriented = std::move(oriented)] {
            if (!graphics->map_cpu(
                    *oriented, true, PerfCpuMapReason::DeferredDisplayRead)) {
                return std::vector<std::uint32_t> { };
            }
            auto mapping =
                oriented->map_cpu(false, PerfCpuMapReason::DeferredDisplayRead);
            return mapping.frame().pixels;
        };
        frame.orientation = DisplayOrientation::Portrait;
        return true;
    }

    // Native staging can allocate/replace a scanout surface and can perform a
    // CPU rotation when a Guest frame has no host surface. Keep both operations
    // on the native presenter worker; poll_events() remains an input and queue
    // pump on the Guest scheduler thread.
    bool prepare_native_frame(DisplayFrame& frame)
    {
        const auto requested_orientation = frame.orientation;
        if (requested_orientation != DisplayOrientation::Portrait) {
            if (frame.host_surface) {
                if (!stage_oriented_frame_for_native_present(
                        frame, requested_orientation)) {
                    return false;
                }
            } else {
                const auto raw_geometry =
                    DisplayGeometry { frame.width, frame.height };
                const auto expected = raw_geometry.pixel_count();
                if (frame.pixels.size() != expected && frame.read_pixels)
                    frame.pixels = frame.read_pixels();
                const auto oriented = orient_display_pixels(
                    raw_geometry, frame.pixels, requested_orientation);
                if (oriented.empty())
                    return false;
                frame.pixels = oriented;
                if (is_landscape(requested_orientation))
                    std::swap(frame.width, frame.height);
                frame.orientation = DisplayOrientation::Portrait;
            }
        }
        return stage_cpu_frame_for_native_present(frame);
    }

#if defined(SHADE_HAS_SDL2)
    bool present_cpu_frame(DisplayFrame& frame)
    {
        auto& performance = performance_counters();
        const auto telemetry_enabled = performance.enabled();
        if (frame.host_surface) {
            if (const auto gles_renderer =
                    std::dynamic_pointer_cast<GlesRenderer>(host_graphics)) {
                performance.record_fallback(gles_renderer->failure_reason());
            }
        }
        const auto expected =
            static_cast<std::size_t>(frame.width) * frame.height;
        if (frame.pixels.size() != expected && frame.read_pixels)
            frame.pixels = frame.read_pixels();
        if (frame.pixels.size() != expected)
            return false;

        std::lock_guard lock { sdl_mutex };
        ensure_cpu_presenter();
        if (telemetry_enabled)
            performance.record_diagnostic_frame_content(frame.sequence,
                frame.owner_process_id, frame.submitted_at, frame.width,
                frame.height, frame.pixels);
        if (SDL_UpdateTexture(texture, nullptr, frame.pixels.data(),
                static_cast<int>(frame.width * sizeof(std::uint32_t))) != 0) {
            throw std::runtime_error { "SDL texture upload failed: " +
                                       std::string { SDL_GetError() } };
        }
        const auto viewport =
            fit_display_viewport({ frame.width, frame.height },
                configure_renderer_coordinates(renderer));
        const SDL_Rect destination { viewport.x, viewport.y,
            static_cast<int>(viewport.width),
            static_cast<int>(viewport.height) };
        SDL_SetRenderDrawColor(renderer, 0U, 0U, 0U, 255U);
        SDL_RenderClear(renderer);
        SDL_RenderCopy(renderer, texture, nullptr, &destination);
        SDL_RenderPresent(renderer);
        return true;
    }

    bool queue_cpu_frame(
        DisplayFrame frame, bool queued, bool native_failed, bool repainting)
    {
        {
            std::lock_guard lock { frame_mutex };
            if (cpu_presentation_stopping || presentation_failed || !running) {
                if (queued) {
                    release_frame_surface_in_use_locked(frame);
                    if (queued_frame_count != 0)
                        --queued_frame_count;
                }
                return false;
            }
            if (repainting) {
                // Repaint requests carry no Guest queue lease. Keep at most one
                // pending repaint so window expose storms cannot create an
                // unbounded software-present backlog behind a slow compositor.
                for (auto iterator = pending_cpu_frames.rbegin();
                    iterator != pending_cpu_frames.rend(); ++iterator) {
                    if (iterator->repainting) {
                        iterator->frame = std::move(frame);
                        return true;
                    }
                }
            }
            pending_cpu_frames.push_back(CpuPresentationFrame {
                std::move(frame), queued, native_failed, repainting });
        }
        cpu_presentation_available.notify_one();
        return true;
    }

    void start_cpu_presenter()
    {
        if (cpu_presentation_thread.joinable() || presentation_failed ||
            !running)
            return;
        cpu_presentation_stopping = false;
        cpu_presentation_error = { };
        cpu_presentation_thread = std::thread([this] {
            std::unique_lock lock { frame_mutex };
            while (true) {
                cpu_presentation_available.wait(lock, [this] {
                    return cpu_presentation_stopping ||
                           !pending_cpu_frames.empty();
                });
                if (cpu_presentation_stopping)
                    return;
                auto pending = std::move(pending_cpu_frames.front());
                pending_cpu_frames.pop_front();
                cpu_presentation_active = true;
                lock.unlock();
                bool presented { };
                std::exception_ptr error;
                try {
                    presented = present_cpu_frame(pending.frame);
                } catch (...) {
                    error = std::current_exception();
                }
                lock.lock();
                cpu_presentation_active = false;
                std::uint64_t depth { };
                const auto frame_sequence = pending.frame.sequence;
                const auto frame_submitted_at = pending.frame.submitted_at;
                if (pending.queued) {
                    release_frame_surface_in_use_locked(pending.frame);
                    if (queued_frame_count != 0) {
                        --queued_frame_count;
                        depth = queued_frame_count;
                    }
                }
                if (presented) {
                    // The queued frame is no longer needed after a successful
                    // CPU present. Move it into the repaint cache instead of
                    // copying its pixel vector while holding frame_mutex; Guest
                    // admission can then continue independently of this
                    // bookkeeping.
                    set_last_presented_frame_locked(std::move(pending.frame));
                    presented_frames.fetch_add(1, std::memory_order_release);
                    performance_counters().record_cpu_present_fallback(
                        frame_sequence, frame_submitted_at);
                } else {
                    if (error)
                        cpu_presentation_error = error;
                    else {
                        cpu_presentation_error =
                            std::make_exception_ptr(std::runtime_error {
                                "SDL CPU presentation failed" });
                    }
                    fail_presentation_locked();
                }
                if (pending.native_failed)
                    native_fallback_active = false;
                cpu_presentation_idle.notify_all();
                if (depth != 0 || queued_frame_count == 0)
                    presentation_space_available.notify_all();
                presentation_available.notify_all();
            }
        });
    }

    bool flush_cpu_presenter()
    {
        std::unique_lock lock { frame_mutex };
        if (!cpu_presentation_thread.joinable())
            return true;
        if (cpu_presentation_idle.wait_until(lock,
                std::chrono::steady_clock::now() + presentation_flush_timeout,
                [this] {
                    return pending_cpu_frames.empty() &&
                           !cpu_presentation_active;
                })) {
            return !cpu_presentation_error && !presentation_failed;
        }
        fail_presentation_locked();
        return false;
    }

    void stop_cpu_presenter()
    {
        if (!cpu_presentation_thread.joinable())
            return;
        {
            std::lock_guard lock { frame_mutex };
            cpu_presentation_stopping = true;
        }
        cpu_presentation_available.notify_all();
        cpu_presentation_thread.join();
        {
            std::lock_guard lock { frame_mutex };
            cpu_presentation_stopping = false;
            cpu_presentation_active = false;
        }
    }
#endif

    HostGraphicsDevice::PresentResult present_native_frame(
        const std::shared_ptr<HostGraphicsDevice>& graphics,
        const DisplayFrame& frame)
    {
        const auto deadline =
            std::chrono::steady_clock::now() + presentation_flush_timeout;
        auto& performance = performance_counters();
        while (true) {
            performance.record_native_present_attempt();
            const auto result = graphics->present(frame.host_surface);
            if (result != HostGraphicsDevice::PresentResult::Skipped)
                return result;
            performance.record_native_present_skipped();
            // A busy swapchain retains this frame and its surface lease.
            // Retry on the presenter worker without blocking input or letting
            // a later frame overtake it.
            std::unique_lock lock { frame_mutex };
            if (presentation_available.wait_for(lock,
                    std::chrono::milliseconds { 1 }, [this] {
                        return presentation_stopping || !running ||
                               presentation_failed;
                    }) ||
                std::chrono::steady_clock::now() >= deadline) {
                return HostGraphicsDevice::PresentResult::Failed;
            }
        }
    }

    void start_native_presenter()
    {
        if (presentation_thread.joinable() || presentation_failed || !running)
            return;
        presentation_stopping = false;
        presentation_thread = std::thread([this] {
            std::unique_lock lock { frame_mutex };
            while (true) {
                presentation_available.wait(lock, [this] {
                    return presentation_stopping ||
                           (!pending_native_frames.empty() &&
                               native_fallback_frames.empty() &&
                               !native_fallback_active);
                });
                if (presentation_stopping)
                    return;
                auto frame = std::move(pending_native_frames.front());
                pending_native_frames.pop_front();
                presentation_active = true;
                auto graphics = host_graphics;
                lock.unlock();
                auto& performance = performance_counters();
                const auto telemetry_enabled = performance.enabled();
                const auto native_dequeued_at =
                    telemetry_enabled
                        ? std::chrono::steady_clock::now()
                        : std::chrono::steady_clock::time_point { };
                if (telemetry_enabled) {
                    performance.record_diagnostic_native_dequeue(
                        frame.sequence, native_dequeued_at);
                }
                if (telemetry_enabled &&
                    frame.native_queued_at !=
                        std::chrono::steady_clock::time_point { }) {
                    const auto residence =
                        native_dequeued_at - frame.native_queued_at;
                    performance.record_latency(PerfLatencyKind::NativeMailbox,
                        static_cast<std::uint64_t>(std::chrono::duration_cast<
                            std::chrono::nanoseconds>(residence)
                                .count()));
                }
                bool prepared { };
                try {
                    prepared = prepare_native_frame(frame);
                } catch (...) {
                    // Native staging failures retain the original frame for the
                    // ordered SDL fallback below. The existing fallback path
                    // owns the error boundary and preserves sequence order.
                    prepared = false;
                }
                if (prepared) {
                    // The repaint cache is published only after a host-ready
                    // surface exists. Its potentially large pixel vector is
                    // copied on this worker, never on the Guest scheduler
                    // thread.
                    auto worker_last_presented_frame = frame;
                    lock.lock();
                    set_last_presented_frame_locked(
                        std::move(worker_last_presented_frame));
                    lock.unlock();
                }
                const auto result =
                    prepared && graphics && frame.host_surface
                        ? present_native_frame(graphics, frame)
                        : HostGraphicsDevice::PresentResult::Failed;
                if (result == HostGraphicsDevice::PresentResult::Queued) {
                    presented_frames.fetch_add(1, std::memory_order_release);
                    performance.record_native_present(
                        frame.sequence, frame.submitted_at);
                } else {
                    performance.record_native_present_failure();
                }
                std::uint64_t released_depth { };
                lock.lock();
                presentation_active = false;
                if (result == HostGraphicsDevice::PresentResult::Queued) {
                    release_frame_surface_in_use_locked(frame);
                    if (queued_frame_count != 0) {
                        --queued_frame_count;
                        released_depth = queued_frame_count;
                    }
                } else {
                    native_fallback_frames.push_back(std::move(frame));
                    // A failed native frame is an ordering barrier. Present
                    // every frame already behind it through SDL as well, so a
                    // newer native frame cannot become visible before the
                    // failed frame is recovered.
                    while (!pending_native_frames.empty()) {
                        native_fallback_frames.push_back(
                            std::move(pending_native_frames.front()));
                        pending_native_frames.pop_front();
                    }
                }
                presentation_idle.notify_all();
                if (released_depth != 0 || queued_frame_count == 0)
                    presentation_space_available.notify_all();
                if (released_depth != 0 || queued_frame_count == 0) {
                    lock.unlock();
                    performance.record_display_queue_depth(released_depth);
                    lock.lock();
                }
            }
        });
    }

    void stop_native_presenter()
    {
        static_cast<void>(flush_native_presenter());
        {
            std::lock_guard lock { frame_mutex };
            presentation_stopping = true;
        }
        presentation_available.notify_all();
        if (presentation_thread.joinable())
            presentation_thread.join();
        {
            std::lock_guard lock { frame_mutex };
            presentation_stopping = false;
            presentation_active = false;
        }
    }

    bool flush_native_presenter()
    {
        std::unique_lock lock { frame_mutex };
        if (!presentation_thread.joinable())
            return true;
        if (presentation_idle.wait_until(lock,
                std::chrono::steady_clock::now() + presentation_flush_timeout,
                [this] {
                    return pending_native_frames.empty() &&
                           !presentation_active;
                })) {
            return true;
        }
        fail_presentation_locked();
        presentation_available.notify_all();
        return false;
    }

    [[nodiscard]] bool transition_to_cpu_presentation()
    {
#if defined(SHADE_HAS_SDL2)
        {
            std::lock_guard lock { sdl_mutex };
            if (window != nullptr && !vulkan_window)
                return true;
        }
        stop_native_presenter();
        std::shared_ptr<HostGraphicsDevice> graphics;
        {
            std::lock_guard lock { frame_mutex };
            graphics = host_graphics;
        }
        if (!graphics || !graphics->release_presentation_surface())
            return false;
        surface_created.store(false, std::memory_order_release);
        ensure_cpu_window();
        std::lock_guard lock { sdl_mutex };
        return window != nullptr && !vulkan_window;
#else
        return false;
#endif
    }
};

bool SdlDisplay::available()
{
#if defined(SHADE_HAS_SDL2)
    return true;
#else
    return false;
#endif
}

SdlDisplay::SdlDisplay(
    DisplayGeometry frame_geometry, DisplayGeometry input_geometry)
    : impl_ { std::make_unique<Impl>(
          frame_geometry.valid() ? frame_geometry : default_display_geometry,
          input_geometry.valid() ? input_geometry : default_display_geometry) }
{
#if defined(SHADE_HAS_SDL2)
    configure_sdl_dpi_awareness();
    if (SDL_InitSubSystem(SDL_INIT_VIDEO) != 0) {
        throw std::runtime_error { "SDL video initialization failed: " +
                                   std::string { SDL_GetError() } };
    }
#if defined(SHADE_HAS_VULKAN)
    if (SDL_Vulkan_LoadLibrary(nullptr) == 0) {
        impl_->vulkan_library_loaded = true;
        impl_->window = impl_->create_window(true);
        impl_->vulkan_window = impl_->window != nullptr;
    }
#endif
    if (impl_->window == nullptr) {
        impl_->window = impl_->create_window(false);
        impl_->vulkan_window = false;
    }
    if (impl_->window == nullptr) {
        throw std::runtime_error { "SDL window creation failed: " +
                                   std::string { SDL_GetError() } };
    }
    impl_->start_cpu_presenter();
#else
    throw std::runtime_error {
        "SDL2 display support was not available when Shade was built"
    };
#endif
}

SdlDisplay::~SdlDisplay()
{
#if defined(SHADE_HAS_SDL2)
    if (impl_) {
        flush_presentation();
        impl_->stop_native_presenter();
        impl_->stop_cpu_presenter();
        {
            std::lock_guard lock { impl_->frame_mutex };
            impl_->abandon_queued_frames_locked();
        }
        impl_->presentation_space_available.notify_all();
        {
            std::lock_guard lock { impl_->sdl_mutex };
            if (impl_->texture != nullptr)
                SDL_DestroyTexture(impl_->texture);
            if (impl_->renderer != nullptr)
                SDL_DestroyRenderer(impl_->renderer);
            impl_->destroy_retired_window();
            if (impl_->window != nullptr)
                SDL_DestroyWindow(impl_->window);
#if defined(SHADE_HAS_VULKAN)
            if (impl_->vulkan_library_loaded)
                SDL_Vulkan_UnloadLibrary();
#endif
            SDL_QuitSubSystem(SDL_INIT_VIDEO);
        }
    }
#endif
}

std::optional<VulkanPresenterConfiguration>
SdlDisplay::vulkan_presenter_configuration() const
{
#if defined(SHADE_HAS_SDL2) && defined(SHADE_HAS_VULKAN)
    std::lock_guard sdl_lock { impl_->sdl_mutex };
    if (!impl_->vulkan_window)
        return std::nullopt;
    unsigned int count { };
    if (SDL_Vulkan_GetInstanceExtensions(impl_->window, &count, nullptr) !=
            SDL_TRUE ||
        count == 0) {
        return std::nullopt;
    }
    std::vector<const char*> names(count);
    if (SDL_Vulkan_GetInstanceExtensions(impl_->window, &count, names.data()) !=
        SDL_TRUE) {
        return std::nullopt;
    }
    VulkanPresenterConfiguration configuration;
    configuration.instance_extensions.reserve(count);
    for (const auto* name : names)
        configuration.instance_extensions.emplace_back(name);
    auto* implementation = impl_.get();
    configuration.create_surface = [implementation](std::uintptr_t instance) {
        std::lock_guard callback_lock { implementation->sdl_mutex };
        VkSurfaceKHR surface { };
        if (SDL_Vulkan_CreateSurface(implementation->window,
                reinterpret_cast<VkInstance>(instance), &surface) != SDL_TRUE) {
            return std::uintptr_t { };
        }
        implementation->surface_created = true;
        return reinterpret_cast<std::uintptr_t>(surface);
    };
    configuration.drawable_size = [implementation] {
        std::lock_guard callback_lock { implementation->sdl_mutex };
        int width { };
        int height { };
        SDL_Vulkan_GetDrawableSize(implementation->window, &width, &height);
        return std::pair { width > 0 ? static_cast<std::uint32_t>(width) : 0U,
            height > 0 ? static_cast<std::uint32_t>(height) : 0U };
    };
    return configuration;
#else
    return std::nullopt;
#endif
}

void SdlDisplay::set_host_graphics(std::shared_ptr<HostGraphicsDevice> graphics)
{
    flush_presentation();
    impl_->stop_native_presenter();
#if defined(SHADE_HAS_SDL2)
    impl_->stop_cpu_presenter();
#endif
    {
        std::lock_guard lock { impl_->frame_mutex };
        // Release frames before dropping the renderer. A deferred readback
        // keeps a shared host-graphics reference alive; retaining it until Impl
        // is destroyed would let Vulkan tear down a Wayland surface after SDL
        // has already destroyed its window.
        impl_->abandon_queued_frames_locked();
        impl_->last_presented_frame.reset();
        impl_->host_graphics = std::move(graphics);
        impl_->presentation_failed = false;
        impl_->orientation_encoder =
            impl_->host_graphics
                ? impl_->host_graphics->create_command_encoder()
                : nullptr;
    }
#if defined(SHADE_HAS_SDL2)
    if (impl_->host_graphics &&
        !impl_->host_graphics->native_presentation_available())
        impl_->ensure_cpu_window();
    if (impl_->host_graphics) {
        impl_->start_cpu_presenter();
        if (impl_->host_graphics->native_presentation_available())
            impl_->start_native_presenter();
    } else {
        impl_->stop_cpu_presenter();
    }
#endif
}

void SdlDisplay::present(DisplayFrame frame)
{
#if defined(SHADE_HAS_SDL2)
    if (frame.width != impl_->guest_geometry.width ||
        frame.height != impl_->guest_geometry.height ||
        (frame.pixels.empty() && !frame.read_pixels)) {
        return;
    }
    std::uint64_t depth { };
    bool coalesced { };
    {
        std::lock_guard lock { impl_->frame_mutex };
        if (impl_->presentation_stopping || impl_->presentation_failed ||
            !impl_->running) {
            coalesced = true;
        } else if (impl_->queued_frame_count < presentation_queue_capacity) {
            impl_->pending_frames.push_back(std::move(frame));
            ++impl_->queued_frame_count;
            depth = impl_->queued_frame_count;
        } else if (!impl_->pending_frames.empty()) {
            // Keep the queue ordered but discard the oldest frame that has not
            // yet crossed into the native presenter. The queue remains bounded
            // and the newest state wins under an artificial or real producer
            // burst.
            impl_->pending_frames.pop_front();
            impl_->pending_frames.push_back(std::move(frame));
            coalesced = true;
            depth = impl_->queued_frame_count;
        } else if (impl_->overflow_frame) {
            // Native work may own every regular slot. Keep only one additional
            // latest frame until the native sequence reaches it.
            *impl_->overflow_frame = std::move(frame);
            coalesced = true;
            depth = impl_->queued_frame_count;
        } else if (impl_->queued_frame_count <
                   presentation_queue_lease_capacity) {
            impl_->overflow_frame = std::move(frame);
            ++impl_->queued_frame_count;
            depth = impl_->queued_frame_count;
        } else {
            // Every regular and overflow lease is already owned by
            // native/fallback work. Drop this newest submission explicitly
            // rather than extending the queue past its bounded budget or making
            // the Guest wait.
            coalesced = true;
            depth = impl_->queued_frame_count;
        }
    }
    if (coalesced)
        performance_counters().record_display_mailbox_coalesced();
    if (depth != 0)
        performance_counters().record_display_queue_depth(depth);
#else
    static_cast<void>(frame);
#endif
}

bool SdlDisplay::has_pending_presentation()
{
#if defined(SHADE_HAS_SDL2)
    std::lock_guard lock { impl_->frame_mutex };
    return !impl_->pending_frames.empty() ||
           impl_->overflow_frame.has_value() ||
           !impl_->native_fallback_frames.empty();
#else
    return false;
#endif
}

void SdlDisplay::flush_presentation()
{
#if defined(SHADE_HAS_SDL2)
    // A native failure is converted to the software path by poll_events(), so a
    // complete boundary has to alternate the main-thread pump with the native
    // worker until every stage is empty.
    const auto deadline =
        std::chrono::steady_clock::now() + presentation_flush_timeout;
    while (true) {
        if (!poll_events() || std::chrono::steady_clock::now() >= deadline) {
            std::uint64_t depth { };
            {
                std::lock_guard lock { impl_->frame_mutex };
                impl_->fail_presentation_locked();
                depth = impl_->queued_frame_count;
                impl_->abandon_queued_frames_locked();
            }
            if (depth != 0)
                performance_counters().record_display_queue_depth(0);
            impl_->presentation_available.notify_all();
            impl_->presentation_space_available.notify_all();
            return;
        }
        if (!impl_->flush_native_presenter()) {
            std::uint64_t depth { };
            {
                std::lock_guard lock { impl_->frame_mutex };
                depth = impl_->queued_frame_count;
                impl_->abandon_queued_frames_locked();
            }
            if (depth != 0)
                performance_counters().record_display_queue_depth(0);
            impl_->presentation_available.notify_all();
            impl_->presentation_space_available.notify_all();
            return;
        }
        if (!impl_->flush_cpu_presenter()) {
            std::uint64_t depth { };
            {
                std::lock_guard lock { impl_->frame_mutex };
                depth = impl_->queued_frame_count;
                impl_->abandon_queued_frames_locked();
            }
            if (depth != 0)
                performance_counters().record_display_queue_depth(0);
            impl_->presentation_available.notify_all();
            impl_->presentation_space_available.notify_all();
            return;
        }
        std::lock_guard lock { impl_->frame_mutex };
        if (impl_->queued_frame_count == 0) {
            break;
        }
    }
#endif
}

std::uint64_t SdlDisplay::presented_frames() const
{
    return impl_->presented_frames.load(std::memory_order_acquire);
}

bool SdlDisplay::poll_events()
{
#if defined(SHADE_HAS_SDL2)
    // SDL events are latency-sensitive and must be drained before any CPU
    // fallback upload. Native presentation is handed to an ordered worker queue
    // and never waits on acquire/present from the guest scheduler thread.
    bool input_running { };
    {
        std::lock_guard lock { impl_->sdl_mutex };
        input_running = impl_->input.poll(impl_->window);
    }
    {
        std::lock_guard lock { impl_->frame_mutex };
        if (!input_running)
            impl_->fail_presentation_locked();
        else if (!impl_->presentation_failed)
            impl_->running = true;
    }
    if (!input_running)
        impl_->presentation_available.notify_all();
    const auto redraw_requested = impl_->input.take_redraw_request();
    const auto surface_change_requested =
        impl_->input.take_surface_change_request();
    if (surface_change_requested && impl_->host_graphics &&
        impl_->host_graphics->native_presentation_available()) {
        impl_->stop_native_presenter();
        static_cast<void>(impl_->host_graphics->refresh_presentation_surface());
        impl_->start_native_presenter();
    }
    std::optional<DisplayFrame> frame;
    bool native_failed { };
    bool repainting { };
    bool queued_frame { };
    bool native_presentation { };
    {
        std::lock_guard lock { impl_->frame_mutex };
        if (!impl_->native_fallback_frames.empty()) {
            frame = std::move(impl_->native_fallback_frames.front());
            impl_->native_fallback_frames.pop_front();
            native_failed = true;
            impl_->native_fallback_active = true;
            queued_frame = true;
        } else if (!impl_->pending_frames.empty()) {
            frame = std::move(impl_->pending_frames.front());
            impl_->pending_frames.pop_front();
            queued_frame = true;
        } else if (impl_->overflow_frame) {
            frame = std::move(*impl_->overflow_frame);
            impl_->overflow_frame.reset();
            queued_frame = true;
        }
        if (!frame && redraw_requested && impl_->last_presented_frame) {
            frame = *impl_->last_presented_frame;
            repainting = true;
        }
    }
    if (native_failed && !impl_->transition_to_cpu_presentation()) {
        if (frame && queued_frame)
            impl_->release_queued_frame(&*frame);
        {
            std::lock_guard lock { impl_->frame_mutex };
            impl_->fail_presentation_locked();
        }
        return false;
    }
    if (frame) {
        const auto requested_orientation = frame->orientation;
        native_presentation =
            !native_failed && impl_->host_graphics &&
            impl_->host_graphics->native_presentation_available();
        // Window/orientation changes are explicit boundaries. The potentially
        // expensive frame staging itself is still deferred to the native
        // worker.
        if (native_presentation && !repainting &&
            impl_->orientation != requested_orientation)
            impl_->update_orientation(requested_orientation);
    }
    if (frame) {
        auto& performance = performance_counters();
        const auto telemetry_enabled = performance.enabled();
        const auto display_dequeued_at =
            telemetry_enabled ? std::chrono::steady_clock::now()
                              : std::chrono::steady_clock::time_point { };
        if (telemetry_enabled) {
            performance.record_diagnostic_display_dequeue(
                frame->sequence, display_dequeued_at);
        }
        if (telemetry_enabled &&
            frame->submitted_at != std::chrono::steady_clock::time_point { }) {
            const auto residence = display_dequeued_at - frame->submitted_at;
            performance.record_latency(PerfLatencyKind::DisplayMailbox,
                static_cast<std::uint64_t>(
                    std::chrono::duration_cast<std::chrono::nanoseconds>(
                        residence)
                        .count()));
        }
        if (native_presentation) {
            const auto native_sequence = frame->sequence;
            std::chrono::steady_clock::time_point native_queued_at;
            bool queued_native { };
            bool native_coalesced { };
            {
                std::lock_guard lock { impl_->frame_mutex };
                // A redraw-only frame was not admitted through present(), so
                // account for it before handing it to the native worker.
                // Otherwise a failed native attempt would later decrement the
                // count for an uncounted frame when it enters the fallback
                // path. Repaint requests are not Guest submissions and may
                // arrive as an expose/focus storm. Share the eight-slot queue
                // plus one overflow lease with regular frames; when that
                // bounded budget is occupied, the next repaint is redundant and
                // is safely coalesced instead of growing the native worker
                // queue.
                if (!queued_frame && impl_->queued_frame_count >=
                                         presentation_queue_lease_capacity) {
                    native_coalesced = true;
                } else {
                    if (!queued_frame)
                        ++impl_->queued_frame_count;
                    if (telemetry_enabled)
                        frame->native_queued_at =
                            std::chrono::steady_clock::now();
                    native_queued_at = frame->native_queued_at;
                    if (impl_->native_fallback_active ||
                        !impl_->native_fallback_frames.empty()) {
                        impl_->native_fallback_frames.push_back(
                            std::move(*frame));
                    } else {
                        impl_->pending_native_frames.push_back(
                            std::move(*frame));
                        queued_native = true;
                    }
                }
            }
            if (native_coalesced)
                performance.record_native_present_mailbox_coalesced();
            if (telemetry_enabled && queued_native) {
                performance.record_diagnostic_native_queue(
                    native_sequence, native_queued_at);
            }
            impl_->presentation_available.notify_one();
            frame.reset();
            queued_frame = false;
        }
    }
    if (frame) {
        const auto requested_orientation = frame->orientation;
        if (requested_orientation != DisplayOrientation::Portrait) {
            const auto raw_geometry =
                DisplayGeometry { frame->width, frame->height };
            const auto expected = raw_geometry.pixel_count();
            if (frame->pixels.size() != expected && frame->read_pixels)
                frame->pixels = frame->read_pixels();
            const auto oriented = orient_display_pixels(
                raw_geometry, frame->pixels, requested_orientation);
            if (oriented.empty()) {
                if (queued_frame) {
                    impl_->release_queued_frame(&*frame);
                    queued_frame = false;
                    std::lock_guard lock { impl_->frame_mutex };
                    impl_->fail_presentation_locked();
                } else {
                    std::lock_guard lock { impl_->frame_mutex };
                    impl_->release_frame_surface_in_use_locked(*frame);
                }
                frame.reset();
            } else {
                frame->pixels = oriented;
                {
                    std::lock_guard lock { impl_->frame_mutex };
                    impl_->release_frame_surface_in_use_locked(*frame);
                }
                frame->host_surface.reset();
                frame->presentation_staging_surface.reset();
                frame->read_pixels = { };
                if (is_landscape(requested_orientation))
                    std::swap(frame->width, frame->height);
                frame->orientation = DisplayOrientation::Portrait;
            }
        }
        if (frame && !repainting && impl_->orientation != requested_orientation)
            impl_->update_orientation(requested_orientation);
    }
    if (frame) {
        static_cast<void>(impl_->queue_cpu_frame(
            std::move(*frame), queued_frame, native_failed, repainting));
    }
#endif
    return impl_->running;
}

bool SdlDisplay::wait_for_event(std::chrono::nanoseconds timeout)
{
    performance_counters().record_sdl_idle_wait();
#if defined(SHADE_HAS_SDL2)
    bool input_running { };
    {
        std::lock_guard lock { impl_->sdl_mutex };
        input_running = impl_->input.wait(impl_->window, timeout);
    }
    {
        std::lock_guard lock { impl_->frame_mutex };
        if (!input_running)
            impl_->fail_presentation_locked();
        else if (!impl_->presentation_failed)
            impl_->running = true;
    }
    if (!input_running)
        impl_->presentation_available.notify_all();
#else
    static_cast<void>(timeout);
#endif
    return impl_->running;
}

std::vector<TouchInput> SdlDisplay::take_touch_events()
{
    return impl_->input.take_touch_events();
}

std::vector<SystemButtonInput> SdlDisplay::take_button_events()
{
    return impl_->input.take_button_events();
}

std::vector<RingerSwitchInput> SdlDisplay::take_ringer_switch_events()
{
    return impl_->input.take_ringer_switch_events();
}

} // namespace shade
