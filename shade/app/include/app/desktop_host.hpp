// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Connect desktop display, audio, control and resource adapters to a
// session.

#pragma once

#include "runtime/session_host.hpp"

namespace shade {

// The CLI's composition root connects optional native adapters to a session.
class DesktopHost final : public SessionHost {
public:
    void initialize_graphics() override;
    [[nodiscard]] std::unique_ptr<DisplayPresenter> create_display(
        const DeviceModel& device) override;
    [[nodiscard]] std::unique_ptr<ControlChannel> create_control(
        const DeviceModel& device) override;
    [[nodiscard]] SessionAudio create_audio() override;
    [[nodiscard]] HostMemorySnapshot memory_snapshot() const override;
    [[nodiscard]] HostMemoryBudgetSnapshot
    memory_budget_snapshot() const override;
};

} // namespace shade
