// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Implement the virtual IOKit audio service and user-client
// operations.

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

namespace kernel_iokit::audio {

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

    [[nodiscard]] bool matches_service(std::span<const std::byte> matching);

    // The caller holds KernelSharedState::mach_mutex. IOAudio2 publishes one
    // service per physical endpoint, so matching returns the complete catalog.
    [[nodiscard]] std::vector<std::uint32_t> ensure_services_locked(
        KernelSharedState& state);

    [[nodiscard]] std::optional<std::uint32_t> handle_mach_request(
        AddressSpace& memory, Output& output, KernelSharedState& state,
        ProcessContext& process, std::uint32_t message_id,
        std::uint32_t message_address, std::uint32_t send_size,
        std::uint32_t receive_size, std::uint32_t connection_object,
        std::uint32_t local_port);

    // Explicit IOServiceClose still has the owning AddressSpace available, so
    // it can release the mapping immediately. Process teardown destroys the
    // whole AddressSpace and only needs to discard the shared-state metadata.
    void close_connection(AddressSpace& memory, KernelSharedState& state,
        std::uint32_t connection_object);

} // namespace kernel_iokit::audio
} // namespace shade
