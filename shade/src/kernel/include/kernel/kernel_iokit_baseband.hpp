// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Implement the virtual IOKit baseband service and offline transport
// state.

#pragma once

#include <cstddef>
#include <cstdint>
#include <optional>
#include <span>
#include <string_view>
#include <vector>

namespace shade {

struct KernelSharedState;
struct ProcessContext;

namespace kernel_iokit::baseband {

    inline constexpr std::string_view service_class { "AppleBaseband" };
    inline constexpr std::string_view serial_multiplexer_class {
        "AppleSerialMultiplexer"
    };
    inline constexpr std::string_view registry_name { "baseband" };
    inline constexpr std::string_view ip_appender_class { "AppleIPAppender" };

    enum class ServiceKind {
        Baseband,
        SerialMultiplexer,
        IpAppender,
    };

    enum class SerialMultiplexerSelector : std::uint32_t {
        Configure = 0,
        GetTime = 2,
        SetLinkQualityMetric = 5,
    };

    enum class BasebandSelector : std::uint32_t {
        SetPower = 1,
        PowerCycle = 7,
    };

    struct MethodResult {
        std::uint32_t return_code { };
        std::vector<std::uint64_t> scalar_output;
        std::vector<std::byte> inband_output { };
    };

    [[nodiscard]] MethodResult dispatch_ip_appender_method(
        std::uint32_t selector, std::span<const std::uint64_t> scalar_input,
        std::span<const std::byte> inband_input,
        std::uint32_t scalar_output_capacity,
        std::uint32_t inband_output_capacity);

    [[nodiscard]] std::optional<ServiceKind> matching_service(
        std::span<const std::byte> matching);

    // The caller holds KernelSharedState::mach_mutex.
    [[nodiscard]] std::uint32_t ensure_service_locked(
        KernelSharedState& state, ServiceKind profile);

    [[nodiscard]] std::optional<MethodResult> dispatch_connect_method(
        KernelSharedState& state, const ProcessContext& process,
        std::uint32_t connection_object, std::uint32_t selector,
        std::span<const std::uint64_t> scalar_input,
        std::span<const std::byte> inband_input,
        std::uint32_t scalar_output_capacity,
        std::uint32_t inband_output_capacity = 0);

} // namespace kernel_iokit::baseband
} // namespace shade
