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

#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <mutex>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <vector>

namespace shade::darwin::route {

// XNU / Darwin 8 PF_ROUTE wire constants.  The target firmware is ARM32,
// where rt_msghdr is 92 bytes and routing sockaddrs are aligned to 32 bits.
inline constexpr std::uint32_t protocol_family = 17;
inline constexpr std::uint8_t message_version = 5;
inline constexpr std::size_t message_header_size = 92;
inline constexpr std::size_t sockaddr_alignment = 4;
inline constexpr std::size_t maximum_sockaddr_count = 8;
inline constexpr std::size_t maximum_retained_messages = 256;

inline constexpr std::uint8_t message_add = 0x01;
inline constexpr std::uint8_t message_delete = 0x02;
inline constexpr std::uint8_t message_change = 0x03;
inline constexpr std::uint8_t message_get = 0x04;
inline constexpr std::uint8_t message_get_silent = 0x11;
inline constexpr std::uint8_t message_get2 = 0x14;

inline constexpr std::uint32_t sysctl_dump = 1;
inline constexpr std::uint32_t sysctl_flags = 2;
inline constexpr std::uint32_t sysctl_interface_list = 3;
inline constexpr std::uint32_t sysctl_dump2 = 7;

inline constexpr std::uint32_t flag_up = 0x00000001U;
inline constexpr std::uint32_t flag_gateway = 0x00000002U;
inline constexpr std::uint32_t flag_host = 0x00000004U;
inline constexpr std::uint32_t flag_done = 0x00000040U;
inline constexpr std::uint32_t flag_cloning = 0x00000100U;
inline constexpr std::uint32_t flag_static = 0x00000800U;
inline constexpr std::uint32_t flag_local = 0x00200000U;

inline constexpr std::uint32_t address_destination = 0x01U;
inline constexpr std::uint32_t address_gateway = 0x02U;
inline constexpr std::uint32_t address_netmask = 0x04U;
inline constexpr std::uint32_t address_interface = 0x10U;

inline constexpr std::size_t header_flags_offset = 8;
inline constexpr std::size_t header_addresses_offset = 12;
inline constexpr std::size_t header_pid_offset = 16;
inline constexpr std::size_t header_sequence_offset = 20;
inline constexpr std::size_t header_error_offset = 24;
inline constexpr std::size_t header2_reference_count_offset = 16;
inline constexpr std::size_t header2_parent_flags_offset = 20;
inline constexpr std::size_t header2_reserved_offset = 24;

enum class ParseError {
    None,
    TruncatedHeader,
    LengthMismatch,
    UnsupportedVersion,
    UnsupportedType,
    MissingAddress,
    InvalidSockaddr,
    InconsistentFamily,
    TrailingData,
};

struct Message {
    std::uint8_t type { };
    std::uint16_t interface_index { };
    std::uint32_t flags { };
    std::uint32_t addresses { };
    std::uint32_t pid { };
    std::uint32_t sequence { };
    std::uint32_t error { };
    std::array<std::optional<std::vector<std::byte>>, maximum_sockaddr_count>
        sockaddrs;
};

struct ParseResult {
    std::optional<Message> message;
    ParseError error { ParseError::None };
};

struct Entry {
    enum class Origin { RoutingSocket, Interface };

    std::uint8_t family { };
    std::uint16_t interface_index { };
    std::uint32_t flags { };
    std::vector<std::byte> destination;
    std::vector<std::byte> gateway;
    std::vector<std::byte> netmask;
    std::string interface_name;
    Origin origin { Origin::RoutingSocket };

    [[nodiscard]] bool same_key(const Entry& other) const;
};

enum class ApplyResult { Applied, AlreadyExists, NotFound };

struct InterfaceRouteUpdate {
    std::vector<Entry> removed;
    std::vector<Entry> added;
};

[[nodiscard]] ParseResult parse_message(std::span<const std::byte> bytes);
[[nodiscard]] std::optional<Entry> make_entry(const Message& message);
[[nodiscard]] std::optional<Entry> make_interface_route(
    std::string interface_name, std::uint16_t interface_index,
    std::span<const std::byte> address, std::span<const std::byte> netmask,
    std::uint32_t flags);
[[nodiscard]] std::optional<Entry> make_default_gateway_route(
    std::string interface_name, std::uint16_t interface_index,
    std::span<const std::byte> gateway);

// XNU broadcasts the result on PF_ROUTE after filling the sender, DONE flag,
// and errno fields.  Keeping this separate also makes future route listeners
// and NET_RT_DUMP support use the exact same response encoding.
[[nodiscard]] std::vector<std::byte> make_response(
    std::span<const std::byte> request, std::uint32_t sender_pid,
    std::uint32_t darwin_error, std::uint16_t interface_index = 0);

[[nodiscard]] std::vector<std::byte> make_entry_message(const Entry& entry,
    std::uint32_t sender_pid, std::uint32_t sequence, bool mark_done,
    bool include_interface, std::uint8_t message_type = message_get);
[[nodiscard]] std::vector<std::byte> make_table_dump(
    std::span<const Entry> entries, std::uint32_t address_family = 0,
    std::uint32_t required_flags = 0, std::uint8_t message_type = message_get);

class Table {
public:
    [[nodiscard]] ApplyResult apply(std::uint8_t command, Entry entry);
    [[nodiscard]] std::optional<Entry> lookup(const Entry& query) const;
    [[nodiscard]] std::optional<Entry> lookup_bound_interface(
        const Entry& query) const;
    [[nodiscard]] InterfaceRouteUpdate replace_interface_routes(
        std::string_view interface_name, std::uint8_t family,
        std::span<const Entry> replacements);
    [[nodiscard]] std::vector<Entry> remove_interface_routes(
        std::string_view interface_name, std::uint16_t interface_index,
        std::uint8_t family);
    [[nodiscard]] std::vector<Entry> snapshot() const;

private:
    mutable std::mutex mutex_;
    std::vector<Entry> entries_;
};

} // namespace shade::darwin::route
