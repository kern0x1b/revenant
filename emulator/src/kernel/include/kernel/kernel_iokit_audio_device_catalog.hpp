// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Describe the virtual audio devices exposed through the IOKit
// registry.

#pragma once

#include "foundation/device_peripheral_profiles.hpp"

#include <cstdint>
#include <optional>
#include <span>
#include <string_view>

namespace emulator::kernel_iokit::audio {

enum class IOAudio2StreamDirection { Input, Output };

struct IOAudio2StreamFormatDescription {
    std::uint32_t sample_rate;
    std::uint32_t format_id;
    std::uint32_t format_flags;
    std::uint32_t bytes_per_packet;
    std::uint32_t frames_per_packet;
    std::uint32_t bytes_per_frame;
    std::uint32_t channels_per_frame;
    std::uint32_t bits_per_channel;
};

struct IOAudio2StreamDescription {
    std::uint32_t identifier;
    IOAudio2StreamDirection direction;
    std::uint32_t starting_channel;
    std::uint32_t buffer_mapping_options;
    std::uint32_t buffer_size;
    IOAudio2StreamFormatDescription format;
    std::span<const IOAudio2StreamFormatDescription> available_formats;
};

struct IOAudio2SelectorItemDescription {
    std::uint32_t value;
    std::string_view name;
};

struct IOAudio2ControlRangeDescription {
    std::uint64_t start_db_value;
    std::uint32_t integer_steps;
    std::uint32_t start_integer_value;
    std::uint64_t db_per_step;
};

struct IOAudio2ControlDescription {
    std::uint32_t identifier;
    std::uint32_t base_class;
    std::uint32_t control_class;
    std::uint32_t scope;
    std::uint32_t element;
    std::uint32_t value;
    bool read_only;
    std::span<const IOAudio2ControlRangeDescription> ranges;
    std::span<const IOAudio2SelectorItemDescription> items;
    std::span<const std::uint32_t> property_selectors { };
    bool multi_selector { };
};

struct IOAudio2DeviceDescription {
    std::optional<std::string_view> name;
    std::string_view manufacturer;
    std::string_view uid;
    std::uint32_t transport_type;
    std::uint32_t io_buffer_frame_size;
    std::span<const IOAudio2StreamDescription> streams;
    std::span<const IOAudio2ControlDescription> controls;
    std::uint32_t input_latency { };
    std::uint32_t output_latency { };
    std::uint32_t input_safety_offset { };
    std::uint32_t output_safety_offset { };
    std::optional<std::uint32_t> clock_domain { };
};

class IOAudio2DeviceCatalog final {
public:
    [[nodiscard]] static std::span<const IOAudio2DeviceDescription> devices(
        AudioHardwareProfile profile = AudioHardwareProfile::CodecBaseband);
    [[nodiscard]] static const IOAudio2DeviceDescription* find(
        std::string_view uid,
        AudioHardwareProfile profile = AudioHardwareProfile::CodecBaseband);
};

}
