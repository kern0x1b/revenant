// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Schedule complete live-control gestures against the host steady
// clock.

#pragma once

#include <chrono>
#include <deque>
#include <optional>
#include <span>
#include <vector>

#include "debug/control_channel.hpp"
#include "foundation/touch_input.hpp"

namespace shade {

// Replays a complete live-control gesture against host steady time. Keeping
// this separate from command parsing makes multi-point gestures independent of
// terminal read chunking and guest scheduling speed.
class LiveTouchScheduler {
public:
    void schedule(std::span<const LiveTouchEvent> gesture);
    [[nodiscard]] std::vector<TouchInput> poll();
    [[nodiscard]] bool empty() const { return events_.empty(); }
    [[nodiscard]] std::optional<std::chrono::steady_clock::time_point>
    next_deadline() const;

private:
    struct Event {
        std::chrono::steady_clock::time_point deadline;
        TouchInput input;
    };

    std::deque<Event> events_;
};

} // namespace shade
