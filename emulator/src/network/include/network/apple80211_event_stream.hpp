// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Encode virtual wireless-device events using the selected guest
// stream format.

#pragma once

#include <cstddef>
#include <cstdint>
#include <deque>
#include <span>
#include <string_view>
#include <vector>

namespace emulator::darwin::network::apple80211_driver {

enum class EventStreamFormat : std::uint8_t {
    Undetected,
    LegacyBitmask16,
    FramedRecords,
};

class EventStream {
public:
    void enqueue(std::uint32_t event);

    [[nodiscard]] bool readable() const;
    [[nodiscard]] std::uint32_t pending_byte_count() const;
    [[nodiscard]] EventStreamFormat format() const { return format_; }
    [[nodiscard]] std::string_view format_name() const;

    [[nodiscard]] std::span<const std::byte> prepare_read(std::size_t capacity);
    void consume(std::size_t bytes);

private:
    void prepare_record();

    EventStreamFormat format_ { EventStreamFormat::Undetected };
    std::deque<std::uint32_t> events_;
    std::vector<std::byte> record_;
    std::size_t record_offset_ { };
    std::size_t record_event_count_ { };
};

}
