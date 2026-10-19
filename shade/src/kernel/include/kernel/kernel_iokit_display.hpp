// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Schedule virtual display vertical-sync notifications and callback
// delivery.

#pragma once

#include <cstddef>
#include <cstdint>
#include <optional>
#include <span>
#include <vector>

namespace shade {

class AddressSpace;
class Output;
struct KernelSharedState;
struct ProcessContext;

namespace kernel_iokit::display {

    struct MethodResult {
        std::uint32_t return_code { };
        std::vector<std::uint64_t> scalar_output;
    };

    [[nodiscard]] std::optional<MethodResult> dispatch_connect_method(
        KernelSharedState& state, const ProcessContext& process,
        std::uint32_t connection_object, std::uint32_t selector,
        std::span<const std::uint64_t> scalar_input,
        std::span<const std::byte> inband_input,
        std::uint32_t scalar_output_capacity);

    [[nodiscard]] std::optional<std::uint32_t> handle_notification_port_request(
        AddressSpace& memory, Output& output, KernelSharedState& state,
        ProcessContext& process, std::uint32_t message_id,
        std::uint32_t message_address, std::uint32_t send_size,
        std::uint32_t receive_size, std::uint32_t connection_object,
        std::uint32_t local_port);

    // Callers hold KernelSharedState::mach_mutex for the three scheduler
    // helpers.
    [[nodiscard]] std::optional<std::uint64_t> next_vsync_deadline_locked(
        const KernelSharedState& state);
    void remove_vsync_deadline_index_locked(
        KernelSharedState& state, std::uint32_t connection_object);
    void index_vsync_deadline_locked(
        KernelSharedState& state, std::uint32_t connection_object);
    void deliver_due_vsync_locked(
        KernelSharedState& state, std::uint64_t deadline);
    void close_connection_locked(
        KernelSharedState& state, std::uint32_t connection_object);

} // namespace kernel_iokit::display
} // namespace shade
