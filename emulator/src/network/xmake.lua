-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

target("shade_network")
    set_kind("static")
    add_files("apple80211_event_stream.cpp", "apple80211_hle.cpp", "darwin_network_abi.cpp",
              "darwin_route_socket.cpp", "dns_configuration_hle.cpp", "host_network.cpp",
              "system_configuration_hle.cpp", "wifi_state.cpp")
    add_deps("shade_foundation", {public = true})
