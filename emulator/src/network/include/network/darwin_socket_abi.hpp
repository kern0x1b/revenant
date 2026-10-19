// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define ARM32 socket message, iovec and ancillary-data layouts.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/sys/socket.h
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/sys/uio.h

#pragma once

#include <cstdint>

namespace emulator::darwin::socket {
    inline constexpr std::uint32_t local = 1;
    inline constexpr std::uint32_t stream = 1;
    inline constexpr std::uint32_t datagram = 2;
    inline constexpr std::uint32_t raw = 3;
    inline constexpr std::uint32_t sequenced_packet = 5;

    namespace arm32_message {
        inline constexpr std::uint32_t name_offset = 0;
        inline constexpr std::uint32_t name_length_offset = 4;
        inline constexpr std::uint32_t iov_offset = 8;
        inline constexpr std::uint32_t iov_count_offset = 12;
        inline constexpr std::uint32_t control_offset = 16;
        inline constexpr std::uint32_t control_length_offset = 20;
        inline constexpr std::uint32_t flags_offset = 24;
        inline constexpr std::uint32_t size = 28;
    }

    namespace arm32_iovec {
        inline constexpr std::uint32_t base_offset = 0;
        inline constexpr std::uint32_t length_offset = 4;
        inline constexpr std::uint32_t size = 8;
    }

    inline constexpr std::uint32_t message_control_truncated = 0x20;
    inline constexpr std::uint32_t message_dont_wait = 0x80;

    inline constexpr std::uint32_t option_level = 0xffff;
    inline constexpr std::uint32_t local_option_level = 0;
    inline constexpr std::uint32_t local_peer_credentials = 1;
    inline constexpr std::uint32_t option_accept_connection = 0x0002;
    inline constexpr std::uint32_t option_reuse_address = 0x0004;
    inline constexpr std::uint32_t option_reuse_port = 0x0200;
    inline constexpr std::uint32_t option_error = 0x1007;
    inline constexpr std::uint32_t option_type = 0x1008;
    inline constexpr std::uint32_t option_pending_bytes = 0x1020;
    inline constexpr std::uint32_t option_no_sigpipe = 0x1022;
    inline constexpr std::uint32_t option_defunct_ok = 0x1100;
    inline constexpr std::uint32_t ioctl_pending_bytes = 0x4004667f;
    inline constexpr std::uint32_t ioctl_non_block = 0x8004667e;

    inline constexpr std::uint32_t shutdown_read = 0;
    inline constexpr std::uint32_t shutdown_write = 1;
    inline constexpr std::uint32_t shutdown_read_write = 2;
}
