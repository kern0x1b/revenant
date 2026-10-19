// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Describe supported Darwin sysctl objects and encode their guest-
// visible values.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/sys/sysctl.h
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/kern/kern_sysctl.c

#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <vector>

namespace shade::darwin::sysctl {

inline constexpr std::uint32_t control_unspecified = 0;
inline constexpr std::uint32_t control_kernel = 1;
inline constexpr std::uint32_t control_vfs = 3;
inline constexpr std::uint32_t control_hardware = 6;
inline constexpr std::uint32_t operation_oid_to_name = 1;
inline constexpr std::uint32_t operation_name_to_oid = 3;
inline constexpr std::uint32_t operation_oid_format = 4;
inline constexpr std::uint32_t vfs_generic = 0;
inline constexpr std::uint32_t vfs_max_type_number = 1;
inline constexpr std::uint32_t vfs_conf = 2;
// The built-in VFS table reserves the type slots through devfs (type 19), so
// VFS_MAXTYPENUM returns the next available type number.
inline constexpr std::uint32_t vfs_max_type_number_value = 20;
inline constexpr std::uint32_t kernel_operating_system_type = 1;
inline constexpr std::uint32_t kernel_operating_system_release = 2;
inline constexpr std::uint32_t kernel_operating_system_revision = 3;
inline constexpr std::uint32_t kernel_version = 4;
inline constexpr std::uint32_t kernel_clock_rate = 12;
inline constexpr std::uint32_t kernel_security_level = 9;
inline constexpr std::uint32_t kernel_process = 14;
inline constexpr std::uint32_t kernel_boot_time = 21;
inline constexpr std::uint32_t kernel_maximum_files_per_process = 29;
inline constexpr std::uint32_t kernel_process_arguments = 38;
inline constexpr std::uint32_t kernel_process_arguments2 = 49;
inline constexpr std::uint32_t kernel_build_version = 65;
inline constexpr std::uint32_t kernel_process_all = 0;
inline constexpr std::uint32_t kernel_process_id = 1;
inline constexpr std::uint32_t kernel_process_pgrp = 2;
inline constexpr std::uint32_t kernel_process_session = 3;
inline constexpr std::uint32_t kernel_process_tty = 4;
inline constexpr std::uint32_t kernel_process_uid = 5;
inline constexpr std::uint32_t kernel_process_ruid = 6;
inline constexpr std::uint32_t kernel_process_lcid = 7;
inline constexpr std::uint32_t arm32_kernel_process_info_size = 492;
inline constexpr std::uint32_t process_flag_exec = 0x00004000;

inline constexpr std::uint32_t hardware_machine = 1;
inline constexpr std::uint32_t hardware_model = 2;
inline constexpr std::uint32_t hardware_cpu_count = 3;
inline constexpr std::uint32_t hardware_byte_order = 4;
inline constexpr std::uint32_t hardware_physical_memory = 5;
inline constexpr std::uint32_t hardware_user_memory = 6;
inline constexpr std::uint32_t hardware_page_size = 7;
inline constexpr std::uint32_t hardware_bus_frequency = 14;
inline constexpr std::uint32_t hardware_cpu_frequency = 15;
inline constexpr std::uint32_t hardware_cache_line = 16;
inline constexpr std::uint32_t hardware_l1_i_cache_size = 17;
inline constexpr std::uint32_t hardware_l1_d_cache_size = 18;
inline constexpr std::uint32_t hardware_l2_settings = 19;
inline constexpr std::uint32_t hardware_l2_cache_size = 20;
inline constexpr std::uint32_t hardware_l3_settings = 21;
inline constexpr std::uint32_t hardware_l3_cache_size = 22;
inline constexpr std::uint32_t hardware_memory_size = 24;
inline constexpr std::uint32_t hardware_available_cpu = 25;
// hw.* nodes XNU registers with OID_AUTO: their numbers start at CTL_AUTO_START
// and guests only learn them through sysctl.name2oid.
inline constexpr std::uint32_t hardware_physical_cpu = 0x100;
inline constexpr std::uint32_t hardware_physical_cpu_max = 0x101;
inline constexpr std::uint32_t hardware_logical_cpu = 0x102;
inline constexpr std::uint32_t hardware_logical_cpu_max = 0x103;
inline constexpr std::uint32_t hardware_cpu_frequency_max = 0x104;
inline constexpr std::uint32_t hardware_bus_frequency_max = 0x105;

struct ObjectIdentifier {
    std::array<std::uint32_t, 2> components { };
    std::size_t size { };
};

struct ObjectMetadata {
    std::string_view name;
    std::uint32_t kind;
    std::string_view format;
};

[[nodiscard]] std::optional<ObjectMetadata> describe_object(
    std::uint32_t control, std::uint32_t selector);
[[nodiscard]] std::vector<std::byte> encode_object_format(
    const ObjectMetadata& metadata);

// Resolves the fixed nodes currently projected by the compatibility kernel.
// Dynamic OID_AUTO nodes can be added here as their values are exposed.
[[nodiscard]] std::optional<ObjectIdentifier> resolve_name(
    std::string_view name);

// Returns the selected device profile string projected by a CTL_HW selector.
[[nodiscard]] std::optional<std::string_view> hardware_string(
    std::uint32_t selector, std::string_view machine, std::string_view model);

// Encodes the stable prefix consumed by KERN_PROCARGS clients:
// executable path, word alignment, argv strings, then environment strings.
[[nodiscard]] std::vector<std::byte> encode_process_arguments(
    std::string_view executable_path, std::span<const std::string> arguments,
    std::span<const std::string> environment);

// KERN_PROCARGS2 inserts argc between the aligned executable path and argv.
[[nodiscard]] std::vector<std::byte> encode_process_arguments2(
    std::string_view executable_path, std::span<const std::string> arguments,
    std::span<const std::string> environment);

} // namespace shade::darwin::sysctl
