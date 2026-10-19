// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Implement root power-domain connections and guest power
// notifications.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/iokit/Kernel/IOPMrootDomain.cpp

#include "power.hpp"

#include "foundation/address_space.hpp"
#include "kernel/darwin_abi.hpp"
#include "mach/device_mig_ids.hpp"
#include "kernel/iokit_abi.hpp"
#include "kernel/kernel_shared_state.hpp"
#include "mach/mig_wire_abi.hpp"
#include "foundation/output.hpp"
#include "mach/xnu_mig_adapter.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <mutex>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace shade::kernel_iokit {
namespace {

    namespace device_mig = xnu::mig::device;

    constexpr std::string_view power_root_class = "IOPMrootDomain";
    constexpr std::string_view io_service_class = "IOService";
    constexpr std::uint32_t mig_reply_identifier_delta = 100;
    constexpr std::uint32_t ndr_native = 0;
    constexpr std::uint32_t ndr_little_endian = 1;
    constexpr std::uint32_t system_sleep_timer_disabled = 0x7fff'ffffU;

    std::uint32_t resolve_name_locked(
        const KernelSharedState& state, std::uint32_t task, std::uint32_t name)
    {
        if (const auto object = state.mach_namespaces.resolve(task, name))
            return *object;
        return state.mach_namespaces.contains_task(task) ? 0U : name;
    }

    std::uint32_t copyout_send_locked(
        KernelSharedState& state, std::uint32_t task, std::uint32_t object)
    {
        return state.mach_namespaces
            .copyout(
                task, object, xnu::ipc::type_mask(xnu::ipc::Right::Send))
            .value_or(0);
    }

    KernelSharedState::IOKitRegistryProperty power_profile_override_property()
    {
        KernelSharedState::IOKitRegistryProperty timer {
            KernelSharedState::IOKitRegistryProperty::Kind::Number,
            std::vector<std::byte>(sizeof(system_sleep_timer_disabled)) };
        for (std::size_t index = 0; index < timer.value.size(); ++index) {
            timer.value[index] = static_cast<std::byte>(
                system_sleep_timer_disabled >> (index * 8U));
        }

        KernelSharedState::IOKitRegistryProperty override {
            KernelSharedState::IOKitRegistryProperty::Kind::Dictionary, { } };
        override.dictionary_value.emplace("System Sleep Timer",
            std::move(timer));
        return override;
    }

    void populate_power_root_properties(
        KernelSharedState::IOKitService& service)
    {
        // AppleARM publishes this platform override on IOPMrootDomain. The
        // Darwin IOPMLib uses it to turn the immutable default power-profile
        // plist into its working profile set. Returning not-found here makes
        // the iPad 4.x client call its private mutable-dictionary path with
        // the immutable plist object and hit CoreFoundation's BKPT guard.
        service.properties.insert_or_assign("SystemPowerProfileOverrideDict",
            power_profile_override_property());
    }

    template <std::size_t Size>
    std::uint32_t write_reply(AddressSpace& memory, std::uint32_t address,
        const std::array<std::uint32_t, Size>& reply)
    {
        for (std::size_t index = 0; index < reply.size(); ++index) {
            const auto offset =
                static_cast<std::uint32_t>(index * sizeof(std::uint32_t));
            if (!memory.write32(address + offset, reply[index]))
                return darwin::mach_message::receive_invalid_data;
        }
        return 0;
    }

    std::uint32_t write_port_reply(AddressSpace& memory, std::uint32_t address,
        std::uint32_t local_port, std::uint32_t message_id, std::uint32_t port)
    {
        using namespace darwin::mig_wire;
        constexpr std::size_t word_count =
            iokit_abi::service_interest_notification::reply_size / word_size;
        const std::array<std::uint32_t, word_count> reply {
            message_bits(disposition_move_send_once, 0, true),
            iokit_abi::service_interest_notification::reply_size,
            local_port,
            0,
            0,
            message_id + mig_reply_identifier_delta,
            1,
            port,
            0,
            port_descriptor_metadata(disposition_move_send),
        };
        return write_reply(memory, address, reply);
    }

    bool is_power_root_locked(const KernelSharedState& state,
        const ProcessContext& process, std::uint32_t remote_object)
    {
        return remote_object == resolve_name_locked(state, process.pid,
                                    process.io_registry_options_port);
    }

    std::optional<std::uint32_t> handle_power_open(AddressSpace& memory,
        Output& output, KernelSharedState& state, ProcessContext& process,
        std::uint32_t message_id, std::uint32_t message_address,
        std::uint32_t receive_size, std::uint32_t remote_object,
        std::uint32_t local_port)
    {
        using namespace iokit_abi::service_open_extended;
        if (message_id != static_cast<std::uint32_t>(
                              iokit_abi::Message::ServiceOpenExtended)) {
            return std::nullopt;
        }
        if (receive_size < reply_size)
            return darwin::mach_message::receive_invalid_data;
        if (memory
                .read32(message_address +
                        darwin::mig_wire::complex_descriptor_count_offset)
                .value_or(0) != request_descriptor_count) {
            return darwin::mach_message::receive_invalid_data;
        }

        std::uint32_t connection_object = 0;
        std::uint32_t connection_name = 0;
        {
            std::lock_guard lock { state.mach_mutex };
            if (!is_power_root_locked(state, process, remote_object))
                return std::nullopt;
            static_cast<void>(state.mach_port_objects.create(remote_object));
            auto [service, inserted] = state.iokit_services.try_emplace(
                remote_object, KernelSharedState::IOKitService {
                    std::string { power_root_class },
                    { std::string { io_service_class } } });
            static_cast<void>(inserted);
            populate_power_root_properties(service->second);
            connection_object = state.allocate_mach_object();
            static_cast<void>(
                state.mach_port_objects.create(connection_object));
            state.mach_queues.try_emplace(connection_object);
            state.iokit_connections.emplace(connection_object,
                KernelSharedState::IOKitConnection { remote_object, process.pid,
                    iokit_abi::power_root_service_type });
            connection_name =
                copyout_send_locked(state, process.pid, connection_object);
        }

        using namespace darwin::mig_wire;
        const std::array<std::uint32_t, reply_word_count> reply {
            message_bits(disposition_move_send_once, 0, true),
            reply_size,
            local_port,
            0,
            0,
            message_id + mig_reply_identifier_delta,
            1,
            connection_name,
            0,
            port_descriptor_metadata(disposition_move_send),
            ndr_native,
            ndr_little_endian,
            iokit_abi::success,
        };
        output.write("[iokit-power] open pid=" + std::to_string(process.pid) +
                     " connection-name=" + std::to_string(connection_name) +
                     " connection-object=" + std::to_string(connection_object) +
                     "\n");
        return write_reply(memory, message_address, reply);
    }

    std::optional<std::uint32_t> handle_interest_registration(
        AddressSpace& memory, Output& output, KernelSharedState& state,
        ProcessContext& process, std::uint32_t message_id,
        std::uint32_t message_address, std::uint32_t receive_size,
        std::uint32_t remote_object, std::uint32_t local_port)
    {
        using namespace iokit_abi::service_interest_notification;
        if (message_id !=
            static_cast<std::uint32_t>(
                iokit_abi::Message::ServiceAddInterestNotification)) {
            return std::nullopt;
        }
        if (receive_size < reply_size)
            return darwin::mach_message::receive_invalid_data;
        const auto descriptor_count =
            memory.read32(message_address +
                          darwin::mig_wire::complex_descriptor_count_offset);
        const auto type_count = memory.read32(
            message_address +
            device_mig::io_service_add_interest_notification_arguments[1]
                .request_count_offset);
        if (!descriptor_count ||
            *descriptor_count != request_descriptor_count || !type_count ||
            *type_count == 0 || *type_count > maximum_interest_name_size) {
            return darwin::mach_message::receive_invalid_data;
        }

        std::array<std::uint32_t,
            device_mig::io_service_add_interest_notification_arguments.size()>
            element_counts { };
        element_counts[1] = *type_count;
        const auto type_layout = xnu::mig::compute_wire_layout(
            device_mig::io_service_add_interest_notification_arguments,
            xnu::mig::WireLayoutSide::Request, element_counts);
        if (!type_layout)
            return darwin::mach_message::receive_invalid_data;
        const auto reference_count =
            memory.read32(message_address + (*type_layout)[3].count_offset);
        if (!reference_count || *reference_count > maximum_reference_count)
            return darwin::mach_message::receive_invalid_data;
        element_counts[3] = *reference_count;
        const auto layout = xnu::mig::compute_wire_layout(
            device_mig::io_service_add_interest_notification_arguments,
            xnu::mig::WireLayoutSide::Request, element_counts);
        if (!layout)
            return darwin::mach_message::receive_invalid_data;

        const auto type_bytes = memory.read_bytes(
            message_address + (*layout)[1].offset, *type_count);
        const auto wake_name =
            memory.read32(message_address + (*layout)[2].offset);
        const auto reference_bytes =
            memory.read_bytes(message_address + (*layout)[3].offset,
                *reference_count * sizeof(std::uint32_t));
        if (!type_bytes || !wake_name || !reference_bytes)
            return darwin::mach_message::receive_invalid_data;

        std::string type;
        type.reserve(type_bytes->size());
        for (const auto byte : *type_bytes)
            type.push_back(static_cast<char>(byte));
        if (!type.empty() && type.back() == '\0')
            type.pop_back();
        std::vector<std::uint32_t> reference;
        reference.reserve(*reference_count);
        for (std::uint32_t index = 0; index < *reference_count; ++index) {
            const auto reference_offset =
                index * static_cast<std::uint32_t>(sizeof(std::uint32_t));
            const auto value = memory.read32(
                message_address + (*layout)[3].offset + reference_offset);
            if (!value)
                return darwin::mach_message::receive_invalid_data;
            reference.push_back(*value);
        }

        std::uint32_t notification_object = 0;
        std::uint32_t notification_name = 0;
        {
            std::lock_guard lock { state.mach_mutex };
            if (!state.iokit_services.contains(remote_object))
                return std::nullopt;
            const auto wake_object =
                resolve_name_locked(state, process.pid, *wake_name);
            if (wake_object == 0)
                return darwin::mach_message::receive_invalid_data;
            notification_object = state.allocate_mach_object();
            static_cast<void>(
                state.mach_port_objects.create(notification_object));
            state.iokit_interest_notifications.emplace(notification_object,
                KernelSharedState::IOKitInterestNotification { process.pid,
                    wake_object, std::move(type), std::move(reference) });
            notification_name =
                copyout_send_locked(state, process.pid, notification_object);
        }
        output.write("[iokit] interest pid=" + std::to_string(process.pid) +
                     " notifier-name=" + std::to_string(notification_name) +
                     " notifier-object=" + std::to_string(notification_object) +
                     "\n");
        return write_port_reply(
            memory, message_address, local_port, message_id, notification_name);
    }

} // namespace

std::optional<std::uint32_t> handle_power_mach_request(AddressSpace& memory,
    Output& output, KernelSharedState& shared_state, ProcessContext& process,
    std::uint32_t message_id, std::uint32_t message_address,
    std::uint32_t receive_size, std::uint32_t remote_object,
    std::uint32_t local_port)
{
    if (const auto result =
            handle_power_open(memory, output, shared_state, process, message_id,
                message_address, receive_size, remote_object, local_port)) {
        return result;
    }
    return handle_interest_registration(memory, output, shared_state, process,
        message_id, message_address, receive_size, remote_object, local_port);
}

} // namespace shade::kernel_iokit
