// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define the renderer backend boundary and select available GLES
// rendering implementations.

#include "graphics/gles_renderer.hpp"

#include <atomic>
#include <cstdint>
#include <filesystem>
#include <memory>
#include <mutex>
#include <optional>
#include <span>
#include <stdexcept>
#include <string>
#include <string_view>
#include <utility>

#include "graphics/display.hpp"

namespace shade {
namespace {

    // Standalone core tests do not install a host adapter. The application
    // always installs one, including a failing factory in non-Vulkan builds.
    class ReferenceGlesRenderer final : public GlesRenderer {
    public:
        bool draw(DisplayFrame& frame, GlesRenderTargetKey target,
            std::span<const GlesRasterVertex> vertices, std::uint32_t mode,
            const GlesRasterState& state) override
        {
            static_cast<void>(target);
            return GlesSoftwareRasterizer::draw(frame, vertices, mode, state);
        }

        bool synchronize(DisplayFrame& frame, GlesRenderTargetKey target,
            std::optional<HostRectangle>* readback_damage) override
        {
            static_cast<void>(target);
            if (readback_damage != nullptr) {
                *readback_damage =
                    HostRectangle { 0, 0, frame.width, frame.height };
            }
            return true;
        }

        bool flush(GlesRenderTargetKey target) override
        {
            static_cast<void>(target);
            return true;
        }

        bool finish(GlesRenderTargetKey target) override
        {
            static_cast<void>(target);
            return true;
        }

        void invalidate(GlesRenderTargetKey target) override
        {
            static_cast<void>(target);
        }

        void release(std::span<const GlesRenderTargetKey> targets) override
        {
            static_cast<void>(targets);
        }

        void release_owner(std::uint64_t owner) override
        {
            static_cast<void>(owner);
        }

        [[nodiscard]] std::string_view name() const override
        {
            return "Shade GLES 1.1 reference";
        }

        [[nodiscard]] bool accelerated() const override { return false; }
        [[nodiscard]] bool software_fallback_allowed() const override
        {
            return false;
        }
        [[nodiscard]] PerfFallbackReason failure_reason() const override
        {
            return PerfFallbackReason::None;
        }
    };

    struct SharedRendererState {
        std::mutex mutex;
        GlesAcceleratedFactory accelerated_factory { };
        GlesBackend backend { GlesBackend::Auto };
        std::filesystem::path pipeline_cache;
        VulkanPresenterConfiguration presenter;
        std::shared_ptr<GlesRenderer>* renderer { };
    };

    SharedRendererState& shared_renderer_state()
    {
        static SharedRendererState state;
        return state;
    }

    std::shared_ptr<GlesRenderer> create_renderer(GlesBackend backend,
        const std::filesystem::path& pipeline_cache,
        const VulkanPresenterConfiguration& presenter)
    {
        const auto factory = shared_renderer_state().accelerated_factory;
        if (!factory && backend != GlesBackend::Vulkan) {
            return std::make_shared<ReferenceGlesRenderer>();
        }

        std::string failure { "no host graphics factory was registered" };
        auto renderer = factory
            ? factory(pipeline_cache,
                  presenter.create_surface ? &presenter : nullptr,
                  backend == GlesBackend::Software
                      ? GlesDeviceSelection::SoftwareOnly
                      : GlesDeviceSelection::PreferHardware,
                  &failure)
            : nullptr;
        if (renderer)
            return std::shared_ptr<GlesRenderer> { std::move(renderer) };
        performance_counters().record_fallback(
            PerfFallbackReason::VulkanUnavailable);
        throw std::runtime_error { "Vulkan GLES backend unavailable: " + failure };
    }

    std::shared_ptr<GlesRenderer>& renderer_slot(GlesBackend backend,
        const std::filesystem::path& pipeline_cache,
        const VulkanPresenterConfiguration& presenter)
    {
        // Register this holder's destructor only after create_renderer()
        // returns. Vulkan ICDs may register their own process-lifetime teardown
        // during device creation; the renderer must be destroyed before those
        // callbacks.
        static std::shared_ptr<GlesRenderer> renderer =
            create_renderer(backend, pipeline_cache, presenter);
        return renderer;
    }

} // namespace

std::shared_ptr<HostSurface> GlesRenderer::create_surface(HostSurfaceKey key,
    HostSurfaceDescriptor descriptor,
    std::span<const std::uint32_t> initial_pixels)
{
    return make_host_surface(key, descriptor, initial_pixels);
}

std::unique_ptr<CommandEncoder> GlesRenderer::create_command_encoder()
{
    return make_cpu_command_encoder();
}

bool GlesRenderer::map_cpu(HostSurface& surface, bool read,
    PerfCpuMapReason reason, std::optional<HostRectangle>* readback_damage)
{
    if (readback_damage != nullptr)
        readback_damage->reset();
    if (!read)
        return true;
    const auto generation = surface.gpu_generation();
    {
        auto mapping = surface.map_cpu(false, reason);
        if (!synchronize(mapping.frame(), surface.key(), readback_damage))
            return false;
    }
    surface.mark_cpu_synchronized(generation);
    return true;
}

HostNativeImage GlesRenderer::native_image(const HostSurface& surface) const
{
    static_cast<void>(surface);
    return { };
}

HostGraphicsDevice::PresentResult GlesRenderer::present(
    const std::shared_ptr<HostSurface>& surface)
{
    static_cast<void>(surface);
    return PresentResult::Failed;
}

bool GlesRenderer::native_presentation_available() const { return false; }

bool GlesRenderer::refresh_presentation_surface() { return false; }

void configure_gles_accelerated_factory(GlesAcceleratedFactory factory)
{
    auto& state = shared_renderer_state();
    std::lock_guard lock { state.mutex };
    if (state.renderer != nullptr && *state.renderer &&
        state.accelerated_factory != factory) {
        throw std::logic_error {
            "GLES factory cannot change after renderer initialization"
        };
    }
    state.accelerated_factory = factory;
}

void configure_gles_backend(GlesBackend backend)
{
    auto& state = shared_renderer_state();
    std::lock_guard lock { state.mutex };
    if (state.renderer != nullptr && *state.renderer &&
        state.backend != backend) {
        throw std::logic_error {
            "GLES backend cannot change after renderer initialization"
        };
    }
    state.backend = backend;
}

std::uint64_t allocate_gles_renderer_owner()
{
    static std::atomic<std::uint64_t> next_owner { 1 };
    for (;;) {
        const auto owner = next_owner.fetch_add(1, std::memory_order_relaxed);
        if (owner != 0)
            return owner;
    }
}

void configure_gles_pipeline_cache(std::filesystem::path path)
{
    auto& state = shared_renderer_state();
    std::lock_guard lock { state.mutex };
    if (state.renderer != nullptr && *state.renderer) {
        throw std::logic_error {
            "GLES pipeline cache path cannot change after initialization"
        };
    }
    state.pipeline_cache = std::move(path);
}

void configure_gles_vulkan_presenter(VulkanPresenterConfiguration configuration)
{
    auto& state = shared_renderer_state();
    std::lock_guard lock { state.mutex };
    if (state.renderer != nullptr && *state.renderer) {
        throw std::logic_error {
            "Vulkan presenter cannot change after renderer initialization"
        };
    }
    state.presenter = std::move(configuration);
}

std::string_view gles_backend_name(GlesBackend backend)
{
    switch (backend) {
    case GlesBackend::Auto:
        return "auto";
    case GlesBackend::Software:
        return "software";
    case GlesBackend::Vulkan:
        return "vulkan";
    }
    return "unknown";
}

std::shared_ptr<GlesRenderer> shared_gles_renderer()
{
    auto& state = shared_renderer_state();
    std::lock_guard lock { state.mutex };
    if (state.renderer == nullptr)
        state.renderer = &renderer_slot(
            state.backend, state.pipeline_cache, state.presenter);
    if (!*state.renderer)
        *state.renderer = create_renderer(
            state.backend, state.pipeline_cache, state.presenter);
    return *state.renderer;
}

void release_gles_render_target(GlesRenderTargetKey target)
{
    release_gles_render_targets(std::span { &target, 1U });
}

void release_gles_render_targets(std::span<const GlesRenderTargetKey> targets)
{
    if (targets.empty())
        return;
    auto& state = shared_renderer_state();
    std::lock_guard lock { state.mutex };
    if (state.renderer != nullptr && *state.renderer)
        (*state.renderer)->release(targets);
}

void shutdown_gles_renderer()
{
    auto& state = shared_renderer_state();
    std::lock_guard lock { state.mutex };
    if (state.renderer != nullptr)
        state.renderer->reset();
}

} // namespace shade
