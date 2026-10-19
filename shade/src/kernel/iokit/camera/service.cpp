// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Dispatch virtual camera user-client requests and capture
// operations.

#include "kernel/kernel_iokit_camera.hpp"

#include "foundation/address_space.hpp"
#include "mach/device_mig_ids.hpp"
#include "kernel/iokit_abi.hpp"
#include "kernel/kernel_shared_state.hpp"
#include "mach/mig_wire_abi.hpp"
#include "foundation/output.hpp"
#include "graphics/surface_store.hpp"

#include <algorithm>
#include <array>
#include <limits>
#include <mutex>
#include <string>

namespace shade::kernel_iokit::camera {
namespace {

    namespace device_mig = xnu::mig::device;

    constexpr std::uint32_t mach_receive_invalid_data = 0x10004008U;
    constexpr std::uint32_t mach_reply_bits = 0x00000012U;
    constexpr std::uint32_t mach_ndr_native = 0x00000000U;
    constexpr std::uint32_t mach_ndr_little_endian = 0x00000001U;
    constexpr std::uint32_t mig_reply_id_delta = 100U;
    constexpr std::uint64_t capture_period = 1'000'000'000ULL / 30U;

    bool contains(std::span<const std::byte> matching, std::string_view value)
    {
        return std::search(matching.begin(), matching.end(), value.begin(),
                   value.end(), [](std::byte byte, char character) {
                       return std::to_integer<unsigned char>(byte) ==
                              static_cast<unsigned char>(character);
                   }) != matching.end();
    }

    void write_word(
        std::vector<std::byte>& bytes, std::size_t offset, std::uint32_t value)
    {
        for (std::size_t index = 0; index < sizeof(value); ++index) {
            bytes[offset + index] =
                static_cast<std::byte>((value >> (index * 8U)) & 0xffU);
        }
    }

    std::uint32_t read_word(
        std::span<const std::byte> bytes, std::size_t offset)
    {
        std::uint32_t value = 0;
        for (std::size_t index = 0; index < sizeof(value); ++index) {
            value |= std::to_integer<std::uint32_t>(bytes[offset + index])
                     << (index * 8U);
        }
        return value;
    }

    std::uint32_t write_status_reply(AddressSpace& memory,
        std::uint32_t address, std::uint32_t local_port,
        std::uint32_t message_id, std::uint32_t result)
    {
        const std::array<std::uint32_t, 9> reply {
            mach_reply_bits,
            36U,
            local_port,
            0U,
            0U,
            message_id + mig_reply_id_delta,
            mach_ndr_native,
            mach_ndr_little_endian,
            result,
        };
        for (std::size_t index = 0; index < reply.size(); ++index) {
            if (!memory.write32(
                    address + static_cast<std::uint32_t>(index * 4U),
                    reply[index])) {
                return mach_receive_invalid_data;
            }
        }
        return 0U;
    }

    bool is_kind_connection_locked(const KernelSharedState& state,
        const ProcessContext& process, std::uint32_t connection_object,
        KernelSharedState::IOKitUserClientKind profile)
    {
        const auto connection = state.iokit_connections.find(connection_object);
        if (connection == state.iokit_connections.end() ||
            connection->second.owner_pid != process.pid) {
            return false;
        }
        const auto service =
            state.iokit_services.find(connection->second.service_port);
        return service != state.iokit_services.end() &&
               service->second.user_client_kind == profile;
    }

    std::optional<std::uint64_t> width_mask(std::uint64_t width)
    {
        if (width == 0U || width > 64U)
            return std::nullopt;
        if (width == 64U)
            return std::numeric_limits<std::uint64_t>::max();
        return (std::uint64_t { 1 } << width) - 1U;
    }

    KernelSharedState::MachMessage make_capture_completion(
        const KernelSharedState::IOKitCameraAcceleratorConnectionState&
            connection,
        std::uint32_t callback, std::uint32_t refcon,
        std::uint32_t pixel_buffer, std::uint32_t result = iokit_abi::success)
    {
        using namespace iokit_abi::display_vsync;
        constexpr std::size_t notification_offset =
            darwin::mig_wire::message_header_size;
        constexpr std::size_t reference_offset =
            notification_offset + 2U * sizeof(std::uint32_t);
        constexpr std::size_t completion_offset =
            reference_offset + async_reference_count * sizeof(std::uint32_t);
        constexpr std::size_t message_size =
            completion_offset + 2U * sizeof(std::uint32_t);

        KernelSharedState::MachMessage message;
        message.bytes.resize(message_size);
        write_word(message.bytes, darwin::mig_wire::header_bits_offset,
            darwin::mig_wire::message_bits(
                darwin::mig_wire::disposition_copy_send));
        write_word(message.bytes, darwin::mig_wire::header_size_offset,
            static_cast<std::uint32_t>(message_size));
        write_word(message.bytes, darwin::mig_wire::header_remote_port_offset,
            connection.notification_port);
        write_word(message.bytes, darwin::mig_wire::header_identifier_offset,
            message_identifier);
        write_word(
            message.bytes, notification_offset, 2U * sizeof(std::uint32_t));
        write_word(message.bytes, notification_offset + sizeof(std::uint32_t),
            async_completion_type);
        write_word(message.bytes,
            reference_offset + async_reserved_index * sizeof(std::uint32_t),
            connection.notification_port);
        write_word(message.bytes,
            reference_offset + async_callout_index * sizeof(std::uint32_t),
            callback);
        write_word(message.bytes,
            reference_offset + async_refcon_index * sizeof(std::uint32_t),
            refcon);
        write_word(message.bytes, completion_offset, result);
        write_word(message.bytes, completion_offset + sizeof(std::uint32_t),
            pixel_buffer);
        message.destination = connection.notification_port;
        return message;
    }

    std::vector<std::uint32_t> make_sensor_frame(
        const SurfaceStore::Backing& surface, std::uint64_t sequence)
    {
        constexpr std::array<std::uint32_t, 8> color_bars {
            0xfff2f2f2U,
            0xffe5dc38U,
            0xff38d8d8U,
            0xff35cc4bU,
            0xffd33bd2U,
            0xffd63a38U,
            0xff354bd4U,
            0xff161616U,
        };
        std::vector<std::uint32_t> pixels(
            static_cast<std::size_t>(surface.width) * surface.height);
        const auto marker = static_cast<std::uint32_t>(
            sequence % std::max<std::uint32_t>(surface.width, 1U));
        for (std::uint32_t y = 0; y < surface.height; ++y) {
            for (std::uint32_t x = 0; x < surface.width; ++x) {
                const auto bar = std::min<std::size_t>(
                    static_cast<std::size_t>(x) * color_bars.size() /
                        std::max<std::uint32_t>(surface.width, 1U),
                    color_bars.size() - 1U);
                auto pixel = color_bars[bar];
                if (x >= marker && x < marker + 3U)
                    pixel = 0xffffffffU;
                if (((x / 24U) + (y / 24U) + sequence / 6U) % 2U != 0U) {
                    const auto red = ((pixel >> 16U) & 0xffU) * 7U / 8U;
                    const auto green = ((pixel >> 8U) & 0xffU) * 7U / 8U;
                    const auto blue = (pixel & 0xffU) * 7U / 8U;
                    pixel = 0xff000000U | (red << 16U) | (green << 8U) | blue;
                }
                pixels[static_cast<std::size_t>(y) * surface.width + x] = pixel;
            }
        }
        return pixels;
    }

} // namespace

bool matches_sensor_service(std::span<const std::byte> matching)
{
    return contains(matching, sensor_service_class);
}

std::optional<std::string_view> matching_accelerator_service(
    std::span<const std::byte> matching)
{
    if (contains(matching, capture_accelerator_service_class))
        return capture_accelerator_service_class;
    if (contains(matching, scaler_accelerator_service_class))
        return scaler_accelerator_service_class;
    return std::nullopt;
}

std::uint32_t ensure_sensor_service_locked(
    KernelSharedState& state, std::uint32_t platform_expert_object)
{
    if (state.camera_sensor_service != 0U)
        return state.camera_sensor_service;

    const auto object = state.allocate_mach_object();
    state.camera_sensor_service = object;
    static_cast<void>(state.mach_port_objects.create(object));
    state.mach_queues.try_emplace(object);
    state.iokit_services.emplace(object,
        KernelSharedState::IOKitService { std::string { sensor_service_class },
            { "IOService" }, { },
            "IOService:/IOPlatformExpertDevice/IOCameraSensor",
            platform_expert_object,
            KernelSharedState::IOKitUserClientKind::CameraSensor });
    return object;
}

std::uint32_t ensure_accelerator_service_locked(KernelSharedState& state,
    std::uint32_t platform_expert_object, std::string_view service_class)
{
    auto& object =
        state.camera_accelerator_services[std::string { service_class }];
    if (object != 0U)
        return object;

    object = state.allocate_mach_object();
    static_cast<void>(state.mach_port_objects.create(object));
    state.mach_queues.try_emplace(object);
    state.iokit_services.emplace(object,
        KernelSharedState::IOKitService { std::string { service_class },
            { "IOService" }, { },
            "IOService:/IOPlatformExpertDevice/" +
                std::string { service_class },
            platform_expert_object,
            KernelSharedState::IOKitUserClientKind::CameraAccelerator });
    return object;
}

std::optional<std::uint32_t> handle_notification_port_request(
    AddressSpace& memory, Output& output, KernelSharedState& state,
    const ProcessContext& process, std::uint32_t message_id,
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
        if (!is_kind_connection_locked(state, process, connection_object,
                KernelSharedState::IOKitUserClientKind::CameraAccelerator)) {
            return std::nullopt;
        }
    }

    const auto descriptor_count =
        memory
            .read32(message_address +
                    darwin::mig_wire::complex_descriptor_count_offset)
            .value_or(0U);
    const auto notification_name =
        memory
            .read32(message_address +
                    device_mig::io_connect_set_notification_port_arguments[2]
                        .request_offset)
            .value_or(0U);
    const auto notification_type =
        memory
            .read32(message_address +
                    device_mig::io_connect_set_notification_port_arguments[1]
                        .request_offset)
            .value_or(0U);
    const auto reference =
        memory
            .read32(message_address +
                    device_mig::io_connect_set_notification_port_arguments[3]
                        .request_offset)
            .value_or(0U);
    const auto descriptor_metadata =
        memory
            .read32(message_address +
                    darwin::mig_wire::descriptor_metadata_offset(0))
            .value_or(0U);
    constexpr std::uint32_t descriptor_semantic_mask = 0xffff0000U;
    const auto expected_descriptor = darwin::mig_wire::port_descriptor_metadata(
        darwin::mig_wire::disposition_make_send);
    if (send_size < 56U || receive_size < 36U || descriptor_count != 1U ||
        notification_name == 0U || notification_type != 0U ||
        (descriptor_metadata & descriptor_semantic_mask) !=
            (expected_descriptor & descriptor_semantic_mask)) {
        return mach_receive_invalid_data;
    }

    std::uint32_t notification_object = 0U;
    {
        std::lock_guard lock { state.mach_mutex };
        notification_object =
            state.mach_namespaces.resolve(process.pid, notification_name)
                .value_or(0U);
        if (notification_object == 0U ||
            !state.mach_port_objects.contains(notification_object)) {
            return write_status_reply(memory, message_address, local_port,
                message_id, iokit_abi::bad_argument);
        }
        state.iokit_camera_accelerator_connections[connection_object] =
            KernelSharedState::IOKitCameraAcceleratorConnectionState {
                notification_object, notification_type, reference, 0U, { }
            };
    }
    output.write(
        "[iokit-camera] notification-port pid=" + std::to_string(process.pid) +
        " connection-object=" + std::to_string(connection_object) +
        " port-object=" + std::to_string(notification_object) + "\n");
    return write_status_reply(
        memory, message_address, local_port, message_id, iokit_abi::success);
}

std::optional<MethodResult> dispatch_connect_method(KernelSharedState& state,
    const ProcessContext& process, AddressSpace& memory, SurfaceStore* surfaces,
    std::uint32_t connection_object, std::uint32_t selector,
    std::span<const std::uint64_t> scalar_input,
    std::span<const std::byte> inband_input,
    std::uint32_t scalar_output_capacity)
{
    std::unique_lock lock { state.mach_mutex };
    if (is_kind_connection_locked(state, process, connection_object,
            KernelSharedState::IOKitUserClientKind::CameraSensor)) {
        if (selector ==
            static_cast<std::uint32_t>(SensorSelector::ReadVariable)) {
            if (scalar_input.size() != 2U || !inband_input.empty() ||
                scalar_output_capacity < 1U) {
                return MethodResult { iokit_abi::bad_argument, { } };
            }
            const auto mask = width_mask(scalar_input[1]);
            if (!mask)
                return MethodResult { iokit_abi::bad_argument, { } };
            const auto variable =
                state.camera_sensor_variables.find(scalar_input[0]);
            const auto value = variable == state.camera_sensor_variables.end()
                                   ? 0U
                                   : variable->second;
            return MethodResult { iokit_abi::success, { value & *mask } };
        }
        if (selector ==
            static_cast<std::uint32_t>(SensorSelector::WriteVariable)) {
            if (scalar_input.size() != 4U || !inband_input.empty() ||
                scalar_output_capacity != 0U) {
                return MethodResult { iokit_abi::bad_argument, { } };
            }
            const auto width = width_mask(scalar_input[1]);
            if (!width)
                return MethodResult { iokit_abi::bad_argument, { } };
            const auto update_mask = scalar_input[3] & *width;
            auto& value = state.camera_sensor_variables[scalar_input[0]];
            value = ((value & *width) & ~update_mask) |
                    (scalar_input[2] & update_mask);
            return MethodResult { iokit_abi::success, { } };
        }
        return MethodResult { iokit_abi::unsupported, { } };
    }

    if (!is_kind_connection_locked(state, process, connection_object,
            KernelSharedState::IOKitUserClientKind::CameraAccelerator)) {
        return std::nullopt;
    }
    if (!scalar_input.empty() || scalar_output_capacity != 0U)
        return MethodResult { iokit_abi::bad_argument, { } };

    if (selector ==
        static_cast<std::uint32_t>(AcceleratorSelector::TransferSurface)) {
        if (inband_input.size() != 0x30U)
            return MethodResult { iokit_abi::bad_argument, { } };
        constexpr std::array<std::size_t, 7> option_offsets { 0U, 4U, 8U, 12U,
            16U, 20U, 44U };
        if (std::any_of(option_offsets.begin(), option_offsets.end(),
                [inband_input](std::size_t offset) {
                    return read_word(inband_input, offset) != 0U;
                })) {
            return MethodResult { iokit_abi::unsupported, { } };
        }
        const auto source_id = read_word(inband_input, 24U);
        const auto destination_id = read_word(inband_input, 28U);
        lock.unlock();
        return MethodResult { surfaces != nullptr &&
                                      surfaces->transfer_scaled(
                                          memory, source_id, destination_id)
                                  ? iokit_abi::success
                                  : iokit_abi::bad_argument,
            { } };
    }

    if (selector ==
        static_cast<std::uint32_t>(AcceleratorSelector::CaptureSurface)) {
        if (inband_input.size() != 0x3cU)
            return MethodResult { iokit_abi::bad_argument, { } };
        const auto callback = read_word(inband_input, 0U);
        const auto refcon = read_word(inband_input, 8U);
        const auto pixel_buffer = read_word(inband_input, 16U);
        auto connection =
            state.iokit_camera_accelerator_connections.find(connection_object);
        if (callback == 0U || read_word(inband_input, 4U) != 0U ||
            refcon == 0U || read_word(inband_input, 12U) != 0U ||
            pixel_buffer == 0U || read_word(inband_input, 20U) != 0U ||
            connection == state.iokit_camera_accelerator_connections.end() ||
            connection->second.notification_port == 0U) {
            return MethodResult { iokit_abi::bad_argument, { } };
        }
        ++connection->second.capture_sequence;
        const auto now = state.clock.now();
        const auto deadline = std::max(now + capture_period,
            connection->second.next_capture_deadline.value_or(now));
        connection->second.next_capture_deadline = deadline + capture_period;
        state.iokit_camera_capture_requests.push_back(
            KernelSharedState::IOKitCameraCaptureRequest { connection_object,
                callback, refcon, pixel_buffer, read_word(inband_input, 24U),
                connection->second.capture_sequence, deadline });
        return MethodResult { iokit_abi::success, { } };
    }

    std::size_t expected_size = 0U;
    switch (static_cast<AcceleratorSelector>(selector)) {
    case AcceleratorSelector::BlitSurface:
        expected_size = 0x50U;
        break;
    case AcceleratorSelector::AbortTransfers:
        expected_size = 0U;
        break;
    case AcceleratorSelector::AbortCaptures: {
        if (!inband_input.empty())
            return MethodResult { iokit_abi::bad_argument, { } };
        if (auto connection = state.iokit_camera_accelerator_connections.find(
                connection_object);
            connection != state.iokit_camera_accelerator_connections.end()) {
            for (const auto& request : state.iokit_camera_capture_requests) {
                if (request.connection_object != connection_object)
                    continue;
                state.enqueue_mach_message_locked(
                    connection->second.notification_port,
                    make_capture_completion(connection->second,
                        request.callback, request.refcon, request.pixel_buffer,
                        iokit_abi::aborted));
            }
            connection->second.next_capture_deadline.reset();
        }
        state.iokit_camera_capture_requests.erase(
            std::remove_if(state.iokit_camera_capture_requests.begin(),
                state.iokit_camera_capture_requests.end(),
                [connection_object](const auto& request) {
                    return request.connection_object == connection_object;
                }),
            state.iokit_camera_capture_requests.end());
        return MethodResult { iokit_abi::success, { } };
    }
    default:
        return MethodResult { iokit_abi::unsupported, { } };
    }
    return inband_input.size() == expected_size
               ? MethodResult { iokit_abi::success, { } }
               : MethodResult { iokit_abi::bad_argument, { } };
}

std::optional<std::uint64_t> next_capture_deadline_locked(
    const KernelSharedState& state)
{
    std::optional<std::uint64_t> deadline;
    for (const auto& request : state.iokit_camera_capture_requests) {
        if (!deadline || request.deadline < *deadline)
            deadline = request.deadline;
    }
    return deadline;
}

void service_due_captures(KernelSharedState& state, std::uint32_t process_id,
    AddressSpace& memory, SurfaceStore& surfaces, std::uint64_t deadline)
{
    struct DueCapture {
        KernelSharedState::IOKitCameraCaptureRequest request;
        KernelSharedState::IOKitCameraAcceleratorConnectionState connection;
    };
    std::vector<DueCapture> due;
    {
        std::lock_guard lock { state.mach_mutex };
        for (auto request = state.iokit_camera_capture_requests.begin();
            request != state.iokit_camera_capture_requests.end();) {
            const auto connection =
                state.iokit_connections.find(request->connection_object);
            const auto accelerator =
                state.iokit_camera_accelerator_connections.find(
                    request->connection_object);
            if (request->deadline > deadline) {
                ++request;
                continue;
            }
            if (connection == state.iokit_connections.end() ||
                accelerator ==
                    state.iokit_camera_accelerator_connections.end()) {
                request = state.iokit_camera_capture_requests.erase(request);
                continue;
            }
            if (connection->second.owner_pid != process_id) {
                ++request;
                continue;
            }
            due.push_back(DueCapture { *request, accelerator->second });
            request = state.iokit_camera_capture_requests.erase(request);
        }
    }

    for (const auto& capture : due) {
        const auto surface = surfaces.find(capture.request.surface_id);
        const auto frame =
            surface ? make_sensor_frame(*surface, capture.request.sequence)
                    : std::vector<std::uint32_t> { };
        const auto written =
            surface && surface_is_yuv422(surface->pixel_format) &&
            surfaces.write_argb(memory, capture.request.surface_id, frame);
        std::lock_guard lock { state.mach_mutex };
        if (!state.mach_port_objects.contains(
                capture.connection.notification_port)) {
            continue;
        }
        auto message = make_capture_completion(capture.connection,
            capture.request.callback, capture.request.refcon,
            capture.request.pixel_buffer);
        if (!written) {
            constexpr std::size_t completion_offset =
                darwin::mig_wire::message_header_size +
                2U * sizeof(std::uint32_t) +
                iokit_abi::display_vsync::async_reference_count *
                    sizeof(std::uint32_t);
            write_word(
                message.bytes, completion_offset, iokit_abi::bad_argument);
        }
        state.enqueue_mach_message_locked(
            capture.connection.notification_port, std::move(message));
    }
}

void close_connection_locked(
    KernelSharedState& state, std::uint32_t connection_object)
{
    state.iokit_camera_accelerator_connections.erase(connection_object);
    state.iokit_camera_capture_requests.erase(
        std::remove_if(state.iokit_camera_capture_requests.begin(),
            state.iokit_camera_capture_requests.end(),
            [connection_object](const auto& request) {
                return request.connection_object == connection_object;
            }),
        state.iokit_camera_capture_requests.end());
}

} // namespace shade::kernel_iokit::camera
