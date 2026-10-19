// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Dispatch virtual JPEG hardware requests to the host image encoder.

#include "kernel/kernel_iokit_jpeg.hpp"

#include <algorithm>
#include <array>
#include <mutex>
#include <string>
#include <string_view>
#include <utility>

#include "foundation/address_space.hpp"
#include "kernel/iokit_abi.hpp"
#include "media/jpeg_encoder.hpp"
#include "kernel/kernel_shared_state.hpp"
#include "graphics/surface_store.hpp"

namespace shade::kernel_iokit::jpeg {
namespace {

    constexpr std::size_t request_size = 0x28U;
    constexpr std::size_t source_surface_offset = 4U;
    constexpr std::size_t source_size_offset = 8U;
    constexpr std::size_t destination_surface_offset = 16U;
    constexpr std::size_t destination_size_offset = 20U;
    constexpr std::size_t encoded_size_offset = 24U;
    constexpr std::size_t width_offset = 28U;
    constexpr std::size_t height_offset = 32U;
    constexpr std::size_t format_offset = 36U;
    constexpr std::array<std::uint32_t, 2> packed_yuv422_formats { 4U, 5U };

    bool contains(std::span<const std::byte> matching, std::string_view value)
    {
        return std::search(matching.begin(), matching.end(), value.begin(),
                   value.end(), [](std::byte byte, char character) {
                       return std::to_integer<unsigned char>(byte) ==
                              static_cast<unsigned char>(character);
                   }) != matching.end();
    }

    bool supports_packed_yuv422(std::uint32_t format)
    {
        return std::ranges::find(packed_yuv422_formats, format) !=
               packed_yuv422_formats.end();
    }

    std::uint32_t read_word(
        std::span<const std::byte> bytes, std::size_t offset)
    {
        std::uint32_t value = 0U;
        for (std::size_t index = 0; index < sizeof(value); ++index) {
            value |= std::to_integer<std::uint32_t>(bytes[offset + index])
                     << (index * 8U);
        }
        return value;
    }

    void write_word(
        std::span<std::byte> bytes, std::size_t offset, std::uint32_t value)
    {
        for (std::size_t index = 0; index < sizeof(value); ++index) {
            bytes[offset + index] =
                static_cast<std::byte>((value >> (index * 8U)) & 0xffU);
        }
    }

    bool owns_jpeg_connection_locked(const KernelSharedState& state,
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
                   KernelSharedState::IOKitUserClientKind::JpegAccelerator;
    }

} // namespace

bool matches_service(std::span<const std::byte> matching)
{
    return contains(matching, service_class);
}

std::uint32_t ensure_service_locked(
    KernelSharedState& state, std::uint32_t platform_expert_object)
{
    if (state.jpeg_accelerator_service != 0U)
        return state.jpeg_accelerator_service;

    const auto object = state.allocate_mach_object();
    state.jpeg_accelerator_service = object;
    static_cast<void>(state.mach_port_objects.create(object));
    state.mach_queues.try_emplace(object);
    state.iokit_services.emplace(object,
        KernelSharedState::IOKitService { std::string { service_class },
            { "IOService" }, { },
            "IOService:/IOPlatformExpertDevice/" +
                std::string { service_class },
            platform_expert_object,
            KernelSharedState::IOKitUserClientKind::JpegAccelerator });
    return object;
}

std::optional<MethodResult> dispatch_connect_method(KernelSharedState& state,
    const ProcessContext& process, AddressSpace& memory, SurfaceStore* surfaces,
    std::uint32_t connection_object, std::uint32_t selector,
    std::span<const std::uint64_t> scalar_input,
    std::span<const std::byte> inband_input,
    std::uint32_t scalar_output_capacity, std::uint32_t inband_output_capacity)
{
    {
        std::lock_guard lock { state.mach_mutex };
        if (!owns_jpeg_connection_locked(state, process, connection_object))
            return std::nullopt;
    }
    if (!scalar_input.empty() || scalar_output_capacity != 0U)
        return MethodResult { iokit_abi::bad_argument, { } };

    if (selector == static_cast<std::uint32_t>(Selector::Initialize)) {
        if (!inband_input.empty() || inband_output_capacity != 0U)
            return MethodResult { iokit_abi::bad_argument, { } };
        return MethodResult { iokit_abi::success, { } };
    }
    if (selector != static_cast<std::uint32_t>(Selector::EncodeSurface))
        return MethodResult { iokit_abi::unsupported, { } };
    if (surfaces == nullptr || inband_input.size() != request_size ||
        inband_output_capacity < request_size ||
        read_word(inband_input, 0U) != 0U ||
        read_word(inband_input, 12U) != 0U ||
        !supports_packed_yuv422(read_word(inband_input, format_offset))) {
        return MethodResult { iokit_abi::bad_argument, { } };
    }

    const auto source_id = read_word(inband_input, source_surface_offset);
    const auto destination_id =
        read_word(inband_input, destination_surface_offset);
    const auto source = surfaces->find(source_id);
    const auto destination = surfaces->find(destination_id);
    const auto width = read_word(inband_input, width_offset);
    const auto height = read_word(inband_input, height_offset);
    const auto source_size = read_word(inband_input, source_size_offset);
    const auto destination_size =
        read_word(inband_input, destination_size_offset);
    const auto expected_source_size =
        static_cast<std::uint64_t>(width) * height * 2U;
    if (!source || !destination || width == 0U || height == 0U ||
        source->width != width || source->height != height ||
        expected_source_size > source_size ||
        source_size > source->allocation_size ||
        destination_size > destination->allocation_size) {
        return MethodResult { iokit_abi::bad_argument, { } };
    }

    const auto pixels = surfaces->read_argb(memory, source_id);
    if (!pixels)
        return MethodResult { iokit_abi::bad_argument, { } };
    const auto encoded = encode_jpeg_argb(*pixels, width, height);
    if (!encoded)
        return MethodResult { iokit_abi::unsupported, { } };
    if (encoded->size() > destination_size ||
        !surfaces->write_bytes(memory, destination_id, *encoded)) {
        return MethodResult { iokit_abi::no_memory, { } };
    }

    std::vector<std::byte> output(request_size);
    write_word(output, encoded_size_offset,
        static_cast<std::uint32_t>(encoded->size()));
    return MethodResult { iokit_abi::success, std::move(output) };
}

} // namespace shade::kernel_iokit::jpeg
