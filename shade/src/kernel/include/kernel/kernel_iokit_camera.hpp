// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Implement virtual camera service connections and capture state.

#pragma once

#include <cstddef>
#include <cstdint>
#include <optional>
#include <span>
#include <string_view>
#include <vector>

namespace shade {

class AddressSpace;
class Output;
class SurfaceStore;
struct KernelSharedState;
struct ProcessContext;

namespace kernel_iokit::camera {

    inline constexpr std::string_view sensor_service_class { "IOCameraSensor" };
    inline constexpr std::string_view capture_accelerator_service_class {
        "AppleH1CamIn"
    };
    inline constexpr std::string_view scaler_accelerator_service_class {
        "AppleM2ScalerCSCDriver"
    };

    enum class SensorSelector : std::uint32_t {
        ReadVariable = 3,
        WriteVariable = 4,
    };

    enum class AcceleratorSelector : std::uint32_t {
        TransferSurface = 0,
        CaptureSurface = 1,
        AbortTransfers = 2,
        AbortCaptures = 3,
        BlitSurface = 4,
    };

    struct MethodResult {
        std::uint32_t return_code { };
        std::vector<std::uint64_t> scalar_output;
    };

    [[nodiscard]] bool matches_sensor_service(
        std::span<const std::byte> matching);
    [[nodiscard]] std::optional<std::string_view> matching_accelerator_service(
        std::span<const std::byte> matching);

    // The caller holds KernelSharedState::mach_mutex. The platform expert is
    // supplied by the registry owner so this hardware module does not duplicate
    // the guest registry hierarchy.
    [[nodiscard]] std::uint32_t ensure_sensor_service_locked(
        KernelSharedState& state, std::uint32_t platform_expert_object);
    [[nodiscard]] std::uint32_t ensure_accelerator_service_locked(
        KernelSharedState& state, std::uint32_t platform_expert_object,
        std::string_view service_class);

    [[nodiscard]] std::optional<std::uint32_t> handle_notification_port_request(
        AddressSpace& memory, Output& output, KernelSharedState& state,
        const ProcessContext& process, std::uint32_t message_id,
        std::uint32_t message_address, std::uint32_t send_size,
        std::uint32_t receive_size, std::uint32_t connection_object,
        std::uint32_t local_port);

    // The caller holds KernelSharedState::mach_mutex.
    [[nodiscard]] std::optional<std::uint64_t> next_capture_deadline_locked(
        const KernelSharedState& state);
    void service_due_captures(KernelSharedState& state,
        std::uint32_t process_id, AddressSpace& memory, SurfaceStore& surfaces,
        std::uint64_t deadline);
    void close_connection_locked(
        KernelSharedState& state, std::uint32_t connection_object);

    [[nodiscard]] std::optional<MethodResult> dispatch_connect_method(
        KernelSharedState& state, const ProcessContext& process,
        AddressSpace& memory, SurfaceStore* surfaces,
        std::uint32_t connection_object, std::uint32_t selector,
        std::span<const std::uint64_t> scalar_input,
        std::span<const std::byte> inband_input,
        std::uint32_t scalar_output_capacity);

} // namespace kernel_iokit::camera
} // namespace shade
