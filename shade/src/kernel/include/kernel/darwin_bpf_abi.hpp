// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define guest Berkeley Packet Filter ioctl commands and packet
// header layouts.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/net/bpf.h

#pragma once

#include <cstddef>
#include <cstdint>
#include <deque>
#include <mutex>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

namespace shade::darwin::bpf {

// Darwin 8 / XNU Berkeley Packet Filter ABI. The target firmware is
// ARM32, so pointers, timeval, ifreq and bpf_program use 32-bit layouts.
inline constexpr std::string_view descriptor_kind { "bpf" };
inline constexpr std::string_view device_prefix { "/dev/bpf" };
inline constexpr std::uint32_t maximum_device_minor = 255;
inline constexpr std::uint32_t default_buffer_length = 4'096;
inline constexpr std::uint32_t minimum_buffer_length = 32;
inline constexpr std::uint32_t maximum_buffer_length = 0x8'0000;
inline constexpr std::uint32_t maximum_filter_instructions = 512;
inline constexpr std::uint32_t filter_instruction_size = 8;
inline constexpr std::uint32_t arm32_capture_header_length = 20;
inline constexpr std::size_t maximum_queued_packets = 64;
inline constexpr std::uint32_t interface_request_size = 32;
inline constexpr std::uint32_t interface_name_size = 16;
inline constexpr std::uint32_t data_link_ethernet = 1;
inline constexpr std::uint16_t filter_major_version = 1;
inline constexpr std::uint16_t filter_minor_version = 1;

inline constexpr std::uint32_t get_buffer_length = 0x4004'4266U;
inline constexpr std::uint32_t set_buffer_length = 0xc004'4266U;
inline constexpr std::uint32_t set_filter = 0x8008'4267U;
inline constexpr std::uint32_t flush = 0x2000'4268U;
inline constexpr std::uint32_t promiscuous = 0x2000'4269U;
inline constexpr std::uint32_t get_data_link_type = 0x4004'426aU;
inline constexpr std::uint32_t get_interface = 0x4020'426bU;
inline constexpr std::uint32_t set_interface = 0x8020'426cU;
inline constexpr std::uint32_t set_read_timeout = 0x8008'426dU;
inline constexpr std::uint32_t get_read_timeout = 0x4008'426eU;
inline constexpr std::uint32_t get_statistics = 0x4008'426fU;
inline constexpr std::uint32_t set_immediate = 0x8004'4270U;
inline constexpr std::uint32_t get_version = 0x4004'4271U;
inline constexpr std::uint32_t get_signal = 0x4004'4272U;
inline constexpr std::uint32_t set_signal = 0x8004'4273U;
inline constexpr std::uint32_t get_header_complete = 0x4004'4274U;
inline constexpr std::uint32_t set_header_complete = 0x8004'4275U;
inline constexpr std::uint32_t get_see_sent = 0x4004'4276U;
inline constexpr std::uint32_t set_see_sent = 0x8004'4277U;
inline constexpr std::uint32_t set_data_link_type = 0x8004'4278U;
inline constexpr std::uint32_t get_data_link_type_list = 0xc008'4279U;
inline constexpr std::uint32_t set_filter_without_reset = 0x8008'427eU;

struct CapturePacket {
    std::uint64_t timestamp_nanoseconds { };
    std::vector<std::byte> frame;
};

struct DescriptorState {
    std::uint32_t minor { };
    std::uint32_t buffer_length { default_buffer_length };
    std::string interface_name;
    std::uint32_t read_timeout_seconds { };
    std::uint32_t read_timeout_microseconds { };
    std::uint32_t signal { };
    bool immediate { };
    bool header_complete { };
    bool see_sent { true };
    mutable std::mutex capture_mutex;
    std::deque<CapturePacket> capture_queue;
    std::uint32_t received_packets { };
    std::uint32_t dropped_packets { };
};

[[nodiscard]] inline std::optional<std::uint32_t> device_minor(
    std::string_view path)
{
    if (!path.starts_with(device_prefix) ||
        path.size() == device_prefix.size()) {
        return std::nullopt;
    }
    std::uint32_t minor = 0;
    for (const auto character : path.substr(device_prefix.size())) {
        if (character < '0' || character > '9') {
            return std::nullopt;
        }
        minor = minor * 10U + static_cast<std::uint32_t>(character - '0');
        if (minor > maximum_device_minor) {
            return std::nullopt;
        }
    }
    return minor;
}

} // namespace shade::darwin::bpf
