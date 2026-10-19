// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Model isolated UDP sockets, multicast membership and queued
// datagrams.

#pragma once

#include <atomic>
#include <cstddef>
#include <cstdint>
#include <deque>
#include <memory>
#include <mutex>
#include <optional>
#include <set>
#include <span>
#include <utility>
#include <vector>

namespace shade::bsd {

enum class VirtualUdpStatus {
    Success,
    InvalidArgument,
    AddressFamilyUnsupported,
    NotConnected,
    AlreadyConnected,
    BadFileDescriptor,
};

struct VirtualUdpDatagram {
    std::vector<std::byte> bytes;
    std::vector<std::byte> source_address;
    std::vector<std::byte> destination_address;
};

struct VirtualUdpAncillaryOptions {
    bool receive_destination_address { };
    bool receive_interface { };
    bool receive_hop_limit { };
    std::uint32_t interface_index { 2 };
};

[[nodiscard]] std::vector<std::byte> make_virtual_udp_ancillary(
    std::uint32_t family, const VirtualUdpDatagram& datagram,
    const VirtualUdpAncillaryOptions& options);

class VirtualUdpSocket;

// Shared in-memory UDP fabric for the isolated network policy. It models the
// BSD socket data plane without opening a host socket, so multicast services
// such as mDNS remain usable in a sandbox and between guest processes.
class VirtualUdpNetwork final
    : public std::enable_shared_from_this<VirtualUdpNetwork> {
public:
    [[nodiscard]] std::shared_ptr<VirtualUdpSocket> create(
        std::uint32_t family);

private:
    friend class VirtualUdpSocket;

    [[nodiscard]] VirtualUdpStatus bind(
        VirtualUdpSocket& socket, std::span<const std::byte> address);
    [[nodiscard]] VirtualUdpStatus set_option(VirtualUdpSocket& socket,
        std::uint32_t level, std::uint32_t option,
        std::span<const std::byte> value);
    [[nodiscard]] VirtualUdpStatus send(VirtualUdpSocket& socket,
        std::span<const std::byte> bytes,
        std::span<const std::byte> destination);
    [[nodiscard]] std::optional<VirtualUdpDatagram> receive(
        VirtualUdpSocket& socket, std::size_t capacity);
    [[nodiscard]] std::vector<std::byte> local_address(
        const VirtualUdpSocket& socket) const;
    [[nodiscard]] bool readable(const VirtualUdpSocket& socket) const;
    [[nodiscard]] std::size_t pending_bytes(
        const VirtualUdpSocket& socket) const;

    mutable std::mutex mutex_;
    std::vector<std::weak_ptr<VirtualUdpSocket>> sockets_;
    std::uint16_t next_ephemeral_port_ { 49'152 };
};

class VirtualUdpSocket final {
public:
    [[nodiscard]] std::uint32_t family() const { return family_; }
    [[nodiscard]] VirtualUdpStatus bind(std::span<const std::byte> address);
    [[nodiscard]] VirtualUdpStatus connect(std::span<const std::byte> address);
    [[nodiscard]] VirtualUdpStatus disconnect();
    void make_defunct();
    [[nodiscard]] bool defunct() const { return defunct_.load(); }
    [[nodiscard]] VirtualUdpStatus set_option(std::uint32_t level,
        std::uint32_t option, std::span<const std::byte> value);
    [[nodiscard]] VirtualUdpStatus send(std::span<const std::byte> bytes,
        std::span<const std::byte> destination);
    [[nodiscard]] VirtualUdpStatus send(std::span<const std::byte> bytes);
    [[nodiscard]] std::optional<VirtualUdpDatagram> receive(
        std::size_t capacity);
    [[nodiscard]] std::vector<std::byte> local_address() const;
    [[nodiscard]] std::optional<std::vector<std::byte>> peer_address() const;
    [[nodiscard]] bool readable() const;
    [[nodiscard]] std::size_t pending_bytes() const;
    [[nodiscard]] bool writable() const { return !defunct(); }

private:
    friend class VirtualUdpNetwork;

    VirtualUdpSocket(
        std::shared_ptr<VirtualUdpNetwork> network, std::uint32_t family)
        : network_ { std::move(network) }
        , family_ { family }
    {
    }

    std::weak_ptr<VirtualUdpNetwork> network_;
    std::uint32_t family_ { };
    std::vector<std::byte> bound_address_;
    std::vector<std::byte> connected_address_;
    std::set<std::vector<std::byte>> multicast_groups_;
    std::deque<VirtualUdpDatagram> incoming_;
    bool multicast_loop_ { true };
    std::atomic_bool defunct_ { false };
};

} // namespace shade::bsd
