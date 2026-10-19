// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define the ARM32 task MIG routine identifiers and request/reply
// argument layouts.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/task.defs

// ARM32 MIG wire contract. Keep message identifiers and argument layouts ABI-stable.
#pragma once

#include <array>
#include <cstdint>
#include <span>
#include <string_view>

#include "mach/xnu_mig_adapter.hpp"

namespace shade::xnu::mig::task {

inline constexpr std::string_view subsystem_name{"task"};
inline constexpr std::uint32_t subsystem_base = 3400U;

enum class Routine : std::uint32_t {
    task_create = 3400U,
    task_terminate = 3401U,
    task_threads = 3402U,
    mach_ports_register = 3403U,
    mach_ports_lookup = 3404U,
    task_info = 3405U,
    task_set_info = 3406U,
    task_suspend = 3407U,
    task_resume = 3408U,
    task_get_special_port = 3409U,
    task_set_special_port = 3410U,
    thread_create = 3411U,
    thread_create_running = 3412U,
    task_set_exception_ports = 3413U,
    task_get_exception_ports = 3414U,
    task_swap_exception_ports = 3415U,
    lock_set_create = 3416U,
    lock_set_destroy = 3417U,
    semaphore_create = 3418U,
    semaphore_destroy = 3419U,
    task_policy_set = 3420U,
    task_policy_get = 3421U,
    task_sample = 3422U,
    task_policy = 3423U,
    task_set_emulation = 3424U,
    task_get_emulation_vector = 3425U,
    task_set_emulation_vector = 3426U,
    task_set_ras_pc = 3427U,
    task_assign = 3429U,
    task_assign_default = 3430U,
    task_get_assignment = 3431U,
    task_set_policy = 3432U,
};

inline constexpr std::array<ArgumentInfo, 4> task_create_arguments{{
    {"target_task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"ledgers", "ledger_array_t", "", ArgumentDirection::In, WireType::OutOfLinePorts, 0U, 0U, 4U, 28U, 4294967295U, 48U, 4294967295U},
    {"inherit_memory", "boolean_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 52U, 4294967295U, 4294967295U, 4294967295U},
    {"child_task", "task_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 1> task_terminate_arguments{{
    {"target_task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> task_threads_arguments{{
    {"target_task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"act_list", "thread_act_array_t", "", ArgumentDirection::Out, WireType::OutOfLinePorts, 0U, 0U, 4U, 4294967295U, 28U, 4294967295U, 48U},
}};

inline constexpr std::array<ArgumentInfo, 2> mach_ports_register_arguments{{
    {"target_task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"init_port_set", "mach_port_array_t = ^array[] of mach_port_t", "", ArgumentDirection::In, WireType::OutOfLinePorts, 0U, 0U, 4U, 28U, 4294967295U, 48U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> mach_ports_lookup_arguments{{
    {"target_task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"init_port_set", "mach_port_array_t = ^array[] of mach_port_t", "", ArgumentDirection::Out, WireType::OutOfLinePorts, 0U, 0U, 4U, 4294967295U, 28U, 4294967295U, 48U},
}};

inline constexpr std::array<ArgumentInfo, 3> task_info_arguments{{
    {"target_task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"flavor", "task_flavor_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"task_info_out", "task_info_t, CountInOut", "", ArgumentDirection::Out, WireType::VariableInline, 40U, 0U, 4U, 4294967295U, 40U, 36U, 36U},
}};

inline constexpr std::array<ArgumentInfo, 3> task_set_info_arguments{{
    {"target_task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"flavor", "task_flavor_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"task_info_in", "task_info_t", "", ArgumentDirection::In, WireType::VariableInline, 40U, 0U, 4U, 40U, 4294967295U, 36U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 1> task_suspend_arguments{{
    {"target_task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 1> task_resume_arguments{{
    {"target_task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> task_get_special_port_arguments{{
    {"task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"which_port", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"special_port", "mach_port_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> task_set_special_port_arguments{{
    {"task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"which_port", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"special_port", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> thread_create_arguments{{
    {"parent_task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"child_act", "thread_act_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> thread_create_running_arguments{{
    {"parent_task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"flavor", "thread_state_flavor_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"new_state", "thread_state_t", "", ArgumentDirection::In, WireType::VariableInline, 0U, 0U, 4U, 40U, 4294967295U, 36U, 4294967295U},
    {"child_act", "thread_act_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 5> task_set_exception_ports_arguments{{
    {"task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"exception_mask", "exception_mask_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"new_port", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"behavior", "exception_behavior_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 52U, 4294967295U, 4294967295U, 4294967295U},
    {"new_flavor", "thread_state_flavor_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 56U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 6> task_get_exception_ports_arguments{{
    {"task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"exception_mask", "exception_mask_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"masks", "exception_mask_array_t", "", ArgumentDirection::Out, WireType::VariableInline, 128U, 0U, 4U, 4294967295U, 40U, 4294967295U, 36U},
    {"old_handlers", "exception_handler_array_t, SameCount", "", ArgumentDirection::Out, WireType::VariableInline, 128U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"old_behaviors", "exception_behavior_array_t, SameCount", "", ArgumentDirection::Out, WireType::VariableInline, 128U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"old_flavors", "exception_flavor_array_t, SameCount", "", ArgumentDirection::Out, WireType::VariableInline, 128U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 9> task_swap_exception_ports_arguments{{
    {"task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"exception_mask", "exception_mask_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"new_port", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"behavior", "exception_behavior_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 52U, 4294967295U, 4294967295U, 4294967295U},
    {"new_flavor", "thread_state_flavor_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 56U, 4294967295U, 4294967295U, 4294967295U},
    {"masks", "exception_mask_array_t", "", ArgumentDirection::Out, WireType::VariableInline, 128U, 0U, 4U, 4294967295U, 40U, 4294967295U, 36U},
    {"old_handlerss", "exception_handler_array_t, SameCount", "", ArgumentDirection::Out, WireType::VariableInline, 128U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"old_behaviors", "exception_behavior_array_t, SameCount", "", ArgumentDirection::Out, WireType::VariableInline, 128U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"old_flavors", "exception_flavor_array_t, SameCount", "", ArgumentDirection::Out, WireType::VariableInline, 128U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> lock_set_create_arguments{{
    {"task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"new_lock_set", "lock_set_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
    {"n_ulocks", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"policy", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> lock_set_destroy_arguments{{
    {"task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"lock_set", "lock_set_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> semaphore_create_arguments{{
    {"task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"semaphore", "semaphore_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
    {"policy", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"value", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> semaphore_destroy_arguments{{
    {"task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"semaphore", "semaphore_consume_ref_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> task_policy_set_arguments{{
    {"task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"flavor", "task_policy_flavor_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"policy_info", "task_policy_t", "", ArgumentDirection::In, WireType::VariableInline, 64U, 0U, 4U, 40U, 4294967295U, 36U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> task_policy_get_arguments{{
    {"task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"flavor", "task_policy_flavor_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"policy_info", "task_policy_t, CountInOut", "", ArgumentDirection::Out, WireType::VariableInline, 64U, 0U, 4U, 4294967295U, 40U, 36U, 36U},
    {"get_default", "boolean_t", "", ArgumentDirection::InOut, WireType::Scalar, 4U, 0U, 0U, 40U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> task_sample_arguments{{
    {"task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"reply", "mach_port_make_send_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 5> task_policy_arguments{{
    {"task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"policy", "policy_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"base", "policy_base_t", "", ArgumentDirection::In, WireType::VariableInline, 20U, 0U, 4U, 40U, 4294967295U, 36U, 4294967295U},
    {"set_limit", "boolean_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"change", "boolean_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> task_set_emulation_arguments{{
    {"target_port", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"routine_entry_pt", "vm_address_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"routine_number", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> task_get_emulation_vector_arguments{{
    {"task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"vector_start", "int", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 48U, 4294967295U, 4294967295U},
    {"emulation_vector", "emulation_vector_t", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 4U, 4294967295U, 28U, 4294967295U, 52U},
}};

inline constexpr std::array<ArgumentInfo, 3> task_set_emulation_vector_arguments{{
    {"task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"vector_start", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"emulation_vector", "emulation_vector_t", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 4U, 28U, 4294967295U, 52U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> task_set_ras_pc_arguments{{
    {"target_task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"basepc", "vm_address_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"boundspc", "vm_address_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> task_assign_arguments{{
    {"task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"new_set", "processor_set_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"assign_threads", "boolean_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> task_assign_default_arguments{{
    {"task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"assign_threads", "boolean_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> task_get_assignment_arguments{{
    {"task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"assigned_set", "processor_set_name_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 6> task_set_policy_arguments{{
    {"task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"pset", "processor_set_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"policy", "policy_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"base", "policy_base_t", "", ArgumentDirection::In, WireType::VariableInline, 20U, 0U, 4U, 56U, 4294967295U, 52U, 4294967295U},
    {"limit", "policy_limit_t", "", ArgumentDirection::In, WireType::VariableInline, 4U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"change", "boolean_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
}};

struct Descriptor {
    Routine routine;
    std::string_view name;
    std::span<const ArgumentInfo> arguments;
};

inline constexpr std::array<Descriptor, 32> routines{{
    {Routine::task_create, "task_create", std::span<const ArgumentInfo>{task_create_arguments}},
    {Routine::task_terminate, "task_terminate", std::span<const ArgumentInfo>{task_terminate_arguments}},
    {Routine::task_threads, "task_threads", std::span<const ArgumentInfo>{task_threads_arguments}},
    {Routine::mach_ports_register, "mach_ports_register", std::span<const ArgumentInfo>{mach_ports_register_arguments}},
    {Routine::mach_ports_lookup, "mach_ports_lookup", std::span<const ArgumentInfo>{mach_ports_lookup_arguments}},
    {Routine::task_info, "task_info", std::span<const ArgumentInfo>{task_info_arguments}},
    {Routine::task_set_info, "task_set_info", std::span<const ArgumentInfo>{task_set_info_arguments}},
    {Routine::task_suspend, "task_suspend", std::span<const ArgumentInfo>{task_suspend_arguments}},
    {Routine::task_resume, "task_resume", std::span<const ArgumentInfo>{task_resume_arguments}},
    {Routine::task_get_special_port, "task_get_special_port", std::span<const ArgumentInfo>{task_get_special_port_arguments}},
    {Routine::task_set_special_port, "task_set_special_port", std::span<const ArgumentInfo>{task_set_special_port_arguments}},
    {Routine::thread_create, "thread_create", std::span<const ArgumentInfo>{thread_create_arguments}},
    {Routine::thread_create_running, "thread_create_running", std::span<const ArgumentInfo>{thread_create_running_arguments}},
    {Routine::task_set_exception_ports, "task_set_exception_ports", std::span<const ArgumentInfo>{task_set_exception_ports_arguments}},
    {Routine::task_get_exception_ports, "task_get_exception_ports", std::span<const ArgumentInfo>{task_get_exception_ports_arguments}},
    {Routine::task_swap_exception_ports, "task_swap_exception_ports", std::span<const ArgumentInfo>{task_swap_exception_ports_arguments}},
    {Routine::lock_set_create, "lock_set_create", std::span<const ArgumentInfo>{lock_set_create_arguments}},
    {Routine::lock_set_destroy, "lock_set_destroy", std::span<const ArgumentInfo>{lock_set_destroy_arguments}},
    {Routine::semaphore_create, "semaphore_create", std::span<const ArgumentInfo>{semaphore_create_arguments}},
    {Routine::semaphore_destroy, "semaphore_destroy", std::span<const ArgumentInfo>{semaphore_destroy_arguments}},
    {Routine::task_policy_set, "task_policy_set", std::span<const ArgumentInfo>{task_policy_set_arguments}},
    {Routine::task_policy_get, "task_policy_get", std::span<const ArgumentInfo>{task_policy_get_arguments}},
    {Routine::task_sample, "task_sample", std::span<const ArgumentInfo>{task_sample_arguments}},
    {Routine::task_policy, "task_policy", std::span<const ArgumentInfo>{task_policy_arguments}},
    {Routine::task_set_emulation, "task_set_emulation", std::span<const ArgumentInfo>{task_set_emulation_arguments}},
    {Routine::task_get_emulation_vector, "task_get_emulation_vector", std::span<const ArgumentInfo>{task_get_emulation_vector_arguments}},
    {Routine::task_set_emulation_vector, "task_set_emulation_vector", std::span<const ArgumentInfo>{task_set_emulation_vector_arguments}},
    {Routine::task_set_ras_pc, "task_set_ras_pc", std::span<const ArgumentInfo>{task_set_ras_pc_arguments}},
    {Routine::task_assign, "task_assign", std::span<const ArgumentInfo>{task_assign_arguments}},
    {Routine::task_assign_default, "task_assign_default", std::span<const ArgumentInfo>{task_assign_default_arguments}},
    {Routine::task_get_assignment, "task_get_assignment", std::span<const ArgumentInfo>{task_get_assignment_arguments}},
    {Routine::task_set_policy, "task_set_policy", std::span<const ArgumentInfo>{task_set_policy_arguments}},
}};

constexpr std::uint32_t id(Routine routine) {
    return static_cast<std::uint32_t>(routine);
}

}  // namespace shade::xnu::mig::task
