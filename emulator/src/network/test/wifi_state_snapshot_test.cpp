// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "network/wifi_state.hpp"

#include "foundation/snapshot_io.hpp"

#include <cstddef>
#include <cstdint>
#include <iostream>
#include <memory>
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

}

int main()
{
    associated_round_trip_keeps_the_link();
    airplane_mode_round_trip_keeps_the_mode();
    access_point_mismatch_is_a_format_error();
    truncated_stream_is_a_format_error();
    if (failures != 0) {
        std::cerr << failures << " Wi-Fi snapshot checks failed\n";
        return 1;
    }
    std::cout << "Wi-Fi snapshot checks passed\n";
    return 0;
}
