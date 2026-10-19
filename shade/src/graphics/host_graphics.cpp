// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define host surface storage, synchronization and accelerated
// drawing contracts.

#include "graphics/host_graphics.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <limits>
#include <ranges>
#include <utility>
#include <vector>

namespace shade {
namespace {

    HostRectangle union_rectangle(HostRectangle left, HostRectangle right)
    {
        const auto x = std::min(left.x, right.x);
        const auto y = std::min(left.y, right.y);
        const auto right_edge =
            std::max(static_cast<std::int64_t>(left.x) + left.width,
                static_cast<std::int64_t>(right.x) + right.width);
        const auto bottom_edge =
            std::max(static_cast<std::int64_t>(left.y) + left.height,
                static_cast<std::int64_t>(right.y) + right.height);
        return HostRectangle { x, y, static_cast<std::uint32_t>(right_edge - x),
            static_cast<std::uint32_t>(bottom_edge - y) };
    }

    bool rectangles_touch_or_overlap(HostRectangle left, HostRectangle right)
    {
        const auto right_edge = [](HostRectangle rectangle) {
            return static_cast<std::int64_t>(rectangle.x) + rectangle.width;
        };
        const auto bottom_edge = [](HostRectangle rectangle) {
            return static_cast<std::int64_t>(rectangle.y) + rectangle.height;
        };
        return static_cast<std::int64_t>(left.x) <= right_edge(right) &&
               static_cast<std::int64_t>(right.x) <= right_edge(left) &&
               static_cast<std::int64_t>(left.y) <= bottom_edge(right) &&
               static_cast<std::int64_t>(right.y) <= bottom_edge(left);
    }

    void add_damage_rectangle(
        std::vector<HostRectangle>& rectangles, HostRectangle rectangle)
    {
        if (rectangle.width == 0 || rectangle.height == 0)
            return;
        for (std::size_t index = 0; index < rectangles.size();) {
            if (!rectangles_touch_or_overlap(rectangles[index], rectangle)) {
                ++index;
                continue;
            }
            rectangle = union_rectangle(rectangles[index], rectangle);
            rectangles.erase(
                rectangles.begin() + static_cast<std::ptrdiff_t>(index));
            index = 0;
        }
        rectangles.push_back(rectangle);
    }

    std::uint32_t source_over(std::uint32_t source, std::uint32_t destination,
        std::uint8_t global_alpha, bool premultiplied)
    {
        const auto scale = [](std::uint32_t value, std::uint32_t factor) {
            return (value * factor + 127U) / 255U;
        };
        const auto source_alpha =
            scale(source >> 24U, static_cast<std::uint32_t>(global_alpha));
        const auto inverse_alpha = 255U - source_alpha;
        std::uint32_t result { };
        for (std::uint32_t shift = 0; shift < 24U; shift += 8U) {
            const auto source_channel = scale((source >> shift) & 0xffU,
                premultiplied ? global_alpha : source_alpha);
            const auto destination_channel =
                scale((destination >> shift) & 0xffU, inverse_alpha);
            result |= std::min(255U, source_channel + destination_channel)
                      << shift;
        }
        result |= std::min(255U,
                      source_alpha + scale(destination >> 24U, inverse_alpha))
                  << 24U;
        return result;
    }

    std::uint32_t constant_alpha_crossfade(std::uint32_t source,
        std::uint32_t destination, std::uint8_t global_alpha)
    {
        const auto scale = [](std::uint32_t value, std::uint32_t factor) {
            return (value * factor + 127U) / 255U;
        };
        const auto alpha = static_cast<std::uint32_t>(global_alpha);
        const auto inverse_alpha = 255U - alpha;
        std::uint32_t result { };
        for (std::uint32_t shift = 0; shift < 32U; shift += 8U) {
            const auto source_channel = scale((source >> shift) & 0xffU, alpha);
            const auto destination_channel =
                scale((destination >> shift) & 0xffU, inverse_alpha);
            result |= std::min(255U, source_channel + destination_channel)
                      << shift;
        }
        return result;
    }

    constexpr float quad_edge_tolerance = 0.01F;

    struct QuadSample {
        std::array<std::size_t, 3> vertices { };
        std::array<float, 3> weights { };
    };

    std::optional<QuadSample> sample_quad_triangle(
        std::span<const HostPoint> quad, std::array<std::size_t, 3> vertices,
        HostPoint point)
    {
        const auto& first = quad[vertices[0]];
        const auto& second = quad[vertices[1]];
        const auto& third = quad[vertices[2]];
        const auto denominator = (second.y - third.y) * (first.x - third.x) +
                                 (third.x - second.x) * (first.y - third.y);
        if (std::abs(denominator) <= quad_edge_tolerance)
            return std::nullopt;
        const auto first_weight =
            ((second.y - third.y) * (point.x - third.x) +
                (third.x - second.x) * (point.y - third.y)) /
            denominator;
        const auto second_weight =
            ((third.y - first.y) * (point.x - third.x) +
                (first.x - third.x) * (point.y - third.y)) /
            denominator;
        const auto third_weight = 1.0F - first_weight - second_weight;
        if (first_weight < -quad_edge_tolerance ||
            second_weight < -quad_edge_tolerance ||
            third_weight < -quad_edge_tolerance) {
            return std::nullopt;
        }
        return QuadSample { vertices,
            { first_weight, second_weight, third_weight } };
    }

    std::optional<QuadSample> sample_quad(
        std::span<const HostPoint> quad, HostPoint point)
    {
        if (quad.size() != 4)
            return std::nullopt;
        if (const auto first = sample_quad_triangle(quad, { 0, 1, 2 }, point)) {
            return first;
        }
        return sample_quad_triangle(quad, { 0, 2, 3 }, point);
    }

    std::optional<HostPoint> interpolate_texture(
        std::span<const HostTexturedVertex> vertices, const QuadSample& sample)
    {
        const auto affine =
            std::ranges::all_of(vertices, [](const HostTexturedVertex& vertex) {
                return std::abs(vertex.perspective - 1.0F) <=
                       quad_edge_tolerance;
            });
        HostPoint numerator { };
        float denominator = 0.0F;
        for (std::size_t index = 0; index < sample.vertices.size(); ++index) {
            const auto vertex = sample.vertices[index];
            const auto reciprocal =
                affine ? 1.0F : 1.0F / vertices[vertex].perspective;
            const auto coefficient = sample.weights[index] * reciprocal;
            numerator.x += coefficient * vertices[vertex].texture.x;
            numerator.y += coefficient * vertices[vertex].texture.y;
            denominator += affine ? sample.weights[index] : coefficient;
        }
        if (!std::isfinite(denominator) || std::abs(denominator) <= 1.0e-6F)
            return std::nullopt;
        return HostPoint { numerator.x / denominator,
            numerator.y / denominator };
    }

    std::uint32_t composite_pixel(std::uint32_t source,
        std::uint32_t destination, HostCompositeMode mode,
        std::uint8_t global_alpha)
    {
        if (mode == HostCompositeMode::Copy)
            return source;
        if (mode == HostCompositeMode::ConstantAlphaCrossfade) {
            return constant_alpha_crossfade(source, destination, global_alpha);
        }
        return source_over(source, destination, global_alpha,
            mode == HostCompositeMode::PremultipliedSourceOver);
    }

    bool valid_rectangle(const DisplayFrame& frame, HostRectangle rectangle)
    {
        return rectangle.x >= 0 && rectangle.y >= 0 && rectangle.width != 0 &&
               rectangle.height != 0 && rectangle.width <= frame.width &&
               rectangle.height <= frame.height &&
               static_cast<std::uint32_t>(rectangle.x) <=
                   frame.width - rectangle.width &&
               static_cast<std::uint32_t>(rectangle.y) <=
                   frame.height - rectangle.height;
    }

    class CpuCommandEncoder final : public CommandEncoder {
    public:
        bool fill(const std::shared_ptr<HostSurface>& destination,
            HostRectangle rectangle, std::uint32_t argb, HostCompositeMode mode,
            std::uint8_t global_alpha) override
        {
            if (!destination)
                return false;
            auto mapping =
                destination->map_cpu(true, PerfCpuMapReason::SoftwareFallback);
            auto& frame = mapping.frame();
            if (rectangle.x < 0 || rectangle.y < 0 ||
                rectangle.width > frame.width ||
                rectangle.height > frame.height ||
                static_cast<std::uint32_t>(rectangle.x) >
                    frame.width - rectangle.width ||
                static_cast<std::uint32_t>(rectangle.y) >
                    frame.height - rectangle.height) {
                return false;
            }
            for (std::uint32_t y = 0; y < rectangle.height; ++y) {
                const auto row =
                    static_cast<std::size_t>(
                        static_cast<std::uint32_t>(rectangle.y) + y) *
                        frame.width +
                    static_cast<std::uint32_t>(rectangle.x);
                for (std::uint32_t x = 0; x < rectangle.width; ++x) {
                    auto& pixel = frame.pixels[row + x];
                    if (mode == HostCompositeMode::Copy) {
                        pixel = argb;
                    } else if (mode ==
                               HostCompositeMode::ConstantAlphaCrossfade) {
                        pixel =
                            constant_alpha_crossfade(argb, pixel, global_alpha);
                    } else {
                        pixel = source_over(argb, pixel, global_alpha,
                            mode == HostCompositeMode::PremultipliedSourceOver);
                    }
                }
            }
            mapping.set_damage(rectangle);
            performance_counters().record_host_fill();
            return true;
        }

        bool copy(const std::shared_ptr<HostSurface>& source,
            const std::shared_ptr<HostSurface>& destination,
            HostRectangle source_rectangle, HostRectangle destination_rectangle,
            HostCompositeMode mode, std::uint8_t global_alpha,
            HostFilter filter, HostRotation rotation,
            std::optional<HostRectangle> clip) override
        {
            if (!source || !destination || source_rectangle.width == 0 ||
                source_rectangle.height == 0 ||
                destination_rectangle.width == 0 ||
                destination_rectangle.height == 0 ||
                filter == HostFilter::Linear) {
                return false;
            }
            DisplayFrame source_frame;
            {
                auto source_mapping =
                    source->map_cpu(false, PerfCpuMapReason::SoftwareFallback);
                source_frame = source_mapping.frame();
            }
            auto destination_mapping =
                destination->map_cpu(true, PerfCpuMapReason::SoftwareFallback);
            auto& destination_frame = destination_mapping.frame();
            const auto valid = [](const DisplayFrame& frame,
                                   HostRectangle rectangle) {
                return rectangle.x >= 0 && rectangle.y >= 0 &&
                       rectangle.width <= frame.width &&
                       rectangle.height <= frame.height &&
                       static_cast<std::uint32_t>(rectangle.x) <=
                           frame.width - rectangle.width &&
                       static_cast<std::uint32_t>(rectangle.y) <=
                           frame.height - rectangle.height;
            };
            if (!valid(source_frame, source_rectangle) ||
                !valid(destination_frame, destination_rectangle)) {
                return false;
            }
            const auto right = [](HostRectangle rectangle) {
                return static_cast<std::int64_t>(rectangle.x) + rectangle.width;
            };
            const auto bottom = [](HostRectangle rectangle) {
                return static_cast<std::int64_t>(rectangle.y) +
                       rectangle.height;
            };
            auto clipped = clip.value_or(destination_rectangle);
            if (!valid(destination_frame, clipped))
                return false;
            const auto clipped_left =
                std::max(clipped.x, destination_rectangle.x);
            const auto clipped_top =
                std::max(clipped.y, destination_rectangle.y);
            const auto clipped_right =
                std::min(right(clipped), right(destination_rectangle));
            const auto clipped_bottom =
                std::min(bottom(clipped), bottom(destination_rectangle));
            if (clipped_right <= clipped_left ||
                clipped_bottom <= clipped_top) {
                return true;
            }
            clipped = { clipped_left, clipped_top,
                static_cast<std::uint32_t>(clipped_right - clipped_left),
                static_cast<std::uint32_t>(clipped_bottom - clipped_top) };
            std::vector<std::uint32_t> sampled(
                static_cast<std::size_t>(clipped.width) * clipped.height);
            for (std::uint32_t y = 0; y < clipped.height; ++y) {
                for (std::uint32_t x = 0; x < clipped.width; ++x) {
                    const auto destination_x =
                        static_cast<std::uint32_t>(clipped.x) + x;
                    const auto destination_y =
                        static_cast<std::uint32_t>(clipped.y) + y;
                    const auto rectangle_x =
                        destination_x -
                        static_cast<std::uint32_t>(destination_rectangle.x);
                    const auto rectangle_y =
                        destination_y -
                        static_cast<std::uint32_t>(destination_rectangle.y);
                    std::uint32_t local_x { };
                    std::uint32_t local_y { };
                    if (rotation == HostRotation::Clockwise90) {
                        local_x = static_cast<std::uint32_t>(
                            static_cast<std::uint64_t>(rectangle_y) *
                            source_rectangle.width /
                            destination_rectangle.height);
                        local_y = source_rectangle.height - 1U -
                                  static_cast<std::uint32_t>(
                                      static_cast<std::uint64_t>(rectangle_x) *
                                      source_rectangle.height /
                                      destination_rectangle.width);
                    } else if (rotation == HostRotation::Rotate180) {
                        local_x = source_rectangle.width - 1U -
                                  static_cast<std::uint32_t>(
                                      static_cast<std::uint64_t>(rectangle_x) *
                                      source_rectangle.width /
                                      destination_rectangle.width);
                        local_y = source_rectangle.height - 1U -
                                  static_cast<std::uint32_t>(
                                      static_cast<std::uint64_t>(rectangle_y) *
                                      source_rectangle.height /
                                      destination_rectangle.height);
                    } else if (rotation == HostRotation::Clockwise270) {
                        local_x = source_rectangle.width - 1U -
                                  static_cast<std::uint32_t>(
                                      static_cast<std::uint64_t>(rectangle_y) *
                                      source_rectangle.width /
                                      destination_rectangle.height);
                        local_y = static_cast<std::uint32_t>(
                            static_cast<std::uint64_t>(rectangle_x) *
                            source_rectangle.height /
                            destination_rectangle.width);
                    } else {
                        local_x = static_cast<std::uint32_t>(
                            static_cast<std::uint64_t>(rectangle_x) *
                            source_rectangle.width /
                            destination_rectangle.width);
                        local_y = static_cast<std::uint32_t>(
                            static_cast<std::uint64_t>(rectangle_y) *
                            source_rectangle.height /
                            destination_rectangle.height);
                    }
                    const auto source_x =
                        static_cast<std::uint32_t>(source_rectangle.x) +
                        local_x;
                    const auto source_y =
                        static_cast<std::uint32_t>(source_rectangle.y) +
                        local_y;
                    sampled[static_cast<std::size_t>(y) * clipped.width + x] =
                        source_frame.pixels[static_cast<std::size_t>(source_y) *
                                                source_frame.width +
                                            source_x];
                }
            }
            for (std::uint32_t y = 0; y < clipped.height; ++y) {
                for (std::uint32_t x = 0; x < clipped.width; ++x) {
                    const auto source_pixel =
                        sampled[static_cast<std::size_t>(y) * clipped.width +
                                x];
                    auto& destination_pixel =
                        destination_frame
                            .pixels[static_cast<std::size_t>(
                                        static_cast<std::uint32_t>(clipped.y) +
                                        y) *
                                        destination_frame.width +
                                    static_cast<std::uint32_t>(clipped.x) + x];
                    if (mode == HostCompositeMode::Copy) {
                        destination_pixel = source_pixel;
                    } else if (mode ==
                               HostCompositeMode::ConstantAlphaCrossfade) {
                        destination_pixel = constant_alpha_crossfade(
                            source_pixel, destination_pixel, global_alpha);
                    } else {
                        destination_pixel = source_over(source_pixel,
                            destination_pixel, global_alpha,
                            mode == HostCompositeMode::PremultipliedSourceOver);
                    }
                }
            }
            destination_mapping.set_damage(clipped);
            performance_counters().record_host_copy();
            return true;
        }

        bool fill_quad(const std::shared_ptr<HostSurface>& destination,
            std::span<const HostPoint> positions, HostRectangle scissor,
            std::uint32_t argb, HostCompositeMode mode,
            std::uint8_t global_alpha) override
        {
            if (!destination || positions.size() != 4 ||
                std::ranges::any_of(positions, [](const HostPoint point) {
                    return !std::isfinite(point.x) || !std::isfinite(point.y);
                })) {
                return false;
            }
            auto mapping =
                destination->map_cpu(true, PerfCpuMapReason::SoftwareFallback);
            auto& frame = mapping.frame();
            if (!valid_rectangle(frame, scissor))
                return false;
            for (std::uint32_t y = 0; y < scissor.height; ++y) {
                for (std::uint32_t x = 0; x < scissor.width; ++x) {
                    const auto destination_x =
                        static_cast<std::uint32_t>(scissor.x) + x;
                    const auto destination_y =
                        static_cast<std::uint32_t>(scissor.y) + y;
                    if (!sample_quad(positions,
                            { static_cast<float>(destination_x) + 0.5F,
                                static_cast<float>(destination_y) + 0.5F })) {
                        continue;
                    }
                    auto& pixel =
                        frame.pixels[static_cast<std::size_t>(destination_y) *
                                         frame.width +
                                     destination_x];
                    pixel = composite_pixel(argb, pixel, mode, global_alpha);
                }
            }
            mapping.set_damage(scissor);
            performance_counters().record_host_fill();
            return true;
        }

        bool copy_quad(const std::shared_ptr<HostSurface>& source,
            const std::shared_ptr<HostSurface>& destination,
            std::span<const HostTexturedVertex> vertices,
            HostRectangle source_rectangle, HostRectangle scissor,
            HostCompositeMode mode, std::uint8_t global_alpha,
            HostFilter filter) override
        {
            if (!source || !destination || vertices.size() != 4 ||
                filter != HostFilter::Nearest ||
                std::ranges::any_of(
                    vertices, [](const HostTexturedVertex vertex) {
                        return !std::isfinite(vertex.position.x) ||
                               !std::isfinite(vertex.position.y) ||
                               !std::isfinite(vertex.texture.x) ||
                               !std::isfinite(vertex.texture.y) ||
                               !std::isfinite(vertex.perspective) ||
                               std::abs(vertex.perspective) <= 1.0e-6F;
                    })) {
                return false;
            }
            DisplayFrame source_frame;
            {
                auto mapping =
                    source->map_cpu(false, PerfCpuMapReason::SoftwareFallback);
                source_frame = mapping.frame();
            }
            auto destination_mapping =
                destination->map_cpu(true, PerfCpuMapReason::SoftwareFallback);
            auto& destination_frame = destination_mapping.frame();
            if (!valid_rectangle(source_frame, source_rectangle) ||
                !valid_rectangle(destination_frame, scissor)) {
                return false;
            }
            std::array<HostPoint, 4> positions { };
            for (std::size_t index = 0; index < positions.size(); ++index)
                positions[index] = vertices[index].position;
            const auto source_right =
                static_cast<std::int64_t>(source_rectangle.x) +
                source_rectangle.width - 1;
            const auto source_bottom =
                static_cast<std::int64_t>(source_rectangle.y) +
                source_rectangle.height - 1;
            for (std::uint32_t y = 0; y < scissor.height; ++y) {
                for (std::uint32_t x = 0; x < scissor.width; ++x) {
                    const auto destination_x =
                        static_cast<std::uint32_t>(scissor.x) + x;
                    const auto destination_y =
                        static_cast<std::uint32_t>(scissor.y) + y;
                    const auto sample = sample_quad(positions,
                        { static_cast<float>(destination_x) + 0.5F,
                            static_cast<float>(destination_y) + 0.5F });
                    if (!sample)
                        continue;
                    const auto texture = interpolate_texture(vertices, *sample);
                    if (!texture)
                        continue;
                    const auto u = texture->x;
                    const auto v = texture->y;
                    const auto source_x = std::clamp<std::int64_t>(
                        static_cast<std::int64_t>(std::floor(u)),
                        source_rectangle.x, source_right);
                    const auto source_y = std::clamp<std::int64_t>(
                        static_cast<std::int64_t>(std::floor(v)),
                        source_rectangle.y, source_bottom);
                    const auto source_pixel =
                        source_frame.pixels[static_cast<std::size_t>(source_y) *
                                                source_frame.width +
                                            static_cast<std::size_t>(source_x)];
                    auto& destination_pixel =
                        destination_frame
                            .pixels[static_cast<std::size_t>(destination_y) *
                                        destination_frame.width +
                                    destination_x];
                    destination_pixel = composite_pixel(
                        source_pixel, destination_pixel, mode, global_alpha);
                }
            }
            destination_mapping.set_damage(scissor);
            performance_counters().record_host_copy();
            return true;
        }

        bool submit(PerfSubmitReason) override { return true; }
        bool finish(PerfSubmitReason) override { return true; }
    };

} // namespace

HostSurfacePresentationLease::HostSurfacePresentationLease(
    std::shared_ptr<HostSurface> surface)
    : surface_ { std::move(surface) }
{
    if (surface_)
        surface_->retain_presentation_lease();
}

HostSurfacePresentationLease::~HostSurfacePresentationLease()
{
    if (surface_)
        surface_->release_presentation_lease();
}

std::shared_ptr<HostSurfacePresentationLease>
make_host_surface_presentation_lease(std::shared_ptr<HostSurface> surface)
{
    if (!surface)
        return { };
    return std::shared_ptr<HostSurfacePresentationLease> {
        new HostSurfacePresentationLease { std::move(surface) }
    };
}

HostSurface::CpuMapping::CpuMapping(HostSurface& surface, bool write)
    : surface_ { &surface }
    , lock_ { surface.mutex_ }
    , write_ { write }
{
}

HostSurface::CpuMapping::CpuMapping(CpuMapping&& other) noexcept
    : surface_ { std::exchange(other.surface_, nullptr) }
    , lock_ { std::move(other.lock_) }
    , write_ { std::exchange(other.write_, false) }
    , damage_ { std::move(other.damage_) }
{
}

HostSurface::CpuMapping::~CpuMapping()
{
    if (surface_ && write_)
        surface_->mark_cpu_write_locked(damage_);
}

HostSurface::HostSurface(HostSurfaceKey key, HostSurfaceDescriptor descriptor,
    std::span<const std::uint32_t> initial_pixels)
    : key_ { key }
    , descriptor_ { descriptor }
    , cpu_frame_ { descriptor.width, descriptor.height, 0,
        std::vector<std::uint32_t>(
            static_cast<std::size_t>(descriptor.width) * descriptor.height, 0) }
    , cpu_damage_ { HostRectangle {
          0, 0, descriptor.width, descriptor.height } }
{
    if (initial_pixels.size() == cpu_frame_.pixels.size())
        std::copy(initial_pixels.begin(), initial_pixels.end(),
            cpu_frame_.pixels.begin());
    record_damage_locked(cpu_generation_, cpu_damage_);
}

std::uint64_t HostSurface::cpu_generation() const
{
    std::lock_guard lock { mutex_ };
    return cpu_generation_;
}

std::uint64_t HostSurface::gpu_generation() const
{
    std::lock_guard lock { mutex_ };
    return gpu_generation_;
}

bool HostSurface::presentation_leased() const
{
    std::lock_guard lock { mutex_ };
    return presentation_lease_count_ != 0;
}

void HostSurface::mark_scanout_presentation()
{
    std::lock_guard lock { mutex_ };
    ++scanout_presentation_sequence_;
}

std::uint64_t HostSurface::scanout_presentation_sequence() const
{
    std::lock_guard lock { mutex_ };
    return scanout_presentation_sequence_;
}

HostSurface::CpuMapping HostSurface::map_cpu(
    bool write, PerfCpuMapReason reason)
{
    performance_counters().record_cpu_map(write, reason);
    return CpuMapping { *this, write };
}

void HostSurface::replace_cpu(std::span<const std::uint32_t> pixels)
{
    std::lock_guard lock { mutex_ };
    if (pixels.size() != cpu_frame_.pixels.size())
        return;
    std::copy(pixels.begin(), pixels.end(), cpu_frame_.pixels.begin());
    mark_cpu_write_locked();
}

void HostSurface::replace_cpu_region(
    HostRectangle rectangle, std::span<const std::uint32_t> pixels)
{
    std::lock_guard lock { mutex_ };
    if (rectangle.x < 0 || rectangle.y < 0 || rectangle.width == 0 ||
        rectangle.height == 0 || rectangle.width > descriptor_.width ||
        rectangle.height > descriptor_.height ||
        static_cast<std::uint32_t>(rectangle.x) >
            descriptor_.width - rectangle.width ||
        static_cast<std::uint32_t>(rectangle.y) >
            descriptor_.height - rectangle.height ||
        pixels.size() !=
            static_cast<std::size_t>(rectangle.width) * rectangle.height) {
        return;
    }
    for (std::uint32_t row = 0; row < rectangle.height; ++row) {
        std::copy_n(
            pixels.begin() + static_cast<std::size_t>(row) * rectangle.width,
            rectangle.width,
            cpu_frame_.pixels.begin() +
                static_cast<std::size_t>(
                    static_cast<std::uint32_t>(rectangle.y) + row) *
                    descriptor_.width +
                static_cast<std::uint32_t>(rectangle.x));
    }
    cpu_generation_ = ++next_generation_;
    add_damage_rectangle(cpu_damage_, rectangle);
    const std::array damage { rectangle };
    record_damage_locked(cpu_generation_, damage);
}

std::optional<HostRectangle> HostSurface::cpu_damage() const
{
    std::lock_guard lock { mutex_ };
    if (cpu_damage_.empty())
        return std::nullopt;
    auto damage = cpu_damage_.front();
    for (std::size_t index = 1; index < cpu_damage_.size(); ++index)
        damage = union_rectangle(damage, cpu_damage_[index]);
    return damage;
}

std::vector<HostRectangle> HostSurface::cpu_damage_rectangles() const
{
    std::lock_guard lock { mutex_ };
    return cpu_damage_;
}

std::vector<HostRectangle> HostSurface::damage_since(
    std::uint64_t generation) const
{
    std::lock_guard lock { mutex_ };
    const auto current = std::max(cpu_generation_, gpu_generation_);
    if (generation >= current)
        return { };
    if (generation < discarded_damage_generation_) {
        return { HostRectangle {
            0, 0, descriptor_.width, descriptor_.height } };
    }
    std::vector<HostRectangle> result;
    for (const auto& record : damage_history_) {
        if (record.generation <= generation)
            continue;
        for (const auto rectangle : record.rectangles)
            add_damage_rectangle(result, rectangle);
    }
    return result;
}

std::uint64_t HostSurface::mark_gpu_write()
{
    return mark_gpu_write(
        HostRectangle { 0, 0, descriptor_.width, descriptor_.height });
}

std::uint64_t HostSurface::mark_gpu_write(HostRectangle damage)
{
    const std::array rectangles { damage };
    return mark_gpu_write(rectangles);
}

std::uint64_t HostSurface::mark_gpu_write(std::span<const HostRectangle> damage)
{
    std::lock_guard lock { mutex_ };
    gpu_generation_ = ++next_generation_;
    record_damage_locked(gpu_generation_, damage);
    return gpu_generation_;
}

void HostSurface::mark_cpu_synchronized(std::uint64_t gpu_generation)
{
    std::lock_guard lock { mutex_ };
    cpu_generation_ = std::max(cpu_generation_, gpu_generation);
    next_generation_ = std::max(next_generation_, cpu_generation_);
    if (gpu_generation >= cpu_generation_)
        cpu_damage_.clear();
}

void HostSurface::mark_gpu_synchronized(std::uint64_t cpu_generation)
{
    std::lock_guard lock { mutex_ };
    gpu_generation_ = std::max(gpu_generation_, cpu_generation);
    next_generation_ = std::max(next_generation_, gpu_generation_);
    if (cpu_generation >= cpu_generation_)
        cpu_damage_.clear();
}

void HostSurface::retain_presentation_lease()
{
    std::lock_guard lock { mutex_ };
    ++presentation_lease_count_;
}

void HostSurface::release_presentation_lease()
{
    std::lock_guard lock { mutex_ };
    if (presentation_lease_count_ != 0)
        --presentation_lease_count_;
}

void HostSurface::mark_cpu_write_locked(std::optional<HostRectangle> damage)
{
    cpu_generation_ = ++next_generation_;
    const auto rectangle = damage.value_or(
        HostRectangle { 0, 0, descriptor_.width, descriptor_.height });
    add_damage_rectangle(cpu_damage_, rectangle);
    const std::array rectangles { rectangle };
    record_damage_locked(cpu_generation_, rectangles);
}

void HostSurface::record_damage_locked(
    std::uint64_t generation, std::span<const HostRectangle> rectangles)
{
    constexpr std::size_t maximum_damage_history = 64;
    std::vector<HostRectangle> normalized;
    for (const auto rectangle : rectangles)
        add_damage_rectangle(normalized, rectangle);
    if (normalized.empty())
        return;
    damage_history_.push_back(
        DamageRecord { generation, std::move(normalized) });
    while (damage_history_.size() > maximum_damage_history) {
        discarded_damage_generation_ = std::max(
            discarded_damage_generation_, damage_history_.front().generation);
        damage_history_.pop_front();
    }
}

std::shared_ptr<HostSurface> make_host_surface(HostSurfaceKey key,
    HostSurfaceDescriptor descriptor,
    std::span<const std::uint32_t> initial_pixels)
{
    return std::make_shared<HostSurface>(key, descriptor, initial_pixels);
}

std::unique_ptr<CommandEncoder> make_cpu_command_encoder()
{
    return std::make_unique<CpuCommandEncoder>();
}

} // namespace shade
