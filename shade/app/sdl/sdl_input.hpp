// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Translate SDL window, keyboard and pointer events into emulator
// input.

#pragma once

#include <chrono>
#include <cstdint>
#include <unordered_set>
#include <vector>

#include "foundation/display_geometry.hpp"
#include "foundation/system_button_input.hpp"
#include "foundation/touch_input.hpp"

struct SDL_Window;
union SDL_Event;

namespace shade {

class SdlInput {
public:
    explicit SdlInput(DisplayGeometry geometry)
        : geometry_ { geometry }
        , display_geometry_ { geometry }
    {
    }
    void set_orientation(DisplayOrientation orientation)
    {
        orientation_ = orientation;
    }
    void set_display_geometry(DisplayGeometry geometry)
    {
        if (geometry.valid())
            display_geometry_ = geometry;
    }
    [[nodiscard]] bool poll(SDL_Window* window);
    [[nodiscard]] bool wait(
        SDL_Window* window, std::chrono::nanoseconds timeout);
    [[nodiscard]] std::vector<TouchInput> take_touch_events();
    [[nodiscard]] std::vector<SystemButtonInput> take_button_events();
    [[nodiscard]] std::vector<RingerSwitchInput> take_ringer_switch_events();
    // A compositor may discard the window back buffer while it is hidden or
    // covered. The presenter consumes this edge to repaint the last scanout
    // without requiring a new guest frame.
    [[nodiscard]] bool take_redraw_request()
    {
        const auto requested = redraw_requested_;
        redraw_requested_ = false;
        return requested;
    }
    // Native presentation surfaces own drawable-sized swapchains. Keep their
    // resize edge separate from ordinary expose/focus redraws so the host
    // backend only rebuilds the surface when its pixel extent can change.
    [[nodiscard]] bool take_surface_change_request()
    {
        const auto requested = surface_change_requested_;
        surface_change_requested_ = false;
        return requested;
    }

private:
    void process_event(const SDL_Event& event, int window_width,
        int window_height, DisplayViewport viewport);

    DisplayGeometry geometry_;
    DisplayGeometry display_geometry_;
    DisplayOrientation orientation_ { DisplayOrientation::Portrait };
    std::vector<TouchInput> touch_events_;
    std::vector<SystemButtonInput> button_events_;
    std::vector<RingerSwitchInput> ringer_switch_events_;
    bool redraw_requested_ { };
    bool surface_change_requested_ { };
    bool mouse_active_ { };
    std::unordered_set<std::int64_t> active_fingers_;
    bool running_ { true };
};

} // namespace shade
