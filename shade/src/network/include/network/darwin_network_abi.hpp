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

#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <vector>

namespace shade {
struct VirtualAccessPoint;
}

namespace shade::darwin::network {

// XNU / Darwin 8 networking constants. These are kept here rather than
// scattered through the syscall dispatcher so both builders and ABI tests use
// the same firmware-facing definitions.
inline constexpr std::uint32_t address_family_unspecified = 0;
inline constexpr std::uint32_t address_family_inet = 2;
inline constexpr std::uint32_t address_family_link = 18;
inline constexpr std::uint32_t address_family_inet6 = 30;

inline constexpr std::uint32_t protocol_ip = 0;
inline constexpr std::uint32_t protocol_udp = 17;
inline constexpr std::uint32_t protocol_ipv6 = 41;
inline constexpr std::uint32_t ip_type_of_service = 3;
inline constexpr std::uint32_t ip_time_to_live = 4;
inline constexpr std::uint32_t ip_receive_destination_address = 7;
inline constexpr std::uint32_t ip_multicast_interface = 9;
inline constexpr std::uint32_t ip_multicast_ttl = 10;
inline constexpr std::uint32_t ip_multicast_loop = 11;
inline constexpr std::uint32_t ip_add_membership = 12;
inline constexpr std::uint32_t ip_drop_membership = 13;
inline constexpr std::uint32_t ip_receive_interface = 20;
inline constexpr std::uint32_t ip_receive_ttl = 24;
inline constexpr std::uint32_t ipv6_unicast_hops = 4;
inline constexpr std::uint32_t ipv6_multicast_interface = 9;
inline constexpr std::uint32_t ipv6_multicast_hops = 10;
inline constexpr std::uint32_t ipv6_multicast_loop = 11;
inline constexpr std::uint32_t ipv6_join_group = 12;
inline constexpr std::uint32_t ipv6_leave_group = 13;
inline constexpr std::uint32_t ipv6_packet_info = 19;
inline constexpr std::uint32_t ipv6_hop_limit = 20;
inline constexpr std::uint32_t ipv6_only = 27;
inline constexpr std::uint32_t ipv4_membership_size = 8;
inline constexpr std::uint32_t ipv6_membership_size = 20;
inline constexpr std::uint32_t arm32_control_header_size = 12;
inline constexpr std::uint32_t arm32_control_level_offset = 4;
inline constexpr std::uint32_t arm32_control_type_offset = 8;
inline constexpr std::uint32_t arm32_sockaddr_dl_size = 20;
inline constexpr std::uint32_t arm32_sockaddr_in_size = 16;
inline constexpr std::uint32_t arm32_sockaddr_in6_size = 28;
inline constexpr std::uint32_t sockaddr_length_offset = 0;
inline constexpr std::uint32_t sockaddr_family_offset = 1;
inline constexpr std::uint32_t sockaddr_port_offset = 2;
inline constexpr std::uint32_t sockaddr_ipv4_address_offset = 4;
inline constexpr std::uint32_t sockaddr_ipv6_address_offset = 8;
inline constexpr std::uint32_t sockaddr_ipv6_scope_offset = 24;

inline constexpr std::uint8_t route_message_version = 5;
inline constexpr std::uint8_t route_message_new_address = 0x0c;
inline constexpr std::uint8_t route_message_interface_info = 0x0e;
inline constexpr std::uint32_t route_address_netmask = 0x04;
inline constexpr std::uint32_t route_address_interface = 0x10;
inline constexpr std::uint32_t route_address_interface_address = 0x20;
inline constexpr std::uint32_t route_address_broadcast = 0x80;

inline constexpr std::uint16_t interface_flag_up = 0x0001;
inline constexpr std::uint16_t interface_flag_broadcast = 0x0002;
inline constexpr std::uint16_t interface_flag_loopback = 0x0008;
inline constexpr std::uint16_t interface_flag_point_to_point = 0x0010;
inline constexpr std::uint16_t interface_flag_running = 0x0040;
inline constexpr std::uint16_t interface_flag_output_active = 0x0400;
inline constexpr std::uint16_t interface_flag_simplex = 0x0800;
inline constexpr std::uint16_t interface_flag_all_multicast = 0x0200;
inline constexpr std::uint16_t interface_flag_multicast = 0x8000;
inline constexpr std::uint16_t interface_flags_kernel_managed =
    interface_flag_broadcast | interface_flag_point_to_point |
    interface_flag_running | interface_flag_output_active |
    interface_flag_simplex | interface_flag_all_multicast |
    interface_flag_multicast;

inline constexpr std::uint8_t interface_type_ethernet = 6;
inline constexpr std::uint8_t interface_type_loopback = 24;
inline constexpr std::uint32_t interface_family_loopback = 1;
inline constexpr std::uint32_t interface_family_ethernet = 2;
inline constexpr std::uint32_t default_loopback_mtu = 16'384;
inline constexpr std::uint32_t default_ethernet_mtu = 1'500;

// Darwin 8 encodes the ioctl parameter size in bits 16..28. Matching the
// direction/group/number separately keeps these identities valid for the
// ARM32 structures used by the firmware while documenting their wire layout.
inline constexpr std::uint32_t ioctl_identity_mask = 0xe000ffffU;
inline constexpr std::uint32_t ioctl_get_interface_mtu = 0xc0006933U;
inline constexpr std::uint32_t ioctl_set_interface_mtu = 0x80006934U;
inline constexpr std::uint32_t ioctl_set_interface_media = 0xc0006937U;
inline constexpr std::uint32_t ioctl_get_interface_media = 0xc0006938U;
inline constexpr std::uint32_t ioctl_get_ipv6_address_flags = 0xc0006949U;
inline constexpr std::uint32_t interface_request_value_offset = 16;
inline constexpr std::uint32_t interface_media_current_offset = 16;
inline constexpr std::uint32_t interface_media_mask_offset = 20;
inline constexpr std::uint32_t interface_media_status_offset = 24;
inline constexpr std::uint32_t interface_media_active_offset = 28;
inline constexpr std::uint32_t interface_media_count_offset = 32;
inline constexpr std::uint32_t interface_media_list_offset = 36;
inline constexpr std::uint32_t media_type_mask = 0x000000e0U;
inline constexpr std::uint32_t media_type_ethernet = 0x00000020U;
inline constexpr std::uint32_t media_subtype_auto = 0;
inline constexpr std::uint32_t media_subtype_100_tx = 6;
inline constexpr std::uint32_t media_option_full_duplex = 0x00100000U;
inline constexpr std::uint32_t media_status_valid = 0x00000001U;
inline constexpr std::uint32_t media_status_active = 0x00000002U;

// Darwin 8 AirPortFamily driver requests. Apple80211 passes this 32-byte
// ifreq-derived envelope to a datagram socket; the payload remains guest
// memory and is described by its final length/pointer fields.
namespace apple80211_driver {

    inline constexpr std::string_view event_device_name = "airport";
    inline constexpr std::string_view event_device_path = "/dev/airport";
    inline constexpr std::string_view event_descriptor_kind = "wifi-events";

    inline constexpr std::uint32_t set_request = 0x802069c8U;
    inline constexpr std::uint32_t get_request = 0xc02069c9U;
    inline constexpr std::uint32_t event_scan_completed = 10;
    inline constexpr std::uint32_t event_header_size = 8;
    inline constexpr std::uint32_t event_identifier_offset = 0;
    inline constexpr std::uint32_t event_payload_length_offset = 4;
    inline constexpr std::uint32_t command_offset = 16;
    inline constexpr std::uint32_t data_length_offset = 24;
    inline constexpr std::uint32_t data_address_offset = 28;

    inline constexpr std::uint32_t command_scan = 10;
    inline constexpr std::uint32_t command_scan_result = 11;
    inline constexpr std::uint32_t command_interface_probe = 12;
    // Legacy AirPortFamily clients issue this zero-length capability probe
    // while constructing the Settings network pane.  It has no payload; a
    // successful no-op is the driver contract when the virtual interface is
    // present.
    inline constexpr std::uint32_t command_capability_probe = 15;
    inline constexpr std::uint32_t command_current_ssid = 1;
    inline constexpr std::uint32_t command_channel = 4;
    inline constexpr std::uint32_t command_rate = 8;
    inline constexpr std::uint32_t command_current_bssid = 9;
    inline constexpr std::uint32_t command_state = 13;
    inline constexpr std::uint32_t command_rssi = 16;
    inline constexpr std::uint32_t command_noise = 17;
    inline constexpr std::uint32_t command_power = 19;
    inline constexpr std::uint32_t command_association_result = 21;
    inline constexpr std::uint32_t command_driver_name = 23;
    inline constexpr std::uint32_t command_current_network = 201;
    inline constexpr std::uint32_t inline_scalar_value_offset = 20;
    inline constexpr std::uint32_t association_result_success = 1;

    inline constexpr std::uint32_t current_ssid_size = 32;
    inline constexpr std::uint32_t current_bssid_size = 6;
    inline constexpr std::uint32_t channel_state_size = 16;
    inline constexpr std::uint32_t channel_state_channel_offset = 8;
    inline constexpr std::uint32_t channel_state_flags_offset = 12;
    inline constexpr std::uint32_t signal_state_size = 52;
    inline constexpr std::uint32_t signal_state_count_offset = 4;
    inline constexpr std::uint32_t signal_state_unit_offset = 8;
    inline constexpr std::uint32_t signal_state_control_average_offset = 12;
    inline constexpr std::uint32_t signal_state_extension_average_offset = 28;
    inline constexpr std::uint32_t signal_state_last_offset = 48;
    inline constexpr std::uint32_t power_state_size = 24;
    inline constexpr std::uint32_t power_state_count_offset = 4;
    inline constexpr std::uint32_t power_state_first_value_offset = 8;

    struct NetworkRecordLayout {
        std::uint32_t size { };
        std::uint32_t ie_length_offset { };
        std::uint32_t ie_pointer_offset { };
    };

    // Darwin 9 aligns the final pointer after a 16-bit IE length. Darwin 10's
    // mobile driver removes that padding while preserving selector 201 and all
    // preceding fields.
    inline constexpr NetworkRecordLayout aligned_network_record_layout { 144,
        136, 140 };
    inline constexpr NetworkRecordLayout compact_network_record_layout { 140,
        134, 136 };

    inline constexpr std::uint32_t scan_result_size = 144;
    inline constexpr std::uint32_t scan_channel_offset = 8;
    inline constexpr std::uint32_t scan_channel_flags_offset = 12;
    inline constexpr std::uint32_t scan_noise_offset = 16;
    inline constexpr std::uint32_t scan_rssi_offset = 18;
    inline constexpr std::uint32_t scan_beacon_interval_offset = 20;
    inline constexpr std::uint32_t scan_capabilities_offset = 22;
    inline constexpr std::uint32_t scan_bssid_offset = 24;
    inline constexpr std::uint32_t scan_rate_count_offset = 30;
    inline constexpr std::uint32_t scan_ssid_length_offset = 92;
    inline constexpr std::uint32_t scan_ssid_offset = 93;
    inline constexpr std::uint32_t scan_age_offset = 128;
    inline constexpr std::uint32_t scan_flags_offset = 132;
    inline constexpr std::uint32_t scan_ie_length_offset = 136;
    inline constexpr std::uint32_t scan_ie_pointer_offset = 140;
    inline constexpr std::int32_t scan_signal_floor_dbm = -100;
    inline constexpr std::int32_t scan_signal_ceiling_dbm = 0;

    // Builds the raw AirPortFamily network record consumed by the firmware's
    // own Apple80211-to-CoreFoundation converter. A null access point
    // represents a powered but unassociated interface and still produces a
    // valid empty record.
    [[nodiscard]] std::optional<std::vector<std::byte>> make_network_record(
        const VirtualAccessPoint* access_point, NetworkRecordLayout layout,
        std::uint16_t ie_length, std::uint32_t ie_pointer);

} // namespace apple80211_driver

constexpr std::uint32_t ioctl_identity(std::uint32_t command)
{
    return command & ioctl_identity_mask;
}

inline constexpr std::uint32_t kernel_event_any = 0;
inline constexpr std::uint32_t kernel_event_vendor_apple = 1;
inline constexpr std::uint32_t kernel_event_network_class = 1;
inline constexpr std::uint32_t kernel_event_inet_subclass = 1;
inline constexpr std::uint32_t kernel_event_data_link_subclass = 2;
inline constexpr std::uint32_t kernel_event_inet6_subclass = 6;
inline constexpr std::uint32_t kernel_event_inet_new_address = 1;
inline constexpr std::uint32_t kernel_event_inet_address_changed = 2;
inline constexpr std::uint32_t kernel_event_inet_address_deleted = 3;
inline constexpr std::uint32_t kernel_event_inet6_new_user_address = 1;
inline constexpr std::uint32_t kernel_event_inet6_address_deleted = 3;
inline constexpr std::uint32_t kernel_event_interface_flags_changed = 1;
inline constexpr std::uint32_t kernel_event_link_off = 12;
inline constexpr std::uint32_t kernel_event_link_on = 13;
inline constexpr std::size_t kernel_event_header_size = 24;
inline constexpr std::size_t interface_name_size = 16;
inline constexpr std::size_t maximum_retained_kernel_events = 256;

struct InterfaceSnapshot {
    std::string name;
    std::uint16_t index { };
    std::uint16_t flags { };
    std::uint32_t family { };
    std::uint32_t unit { };
    std::uint32_t mtu { };
    std::uint8_t type { };
    std::array<std::byte, 6> link_address { };
    std::uint8_t link_address_length { };
    std::optional<std::array<std::byte, 16>> ipv4_address;
    std::optional<std::array<std::byte, 16>> ipv4_netmask;
    std::optional<std::array<std::byte, 16>> ipv4_broadcast;
    std::optional<std::array<std::byte, 28>> ipv6_address;
    std::optional<std::array<std::byte, 28>> ipv6_netmask;
};

[[nodiscard]] std::vector<std::byte> make_route_interface_list(
    std::span<const InterfaceSnapshot> interfaces,
    std::uint32_t address_family = address_family_unspecified,
    std::uint32_t interface_index = 0);

[[nodiscard]] std::vector<std::byte> make_network_event_data(
    const InterfaceSnapshot& interface);
[[nodiscard]] std::vector<std::byte> make_ipv4_network_event_data(
    const InterfaceSnapshot& interface);
[[nodiscard]] std::vector<std::byte> make_ipv6_network_event_data(
    const InterfaceSnapshot& interface);

[[nodiscard]] std::vector<std::byte> make_kernel_event(std::uint32_t identifier,
    std::uint32_t vendor, std::uint32_t event_class,
    std::uint32_t event_subclass, std::uint32_t event_code,
    std::span<const std::byte> event_data);

} // namespace shade::darwin::network
