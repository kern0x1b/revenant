// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define the session-facing window, presentation and native input
// boundary.

#pragma once

#include <chrono>
#include <cstdint>
#include <memory>
#include <optional>
#include <vector>

#include "foundation/display_geometry.hpp"
#include "graphics/gles_renderer.hpp"
#include "foundation/system_button_input.hpp"
#include "foundation/touch_input.hpp"

namespace shade {

struct DisplayFrame;

// Host window and input contract consumed by an emulator session. Concrete
// presenters own window-system resources and translate native events.
class DisplayPresenter {
public:
    virtual ~DisplayPresenter() = default;
    [[nodiscard]] virtual std::optional<VulkanPresenterConfiguration>
    vulkan_presenter_configuration() const = 0;
    virtual void set_host_graphics(
        std::shared_ptr<HostGraphicsDevice> graphics) = 0;
    virtual void present(DisplayFrame frame) = 0;
    virtual void flush_presentation() = 0;
    // A Guest submission can arrive just before the scheduler enters its
    // interactive idle wait.  The scheduler must poll again before sleeping
    // when the ordered display mailbox already owns a frame.
    [[nodiscard]] virtual bool has_pending_presentation() = 0;
    // Counts frames accepted by the native swapchain or software presenter.
    [[nodiscard]] virtual std::uint64_t presented_frames() const = 0;
    // Returns false after the user closes the window.
    [[nodiscard]] virtual bool poll_events() = 0;
    // Blocks on the host event queue until an event or the supplied deadline.
    // The caller remains responsible for processing Guest deadlines.
    [[nodiscard]] virtual bool wait_for_event(
        std::chrono::nanoseconds timeout) = 0;
    [[nodiscard]] virtual std::vector<TouchInput> take_touch_events() = 0;
    [[nodiscard]] virtual std::vector<SystemButtonInput>
    take_button_events() = 0;
    [[nodiscard]] virtual std::vector<RingerSwitchInput>
    take_ringer_switch_events() = 0;
};

} // namespace shade
