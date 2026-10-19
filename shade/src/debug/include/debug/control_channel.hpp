// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define host-independent live commands for emulator control and
// input injection.

#pragma once

#include <chrono>
#include <filesystem>
#include <string>
#include <vector>

#include "foundation/display_geometry.hpp"
#include "foundation/system_button_input.hpp"
#include "foundation/touch_input.hpp"

namespace shade {

enum class LiveControlCommandKind {
    Touch,
    Gesture,
    Button,
    ButtonHold,
    Home,
    Lock,
    VolumeUp,
    VolumeDown,
    RingerRing,
    RingerSilent,
    Snapshot,
    SnapshotSequence,
    Settle,
    PerfBegin,
    PerfEnd,
    Status,
    Processes,
    Threads,
    Help,
    Quit,
    Error,
};

struct LiveTouchEvent {
    std::chrono::milliseconds delay { };
    TouchInput input;
};

struct LiveControlCommand {
    LiveControlCommandKind kind { LiveControlCommandKind::Error };
    TouchInput touch;
    std::vector<LiveTouchEvent> gesture;
    SystemButtonInput system_button;
    std::chrono::milliseconds button_hold { };
    bool wake_display { };
    std::filesystem::path path;
    std::chrono::milliseconds snapshot_interval { };
    std::size_t snapshot_count { };
    std::string message;
};

class ControlChannel {
public:
    virtual ~ControlChannel() = default;
    [[nodiscard]] virtual std::vector<LiveControlCommand> poll() = 0;
    virtual void wait_for(std::chrono::nanoseconds timeout) = 0;
    [[nodiscard]] virtual bool closed() const = 0;
};

} // namespace shade
