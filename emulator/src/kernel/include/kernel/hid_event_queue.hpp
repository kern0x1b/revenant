// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Represent shared guest HID event queues and their notification
// state.

#pragma once

#include "foundation/snapshot_io.hpp"
#include "foundation/touch_input.hpp"

#include <bit>
#include <cstddef>
#include <cstdint>
#include <deque>
#include <mutex>
#include <optional>
#include <variant>

namespace emulator {

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

    void save(snapshot::Writer& out) const
    {
        std::lock_guard lock { mutex_ };
        snapshot::save(out, consumer_.has_value());
        if (consumer_) {
            snapshot::save(out, consumer_->process);
            snapshot::save(out, consumer_->processor);
            snapshot::save(out, consumer_->system);
            snapshot::save(out, consumer_->keyboard_events);
        }
        snapshot::save(out, static_cast<std::uint64_t>(events_.size()));
        for (const auto& event : events_)
            save_event(out, event);
    }

    void load(snapshot::Reader& in)
    {
        std::lock_guard lock { mutex_ };
        bool has_consumer { };
        snapshot::load(in, has_consumer);
        consumer_.reset();
        if (has_consumer) {
            Consumer consumer { };
            snapshot::load(in, consumer.process);
            snapshot::load(in, consumer.processor);
            snapshot::load(in, consumer.system);
            snapshot::load(in, consumer.keyboard_events);
            consumer_ = consumer;
        }
        std::uint64_t count { };
        snapshot::load(in, count);
        events_.clear();
        for (std::uint64_t index = 0; index < count; ++index)
            events_.push_back(load_event(in));
    }

private:
    static void save_float(snapshot::Writer& out, float value)
    {
        snapshot::save(out, std::bit_cast<std::uint32_t>(value));
    }

    static void load_float(snapshot::Reader& in, float& value)
    {
        std::uint32_t bits { };
        snapshot::load(in, bits);
        value = std::bit_cast<float>(bits);
    }

    static void save_event(snapshot::Writer& out, const Event& event)
    {
        snapshot::save(out, static_cast<std::uint8_t>(event.input.index()));
        if (const auto* touch = std::get_if<TouchInput>(&event.input)) {
            snapshot::save(out, touch->phase);
            save_float(out, touch->x);
            save_float(out, touch->y);
        } else if (const auto* key = std::get_if<KeyboardInput>(&event.input)) {
            snapshot::save(out, key->usage_page);
            snapshot::save(out, key->usage);
            snapshot::save(out, key->down);
        } else {
            const auto& acceleration = std::get<Acceleration>(event.input);
            save_float(out, acceleration.x);
            save_float(out, acceleration.y);
            save_float(out, acceleration.z);
        }
        snapshot::save(out, event.timestamp);
        snapshot::save(out, event.identity);
    }

    static Event load_event(snapshot::Reader& in)
    {
        std::uint8_t index { };
        snapshot::load(in, index);
        Event event { };
        switch (index) {
        case 0: {
            TouchInput touch { };
            snapshot::load(in, touch.phase);
            load_float(in, touch.x);
            load_float(in, touch.y);
            event.input = touch;
            break;
        }
        case 1: {
            KeyboardInput key { };
            snapshot::load(in, key.usage_page);
            snapshot::load(in, key.usage);
            snapshot::load(in, key.down);
            event.input = key;
            break;
        }
        case 2: {
            Acceleration acceleration { };
            load_float(in, acceleration.x);
            load_float(in, acceleration.y);
            load_float(in, acceleration.z);
            event.input = acceleration;
            break;
        }
        default:
            throw snapshot::FormatError { "snapshot names an unknown HID event" };
        }
        snapshot::load(in, event.timestamp);
        snapshot::load(in, event.identity);
        return event;
    }

    mutable std::mutex mutex_;
    std::optional<Consumer> consumer_;
    std::deque<Event> events_;
};

}
