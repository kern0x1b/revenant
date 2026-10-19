// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Dispatch virtual MBX user-client requests and command-buffer
// operations.

#include "kernel/kernel_iokit_mbx.hpp"

#include "foundation/address_space.hpp"
#include "kernel/iokit_abi.hpp"
#include "kernel/kernel_shared_state.hpp"

#include "../../mach/support.hpp"

#include <algorithm>
#include <array>
#include <bit>
#include <limits>
#include <mutex>
#include <string>
#include <utility>
#include <vector>

namespace shade::kernel_iokit::mbx {

namespace {

    enum class Selector : std::uint32_t {
        GetDeviceIdentifier = 0,
        GetCommandQueue = 2,
        AllocateResource = 6,
        ReleaseResource = 7,
    };

    enum class ConnectionType : std::uint32_t {
        Device = 0,
        CommandTransport = 1,
    };

    constexpr std::uint32_t resource_mapping_search_base = 0x1c000000U;
    constexpr std::uint32_t command_queue_mapping_search_base = 0x1b000000U;
    constexpr std::uint32_t resource_description_size = 24U;
    constexpr std::uint32_t maximum_resource_size = 64U * 1024U * 1024U;
    constexpr std::uint32_t command_queue_control_size =
        AddressSpace::page_size;
    constexpr std::uint32_t command_queue_buffer_size = 64U * 1024U;

    void write_word(
        std::span<std::byte> bytes, std::size_t offset, std::uint32_t value)
    {
        for (std::size_t byte = 0; byte < sizeof(value); ++byte) {
            bytes[offset + byte] =
                static_cast<std::byte>((value >> (byte * 8U)) & 0xffU);
        }
    }

    std::optional<std::uint32_t> find_aligned_region(const AddressSpace& memory,
        std::uint32_t mapped_size, std::uint32_t alignment)
    {
        const auto effective_alignment =
            std::max<std::uint32_t>(alignment, AddressSpace::page_size);
        auto search = resource_mapping_search_base;
        while (true) {
            const auto aligned =
                (static_cast<std::uint64_t>(search) + effective_alignment -
                    1U) &
                ~static_cast<std::uint64_t>(effective_alignment - 1U);
            if (aligned > std::numeric_limits<std::uint32_t>::max())
                return std::nullopt;
            const auto region = mach_support::find_free_guest_region(
                memory, static_cast<std::uint32_t>(aligned), mapped_size);
            if (!region)
                return std::nullopt;
            if ((*region & (effective_alignment - 1U)) == 0U)
                return region;
            if (*region > std::numeric_limits<std::uint32_t>::max() -
                              AddressSpace::page_size)
                return std::nullopt;
            search = *region + AddressSpace::page_size;
        }
    }

    MethodResult allocate_resource(AddressSpace& memory,
        KernelSharedState& state, std::uint32_t connection_object,
        std::span<const std::uint64_t> scalar_input,
        std::span<const std::byte> inband_input,
        std::uint32_t scalar_output_capacity,
        std::uint32_t inband_output_capacity)
    {
        if (scalar_input.size() != 3U || !inband_input.empty() ||
            scalar_output_capacity != 0U ||
            inband_output_capacity < resource_description_size ||
            scalar_input[1] == 0U || scalar_input[1] > maximum_resource_size ||
            scalar_input[2] == 0U ||
            scalar_input[2] > std::numeric_limits<std::uint32_t>::max() ||
            !std::has_single_bit(static_cast<std::uint32_t>(scalar_input[2]))) {
            return MethodResult { iokit_abi::bad_argument, { }, { } };
        }

        const auto exposed_size = static_cast<std::uint32_t>(scalar_input[1]);
        const auto alignment = static_cast<std::uint32_t>(scalar_input[2]);
        const auto mapped_size = (exposed_size + AddressSpace::page_size - 1U) &
                                 ~(AddressSpace::page_size - 1U);
        const auto region = find_aligned_region(memory, mapped_size, alignment);
        if (!region || !memory.map(*region, mapped_size,
                           MemoryPermission::Read | MemoryPermission::Write)) {
            return MethodResult { iokit_abi::no_memory, { }, { } };
        }

        auto& connection = state.iokit_mbx_connections[connection_object];
        auto handle = connection.next_resource_handle++;
        while (handle == 0U || connection.resources.contains(handle))
            handle = connection.next_resource_handle++;
        const auto resource_type = static_cast<std::uint32_t>(scalar_input[0]);
        connection.resources.emplace(handle,
            KernelSharedState::IOKitMbxConnectionState::Resource {
                *region, mapped_size, exposed_size, resource_type, alignment });

        std::vector<std::byte> description(resource_description_size);
        write_word(description, 0U, handle);
        write_word(description, 4U, *region);
        // The compatibility renderer shares one guest-visible address space for
        // CPU and emulated-device access. Keeping both addresses identical lets
        // the firmware build its native command stream without a second
        // hardware VM.
        write_word(description, 8U, *region);
        write_word(description, 12U, exposed_size);
        write_word(description, 16U, resource_type);
        write_word(description, 20U, alignment);
        return MethodResult { iokit_abi::success, { }, std::move(description) };
    }

    MethodResult release_resource(AddressSpace& memory,
        KernelSharedState& state, std::uint32_t connection_object,
        std::span<const std::uint64_t> scalar_input,
        std::span<const std::byte> inband_input,
        std::uint32_t scalar_output_capacity,
        std::uint32_t inband_output_capacity)
    {
        if (scalar_input.size() != 1U || !inband_input.empty() ||
            scalar_output_capacity != 0U || inband_output_capacity != 0U ||
            scalar_input[0] > std::numeric_limits<std::uint32_t>::max()) {
            return MethodResult { iokit_abi::bad_argument, { }, { } };
        }
        const auto connection =
            state.iokit_mbx_connections.find(connection_object);
        if (connection == state.iokit_mbx_connections.end())
            return MethodResult { iokit_abi::not_found, { }, { } };
        const auto resource = connection->second.resources.find(
            static_cast<std::uint32_t>(scalar_input[0]));
        if (resource == connection->second.resources.end())
            return MethodResult { iokit_abi::not_found, { }, { } };
        const auto mapping = resource->second;
        connection->second.resources.erase(resource);
        if (mapping.address != 0U && mapping.mapped_size != 0U &&
            memory.mapped(mapping.address, mapping.mapped_size)) {
            static_cast<void>(
                memory.unmap(mapping.address, mapping.mapped_size));
        }
        return MethodResult { iokit_abi::success, { }, { } };
    }

    MethodResult get_command_queue(AddressSpace& memory,
        KernelSharedState& state, std::uint32_t connection_object,
        std::span<const std::uint64_t> scalar_input,
        std::span<const std::byte> inband_input,
        std::uint32_t scalar_output_capacity,
        std::uint32_t inband_output_capacity)
    {
        if (!scalar_input.empty() || !inband_input.empty() ||
            scalar_output_capacity < 1U || inband_output_capacity != 0U) {
            return MethodResult { iokit_abi::bad_argument, { }, { } };
        }

        auto& connection = state.iokit_mbx_connections[connection_object];
        if (connection.command_queue &&
            memory.mapped(connection.command_queue->control_address,
                connection.command_queue->mapped_size)) {
            return MethodResult { iokit_abi::success,
                { connection.command_queue->control_address }, { } };
        }

        constexpr auto mapped_size =
            command_queue_control_size + command_queue_buffer_size;
        const auto region = mach_support::find_free_guest_region(
            memory, command_queue_mapping_search_base, mapped_size);
        if (!region || !memory.map(*region, mapped_size,
                           MemoryPermission::Read | MemoryPermission::Write)) {
            return MethodResult { iokit_abi::no_memory, { }, { } };
        }
        const auto buffer_address = *region + command_queue_control_size;
        if (!memory.write32(*region, command_queue_buffer_size) ||
            !memory.write32(*region + 12U, buffer_address)) {
            static_cast<void>(memory.unmap(*region, mapped_size));
            return MethodResult { iokit_abi::no_memory, { }, { } };
        }
        connection.command_queue =
            KernelSharedState::IOKitMbxConnectionState::CommandQueue { *region,
                buffer_address, mapped_size, command_queue_buffer_size };
        return MethodResult { iokit_abi::success, { *region }, { } };
    }

} // namespace

bool matches_service(std::span<const std::byte> matching)
{
    return std::search(matching.begin(), matching.end(), service_class.begin(),
               service_class.end(), [](std::byte byte, char character) {
                   return std::to_integer<unsigned char>(byte) ==
                          static_cast<unsigned char>(character);
               }) != matching.end();
}

std::uint32_t ensure_service_locked(
    KernelSharedState& state, std::uint32_t platform_expert_object)
{
    const auto existing = std::find_if(state.iokit_services.begin(),
        state.iokit_services.end(), [](const auto& entry) {
            return entry.second.class_name == service_class;
        });
    if (existing != state.iokit_services.end())
        return existing->first;

    const auto object = state.allocate_mach_object();
    static_cast<void>(state.mach_port_objects.create(object));
    state.mach_queues.try_emplace(object);
    state.iokit_services.emplace(
        object, KernelSharedState::IOKitService { std::string { service_class },
                    { "IOService" }, { },
                    "IOService:/IOPlatformExpertDevice/AppleMBXDevice",
                    platform_expert_object,
                    KernelSharedState::IOKitUserClientKind::Mbx });
    return object;
}

std::optional<MethodResult> dispatch_connect_method(AddressSpace& memory,
    KernelSharedState& state, const ProcessContext& process,
    std::uint32_t connection_object, std::uint32_t selector,
    std::span<const std::uint64_t> scalar_input,
    std::span<const std::byte> inband_input,
    std::uint32_t scalar_output_capacity, std::uint32_t inband_output_capacity)
{
    std::lock_guard lock { state.mach_mutex };
    const auto connection = state.iokit_connections.find(connection_object);
    if (connection == state.iokit_connections.end() ||
        connection->second.owner_pid != process.pid)
        return std::nullopt;
    const auto service =
        state.iokit_services.find(connection->second.service_port);
    if (service == state.iokit_services.end() ||
        service->second.user_client_kind !=
            KernelSharedState::IOKitUserClientKind::Mbx)
        return std::nullopt;

    constexpr std::uint64_t integrated_device_identifier = 0U;
    if (connection->second.type ==
        static_cast<std::uint32_t>(ConnectionType::Device)) {
        if (selector ==
            static_cast<std::uint32_t>(Selector::GetDeviceIdentifier)) {
            if (!inband_input.empty() || inband_output_capacity != 0U ||
                !scalar_input.empty() || scalar_output_capacity < 1U)
                return MethodResult { iokit_abi::bad_argument, { }, { } };
            // MBXGLEngine stores this scalar as its selected device identifier.
            // The iPhone1,1 has one integrated MBX device, represented by
            // identifier zero.
            return MethodResult { iokit_abi::success,
                { integrated_device_identifier }, { } };
        }
        if (selector ==
            static_cast<std::uint32_t>(Selector::AllocateResource)) {
            return allocate_resource(memory, state, connection_object,
                scalar_input, inband_input, scalar_output_capacity,
                inband_output_capacity);
        }
        if (selector == static_cast<std::uint32_t>(Selector::ReleaseResource)) {
            return release_resource(memory, state, connection_object,
                scalar_input, inband_input, scalar_output_capacity,
                inband_output_capacity);
        }
    }

    if (connection->second.type ==
        static_cast<std::uint32_t>(ConnectionType::CommandTransport)) {
        if (selector ==
            static_cast<std::uint32_t>(Selector::GetDeviceIdentifier)) {
            if (scalar_input.size() != 2U || scalar_output_capacity != 0U ||
                !inband_input.empty() || inband_output_capacity != 0U ||
                scalar_input[0] != integrated_device_identifier ||
                scalar_input[1] != 0U)
                return MethodResult { iokit_abi::bad_argument, { }, { } };
            // The host GLES backend already owns command submission. This
            // handshake binds the firmware engine to the selected virtual
            // device without duplicating the hardware queue in the guest kernel
            // model.
            return MethodResult { iokit_abi::success, { }, { } };
        }
        if (selector == static_cast<std::uint32_t>(Selector::GetCommandQueue)) {
            return get_command_queue(memory, state, connection_object,
                scalar_input, inband_input, scalar_output_capacity,
                inband_output_capacity);
        }
    }

    return MethodResult { iokit_abi::unsupported, { }, { } };
}

void close_connection(AddressSpace& memory, KernelSharedState& state,
    std::uint32_t connection_object)
{
    std::vector<KernelSharedState::IOKitMbxConnectionState::Resource> resources;
    std::optional<KernelSharedState::IOKitMbxConnectionState::CommandQueue>
        command_queue;
    {
        std::lock_guard lock { state.mach_mutex };
        const auto connection =
            state.iokit_mbx_connections.find(connection_object);
        if (connection == state.iokit_mbx_connections.end())
            return;
        resources.reserve(connection->second.resources.size());
        for (const auto& [handle, resource] : connection->second.resources) {
            static_cast<void>(handle);
            resources.push_back(resource);
        }
        command_queue = connection->second.command_queue;
        state.iokit_mbx_connections.erase(connection);
    }
    for (const auto& resource : resources) {
        if (resource.address != 0U && resource.mapped_size != 0U &&
            memory.mapped(resource.address, resource.mapped_size)) {
            static_cast<void>(
                memory.unmap(resource.address, resource.mapped_size));
        }
    }
    if (command_queue) {
        const auto queue = *command_queue;
        if (queue.control_address != 0U && queue.mapped_size != 0U &&
            memory.mapped(queue.control_address, queue.mapped_size)) {
            static_cast<void>(
                memory.unmap(queue.control_address, queue.mapped_size));
        }
    }
}

} // namespace shade::kernel_iokit::mbx
