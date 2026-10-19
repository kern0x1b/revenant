// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Read virtual packet-filter descriptors and encode captured packet
// records.

#include "kernel/kernel.hpp"

#include "kernel/darwin_abi.hpp"
#include "kernel/darwin_bpf_abi.hpp"
#include "network/virtual_network.hpp"

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <mutex>
#include <span>
#include <sstream>
#include <string>
#include <vector>

#include "support.hpp"

namespace shade {
namespace {

    std::string interface_name(std::span<const std::byte> request)
    {
        const auto limit = std::min<std::size_t>(
            request.size(), darwin::bpf::interface_name_size);
        std::string name;
        name.reserve(limit);
        for (std::size_t index = 0; index < limit; ++index) {
            const auto character =
                std::to_integer<unsigned char>(request[index]);
            if (character == 0) {
                break;
            }
            name.push_back(static_cast<char>(character));
        }
        return name;
    }

    constexpr std::size_t ethernet_header_length = 14;
    constexpr std::size_t arp_payload_length = 28;
    constexpr std::size_t ethernet_arp_length =
        ethernet_header_length + arp_payload_length;
    constexpr std::size_t ethernet_destination_offset = 0;
    constexpr std::size_t ethernet_source_offset = 6;
    constexpr std::size_t ethernet_type_offset = 12;
    constexpr std::size_t arp_hardware_type_offset = 0;
    constexpr std::size_t arp_protocol_type_offset = 2;
    constexpr std::size_t arp_hardware_length_offset = 4;
    constexpr std::size_t arp_protocol_length_offset = 5;
    constexpr std::size_t arp_operation_offset = 6;
    constexpr std::size_t arp_sender_hardware_offset = 8;
    constexpr std::size_t arp_sender_protocol_offset = 14;
    constexpr std::size_t arp_target_hardware_offset = 18;
    constexpr std::size_t arp_target_protocol_offset = 24;

    constexpr std::array<std::byte, 6> ethernet_broadcast { std::byte { 0xff },
        std::byte { 0xff }, std::byte { 0xff }, std::byte { 0xff },
        std::byte { 0xff }, std::byte { 0xff } };

    template <std::size_t Size>
    std::array<std::byte, Size> copy_array(
        std::span<const std::byte> bytes, std::size_t offset)
    {
        std::array<std::byte, Size> result { };
        std::copy_n(bytes.begin() + static_cast<std::ptrdiff_t>(offset), Size,
            result.begin());
        return result;
    }

    bool valid_unicast_mac(const virtual_network::MacAddress& address)
    {
        return (std::to_integer<unsigned>(address.front()) & 1U) == 0U &&
               std::any_of(address.begin(), address.end(),
                   [](std::byte value) { return value != std::byte { }; });
    }

    std::uint16_t read_network_u16(
        std::span<const std::byte> bytes, std::size_t offset)
    {
        return static_cast<std::uint16_t>(
            (std::to_integer<std::uint16_t>(bytes[offset]) << 8U) |
            std::to_integer<std::uint16_t>(bytes[offset + 1U]));
    }

    void write_network_u16(
        std::span<std::byte> bytes, std::size_t offset, std::uint16_t value)
    {
        bytes[offset] = static_cast<std::byte>((value >> 8U) & 0xffU);
        bytes[offset + 1U] = static_cast<std::byte>(value & 0xffU);
    }

    void write_arm32_u16(
        std::span<std::byte> bytes, std::size_t offset, std::uint16_t value)
    {
        bytes[offset] = static_cast<std::byte>(value & 0xffU);
        bytes[offset + 1U] = static_cast<std::byte>((value >> 8U) & 0xffU);
    }

    void write_arm32_u32(
        std::span<std::byte> bytes, std::size_t offset, std::uint32_t value)
    {
        for (std::size_t byte = 0; byte < sizeof(value); ++byte) {
            bytes[offset + byte] =
                static_cast<std::byte>((value >> (byte * 8U)) & 0xffU);
        }
    }

    std::size_t arm32_bpf_word_align(std::size_t size)
    {
        constexpr std::size_t alignment = sizeof(std::uint32_t);
        return (size + alignment - 1U) & ~(alignment - 1U);
    }

} // namespace

bool CompatibilityKernel::bpf_descriptor_readable(std::uint32_t fd) const
{
    const auto descriptor = bpf_descriptors_.find(fd);
    if (descriptor == bpf_descriptors_.end() || !descriptor->second) {
        return false;
    }
    const std::lock_guard capture_lock { descriptor->second->capture_mutex };
    return !descriptor->second->capture_queue.empty();
}

bool CompatibilityKernel::receive_bpf_bytes(
    Cpu& cpu, std::uint32_t fd, std::uint32_t address, std::uint32_t size)
{
    const auto descriptor = bpf_descriptors_.find(fd);
    if (descriptor == bpf_descriptors_.end() || !descriptor->second) {
        return false;
    }

    auto& state = *descriptor->second;
    const std::lock_guard capture_lock { state.capture_mutex };
    if (state.capture_queue.empty()) {
        return false;
    }

    std::vector<std::byte> capture;
    std::size_t packet_count = 0;
    for (const auto& packet : state.capture_queue) {
        const auto record_length = arm32_bpf_word_align(
            darwin::bpf::arm32_capture_header_length + packet.frame.size());
        if (record_length > std::numeric_limits<std::uint32_t>::max() ||
            record_length >
                size - std::min<std::size_t>(size, capture.size())) {
            break;
        }

        const auto record_offset = capture.size();
        capture.resize(record_offset + record_length);
        auto record =
            std::span { capture }.subspan(record_offset, record_length);
        constexpr std::uint64_t nanoseconds_per_second = 1'000'000'000ULL;
        constexpr std::uint64_t nanoseconds_per_microsecond = 1'000ULL;
        const auto seconds =
            packet.timestamp_nanoseconds / nanoseconds_per_second;
        const auto microseconds =
            (packet.timestamp_nanoseconds % nanoseconds_per_second) /
            nanoseconds_per_microsecond;
        const auto frame_length =
            static_cast<std::uint32_t>(packet.frame.size());
        write_arm32_u32(record, 0, static_cast<std::uint32_t>(seconds));
        write_arm32_u32(record, 4, static_cast<std::uint32_t>(microseconds));
        write_arm32_u32(record, 8, frame_length);
        write_arm32_u32(record, 12, frame_length);
        write_arm32_u16(record, 16,
            static_cast<std::uint16_t>(
                darwin::bpf::arm32_capture_header_length));
        std::copy(packet.frame.begin(), packet.frame.end(),
            record.begin() + static_cast<std::ptrdiff_t>(
                                 darwin::bpf::arm32_capture_header_length));
        ++packet_count;
    }

    if (capture.empty()) {
        bsd_error(cpu, darwin::error::invalid_argument);
        return true;
    }
    if (!memory_.copy_in(address, capture)) {
        bsd_error(cpu, bsd_support::bad_address);
        return true;
    }
    while (packet_count-- != 0U) {
        state.capture_queue.pop_front();
    }
    bsd_success(cpu, static_cast<std::uint32_t>(capture.size()));
    return true;
}

bool CompatibilityKernel::write_bpf_bytes(
    Cpu& cpu, std::uint32_t fd, std::uint32_t address, std::uint32_t size)
{
    const auto descriptor = bpf_descriptors_.find(fd);
    if (descriptor == bpf_descriptors_.end() || !descriptor->second) {
        bsd_error(cpu, bsd_support::bad_file_descriptor);
        return true;
    }
    if (size > bsd_support::maximum_io) {
        bsd_error(cpu, bsd_support::invalid_argument);
        return true;
    }
    const auto frame = memory_.read_bytes(address, size);
    if (!frame) {
        bsd_error(cpu, bsd_support::bad_address);
        return true;
    }
    if (frame->empty()) {
        bsd_success(cpu, 0);
        return true;
    }

    std::string attached_interface;
    bool header_complete = false;
    {
        const std::lock_guard capture_lock {
            descriptor->second->capture_mutex
        };
        attached_interface = descriptor->second->interface_name;
        header_complete = descriptor->second->header_complete;
    }
    KernelSharedState::NetworkInterface interface;
    {
        const std::lock_guard network_lock { shared_state_->network_mutex };
        const auto found =
            shared_state_->network_interfaces.find(attached_interface);
        if (attached_interface.empty() ||
            found == shared_state_->network_interfaces.end()) {
            bsd_error(cpu, darwin::error::no_such_device_or_address);
            return true;
        }
        interface = found->second;
    }

    const auto bytes = std::span<const std::byte> { *frame };
    const auto complete_ethernet_frame = bytes.size() >= ethernet_arp_length;
    const auto arp_payload_only = bytes.size() == arp_payload_length;
    if (!complete_ethernet_frame && !arp_payload_only) {
        bsd_success(cpu, size);
        return true;
    }
    const auto arp_offset =
        complete_ethernet_frame ? ethernet_header_length : 0U;
    const auto arp = bytes.subspan(arp_offset, arp_payload_length);
    if ((complete_ethernet_frame &&
            read_network_u16(bytes, ethernet_type_offset) != 0x0806U) ||
        read_network_u16(arp, arp_hardware_type_offset) != 1U ||
        read_network_u16(arp, arp_protocol_type_offset) != 0x0800U ||
        arp[arp_hardware_length_offset] != std::byte { 6 } ||
        arp[arp_protocol_length_offset] != std::byte { 4 } ||
        read_network_u16(arp, arp_operation_offset) != 1U) {
        bsd_success(cpu, size);
        return true;
    }

    const auto sender_mac = copy_array<6>(arp, arp_sender_hardware_offset);
    const auto sender_ip = copy_array<4>(arp, arp_sender_protocol_offset);
    const auto target_ip = copy_array<4>(arp, arp_target_protocol_offset);
    const auto neighbor = std::find_if(virtual_network::ipv4_neighbors.begin(),
        virtual_network::ipv4_neighbors.end(),
        [&](const auto& candidate) { return candidate.address == target_ip; });
    if (neighbor == virtual_network::ipv4_neighbors.end() ||
        interface.link_address_length != sender_mac.size() ||
        sender_mac != interface.link_address ||
        !valid_unicast_mac(sender_mac)) {
        bsd_success(cpu, size);
        return true;
    }

    if (complete_ethernet_frame) {
        const auto destination =
            copy_array<6>(bytes, ethernet_destination_offset);
        const auto source = copy_array<6>(bytes, ethernet_source_offset);
        const auto valid_destination = destination == ethernet_broadcast ||
                                       destination == neighbor->mac_address;
        const auto valid_source =
            header_complete ? source == sender_mac
                            : (source == sender_mac ||
                                  std::all_of(source.begin(), source.end(),
                                      [](std::byte value) {
                                          return value == std::byte { };
                                      }));
        if (!valid_destination || !valid_source) {
            bsd_success(cpu, size);
            return true;
        }
    }

    std::vector<std::byte> reply(ethernet_arp_length);
    auto reply_bytes = std::span { reply };
    std::copy(sender_mac.begin(), sender_mac.end(),
        reply.begin() + ethernet_destination_offset);
    std::copy(neighbor->mac_address.begin(), neighbor->mac_address.end(),
        reply.begin() + ethernet_source_offset);
    write_network_u16(reply_bytes, ethernet_type_offset, 0x0806U);
    auto reply_arp =
        reply_bytes.subspan(ethernet_header_length, arp_payload_length);
    write_network_u16(reply_arp, arp_hardware_type_offset, 1U);
    write_network_u16(reply_arp, arp_protocol_type_offset, 0x0800U);
    reply_arp[arp_hardware_length_offset] = std::byte { 6 };
    reply_arp[arp_protocol_length_offset] = std::byte { 4 };
    write_network_u16(reply_arp, arp_operation_offset, 2U);
    std::copy(neighbor->mac_address.begin(), neighbor->mac_address.end(),
        reply_arp.begin() + arp_sender_hardware_offset);
    std::copy(neighbor->address.begin(), neighbor->address.end(),
        reply_arp.begin() + arp_sender_protocol_offset);
    std::copy(sender_mac.begin(), sender_mac.end(),
        reply_arp.begin() + arp_target_hardware_offset);
    std::copy(sender_ip.begin(), sender_ip.end(),
        reply_arp.begin() + arp_target_protocol_offset);

    const auto timestamp = shared_state_->clock.wall_time();
    {
        auto& capture_state = *descriptor->second;
        const std::lock_guard capture_lock { capture_state.capture_mutex };
        if (capture_state.interface_name == attached_interface) {
            ++capture_state.received_packets;
            if (capture_state.capture_queue.size() >=
                darwin::bpf::maximum_queued_packets) {
                ++capture_state.dropped_packets;
            } else {
                capture_state.capture_queue.push_back(
                    darwin::bpf::CapturePacket { timestamp, std::move(reply) });
            }
        }
    }

    bsd_success(cpu, size);
    return true;
}

bool CompatibilityKernel::ioctl_bpf_device(Cpu& cpu, std::uint32_t fd)
{
    const auto descriptor = bpf_descriptors_.find(fd);
    if (descriptor == bpf_descriptors_.end()) {
        return false;
    }

    auto& registers = cpu.registers();
    const auto request = registers[1];
    const auto argument = registers[2];
    auto& state = *descriptor->second;
    const auto read_scalar = [&]() { return memory_.read32(argument); };
    const auto write_scalar = [&](std::uint32_t value) {
        return memory_.write32(argument, value);
    };
    const auto apply_filter = [&]() {
        const auto length = memory_.read32(argument);
        const auto instructions = memory_.read32(argument + 4U);
        if (!length || !instructions) {
            bsd_error(cpu, bsd_support::bad_address);
            return false;
        }
        if (*length > darwin::bpf::maximum_filter_instructions) {
            bsd_error(cpu, darwin::error::invalid_argument);
            return false;
        }
        if (*length != 0U && !memory_.read_bytes(*instructions,
                                 static_cast<std::size_t>(*length) *
                                     darwin::bpf::filter_instruction_size)) {
            bsd_error(cpu, bsd_support::bad_address);
            return false;
        }
        bsd_success(cpu, 0);
        return true;
    };

    switch (request) {
    case darwin::bpf::get_buffer_length: {
        std::uint32_t buffer_length = 0;
        {
            const std::lock_guard capture_lock { state.capture_mutex };
            buffer_length = state.buffer_length;
        }
        if (!write_scalar(buffer_length)) {
            bsd_error(cpu, bsd_support::bad_address);
        } else {
            bsd_success(cpu, 0);
        }
        return true;
    }
    case darwin::bpf::set_buffer_length: {
        const auto requested = read_scalar();
        if (!requested) {
            bsd_error(cpu, bsd_support::bad_address);
            return true;
        }
        if (*requested < darwin::bpf::minimum_buffer_length ||
            *requested > darwin::bpf::maximum_buffer_length) {
            bsd_error(cpu, darwin::error::invalid_argument);
            return true;
        }
        {
            const std::lock_guard capture_lock { state.capture_mutex };
            state.buffer_length = *requested;
        }
        if (!write_scalar(*requested)) {
            bsd_error(cpu, bsd_support::bad_address);
        } else {
            bsd_success(cpu, 0);
        }
        return true;
    }
    case darwin::bpf::set_filter:
        if (apply_filter()) {
            const std::lock_guard capture_lock { state.capture_mutex };
            state.capture_queue.clear();
        }
        return true;
    case darwin::bpf::set_filter_without_reset:
        apply_filter();
        return true;
    case darwin::bpf::flush: {
        const std::lock_guard capture_lock { state.capture_mutex };
        state.capture_queue.clear();
        bsd_success(cpu, 0);
        return true;
    }
    case darwin::bpf::promiscuous:
        bsd_success(cpu, 0);
        return true;
    case darwin::bpf::get_data_link_type:
        if (!write_scalar(darwin::bpf::data_link_ethernet)) {
            bsd_error(cpu, bsd_support::bad_address);
        } else {
            bsd_success(cpu, 0);
        }
        return true;
    case darwin::bpf::get_interface: {
        std::string attached_interface;
        {
            const std::lock_guard capture_lock { state.capture_mutex };
            attached_interface = state.interface_name;
        }
        std::vector<std::byte> request_bytes(
            darwin::bpf::interface_request_size);
        const auto count = std::min<std::size_t>(
            attached_interface.size(), darwin::bpf::interface_name_size - 1U);
        std::transform(attached_interface.begin(),
            attached_interface.begin() + static_cast<std::ptrdiff_t>(count),
            request_bytes.begin(),
            [](char value) { return static_cast<std::byte>(value); });
        if (!memory_.copy_in(argument, request_bytes)) {
            bsd_error(cpu, bsd_support::bad_address);
        } else {
            bsd_success(cpu, 0);
        }
        return true;
    }
    case darwin::bpf::set_interface: {
        const auto request_bytes =
            memory_.read_bytes(argument, darwin::bpf::interface_request_size);
        if (!request_bytes) {
            bsd_error(cpu, bsd_support::bad_address);
            return true;
        }
        const auto name = interface_name(*request_bytes);
        if (name.empty()) {
            bsd_error(cpu, darwin::error::invalid_argument);
            return true;
        }
        {
            const std::lock_guard network_lock { shared_state_->network_mutex };
            if (!shared_state_->network_interfaces.contains(name)) {
                bsd_error(cpu, darwin::error::no_such_device_or_address);
                return true;
            }
        }
        {
            const std::lock_guard capture_lock { state.capture_mutex };
            state.interface_name = name;
            state.capture_queue.clear();
        }
        bsd_success(cpu, 0);
        return true;
    }
    case darwin::bpf::set_read_timeout: {
        const auto seconds = memory_.read32(argument);
        const auto microseconds = memory_.read32(argument + 4U);
        if (!seconds || !microseconds) {
            bsd_error(cpu, bsd_support::bad_address);
            return true;
        }
        if (static_cast<std::int32_t>(*seconds) < 0 ||
            *microseconds >= 1'000'000U) {
            bsd_error(cpu, darwin::error::invalid_argument);
            return true;
        }
        {
            const std::lock_guard capture_lock { state.capture_mutex };
            state.read_timeout_seconds = *seconds;
            state.read_timeout_microseconds = *microseconds;
        }
        bsd_success(cpu, 0);
        return true;
    }
    case darwin::bpf::get_read_timeout: {
        std::uint32_t seconds = 0;
        std::uint32_t microseconds = 0;
        {
            const std::lock_guard capture_lock { state.capture_mutex };
            seconds = state.read_timeout_seconds;
            microseconds = state.read_timeout_microseconds;
        }
        if (!memory_.write32(argument, seconds) ||
            !memory_.write32(argument + 4U, microseconds)) {
            bsd_error(cpu, bsd_support::bad_address);
        } else {
            bsd_success(cpu, 0);
        }
        return true;
    }
    case darwin::bpf::get_statistics: {
        std::uint32_t received = 0;
        std::uint32_t dropped = 0;
        {
            const std::lock_guard capture_lock { state.capture_mutex };
            received = state.received_packets;
            dropped = state.dropped_packets;
        }
        if (!memory_.write32(argument, received) ||
            !memory_.write32(argument + 4U, dropped)) {
            bsd_error(cpu, bsd_support::bad_address);
        } else {
            bsd_success(cpu, 0);
        }
        return true;
    }
    case darwin::bpf::set_immediate:
    case darwin::bpf::set_header_complete:
    case darwin::bpf::set_see_sent: {
        const auto enabled = read_scalar();
        if (!enabled) {
            bsd_error(cpu, bsd_support::bad_address);
            return true;
        }
        {
            const std::lock_guard capture_lock { state.capture_mutex };
            if (request == darwin::bpf::set_immediate) {
                state.immediate = *enabled != 0;
            } else if (request == darwin::bpf::set_header_complete) {
                state.header_complete = *enabled != 0;
            } else {
                state.see_sent = *enabled != 0;
            }
        }
        bsd_success(cpu, 0);
        return true;
    }
    case darwin::bpf::get_header_complete:
    case darwin::bpf::get_see_sent: {
        bool enabled = false;
        {
            const std::lock_guard capture_lock { state.capture_mutex };
            enabled = request == darwin::bpf::get_header_complete
                          ? state.header_complete
                          : state.see_sent;
        }
        if (!write_scalar(enabled ? 1U : 0U)) {
            bsd_error(cpu, bsd_support::bad_address);
        } else {
            bsd_success(cpu, 0);
        }
        return true;
    }
    case darwin::bpf::get_version:
        if (!memory_.write16(argument, darwin::bpf::filter_major_version) ||
            !memory_.write16(
                argument + 2U, darwin::bpf::filter_minor_version)) {
            bsd_error(cpu, bsd_support::bad_address);
        } else {
            bsd_success(cpu, 0);
        }
        return true;
    case darwin::bpf::get_signal: {
        std::uint32_t signal = 0;
        {
            const std::lock_guard capture_lock { state.capture_mutex };
            signal = state.signal;
        }
        if (!write_scalar(signal)) {
            bsd_error(cpu, bsd_support::bad_address);
        } else {
            bsd_success(cpu, 0);
        }
        return true;
    }
    case darwin::bpf::set_signal: {
        const auto signal = read_scalar();
        if (!signal) {
            bsd_error(cpu, bsd_support::bad_address);
        } else {
            {
                const std::lock_guard capture_lock { state.capture_mutex };
                state.signal = *signal;
            }
            bsd_success(cpu, 0);
        }
        return true;
    }
    case darwin::bpf::set_data_link_type: {
        const auto data_link_type = read_scalar();
        if (!data_link_type) {
            bsd_error(cpu, bsd_support::bad_address);
        } else if (*data_link_type != darwin::bpf::data_link_ethernet) {
            bsd_error(cpu, darwin::error::invalid_argument);
        } else {
            bsd_success(cpu, 0);
        }
        return true;
    }
    case darwin::bpf::get_data_link_type_list: {
        const auto capacity = memory_.read32(argument);
        const auto list = memory_.read32(argument + 4U);
        if (!capacity || !list) {
            bsd_error(cpu, bsd_support::bad_address);
            return true;
        }
        if (*capacity != 0U &&
            !memory_.write32(*list, darwin::bpf::data_link_ethernet)) {
            bsd_error(cpu, bsd_support::bad_address);
            return true;
        }
        if (!memory_.write32(argument, 1U)) {
            bsd_error(cpu, bsd_support::bad_address);
        } else {
            bsd_success(cpu, 0);
        }
        return true;
    }
    default: {
        std::ostringstream message;
        message << "[bpf] unsupported ioctl 0x" << std::hex << request << '\n';
        output_.write(message.str());
        bsd_error(cpu, darwin::error::inappropriate_ioctl);
        return true;
    }
    }
}

} // namespace shade
