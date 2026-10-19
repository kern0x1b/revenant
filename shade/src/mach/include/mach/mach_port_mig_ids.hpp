// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define the ARM32 mach_port MIG routine identifiers and
// request/reply argument layouts.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/mach_port.defs

// ARM32 MIG wire contract. Keep message identifiers and argument layouts ABI-stable.
#pragma once

#include <array>
#include <cstdint>
#include <span>
#include <string_view>

#include "mach/xnu_mig_adapter.hpp"

namespace shade::xnu::mig::mach_port {

inline constexpr std::string_view subsystem_name{"mach_port"};
inline constexpr std::uint32_t subsystem_base = 3200U;

enum class Routine : std::uint32_t {
    mach_port_names = 3200U,
    mach_port_type = 3201U,
    mach_port_rename = 3202U,
    mach_port_allocate_name = 3203U,
    mach_port_allocate = 3204U,
    mach_port_destroy = 3205U,
    mach_port_deallocate = 3206U,
    mach_port_get_refs = 3207U,
    mach_port_mod_refs = 3208U,
    mach_port_set_mscount = 3210U,
    mach_port_get_set_status = 3211U,
    mach_port_move_member = 3212U,
    mach_port_request_notification = 3213U,
    mach_port_insert_right = 3214U,
    mach_port_extract_right = 3215U,
    mach_port_set_seqno = 3216U,
    mach_port_get_attributes = 3217U,
    mach_port_set_attributes = 3218U,
    mach_port_allocate_qos = 3219U,
    mach_port_allocate_full = 3220U,
    task_set_port_space = 3221U,
    mach_port_get_srights = 3222U,
    mach_port_space_info = 3223U,
    mach_port_dnrequest_info = 3224U,
    mach_port_kernel_object = 3225U,
    mach_port_insert_member = 3226U,
    mach_port_extract_member = 3227U,
};

inline constexpr std::array<ArgumentInfo, 3> mach_port_names_arguments{{
    {"task", "ipc_space_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"names", "mach_port_name_array_t", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 4U, 4294967295U, 28U, 4294967295U, 60U},
    {"types", "mach_port_type_array_t", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 4U, 4294967295U, 40U, 4294967295U, 64U},
}};

inline constexpr std::array<ArgumentInfo, 3> mach_port_type_arguments{{
    {"task", "ipc_space_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"name", "mach_port_name_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"ptype", "mach_port_type_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> mach_port_rename_arguments{{
    {"task", "ipc_space_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"old_name", "mach_port_name_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"new_name", "mach_port_name_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> mach_port_allocate_name_arguments{{
    {"task", "ipc_space_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"right", "mach_port_right_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"name", "mach_port_name_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> mach_port_allocate_arguments{{
    {"task", "ipc_space_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"right", "mach_port_right_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"name", "mach_port_name_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> mach_port_destroy_arguments{{
    {"task", "ipc_space_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"name", "mach_port_name_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> mach_port_deallocate_arguments{{
    {"task", "ipc_space_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"name", "mach_port_name_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> mach_port_get_refs_arguments{{
    {"task", "ipc_space_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"name", "mach_port_name_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"right", "mach_port_right_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
    {"refs", "mach_port_urefs_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> mach_port_mod_refs_arguments{{
    {"task", "ipc_space_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"name", "mach_port_name_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"right", "mach_port_right_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
    {"delta", "mach_port_delta_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 40U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> mach_port_set_mscount_arguments{{
    {"task", "ipc_space_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"name", "mach_port_name_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"mscount", "mach_port_mscount_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> mach_port_get_set_status_arguments{{
    {"task", "ipc_space_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"name", "mach_port_name_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"members", "mach_port_name_array_t", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 4U, 4294967295U, 28U, 4294967295U, 48U},
}};

inline constexpr std::array<ArgumentInfo, 3> mach_port_move_member_arguments{{
    {"task", "ipc_space_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"member", "mach_port_name_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"after", "mach_port_name_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 6> mach_port_request_notification_arguments{{
    {"task", "ipc_space_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"name", "mach_port_name_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"msgid", "mach_msg_id_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 52U, 4294967295U, 4294967295U, 4294967295U},
    {"sync", "mach_port_mscount_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 56U, 4294967295U, 4294967295U, 4294967295U},
    {"notify", "mach_port_send_once_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"previous", "mach_port_move_send_once_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> mach_port_insert_right_arguments{{
    {"task", "ipc_space_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"name", "mach_port_name_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"poly", "mach_port_poly_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> mach_port_extract_right_arguments{{
    {"task", "ipc_space_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"name", "mach_port_name_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"msgt_name", "mach_msg_type_name_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
    {"poly", "mach_port_poly_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> mach_port_set_seqno_arguments{{
    {"task", "ipc_space_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"name", "mach_port_name_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"seqno", "mach_port_seqno_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> mach_port_get_attributes_arguments{{
    {"task", "ipc_space_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"name", "mach_port_name_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"flavor", "mach_port_flavor_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
    {"port_info_out", "mach_port_info_t, CountInOut", "", ArgumentDirection::Out, WireType::VariableInline, 40U, 0U, 4U, 4294967295U, 40U, 40U, 36U},
}};

inline constexpr std::array<ArgumentInfo, 4> mach_port_set_attributes_arguments{{
    {"task", "ipc_space_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"name", "mach_port_name_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"flavor", "mach_port_flavor_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
    {"port_info", "mach_port_info_t", "", ArgumentDirection::In, WireType::VariableInline, 40U, 0U, 4U, 44U, 4294967295U, 40U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> mach_port_allocate_qos_arguments{{
    {"task", "ipc_space_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"right", "mach_port_right_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"qos", "mach_port_qos_t", "", ArgumentDirection::InOut, WireType::FixedInline, 8U, 0U, 4U, 36U, 36U, 4294967295U, 4294967295U},
    {"name", "mach_port_name_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 44U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 5> mach_port_allocate_full_arguments{{
    {"task", "ipc_space_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"right", "mach_port_right_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"proto", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"qos", "mach_port_qos_t", "", ArgumentDirection::InOut, WireType::FixedInline, 8U, 0U, 4U, 52U, 36U, 4294967295U, 4294967295U},
    {"name", "mach_port_name_t", "", ArgumentDirection::InOut, WireType::Scalar, 4U, 0U, 0U, 60U, 44U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> task_set_port_space_arguments{{
    {"task", "ipc_space_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"table_entries", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> mach_port_get_srights_arguments{{
    {"task", "ipc_space_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"name", "mach_port_name_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"srights", "mach_port_rights_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> mach_port_space_info_arguments{{
    {"task", "ipc_space_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"space_info", "ipc_info_space_t", "", ArgumentDirection::Out, WireType::FixedInline, 24U, 0U, 4U, 4294967295U, 60U, 4294967295U, 4294967295U},
    {"table_info", "ipc_info_name_array_t, Dealloc", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 28U, 4294967295U, 28U, 4294967295U, 84U},
    {"tree_info", "ipc_info_tree_name_array_t, Dealloc", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 36U, 4294967295U, 40U, 4294967295U, 88U},
}};

inline constexpr std::array<ArgumentInfo, 4> mach_port_dnrequest_info_arguments{{
    {"task", "ipc_space_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"name", "mach_port_name_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"dnr_total", "unsigned", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
    {"dnr_used", "unsigned", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 40U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> mach_port_kernel_object_arguments{{
    {"task", "ipc_space_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"name", "mach_port_name_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"object_type", "unsigned", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
    {"object_addr", "vm_offset_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 40U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> mach_port_insert_member_arguments{{
    {"task", "ipc_space_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"name", "mach_port_name_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"pset", "mach_port_name_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> mach_port_extract_member_arguments{{
    {"task", "ipc_space_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"name", "mach_port_name_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"pset", "mach_port_name_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
}};

struct Descriptor {
    Routine routine;
    std::string_view name;
    std::span<const ArgumentInfo> arguments;
};

inline constexpr std::array<Descriptor, 27> routines{{
    {Routine::mach_port_names, "mach_port_names", std::span<const ArgumentInfo>{mach_port_names_arguments}},
    {Routine::mach_port_type, "mach_port_type", std::span<const ArgumentInfo>{mach_port_type_arguments}},
    {Routine::mach_port_rename, "mach_port_rename", std::span<const ArgumentInfo>{mach_port_rename_arguments}},
    {Routine::mach_port_allocate_name, "mach_port_allocate_name", std::span<const ArgumentInfo>{mach_port_allocate_name_arguments}},
    {Routine::mach_port_allocate, "mach_port_allocate", std::span<const ArgumentInfo>{mach_port_allocate_arguments}},
    {Routine::mach_port_destroy, "mach_port_destroy", std::span<const ArgumentInfo>{mach_port_destroy_arguments}},
    {Routine::mach_port_deallocate, "mach_port_deallocate", std::span<const ArgumentInfo>{mach_port_deallocate_arguments}},
    {Routine::mach_port_get_refs, "mach_port_get_refs", std::span<const ArgumentInfo>{mach_port_get_refs_arguments}},
    {Routine::mach_port_mod_refs, "mach_port_mod_refs", std::span<const ArgumentInfo>{mach_port_mod_refs_arguments}},
    {Routine::mach_port_set_mscount, "mach_port_set_mscount", std::span<const ArgumentInfo>{mach_port_set_mscount_arguments}},
    {Routine::mach_port_get_set_status, "mach_port_get_set_status", std::span<const ArgumentInfo>{mach_port_get_set_status_arguments}},
    {Routine::mach_port_move_member, "mach_port_move_member", std::span<const ArgumentInfo>{mach_port_move_member_arguments}},
    {Routine::mach_port_request_notification, "mach_port_request_notification", std::span<const ArgumentInfo>{mach_port_request_notification_arguments}},
    {Routine::mach_port_insert_right, "mach_port_insert_right", std::span<const ArgumentInfo>{mach_port_insert_right_arguments}},
    {Routine::mach_port_extract_right, "mach_port_extract_right", std::span<const ArgumentInfo>{mach_port_extract_right_arguments}},
    {Routine::mach_port_set_seqno, "mach_port_set_seqno", std::span<const ArgumentInfo>{mach_port_set_seqno_arguments}},
    {Routine::mach_port_get_attributes, "mach_port_get_attributes", std::span<const ArgumentInfo>{mach_port_get_attributes_arguments}},
    {Routine::mach_port_set_attributes, "mach_port_set_attributes", std::span<const ArgumentInfo>{mach_port_set_attributes_arguments}},
    {Routine::mach_port_allocate_qos, "mach_port_allocate_qos", std::span<const ArgumentInfo>{mach_port_allocate_qos_arguments}},
    {Routine::mach_port_allocate_full, "mach_port_allocate_full", std::span<const ArgumentInfo>{mach_port_allocate_full_arguments}},
    {Routine::task_set_port_space, "task_set_port_space", std::span<const ArgumentInfo>{task_set_port_space_arguments}},
    {Routine::mach_port_get_srights, "mach_port_get_srights", std::span<const ArgumentInfo>{mach_port_get_srights_arguments}},
    {Routine::mach_port_space_info, "mach_port_space_info", std::span<const ArgumentInfo>{mach_port_space_info_arguments}},
    {Routine::mach_port_dnrequest_info, "mach_port_dnrequest_info", std::span<const ArgumentInfo>{mach_port_dnrequest_info_arguments}},
    {Routine::mach_port_kernel_object, "mach_port_kernel_object", std::span<const ArgumentInfo>{mach_port_kernel_object_arguments}},
    {Routine::mach_port_insert_member, "mach_port_insert_member", std::span<const ArgumentInfo>{mach_port_insert_member_arguments}},
    {Routine::mach_port_extract_member, "mach_port_extract_member", std::span<const ArgumentInfo>{mach_port_extract_member_arguments}},
}};

constexpr std::uint32_t id(Routine routine) {
    return static_cast<std::uint32_t>(routine);
}

}  // namespace shade::xnu::mig::mach_port
