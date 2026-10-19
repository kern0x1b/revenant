// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define guest ARM thread-state flavors and register layouts.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-4903.241.1/osfmk/mach/arm/thread_status.h

#pragma once

#include <array>
#include <cstddef>
#include <cstdint>

namespace shade::darwin::arm_thread {

// The iPhoneOS 1.0 ARM_THREAD_STATE flavor used by libSystem: r0-r15 followed
// by CPSR, matching the 17-natural state accepted by thread_create_running.
inline constexpr std::uint32_t general_state_flavor = 1;
inline constexpr std::size_t general_register_count = 16;
inline constexpr std::size_t cpsr_index = general_register_count;
inline constexpr std::size_t general_state_word_count =
    general_register_count + 1U;

using GeneralState = std::array<std::uint32_t, general_state_word_count>;

} // namespace shade::darwin::arm_thread
