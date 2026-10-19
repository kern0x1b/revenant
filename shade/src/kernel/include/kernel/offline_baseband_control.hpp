// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Parse local modem configuration commands for the offline baseband
// endpoint.

#pragma once

#include <cstddef>
#include <cstdint>
#include <map>
#include <span>
#include <string>
#include <vector>

namespace shade::bsd::baseband_device {

// Minimal command plane retained by an Offline serial-multiplexer endpoint.
// It acknowledges complete AT command lines without inventing radio state or
// unsolicited modem traffic.
class OfflineControlPlane {
public:
    [[nodiscard]] std::vector<std::byte> consume(
        std::uint32_t channel, std::span<const std::byte> bytes);
    void reset();
    void reset(std::uint32_t channel);

private:
    std::map<std::uint32_t, std::string> lines_;
};

} // namespace shade::bsd::baseband_device
