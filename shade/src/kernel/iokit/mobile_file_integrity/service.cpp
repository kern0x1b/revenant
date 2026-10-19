// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Return process entitlement data through the guest AMFI user-client
// ABI.

#include "kernel/kernel_iokit_mobile_file_integrity.hpp"

#include "kernel/iokit_abi.hpp"
#include "kernel/kernel_shared_state.hpp"

#include <algorithm>
#include <mutex>
#include <string>
#include <utility>

namespace shade::kernel_iokit::mobile_file_integrity {
namespace {

    constexpr std::uint32_t load_entitlements_selector = 1U;
    constexpr std::size_t audit_token_word_count = 8U;
    constexpr std::size_t audit_token_pid_word = 5U;

    std::uint32_t read_little_endian_word(
        std::span<const std::byte> bytes, std::size_t offset)
    {
        std::uint32_t value = 0;
        for (std::size_t byte = 0; byte < sizeof(value); ++byte) {
            value |= std::to_integer<std::uint32_t>(bytes[offset + byte])
                     << (byte * 8U);
        }
        return value;
    }

} // namespace

bool matches_service(std::span<const std::byte> matching)
{
    return std::search(matching.begin(), matching.end(), service_class.begin(),
               service_class.end(), [](std::byte byte, char character) {
                   return std::to_integer<unsigned char>(byte) ==
                          static_cast<unsigned char>(character);
               }) != matching.end();
}

std::uint32_t ensure_service_locked(KernelSharedState& state)
{
    if (state.mobile_file_integrity_service != 0)
        return state.mobile_file_integrity_service;
    const auto object = state.allocate_mach_object();
    state.mobile_file_integrity_service = object;
    static_cast<void>(state.mach_port_objects.create(object));
    state.mach_queues.try_emplace(object);
    state.iokit_services.emplace(object,
        KernelSharedState::IOKitService { std::string { service_class },
            { "IOService" }, { }, { }, 0,
            KernelSharedState::IOKitUserClientKind::MobileFileIntegrity });
    return object;
}

std::optional<MethodResult> dispatch_connect_method(KernelSharedState& state,
    const ProcessContext& process, std::uint32_t connection_object,
    std::uint32_t selector, std::span<const std::uint64_t> scalar_input,
    std::span<const std::byte> inband_input,
    std::uint32_t scalar_output_capacity, std::uint32_t inband_output_capacity)
{
    std::lock_guard lock { state.mach_mutex };
    const auto connection = state.iokit_connections.find(connection_object);
    if (connection == state.iokit_connections.end() ||
        connection->second.owner_pid != process.pid) {
        return std::nullopt;
    }
    const auto service =
        state.iokit_services.find(connection->second.service_port);
    if (service == state.iokit_services.end() ||
        service->second.user_client_kind !=
            KernelSharedState::IOKitUserClientKind::MobileFileIntegrity) {
        return std::nullopt;
    }
    if (selector != load_entitlements_selector)
        return MethodResult { iokit_abi::unsupported, { } };
    constexpr auto audit_token_size =
        audit_token_word_count * sizeof(std::uint32_t);
    if (!scalar_input.empty() || inband_input.size() != audit_token_size ||
        scalar_output_capacity != 0U) {
        return MethodResult { iokit_abi::bad_argument, { } };
    }
    const auto target_pid = read_little_endian_word(
        inband_input, audit_token_pid_word * sizeof(std::uint32_t));
    const auto target = state.processes.find(target_pid);
    if (target == state.processes.end() ||
        target->second.code_signature_entitlements.empty()) {
        return MethodResult { iokit_abi::not_found, { } };
    }
    auto output = target->second.code_signature_entitlements;
    // IOCFUnserialize accepts a C string. The embedded entitlement blob stores
    // the exact XML bytes without a terminator, while the AMFI user-client ABI
    // returns a terminated in-band buffer.
    output.push_back(std::byte { 0 });
    if (output.size() > inband_output_capacity)
        return MethodResult { iokit_abi::bad_argument, { } };
    return MethodResult { iokit_abi::success, std::move(output) };
}

} // namespace shade::kernel_iokit::mobile_file_integrity
