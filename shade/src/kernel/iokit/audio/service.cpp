// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Dispatch virtual IOKit audio user-client requests and stream
// operations.

#include "kernel/kernel_iokit_audio.hpp"
#include "property_notifications.hpp"

#include "foundation/address_space.hpp"
#include "mach/device_mig_ids.hpp"
#include "kernel/iokit_abi.hpp"
#include "kernel/kernel_iokit_audio_device_catalog.hpp"
#include "kernel/kernel_iokit_audio_abi.hpp"
#include "kernel/kernel_shared_state.hpp"
#include "mach/mig_wire_abi.hpp"
#include "foundation/output.hpp"

#include "../../mach/support.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <map>
#include <mutex>
#include <span>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace shade::kernel_iokit::audio {
namespace {

    namespace device_mig = xnu::mig::device;

    constexpr std::uint32_t mach_receive_invalid_data = 0x10004008U;
    constexpr std::uint32_t mig_reply_identifier_delta = 100;
    constexpr std::uint32_t simple_reply_size = 36;
    constexpr std::uint32_t map_reply_size = 44;
    constexpr std::uint32_t audio_mapping_search_base = 0x1e000000U;
    constexpr std::uint32_t linear_pcm_format = 0x6c70636dU; // 'lpcm'
    constexpr std::uint32_t linear_pcm_flags = 0x0cU;
    constexpr std::uint32_t stream_format_size = 40;

    std::vector<std::byte> bytes_from_string(std::string_view value)
    {
        std::vector<std::byte> bytes(value.size());
        std::transform(value.begin(), value.end(), bytes.begin(),
            [](char character) { return static_cast<std::byte>(character); });
        return bytes;
    }

    KernelSharedState::IOKitRegistryProperty string_property(
        std::string_view value)
    {
        return { KernelSharedState::IOKitRegistryProperty::Kind::String,
            bytes_from_string(value) };
    }

    KernelSharedState::IOKitRegistryProperty number_property(
        std::uint32_t value)
    {
        std::vector<std::byte> bytes(sizeof(value));
        for (std::size_t index = 0; index < bytes.size(); ++index)
            bytes[index] = static_cast<std::byte>(value >> (index * 8U));
        return { KernelSharedState::IOKitRegistryProperty::Kind::Number,
            std::move(bytes) };
    }

    KernelSharedState::IOKitRegistryProperty number64_property(
        std::uint64_t value)
    {
        std::vector<std::byte> bytes(sizeof(value));
        for (std::size_t index = 0; index < bytes.size(); ++index)
            bytes[index] = static_cast<std::byte>(value >> (index * 8U));
        return { KernelSharedState::IOKitRegistryProperty::Kind::Number,
            std::move(bytes) };
    }

    constexpr std::uint64_t fixed_sample_rate(std::uint32_t sample_rate)
    {
        return static_cast<std::uint64_t>(sample_rate) << 32U;
    }

    KernelSharedState::IOKitRegistryProperty boolean_property(bool value)
    {
        return { KernelSharedState::IOKitRegistryProperty::Kind::Boolean,
            { value ? std::byte { 1 } : std::byte { 0 } } };
    }

    KernelSharedState::IOKitRegistryProperty array_property(
        std::vector<KernelSharedState::IOKitRegistryProperty> value)
    {
        KernelSharedState::IOKitRegistryProperty property;
        property.kind = KernelSharedState::IOKitRegistryProperty::Kind::Array;
        property.array_value = std::move(value);
        return property;
    }

    KernelSharedState::IOKitRegistryProperty dictionary_property(
        std::map<std::string, KernelSharedState::IOKitRegistryProperty> value)
    {
        KernelSharedState::IOKitRegistryProperty property;
        property.kind =
            KernelSharedState::IOKitRegistryProperty::Kind::Dictionary;
        property.dictionary_value = std::move(value);
        return property;
    }

    const IOAudio2StreamDescription* find_stream(
        const IOAudio2DeviceDescription& device, std::uint32_t identifier)
    {
        const auto stream =
            std::find_if(device.streams.begin(), device.streams.end(),
                [identifier](const IOAudio2StreamDescription& candidate) {
                    return candidate.identifier == identifier;
                });
        return stream == device.streams.end() ? nullptr : &*stream;
    }

    const IOAudio2ControlDescription* find_control(
        const IOAudio2DeviceDescription& device, std::uint32_t identifier)
    {
        const auto control =
            std::find_if(device.controls.begin(), device.controls.end(),
                [identifier](const IOAudio2ControlDescription& candidate) {
                    return candidate.identifier == identifier;
                });
        return control == device.controls.end() ? nullptr : &*control;
    }

    bool valid_control_value(
        const IOAudio2ControlDescription& control, std::uint32_t value)
    {
        if (control.read_only)
            return false;
        if (!control.items.empty()) {
            return std::ranges::any_of(control.items,
                [value](const IOAudio2SelectorItemDescription& item) {
                    return item.value == value;
                });
        }
        if (!control.ranges.empty()) {
            return std::ranges::any_of(control.ranges,
                [value](const IOAudio2ControlRangeDescription& range) {
                    const auto maximum =
                        static_cast<std::uint64_t>(range.start_integer_value) +
                        range.integer_steps;
                    return value >= range.start_integer_value &&
                           value <= maximum;
                });
        }
        return value <= 1U;
    }

    std::uint32_t read_u32(std::span<const std::byte> bytes, std::size_t offset)
    {
        std::uint32_t value = 0;
        for (std::size_t index = 0; index < sizeof(value); ++index) {
            value |= std::to_integer<std::uint32_t>(bytes[offset + index])
                     << (index * 8U);
        }
        return value;
    }

    double read_fixed_sample_rate(
        std::span<const std::byte> bytes, std::size_t offset)
    {
        std::uint64_t bits = 0;
        for (std::size_t index = 0; index < sizeof(bits); ++index) {
            bits |= std::to_integer<std::uint64_t>(bytes[offset + index])
                    << (index * 8U);
        }
        // IOAudio2 carries sample rates as unsigned 32.32 fixed point,
        // including the physical stream format and nominal-rate setter.
        return static_cast<double>(bits) / 4294967296.0;
    }

    bool valid_stream_format(std::span<const std::byte> format)
    {
        if (format.size() != stream_format_size)
            return false;
        const auto sample_rate = read_fixed_sample_rate(format, 0);
        const auto format_id = read_u32(format, 8);
        const auto format_flags = read_u32(format, 12);
        const auto bytes_per_packet = read_u32(format, 16);
        const auto frames_per_packet = read_u32(format, 20);
        const auto bytes_per_frame = read_u32(format, 24);
        const auto channels_per_frame = read_u32(format, 28);
        const auto bits_per_channel = read_u32(format, 32);
        return std::isfinite(sample_rate) && sample_rate >= 4'000.0 &&
               sample_rate <= 192'000.0 && format_id == linear_pcm_format &&
               (format_flags & linear_pcm_flags) == linear_pcm_flags &&
               frames_per_packet != 0 && channels_per_frame >= 1 &&
               channels_per_frame <= 8 && bits_per_channel == 16 &&
               bytes_per_frame == channels_per_frame * sizeof(std::int16_t) &&
               bytes_per_packet == bytes_per_frame * frames_per_packet;
    }

    KernelSharedState::IOKitRegistryProperty stream_format_property(
        const IOKitAudioAbi& profile,
        const IOAudio2StreamFormatDescription& format, bool ranged = false)
    {
        std::map<std::string, KernelSharedState::IOKitRegistryProperty>
            properties;
        properties.emplace(profile.registry.sample_rate,
            number64_property(fixed_sample_rate(format.sample_rate)));
        properties.emplace(
            profile.registry.format_id, number_property(format.format_id));
        properties.emplace(profile.registry.format_flags,
            number_property(format.format_flags));
        properties.emplace(profile.registry.bytes_per_packet,
            number_property(format.bytes_per_packet));
        properties.emplace(profile.registry.frames_per_packet,
            number_property(format.frames_per_packet));
        properties.emplace(profile.registry.bytes_per_frame,
            number_property(format.bytes_per_frame));
        properties.emplace(profile.registry.channels_per_frame,
            number_property(format.channels_per_frame));
        properties.emplace(profile.registry.bits_per_channel,
            number_property(format.bits_per_channel));
        if (ranged) {
            properties.emplace(profile.registry.minimum_sample_rate,
                number64_property(fixed_sample_rate(format.sample_rate)));
            properties.emplace(profile.registry.maximum_sample_rate,
                number64_property(fixed_sample_rate(format.sample_rate)));
        }
        return dictionary_property(std::move(properties));
    }

    KernelSharedState::IOKitRegistryProperty streams_property(
        const IOKitAudioAbi& profile,
        const IOAudio2DeviceDescription& device,
        IOAudio2StreamDirection direction)
    {
        std::vector<KernelSharedState::IOKitRegistryProperty> streams;
        streams.reserve(device.streams.size());
        for (const auto& stream : device.streams) {
            if (stream.direction != direction)
                continue;
            std::map<std::string, KernelSharedState::IOKitRegistryProperty>
                properties;
            properties.emplace(
                profile.registry.stream_id, number_property(stream.identifier));
            properties.emplace(profile.registry.starting_channel,
                number_property(stream.starting_channel));
            properties.emplace(profile.registry.buffer_mapping_options,
                number_property(stream.buffer_mapping_options));
            properties.emplace(profile.registry.current_format,
                stream_format_property(profile, stream.format));
            std::vector<KernelSharedState::IOKitRegistryProperty>
                available_formats;
            const auto formats = stream.available_formats.empty()
                                     ? std::span { &stream.format, 1U }
                                     : stream.available_formats;
            available_formats.reserve(formats.size());
            for (const auto& format : formats) {
                available_formats.push_back(
                    stream_format_property(profile, format, true));
            }
            properties.emplace(profile.registry.available_formats,
                array_property(std::move(available_formats)));
            streams.push_back(dictionary_property(std::move(properties)));
        }
        return array_property(std::move(streams));
    }

    KernelSharedState::IOKitRegistryProperty controls_property(
        const IOKitAudioAbi& profile,
        const IOAudio2DeviceDescription& device)
    {
        std::vector<KernelSharedState::IOKitRegistryProperty> controls;
        controls.reserve(device.controls.size());
        for (const auto& control : device.controls) {
            std::vector<KernelSharedState::IOKitRegistryProperty>
                selector_items;
            selector_items.reserve(control.items.size());
            for (const auto& item : control.items) {
                std::map<std::string, KernelSharedState::IOKitRegistryProperty>
                    item_properties;
                item_properties.emplace(
                    profile.registry.control_name, string_property(item.name));
                item_properties.emplace(profile.registry.control_value,
                    number_property(item.value));
                selector_items.push_back(
                    dictionary_property(std::move(item_properties)));
            }

            std::map<std::string, KernelSharedState::IOKitRegistryProperty>
                properties;
            properties.emplace(profile.registry.control_id,
                number_property(control.identifier));
            properties.emplace(profile.registry.control_base_class,
                number_property(control.base_class));
            properties.emplace(profile.registry.control_class,
                number_property(control.control_class));
            properties.emplace(
                profile.registry.control_scope, number_property(control.scope));
            properties.emplace(profile.registry.control_element,
                number_property(control.element));
            properties.emplace(profile.registry.control_read_only,
                boolean_property(control.read_only));
            properties.emplace(
                profile.registry.control_variant, number_property(0));
            if (control.multi_selector) {
                properties.emplace(profile.registry.control_multi_selector,
                    number_property(1));
                properties.emplace(
                    profile.registry.control_value, array_property({ }));
            } else {
                properties.emplace(profile.registry.control_value,
                    number_property(control.value));
            }
            if (!selector_items.empty()) {
                properties.emplace(profile.registry.control_selectors,
                    array_property(std::move(selector_items)));
            }
            if (!control.property_selectors.empty()) {
                std::vector<KernelSharedState::IOKitRegistryProperty> selectors;
                selectors.reserve(control.property_selectors.size());
                for (const auto selector : control.property_selectors)
                    selectors.push_back(number_property(selector));
                properties.emplace(profile.registry.control_property_selectors,
                    array_property(std::move(selectors)));
            }
            if (!control.ranges.empty()) {
                std::vector<KernelSharedState::IOKitRegistryProperty> segments;
                segments.reserve(control.ranges.size());
                for (const auto& range : control.ranges) {
                    std::map<std::string,
                        KernelSharedState::IOKitRegistryProperty>
                        range_properties;
                    range_properties.emplace(
                        profile.registry.control_range_start_integer,
                        number_property(range.start_integer_value));
                    range_properties.emplace(
                        profile.registry.control_range_start_db,
                        number64_property(range.start_db_value));
                    range_properties.emplace(
                        profile.registry.control_range_integer_steps,
                        number_property(range.integer_steps));
                    range_properties.emplace(
                        profile.registry.control_range_db_per_step,
                        number64_property(range.db_per_step));
                    segments.push_back(
                        dictionary_property(std::move(range_properties)));
                }
                properties.emplace(profile.registry.control_transfer_function,
                    number_property(0));
                properties.emplace(profile.registry.control_range_map,
                    array_property(std::move(segments)));
            }
            controls.push_back(dictionary_property(std::move(properties)));
        }
        return array_property(std::move(controls));
    }

    bool contains(std::span<const std::byte> matching, std::string_view value)
    {
        return std::search(matching.begin(), matching.end(), value.begin(),
                   value.end(), [](std::byte byte, char character) {
                       return std::to_integer<unsigned char>(byte) ==
                              static_cast<unsigned char>(character);
                   }) != matching.end();
    }

    bool is_audio_connection_locked(const KernelSharedState& state,
        const ProcessContext& process, std::uint32_t connection_object)
    {
        const auto& profile = IOKitAudioAbi::io_audio2();
        const auto connection = state.iokit_connections.find(connection_object);
        if (connection == state.iokit_connections.end() ||
            connection->second.owner_pid != process.pid ||
            connection->second.type != profile.service_type) {
            return false;
        }
        const auto service =
            state.iokit_services.find(connection->second.service_port);
        return service != state.iokit_services.end() &&
               service->second.user_client_kind ==
                   KernelSharedState::IOKitUserClientKind::Audio &&
               service->second.class_name == profile.service_class;
    }

    const IOAudio2DeviceDescription* device_for_connection_locked(
        const KernelSharedState& state, const ProcessContext& process,
        std::uint32_t connection_object)
    {
        if (!is_audio_connection_locked(state, process, connection_object))
            return nullptr;
        const auto connection = state.iokit_connections.find(connection_object);
        for (const auto& [uid, service_object] : state.ioaudio2_services) {
            if (service_object == connection->second.service_port)
                return IOAudio2DeviceCatalog::find(
                    uid, state.audio_hardware_profile);
        }
        return nullptr;
    }

    bool request_targets_current_task_locked(const KernelSharedState& state,
        const ProcessContext& process, std::uint32_t task_name)
    {
        const auto task_object =
            state.mach_namespaces.resolve(process.pid, task_name).value_or(0);
        const auto owner = state.task_port_pids.find(task_object);
        return owner != state.task_port_pids.end() &&
               owner->second == process.pid;
    }

    template <std::size_t Size>
    std::uint32_t write_reply(AddressSpace& memory, std::uint32_t address,
        const std::array<std::uint32_t, Size>& reply)
    {
        for (std::size_t index = 0; index < reply.size(); ++index) {
            if (!memory.write32(address + static_cast<std::uint32_t>(
                                              index * sizeof(std::uint32_t)),
                    reply[index])) {
                return mach_receive_invalid_data;
            }
        }
        return 0;
    }

    std::uint32_t write_simple_reply(AddressSpace& memory,
        std::uint32_t address, std::uint32_t local_port,
        std::uint32_t message_id, std::uint32_t result)
    {
        const std::array<std::uint32_t,
            simple_reply_size / sizeof(std::uint32_t)>
            reply { darwin::mig_wire::message_bits(
                        darwin::mig_wire::disposition_move_send_once),
                simple_reply_size, local_port, 0, 0,
                message_id + mig_reply_identifier_delta, 0, 1, result };
        return write_reply(memory, address, reply);
    }

    std::uint32_t write_map_reply(AddressSpace& memory, std::uint32_t address,
        std::uint32_t local_port, std::uint32_t message_id,
        std::uint32_t result, std::uint32_t mapped_address,
        std::uint32_t mapped_size)
    {
        const std::array<std::uint32_t, map_reply_size / sizeof(std::uint32_t)>
            reply { darwin::mig_wire::message_bits(
                        darwin::mig_wire::disposition_move_send_once),
                map_reply_size, local_port, 0, 0,
                message_id + mig_reply_identifier_delta, 0, 1, result,
                mapped_address, mapped_size };
        return write_reply(memory, address, reply);
    }

    std::optional<std::uint32_t> handle_notification_port_request(
        AddressSpace& memory, Output& output, KernelSharedState& state,
        ProcessContext& process, std::uint32_t message_id,
        std::uint32_t message_address, std::uint32_t send_size,
        std::uint32_t receive_size, std::uint32_t connection_object,
        std::uint32_t local_port)
    {
        if (message_id !=
            device_mig::id(
                device_mig::Routine::io_connect_set_notification_port)) {
            return std::nullopt;
        }
        if (send_size < 56U || receive_size < simple_reply_size)
            return mach_receive_invalid_data;
        const auto& profile = IOKitAudioAbi::io_audio2();

        const auto descriptor_count =
            memory
                .read32(message_address +
                        darwin::mig_wire::complex_descriptor_count_offset)
                .value_or(0);
        const auto notification_name =
            memory
                .read32(
                    message_address +
                    device_mig::io_connect_set_notification_port_arguments[2]
                        .request_offset)
                .value_or(0);
        const auto notification_type =
            memory
                .read32(
                    message_address +
                    device_mig::io_connect_set_notification_port_arguments[1]
                        .request_offset)
                .value_or(~0U);
        const auto reference =
            memory
                .read32(
                    message_address +
                    device_mig::io_connect_set_notification_port_arguments[3]
                        .request_offset)
                .value_or(0);
        if (descriptor_count != 1U || notification_name == 0 ||
            notification_type != profile.notification_type) {
            return write_simple_reply(memory, message_address, local_port,
                message_id, iokit_abi::bad_argument);
        }

        std::uint32_t notification_object = 0;
        {
            std::lock_guard lock { state.mach_mutex };
            if (!is_audio_connection_locked(state, process, connection_object))
                return std::nullopt;
            notification_object =
                state.mach_namespaces.resolve(process.pid, notification_name)
                    .value_or(0);
            if (notification_object == 0 ||
                !state.mach_port_objects.contains(notification_object)) {
                return write_simple_reply(memory, message_address, local_port,
                    message_id, iokit_abi::bad_argument);
            }
            auto& connection = state.iokit_audio_connections[connection_object];
            connection.notification_port = notification_object;
            connection.notification_type = notification_type;
            connection.registration_reference = reference;
        }
        output.write("[iokit-audio] notification-port pid=" +
                     std::to_string(process.pid) +
                     " connection-object=" + std::to_string(connection_object) +
                     " port-object=" + std::to_string(notification_object) +
                     "\n");
        return write_simple_reply(memory, message_address, local_port,
            message_id, iokit_abi::success);
    }

    std::optional<std::uint32_t> handle_map_memory_request(AddressSpace& memory,
        Output& output, KernelSharedState& state, ProcessContext& process,
        std::uint32_t message_id, std::uint32_t message_address,
        std::uint32_t send_size, std::uint32_t receive_size,
        std::uint32_t connection_object, std::uint32_t local_port)
    {
        if (message_id !=
            device_mig::id(device_mig::Routine::io_connect_map_memory)) {
            return std::nullopt;
        }
        if (send_size < 64U || receive_size < map_reply_size)
            return mach_receive_invalid_data;

        const auto descriptor_count =
            memory
                .read32(message_address +
                        darwin::mig_wire::complex_descriptor_count_offset)
                .value_or(0);
        const auto task_name =
            memory
                .read32(message_address +
                        device_mig::io_connect_map_memory_arguments[2]
                            .request_offset)
                .value_or(0);
        const auto memory_type =
            memory
                .read32(message_address +
                        device_mig::io_connect_map_memory_arguments[1]
                            .request_offset)
                .value_or(~0U);
        const auto flags =
            memory
                .read32(message_address +
                        device_mig::io_connect_map_memory_arguments[5]
                            .request_offset)
                .value_or(0);
        const IOAudio2DeviceDescription* device = nullptr;
        {
            std::lock_guard lock { state.mach_mutex };
            device =
                device_for_connection_locked(state, process, connection_object);
        }
        if (device == nullptr)
            return std::nullopt;
        const auto& profile = IOKitAudioAbi::io_audio2();
        const auto stream_id = profile.stream_id_for_memory_type(memory_type);
        const auto* stream =
            stream_id ? find_stream(*device, *stream_id) : nullptr;
        const auto engine_status = memory_type == profile.memory.engine_status;
        const auto expected_flags = engine_status ? profile.memory.map_options
                                    : stream != nullptr
                                        ? stream->buffer_mapping_options
                                        : 0U;
        if (descriptor_count != 1U || task_name == 0 ||
            (!engine_status && stream == nullptr) || flags != expected_flags) {
            return write_map_reply(memory, message_address, local_port,
                message_id, iokit_abi::bad_argument, 0, 0);
        }

        std::uint32_t mapped_address = 0;
        const auto exposed_size = engine_status
                                      ? profile.memory.engine_status_size
                                      : stream->buffer_size;
        const auto mapped_size = (exposed_size + AddressSpace::page_size - 1U) &
                                 ~(AddressSpace::page_size - 1U);
        {
            std::lock_guard lock { state.mach_mutex };
            if (device_for_connection_locked(
                    state, process, connection_object) != device) {
                return std::nullopt;
            }
            if (!request_targets_current_task_locked(
                    state, process, task_name)) {
                return write_map_reply(memory, message_address, local_port,
                    message_id, iokit_abi::bad_argument, 0, 0);
            }

            auto& connection = state.iokit_audio_connections[connection_object];
            const auto existing = connection.memory_mappings.find(memory_type);
            if (existing != connection.memory_mappings.end() &&
                existing->second.address != 0 &&
                memory.mapped(
                    existing->second.address, existing->second.mapped_size)) {
                mapped_address = existing->second.address;
            } else {
                const auto region = mach_support::find_free_guest_region(
                    memory, audio_mapping_search_base, mapped_size);
                const std::vector<std::byte> initial_contents(exposed_size);
                if (!region ||
                    !memory.map(*region, mapped_size,
                        MemoryPermission::Read | MemoryPermission::Write) ||
                    !memory.copy_in(*region, initial_contents)) {
                    if (region && memory.mapped(*region, mapped_size))
                        static_cast<void>(memory.unmap(*region, mapped_size));
                    return write_map_reply(memory, message_address, local_port,
                        message_id, iokit_abi::bad_argument, 0, 0);
                }
                mapped_address = *region;
                connection.memory_mappings[memory_type] = KernelSharedState::
                    IOKitAudioConnectionState::MemoryMapping { mapped_address,
                        mapped_size, exposed_size };
            }
        }

        output.write("[iokit-audio] map pid=" + std::to_string(process.pid) +
                     " connection-object=" + std::to_string(connection_object) +
                     " type=" + std::to_string(memory_type) +
                     " address=" + std::to_string(mapped_address) +
                     " bytes=" + std::to_string(exposed_size) + "\n");
        return write_map_reply(memory, message_address, local_port, message_id,
            iokit_abi::success, mapped_address, exposed_size);
    }

    std::optional<std::uint32_t> handle_unmap_memory_request(
        AddressSpace& memory, Output& output, KernelSharedState& state,
        ProcessContext& process, std::uint32_t message_id,
        std::uint32_t message_address, std::uint32_t send_size,
        std::uint32_t receive_size, std::uint32_t connection_object,
        std::uint32_t local_port)
    {
        if (message_id !=
            device_mig::id(device_mig::Routine::io_connect_unmap_memory)) {
            return std::nullopt;
        }
        if (send_size < 56U || receive_size < simple_reply_size)
            return mach_receive_invalid_data;

        const auto descriptor_count =
            memory
                .read32(message_address +
                        darwin::mig_wire::complex_descriptor_count_offset)
                .value_or(0);
        const auto task_name =
            memory
                .read32(message_address +
                        device_mig::io_connect_unmap_memory_arguments[2]
                            .request_offset)
                .value_or(0);
        const auto memory_type =
            memory
                .read32(message_address +
                        device_mig::io_connect_unmap_memory_arguments[1]
                            .request_offset)
                .value_or(~0U);
        const auto requested_address =
            memory
                .read32(message_address +
                        device_mig::io_connect_unmap_memory_arguments[3]
                            .request_offset)
                .value_or(0);

        std::uint32_t mapped_size = 0;
        {
            std::lock_guard lock { state.mach_mutex };
            const auto* device =
                device_for_connection_locked(state, process, connection_object);
            if (device == nullptr)
                return std::nullopt;
            const auto connection =
                state.iokit_audio_connections.find(connection_object);
            const auto& profile = IOKitAudioAbi::io_audio2();
            const auto stream_id =
                profile.stream_id_for_memory_type(memory_type);
            const auto known_memory_type =
                memory_type == profile.memory.engine_status ||
                (stream_id && find_stream(*device, *stream_id) != nullptr);
            KernelSharedState::IOKitAudioConnectionState::MemoryMapping mapping;
            if (connection != state.iokit_audio_connections.end()) {
                const auto found =
                    connection->second.memory_mappings.find(memory_type);
                if (found != connection->second.memory_mappings.end())
                    mapping = found->second;
            }
            if (descriptor_count != 1U || task_name == 0 ||
                !known_memory_type ||
                !request_targets_current_task_locked(
                    state, process, task_name) ||
                connection == state.iokit_audio_connections.end() ||
                mapping.address != requested_address ||
                requested_address == 0) {
                return write_simple_reply(memory, message_address, local_port,
                    message_id, iokit_abi::bad_argument);
            }
            mapped_size = mapping.mapped_size;
            connection->second.memory_mappings.erase(memory_type);
        }
        const auto unmapped =
            mapped_size != 0 && memory.unmap(requested_address, mapped_size);
        output.write("[iokit-audio] unmap pid=" + std::to_string(process.pid) +
                     " connection-object=" + std::to_string(connection_object) +
                     " type=" + std::to_string(memory_type) +
                     " result=" + std::to_string(unmapped) + "\n");
        return write_simple_reply(memory, message_address, local_port,
            message_id,
            unmapped ? iokit_abi::success : iokit_abi::bad_argument);
    }

} // namespace

std::optional<MethodResult> dispatch_connect_method(KernelSharedState& state,
    const ProcessContext& process, std::uint32_t connection_object,
    std::uint32_t selector, std::span<const std::uint64_t> scalar_input,
    std::span<const std::byte> inband_input,
    std::uint32_t scalar_output_capacity)
{
    // The generated IOAudio2 client reserves one scalar result slot for void
    // methods. It is a capacity, not part of a method's input contract.
    static_cast<void>(scalar_output_capacity);
    std::lock_guard lock { state.mach_mutex };
    const auto* device =
        device_for_connection_locked(state, process, connection_object);
    if (device == nullptr)
        return std::nullopt;

    const auto& profile = IOKitAudioAbi::io_audio2();
    auto& connection = state.iokit_audio_connections[connection_object];
    const auto service_object = state.iokit_connections.at(connection_object).service_port;
    auto& properties = state.iokit_services.at(service_object).properties;
    const IOAudio2PropertyNotifications notifications { state, service_object };
    if (selector == profile.selectors.start ||
        selector == profile.selectors.stop) {
        if (!scalar_input.empty() || !inband_input.empty()) {
            return MethodResult { iokit_abi::bad_argument, { } };
        }
        connection.running = selector == profile.selectors.start;
        return MethodResult { iokit_abi::success, { } };
    }

    if (selector == profile.selectors.set_control_value) {
        if (scalar_input.size() != 2 || !inband_input.empty() ||
            scalar_input[0] > std::numeric_limits<std::uint32_t>::max() ||
            scalar_input[1] > std::numeric_limits<std::uint32_t>::max()) {
            return MethodResult { iokit_abi::bad_argument, { } };
        }
        const auto identifier = static_cast<std::uint32_t>(scalar_input[0]);
        const auto value = static_cast<std::uint32_t>(scalar_input[1]);
        const auto* control = find_control(*device, identifier);
        if (control == nullptr || !valid_control_value(*control, value))
            return MethodResult { iokit_abi::bad_argument, { } };
        connection.control_values[identifier] = value;
        for (auto& entry : properties
                               .at(std::string { profile.registry.controls })
                               .array_value) {
            auto& fields = entry.dictionary_value;
            if (read_u32(fields
                             .at(std::string { profile.registry.control_id })
                             .value,
                    0) == identifier) {
                fields[std::string { profile.registry.control_value }] =
                    number_property(value);
                break;
            }
        }
        notifications.control_value_changed(identifier, value);
        return MethodResult { iokit_abi::success, { } };
    }

    if (selector == profile.selectors.set_nominal_sample_rate) {
        if (!scalar_input.empty() || inband_input.size() != sizeof(std::uint64_t)) {
            return MethodResult { iokit_abi::bad_argument, { } };
        }
        const auto sample_rate = read_fixed_sample_rate(inband_input, 0);
        if (!std::isfinite(sample_rate) || sample_rate < 4'000.0 ||
            sample_rate > 192'000.0) {
            return MethodResult { iokit_abi::bad_argument, { } };
        }
        connection.nominal_sample_rate.assign(
            inband_input.begin(), inband_input.end());
        properties[std::string { profile.registry.sample_rate }] = {
            KernelSharedState::IOKitRegistryProperty::Kind::Number,
            connection.nominal_sample_rate };
        notifications.publish(0, 0x6e737274U); // nominal sample rate
        return MethodResult { iokit_abi::success, { } };
    }

    if (selector == profile.selectors.set_stream_current_format) {
        // The stream identifier is the required scalar. Accept the extended
        // request's trailing scalar as well as the original one-scalar form.
        if ((scalar_input.size() != 1 && scalar_input.size() != 2) ||
            !valid_stream_format(inband_input) ||
            scalar_input.front() > std::numeric_limits<std::uint32_t>::max()) {
            return MethodResult { iokit_abi::bad_argument, { } };
        }
        const auto stream_id = static_cast<std::uint32_t>(scalar_input.front());
        if (find_stream(*device, stream_id) == nullptr)
            return MethodResult { iokit_abi::bad_argument, { } };
        connection.streams[stream_id].current_format.assign(
            inband_input.begin(), inband_input.end());
        const auto* stream = find_stream(*device, stream_id);
        const auto key = stream->direction == IOAudio2StreamDirection::Input
                             ? profile.registry.input_streams
                             : profile.registry.output_streams;
        for (auto& entry : properties.at(std::string { key }).array_value) {
            auto& fields = entry.dictionary_value;
            if (read_u32(fields.at(std::string { profile.registry.stream_id }).value, 0) != stream_id)
                continue;
            auto& format = fields
                               .at(std::string {
                                   profile.registry.current_format })
                               .dictionary_value;
            format[std::string { profile.registry.sample_rate }] = {
                KernelSharedState::IOKitRegistryProperty::Kind::Number,
                { inband_input.begin(), inband_input.begin() + 8 } };
            const std::array keys { profile.registry.format_id,
                profile.registry.format_flags, profile.registry.bytes_per_packet,
                profile.registry.frames_per_packet, profile.registry.bytes_per_frame,
                profile.registry.channels_per_frame, profile.registry.bits_per_channel };
            for (std::size_t index = 0; index < keys.size(); ++index)
                format[std::string { keys[index] }] =
                    number_property(read_u32(inband_input, 8 + index * 4));
            break;
        }
        notifications.publish(stream_id, 0x70667420U); // physical format

        return MethodResult { iokit_abi::success, { } };
    }

    if (selector == profile.selectors.set_stream_active) {
        if (scalar_input.size() != 2 || !inband_input.empty() ||
            scalar_input[0] > std::numeric_limits<std::uint32_t>::max() ||
            scalar_input[1] > 1) {
            return MethodResult { iokit_abi::bad_argument, { } };
        }
        const auto stream_id = static_cast<std::uint32_t>(scalar_input[0]);
        if (find_stream(*device, stream_id) == nullptr)
            return MethodResult { iokit_abi::bad_argument, { } };
        connection.streams[stream_id].active = scalar_input[1] != 0;
        return MethodResult { iokit_abi::success, { } };
    }

    return MethodResult { iokit_abi::unsupported, { } };
}

bool matches_service(std::span<const std::byte> matching)
{
    return contains(matching, IOKitAudioAbi::io_audio2().service_class);
}

std::vector<std::uint32_t> ensure_services_locked(KernelSharedState& state)
{
    const auto& profile = IOKitAudioAbi::io_audio2();
    std::vector<std::uint32_t> services;
    const auto devices =
        IOAudio2DeviceCatalog::devices(state.audio_hardware_profile);
    services.reserve(devices.size());
    for (const auto& device : devices) {
        const auto cached =
            state.ioaudio2_services.find(std::string { device.uid });
        if (cached != state.ioaudio2_services.end() &&
            state.iokit_services.contains(cached->second)) {
            services.push_back(cached->second);
            continue;
        }

        const auto object = state.allocate_mach_object();
        state.ioaudio2_services[std::string { device.uid }] = object;
        static_cast<void>(state.mach_port_objects.create(object));
        state.mach_queues.try_emplace(object);

        std::map<std::string, KernelSharedState::IOKitRegistryProperty>
            properties;
        if (device.name) {
            properties.emplace(
                profile.registry.device_name, string_property(*device.name));
        }
        properties.emplace(profile.registry.device_manufacturer,
            string_property(device.manufacturer));
        properties.emplace(
            profile.registry.device_uid, string_property(device.uid));
        if (device.transport_type != 0U) {
            properties.emplace(profile.registry.transport_type,
                number_property(device.transport_type));
        }
        if (device.clock_domain) {
            properties.emplace(profile.registry.clock_domain,
                number_property(*device.clock_domain));
        }
        properties.emplace(profile.registry.exclusive_access_owner,
            number_property(~std::uint32_t { 0 }));
        properties.emplace(profile.registry.io_buffer_frame_size,
            number_property(device.io_buffer_frame_size));
        // A device without inputs publishes no input keys at all.
        const auto has_input = std::ranges::any_of(device.streams,
            [](const IOAudio2StreamDescription& stream) {
                return stream.direction == IOAudio2StreamDirection::Input;
            });
        if (has_input) {
            properties.emplace(profile.registry.input_safety_offset,
                number_property(device.input_safety_offset));
        }
        properties.emplace(profile.registry.output_safety_offset,
            number_property(device.output_safety_offset));
        if (has_input) {
            properties.emplace(profile.registry.input_latency,
                number_property(device.input_latency));
        }
        properties.emplace(profile.registry.output_latency,
            number_property(device.output_latency));
        if (!device.streams.empty()) {
            properties.emplace(profile.registry.sample_rate,
                number64_property(fixed_sample_rate(
                    device.streams.front().format.sample_rate)));
        }
        properties.emplace(
            profile.registry.is_running, boolean_property(false));
        if (has_input) {
            properties.emplace(profile.registry.input_streams,
                streams_property(
                    profile, device, IOAudio2StreamDirection::Input));
        }
        properties.emplace(profile.registry.output_streams,
            streams_property(profile, device, IOAudio2StreamDirection::Output));
        properties.emplace(
            profile.registry.controls, controls_property(profile, device));

        state.iokit_services.emplace(
            object, KernelSharedState::IOKitService {
                        std::string { profile.service_class }, { "IOService" },
                        std::move(properties),
                        std::string { profile.registry_path } + "/" +
                            std::string { device.uid },
                        0, KernelSharedState::IOKitUserClientKind::Audio });
        services.push_back(object);
    }
    return services;
}

std::optional<std::uint32_t> handle_mach_request(AddressSpace& memory,
    Output& output, KernelSharedState& state, ProcessContext& process,
    std::uint32_t message_id, std::uint32_t message_address,
    std::uint32_t send_size, std::uint32_t receive_size,
    std::uint32_t connection_object, std::uint32_t local_port)
{
    {
        std::lock_guard lock { state.mach_mutex };
        if (!is_audio_connection_locked(state, process, connection_object))
            return std::nullopt;
    }
    if (const auto result = handle_notification_port_request(memory, output,
            state, process, message_id, message_address, send_size,
            receive_size, connection_object, local_port)) {
        return result;
    }
    if (const auto result = handle_map_memory_request(memory, output, state,
            process, message_id, message_address, send_size, receive_size,
            connection_object, local_port)) {
        return result;
    }
    return handle_unmap_memory_request(memory, output, state, process,
        message_id, message_address, send_size, receive_size, connection_object,
        local_port);
}

void close_connection(AddressSpace& memory, KernelSharedState& state,
    std::uint32_t connection_object)
{
    std::vector<KernelSharedState::IOKitAudioConnectionState::MemoryMapping>
        mappings;
    {
        std::lock_guard lock { state.mach_mutex };
        const auto connection =
            state.iokit_audio_connections.find(connection_object);
        if (connection == state.iokit_audio_connections.end())
            return;
        mappings.reserve(connection->second.memory_mappings.size());
        for (const auto& [memory_type, mapping] :
            connection->second.memory_mappings) {
            static_cast<void>(memory_type);
            mappings.push_back(mapping);
        }
        state.iokit_audio_connections.erase(connection);
    }
    for (const auto& mapping : mappings) {
        if (mapping.address != 0 && mapping.mapped_size != 0 &&
            memory.mapped(mapping.address, mapping.mapped_size)) {
            static_cast<void>(
                memory.unmap(mapping.address, mapping.mapped_size));
        }
    }
}

} // namespace shade::kernel_iokit::audio
