// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Implement virtual HID service discovery, event queues and
// notifications.

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
struct KernelSharedState;
struct ProcessContext;

namespace kernel_iokit::hid {

    inline constexpr std::string_view service_class { "AppleMultitouchSPI" };

    struct MethodResult {
        std::uint32_t return_code { };
        std::vector<std::uint64_t> scalar_output;
        std::vector<std::byte> inband_output;
    };

    [[nodiscard]] bool matches_service(std::span<const std::byte> matching);

    // The caller holds KernelSharedState::mach_mutex.
    [[nodiscard]] std::uint32_t ensure_service_locked(
        KernelSharedState& state, std::uint32_t parent_object);

    [[nodiscard]] std::optional<MethodResult> dispatch_connect_method(
        KernelSharedState& state, const ProcessContext& process,
        std::uint32_t connection_object, std::uint32_t selector,
        std::span<const std::uint64_t> scalar_input,
        std::span<const std::byte> inband_input,
        std::uint32_t scalar_output_capacity,
        std::uint32_t inband_output_capacity);

    [[nodiscard]] std::optional<std::uint32_t> handle_mach_request(
        AddressSpace& memory, Output& output, KernelSharedState& state,
        const ProcessContext& process, std::uint32_t message_id,
        std::uint32_t message_address, std::uint32_t send_size,
        std::uint32_t receive_size, std::uint32_t connection_object,
        std::uint32_t local_port);

    void close_connection(AddressSpace& memory, KernelSharedState& state,
        std::uint32_t connection_object);

} // namespace kernel_iokit::hid
} // namespace shade
