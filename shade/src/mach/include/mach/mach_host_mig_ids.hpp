// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define the ARM32 mach_host MIG routine identifiers and
// request/reply argument layouts.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/mach/mach_host.defs

// ARM32 MIG wire contract. Keep message identifiers and argument layouts ABI-stable.
#pragma once

#include <array>
#include <cstdint>
#include <span>
#include <string_view>

#include "mach/xnu_mig_adapter.hpp"

namespace shade::xnu::mig::mach_host {

inline constexpr std::string_view subsystem_name{"mach_host"};
inline constexpr std::uint32_t subsystem_base = 200U;

enum class Routine : std::uint32_t {
    host_info = 200U,
    host_kernel_version = 201U,
    host_page_size = 202U,
    mach_memory_object_memory_entry = 203U,
    host_processor_info = 204U,
    host_get_io_master = 205U,
    host_get_clock_service = 206U,
    kmod_get_info = 207U,
    host_zone_info = 208U,
    host_virtual_physical_table_info = 209U,
    host_ipc_hash_info = 210U,
    enable_bluebox = 211U,
    disable_bluebox = 212U,
    processor_set_default = 213U,
    processor_set_create = 214U,
    mach_memory_object_memory_entry_64 = 215U,
    host_statistics = 216U,
    host_request_notification = 217U,
    host_lockgroup_info = 218U,
};

inline constexpr std::array<ArgumentInfo, 3> host_info_arguments{{
    {"host", "host_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"flavor", "host_flavor_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"host_info_out", "host_info_t, CountInOut", "", ArgumentDirection::Out, WireType::VariableInline, 56U, 0U, 4U, 4294967295U, 40U, 36U, 36U},
}};

inline constexpr std::array<ArgumentInfo, 2> host_kernel_version_arguments{{
    {"host", "host_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"kernel_version", "kernel_version_t", "", ArgumentDirection::Out, WireType::VariableInline, 512U, 4U, 1U, 4294967295U, 44U, 4294967295U, 40U},
}};

inline constexpr std::array<ArgumentInfo, 2> host_page_size_arguments{{
    {"host", "host_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"out_page_size", "vm_size_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 6> mach_memory_object_memory_entry_arguments{{
    {"host", "host_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"internal", "boolean_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"size", "vm_size_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 52U, 4294967295U, 4294967295U, 4294967295U},
    {"permission", "vm_prot_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 56U, 4294967295U, 4294967295U, 4294967295U},
    {"pager", "memory_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"entry_handle", "mach_port_move_send_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> host_processor_info_arguments{{
    {"host", "host_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"flavor", "processor_flavor_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"out_processor_count", "natural_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 48U, 4294967295U, 4294967295U},
    {"out_processor_info", "processor_info_array_t", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 4U, 4294967295U, 28U, 4294967295U, 52U},
}};

inline constexpr std::array<ArgumentInfo, 2> host_get_io_master_arguments{{
    {"host", "host_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"io_master", "io_master_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> host_get_clock_service_arguments{{
    {"host", "host_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"clock_id", "clock_id_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"clock_serv", "clock_serv_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> kmod_get_info_arguments{{
    {"host", "host_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"modules", "kmod_args_t", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 1U, 4294967295U, 28U, 4294967295U, 48U},
}};

inline constexpr std::array<ArgumentInfo, 3> host_zone_info_arguments{{
    {"host", "host_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"names", "zone_name_array_t, Dealloc", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 80U, 4294967295U, 28U, 4294967295U, 60U},
    {"info", "zone_info_array_t, Dealloc", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 36U, 4294967295U, 40U, 4294967295U, 64U},
}};

inline constexpr std::array<ArgumentInfo, 2> host_virtual_physical_table_info_arguments{{
    {"host", "host_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"info", "hash_info_bucket_array_t, Dealloc", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 4U, 4294967295U, 28U, 4294967295U, 48U},
}};

inline constexpr std::array<ArgumentInfo, 2> host_ipc_hash_info_arguments{{
    {"host", "host_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"info", "hash_info_bucket_array_t, Dealloc", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 4U, 4294967295U, 28U, 4294967295U, 48U},
}};

inline constexpr std::array<ArgumentInfo, 4> enable_bluebox_arguments{{
    {"host", "host_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"taskID", "unsigned", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"TWI_TableStart", "unsigned", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
    {"Desc_TableStart", "unsigned", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 40U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 1> disable_bluebox_arguments{{
    {"host", "host_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> processor_set_default_arguments{{
    {"host", "host_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"default_set", "processor_set_name_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> processor_set_create_arguments{{
    {"host", "host_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"new_set", "processor_set_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
    {"new_name", "processor_set_name_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 40U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 6> mach_memory_object_memory_entry_64_arguments{{
    {"host", "host_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"internal", "boolean_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"size", "memory_object_size_t", "", ArgumentDirection::In, WireType::Scalar, 8U, 0U, 0U, 52U, 4294967295U, 4294967295U, 4294967295U},
    {"permission", "vm_prot_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 60U, 4294967295U, 4294967295U, 4294967295U},
    {"pager", "memory_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"entry_handle", "mach_port_move_send_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> host_statistics_arguments{{
    {"host_priv", "host_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"flavor", "host_flavor_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"host_info_out", "host_info_t, CountInOut", "", ArgumentDirection::Out, WireType::VariableInline, 56U, 0U, 4U, 4294967295U, 40U, 36U, 36U},
}};

inline constexpr std::array<ArgumentInfo, 3> host_request_notification_arguments{{
    {"host", "host_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"notify_type", "host_flavor_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"notify_port", "mach_port_make_send_once_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> host_lockgroup_info_arguments{{
    {"host", "host_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"lockgroup_info", "lockgroup_info_array_t, Dealloc", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 252U, 4294967295U, 28U, 4294967295U, 48U},
}};

struct Descriptor {
    Routine routine;
    std::string_view name;
    std::span<const ArgumentInfo> arguments;
};

inline constexpr std::array<Descriptor, 19> routines{{
    {Routine::host_info, "host_info", std::span<const ArgumentInfo>{host_info_arguments}},
    {Routine::host_kernel_version, "host_kernel_version", std::span<const ArgumentInfo>{host_kernel_version_arguments}},
    {Routine::host_page_size, "host_page_size", std::span<const ArgumentInfo>{host_page_size_arguments}},
    {Routine::mach_memory_object_memory_entry, "mach_memory_object_memory_entry", std::span<const ArgumentInfo>{mach_memory_object_memory_entry_arguments}},
    {Routine::host_processor_info, "host_processor_info", std::span<const ArgumentInfo>{host_processor_info_arguments}},
    {Routine::host_get_io_master, "host_get_io_master", std::span<const ArgumentInfo>{host_get_io_master_arguments}},
    {Routine::host_get_clock_service, "host_get_clock_service", std::span<const ArgumentInfo>{host_get_clock_service_arguments}},
    {Routine::kmod_get_info, "kmod_get_info", std::span<const ArgumentInfo>{kmod_get_info_arguments}},
    {Routine::host_zone_info, "host_zone_info", std::span<const ArgumentInfo>{host_zone_info_arguments}},
    {Routine::host_virtual_physical_table_info, "host_virtual_physical_table_info", std::span<const ArgumentInfo>{host_virtual_physical_table_info_arguments}},
    {Routine::host_ipc_hash_info, "host_ipc_hash_info", std::span<const ArgumentInfo>{host_ipc_hash_info_arguments}},
    {Routine::enable_bluebox, "enable_bluebox", std::span<const ArgumentInfo>{enable_bluebox_arguments}},
    {Routine::disable_bluebox, "disable_bluebox", std::span<const ArgumentInfo>{disable_bluebox_arguments}},
    {Routine::processor_set_default, "processor_set_default", std::span<const ArgumentInfo>{processor_set_default_arguments}},
    {Routine::processor_set_create, "processor_set_create", std::span<const ArgumentInfo>{processor_set_create_arguments}},
    {Routine::mach_memory_object_memory_entry_64, "mach_memory_object_memory_entry_64", std::span<const ArgumentInfo>{mach_memory_object_memory_entry_64_arguments}},
    {Routine::host_statistics, "host_statistics", std::span<const ArgumentInfo>{host_statistics_arguments}},
    {Routine::host_request_notification, "host_request_notification", std::span<const ArgumentInfo>{host_request_notification_arguments}},
    {Routine::host_lockgroup_info, "host_lockgroup_info", std::span<const ArgumentInfo>{host_lockgroup_info_arguments}},
}};

constexpr std::uint32_t id(Routine routine) {
    return static_cast<std::uint32_t>(routine);
}

}  // namespace shade::xnu::mig::mach_host
