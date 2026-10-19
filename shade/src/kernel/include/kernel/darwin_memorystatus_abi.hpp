// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// ARM32 memorystatus_control wire values. Darwin ARM aligns uint64_t to
// four bytes, independently of the host structure layout.
// https://github.com/apple-oss-distributions/xnu/blob/xnu-2422.1.72/bsd/sys/kern_memorystatus.h

#pragma once

#include <cstdint>

#include "device_state/darwin_abi.hpp"

namespace shade::darwin::memorystatus {

inline constexpr std::uint32_t syscall_number = 440;
inline constexpr std::uint32_t get_priority_list = 1;
inline constexpr std::uint32_t set_priority_properties = 2;
inline constexpr std::uint32_t maximum_buffer_size = 65536;
inline constexpr std::uint32_t properties_size = 12;
inline constexpr std::uint32_t maximum_property_count = 2;
inline constexpr std::uint32_t priority_entry_size = 24;
inline constexpr std::int32_t default_band = 18;
inline constexpr std::int32_t maximum_priority = 21;
inline constexpr std::int32_t idle_priority = 0;
inline constexpr std::int32_t deferred_idle_priority = 1;

struct ProcessState {
    std::int32_t priority { -100 };
    std::uint64_t user_data { };
};

[[nodiscard]] constexpr ProcessState initial_state(
    DarwinMemoryStatusPriorityAbi abi)
{
    return { abi == DarwinMemoryStatusPriorityAbi::PriorityBands ? default_band
                                                                 : -100,
        0 };
}

} // namespace shade::darwin::memorystatus
