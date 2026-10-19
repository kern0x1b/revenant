// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Present guest frames in an SDL window and coordinate native
// presentation.

#pragma once

#include <chrono>
#include <cstdint>
#include <memory>
#include <optional>
#include <vector>

#include "graphics/display_presenter.hpp"
#include "graphics/gles_renderer.hpp"
#include "foundation/system_button_input.hpp"
#include "foundation/touch_input.hpp"

namespace shade {

struct DisplayFrame;

class SdlDisplay final : public DisplayPresenter {
public:
    SdlDisplay(DisplayGeometry frame_geometry, DisplayGeometry input_geometry);
    ~SdlDisplay() override;
    SdlDisplay(const SdlDisplay&) = delete;
    SdlDisplay& operator=(const SdlDisplay&) = delete;

    [[nodiscard]] static bool available();
    [[nodiscard]] std::optional<VulkanPresenterConfiguration>
    vulkan_presenter_configuration() const override;
    void set_host_graphics(
        std::shared_ptr<HostGraphicsDevice> graphics) override;
    void present(DisplayFrame frame) override;
    void flush_presentation() override;
    [[nodiscard]] bool has_pending_presentation() override;
    [[nodiscard]] std::uint64_t presented_frames() const override;
    [[nodiscard]] bool poll_events() override;
    [[nodiscard]] bool wait_for_event(
        std::chrono::nanoseconds timeout) override;
    [[nodiscard]] std::vector<TouchInput> take_touch_events() override;
    [[nodiscard]] std::vector<SystemButtonInput> take_button_events() override;
    [[nodiscard]] std::vector<RingerSwitchInput>
    take_ringer_switch_events() override;

private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};

}
