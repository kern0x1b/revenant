// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Coordinate kernel socket readiness and virtual network event
// delivery.

#pragma once

#include <string_view>

#include "network/darwin_network_abi.hpp"
#include "kernel/kernel_shared_state.hpp"

namespace shade::kernel_network {

// An isolated guest still has a local IP stack. Stream endpoints in this
// mode deliberately have no HostSocket: bind/listen state remains inside the
// simulator, while connect cannot escape to a host or external address.
inline constexpr std::string_view isolated_ipv4_stream_descriptor {
    "isolated-inet-stream"
};
inline constexpr std::string_view isolated_ipv6_stream_descriptor {
    "isolated-inet6-stream"
};

[[nodiscard]] constexpr bool is_isolated_stream_descriptor(
    std::string_view descriptor)
{
    return descriptor == isolated_ipv4_stream_descriptor ||
           descriptor == isolated_ipv6_stream_descriptor;
}

[[nodiscard]] darwin::network::InterfaceSnapshot make_interface_snapshot(
    std::string_view name,
    const KernelSharedState::NetworkInterface& interface);

} // namespace shade::kernel_network
