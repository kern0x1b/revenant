// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Encode and decode DNSService client and responder IPC messages.

#pragma once

#include <array>
#include <bit>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <optional>
#include <span>
#include <string_view>
#include <vector>

namespace shade::dnssd_ipc {

// DNSService IPC ABI used by the mDNSResponderSystemLibraries-120 client in
// iPhoneOS 1.0.  The wire header is converted one 32-bit word at a time; the
// two-word context keeps 32- and 64-bit clients interoperable.
inline constexpr std::uint32_t version = 1;
inline constexpr std::uint32_t flag_no_reply = 1U;
inline constexpr std::uint32_t flag_reuse_socket = 2U;
inline constexpr std::size_t header_size = 28U;
inline constexpr std::string_view server_path { "/var/run/mDNSResponder" };
inline constexpr std::string_view control_path_prefix {
    "/tmp/dnssd_clippath."
};

enum class RequestOperation : std::uint32_t {
    Connection = 1,
    RegisterRecord,
    RemoveRecord,
    Enumeration,
    RegisterService,
    Browse,
    Resolve,
    Query,
    ReconfirmRecord,
    AddRecord,
    UpdateRecord,
    SetDomain,
    NatPortMapping,
    GetAddressInfo,
};

enum class ReplyOperation : std::uint32_t {
    Enumeration = 64,
    RegisterService,
    Browse,
    Resolve,
    Query,
    RegisterRecord,
    NatPortMapping,
    GetAddressInfo,
};

inline constexpr std::int32_t error_no_such_record = -65554;
inline constexpr std::size_t reply_prefix_size = 12U;
inline constexpr std::size_t get_address_info_request_fixed_size = 12U;
inline constexpr std::size_t get_address_info_reply_suffix_size = 8U;

inline constexpr std::uint32_t get_address_info_protocol_ipv4 = 1U;
inline constexpr std::uint32_t get_address_info_protocol_ipv6 = 2U;

enum class DnsRecordType : std::uint16_t {
    A = 1,
    Aaaa = 28,
};

struct Header {
    std::uint32_t data_length { };
    std::uint32_t flags { };
    RequestOperation operation { RequestOperation::Connection };
    std::array<std::uint32_t, 2> client_context { };
    std::uint32_t record_index { };
};

struct ReplyHeader {
    std::uint32_t data_length { };
    std::uint32_t flags { };
    ReplyOperation operation { ReplyOperation::Enumeration };
    std::array<std::uint32_t, 2> client_context { };
    std::uint32_t record_index { };
};

struct ReplyPrefix {
    std::uint32_t flags { };
    std::uint32_t interface_index { };
    std::int32_t error { };
};

struct GetAddressInfoRequest {
    std::uint32_t flags { };
    std::uint32_t interface_index { };
    std::uint32_t protocols { };
    std::string_view hostname;
};

struct GetAddressInfoReply {
    ReplyPrefix prefix;
    std::string_view hostname;
    DnsRecordType record_type { DnsRecordType::A };
    std::span<const std::byte> address;
    std::uint32_t ttl { };
};

[[nodiscard]] constexpr std::array<std::byte, 2> encode_u16(std::uint16_t value)
{
    return {
        static_cast<std::byte>((value >> 8U) & 0xffU),
        static_cast<std::byte>(value & 0xffU),
    };
}

[[nodiscard]] constexpr std::uint16_t decode_u16(const std::byte* bytes)
{
    return static_cast<std::uint16_t>(
        (static_cast<std::uint16_t>(bytes[0]) << 8U) |
        static_cast<std::uint16_t>(bytes[1]));
}

[[nodiscard]] constexpr std::array<std::byte, 4> encode_u32(std::uint32_t value)
{
    return {
        static_cast<std::byte>((value >> 24U) & 0xffU),
        static_cast<std::byte>((value >> 16U) & 0xffU),
        static_cast<std::byte>((value >> 8U) & 0xffU),
        static_cast<std::byte>(value & 0xffU),
    };
}

[[nodiscard]] constexpr std::uint32_t decode_u32(const std::byte* bytes)
{
    return (static_cast<std::uint32_t>(bytes[0]) << 24U) |
           (static_cast<std::uint32_t>(bytes[1]) << 16U) |
           (static_cast<std::uint32_t>(bytes[2]) << 8U) |
           static_cast<std::uint32_t>(bytes[3]);
}

// client_context is deliberately opaque on the wire. The daemon copies its
// eight bytes without byte swapping so a client can recover its own pointer;
// this target is little-endian ARM32.
[[nodiscard]] constexpr std::array<std::byte, 4> encode_arm32_u32(
    std::uint32_t value)
{
    return {
        static_cast<std::byte>(value & 0xffU),
        static_cast<std::byte>((value >> 8U) & 0xffU),
        static_cast<std::byte>((value >> 16U) & 0xffU),
        static_cast<std::byte>((value >> 24U) & 0xffU),
    };
}

[[nodiscard]] constexpr std::uint32_t decode_arm32_u32(const std::byte* bytes)
{
    return static_cast<std::uint32_t>(bytes[0]) |
           (static_cast<std::uint32_t>(bytes[1]) << 8U) |
           (static_cast<std::uint32_t>(bytes[2]) << 16U) |
           (static_cast<std::uint32_t>(bytes[3]) << 24U);
}

[[nodiscard]] constexpr std::array<std::byte, header_size> encode_header_words(
    std::uint32_t data_length, std::uint32_t flags, std::uint32_t operation,
    const std::array<std::uint32_t, 2>& client_context,
    std::uint32_t record_index)
{
    std::array<std::byte, header_size> wire { };
    const std::array converted_words { version, data_length, flags, operation };
    for (std::size_t word = 0; word < converted_words.size(); ++word) {
        const auto encoded = encode_u32(converted_words[word]);
        for (std::size_t byte = 0; byte < encoded.size(); ++byte) {
            wire[word * encoded.size() + byte] = encoded[byte];
        }
    }
    for (std::size_t word = 0; word < client_context.size(); ++word) {
        const auto encoded = encode_arm32_u32(client_context[word]);
        for (std::size_t byte = 0; byte < encoded.size(); ++byte) {
            wire[16U + word * encoded.size() + byte] = encoded[byte];
        }
    }
    const auto encoded_record_index = encode_u32(record_index);
    for (std::size_t byte = 0; byte < encoded_record_index.size(); ++byte) {
        wire[24U + byte] = encoded_record_index[byte];
    }
    return wire;
}

[[nodiscard]] constexpr std::array<std::byte, header_size> encode_header(
    const Header& header)
{
    return encode_header_words(header.data_length, header.flags,
        static_cast<std::uint32_t>(header.operation), header.client_context,
        header.record_index);
}

[[nodiscard]] constexpr std::array<std::byte, header_size> encode_header(
    const ReplyHeader& header)
{
    return encode_header_words(header.data_length, header.flags,
        static_cast<std::uint32_t>(header.operation), header.client_context,
        header.record_index);
}

[[nodiscard]] constexpr std::array<std::byte, reply_prefix_size>
encode_reply_prefix(const ReplyPrefix& prefix)
{
    std::array<std::byte, reply_prefix_size> wire { };
    const std::array words {
        prefix.flags,
        prefix.interface_index,
        static_cast<std::uint32_t>(prefix.error),
    };
    for (std::size_t word = 0; word < words.size(); ++word) {
        const auto encoded = encode_u32(words[word]);
        for (std::size_t byte = 0; byte < encoded.size(); ++byte) {
            wire[word * encoded.size() + byte] = encoded[byte];
        }
    }
    return wire;
}

namespace detail {

    template <std::size_t Size>
    void append(std::vector<std::byte>& output,
        const std::array<std::byte, Size>& value)
    {
        output.insert(output.end(), value.begin(), value.end());
    }

    [[nodiscard]] inline bool valid_c_string(std::string_view value)
    {
        return value.find('\0') == std::string_view::npos;
    }

    [[nodiscard]] inline std::optional<std::size_t> find_terminator(
        std::span<const std::byte> wire, std::size_t start)
    {
        for (std::size_t index = start; index < wire.size(); ++index) {
            if (wire[index] == std::byte { 0 }) {
                return index;
            }
        }
        return std::nullopt;
    }

    [[nodiscard]] inline std::string_view string_view_at(
        std::span<const std::byte> wire, std::size_t start, std::size_t size)
    {
        return { reinterpret_cast<const char*>(wire.data() + start), size };
    }

} // namespace detail

[[nodiscard]] inline std::optional<std::vector<std::byte>>
encode_get_address_info_request(const GetAddressInfoRequest& request)
{
    if (!detail::valid_c_string(request.hostname)) {
        return std::nullopt;
    }
    std::vector<std::byte> wire;
    wire.reserve(
        get_address_info_request_fixed_size + request.hostname.size() + 1U);
    detail::append(wire, encode_u32(request.flags));
    detail::append(wire, encode_u32(request.interface_index));
    detail::append(wire, encode_u32(request.protocols));
    for (const char character : request.hostname) {
        wire.push_back(static_cast<std::byte>(character));
    }
    wire.push_back(std::byte { 0 });
    return wire;
}

[[nodiscard]] inline std::optional<GetAddressInfoRequest>
decode_get_address_info_request(std::span<const std::byte> wire)
{
    if (wire.size() < get_address_info_request_fixed_size + 1U) {
        return std::nullopt;
    }
    const auto terminator =
        detail::find_terminator(wire, get_address_info_request_fixed_size);
    if (!terminator || *terminator + 1U != wire.size()) {
        return std::nullopt;
    }
    return GetAddressInfoRequest {
        decode_u32(wire.data()),
        decode_u32(wire.data() + 4U),
        decode_u32(wire.data() + 8U),
        detail::string_view_at(wire, get_address_info_request_fixed_size,
            *terminator - get_address_info_request_fixed_size),
    };
}

[[nodiscard]] inline std::optional<std::vector<std::byte>>
encode_get_address_info_reply(const GetAddressInfoReply& reply)
{
    if (!detail::valid_c_string(reply.hostname) ||
        reply.address.size() > std::numeric_limits<std::uint16_t>::max()) {
        return std::nullopt;
    }
    std::vector<std::byte> wire;
    wire.reserve(reply_prefix_size + reply.hostname.size() + 1U +
                 get_address_info_reply_suffix_size + reply.address.size());
    detail::append(wire, encode_reply_prefix(reply.prefix));
    for (const char character : reply.hostname) {
        wire.push_back(static_cast<std::byte>(character));
    }
    wire.push_back(std::byte { 0 });
    detail::append(
        wire, encode_u16(static_cast<std::uint16_t>(reply.record_type)));
    detail::append(
        wire, encode_u16(static_cast<std::uint16_t>(reply.address.size())));
    wire.insert(wire.end(), reply.address.begin(), reply.address.end());
    detail::append(wire, encode_u32(reply.ttl));
    return wire;
}

[[nodiscard]] inline std::optional<GetAddressInfoReply>
decode_get_address_info_reply(std::span<const std::byte> wire)
{
    if (wire.size() <
        reply_prefix_size + 1U + get_address_info_reply_suffix_size) {
        return std::nullopt;
    }
    const auto terminator = detail::find_terminator(wire, reply_prefix_size);
    if (!terminator) {
        return std::nullopt;
    }
    const auto record_offset = *terminator + 1U;
    if (wire.size() < record_offset + get_address_info_reply_suffix_size) {
        return std::nullopt;
    }
    const auto address_size = decode_u16(wire.data() + record_offset + 2U);
    const auto address_offset = record_offset + 4U;
    const auto ttl_offset = address_offset + address_size;
    if (ttl_offset + 4U != wire.size()) {
        return std::nullopt;
    }
    return GetAddressInfoReply {
        ReplyPrefix {
            decode_u32(wire.data()),
            decode_u32(wire.data() + 4U),
            std::bit_cast<std::int32_t>(decode_u32(wire.data() + 8U)),
        },
        detail::string_view_at(
            wire, reply_prefix_size, *terminator - reply_prefix_size),
        static_cast<DnsRecordType>(decode_u16(wire.data() + record_offset)),
        wire.subspan(address_offset, address_size),
        decode_u32(wire.data() + ttl_offset),
    };
}

} // namespace shade::dnssd_ipc
