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
    [[nodiscard]] virtual bool flush(GlesRenderTargetKey target) = 0;
    [[nodiscard]] virtual bool finish(GlesRenderTargetKey target) = 0;
    [[nodiscard]] virtual bool synchronize(DisplayFrame& frame,
        GlesRenderTargetKey target,
        std::optional<HostRectangle>* readback_damage = nullptr) = 0;
    virtual void invalidate(GlesRenderTargetKey target) = 0;
    virtual void release(std::span<const GlesRenderTargetKey> targets) = 0;
    virtual void release_owner(std::uint64_t owner) = 0;
    [[nodiscard]] virtual std::string_view name() const = 0;
    [[nodiscard]] virtual bool accelerated() const = 0;
    [[nodiscard]] virtual bool hardware_accelerated() const
    {
        return accelerated();
    }
    [[nodiscard]] virtual bool software_fallback_allowed() const = 0;
    [[nodiscard]] virtual PerfFallbackReason failure_reason() const = 0;
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

void configure_gles_accelerated_factory(GlesAcceleratedFactory factory);

void configure_gles_backend(GlesBackend backend);
[[nodiscard]] std::uint64_t allocate_gles_renderer_owner();
void configure_gles_pipeline_cache(std::filesystem::path path);
void configure_gles_vulkan_presenter(
    VulkanPresenterConfiguration configuration);
[[nodiscard]] std::string_view gles_backend_name(GlesBackend backend);
[[nodiscard]] std::shared_ptr<GlesRenderer> shared_gles_renderer();
void release_gles_render_target(GlesRenderTargetKey target);
void release_gles_render_targets(std::span<const GlesRenderTargetKey> targets);
void shutdown_gles_renderer();

}
