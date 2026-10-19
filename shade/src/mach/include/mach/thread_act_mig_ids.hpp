// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define the ARM32 thread_act MIG routine identifiers and
// request/reply argument layouts.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/thread_act.defs

// ARM32 MIG wire contract. Keep message identifiers and argument layouts ABI-stable.
#pragma once

#include <array>
#include <cstdint>
#include <span>
#include <string_view>

#include "mach/xnu_mig_adapter.hpp"

namespace shade::xnu::mig::thread_act {

inline constexpr std::string_view subsystem_name{"thread_act"};
inline constexpr std::uint32_t subsystem_base = 3600U;

enum class Routine : std::uint32_t {
    thread_terminate = 3600U,
    act_get_state = 3601U,
    act_set_state = 3602U,
    thread_get_state = 3603U,
    thread_set_state = 3604U,
    thread_suspend = 3605U,
    thread_resume = 3606U,
    thread_abort = 3607U,
    thread_abort_safely = 3608U,
    thread_depress_abort = 3609U,
    thread_get_special_port = 3610U,
    thread_set_special_port = 3611U,
    thread_info = 3612U,
    thread_set_exception_ports = 3613U,
    thread_get_exception_ports = 3614U,
    thread_swap_exception_ports = 3615U,
    thread_policy = 3616U,
    thread_policy_set = 3617U,
    thread_policy_get = 3618U,
    thread_sample = 3619U,
    thread_assign = 3621U,
    thread_assign_default = 3622U,
    thread_get_assignment = 3623U,
    thread_set_policy = 3624U,
};

inline constexpr std::array<ArgumentInfo, 1> thread_terminate_arguments{{
    {"target_act", "thread_act_consume_ref_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> act_get_state_arguments{{
    {"target_act", "thread_act_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"flavor", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"old_state", "thread_state_t, CountInOut", "", ArgumentDirection::Out, WireType::VariableInline, 0U, 0U, 4U, 4294967295U, 40U, 36U, 36U},
}};

inline constexpr std::array<ArgumentInfo, 3> act_set_state_arguments{{
    {"target_act", "thread_act_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"flavor", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"new_state", "thread_state_t", "", ArgumentDirection::In, WireType::VariableInline, 0U, 0U, 4U, 40U, 4294967295U, 36U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> thread_get_state_arguments{{
    {"target_act", "thread_act_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"flavor", "thread_state_flavor_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"old_state", "thread_state_t, CountInOut", "", ArgumentDirection::Out, WireType::VariableInline, 0U, 0U, 4U, 4294967295U, 40U, 36U, 36U},
}};

inline constexpr std::array<ArgumentInfo, 3> thread_set_state_arguments{{
    {"target_act", "thread_act_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"flavor", "thread_state_flavor_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"new_state", "thread_state_t", "", ArgumentDirection::In, WireType::VariableInline, 0U, 0U, 4U, 40U, 4294967295U, 36U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 1> thread_suspend_arguments{{
    {"target_act", "thread_act_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 1> thread_resume_arguments{{
    {"target_act", "thread_act_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 1> thread_abort_arguments{{
    {"target_act", "thread_act_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 1> thread_abort_safely_arguments{{
    {"target_act", "thread_act_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 1> thread_depress_abort_arguments{{
    {"thread", "thread_act_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> thread_get_special_port_arguments{{
    {"thr_act", "thread_act_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"which_port", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"special_port", "mach_port_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> thread_set_special_port_arguments{{
    {"thr_act", "thread_act_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"which_port", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"special_port", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> thread_info_arguments{{
    {"target_act", "thread_act_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"flavor", "thread_flavor_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"thread_info_out", "thread_info_t, CountInOut", "", ArgumentDirection::Out, WireType::VariableInline, 48U, 0U, 4U, 4294967295U, 40U, 36U, 36U},
}};

inline constexpr std::array<ArgumentInfo, 5> thread_set_exception_ports_arguments{{
    {"thread", "thread_act_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"exception_mask", "exception_mask_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"new_port", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"behavior", "exception_behavior_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 52U, 4294967295U, 4294967295U, 4294967295U},
    {"new_flavor", "thread_state_flavor_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 56U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 6> thread_get_exception_ports_arguments{{
    {"thread", "thread_act_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"exception_mask", "exception_mask_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"masks", "exception_mask_array_t", "", ArgumentDirection::Out, WireType::VariableInline, 128U, 0U, 4U, 4294967295U, 40U, 4294967295U, 36U},
    {"old_handlers", "exception_handler_array_t, SameCount", "", ArgumentDirection::Out, WireType::VariableInline, 128U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"old_behaviors", "exception_behavior_array_t, SameCount", "", ArgumentDirection::Out, WireType::VariableInline, 128U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"old_flavors", "exception_flavor_array_t, SameCount", "", ArgumentDirection::Out, WireType::VariableInline, 128U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 9> thread_swap_exception_ports_arguments{{
    {"thread", "thread_act_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"exception_mask", "exception_mask_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"new_port", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"behavior", "exception_behavior_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 52U, 4294967295U, 4294967295U, 4294967295U},
    {"new_flavor", "thread_state_flavor_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 56U, 4294967295U, 4294967295U, 4294967295U},
    {"masks", "exception_mask_array_t", "", ArgumentDirection::Out, WireType::VariableInline, 128U, 0U, 4U, 4294967295U, 40U, 4294967295U, 36U},
    {"old_handlers", "exception_handler_array_t, SameCount", "", ArgumentDirection::Out, WireType::VariableInline, 128U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"old_behaviors", "exception_behavior_array_t, SameCount", "", ArgumentDirection::Out, WireType::VariableInline, 128U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"old_flavors", "exception_flavor_array_t, SameCount", "", ArgumentDirection::Out, WireType::VariableInline, 128U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> thread_policy_arguments{{
    {"thr_act", "thread_act_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"policy", "policy_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"base", "policy_base_t", "", ArgumentDirection::In, WireType::VariableInline, 20U, 0U, 4U, 40U, 4294967295U, 36U, 4294967295U},
    {"set_limit", "boolean_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> thread_policy_set_arguments{{
    {"thread", "thread_act_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"flavor", "thread_policy_flavor_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"policy_info", "thread_policy_t", "", ArgumentDirection::In, WireType::VariableInline, 64U, 0U, 4U, 40U, 4294967295U, 36U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> thread_policy_get_arguments{{
    {"thread", "thread_act_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"flavor", "thread_policy_flavor_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"policy_info", "thread_policy_t, CountInOut", "", ArgumentDirection::Out, WireType::VariableInline, 64U, 0U, 4U, 4294967295U, 40U, 36U, 36U},
    {"get_default", "boolean_t", "", ArgumentDirection::InOut, WireType::Scalar, 4U, 0U, 0U, 40U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> thread_sample_arguments{{
    {"thread", "thread_act_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"reply", "mach_port_make_send_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> thread_assign_arguments{{
    {"thread", "thread_act_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"new_set", "processor_set_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 1> thread_assign_default_arguments{{
    {"thread", "thread_act_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> thread_get_assignment_arguments{{
    {"thread", "thread_act_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"assigned_set", "processor_set_name_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 5> thread_set_policy_arguments{{
    {"thr_act", "thread_act_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"pset", "processor_set_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"policy", "policy_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"base", "policy_base_t", "", ArgumentDirection::In, WireType::VariableInline, 20U, 0U, 4U, 56U, 4294967295U, 52U, 4294967295U},
    {"limit", "policy_limit_t", "", ArgumentDirection::In, WireType::VariableInline, 4U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
}};

struct Descriptor {
    Routine routine;
    std::string_view name;
    std::span<const ArgumentInfo> arguments;
};

inline constexpr std::array<Descriptor, 24> routines{{
    {Routine::thread_terminate, "thread_terminate", std::span<const ArgumentInfo>{thread_terminate_arguments}},
    {Routine::act_get_state, "act_get_state", std::span<const ArgumentInfo>{act_get_state_arguments}},
    {Routine::act_set_state, "act_set_state", std::span<const ArgumentInfo>{act_set_state_arguments}},
    {Routine::thread_get_state, "thread_get_state", std::span<const ArgumentInfo>{thread_get_state_arguments}},
    {Routine::thread_set_state, "thread_set_state", std::span<const ArgumentInfo>{thread_set_state_arguments}},
    {Routine::thread_suspend, "thread_suspend", std::span<const ArgumentInfo>{thread_suspend_arguments}},
    {Routine::thread_resume, "thread_resume", std::span<const ArgumentInfo>{thread_resume_arguments}},
    {Routine::thread_abort, "thread_abort", std::span<const ArgumentInfo>{thread_abort_arguments}},
    {Routine::thread_abort_safely, "thread_abort_safely", std::span<const ArgumentInfo>{thread_abort_safely_arguments}},
    {Routine::thread_depress_abort, "thread_depress_abort", std::span<const ArgumentInfo>{thread_depress_abort_arguments}},
    {Routine::thread_get_special_port, "thread_get_special_port", std::span<const ArgumentInfo>{thread_get_special_port_arguments}},
    {Routine::thread_set_special_port, "thread_set_special_port", std::span<const ArgumentInfo>{thread_set_special_port_arguments}},
    {Routine::thread_info, "thread_info", std::span<const ArgumentInfo>{thread_info_arguments}},
    {Routine::thread_set_exception_ports, "thread_set_exception_ports", std::span<const ArgumentInfo>{thread_set_exception_ports_arguments}},
    {Routine::thread_get_exception_ports, "thread_get_exception_ports", std::span<const ArgumentInfo>{thread_get_exception_ports_arguments}},
    {Routine::thread_swap_exception_ports, "thread_swap_exception_ports", std::span<const ArgumentInfo>{thread_swap_exception_ports_arguments}},
    {Routine::thread_policy, "thread_policy", std::span<const ArgumentInfo>{thread_policy_arguments}},
    {Routine::thread_policy_set, "thread_policy_set", std::span<const ArgumentInfo>{thread_policy_set_arguments}},
    {Routine::thread_policy_get, "thread_policy_get", std::span<const ArgumentInfo>{thread_policy_get_arguments}},
    {Routine::thread_sample, "thread_sample", std::span<const ArgumentInfo>{thread_sample_arguments}},
    {Routine::thread_assign, "thread_assign", std::span<const ArgumentInfo>{thread_assign_arguments}},
    {Routine::thread_assign_default, "thread_assign_default", std::span<const ArgumentInfo>{thread_assign_default_arguments}},
    {Routine::thread_get_assignment, "thread_get_assignment", std::span<const ArgumentInfo>{thread_get_assignment_arguments}},
    {Routine::thread_set_policy, "thread_set_policy", std::span<const ArgumentInfo>{thread_set_policy_arguments}},
}};

constexpr std::uint32_t id(Routine routine) {
    return static_cast<std::uint32_t>(routine);
}

}  // namespace shade::xnu::mig::thread_act
