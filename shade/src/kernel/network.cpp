// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Coordinate kernel network readiness, event queues and packet
// delivery.

#include "kernel/kernel.hpp"
#include "kernel/kevent_wire.hpp"

#include "kernel/baseband_device.hpp"
#include "kernel/darwin_abi.hpp"
#include "kernel/darwin_kqueue_abi.hpp"
#include "network/darwin_network_abi.hpp"
#include "network/darwin_route_socket.hpp"
#include "kernel/kernel_network.hpp"
#include "kernel/offline_serial_device.hpp"

#include <algorithm>
#include <array>
#include <bit>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <mutex>
#include <optional>
#include <span>
#include <sstream>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "bsd/support.hpp"

namespace shade {
namespace {

    constexpr std::uint32_t ebadf = 9;
    constexpr std::uint32_t efault = 14;
    constexpr std::uint32_t einval = 22;
    constexpr std::uint32_t enotconn = 57;

} // namespace

namespace kernel_network {
    darwin::network::InterfaceSnapshot make_interface_snapshot(
        std::string_view name,
        const KernelSharedState::NetworkInterface& interface)
    {
        darwin::network::InterfaceSnapshot result;
        result.name = name;
        result.index = interface.index;
        result.flags = interface.flags;
        result.family = interface.family;
        result.unit = interface.unit;
        result.mtu = interface.mtu;
        result.type = interface.type;
        result.link_address = interface.link_address;
        result.link_address_length = interface.link_address_length;
        if (interface.has_ipv4) {
            result.ipv4_address = interface.ipv4_address;
            result.ipv4_netmask = interface.ipv4_netmask;
            if (std::to_integer<std::uint8_t>(interface.ipv4_broadcast[0]) !=
                0) {
                result.ipv4_broadcast = interface.ipv4_broadcast;
            }
        }
        if (interface.has_ipv6) {
            result.ipv6_address = interface.ipv6_address;
            result.ipv6_netmask = interface.ipv6_netmask;
        }
        return result;
    }
} // namespace kernel_network

void CompatibilityKernel::set_host_network_policy(HostNetworkPolicy policy)
{
    host_network_policy_ = policy;
    constexpr bool service_available = true;
    bool availability_changed = false;
    {
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        // The policy gates host socket reachability, not guest hardware.
        // Isolated devices retain their virtual 802.11 controller and local
        // network state while BSD internet sockets remain host-inaccessible.
        availability_changed =
            shared_state_->wifi_service_available != service_available;
        shared_state_->wifi_service_available = service_available;
    }
    // Every forked process receives its own kernel facade and host socket
    // policy, but the radio is one shared device. Reapplying an unchanged host
    // capability must not undo a guest Wi-Fi or airplane-mode decision.
    if (!availability_changed)
        return;

    const auto before = wifi_state_->snapshot();
    // Publishing a usable backend powers the radio. Association is restored
    // only when the guest data partition already marks a visible network as
    // preferred; a fresh device remains idle until its first native join.
    const auto power_changed = wifi_state_->set_power(service_available);
    if (power_changed) {
        const auto after = wifi_state_->snapshot();
        apply_wifi_transition(before, after);
        apple80211_hle_.publish_state_change(before, after);
    }
}

std::optional<darwin::network::InterfaceSnapshot>
CompatibilityKernel::network_interface_snapshot(std::string_view name) const
{
    std::lock_guard network_lock { shared_state_->network_mutex };
    const auto found =
        shared_state_->network_interfaces.find(std::string { name });
    if (found == shared_state_->network_interfaces.end())
        return std::nullopt;
    return kernel_network::make_interface_snapshot(found->first, found->second);
}

std::vector<darwin::route::Entry> CompatibilityKernel::route_snapshot() const
{
    return shared_state_->route_table.snapshot();
}

bool CompatibilityKernel::receive_socket_message(
    Cpu& cpu, std::uint32_t fd, std::uint32_t message_address)
{
    using namespace darwin::socket;
    if (!memory_.accessible(message_address, arm32_message::size,
            MemoryPermission::Read | MemoryPermission::Write)) {
        bsd_error(cpu, efault);
        return true;
    }
    const auto name_address =
        memory_.read32(message_address + arm32_message::name_offset);
    const auto name_capacity =
        memory_.read32(message_address + arm32_message::name_length_offset);
    const auto iov_address =
        memory_.read32(message_address + arm32_message::iov_offset);
    const auto iov_count =
        memory_.read32(message_address + arm32_message::iov_count_offset);
    const auto control_address =
        memory_.read32(message_address + arm32_message::control_offset);
    const auto control_capacity =
        memory_.read32(message_address + arm32_message::control_length_offset);
    if (!name_address || !name_capacity || !iov_address || !iov_count ||
        !control_address || !control_capacity) {
        bsd_error(cpu, efault);
        return true;
    }
    if (*iov_count > darwin::io::maximum_vector_count) {
        bsd_error(cpu, einval);
        return true;
    }
    const auto iovec_bytes =
        static_cast<std::size_t>(*iov_count) * arm32_iovec::size;
    if ((*iov_count != 0 &&
            (*iov_address == 0 || !memory_.accessible(*iov_address, iovec_bytes,
                                      MemoryPermission::Read))) ||
        (*name_capacity != 0 && *name_address == 0) ||
        (*control_capacity != 0 && *control_address == 0)) {
        bsd_error(cpu, efault);
        return true;
    }

    struct GuestIovec {
        std::uint32_t base { };
        std::uint32_t capacity { };
    };
    std::vector<GuestIovec> iovecs;
    iovecs.reserve(*iov_count);
    std::size_t receive_capacity = 0;
    for (std::uint32_t index = 0; index < *iov_count; ++index) {
        const auto entry = *iov_address + index * arm32_iovec::size;
        const auto base = memory_.read32(entry + arm32_iovec::base_offset);
        const auto capacity =
            memory_.read32(entry + arm32_iovec::length_offset);
        if (!base || !capacity || (*capacity != 0 && *base == 0) ||
            *capacity > bsd_support::maximum_io ||
            receive_capacity > bsd_support::maximum_io - *capacity) {
            bsd_error(cpu, !base || !capacity || (*capacity != 0 && *base == 0)
                               ? efault
                               : einval);
            return true;
        }
        iovecs.push_back(GuestIovec { *base, *capacity });
        receive_capacity += *capacity;
    }

    if (const auto udp = virtual_udp_sockets_.find(fd);
        udp != virtual_udp_sockets_.end()) {
        if (udp->second->defunct()) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
            return true;
        }
        const auto received = udp->second->receive(receive_capacity);
        if (!received)
            return false;

        std::size_t source_offset = 0;
        for (const auto& iovec : iovecs) {
            const auto remaining = received->bytes.size() - source_offset;
            const auto count = std::min<std::size_t>(iovec.capacity, remaining);
            if (count != 0 &&
                !memory_.copy_in(iovec.base,
                    std::span<const std::byte> { received->bytes }.subspan(
                        source_offset, count))) {
                bsd_error(cpu, efault);
                return true;
            }
            source_offset += count;
            if (source_offset == received->bytes.size())
                break;
        }

        const auto actual_name_length =
            static_cast<std::uint32_t>(received->source_address.size());
        const auto copied_name_length =
            std::min(*name_capacity, actual_name_length);
        if (copied_name_length != 0 &&
            (*name_address == 0 ||
                !memory_.copy_in(*name_address,
                    std::span<const std::byte> { received->source_address }
                        .first(copied_name_length)))) {
            bsd_error(cpu, efault);
            return true;
        }

        const auto option_enabled = [&](std::uint32_t level,
                                        std::uint32_t option) {
            const auto descriptor = socket_options_.find(fd);
            if (descriptor == socket_options_.end())
                return false;
            const auto found = descriptor->second.find({ level, option });
            if (found == descriptor->second.end())
                return false;
            return std::any_of(found->second.begin(), found->second.end(),
                [](std::byte value) { return value != std::byte { 0 }; });
        };
        const auto family = udp->second->family();
        bsd::VirtualUdpAncillaryOptions options;
        if (family == darwin::network::address_family_inet) {
            options.receive_destination_address =
                option_enabled(darwin::network::protocol_ip,
                    darwin::network::ip_receive_destination_address);
            options.receive_interface =
                option_enabled(darwin::network::protocol_ip,
                    darwin::network::ip_receive_interface);
            options.receive_hop_limit = option_enabled(
                darwin::network::protocol_ip, darwin::network::ip_receive_ttl);
        } else {
            options.receive_destination_address =
                option_enabled(darwin::network::protocol_ipv6,
                    darwin::network::ipv6_packet_info);
            options.receive_hop_limit =
                option_enabled(darwin::network::protocol_ipv6,
                    darwin::network::ipv6_hop_limit);
        }
        const auto control =
            bsd::make_virtual_udp_ancillary(family, *received, options);
        const auto copied_control =
            std::min<std::size_t>(*control_capacity, control.size());
        std::uint32_t message_flags = 0;
        if (copied_control < control.size())
            message_flags |= message_control_truncated;
        if (copied_control != 0 &&
            (*control_address == 0 ||
                !memory_.copy_in(*control_address,
                    std::span<const std::byte> { control }.first(
                        copied_control)))) {
            bsd_error(cpu, efault);
            return true;
        }
        if (!memory_.write32(
                message_address + arm32_message::name_length_offset,
                actual_name_length) ||
            !memory_.write32(
                message_address + arm32_message::control_length_offset,
                static_cast<std::uint32_t>(copied_control)) ||
            !memory_.write32(
                message_address + arm32_message::flags_offset, message_flags)) {
            bsd_error(cpu, efault);
            return true;
        }
        bsd_success(cpu, static_cast<std::uint32_t>(received->bytes.size()));
        output_.write("[network] recvmsg virtual UDP fd=" + std::to_string(fd) +
                      " bytes=" + std::to_string(received->bytes.size()) +
                      " control=" + std::to_string(copied_control) + "\n");
        return true;
    }

    if (const auto host = host_sockets_.find(fd); host != host_sockets_.end()) {
        const auto received = host->second->receive(receive_capacity);
        if (received.status == HostSocketStatus::WouldBlock)
            return false;
        if (received.status == HostSocketStatus::Error) {
            bsd_error(cpu, received.darwin_error);
            return true;
        }

        std::size_t source_offset = 0;
        for (const auto& iovec : iovecs) {
            const auto count = std::min<std::size_t>(
                iovec.capacity, received.bytes.size() - source_offset);
            if (count != 0 &&
                !memory_.copy_in(iovec.base,
                    std::span<const std::byte> { received.bytes }.subspan(
                        source_offset, count))) {
                bsd_error(cpu, efault);
                return true;
            }
            source_offset += count;
            if (source_offset == received.bytes.size())
                break;
        }

        const auto actual_name_length = static_cast<std::uint32_t>(
            std::min<std::size_t>(received.address.size(),
                std::numeric_limits<std::uint32_t>::max()));
        const auto copied_name_length =
            std::min(*name_capacity, actual_name_length);
        if (copied_name_length != 0 &&
            (*name_address == 0 ||
                !memory_.copy_in(*name_address,
                    std::span<const std::byte> { received.address }.first(
                        copied_name_length)))) {
            bsd_error(cpu, efault);
            return true;
        }
        const auto option_enabled = [&](std::uint32_t level,
                                        std::uint32_t option) {
            const auto descriptor = socket_options_.find(fd);
            if (descriptor == socket_options_.end())
                return false;
            const auto found = descriptor->second.find({ level, option });
            if (found == descriptor->second.end() || found->second.empty()) {
                return false;
            }
            std::uint32_t enabled = 0;
            for (std::size_t byte = 0;
                byte < std::min(found->second.size(), sizeof(enabled));
                ++byte) {
                enabled |= std::to_integer<std::uint32_t>(found->second[byte])
                           << (byte * 8U);
            }
            return enabled != 0;
        };
        std::vector<std::byte> guest_control;
        const auto append_u32 = [](std::vector<std::byte>& bytes,
                                    std::uint32_t value) {
            for (std::size_t byte = 0; byte < sizeof(value); ++byte) {
                bytes.push_back(static_cast<std::byte>(value >> (byte * 8U)));
            }
        };
        const auto append_control = [&](std::uint32_t level, std::uint32_t type,
                                        std::span<const std::byte> payload) {
            const auto length = darwin::network::arm32_control_header_size +
                                static_cast<std::uint32_t>(payload.size());
            append_u32(guest_control, length);
            append_u32(guest_control, level);
            append_u32(guest_control, type);
            guest_control.insert(
                guest_control.end(), payload.begin(), payload.end());
            while ((guest_control.size() & 3U) != 0) {
                guest_control.push_back(std::byte { 0 });
            }
        };
        const auto received_interface_index = received.interface_index.value_or(
            host_network_policy_ == HostNetworkPolicy::Loopback ? 1U : 2U);
        const auto interface_name = received_interface_index == 1U
                                        ? std::string { "lo0" }
                                        : std::string { "en0" };
        darwin::network::InterfaceSnapshot receive_interface;
        if (const auto snapshot = network_interface_snapshot(interface_name)) {
            receive_interface = *snapshot;
        } else {
            receive_interface.name = interface_name;
            receive_interface.index = interface_name == "lo0" ? 1U : 2U;
            receive_interface.type =
                interface_name == "lo0"
                    ? darwin::network::interface_type_loopback
                    : darwin::network::interface_type_ethernet;
        }
        if (host->second->darwin_family() ==
            darwin::network::address_family_inet) {
            if (option_enabled(darwin::network::protocol_ip,
                    darwin::network::ip_receive_destination_address)) {
                std::array<std::byte, 4> destination { };
                std::copy_n(received.destination_address.begin(),
                    std::min(destination.size(),
                        received.destination_address.size()),
                    destination.begin());
                append_control(darwin::network::protocol_ip,
                    darwin::network::ip_receive_destination_address,
                    destination);
            }
            if (option_enabled(darwin::network::protocol_ip,
                    darwin::network::ip_receive_interface)) {
                std::array<std::byte, darwin::network::arm32_sockaddr_dl_size>
                    link { };
                link[0] = static_cast<std::byte>(link.size());
                link[1] = static_cast<std::byte>(
                    darwin::network::address_family_link);
                link[2] = static_cast<std::byte>(receive_interface.index);
                link[3] = static_cast<std::byte>(receive_interface.index >> 8U);
                link[4] = static_cast<std::byte>(receive_interface.type);
                const auto name_length =
                    std::min<std::size_t>(receive_interface.name.size(), 12U);
                link[5] = static_cast<std::byte>(name_length);
                link[6] = static_cast<std::byte>(std::min<std::size_t>(
                    receive_interface.link_address_length, 12U - name_length));
                for (std::size_t index = 0; index < name_length; ++index) {
                    link[8U + index] =
                        static_cast<std::byte>(receive_interface.name[index]);
                }
                for (std::size_t index = 0;
                    index < std::to_integer<std::uint8_t>(link[6]); ++index) {
                    link[8U + name_length + index] =
                        receive_interface.link_address[index];
                }
                append_control(darwin::network::protocol_ip,
                    darwin::network::ip_receive_interface, link);
            }
            if (option_enabled(darwin::network::protocol_ip,
                    darwin::network::ip_receive_ttl) &&
                received.hop_limit) {
                const std::array ttl { static_cast<std::byte>(
                    *received.hop_limit) };
                append_control(darwin::network::protocol_ip,
                    darwin::network::ip_receive_ttl, ttl);
            }
        } else if (host->second->darwin_family() ==
                   darwin::network::address_family_inet6) {
            if (option_enabled(darwin::network::protocol_ipv6,
                    darwin::network::ipv6_packet_info)) {
                std::array<std::byte, 20> packet_info { };
                std::copy_n(received.destination_address.begin(),
                    std::min<std::size_t>(
                        16, received.destination_address.size()),
                    packet_info.begin());
                for (std::size_t byte = 0; byte < sizeof(std::uint32_t);
                    ++byte) {
                    packet_info[16U + byte] = static_cast<std::byte>(
                        received_interface_index >> (byte * 8U));
                }
                append_control(darwin::network::protocol_ipv6,
                    darwin::network::ipv6_packet_info, packet_info);
            }
            if (option_enabled(darwin::network::protocol_ipv6,
                    darwin::network::ipv6_hop_limit) &&
                received.hop_limit) {
                std::array<std::byte, 4> hop_limit { };
                for (std::size_t byte = 0; byte < hop_limit.size(); ++byte) {
                    hop_limit[byte] = static_cast<std::byte>(
                        *received.hop_limit >> (byte * 8U));
                }
                append_control(darwin::network::protocol_ipv6,
                    darwin::network::ipv6_hop_limit, hop_limit);
            }
        }
        const auto copied_control =
            std::min<std::size_t>(*control_capacity, guest_control.size());
        std::uint32_t message_flags = 0;
        if (copied_control < guest_control.size()) {
            message_flags |= message_control_truncated;
        }
        if (copied_control != 0 &&
            (*control_address == 0 ||
                !memory_.copy_in(*control_address,
                    std::span<const std::byte> { guest_control }.first(
                        copied_control)))) {
            bsd_error(cpu, efault);
            return true;
        }
        if (!memory_.write32(
                message_address + arm32_message::name_length_offset,
                actual_name_length) ||
            !memory_.write32(
                message_address + arm32_message::control_length_offset,
                static_cast<std::uint32_t>(copied_control)) ||
            !memory_.write32(
                message_address + arm32_message::flags_offset, message_flags)) {
            bsd_error(cpu, efault);
            return true;
        }
        bsd_success(cpu, static_cast<std::uint32_t>(received.transferred));
        output_.write("[network] recvmsg host fd=" + std::to_string(fd) +
                      " bytes=" + std::to_string(received.transferred) +
                      " iov=" + std::to_string(iovecs.size()) + "\n");
        return true;
    }

    const auto endpoint = socket_pair_endpoints_.find(fd);
    if (endpoint == socket_pair_endpoints_.end()) {
        bsd_error(cpu, virtual_descriptors_.contains(fd) ? enotconn : ebadf);
        return true;
    }
    std::lock_guard socket_lock { shared_state_->socket_mutex };
    auto& source =
        shared_state_
            ->socket_pair_buffers[endpoint->second.pair][endpoint->second.side];
    const auto lifetime = endpoint->second.description
                              ? endpoint->second.description->lifetime
                              : nullptr;
    if (!lifetime) {
        bsd_error(cpu, ebadf);
        return true;
    }
    const bool end_of_stream = !endpoint->second.local_read_open() ||
                               !endpoint->second.peer_write_open();
    if (source.empty() && !end_of_stream)
        return false;
    const auto read_begin = lifetime->read_offsets[endpoint->second.side];
    std::uint32_t total = 0;
    for (const auto& iovec : iovecs) {
        if (source.empty())
            break;
        const auto count = std::min<std::size_t>(iovec.capacity, source.size());
        std::vector<std::byte> bytes;
        bytes.reserve(count);
        for (std::size_t byte = 0; byte < count; ++byte) {
            bytes.push_back(source.front());
            source.pop_front();
        }
        if (!memory_.copy_in(iovec.base, bytes)) {
            bsd_error(cpu, efault);
            return true;
        }
        total += static_cast<std::uint32_t>(count);
    }
    const auto read_end = read_begin + total;
    lifetime->read_offsets[endpoint->second.side] = read_end;
    std::vector<KernelSharedState::DescriptorTransfer> transfers;
    auto& ancillary =
        shared_state_->socket_pair_ancillary[endpoint->second.pair]
                                            [endpoint->second.side];
    while (!ancillary.empty() && ancillary.front().byte_offset < read_begin) {
        ancillary.pop_front();
    }
    while (!ancillary.empty() && ancillary.front().byte_offset < read_end) {
        auto record = std::move(ancillary.front());
        ancillary.pop_front();
        transfers.insert(transfers.end(),
            std::make_move_iterator(record.transfers.begin()),
            std::make_move_iterator(record.transfers.end()));
    }
    std::vector<std::uint32_t> received_fds;
    const auto required_control =
        static_cast<std::uint32_t>(12U + transfers.size() * 4U);
    std::uint32_t message_flags = 0;
    if (!transfers.empty() &&
        (*control_address == 0 || *control_capacity < required_control)) {
        message_flags |= message_control_truncated;
    } else if (!transfers.empty()) {
        for (const auto& transfer : transfers) {
            const auto imported = import_descriptor(transfer);
            if (!imported) {
                bsd_error(cpu, 24); // EMFILE
                return true;
            }
            received_fds.push_back(*imported);
        }
        if (!memory_.write32(*control_address, required_control) ||
            !memory_.write32(*control_address + 4, 0xffffU) ||
            !memory_.write32(*control_address + 8, 1U)) {
            bsd_error(cpu, efault);
            return true;
        }
        for (std::size_t index = 0; index < received_fds.size(); ++index) {
            if (!memory_.write32(*control_address + 12U +
                                     static_cast<std::uint32_t>(index * 4U),
                    received_fds[index])) {
                bsd_error(cpu, efault);
                return true;
            }
        }
    }
    const auto actual_control =
        transfers.empty() || message_flags != 0 ? 0U : required_control;
    if (!memory_.write32(message_address + arm32_message::control_length_offset,
            actual_control) ||
        !memory_.write32(
            message_address + arm32_message::flags_offset, message_flags)) {
        bsd_error(cpu, efault);
        return true;
    }
    bsd_success(cpu, total);
    output_.write("[network] recvmsg fd=" + std::to_string(fd) +
                  " bytes=" + std::to_string(total) +
                  " rights=" + std::to_string(received_fds.size()) + "\n");
    return true;
}

bool CompatibilityKernel::receive_socket_bytes(Cpu& cpu, std::uint32_t fd,
    std::uint32_t address, std::uint32_t size, std::uint32_t source_address,
    std::uint32_t source_length_address)
{
    if (size == 0) {
        bsd_success(cpu, 0);
        return true;
    }
    if (bpf_descriptors_.contains(fd)) {
        return receive_bpf_bytes(cpu, fd, address, size);
    }
    if (const auto event_stream = wifi_driver_event_streams_.find(fd);
        event_stream != wifi_driver_event_streams_.end() &&
        event_stream->second && event_stream->second->readable()) {
        const auto previous_format = event_stream->second->format();
        const auto bytes = event_stream->second->prepare_read(size);
        if (!memory_.copy_in(address, bytes)) {
            bsd_error(cpu, darwin::error::bad_address);
        } else {
            if (previous_format == darwin::network::apple80211_driver::
                                        EventStreamFormat::Undetected) {
                output_.write(
                    "[wifi-driver] event-stream pid=" +
                    std::to_string(process_.pid) + " fd=" + std::to_string(fd) +
                    " profile=" +
                    std::string { event_stream->second->format_name() } +
                    " read-capacity=" + std::to_string(size) + "\n");
            }
            event_stream->second->consume(bytes.size());
            bsd_success(cpu, static_cast<std::uint32_t>(bytes.size()));
        }
        return true;
    }
    if (const auto descriptor = virtual_descriptors_.find(fd);
        descriptor != virtual_descriptors_.end() &&
        descriptor->second == bsd::offline_serial_device::descriptor_kind) {
        const auto bytes = offline_serial_state_.read(size);
        if (bytes.empty())
            return false;
        if (!memory_.copy_in(address, bytes)) {
            bsd_error(cpu, darwin::error::bad_address);
        } else {
            bsd_success(cpu, static_cast<std::uint32_t>(bytes.size()));
        }
        return true;
    }
    if (const auto host = host_sockets_.find(fd); host != host_sockets_.end()) {
        const auto received = host->second->receive(size);
        if (received.status == HostSocketStatus::WouldBlock)
            return false;
        if (received.status == HostSocketStatus::Error) {
            bsd_error(cpu, received.darwin_error);
            return true;
        }
        if (!memory_.copy_in(address, received.bytes) ||
            !copy_socket_address(
                source_address, source_length_address, received.address)) {
            bsd_error(cpu, darwin::error::bad_address);
        } else {
            bsd_success(cpu, static_cast<std::uint32_t>(received.transferred));
        }
        return true;
    }
    if (const auto udp = virtual_udp_sockets_.find(fd);
        udp != virtual_udp_sockets_.end()) {
        if (udp->second->defunct()) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
            return true;
        }
        const auto received = udp->second->receive(size);
        if (!received)
            return false;
        if (!memory_.copy_in(address, received->bytes) ||
            !copy_socket_address(source_address, source_length_address,
                received->source_address)) {
            bsd_error(cpu, darwin::error::bad_address);
        } else {
            bsd_success(
                cpu, static_cast<std::uint32_t>(received->bytes.size()));
            output_.write(
                "[network] virtual UDP receive fd=" + std::to_string(fd) +
                " bytes=" + std::to_string(received->bytes.size()) + "\n");
        }
        return true;
    }
    if (const auto descriptor = virtual_descriptors_.find(fd);
        descriptor != virtual_descriptors_.end() &&
        descriptor->second == bsd::baseband_device::descriptor_kind) {
        const auto endpoint = baseband_open_description(fd);
        auto bytes =
            endpoint ? endpoint->receive(size) : std::vector<std::byte> { };
        if (bytes.empty()) {
            if (endpoint && endpoint->receive_eof()) {
                bsd_success(cpu, 0);
                return true;
            }
            return false;
        }
        if (!memory_.copy_in(address, bytes)) {
            bsd_error(cpu, darwin::error::bad_address);
        } else {
            bsd_success(cpu, static_cast<std::uint32_t>(bytes.size()));
            output_.write(
                "[baseband] read pid=" + std::to_string(process_.pid) + " fd=" +
                std::to_string(fd) + " bytes=" + std::to_string(bytes.size()) +
                " hex=" + bsd_support::format_payload_prefix(bytes) + "\n");
        }
        return true;
    }
    if (const auto descriptor = virtual_descriptors_.find(fd);
        descriptor != virtual_descriptors_.end() &&
        descriptor->second == "system-event-socket") {
        const auto event = consume_system_event(fd);
        if (!event)
            return false;
        const auto copied_size =
            std::min<std::size_t>(size, event->bytes.size());
        if (!memory_.copy_in(
                address, std::span<const std::byte> { event->bytes }.first(
                             copied_size))) {
            bsd_error(cpu, darwin::error::bad_address);
        } else {
            bsd_success(cpu, static_cast<std::uint32_t>(copied_size));
            output_.write(
                "[network] kern_event id=" + std::to_string(event->identifier) +
                " code=" + std::to_string(event->event_code) + "\n");
        }
        return true;
    }
    if (const auto descriptor = virtual_descriptors_.find(fd);
        descriptor != virtual_descriptors_.end() &&
        descriptor->second == "route-socket") {
        const auto message = consume_route_message(fd);
        if (!message)
            return false;
        const auto copied_size =
            std::min<std::size_t>(size, message->bytes.size());
        if (!memory_.copy_in(
                address, std::span<const std::byte> { message->bytes }.first(
                             copied_size))) {
            bsd_error(cpu, darwin::error::bad_address);
        } else {
            bsd_success(cpu, static_cast<std::uint32_t>(copied_size));
        }
        return true;
    }
    const auto endpoint = socket_pair_endpoints_.find(fd);
    if (endpoint == socket_pair_endpoints_.end())
        return false;
    std::vector<std::byte> bytes;
    {
        std::lock_guard socket_lock { shared_state_->socket_mutex };
        const auto pair =
            shared_state_->socket_pair_buffers.find(endpoint->second.pair);
        if (pair == shared_state_->socket_pair_buffers.end())
            return false;
        auto& pending = pair->second[endpoint->second.side];
        const auto lifetime = endpoint->second.description
                                  ? endpoint->second.description->lifetime
                                  : nullptr;
        if (!lifetime)
            return false;
        const bool end_of_stream = !endpoint->second.local_read_open() ||
                                   !endpoint->second.peer_write_open();
        if (pending.empty() && !end_of_stream)
            return false;
        const auto count = std::min<std::size_t>(size, pending.size());
        bytes.resize(count);
        for (auto& byte : bytes) {
            byte = pending.front();
            pending.pop_front();
        }
        const auto side = endpoint->second.side;
        lifetime->read_offsets[side] += count;
        auto& ancillary =
            shared_state_->socket_pair_ancillary[endpoint->second.pair][side];
        while (!ancillary.empty() &&
               ancillary.front().byte_offset < lifetime->read_offsets[side]) {
            // read/recv without a control buffer consumes and discards rights
            // attached to bytes in that range, matching SOCK_STREAM semantics.
            ancillary.pop_front();
        }
    }
    if (!memory_.copy_in(address, bytes)) {
        bsd_error(cpu, darwin::error::bad_address);
    } else {
        bsd_success(cpu, static_cast<std::uint32_t>(bytes.size()));
        output_.write("[network] read fd=" + std::to_string(fd) +
                      " bytes=" + std::to_string(bytes.size()) + "\n");
    }
    return true;
}

bool CompatibilityKernel::copy_socket_address(std::uint32_t address,
    std::uint32_t length_address, std::span<const std::byte> socket_address)
{
    if (address == 0 && length_address == 0)
        return true;
    if (address == 0 || length_address == 0)
        return false;
    const auto capacity = memory_.read32(length_address);
    if (!capacity)
        return false;
    const auto copied = std::min<std::size_t>(*capacity, socket_address.size());
    return (copied == 0 ||
               memory_.copy_in(address, socket_address.first(copied))) &&
           memory_.write32(length_address,
               static_cast<std::uint32_t>(socket_address.size()));
}

bool CompatibilityKernel::complete_unix_accept(Cpu& cpu,
    std::uint32_t listener_fd, std::uint32_t address,
    std::uint32_t length_address)
{
    if (!virtual_descriptors_.contains(listener_fd)) {
        bsd_error(cpu, ebadf);
        return true;
    }
    if (!listening_sockets_.contains(listener_fd)) {
        bsd_error(cpu, einval);
        return true;
    }
    const auto listener = unix_listener_states_.find(listener_fd);
    if (listener == unix_listener_states_.end()) {
        const auto descriptor = virtual_descriptors_.find(listener_fd);
        if (descriptor != virtual_descriptors_.end() &&
            kernel_network::is_isolated_stream_descriptor(descriptor->second)) {
            // No route can produce a peer while isolated. A blocking accept
            // therefore remains asleep, just as it would on an empty local
            // listener, instead of failing merely because no HostSocket exists.
            return false;
        }
        bsd_error(cpu, einval);
        return true;
    }

    std::lock_guard socket_lock { shared_state_->socket_mutex };
    if (listener->second->pending_endpoints.empty())
        return false;
    const auto accepted_fd = allocate_file_descriptor();
    if (!accepted_fd) {
        bsd_error(cpu, 24); // EMFILE
        return true;
    }
    auto accepted_endpoint =
        std::move(listener->second->pending_endpoints.front());
    listener->second->pending_endpoints.pop_front();
    const auto pair = accepted_endpoint.pair;
    virtual_descriptors_[*accepted_fd] = "unix-stream";
    socket_pair_endpoints_[*accepted_fd] = std::move(accepted_endpoint);
    file_status_flags_[*accepted_fd] = darwin::open_flag::read_write;
    descriptor_flags_[*accepted_fd] = 0;

    constexpr std::array<std::byte, 2> unnamed_peer { std::byte { 2 },
        static_cast<std::byte>(darwin::socket::local) };
    if (!copy_socket_address(address, length_address, unnamed_peer)) {
        virtual_descriptors_.erase(*accepted_fd);
        socket_pair_endpoints_.erase(*accepted_fd);
        file_status_flags_.erase(*accepted_fd);
        descriptor_flags_.erase(*accepted_fd);
        bsd_error(cpu, efault);
        return true;
    }
    output_.write("[network] accept pid=" + std::to_string(process_.pid) +
                  " listener-fd=" + std::to_string(listener_fd) +
                  " fd=" + std::to_string(*accepted_fd) +
                  " pair=" + std::to_string(pair) + "\n");
    bsd_success(cpu, *accepted_fd);
    return true;
}

std::optional<std::uint32_t> CompatibilityKernel::install_host_socket(
    std::shared_ptr<HostSocket> socket)
{
    if (!socket)
        return std::nullopt;
    const auto fd = allocate_file_descriptor();
    if (!fd)
        return std::nullopt;
    const auto ipv6 =
        socket->darwin_family() == darwin::network::address_family_inet6;
    const auto stream = socket->darwin_type() == 1;
    virtual_descriptors_[*fd] = ipv6 ? (stream ? "inet6-stream" : "inet6-dgram")
                                     : (stream ? "inet-stream" : "inet-dgram");
    host_sockets_[*fd] = std::move(socket);
    file_status_flags_[*fd] = darwin::open_flag::read_write;
    descriptor_flags_[*fd] = 0;
    return fd;
}

void CompatibilityKernel::apply_wifi_transition(
    const WifiSnapshot& before, const WifiSnapshot& after)
{
    constexpr std::string_view name { "en0" };
    bool flags_changed = false;
    bool address_added = false;
    bool address_deleted = false;
    std::optional<darwin::network::InterfaceSnapshot> deleted_address_snapshot;
    {
        std::lock_guard network_lock { shared_state_->network_mutex };
        const auto found =
            shared_state_->network_interfaces.find(std::string { name });
        if (found == shared_state_->network_interfaces.end())
            return;
        auto& interface = found->second;
        const auto previous_flags = interface.flags;
        const auto previous_ipv4 = interface.has_ipv4;
        if (previous_ipv4 && !after.ipv4) {
            deleted_address_snapshot =
                kernel_network::make_interface_snapshot(name, interface);
        }

        if (after.powered) {
            interface.flags = static_cast<std::uint16_t>(
                interface.flags | darwin::network::interface_flag_up);
        } else {
            interface.flags = static_cast<std::uint16_t>(
                interface.flags &
                static_cast<std::uint16_t>(
                    ~(darwin::network::interface_flag_up |
                        darwin::network::interface_flag_running |
                        darwin::network::interface_flag_output_active)));
        }
        if (after.associated_access_point) {
            interface.flags = static_cast<std::uint16_t>(
                interface.flags | darwin::network::interface_flag_running |
                darwin::network::interface_flag_output_active);
        } else {
            interface.flags = static_cast<std::uint16_t>(
                interface.flags &
                static_cast<std::uint16_t>(
                    ~(darwin::network::interface_flag_running |
                        darwin::network::interface_flag_output_active)));
        }

        interface.has_ipv4 = after.ipv4.has_value();
        interface.ipv4_address = { };
        interface.ipv4_netmask = { };
        interface.ipv4_broadcast = { };
        interface.ipv4_gateway = { };
        if (after.ipv4) {
            const auto make_sockaddr =
                [](const std::array<std::byte, 4>& value) {
                    std::array<std::byte, 16> result { };
                    result[0] = std::byte { 16 };
                    result[1] = static_cast<std::byte>(
                        darwin::network::address_family_inet);
                    std::copy(value.begin(), value.end(), result.begin() + 4);
                    return result;
                };
            interface.ipv4_address = make_sockaddr(after.ipv4->address);
            interface.ipv4_netmask = make_sockaddr(after.ipv4->netmask);
            interface.ipv4_broadcast = make_sockaddr(after.ipv4->broadcast);
            interface.ipv4_gateway = make_sockaddr(after.ipv4->gateway);
        }
        flags_changed = previous_flags != interface.flags;
        address_added = !previous_ipv4 && interface.has_ipv4;
        address_deleted = previous_ipv4 && !interface.has_ipv4;
    }

    synchronize_interface_routes(name, darwin::network::address_family_inet);

    const auto was_linked = before.associated_access_point.has_value();
    const auto is_linked = after.associated_access_point.has_value();
    if (was_linked != is_linked) {
        post_data_link_event(
            name, is_linked ? darwin::network::kernel_event_link_on
                            : darwin::network::kernel_event_link_off);
    }
    if (flags_changed) {
        post_data_link_event(
            name, darwin::network::kernel_event_interface_flags_changed);
    }
    if (address_added) {
        post_network_event(name, darwin::network::kernel_event_inet_subclass,
            darwin::network::kernel_event_inet_new_address);
    } else if (address_deleted) {
        post_network_event(name, darwin::network::kernel_event_inet_subclass,
            darwin::network::kernel_event_inet_address_deleted,
            std::move(deleted_address_snapshot));
    }
}

void CompatibilityKernel::post_network_event(std::string_view interface_name,
    std::uint32_t event_subclass, std::uint32_t event_code,
    std::optional<darwin::network::InterfaceSnapshot> address_snapshot)
{
    darwin::network::InterfaceSnapshot snapshot;
    if (address_snapshot) {
        snapshot = std::move(*address_snapshot);
    } else {
        std::lock_guard network_lock { shared_state_->network_mutex };
        const auto interface = shared_state_->network_interfaces.find(
            std::string { interface_name });
        if (interface == shared_state_->network_interfaces.end())
            return;
        snapshot = kernel_network::make_interface_snapshot(
            interface->first, interface->second);
    }
    const auto event_data =
        event_subclass == darwin::network::kernel_event_inet_subclass
            ? darwin::network::make_ipv4_network_event_data(snapshot)
            : (event_subclass == darwin::network::kernel_event_inet6_subclass
                      ? darwin::network::make_ipv6_network_event_data(snapshot)
                      : darwin::network::make_network_event_data(snapshot));

    std::lock_guard socket_lock { shared_state_->socket_mutex };
    const auto identifier = shared_state_->next_kernel_event_identifier++;
    KernelSharedState::KernelEvent event {
        identifier,
        darwin::network::kernel_event_vendor_apple,
        darwin::network::kernel_event_network_class,
        event_subclass,
        event_code,
        darwin::network::make_kernel_event(identifier,
            darwin::network::kernel_event_vendor_apple,
            darwin::network::kernel_event_network_class, event_subclass,
            event_code, event_data),
    };
    shared_state_->kernel_events.push_back(std::move(event));
    while (shared_state_->kernel_events.size() >
           darwin::network::maximum_retained_kernel_events) {
        shared_state_->kernel_events.pop_front();
    }
    shared_state_->note_io_event_transition();
}

void CompatibilityKernel::post_data_link_event(
    std::string_view interface_name, std::uint32_t event_code)
{
    post_network_event(interface_name,
        darwin::network::kernel_event_data_link_subclass, event_code);
}

bool CompatibilityKernel::system_event_matches(
    std::uint32_t fd, const KernelSharedState::KernelEvent& event) const
{
    const auto filter = system_event_filters_.find(fd);
    if (filter == system_event_filters_.end())
        return true;
    const auto [vendor, event_class, subclass] = filter->second;
    if (vendor == darwin::network::kernel_event_any)
        return true;
    if (vendor != event.vendor)
        return false;
    if (event_class == darwin::network::kernel_event_any)
        return true;
    if (event_class != event.event_class)
        return false;
    return subclass == darwin::network::kernel_event_any ||
           subclass == event.event_subclass;
}

bool CompatibilityKernel::system_event_available(std::uint32_t fd) const
{
    const auto cursor = system_event_next_identifiers_.find(fd);
    if (cursor == system_event_next_identifiers_.end())
        return false;
    std::lock_guard socket_lock { shared_state_->socket_mutex };
    return std::any_of(shared_state_->kernel_events.begin(),
        shared_state_->kernel_events.end(), [&](const auto& event) {
            return event.identifier >= cursor->second &&
                   system_event_matches(fd, event);
        });
}

std::optional<KernelSharedState::KernelEvent>
CompatibilityKernel::consume_system_event(std::uint32_t fd)
{
    const auto cursor = system_event_next_identifiers_.find(fd);
    if (cursor == system_event_next_identifiers_.end())
        return std::nullopt;
    std::lock_guard socket_lock { shared_state_->socket_mutex };
    const auto event = std::find_if(shared_state_->kernel_events.begin(),
        shared_state_->kernel_events.end(), [&](const auto& candidate) {
            return candidate.identifier >= cursor->second &&
                   system_event_matches(fd, candidate);
        });
    if (event == shared_state_->kernel_events.end())
        return std::nullopt;
    cursor->second = event->identifier + 1U;
    return *event;
}

bool CompatibilityKernel::route_message_available(std::uint32_t fd) const
{
    const auto socket = route_socket_states_.find(fd);
    if (socket == route_socket_states_.end() || !socket->second)
        return false;
    const auto& state = *socket->second;
    std::lock_guard route_lock { shared_state_->route_socket_mutex };
    return std::any_of(shared_state_->route_socket_messages.begin(),
        shared_state_->route_socket_messages.end(), [&](const auto& message) {
            const auto receiver_matches =
                !message.receiver_socket ||
                *message.receiver_socket == state.identifier;
            const auto family_matches = message.receiver_socket ||
                                        state.protocol == 0 ||
                                        state.protocol == message.family;
            return message.identifier >= state.next_message_identifier &&
                   receiver_matches && family_matches;
        });
}

std::optional<KernelSharedState::RouteSocketMessage>
CompatibilityKernel::consume_route_message(std::uint32_t fd)
{
    const auto socket = route_socket_states_.find(fd);
    if (socket == route_socket_states_.end() || !socket->second) {
        return std::nullopt;
    }
    auto& state = *socket->second;
    std::lock_guard route_lock { shared_state_->route_socket_mutex };
    const auto message = std::find_if(
        shared_state_->route_socket_messages.begin(),
        shared_state_->route_socket_messages.end(), [&](const auto& candidate) {
            const auto receiver_matches =
                !candidate.receiver_socket ||
                *candidate.receiver_socket == state.identifier;
            const auto family_matches = candidate.receiver_socket ||
                                        state.protocol == 0 ||
                                        state.protocol == candidate.family;
            return candidate.identifier >= state.next_message_identifier &&
                   receiver_matches && family_matches;
        });
    if (message == shared_state_->route_socket_messages.end())
        return std::nullopt;
    state.next_message_identifier = message->identifier + 1U;
    return *message;
}

void CompatibilityKernel::post_route_message(std::vector<std::byte> bytes,
    std::uint8_t family, std::optional<std::uint64_t> receiver_socket)
{
    std::lock_guard route_lock { shared_state_->route_socket_mutex };
    KernelSharedState::RouteSocketMessage message;
    message.identifier = shared_state_->next_route_message_identifier++;
    message.bytes = std::move(bytes);
    message.family = family;
    message.receiver_socket = receiver_socket;
    shared_state_->route_socket_messages.push_back(std::move(message));
    while (shared_state_->route_socket_messages.size() >
           darwin::route::maximum_retained_messages) {
        shared_state_->route_socket_messages.pop_front();
    }
    shared_state_->note_io_event_transition();
}

void CompatibilityKernel::synchronize_interface_routes(
    std::string_view interface_name, std::uint8_t family)
{
    KernelSharedState::NetworkInterface interface;
    {
        std::lock_guard network_lock { shared_state_->network_mutex };
        const auto found = shared_state_->network_interfaces.find(
            std::string { interface_name });
        if (found == shared_state_->network_interfaces.end())
            return;
        interface = found->second;
    }

    std::vector<darwin::route::Entry> replacements;
    if (family == darwin::network::address_family_inet && interface.has_ipv4) {
        const auto loopback =
            (interface.flags & darwin::network::interface_flag_loopback) != 0;
        const auto flags =
            darwin::route::flag_up | (loopback ? darwin::route::flag_host : 0U);
        const auto mask =
            loopback ? std::span<const std::byte> { }
                     : std::span<const std::byte> { interface.ipv4_netmask };
        if (auto route = darwin::route::make_interface_route(
                std::string { interface_name }, interface.index,
                interface.ipv4_address, mask, flags)) {
            replacements.push_back(std::move(*route));
        }
        if (!loopback) {
            if (auto route = darwin::route::make_default_gateway_route(
                    std::string { interface_name }, interface.index,
                    interface.ipv4_gateway)) {
                replacements.push_back(std::move(*route));
            }
        }
    } else if (family == darwin::network::address_family_inet6 &&
               interface.has_ipv6) {
        const auto mask_is_host =
            std::all_of(interface.ipv6_netmask.begin() + 8,
                interface.ipv6_netmask.begin() + 24,
                [](std::byte byte) { return byte == std::byte { 0xff }; });
        if (!mask_is_host) {
            if (auto prefix = darwin::route::make_interface_route(
                    std::string { interface_name }, interface.index,
                    interface.ipv6_address, interface.ipv6_netmask,
                    darwin::route::flag_up | darwin::route::flag_cloning)) {
                replacements.push_back(std::move(*prefix));
            }
        }
        if (auto local = darwin::route::make_interface_route(
                std::string { interface_name }, interface.index,
                interface.ipv6_address, { },
                darwin::route::flag_up | darwin::route::flag_host |
                    darwin::route::flag_local)) {
            replacements.push_back(std::move(*local));
        }
    }

    darwin::route::InterfaceRouteUpdate update;
    const auto address_configured =
        (family == darwin::network::address_family_inet &&
            interface.has_ipv4) ||
        (family == darwin::network::address_family_inet6 && interface.has_ipv6);
    if (address_configured) {
        update = shared_state_->route_table.replace_interface_routes(
            interface_name, family, replacements);
    } else {
        update.removed = shared_state_->route_table.remove_interface_routes(
            interface_name, interface.index, family);
    }
    for (const auto& removed : update.removed) {
        post_route_message(darwin::route::make_entry_message(removed, 0, 0,
                               false, false, darwin::route::message_delete),
            removed.family);
    }
    for (const auto& added : update.added) {
        post_route_message(darwin::route::make_entry_message(added, 0, 0, false,
                               false, darwin::route::message_add),
            added.family);
    }
    if (!update.removed.empty() || !update.added.empty()) {
        output_.write(
            "[network] interface routes if=" + std::string { interface_name } +
            " family=" + std::to_string(family) +
            " removed=" + std::to_string(update.removed.size()) +
            " added=" + std::to_string(update.added.size()) + "\n");
    }
}

bool CompatibilityKernel::descriptor_readable(std::uint32_t fd) const
{
    if (file_descriptors_.contains(fd))
        return true;
    if (bpf_descriptor_readable(fd))
        return true;
    if (const auto descriptor = virtual_descriptors_.find(fd);
        descriptor != virtual_descriptors_.end() &&
        descriptor->second == "random") {
        // Entropy character devices always have bytes available. OpenSSL's
        // RAND_poll probes them with select(2) before issuing read(2).
        return true;
    }
    if (const auto event_stream = wifi_driver_event_streams_.find(fd);
        event_stream != wifi_driver_event_streams_.end() &&
        event_stream->second && event_stream->second->readable()) {
        return true;
    }
    if (const auto descriptor = virtual_descriptors_.find(fd);
        descriptor != virtual_descriptors_.end() &&
        descriptor->second == bsd::baseband_device::descriptor_kind) {
        if (const auto endpoint = baseband_open_description(fd);
            endpoint && (endpoint->pending_receive_bytes() != 0 ||
                            endpoint->receive_eof())) {
            return true;
        }
    }
    if (const auto descriptor = virtual_descriptors_.find(fd);
        descriptor != virtual_descriptors_.end() &&
        descriptor->second == bsd::offline_serial_device::descriptor_kind &&
        offline_serial_state_.pending_bytes() != 0) {
        return true;
    }
    if (const auto host = host_sockets_.find(fd);
        host != host_sockets_.end() && host->second->readable()) {
        return true;
    }
    if (const auto udp = virtual_udp_sockets_.find(fd);
        udp != virtual_udp_sockets_.end() && udp->second->readable()) {
        return true;
    }
    if (listening_sockets_.contains(fd)) {
        if (const auto listener = unix_listener_states_.find(fd);
            listener != unix_listener_states_.end()) {
            std::lock_guard socket_lock { shared_state_->socket_mutex };
            if (!listener->second->pending_endpoints.empty()) {
                return true;
            }
        }
    }
    const auto socket_ready = [&](std::uint32_t socket_fd) {
        const auto endpoint = socket_pair_endpoints_.find(socket_fd);
        if (endpoint == socket_pair_endpoints_.end())
            return false;
        std::lock_guard socket_lock { shared_state_->socket_mutex };
        const auto pair =
            shared_state_->socket_pair_buffers.find(endpoint->second.pair);
        return pair != shared_state_->socket_pair_buffers.end() &&
               (!pair->second[endpoint->second.side].empty() ||
                   !endpoint->second.local_read_open() ||
                   !endpoint->second.peer_write_open());
    };
    if (socket_ready(fd))
        return true;
    if (system_event_available(fd))
        return true;
    if (route_message_available(fd))
        return true;
    const auto queue = kqueues_.find(fd);
    if (queue == kqueues_.end())
        return false;
    return std::any_of(
        queue->second.begin(), queue->second.end(), [&](const auto& event) {
            return (event.ident != fd &&
                       event.filter == darwin::kqueue::filter_read &&
                       descriptor_readable(static_cast<std::uint32_t>(event.ident))) ||
                   (event.filter == darwin::kqueue::filter_write &&
                       descriptor_writable(static_cast<std::uint32_t>(event.ident))) ||
                   (event.filter == darwin::kqueue::filter_mach_port &&
                       ready_mach_kevent_name(event).has_value()) ||
                   (event.enabled && event.timer &&
                       event.timer->expirations(shared_state_->clock.now()) != 0) ||
                   (event.enabled &&
                       event.filter == darwin::kqueue::filter_vnode &&
                       event.vnode_watch &&
                       (event.vnode_watch->pending(
                            *shared_state_->guest_file_generation_registry) &
                           event.filter_flags) != 0U);
        });
}

bool CompatibilityKernel::descriptor_writable(std::uint32_t fd) const
{
    if (fd == 1 || fd == 2 || file_descriptors_.contains(fd) ||
        socket_pair_endpoints_.contains(fd)) {
        return true;
    }
    if (const auto host = host_sockets_.find(fd); host != host_sockets_.end()) {
        return host->second->writable();
    }
    if (const auto udp = virtual_udp_sockets_.find(fd);
        udp != virtual_udp_sockets_.end()) {
        return udp->second->writable();
    }
    if (const auto control = kernel_control_endpoints_.find(fd);
        control != kernel_control_endpoints_.end()) {
        return control->second->peer.has_value();
    }
    if (const auto descriptor = virtual_descriptors_.find(fd);
        descriptor != virtual_descriptors_.end() &&
        (descriptor->second == "route-socket" ||
            descriptor->second == darwin::bpf::descriptor_kind ||
            (descriptor->second == bsd::baseband_device::descriptor_kind &&
                baseband_open_description(fd) &&
                baseband_open_description(fd)->writable()) ||
            descriptor->second ==
                bsd::offline_serial_device::descriptor_kind)) {
        return true;
    }
    return false;
}

bool CompatibilityKernel::descriptor_requires_host_poll(std::uint32_t fd) const
{
    std::unordered_set<std::uint32_t> visited;
    return descriptor_requires_host_poll(fd, visited);
}

bool CompatibilityKernel::descriptor_requires_host_poll(std::uint32_t fd,
    std::unordered_set<std::uint32_t>& visited) const
{
    // A descriptor cycle is invalid Guest state, but treating it as host
    // sensitive preserves forward progress without recursively polling it.
    if (!visited.insert(fd).second)
        return true;
    if (const auto duplicate = duplicated_descriptors_.find(fd);
        duplicate != duplicated_descriptors_.end()) {
        return descriptor_requires_host_poll(duplicate->second, visited);
    }
    if (host_sockets_.contains(fd) || virtual_udp_sockets_.contains(fd) ||
        bpf_descriptors_.contains(fd) || wifi_driver_event_streams_.contains(fd)) {
        return true;
    }
    if (const auto kind = virtual_descriptors_.find(fd);
        kind != virtual_descriptors_.end() &&
        (kind->second == bsd::baseband_device::descriptor_kind ||
            kind->second == bsd::offline_serial_device::descriptor_kind)) {
        return true;
    }
    const auto queue = kqueues_.find(fd);
    if (queue == kqueues_.end())
        return false;
    for (const auto& registration : queue->second) {
        if (!registration.enabled ||
            (registration.filter != darwin::kqueue::filter_read &&
                registration.filter != darwin::kqueue::filter_write)) {
            continue;
        }
        if (descriptor_requires_host_poll(static_cast<std::uint32_t>(registration.ident), visited))
            return true;
    }
    return false;
}

bool CompatibilityKernel::descriptor_valid(std::uint32_t fd) const
{
    return fd <= 2 || file_descriptors_.contains(fd) ||
           virtual_descriptors_.contains(fd) ||
           duplicated_descriptors_.contains(fd) ||
           descriptor_flags_.contains(fd) || bpf_descriptors_.contains(fd) ||
           host_sockets_.contains(fd) || virtual_udp_sockets_.contains(fd) ||
           kernel_control_endpoints_.contains(fd) ||
           socket_pair_endpoints_.contains(fd);
}

std::uint16_t CompatibilityKernel::descriptor_poll_revents(
    std::int32_t fd, std::uint16_t events) const
{
    // A negative pollfd is an explicitly ignored entry. It does not produce
    // POLLNVAL, matching Darwin's poll(2) ABI.
    if (fd < 0)
        return 0;
    const auto descriptor = static_cast<std::uint32_t>(fd);
    if (!descriptor_valid(descriptor))
        return darwin::poll::invalid;

    std::uint16_t revents = 0;
    constexpr auto readable_events = static_cast<std::uint16_t>(
        darwin::poll::in | darwin::poll::read_normal | darwin::poll::read_band);
    constexpr auto writable_events = static_cast<std::uint16_t>(
        darwin::poll::out | darwin::poll::write_normal |
        darwin::poll::write_band);
    if ((events & readable_events) != 0 && descriptor_readable(descriptor))
        revents |= events & readable_events;
    if ((events & writable_events) != 0 && descriptor_writable(descriptor))
        revents |= events & writable_events;
    if (const auto kind = virtual_descriptors_.find(descriptor);
        kind != virtual_descriptors_.end() &&
        kind->second == bsd::baseband_device::descriptor_kind) {
        if (const auto endpoint = baseband_open_description(descriptor)) {
            if (endpoint->receive_eof())
                revents |= darwin::poll::hangup;
            if (endpoint->transmit_sink_failed())
                revents |= darwin::poll::error;
        }
    }
    return revents;
}

std::optional<std::uint32_t> CompatibilityKernel::ready_mach_port_name(
    std::uint32_t name) const
{
    using xnu::ipc::Right;

    std::lock_guard mach_lock { shared_state_->mach_mutex };
    const auto entry =
        shared_state_->mach_namespaces.lookup(process_.pid, name);
    if (!entry)
        return std::nullopt;

    const auto queue_has_message = [&](std::uint32_t object) {
        const auto queue = shared_state_->mach_queues.find(object);
        return queue != shared_state_->mach_queues.end() &&
               !queue->second.empty();
    };
    if ((entry->type & xnu::ipc::type_mask(Right::PortSet)) != 0U) {
        const auto set = shared_state_->mach_port_sets.find(entry->object);
        if (set == shared_state_->mach_port_sets.end())
            return std::nullopt;
        for (const auto member_object : set->second) {
            if (!queue_has_message(member_object))
                continue;
            if (const auto member_name =
                    shared_state_->mach_namespaces.name_for(
                        process_.pid, member_object)) {
                return member_name;
            }
        }
        return std::nullopt;
    }
    if ((entry->type & xnu::ipc::type_mask(Right::Receive)) != 0U &&
        queue_has_message(entry->object)) {
        return name;
    }
    return std::nullopt;
}

std::optional<std::uint32_t> CompatibilityKernel::ready_mach_kevent_name(
    const KeventRegistration& registration) const
{
    const auto generation_before =
        shared_state_->mach_queue_generation_snapshot();
    if (registration.empty_mach_queue_generation == generation_before)
        return std::nullopt;

    if (const auto ready = ready_mach_port_name(static_cast<std::uint32_t>(registration.ident))) {
        registration.empty_mach_queue_generation = 0;
        return ready;
    }

    // Do not publish a negative result if a producer changed the queue while
    // the namespace/port-set lookup was in progress. A later enqueue after the
    // second snapshot also advances the generation and invalidates this value.
    if (shared_state_->mach_queue_generation_snapshot() == generation_before) {
        registration.empty_mach_queue_generation = generation_before;
    }
    return std::nullopt;
}

std::optional<std::uint32_t> CompatibilityKernel::socket_pending_byte_count(
    std::uint32_t fd, std::uint32_t& darwin_error) const
{
    darwin_error = 0;
    if (const auto event_stream = wifi_driver_event_streams_.find(fd);
        event_stream != wifi_driver_event_streams_.end() &&
        event_stream->second) {
        return event_stream->second->pending_byte_count();
    }
    if (const auto host = host_sockets_.find(fd); host != host_sockets_.end()) {
        const auto pending = host->second->pending_bytes();
        if (pending.status == HostSocketStatus::Error) {
            darwin_error = pending.darwin_error;
            return std::nullopt;
        }
        return static_cast<std::uint32_t>(std::min<std::size_t>(
            pending.transferred, std::numeric_limits<std::uint32_t>::max()));
    }
    if (const auto udp = virtual_udp_sockets_.find(fd);
        udp != virtual_udp_sockets_.end()) {
        return static_cast<std::uint32_t>(
            std::min<std::size_t>(udp->second->pending_bytes(),
                std::numeric_limits<std::uint32_t>::max()));
    }
    if (const auto descriptor = virtual_descriptors_.find(fd);
        descriptor != virtual_descriptors_.end() &&
        descriptor->second == bsd::baseband_device::descriptor_kind) {
        const auto endpoint = baseband_open_description(fd);
        return static_cast<std::uint32_t>(std::min<std::size_t>(
            endpoint ? endpoint->pending_receive_bytes() : 0U,
            std::numeric_limits<std::uint32_t>::max()));
    }
    if (const auto descriptor = virtual_descriptors_.find(fd);
        descriptor != virtual_descriptors_.end() &&
        descriptor->second == bsd::offline_serial_device::descriptor_kind) {
        return static_cast<std::uint32_t>(
            std::min<std::size_t>(offline_serial_state_.pending_bytes(),
                std::numeric_limits<std::uint32_t>::max()));
    }
    if (const auto endpoint = socket_pair_endpoints_.find(fd);
        endpoint != socket_pair_endpoints_.end()) {
        std::lock_guard socket_lock { shared_state_->socket_mutex };
        return static_cast<std::uint32_t>(std::min<std::size_t>(
            shared_state_
                ->socket_pair_buffers[endpoint->second.pair]
                                     [endpoint->second.side]
                .size(),
            std::numeric_limits<std::uint32_t>::max()));
    }
    if (kernel_control_endpoints_.contains(fd)) {
        return 0;
    }
    if (const auto descriptor = virtual_descriptors_.find(fd);
        descriptor != virtual_descriptors_.end() &&
        (descriptor->second.starts_with("unix-") ||
            descriptor->second.starts_with("inet") ||
            descriptor->second == "socketpair")) {
        return 0;
    }
    darwin_error = 25; // ENOTTY
    return std::nullopt;
}

std::shared_ptr<bsd::baseband_device::OpenDescription>
CompatibilityKernel::baseband_open_description(std::uint32_t fd) const
{
    for (unsigned depth = 0; depth < 256U; ++depth) {
        if (const auto description = baseband_open_descriptions_.find(fd);
            description != baseband_open_descriptions_.end()) {
            return description->second;
        }
        const auto duplicate = duplicated_descriptors_.find(fd);
        if (duplicate == duplicated_descriptors_.end())
            break;
        fd = duplicate->second;
    }
    return { };
}

std::optional<std::uint32_t> CompatibilityKernel::collect_ready_kevents(
    std::size_t processor, std::uint32_t queue_fd, std::uint32_t event_address,
    std::uint32_t event_count, bool extended, bool waking_blocked_receiver)
{
    const KeventWireFormat wire { extended };
    const auto queue = kqueues_.find(queue_fd);
    if (queue == kqueues_.end())
        return std::nullopt;
    std::uint32_t written = 0;
    for (auto registration = queue->second.begin();
        registration != queue->second.end();) {
        std::uint32_t filter_flags = 0;
        std::uint32_t available = 1;
        auto process_exec_generation_at_evaluation =
            registration->process_exec_generation;
        auto process_exit_generation_at_evaluation =
            registration->process_exit_generation;
        auto result_flags = static_cast<std::uint16_t>(
            registration->flags &
            (darwin::kqueue::event_clear | darwin::kqueue::event_dispatch |
                darwin::kqueue::event_one_shot));
        std::optional<std::uint32_t> ready_mach_name;
        if (registration->filter == darwin::kqueue::filter_process) {
            std::lock_guard lock { shared_state_->mach_mutex };
            const auto process =
                shared_state_->process_kevent_states.find(static_cast<std::uint32_t>(registration->ident));
            if (process != shared_state_->process_kevent_states.end()) {
                process_exec_generation_at_evaluation =
                    process->second.exec_generation;
                process_exit_generation_at_evaluation =
                    process->second.exit_generation;
                if ((registration->filter_flags &
                        darwin::kqueue::process_note_exec) != 0U &&
                    process->second.exec_generation !=
                        registration->process_exec_generation) {
                    filter_flags |= darwin::kqueue::process_note_exec;
                }
                if ((registration->filter_flags &
                        darwin::kqueue::process_note_exit) != 0U &&
                    process->second.exit_generation !=
                        registration->process_exit_generation) {
                    filter_flags |= darwin::kqueue::process_note_exit;
                    available = process->second.wait_status;
                    result_flags |= darwin::kqueue::event_end_of_file |
                                    darwin::kqueue::event_one_shot;
                }
            }
            result_flags |= darwin::kqueue::event_clear;
        } else if (registration->filter == darwin::kqueue::filter_vnode) {
            if (registration->vnode_watch) {
                filter_flags = registration->vnode_watch->pending(
                                   *shared_state_->guest_file_generation_registry) &
                               registration->filter_flags;
            }
            available = 0U;
        } else if (registration->filter == darwin::kqueue::filter_mach_port) {
            ready_mach_name = ready_mach_kevent_name(*registration);
            if (ready_mach_name)
                available = *ready_mach_name;
        } else if (registration->filter == darwin::kqueue::filter_user) {
            filter_flags = registration->filter_flags;
            available = static_cast<std::uint32_t>(registration->data);
        }
        const auto ready =
            !registration->enabled ? false
            : registration->filter == darwin::kqueue::filter_read
                ? descriptor_readable(static_cast<std::uint32_t>(registration->ident))
            : registration->filter == darwin::kqueue::filter_write
                ? descriptor_writable(static_cast<std::uint32_t>(registration->ident))
            : registration->filter == darwin::kqueue::filter_process
                ? filter_flags != 0U
            : registration->filter == darwin::kqueue::filter_vnode
                ? filter_flags != 0U
            : registration->filter == darwin::kqueue::filter_mach_port
                ? ready_mach_name.has_value()
            : registration->filter == darwin::kqueue::filter_timer
                ? registration->timer &&
                    registration->timer->expirations(shared_state_->clock.now()) != 0
            : registration->filter == darwin::kqueue::filter_user
                ? registration->user_triggered
                : false;
        const auto clears_after_delivery =
            (registration->flags & darwin::kqueue::event_clear) != 0U;
        if (!ready) {
            registration->clear_delivered = false;
            ++registration;
            continue;
        }
        if (const auto endpoint =
                socket_pair_endpoints_.find(static_cast<std::uint32_t>(registration->ident));
            endpoint != socket_pair_endpoints_.end() &&
            (registration->filter == darwin::kqueue::filter_read ||
                registration->filter == darwin::kqueue::filter_write)) {
            std::lock_guard socket_lock { shared_state_->socket_mutex };
            available = static_cast<std::uint32_t>(shared_state_
                    ->socket_pair_buffers[endpoint->second.pair]
                                         [endpoint->second.side]
                    .size());
        } else if (registration->filter == darwin::kqueue::filter_read &&
                   listening_sockets_.contains(static_cast<std::uint32_t>(registration->ident))) {
            std::lock_guard socket_lock { shared_state_->socket_mutex };
            if (const auto listener =
                    unix_listener_states_.find(static_cast<std::uint32_t>(registration->ident));
                listener != unix_listener_states_.end()) {
                available = static_cast<std::uint32_t>(
                    listener->second->pending_endpoints.size());
            }
        }
        // Process readiness is already edge-consumed by its observed
        // generations. Comparing only `data` can collapse distinct process
        // events (for example NOTE_EXEC data=1 followed by signal-1 exit).
        // EVFILT_MACHPORT's readiness probe does not consume the message. XNU
        // keeps its wait-queue-backed knote active while any member queue is
        // nonempty, even with EV_CLEAR; the client drains messages separately
        // through mach_msg. Re-evaluate it on every kevent call so a busy port
        // set cannot strand messages behind the first reported member.
        if (clears_after_delivery &&
            registration->filter != darwin::kqueue::filter_process &&
            registration->filter != darwin::kqueue::filter_timer &&
            registration->filter != darwin::kqueue::filter_vnode &&
            registration->filter != darwin::kqueue::filter_mach_port &&
            registration->clear_delivered &&
            registration->clear_available == available) {
            ++registration;
            continue;
        }
        if (written == event_count) {
            ++registration;
            continue;
        }
        if (clears_after_delivery)
            result_flags |= darwin::kqueue::event_clear;
        const auto event = event_address + written * wire.size();
        auto extension = registration->extension;
        auto data = registration->filter == darwin::kqueue::filter_user
            ? registration->data : static_cast<std::int64_t>(available);
        if (registration->timer) {
            data = registration->timer->expirations(shared_state_->clock.now());
            extension[0] = 0;
        }
        if (extended && registration->filter == darwin::kqueue::filter_mach_port &&
            (registration->filter_flags & darwin::mach_message::option_receive) != 0U) {
            const auto received = receive_kevent_mach_message(
                *registration, processor, waking_blocked_receiver);
            if (!received) {
                ++registration;
                continue;
            }
            data = 0;
            filter_flags = received->status;
            extension[1] = received->message_size;
        }
        if (!wire.write(memory_, event, KeventValue { registration->ident,
                registration->filter, result_flags, filter_flags, data,
                registration->user_data, extension }))
            return std::nullopt;
        ++written;
        if (registration->timer) {
            registration->timer->consume(shared_state_->clock.now());
            note_timer_deadline_transition();
        }
        if (clears_after_delivery) {
            registration->clear_delivered = true;
            registration->clear_available = available;
            if (registration->filter == darwin::kqueue::filter_user)
                registration->user_triggered = false;
            if (registration->vnode_watch)
                registration->vnode_watch->acknowledge(filter_flags);
        }
        if ((registration->flags & darwin::kqueue::event_dispatch) != 0U) {
            registration->enabled = false;
        }
        if ((filter_flags & darwin::kqueue::process_note_exit) != 0U) {
            registration = queue->second.erase(registration);
        } else if ((registration->flags & darwin::kqueue::event_one_shot) !=
                   0U) {
            registration = queue->second.erase(registration);
        } else {
            if (registration->filter == darwin::kqueue::filter_process) {
                // A later process edge can arrive after readiness was
                // evaluated but before the event has been copied out. Only
                // acknowledge generations represented by this delivery, and
                // use the values captured by that evaluation. Re-reading and
                // copying every current generation here can consume an edge
                // that was never returned to the guest.
                if ((filter_flags & darwin::kqueue::process_note_exec) != 0U) {
                    registration->process_exec_generation =
                        process_exec_generation_at_evaluation;
                }
                if ((filter_flags & darwin::kqueue::process_note_exit) != 0U) {
                    registration->process_exit_generation =
                        process_exit_generation_at_evaluation;
                }
            }
            ++registration;
        }
    }
    return written;
}

void CompatibilityKernel::detach_kevents_for_descriptor(std::uint32_t fd)
{
    for (auto& [queue_fd, registrations] : kqueues_) {
        (void)queue_fd;
        std::erase_if(registrations, [fd](const auto& registration) {
            return registration.ident == fd &&
                   (registration.filter == darwin::kqueue::filter_read ||
                       registration.filter == darwin::kqueue::filter_write ||
                       registration.filter == darwin::kqueue::filter_vnode);
        });
    }
}

} // namespace shade
