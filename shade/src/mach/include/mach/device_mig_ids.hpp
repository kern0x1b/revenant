// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define the ARM32 device MIG routine identifiers and request/reply
// argument layouts.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/device/device.defs

// ARM32 MIG wire contract. Keep message identifiers and argument layouts ABI-stable.
#pragma once

#include <array>
#include <cstdint>
#include <span>
#include <string_view>

#include "mach/xnu_mig_adapter.hpp"

namespace shade::xnu::mig::device {

inline constexpr std::string_view subsystem_name{"iokit"};
inline constexpr std::uint32_t subsystem_base = 2800U;

enum class Routine : std::uint32_t {
    io_object_get_class = 2800U,
    io_object_conforms_to = 2801U,
    io_iterator_next = 2802U,
    io_iterator_reset = 2803U,
    io_service_get_matching_services = 2804U,
    io_registry_entry_get_property = 2805U,
    io_registry_create_iterator = 2806U,
    io_registry_iterator_enter_entry = 2807U,
    io_registry_iterator_exit_entry = 2808U,
    io_registry_entry_from_path = 2809U,
    io_registry_entry_get_name = 2810U,
    io_registry_entry_get_properties = 2811U,
    io_registry_entry_get_property_bytes = 2812U,
    io_registry_entry_get_child_iterator = 2813U,
    io_registry_entry_get_parent_iterator = 2814U,
    io_service_open = 2815U,
    io_service_close = 2816U,
    io_connect_get_service = 2817U,
    io_connect_set_notification_port = 2818U,
    io_connect_map_memory = 2819U,
    io_connect_add_client = 2820U,
    io_connect_set_properties = 2821U,
    io_connect_method_scalarI_scalarO = 2822U,
    io_connect_method_scalarI_structureO = 2823U,
    io_connect_method_scalarI_structureI = 2824U,
    io_connect_method_structureI_structureO = 2825U,
    io_registry_entry_get_path = 2826U,
    io_registry_get_root_entry = 2827U,
    io_registry_entry_set_properties = 2828U,
    io_registry_entry_in_plane = 2829U,
    io_object_get_retain_count = 2830U,
    io_service_get_busy_state = 2831U,
    io_service_wait_quiet = 2832U,
    io_registry_entry_create_iterator = 2833U,
    io_iterator_is_valid = 2834U,
    io_make_matching = 2835U,
    io_catalog_send_data = 2836U,
    io_catalog_terminate = 2837U,
    io_catalog_get_data = 2838U,
    io_catalog_get_gen_count = 2839U,
    io_catalog_module_loaded = 2840U,
    io_catalog_reset = 2841U,
    io_service_request_probe = 2842U,
    io_registry_entry_get_name_in_plane = 2843U,
    io_service_match_property_table = 2844U,
    io_async_method_scalarI_scalarO = 2845U,
    io_async_method_scalarI_structureO = 2846U,
    io_async_method_scalarI_structureI = 2847U,
    io_async_method_structureI_structureO = 2848U,
    io_service_add_notification = 2849U,
    io_service_add_interest_notification = 2850U,
    io_service_acknowledge_notification = 2851U,
    io_connect_get_notification_semaphore = 2852U,
    io_connect_unmap_memory = 2853U,
    io_registry_entry_get_location_in_plane = 2854U,
    io_registry_entry_get_property_recursively = 2855U,
    io_service_get_state = 2856U,
    io_service_get_matching_services_ool = 2857U,
    io_service_match_property_table_ool = 2858U,
    io_service_add_notification_ool = 2859U,
    io_object_get_superclass = 2860U,
    io_object_get_bundle_identifier = 2861U,
};

inline constexpr std::array<ArgumentInfo, 2> io_object_get_class_arguments{{
    {"object", "io_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"className", "io_name_t", "", ArgumentDirection::Out, WireType::VariableInline, 128U, 4U, 1U, 4294967295U, 44U, 4294967295U, 40U},
}};

inline constexpr std::array<ArgumentInfo, 3> io_object_conforms_to_arguments{{
    {"object", "io_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"className", "io_name_t", "", ArgumentDirection::In, WireType::VariableInline, 128U, 4U, 1U, 40U, 4294967295U, 36U, 4294967295U},
    {"conforms", "boolean_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> io_iterator_next_arguments{{
    {"iterator", "io_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"object", "io_object_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 1> io_iterator_reset_arguments{{
    {"iterator", "io_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> io_service_get_matching_services_arguments{{
    {"master_port", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"matching", "io_string_t", "", ArgumentDirection::In, WireType::VariableInline, 512U, 4U, 1U, 40U, 4294967295U, 36U, 4294967295U},
    {"existing", "io_object_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> io_registry_entry_get_property_arguments{{
    {"registry_entry", "io_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"property_name", "io_name_t", "", ArgumentDirection::In, WireType::VariableInline, 128U, 4U, 1U, 40U, 4294967295U, 36U, 4294967295U},
    {"properties", "io_buf_ptr_t, physicalcopy", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 1U, 4294967295U, 28U, 4294967295U, 48U},
}};

inline constexpr std::array<ArgumentInfo, 4> io_registry_create_iterator_arguments{{
    {"master_port", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"plane", "io_name_t", "", ArgumentDirection::In, WireType::VariableInline, 128U, 4U, 1U, 40U, 4294967295U, 36U, 4294967295U},
    {"options", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"iterator", "io_object_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 1> io_registry_iterator_enter_entry_arguments{{
    {"iterator", "io_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 1> io_registry_iterator_exit_entry_arguments{{
    {"iterator", "io_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> io_registry_entry_from_path_arguments{{
    {"master_port", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"path", "io_string_t", "", ArgumentDirection::In, WireType::VariableInline, 512U, 4U, 1U, 40U, 4294967295U, 36U, 4294967295U},
    {"registry_entry", "io_object_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> io_registry_entry_get_name_arguments{{
    {"registry_entry", "io_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"name", "io_name_t", "", ArgumentDirection::Out, WireType::VariableInline, 128U, 4U, 1U, 4294967295U, 44U, 4294967295U, 40U},
}};

inline constexpr std::array<ArgumentInfo, 2> io_registry_entry_get_properties_arguments{{
    {"registry_entry", "io_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"properties", "io_buf_ptr_t, physicalcopy", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 1U, 4294967295U, 28U, 4294967295U, 48U},
}};

inline constexpr std::array<ArgumentInfo, 3> io_registry_entry_get_property_bytes_arguments{{
    {"registry_entry", "io_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"property_name", "io_name_t", "", ArgumentDirection::In, WireType::VariableInline, 128U, 4U, 1U, 40U, 4294967295U, 36U, 4294967295U},
    {"data", "io_struct_inband_t, CountInOut", "", ArgumentDirection::Out, WireType::VariableInline, 4096U, 0U, 1U, 4294967295U, 40U, 4294967295U, 36U},
}};

inline constexpr std::array<ArgumentInfo, 3> io_registry_entry_get_child_iterator_arguments{{
    {"registry_entry", "io_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"plane", "io_name_t", "", ArgumentDirection::In, WireType::VariableInline, 128U, 4U, 1U, 40U, 4294967295U, 36U, 4294967295U},
    {"iterator", "io_object_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> io_registry_entry_get_parent_iterator_arguments{{
    {"registry_entry", "io_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"plane", "io_name_t", "", ArgumentDirection::In, WireType::VariableInline, 128U, 4U, 1U, 40U, 4294967295U, 36U, 4294967295U},
    {"iterator", "io_object_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> io_service_open_arguments{{
    {"service", "io_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"owningTask", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"connect_type", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"connection", "io_connect_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 1> io_service_close_arguments{{
    {"connection", "io_connect_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> io_connect_get_service_arguments{{
    {"connection", "io_connect_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"service", "io_object_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> io_connect_set_notification_port_arguments{{
    {"connection", "io_connect_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"notification_type", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"port", "mach_port_make_send_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"reference", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 52U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 6> io_connect_map_memory_arguments{{
    {"connection", "io_connect_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"memory_type", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"into_task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"address", "vm_address_t", "", ArgumentDirection::InOut, WireType::Scalar, 4U, 0U, 0U, 52U, 36U, 4294967295U, 4294967295U},
    {"size", "vm_size_t", "", ArgumentDirection::InOut, WireType::Scalar, 4U, 0U, 0U, 56U, 40U, 4294967295U, 4294967295U},
    {"flags", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 60U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> io_connect_add_client_arguments{{
    {"connection", "io_connect_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"connect_to", "io_connect_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> io_connect_set_properties_arguments{{
    {"connection", "io_connect_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"properties", "io_buf_ptr_t, physicalcopy", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 28U, 4294967295U, 48U, 4294967295U},
    {"result", "natural_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> io_connect_method_scalarI_scalarO_arguments{{
    {"connection", "io_connect_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"selector", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"input", "io_scalar_inband_t", "", ArgumentDirection::In, WireType::VariableInline, 64U, 0U, 4U, 40U, 4294967295U, 36U, 4294967295U},
    {"output", "io_scalar_inband_t, CountInOut", "", ArgumentDirection::Out, WireType::VariableInline, 64U, 0U, 4U, 4294967295U, 40U, 4294967295U, 36U},
}};

inline constexpr std::array<ArgumentInfo, 4> io_connect_method_scalarI_structureO_arguments{{
    {"connection", "io_connect_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"selector", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"input", "io_scalar_inband_t", "", ArgumentDirection::In, WireType::VariableInline, 64U, 0U, 4U, 40U, 4294967295U, 36U, 4294967295U},
    {"output", "io_struct_inband_t, CountInOut", "", ArgumentDirection::Out, WireType::VariableInline, 4096U, 0U, 1U, 4294967295U, 40U, 4294967295U, 36U},
}};

inline constexpr std::array<ArgumentInfo, 4> io_connect_method_scalarI_structureI_arguments{{
    {"connection", "io_connect_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"selector", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"input", "io_scalar_inband_t", "", ArgumentDirection::In, WireType::VariableInline, 64U, 0U, 4U, 40U, 4294967295U, 36U, 4294967295U},
    {"inputStruct", "io_struct_inband_t", "", ArgumentDirection::In, WireType::VariableInline, 4096U, 0U, 1U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> io_connect_method_structureI_structureO_arguments{{
    {"connection", "io_connect_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"selector", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"input", "io_struct_inband_t", "", ArgumentDirection::In, WireType::VariableInline, 4096U, 0U, 1U, 40U, 4294967295U, 36U, 4294967295U},
    {"output", "io_struct_inband_t, CountInOut", "", ArgumentDirection::Out, WireType::VariableInline, 4096U, 0U, 1U, 4294967295U, 40U, 4294967295U, 36U},
}};

inline constexpr std::array<ArgumentInfo, 3> io_registry_entry_get_path_arguments{{
    {"registry_entry", "io_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"plane", "io_name_t", "", ArgumentDirection::In, WireType::VariableInline, 128U, 4U, 1U, 40U, 4294967295U, 36U, 4294967295U},
    {"path", "io_string_t", "", ArgumentDirection::Out, WireType::VariableInline, 512U, 4U, 1U, 4294967295U, 44U, 4294967295U, 40U},
}};

inline constexpr std::array<ArgumentInfo, 2> io_registry_get_root_entry_arguments{{
    {"master_port", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"root", "io_object_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> io_registry_entry_set_properties_arguments{{
    {"registry_entry", "io_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"properties", "io_buf_ptr_t, physicalcopy", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 28U, 4294967295U, 48U, 4294967295U},
    {"result", "natural_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> io_registry_entry_in_plane_arguments{{
    {"registry_entry", "io_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"plane", "io_name_t", "", ArgumentDirection::In, WireType::VariableInline, 128U, 4U, 1U, 40U, 4294967295U, 36U, 4294967295U},
    {"inPlane", "boolean_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> io_object_get_retain_count_arguments{{
    {"object", "io_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"retainCount", "int", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> io_service_get_busy_state_arguments{{
    {"service", "io_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"busyState", "int", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> io_service_wait_quiet_arguments{{
    {"service", "io_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"wait_time", "mach_timespec_t", "", ArgumentDirection::In, WireType::FixedInline, 8U, 0U, 4U, 32U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> io_registry_entry_create_iterator_arguments{{
    {"registry_entry", "io_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"plane", "io_name_t", "", ArgumentDirection::In, WireType::VariableInline, 128U, 4U, 1U, 40U, 4294967295U, 36U, 4294967295U},
    {"options", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"iterator", "io_object_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> io_iterator_is_valid_arguments{{
    {"iterator", "io_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"is_valid", "boolean_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 5> io_make_matching_arguments{{
    {"master_port", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"of_type", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"options", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
    {"input", "io_struct_inband_t", "", ArgumentDirection::In, WireType::VariableInline, 4096U, 0U, 1U, 44U, 4294967295U, 40U, 4294967295U},
    {"matching", "io_string_t", "", ArgumentDirection::Out, WireType::VariableInline, 512U, 4U, 1U, 4294967295U, 44U, 4294967295U, 40U},
}};

inline constexpr std::array<ArgumentInfo, 4> io_catalog_send_data_arguments{{
    {"master_port", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"flag", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"inData", "io_buf_ptr_t", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 28U, 4294967295U, 52U, 4294967295U},
    {"result", "natural_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> io_catalog_terminate_arguments{{
    {"master_port", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"flag", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"name", "io_name_t", "", ArgumentDirection::In, WireType::VariableInline, 128U, 4U, 1U, 44U, 4294967295U, 40U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> io_catalog_get_data_arguments{{
    {"master_port", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"flag", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"outData", "io_buf_ptr_t", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 1U, 4294967295U, 28U, 4294967295U, 48U},
}};

inline constexpr std::array<ArgumentInfo, 2> io_catalog_get_gen_count_arguments{{
    {"master_port", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"genCount", "int", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> io_catalog_module_loaded_arguments{{
    {"master_port", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"name", "io_name_t", "", ArgumentDirection::In, WireType::VariableInline, 128U, 4U, 1U, 40U, 4294967295U, 36U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> io_catalog_reset_arguments{{
    {"master_port", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"flag", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 2> io_service_request_probe_arguments{{
    {"service", "io_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"options", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> io_registry_entry_get_name_in_plane_arguments{{
    {"registry_entry", "io_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"plane", "io_name_t", "", ArgumentDirection::In, WireType::VariableInline, 128U, 4U, 1U, 40U, 4294967295U, 36U, 4294967295U},
    {"name", "io_name_t", "", ArgumentDirection::Out, WireType::VariableInline, 128U, 4U, 1U, 4294967295U, 44U, 4294967295U, 40U},
}};

inline constexpr std::array<ArgumentInfo, 3> io_service_match_property_table_arguments{{
    {"service", "io_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"matching", "io_string_t", "", ArgumentDirection::In, WireType::VariableInline, 512U, 4U, 1U, 40U, 4294967295U, 36U, 4294967295U},
    {"matches", "boolean_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 6> io_async_method_scalarI_scalarO_arguments{{
    {"connection", "io_connect_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"wake_port", "mach_port_make_send_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"reference", "io_async_ref_t", "", ArgumentDirection::In, WireType::VariableInline, 32U, 0U, 4U, 52U, 4294967295U, 48U, 4294967295U},
    {"selector", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"input", "io_scalar_inband_t", "", ArgumentDirection::In, WireType::VariableInline, 64U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"output", "io_scalar_inband_t, CountInOut", "", ArgumentDirection::Out, WireType::VariableInline, 64U, 0U, 4U, 4294967295U, 40U, 4294967295U, 36U},
}};

inline constexpr std::array<ArgumentInfo, 6> io_async_method_scalarI_structureO_arguments{{
    {"connection", "io_connect_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"wake_port", "mach_port_make_send_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"reference", "io_async_ref_t", "", ArgumentDirection::In, WireType::VariableInline, 32U, 0U, 4U, 52U, 4294967295U, 48U, 4294967295U},
    {"selector", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"input", "io_scalar_inband_t", "", ArgumentDirection::In, WireType::VariableInline, 64U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"output", "io_struct_inband_t, CountInOut", "", ArgumentDirection::Out, WireType::VariableInline, 4096U, 0U, 1U, 4294967295U, 40U, 4294967295U, 36U},
}};

inline constexpr std::array<ArgumentInfo, 6> io_async_method_scalarI_structureI_arguments{{
    {"connection", "io_connect_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"wake_port", "mach_port_make_send_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"reference", "io_async_ref_t", "", ArgumentDirection::In, WireType::VariableInline, 32U, 0U, 4U, 52U, 4294967295U, 48U, 4294967295U},
    {"selector", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"input", "io_scalar_inband_t", "", ArgumentDirection::In, WireType::VariableInline, 64U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"inputStruct", "io_struct_inband_t", "", ArgumentDirection::In, WireType::VariableInline, 4096U, 0U, 1U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 6> io_async_method_structureI_structureO_arguments{{
    {"connection", "io_connect_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"wake_port", "mach_port_make_send_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"reference", "io_async_ref_t", "", ArgumentDirection::In, WireType::VariableInline, 32U, 0U, 4U, 52U, 4294967295U, 48U, 4294967295U},
    {"selector", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"input", "io_struct_inband_t", "", ArgumentDirection::In, WireType::VariableInline, 4096U, 0U, 1U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"output", "io_struct_inband_t, CountInOut", "", ArgumentDirection::Out, WireType::VariableInline, 4096U, 0U, 1U, 4294967295U, 40U, 4294967295U, 36U},
}};

inline constexpr std::array<ArgumentInfo, 6> io_service_add_notification_arguments{{
    {"master_port", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"notification_type", "io_name_t", "", ArgumentDirection::In, WireType::VariableInline, 128U, 4U, 1U, 56U, 4294967295U, 52U, 4294967295U},
    {"matching", "io_string_t", "", ArgumentDirection::In, WireType::VariableInline, 512U, 4U, 1U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"wake_port", "mach_port_make_send_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"reference", "io_async_ref_t", "", ArgumentDirection::In, WireType::VariableInline, 32U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"notification", "io_object_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 5> io_service_add_interest_notification_arguments{{
    {"service", "io_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"type_of_interest", "io_name_t", "", ArgumentDirection::In, WireType::VariableInline, 128U, 4U, 1U, 56U, 4294967295U, 52U, 4294967295U},
    {"wake_port", "mach_port_make_send_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"reference", "io_async_ref_t", "", ArgumentDirection::In, WireType::VariableInline, 32U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"notification", "io_object_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> io_service_acknowledge_notification_arguments{{
    {"service", "io_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"notify_ref", "natural_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"response", "natural_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 36U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> io_connect_get_notification_semaphore_arguments{{
    {"connection", "io_connect_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"notification_type", "natural_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 32U, 4294967295U, 4294967295U, 4294967295U},
    {"semaphore", "semaphore_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> io_connect_unmap_memory_arguments{{
    {"connection", "io_connect_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"memory_type", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 48U, 4294967295U, 4294967295U, 4294967295U},
    {"into_task", "task_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 28U, 4294967295U, 4294967295U, 4294967295U},
    {"address", "vm_address_t", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 52U, 4294967295U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> io_registry_entry_get_location_in_plane_arguments{{
    {"registry_entry", "io_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"plane", "io_name_t", "", ArgumentDirection::In, WireType::VariableInline, 128U, 4U, 1U, 40U, 4294967295U, 36U, 4294967295U},
    {"location", "io_name_t", "", ArgumentDirection::Out, WireType::VariableInline, 128U, 4U, 1U, 4294967295U, 44U, 4294967295U, 40U},
}};

inline constexpr std::array<ArgumentInfo, 5> io_registry_entry_get_property_recursively_arguments{{
    {"registry_entry", "io_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"plane", "io_name_t", "", ArgumentDirection::In, WireType::VariableInline, 128U, 4U, 1U, 40U, 4294967295U, 36U, 4294967295U},
    {"property_name", "io_name_t", "", ArgumentDirection::In, WireType::VariableInline, 128U, 4U, 1U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"options", "int", "", ArgumentDirection::In, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"properties", "io_buf_ptr_t, physicalcopy", "", ArgumentDirection::Out, WireType::OutOfLine, 0U, 0U, 1U, 4294967295U, 28U, 4294967295U, 48U},
}};

inline constexpr std::array<ArgumentInfo, 2> io_service_get_state_arguments{{
    {"service", "io_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"state", "uint64_t", "", ArgumentDirection::Out, WireType::Scalar, 8U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> io_service_get_matching_services_ool_arguments{{
    {"master_port", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"matching", "io_buf_ptr_t, physicalcopy", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 28U, 4294967295U, 48U, 4294967295U},
    {"result", "natural_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 48U, 4294967295U, 4294967295U},
    {"existing", "io_object_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 4> io_service_match_property_table_ool_arguments{{
    {"service", "io_object_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"matching", "io_buf_ptr_t, physicalcopy", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 28U, 4294967295U, 48U, 4294967295U},
    {"result", "natural_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 36U, 4294967295U, 4294967295U},
    {"matches", "boolean_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 40U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 7> io_service_add_notification_ool_arguments{{
    {"master_port", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"notification_type", "io_name_t", "", ArgumentDirection::In, WireType::VariableInline, 128U, 4U, 1U, 68U, 4294967295U, 64U, 4294967295U},
    {"matching", "io_buf_ptr_t, physicalcopy", "", ArgumentDirection::In, WireType::OutOfLine, 0U, 0U, 1U, 28U, 4294967295U, 196U, 4294967295U},
    {"wake_port", "mach_port_make_send_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 40U, 4294967295U, 4294967295U, 4294967295U},
    {"reference", "io_async_ref_t", "", ArgumentDirection::In, WireType::VariableInline, 32U, 0U, 4U, 4294967295U, 4294967295U, 4294967295U, 4294967295U},
    {"result", "natural_t", "", ArgumentDirection::Out, WireType::Scalar, 4U, 0U, 0U, 4294967295U, 48U, 4294967295U, 4294967295U},
    {"notification", "io_object_t", "", ArgumentDirection::Out, WireType::Port, 4U, 0U, 0U, 4294967295U, 28U, 4294967295U, 4294967295U},
}};

inline constexpr std::array<ArgumentInfo, 3> io_object_get_superclass_arguments{{
    {"master_port", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"obj_name", "io_name_t", "", ArgumentDirection::In, WireType::VariableInline, 128U, 4U, 1U, 40U, 4294967295U, 36U, 4294967295U},
    {"class_name", "io_name_t", "", ArgumentDirection::Out, WireType::VariableInline, 128U, 4U, 1U, 4294967295U, 44U, 4294967295U, 40U},
}};

inline constexpr std::array<ArgumentInfo, 3> io_object_get_bundle_identifier_arguments{{
    {"master_port", "mach_port_t", "", ArgumentDirection::In, WireType::Port, 4U, 0U, 0U, 8U, 4294967295U, 4294967295U, 4294967295U},
    {"obj_name", "io_name_t", "", ArgumentDirection::In, WireType::VariableInline, 128U, 4U, 1U, 40U, 4294967295U, 36U, 4294967295U},
    {"class_name", "io_name_t", "", ArgumentDirection::Out, WireType::VariableInline, 128U, 4U, 1U, 4294967295U, 44U, 4294967295U, 40U},
}};

struct Descriptor {
    Routine routine;
    std::string_view name;
    std::span<const ArgumentInfo> arguments;
};

inline constexpr std::array<Descriptor, 62> routines{{
    {Routine::io_object_get_class, "io_object_get_class", std::span<const ArgumentInfo>{io_object_get_class_arguments}},
    {Routine::io_object_conforms_to, "io_object_conforms_to", std::span<const ArgumentInfo>{io_object_conforms_to_arguments}},
    {Routine::io_iterator_next, "io_iterator_next", std::span<const ArgumentInfo>{io_iterator_next_arguments}},
    {Routine::io_iterator_reset, "io_iterator_reset", std::span<const ArgumentInfo>{io_iterator_reset_arguments}},
    {Routine::io_service_get_matching_services, "io_service_get_matching_services", std::span<const ArgumentInfo>{io_service_get_matching_services_arguments}},
    {Routine::io_registry_entry_get_property, "io_registry_entry_get_property", std::span<const ArgumentInfo>{io_registry_entry_get_property_arguments}},
    {Routine::io_registry_create_iterator, "io_registry_create_iterator", std::span<const ArgumentInfo>{io_registry_create_iterator_arguments}},
    {Routine::io_registry_iterator_enter_entry, "io_registry_iterator_enter_entry", std::span<const ArgumentInfo>{io_registry_iterator_enter_entry_arguments}},
    {Routine::io_registry_iterator_exit_entry, "io_registry_iterator_exit_entry", std::span<const ArgumentInfo>{io_registry_iterator_exit_entry_arguments}},
    {Routine::io_registry_entry_from_path, "io_registry_entry_from_path", std::span<const ArgumentInfo>{io_registry_entry_from_path_arguments}},
    {Routine::io_registry_entry_get_name, "io_registry_entry_get_name", std::span<const ArgumentInfo>{io_registry_entry_get_name_arguments}},
    {Routine::io_registry_entry_get_properties, "io_registry_entry_get_properties", std::span<const ArgumentInfo>{io_registry_entry_get_properties_arguments}},
    {Routine::io_registry_entry_get_property_bytes, "io_registry_entry_get_property_bytes", std::span<const ArgumentInfo>{io_registry_entry_get_property_bytes_arguments}},
    {Routine::io_registry_entry_get_child_iterator, "io_registry_entry_get_child_iterator", std::span<const ArgumentInfo>{io_registry_entry_get_child_iterator_arguments}},
    {Routine::io_registry_entry_get_parent_iterator, "io_registry_entry_get_parent_iterator", std::span<const ArgumentInfo>{io_registry_entry_get_parent_iterator_arguments}},
    {Routine::io_service_open, "io_service_open", std::span<const ArgumentInfo>{io_service_open_arguments}},
    {Routine::io_service_close, "io_service_close", std::span<const ArgumentInfo>{io_service_close_arguments}},
    {Routine::io_connect_get_service, "io_connect_get_service", std::span<const ArgumentInfo>{io_connect_get_service_arguments}},
    {Routine::io_connect_set_notification_port, "io_connect_set_notification_port", std::span<const ArgumentInfo>{io_connect_set_notification_port_arguments}},
    {Routine::io_connect_map_memory, "io_connect_map_memory", std::span<const ArgumentInfo>{io_connect_map_memory_arguments}},
    {Routine::io_connect_add_client, "io_connect_add_client", std::span<const ArgumentInfo>{io_connect_add_client_arguments}},
    {Routine::io_connect_set_properties, "io_connect_set_properties", std::span<const ArgumentInfo>{io_connect_set_properties_arguments}},
    {Routine::io_connect_method_scalarI_scalarO, "io_connect_method_scalarI_scalarO", std::span<const ArgumentInfo>{io_connect_method_scalarI_scalarO_arguments}},
    {Routine::io_connect_method_scalarI_structureO, "io_connect_method_scalarI_structureO", std::span<const ArgumentInfo>{io_connect_method_scalarI_structureO_arguments}},
    {Routine::io_connect_method_scalarI_structureI, "io_connect_method_scalarI_structureI", std::span<const ArgumentInfo>{io_connect_method_scalarI_structureI_arguments}},
    {Routine::io_connect_method_structureI_structureO, "io_connect_method_structureI_structureO", std::span<const ArgumentInfo>{io_connect_method_structureI_structureO_arguments}},
    {Routine::io_registry_entry_get_path, "io_registry_entry_get_path", std::span<const ArgumentInfo>{io_registry_entry_get_path_arguments}},
    {Routine::io_registry_get_root_entry, "io_registry_get_root_entry", std::span<const ArgumentInfo>{io_registry_get_root_entry_arguments}},
    {Routine::io_registry_entry_set_properties, "io_registry_entry_set_properties", std::span<const ArgumentInfo>{io_registry_entry_set_properties_arguments}},
    {Routine::io_registry_entry_in_plane, "io_registry_entry_in_plane", std::span<const ArgumentInfo>{io_registry_entry_in_plane_arguments}},
    {Routine::io_object_get_retain_count, "io_object_get_retain_count", std::span<const ArgumentInfo>{io_object_get_retain_count_arguments}},
    {Routine::io_service_get_busy_state, "io_service_get_busy_state", std::span<const ArgumentInfo>{io_service_get_busy_state_arguments}},
    {Routine::io_service_wait_quiet, "io_service_wait_quiet", std::span<const ArgumentInfo>{io_service_wait_quiet_arguments}},
    {Routine::io_registry_entry_create_iterator, "io_registry_entry_create_iterator", std::span<const ArgumentInfo>{io_registry_entry_create_iterator_arguments}},
    {Routine::io_iterator_is_valid, "io_iterator_is_valid", std::span<const ArgumentInfo>{io_iterator_is_valid_arguments}},
    {Routine::io_make_matching, "io_make_matching", std::span<const ArgumentInfo>{io_make_matching_arguments}},
    {Routine::io_catalog_send_data, "io_catalog_send_data", std::span<const ArgumentInfo>{io_catalog_send_data_arguments}},
    {Routine::io_catalog_terminate, "io_catalog_terminate", std::span<const ArgumentInfo>{io_catalog_terminate_arguments}},
    {Routine::io_catalog_get_data, "io_catalog_get_data", std::span<const ArgumentInfo>{io_catalog_get_data_arguments}},
    {Routine::io_catalog_get_gen_count, "io_catalog_get_gen_count", std::span<const ArgumentInfo>{io_catalog_get_gen_count_arguments}},
    {Routine::io_catalog_module_loaded, "io_catalog_module_loaded", std::span<const ArgumentInfo>{io_catalog_module_loaded_arguments}},
    {Routine::io_catalog_reset, "io_catalog_reset", std::span<const ArgumentInfo>{io_catalog_reset_arguments}},
    {Routine::io_service_request_probe, "io_service_request_probe", std::span<const ArgumentInfo>{io_service_request_probe_arguments}},
    {Routine::io_registry_entry_get_name_in_plane, "io_registry_entry_get_name_in_plane", std::span<const ArgumentInfo>{io_registry_entry_get_name_in_plane_arguments}},
    {Routine::io_service_match_property_table, "io_service_match_property_table", std::span<const ArgumentInfo>{io_service_match_property_table_arguments}},
    {Routine::io_async_method_scalarI_scalarO, "io_async_method_scalarI_scalarO", std::span<const ArgumentInfo>{io_async_method_scalarI_scalarO_arguments}},
    {Routine::io_async_method_scalarI_structureO, "io_async_method_scalarI_structureO", std::span<const ArgumentInfo>{io_async_method_scalarI_structureO_arguments}},
    {Routine::io_async_method_scalarI_structureI, "io_async_method_scalarI_structureI", std::span<const ArgumentInfo>{io_async_method_scalarI_structureI_arguments}},
    {Routine::io_async_method_structureI_structureO, "io_async_method_structureI_structureO", std::span<const ArgumentInfo>{io_async_method_structureI_structureO_arguments}},
    {Routine::io_service_add_notification, "io_service_add_notification", std::span<const ArgumentInfo>{io_service_add_notification_arguments}},
    {Routine::io_service_add_interest_notification, "io_service_add_interest_notification", std::span<const ArgumentInfo>{io_service_add_interest_notification_arguments}},
    {Routine::io_service_acknowledge_notification, "io_service_acknowledge_notification", std::span<const ArgumentInfo>{io_service_acknowledge_notification_arguments}},
    {Routine::io_connect_get_notification_semaphore, "io_connect_get_notification_semaphore", std::span<const ArgumentInfo>{io_connect_get_notification_semaphore_arguments}},
    {Routine::io_connect_unmap_memory, "io_connect_unmap_memory", std::span<const ArgumentInfo>{io_connect_unmap_memory_arguments}},
    {Routine::io_registry_entry_get_location_in_plane, "io_registry_entry_get_location_in_plane", std::span<const ArgumentInfo>{io_registry_entry_get_location_in_plane_arguments}},
    {Routine::io_registry_entry_get_property_recursively, "io_registry_entry_get_property_recursively", std::span<const ArgumentInfo>{io_registry_entry_get_property_recursively_arguments}},
    {Routine::io_service_get_state, "io_service_get_state", std::span<const ArgumentInfo>{io_service_get_state_arguments}},
    {Routine::io_service_get_matching_services_ool, "io_service_get_matching_services_ool", std::span<const ArgumentInfo>{io_service_get_matching_services_ool_arguments}},
    {Routine::io_service_match_property_table_ool, "io_service_match_property_table_ool", std::span<const ArgumentInfo>{io_service_match_property_table_ool_arguments}},
    {Routine::io_service_add_notification_ool, "io_service_add_notification_ool", std::span<const ArgumentInfo>{io_service_add_notification_ool_arguments}},
    {Routine::io_object_get_superclass, "io_object_get_superclass", std::span<const ArgumentInfo>{io_object_get_superclass_arguments}},
    {Routine::io_object_get_bundle_identifier, "io_object_get_bundle_identifier", std::span<const ArgumentInfo>{io_object_get_bundle_identifier_arguments}},
}};

constexpr std::uint32_t id(Routine routine) {
    return static_cast<std::uint32_t>(routine);
}

}  // namespace shade::xnu::mig::device
