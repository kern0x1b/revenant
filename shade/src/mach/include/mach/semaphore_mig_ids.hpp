// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define the ARM32 semaphore MIG routine identifiers and
// request/reply argument layouts.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/semaphore.defs

// ARM32 MIG wire contract. Keep message identifiers and argument layouts ABI-stable.
#pragma once

#include <array>
#include <cstdint>
#include <span>
#include <string_view>

#include "mach/xnu_mig_adapter.hpp"

namespace shade::xnu::mig::semaphore {

inline constexpr std::string_view subsystem_name{"semaphore"};
inline constexpr std::uint32_t subsystem_base = 617200U;

enum class Routine : std::uint32_t {
    semaphore_signal = 617200U,
    semaphore_signal_all = 617201U,
    semaphore_wait = 617202U,
    semaphore_signal_thread = 617203U,
    semaphore_timedwait = 617204U,
    semaphore_wait_signal = 617205U,
    semaphore_timedwait_signal = 617206U,
};

inline constexpr std::array<ArgumentInfo, 1> semaphore_signal_arguments{{
    {"semaphore", "semaphore_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 1> semaphore_signal_all_arguments{{
    {"semaphore", "semaphore_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 1> semaphore_wait_arguments{{
    {"semaphore", "semaphore_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> semaphore_signal_thread_arguments{{
    {"semaphore", "semaphore_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"thread", "thread_act_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> semaphore_timedwait_arguments{{
    {"semaphore", "semaphore_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"wait_time", "mach_timespec_t", "", ArgumentDirection::In, WireType::FixedInline, 8U, 0U, 4U, 32U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> semaphore_wait_signal_arguments{{
    {"wait_semaphore", "semaphore_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"signal_semaphore", "semaphore_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> semaphore_timedwait_signal_arguments{{
    {"wait_semaphore", "semaphore_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"signal_semaphore", "semaphore_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"wait_time", "mach_timespec_t", "", ArgumentDirection::In, WireType::FixedInline, 8U, 0U, 4U, 48U, 4294967295U, 4294967295U, 4294967295U},
}};

struct Descriptor {
    Routine routine;
    std::string_view name;
    std::span<const ArgumentInfo> arguments;
};

inline constexpr std::array<Descriptor, 7> routines{{
    {Routine::semaphore_signal, "semaphore_signal", std::span<const ArgumentInfo>{semaphore_signal_arguments}},
    {Routine::semaphore_signal_all, "semaphore_signal_all", std::span<const ArgumentInfo>{semaphore_signal_all_arguments}},
    {Routine::semaphore_wait, "semaphore_wait", std::span<const ArgumentInfo>{semaphore_wait_arguments}},
    {Routine::semaphore_signal_thread, "semaphore_signal_thread", std::span<const ArgumentInfo>{semaphore_signal_thread_arguments}},
    {Routine::semaphore_timedwait, "semaphore_timedwait", std::span<const ArgumentInfo>{semaphore_timedwait_arguments}},
    {Routine::semaphore_wait_signal, "semaphore_wait_signal", std::span<const ArgumentInfo>{semaphore_wait_signal_arguments}},
    {Routine::semaphore_timedwait_signal, "semaphore_timedwait_signal", std::span<const ArgumentInfo>{semaphore_timedwait_signal_arguments}},
}};

constexpr std::uint32_t id(Routine routine) {
    return static_cast<std::uint32_t>(routine);
}

}  // namespace shade::xnu::mig::semaphore
