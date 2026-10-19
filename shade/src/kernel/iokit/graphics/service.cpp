// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Dispatch virtual IOKit graphics requests and surface-sharing
// operations.

#include "kernel/kernel_iokit_graphics.hpp"

#include "foundation/address_space.hpp"
#include "mach/device_mig_ids.hpp"
#include "kernel/iokit_abi.hpp"
#include "kernel/kernel_shared_state.hpp"
#include "mach/mig_wire_abi.hpp"

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
#include <vector>

namespace shade::kernel_iokit::graphics {
namespace {

    namespace device_mig = xnu::mig::device;

    constexpr std::uint32_t mach_receive_invalid_data = 0x10004008U;
    constexpr std::uint32_t simple_reply_size = 36U;
    constexpr std::uint32_t map_reply_size = 44U;
    constexpr std::uint32_t mig_reply_identifier_delta = 100U;
    constexpr std::uint32_t graphics_mapping_search_base = 0x1d000000U;
    constexpr std::uint32_t maximum_mapping_size = 512U * 1024U * 1024U;

    // These are the memory selectors used by the SGX535 GLEngine/driver pair.
    // They are part of the accelerator user-client ABI, not an application
    // rule.
    constexpr std::uint32_t device_memory_type = 0U;
    constexpr std::uint32_t shared_memory_type = 2U;
    constexpr std::uint32_t map_flags = 1U;
    // The shared-context path writes a 0x4000-byte 16-bit table immediately
    // after the selector-4 reply.  A zero-sized IOConnectMapMemory request is
    // an in/out request for this firmware-owned arena, so expose the smallest
    // extent required by the ABI rather than a single guard page.
    constexpr std::uint32_t minimum_shared_mapping_size = 0x4000U;
    constexpr std::uint32_t shared_context_reply_size =
        3U * sizeof(std::uint32_t);

    enum class Selector : std::uint32_t {
        InitializeLibrary = 1U,
        CreateShared = 0U,
        InitializeContext = 4U,
        GetSharedResource = 7U,
    };

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

    bool contains(std::span<const std::byte> bytes, std::string_view value)
    {
        return std::search(bytes.begin(), bytes.end(), value.begin(),
                   value.end(), [](std::byte byte, char character) {
                       return std::to_integer<unsigned char>(byte) ==
                              static_cast<unsigned char>(character);
                   }) != bytes.end();
    }

    bool is_graphics_connection_locked(const KernelSharedState& state,
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
               service->second.class_name == service_class &&
               service->second.user_client_kind ==
                   KernelSharedState::IOKitUserClientKind::
                       GraphicsAccelerator;
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
        const auto size =
            std::max<std::uint32_t>(requested_size, AddressSpace::page_size);
        if (size > maximum_mapping_size)
            return std::nullopt;
        const auto rounded =
            (static_cast<std::uint64_t>(size) + AddressSpace::page_size - 1U) &
            ~(static_cast<std::uint64_t>(AddressSpace::page_size) - 1U);
        if (rounded > maximum_mapping_size ||
            rounded > std::numeric_limits<std::uint32_t>::max())
            return std::nullopt;
        return static_cast<std::uint32_t>(rounded);
    }

    std::optional<std::uint32_t> handle_map_memory_request(AddressSpace& memory,
        KernelSharedState& state, const ProcessContext& process,
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
        const auto requested_size =
            memory
                .read32(message_address +
                        device_mig::io_connect_map_memory_arguments[4]
                            .request_offset)
                .value_or(0);
        const auto flags =
            memory
                .read32(message_address +
                        device_mig::io_connect_map_memory_arguments[5]
                            .request_offset)
                .value_or(0);
        const auto valid_memory_type = memory_type == device_memory_type ||
                                       memory_type == shared_memory_type;
        const auto effective_requested_size =
            memory_type == shared_memory_type
                ? std::max(requested_size, minimum_shared_mapping_size)
                : requested_size;
        const auto mapped_size = rounded_mapping_size(effective_requested_size);
        if (descriptor_count != 1U || task_name == 0 || !valid_memory_type ||
            flags != map_flags || !mapped_size) {
            return write_map_reply(memory, message_address, local_port,
                message_id,
                mapped_size ? iokit_abi::bad_argument : iokit_abi::no_memory, 0,
                0);
        }

        std::uint32_t mapped_address = 0;
        // IOConnectMapMemory's size argument is in/out.  The SGX shared arena
        // is requested with size zero and the user client returns its actual
        // extent; reporting the request back would make the firmware treat a
        // valid mapping as an empty arena.
        std::uint32_t exposed_size = *mapped_size;
        {
            std::lock_guard lock { state.mach_mutex };
            if (!is_graphics_connection_locked(
                    state, process, connection_object) ||
                !request_targets_current_task_locked(
                    state, process, task_name)) {
                return write_map_reply(memory, message_address, local_port,
                    message_id, iokit_abi::bad_argument, 0, 0);
            }

            auto& connection =
                state.iokit_graphics_connections[connection_object];
            const auto existing = connection.memory_mappings.find(memory_type);
            if (existing != connection.memory_mappings.end() &&
                existing->second.address != 0 &&
                memory.mapped(
                    existing->second.address, existing->second.mapped_size)) {
                mapped_address = existing->second.address;
                exposed_size = existing->second.exposed_size;
            } else {
                if (existing != connection.memory_mappings.end())
                    connection.memory_mappings.erase(existing);
                const auto region = mach_support::find_free_guest_region(
                    memory, graphics_mapping_search_base, *mapped_size);
                if (!region ||
                    !memory.map(*region, *mapped_size,
                        MemoryPermission::Read | MemoryPermission::Write)) {
                    return write_map_reply(memory, message_address, local_port,
                        message_id, iokit_abi::no_memory, 0, 0);
                }
                mapped_address = *region;
                connection.memory_mappings.emplace(memory_type,
                    KernelSharedState::IOKitGraphicsConnectionState::
                        MemoryMapping {
                            mapped_address, *mapped_size, exposed_size });
            }
        }

        return write_map_reply(memory, message_address, local_port, message_id,
            iokit_abi::success, mapped_address, exposed_size);
    }

    std::optional<std::uint32_t> handle_unmap_memory_request(
        AddressSpace& memory, KernelSharedState& state,
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
        if (descriptor_count != 1U || task_name == 0 ||
            (memory_type != device_memory_type &&
                memory_type != shared_memory_type)) {
            return write_simple_reply(memory, message_address, local_port,
                message_id, iokit_abi::bad_argument);
        }

        KernelSharedState::IOKitGraphicsConnectionState::MemoryMapping mapping;
        {
            std::lock_guard lock { state.mach_mutex };
            if (!is_graphics_connection_locked(
                    state, process, connection_object) ||
                !request_targets_current_task_locked(
                    state, process, task_name)) {
                return write_simple_reply(memory, message_address, local_port,
                    message_id, iokit_abi::bad_argument);
            }
            auto connection =
                state.iokit_graphics_connections.find(connection_object);
            if (connection == state.iokit_graphics_connections.end())
                return write_simple_reply(memory, message_address, local_port,
                    message_id, iokit_abi::bad_argument);
            const auto found =
                connection->second.memory_mappings.find(memory_type);
            if (found == connection->second.memory_mappings.end() ||
                found->second.address != requested_address ||
                requested_address == 0) {
                return write_simple_reply(memory, message_address, local_port,
                    message_id, iokit_abi::bad_argument);
            }
            mapping = found->second;
            connection->second.memory_mappings.erase(found);
        }

        const auto unmapped =
            memory.unmap(mapping.address, mapping.mapped_size);
        return write_simple_reply(memory, message_address, local_port,
            message_id,
            unmapped ? iokit_abi::success : iokit_abi::bad_argument);
    }

    std::optional<std::uint32_t> handle_add_client_request(AddressSpace& memory,
        KernelSharedState& state, const ProcessContext& process,
        std::uint32_t message_id, std::uint32_t message_address,
        std::uint32_t send_size, std::uint32_t receive_size,
        std::uint32_t connection_object, std::uint32_t local_port)
    {
        if (message_id !=
            device_mig::id(device_mig::Routine::io_connect_add_client))
            return std::nullopt;
        if (send_size < 40U || receive_size < simple_reply_size)
            return mach_receive_invalid_data;

        const auto client_name =
            memory
                .read32(message_address +
                        device_mig::io_connect_add_client_arguments[1]
                            .request_offset)
                .value_or(0);
        {
            std::lock_guard lock { state.mach_mutex };
            if (!is_graphics_connection_locked(
                    state, process, connection_object))
                return std::nullopt;
            // IOConnectAddClient names the shared connection with a task-local
            // Mach name. Resolve it before recording the relationship; the
            // accelerator does not expose a second service object for this
            // handshake.
            if (const auto client_object =
                    state.mach_namespaces.resolve(process.pid, client_name);
                client_object &&
                is_graphics_connection_locked(state, process, *client_object)) {
                state.iokit_graphics_connections[connection_object]
                    .shared_connection_object = *client_object;
            }
        }
        return write_simple_reply(memory, message_address, local_port,
            message_id, iokit_abi::success);
    }

} // namespace

bool matches_service(std::span<const std::byte> matching)
{
    return contains(matching, service_class);
}

std::uint32_t ensure_service_locked(
    KernelSharedState& state, std::uint32_t platform_expert_object)
{
    const auto existing = std::find_if(state.iokit_services.begin(),
        state.iokit_services.end(), [](const auto& entry) {
            return entry.second.class_name == service_class;
        });
    if (existing != state.iokit_services.end()) {
        existing->second.user_client_kind =
            KernelSharedState::IOKitUserClientKind::GraphicsAccelerator;
        existing->second.properties.insert_or_assign(
            "IOGLESBundleName", string_property(state.graphics_driver_bundle));
        return existing->first;
    }

    const auto object = state.allocate_mach_object();
    static_cast<void>(state.mach_port_objects.create(object));
    state.mach_queues.try_emplace(object);
    std::map<std::string, KernelSharedState::IOKitRegistryProperty> properties;
    properties.emplace(
        "IOGLESBundleName", string_property(state.graphics_driver_bundle));
    state.iokit_services.emplace(object,
        KernelSharedState::IOKitService { std::string { service_class },
            { "IOService" }, std::move(properties),
            "IOService:/IOPlatformExpertDevice/IOAcceleratorES",
            platform_expert_object,
            KernelSharedState::IOKitUserClientKind::GraphicsAccelerator });
    return object;
}

std::optional<MethodResult> dispatch_connect_method(AddressSpace& memory,
    KernelSharedState& state, const ProcessContext& process,
    std::uint32_t connection_object, std::uint32_t selector,
    std::span<const std::uint64_t> scalar_input,
    std::span<const std::byte> inband_input,
    std::uint32_t scalar_output_capacity, std::uint32_t inband_output_capacity)
{
    static_cast<void>(scalar_output_capacity);
    std::lock_guard lock { state.mach_mutex };
    if (!is_graphics_connection_locked(state, process, connection_object))
        return std::nullopt;

    auto& connection = state.iokit_graphics_connections[connection_object];
    const auto shared_mapping_reply = [&]() -> std::optional<MethodResult> {
        const KernelSharedState::IOKitGraphicsConnectionState::MemoryMapping*
            mapping = nullptr;
        if (const auto local =
                connection.memory_mappings.find(shared_memory_type);
            local != connection.memory_mappings.end()) {
            mapping = &local->second;
        }
        if (mapping == nullptr && connection.shared_connection_object != 0U) {
            const auto shared = state.iokit_graphics_connections.find(
                connection.shared_connection_object);
            if (shared != state.iokit_graphics_connections.end()) {
                const auto shared_mapping =
                    shared->second.memory_mappings.find(shared_memory_type);
                if (shared_mapping != shared->second.memory_mappings.end())
                    mapping = &shared_mapping->second;
            }
        }
        if (mapping == nullptr) {
            for (const auto& [candidate_object, candidate] :
                state.iokit_graphics_connections) {
                const auto candidate_connection =
                    state.iokit_connections.find(candidate_object);
                if (candidate_connection == state.iokit_connections.end() ||
                    candidate_connection->second.owner_pid != process.pid ||
                    candidate.shared_connection_object != connection_object)
                    continue;
                const auto candidate_mapping =
                    candidate.memory_mappings.find(shared_memory_type);
                if (candidate_mapping != candidate.memory_mappings.end()) {
                    mapping = &candidate_mapping->second;
                    break;
                }
            }
        }
        if (mapping == nullptr || mapping->address == 0U ||
            mapping->exposed_size < minimum_shared_mapping_size ||
            !memory.mapped(mapping->address, mapping->mapped_size)) {
            return MethodResult { iokit_abi::bad_argument, { }, { } };
        }

        // Static analysis of IMGSGX535GLDriver shows the reply as three words:
        // word 1 is the writable 0x4000-byte table and word 2 is an opaque
        // connection-local object that is dereferenced at offset zero and +12.
        // Keep both inside the connection's shared mapping.  This is a guest
        // address, never a host pointer or a device-specific fake object.
        const auto address = mapping->address;
        const std::array<std::uint32_t, 3> words { 0U, address, address };
        std::vector<std::byte> result(shared_context_reply_size);
        for (std::size_t index = 0; index < words.size(); ++index) {
            const auto word = words[index];
            for (std::size_t byte = 0; byte < sizeof(word); ++byte) {
                result[index * sizeof(word) + byte] =
                    static_cast<std::byte>((word >> (byte * 8U)) & 0xffU);
            }
        }
        return MethodResult { iokit_abi::success, { }, std::move(result) };
    };

    switch (static_cast<Selector>(selector)) {
    case Selector::InitializeLibrary:
        if (!scalar_input.empty() || !inband_input.empty() ||
            inband_output_capacity != 0U)
            return MethodResult { iokit_abi::bad_argument, { }, { } };
        return MethodResult { iokit_abi::success, { }, { } };
    case Selector::CreateShared:
        if (scalar_input.size() != 1U ||
            scalar_input[0] != shared_memory_type || !inband_input.empty() ||
            inband_output_capacity != 0U)
            return MethodResult { iokit_abi::bad_argument, { }, { } };
        connection.shared_created = true;
        return MethodResult { iokit_abi::success, { }, { } };
    case Selector::InitializeContext:
        // The shared connection uses the same selector for its 80-byte
        // allocation request.  It returns the same shared-arena descriptor as
        // the context-side form.
        if (scalar_input.empty() && inband_input.size() == 80U &&
            inband_output_capacity == shared_context_reply_size &&
            connection.shared_created) {
            if (const auto result = shared_mapping_reply())
                return *result;
            return MethodResult { iokit_abi::bad_argument, { }, { } };
        }
        if ((!scalar_input.empty() &&
                (scalar_input.size() != 1U || scalar_input[0] != 0U)) ||
            !inband_input.empty() ||
            inband_output_capacity != shared_context_reply_size)
            return MethodResult { iokit_abi::bad_argument, { }, { } };
        if (!connection.shared_created && connection.memory_mappings.empty())
            return MethodResult { iokit_abi::bad_argument, { }, { } };
        connection.context_created = true;
        if (const auto result = shared_mapping_reply())
            return *result;
        return MethodResult { iokit_abi::bad_argument, { }, { } };
    case Selector::GetSharedResource:
        if (!scalar_input.empty() || !inband_input.empty() ||
            !connection.shared_created ||
            inband_output_capacity != sizeof(std::uint32_t))
            return MethodResult { iokit_abi::bad_argument, { }, { } };
        if (connection.shared_resource_token == 0U)
            connection.shared_resource_token = connection_object;
        const auto token = connection.shared_resource_token;
        std::vector<std::byte> result(sizeof(token));
        for (std::size_t index = 0; index < sizeof(token); ++index) {
            result[index] =
                static_cast<std::byte>((token >> (index * 8U)) & 0xffU);
        }
        return MethodResult { iokit_abi::success, { }, std::move(result) };
    }
    return MethodResult { iokit_abi::unsupported, { }, { } };
}

std::optional<std::uint32_t> handle_mach_request(AddressSpace& memory,
    KernelSharedState& state, const ProcessContext& process,
    std::uint32_t message_id, std::uint32_t message_address,
    std::uint32_t send_size, std::uint32_t receive_size,
    std::uint32_t connection_object, std::uint32_t local_port)
{
    {
        std::lock_guard lock { state.mach_mutex };
        if (!is_graphics_connection_locked(state, process, connection_object))
            return std::nullopt;
    }
    if (const auto result = handle_map_memory_request(memory, state, process,
            message_id, message_address, send_size, receive_size,
            connection_object, local_port)) {
        return result;
    }
    if (const auto result = handle_unmap_memory_request(memory, state, process,
            message_id, message_address, send_size, receive_size,
            connection_object, local_port)) {
        return result;
    }
    return handle_add_client_request(memory, state, process, message_id,
        message_address, send_size, receive_size, connection_object,
        local_port);
}

void close_connection(AddressSpace& memory, KernelSharedState& state,
    std::uint32_t connection_object)
{
    std::vector<KernelSharedState::IOKitGraphicsConnectionState::MemoryMapping>
        mappings;
    {
        std::lock_guard lock { state.mach_mutex };
        const auto connection =
            state.iokit_graphics_connections.find(connection_object);
        if (connection == state.iokit_graphics_connections.end())
            return;
        mappings.reserve(connection->second.memory_mappings.size());
        for (const auto& [memory_type, mapping] :
            connection->second.memory_mappings) {
            static_cast<void>(memory_type);
            mappings.push_back(mapping);
        }
        state.iokit_graphics_connections.erase(connection);
    }
    for (const auto& mapping : mappings) {
        if (mapping.address != 0U && mapping.mapped_size != 0U &&
            memory.mapped(mapping.address, mapping.mapped_size)) {
            static_cast<void>(
                memory.unmap(mapping.address, mapping.mapped_size));
        }
    }
}

} // namespace shade::kernel_iokit::graphics
