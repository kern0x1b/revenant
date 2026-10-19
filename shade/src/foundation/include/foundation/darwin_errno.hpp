// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define Darwin error numbers independently of the host operating
// system.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/sys/errno.h

#pragma once

#include <cstdint>

namespace shade::darwin::error {
    inline constexpr std::uint32_t operation_not_permitted = 1;
    inline constexpr std::uint32_t no_entry = 2;
    inline constexpr std::uint32_t no_such_process = 3;
    inline constexpr std::uint32_t io = 5;
    inline constexpr std::uint32_t no_such_device_or_address = 6;
    inline constexpr std::uint32_t argument_list_too_long = 7;
    inline constexpr std::uint32_t bad_file_descriptor = 9;
    inline constexpr std::uint32_t no_child_process = 10;
    inline constexpr std::uint32_t interrupted = 4;
    inline constexpr std::uint32_t no_memory = 12;
    inline constexpr std::uint32_t permission_denied = 13;
    inline constexpr std::uint32_t bad_address = 14;
    inline constexpr std::uint32_t device_busy = 16;
    inline constexpr std::uint32_t file_exists = 17;
    inline constexpr std::uint32_t no_space_on_device = 28;
    inline constexpr std::uint32_t inappropriate_ioctl = 25;
    inline constexpr std::uint32_t illegal_seek = 29;
    inline constexpr std::uint32_t broken_pipe = 32;
    inline constexpr std::uint32_t would_block = 35;
    inline constexpr std::uint32_t operation_in_progress = 36;
    inline constexpr std::uint32_t no_protocol_option = 42;
    inline constexpr std::uint32_t address_in_use = 48;
    inline constexpr std::uint32_t not_directory = 20;
    inline constexpr std::uint32_t is_directory = 21;
    inline constexpr std::uint32_t invalid_argument = 22;
    inline constexpr std::uint32_t result_too_large = 34;
    inline constexpr std::uint32_t value_too_large = 84;
    inline constexpr std::uint32_t protocol_not_supported = 43;
    inline constexpr std::uint32_t not_supported = 45;
    inline constexpr std::uint32_t timed_out = 60;
    inline constexpr std::uint32_t operation_not_supported = 102;
    inline constexpr std::uint32_t address_not_available = 49;
    inline constexpr std::uint32_t network_unreachable = 51;
    inline constexpr std::uint32_t not_connected = 57;
    inline constexpr std::uint32_t connection_refused = 61;
    inline constexpr std::uint32_t no_attribute = 93;
} // namespace shade::darwin::error
