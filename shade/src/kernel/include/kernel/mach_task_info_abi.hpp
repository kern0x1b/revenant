// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define ARM32 task-information flavors and result layouts.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/task_info.h

#pragma once

#include <cstddef>
#include <cstdint>

namespace shade::darwin::mach::task_info {

// XNU osfmk/mach/task_info.h. Fields are natural_t words at the
// 32-bit ARM compatibility boundary.
inline constexpr std::uint32_t absolute_time_flavor = 1;
inline constexpr std::size_t absolute_time_word_count = 8;

inline constexpr std::uint32_t events_flavor = 2;
inline constexpr std::size_t events_word_count = 8;

inline constexpr std::uint32_t thread_times_flavor = 3;
inline constexpr std::size_t thread_times_word_count = 4;

inline constexpr std::uint32_t basic_32_flavor = 4;
inline constexpr std::size_t basic_32_word_count = 8;

inline constexpr std::uint32_t basic_64_flavor = 5;
// The ARM32 task_info wire ABI used by Darwin 9/11 exposes the compact
// eight-word basic_64 record.  The native 64-bit layout has ten words, but
// that variant is not requested by the firmware profiles supported here.
inline constexpr std::size_t basic_64_word_count = 8;

inline constexpr std::uint32_t dyld_info_flavor = 17;
inline constexpr std::size_t dyld_info_word_count = 5;

inline constexpr std::uint32_t timeshare_policy = 1;

} // namespace shade::darwin::mach::task_info
