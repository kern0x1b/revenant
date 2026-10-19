// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Encode guest interface records, network events and wireless ioctl
// payloads.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/net/if.h
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/netinet/in_var.h
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/sys/kern_event.h
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/netinet/in.c

#include "network/darwin_network_abi.hpp"

#include "network/wifi_state.hpp"

#include <algorithm>
#include <bit>
#include <limits>
#include <stdexcept>
#include <string>
#include <string_view>

namespace shade::darwin::network {
namespace {

    constexpr std::size_t interface_message_header_size = 112;
    constexpr std::size_t interface_data_offset = 16;
    constexpr std::size_t interface_data_mtu_offset = interface_data_offset + 8;
    constexpr std::size_t interface_data_baudrate_offset =
        interface_data_offset + 16;
    constexpr std::size_t interface_address_message_header_size = 20;
    constexpr std::size_t sockaddr_data_offset = 8;
    constexpr std::size_t minimum_sockaddr_dl_size = 20;
    constexpr std::uint32_t ethernet_baudrate = 10'000'000;
    constexpr std::size_t network_event_data_size =
        sizeof(std::uint32_t) * 2U + interface_name_size;
    constexpr std::size_t ipv4_network_event_data_size =
        network_event_data_size + 7U * sizeof(std::uint32_t);
    constexpr std::size_t ipv6_network_event_data_size = 160;

    void put32(
        std::span<std::byte> bytes, std::size_t offset, std::uint32_t value);

    std::string_view event_interface_base_name(
        const InterfaceSnapshot& interface)
    {
        auto name = std::string_view { interface.name };
        const auto unit = std::to_string(interface.unit);
        if (name.size() > unit.size() && name.ends_with(unit)) {
            name.remove_suffix(unit.size());
        }
        return name;
    }

    std::vector<std::byte> make_network_event_storage(
        const InterfaceSnapshot& interface, std::size_t size)
    {
        std::vector<std::byte> result(size);
        put32(result, 0, interface.family);
        put32(result, 4, interface.unit);
        // XNU's net_event_data carries the driver base name and unit
        // separately. Consumers reconstruct the BSD interface name as
        // "<if_name><if_unit>".
        const auto base_name = event_interface_base_name(interface);
        const auto name_length =
            std::min(base_name.size(), interface_name_size - 1U);
        std::transform(base_name.begin(),
            base_name.begin() + static_cast<std::ptrdiff_t>(name_length),
            result.begin() + 8,
            [](char value) { return static_cast<std::byte>(value); });
        return result;
    }

    void put16(
        std::span<std::byte> bytes, std::size_t offset, std::uint16_t value)
    {
        bytes[offset] = static_cast<std::byte>(value);
        bytes[offset + 1] = static_cast<std::byte>(value >> 8U);
    }

    void put32(
        std::span<std::byte> bytes, std::size_t offset, std::uint32_t value)
    {
        for (std::size_t index = 0; index < sizeof(value); ++index) {
            bytes[offset + index] =
                static_cast<std::byte>(value >> (index * 8U));
        }
    }

    std::uint32_t ipv4_network_value(const std::array<std::byte, 16>& address)
    {
        std::uint32_t value { };
        for (std::size_t index = 0; index < 4; ++index) {
            value = (value << 8U) |
                    std::to_integer<std::uint8_t>(address[4 + index]);
        }
        return value;
    }

    void put_ipv4_network_value(
        std::span<std::byte> bytes, std::size_t offset, std::uint32_t value)
    {
        for (std::size_t index = 0; index < sizeof(value); ++index) {
            bytes[offset + index] =
                static_cast<std::byte>(value >> ((3U - index) * 8U));
        }
    }

    std::uint32_t ipv4_classful_mask(std::uint32_t address)
    {
        if ((address & 0x80000000U) == 0)
            return 0xff000000U;
        if ((address & 0xc0000000U) == 0x80000000U) {
            return 0xffff0000U;
        }
        return 0xffffff00U;
    }

    std::size_t rounded_sockaddr_size(std::size_t size)
    {
        constexpr std::size_t alignment = sizeof(std::uint32_t);
        return std::max(alignment, (size + alignment - 1U) & ~(alignment - 1U));
    }

    template <std::size_t Size>
    void append_sockaddr(std::vector<std::byte>& record,
        const std::array<std::byte, Size>& address)
    {
        const auto declared_size = std::to_integer<std::uint8_t>(address[0]);
        const auto copied_size =
            declared_size == 0 ? Size
                               : std::min<std::size_t>(declared_size, Size);
        const auto padded_size = rounded_sockaddr_size(copied_size);
        const auto original_size = record.size();
        record.resize(original_size + padded_size);
        std::copy_n(
            address.begin(), copied_size, record.begin() + original_size);
    }

    std::vector<std::byte> make_interface_record(
        const InterfaceSnapshot& interface)
    {
        const auto name_length =
            std::min(interface.name.size(), interface_name_size - 1U);
        const auto link_length = std::min<std::size_t>(
            interface.link_address_length, interface.link_address.size());
        const auto sockaddr_length = std::max(minimum_sockaddr_dl_size,
            sockaddr_data_offset + name_length + link_length);
        const auto padded_sockaddr_length =
            rounded_sockaddr_size(sockaddr_length);
        const auto record_size =
            interface_message_header_size + padded_sockaddr_length;
        if (record_size > std::numeric_limits<std::uint16_t>::max()) {
            throw std::length_error {
                "Darwin interface record exceeds ifm_msglen"
            };
        }

        std::vector<std::byte> record(record_size);
        put16(record, 0, static_cast<std::uint16_t>(record.size()));
        record[2] = static_cast<std::byte>(route_message_version);
        record[3] = static_cast<std::byte>(route_message_interface_info);
        put32(record, 4, route_address_interface);
        put32(record, 8, interface.flags);
        put16(record, 12, interface.index);

        record[interface_data_offset] = static_cast<std::byte>(interface.type);
        record[interface_data_offset + 3] = static_cast<std::byte>(link_length);
        record[interface_data_offset + 4] = static_cast<std::byte>(
            interface.type == interface_type_ethernet ? 14U : 0U);
        put32(record, interface_data_mtu_offset, interface.mtu);
        put32(record, interface_data_baudrate_offset,
            interface.type == interface_type_ethernet ? ethernet_baudrate : 0U);

        const auto sockaddr_offset = interface_message_header_size;
        record[sockaddr_offset] = static_cast<std::byte>(sockaddr_length);
        record[sockaddr_offset + 1] =
            static_cast<std::byte>(address_family_link);
        put16(record, sockaddr_offset + 2, interface.index);
        record[sockaddr_offset + 4] = static_cast<std::byte>(interface.type);
        record[sockaddr_offset + 5] = static_cast<std::byte>(name_length);
        record[sockaddr_offset + 6] = static_cast<std::byte>(link_length);
        std::transform(interface.name.begin(),
            interface.name.begin() + static_cast<std::ptrdiff_t>(name_length),
            record.begin() + static_cast<std::ptrdiff_t>(
                                 sockaddr_offset + sockaddr_data_offset),
            [](char value) { return static_cast<std::byte>(value); });
        std::copy_n(interface.link_address.begin(), link_length,
            record.begin() +
                static_cast<std::ptrdiff_t>(
                    sockaddr_offset + sockaddr_data_offset + name_length));
        return record;
    }

    template <std::size_t Size>
    std::vector<std::byte> make_address_record(
        const InterfaceSnapshot& interface,
        const std::array<std::byte, Size>& address,
        const std::optional<std::array<std::byte, Size>>& netmask,
        const std::optional<std::array<std::byte, Size>>& broadcast)
    {
        std::uint32_t address_bits = route_address_interface_address;
        if (netmask)
            address_bits |= route_address_netmask;
        if (broadcast)
            address_bits |= route_address_broadcast;

        std::vector<std::byte> record(interface_address_message_header_size);
        record[2] = static_cast<std::byte>(route_message_version);
        record[3] = static_cast<std::byte>(route_message_new_address);
        put32(record, 4, address_bits);
        put16(record, 12, interface.index);
        if (netmask)
            append_sockaddr(record, *netmask);
        append_sockaddr(record, address);
        if (broadcast)
            append_sockaddr(record, *broadcast);
        if (record.size() > std::numeric_limits<std::uint16_t>::max()) {
            throw std::length_error {
                "Darwin address record exceeds ifam_msglen"
            };
        }
        put16(record, 0, static_cast<std::uint16_t>(record.size()));
        return record;
    }

    void append_record(
        std::vector<std::byte>& output, std::vector<std::byte> record)
    {
        output.insert(output.end(), record.begin(), record.end());
    }

} // namespace

std::optional<std::vector<std::byte>> apple80211_driver::make_network_record(
    const VirtualAccessPoint* access_point, NetworkRecordLayout layout,
    std::uint16_t ie_length, std::uint32_t ie_pointer)
{
    if (layout.size < scan_flags_offset + sizeof(std::uint32_t) ||
        layout.ie_length_offset + sizeof(std::uint16_t) > layout.size ||
        layout.ie_pointer_offset + sizeof(std::uint32_t) > layout.size ||
        (ie_length != 0 && ie_pointer == 0) ||
        (access_point && access_point->ssid.size() > 32)) {
        return std::nullopt;
    }

    std::vector<std::byte> result(layout.size, std::byte { 0 });
    put16(result, layout.ie_length_offset, ie_length);
    put32(result, layout.ie_pointer_offset, ie_pointer);
    if (!access_point)
        return result;

    put32(result, scan_channel_offset, access_point->channel);
    put32(result, scan_channel_flags_offset, 0);
    put16(result, scan_noise_offset,
        static_cast<std::uint16_t>(static_cast<std::int16_t>(-90)));
    const auto signal_strength =
        std::clamp(access_point->rssi - scan_signal_floor_dbm, 0,
            scan_signal_ceiling_dbm - scan_signal_floor_dbm);
    put16(
        result, scan_rssi_offset, static_cast<std::uint16_t>(signal_strength));
    put16(result, scan_beacon_interval_offset, 100);
    // IEEE 802.11 capability bit 0 is ESS. Privacy (bit 4) is set only for
    // networks whose association requires a key.
    put16(result, scan_capabilities_offset,
        static_cast<std::uint16_t>(
            1U | (access_point->security == WifiSecurity::Open ? 0U : 0x10U)));
    std::copy(access_point->bssid.begin(), access_point->bssid.end(),
        result.begin() + scan_bssid_offset);
    result[scan_rate_count_offset] = std::byte { 0 };
    result[scan_ssid_length_offset] =
        static_cast<std::byte>(access_point->ssid.size());
    std::transform(access_point->ssid.begin(), access_point->ssid.end(),
        result.begin() + scan_ssid_offset, [](char value) {
            return static_cast<std::byte>(static_cast<unsigned char>(value));
        });
    put32(result, scan_age_offset, 0);
    put32(result, scan_flags_offset, 0);
    return result;
}

std::vector<std::byte> make_route_interface_list(
    std::span<const InterfaceSnapshot> interfaces, std::uint32_t address_family,
    std::uint32_t interface_index)
{
    std::vector<std::byte> result;
    for (const auto& interface : interfaces) {
        if (interface_index != 0 && interface.index != interface_index)
            continue;
        append_record(result, make_interface_record(interface));
        if ((address_family == address_family_unspecified ||
                address_family == address_family_inet) &&
            interface.ipv4_address) {
            auto destination = interface.ipv4_broadcast;
            if (!destination &&
                (interface.flags & interface_flag_loopback) != 0) {
                // XNU's in_ifinit redirects a loopback in_ifaddr's
                // ifa_dstaddr to ifa_addr. sysctl_iflist exports that pointer
                // as RTAX_BRD, which Darwin getifaddrs exposes through the
                // ifa_broadaddr/ifa_dstaddr union.
                destination = interface.ipv4_address;
            }
            append_record(
                result, make_address_record(interface, *interface.ipv4_address,
                            interface.ipv4_netmask, destination));
        }
        if ((address_family == address_family_unspecified ||
                address_family == address_family_inet6) &&
            interface.ipv6_address) {
            append_record(
                result, make_address_record(interface, *interface.ipv6_address,
                            interface.ipv6_netmask,
                            std::optional<std::array<std::byte, 28>> { }));
        }
    }
    return result;
}

std::vector<std::byte> make_network_event_data(
    const InterfaceSnapshot& interface)
{
    return make_network_event_storage(interface, network_event_data_size);
}

std::vector<std::byte> make_ipv4_network_event_data(
    const InterfaceSnapshot& interface)
{
    auto result =
        make_network_event_storage(interface, ipv4_network_event_data_size);
    constexpr std::size_t address_offset = network_event_data_size;
    constexpr std::size_t network_offset = address_offset + 4U;
    constexpr std::size_t netmask_offset = network_offset + 4U;
    constexpr std::size_t subnet_offset = netmask_offset + 4U;
    constexpr std::size_t subnet_mask_offset = subnet_offset + 4U;
    constexpr std::size_t broadcast_offset = subnet_mask_offset + 4U;
    constexpr std::size_t destination_offset = broadcast_offset + 4U;

    if (interface.ipv4_address) {
        std::copy_n(interface.ipv4_address->begin() + 4, 4,
            result.begin() + static_cast<std::ptrdiff_t>(address_offset));
        const auto address = ipv4_network_value(*interface.ipv4_address);
        const auto class_mask = ipv4_classful_mask(address);
        const auto subnet_mask =
            interface.ipv4_netmask ? ipv4_network_value(*interface.ipv4_netmask)
                                   : class_mask;
        const auto network_mask = class_mask & subnet_mask;

        // XNU's ia_{,sub}net{,mask} fields are guest-host-order u_long
        // values, unlike the surrounding in_addr fields.
        put32(result, network_offset, address & network_mask);
        put32(result, netmask_offset, network_mask);
        put32(result, subnet_offset, address & subnet_mask);
        put32(result, subnet_mask_offset, subnet_mask);
        put_ipv4_network_value(
            result, broadcast_offset, (address & network_mask) | ~network_mask);
    }
    if (interface.ipv4_broadcast) {
        std::copy_n(interface.ipv4_broadcast->begin() + 4, 4,
            result.begin() + static_cast<std::ptrdiff_t>(destination_offset));
    } else if (interface.ipv4_address &&
               (interface.flags & interface_flag_loopback) != 0) {
        std::copy_n(interface.ipv4_address->begin() + 4, 4,
            result.begin() + static_cast<std::ptrdiff_t>(destination_offset));
    }
    return result;
}

std::vector<std::byte> make_ipv6_network_event_data(
    const InterfaceSnapshot& interface)
{
    auto result =
        make_network_event_storage(interface, ipv6_network_event_data_size);
    constexpr std::size_t address_offset = network_event_data_size;
    constexpr std::size_t network_offset = address_offset + 28U;
    constexpr std::size_t prefix_mask_offset = network_offset + 56U;
    constexpr std::size_t prefix_length_offset = prefix_mask_offset + 28U;

    if (interface.ipv6_address) {
        std::copy(interface.ipv6_address->begin(),
            interface.ipv6_address->end(),
            result.begin() + static_cast<std::ptrdiff_t>(address_offset));
        std::copy(interface.ipv6_address->begin(),
            interface.ipv6_address->end(),
            result.begin() + static_cast<std::ptrdiff_t>(network_offset));
    }
    if (interface.ipv6_netmask) {
        std::copy(interface.ipv6_netmask->begin(),
            interface.ipv6_netmask->end(),
            result.begin() + static_cast<std::ptrdiff_t>(prefix_mask_offset));
        std::uint32_t prefix_length { };
        for (std::size_t index = 8; index < 24; ++index) {
            prefix_length += std::popcount(std::to_integer<std::uint8_t>(
                (*interface.ipv6_netmask)[index]));
            if (interface.ipv6_address) {
                result[network_offset + index] =
                    (*interface.ipv6_address)[index] &
                    (*interface.ipv6_netmask)[index];
            }
        }
        put32(result, prefix_length_offset, prefix_length);
    }
    return result;
}

std::vector<std::byte> make_kernel_event(std::uint32_t identifier,
    std::uint32_t vendor, std::uint32_t event_class,
    std::uint32_t event_subclass, std::uint32_t event_code,
    std::span<const std::byte> event_data)
{
    if (event_data.size() >
        std::numeric_limits<std::uint32_t>::max() - kernel_event_header_size) {
        throw std::length_error { "Darwin kernel event exceeds total_size" };
    }
    std::vector<std::byte> result(kernel_event_header_size + event_data.size());
    put32(result, 0, static_cast<std::uint32_t>(result.size()));
    put32(result, 4, vendor);
    put32(result, 8, event_class);
    put32(result, 12, event_subclass);
    put32(result, 16, identifier);
    put32(result, 20, event_code);
    std::copy(event_data.begin(), event_data.end(),
        result.begin() + static_cast<std::ptrdiff_t>(kernel_event_header_size));
    return result;
}

} // namespace shade::darwin::network
