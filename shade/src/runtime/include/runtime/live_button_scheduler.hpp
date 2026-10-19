// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Schedule host-timed press and release events for guest hardware
// buttons.

#pragma once

#include <chrono>
#include <deque>
#include <optional>
#include <vector>

#include "foundation/system_button_input.hpp"

namespace shade {

// Keeps a physical button Down event alive for a host-controlled duration and
// emits the matching Up event without involving the window toolkit.
class LiveButtonScheduler {
public:
    void schedule(SystemButtonInput down, std::chrono::milliseconds hold);
    [[nodiscard]] std::vector<SystemButtonInput> poll();
    [[nodiscard]] bool empty() const { return events_.empty(); }
    [[nodiscard]] std::optional<std::chrono::steady_clock::time_point>
    next_deadline() const;

private:
    struct Event {
        std::chrono::steady_clock::time_point deadline;
        SystemButtonInput input;
    };

    std::deque<Event> events_;
};

} // namespace shade
