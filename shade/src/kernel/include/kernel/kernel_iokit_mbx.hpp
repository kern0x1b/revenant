// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Implement virtual MBX user-client connections and command
// transport.

#pragma once

#include <cstddef>
#include <cstdint>
#include <optional>
#include <span>
#include <string_view>
#include <vector>

namespace shade {

class AddressSpace;
struct KernelSharedState;
struct ProcessContext;

namespace kernel_iokit::mbx {

    inline constexpr std::string_view service_class { "AppleMBXDevice" };

    [[nodiscard]] bool matches_service(std::span<const std::byte> matching);

    // The caller holds KernelSharedState::mach_mutex. The platform expert is
    // supplied by the registry owner so this hardware module does not need to
    // duplicate the guest registry hierarchy.
    [[nodiscard]] std::uint32_t ensure_service_locked(
        KernelSharedState& state, std::uint32_t platform_expert_object);

    struct MethodResult {
        std::uint32_t return_code { };
        std::vector<std::uint64_t> scalar_output;
        std::vector<std::byte> inband_output;
    };

    [[nodiscard]] std::optional<MethodResult> dispatch_connect_method(
        AddressSpace& memory, KernelSharedState& state,
        const ProcessContext& process, std::uint32_t connection_object,
        std::uint32_t selector, std::span<const std::uint64_t> scalar_input,
        std::span<const std::byte> inband_input,
        std::uint32_t scalar_output_capacity,
        std::uint32_t inband_output_capacity);

    // Explicit IOServiceClose still has the owning AddressSpace available, so
    // it can release command-transport resources immediately. Process teardown
    // owns the entire AddressSpace and only discards the shared-state metadata.
    void close_connection(AddressSpace& memory, KernelSharedState& state,
        std::uint32_t connection_object);

} // namespace kernel_iokit::mbx
} // namespace shade
