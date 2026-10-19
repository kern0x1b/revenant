// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define guest host-information and virtual-memory statistics
// layouts.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/host_info.h
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/vm_statistics.h

#pragma once

#include <cstddef>
#include <cstdint>

namespace shade::darwin::mach::xnu {

// Keep the audited routine and data constants together so host dispatch does
// not infer a wire layout from a caller-provided count.
namespace routine {
    inline constexpr std::uint32_t host_info = 200;
    inline constexpr std::uint32_t host_page_size = 202;
    inline constexpr std::uint32_t host_statistics = 216;
} // namespace routine

namespace message {
    inline constexpr std::uint32_t flavor_offset = 32;
    inline constexpr std::uint32_t count_inout_request_offset = 36;
    inline constexpr std::uint32_t count_inout_reply_offset = 36;
    inline constexpr std::uint32_t inline_data_reply_offset = 40;
} // namespace message

namespace host_info {
    inline constexpr std::uint32_t basic_flavor = 1;
    inline constexpr std::uint32_t priority_flavor = 5;
    inline constexpr std::size_t basic_old_word_count = 5;
    inline constexpr std::size_t basic_word_count = 12;
    inline constexpr std::size_t priority_word_count = 8;
} // namespace host_info

namespace host_statistics {
    inline constexpr std::uint32_t load_flavor = 1;
    inline constexpr std::uint32_t vm_flavor = 2;
    inline constexpr std::uint32_t cpu_load_flavor = 3;
    inline constexpr std::size_t load_word_count = 6;
    inline constexpr std::size_t vm_rev0_word_count = 12;
    inline constexpr std::size_t vm_rev1_word_count = 14;
    inline constexpr std::size_t vm_rev2_word_count = 15;
    inline constexpr std::size_t cpu_load_word_count = 4;
} // namespace host_statistics

} // namespace shade::darwin::mach::xnu
