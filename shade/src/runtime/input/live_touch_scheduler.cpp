// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Schedule complete live-control gestures against the host steady
// clock.

#include "runtime/live_touch_scheduler.hpp"

#include <algorithm>

namespace shade {

void LiveTouchScheduler::schedule(std::span<const LiveTouchEvent> gesture)
{
    if (gesture.empty())
        return;

    const auto now = std::chrono::steady_clock::now();
    const auto start = events_.empty()
                           ? now
                           : std::max(now, events_.back().deadline +
                                               std::chrono::milliseconds { 1 });
    for (const auto& event : gesture) {
        events_.push_back(Event { start + event.delay, event.input });
    }
}

std::vector<TouchInput> LiveTouchScheduler::poll()
{
    std::vector<TouchInput> result;
    const auto now = std::chrono::steady_clock::now();
    while (!events_.empty() && events_.front().deadline <= now) {
        result.push_back(events_.front().input);
        events_.pop_front();
    }
    return result;
}

std::optional<std::chrono::steady_clock::time_point>
LiveTouchScheduler::next_deadline() const
{
    return events_.empty()
               ? std::nullopt
               : std::optional<std::chrono::steady_clock::time_point> {
                     events_.front().deadline
                 };
}

} // namespace shade
