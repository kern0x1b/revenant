// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define the ARM32 processor_set MIG routine identifiers and
// request/reply argument layouts.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/processor_set.defs

// ARM32 MIG wire contract. Keep message identifiers and argument layouts ABI-stable.
#pragma once

#include <array>
#include <cstdint>
#include <span>
#include <string_view>

#include "mach/xnu_mig_adapter.hpp"

namespace shade::xnu::mig::processor_set {

inline constexpr std::string_view subsystem_name{"processor_set"};
inline constexpr std::uint32_t subsystem_base = 4000U;

enum class Routine : std::uint32_t {
    processor_set_statistics = 4000U,
    processor_set_destroy = 4001U,
    processor_set_max_priority = 4002U,
    processor_set_policy_enable = 4003U,
    processor_set_policy_disable = 4004U,
    processor_set_tasks = 4005U,
    processor_set_threads = 4006U,
    processor_set_policy_control = 4007U,
    processor_set_stack_usage = 4008U,
    processor_set_info = 4009U,
};

inline constexpr std::array<ArgumentInfo, 3> processor_set_statistics_arguments{{
    {"pset", "processor_set_name_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"flavor", "processor_set_flavor_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"info_out", "processor_set_info_t, CountInOut", "", ArgumentDirection::Out, WireType::VariableInline, 20U, 0U, 4U, 4294967295U, 40U, 36U, 36U},
}};

inline constexpr std::array<ArgumentInfo, 1> processor_set_destroy_arguments{{
    {"set", "processor_set_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> processor_set_max_priority_arguments{{
    {"processor_set", "processor_set_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"max_priority", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"change_threads", "boolean_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> processor_set_policy_enable_arguments{{
    {"processor_set", "processor_set_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"policy", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> processor_set_policy_disable_arguments{{
    {"processor_set", "processor_set_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"policy", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"change_threads", "boolean_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> processor_set_tasks_arguments{{
    {"processor_set", "processor_set_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"task_list", "task_array_t", "", ArgumentDirection::Out, WireType::OutOfLinePorts, 0U, 0U, 4U, 4294967295U, 28U, 4294967295U, 48U},
}};

inline constexpr std::array<ArgumentInfo, 2> processor_set_threads_arguments{{
    {"processor_set", "processor_set_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"thread_list", "thread_act_array_t", "", ArgumentDirection::Out, WireType::OutOfLinePorts, 0U, 0U, 4U, 4294967295U, 28U, 4294967295U, 48U},
}};

inline constexpr std::array<ArgumentInfo, 4> processor_set_policy_control_arguments{{
    {"pset", "processor_set_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"flavor", "processor_set_flavor_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"policy_info", "processor_set_info_t", "", ArgumentDirection::In, WireType::VariableInline, 20U, 0U, 4U, 40U, 4294967295U, 36U, 4294967295U},
    {"change", "boolean_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 6> processor_set_stack_usage_arguments{{
    {"pset", "processor_set_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"total", "unsigned", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
    {"space", "vm_size_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 40U, 4294967295U, 4294967295U},
    {"resident", "vm_size_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 44U, 4294967295U, 4294967295U},
    {"maxusage", "vm_size_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 48U, 4294967295U, 4294967295U},
    {"maxstack", "vm_offset_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 52U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> processor_set_info_arguments{{
    {"set_name", "processor_set_name_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"flavor", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"host", "host_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
    {"info_out", "processor_set_info_t, CountInOut", "", ArgumentDirection::Out, WireType::VariableInline, 20U, 0U, 4U, 4294967295U, 52U, 36U, 48U},
}};

struct Descriptor {
    Routine routine;
    std::string_view name;
    std::span<const ArgumentInfo> arguments;
};

inline constexpr std::array<Descriptor, 10> routines{{
    {Routine::processor_set_statistics, "processor_set_statistics", std::span<const ArgumentInfo>{processor_set_statistics_arguments}},
    {Routine::processor_set_destroy, "processor_set_destroy", std::span<const ArgumentInfo>{processor_set_destroy_arguments}},
    {Routine::processor_set_max_priority, "processor_set_max_priority", std::span<const ArgumentInfo>{processor_set_max_priority_arguments}},
    {Routine::processor_set_policy_enable, "processor_set_policy_enable", std::span<const ArgumentInfo>{processor_set_policy_enable_arguments}},
    {Routine::processor_set_policy_disable, "processor_set_policy_disable", std::span<const ArgumentInfo>{processor_set_policy_disable_arguments}},
    {Routine::processor_set_tasks, "processor_set_tasks", std::span<const ArgumentInfo>{processor_set_tasks_arguments}},
    {Routine::processor_set_threads, "processor_set_threads", std::span<const ArgumentInfo>{processor_set_threads_arguments}},
    {Routine::processor_set_policy_control, "processor_set_policy_control", std::span<const ArgumentInfo>{processor_set_policy_control_arguments}},
    {Routine::processor_set_stack_usage, "processor_set_stack_usage", std::span<const ArgumentInfo>{processor_set_stack_usage_arguments}},
    {Routine::processor_set_info, "processor_set_info", std::span<const ArgumentInfo>{processor_set_info_arguments}},
}};

constexpr std::uint32_t id(Routine routine) {
    return static_cast<std::uint32_t>(routine);
}

}  // namespace shade::xnu::mig::processor_set
