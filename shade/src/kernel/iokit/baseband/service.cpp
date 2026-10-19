// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Dispatch virtual IOKit baseband requests and offline transport
// operations.

#include "kernel/kernel_iokit_baseband.hpp"

#include "kernel/iokit_abi.hpp"
#include "kernel/kernel_shared_state.hpp"

#include <algorithm>
#include <limits>
#include <mutex>
#include <string>

namespace shade::kernel_iokit::baseband {

namespace {

    bool contains(std::span<const std::byte> matching, std::string_view value)
    {
        return std::search(matching.begin(), matching.end(), value.begin(),
                   value.end(), [](std::byte byte, char character) {
                       return std::to_integer<unsigned char>(byte) ==
                              static_cast<unsigned char>(character);
                   }) != matching.end();
    }

} // namespace

std::optional<ServiceKind> matching_service(
    std::span<const std::byte> matching)
{
    if (contains(matching, serial_multiplexer_class))
        return ServiceKind::SerialMultiplexer;
    if (contains(matching, ip_appender_class))
        return ServiceKind::IpAppender;
    if (contains(matching, service_class) || contains(matching, registry_name))
        return ServiceKind::Baseband;
    return std::nullopt;
}

std::uint32_t ensure_service_locked(
    KernelSharedState& state, ServiceKind profile)
{
    const auto class_name = profile == ServiceKind::SerialMultiplexer
                                ? serial_multiplexer_class
                            : profile == ServiceKind::IpAppender
                                ? ip_appender_class
                                : service_class;
    const auto existing = std::find_if(state.iokit_services.begin(),
        state.iokit_services.end(), [class_name](const auto& entry) {
            return entry.second.class_name == class_name;
        });
    if (existing != state.iokit_services.end())
        return existing->first;

    const auto object = state.allocate_mach_object();
    if (profile == ServiceKind::Baseband)
        state.baseband_service = object;
    else if (profile == ServiceKind::SerialMultiplexer)
        state.serial_multiplexer_service = object;
    static_cast<void>(state.mach_port_objects.create(object));
    state.mach_queues.try_emplace(object);
    const auto serial_multiplexer =
        profile == ServiceKind::SerialMultiplexer;
    state.iokit_services.emplace(object,
        KernelSharedState::IOKitService {
            std::string { class_name },
            { "IOService" }, { }, { }, 0,
            serial_multiplexer
                ? KernelSharedState::IOKitUserClientKind::SerialMultiplexer
                : KernelSharedState::IOKitUserClientKind::Generic });
    return object;
}

std::optional<MethodResult> dispatch_connect_method(KernelSharedState& state,
    const ProcessContext& process, std::uint32_t connection_object,
    std::uint32_t selector, std::span<const std::uint64_t> scalar_input,
    std::span<const std::byte> inband_input,
    std::uint32_t scalar_output_capacity,
    std::uint32_t inband_output_capacity)
{
    constexpr std::uint64_t nanoseconds_per_second = 1'000'000'000ULL;
    constexpr std::uint64_t nanoseconds_per_microsecond = 1'000ULL;

    std::lock_guard lock { state.mach_mutex };
    const auto connection = state.iokit_connections.find(connection_object);
    if (connection == state.iokit_connections.end() ||
        connection->second.owner_pid != process.pid) {
        return std::nullopt;
    }
    const auto service =
        state.iokit_services.find(connection->second.service_port);
    if (service == state.iokit_services.end()) {
        return std::nullopt;
    }

    if (service->second.class_name == ip_appender_class) {
        return dispatch_ip_appender_method(selector, scalar_input,
            inband_input, scalar_output_capacity, inband_output_capacity);
    }

    if (service->second.class_name == service_class) {
        if (selector ==
            static_cast<std::uint32_t>(BasebandSelector::SetPower)) {
            if (scalar_input.size() != 1U || scalar_input[0] > 1U ||
                !inband_input.empty() || scalar_output_capacity != 0U) {
                return MethodResult { iokit_abi::bad_argument, { } };
            }
            // This user-client call controls a physical modem power rail. An
            // offline endpoint has no rail to switch, so acknowledge either
            // boolean state without changing transport availability or
            // fabricating modem input.
            return MethodResult { iokit_abi::success, { } };
        }
        if (selector ==
            static_cast<std::uint32_t>(BasebandSelector::PowerCycle)) {
            if (!scalar_input.empty() || !inband_input.empty() ||
                scalar_output_capacity != 0U) {
                return MethodResult { iokit_abi::bad_argument, { } };
            }
            // The offline transport has no physical power rail or modem state
            // to reset. Completing the firmware's recovery command is
            // state-neutral; subsequent reads still observe the same empty
            // offline channel.
            return MethodResult { iokit_abi::success, { } };
        }
        return MethodResult { iokit_abi::unsupported, { } };
    }

    if (service->second.user_client_kind !=
        KernelSharedState::IOKitUserClientKind::SerialMultiplexer) {
        return std::nullopt;
    }

    if (selector ==
        static_cast<std::uint32_t>(SerialMultiplexerSelector::Configure)) {
        // The native driver uses these two scalars to tune its physical mux.
        // The virtual baseband transport already owns queueing and framing, but
        // retain the user-client ABI's strict shape instead of treating
        // arbitrary selectors as successful.
        if (scalar_input.size() != 2U || !inband_input.empty() ||
            scalar_output_capacity != 0U || scalar_input[0] == 0U ||
            scalar_input[1] == 0U ||
            scalar_input[0] > std::numeric_limits<std::uint32_t>::max() ||
            scalar_input[1] > std::numeric_limits<std::uint32_t>::max()) {
            return MethodResult { iokit_abi::bad_argument, { } };
        }
        return MethodResult { iokit_abi::success, { } };
    }

    if (selector == static_cast<std::uint32_t>(
                        SerialMultiplexerSelector::SetLinkQualityMetric)) {
        if (scalar_input.size() != 1U || !inband_input.empty() ||
            scalar_output_capacity != 0U) {
            return MethodResult { iokit_abi::bad_argument, { } };
        }
        // The native driver forwards this advisory metric to its physical
        // serial link. The offline transport has no link-quality state to
        // update, but the ABI operation itself still completes successfully.
        return MethodResult { iokit_abi::success, { } };
    }

    if (selector !=
        static_cast<std::uint32_t>(SerialMultiplexerSelector::GetTime))
        return MethodResult { iokit_abi::unsupported, { } };
    if (!scalar_input.empty() || !inband_input.empty())
        return MethodResult { iokit_abi::bad_argument, { } };

    // The selector is shape-overloaded across AppleSerialMultiplexer clients.
    // A command form has no output, while the query form requests a timeval
    // pair. Preserve both firmware-owned contracts without inventing a modem
    // response for the command form.
    if (scalar_output_capacity == 0U)
        return MethodResult { iokit_abi::success, { } };
    if (scalar_output_capacity < 2U)
        return MethodResult { iokit_abi::bad_argument, { } };

    // AppleSerialMultiplexer reports the kernel calendar as a timeval pair.
    // CommCenter converts seconds + microseconds/1000 into its millisecond
    // timeline, so source both fields from the same virtual calendar used by
    // gettimeofday instead of consulting the host clock independently.
    const auto wall_time = state.clock.wall_time();
    const auto seconds = wall_time / nanoseconds_per_second;
    const auto microseconds =
        (wall_time / nanoseconds_per_microsecond) % 1'000'000ULL;
    if (seconds > std::numeric_limits<std::uint32_t>::max())
        return MethodResult { iokit_abi::unsupported, { } };
    return MethodResult { iokit_abi::success, { seconds, microseconds } };
}

} // namespace shade::kernel_iokit::baseband
