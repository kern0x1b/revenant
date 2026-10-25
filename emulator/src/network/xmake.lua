-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

target("emulator_network")
    set_kind("static")
    add_files("apple80211_event_stream.cpp", "apple80211_hle.cpp", "darwin_network_abi.cpp",
              "darwin_route_socket.cpp", "dns_configuration_hle.cpp", "host_network.cpp",
              "host_readiness.cpp", "system_configuration_hle.cpp", "wifi_state.cpp")
    add_deps("emulator_foundation", {public = true})

target("emulator_network_host_readiness_test")
    set_kind("binary")
    set_default(false)
    add_files("test/host_readiness_test.cpp")
    add_deps("emulator_network")
    add_tests("network.host_readiness")

target("emulator_network_host_readiness_bench")
    set_kind("binary")
    set_default(false)
    add_files("test/host_readiness_bench.cpp")
    add_deps("emulator_network")
