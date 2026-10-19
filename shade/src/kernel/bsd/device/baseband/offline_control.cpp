// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Parse local modem configuration commands for the offline baseband
// endpoint.

#include "kernel/offline_baseband_control.hpp"

#include <algorithm>
#include <cctype>
#include <string_view>

namespace shade::bsd::baseband_device {
namespace {

    constexpr std::size_t maximum_command_size = 256U;
    constexpr std::string_view success_response { "\r\nOK\r\n" };

    std::string uppercase(std::string_view value)
    {
        std::string result { value };
        std::transform(result.begin(), result.end(), result.begin(), [](char c) {
            return static_cast<char>(
                std::toupper(static_cast<unsigned char>(c)));
        });
        return result;
    }

    void append(std::vector<std::byte>& destination, std::string_view value)
    {
        destination.reserve(destination.size() + value.size());
        for (const auto character : value) {
            destination.push_back(
                static_cast<std::byte>(static_cast<unsigned char>(character)));
        }
    }

} // namespace

std::vector<std::byte> OfflineControlPlane::consume(
    std::uint32_t channel, std::span<const std::byte> bytes)
{
    auto& line = lines_[channel];
    std::vector<std::byte> response;
    for (const auto byte : bytes) {
        const auto character =
            static_cast<char>(std::to_integer<unsigned char>(byte));
        if (character != '\r' && character != '\n') {
            if (line.size() < maximum_command_size)
                line.push_back(character);
            continue;
        }
        if (line.empty())
            continue;
        const auto command = uppercase(line);
        line.clear();
        // The Offline endpoint accepts complete local modem configuration
        // lines, but never invents query payloads or unsolicited radio state.
        // A bare final result is enough for the firmware to finish transport
        // setup and then consume the existing CoreTelephony Offline profile.
        if (command.starts_with("AT")) {
            append(response, success_response);
        }
    }
    return response;
}

void OfflineControlPlane::reset() { lines_.clear(); }

void OfflineControlPlane::reset(std::uint32_t channel) { lines_.erase(channel); }

} // namespace shade::bsd::baseband_device
