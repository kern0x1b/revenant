// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Expose the virtual DNS configuration through the guest resolver
// boundary.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/configd/blob/configd-137.3/dnsinfo/dnsinfo.h

#include "network/dns_configuration_hle.hpp"

#include <cstddef>
#include <cstdint>
#include <span>
#include <string>
#include <string_view>
#include <vector>

#include "foundation/address_space.hpp"
#include "foundation/userland_hle.hpp"

namespace shade {
namespace {

    constexpr std::string_view responder_image { "/usr/sbin/mDNSResponder" };

    // Darwin 8 ARM32 dnsinfo.h layouts. dns_configuration_copy normally expands
    // configd's serialized DNS state into these pointer-rich structures.
    constexpr std::uint32_t config_size = 40;
    constexpr std::uint32_t resolver_pointer_offset = config_size;
    constexpr std::uint32_t resolver_offset = resolver_pointer_offset + 4U;
    // iPhoneOS 1.0 uses the post-Tiger resolver layout: interface/scoped fields
    // precede the original dnsinfo members.  The firmware reads n_nameserver at
    // +8, nameserver at +12, port at +20, and search_order at +60.
    constexpr std::uint32_t resolver_size = 96;
    constexpr std::uint32_t nameserver_pointer_offset =
        resolver_offset + resolver_size;
    constexpr std::uint32_t nameserver_offset = nameserver_pointer_offset + 4U;
    constexpr std::uint32_t nameserver_size = 16;
    constexpr std::uint32_t allocation_size =
        nameserver_offset + nameserver_size;
    constexpr std::uint32_t default_search_order = 200000;

    void write_u16(
        std::span<std::byte> bytes, std::size_t offset, std::uint16_t value)
    {
        bytes[offset] = static_cast<std::byte>(value & 0xffU);
        bytes[offset + 1U] = static_cast<std::byte>((value >> 8U) & 0xffU);
    }

    void write_u32(
        std::span<std::byte> bytes, std::size_t offset, std::uint32_t value)
    {
        for (std::size_t index = 0; index < 4; ++index) {
            bytes[offset + index] =
                static_cast<std::byte>((value >> (index * 8U)) & 0xffU);
        }
    }

} // namespace

void register_dns_configuration_hle(UserlandHleRegistry& registry)
{
    registry.register_function(std::string { responder_image },
        "_dns_configuration_copy", [](UserlandHleCall& call) {
            const auto base = call.allocate_data(allocation_size, 4);
            if (base == 0) {
                call.set_return(0);
                return;
            }

            std::vector<std::byte> bytes(allocation_size);
            write_u32(bytes, 0, 1); // dns_config_t::n_resolver
            write_u32(bytes, 4, base + resolver_pointer_offset);
            write_u32(bytes, resolver_pointer_offset, base + resolver_offset);

            write_u32(bytes, resolver_offset + 8U, 1);
            write_u32(
                bytes, resolver_offset + 12U, base + nameserver_pointer_offset);
            write_u16(bytes, resolver_offset + 20U, 53);
            write_u32(bytes, resolver_offset + 60U, default_search_order);
            write_u32(
                bytes, nameserver_pointer_offset, base + nameserver_offset);

            // sockaddr_in { sin_len, sin_family, sin_port, sin_addr } for the
            // simulator's DNS proxy at 10.0.2.3:53.
            bytes[nameserver_offset] = std::byte { 16 };
            bytes[nameserver_offset + 1U] = std::byte { 2 };
            bytes[nameserver_offset + 2U] = std::byte { 0 };
            bytes[nameserver_offset + 3U] = std::byte { 53 };
            bytes[nameserver_offset + 4U] = std::byte { 10 };
            bytes[nameserver_offset + 5U] = std::byte { 0 };
            bytes[nameserver_offset + 6U] = std::byte { 2 };
            bytes[nameserver_offset + 7U] = std::byte { 3 };

            if (!call.memory().copy_in(base, bytes)) {
                call.set_return(0);
                return;
            }
            call.set_return(base);
        });
    registry.register_function(std::string { responder_image },
        "_dns_configuration_free", [](UserlandHleCall& call) {
            // HLE data pages live for the process address-space lifetime.
            call.set_return(0);
        });
}

} // namespace shade
