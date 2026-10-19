// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define the ARM32 clock_reply MIG routine identifiers and
// request/reply argument layouts.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/clock_reply.defs

// ARM32 MIG wire contract. Keep message identifiers and argument layouts ABI-stable.
#pragma once

#include <array>
#include <cstdint>
#include <span>
#include <string_view>

#include "mach/xnu_mig_adapter.hpp"

namespace shade::xnu::mig::clock_reply {

inline constexpr std::string_view subsystem_name{"clock_reply"};
inline constexpr std::uint32_t subsystem_base = 3125107U;

enum class Routine : std::uint32_t {
    clock_alarm_reply = 3125107U,
};

inline constexpr std::array<ArgumentInfo, 4> clock_alarm_reply_arguments{{
    {"alarm_port", "clock_reply_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"alarm_code", "kern_return_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"alarm_type", "alarm_type_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
    {"alarm_time", "mach_timespec_t", "", ArgumentDirection::In, WireType::FixedInline, 8U, 0U, 4U, 40U, 4294967295U, 4294967295U, 4294967295U},
}};

struct Descriptor {
    Routine routine;
    std::string_view name;
    std::span<const ArgumentInfo> arguments;
};

inline constexpr std::array<Descriptor, 1> routines{{
    {Routine::clock_alarm_reply, "clock_alarm_reply", std::span<const ArgumentInfo>{clock_alarm_reply_arguments}},
}};

constexpr std::uint32_t id(Routine routine) {
    return static_cast<std::uint32_t>(routine);
}

}  // namespace shade::xnu::mig::clock_reply
