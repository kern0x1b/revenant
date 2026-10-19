// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Implement virtual serial attributes, buffered reads and offline
// controller replies.

#include "kernel/offline_serial_device.hpp"

#include <algorithm>
#include <array>
#include <cstddef>
#include <mutex>
#include <utility>

namespace shade::bsd::offline_serial_device {
namespace {

    constexpr std::byte h4_command_packet { 0x01 };
    constexpr std::byte h4_event_packet { 0x04 };
    constexpr std::byte command_complete_event { 0x0e };
    constexpr std::byte vendor_event { 0xff };
    constexpr std::byte hardware_failure_status { 0x03 };
    constexpr std::byte bccmd_unknown_variable_status { 0x01 };
    constexpr std::size_t command_header_size = 4;
    constexpr std::size_t maximum_command_size = 259;

} // namespace

darwin::tty::Arm32Attributes State::attributes() const
{
    const std::lock_guard lock { mutex_ };
    return attributes_;
}

void State::set_attributes(const darwin::tty::Arm32Attributes& attributes)
{
    const std::lock_guard lock { mutex_ };
    attributes_ = attributes;
}

void State::inherit_configuration(const State& parent)
{
    set_attributes(parent.attributes());
}

std::size_t State::write(std::span<const std::byte> bytes)
{
    const std::lock_guard lock { mutex_ };
    for (const auto byte : bytes) {
        consume_h4_byte(byte);
    }
    return bytes.size();
}

std::vector<std::byte> State::read(std::size_t maximum)
{
    const std::lock_guard lock { mutex_ };
    const auto count = std::min(maximum, receive_queue_.size());
    std::vector<std::byte> bytes;
    bytes.reserve(count);
    for (std::size_t index = 0; index < count; ++index) {
        bytes.push_back(receive_queue_.front());
        receive_queue_.pop_front();
    }
    return bytes;
}

std::size_t State::pending_bytes() const
{
    const std::lock_guard lock { mutex_ };
    return receive_queue_.size();
}

void State::consume_h4_byte(std::byte value)
{
    if (command_.empty()) {
        if (value == h4_command_packet) {
            command_.push_back(value);
        }
        return;
    }

    command_.push_back(value);
    if (command_.size() < command_header_size) {
        return;
    }
    const auto parameter_length = std::to_integer<std::uint8_t>(command_[3]);
    const auto command_size = command_header_size + parameter_length;
    if (command_size > maximum_command_size || command_.size() > command_size) {
        command_.clear();
        return;
    }
    if (command_.size() != command_size) {
        return;
    }

    const auto csr_bccmd = command_[1] == std::byte { 0x00 } &&
                           command_[2] == std::byte { 0xfc } &&
                           parameter_length >= 11;
    if (csr_bccmd) {
        // CSR BCCMD replies use a vendor event rather than Command Complete.
        // Mirror the request envelope, turn REQ into RESP, and report an
        // unknown variable. The guest retains ownership of policy and exits its
        // command path immediately instead of waiting for a controller that is
        // absent.
        std::vector<std::byte> response(3U + parameter_length);
        response[0] = h4_event_packet;
        response[1] = vendor_event;
        response[2] = static_cast<std::byte>(parameter_length);
        response[3] = vendor_event;
        response[4] = static_cast<std::byte>(
            std::to_integer<std::uint8_t>(command_[5]) + 1U);
        for (std::size_t index = 2; index < parameter_length; ++index) {
            response[3U + index] = command_[4U + index];
        }
        response[12] = bccmd_unknown_variable_status;
        response[13] = std::byte { 0x00 };
        receive_queue_.insert(
            receive_queue_.end(), response.begin(), response.end());
    } else {
        // H4 Command Complete: one command packet may continue, original
        // opcode, and a standard HCI Hardware Failure status.
        const std::array response { h4_event_packet, command_complete_event,
            std::byte { 0x04 }, std::byte { 0x01 }, command_[1], command_[2],
            hardware_failure_status };
        receive_queue_.insert(
            receive_queue_.end(), response.begin(), response.end());
    }
    command_.clear();
}

bool is_path(std::string_view candidate)
{
    // This is the stable hardware ABI exposed by the device family, not a
    // process or firmware-version check.
    return candidate == "/dev/cu.bluetooth";
}

} // namespace shade::bsd::offline_serial_device
