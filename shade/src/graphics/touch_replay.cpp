// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Replay scripted touch events against host time and presentation
// coordinates.

#include "graphics/touch_replay.hpp"

#include <fstream>
#include <limits>
#include <sstream>
#include <stdexcept>
#include <string>

namespace shade {
namespace {

    TouchPhase parse_phase(const std::string& value)
    {
        if (value == "down")
            return TouchPhase::Down;
        if (value == "move")
            return TouchPhase::Move;
        if (value == "up")
            return TouchPhase::Up;
        if (value == "cancel")
            return TouchPhase::Cancel;
        throw std::runtime_error { "unknown touch replay phase: " + value };
    }

} // namespace

TouchReplay::TouchReplay(const std::filesystem::path& path)
{
    std::ifstream stream { path };
    if (!stream)
        throw std::runtime_error { "cannot open touch replay file: " +
                                   path.string() };

    std::string line;
    std::uint64_t previous_delay = 0;
    std::size_t line_number = 0;
    while (std::getline(stream, line)) {
        ++line_number;
        const auto first = line.find_first_not_of(" \t\r");
        if (first == std::string::npos || line[first] == '#')
            continue;

        std::istringstream parser { line };
        std::uint64_t delay = 0;
        std::string phase;
        TouchInput input;
        std::string trailing;
        if (!(parser >> delay >> phase >> input.x >> input.y) ||
            (parser >> trailing) || delay < previous_delay ||
            delay > static_cast<std::uint64_t>(
                        std::numeric_limits<std::int64_t>::max())) {
            throw std::runtime_error { "invalid touch replay line " +
                                       std::to_string(line_number) };
        }
        input.phase = parse_phase(phase);
        events_.push_back(Event {
            std::chrono::milliseconds { static_cast<std::int64_t>(delay) },
            input });
        previous_delay = delay;
    }
}

void TouchReplay::start()
{
    start_time_ = std::chrono::steady_clock::now();
    next_event_ = 0;
    started_ = true;
}

std::vector<TouchInput> TouchReplay::poll()
{
    std::vector<TouchInput> result;
    if (!started_)
        return result;
    const auto elapsed = std::chrono::steady_clock::now() - start_time_;
    while (
        next_event_ < events_.size() && elapsed >= events_[next_event_].delay) {
        result.push_back(events_[next_event_].input);
        ++next_event_;
    }
    return result;
}

bool TouchReplay::settled(std::chrono::milliseconds quiet_period) const
{
    if (!started_ || !empty())
        return false;
    const auto final_delay = events_.empty() ? std::chrono::milliseconds { 0 }
                                             : events_.back().delay;
    return std::chrono::steady_clock::now() - start_time_ >=
           final_delay + quiet_period;
}

std::optional<std::chrono::steady_clock::time_point>
TouchReplay::next_deadline() const
{
    if (!started_ || empty())
        return std::nullopt;
    return start_time_ + events_[next_event_].delay;
}

std::optional<std::chrono::steady_clock::time_point>
TouchReplay::settled_deadline(std::chrono::milliseconds quiet_period) const
{
    if (!started_)
        return std::nullopt;
    const auto final_delay = events_.empty() ? std::chrono::milliseconds { 0 }
                                             : events_.back().delay;
    return start_time_ + final_delay + quiet_period;
}

} // namespace shade
