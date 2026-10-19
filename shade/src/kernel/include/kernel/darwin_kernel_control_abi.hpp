// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define Darwin PF_SYSTEM kernel-control socket and ioctl layouts.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/sys/sys_domain.h
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/sys/kern_control.h

#pragma once

#include <cstddef>
#include <cstdint>

namespace shade::darwin::kernel_control {

// XNU bsd/sys/sys_domain.h and bsd/sys/kern_control.h.
inline constexpr std::uint32_t protocol_family_system = 32;
inline constexpr std::uint32_t protocol_event = 1;
inline constexpr std::uint32_t protocol_control = 2;
inline constexpr std::uint16_t system_address_control = 2;

inline constexpr std::uint32_t maximum_name_size = 96;
inline constexpr std::uint32_t control_info_size =
    sizeof(std::uint32_t) + maximum_name_size;
inline constexpr std::uint32_t control_info_identifier_offset = 0;
inline constexpr std::uint32_t control_info_name_offset = 4;

inline constexpr std::uint32_t socket_address_size = 32;
inline constexpr std::uint32_t socket_address_length_offset = 0;
inline constexpr std::uint32_t socket_address_family_offset = 1;
inline constexpr std::uint32_t socket_address_system_offset = 2;
inline constexpr std::uint32_t socket_address_identifier_offset = 4;
inline constexpr std::uint32_t socket_address_unit_offset = 8;
inline constexpr std::uint32_t socket_address_reserved_offset = 12;
inline constexpr std::uint32_t socket_address_reserved_count = 5;

// _IOWR('N', 3, struct ctl_info), where sizeof(ctl_info) == 100 on ARM32.
inline constexpr std::uint32_t ioctl_get_info = 0xc0644e03U;

} // namespace shade::darwin::kernel_control
