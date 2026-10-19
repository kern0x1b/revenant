// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Implement isolated UDP delivery, socket membership and ancillary
// records.

#include "network/virtual_udp.hpp"

#include "network/darwin_network_abi.hpp"

#include <algorithm>
#include <array>
#include <limits>

namespace shade::bsd {
namespace {

    using namespace darwin::network;

    constexpr std::size_t maximum_pending_datagrams = 256;
    constexpr std::array<std::byte, 4> default_ipv4_address { std::byte { 10 },
        std::byte { 0 }, std::byte { 2 }, std::byte { 15 } };
    constexpr std::array<std::byte, 16> default_ipv6_address { std::byte { 0 },
        std::byte { 0 }, std::byte { 0 }, std::byte { 0 }, std::byte { 0 },
        std::byte { 0 }, std::byte { 0 }, std::byte { 0 }, std::byte { 0 },
        std::byte { 0 }, std::byte { 0 }, std::byte { 0 }, std::byte { 0 },
        std::byte { 0 }, std::byte { 0 }, std::byte { 1 } };

    [[nodiscard]] std::size_t address_size(std::uint32_t family)
    {
        if (family == address_family_inet)
            return arm32_sockaddr_in_size;
        if (family == address_family_inet6)
            return arm32_sockaddr_in6_size;
        return 0;
    }

    [[nodiscard]] bool valid_address(
        std::span<const std::byte> address, std::uint32_t family)
    {
        const auto expected = address_size(family);
        return expected != 0 && address.size() >= expected &&
               std::to_integer<std::uint8_t>(address[sockaddr_family_offset]) ==
                   family;
    }

    [[nodiscard]] std::vector<std::byte> normalize_address(
        std::span<const std::byte> address, std::uint32_t family)
    {
        const auto size = address_size(family);
        std::vector<std::byte> normalized(
            address.begin(), address.begin() + size);
        normalized[sockaddr_length_offset] = static_cast<std::byte>(size);
        return normalized;
    }

    [[nodiscard]] bool same_port(
        std::span<const std::byte> left, std::span<const std::byte> right)
    {
        return left[sockaddr_port_offset] == right[sockaddr_port_offset] &&
               left[sockaddr_port_offset + 1U] ==
                   right[sockaddr_port_offset + 1U];
    }

    [[nodiscard]] bool zero_port(std::span<const std::byte> address)
    {
        return address[sockaddr_port_offset] == std::byte { 0 } &&
               address[sockaddr_port_offset + 1U] == std::byte { 0 };
    }

    void set_port(std::span<std::byte> address, std::uint16_t port)
    {
        address[sockaddr_port_offset] = static_cast<std::byte>(port >> 8U);
        address[sockaddr_port_offset + 1U] = static_cast<std::byte>(port);
    }

    [[nodiscard]] std::span<const std::byte> address_bytes(
        std::span<const std::byte> address, std::uint32_t family)
    {
        const auto offset = family == address_family_inet
                                ? sockaddr_ipv4_address_offset
                                : sockaddr_ipv6_address_offset;
        const auto count = family == address_family_inet ? 4U : 16U;
        return address.subspan(offset, count);
    }

    [[nodiscard]] bool wildcard_address(
        std::span<const std::byte> address, std::uint32_t family)
    {
        const auto bytes = address_bytes(address, family);
        return std::all_of(bytes.begin(), bytes.end(),
            [](std::byte value) { return value == std::byte { 0 }; });
    }

    [[nodiscard]] bool multicast_address(
        std::span<const std::byte> address, std::uint32_t family)
    {
        const auto bytes = address_bytes(address, family);
        if (family == address_family_inet) {
            const auto first = std::to_integer<std::uint8_t>(bytes.front());
            return first >= 224U && first <= 239U;
        }
        return bytes.front() == std::byte { 0xff };
    }

    [[nodiscard]] bool same_ip(std::span<const std::byte> left,
        std::span<const std::byte> right, std::uint32_t family)
    {
        return std::ranges::equal(
            address_bytes(left, family), address_bytes(right, family));
    }

    [[nodiscard]] std::vector<std::byte> multicast_group(
        std::span<const std::byte> address, std::uint32_t family)
    {
        const auto bytes = address_bytes(address, family);
        return { bytes.begin(), bytes.end() };
    }

    [[nodiscard]] bool enabled_value(std::span<const std::byte> value)
    {
        return !value.empty() &&
               std::any_of(value.begin(), value.end(),
                   [](std::byte byte) { return byte != std::byte { 0 }; });
    }

} // namespace

std::vector<std::byte> make_virtual_udp_ancillary(std::uint32_t family,
    const VirtualUdpDatagram& datagram,
    const VirtualUdpAncillaryOptions& options)
{
    std::vector<std::byte> control;
    const auto append_u32 = [&](std::uint32_t value) {
        for (std::size_t byte = 0; byte < sizeof(value); ++byte)
            control.push_back(static_cast<std::byte>(value >> (byte * 8U)));
    };
    const auto append_control = [&](std::uint32_t level, std::uint32_t type,
                                    std::span<const std::byte> payload) {
        append_u32(arm32_control_header_size +
                   static_cast<std::uint32_t>(payload.size()));
        append_u32(level);
        append_u32(type);
        control.insert(control.end(), payload.begin(), payload.end());
        while ((control.size() & 3U) != 0)
            control.push_back(std::byte { 0 });
    };

    if (family == address_family_inet) {
        if (options.receive_destination_address &&
            datagram.destination_address.size() >= arm32_sockaddr_in_size) {
            append_control(protocol_ip, ip_receive_destination_address,
                std::span<const std::byte> { datagram.destination_address }
                    .subspan(sockaddr_ipv4_address_offset, 4));
        }
        if (options.receive_interface) {
            std::array<std::byte, arm32_sockaddr_dl_size> link { };
            constexpr std::array<std::byte, 3> interface_name {
                std::byte { 'e' }, std::byte { 'n' }, std::byte { '0' }
            };
            link[0] = static_cast<std::byte>(link.size());
            link[1] = static_cast<std::byte>(address_family_link);
            link[2] = static_cast<std::byte>(options.interface_index);
            link[3] = static_cast<std::byte>(options.interface_index >> 8U);
            link[4] = static_cast<std::byte>(interface_type_ethernet);
            link[5] = static_cast<std::byte>(interface_name.size());
            std::copy(
                interface_name.begin(), interface_name.end(), link.begin() + 8);
            append_control(protocol_ip, ip_receive_interface, link);
        }
        if (options.receive_hop_limit) {
            constexpr std::array ttl { std::byte { 255 } };
            append_control(protocol_ip, ip_receive_ttl, ttl);
        }
    } else if (family == address_family_inet6) {
        if (options.receive_destination_address &&
            datagram.destination_address.size() >= arm32_sockaddr_in6_size) {
            std::array<std::byte, 20> packet_info { };
            std::copy_n(datagram.destination_address.begin() +
                            sockaddr_ipv6_address_offset,
                16, packet_info.begin());
            for (std::size_t byte = 0; byte < sizeof(options.interface_index);
                ++byte) {
                packet_info[16U + byte] = static_cast<std::byte>(
                    options.interface_index >> (byte * 8U));
            }
            append_control(protocol_ipv6, ipv6_packet_info, packet_info);
        }
        if (options.receive_hop_limit) {
            std::array<std::byte, 4> hop_limit { };
            hop_limit[0] = std::byte { 255 };
            append_control(protocol_ipv6, ipv6_hop_limit, hop_limit);
        }
    }
    return control;
}

std::shared_ptr<VirtualUdpSocket> VirtualUdpNetwork::create(
    std::uint32_t family)
{
    if (address_size(family) == 0)
        return { };
    auto socket = std::shared_ptr<VirtualUdpSocket> { new VirtualUdpSocket {
        shared_from_this(), family } };
    std::lock_guard lock { mutex_ };
    sockets_.push_back(socket);
    return socket;
}

VirtualUdpStatus VirtualUdpNetwork::bind(
    VirtualUdpSocket& socket, std::span<const std::byte> address)
{
    if (!valid_address(address, socket.family_))
        return VirtualUdpStatus::InvalidArgument;
    std::lock_guard lock { mutex_ };
    socket.bound_address_ = normalize_address(address, socket.family_);
    return VirtualUdpStatus::Success;
}

VirtualUdpStatus VirtualUdpNetwork::set_option(VirtualUdpSocket& socket,
    std::uint32_t level, std::uint32_t option, std::span<const std::byte> value)
{
    std::lock_guard lock { mutex_ };
    const bool ipv4 =
        socket.family_ == address_family_inet && level == protocol_ip;
    const bool ipv6 =
        socket.family_ == address_family_inet6 && level == protocol_ipv6;
    if ((ipv4 && option == ip_multicast_loop) ||
        (ipv6 && option == ipv6_multicast_loop)) {
        if (value.empty())
            return VirtualUdpStatus::InvalidArgument;
        socket.multicast_loop_ = enabled_value(value);
        return VirtualUdpStatus::Success;
    }

    const bool join = (ipv4 && option == ip_add_membership) ||
                      (ipv6 && option == ipv6_join_group);
    const bool leave = (ipv4 && option == ip_drop_membership) ||
                       (ipv6 && option == ipv6_leave_group);
    if (!join && !leave)
        return VirtualUdpStatus::Success;
    const auto group_size = ipv4 ? 4U : 16U;
    if (value.size() < group_size)
        return VirtualUdpStatus::InvalidArgument;
    std::vector<std::byte> group(value.begin(), value.begin() + group_size);
    if (join)
        socket.multicast_groups_.insert(std::move(group));
    else
        socket.multicast_groups_.erase(group);
    return VirtualUdpStatus::Success;
}

VirtualUdpStatus VirtualUdpNetwork::send(VirtualUdpSocket& socket,
    std::span<const std::byte> bytes, std::span<const std::byte> destination)
{
    if (!valid_address(destination, socket.family_))
        return VirtualUdpStatus::InvalidArgument;
    const auto normalized_destination =
        normalize_address(destination, socket.family_);
    if (zero_port(normalized_destination))
        return VirtualUdpStatus::InvalidArgument;

    std::lock_guard lock { mutex_ };
    if (socket.bound_address_.empty()) {
        socket.bound_address_.assign(
            address_size(socket.family_), std::byte { 0 });
        socket.bound_address_[sockaddr_length_offset] =
            static_cast<std::byte>(socket.bound_address_.size());
        socket.bound_address_[sockaddr_family_offset] =
            static_cast<std::byte>(socket.family_);
        set_port(socket.bound_address_, next_ephemeral_port_++);
        if (next_ephemeral_port_ == 0)
            next_ephemeral_port_ = 49'152;
    }

    auto source = socket.bound_address_;
    if (wildcard_address(source, socket.family_)) {
        const auto replacement =
            socket.family_ == address_family_inet
                ? std::span<const std::byte> { default_ipv4_address }
                : std::span<const std::byte> { default_ipv6_address };
        const auto offset = socket.family_ == address_family_inet
                                ? sockaddr_ipv4_address_offset
                                : sockaddr_ipv6_address_offset;
        std::copy(
            replacement.begin(), replacement.end(), source.begin() + offset);
    }

    const bool multicast =
        multicast_address(normalized_destination, socket.family_);
    const auto group =
        multicast ? multicast_group(normalized_destination, socket.family_)
                  : std::vector<std::byte> { };
    for (auto current = sockets_.begin(); current != sockets_.end();) {
        const auto target = current->lock();
        if (!target) {
            current = sockets_.erase(current);
            continue;
        }
        ++current;
        if (target->defunct() || target->family_ != socket.family_ ||
            target->bound_address_.empty() ||
            !same_port(target->bound_address_, normalized_destination)) {
            continue;
        }
        if (!target->connected_address_.empty() &&
            (!same_port(target->connected_address_, source) ||
                !same_ip(
                    target->connected_address_, source, target->family_))) {
            continue;
        }
        if (target.get() == &socket && multicast && !socket.multicast_loop_)
            continue;
        const bool wildcard =
            wildcard_address(target->bound_address_, target->family_);
        if (multicast) {
            // Darwin permits a wildcard-bound multicast receiver. Membership is
            // still tracked, while accepting wildcard bindings also covers the
            // early mDNS setup sequence before its interface join is issued.
            if (!wildcard && !target->multicast_groups_.contains(group))
                continue;
        } else if (!wildcard && !same_ip(target->bound_address_,
                                    normalized_destination, target->family_)) {
            continue;
        }
        if (target->incoming_.size() >= maximum_pending_datagrams)
            target->incoming_.pop_front();
        target->incoming_.push_back(VirtualUdpDatagram {
            { bytes.begin(), bytes.end() }, source, normalized_destination });
    }
    return VirtualUdpStatus::Success;
}

std::optional<VirtualUdpDatagram> VirtualUdpNetwork::receive(
    VirtualUdpSocket& socket, std::size_t capacity)
{
    std::lock_guard lock { mutex_ };
    if (socket.incoming_.empty())
        return std::nullopt;
    auto datagram = std::move(socket.incoming_.front());
    socket.incoming_.pop_front();
    if (datagram.bytes.size() > capacity)
        datagram.bytes.resize(capacity);
    return datagram;
}

std::vector<std::byte> VirtualUdpNetwork::local_address(
    const VirtualUdpSocket& socket) const
{
    std::lock_guard lock { mutex_ };
    if (!socket.bound_address_.empty())
        return socket.bound_address_;
    std::vector<std::byte> address(
        address_size(socket.family_), std::byte { 0 });
    address[sockaddr_length_offset] = static_cast<std::byte>(address.size());
    address[sockaddr_family_offset] = static_cast<std::byte>(socket.family_);
    return address;
}

bool VirtualUdpNetwork::readable(const VirtualUdpSocket& socket) const
{
    std::lock_guard lock { mutex_ };
    return !socket.incoming_.empty();
}

std::size_t VirtualUdpNetwork::pending_bytes(
    const VirtualUdpSocket& socket) const
{
    std::lock_guard lock { mutex_ };
    return socket.incoming_.empty() ? 0 : socket.incoming_.front().bytes.size();
}

VirtualUdpStatus VirtualUdpSocket::bind(std::span<const std::byte> address)
{
    if (defunct())
        return VirtualUdpStatus::BadFileDescriptor;
    const auto network = network_.lock();
    return network ? network->bind(*this, address)
                   : VirtualUdpStatus::AddressFamilyUnsupported;
}

VirtualUdpStatus VirtualUdpSocket::connect(std::span<const std::byte> address)
{
    if (defunct())
        return VirtualUdpStatus::BadFileDescriptor;
    if (!valid_address(address, family_))
        return VirtualUdpStatus::InvalidArgument;
    const auto network = network_.lock();
    if (!network)
        return VirtualUdpStatus::AddressFamilyUnsupported;
    auto normalized = normalize_address(address, family_);
    if (zero_port(normalized))
        return VirtualUdpStatus::InvalidArgument;
    std::lock_guard lock { network->mutex_ };
    if (!connected_address_.empty())
        return VirtualUdpStatus::AlreadyConnected;
    connected_address_ = std::move(normalized);
    return VirtualUdpStatus::Success;
}

VirtualUdpStatus VirtualUdpSocket::disconnect()
{
    if (defunct())
        return VirtualUdpStatus::BadFileDescriptor;
    const auto network = network_.lock();
    if (!network)
        return VirtualUdpStatus::AddressFamilyUnsupported;
    std::lock_guard lock { network->mutex_ };
    if (connected_address_.empty())
        return VirtualUdpStatus::NotConnected;
    connected_address_.clear();
    return VirtualUdpStatus::Success;
}

VirtualUdpStatus VirtualUdpSocket::set_option(
    std::uint32_t level, std::uint32_t option, std::span<const std::byte> value)
{
    const auto network = network_.lock();
    return network ? network->set_option(*this, level, option, value)
                   : VirtualUdpStatus::AddressFamilyUnsupported;
}

VirtualUdpStatus VirtualUdpSocket::send(
    std::span<const std::byte> bytes, std::span<const std::byte> destination)
{
    if (defunct())
        return VirtualUdpStatus::BadFileDescriptor;
    if (peer_address())
        return VirtualUdpStatus::AlreadyConnected;
    const auto network = network_.lock();
    return network ? network->send(*this, bytes, destination)
                   : VirtualUdpStatus::AddressFamilyUnsupported;
}

VirtualUdpStatus VirtualUdpSocket::send(std::span<const std::byte> bytes)
{
    if (defunct())
        return VirtualUdpStatus::BadFileDescriptor;
    const auto peer = peer_address();
    if (!peer)
        return VirtualUdpStatus::NotConnected;
    const auto network = network_.lock();
    return network ? network->send(*this, bytes, *peer)
                   : VirtualUdpStatus::AddressFamilyUnsupported;
}

std::optional<VirtualUdpDatagram> VirtualUdpSocket::receive(
    std::size_t capacity)
{
    const auto network = network_.lock();
    return network ? network->receive(*this, capacity) : std::nullopt;
}

std::vector<std::byte> VirtualUdpSocket::local_address() const
{
    const auto network = network_.lock();
    return network ? network->local_address(*this) : std::vector<std::byte> { };
}

std::optional<std::vector<std::byte>> VirtualUdpSocket::peer_address() const
{
    const auto network = network_.lock();
    if (!network)
        return std::nullopt;
    std::lock_guard lock { network->mutex_ };
    if (connected_address_.empty())
        return std::nullopt;
    return connected_address_;
}

bool VirtualUdpSocket::readable() const
{
    if (defunct())
        return true;
    const auto network = network_.lock();
    return network && network->readable(*this);
}

std::size_t VirtualUdpSocket::pending_bytes() const
{
    const auto network = network_.lock();
    return network ? network->pending_bytes(*this) : 0;
}

void VirtualUdpSocket::make_defunct()
{
    const auto network = network_.lock();
    if (!network)
        return;
    std::lock_guard lock { network->mutex_ };
    defunct_.store(true);
    incoming_.clear();
    connected_address_.clear();
    multicast_groups_.clear();
}

} // namespace shade::bsd
