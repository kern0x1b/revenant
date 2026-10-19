// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Implement the virtual JPEG device and guest encode requests.

#pragma once

#include <cstddef>
#include <cstdint>
#include <optional>
#include <span>
#include <vector>

namespace shade {

class AddressSpace;
class SurfaceStore;
struct KernelSharedState;
struct ProcessContext;

namespace kernel_iokit::jpeg {

    inline constexpr auto service_class = "AppleJPEGDriver";

    enum class Selector : std::uint32_t {
        Initialize = 2,
        EncodeSurface = 3,
    };

    struct MethodResult {
        std::uint32_t return_code { };
        std::vector<std::byte> inband_output;
    };

    [[nodiscard]] bool matches_service(std::span<const std::byte> matching);

    // The caller holds KernelSharedState::mach_mutex.
    [[nodiscard]] std::uint32_t ensure_service_locked(
        KernelSharedState& state, std::uint32_t platform_expert_object);

    [[nodiscard]] std::optional<MethodResult> dispatch_connect_method(
        KernelSharedState& state, const ProcessContext& process,
        AddressSpace& memory, SurfaceStore* surfaces,
        std::uint32_t connection_object, std::uint32_t selector,
        std::span<const std::uint64_t> scalar_input,
        std::span<const std::byte> inband_input,
        std::uint32_t scalar_output_capacity,
        std::uint32_t inband_output_capacity);

} // namespace kernel_iokit::jpeg
} // namespace shade
