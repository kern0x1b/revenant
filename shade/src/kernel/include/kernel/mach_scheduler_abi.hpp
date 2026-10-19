// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define Mach thread-switch and scheduler policy constants.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/thread_switch.h

#pragma once

#include <cstdint>

namespace shade::darwin::mach::scheduler {

// XNU osfmk/mach/thread_switch.h.
constexpr std::uint32_t swtch_pri_trap = 59;
constexpr std::uint32_t swtch_trap = 60;
constexpr std::uint32_t thread_switch_trap = 61;
constexpr std::uint32_t switch_option_none = 0;
constexpr std::uint32_t switch_option_depress = 1;
constexpr std::uint32_t switch_option_wait = 2;
constexpr std::uint32_t maximum_switch_option = switch_option_wait;

constexpr std::uint64_t nanoseconds_per_millisecond = 1'000'000ULL;

} // namespace shade::darwin::mach::scheduler
