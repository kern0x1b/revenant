// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define guest process-information selectors and ARM32 result
// layouts.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-1228.15.4/bsd/sys/proc_info.h

#pragma once

#include <cstdint>

namespace emulator::darwin::proc_info {

inline constexpr std::uint32_t syscall_number = 336U;

inline constexpr std::uint32_t call_pid_info = 2U;
inline constexpr std::uint32_t flavor_pid_path_info = 11U;
inline constexpr std::uint32_t flavor_pid_short_bsd_info = 13U;
inline constexpr std::uint32_t flavor_pid_unique_identifier_info = 17U;
inline constexpr std::uint32_t flavor_pid_bsd_info_with_identity = 18U;
inline constexpr std::uint32_t short_bsd_info_size = 64U;
inline constexpr std::uint32_t unique_identifier_info_size = 56U;
inline constexpr std::uint32_t bsd_info_size = 136U;
inline constexpr std::uint32_t flag_importance_donor = 0x00400000U;

inline constexpr std::uint32_t path_info_size = 1024U;
inline constexpr std::uint32_t path_info_max_size = 4U * path_info_size;

}
