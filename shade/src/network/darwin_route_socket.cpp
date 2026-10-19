// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Parse and maintain guest PF_ROUTE messages and virtual routing
// entries.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/net/route.h
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/net/rtsock.c

#include "network/darwin_route_socket.hpp"

#include "network/darwin_network_abi.hpp"

#include <algorithm>
#include <bit>
#include <utility>

namespace shade::darwin::route {
namespace {

    std::uint16_t read16(std::span<const std::byte> bytes, std::size_t offset)
    {
        return static_cast<std::uint16_t>(
            std::to_integer<std::uint8_t>(bytes[offset]) |
            (static_cast<std::uint16_t>(
                 std::to_integer<std::uint8_t>(bytes[offset + 1]))
                << 8U));
    }

    std::uint32_t read32(std::span<const std::byte> bytes, std::size_t offset)
    {
        std::uint32_t value { };
        for (std::size_t index = 0; index < sizeof(value); ++index) {
            value |= static_cast<std::uint32_t>(
                         std::to_integer<std::uint8_t>(bytes[offset + index]))
                     << (index * 8U);
        }
        return value;
    }

    void write32(
        std::span<std::byte> bytes, std::size_t offset, std::uint32_t value)
    {
        for (std::size_t index = 0; index < sizeof(value); ++index) {
            bytes[offset + index] =
                static_cast<std::byte>((value >> (index * 8U)) & 0xffU);
        }
    }

    void write16(
        std::span<std::byte> bytes, std::size_t offset, std::uint16_t value)
    {
        bytes[offset] = static_cast<std::byte>(value & 0xffU);
        bytes[offset + 1] = static_cast<std::byte>(value >> 8U);
    }

    std::size_t aligned_sockaddr_size(std::size_t size)
    {
        // Darwin's ROUNDUP treats a zero-length netmask as one alignment unit.
        if (size == 0)
            return sockaddr_alignment;
        return (size + sockaddr_alignment - 1U) & ~(sockaddr_alignment - 1U);
    }

    bool supported_command(std::uint8_t type)
    {
        return type == message_add || type == message_delete ||
               type == message_change || type == message_get ||
               type == message_get_silent;
    }

    ParseResult parse_failure(ParseError error)
    {
        return { std::nullopt, error };
    }

    std::size_t address_data_offset(std::uint8_t family)
    {
        return family == network::address_family_inet ? 4U : 8U;
    }

    std::size_t address_data_size(std::uint8_t family)
    {
        return family == network::address_family_inet ? 4U : 16U;
    }

    std::vector<std::byte> address_data(
        std::span<const std::byte> address, std::uint8_t family)
    {
        const auto offset = address_data_offset(family);
        const auto size = address_data_size(family);
        std::vector<std::byte> result(size);
        if (address.size() > offset) {
            const auto count = std::min(size, address.size() - offset);
            std::copy_n(address.begin() + static_cast<std::ptrdiff_t>(offset),
                static_cast<std::ptrdiff_t>(count), result.begin());
        }
        return result;
    }

    std::vector<std::byte> effective_mask(const Entry& entry)
    {
        if ((entry.flags & flag_host) != 0) {
            return std::vector<std::byte>(
                address_data_size(entry.family), std::byte { 0xff });
        }
        if (!entry.netmask.empty()) {
            return address_data(entry.netmask, entry.family);
        }
        return std::vector<std::byte>(address_data_size(entry.family));
    }

    std::size_t mask_bit_count(std::span<const std::byte> mask)
    {
        std::size_t result { };
        for (const auto byte : mask) {
            result += std::popcount(std::to_integer<std::uint8_t>(byte));
        }
        return result;
    }

    bool address_matches(const Entry& route, std::span<const std::byte> query)
    {
        const auto destination = address_data(route.destination, route.family);
        const auto mask = effective_mask(route);
        if (destination.size() != query.size() || mask.size() != query.size()) {
            return false;
        }
        for (std::size_t index = 0; index < query.size(); ++index) {
            if ((query[index] & mask[index]) !=
                (destination[index] & mask[index])) {
                return false;
            }
        }
        return true;
    }

    void append_sockaddr(
        std::vector<std::byte>& output, std::span<const std::byte> address)
    {
        const auto start = output.size();
        output.insert(output.end(), address.begin(), address.end());
        output.resize(start + aligned_sockaddr_size(address.size()));
    }

    std::vector<std::byte> make_link_sockaddr(const Entry& entry)
    {
        constexpr std::size_t link_sockaddr_size = 20;
        constexpr std::size_t link_name_offset = 8;
        std::vector<std::byte> link(link_sockaddr_size);
        link[0] = static_cast<std::byte>(link_sockaddr_size);
        link[1] = static_cast<std::byte>(network::address_family_link);
        write16(link, 2, entry.interface_index);
        const auto name_size = std::min(
            entry.interface_name.size(), link_sockaddr_size - link_name_offset);
        link[5] = static_cast<std::byte>(name_size);
        std::transform(entry.interface_name.begin(),
            entry.interface_name.begin() +
                static_cast<std::ptrdiff_t>(name_size),
            link.begin() + static_cast<std::ptrdiff_t>(link_name_offset),
            [](char value) { return static_cast<std::byte>(value); });
        return link;
    }

} // namespace

ParseResult parse_message(std::span<const std::byte> bytes)
{
    if (bytes.size() < message_header_size) {
        return parse_failure(ParseError::TruncatedHeader);
    }
    if (read16(bytes, 0) != bytes.size()) {
        return parse_failure(ParseError::LengthMismatch);
    }
    if (std::to_integer<std::uint8_t>(bytes[2]) != message_version) {
        return parse_failure(ParseError::UnsupportedVersion);
    }
    const auto type = std::to_integer<std::uint8_t>(bytes[3]);
    if (!supported_command(type)) {
        return parse_failure(ParseError::UnsupportedType);
    }

    Message message;
    message.type = type;
    message.interface_index = read16(bytes, 4);
    message.flags = read32(bytes, header_flags_offset);
    message.addresses = read32(bytes, header_addresses_offset);
    message.pid = read32(bytes, header_pid_offset);
    message.sequence = read32(bytes, header_sequence_offset);
    message.error = read32(bytes, header_error_offset);

    if ((message.addresses & address_destination) == 0 ||
        (type == message_add && (message.addresses & address_gateway) == 0)) {
        return parse_failure(ParseError::MissingAddress);
    }

    std::size_t offset = message_header_size;
    for (std::size_t index = 0; index < maximum_sockaddr_count; ++index) {
        if ((message.addresses & (1U << index)) == 0)
            continue;
        if (offset >= bytes.size()) {
            return parse_failure(ParseError::InvalidSockaddr);
        }
        const auto length = static_cast<std::size_t>(
            std::to_integer<std::uint8_t>(bytes[offset]));
        const auto occupied = aligned_sockaddr_size(length);
        if (occupied > bytes.size() - offset ||
            length > bytes.size() - offset) {
            return parse_failure(ParseError::InvalidSockaddr);
        }
        message.sockaddrs[index] = std::vector<std::byte> {
            bytes.begin() + static_cast<std::ptrdiff_t>(offset),
            bytes.begin() + static_cast<std::ptrdiff_t>(offset + length)
        };
        offset += occupied;
    }
    if (offset != bytes.size()) {
        return parse_failure(ParseError::TrailingData);
    }

    const auto& destination = *message.sockaddrs[0];
    if (destination.size() < 2) {
        return parse_failure(ParseError::InvalidSockaddr);
    }
    const auto family = std::to_integer<std::uint8_t>(destination[1]);
    const auto minimum_address_size =
        family == network::address_family_inet
            ? 16U
            : (family == network::address_family_inet6 ? 28U : 0U);
    if (minimum_address_size == 0 ||
        destination.size() < minimum_address_size) {
        return parse_failure(ParseError::InconsistentFamily);
    }
    for (const auto index : { 1U, 2U }) {
        if (!message.sockaddrs[index] || message.sockaddrs[index]->empty())
            continue;
        if (message.sockaddrs[index]->size() < 2) {
            return parse_failure(ParseError::InvalidSockaddr);
        }
        const auto candidate_family =
            std::to_integer<std::uint8_t>((*message.sockaddrs[index])[1]);
        // Compact netmasks are permitted to carry AF_UNSPEC.  Gateways may be
        // AF_LINK for directly attached routes.
        if (candidate_family != network::address_family_unspecified &&
            candidate_family != family &&
            !(index == 1U &&
                candidate_family == network::address_family_link)) {
            return parse_failure(ParseError::InconsistentFamily);
        }
    }
    if (message.sockaddrs[4] && !message.sockaddrs[4]->empty() &&
        (message.sockaddrs[4]->size() < 8 ||
            std::to_integer<std::uint8_t>((*message.sockaddrs[4])[1]) !=
                network::address_family_link)) {
        return parse_failure(ParseError::InconsistentFamily);
    }
    return { .message = std::move(message) };
}

std::optional<Entry> make_entry(const Message& message)
{
    if (!message.sockaddrs[0] || message.sockaddrs[0]->size() < 2 ||
        (message.type == message_add && !message.sockaddrs[1])) {
        return std::nullopt;
    }
    Entry entry;
    entry.family = std::to_integer<std::uint8_t>((*message.sockaddrs[0])[1]);
    entry.interface_index = message.interface_index;
    entry.flags = message.flags;
    entry.destination = *message.sockaddrs[0];
    if (message.sockaddrs[1])
        entry.gateway = *message.sockaddrs[1];
    if (message.sockaddrs[2])
        entry.netmask = *message.sockaddrs[2];
    if (message.sockaddrs[4]) {
        const auto& link = *message.sockaddrs[4];
        const auto name_length =
            static_cast<std::size_t>(std::to_integer<std::uint8_t>(link[5]));
        if (name_length > link.size() - 8U)
            return std::nullopt;
        entry.interface_name.assign(
            reinterpret_cast<const char*>(link.data() + 8U), name_length);
        if (entry.interface_index == 0 && link.size() >= 4) {
            entry.interface_index = read16(link, 2);
        }
    }
    return entry;
}

std::optional<Entry> make_interface_route(std::string interface_name,
    std::uint16_t interface_index, std::span<const std::byte> address,
    std::span<const std::byte> netmask, std::uint32_t flags)
{
    if (address.size() < 2)
        return std::nullopt;
    const auto family = std::to_integer<std::uint8_t>(address[1]);
    const auto expected_size =
        family == network::address_family_inet
            ? 16U
            : (family == network::address_family_inet6 ? 28U : 0U);
    if (expected_size == 0 || address.size() < expected_size ||
        ((flags & flag_host) == 0 && netmask.size() < expected_size)) {
        return std::nullopt;
    }

    Entry entry;
    entry.family = family;
    entry.interface_index = interface_index;
    entry.flags = flags;
    entry.destination.assign(address.begin(),
        address.begin() + static_cast<std::ptrdiff_t>(expected_size));
    entry.gateway = entry.destination;
    entry.interface_name = std::move(interface_name);
    entry.origin = Entry::Origin::Interface;
    const auto data_offset = address_data_offset(family);
    for (std::size_t index = 2; index < data_offset; ++index) {
        entry.destination[index] = std::byte { };
        entry.gateway[index] = std::byte { };
    }
    if ((flags & flag_host) == 0) {
        entry.netmask.assign(netmask.begin(),
            netmask.begin() + static_cast<std::ptrdiff_t>(expected_size));
        const auto mask = address_data(entry.netmask, family);
        for (std::size_t index = 0; index < mask.size(); ++index) {
            entry.destination[data_offset + index] &= mask[index];
        }
    }
    return entry;
}

std::optional<Entry> make_default_gateway_route(std::string interface_name,
    std::uint16_t interface_index, std::span<const std::byte> gateway)
{
    if (gateway.size() < 2)
        return std::nullopt;
    const auto family = std::to_integer<std::uint8_t>(gateway[1]);
    const auto expected_size =
        family == network::address_family_inet
            ? 16U
            : (family == network::address_family_inet6 ? 28U : 0U);
    if (expected_size == 0 || gateway.size() < expected_size) {
        return std::nullopt;
    }

    Entry entry;
    entry.family = family;
    entry.interface_index = interface_index;
    entry.flags = flag_up | flag_gateway | flag_static;
    entry.destination.assign(expected_size, std::byte { });
    entry.destination[0] = static_cast<std::byte>(expected_size);
    entry.destination[1] = static_cast<std::byte>(family);
    entry.gateway.assign(gateway.begin(),
        gateway.begin() + static_cast<std::ptrdiff_t>(expected_size));
    entry.netmask = entry.destination;
    entry.interface_name = std::move(interface_name);
    entry.origin = Entry::Origin::Interface;
    return entry;
}

bool Entry::same_key(const Entry& other) const
{
    return family == other.family &&
           address_data(destination, family) ==
               address_data(other.destination, other.family) &&
           effective_mask(*this) == effective_mask(other);
}

std::vector<std::byte> make_response(std::span<const std::byte> request,
    std::uint32_t sender_pid, std::uint32_t darwin_error,
    std::uint16_t interface_index)
{
    std::vector<std::byte> response { request.begin(), request.end() };
    if (response.size() < message_header_size)
        return { };
    auto bytes = std::span<std::byte> { response };
    if (darwin_error == 0) {
        write32(bytes, header_flags_offset,
            read32(request, header_flags_offset) | flag_done);
    }
    if (interface_index != 0)
        write16(bytes, 4, interface_index);
    write32(bytes, header_pid_offset, sender_pid);
    write32(bytes, header_error_offset, darwin_error);
    return response;
}

std::vector<std::byte> make_entry_message(const Entry& entry,
    std::uint32_t sender_pid, std::uint32_t sequence, bool mark_done,
    bool include_interface, std::uint8_t message_type)
{
    std::uint32_t addresses = address_destination | address_gateway;
    if (!entry.netmask.empty())
        addresses |= address_netmask;
    if (include_interface && !entry.interface_name.empty()) {
        addresses |= address_interface;
    }

    std::vector<std::byte> result(message_header_size);
    result[2] = static_cast<std::byte>(message_version);
    result[3] = static_cast<std::byte>(message_type);
    write16(result, 4, entry.interface_index);
    write32(result, header_flags_offset,
        entry.flags | (mark_done ? flag_done : 0U));
    write32(result, header_addresses_offset, addresses);
    write32(result, header_pid_offset, sender_pid);
    write32(result, header_sequence_offset, sequence);
    append_sockaddr(result, entry.destination);
    append_sockaddr(result, entry.gateway);
    if (!entry.netmask.empty())
        append_sockaddr(result, entry.netmask);
    if ((addresses & address_interface) != 0) {
        append_sockaddr(result, make_link_sockaddr(entry));
    }
    write16(result, 0, static_cast<std::uint16_t>(result.size()));
    return result;
}

std::vector<std::byte> make_table_dump(std::span<const Entry> entries,
    std::uint32_t address_family, std::uint32_t required_flags,
    std::uint8_t message_type)
{
    std::vector<Entry> ordered;
    std::copy_if(entries.begin(), entries.end(), std::back_inserter(ordered),
        [&](const Entry& entry) {
            return address_family == network::address_family_unspecified ||
                   entry.family == address_family;
        });
    if (required_flags != 0) {
        std::erase_if(ordered, [&](const Entry& entry) {
            return (entry.flags & required_flags) == 0;
        });
    }
    std::sort(ordered.begin(), ordered.end(),
        [](const Entry& left, const Entry& right) {
            if (left.family != right.family)
                return left.family < right.family;
            const auto left_address =
                address_data(left.destination, left.family);
            const auto right_address =
                address_data(right.destination, right.family);
            if (left_address != right_address)
                return left_address < right_address;
            return effective_mask(left) < effective_mask(right);
        });
    std::vector<std::byte> result;
    for (const auto& entry : ordered) {
        const auto message =
            make_entry_message(entry, 0, 0, false, false, message_type);
        result.insert(result.end(), message.begin(), message.end());
    }
    return result;
}

ApplyResult Table::apply(std::uint8_t command, Entry entry)
{
    std::lock_guard lock { mutex_ };
    const auto existing = std::find_if(entries_.begin(), entries_.end(),
        [&](const Entry& candidate) { return candidate.same_key(entry); });
    if (command == message_add) {
        if (existing != entries_.end())
            return ApplyResult::AlreadyExists;
        entries_.push_back(std::move(entry));
        return ApplyResult::Applied;
    }
    if (existing == entries_.end())
        return ApplyResult::NotFound;
    if (command == message_delete) {
        entries_.erase(existing);
    } else if (command == message_change) {
        if (entry.gateway.empty())
            entry.gateway = existing->gateway;
        if (entry.interface_name.empty()) {
            entry.interface_name = existing->interface_name;
            entry.interface_index = existing->interface_index;
        }
        *existing = std::move(entry);
    } else {
        return ApplyResult::NotFound;
    }
    return ApplyResult::Applied;
}

std::optional<Entry> Table::lookup(const Entry& query) const
{
    std::lock_guard lock { mutex_ };
    if (!query.netmask.empty()) {
        const auto existing = std::find_if(entries_.begin(), entries_.end(),
            [&](const Entry& candidate) { return candidate.same_key(query); });
        return existing == entries_.end() ? std::nullopt
                                          : std::optional<Entry> { *existing };
    }

    const auto query_address = address_data(query.destination, query.family);
    const Entry* best { };
    std::size_t best_bits { };
    bool found { };
    for (const auto& candidate : entries_) {
        if (candidate.family != query.family ||
            !address_matches(candidate, query_address)) {
            continue;
        }
        const auto bits = mask_bit_count(effective_mask(candidate));
        if (!found || bits > best_bits) {
            best = &candidate;
            best_bits = bits;
            found = true;
        }
    }
    return best ? std::optional<Entry> { *best } : std::nullopt;
}

std::optional<Entry> Table::lookup_bound_interface(const Entry& query) const
{
    std::lock_guard lock { mutex_ };
    const auto query_address = address_data(query.destination, query.family);
    const Entry* best { };
    std::size_t best_bits { };
    for (const auto& candidate : entries_) {
        const auto bound =
            !candidate.interface_name.empty() || candidate.interface_index != 0;
        if (!bound || candidate.family != query.family ||
            !address_matches(candidate, query_address)) {
            continue;
        }
        const auto bits = mask_bit_count(effective_mask(candidate));
        if (best == nullptr || bits > best_bits) {
            best = &candidate;
            best_bits = bits;
        }
    }
    return best ? std::optional<Entry> { *best } : std::nullopt;
}

InterfaceRouteUpdate Table::replace_interface_routes(
    std::string_view interface_name, std::uint8_t family,
    std::span<const Entry> replacements)
{
    std::lock_guard lock { mutex_ };
    InterfaceRouteUpdate update;
    for (auto entry = entries_.begin(); entry != entries_.end();) {
        if (entry->origin == Entry::Origin::Interface &&
            entry->family == family &&
            entry->interface_name == interface_name) {
            update.removed.push_back(*entry);
            entry = entries_.erase(entry);
        } else {
            ++entry;
        }
    }
    for (auto replacement : replacements) {
        replacement.origin = Entry::Origin::Interface;
        const auto collision = std::find_if(
            entries_.begin(), entries_.end(), [&](const Entry& candidate) {
                return candidate.same_key(replacement);
            });
        if (collision == entries_.end()) {
            entries_.push_back(replacement);
            update.added.push_back(std::move(replacement));
        }
    }
    return update;
}

std::vector<Entry> Table::remove_interface_routes(
    std::string_view interface_name, std::uint16_t interface_index,
    std::uint8_t family)
{
    std::lock_guard lock { mutex_ };
    std::vector<Entry> removed;
    for (auto entry = entries_.begin(); entry != entries_.end();) {
        const auto belongs_to_interface =
            (!interface_name.empty() &&
                entry->interface_name == interface_name) ||
            (interface_index != 0 && entry->interface_index == interface_index);
        if (entry->family == family && belongs_to_interface) {
            removed.push_back(*entry);
            entry = entries_.erase(entry);
        } else {
            ++entry;
        }
    }
    return removed;
}

std::vector<Entry> Table::snapshot() const
{
    std::lock_guard lock { mutex_ };
    return entries_;
}

} // namespace shade::darwin::route
