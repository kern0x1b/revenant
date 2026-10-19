// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Resolve the firmware IOKit audio method and memory-map capability
// profile.

#pragma once

#include <cstdint>
#include <optional>
#include <string_view>

namespace shade::kernel_iokit::audio {

// Describes the firmware-facing IOAudio user-client ABI. Selection follows the
// provider protocol exposed in the IOKit registry, rather than an OS version,
// product build, process, or application.
struct IOKitAudioAbi {
    struct RegistryKeys {
        std::string_view device_name;
        std::string_view device_manufacturer;
        std::string_view device_uid;
        // Newer IOAudio2 clients use this numeric capability to classify the
        // physical transport before constructing their route database.
        std::string_view transport_type;
        std::string_view clock_domain;
        std::string_view exclusive_access_owner;
        std::string_view io_buffer_frame_size;
        std::string_view input_safety_offset;
        std::string_view output_safety_offset;
        std::string_view input_latency;
        std::string_view output_latency;
        std::string_view sample_rate;
        std::string_view is_running;
        std::string_view input_streams;
        std::string_view output_streams;
        std::string_view controls;
        std::string_view stream_id;
        std::string_view starting_channel;
        std::string_view current_format;
        std::string_view available_formats;
        std::string_view buffer_mapping_options;
        std::string_view format_id;
        std::string_view format_flags;
        std::string_view bytes_per_packet;
        std::string_view frames_per_packet;
        std::string_view bytes_per_frame;
        std::string_view channels_per_frame;
        std::string_view bits_per_channel;
        std::string_view minimum_sample_rate;
        std::string_view maximum_sample_rate;
        std::string_view control_id;
        std::string_view control_base_class;
        std::string_view control_class;
        std::string_view control_scope;
        std::string_view control_element;
        std::string_view control_read_only;
        std::string_view control_variant;
        std::string_view control_multi_selector;
        std::string_view control_name;
        std::string_view control_value;
        std::string_view control_selectors;
        std::string_view control_property_selectors;
        std::string_view control_selector_kind;
        std::string_view control_transfer_function;
        std::string_view control_range_map;
        std::string_view control_range_start_integer;
        std::string_view control_range_start_db;
        std::string_view control_range_integer_steps;
        std::string_view control_range_db_per_step;
    };

    struct Selectors {
        std::uint32_t start;
        std::uint32_t stop;
        std::uint32_t set_control_value;
        std::uint32_t set_nominal_sample_rate;
        std::uint32_t set_stream_current_format;
        std::uint32_t set_stream_active;
    };

    struct MemoryTypes {
        std::uint32_t engine_status;
        std::uint32_t engine_status_size;
        std::uint32_t stream_base;
        std::uint32_t map_options;
    };

    std::string_view service_class;
    std::string_view registry_path;
    std::uint32_t service_type;
    std::uint32_t notification_type;
    RegistryKeys registry;
    Selectors selectors;
    MemoryTypes memory;

    [[nodiscard]] std::uint32_t stream_memory_type(
        std::uint32_t stream_id) const;
    [[nodiscard]] std::optional<std::uint32_t> stream_id_for_memory_type(
        std::uint32_t memory_type) const;

    [[nodiscard]] static const IOKitAudioAbi& io_audio2();
};

} // namespace shade::kernel_iokit::audio
