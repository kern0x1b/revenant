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

namespace emulator {
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

}

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

const std::array<snapshot::Member<DisplayState>, 9>& DisplayState::snapshot_members()
{
    static constexpr std::array<snapshot::Member<DisplayState>, 9> members {{
        {"display.geometry_width",
            [](const DisplayState& display) {
                return snapshot::is_default(display.geometry_.width);
            },
            [](snapshot::Writer& out, const DisplayState& display) {
                snapshot::save(out, display.geometry_.width);
            },
            [](snapshot::Reader& in, DisplayState& display) {
                std::uint32_t width { };
                snapshot::load(in, width);
                if (width != display.geometry_.width)
                    throw snapshot::FormatError { "display geometry differs from the wiring" };
            }},
        {"display.geometry_height",
            [](const DisplayState& display) {
                return snapshot::is_default(display.geometry_.height);
            },
            [](snapshot::Writer& out, const DisplayState& display) {
                snapshot::save(out, display.geometry_.height);
            },
            [](snapshot::Reader& in, DisplayState& display) {
                std::uint32_t height { };
                snapshot::load(in, height);
                if (height != display.geometry_.height)
                    throw snapshot::FormatError { "display geometry differs from the wiring" };
            }},
        {"display.pixels_",
            [](const DisplayState& display) {
                return snapshot::is_default(display.pixels_);
            },
            [](snapshot::Writer& out, const DisplayState& display) {
                snapshot::save(out, display.pixels_);
            },
            [](snapshot::Reader& in, DisplayState& display) {
                std::vector<std::uint32_t> pixels;
                snapshot::load(in, pixels);
                if (pixels.size() != display.geometry_.pixel_count())
                    throw snapshot::FormatError { "display pixels differ from the geometry" };
                display.pixels_ = std::move(pixels);
                display.host_surface_.reset();
                display.surface_reader_ = { };
                display.surface_content_revision_reader_ = { };
            }},
        {"display.surface_content_generation_",
            [](const DisplayState& display) {
                return snapshot::is_default(display.surface_content_generation_);
            },
            [](snapshot::Writer& out, const DisplayState& display) {
                snapshot::save(out, display.surface_content_generation_);
            },
            [](snapshot::Reader& in, DisplayState& display) {
                snapshot::load(in, display.surface_content_generation_);
            }},
        {"display.content_owner_process_id_",
            [](const DisplayState& display) {
                return snapshot::is_default(display.content_owner_process_id_);
            },
            [](snapshot::Writer& out, const DisplayState& display) {
                snapshot::save(out, display.content_owner_process_id_);
            },
            [](snapshot::Reader& in, DisplayState& display) {
                snapshot::load(in, display.content_owner_process_id_);
            }},
        {"display.sequence_",
            [](const DisplayState& display) {
                return snapshot::is_default(display.sequence_);
            },
            [](snapshot::Writer& out, const DisplayState& display) {
                snapshot::save(out, display.sequence_);
            },
            [](snapshot::Reader& in, DisplayState& display) {
                snapshot::load(in, display.sequence_);
            }},
        {"display.content_revision_",
            [](const DisplayState& display) {
                return snapshot::is_default(display.content_revision_);
            },
            [](snapshot::Writer& out, const DisplayState& display) {
                snapshot::save(out, display.content_revision_);
            },
            [](snapshot::Reader& in, DisplayState& display) {
                snapshot::load(in, display.content_revision_);
            }},
        {"display.powered_on_",
            [](const DisplayState& display) {
                return snapshot::is_default(display.powered_on_);
            },
            [](snapshot::Writer& out, const DisplayState& display) {
                snapshot::save(out, display.powered_on_);
            },
            [](snapshot::Reader& in, DisplayState& display) {
                snapshot::load(in, display.powered_on_);
            }},
        {"display.content_orientation_",
            [](const DisplayState& display) {
                return snapshot::is_default(display.content_orientation_);
            },
            [](snapshot::Writer& out, const DisplayState& display) {
                snapshot::save(out, display.content_orientation_);
            },
            [](snapshot::Reader& in, DisplayState& display) {
                snapshot::load(in, display.content_orientation_);
            }},
    }};
    return members;
}

void DisplayState::save(snapshot::Writer& out) const
{
    std::lock_guard lock { mutex_ };
    if (host_surface_ || surface_reader_ || surface_content_revision_reader_)
        throw snapshot::RefusedError { "display.host_surface" };
    snapshot::save_members(out, *this, snapshot_members());
}

void DisplayState::load(snapshot::Reader& in)
{
    std::lock_guard lock { mutex_ };
    snapshot::restore_members(in, *this, snapshot_members());
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

}
