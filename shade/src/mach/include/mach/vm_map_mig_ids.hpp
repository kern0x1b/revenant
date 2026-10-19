// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define the ARM32 vm_map MIG routine identifiers and request/reply
// argument layouts.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/vm_map.defs

// ARM32 MIG wire contract. Keep message identifiers and argument layouts ABI-stable.
#pragma once

#include <array>
#include <cstdint>
#include <span>
#include <string_view>

#include "mach/xnu_mig_adapter.hpp"

namespace shade::xnu::mig::vm_map {

inline constexpr std::string_view subsystem_name{"vm_map"};
inline constexpr std::uint32_t subsystem_base = 3800U;

enum class Routine : std::uint32_t {
    vm_region = 3800U,
    vm_allocate = 3801U,
    vm_deallocate = 3802U,
    vm_protect = 3803U,
    vm_inherit = 3804U,
    vm_read = 3805U,
    vm_read_list = 3806U,
    vm_write = 3807U,
    vm_copy = 3808U,
    vm_read_overwrite = 3809U,
    vm_msync = 3810U,
    vm_behavior_set = 3811U,
    vm_map = 3812U,
    vm_machine_attribute = 3813U,
    vm_remap = 3814U,
    task_wire = 3815U,
    mach_make_memory_entry = 3816U,
    vm_map_page_query = 3817U,
    mach_vm_region_info = 3818U,
    vm_mapped_pages_info = 3819U,
    vm_region_recurse = 3821U,
    vm_region_recurse_64 = 3822U,
    mach_vm_region_info_64 = 3823U,
    vm_region_64 = 3824U,
    mach_make_memory_entry_64 = 3825U,
    vm_map_64 = 3826U,
    vm_purgable_control = 3830U,
};

inline constexpr std::array<ArgumentInfo, 6> vm_region_arguments{{
    {"target_task", "vm_map_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"address", "vm_address_t", "", ArgumentDirection::InOut, WireType::Scalar, 4U, 0U, 0U, 32U, 48U, 4294967295U, 4294967295U},
    {"size", "vm_size_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 52U, 4294967295U, 4294967295U},
    {"flavor", "vm_region_flavor_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
    {"info", "vm_region_info_t, CountInOut", "", ArgumentDirection::Out, WireType::VariableInline, 40U, 0U, 4U, 4294967295U, 60U, 40U, 56U},
    {"object_name", "memory_object_name_t = MACH_MSG_TYPE_MOVE_SEND ctype: mach_port_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> vm_allocate_arguments{{
    {"target_task", "vm_task_entry_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"address", "vm_address_t", "", ArgumentDirection::InOut, WireType::Scalar, 4U, 0U, 0U, 32U, 36U, 4294967295U, 4294967295U},
    {"size", "vm_size_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
    {"flags", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 40U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> vm_deallocate_arguments{{
    {"target_task", "vm_task_entry_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"address", "vm_address_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"size", "vm_size_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 5> vm_protect_arguments{{
    {"target_task", "vm_task_entry_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"address", "vm_address_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"size", "vm_size_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
    {"set_maximum", "boolean_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 40U, 4294967295U, 4294967295U, 4294967295U},
    {"new_protection", "vm_prot_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 44U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> vm_inherit_arguments{{
    {"target_task", "vm_task_entry_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"address", "vm_address_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"size", "vm_size_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
    {"new_inheritance", "vm_inherit_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 40U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> vm_read_arguments{{
    {"target_task", "vm_map_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"address", "vm_address_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"size", "vm_size_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
    {"data", "pointer_t", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 1U, 4294967295U, 28U, 4294967295U, 48U},
}};

inline constexpr std::array<ArgumentInfo, 3> vm_read_list_arguments{{
    {"target_task", "vm_map_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"data_list", "vm_read_entry_t", "", ArgumentDirection::InOut, WireType::FixedInline, 2048U, 0U, 4U, 32U, 36U, 4294967295U, 4294967295U},
    {"count", "natural_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 2080U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> vm_write_arguments{{
    {"target_task", "vm_map_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"address", "vm_address_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"data", "pointer_t", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 28U, 4294967295U, 52U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> vm_copy_arguments{{
    {"target_task", "vm_map_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"source_address", "vm_address_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"size", "vm_size_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
    {"dest_address", "vm_address_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 40U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 5> vm_read_overwrite_arguments{{
    {"target_task", "vm_map_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"address", "vm_address_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"size", "vm_size_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
    {"data", "vm_address_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 40U, 4294967295U, 4294967295U, 4294967295U},
    {"outsize", "vm_size_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> vm_msync_arguments{{
    {"target_task", "vm_map_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"address", "vm_address_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"size", "vm_size_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
    {"sync_flags", "vm_sync_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 40U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> vm_behavior_set_arguments{{
    {"target_task", "vm_map_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"address", "vm_address_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"size", "vm_size_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
    {"new_behavior", "vm_behavior_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 40U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 11> vm_map_arguments{{
    {"target_task", "vm_task_entry_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"address", "vm_address_t", "", ArgumentDirection::InOut, WireType::Scalar, 4U, 0U, 0U, 48U, 36U, 4294967295U, 4294967295U},
    {"size", "vm_size_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 52U, 4294967295U, 4294967295U, 4294967295U},
    {"mask", "vm_address_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 56U, 4294967295U, 4294967295U, 4294967295U},
    {"flags", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 60U, 4294967295U, 4294967295U, 4294967295U},
    {"object", "mem_entry_name_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"offset", "vm_offset_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 64U, 4294967295U, 4294967295U, 4294967295U},
    {"copy", "boolean_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 68U, 4294967295U, 4294967295U, 4294967295U},
    {"cur_protection", "vm_prot_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 72U, 4294967295U, 4294967295U, 4294967295U},
    {"max_protection", "vm_prot_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 76U, 4294967295U, 4294967295U, 4294967295U},
    {"inheritance", "vm_inherit_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 80U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 5> vm_machine_attribute_arguments{{
    {"target_task", "vm_map_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"address", "vm_address_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"size", "vm_size_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
    {"attribute", "vm_machine_attribute_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 40U, 4294967295U, 4294967295U, 4294967295U},
    {"value", "vm_machine_attribute_val_t", "", ArgumentDirection::InOut, WireType::Scalar, 4U, 0U, 0U, 44U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 11> vm_remap_arguments{{
    {"target_task", "vm_map_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"target_address", "vm_address_t", "", ArgumentDirection::InOut, WireType::Scalar, 4U, 0U, 0U, 48U, 36U, 4294967295U, 4294967295U},
    {"size", "vm_size_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 52U, 4294967295U, 4294967295U, 4294967295U},
    {"mask", "vm_address_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 56U, 4294967295U, 4294967295U, 4294967295U},
    {"anywhere", "boolean_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 60U, 4294967295U, 4294967295U, 4294967295U},
    {"src_task", "vm_map_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"src_address", "vm_address_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 64U, 4294967295U, 4294967295U, 4294967295U},
    {"copy", "boolean_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 68U, 4294967295U, 4294967295U, 4294967295U},
    {"cur_protection", "vm_prot_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 40U, 4294967295U, 4294967295U},
    {"max_protection", "vm_prot_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 44U, 4294967295U, 4294967295U},
    {"inheritance", "vm_inherit_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 72U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> task_wire_arguments{{
    {"target_task", "vm_map_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"must_wire", "boolean_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 6> mach_make_memory_entry_arguments{{
    {"target_task", "vm_map_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"size", "vm_size_t", "", ArgumentDirection::InOut, WireType::Scalar, 4U, 0U, 0U, 48U, 48U, 4294967295U, 4294967295U},
    {"offset", "vm_offset_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 52U, 4294967295U, 4294967295U, 4294967295U},
    {"permission", "vm_prot_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 56U, 4294967295U, 4294967295U, 4294967295U},
    {"object_handle", "mem_entry_name_port_move_send_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
    {"parent_entry", "mem_entry_name_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> vm_map_page_query_arguments{{
    {"target_map", "vm_map_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"offset", "vm_offset_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"disposition", "integer_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
    {"ref_count", "integer_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 40U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> mach_vm_region_info_arguments{{
    {"task", "vm_map_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"address", "vm_address_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"region", "vm_info_region_t", "", ArgumentDirection::Out, WireType::FixedInline, 40U, 0U, 4U, 4294967295U, 48U, 4294967295U, 4294967295U},
    {"objects", "vm_info_object_array_t", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 84U, 4294967295U, 28U, 4294967295U, 88U},
}};

inline constexpr std::array<ArgumentInfo, 2> vm_mapped_pages_info_arguments{{
    {"task", "vm_map_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"pages", "page_address_array_t", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 4U, 4294967295U, 28U, 4294967295U, 48U},
}};

inline constexpr std::array<ArgumentInfo, 5> vm_region_recurse_arguments{{
    {"target_task", "vm_map_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"address", "vm_address_t", "", ArgumentDirection::InOut, WireType::Scalar, 4U, 0U, 0U, 32U, 36U, 4294967295U, 4294967295U},
    {"size", "vm_size_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 40U, 4294967295U, 4294967295U},
    {"nesting_depth", "natural_t", "", ArgumentDirection::InOut, WireType::Scalar, 4U, 0U, 0U, 36U, 44U, 4294967295U, 4294967295U},
    {"info", "vm_region_recurse_info_t,CountInOut", "", ArgumentDirection::Out, WireType::VariableInline, 76U, 0U, 4U, 4294967295U, 52U, 40U, 48U},
}};

inline constexpr std::array<ArgumentInfo, 5> vm_region_recurse_64_arguments{{
    {"target_task", "vm_map_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"address", "vm_address_t", "", ArgumentDirection::InOut, WireType::Scalar, 4U, 0U, 0U, 32U, 36U, 4294967295U, 4294967295U},
    {"size", "vm_size_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 40U, 4294967295U, 4294967295U},
    {"nesting_depth", "natural_t", "", ArgumentDirection::InOut, WireType::Scalar, 4U, 0U, 0U, 36U, 44U, 4294967295U, 4294967295U},
    {"info", "vm_region_recurse_info_t,CountInOut", "", ArgumentDirection::Out, WireType::VariableInline, 76U, 0U, 4U, 4294967295U, 52U, 40U, 48U},
}};

inline constexpr std::array<ArgumentInfo, 4> mach_vm_region_info_64_arguments{{
    {"task", "vm_map_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"address", "vm_address_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"region", "vm_info_region_64_t", "", ArgumentDirection::Out, WireType::FixedInline, 44U, 0U, 4U, 4294967295U, 48U, 4294967295U, 4294967295U},
    {"objects", "vm_info_object_array_t", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 84U, 4294967295U, 28U, 4294967295U, 92U},
}};

inline constexpr std::array<ArgumentInfo, 6> vm_region_64_arguments{{
    {"target_task", "vm_map_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"address", "vm_address_t", "", ArgumentDirection::InOut, WireType::Scalar, 4U, 0U, 0U, 32U, 48U, 4294967295U, 4294967295U},
    {"size", "vm_size_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 52U, 4294967295U, 4294967295U},
    {"flavor", "vm_region_flavor_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
    {"info", "vm_region_info_t, CountInOut", "", ArgumentDirection::Out, WireType::VariableInline, 40U, 0U, 4U, 4294967295U, 60U, 40U, 56U},
    {"object_name", "memory_object_name_t = MACH_MSG_TYPE_MOVE_SEND ctype: mach_port_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 6> mach_make_memory_entry_64_arguments{{
    {"target_task", "vm_map_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"size", "memory_object_size_t", "", ArgumentDirection::InOut, WireType::Scalar, 8U, 0U, 0U, 48U, 48U, 4294967295U, 4294967295U},
    {"offset", "memory_object_offset_t", "", ArgumentDirection::In, WireType::Scalar, 8U, 0U, 0U, 56U, 4294967295U, 4294967295U, 4294967295U},
    {"permission", "vm_prot_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 64U, 4294967295U, 4294967295U, 4294967295U},
    {"object_handle", "mach_port_move_send_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
    {"parent_entry", "mem_entry_name_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 11> vm_map_64_arguments{{
    {"target_task", "vm_task_entry_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"address", "vm_address_t", "", ArgumentDirection::InOut, WireType::Scalar, 4U, 0U, 0U, 48U, 36U, 4294967295U, 4294967295U},
    {"size", "vm_size_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 52U, 4294967295U, 4294967295U, 4294967295U},
    {"mask", "vm_address_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 56U, 4294967295U, 4294967295U, 4294967295U},
    {"flags", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 60U, 4294967295U, 4294967295U, 4294967295U},
    {"object", "mem_entry_name_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"offset", "memory_object_offset_t", "", ArgumentDirection::In, WireType::Scalar, 8U, 0U, 0U, 64U, 4294967295U, 4294967295U, 4294967295U},
    {"copy", "boolean_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 72U, 4294967295U, 4294967295U, 4294967295U},
    {"cur_protection", "vm_prot_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 76U, 4294967295U, 4294967295U, 4294967295U},
    {"max_protection", "vm_prot_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 80U, 4294967295U, 4294967295U, 4294967295U},
    {"inheritance", "vm_inherit_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 84U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> vm_purgable_control_arguments{{
    {"target_task", "vm_map_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"address", "vm_address_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"control", "vm_purgable_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
    {"state", "int", "", ArgumentDirection::InOut, WireType::Scalar, 4U, 0U, 0U, 40U, 36U, 4294967295U, 4294967295U},
}};

struct Descriptor {
    Routine routine;
    std::string_view name;
    std::span<const ArgumentInfo> arguments;
};

inline constexpr std::array<Descriptor, 27> routines{{
    {Routine::vm_region, "vm_region", std::span<const ArgumentInfo>{vm_region_arguments}},
    {Routine::vm_allocate, "vm_allocate", std::span<const ArgumentInfo>{vm_allocate_arguments}},
    {Routine::vm_deallocate, "vm_deallocate", std::span<const ArgumentInfo>{vm_deallocate_arguments}},
    {Routine::vm_protect, "vm_protect", std::span<const ArgumentInfo>{vm_protect_arguments}},
    {Routine::vm_inherit, "vm_inherit", std::span<const ArgumentInfo>{vm_inherit_arguments}},
    {Routine::vm_read, "vm_read", std::span<const ArgumentInfo>{vm_read_arguments}},
    {Routine::vm_read_list, "vm_read_list", std::span<const ArgumentInfo>{vm_read_list_arguments}},
    {Routine::vm_write, "vm_write", std::span<const ArgumentInfo>{vm_write_arguments}},
    {Routine::vm_copy, "vm_copy", std::span<const ArgumentInfo>{vm_copy_arguments}},
    {Routine::vm_read_overwrite, "vm_read_overwrite", std::span<const ArgumentInfo>{vm_read_overwrite_arguments}},
    {Routine::vm_msync, "vm_msync", std::span<const ArgumentInfo>{vm_msync_arguments}},
    {Routine::vm_behavior_set, "vm_behavior_set", std::span<const ArgumentInfo>{vm_behavior_set_arguments}},
    {Routine::vm_map, "vm_map", std::span<const ArgumentInfo>{vm_map_arguments}},
    {Routine::vm_machine_attribute, "vm_machine_attribute", std::span<const ArgumentInfo>{vm_machine_attribute_arguments}},
    {Routine::vm_remap, "vm_remap", std::span<const ArgumentInfo>{vm_remap_arguments}},
    {Routine::task_wire, "task_wire", std::span<const ArgumentInfo>{task_wire_arguments}},
    {Routine::mach_make_memory_entry, "mach_make_memory_entry", std::span<const ArgumentInfo>{mach_make_memory_entry_arguments}},
    {Routine::vm_map_page_query, "vm_map_page_query", std::span<const ArgumentInfo>{vm_map_page_query_arguments}},
    {Routine::mach_vm_region_info, "mach_vm_region_info", std::span<const ArgumentInfo>{mach_vm_region_info_arguments}},
    {Routine::vm_mapped_pages_info, "vm_mapped_pages_info", std::span<const ArgumentInfo>{vm_mapped_pages_info_arguments}},
    {Routine::vm_region_recurse, "vm_region_recurse", std::span<const ArgumentInfo>{vm_region_recurse_arguments}},
    {Routine::vm_region_recurse_64, "vm_region_recurse_64", std::span<const ArgumentInfo>{vm_region_recurse_64_arguments}},
    {Routine::mach_vm_region_info_64, "mach_vm_region_info_64", std::span<const ArgumentInfo>{mach_vm_region_info_64_arguments}},
    {Routine::vm_region_64, "vm_region_64", std::span<const ArgumentInfo>{vm_region_64_arguments}},
    {Routine::mach_make_memory_entry_64, "mach_make_memory_entry_64", std::span<const ArgumentInfo>{mach_make_memory_entry_64_arguments}},
    {Routine::vm_map_64, "vm_map_64", std::span<const ArgumentInfo>{vm_map_64_arguments}},
    {Routine::vm_purgable_control, "vm_purgable_control", std::span<const ArgumentInfo>{vm_purgable_control_arguments}},
}};

constexpr std::uint32_t id(Routine routine) {
    return static_cast<std::uint32_t>(routine);
}

}  // namespace shade::xnu::mig::vm_map
