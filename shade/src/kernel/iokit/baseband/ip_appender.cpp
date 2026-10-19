// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "kernel/kernel_iokit_baseband.hpp"

#include "kernel/iokit_abi.hpp"

namespace shade::kernel_iokit::baseband {
namespace {

    // Native AppleIPAppender user-client operations. Its registry service and
    // interest notifications exist even when no modem data interface is up.
    enum class Selector : std::uint32_t {
        GetSleepTimeAdjustment = 6,
        SetLinkQualityMetric = 8,
        RestartDormancyCheck = 9,
        ReportThroughput = 11,
    };

} // namespace

MethodResult dispatch_ip_appender_method(std::uint32_t selector,
    std::span<const std::uint64_t> scalar_input,
    std::span<const std::byte> inband_input,
    std::uint32_t scalar_output_capacity,
    std::uint32_t inband_output_capacity)
{
    switch (static_cast<Selector>(selector)) {
    case Selector::GetSleepTimeAdjustment:
        if (!scalar_input.empty() || !inband_input.empty() ||
            scalar_output_capacity != 0U || inband_output_capacity < 8U)
            return { iokit_abi::bad_argument, { } };
        // The response is an ARM32 timeval (seconds, microseconds). Virtual
        // time does not lose elapsed time to a physical modem suspend cycle.
        return { iokit_abi::success, { }, std::vector<std::byte>(8U) };
    case Selector::SetLinkQualityMetric:
        if (scalar_input.size() != 1U || !inband_input.empty() ||
            scalar_output_capacity != 0U || inband_output_capacity != 0U)
            return { iokit_abi::bad_argument, { } };
        break;
    case Selector::RestartDormancyCheck:
        if (!scalar_input.empty() || !inband_input.empty() ||
            scalar_output_capacity != 0U || inband_output_capacity != 0U)
            return { iokit_abi::bad_argument, { } };
        break;
    case Selector::ReportThroughput:
        if (!scalar_input.empty() || inband_input.size() != 32U ||
            scalar_output_capacity != 0U || inband_output_capacity != 0U)
            return { iokit_abi::bad_argument, { } };
        break;
    default:
        return { iokit_abi::unsupported, { } };
    }
    // Advisory operations address the set of active modem network interfaces.
    // The current transport has none, so there is no physical link to update.
    return { iokit_abi::success, { } };
}

} // namespace shade::kernel_iokit::baseband
