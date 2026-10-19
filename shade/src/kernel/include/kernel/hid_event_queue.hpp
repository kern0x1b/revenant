// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Represent shared guest HID event queues and their notification
// state.

#pragma once

#include "foundation/touch_input.hpp"

#include <cstddef>
#include <cstdint>
#include <deque>
#include <mutex>
#include <optional>
#include <variant>

namespace shade {

class HidEventQueue {
public:
    struct Consumer {
        std::uint32_t process;
        std::size_t processor;
        std::uint32_t system;
        bool keyboard_events { };
    };
    struct KeyboardInput {
        std::uint32_t usage_page;
        std::uint32_t usage;
        bool down;
    };
    struct Acceleration {
        float x;
        float y;
        float z;
    };
    struct Event {
        std::variant<TouchInput, KeyboardInput, Acceleration> input;
        std::uint64_t timestamp;
        std::uint32_t identity { 1U };
    };

    void open(Consumer consumer)
    {
        std::lock_guard lock { mutex_ };
        consumer_ = consumer;
        events_.clear();
    }
    void close(std::uint32_t process)
    {
        std::lock_guard lock { mutex_ };
        if (consumer_ && consumer_->process == process) {
            consumer_.reset();
            events_.clear();
        }
    }
    [[nodiscard]] std::optional<Consumer> consumer() const
    {
        std::lock_guard lock { mutex_ };
        return consumer_;
    }
    [[nodiscard]] bool enqueue(Event event)
    {
        std::lock_guard lock { mutex_ };
        if (!consumer_ || (std::holds_alternative<KeyboardInput>(event.input) &&
                              !consumer_->keyboard_events))
            return false;
        events_.push_back(event);
        return true;
    }
    [[nodiscard]] std::optional<Event> take(
        std::uint32_t process, std::size_t processor)
    {
        std::lock_guard lock { mutex_ };
        if (!consumer_ || consumer_->process != process ||
            consumer_->processor != processor || events_.empty())
            return std::nullopt;
        auto event = events_.front();
        events_.pop_front();
        return event;
    }

private:
    mutable std::mutex mutex_;
    std::optional<Consumer> consumer_;
    std::deque<Event> events_;
};

} // namespace shade
