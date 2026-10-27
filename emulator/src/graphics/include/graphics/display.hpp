// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Manage guest display state and frame submissions independently of
// the host presenter.

#pragma once

#include <array>
#include <chrono>
#include <cstdint>
#include <functional>
#include <memory>
#include <mutex>
#include <utility>
#include <vector>

#include "foundation/display_geometry.hpp"
#include "foundation/snapshot_io.hpp"
#include "foundation/snapshot_member.hpp"

namespace emulator {

class HostSurface;
class HostSurfacePresentationLease;

struct DisplayFrame {
    DisplayFrame() = default;
    DisplayFrame(std::uint32_t frame_width, std::uint32_t frame_height,
        std::uint64_t frame_sequence, std::vector<std::uint32_t> frame_pixels,
        std::shared_ptr<HostSurface> frame_surface = { },
        std::function<std::vector<std::uint32_t>()> frame_reader = { },
        std::uint32_t frame_owner_process_id = 0)
        : width { frame_width }
        , height { frame_height }
        , sequence { frame_sequence }
        , pixels { std::move(frame_pixels) }
        , host_surface { std::move(frame_surface) }
        , read_pixels { std::move(frame_reader) }
        , owner_process_id { frame_owner_process_id }
    {
    }

    std::uint32_t width { };
    std::uint32_t height { };
    std::uint64_t sequence { };
    std::chrono::steady_clock::time_point submitted_at { };
    std::chrono::steady_clock::time_point native_queued_at { };
    std::vector<std::uint32_t> pixels;
    std::shared_ptr<HostSurface> host_surface;
    std::shared_ptr<HostSurfacePresentationLease> presentation_lease;
    std::shared_ptr<HostSurface> presentation_staging_surface;
    std::shared_ptr<HostSurfacePresentationLease> presentation_staging_lease;
    std::function<std::vector<std::uint32_t>()> read_pixels;
    std::uint32_t owner_process_id { };
    DisplayOrientation orientation { DisplayOrientation::Portrait };
};

class DisplayState {
    friend struct CompatibilityKernelSnapshot;

public:
    using Presenter = std::function<void(DisplayFrame)>;
    using OrientationResolver =
        std::function<DisplayOrientation(std::uint32_t process_id)>;

    DisplayState();
    explicit DisplayState(DisplayGeometry geometry);

    void set_presenter(Presenter presenter);
    void set_orientation_resolver(OrientationResolver resolver);
    void clear(std::uint32_t argb);
    void replace_pixels(
        std::vector<std::uint32_t> pixels, std::uint32_t owner_process_id = 0);
    void replace_surface(std::shared_ptr<HostSurface> surface,
        std::function<std::vector<std::uint32_t>()> read_pixels,
        std::uint32_t owner_process_id = 0,
        std::function<std::uint64_t()> content_revision_reader = { });
    void set_powered_on(bool powered_on);
    void present(std::uint32_t owner_process_id = 0);
    bool clear_if_owner(std::uint32_t owner_process_id);
    void save(snapshot::Writer& out) const;
    void load(snapshot::Reader& in);
    static const std::array<snapshot::Member<DisplayState>, 9>& snapshot_members();

    [[nodiscard]] DisplayFrame snapshot() const;
    [[nodiscard]] std::uint64_t presented_frames() const;
    [[nodiscard]] std::uint64_t content_revision() const;
    [[nodiscard]] std::uint32_t content_owner_process_id() const;
    [[nodiscard]] bool powered_on() const;
    [[nodiscard]] DisplayGeometry geometry() const { return geometry_; }
    [[nodiscard]] std::uint32_t width() const { return geometry_.width; }
    [[nodiscard]] std::uint32_t height() const { return geometry_.height; }

private:
    void refresh_surface_content_revision();

    DisplayGeometry geometry_;
    mutable std::mutex mutex_;
    std::vector<std::uint32_t> pixels_;
    std::shared_ptr<HostSurface> host_surface_;
    std::function<std::vector<std::uint32_t>()> surface_reader_;
    std::function<std::uint64_t()> surface_content_revision_reader_;
    std::uint64_t surface_content_generation_ { };
    std::uint32_t content_owner_process_id_ { };
    Presenter presenter_;
    OrientationResolver orientation_resolver_;
    std::uint64_t sequence_ { };
    std::uint64_t content_revision_ { };
    bool powered_on_ { true };
    DisplayOrientation content_orientation_ { DisplayOrientation::Portrait };
};

}
