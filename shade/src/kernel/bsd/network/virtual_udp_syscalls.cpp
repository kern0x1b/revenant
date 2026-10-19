// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Dispatch guest datagram and message I/O across host and isolated
// UDP paths.

#include "kernel/kernel.hpp"

#include "kernel/darwin_abi.hpp"

#include "../support.hpp"

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <span>
#include <utility>
#include <vector>

namespace shade {
namespace {

    std::uint32_t socket_error(bsd::VirtualUdpStatus status)
    {
        switch (status) {
        case bsd::VirtualUdpStatus::NotConnected:
            return bsd_support::not_connected;
        case bsd::VirtualUdpStatus::BadFileDescriptor:
            return bsd_support::bad_file_descriptor;
        case bsd::VirtualUdpStatus::AlreadyConnected:
            return bsd_support::already_connected;
        case bsd::VirtualUdpStatus::AddressFamilyUnsupported:
            return 47; // EAFNOSUPPORT
        case bsd::VirtualUdpStatus::InvalidArgument:
            return bsd_support::invalid_argument;
        case bsd::VirtualUdpStatus::Success:
            return 0;
        }
        return bsd_support::invalid_argument;
    }

} // namespace

bool CompatibilityKernel::send_host_socket_bytes(Cpu& cpu, std::uint32_t fd,
    std::vector<std::byte> bytes, std::vector<std::byte> destination,
    bool nonblocking)
{
    const auto host = host_sockets_.find(fd);
    if (host == host_sockets_.end()) {
        bsd_error(cpu, bsd_support::bad_file_descriptor);
        return true;
    }

    const auto result = host->second->send(bytes, destination);
    if (result.status == HostSocketStatus::WouldBlock) {
        if (nonblocking) {
            bsd_error(cpu, bsd_support::would_block);
            return true;
        }
        const auto processor = cpu.processor_id();
        pending_host_writes_.insert_or_assign(
            processor, PendingHostWrite { fd, host->second, std::move(bytes),
                           std::move(destination) });
        process_.waiting_for_events = true;
        bsd_success(cpu, 0);
        output_.write(
            "[network] write wait pid=" + std::to_string(process_.pid) +
            " fd=" + std::to_string(fd) + "\n");
        cpu.halt(Umbra::HaltReason::UserDefined5);
        return true;
    }
    if (result.status == HostSocketStatus::Error) {
        bsd_error(cpu, result.darwin_error);
        return true;
    }

    bsd_success(cpu, static_cast<std::uint32_t>(result.transferred));
    if (socket_payload_trace_count_ < 32U) {
        output_.write("[network] send host fd=" + std::to_string(fd) +
                      " bytes=" + std::to_string(result.transferred) + "\n");
        ++socket_payload_trace_count_;
    }
    return true;
}

bool CompatibilityKernel::send_socket_message(Cpu& cpu, std::uint32_t fd,
    std::uint32_t message_address, std::uint32_t flags)
{
    const auto socket = virtual_udp_sockets_.find(fd);
    const auto host = host_sockets_.find(fd);
    if (socket == virtual_udp_sockets_.end() && host == host_sockets_.end())
        return false;

    using namespace darwin::socket;
    if (!memory_.accessible(
            message_address, arm32_message::size, MemoryPermission::Read)) {
        bsd_error(cpu, bsd_support::bad_address);
        return true;
    }
    const auto name_address =
        memory_.read32(message_address + arm32_message::name_offset);
    const auto name_length =
        memory_.read32(message_address + arm32_message::name_length_offset);
    const auto iov_address =
        memory_.read32(message_address + arm32_message::iov_offset);
    const auto iov_count =
        memory_.read32(message_address + arm32_message::iov_count_offset);
    const auto control_address =
        memory_.read32(message_address + arm32_message::control_offset);
    const auto control_length =
        memory_.read32(message_address + arm32_message::control_length_offset);
    if (!name_address || !name_length || !iov_address || !iov_count ||
        !control_address || !control_length) {
        bsd_error(cpu, bsd_support::bad_address);
        return true;
    }
    if (*iov_count > darwin::io::maximum_vector_count ||
        *name_length > bsd_support::maximum_socket_address_size ||
        *control_length > bsd_support::maximum_io) {
        bsd_error(cpu, bsd_support::invalid_argument);
        return true;
    }
    const auto iovec_bytes =
        static_cast<std::size_t>(*iov_count) * arm32_iovec::size;
    if ((*iov_count != 0 &&
            (*iov_address == 0 || !memory_.accessible(*iov_address, iovec_bytes,
                                      MemoryPermission::Read))) ||
        (*name_length != 0 && (*name_address == 0 ||
                                  !memory_.accessible(*name_address,
                                      *name_length, MemoryPermission::Read))) ||
        (*control_length != 0 &&
            (*control_address == 0 ||
                !memory_.accessible(*control_address, *control_length,
                    MemoryPermission::Read)))) {
        bsd_error(cpu, bsd_support::bad_address);
        return true;
    }

    std::vector<std::byte> payload;
    for (std::uint32_t index = 0; index < *iov_count; ++index) {
        const auto entry = *iov_address + index * arm32_iovec::size;
        const auto base = memory_.read32(entry + arm32_iovec::base_offset);
        const auto size = memory_.read32(entry + arm32_iovec::length_offset);
        if (!base || !size || (*size != 0 && *base == 0) ||
            *size > bsd_support::maximum_io ||
            payload.size() > bsd_support::maximum_io - *size) {
            bsd_error(cpu, !base || !size || (*size != 0 && *base == 0)
                               ? bsd_support::bad_address
                               : bsd_support::invalid_argument);
            return true;
        }
        if (*size == 0)
            continue;
        const auto bytes = memory_.read_bytes(*base, *size);
        if (!bytes) {
            bsd_error(cpu, bsd_support::bad_address);
            return true;
        }
        payload.insert(payload.end(), bytes->begin(), bytes->end());
    }

    std::vector<std::byte> destination;
    if (*name_length != 0) {
        const auto address = memory_.read_bytes(*name_address, *name_length);
        if (!address) {
            bsd_error(cpu, bsd_support::bad_address);
            return true;
        }
        destination = *address;
    }

    if (host != host_sockets_.end()) {
        const auto nonblocking =
            (flags & message_dont_wait) != 0 ||
            (file_status_flags_[fd] & darwin::open_flag::non_block) != 0;
        return send_host_socket_bytes(
            cpu, fd, std::move(payload), std::move(destination), nonblocking);
    }

    const auto result = destination.empty()
                            ? socket->second->send(payload)
                            : socket->second->send(payload, destination);
    if (result != bsd::VirtualUdpStatus::Success) {
        bsd_error(cpu, socket_error(result));
    } else {
        bsd_success(cpu, static_cast<std::uint32_t>(payload.size()));
        if (socket_payload_trace_count_ < 32U) {
            output_.write(
                "[network] sendmsg virtual UDP fd=" + std::to_string(fd) +
                " bytes=" + std::to_string(payload.size()) + "\n");
            ++socket_payload_trace_count_;
        }
    }
    return true;
}

} // namespace shade
