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

namespace emulator {
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

    void save_access_point(
        snapshot::Writer& out, const VirtualAccessPoint& point)
    {
        snapshot::save(out, point.ssid);
        out.raw(point.bssid);
        snapshot::save(out, point.channel);
        snapshot::save(out, point.rssi);
        snapshot::save(out, point.link_rate_mbps);
        snapshot::save(out, point.security);
    }

    VirtualAccessPoint load_access_point(snapshot::Reader& in)
    {
        VirtualAccessPoint point;
        snapshot::load(in, point.ssid);
        const auto bssid = in.raw(point.bssid.size());
        std::copy(bssid.begin(), bssid.end(), point.bssid.begin());
        snapshot::load(in, point.channel);
        snapshot::load(in, point.rssi);
        snapshot::load(in, point.link_rate_mbps);
        snapshot::load(in, point.security);
        return point;
    }

    bool same_access_point(
        const VirtualAccessPoint& left, const VirtualAccessPoint& right)
    {
        return left.ssid == right.ssid && left.bssid == right.bssid &&
               left.channel == right.channel && left.rssi == right.rssi &&
               left.link_rate_mbps == right.link_rate_mbps &&
               left.security == right.security;
    }

    void save_ipv4(snapshot::Writer& out, const WifiIpv4Configuration& ipv4)
    {
        snapshot::save(out, ipv4.address);
        snapshot::save(out, ipv4.netmask);
        snapshot::save(out, ipv4.broadcast);
        snapshot::save(out, ipv4.gateway);
        snapshot::save(out, ipv4.dns_servers);
    }

    WifiIpv4Configuration load_ipv4(snapshot::Reader& in)
    {
        WifiIpv4Configuration ipv4;
        snapshot::load(in, ipv4.address);
        snapshot::load(in, ipv4.netmask);
        snapshot::load(in, ipv4.broadcast);
        snapshot::load(in, ipv4.gateway);
        snapshot::load(in, ipv4.dns_servers);
        return ipv4;
    }

}

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

const std::array<snapshot::Member<WifiState>, 7>& WifiState::snapshot_members()
{
    static constexpr std::array<snapshot::Member<WifiState>, 7> members {{
        {"wifi.access_points_",
            [](const WifiState& wifi) { return snapshot::is_default(wifi.access_points_); },
            [](snapshot::Writer& out, const WifiState& wifi) {
                snapshot::save(out, static_cast<std::uint64_t>(wifi.access_points_.size()));
                for (const auto& point : wifi.access_points_)
                    save_access_point(out, point);
            },
            [](snapshot::Reader& in, WifiState& wifi) {
                std::uint64_t access_point_count { };
                snapshot::load(in, access_point_count);
                if (access_point_count != wifi.access_points_.size())
                    throw snapshot::FormatError { "Wi-Fi access points differ from the wiring" };
                for (const auto& expected : wifi.access_points_) {
                    if (!same_access_point(load_access_point(in), expected))
                        throw snapshot::FormatError {
                            "Wi-Fi access points differ from the wiring" };
                }
            }},
        {"wifi.preferred_networks_",
            [](const WifiState& wifi) { return snapshot::is_default(wifi.preferred_networks_); },
            [](snapshot::Writer& out, const WifiState& wifi) {
                snapshot::save(out, wifi.preferred_networks_);
            },
            [](snapshot::Reader& in, WifiState& wifi) {
                snapshot::load(in, wifi.preferred_networks_);
            }},
        {"wifi.link_state_",
            [](const WifiState& wifi) { return snapshot::is_default(wifi.link_state_); },
            [](snapshot::Writer& out, const WifiState& wifi) {
                snapshot::save(out, wifi.link_state_);
            },
            [](snapshot::Reader& in, WifiState& wifi) {
                snapshot::load(in, wifi.link_state_);
            }},
        {"wifi.airplane_mode_",
            [](const WifiState& wifi) { return snapshot::is_default(wifi.airplane_mode_); },
            [](snapshot::Writer& out, const WifiState& wifi) {
                snapshot::save(out, wifi.airplane_mode_);
            },
            [](snapshot::Reader& in, WifiState& wifi) {
                snapshot::load(in, wifi.airplane_mode_);
            }},
        {"wifi.powered_before_airplane_mode_",
            [](const WifiState& wifi) {
                return snapshot::is_default(wifi.powered_before_airplane_mode_);
            },
            [](snapshot::Writer& out, const WifiState& wifi) {
                snapshot::save(out, wifi.powered_before_airplane_mode_);
            },
            [](snapshot::Reader& in, WifiState& wifi) {
                snapshot::load(in, wifi.powered_before_airplane_mode_);
            }},
        {"wifi.associated_index_",
            [](const WifiState& wifi) { return snapshot::is_default(wifi.associated_index_); },
            [](snapshot::Writer& out, const WifiState& wifi) {
                snapshot::save(out, wifi.associated_index_);
            },
            [](snapshot::Reader& in, WifiState& wifi) {
                snapshot::load(in, wifi.associated_index_);
                if (wifi.associated_index_ &&
                    *wifi.associated_index_ >= wifi.access_points_.size())
                    throw snapshot::FormatError { "Wi-Fi association is not a wired access point" };
            }},
        {"wifi.ipv4_",
            [](const WifiState& wifi) { return snapshot::is_default(wifi.ipv4_); },
            [](snapshot::Writer& out, const WifiState& wifi) {
                snapshot::save(out, wifi.ipv4_.has_value());
                if (wifi.ipv4_)
                    save_ipv4(out, *wifi.ipv4_);
            },
            [](snapshot::Reader& in, WifiState& wifi) {
                bool has_ipv4 { };
                snapshot::load(in, has_ipv4);
                std::optional<WifiIpv4Configuration> ipv4;
                if (has_ipv4)
                    ipv4 = load_ipv4(in);
                wifi.ipv4_ = std::move(ipv4);
            }},
    }};
    return members;
}

void WifiState::save(snapshot::Writer& out) const
{
    std::lock_guard lock { mutex_ };
    snapshot::save_members(out, *this, snapshot_members());
}

void WifiState::load(snapshot::Reader& in)
{
    std::lock_guard lock { mutex_ };
    snapshot::restore_members(in, *this, snapshot_members());
}

}
