// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "network/darwin_network_abi.hpp"
#include "network/darwin_socket_abi.hpp"
#include "network/host_network.hpp"

#include <array>
#include <chrono>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <thread>
#include <vector>

namespace {

int failures = 0;

void check(bool condition, const char* expression, int line)
{
    if (condition)
        return;
    ++failures;
    std::fprintf(stderr, "interface_counters_test.cpp:%d: check failed: %s\n",
        line, expression);
}

#define CHECK(expression) check((expression), #expression, __LINE__)

std::vector<std::byte> inet_address(
    std::array<std::uint8_t, 4> address, std::uint16_t port)
{
    std::vector<std::byte> bytes(16);
    bytes[0] = std::byte { 16 };
    bytes[1] = std::byte { 2 };
    bytes[2] = std::byte { static_cast<std::uint8_t>(port >> 8U) };
    bytes[3] = std::byte { static_cast<std::uint8_t>(port) };
    for (std::size_t index = 0; index < address.size(); ++index)
        bytes[4 + index] = std::byte { address[index] };
    return bytes;
}

std::vector<std::byte> inet6_loopback_address()
{
    std::vector<std::byte> bytes(28);
    bytes[0] = std::byte { 28 };
    bytes[1] = std::byte { 30 };
    bytes[23] = std::byte { 1 };
    return bytes;
}

std::vector<std::byte> payload(std::size_t size)
{
    std::vector<std::byte> bytes(size);
    for (std::size_t index = 0; index < size; ++index)
        bytes[index] = std::byte { static_cast<std::uint8_t>(index + 1U) };
    return bytes;
}

}

int main()
{
    using namespace emulator::darwin::network;
    using emulator::HostNetworkPolicy;
    using emulator::HostSocket;

    CHECK(darwin_address_is_loopback(inet_address({ 127, 0, 0, 1 }, 53)));
    CHECK(darwin_address_is_loopback(inet6_loopback_address()));
    CHECK(!darwin_address_is_loopback(inet_address({ 10, 0, 0, 1 }, 53)));
    CHECK(!darwin_address_is_loopback(std::vector<std::byte> { }));

    InterfaceCounters lo0;
    InterfaceCounters en0;

    auto receiver = HostSocket::create(HostNetworkPolicy::Loopback,
        address_family_inet, emulator::darwin::socket::datagram, 0)
                        .socket;
    auto sender = HostSocket::create(HostNetworkPolicy::Loopback,
        address_family_inet, emulator::darwin::socket::datagram, 0)
                      .socket;
    CHECK(receiver != nullptr);
    CHECK(sender != nullptr);
    if (!receiver || !sender) {
        std::fprintf(stderr, "interface_counters: sockets unavailable\n");
        return 1;
    }

    const auto bound = receiver->bind(inet_address({ 127, 0, 0, 1 }, 0));
    CHECK(bound.status == emulator::HostSocketStatus::Success);
    const auto local = receiver->local_address();
    CHECK(local.status == emulator::HostSocketStatus::Success);
    const auto destination = local.address;
    CHECK(darwin_address_is_loopback(destination));

    for (const auto size : { std::size_t { 5 }, std::size_t { 7 },
             std::size_t { 11 } }) {
        const auto bytes = payload(size);
        const auto sent = sender->send(bytes, destination);
        const auto loopback = sender->loopback_for(destination);
        CHECK(loopback);
        CHECK(sent.status == emulator::HostSocketStatus::Success);
        (loopback ? lo0 : en0)
            .record(true, sent.transferred,
                sent.status == emulator::HostSocketStatus::Error);
    }

    for (std::size_t index = 0; index < 3; ++index) {
        for (int attempt = 0; attempt < 5000 && !receiver->readable();
             ++attempt)
            std::this_thread::sleep_for(std::chrono::milliseconds { 1 });
        const auto received = receiver->receive(64);
        CHECK(received.status == emulator::HostSocketStatus::Success);
        if (received.status == emulator::HostSocketStatus::WouldBlock)
            continue;
        const auto loopback = receiver->loopback_for(received.address);
        CHECK(loopback);
        CHECK(received.bytes == payload(index == 0 ? 5 : index == 1 ? 7 : 11));
        (loopback ? lo0 : en0)
            .record(false, received.transferred,
                received.status == emulator::HostSocketStatus::Error);
    }

    const std::vector<std::byte> unaddressable { std::byte { 4 },
        std::byte { 99 }, std::byte { 0 }, std::byte { 0 } };
    const auto refused = sender->send(payload(3), unaddressable);
    CHECK(refused.status == emulator::HostSocketStatus::Error);
    CHECK(!sender->loopback_for(unaddressable));
    en0.record(true, refused.transferred,
        refused.status == emulator::HostSocketStatus::Error);

    CHECK(lo0.output_packets == 3);
    CHECK(lo0.output_bytes == 23);
    CHECK(lo0.input_packets == 3);
    CHECK(lo0.input_bytes == 23);
    CHECK(lo0.input_errors == 0 && lo0.output_errors == 0);
    CHECK(en0.output_packets == 0 && en0.output_bytes == 0);
    CHECK(en0.output_errors == 1);
    CHECK(en0.input_packets == 0 && en0.input_errors == 0);

    if (failures == 0)
        std::printf("interface_counters: all checks passed\n");
    return failures == 0 ? 0 : 1;
}
