// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Dispatch virtual HID user-client requests and event-queue
// notifications.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/iokit/Kernel/IODataQueue.cpp

#include "kernel/kernel_iokit_hid.hpp"

#include "foundation/address_space.hpp"
#include "mach/device_mig_ids.hpp"
#include "kernel/iokit_abi.hpp"
#include "kernel/kernel_shared_state.hpp"
#include "mach/mig_wire_abi.hpp"
#include "foundation/output.hpp"

#include "../../mach/support.hpp"

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <map>
#include <mutex>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <utility>

namespace shade::kernel_iokit::hid {
namespace {

    namespace device_mig = xnu::mig::device;

    constexpr std::uint32_t mach_receive_invalid_data = 0x10004008U;
    constexpr std::uint32_t simple_reply_size = 36U;
    constexpr std::uint32_t map_reply_size = 44U;
    constexpr std::uint32_t mig_reply_identifier_delta = 100U;
    constexpr std::uint32_t hid_mapping_search_base = 0x1f000000U;
    // IODataQueue's notification source uses memory type zero on this
    // firmware generation. It is the driver's queue mapping, not a graphics
    // shared-memory selector.
    constexpr std::uint32_t hid_memory_type = 0U;
    constexpr std::uint32_t hid_map_options = 1U;
    constexpr std::uint32_t hid_queue_size = 0x1000U;
    constexpr std::uint32_t maximum_mapping_size = 16U * 1024U * 1024U;
    constexpr std::string_view provider_class_property { "IOProviderClass" };
    constexpr std::string_view hid_support_property { "HIDServiceSupport" };
    constexpr std::string_view plugin_types_property { "IOCFPlugInTypes" };
    constexpr std::string_view plugin_type_uuid {
        "0516B563-B15B-11DA-96EB-0014519758EF"
    };
    constexpr std::string_view plugin_path {
        "AppleMultitouchSPI.kext/PlugIns/MultitouchHID.plugin"
    };

    std::string serialized_text(std::span<const std::byte> bytes)
    {
        std::string text;
        text.reserve(bytes.size());
        for (const auto byte : bytes) {
            if (byte == std::byte { 0 })
                break;
            text.push_back(static_cast<char>(std::to_integer<unsigned char>(
                byte)));
        }
        return text;
    }

    bool matching_true_property(std::string_view text, std::string_view key)
    {
        const auto key_marker = "<key>" + std::string { key } + "</key>";
        const auto key_offset = text.find(key_marker);
        if (key_offset == std::string_view::npos)
            return false;
        const auto value_offset = key_offset + key_marker.size();
        const auto next_key = text.find("<key>", value_offset);
        const auto true_value = text.find("<true/>", value_offset);
        return true_value != std::string_view::npos &&
               (next_key == std::string_view::npos || true_value < next_key);
    }

    std::optional<std::string> matching_string(std::string_view text,
        std::string_view key)
    {
        const auto key_marker = "<key>" + std::string { key } + "</key>";
        const auto key_offset = text.find(key_marker);
        if (key_offset == std::string_view::npos)
            return std::nullopt;
        const auto string_offset = text.find("<string", key_offset +
                                                    key_marker.size());
        if (string_offset == std::string_view::npos)
            return std::nullopt;
        const auto value_offset = text.find('>', string_offset);
        const auto end_offset = text.find("</string>", value_offset + 1U);
        if (value_offset == std::string_view::npos ||
            end_offset == std::string_view::npos)
            return std::nullopt;
        return std::string { text.substr(value_offset + 1U,
            end_offset - value_offset - 1U) };
    }

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

    KernelSharedState::IOKitRegistryProperty boolean_property(bool value)
    {
        return { KernelSharedState::IOKitRegistryProperty::Kind::Boolean,
            { value ? std::byte { 1 } : std::byte { 0 } } };
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

    KernelSharedState::IOKitRegistryProperty dictionary_property(
        std::map<std::string, KernelSharedState::IOKitRegistryProperty> value)
    {
        KernelSharedState::IOKitRegistryProperty property;
        property.kind =
            KernelSharedState::IOKitRegistryProperty::Kind::Dictionary;
        property.dictionary_value = std::move(value);
        return property;
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
        return 0U;
    }

    std::uint32_t write_simple_reply(AddressSpace& memory,
        std::uint32_t address, std::uint32_t local_port,
        std::uint32_t message_id, std::uint32_t result)
    {
        const std::array<std::uint32_t,
            simple_reply_size / sizeof(std::uint32_t)>
            reply { darwin::mig_wire::message_bits(
                        darwin::mig_wire::disposition_move_send_once),
                simple_reply_size, local_port, 0U, 0U,
                message_id + mig_reply_identifier_delta, 0U, 1U, result };
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
                map_reply_size, local_port, 0U, 0U,
                message_id + mig_reply_identifier_delta, 0U, 1U, result,
                mapped_address, mapped_size };
        return write_reply(memory, address, reply);
    }

    bool is_hid_connection_locked(const KernelSharedState& state,
        const ProcessContext& process, std::uint32_t connection_object)
    {
        const auto connection = state.iokit_connections.find(connection_object);
        if (connection == state.iokit_connections.end() ||
            connection->second.owner_pid != process.pid) {
            return false;
        }
        const auto service =
            state.iokit_services.find(connection->second.service_port);
        return service != state.iokit_services.end() &&
               service->second.user_client_kind ==
                   KernelSharedState::IOKitUserClientKind::MultitouchHid;
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

    std::optional<std::uint32_t> rounded_mapping_size(
        std::uint32_t requested_size)
    {
        const auto size = std::max(requested_size, hid_queue_size);
        if (size > maximum_mapping_size)
            return std::nullopt;
        const auto rounded =
            (static_cast<std::uint64_t>(size) + AddressSpace::page_size - 1U) &
            ~(static_cast<std::uint64_t>(AddressSpace::page_size) - 1U);
        if (rounded > maximum_mapping_size ||
            rounded > std::numeric_limits<std::uint32_t>::max()) {
            return std::nullopt;
        }
        return static_cast<std::uint32_t>(rounded);
    }

    std::optional<std::uint32_t> handle_notification_port_request(
        AddressSpace& memory, Output& output, KernelSharedState& state,
        const ProcessContext& process, std::uint32_t message_id,
        std::uint32_t message_address, std::uint32_t send_size,
        std::uint32_t receive_size, std::uint32_t connection_object,
        std::uint32_t local_port)
    {
        if (message_id != device_mig::id(
                device_mig::Routine::io_connect_set_notification_port)) {
            return std::nullopt;
        }
        {
            std::lock_guard lock { state.mach_mutex };
            if (!is_hid_connection_locked(state, process, connection_object))
                return std::nullopt;
        }
        if (send_size < 56U || receive_size < simple_reply_size)
            return mach_receive_invalid_data;

        const auto descriptor_count =
            memory.read32(message_address +
                          darwin::mig_wire::complex_descriptor_count_offset)
                .value_or(0U);
        const auto notification_name = memory.read32(message_address +
            device_mig::io_connect_set_notification_port_arguments[2]
                .request_offset).value_or(0U);
        const auto notification_type = memory.read32(message_address +
            device_mig::io_connect_set_notification_port_arguments[1]
                .request_offset).value_or(0U);
        const auto reference = memory.read32(message_address +
            device_mig::io_connect_set_notification_port_arguments[3]
                .request_offset).value_or(0U);
        const auto descriptor_metadata = memory.read32(message_address +
            darwin::mig_wire::descriptor_metadata_offset(0)).value_or(0U);
        constexpr std::uint32_t port_descriptor_semantic_mask = 0xffff0000U;
        const auto expected_descriptor = darwin::mig_wire::port_descriptor_metadata(
            darwin::mig_wire::disposition_make_send);
        if (descriptor_count != 1U || notification_name == 0U ||
            (descriptor_metadata & port_descriptor_semantic_mask) !=
                (expected_descriptor & port_descriptor_semantic_mask)) {
            return write_simple_reply(memory, message_address, local_port,
                message_id, iokit_abi::bad_argument);
        }

        std::lock_guard lock { state.mach_mutex };
        if (!is_hid_connection_locked(state, process, connection_object))
            return write_simple_reply(memory, message_address, local_port,
                message_id, iokit_abi::unsupported);
        const auto notification_object =
            state.mach_namespaces.resolve(process.pid, notification_name)
                .value_or(0U);
        if (notification_object == 0U ||
            !state.mach_port_objects.contains(notification_object)) {
            return write_simple_reply(memory, message_address, local_port,
                message_id, iokit_abi::bad_argument);
        }
        auto& connection = state.iokit_multitouch_hid_connections[
            connection_object];
        connection.notification_port = notification_object;
        connection.notification_type = notification_type;
        connection.registration_reference = reference;
        output.write("[iokit-hid] notification-port pid=" +
                     std::to_string(process.pid) + " connection-object=" +
                     std::to_string(connection_object) + " port-object=" +
                     std::to_string(notification_object) + "\n");
        return write_simple_reply(memory, message_address, local_port,
            message_id, iokit_abi::success);
    }

    std::optional<std::uint32_t> handle_map_memory_request(AddressSpace& memory,
        Output& output, KernelSharedState& state,
        const ProcessContext& process, std::uint32_t message_id,
        std::uint32_t message_address, std::uint32_t send_size,
        std::uint32_t receive_size, std::uint32_t connection_object,
        std::uint32_t local_port)
    {
        if (message_id !=
            device_mig::id(device_mig::Routine::io_connect_map_memory)) {
            return std::nullopt;
        }
        if (send_size < 64U || receive_size < map_reply_size)
            return mach_receive_invalid_data;
        const auto descriptor_count =
            memory.read32(message_address +
                          darwin::mig_wire::complex_descriptor_count_offset)
                .value_or(0U);
        const auto memory_type = memory.read32(message_address +
            device_mig::io_connect_map_memory_arguments[1].request_offset)
            .value_or(~0U);
        const auto task_name = memory.read32(message_address +
            device_mig::io_connect_map_memory_arguments[2].request_offset)
            .value_or(0U);
        const auto requested_size = memory.read32(message_address +
            device_mig::io_connect_map_memory_arguments[4].request_offset)
            .value_or(0U);
        const auto flags = memory.read32(message_address +
            device_mig::io_connect_map_memory_arguments[5].request_offset)
            .value_or(0U);
        const auto mapped_size = rounded_mapping_size(requested_size);
        if (descriptor_count != 1U || memory_type != hid_memory_type ||
            task_name == 0U || flags != hid_map_options || !mapped_size) {
            return write_map_reply(memory, message_address, local_port,
                message_id,
                mapped_size ? iokit_abi::bad_argument : iokit_abi::no_memory,
                0U, 0U);
        }

        std::uint32_t mapped_address = 0U;
        {
            std::lock_guard lock { state.mach_mutex };
            if (!is_hid_connection_locked(state, process, connection_object) ||
                !request_targets_current_task_locked(state, process,
                    task_name)) {
                return write_map_reply(memory, message_address, local_port,
                    message_id, iokit_abi::bad_argument, 0U, 0U);
            }
            auto& connection =
                state.iokit_multitouch_hid_connections[connection_object];
            const auto existing = connection.memory_mappings.find(memory_type);
            if (existing != connection.memory_mappings.end() &&
                existing->second.address != 0U &&
                memory.mapped(existing->second.address,
                    existing->second.mapped_size)) {
                mapped_address = existing->second.address;
            } else {
                if (existing != connection.memory_mappings.end())
                    connection.memory_mappings.erase(existing);
                const auto region = mach_support::find_free_guest_region(
                    memory, hid_mapping_search_base, *mapped_size);
                if (!region || !memory.map(*region, *mapped_size,
                        MemoryPermission::Read | MemoryPermission::Write)) {
                    return write_map_reply(memory, message_address, local_port,
                        message_id, iokit_abi::no_memory, 0U, 0U);
                }
                mapped_address = *region;
                connection.memory_mappings.emplace(memory_type,
                    KernelSharedState::IOKitMultitouchHidConnectionState::
                        MemoryMapping { mapped_address, *mapped_size,
                            *mapped_size });
            }
        }
        output.write("[iokit-hid] map pid=" + std::to_string(process.pid) +
                     " connection-object=" + std::to_string(connection_object) +
                     " address=" + std::to_string(mapped_address) +
                     " bytes=" + std::to_string(*mapped_size) + "\n");
        return write_map_reply(memory, message_address, local_port, message_id,
            iokit_abi::success, mapped_address, *mapped_size);
    }

    std::optional<std::uint32_t> handle_unmap_memory_request(
        AddressSpace& memory, Output& output, KernelSharedState& state,
        const ProcessContext& process, std::uint32_t message_id,
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
            memory.read32(message_address +
                          darwin::mig_wire::complex_descriptor_count_offset)
                .value_or(0U);
        const auto memory_type = memory.read32(message_address +
            device_mig::io_connect_unmap_memory_arguments[1].request_offset)
            .value_or(~0U);
        const auto task_name = memory.read32(message_address +
            device_mig::io_connect_unmap_memory_arguments[2].request_offset)
            .value_or(0U);
        const auto requested_address = memory.read32(message_address +
            device_mig::io_connect_unmap_memory_arguments[3].request_offset)
            .value_or(0U);
        KernelSharedState::IOKitMultitouchHidConnectionState::MemoryMapping
            mapping;
        {
            std::lock_guard lock { state.mach_mutex };
            if (!is_hid_connection_locked(state, process, connection_object) ||
                !request_targets_current_task_locked(state, process, task_name) ||
                descriptor_count != 1U || memory_type != hid_memory_type ||
                task_name == 0U || requested_address == 0U) {
                return write_simple_reply(memory, message_address, local_port,
                    message_id, iokit_abi::bad_argument);
            }
            auto connection =
                state.iokit_multitouch_hid_connections.find(connection_object);
            if (connection == state.iokit_multitouch_hid_connections.end())
                return write_simple_reply(memory, message_address, local_port,
                    message_id, iokit_abi::bad_argument);
            const auto found = connection->second.memory_mappings.find(
                memory_type);
            if (found == connection->second.memory_mappings.end() ||
                found->second.address != requested_address) {
                return write_simple_reply(memory, message_address, local_port,
                    message_id, iokit_abi::bad_argument);
            }
            mapping = found->second;
            connection->second.memory_mappings.erase(found);
        }
        const auto unmapped = memory.unmap(mapping.address, mapping.mapped_size);
        output.write("[iokit-hid] unmap pid=" + std::to_string(process.pid) +
                     " connection-object=" + std::to_string(connection_object) +
                     " result=" + std::to_string(unmapped) + "\n");
        return write_simple_reply(memory, message_address, local_port,
            message_id, unmapped ? iokit_abi::success : iokit_abi::bad_argument);
    }

} // namespace

bool matches_service(std::span<const std::byte> matching)
{
    const auto text = serialized_text(matching);
    const auto provider = matching_string(text, provider_class_property);
    return provider && *provider == "IOService" &&
           matching_true_property(text, hid_support_property);
}

std::uint32_t ensure_service_locked(KernelSharedState& state,
    std::uint32_t parent_object)
{
    if (state.multitouch_hid_service != 0U)
        return state.multitouch_hid_service;

    const auto object = state.allocate_mach_object();
    state.multitouch_hid_service = object;
    static_cast<void>(state.mach_port_objects.create(object));
    state.mach_queues.try_emplace(object);

    std::map<std::string, KernelSharedState::IOKitRegistryProperty> properties;
    properties.emplace("HIDServiceSupport", boolean_property(true));
    properties.emplace("IOProviderClass", string_property("IOService"));
    properties.emplace("IOClass", string_property(service_class));
    properties.emplace("Transport", string_property("SPI"));
    properties.emplace("Max Packet Size", number_property(512U));
    properties.emplace("parser-type", number_property(1U));
    properties.emplace("forced-display-width",
        number_property(state.user_interface_geometry.width));
    properties.emplace("forced-display-height",
        number_property(state.user_interface_geometry.height));
    properties.emplace("IORegistryEntryID", number64_property(object));
    properties.emplace("IOCFPlugInTypes", dictionary_property({
        { std::string { plugin_type_uuid }, string_property(plugin_path) }
    }));

    state.iokit_services.emplace(object,
        KernelSharedState::IOKitService { std::string { service_class },
            { "IOService" }, std::move(properties),
            "IOService:/IOPlatformExpertDevice/AppleMultitouchSPI",
            parent_object,
            KernelSharedState::IOKitUserClientKind::MultitouchHid });
    return object;
}

std::optional<MethodResult> dispatch_connect_method(KernelSharedState& state,
    const ProcessContext& process, std::uint32_t connection_object,
    std::uint32_t selector, std::span<const std::uint64_t> scalar_input,
    std::span<const std::byte> inband_input,
    std::uint32_t scalar_output_capacity,
    std::uint32_t inband_output_capacity)
{
    std::lock_guard lock { state.mach_mutex };
    if (!is_hid_connection_locked(state, process, connection_object))
        return std::nullopt;

    // MultitouchSupport uses the two driver-control selectors below for the
    // stock SPI endpoint: selector 0 on the direct path and selector 0x15
    // when the endpoint has the request gate enabled. The virtual queue is
    // mapped separately; no guest-facing event format is fabricated here.
    if (selector == 0U || selector == 0x15U) {
        if (scalar_input.size() != 1U || scalar_input.front() != 1U ||
            !inband_input.empty() || inband_output_capacity != 0U ||
            scalar_output_capacity > 16U) {
            return MethodResult { iokit_abi::bad_argument, { }, { } };
        }
        state.iokit_multitouch_hid_connections[connection_object].started =
            true;
        return MethodResult { iokit_abi::success, { }, { } };
    }
    return MethodResult { iokit_abi::unsupported, { }, { } };
}

std::optional<std::uint32_t> handle_mach_request(AddressSpace& memory,
    Output& output, KernelSharedState& state, const ProcessContext& process,
    std::uint32_t message_id, std::uint32_t message_address,
    std::uint32_t send_size, std::uint32_t receive_size,
    std::uint32_t connection_object, std::uint32_t local_port)
{
    {
        std::lock_guard lock { state.mach_mutex };
        if (!is_hid_connection_locked(state, process, connection_object))
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
        message_id, message_address, send_size, receive_size,
        connection_object, local_port);
}

void close_connection(AddressSpace& memory, KernelSharedState& state,
    std::uint32_t connection_object)
{
    std::vector<KernelSharedState::IOKitMultitouchHidConnectionState::
        MemoryMapping> mappings;
    {
        std::lock_guard lock { state.mach_mutex };
        const auto connection =
            state.iokit_multitouch_hid_connections.find(connection_object);
        if (connection == state.iokit_multitouch_hid_connections.end())
            return;
        for (const auto& [memory_type, mapping] :
            connection->second.memory_mappings) {
            static_cast<void>(memory_type);
            mappings.push_back(mapping);
        }
        state.iokit_multitouch_hid_connections.erase(connection);
    }
    for (const auto& mapping : mappings) {
        if (mapping.address != 0U && mapping.mapped_size != 0U &&
            memory.mapped(mapping.address, mapping.mapped_size)) {
            static_cast<void>(memory.unmap(mapping.address, mapping.mapped_size));
        }
    }
}

} // namespace shade::kernel_iokit::hid
