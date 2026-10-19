// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define guest IOKit MIG selectors, matching data and notification
// layouts.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/device/device.defs
// https://github.com/apple-oss-distributions/xnu/blob/xnu-1228.15.4/iokit/IOKit/OSMessageNotification.h

#pragma once

#include <cstdint>

namespace emulator::iokit_abi {

enum class Message : std::uint32_t {
    IteratorNext = 2802,
    ServiceGetMatchingServices = 2804,
    RegistryEntryGetProperty = 2805,
    RegistryEntryFromPath = 2809,
    ServiceOpen = 2815,
    ServiceClose = 2816,
    ConnectSetNotificationPort = 2818,
    ConnectMapMemory = 2819,
    RegistryGetRootEntry = 2827,
    RegistryEntrySetProperties = 2828,
    ServiceGetBusyState = 2831,
    ServiceAddNotification = 2849,
    ServiceAddInterestNotification = 2850,
    ConnectUnmapMemory = 2853,
    ServiceOpenExtended = 2862,
    ConnectMethod = 2865,
    ServiceGetMatchingService = 2872,
    ServiceGetMatchingServiceAfterVariableOutput = 2873,
};

namespace service_get_matching_service_v1 {

    inline constexpr std::uint32_t matching_count_offset = 36;
    inline constexpr std::uint32_t matching_offset = 40;
    inline constexpr std::uint32_t maximum_matching_size = 512;
    inline constexpr std::uint32_t minimum_port_reply_size = 40;

}

enum class MobileFramebufferSelector : std::uint32_t {
    GetLayerDefaultSurface = 3,
    SetVSyncNotificationsV1 = 8,
    SetVSyncNotifications = 9,
    RequestPowerChangeV2 = 12,
    RequestPowerChangeV1 = 13,
    RequestPowerChange = 14,
    SetWhiteOnBlackMode = 19,
    SetTVOutSignalType = 16,
    IsMainDisplay = 18,
    GetDigitalOutState = 25,
};

constexpr bool is_mobile_framebuffer_vsync_selector(std::uint32_t selector)
{
    return selector ==
               static_cast<std::uint32_t>(
                   MobileFramebufferSelector::SetVSyncNotificationsV1) ||
           selector == static_cast<std::uint32_t>(
                           MobileFramebufferSelector::SetVSyncNotifications);
}

constexpr bool is_mobile_framebuffer_power_selector(std::uint32_t selector)
{
    return selector == static_cast<std::uint32_t>(
                           MobileFramebufferSelector::RequestPowerChangeV2) ||
           selector == static_cast<std::uint32_t>(
                           MobileFramebufferSelector::RequestPowerChangeV1) ||
           selector == static_cast<std::uint32_t>(
                           MobileFramebufferSelector::RequestPowerChange);
}

inline constexpr std::uint32_t success = 0;
inline constexpr std::uint32_t no_memory = 0xe00002bdU;
inline constexpr std::uint32_t not_found = 0xe00002f0U;
inline constexpr std::uint32_t bad_argument = 0xe00002c2U;
inline constexpr std::uint32_t unsupported = 0xe00002c7U;
inline constexpr std::uint32_t aborted = 0xe00002ebU;

inline constexpr std::uint32_t service_busy_state_quiet = 0;

inline constexpr std::uint32_t mobile_framebuffer_service_type = 0;
inline constexpr std::uint32_t core_surface_root_service_type = 0;
inline constexpr std::uint32_t power_root_service_type = 0;
inline constexpr std::uint32_t generic_user_client_type = 0xffffffffU;

inline constexpr std::uint32_t mobile_framebuffer_default_surface_id = 0x100U;

namespace display_vsync {

    inline constexpr std::uint32_t message_identifier = 53;
    inline constexpr std::uint32_t async_completion_type = 150;
    inline constexpr std::uint32_t async_reference_count = 8;
    inline constexpr std::uint32_t async_reserved_index = 0;
    inline constexpr std::uint32_t async_callout_index = 1;
    inline constexpr std::uint32_t async_refcon_index = 2;
    inline constexpr std::uint32_t completion_argument_count = 6;
    inline constexpr std::uint32_t refresh_rate_hz = 60;
    inline constexpr std::uint64_t period_absolute_time =
        1'000'000'000ULL / refresh_rate_hz;

}

namespace service_open_extended {

    inline constexpr std::uint32_t request_descriptor_count = 2;
    inline constexpr std::uint32_t connect_type_offset = 60;
    inline constexpr std::uint32_t connect_type_size = sizeof(std::uint32_t);
    inline constexpr std::uint32_t reply_size = 52;
    inline constexpr std::uint32_t reply_word_count =
        reply_size / sizeof(std::uint32_t);
    inline constexpr std::uint32_t result_offset = 48;

}

namespace service_interest_notification {

    inline constexpr std::uint32_t request_descriptor_count = 1;
    inline constexpr std::uint32_t reply_size = 40;
    inline constexpr std::uint32_t maximum_interest_name_size = 128;
    inline constexpr std::uint32_t maximum_reference_count = 8;

}

namespace connect_method {

    inline constexpr std::uint32_t selector_offset = 32;
    inline constexpr std::uint32_t scalar_input_count_offset = 36;
    inline constexpr std::uint32_t scalar_input_offset = 40;
    inline constexpr std::uint32_t maximum_scalar_count = 16;
    inline constexpr std::uint32_t maximum_inband_size = 4096;
    inline constexpr std::uint32_t scalar_size = sizeof(std::uint64_t);
    inline constexpr std::uint32_t inband_count_size = sizeof(std::uint32_t);
    inline constexpr std::uint32_t natural32_ool_request_size =
        2 * sizeof(std::uint32_t);
    inline constexpr std::uint32_t mach_vm64_ool_request_size =
        4 * sizeof(std::uint32_t);
    inline constexpr std::uint32_t output_capacity_request_size =
        2 * sizeof(std::uint32_t);
    inline constexpr std::uint32_t trailing_request_size =
        2 * natural32_ool_request_size + output_capacity_request_size;
    inline constexpr std::uint32_t mach_vm64_trailing_request_size =
        2 * mach_vm64_ool_request_size + output_capacity_request_size;
    inline constexpr std::uint32_t minimum_request_size =
        scalar_input_offset + inband_count_size + trailing_request_size;

    inline constexpr std::uint32_t return_code_offset = 32;
    inline constexpr std::uint32_t scalar_output_count_offset = 36;
    inline constexpr std::uint32_t scalar_output_offset = 40;
    constexpr std::uint32_t inband_output_count_offset(
        std::uint32_t scalar_count)
    {
        return scalar_output_offset + scalar_count * scalar_size;
    }
    constexpr std::uint32_t inband_output_offset(std::uint32_t scalar_count)
    {
        return inband_output_count_offset(scalar_count) + sizeof(std::uint32_t);
    }
    constexpr std::uint32_t aligned_inband_output_size(
        std::uint32_t inband_count)
    {
        return (inband_count + sizeof(std::uint32_t) - 1U) &
               ~(sizeof(std::uint32_t) - 1U);
    }
    constexpr std::uint32_t out_of_line_output_size_offset(
        std::uint32_t scalar_count, std::uint32_t inband_count)
    {
        return inband_output_offset(scalar_count) +
               aligned_inband_output_size(inband_count);
    }
    constexpr std::uint32_t reply_size(
        std::uint32_t scalar_count, std::uint32_t inband_count)
    {
        return out_of_line_output_size_offset(scalar_count, inband_count) +
               sizeof(std::uint32_t);
    }
    inline constexpr std::uint32_t minimum_reply_size = reply_size(0, 0);
    inline constexpr std::uint32_t maximum_reply_size =
        reply_size(maximum_scalar_count, maximum_inband_size);
    inline constexpr std::uint32_t natural32_ool_reply_size =
        sizeof(std::uint32_t);
    inline constexpr std::uint32_t mach_vm64_ool_reply_size =
        2 * sizeof(std::uint32_t);
    inline constexpr std::uint32_t mach_vm64_minimum_reply_size =
        return_code_offset + sizeof(std::uint32_t) +
        sizeof(std::uint32_t) + sizeof(std::uint32_t) +
        mach_vm64_ool_reply_size;
    inline constexpr std::uint32_t firmware_receive_buffer_size = 0x10b8U;
    inline constexpr std::uint32_t mach_vm64_firmware_receive_buffer_size =
        0x10bcU;

}

}
