// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Manage guest display state and frame submissions independently of
// the host presenter.

#include "graphics/display.hpp"
#include "graphics/host_graphics.hpp"
#include "foundation/performance.hpp"

#include <algorithm>
#include <utility>

namespace shade {
namespace {

    void attach_presentation_leases(DisplayFrame& frame)
    {
        if (frame.host_surface && !frame.presentation_lease)
            frame.presentation_lease =
                make_host_surface_presentation_lease(frame.host_surface);
        if (frame.presentation_staging_surface &&
            !frame.presentation_staging_lease) {
            frame.presentation_staging_lease =
                frame.presentation_staging_surface == frame.host_surface
                    ? frame.presentation_lease
                    : make_host_surface_presentation_lease(
                          frame.presentation_staging_surface);
        }
    }

    std::vector<std::uint32_t> visible_pixels(
        const std::vector<std::uint32_t>& scanout, bool powered_on)
    {
        if (powered_on)
            return scanout;
        return std::vector<std::uint32_t>(scanout.size(), 0xff000000U);
    }

} // namespace

DisplayState::DisplayState()
    : DisplayState(default_display_geometry)
{
}

DisplayState::DisplayState(DisplayGeometry geometry)
    : geometry_ { geometry.valid() ? geometry : default_display_geometry }
    , pixels_(geometry_.pixel_count(), 0xff000000U)
{
}

void DisplayState::set_presenter(Presenter presenter)
{
    std::lock_guard lock { mutex_ };
    presenter_ = std::move(presenter);
}

void DisplayState::set_orientation_resolver(OrientationResolver resolver)
{
    std::lock_guard lock { mutex_ };
    orientation_resolver_ = std::move(resolver);
}

void DisplayState::clear(std::uint32_t argb)
{
    std::lock_guard lock { mutex_ };
    std::fill(pixels_.begin(), pixels_.end(), argb);
    host_surface_.reset();
    surface_reader_ = { };
    surface_content_revision_reader_ = { };
    surface_content_generation_ = 0;
    content_owner_process_id_ = 0;
    content_orientation_ = DisplayOrientation::Portrait;
    ++content_revision_;
}

void DisplayState::replace_pixels(
    std::vector<std::uint32_t> pixels, std::uint32_t owner_process_id)
{
    const auto expected = geometry_.pixel_count();
    if (pixels.size() != expected)
        return;
    std::lock_guard lock { mutex_ };
    const auto owner_changed =
        owner_process_id != 0 && content_owner_process_id_ != owner_process_id;
    auto next_orientation = content_orientation_;
    if (owner_process_id != 0 && orientation_resolver_)
        next_orientation = orientation_resolver_(owner_process_id);
    const auto content_unchanged = !host_surface_ && !owner_changed &&
                                   pixels_ == pixels &&
                                   next_orientation == content_orientation_;
    pixels_ = std::move(pixels);
    host_surface_.reset();
    surface_reader_ = { };
    surface_content_revision_reader_ = { };
    surface_content_generation_ = 0;
    if (owner_process_id != 0) {
        content_owner_process_id_ = owner_process_id;
        content_orientation_ = next_orientation;
    }
    if (!content_unchanged)
        ++content_revision_;
}

void DisplayState::replace_surface(std::shared_ptr<HostSurface> surface,
    std::function<std::vector<std::uint32_t>()> read_pixels,
    std::uint32_t owner_process_id,
    std::function<std::uint64_t()> content_revision_reader)
{
    if (!surface || !read_pixels)
        return;
    const auto content_generation =
        content_revision_reader ? content_revision_reader() : 0U;
    std::lock_guard lock { mutex_ };
    const auto owner_changed =
        owner_process_id != 0 && content_owner_process_id_ != owner_process_id;
    const auto content_changed =
        host_surface_ != surface || !surface_content_revision_reader_ ||
        !content_revision_reader ||
        surface_content_generation_ != content_generation;
    host_surface_ = std::move(surface);
    surface_reader_ = std::move(read_pixels);
    surface_content_revision_reader_ = std::move(content_revision_reader);
    surface_content_generation_ = content_generation;
    if (owner_process_id != 0) {
        content_owner_process_id_ = owner_process_id;
        if (orientation_resolver_)
            content_orientation_ = orientation_resolver_(owner_process_id);
    }
    if (owner_changed || content_changed)
        ++content_revision_;
}

void DisplayState::set_powered_on(bool powered_on)
{
    Presenter presenter;
    DisplayFrame frame;
    {
        std::lock_guard lock { mutex_ };
        if (powered_on_ == powered_on)
            return;
        powered_on_ = powered_on;
        ++content_revision_;
        ++sequence_;
        presenter = presenter_;
        if (!presenter)
            return;
        if (powered_on_ && host_surface_) {
            frame = DisplayFrame { geometry_.width, geometry_.height, sequence_,
                { }, host_surface_, surface_reader_,
                content_owner_process_id_ };
        } else {
            frame = DisplayFrame { geometry_.width, geometry_.height, sequence_,
                visible_pixels(pixels_, powered_on_), { }, { },
                content_owner_process_id_ };
        }
        frame.orientation = content_orientation_;
    }
    attach_presentation_leases(frame);
    const PerformanceLatencyScope latency { PerfLatencyKind::DisplayPresent };
    auto& performance = performance_counters();
    if (performance.enabled()) {
        frame.submitted_at = std::chrono::steady_clock::now();
        performance.record_display_submission(
            frame.sequence, frame.owner_process_id, frame.submitted_at);
    }
    presenter(std::move(frame));
}

void DisplayState::refresh_surface_content_revision()
{
    std::function<std::uint64_t()> reader;
    std::shared_ptr<HostSurface> surface;
    {
        std::lock_guard lock { mutex_ };
        reader = surface_content_revision_reader_;
        surface = host_surface_;
    }
    if (!reader || !surface)
        return;
    const auto content_generation = reader();
    std::lock_guard lock { mutex_ };
    if (host_surface_ != surface || !surface_content_revision_reader_ ||
        content_generation == surface_content_generation_)
        return;
    surface_content_generation_ = content_generation;
    ++content_revision_;
}

void DisplayState::present(std::uint32_t owner_process_id)
{
    refresh_surface_content_revision();
    Presenter presenter;
    DisplayFrame frame;
    {
        std::lock_guard lock { mutex_ };
        ++sequence_;
        if (owner_process_id != 0) {
            content_owner_process_id_ = owner_process_id;
            if (orientation_resolver_)
                content_orientation_ = orientation_resolver_(owner_process_id);
        }
        presenter = presenter_;
        if (!presenter)
            return;
        if (powered_on_ && host_surface_) {
            frame = DisplayFrame { geometry_.width, geometry_.height, sequence_,
                { }, host_surface_, surface_reader_,
                content_owner_process_id_ };
        } else {
            frame = DisplayFrame { geometry_.width, geometry_.height, sequence_,
                visible_pixels(pixels_, powered_on_), { }, { },
                content_owner_process_id_ };
        }
        frame.orientation = content_orientation_;
    }
    attach_presentation_leases(frame);
    const PerformanceLatencyScope latency { PerfLatencyKind::DisplayPresent };
    auto& performance = performance_counters();
    if (performance.enabled()) {
        frame.submitted_at = std::chrono::steady_clock::now();
        performance.record_display_submission(
            frame.sequence, frame.owner_process_id, frame.submitted_at);
    }
    presenter(std::move(frame));
}

bool DisplayState::clear_if_owner(std::uint32_t owner_process_id)
{
    if (owner_process_id == 0)
        return false;
    Presenter presenter;
    DisplayFrame frame;
    {
        std::lock_guard lock { mutex_ };
        if (content_owner_process_id_ != owner_process_id)
            return false;
        std::fill(pixels_.begin(), pixels_.end(), 0xff000000U);
        host_surface_.reset();
        surface_reader_ = { };
        surface_content_revision_reader_ = { };
        surface_content_generation_ = 0;
        content_owner_process_id_ = 0;
        content_orientation_ = DisplayOrientation::Portrait;
        ++content_revision_;
        ++sequence_;
        presenter = presenter_;
        if (!presenter)
            return true;
        frame = DisplayFrame { geometry_.width, geometry_.height, sequence_,
            pixels_ };
        frame.orientation = DisplayOrientation::Portrait;
    }
    attach_presentation_leases(frame);
    const PerformanceLatencyScope latency { PerfLatencyKind::DisplayPresent };
    auto& performance = performance_counters();
    if (performance.enabled()) {
        frame.submitted_at = std::chrono::steady_clock::now();
        performance.record_display_submission(
            frame.sequence, frame.owner_process_id, frame.submitted_at);
    }
    presenter(std::move(frame));
    return true;
}

DisplayFrame DisplayState::snapshot() const
{
    std::function<std::vector<std::uint32_t>()> reader;
    std::shared_ptr<HostSurface> surface;
    std::vector<std::uint32_t> pixels;
    std::uint64_t sequence { };
    bool powered_on { };
    std::uint32_t owner_process_id { };
    DisplayOrientation orientation { DisplayOrientation::Portrait };
    {
        std::lock_guard lock { mutex_ };
        reader = surface_reader_;
        surface = host_surface_;
        pixels = pixels_;
        sequence = sequence_;
        powered_on = powered_on_;
        owner_process_id = content_owner_process_id_;
        orientation = content_orientation_;
    }
    if (!powered_on) {
        pixels.assign(geometry_.pixel_count(), 0xff000000U);
    } else if (surface && reader) {
        auto materialized = reader();
        if (materialized.size() == geometry_.pixel_count())
            pixels = std::move(materialized);
    }
    auto frame = DisplayFrame { geometry_.width, geometry_.height, sequence,
        std::move(pixels), std::move(surface), std::move(reader),
        owner_process_id };
    frame.orientation = orientation;
    return frame;
}

std::uint64_t DisplayState::presented_frames() const
{
    std::lock_guard lock { mutex_ };
    return sequence_;
}

std::uint64_t DisplayState::content_revision() const
{
    std::lock_guard lock { mutex_ };
    return content_revision_;
}

std::uint32_t DisplayState::content_owner_process_id() const
{
    std::lock_guard lock { mutex_ };
    return content_owner_process_id_;
}

bool DisplayState::powered_on() const
{
    std::lock_guard lock { mutex_ };
    return powered_on_;
}

} // namespace shade
