// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Translate SDL window, keyboard and pointer events into emulator
// input.

#include "sdl_input.hpp"

#include <algorithm>
#include <limits>
#include <optional>

#include "graphics/display.hpp"

#if defined(SHADE_HAS_SDL2)
#include <SDL.h>
#endif

namespace shade {
namespace {

#if defined(SHADE_HAS_SDL2)
    DisplayGeometry input_coordinate_geometry(SDL_Window* window)
    {
        int width { };
        int height { };
        if (auto* renderer = SDL_GetRenderer(window))
            SDL_RenderGetLogicalSize(renderer, &width, &height);
        // SDL renderer events use its logical coordinates; a native Vulkan
        // window without an SDL renderer delivers window coordinates.
        if (width <= 0 || height <= 0)
            SDL_GetWindowSize(window, &width, &height);
        return { static_cast<std::uint32_t>(std::max(width, 0)),
            static_cast<std::uint32_t>(std::max(height, 0)) };
    }

    struct MappedTouch {
        TouchInput input;
        bool inside { };
    };

    MappedTouch map_window_touch(float x, float y, TouchPhase phase,
        DisplayViewport viewport, DisplayGeometry geometry,
        DisplayOrientation orientation)
    {
        const auto viewport_width = std::max(viewport.width, 1U);
        const auto viewport_height = std::max(viewport.height, 1U);
        const auto normalized_x =
            std::clamp((x - static_cast<float>(viewport.x)) /
                           static_cast<float>(viewport_width),
                0.0F, 1.0F);
        const auto normalized_y =
            std::clamp((y - static_cast<float>(viewport.y)) /
                           static_cast<float>(viewport_height),
                0.0F, 1.0F);
        const auto guest_width = geometry.valid() ? geometry.width - 1U : 0U;
        const auto guest_height = geometry.valid() ? geometry.height - 1U : 0U;
        float guest_x = normalized_x * static_cast<float>(guest_width);
        float guest_y = normalized_y * static_cast<float>(guest_height);
        switch (orientation) {
        case DisplayOrientation::Portrait:
            break;
        case DisplayOrientation::PortraitUpsideDown:
            guest_x = (1.0F - normalized_x) * static_cast<float>(guest_width);
            guest_y = (1.0F - normalized_y) * static_cast<float>(guest_height);
            break;
        case DisplayOrientation::LandscapeLeft:
            guest_x = normalized_y * static_cast<float>(guest_width);
            guest_y = (1.0F - normalized_x) * static_cast<float>(guest_height);
            break;
        case DisplayOrientation::LandscapeRight:
            guest_x = (1.0F - normalized_y) * static_cast<float>(guest_width);
            guest_y = normalized_x * static_cast<float>(guest_height);
            break;
        }
        const auto viewport_right =
            static_cast<float>(viewport.x) + static_cast<float>(viewport.width);
        const auto viewport_bottom = static_cast<float>(viewport.y) +
                                     static_cast<float>(viewport.height);
        const auto inside =
            x >= static_cast<float>(viewport.x) && x < viewport_right &&
            y >= static_cast<float>(viewport.y) && y < viewport_bottom;
        return MappedTouch { TouchInput { phase, guest_x, guest_y }, inside };
    }

    MappedTouch map_finger(TouchPhase phase, float x, float y, int window_width,
        int window_height, DisplayViewport viewport, DisplayGeometry geometry,
        DisplayOrientation orientation)
    {
        return map_window_touch(
            std::clamp(x, 0.0F, 1.0F) *
                static_cast<float>(std::max(window_width, 1)),
            std::clamp(y, 0.0F, 1.0F) *
                static_cast<float>(std::max(window_height, 1)),
            phase, viewport, geometry, orientation);
    }

    std::optional<SystemButton> map_key(SDL_Keycode key)
    {
        switch (key) {
        case SDLK_h:
            return SystemButton::Home;
        case SDLK_l:
            return SystemButton::Lock;
        case SDLK_PLUS:
        case SDLK_KP_PLUS:
            return SystemButton::VolumeUp;
        case SDLK_MINUS:
        case SDLK_KP_MINUS:
            return SystemButton::VolumeDown;
        default:
            return std::nullopt;
        }
    }
#endif

} // namespace

bool SdlInput::poll(SDL_Window* window)
{
#if defined(SHADE_HAS_SDL2)
    SDL_Event event { };
    while (SDL_PollEvent(&event) != 0) {
        const auto coordinates = input_coordinate_geometry(window);
        process_event(event, static_cast<int>(coordinates.width),
            static_cast<int>(coordinates.height),
            fit_display_viewport(display_geometry_, coordinates));
    }
#else
    static_cast<void>(window);
#endif
    return running_;
}

bool SdlInput::wait(SDL_Window* window, std::chrono::nanoseconds timeout)
{
#if defined(SHADE_HAS_SDL2)
    if (!running_)
        return false;
    int timeout_milliseconds = 0;
    const auto indefinite = timeout == std::chrono::nanoseconds::max();
    if (!indefinite) {
        if (timeout <= std::chrono::nanoseconds::zero())
            return poll(window);
        const auto rounded =
            std::chrono::duration_cast<std::chrono::milliseconds>(timeout);
        auto milliseconds = rounded.count();
        if (std::chrono::duration_cast<std::chrono::nanoseconds>(rounded) <
            timeout) {
            ++milliseconds;
        }
        milliseconds = std::min<std::int64_t>(
            milliseconds, std::numeric_limits<int>::max());
        timeout_milliseconds = static_cast<int>(milliseconds);
    }

    SDL_Event event { };
    const auto received =
        indefinite ? SDL_WaitEvent(&event)
                   : SDL_WaitEventTimeout(&event, timeout_milliseconds);
    if (received != 0) {
        const auto coordinates = input_coordinate_geometry(window);
        process_event(event, static_cast<int>(coordinates.width),
            static_cast<int>(coordinates.height),
            fit_display_viewport(display_geometry_, coordinates));
    }
#else
    static_cast<void>(window);
    static_cast<void>(timeout);
#endif
    return running_;
}

void SdlInput::process_event(const SDL_Event& event, int window_width,
    int window_height, DisplayViewport viewport)
{
#if defined(SHADE_HAS_SDL2)
    switch (event.type) {
    case SDL_WINDOWEVENT:
        switch (event.window.event) {
        case SDL_WINDOWEVENT_EXPOSED:
        case SDL_WINDOWEVENT_SHOWN:
        case SDL_WINDOWEVENT_RESTORED:
        case SDL_WINDOWEVENT_FOCUS_GAINED:
            redraw_requested_ = true;
            break;
        case SDL_WINDOWEVENT_SIZE_CHANGED:
        case SDL_WINDOWEVENT_RESIZED:
            surface_change_requested_ = true;
            redraw_requested_ = true;
            break;
        default:
            break;
        }
        break;
    case SDL_QUIT:
        running_ = false;
        break;
    case SDL_KEYDOWN:
    case SDL_KEYUP:
        if (event.key.repeat == 0) {
            if (event.type == SDL_KEYDOWN && event.key.keysym.sym == SDLK_r) {
                ringer_switch_events_.push_back(RingerSwitchInput { });
                break;
            }
            if (const auto button = map_key(event.key.keysym.sym)) {
                button_events_.push_back(SystemButtonInput { *button,
                    event.type == SDL_KEYDOWN ? SystemButtonPhase::Down
                                              : SystemButtonPhase::Up });
            }
        }
        break;
    case SDL_MOUSEBUTTONDOWN:
        if (event.button.button == SDL_BUTTON_LEFT &&
            event.button.which != SDL_TOUCH_MOUSEID) {
            const auto mapped =
                map_window_touch(static_cast<float>(event.button.x),
                    static_cast<float>(event.button.y), TouchPhase::Down,
                    viewport, geometry_, orientation_);
            if (mapped.inside) {
                mouse_active_ = true;
                touch_events_.push_back(mapped.input);
            }
        }
        break;
    case SDL_MOUSEMOTION:
        if (mouse_active_ && event.motion.which != SDL_TOUCH_MOUSEID) {
            touch_events_.push_back(
                map_window_touch(static_cast<float>(event.motion.x),
                    static_cast<float>(event.motion.y), TouchPhase::Move,
                    viewport, geometry_, orientation_)
                    .input);
        }
        break;
    case SDL_MOUSEBUTTONUP:
        if (event.button.button == SDL_BUTTON_LEFT && mouse_active_ &&
            event.button.which != SDL_TOUCH_MOUSEID) {
            touch_events_.push_back(
                map_window_touch(static_cast<float>(event.button.x),
                    static_cast<float>(event.button.y), TouchPhase::Up,
                    viewport, geometry_, orientation_)
                    .input);
            mouse_active_ = false;
        }
        break;
    case SDL_FINGERDOWN: {
        const auto mapped =
            map_finger(TouchPhase::Down, event.tfinger.x, event.tfinger.y,
                window_width, window_height, viewport, geometry_, orientation_);
        if (mapped.inside) {
            active_fingers_.insert(
                static_cast<std::int64_t>(event.tfinger.fingerId));
            touch_events_.push_back(mapped.input);
        }
        break;
    }
    case SDL_FINGERMOTION:
        if (active_fingers_.contains(
                static_cast<std::int64_t>(event.tfinger.fingerId))) {
            touch_events_.push_back(map_finger(TouchPhase::Move,
                event.tfinger.x, event.tfinger.y, window_width, window_height,
                viewport, geometry_, orientation_)
                    .input);
        }
        break;
    case SDL_FINGERUP:
        if (active_fingers_.erase(
                static_cast<std::int64_t>(event.tfinger.fingerId)) != 0U) {
            touch_events_.push_back(map_finger(TouchPhase::Up, event.tfinger.x,
                event.tfinger.y, window_width, window_height, viewport,
                geometry_, orientation_)
                    .input);
        }
        break;
    default:
        break;
    }
#else
    static_cast<void>(event);
    static_cast<void>(window_width);
    static_cast<void>(window_height);
    static_cast<void>(viewport);
#endif
}

std::vector<TouchInput> SdlInput::take_touch_events()
{
    auto events = std::move(touch_events_);
    touch_events_.clear();
    return events;
}

std::vector<SystemButtonInput> SdlInput::take_button_events()
{
    auto events = std::move(button_events_);
    button_events_.clear();
    return events;
}

std::vector<RingerSwitchInput> SdlInput::take_ringer_switch_events()
{
    auto events = std::move(ringer_switch_events_);
    ringer_switch_events_.clear();
    return events;
}

} // namespace shade
