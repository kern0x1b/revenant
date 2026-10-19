// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define guest kqueue filter, event and notification constants.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/sys/event.h

#pragma once

#include <cstdint>

namespace shade::darwin::kqueue {

inline constexpr std::int16_t filter_read = -1;
inline constexpr std::int16_t filter_write = -2;
inline constexpr std::int16_t filter_vnode = -4;
inline constexpr std::int16_t filter_process = -5;
inline constexpr std::int16_t filter_timer = -7;
inline constexpr std::int16_t filter_mach_port = -8;
inline constexpr std::int16_t filter_user = -10;

inline constexpr std::uint16_t event_add = 0x0001;
inline constexpr std::uint16_t event_delete = 0x0002;
inline constexpr std::uint16_t event_enable = 0x0004;
inline constexpr std::uint16_t event_disable = 0x0008;
inline constexpr std::uint16_t event_one_shot = 0x0010;
inline constexpr std::uint16_t event_clear = 0x0020;
inline constexpr std::uint16_t event_receipt = 0x0040;
inline constexpr std::uint16_t event_dispatch = 0x0080;
inline constexpr std::uint16_t event_trigger = 0x0100;
inline constexpr std::uint16_t event_error = 0x4000;
inline constexpr std::uint16_t event_end_of_file = 0x8000;

inline constexpr std::uint32_t process_note_exec = 0x20000000U;
inline constexpr std::uint32_t timer_note_seconds = 0x00000001U;
inline constexpr std::uint32_t timer_note_microseconds = 0x00000002U;
inline constexpr std::uint32_t timer_note_nanoseconds = 0x00000004U;
inline constexpr std::uint32_t timer_note_absolute = 0x00000008U;
inline constexpr std::uint32_t process_note_exit = 0x80000000U;

inline constexpr std::uint32_t vnode_note_delete = 0x00000001U;
inline constexpr std::uint32_t vnode_note_write = 0x00000002U;
inline constexpr std::uint32_t vnode_note_extend = 0x00000004U;
inline constexpr std::uint32_t vnode_note_attrib = 0x00000008U;
inline constexpr std::uint32_t vnode_note_rename = 0x00000020U;

inline constexpr std::uint32_t user_note_trigger = 0x01000000U;
inline constexpr std::uint32_t user_note_ff_and = 0x40000000U;
inline constexpr std::uint32_t user_note_ff_or = 0x80000000U;
inline constexpr std::uint32_t user_note_ff_copy = 0xc0000000U;
inline constexpr std::uint32_t user_note_ff_control_mask = 0xc0000000U;
inline constexpr std::uint32_t user_note_flags_mask = 0x00ffffffU;

namespace arm32_event {
    inline constexpr std::uint32_t identifier_offset = 0;
    inline constexpr std::uint32_t filter_offset = 4;
    inline constexpr std::uint32_t flags_offset = 6;
    inline constexpr std::uint32_t filter_flags_offset = 8;
    inline constexpr std::uint32_t data_offset = 12;
    inline constexpr std::uint32_t user_data_offset = 16;
    inline constexpr std::uint32_t size = 20;
} // namespace arm32_event

namespace arm32_timespec {
    inline constexpr std::uint32_t seconds_offset = 0;
    inline constexpr std::uint32_t nanoseconds_offset = 4;
    inline constexpr std::uint32_t size = 8;
} // namespace arm32_timespec

inline constexpr std::uint64_t nanoseconds_per_second = 1'000'000'000ULL;

} // namespace shade::darwin::kqueue
