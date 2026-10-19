// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Schedule virtual vertical-sync notifications and display callback
// delivery.

#include "kernel/kernel_iokit_display.hpp"

#include "foundation/address_space.hpp"
#include "kernel/darwin_abi.hpp"
#include "mach/device_mig_ids.hpp"
#include "kernel/iokit_abi.hpp"
#include "kernel/kernel_shared_state.hpp"
#include "mach/mig_wire_abi.hpp"
#include "foundation/output.hpp"
#include "foundation/performance.hpp"
#include "mach/xnu_mig_adapter.hpp"

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <mutex>
#include <span>
#include <string>

namespace shade::kernel_iokit::display {
namespace {

    namespace device_mig = xnu::mig::device;

    constexpr std::uint32_t mach_receive_invalid_data = 0x10004008U;
    constexpr std::uint32_t mig_reply_identifier_delta = 100;
    constexpr std::uint32_t reply_size = 36;
    constexpr std::uint32_t mobile_framebuffer_service_type = 0;

    void write_word(
        std::vector<std::byte>& bytes, std::size_t offset, std::uint32_t value)
    {
        for (std::size_t byte = 0; byte < sizeof(value); ++byte) {
            bytes[offset + byte] = static_cast<std::byte>(value >> (byte * 8U));
        }
    }

    std::uint32_t write_simple_reply(AddressSpace& memory,
        std::uint32_t address, std::uint32_t local_port,
        std::uint32_t message_id, std::uint32_t result)
    {
        const std::array<std::uint32_t, reply_size / sizeof(std::uint32_t)>
            reply {
                darwin::mig_wire::message_bits(
                    darwin::mig_wire::disposition_move_send_once),
                reply_size,
                local_port,
                0,
                0,
                message_id + mig_reply_identifier_delta,
                0,
                1,
                result,
            };
        for (std::size_t index = 0; index < reply.size(); ++index) {
            if (!memory.write32(address + static_cast<std::uint32_t>(
                                              index * sizeof(std::uint32_t)),
                    reply[index])) {
                return mach_receive_invalid_data;
            }
        }
        return 0;
    }

    bool is_display_connection_locked(const KernelSharedState& state,
        const ProcessContext& process, std::uint32_t connection_object)
    {
        const auto connection = state.iokit_connections.find(connection_object);
        if (connection == state.iokit_connections.end() ||
            connection->second.owner_pid != process.pid ||
            connection->second.type != mobile_framebuffer_service_type) {
            return false;
        }
        const auto service =
            state.iokit_services.find(connection->second.service_port);
        return service != state.iokit_services.end() &&
               service->second.user_client_kind ==
                   KernelSharedState::IOKitUserClientKind::Display;
    }

    bool queue_has_vsync(
        const std::deque<KernelSharedState::MachMessage>& queue,
        std::uint32_t connection_object, std::uint64_t registration_generation)
    {
        return std::any_of(
            queue.begin(), queue.end(), [&](const auto& message) {
                return message.display_vsync_connection_object ==
                           connection_object &&
                       message.display_vsync_registration_generation ==
                           registration_generation;
            });
    }

    void discard_queued_vsync_messages_locked(KernelSharedState& state,
        std::uint32_t notification_port, std::uint32_t connection_object,
        std::uint64_t registration_generation)
    {
        const auto queue = state.mach_queues.find(notification_port);
        if (queue == state.mach_queues.end())
            return;

        auto& messages = queue->second;
        const auto old_size = messages.size();
        std::erase_if(messages, [&](const auto& message) {
            return message.display_vsync_connection_object ==
                       connection_object &&
                   message.display_vsync_registration_generation ==
                       registration_generation;
        });
        if (messages.size() != old_size)
            state.note_mach_queue_topology_change_locked();
    }

    KernelSharedState::MachMessage make_vsync_message(
        std::uint32_t connection_object,
        const KernelSharedState::IOKitDisplayVSync& registration,
        std::uint64_t deadline)
    {
        using namespace iokit_abi::display_vsync;
        constexpr std::size_t notification_header_offset =
            darwin::mig_wire::message_header_size;
        constexpr std::size_t notification_reference_offset =
            notification_header_offset + 2U * sizeof(std::uint32_t);
        constexpr std::size_t completion_offset =
            notification_reference_offset +
            async_reference_count * sizeof(std::uint32_t);
        constexpr std::size_t completion_size =
            (1U + completion_argument_count) * sizeof(std::uint32_t);
        constexpr std::size_t message_size =
            completion_offset + completion_size;

        KernelSharedState::MachMessage message;
        message.bytes.resize(message_size);
        write_word(message.bytes, darwin::mig_wire::header_bits_offset,
            darwin::mig_wire::message_bits(
                darwin::mig_wire::disposition_copy_send));
        write_word(message.bytes, darwin::mig_wire::header_size_offset,
            static_cast<std::uint32_t>(message_size));
        write_word(message.bytes, darwin::mig_wire::header_remote_port_offset,
            registration.notification_port);
        write_word(message.bytes, darwin::mig_wire::header_identifier_offset,
            message_identifier);
        write_word(message.bytes, notification_header_offset,
            static_cast<std::uint32_t>(completion_size));
        write_word(message.bytes,
            notification_header_offset + sizeof(std::uint32_t),
            async_completion_type);
        for (std::size_t index = 0; index < registration.async_reference.size();
            ++index) {
            write_word(message.bytes,
                notification_reference_offset + index * sizeof(std::uint32_t),
                registration.async_reference[index]);
        }

        write_word(message.bytes, completion_offset, iokit_abi::success);
        const auto argument_offset = completion_offset + sizeof(std::uint32_t);
        write_word(message.bytes, argument_offset,
            static_cast<std::uint32_t>(registration.sequence));
        write_word(
            message.bytes, argument_offset + 1U * sizeof(std::uint32_t), 0);
        // IOMobileFramebufferNotifyFunc forwards all six natural_t values to
        // the firmware callback. Both GraphicsServices' HeartbeatVBLCallback
        // and LayerKit's LKDisplayLinkCallback consume arguments 2 and 3 as the
        // 64-bit sampled frame time. QuartzCore's IOMFBServer adds arguments 4
        // and 5 to that sample to obtain the next host time and also publishes
        // the same value as CVTimeStamp.videoRefreshPeriod. Pass one physical
        // panel period: zero prevents a completed frame from scheduling the
        // next animation update, while duplicating the absolute deadline
        // advances time twice.
        write_word(message.bytes, argument_offset + 2U * sizeof(std::uint32_t),
            static_cast<std::uint32_t>(deadline));
        write_word(message.bytes, argument_offset + 3U * sizeof(std::uint32_t),
            static_cast<std::uint32_t>(deadline >> 32U));
        write_word(message.bytes, argument_offset + 4U * sizeof(std::uint32_t),
            static_cast<std::uint32_t>(period_absolute_time));
        write_word(message.bytes, argument_offset + 5U * sizeof(std::uint32_t),
            static_cast<std::uint32_t>(period_absolute_time >> 32U));
        message.destination = registration.notification_port;
        message.display_vsync_connection_object = connection_object;
        message.display_vsync_registration_generation =
            registration.registration_generation;
        message.display_vsync_sequence = registration.sequence;
        return message;
    }

} // namespace

std::optional<MethodResult> dispatch_connect_method(KernelSharedState& state,
    const ProcessContext& process, std::uint32_t connection_object,
    std::uint32_t selector, std::span<const std::uint64_t> scalar_input,
    std::span<const std::byte> inband_input,
    std::uint32_t scalar_output_capacity)
{
    std::lock_guard lock { state.mach_mutex };
    if (!is_display_connection_locked(state, process, connection_object))
        return std::nullopt;
    const auto& connection = state.iokit_connections.at(connection_object);
    const bool external = state.external_framebuffer_service != 0 &&
                          connection.service_port ==
                              state.external_framebuffer_service;

    if (selector == static_cast<std::uint32_t>(
                        iokit_abi::MobileFramebufferSelector::IsMainDisplay)) {
        if (!scalar_input.empty() || !inband_input.empty() ||
            scalar_output_capacity < 1U) {
            return MethodResult { iokit_abi::bad_argument, { } };
        }
        return MethodResult { iokit_abi::success, { external ? 0U : 1U } };
    }

    // An external controller is present even with no monitor attached. Its
    // connection state and power requests must never change the built-in LCD.
    if (external && selector == static_cast<std::uint32_t>(
                                   iokit_abi::MobileFramebufferSelector::
                                       GetDigitalOutState)) {
        if (!scalar_input.empty() || !inband_input.empty() ||
            scalar_output_capacity < 1U) {
            return MethodResult { iokit_abi::bad_argument, { } };
        }
        return MethodResult { iokit_abi::success, { 0U } };
    }
    if (external && selector == static_cast<std::uint32_t>(
                                   iokit_abi::MobileFramebufferSelector::
                                       SetTVOutSignalType)) {
        if (scalar_input.size() != 1U || !inband_input.empty() ||
            scalar_output_capacity != 0U) {
            return MethodResult { iokit_abi::bad_argument, { } };
        }
        return MethodResult { scalar_input.front() == 0U
                                  ? iokit_abi::success
                                  : iokit_abi::unsupported,
            { } };
    }

    if (selector ==
        static_cast<std::uint32_t>(
            iokit_abi::MobileFramebufferSelector::GetLayerDefaultSurface)) {
        if (!scalar_input.empty() || !inband_input.empty() ||
            scalar_output_capacity < 1U) {
            return MethodResult { iokit_abi::bad_argument, { } };
        }
        return MethodResult { iokit_abi::success,
            { external ? 0U : iokit_abi::mobile_framebuffer_default_surface_id } };
    }

    if (selector ==
        static_cast<std::uint32_t>(
            iokit_abi::MobileFramebufferSelector::SetWhiteOnBlackMode)) {
        if (scalar_input.size() != 1U || !inband_input.empty() ||
            scalar_output_capacity != 0U) {
            return MethodResult { iokit_abi::bad_argument, { } };
        }
        return MethodResult { iokit_abi::success, { } };
    }

    if (iokit_abi::is_mobile_framebuffer_vsync_selector(selector)) {
        if (scalar_input.size() != 2U || !inband_input.empty()) {
            return MethodResult { iokit_abi::bad_argument, { } };
        }
        if (external)
            return MethodResult { iokit_abi::success, { } };
        const auto registration =
            state.iokit_display_vsync.find(connection_object);
        if (registration == state.iokit_display_vsync.end())
            return MethodResult { iokit_abi::bad_argument, { } };

        remove_vsync_deadline_index_locked(state, connection_object);
        auto& vsync = registration->second;
        ++vsync.method_call_count;
        const auto callout = static_cast<std::uint32_t>(scalar_input[0]);
        const auto refcon = static_cast<std::uint32_t>(scalar_input[1]);
        vsync.async_reference.fill(0);
        vsync.async_reference[iokit_abi::display_vsync::async_reserved_index] =
            vsync.notification_port;
        vsync.async_reference[iokit_abi::display_vsync::async_callout_index] =
            callout;
        vsync.async_reference[iokit_abi::display_vsync::async_refcon_index] =
            refcon;
        const auto was_enabled = vsync.enabled;
        vsync.enabled = callout != 0 && refcon != 0;
        if (was_enabled != vsync.enabled)
            vsync.last_notification_frame_time.reset();
        if (!vsync.enabled) {
            // A message queued before disable belongs to the old registration
            // window. Do not let a sleeping receiver consume it after selector
            // 9 has been turned off: selector-off means no callback and no
            // frame. The scanout surface remains untouched, so the last real
            // frame stays visible until the next fixed-phase enable.
            discard_queued_vsync_messages_locked(state, vsync.notification_port,
                connection_object, vsync.registration_generation);
            // Disabling selector 9 cancels the old notification window. A
            // queued message discarded above can no longer enter NotifyFunc, so
            // retire its host-only callback watermark with the same
            // registration semantics.
            vsync.callback_sequence = vsync.sequence;
            vsync.swap_sequence = vsync.sequence;
        }
        state.mark_foreground_transition_locked(
            vsync.enabled
                ? KernelSharedState::ForegroundTransitionMilestone::VsyncEnabled
                : KernelSharedState::ForegroundTransitionMilestone::
                      VsyncDisabled);
        if (vsync.enabled) {
            const auto now = state.clock.now();
            const auto period = iokit_abi::display_vsync::period_absolute_time;
            // The LCD scan phase is independent of client registration.
            // Preserve a future pulse across the disable/enable pairs emitted
            // by GraphicsServices; repeatedly scheduling at now + period lets a
            // busy client chase the deadline forever and starves its animation
            // callback.
            if (!vsync.next_deadline || *vsync.next_deadline <= now) {
                vsync.next_deadline = now - now % period + period;
            }
            index_vsync_deadline_locked(state, connection_object);
        }
        return MethodResult { iokit_abi::success, { } };
    }

    if (iokit_abi::is_mobile_framebuffer_power_selector(selector)) {
        if (scalar_input.size() != 1U || !inband_input.empty() ||
            scalar_output_capacity != 0U) {
            return MethodResult { iokit_abi::bad_argument, { } };
        }
        if (external)
            return MethodResult { iokit_abi::success, { } };
        auto requested_power_state =
            static_cast<std::uint32_t>(scalar_input.front());
        const auto wake_lock_power_off_pending = [&state] {
            return state.host_display_wake_after_lock_sequence != 0U &&
                   std::find(state.host_display_pending_lock_power_off_sequences
                                 .begin(),
                       state.host_display_pending_lock_power_off_sequences
                           .end(),
                       state.host_display_wake_after_lock_sequence) !=
                       state.host_display_pending_lock_power_off_sequences
                           .end();
        };
        if (state.host_display_intent ==
            KernelSharedState::HostDisplayIntent::LockPending) {
            if (requested_power_state == 0U) {
                if (!state.host_display_pending_lock_power_off_sequences
                        .empty()) {
                    state.host_display_pending_lock_power_off_sequences
                        .pop_front();
                }
                state.host_display_intent =
                    state.host_display_pending_lock_power_off_sequences.empty()
                        ? KernelSharedState::HostDisplayIntent::GuestControlled
                        : KernelSharedState::HostDisplayIntent::LockPending;
            }
        } else if (state.host_display_intent ==
                   KernelSharedState::HostDisplayIntent::LockedOff) {
            if (requested_power_state == 0U &&
                !state.host_display_pending_lock_power_off_sequences.empty()) {
                state.host_display_pending_lock_power_off_sequences.pop_front();
            }
            requested_power_state = 0U;
        } else if (state.host_display_intent ==
                   KernelSharedState::HostDisplayIntent::WakePending) {
            if (requested_power_state == 0U) {
                const auto belongs_to_preceding_lock =
                    wake_lock_power_off_pending();
                if (belongs_to_preceding_lock &&
                    !state.host_display_pending_lock_power_off_sequences
                        .empty()) {
                    // Panel-off requests follow their Lock events in FIFO
                    // order. Consume exactly one generation; an old request
                    // cannot acknowledge a newer lock/wake cycle.
                    state.host_display_pending_lock_power_off_sequences
                        .pop_front();
                    if (state.host_display_hardware_wake_pending ||
                        state.host_display_wake_power_on_acknowledged) {
                        requested_power_state = 1U;
                    }
                } else if (state.host_display_hardware_wake_pending) {
                    // A physical Home or Sleep/Wake press owns panel power
                    // until the guest acknowledges the wake. The guest-visible
                    // event keeps its original identity.
                    requested_power_state = 1U;
                }
            } else {
                state.host_display_wake_power_on_acknowledged = true;
            }
            if (state.host_display_wake_power_on_acknowledged &&
                !wake_lock_power_off_pending()) {
                state.host_display_intent =
                    KernelSharedState::HostDisplayIntent::GuestControlled;
                state.host_display_hardware_wake_pending = false;
                state.host_display_wake_power_on_acknowledged = false;
                state.host_display_wake_after_lock_sequence = 0U;
            }
        }
        state.iokit_display_connections[connection_object]
            .requested_power_state = requested_power_state;
        state.requested_display_power_state = requested_power_state;
        return MethodResult { iokit_abi::success, { } };
    }

    return MethodResult { iokit_abi::unsupported, { } };
}

std::optional<std::uint32_t> handle_notification_port_request(
    AddressSpace& memory, Output& output, KernelSharedState& state,
    ProcessContext& process, std::uint32_t message_id,
    std::uint32_t message_address, std::uint32_t send_size,
    std::uint32_t receive_size, std::uint32_t connection_object,
    std::uint32_t local_port)
{
    if (message_id !=
        device_mig::id(device_mig::Routine::io_connect_set_notification_port)) {
        return std::nullopt;
    }
    {
        std::lock_guard lock { state.mach_mutex };
        if (!is_display_connection_locked(state, process, connection_object))
            return std::nullopt;
    }
    const auto header_size =
        memory.read32(message_address + darwin::mig_wire::header_size_offset)
            .value_or(0);
    const auto descriptor_count =
        memory
            .read32(message_address +
                    darwin::mig_wire::complex_descriptor_count_offset)
            .value_or(0);
    const auto notification_name =
        memory
            .read32(message_address +
                    device_mig::io_connect_set_notification_port_arguments[2]
                        .request_offset)
            .value_or(0);
    const auto notification_type =
        memory
            .read32(message_address +
                    device_mig::io_connect_set_notification_port_arguments[1]
                        .request_offset)
            .value_or(0);
    const auto descriptor_metadata =
        memory
            .read32(message_address +
                    darwin::mig_wire::descriptor_metadata_offset(0))
            .value_or(0);
    const auto reference =
        memory
            .read32(message_address +
                    device_mig::io_connect_set_notification_port_arguments[3]
                        .request_offset)
            .value_or(0);
    output.write("[iokit-display] notification-port-request pid=" +
                 std::to_string(process.pid) +
                 " connection-object=" + std::to_string(connection_object) +
                 " send-size=" + std::to_string(send_size) +
                 " header-size=" + std::to_string(header_size) +
                 " receive-size=" + std::to_string(receive_size) +
                 " descriptors=" + std::to_string(descriptor_count) +
                 " port-name=" + std::to_string(notification_name) +
                 " metadata=" + std::to_string(descriptor_metadata) + "\n");
    constexpr std::uint32_t port_descriptor_semantic_mask = 0xffff0000U;
    const auto expected_descriptor = darwin::mig_wire::port_descriptor_metadata(
        darwin::mig_wire::disposition_make_send);
    if (receive_size < reply_size || send_size < 56U ||
        descriptor_count != 1U || notification_name == 0 ||
        (descriptor_metadata & port_descriptor_semantic_mask) !=
            (expected_descriptor & port_descriptor_semantic_mask)) {
        output.write("[iokit-display] invalid-notification-port-request pid=" +
                     std::to_string(process.pid) + "\n");
        return mach_receive_invalid_data;
    }

    std::uint32_t notification_object = 0;
    {
        std::lock_guard lock { state.mach_mutex };
        if (!is_display_connection_locked(state, process, connection_object))
            return write_simple_reply(memory, message_address, local_port,
                message_id, iokit_abi::unsupported);
        notification_object =
            state.mach_namespaces.resolve(process.pid, notification_name)
                .value_or(0);
        if (notification_object == 0 ||
            !state.mach_port_objects.contains(notification_object)) {
            output.write("[iokit-display] invalid-notification-port-name pid=" +
                         std::to_string(process.pid) +
                         " port-name=" + std::to_string(notification_name) +
                         " port-object=" + std::to_string(notification_object) +
                         "\n");
            return write_simple_reply(memory, message_address, local_port,
                message_id, iokit_abi::bad_argument);
        }
        if (const auto previous =
                state.iokit_display_vsync.find(connection_object);
            previous != state.iokit_display_vsync.end()) {
            remove_vsync_deadline_index_locked(state, connection_object);
            discard_queued_vsync_messages_locked(state,
                previous->second.notification_port, connection_object,
                previous->second.registration_generation);
        }
        KernelSharedState::IOKitDisplayVSync registration;
        registration.owner_pid = process.pid;
        registration.notification_port = notification_object;
        registration.notification_type = notification_type;
        registration.registration_reference = reference;
        registration.registration_generation =
            ++state.iokit_display_vsync_registration_generation;
        state.iokit_display_vsync[connection_object] = registration;
    }

    output.write(
        "[iokit-display] notification-port pid=" + std::to_string(process.pid) +
        " connection-object=" + std::to_string(connection_object) +
        " port-object=" + std::to_string(notification_object) + "\n");
    return write_simple_reply(
        memory, message_address, local_port, message_id, iokit_abi::success);
}

std::optional<std::uint64_t> next_vsync_deadline_locked(
    const KernelSharedState& state)
{
    if (state.iokit_display_vsync_deadlines.empty())
        return std::nullopt;
    return state.iokit_display_vsync_deadlines.begin()->first;
}

void remove_vsync_deadline_index_locked(
    KernelSharedState& state, std::uint32_t connection_object)
{
    const auto registration = state.iokit_display_vsync.find(connection_object);
    if (registration == state.iokit_display_vsync.end() ||
        !registration->second.next_deadline) {
        return;
    }
    state.iokit_display_vsync_deadlines.erase(
        { *registration->second.next_deadline, connection_object });
}

void index_vsync_deadline_locked(
    KernelSharedState& state, std::uint32_t connection_object)
{
    const auto registration = state.iokit_display_vsync.find(connection_object);
    if (registration == state.iokit_display_vsync.end() ||
        !registration->second.enabled || !registration->second.next_deadline) {
        return;
    }
    state.iokit_display_vsync_deadlines.emplace(
        *registration->second.next_deadline, connection_object);
}

void deliver_due_vsync_locked(KernelSharedState& state, std::uint64_t deadline)
{
    while (!state.iokit_display_vsync_deadlines.empty() &&
           state.iokit_display_vsync_deadlines.begin()->first <= deadline) {
        const auto indexed_deadline =
            state.iokit_display_vsync_deadlines.begin()->first;
        const auto connection_object =
            state.iokit_display_vsync_deadlines.begin()->second;
        state.iokit_display_vsync_deadlines.erase(
            state.iokit_display_vsync_deadlines.begin());

        // Multiple client registrations can share one physical panel pulse.
        // Count that internal pulse once while preserving every registration's
        // existing guest notification and deadline advancement below.
        if (state.display_vsync_last_delivered_deadline != indexed_deadline) {
            state.display_vsync_last_delivered_deadline = indexed_deadline;
            ++state.display_vsync_pulse_count;
        }

        const auto registration_it =
            state.iokit_display_vsync.find(connection_object);
        if (registration_it == state.iokit_display_vsync.end())
            continue;
        auto& registration = registration_it->second;
        // Vsync is driven by a kernel-owned timer, so it can fire after the
        // client has torn down its ipc_space.  Do not recreate a queue for a
        // dead notification port via operator[]; retire the registration
        // instead.
        if (!state.mach_port_objects.contains(registration.notification_port)) {
            state.iokit_display_vsync.erase(registration_it);
            continue;
        }
        if (!registration.enabled || !registration.next_deadline ||
            *registration.next_deadline != indexed_deadline) {
            continue;
        }
        auto& queue = state.mach_queues[registration.notification_port];
        if (!queue_has_vsync(queue, connection_object,
                registration.registration_generation)) {
            const auto period = iokit_abi::display_vsync::period_absolute_time;
            const auto frame_time =
                registration.last_notification_frame_time
                    ? *registration.last_notification_frame_time + period
                    : indexed_deadline;
            ++registration.sequence;
            state.enqueue_mach_message_locked(registration.notification_port,
                // Physical timer deadlines can be coalesced while the prior
                // callback is pending. Advance the guest-visible sample by one
                // panel period per notification actually delivered so
                // animation state cannot jump over undisplayed frames.
                make_vsync_message(
                    connection_object, registration, frame_time));
            registration.last_notification_frame_time = frame_time;
            performance_counters().record_vsync_due(registration.owner_pid,
                registration.async_reference
                    [iokit_abi::display_vsync::async_refcon_index],
                registration.sequence);
            performance_counters().record_display_vsync_queued();
        } else {
            // A completed callback can race with retirement of its queued
            // message. In that case this pulse was not hidden by an active
            // animation callback, so keep the continuous sample baseline on
            // the physical panel phase. A genuinely pending callback retains
            // its last delivered sample and therefore cannot skip animation
            // states when the host is late.
            if (registration.callback_sequence >= registration.sequence)
                registration.last_notification_frame_time = indexed_deadline;
            performance_counters().record_display_vsync_coalesced();
        }
        const auto period = iokit_abi::display_vsync::period_absolute_time;
        const auto elapsed = deadline - *registration.next_deadline;
        registration.next_deadline =
            *registration.next_deadline + (elapsed / period + 1U) * period;
        index_vsync_deadline_locked(state, connection_object);
    }
}

void close_connection_locked(
    KernelSharedState& state, std::uint32_t connection_object)
{
    const auto registration = state.iokit_display_vsync.find(connection_object);
    remove_vsync_deadline_index_locked(state, connection_object);
    if (registration != state.iokit_display_vsync.end()) {
        discard_queued_vsync_messages_locked(state,
            registration->second.notification_port, connection_object,
            registration->second.registration_generation);
    }
    state.iokit_display_vsync.erase(connection_object);
    state.iokit_display_connections.erase(connection_object);
}

} // namespace shade::kernel_iokit::display
