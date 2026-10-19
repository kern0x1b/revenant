// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Maintain writable guest SystemConfiguration preferences for the
// virtual network.

#pragma once

#include <array>
#include <cstddef>
#include <filesystem>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

namespace shade {

struct NetworkPreferencesResult {
    std::filesystem::path path;
    std::string service_identifier;
    std::vector<std::string> preferred_wifi_networks;
    bool supported { };
    bool changed { };
};

struct NetworkPreferencesIpv4 {
    std::array<std::byte, 4> address { };
    std::array<std::byte, 4> netmask { };
    std::array<std::byte, 4> gateway { };
    std::vector<std::array<std::byte, 4>> dns_servers;
};

struct NetworkPreferencesAirport {
    std::string_view interface_name;
    std::array<std::byte, 6> mac_address { };
    NetworkPreferencesIpv4 ipv4;
};

// Ensures that the simulated device's writable SystemConfiguration state has
// a current network set. When an interface is available, also installs its
// standard AirPort service and supplies missing legacy Wi-Fi capability
// defaults. This is a one-shot compatibility migration for root filesystems
// whose /var state predates the virtual network; normal guest
// SystemConfiguration code owns the files after boot.
[[nodiscard]] NetworkPreferencesResult ensure_network_preferences(
    const std::filesystem::path& rootfs,
    std::optional<NetworkPreferencesAirport> airport = std::nullopt);

} // namespace shade
