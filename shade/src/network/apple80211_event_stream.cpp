// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Encode virtual wireless-device events using the selected guest
// stream format.

#include "network/apple80211_event_stream.hpp"

#include <algorithm>
#include <limits>

#include "network/darwin_network_abi.hpp"

namespace shade::darwin::network::apple80211_driver {
namespace {

    constexpr std::size_t legacy_bitmask_size = sizeof(std::uint16_t);

    void write32(
        std::vector<std::byte>& bytes, std::size_t offset, std::uint32_t value)
    {
        for (std::size_t byte = 0; byte < sizeof(value); ++byte) {
            bytes[offset + byte] =
                static_cast<std::byte>((value >> (byte * 8U)) & 0xffU);
        }
    }

} // namespace

void EventStream::enqueue(std::uint32_t event)
{
    if (event != 0)
        events_.push_back(event);
}

bool EventStream::readable() const
{
    return record_offset_ < record_.size() || !events_.empty();
}

std::uint32_t EventStream::pending_byte_count() const
{
    if (record_offset_ < record_.size()) {
        return static_cast<std::uint32_t>(record_.size() - record_offset_);
    }
    if (events_.empty())
        return 0;
    return format_ == EventStreamFormat::LegacyBitmask16
               ? static_cast<std::uint32_t>(legacy_bitmask_size)
               : event_header_size;
}

std::string_view EventStream::format_name() const
{
    switch (format_) {
    case EventStreamFormat::LegacyBitmask16:
        return "legacy-bitmask16";
    case EventStreamFormat::FramedRecords:
        return "framed-records";
    case EventStreamFormat::Undetected:
        return "undetected";
    }
    return "undetected";
}

std::span<const std::byte> EventStream::prepare_read(std::size_t capacity)
{
    if (capacity == 0 || !readable())
        return { };
    if (format_ == EventStreamFormat::Undetected) {
        format_ = capacity <= legacy_bitmask_size
                       ? EventStreamFormat::LegacyBitmask16
                       : EventStreamFormat::FramedRecords;
    }
    if (record_offset_ >= record_.size())
        prepare_record();
    const auto pending =
        std::span<const std::byte> { record_ }.subspan(record_offset_);
    return pending.first(std::min(capacity, pending.size()));
}

void EventStream::consume(std::size_t bytes)
{
    const auto remaining = record_.size() - record_offset_;
    record_offset_ += std::min(bytes, remaining);
    if (record_offset_ < record_.size())
        return;
    for (std::size_t event = 0; event < record_event_count_ && !events_.empty();
        ++event) {
        events_.pop_front();
    }
    record_.clear();
    record_offset_ = 0;
    record_event_count_ = 0;
}

void EventStream::prepare_record()
{
    record_.clear();
    record_offset_ = 0;
    record_event_count_ = 0;
    if (events_.empty())
        return;

    if (format_ == EventStreamFormat::LegacyBitmask16) {
        std::uint16_t mask { };
        for (const auto event : events_) {
            if (event <= std::numeric_limits<std::uint16_t>::digits) {
                mask |= static_cast<std::uint16_t>(1U << (event - 1U));
            }
            ++record_event_count_;
        }
        record_ = {
            static_cast<std::byte>(mask & 0xffU),
            static_cast<std::byte>((mask >> 8U) & 0xffU),
        };
        return;
    }

    record_.assign(event_header_size, std::byte { 0 });
    write32(record_, event_identifier_offset, events_.front());
    write32(record_, event_payload_length_offset, 0);
    record_event_count_ = 1;
}

} // namespace shade::darwin::network::apple80211_driver
