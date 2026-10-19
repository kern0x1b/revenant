// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Dispatch guest socket creation, connection and network I/O
// syscalls.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/kern/uipc_syscalls.c

#include "kernel/kernel.hpp"

#include "kernel/darwin_abi.hpp"
#include "kernel/darwin_kernel_control_abi.hpp"
#include "kernel/darwin_kqueue_abi.hpp"
#include "network/darwin_network_abi.hpp"
#include "kernel/darwin_resource_abi.hpp"
#include "network/darwin_route_socket.hpp"
#include "kernel/kernel_network.hpp"

#include <algorithm>
#include <array>
#include <bit>
#include <cstddef>
#include <cstdint>
#include <fstream>
#include <iterator>
#include <limits>
#include <mutex>
#include <optional>
#include <span>
#include <sstream>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "support.hpp"

namespace shade {

void CompatibilityKernel::dispatch_bsd_socket(Cpu& cpu, std::uint32_t number)
{
    auto& registers = cpu.registers();
    switch (number) {
    case 27: { // recvmsg
        auto fd = registers[0];
        if (const auto duplicate = duplicated_descriptors_.find(fd);
            duplicate != duplicated_descriptors_.end()) {
            fd = duplicate->second;
        }
        if (receive_socket_message(cpu, fd, registers[1]))
            return;
        if ((registers[2] & darwin::socket::message_dont_wait) != 0 ||
            (file_status_flags_[fd] & darwin::open_flag::non_block) != 0) {
            bsd_error(cpu, bsd_support::would_block);
            return;
        }
        pending_recvmsgs_[cpu.processor_id()] =
            PendingRecvmsg { fd, registers[1], cpu.processor_id() };
        process_.waiting_for_events = true;
        cpu.halt(Umbra::HaltReason::UserDefined5);
        return;
    }
    case 28: { // sendmsg
        auto fd = registers[0];
        if (const auto duplicate = duplicated_descriptors_.find(fd);
            duplicate != duplicated_descriptors_.end()) {
            fd = duplicate->second;
        }
        if (send_socket_message(cpu, fd, registers[1], registers[2]))
            return;
        const auto endpoint = socket_pair_endpoints_.find(fd);
        if (endpoint == socket_pair_endpoints_.end()) {
            bsd_error(cpu, virtual_descriptors_.contains(fd)
                               ? 57U
                               : bsd_support::bad_file_descriptor); // ENOTCONN
            return;
        }
        if (!endpoint->second.local_write_open() ||
            !endpoint->second.peer_read_open()) {
            bsd_error(cpu, darwin::error::broken_pipe);
            return;
        }
        const auto message = registers[1];
        if (!memory_.accessible(message, darwin::socket::arm32_message::size,
                MemoryPermission::Read)) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        const auto iov_address = memory_.read32(message + 8);
        const auto iov_count = memory_.read32(message + 12);
        if (!iov_address || !iov_count) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        if (*iov_count > darwin::io::maximum_vector_count) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        const auto iovec_bytes = static_cast<std::size_t>(*iov_count) *
                                 darwin::socket::arm32_iovec::size;
        if (*iov_count != 0 &&
            (*iov_address == 0 || !memory_.accessible(*iov_address, iovec_bytes,
                                      MemoryPermission::Read))) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        std::uint32_t total = 0;
        std::vector<std::byte> outgoing;
        for (std::uint32_t index = 0; index < *iov_count; ++index) {
            const auto base = memory_.read32(*iov_address + index * 8U);
            const auto size = memory_.read32(*iov_address + index * 8U + 4U);
            if (!base || !size || *size > bsd_support::maximum_io ||
                total > bsd_support::maximum_io - *size) {
                bsd_error(cpu, !base || !size ? bsd_support::bad_address
                                              : bsd_support::invalid_argument);
                return;
            }
            const auto bytes = memory_.read_bytes(*base, *size);
            if (!bytes) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            outgoing.insert(outgoing.end(), bytes->begin(), bytes->end());
            total += *size;
        }
        const auto control_address = memory_.read32(message + 16);
        const auto control_size_value = memory_.read32(message + 20);
        if (!control_address || !control_size_value) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        const auto control_size = *control_size_value;
        std::vector<KernelSharedState::DescriptorTransfer> transfers;
        if (control_size != 0) {
            if (control_size > bsd_support::maximum_io) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            if (*control_address == 0 ||
                !memory_.accessible(
                    *control_address, control_size, MemoryPermission::Read)) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            for (std::uint32_t offset = 0; offset < control_size;) {
                const auto cmsg_length =
                    memory_.read32(*control_address + offset);
                const auto cmsg_level =
                    memory_.read32(*control_address + offset + 4U);
                const auto cmsg_type =
                    memory_.read32(*control_address + offset + 8U);
                if (!cmsg_length || !cmsg_level || !cmsg_type) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                if (*cmsg_length < 12U ||
                    *cmsg_length > control_size - offset) {
                    bsd_error(cpu, bsd_support::invalid_argument);
                    return;
                }
                if (*cmsg_level == 0xffffU && *cmsg_type == 1U) {
                    const auto descriptor_bytes = *cmsg_length - 12U;
                    if ((descriptor_bytes % 4U) != 0) {
                        bsd_error(cpu, bsd_support::invalid_argument);
                        return;
                    }
                    for (std::uint32_t descriptor_offset = 0;
                        descriptor_offset < descriptor_bytes;
                        descriptor_offset += 4U) {
                        const auto passed_fd =
                            memory_.read32(*control_address + offset + 12U +
                                           descriptor_offset);
                        if (!passed_fd) {
                            bsd_error(cpu, bsd_support::bad_address);
                            return;
                        }
                        if (reject_guarded_descriptor(cpu, *passed_fd, DarwinFileGuard::socket_ipc))
                            return;
                        const auto transfer = export_descriptor(*passed_fd);
                        if (!transfer) {
                            bsd_error(cpu, bsd_support::bad_file_descriptor);
                            return;
                        }
                        transfers.push_back(*transfer);
                    }
                }
                const auto aligned_length = (*cmsg_length + 3U) & ~3U;
                if (aligned_length == 0 ||
                    aligned_length > control_size - offset)
                    break;
                offset += aligned_length;
            }
        }
        const auto transfer_count = transfers.size();
        {
            std::lock_guard socket_lock { shared_state_->socket_mutex };
            const auto destination_side = 1U - endpoint->second.side;
            auto& destination =
                shared_state_->socket_pair_buffers[endpoint->second.pair]
                                                  [destination_side];
            const auto lifetime = endpoint->second.description
                                      ? endpoint->second.description->lifetime
                                      : nullptr;
            if (!lifetime) {
                bsd_error(cpu, bsd_support::bad_file_descriptor);
                return;
            }
            const auto ancillary_offset =
                lifetime->read_offsets[destination_side] + destination.size();
            destination.insert(
                destination.end(), outgoing.begin(), outgoing.end());
            if (!transfers.empty()) {
                shared_state_
                    ->socket_pair_ancillary[endpoint->second.pair]
                                           [destination_side]
                    .push_back(KernelSharedState::SocketAncillaryRecord {
                        ancillary_offset, std::move(transfers) });
            }
        }
        output_.write("[network] sendmsg pid=" +
                      std::to_string(process_.pid) + " fd=" +
                      std::to_string(fd) +
                      " bytes=" + std::to_string(total) +
                      " control=" + std::to_string(control_size) +
                      " rights=" + std::to_string(transfer_count) + "\n");
        shared_state_->note_io_event_transition();
        bsd_success(cpu, total);
        return;
    }
    case darwin::syscall::receive_from: {
        auto fd = registers[0];
        if (const auto duplicate = duplicated_descriptors_.find(fd);
            duplicate != duplicated_descriptors_.end()) {
            fd = duplicate->second;
        }
        if (!virtual_descriptors_.contains(fd)) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
            return;
        }
        if (!host_sockets_.contains(fd) && !virtual_udp_sockets_.contains(fd) &&
            !socket_pair_endpoints_.contains(fd) &&
            !system_event_next_identifiers_.contains(fd)) {
            bsd_error(cpu, bsd_support::not_connected);
            return;
        }
        if (registers[2] > bsd_support::maximum_io) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        if (receive_socket_bytes(cpu, fd, registers[1], registers[2],
                registers[4], registers[5])) {
            return;
        }
        if ((registers[3] & darwin::socket::message_dont_wait) != 0 ||
            (file_status_flags_[fd] & darwin::open_flag::non_block) != 0) {
            bsd_error(cpu, bsd_support::would_block);
            return;
        }
        pending_socket_reads_[cpu.processor_id()] =
            PendingSocketRead { fd, registers[1], registers[2], registers[4],
                registers[5], cpu.processor_id(), std::nullopt };
        process_.waiting_for_events = true;
        bsd_success(cpu, 0);
        cpu.halt(Umbra::HaltReason::UserDefined5);
        return;
    }
    case darwin::syscall::accept: {
        const auto listener_fd = registers[0];
        if (!listening_sockets_.contains(listener_fd)) {
            bsd_error(cpu, virtual_descriptors_.contains(listener_fd)
                               ? bsd_support::invalid_argument
                               : bsd_support::bad_file_descriptor);
            return;
        }
        if (const auto host = host_sockets_.find(listener_fd);
            host != host_sockets_.end()) {
            const auto accepted = host->second->accept();
            if (accepted.status == HostSocketStatus::WouldBlock) {
                if ((file_status_flags_[listener_fd] &
                        darwin::open_flag::non_block) != 0) {
                    bsd_error(cpu, bsd_support::would_block);
                    return;
                }
                pending_host_accepts_[cpu.processor_id()] =
                    PendingHostAccept { listener_fd, registers[1], registers[2],
                        cpu.processor_id() };
                process_.waiting_for_events = true;
                bsd_success(cpu, 0);
                cpu.halt(Umbra::HaltReason::UserDefined5);
                return;
            }
            if (accepted.status == HostSocketStatus::Error) {
                bsd_error(cpu, accepted.darwin_error);
                return;
            }
            const auto accepted_fd =
                install_host_socket(accepted.accepted_socket);
            if (!accepted_fd) {
                bsd_error(cpu, 24); // EMFILE
                return;
            }
            if (!copy_socket_address(
                    registers[1], registers[2], accepted.address)) {
                host_sockets_.erase(*accepted_fd);
                virtual_descriptors_.erase(*accepted_fd);
                file_status_flags_.erase(*accepted_fd);
                descriptor_flags_.erase(*accepted_fd);
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            bsd_success(cpu, *accepted_fd);
            return;
        }
        if (complete_unix_accept(
                cpu, listener_fd, registers[1], registers[2])) {
            return;
        }
        if ((file_status_flags_[listener_fd] & darwin::open_flag::non_block) !=
            0) {
            bsd_error(cpu, bsd_support::would_block);
            return;
        }
        pending_unix_accepts_[cpu.processor_id()] =
            PendingUnixAccept { listener_fd, registers[1], registers[2],
                cpu.processor_id() };
        process_.waiting_for_events = true;
        bsd_success(cpu, 0);
        cpu.halt(Umbra::HaltReason::UserDefined5);
        return;
    }
    case 31: // getpeername
    case 32: { // getsockname
        const auto fd = registers[0];
        const auto socket = virtual_descriptors_.find(fd);
        if (socket == virtual_descriptors_.end()) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
            return;
        }
        const bool peer = number == 31;
        if (name_kernel_control_socket(cpu, peer))
            return;
        if (const auto host = host_sockets_.find(fd);
            host != host_sockets_.end()) {
            const auto address = peer ? host->second->peer_address()
                                      : host->second->local_address();
            if (address.status == HostSocketStatus::Error) {
                bsd_error(cpu, address.darwin_error);
            } else if (!copy_socket_address(
                           registers[1], registers[2], address.address)) {
                bsd_error(cpu, bsd_support::bad_address);
            } else {
                bsd_success(cpu, 0);
            }
            return;
        }
        if (const auto udp = virtual_udp_sockets_.find(fd);
            udp != virtual_udp_sockets_.end()) {
            if (peer) {
                const auto address = udp->second->peer_address();
                if (!address) {
                    bsd_error(cpu, bsd_support::not_connected);
                } else if (!copy_socket_address(
                               registers[1], registers[2], *address)) {
                    bsd_error(cpu, bsd_support::bad_address);
                } else {
                    bsd_success(cpu, 0);
                }
            } else if (!copy_socket_address(registers[1], registers[2],
                           udp->second->local_address())) {
                bsd_error(cpu, bsd_support::bad_address);
            } else {
                bsd_success(cpu, 0);
            }
            return;
        }
        if (kernel_network::is_isolated_stream_descriptor(socket->second)) {
            if (peer) {
                bsd_error(cpu, bsd_support::not_connected);
                return;
            }
            const auto ipv6 = socket->second ==
                              kernel_network::isolated_ipv6_stream_descriptor;
            const auto address_size =
                ipv6 ? darwin::network::arm32_sockaddr_in6_size
                     : darwin::network::arm32_sockaddr_in_size;
            std::vector<std::byte> address(address_size, std::byte { 0 });
            address[darwin::network::sockaddr_length_offset] =
                static_cast<std::byte>(address_size);
            address[darwin::network::sockaddr_family_offset] =
                static_cast<std::byte>(
                    ipv6 ? darwin::network::address_family_inet6
                         : darwin::network::address_family_inet);
            if (const auto bound = bound_socket_names_.find(fd);
                bound != bound_socket_names_.end()) {
                address.assign(
                    reinterpret_cast<const std::byte*>(bound->second.data()),
                    reinterpret_cast<const std::byte*>(
                        bound->second.data() + bound->second.size()));
            }
            if (!copy_socket_address(registers[1], registers[2], address)) {
                bsd_error(cpu, bsd_support::bad_address);
            } else {
                bsd_success(cpu, 0);
            }
            return;
        }
        if (peer && !socket_pair_endpoints_.contains(fd)) {
            bsd_error(cpu, bsd_support::not_connected);
            return;
        }
        const auto capacity = memory_.read32(registers[2]);
        if (!capacity) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }

        std::uint8_t family = 1; // AF_UNIX
        if (socket->second == "inet-dgram")
            family = 2;
        else if (socket->second == "inet6-dgram")
            family = 30;
        else if (socket->second == "route-socket")
            family = 17;
        else if (socket->second == "system-event-socket")
            family = 32;
        std::string name;
        if (!peer) {
            if (const auto bound = bound_socket_names_.find(fd);
                bound != bound_socket_names_.end()) {
                name = bound->second;
            }
        }
        const auto address_size =
            static_cast<std::uint32_t>(std::min<std::size_t>(
                255, 2U + (name.empty() ? 0U : name.size() + 1U)));
        std::vector<std::byte> address(address_size, std::byte { 0 });
        address[0] = static_cast<std::byte>(address_size);
        address[1] = static_cast<std::byte>(family);
        for (std::size_t index = 0;
            index < name.size() && index + 2 < address.size(); ++index) {
            address[index + 2] = static_cast<std::byte>(name[index]);
        }
        const auto copied = std::min(*capacity, address_size);
        if ((copied != 0 &&
                !memory_.copy_in(registers[1],
                    std::span<const std::byte> { address.data(), copied })) ||
            !memory_.write32(registers[2], copied)) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        bsd_success(cpu, 0);
        return;
    }
    case darwin::syscall::socket: {
        if (registers[0] == darwin::socket::local &&
            (registers[1] == darwin::socket::stream ||
                registers[1] == darwin::socket::datagram ||
                registers[1] == darwin::socket::sequenced_packet)) {
            const auto fd = allocate_file_descriptor();
            if (!fd) {
                bsd_error(cpu, 24);
                return;
            }
            virtual_descriptors_.emplace(*fd,
                registers[1] == darwin::socket::stream     ? "unix-stream"
                : registers[1] == darwin::socket::datagram ? "unix-dgram"
                                                           : "unix-seqpacket");
            file_status_flags_[*fd] = darwin::open_flag::read_write;
            descriptor_flags_[*fd] = 0;
            bsd_success(cpu, *fd);
            return;
        }
        if ((registers[0] == darwin::network::address_family_inet ||
                registers[0] == darwin::network::address_family_inet6) &&
            (registers[1] == darwin::socket::stream ||
                registers[1] == darwin::socket::datagram)) {
            if (host_network_policy_ == HostNetworkPolicy::Isolated &&
                registers[1] == darwin::socket::stream) {
                const auto fd = allocate_file_descriptor();
                if (!fd) {
                    bsd_error(cpu, 24); // EMFILE
                    return;
                }
                virtual_descriptors_.emplace(
                    *fd, registers[0] == darwin::network::address_family_inet
                             ? kernel_network::isolated_ipv4_stream_descriptor
                             : kernel_network::isolated_ipv6_stream_descriptor);
                file_status_flags_[*fd] = darwin::open_flag::read_write;
                descriptor_flags_[*fd] = 0;
                bsd_success(cpu, *fd);
                return;
            }
            if (host_network_policy_ != HostNetworkPolicy::Isolated) {
                const auto created = HostSocket::create(host_network_policy_,
                    registers[0], registers[1], registers[2]);
                if (!created.socket) {
                    output_.write("[network] socket-create failed pid=" +
                                  std::to_string(process_.pid) +
                                  " family=" + std::to_string(registers[0]) +
                                  " type=" + std::to_string(registers[1]) +
                                  " protocol=" + std::to_string(registers[2]) +
                                  " error=" +
                                  std::to_string(created.darwin_error) + "\n");
                    bsd_error(cpu, created.darwin_error);
                    return;
                }
                const auto fd = install_host_socket(created.socket);
                if (!fd) {
                    bsd_error(cpu, 24); // EMFILE
                    return;
                }
                bsd_success(cpu, *fd);
                return;
            }
            const auto fd = allocate_file_descriptor();
            if (!fd) {
                bsd_error(cpu, 24);
                return;
            }
            virtual_descriptors_.emplace(
                *fd, registers[0] == darwin::network::address_family_inet
                         ? "inet-dgram"
                         : "inet6-dgram");
            auto udp = shared_state_->virtual_udp_network->create(registers[0]);
            if (!udp) {
                virtual_descriptors_.erase(*fd);
                bsd_error(cpu, 47); // EAFNOSUPPORT
                return;
            }
            virtual_udp_sockets_[*fd] = std::move(udp);
            file_status_flags_[*fd] = darwin::open_flag::read_write;
            descriptor_flags_[*fd] = 0;
            bsd_success(cpu, *fd);
            return;
        }
        if (registers[0] == darwin::route::protocol_family &&
            registers[1] == darwin::socket::raw &&
            (registers[2] == darwin::network::address_family_unspecified ||
                registers[2] == darwin::network::address_family_inet ||
                registers[2] == darwin::network::address_family_inet6)) {
            const auto fd = allocate_file_descriptor();
            if (!fd) {
                bsd_error(cpu, 24); // EMFILE
                return;
            }
            virtual_descriptors_.emplace(*fd, "route-socket");
            file_status_flags_[*fd] = darwin::open_flag::read_write;
            descriptor_flags_[*fd] = 0;
            {
                std::lock_guard route_lock {
                    shared_state_->route_socket_mutex
                };
                route_socket_states_[*fd] =
                    std::make_shared<KernelSharedState::RouteSocketState>(
                        KernelSharedState::RouteSocketState {
                            shared_state_->next_route_socket_identifier++,
                            shared_state_->next_route_message_identifier,
                            registers[2] });
            }
            bsd_success(cpu, *fd);
            return;
        }
        if (registers[0] == darwin::kernel_control::protocol_family_system &&
            registers[1] == darwin::socket::raw &&
            registers[2] == darwin::kernel_control::protocol_event) {
            // PF_SYSTEM, SOCK_RAW, SYSPROTO_EVENT. Host kernels do not expose
            // this Darwin family, so it is backed by the guest kernel event
            // queue.
            const auto fd = allocate_file_descriptor();
            if (!fd) {
                bsd_error(cpu, 24); // EMFILE
                return;
            }
            virtual_descriptors_.emplace(*fd, "system-event-socket");
            file_status_flags_[*fd] = darwin::open_flag::read_write;
            descriptor_flags_[*fd] = 0;
            {
                std::lock_guard socket_lock { shared_state_->socket_mutex };
                system_event_next_identifiers_[*fd] =
                    shared_state_->next_kernel_event_identifier;
            }
            bsd_success(cpu, *fd);
            return;
        }
        if (create_kernel_control_socket(cpu))
            return;
        trace_unknown(cpu, "BSD socket domain", registers[0]);
        bsd_error(cpu, 47); // EAFNOSUPPORT
        return;
    }
    case darwin::syscall::connect: {
        const auto fd = registers[0];
        const auto socket = virtual_descriptors_.find(fd);
        if (socket == virtual_descriptors_.end()) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
            return;
        }
        if (registers[2] < 2 ||
            registers[2] > bsd_support::maximum_socket_address_size) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        if (const auto host = host_sockets_.find(fd);
            host != host_sockets_.end()) {
            const auto address = memory_.read_bytes(registers[1], registers[2]);
            if (!address) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            const auto connected = host->second->connect(*address);
            if (connected.status == HostSocketStatus::Error) {
                bsd_error(cpu, connected.darwin_error);
            } else if (connected.status == HostSocketStatus::WouldBlock) {
                if ((file_status_flags_[fd] & darwin::open_flag::non_block) !=
                    0) {
                    bsd_error(cpu, connected.darwin_error);
                } else {
                    pending_host_connects_[cpu.processor_id()] =
                        PendingHostConnect { fd, cpu.processor_id() };
                    process_.waiting_for_events = true;
                    bsd_success(cpu, 0);
                    cpu.halt(Umbra::HaltReason::UserDefined5);
                }
            } else {
                bsd_success(cpu, 0);
            }
            return;
        }
        if (const auto udp = virtual_udp_sockets_.find(fd);
            udp != virtual_udp_sockets_.end()) {
            const auto address = memory_.read_bytes(registers[1], registers[2]);
            if (!address) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            const auto family = std::to_integer<std::uint8_t>(
                (*address)[darwin::network::sockaddr_family_offset]);
            if (family == darwin::network::address_family_unspecified) {
                const auto result = udp->second->disconnect();
                if (result == bsd::VirtualUdpStatus::Success)
                    bsd_success(cpu, 0);
                else
                    bsd_error(cpu, bsd_support::not_connected);
            } else {
                const auto result = udp->second->connect(*address);
                if (result == bsd::VirtualUdpStatus::Success) {
                    bsd_success(cpu, 0);
                } else {
                    bsd_error(
                        cpu, result == bsd::VirtualUdpStatus::AlreadyConnected
                                 ? bsd_support::already_connected
                                 : bsd_support::invalid_argument);
                }
            }
            return;
        }
        if (kernel_network::is_isolated_stream_descriptor(socket->second)) {
            // Isolation keeps the local endpoint model usable without
            // translating a guest destination onto the host loopback namespace.
            bsd_error(cpu, darwin::error::network_unreachable);
            return;
        }
        if (connect_kernel_control_socket(cpu))
            return;
        const auto family = memory_.read8(registers[1] + 1);
        if (!family) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        std::string name;
        if (*family == 1) {
            name = memory_.read_c_string(registers[1] + 2, registers[2] - 2)
                       .value_or("");
        }
        output_.write("[network] connect pid=" + std::to_string(process_.pid) +
                      " fd=" + std::to_string(fd) +
                      " family=" + std::to_string(*family) + " " + name + "\n");
        if (*family != 1 || !socket->second.starts_with("unix-")) {
            bsd_error(cpu, 47); // EAFNOSUPPORT
            return;
        }
        if (socket_pair_endpoints_.contains(fd)) {
            bsd_error(cpu, bsd_support::already_connected);
            return;
        }
        std::lock_guard socket_lock { shared_state_->socket_mutex };
        const auto registration = shared_state_->unix_listeners.find(name);
        const auto listener =
            registration == shared_state_->unix_listeners.end()
                ? std::shared_ptr<KernelSharedState::UnixListener> { }
                : registration->second.lock();
        if (!listener) {
            bsd_error(cpu, bsd_support::connection_refused);
            return;
        }
        const auto pair = shared_state_->next_socket_pair++;
        auto endpoints = make_socket_pair_endpoints(pair);
        endpoints.first.peer_credentials = listener->credentials;
        endpoints.second.peer_credentials.emplace(
            process_.effective_uid, process_.effective_gid);
        shared_state_->socket_pair_buffers.emplace(
            pair, std::array<std::deque<std::byte>, 2> { });
        socket_pair_endpoints_[fd] = std::move(endpoints.first);
        listener->pending_endpoints.push_back(std::move(endpoints.second));
        shared_state_->note_io_event_transition();
        output_.write("[network] connected pair=" + std::to_string(pair) +
                      " listener-pid=" + std::to_string(listener->owner_pid) +
                      "\n");
        bsd_success(cpu, 0);
        return;
    }
    case darwin::syscall::bind: {
        const auto socket = virtual_descriptors_.find(registers[0]);
        if (socket == virtual_descriptors_.end()) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
            return;
        }
        if (registers[2] < 2 ||
            registers[2] > bsd_support::maximum_socket_address_size) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        if (const auto host = host_sockets_.find(registers[0]);
            host != host_sockets_.end()) {
            const auto address = memory_.read_bytes(registers[1], registers[2]);
            if (!address) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            const auto bound = host->second->bind(*address);
            if (bound.status == HostSocketStatus::Error) {
                bsd_error(cpu, bound.darwin_error);
            } else {
                bsd_success(cpu, 0);
            }
            return;
        }
        if (const auto udp = virtual_udp_sockets_.find(registers[0]);
            udp != virtual_udp_sockets_.end()) {
            const auto address = memory_.read_bytes(registers[1], registers[2]);
            if (!address) {
                bsd_error(cpu, bsd_support::bad_address);
            } else if (udp->second->bind(*address) !=
                       bsd::VirtualUdpStatus::Success) {
                bsd_error(cpu, bsd_support::invalid_argument);
            } else {
                output_.write("[network] virtual UDP bind fd=" +
                              std::to_string(registers[0]) + "\n");
                bsd_success(cpu, 0);
            }
            return;
        }
        if (kernel_network::is_isolated_stream_descriptor(socket->second)) {
            const auto ipv6 = socket->second ==
                              kernel_network::isolated_ipv6_stream_descriptor;
            const auto expected_family =
                ipv6 ? darwin::network::address_family_inet6
                     : darwin::network::address_family_inet;
            const auto expected_size =
                ipv6 ? darwin::network::arm32_sockaddr_in6_size
                     : darwin::network::arm32_sockaddr_in_size;
            if (registers[2] < expected_size) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            const auto address =
                memory_.read_bytes(registers[1], expected_size);
            if (!address) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            if (std::to_integer<std::uint8_t>(
                    (*address)[darwin::network::sockaddr_family_offset]) !=
                expected_family) {
                bsd_error(cpu, 47); // EAFNOSUPPORT
                return;
            }
            if (bound_socket_names_.contains(registers[0])) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            auto canonical = *address;
            canonical[darwin::network::sockaddr_length_offset] =
                static_cast<std::byte>(expected_size);
            const std::string encoded { reinterpret_cast<const char*>(
                                            canonical.data()),
                canonical.size() };
            const auto duplicate = std::any_of(bound_socket_names_.begin(),
                bound_socket_names_.end(), [&](const auto& entry) {
                    const auto descriptor =
                        virtual_descriptors_.find(entry.first);
                    return descriptor != virtual_descriptors_.end() &&
                           kernel_network::is_isolated_stream_descriptor(
                               descriptor->second) &&
                           entry.second == encoded;
                });
            if (duplicate) {
                bsd_error(cpu, bsd_support::address_in_use);
                return;
            }
            bound_socket_names_[registers[0]] = encoded;
            const auto port =
                (static_cast<std::uint32_t>(std::to_integer<std::uint8_t>(
                     canonical[darwin::network::sockaddr_port_offset]))
                    << 8U) |
                std::to_integer<std::uint8_t>(
                    canonical[darwin::network::sockaddr_port_offset + 1U]);
            output_.write(
                "[network] isolated bind pid=" + std::to_string(process_.pid) +
                " fd=" + std::to_string(registers[0]) +
                " family=" + std::to_string(expected_family) +
                " port=" + std::to_string(port) + "\n");
            bsd_success(cpu, 0);
            return;
        }
        const auto family = memory_.read8(registers[1] + 1);
        if (!family) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        std::string name;
        if (*family == 1) {
            name = memory_.read_c_string(registers[1] + 2, registers[2] - 2)
                       .value_or("");
        } else {
            name = "family:" + std::to_string(*family);
        }
        if (*family == darwin::socket::local) {
            std::lock_guard socket_lock { shared_state_->socket_mutex };
            if (name.empty()) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            if (bound_socket_names_.contains(registers[0])) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            if (!shared_state_->unix_socket_nodes.insert(name).second) {
                bsd_error(cpu, bsd_support::address_in_use);
                return;
            }
        }
        bound_socket_names_[registers[0]] = name;
        output_.write("[network] bind fd=" + std::to_string(registers[0]) +
                      " " + name + "\n");
        bsd_success(cpu, 0);
        return;
    }
    case 105: { // setsockopt
        const auto fd = registers[0];
        if (!virtual_descriptors_.contains(fd)) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
            return;
        }
        const auto value_address = registers[3];
        const auto value_size = registers[4];
        if (value_size > bsd_support::maximum_io ||
            value_size > static_cast<std::uint32_t>(
                             std::numeric_limits<std::int32_t>::max())) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        if (value_address == 0 && value_size != 0) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        std::vector<std::byte> value;
        if (value_size != 0) {
            const auto bytes = memory_.read_bytes(value_address, value_size);
            if (!bytes) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            value = *bytes;
        }
        const auto defunct_option =
            registers[1] == darwin::socket::option_level &&
            registers[2] == darwin::socket::option_defunct_ok;
        if (defunct_option) {
            if (value.size() != sizeof(std::uint32_t)) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            const auto enabled = std::any_of(value.begin(), value.end(),
                [](std::byte byte) { return byte != std::byte { 0 }; });
            if (!enabled && process_.effective_uid != 0U) {
                bsd_error(cpu, darwin::error::operation_not_permitted);
                return;
            }
        }
        if (const auto host = host_sockets_.find(fd);
            host != host_sockets_.end() && !defunct_option) {
            const auto result =
                host->second->set_option(registers[1], registers[2], value);
            if (result.status == HostSocketStatus::Error) {
                bsd_error(cpu, result.darwin_error);
                return;
            }
        }
        if (const auto udp = virtual_udp_sockets_.find(fd);
            udp != virtual_udp_sockets_.end() && !defunct_option &&
            udp->second->set_option(registers[1], registers[2], value) !=
                bsd::VirtualUdpStatus::Success) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        socket_options_[fd][{ registers[1], registers[2] }] = std::move(value);
        output_.write(
            "[network] setsockopt pid=" + std::to_string(process_.pid) +
            " fd=" + std::to_string(fd) +
            " level=" + std::to_string(registers[1]) +
            " option=" + std::to_string(registers[2]) +
            " bytes=" + std::to_string(value_size) + "\n");
        bsd_success(cpu, 0);
        return;
    }
    case darwin::syscall::listen: {
        if (!virtual_descriptors_.contains(registers[0])) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
        } else if (const auto host = host_sockets_.find(registers[0]);
            host != host_sockets_.end()) {
            const auto listened = host->second->listen(registers[1]);
            if (listened.status == HostSocketStatus::Error) {
                bsd_error(cpu, listened.darwin_error);
            } else {
                listening_sockets_.insert(registers[0]);
                bsd_success(cpu, 0);
            }
        } else if (kernel_network::is_isolated_stream_descriptor(
                       virtual_descriptors_.at(registers[0]))) {
            if (!bound_socket_names_.contains(registers[0])) {
                bsd_error(cpu, bsd_support::invalid_argument);
            } else {
                listening_sockets_.insert(registers[0]);
                output_.write("[network] isolated listen pid=" +
                              std::to_string(process_.pid) +
                              " fd=" + std::to_string(registers[0]) + "\n");
                bsd_success(cpu, 0);
            }
        } else if (!bound_socket_names_.contains(registers[0])) {
            bsd_error(cpu, 22);
        } else {
            const auto& name = bound_socket_names_.at(registers[0]);
            std::lock_guard socket_lock { shared_state_->socket_mutex };
            const auto own = unix_listener_states_.find(registers[0]);
            const auto linked = shared_state_->unix_socket_nodes.contains(name);
            auto existing =
                linked && shared_state_->unix_listeners.contains(name)
                    ? shared_state_->unix_listeners.at(name).lock()
                    : std::shared_ptr<KernelSharedState::UnixListener> { };
            if (linked && existing &&
                (own == unix_listener_states_.end() ||
                    own->second != existing)) {
                bsd_error(cpu, bsd_support::address_in_use);
            } else {
                if (!existing && own != unix_listener_states_.end()) {
                    existing = own->second;
                }
                if (!existing) {
                    existing =
                        std::make_shared<KernelSharedState::UnixListener>(
                            KernelSharedState::UnixListener {
                                process_.pid, registers[0], { } });
                }
                existing->credentials.emplace(
                    process_.effective_uid, process_.effective_gid);
                // unlink after bind but before listen leaves an unnamed
                // listening socket. Do not resurrect the pathname.
                if (linked)
                    shared_state_->unix_listeners[name] = existing;
                unix_listener_states_[registers[0]] = std::move(existing);
                listening_sockets_.insert(registers[0]);
                output_.write(
                    "[network] listen pid=" + std::to_string(process_.pid) +
                    " fd=" + std::to_string(registers[0]) + " " + name + "\n");
                bsd_success(cpu, 0);
            }
        }
        return;
    }
    case 118: { // getsockopt
        const auto fd = registers[0];
        const auto socket = virtual_descriptors_.find(fd);
        if (socket == virtual_descriptors_.end()) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
            return;
        }
        const auto value_address = registers[3];
        const auto size_address = registers[4];
        std::uint32_t capacity = 0;
        if (value_address != 0) {
            const auto requested_size = memory_.read32(size_address);
            if (!requested_size) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            capacity = *requested_size;
            if (capacity > static_cast<std::uint32_t>(
                               std::numeric_limits<std::int32_t>::max())) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
        }

        std::vector<std::byte> value;
        if (registers[1] == darwin::socket::local_option_level &&
            registers[2] == darwin::socket::local_peer_credentials &&
            (socket->second.starts_with("unix-") ||
                socket->second == "socketpair")) {
            const auto endpoint = socket_pair_endpoints_.find(fd);
            if (endpoint == socket_pair_endpoints_.end() ||
                !endpoint->second.peer_credentials) {
                bsd_error(cpu, socket->second == "unix-dgram"
                                   ? bsd_support::invalid_argument
                                   : bsd_support::not_connected);
                return;
            }
            const auto encoded = endpoint->second.peer_credentials->encode();
            value.assign(encoded.begin(), encoded.end());
        } else if (registers[1] == darwin::socket::option_level &&
            registers[2] == darwin::socket::option_pending_bytes) {
            std::uint32_t pending_error = 0;
            const auto pending_count =
                socket_pending_byte_count(fd, pending_error);
            if (!pending_count) {
                bsd_error(cpu, pending_error);
                return;
            }
            value.resize(sizeof(*pending_count));
            for (std::size_t byte = 0; byte < sizeof(*pending_count); ++byte) {
                value[byte] =
                    static_cast<std::byte>(*pending_count >> (byte * 8U));
            }
        } else if (registers[1] == darwin::socket::option_level &&
                   registers[2] == darwin::socket::option_error) {
            std::uint32_t socket_error = 0;
            if (const auto host = host_sockets_.find(fd);
                host != host_sockets_.end()) {
                const auto queried = host->second->socket_error();
                if (queried.status == HostSocketStatus::Error) {
                    bsd_error(cpu, queried.darwin_error);
                    return;
                }
                socket_error = queried.darwin_error;
            }
            value.resize(sizeof(socket_error));
            for (std::size_t byte = 0; byte < sizeof(socket_error); ++byte) {
                value[byte] =
                    static_cast<std::byte>(socket_error >> (byte * 8U));
            }
        }
        if (value.empty()) {
            if (const auto descriptor = socket_options_.find(fd);
                descriptor != socket_options_.end()) {
                if (const auto option =
                        descriptor->second.find({ registers[1], registers[2] });
                    option != descriptor->second.end()) {
                    value = option->second;
                }
            }
        }
        if (value.empty() && registers[1] == darwin::socket::option_level) {
            std::uint32_t default_value = 0;
            if (registers[2] == darwin::socket::option_type) {
                if (const auto host = host_sockets_.find(fd);
                    host != host_sockets_.end()) {
                    default_value = host->second->darwin_type();
                } else {
                    default_value = socket->second == "unix-stream"      ? 1U
                                    : socket->second == "unix-dgram"     ? 2U
                                    : socket->second == "unix-seqpacket" ? 5U
                                                                         : 3U;
                }
            } else if (registers[2] ==
                       darwin::socket::option_accept_connection) {
                default_value = listening_sockets_.contains(fd) ? 1U : 0U;
            } else if (registers[2] == darwin::socket::option_defunct_ok) {
                default_value = !(socket->second.starts_with("unix-") ||
                                  socket->second == "socketpair");
            }
            value.resize(sizeof(default_value));
            for (std::size_t byte = 0; byte < sizeof(default_value); ++byte) {
                value[byte] =
                    static_cast<std::byte>(default_value >> (byte * 8U));
            }
        }
        if (value.empty()) {
            output_.write("[network] unsupported getsockopt pid=" +
                          std::to_string(process_.pid) + " fd=" +
                          std::to_string(fd) + " level=" +
                          std::to_string(registers[1]) + " option=" +
                          std::to_string(registers[2]) + " capacity=" +
                          std::to_string(capacity) + "\n");
            bsd_error(cpu, darwin::error::no_protocol_option);
            return;
        }
        const auto copied_size = std::min<std::uint32_t>(
            capacity, static_cast<std::uint32_t>(value.size()));
        if ((copied_size != 0 && !memory_.copy_in(value_address,
                                     std::span<const std::byte> {
                                         value.data(), copied_size })) ||
            !memory_.write32(
                size_address, static_cast<std::uint32_t>(value.size()))) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        bsd_success(cpu, 0);
        return;
    }
    case darwin::syscall::write_vector: {
        const auto fd = registers[0];
        const auto vector_address = registers[1];
        const auto vector_count = registers[2];
        if (vector_count > darwin::io::maximum_vector_count) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        if (vector_count == 0) {
            bsd_success(cpu, 0);
            return;
        }
        const auto vector_bytes = static_cast<std::size_t>(vector_count) *
                                  darwin::socket::arm32_iovec::size;
        if (vector_address == 0 || !memory_.accessible(vector_address,
                                       vector_bytes, MemoryPermission::Read)) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }

        struct GuestIovec {
            std::uint32_t base { };
            std::uint32_t size { };
        };
        std::vector<GuestIovec> iovecs;
        iovecs.reserve(vector_count);
        std::size_t payload_size = 0;
        for (std::uint32_t index = 0; index < vector_count; ++index) {
            const auto entry =
                vector_address + index * darwin::socket::arm32_iovec::size;
            const auto base = memory_.read32(
                entry + darwin::socket::arm32_iovec::base_offset);
            const auto size = memory_.read32(
                entry + darwin::socket::arm32_iovec::length_offset);
            if (!base || !size || (*size != 0U && *base == 0U)) {
                bsd_error(cpu, bsd_support::bad_address);
                return;
            }
            if (*size > bsd_support::maximum_io ||
                payload_size > bsd_support::maximum_io - *size) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            iovecs.push_back(GuestIovec { *base, *size });
            payload_size += *size;
        }

        auto host_fd = fd;
        if (const auto duplicate = duplicated_descriptors_.find(host_fd);
            duplicate != duplicated_descriptors_.end()) {
            host_fd = duplicate->second;
        }
        if (host_sockets_.contains(host_fd)) {
            if (payload_size == 0) {
                bsd_success(cpu, 0);
                return;
            }
            std::vector<std::byte> payload;
            payload.reserve(payload_size);
            for (const auto& iovec : iovecs) {
                if (iovec.size == 0U)
                    continue;
                const auto bytes = memory_.read_bytes(iovec.base, iovec.size);
                if (!bytes) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                payload.insert(payload.end(), bytes->begin(), bytes->end());
            }
            const auto nonblocking = (file_status_flags_[host_fd] &
                                         darwin::open_flag::non_block) != 0;
            static_cast<void>(send_host_socket_bytes(
                cpu, host_fd, std::move(payload), { }, nonblocking));
            return;
        }
        std::uint32_t total = 0;
        for (const auto& iovec : iovecs) {
            registers[0] = fd;
            registers[1] = iovec.base;
            registers[2] = iovec.size;
            dispatch_bsd(cpu, darwin::syscall::write);
            if ((cpu.cpsr() & bsd_support::carry_flag) != 0) {
                if (total != 0)
                    bsd_success(cpu, total);
                return;
            }
            total += registers[0];
            if (registers[0] < iovec.size)
                break;
        }
        bsd_success(cpu, total);
        return;
    }
    case darwin::syscall::send_to: {
        auto fd = registers[0];
        if (const auto duplicate = duplicated_descriptors_.find(fd);
            duplicate != duplicated_descriptors_.end()) {
            fd = duplicate->second;
        }
        if (!virtual_descriptors_.contains(fd)) {
            bsd_error(cpu, bsd_support::bad_file_descriptor);
            return;
        }
        const auto size = static_cast<std::size_t>(registers[2]);
        if (size > bsd_support::maximum_io) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return;
        }
        auto bytes = memory_.read_bytes(registers[1], size);
        if (!bytes) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        if (kernel_control_endpoints_.contains(fd)) {
            if (registers[4] != 0 || registers[5] != 0) {
                bsd_error(cpu, bsd_support::already_connected);
                return;
            }
            static_cast<void>(write_kernel_control_socket(cpu, fd, *bytes));
            return;
        }
        if (const auto host = host_sockets_.find(fd);
            host != host_sockets_.end()) {
            std::vector<std::byte> destination;
            if (registers[4] != 0 || registers[5] != 0) {
                if (registers[4] == 0 || registers[5] < 2 ||
                    registers[5] > bsd_support::maximum_socket_address_size) {
                    bsd_error(cpu, bsd_support::invalid_argument);
                    return;
                }
                const auto address =
                    memory_.read_bytes(registers[4], registers[5]);
                if (!address) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                destination = *address;
            }
            const auto nonblocking =
                (registers[3] & darwin::socket::message_dont_wait) != 0 ||
                (file_status_flags_[fd] & darwin::open_flag::non_block) != 0;
            static_cast<void>(send_host_socket_bytes(cpu, fd, std::move(*bytes),
                std::move(destination), nonblocking));
            return;
        }
        if (const auto endpoint = socket_pair_endpoints_.find(fd);
            endpoint != socket_pair_endpoints_.end()) {
            if (!endpoint->second.local_write_open() ||
                !endpoint->second.peer_read_open()) {
                bsd_error(cpu, darwin::error::broken_pipe);
                return;
            }
            std::lock_guard socket_lock { shared_state_->socket_mutex };
            auto& destination =
                shared_state_->socket_pair_buffers[endpoint->second.pair]
                                                  [1U - endpoint->second.side];
            destination.insert(destination.end(), bytes->begin(), bytes->end());
            shared_state_->note_io_event_transition();
            bsd_success(cpu, static_cast<std::uint32_t>(bytes->size()));
            return;
        }
        if (const auto udp = virtual_udp_sockets_.find(fd);
            udp != virtual_udp_sockets_.end()) {
            bsd::VirtualUdpStatus sent { };
            if (registers[4] == 0 && registers[5] == 0) {
                sent = udp->second->send(*bytes);
            } else if (registers[4] == 0 || registers[5] < 2) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            } else {
                const auto destination =
                    memory_.read_bytes(registers[4], registers[5]);
                if (!destination) {
                    bsd_error(cpu, bsd_support::bad_address);
                    return;
                }
                sent = udp->second->send(*bytes, *destination);
            }
            if (sent != bsd::VirtualUdpStatus::Success) {
                bsd_error(cpu, sent == bsd::VirtualUdpStatus::BadFileDescriptor
                                   ? bsd_support::bad_file_descriptor
                               : sent == bsd::VirtualUdpStatus::NotConnected
                                   ? bsd_support::not_connected
                               : sent == bsd::VirtualUdpStatus::AlreadyConnected
                                   ? bsd_support::already_connected
                                   : bsd_support::invalid_argument);
                return;
            }
            bsd_success(cpu, static_cast<std::uint32_t>(bytes->size()));
            return;
        }
        // An unconnected Unix datagram needs a live destination. Darwin's
        // sendto arguments beyond r3 are stack based, and the current callers
        // reach this path only after a failed /var/run/syslog connection.
        bsd_error(cpu, bsd_support::not_connected);
        return;
    }
    case darwin::syscall::shutdown: {
        auto fd = registers[0];
        if (const auto duplicate = duplicated_descriptors_.find(fd);
            duplicate != duplicated_descriptors_.end()) {
            fd = duplicate->second;
        }
        if (const auto host = host_sockets_.find(fd);
            host != host_sockets_.end()) {
            const auto result = host->second->shutdown(registers[1]);
            if (result.status == HostSocketStatus::Error) {
                bsd_error(cpu, result.darwin_error);
            } else {
                bsd_success(cpu, 0);
            }
            return;
        }
        if (const auto endpoint = socket_pair_endpoints_.find(fd);
            endpoint != socket_pair_endpoints_.end()) {
            const auto how = registers[1];
            if (how > darwin::socket::shutdown_read_write) {
                bsd_error(cpu, bsd_support::invalid_argument);
                return;
            }
            if (how == darwin::socket::shutdown_read ||
                how == darwin::socket::shutdown_read_write) {
                endpoint->second.shutdown_read();
                std::lock_guard socket_lock { shared_state_->socket_mutex };
                shared_state_
                    ->socket_pair_buffers[endpoint->second.pair]
                                         [endpoint->second.side]
                    .clear();
            }
            if (how == darwin::socket::shutdown_write ||
                how == darwin::socket::shutdown_read_write) {
                endpoint->second.shutdown_write();
            }
            shared_state_->note_io_event_transition();
            bsd_success(cpu, 0);
        } else {
            bsd_error(cpu, virtual_descriptors_.contains(fd)
                               ? bsd_support::not_connected
                               : bsd_support::bad_file_descriptor);
        }
        return;
    }
    case darwin::syscall::socket_pair: {
        if (registers[0] != darwin::socket::local ||
            (registers[1] != darwin::socket::stream &&
                registers[1] != darwin::socket::datagram &&
                registers[1] != darwin::socket::sequenced_packet)) {
            bsd_error(cpu, 47); // EAFNOSUPPORT
            return;
        }
        const auto first = allocate_file_descriptor();
        if (!first) {
            bsd_error(cpu, 24); // EMFILE
            return;
        }
        virtual_descriptors_.emplace(*first, "socketpair");
        file_status_flags_[*first] = darwin::open_flag::read_write;
        descriptor_flags_[*first] = 0;
        const auto second = allocate_file_descriptor();
        if (!second) {
            virtual_descriptors_.erase(*first);
            file_status_flags_.erase(*first);
            descriptor_flags_.erase(*first);
            bsd_error(cpu, 24); // EMFILE
            return;
        }
        virtual_descriptors_.emplace(*second, "socketpair");
        file_status_flags_[*second] = darwin::open_flag::read_write;
        descriptor_flags_[*second] = 0;
        const auto pair = shared_state_->next_socket_pair++;
        auto endpoints = make_socket_pair_endpoints(pair);
        if (registers[1] == darwin::socket::stream) {
            endpoints.first.peer_credentials.emplace(
                process_.effective_uid, process_.effective_gid);
            endpoints.second.peer_credentials = endpoints.first.peer_credentials;
        }
        shared_state_->socket_pair_buffers.emplace(
            pair, std::array<std::deque<std::byte>, 2> { });
        socket_pair_endpoints_.emplace(*first, std::move(endpoints.first));
        socket_pair_endpoints_.emplace(*second, std::move(endpoints.second));
        output_.write(
            "[network] socketpair pid=" + std::to_string(process_.pid) +
            " pair=" + std::to_string(pair) + " type=" +
            std::to_string(registers[1]) + " fds=" + std::to_string(*first) +
            "," + std::to_string(*second) + "\n");
        if (!memory_.write32(registers[3], *first) ||
            !memory_.write32(registers[3] + 4, *second)) {
            bsd_error(cpu, bsd_support::bad_address);
            return;
        }
        bsd_success(cpu, 0);
        return;
    }
    default:
        trace_unknown(cpu, "BSD syscall", number);
        bsd_error(cpu, bsd_support::not_implemented);
        return;
    }
}

} // namespace shade
