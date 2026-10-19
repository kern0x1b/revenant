// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Implement guest PF_SYSTEM kernel-control socket operations.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/kern/kern_control.c

#include "kernel/kernel.hpp"

#include "kernel/darwin_abi.hpp"
#include "kernel/darwin_kernel_control_abi.hpp"
#include "kernel/kernel_control.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <span>
#include <sstream>
#include <string>

#include "../../support.hpp"

namespace shade {

bool CompatibilityKernel::create_kernel_control_socket(Cpu& cpu)
{
    auto& registers = cpu.registers();
    if (registers[0] != darwin::kernel_control::protocol_family_system ||
        registers[1] != darwin::socket::datagram ||
        registers[2] != darwin::kernel_control::protocol_control) {
        return false;
    }
    const auto fd = allocate_file_descriptor();
    if (!fd) {
        bsd_error(cpu, 24); // EMFILE
        return true;
    }
    virtual_descriptors_.emplace(
        *fd, std::string { bsd::kernel_control::descriptor_kind });
    kernel_control_endpoints_[*fd] =
        std::make_shared<bsd::kernel_control::Endpoint>(
            bsd::kernel_control::Endpoint { registers[1], std::nullopt, 0 });
    file_status_flags_[*fd] = darwin::open_flag::read_write;
    descriptor_flags_[*fd] = 0;
    output_.write(
        "[kernel-control] socket pid=" + std::to_string(process_.pid) +
        " fd=" + std::to_string(*fd) + "\n");
    bsd_success(cpu, *fd);
    return true;
}

bool CompatibilityKernel::connect_kernel_control_socket(Cpu& cpu)
{
    auto& registers = cpu.registers();
    const auto endpoint = kernel_control_endpoints_.find(registers[0]);
    if (endpoint == kernel_control_endpoints_.end())
        return false;
    if (registers[2] < darwin::kernel_control::socket_address_size) {
        bsd_error(cpu, bsd_support::invalid_argument);
        return true;
    }
    const auto length = memory_.read8(
        registers[1] + darwin::kernel_control::socket_address_length_offset);
    const auto family = memory_.read8(
        registers[1] + darwin::kernel_control::socket_address_family_offset);
    const auto system_address = memory_.read16(
        registers[1] + darwin::kernel_control::socket_address_system_offset);
    const auto identifier = memory_.read32(
        registers[1] +
        darwin::kernel_control::socket_address_identifier_offset);
    const auto unit = memory_.read32(
        registers[1] + darwin::kernel_control::socket_address_unit_offset);
    if (!length || !family || !system_address || !identifier || !unit) {
        bsd_error(cpu, bsd_support::bad_address);
        return true;
    }
    if (*length != darwin::kernel_control::socket_address_size ||
        *family != darwin::kernel_control::protocol_family_system ||
        *system_address != darwin::kernel_control::system_address_control) {
        bsd_error(cpu, bsd_support::invalid_argument);
        return true;
    }
    for (std::uint32_t index = 0;
        index < darwin::kernel_control::socket_address_reserved_count;
        ++index) {
        const auto reserved = memory_.read32(
            registers[1] +
            darwin::kernel_control::socket_address_reserved_offset +
            index * static_cast<std::uint32_t>(sizeof(std::uint32_t)));
        if (!reserved) {
            bsd_error(cpu, bsd_support::bad_address);
            return true;
        }
        if (*reserved != 0) {
            bsd_error(cpu, bsd_support::invalid_argument);
            return true;
        }
    }
    const auto name = bsd::kernel_control::name_for_identifier(*identifier);
    if (!name) {
        bsd_error(cpu, darwin::error::no_entry);
        return true;
    }
    if (endpoint->second->peer) {
        bsd_error(cpu, bsd_support::already_connected);
        return true;
    }
    endpoint->second->peer =
        bsd::kernel_control::Address { *identifier, *unit };
    output_.write(
        "[kernel-control] connect pid=" + std::to_string(process_.pid) +
        " fd=" + std::to_string(registers[0]) + " name=" +
        std::string { *name } + " unit=" + std::to_string(*unit) + "\n");
    bsd_success(cpu, 0);
    return true;
}

bool CompatibilityKernel::ioctl_kernel_control_socket(Cpu& cpu)
{
    auto& registers = cpu.registers();
    const auto endpoint = kernel_control_endpoints_.find(registers[0]);
    if (endpoint == kernel_control_endpoints_.end())
        return false;
    if (registers[1] != darwin::kernel_control::ioctl_get_info) {
        std::ostringstream message;
        message << "[kernel-control] unsupported ioctl pid=" << process_.pid
                << " fd=" << registers[0] << " request=0x" << std::hex
                << registers[1] << '\n';
        output_.write(message.str());
        bsd_error(cpu, darwin::error::inappropriate_ioctl);
        return true;
    }
    const auto name = memory_.read_c_string(
        registers[2] + darwin::kernel_control::control_info_name_offset,
        darwin::kernel_control::maximum_name_size);
    if (!name) {
        bsd_error(cpu, bsd_support::bad_address);
        return true;
    }
    if (name->empty() ||
        name->size() + 1 > darwin::kernel_control::maximum_name_size) {
        bsd_error(cpu, bsd_support::invalid_argument);
        return true;
    }
    const auto identifier = bsd::kernel_control::identifier_for_name(*name);
    output_.write(
        "[kernel-control] lookup pid=" + std::to_string(process_.pid) +
        " name=" + *name + (identifier ? " found\n" : " missing\n"));
    if (!identifier) {
        bsd_error(cpu, darwin::error::no_entry);
        return true;
    }
    if (!memory_.write32(
            registers[2] +
                darwin::kernel_control::control_info_identifier_offset,
            *identifier)) {
        bsd_error(cpu, bsd_support::bad_address);
        return true;
    }
    bsd_success(cpu, 0);
    return true;
}

bool CompatibilityKernel::name_kernel_control_socket(Cpu& cpu, bool peer)
{
    auto& registers = cpu.registers();
    const auto endpoint = kernel_control_endpoints_.find(registers[0]);
    if (endpoint == kernel_control_endpoints_.end())
        return false;
    // XNU provides ctl_peeraddr but deliberately has no local sockaddr
    // operation for kernel-control sockets.
    if (!peer) {
        bsd_error(cpu, darwin::error::operation_not_supported);
        return true;
    }
    if (!endpoint->second->peer) {
        bsd_error(cpu, bsd_support::not_connected);
        return true;
    }
    std::array<std::byte, darwin::kernel_control::socket_address_size>
        address { };
    address[darwin::kernel_control::socket_address_length_offset] =
        static_cast<std::byte>(darwin::kernel_control::socket_address_size);
    address[darwin::kernel_control::socket_address_family_offset] =
        static_cast<std::byte>(darwin::kernel_control::protocol_family_system);
    const auto write_little_endian = [&address](std::uint32_t offset,
                                         std::uint32_t value,
                                         std::uint32_t size) {
        for (std::uint32_t index = 0; index < size; ++index) {
            address[offset + index] =
                static_cast<std::byte>(value >> (index * 8U));
        }
    };
    write_little_endian(darwin::kernel_control::socket_address_system_offset,
        darwin::kernel_control::system_address_control, sizeof(std::uint16_t));
    write_little_endian(
        darwin::kernel_control::socket_address_identifier_offset,
        endpoint->second->peer->identifier, sizeof(std::uint32_t));
    write_little_endian(darwin::kernel_control::socket_address_unit_offset,
        endpoint->second->peer->unit, sizeof(std::uint32_t));
    if (!copy_socket_address(registers[1], registers[2],
            std::span<const std::byte> { address })) {
        bsd_error(cpu, bsd_support::bad_address);
    } else {
        bsd_success(cpu, 0);
    }
    return true;
}

bool CompatibilityKernel::write_kernel_control_socket(
    Cpu& cpu, std::uint32_t fd, std::span<const std::byte> bytes)
{
    const auto endpoint = kernel_control_endpoints_.find(fd);
    if (endpoint == kernel_control_endpoints_.end())
        return false;
    if (!endpoint->second->peer) {
        bsd_error(cpu, bsd_support::not_connected);
        return true;
    }
    endpoint->second->transmitted_bytes += bytes.size();
    if (socket_payload_trace_count_ < 32U) {
        output_.write(
            "[kernel-control] write pid=" + std::to_string(process_.pid) +
            " fd=" + std::to_string(fd) +
            " bytes=" + std::to_string(bytes.size()) +
            " hex=" + bsd_support::format_payload_prefix(bytes) + "\n");
        ++socket_payload_trace_count_;
    }
    // The simulated modem is offline: the IP interface control accepts
    // outgoing configuration frames but deliberately fabricates no replies.
    bsd_success(cpu, static_cast<std::uint32_t>(bytes.size()));
    return true;
}

} // namespace shade
