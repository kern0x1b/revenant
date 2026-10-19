// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define the ARM32 host_priv MIG routine identifiers and
// request/reply argument layouts.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/host_priv.defs

// ARM32 MIG wire contract. Keep message identifiers and argument layouts ABI-stable.
#pragma once

#include <array>
#include <cstdint>
#include <span>
#include <string_view>

#include "mach/xnu_mig_adapter.hpp"

namespace shade::xnu::mig::host_priv {

inline constexpr std::string_view subsystem_name{"host_priv"};
inline constexpr std::uint32_t subsystem_base = 400U;

enum class Routine : std::uint32_t {
    host_get_boot_info = 400U,
    host_reboot = 401U,
    host_priv_statistics = 402U,
    host_default_memory_manager = 403U,
    vm_wire = 404U,
    thread_wire = 405U,
    vm_allocate_cpm = 406U,
    host_processors = 407U,
    host_get_clock_control = 408U,
    kmod_create = 409U,
    kmod_destroy = 410U,
    kmod_control = 411U,
    host_get_special_port = 412U,
    host_set_special_port = 413U,
    host_set_exception_ports = 414U,
    host_get_exception_ports = 415U,
    host_swap_exception_ports = 416U,
    host_load_symbol_table = 417U,
    mach_vm_wire = 418U,
    host_processor_sets = 419U,
    host_processor_set_priv = 420U,
    set_dp_control_port = 421U,
    get_dp_control_port = 422U,
    host_set_UNDServer = 423U,
    host_get_UNDServer = 424U,
};

inline constexpr std::array<ArgumentInfo, 2> host_get_boot_info_arguments{{
    {"host_priv", "host_priv_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"boot_info", "kernel_boot_info_t", "", ArgumentDirection::Out, WireType::VariableInline, 4096U, 4U, 1U, 4294967295U, 44U, 4294967295U, 40U},
}};

inline constexpr std::array<ArgumentInfo, 2> host_reboot_arguments{{
    {"host_priv", "host_priv_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"options", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> host_priv_statistics_arguments{{
    {"host_priv", "host_priv_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"flavor", "host_flavor_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"host_info_out", "host_info_t, CountInOut", "", ArgumentDirection::Out, WireType::VariableInline, 56U, 0U, 4U, 4294967295U, 40U, 36U, 36U},
}};

inline constexpr std::array<ArgumentInfo, 3> host_default_memory_manager_arguments{{
    {"host_priv", "host_priv_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"default_manager", "memory_object_default_t = MACH_MSG_TYPE_MAKE_SEND", "", ArgumentDirection::InOut, WireType::Port, 4U, 0U, 0U, 28U, 28U, 4294967295U, 4294967295U},
    {"cluster_size", "vm_size_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 5> vm_wire_arguments{{
    {"host_priv", "host_priv_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"task", "vm_map_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"address", "vm_address_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"size", "vm_size_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 52U, 4294967295U, 4294967295U, 4294967295U},
    {"desired_access", "vm_prot_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 56U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> thread_wire_arguments{{
    {"host_priv", "host_priv_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"thread", "thread_act_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"wired", "boolean_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 5> vm_allocate_cpm_arguments{{
    {"host_priv", "host_priv_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"task", "vm_map_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"address", "vm_address_t", "", ArgumentDirection::InOut, WireType::Scalar, 4U, 0U, 0U, 48U, 36U, 4294967295U, 4294967295U},
    {"size", "vm_size_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 52U, 4294967295U, 4294967295U, 4294967295U},
    {"anywhere", "boolean_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 56U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> host_processors_arguments{{
    {"host_priv", "host_priv_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"out_processor_list", "processor_array_t", "", ArgumentDirection::Out, WireType::OutOfLinePorts, 0U, 0U, 4U, 4294967295U, 28U, 4294967295U, 48U},
}};

inline constexpr std::array<ArgumentInfo, 3> host_get_clock_control_arguments{{
    {"host_priv", "host_priv_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"clock_id", "clock_id_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"clock_ctrl", "clock_ctrl_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> kmod_create_arguments{{
    {"host_priv", "host_priv_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"info", "vm_address_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"module", "kmod_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> kmod_destroy_arguments{{
    {"host_priv", "host_priv_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"module", "kmod_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> kmod_control_arguments{{
    {"host_priv", "host_priv_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"module", "kmod_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"flavor", "kmod_control_flavor_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 52U, 4294967295U, 4294967295U, 4294967295U},
    {"data", "kmod_args_t", "", ArgumentDirection::InOut, WireType::OutOfLine, 0U, 0U, 1U, 28U, 28U, 56U, 48U},
}};

inline constexpr std::array<ArgumentInfo, 4> host_get_special_port_arguments{{
    {"host_priv", "host_priv_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"node", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"which", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
    {"port", "mach_port_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> host_set_special_port_arguments{{
    {"host_priv", "host_priv_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"which", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"port", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 5> host_set_exception_ports_arguments{{
    {"host_priv", "host_priv_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"exception_mask", "exception_mask_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"new_port", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"behavior", "exception_behavior_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 52U, 4294967295U, 4294967295U, 4294967295U},
    {"new_flavor", "thread_state_flavor_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 56U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 6> host_get_exception_ports_arguments{{
    {"host_priv", "host_priv_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"exception_mask", "exception_mask_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"masks", "exception_mask_array_t", "", ArgumentDirection::Out, WireType::VariableInline, 128U, 0U, 4U, 4294967295U, 40U, 4294967295U, 36U},
    {"old_handlers", "exception_handler_array_t, SameCount", "", ArgumentDirection::Out, WireType::VariableInline, 128U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"old_behaviors", "exception_behavior_array_t, SameCount", "", ArgumentDirection::Out, WireType::VariableInline, 128U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"old_flavors", "exception_flavor_array_t, SameCount", "", ArgumentDirection::Out, WireType::VariableInline, 128U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 9> host_swap_exception_ports_arguments{{
    {"host_priv", "host_priv_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"exception_mask", "exception_mask_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"new_port", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"behavior", "exception_behavior_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 52U, 4294967295U, 4294967295U, 4294967295U},
    {"new_flavor", "thread_state_flavor_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 56U, 4294967295U, 4294967295U, 4294967295U},
    {"masks", "exception_mask_array_t", "", ArgumentDirection::Out, WireType::VariableInline, 128U, 0U, 4U, 4294967295U, 40U, 4294967295U, 36U},
    {"old_handlerss", "exception_handler_array_t, SameCount", "", ArgumentDirection::Out, WireType::VariableInline, 128U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"old_behaviors", "exception_behavior_array_t, SameCount", "", ArgumentDirection::Out, WireType::VariableInline, 128U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"old_flavors", "exception_flavor_array_t, SameCount", "", ArgumentDirection::Out, WireType::VariableInline, 128U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> host_load_symbol_table_arguments{{
    {"host", "host_priv_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"name", "symtab_name_t", "", ArgumentDirection::In, WireType::VariableInline, 32U, 4U, 1U, 68U, 4294967295U, 64U, 4294967295U},
    {"symtab", "pointer_t", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 40U, 4294967295U, 100U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 5> mach_vm_wire_arguments{{
    {"host_priv", "host_priv_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"task", "vm_map_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"address", "mach_vm_address_t", "", ArgumentDirection::In, WireType::Scalar, 8U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"size", "mach_vm_size_t", "", ArgumentDirection::In, WireType::Scalar, 8U, 0U, 0U, 56U, 4294967295U, 4294967295U, 4294967295U},
    {"desired_access", "vm_prot_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 64U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> host_processor_sets_arguments{{
    {"host_priv", "host_priv_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"processor_sets", "processor_set_name_array_t", "", ArgumentDirection::Out, WireType::OutOfLinePorts, 0U, 0U, 4U, 4294967295U, 28U, 4294967295U, 48U},
}};

inline constexpr std::array<ArgumentInfo, 3> host_processor_set_priv_arguments{{
    {"host_priv", "host_priv_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"set_name", "processor_set_name_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"set", "processor_set_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> set_dp_control_port_arguments{{
    {"host", "host_priv_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"control_port", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> get_dp_control_port_arguments{{
    {"host", "host_priv_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"contorl_port", "mach_port_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> host_set_UNDServer_arguments{{
    {"host", "host_priv_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"server", "UNDServerRef", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> host_get_UNDServer_arguments{{
    {"host", "host_priv_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"server", "UNDServerRef", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

struct Descriptor {
    Routine routine;
    std::string_view name;
    std::span<const ArgumentInfo> arguments;
};

inline constexpr std::array<Descriptor, 25> routines{{
    {Routine::host_get_boot_info, "host_get_boot_info", std::span<const ArgumentInfo>{host_get_boot_info_arguments}},
    {Routine::host_reboot, "host_reboot", std::span<const ArgumentInfo>{host_reboot_arguments}},
    {Routine::host_priv_statistics, "host_priv_statistics", std::span<const ArgumentInfo>{host_priv_statistics_arguments}},
    {Routine::host_default_memory_manager, "host_default_memory_manager", std::span<const ArgumentInfo>{host_default_memory_manager_arguments}},
    {Routine::vm_wire, "vm_wire", std::span<const ArgumentInfo>{vm_wire_arguments}},
    {Routine::thread_wire, "thread_wire", std::span<const ArgumentInfo>{thread_wire_arguments}},
    {Routine::vm_allocate_cpm, "vm_allocate_cpm", std::span<const ArgumentInfo>{vm_allocate_cpm_arguments}},
    {Routine::host_processors, "host_processors", std::span<const ArgumentInfo>{host_processors_arguments}},
    {Routine::host_get_clock_control, "host_get_clock_control", std::span<const ArgumentInfo>{host_get_clock_control_arguments}},
    {Routine::kmod_create, "kmod_create", std::span<const ArgumentInfo>{kmod_create_arguments}},
    {Routine::kmod_destroy, "kmod_destroy", std::span<const ArgumentInfo>{kmod_destroy_arguments}},
    {Routine::kmod_control, "kmod_control", std::span<const ArgumentInfo>{kmod_control_arguments}},
    {Routine::host_get_special_port, "host_get_special_port", std::span<const ArgumentInfo>{host_get_special_port_arguments}},
    {Routine::host_set_special_port, "host_set_special_port", std::span<const ArgumentInfo>{host_set_special_port_arguments}},
    {Routine::host_set_exception_ports, "host_set_exception_ports", std::span<const ArgumentInfo>{host_set_exception_ports_arguments}},
    {Routine::host_get_exception_ports, "host_get_exception_ports", std::span<const ArgumentInfo>{host_get_exception_ports_arguments}},
    {Routine::host_swap_exception_ports, "host_swap_exception_ports", std::span<const ArgumentInfo>{host_swap_exception_ports_arguments}},
    {Routine::host_load_symbol_table, "host_load_symbol_table", std::span<const ArgumentInfo>{host_load_symbol_table_arguments}},
    {Routine::mach_vm_wire, "mach_vm_wire", std::span<const ArgumentInfo>{mach_vm_wire_arguments}},
    {Routine::host_processor_sets, "host_processor_sets", std::span<const ArgumentInfo>{host_processor_sets_arguments}},
    {Routine::host_processor_set_priv, "host_processor_set_priv", std::span<const ArgumentInfo>{host_processor_set_priv_arguments}},
    {Routine::set_dp_control_port, "set_dp_control_port", std::span<const ArgumentInfo>{set_dp_control_port_arguments}},
    {Routine::get_dp_control_port, "get_dp_control_port", std::span<const ArgumentInfo>{get_dp_control_port_arguments}},
    {Routine::host_set_UNDServer, "host_set_UNDServer", std::span<const ArgumentInfo>{host_set_UNDServer_arguments}},
    {Routine::host_get_UNDServer, "host_get_UNDServer", std::span<const ArgumentInfo>{host_get_UNDServer_arguments}},
}};

constexpr std::uint32_t id(Routine routine) {
    return static_cast<std::uint32_t>(routine);
}

}  // namespace shade::xnu::mig::host_priv
