// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
#include "property_notifications.hpp"

#include "kernel/kernel_shared_state.hpp"
#include "mach/mig_wire_abi.hpp"

namespace shade::kernel_iokit::audio {

IOAudio2PropertyNotifications::IOAudio2PropertyNotifications(
    KernelSharedState& state, std::uint32_t service_object)
    : state_(state), service_object_(service_object)
{
}

void IOAudio2PropertyNotifications::publish(std::uint32_t object_id,
    std::uint32_t selector, std::uint32_t scope, std::uint32_t element) const
{
    send(object_id, 0x70726f70U, selector, scope, element);
}

void IOAudio2PropertyNotifications::control_value_changed(
    std::uint32_t control_id, std::uint32_t value) const
{
    send(control_id, 0x6376616cU, value, 0, 0); // cval
}

void IOAudio2PropertyNotifications::send(std::uint32_t object_id,
    std::uint32_t kind, std::uint32_t value, std::uint32_t scope,
    std::uint32_t element) const
{
    // IOAudio2 sends a Mach header, the registration reference and count,
    // followed by 32-byte notifications (object, kind, property address).
    constexpr std::size_t body = darwin::mig_wire::message_header_size;
    constexpr std::size_t record = body + 8;
    for (const auto& [connection_object, connection] :
        state_.iokit_audio_connections) {
        const auto client = state_.iokit_connections.find(connection_object);
        if (client == state_.iokit_connections.end() ||
            client->second.service_port != service_object_ ||
            connection.notification_port == 0)
            continue;
        KernelSharedState::MachMessage message;
        message.bytes.resize(record + 32);
        const auto put = [&message](std::size_t offset, std::uint32_t value) {
            for (unsigned byte = 0; byte < 4; ++byte)
                message.bytes[offset + byte] =
                    static_cast<std::byte>((value >> (byte * 8)) & 0xffU);
        };
        put(darwin::mig_wire::header_bits_offset,
            darwin::mig_wire::message_bits(
                darwin::mig_wire::disposition_copy_send));
        put(darwin::mig_wire::header_size_offset,
            static_cast<std::uint32_t>(message.bytes.size()));
        put(darwin::mig_wire::header_remote_port_offset,
            connection.notification_port);
        put(body, connection.registration_reference);
        put(body + 4, 1);
        put(record, object_id);
        put(record + 4, kind);
        put(record + 8, value);
        put(record + 12, scope);
        put(record + 16, element);
        message.destination = connection.notification_port;
        state_.enqueue_mach_message_locked(
            connection.notification_port, std::move(message));
    }
}

} // namespace shade::kernel_iokit::audio
