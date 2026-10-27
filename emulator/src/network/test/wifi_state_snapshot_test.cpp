// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "network/wifi_state.hpp"

#include "foundation/snapshot_io.hpp"
#include "foundation/snapshot_member.hpp"

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <iostream>
#include <memory>
#include <optional>
#include <string>
#include <vector>

namespace {

using emulator::VirtualAccessPoint;
using emulator::WifiState;
using emulator::WifiSnapshot;
using emulator::snapshot::FormatError;
using emulator::snapshot::Reader;
using emulator::snapshot::Writer;

int failures = 0;

void expect(bool condition, const std::string& what)
{
    if (condition)
        return;
    std::cerr << "FAIL: " << what << '\n';
    ++failures;
}

std::vector<std::byte> save_wifi(const WifiState& wifi)
{
    Writer out;
    wifi.save(out);
    return out.bytes();
}

void expect_same_snapshot(const WifiSnapshot& expected, const WifiSnapshot& actual)
{
    expect(actual.link_state == expected.link_state, "the link state");
    expect(actual.powered == expected.powered, "the power state");
    expect(actual.airplane_mode == expected.airplane_mode, "the airplane mode");
    expect(actual.associated_access_point.has_value() ==
            expected.associated_access_point.has_value(),
        "the association");
    if (expected.associated_access_point && actual.associated_access_point) {
        expect(actual.associated_access_point->ssid ==
                expected.associated_access_point->ssid,
            "the associated network");
    }
    expect(actual.ipv4.has_value() == expected.ipv4.has_value(),
        "the IPv4 configuration is present");
}

void associated_round_trip_keeps_the_link()
{
    WifiState source;
    expect(source.set_power(true), "power the Wi-Fi on");
    expect(source.associate(), "associate to the wired access point");
    const auto bytes = save_wifi(source);

    WifiState restored;
    Reader in { bytes };
    restored.load(in);
    expect(in.at_end(), "the Wi-Fi stream is consumed");
    expect_same_snapshot(source.snapshot(), restored.snapshot());
    expect(save_wifi(restored) == bytes,
        "saving the restored Wi-Fi state reproduces the same stream");
}

void airplane_mode_round_trip_keeps_the_mode()
{
    WifiState source;
    expect(source.set_power(true), "power the Wi-Fi on");
    expect(source.set_airplane_mode(true), "enter airplane mode");
    const auto bytes = save_wifi(source);

    WifiState restored;
    Reader in { bytes };
    restored.load(in);
    expect(restored.snapshot().airplane_mode, "airplane mode survives");
    expect_same_snapshot(source.snapshot(), restored.snapshot());
    expect(save_wifi(restored) == bytes,
        "airplane mode saves to the same stream");
}

void access_point_mismatch_is_a_format_error()
{
    WifiState source;
    expect(source.set_power(true), "power the Wi-Fi on");
    const auto bytes = save_wifi(source);

    VirtualAccessPoint other;
    other.ssid = "elsewhere";
    WifiState restored { { other } };
    bool threw = false;
    try {
        Reader in { bytes };
        restored.load(in);
    } catch (const FormatError&) {
        threw = true;
    }
    expect(threw, "access points that differ from the wiring are refused");
}

void truncated_stream_is_a_format_error()
{
    WifiState source;
    expect(source.set_power(true), "power the Wi-Fi on");
    expect(source.associate(), "associate to the wired access point");
    const auto bytes = save_wifi(source);
    const std::vector<std::byte> truncated { bytes.begin(),
        bytes.begin() + static_cast<std::ptrdiff_t>(bytes.size() - 1U) };

    WifiState restored;
    bool threw = false;
    try {
        Reader in { truncated };
        restored.load(in);
    } catch (const FormatError&) {
        threw = true;
    }
    expect(threw, "a truncated Wi-Fi stream throws FormatError");
}

void no_access_point_layout_is_fixed()
{
    const WifiState wifi { std::vector<VirtualAccessPoint> {} };
    Writer expected;
    emulator::snapshot::save(expected, static_cast<std::uint64_t>(0));
    emulator::snapshot::save(expected, std::vector<std::string> {});
    emulator::snapshot::save(expected, emulator::WifiLinkState::PoweredOff);
    emulator::snapshot::save(expected, false);
    emulator::snapshot::save(expected, false);
    emulator::snapshot::save(expected, std::optional<std::size_t> {});
    emulator::snapshot::save(expected, false);
    expect(save_wifi(wifi) == expected.bytes(),
        "the Wi-Fi state saves its members in their fixed order");
}

void descriptors_name_the_saved_fields_in_order()
{
    std::vector<std::string> names;
    for (const auto& member : WifiState::snapshot_members())
        names.emplace_back(member.name);
    const std::vector<std::string> expected {
        "wifi.access_points_",
        "wifi.preferred_networks_",
        "wifi.link_state_",
        "wifi.airplane_mode_",
        "wifi.powered_before_airplane_mode_",
        "wifi.associated_index_",
        "wifi.ipv4_",
    };
    expect(names == expected, "the Wi-Fi members are named in save order");
}

void is_default_holds_for_a_state_with_nothing_wired()
{
    const WifiState empty { std::vector<VirtualAccessPoint> {} };
    for (const auto& member : WifiState::snapshot_members()) {
        expect(member.is_default(empty),
            std::string { member.name } + " is default when nothing is wired or on");
    }
}

void populated_members_name_the_fields_that_hold_state()
{
    const WifiState wired;
    std::vector<std::string> populated;
    emulator::snapshot::note_populated_members(
        populated, wired, WifiState::snapshot_members());
    expect(populated == std::vector<std::string> { "wifi.access_points_" },
        "a powered-off Wi-Fi state populates only its wired access point");

    WifiState associated;
    expect(associated.set_power(true), "power the Wi-Fi on");
    expect(associated.associate(), "associate to the wired access point");
    populated.clear();
    emulator::snapshot::note_populated_members(
        populated, associated, WifiState::snapshot_members());
    const auto has = [&populated](const std::string& name) {
        return std::find(populated.begin(), populated.end(), name) != populated.end();
    };
    expect(has("wifi.link_state_"), "an associated Wi-Fi state populates its link state");
    expect(has("wifi.associated_index_"),
        "an associated Wi-Fi state populates its association");
}

}

int main()
{
    associated_round_trip_keeps_the_link();
    airplane_mode_round_trip_keeps_the_mode();
    access_point_mismatch_is_a_format_error();
    truncated_stream_is_a_format_error();
    no_access_point_layout_is_fixed();
    descriptors_name_the_saved_fields_in_order();
    is_default_holds_for_a_state_with_nothing_wired();
    populated_members_name_the_fields_that_hold_state();
    if (failures != 0) {
        std::cerr << failures << " Wi-Fi snapshot checks failed\n";
        return 1;
    }
    std::cout << "Wi-Fi snapshot checks passed\n";
    return 0;
}
