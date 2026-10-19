// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Resolve the firmware IOKit audio method and memory-map capability
// profile.

#include "kernel/kernel_iokit_audio_abi.hpp"

namespace shade::kernel_iokit::audio {
namespace {

    constexpr IOKitAudioAbi io_audio2_abi{
    .service_class = "IOAudio2Device",
    .registry_path = "IOService:/IOAudio2Device",
    .service_type = 0,
    .notification_type = 0,
    .registry =
        {
            .device_name = "device name",
            .device_manufacturer = "device manufacturer",
            .device_uid = "device UID",
            .transport_type = "transport type",
            .clock_domain = "clock domain",
            .exclusive_access_owner = "exclusive access owner",
            .io_buffer_frame_size = "io buffer frame size",
            .input_safety_offset = "input safety offset",
            .output_safety_offset = "output safety offset",
            .input_latency = "input latency",
            .output_latency = "output latency",
            .sample_rate = "sample rate",
            .is_running = "is running",
            .input_streams = "input streams",
            .output_streams = "output streams",
            .controls = "controls",
            .stream_id = "stream ID",
            .starting_channel = "starting channel",
            .current_format = "current format",
            .available_formats = "available formats",
            .buffer_mapping_options = "buffer mapping options",
            .format_id = "format ID",
            .format_flags = "format flags",
            .bytes_per_packet = "bytes per packet",
            .frames_per_packet = "frames per packet",
            .bytes_per_frame = "bytes per frame",
            .channels_per_frame = "channels per frame",
            .bits_per_channel = "bits per channel",
            .minimum_sample_rate = "min sample rate",
            .maximum_sample_rate = "max sample rate",
            .control_id = "control ID",
            .control_base_class = "base class",
            .control_class = "class",
            .control_scope = "scope",
            .control_element = "element",
            .control_read_only = "read only",
            .control_variant = "variant",
            .control_multi_selector = "multi-selector",
            .control_name = "name",
            .control_value = "value",
            .control_selectors = "selectors",
            .control_property_selectors = "property selectors",
            .control_selector_kind = "kind",
            .control_transfer_function = "transfer function",
            .control_range_map = "range map",
            .control_range_start_integer = "start int value",
            .control_range_start_db = "start db value",
            .control_range_integer_steps = "integer steps",
            .control_range_db_per_step = "db per step",
        },
    .selectors =
        {
            .start = 0,
            .stop = 1,
            .set_control_value = 2,
            .set_nominal_sample_rate = 4,
            .set_stream_current_format = 5,
            .set_stream_active = 6,
        },
    .memory =
        {
            .engine_status = 0,
            .engine_status_size = 24,
            .stream_base = 0x10000000U,
            .map_options = 1,
        },
};

} // namespace

std::uint32_t IOKitAudioAbi::stream_memory_type(
    std::uint32_t stream_id) const
{
    return memory.stream_base + stream_id;
}

std::optional<std::uint32_t> IOKitAudioAbi::stream_id_for_memory_type(
    std::uint32_t memory_type) const
{
    if (memory_type <= memory.stream_base)
        return std::nullopt;
    return memory_type - memory.stream_base;
}

const IOKitAudioAbi& IOKitAudioAbi::io_audio2()
{
    return io_audio2_abi;
}

} // namespace shade::kernel_iokit::audio
