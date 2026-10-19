// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Maintain virtual wireless link, access-point and IP configuration
// state.

#include "network/wifi_state.hpp"

#include "network/virtual_network.hpp"

#include <algorithm>
#include <utility>

namespace shade {
namespace {

    std::vector<VirtualAccessPoint> default_access_points()
    {
        return { {
            std::string { virtual_network::access_point_ssid },
            { std::byte { 0x02 }, std::byte { 0x1a }, std::byte { 0x54 },
                std::byte { 0x3a }, std::byte { 0x00 }, std::byte { 0x01 } },
            virtual_network::access_point_channel,
            -32,
            54,
            WifiSecurity::Open,
        } };
    }

} // namespace

WifiState::WifiState()
    : WifiState { default_access_points() }
{
}

WifiState::WifiState(std::vector<VirtualAccessPoint> access_points)
    : access_points_ { std::move(access_points) }
{
}

WifiSnapshot WifiState::snapshot() const
{
    std::lock_guard lock { mutex_ };
    WifiSnapshot result;
    result.link_state = link_state_;
    result.powered = link_state_ != WifiLinkState::PoweredOff;
    result.airplane_mode = airplane_mode_;
    if (associated_index_ && *associated_index_ < access_points_.size()) {
        result.associated_access_point = access_points_[*associated_index_];
    }
    result.ipv4 = ipv4_;
    return result;
}

std::vector<VirtualAccessPoint> WifiState::scan()
{
    std::lock_guard lock { mutex_ };
    if (link_state_ == WifiLinkState::PoweredOff)
        return { };
    const auto previous = link_state_;
    link_state_ = WifiLinkState::Scanning;
    const auto result = access_points_;
    link_state_ =
        previous == WifiLinkState::Scanning ? WifiLinkState::Idle : previous;
    return result;
}

void WifiState::set_preferred_networks(std::vector<std::string> ssids)
{
    std::lock_guard lock { mutex_ };
    preferred_networks_.clear();
    preferred_networks_.reserve(ssids.size());
    for (auto& ssid : ssids) {
        if (ssid.empty() ||
            std::find(preferred_networks_.begin(), preferred_networks_.end(),
                ssid) != preferred_networks_.end()) {
            continue;
        }
        preferred_networks_.push_back(std::move(ssid));
    }
}

bool WifiState::set_power(bool powered)
{
    std::lock_guard lock { mutex_ };
    if (!powered) {
        const auto changed = link_state_ != WifiLinkState::PoweredOff;
        link_state_ = WifiLinkState::PoweredOff;
        associated_index_.reset();
        ipv4_.reset();
        return changed;
    }
    if (airplane_mode_)
        return false;
    if (link_state_ != WifiLinkState::PoweredOff)
        return false;
    link_state_ = WifiLinkState::Idle;
    static_cast<void>(auto_join_locked());
    return true;
}

bool WifiState::set_airplane_mode(bool enabled)
{
    std::lock_guard lock { mutex_ };
    const auto changed = airplane_mode_ != enabled;
    if (!changed)
        return false;
    if (enabled) {
        powered_before_airplane_mode_ =
            link_state_ != WifiLinkState::PoweredOff;
    }
    airplane_mode_ = enabled;
    if (enabled) {
        link_state_ = WifiLinkState::PoweredOff;
        associated_index_.reset();
        ipv4_.reset();
    } else if (powered_before_airplane_mode_) {
        link_state_ = WifiLinkState::Idle;
        static_cast<void>(auto_join_locked());
    }
    return changed;
}

bool WifiState::associate(std::string_view ssid)
{
    std::lock_guard lock { mutex_ };
    return associate_locked(ssid, true);
}

bool WifiState::associate_locked(std::string_view ssid, bool remember)
{
    if (link_state_ == WifiLinkState::PoweredOff)
        return false;
    const auto found = std::find_if(access_points_.begin(),
        access_points_.end(), [&](const VirtualAccessPoint& access_point) {
            return ssid.empty() || access_point.ssid == ssid;
        });
    if (found == access_points_.end())
        return false;
    if (remember &&
        std::find(preferred_networks_.begin(), preferred_networks_.end(),
            found->ssid) == preferred_networks_.end()) {
        preferred_networks_.push_back(found->ssid);
    }
    associated_index_ =
        static_cast<std::size_t>(std::distance(access_points_.begin(), found));
    link_state_ = WifiLinkState::Associated;
    // The virtual network is always locally available. DHCP completion is
    // deterministic so the 2007 SystemConfiguration client does not depend on
    // host Wi-Fi hardware or timing.
    ipv4_ = default_ipv4_configuration();
    link_state_ = WifiLinkState::Configured;
    return true;
}

bool WifiState::auto_join_locked()
{
    for (const auto& ssid : preferred_networks_) {
        if (associate_locked(ssid, false))
            return true;
    }
    return false;
}

bool WifiState::disassociate()
{
    std::lock_guard lock { mutex_ };
    if (link_state_ == WifiLinkState::PoweredOff)
        return false;
    const auto changed = associated_index_.has_value() || ipv4_.has_value();
    associated_index_.reset();
    ipv4_.reset();
    link_state_ = WifiLinkState::Idle;
    return changed;
}

WifiIpv4Configuration WifiState::default_ipv4_configuration()
{
    WifiIpv4Configuration result;
    result.address = virtual_network::client_address;
    result.netmask = virtual_network::netmask;
    result.broadcast = virtual_network::broadcast_address;
    result.gateway = virtual_network::gateway_address;
    result.dns_servers.push_back(virtual_network::dns_proxy_address);
    return result;
}

} // namespace shade
