// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define ARM32 thread-information flavors and result layouts.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/thread_info.h

#pragma once

#include <cstddef>
#include <cstdint>

namespace shade::darwin::mach::thread_info {

// XNU osfmk/mach/thread_info.h. All fields are natural_t words on
// the 32-bit ARM ABI used by iPhone OS 1.x.
constexpr std::uint32_t basic_flavor = 3;
constexpr std::size_t basic_word_count = 10;

constexpr std::uint32_t sched_timeshare_flavor = 10;
constexpr std::size_t sched_timeshare_word_count = 5;
constexpr std::size_t timeshare_max_priority_index = 0;
constexpr std::size_t timeshare_base_priority_index = 1;
constexpr std::size_t timeshare_current_priority_index = 2;
constexpr std::size_t timeshare_depressed_index = 3;
constexpr std::size_t timeshare_depress_priority_index = 4;

constexpr std::uint32_t standard_policy = 1;
constexpr std::uint32_t waiting_state = 3;

} // namespace shade::darwin::mach::thread_info
