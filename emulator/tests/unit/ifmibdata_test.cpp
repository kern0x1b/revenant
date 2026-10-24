// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
#include "network/darwin_network_abi.hpp"

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <vector>

namespace {

int failures = 0;

void check(bool condition, const char* expression, int line)
{
    if (condition)
        return;
    ++failures;
    std::fprintf(stderr, "ifmibdata_test.cpp:%d: check failed: %s\n", line,
        expression);
}

#define CHECK(expression) check((expression), #expression, __LINE__)

std::uint32_t read32(const std::vector<std::byte>& bytes, std::size_t offset)
{
    std::uint32_t value { };
    for (std::size_t index = 0; index < 4; ++index)
        value |= std::to_integer<std::uint32_t>(bytes[offset + index])
                 << (index * 8U);
    return value;
}

std::uint64_t read64(const std::vector<std::byte>& bytes, std::size_t offset)
{
    return read32(bytes, offset) |
           (static_cast<std::uint64_t>(read32(bytes, offset + 4)) << 32U);
}

}

int main()
{
    using namespace emulator::darwin::network;

    constexpr std::size_t flags_offset = 20;
    constexpr std::size_t data_offset = 52;
    constexpr std::size_t mtu_offset = data_offset + 8;
    constexpr std::size_t baudrate_offset = data_offset + 16;
    constexpr std::size_t counters_offset = data_offset + 24;

    CHECK(ifmibdata_size == 180);

    InterfaceSnapshot loopback;
    loopback.name = "lo0";
    loopback.index = 1;
    loopback.flags = interface_flag_loopback | interface_flag_running;
    loopback.family = interface_family_loopback;
    loopback.mtu = default_loopback_mtu;
    loopback.type = interface_type_loopback;

    const auto lo0 = make_ifmibdata(loopback);
    CHECK(lo0.size() == ifmibdata_size);
    CHECK(lo0[0] == std::byte { 'l' } && lo0[1] == std::byte { 'o' });
    CHECK(lo0[2] == std::byte { '0' } && lo0[3] == std::byte { 0 });
    CHECK(read32(lo0, flags_offset) == (interface_flag_loopback |
                                           interface_flag_running));
    CHECK(lo0[data_offset] == std::byte { interface_type_loopback });
    CHECK(lo0[data_offset + 3] == std::byte { 0 });
    CHECK(lo0[data_offset + 4] == std::byte { 0 });
    CHECK(read32(lo0, mtu_offset) == default_loopback_mtu);
    CHECK(read64(lo0, baudrate_offset) == 0);
    CHECK(std::all_of(lo0.begin() + counters_offset, lo0.end(),
        [](std::byte value) { return value == std::byte { 0 }; }));

    InterfaceSnapshot ethernet;
    ethernet.name = "en0";
    ethernet.index = 2;
    ethernet.flags = interface_flag_broadcast | interface_flag_simplex |
                     interface_flag_multicast;
    ethernet.family = interface_family_ethernet;
    ethernet.mtu = default_ethernet_mtu;
    ethernet.type = interface_type_ethernet;
    ethernet.link_address = { std::byte { 0x02 }, std::byte { 0x00 },
        std::byte { 0x00 }, std::byte { 0x00 }, std::byte { 0x00 },
        std::byte { 0x01 } };
    ethernet.link_address_length = 6;
    ethernet.counters.input_packets = 3;
    ethernet.counters.input_errors = 1;
    ethernet.counters.input_bytes = 23;
    ethernet.counters.output_packets = 2;
    ethernet.counters.output_bytes = 11;
    ethernet.up_time_nanoseconds = 5'000'000'123ULL;

    const auto en0 = make_ifmibdata(ethernet);
    CHECK(en0.size() == ifmibdata_size);
    CHECK(en0[0] == std::byte { 'e' } && en0[1] == std::byte { 'n' });
    CHECK(en0[2] == std::byte { '0' } && en0[3] == std::byte { 0 });
    CHECK(read32(en0, flags_offset) == (interface_flag_broadcast |
                                           interface_flag_simplex |
                                           interface_flag_multicast));
    CHECK(en0[data_offset] == std::byte { interface_type_ethernet });
    CHECK(en0[data_offset + 3] == std::byte { 6 });
    CHECK(en0[data_offset + 4] == std::byte { 14 });
    CHECK(read32(en0, mtu_offset) == default_ethernet_mtu);
    CHECK(read64(en0, baudrate_offset) == 10'000'000ULL);
    CHECK(read64(en0, counters_offset) == 3);
    CHECK(read64(en0, counters_offset + 8) == 1);
    CHECK(read64(en0, counters_offset + 16) == 2);
    CHECK(read64(en0, counters_offset + 24) == 0);
    CHECK(read64(en0, counters_offset + 40) == 23);
    CHECK(read64(en0, counters_offset + 48) == 11);
    CHECK(read32(en0, data_offset + 120) == 5);
    CHECK(read32(en0, data_offset + 124) == 0);
    CHECK(std::all_of(en0.begin() + data_offset + 128, en0.end(),
        [](std::byte value) { return value == std::byte { 0 }; }));

    if (failures == 0)
        std::printf("ifmibdata: all checks passed\n");
    return failures == 0 ? 0 : 1;
}
