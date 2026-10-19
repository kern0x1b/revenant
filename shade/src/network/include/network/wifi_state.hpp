// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Maintain virtual wireless link, access-point and IP configuration
// state.

#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <mutex>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

#include "network/virtual_network.hpp"

namespace shade {

inline constexpr auto wifi_interface_mac_address =
    virtual_network::interface_mac_address;

enum class WifiLinkState : std::uint8_t {
    PoweredOff,
    Idle,
    Scanning,
    Associated,
    Configured,
};

enum class WifiSecurity : std::uint8_t {
    Open,
    Wep,
    WpaPersonal,
};

struct VirtualAccessPoint {
    std::string ssid;
    std::array<std::byte, 6> bssid { };
    std::uint16_t channel { };
    std::int32_t rssi { };
    std::uint32_t link_rate_mbps { };
    WifiSecurity security { WifiSecurity::Open };
};

struct WifiIpv4Configuration {
    std::array<std::byte, 4> address { };
    std::array<std::byte, 4> netmask { };
    std::array<std::byte, 4> broadcast { };
    std::array<std::byte, 4> gateway { };
    std::vector<std::array<std::byte, 4>> dns_servers;
};

struct WifiSnapshot {
    WifiLinkState link_state { WifiLinkState::PoweredOff };
    bool powered { };
    bool airplane_mode { };
    std::optional<VirtualAccessPoint> associated_access_point;
    std::optional<WifiIpv4Configuration> ipv4;
};

// User-visible 802.11 state. It intentionally models radio/link and IP
// configuration, not Broadcom registers or an IO80211 hardware data path.
// BSD sockets continue through HostNetwork while SystemConfiguration observes
// this state through en0 and XNU kernel events.
class WifiState {
public:
    WifiState();
    explicit WifiState(std::vector<VirtualAccessPoint> access_points);

    [[nodiscard]] WifiSnapshot snapshot() const;
    [[nodiscard]] std::vector<VirtualAccessPoint> scan();
    void set_preferred_networks(std::vector<std::string> ssids);
    [[nodiscard]] bool set_power(bool powered);
    [[nodiscard]] bool set_airplane_mode(bool enabled);
    [[nodiscard]] bool associate(std::string_view ssid = { });
    [[nodiscard]] bool disassociate();

private:
    [[nodiscard]] static WifiIpv4Configuration default_ipv4_configuration();
    [[nodiscard]] bool auto_join_locked();
    [[nodiscard]] bool associate_locked(std::string_view ssid, bool remember);

    mutable std::mutex mutex_;
    std::vector<VirtualAccessPoint> access_points_;
    std::vector<std::string> preferred_networks_;
    WifiLinkState link_state_ { WifiLinkState::PoweredOff };
    bool airplane_mode_ { };
    bool powered_before_airplane_mode_ { };
    std::optional<std::size_t> associated_index_;
    std::optional<WifiIpv4Configuration> ipv4_;
};

} // namespace shade
