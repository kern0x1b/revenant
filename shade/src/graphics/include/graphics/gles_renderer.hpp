// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define the renderer backend boundary and select available GLES
// rendering implementations.

#pragma once

#include <compare>
#include <cstdint>
#include <filesystem>
#include <functional>
#include <memory>
#include <span>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "graphics/gles_rasterizer.hpp"
#include "graphics/host_graphics.hpp"
#include "foundation/performance.hpp"

namespace shade {

struct DisplayFrame;

enum class GlesBackend : std::uint8_t {
    Auto,
    Software,
    Vulkan,
};

enum class GlesDeviceSelection : std::uint8_t {
    PreferHardware,
    SoftwareOnly,
};

using GlesRenderTargetKey = HostSurfaceKey;

// Host-side renderer boundary for the guest GLES state model. Backends consume
// already decoded GLES vertices and fixed-function state; they do not depend on
// EGL, CoreSurface, LayerKit, or any guest process details.
class GlesRenderer : public HostGraphicsDevice {
public:
    virtual ~GlesRenderer() = default;

    [[nodiscard]] std::shared_ptr<HostSurface> create_surface(
        HostSurfaceKey key, HostSurfaceDescriptor descriptor,
        std::span<const std::uint32_t> initial_pixels = { }) override;
    [[nodiscard]] std::unique_ptr<CommandEncoder>
    create_command_encoder() override;
    [[nodiscard]] bool map_cpu(HostSurface& surface, bool read,
        PerfCpuMapReason reason = PerfCpuMapReason::GpuReadback,
        std::optional<HostRectangle>* readback_damage = nullptr) override;
    [[nodiscard]] HostNativeImage native_image(
        const HostSurface& surface) const override;
    [[nodiscard]] PresentResult present(
        const std::shared_ptr<HostSurface>& surface) override;
    [[nodiscard]] bool native_presentation_available() const override;
    [[nodiscard]] bool refresh_presentation_surface() override;

    [[nodiscard]] virtual bool draw(DisplayFrame& frame,
        GlesRenderTargetKey target, std::span<const GlesRasterVertex> vertices,
        std::uint32_t mode, const GlesRasterState& state) = 0;
    // Makes recorded work visible to the host queue without waiting for it.
    [[nodiscard]] virtual bool flush(GlesRenderTargetKey target) = 0;
    // Waits for recorded work without materializing the target on the CPU.
    [[nodiscard]] virtual bool finish(GlesRenderTargetKey target) = 0;
    // Materializes GPU-resident draws in a host-endian CPU frame at an
    // explicit CPU-map/readback boundary. An immediately visible backend may
    // implement this as a no-op.
    [[nodiscard]] virtual bool synchronize(DisplayFrame& frame,
        GlesRenderTargetKey target,
        std::optional<HostRectangle>* readback_damage = nullptr) = 0;
    // Marks a CPU-side clear or another writer as authoritative for the target.
    virtual void invalidate(GlesRenderTargetKey target) = 0;
    // Releases a lifecycle batch behind one backend synchronization boundary.
    // Guest-facing stores already know the complete retiring set; preserving
    // that batch prevents a host fence wait per individual surface.
    virtual void release(std::span<const GlesRenderTargetKey> targets) = 0;
    // Drops every process-local target and sampled texture associated with an
    // OpenGLES resource owner. The renderer is shared across guest processes,
    // so retiring only render targets would otherwise leave per-process
    // texture cache entries resident until the global LRU budget is reached.
    virtual void release_owner(std::uint64_t owner) = 0;
    [[nodiscard]] virtual std::string_view name() const = 0;
    [[nodiscard]] virtual bool accelerated() const = 0;
    // Native queue rendering also works with a CPU Vulkan ICD. Keep physical
    // hardware reporting separate from the host rendering capability above.
    [[nodiscard]] virtual bool hardware_accelerated() const
    {
        return accelerated();
    }
    [[nodiscard]] virtual bool software_fallback_allowed() const = 0;
    [[nodiscard]] virtual PerfFallbackReason failure_reason() const = 0;
    // Approximate live host allocation footprint owned by this renderer. The
    // value is for the unified host-resource view; zero is valid for software
    // backends that do not retain a separate allocation pool.
    [[nodiscard]] virtual std::uint64_t resource_bytes() const noexcept
    {
        return 0;
    }
};

struct VulkanPresenterConfiguration {
    std::vector<std::string> instance_extensions;
    std::function<std::uintptr_t(std::uintptr_t)> create_surface;
    std::function<std::pair<std::uint32_t, std::uint32_t>()> drawable_size;
};

using GlesAcceleratedFactory = std::unique_ptr<GlesRenderer> (*)(
    const std::filesystem::path&, const VulkanPresenterConfiguration*,
    GlesDeviceSelection, std::string*) noexcept;

// A host adapter supplies the native backend before renderer creation. The
// standalone core retains a reference rasterizer for tests without a host;
// an installed host factory never falls back to that implementation.
void configure_gles_accelerated_factory(GlesAcceleratedFactory factory);

// A renderer owns host-wide Vulkan device/queue state and is shared by all
// guest processes. Per-process EGL/GLES resources remain in OpenGlesHle.
// Configure the host policy before the first renderer is requested.
void configure_gles_backend(GlesBackend backend);
// Allocates a host-wide namespace for process-local renderer resources.
// Owner zero remains reserved for shared CoreSurface targets.
[[nodiscard]] std::uint64_t allocate_gles_renderer_owner();
// The command-line host points this at its writable data partition before the
// first renderer is created. Empty disables persistent Vulkan pipeline data.
void configure_gles_pipeline_cache(std::filesystem::path path);
// Configures an optional host window before Vulkan instance/device creation.
// The callback boundary keeps SDL and native-window types out of the renderer.
void configure_gles_vulkan_presenter(
    VulkanPresenterConfiguration configuration);
[[nodiscard]] std::string_view gles_backend_name(GlesBackend backend);
[[nodiscard]] std::shared_ptr<GlesRenderer> shared_gles_renderer();
// Releases a shared CoreSurface target only when the renderer is still alive;
// unlike shared_gles_renderer(), this never creates a backend during teardown.
void release_gles_render_target(GlesRenderTargetKey target);
void release_gles_render_targets(std::span<const GlesRenderTargetKey> targets);
// Release the host renderer while its graphics driver is still initialized.
// The command-line host calls this after all guest runtimes have unwound.
void shutdown_gles_renderer();

} // namespace shade
