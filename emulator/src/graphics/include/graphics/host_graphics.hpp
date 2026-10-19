// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define host surface storage, synchronization and accelerated
// drawing contracts.

#pragma once

#include <compare>
#include <cstdint>
#include <deque>
#include <memory>
#include <mutex>
#include <optional>
#include <span>
#include <vector>

#include "graphics/display.hpp"
#include "foundation/performance.hpp"

namespace emulator {

struct HostSurfaceKey {
    std::uint64_t owner { };
    std::uint64_t surface { };

    auto operator<=>(const HostSurfaceKey&) const = default;
};

struct HostSurfaceDescriptor {
    std::uint32_t width { };
    std::uint32_t height { };
    std::uint32_t bytes_per_row { };
    std::uint32_t pixel_format { };
    PerfSurfaceKind kind { PerfSurfaceKind::Unknown };
};

struct HostRectangle {
    std::int32_t x { };
    std::int32_t y { };
    std::uint32_t width { };
    std::uint32_t height { };

    bool operator==(const HostRectangle&) const = default;
};

struct HostPoint {
    float x { };
    float y { };
};

struct HostTexturedVertex {
    HostPoint position { };
    HostPoint texture { };
    float perspective { 1.0F };
};

enum class HostCompositeMode : std::uint8_t {
    Copy,
    SourceOver,
    PremultipliedSourceOver,
    ConstantAlphaCrossfade,
};

enum class HostFilter : std::uint8_t {
    Nearest,
    Linear,
};

enum class HostRotation : std::uint8_t {
    Identity,
    Clockwise90,
    Rotate180,
    Clockwise270,
};

class HostSurface;

class HostSurfacePresentationLease {
public:
    ~HostSurfacePresentationLease();

private:
    friend std::shared_ptr<HostSurfacePresentationLease>
    make_host_surface_presentation_lease(std::shared_ptr<HostSurface> surface);
    explicit HostSurfacePresentationLease(std::shared_ptr<HostSurface> surface);

    std::shared_ptr<HostSurface> surface_;
};

class HostSurface {
public:
    class CpuMapping {
    public:
        CpuMapping(CpuMapping&& other) noexcept;
        CpuMapping& operator=(CpuMapping&&) = delete;
        ~CpuMapping();

        [[nodiscard]] DisplayFrame& frame() { return surface_->cpu_frame_; }
        [[nodiscard]] const DisplayFrame& frame() const
        {
            return surface_->cpu_frame_;
        }
        void set_damage(HostRectangle damage) { damage_ = damage; }

    private:
        friend class HostSurface;
        CpuMapping(HostSurface& surface, bool write);

        HostSurface* surface_ { };
        std::unique_lock<std::mutex> lock_;
        bool write_ { };
        std::optional<HostRectangle> damage_;
    };

    HostSurface(HostSurfaceKey key, HostSurfaceDescriptor descriptor,
        std::span<const std::uint32_t> initial_pixels = { });

    [[nodiscard]] HostSurfaceKey key() const { return key_; }
    [[nodiscard]] HostSurfaceDescriptor descriptor() const
    {
        return descriptor_;
    }
    [[nodiscard]] std::uint64_t cpu_generation() const;
    [[nodiscard]] std::uint64_t gpu_generation() const;
    [[nodiscard]] bool presentation_leased() const;
    void mark_scanout_presentation();
    [[nodiscard]] std::uint64_t scanout_presentation_sequence() const;
    [[nodiscard]] CpuMapping map_cpu(
        bool write, PerfCpuMapReason reason = PerfCpuMapReason::Internal);
    void replace_cpu(std::span<const std::uint32_t> pixels);
    void replace_cpu_region(
        HostRectangle rectangle, std::span<const std::uint32_t> pixels);
    [[nodiscard]] std::optional<HostRectangle> cpu_damage() const;
    [[nodiscard]] std::vector<HostRectangle> cpu_damage_rectangles() const;
    [[nodiscard]] std::vector<HostRectangle> damage_since(
        std::uint64_t generation) const;
    [[nodiscard]] std::uint64_t mark_gpu_write();
    [[nodiscard]] std::uint64_t mark_gpu_write(HostRectangle damage);
    [[nodiscard]] std::uint64_t mark_gpu_write(
        std::span<const HostRectangle> damage);
    void mark_cpu_synchronized(std::uint64_t gpu_generation);
    void mark_gpu_synchronized(std::uint64_t cpu_generation);

private:
    friend class HostSurfacePresentationLease;
    struct DamageRecord {
        std::uint64_t generation { };
        std::vector<HostRectangle> rectangles;
    };

    void mark_cpu_write_locked(
        std::optional<HostRectangle> damage = std::nullopt);
    void record_damage_locked(
        std::uint64_t generation, std::span<const HostRectangle> rectangles);
    void retain_presentation_lease();
    void release_presentation_lease();

    HostSurfaceKey key_;
    HostSurfaceDescriptor descriptor_;
    mutable std::mutex mutex_;
    DisplayFrame cpu_frame_;
    std::uint64_t next_generation_ { 1 };
    std::uint64_t cpu_generation_ { 1 };
    std::uint64_t gpu_generation_ { };
    std::vector<HostRectangle> cpu_damage_;
    std::deque<DamageRecord> damage_history_;
    std::uint64_t discarded_damage_generation_ { };
    std::uint64_t presentation_lease_count_ { };
    std::uint64_t scanout_presentation_sequence_ { };
};

[[nodiscard]] std::shared_ptr<HostSurfacePresentationLease>
make_host_surface_presentation_lease(std::shared_ptr<HostSurface> surface);

class CommandEncoder {
public:
    virtual ~CommandEncoder() = default;
    [[nodiscard]] virtual bool fill(
        const std::shared_ptr<HostSurface>& destination,
        HostRectangle rectangle, std::uint32_t argb,
        HostCompositeMode mode = HostCompositeMode::Copy,
        std::uint8_t global_alpha = 0xffU) = 0;
    [[nodiscard]] virtual bool copy(const std::shared_ptr<HostSurface>& source,
        const std::shared_ptr<HostSurface>& destination,
        HostRectangle source_rectangle, HostRectangle destination_rectangle,
        HostCompositeMode mode = HostCompositeMode::Copy,
        std::uint8_t global_alpha = 0xffU,
        HostFilter filter = HostFilter::Nearest,
        HostRotation rotation = HostRotation::Identity,
        std::optional<HostRectangle> clip = std::nullopt) = 0;
    [[nodiscard]] virtual bool fill_quad(const std::shared_ptr<HostSurface>&,
        std::span<const HostPoint>, HostRectangle, std::uint32_t,
        HostCompositeMode, std::uint8_t)
    {
        return false;
    }
    [[nodiscard]] virtual bool copy_quad(const std::shared_ptr<HostSurface>&,
        const std::shared_ptr<HostSurface>&,
        std::span<const HostTexturedVertex>, HostRectangle, HostRectangle,
        HostCompositeMode, std::uint8_t, HostFilter)
    {
        return false;
    }
    [[nodiscard]] virtual bool fill_triangles(
        const std::shared_ptr<HostSurface>&, std::span<const HostPoint>,
        HostRectangle, std::uint32_t, HostCompositeMode, std::uint8_t)
    {
        return false;
    }
    [[nodiscard]] virtual bool copy_triangles(
        const std::shared_ptr<HostSurface>&,
        const std::shared_ptr<HostSurface>&,
        std::span<const HostTexturedVertex>, HostRectangle, HostCompositeMode,
        std::uint8_t, HostFilter)
    {
        return false;
    }
    [[nodiscard]] virtual bool submit(
        PerfSubmitReason reason = PerfSubmitReason::Other) = 0;
    [[nodiscard]] virtual bool finish(
        PerfSubmitReason reason = PerfSubmitReason::Other) = 0;
};

struct HostNativeImage {
    enum class Api : std::uint8_t {
        None,
        Vulkan,
    };

    Api api { Api::None };
    std::uintptr_t device { };
    std::uintptr_t image { };
    std::uint32_t layout { };
    HostSurfaceDescriptor descriptor;
    std::uint64_t generation { };
};

class HostGraphicsDevice {
public:
    enum class PresentResult : std::uint8_t {
        Queued,
        Skipped,
        Failed,
    };

    virtual ~HostGraphicsDevice() = default;
    [[nodiscard]] virtual std::shared_ptr<HostSurface> create_surface(
        HostSurfaceKey key, HostSurfaceDescriptor descriptor,
        std::span<const std::uint32_t> initial_pixels = { }) = 0;
    [[nodiscard]] virtual std::unique_ptr<CommandEncoder>
    create_command_encoder() = 0;
    [[nodiscard]] virtual bool map_cpu(HostSurface& surface, bool read,
        PerfCpuMapReason reason = PerfCpuMapReason::GpuReadback,
        std::optional<HostRectangle>* readback_damage = nullptr) = 0;
    [[nodiscard]] virtual HostNativeImage native_image(
        const HostSurface& surface) const = 0;
    [[nodiscard]] virtual PresentResult present(
        const std::shared_ptr<HostSurface>& surface) = 0;
    [[nodiscard]] virtual bool native_presentation_available() const = 0;
    [[nodiscard]] virtual bool release_presentation_surface()
    {
        return !native_presentation_available();
    }
    [[nodiscard]] virtual bool refresh_presentation_surface() { return false; }
};

[[nodiscard]] std::shared_ptr<HostSurface> make_host_surface(HostSurfaceKey key,
    HostSurfaceDescriptor descriptor,
    std::span<const std::uint32_t> initial_pixels = { });
[[nodiscard]] std::unique_ptr<CommandEncoder> make_cpu_command_encoder();

}
