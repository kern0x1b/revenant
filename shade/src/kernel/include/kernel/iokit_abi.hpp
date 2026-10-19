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

namespace shade::iokit_abi {

// Darwin 8 osfmk/device/device.defs subsystem iokit 2800. Later routines used
// by the iPhoneOS 1.0 IOKit build retain their firmware-observed IDs.
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
    // Private iPhoneOS-era extension retained by the firmware IOKit client.
    // The request ID is loaded by _io_connect_method in the 1.0 IOKit image.
    ConnectMethod = 2865,
    // Darwin 11 private inline counterpart to the generated plural iterator
    // routine. The firmware wrapper returns the first matching service port.
    ServiceGetMatchingService = 2872,
    ServiceGetMatchingServiceAfterVariableOutput = 2873,
};

namespace service_get_matching_service_v1 {

    // Firmware-observed ARM32 MIG request: header, NDR, element count, then a
    // compact inline serialized matching dictionary. The successful reply is
    // the standard single port descriptor used by other IOKit object calls.
    inline constexpr std::uint32_t matching_count_offset = 36;
    inline constexpr std::uint32_t matching_offset = 40;
    inline constexpr std::uint32_t maximum_matching_size = 512;
    inline constexpr std::uint32_t minimum_port_reply_size = 40;

} // namespace service_get_matching_service_v1

// IOMobileFramebuffer.framework exposes these selectors independently of the
// physical framebuffer driver class (AppleH1CLCD, AppleM2CLCD, ...). Keep the
// user-client contract named after that framework boundary so a device profile
// can select its native IORegistry class without changing the transport ABI.
enum class MobileFramebufferSelector : std::uint32_t {
    GetLayerDefaultSurface = 3,
    SetVSyncNotificationsV1 = 8,
    SetVSyncNotifications = 9,
    RequestPowerChangeV2 = 12,
    RequestPowerChangeV1 = 13,
    RequestPowerChange = 14,
    // Optional panel-mode control exposed by later framebuffer clients.  The
    // guest sends one scalar and expects only an IOKit return code; the host
    // compositor already owns the final pixel transform, so accepting this
    // capability is intentionally state-neutral.
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

// A zero busy count means the modeled I/O service tree has completed all
// outstanding start/stop transitions.
inline constexpr std::uint32_t service_busy_state_quiet = 0;

inline constexpr std::uint32_t mobile_framebuffer_service_type = 0;
inline constexpr std::uint32_t core_surface_root_service_type = 0;
inline constexpr std::uint32_t power_root_service_type = 0;
inline constexpr std::uint32_t generic_user_client_type = 0xffffffffU;

// CoreSurface IDs are transport handles, not guest pointers. Keep the display
// driver's reserved surface outside the IDs normally allocated at process
// startup; CoreSurfaceHle advances its allocator after a lookup of this ID.
inline constexpr std::uint32_t mobile_framebuffer_default_surface_id = 0x100U;

namespace display_vsync {

    // OSMessageNotification.h from XNU: a kernel async completion is Mach
    // message 53 with notification type 150 and an eight-natural reference.
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

} // namespace display_vsync

namespace service_open_extended {

    // Firmware-private routine 2862. It is absent from XNU device.defs, so
    // keep its observed request/reply contract separate from generated MIG
    // data.
    inline constexpr std::uint32_t request_descriptor_count = 2;
    // The 7A341 IOKit wrapper emits the connection type after two descriptors
    // and the NDR record. Older observed callers use a shorter request and
    // imply zero.
    inline constexpr std::uint32_t connect_type_offset = 60;
    inline constexpr std::uint32_t connect_type_size = sizeof(std::uint32_t);
    inline constexpr std::uint32_t reply_size = 52;
    inline constexpr std::uint32_t reply_word_count =
        reply_size / sizeof(std::uint32_t);
    inline constexpr std::uint32_t result_offset = 48;

} // namespace service_open_extended

namespace service_interest_notification {

    inline constexpr std::uint32_t request_descriptor_count = 1;
    inline constexpr std::uint32_t reply_size = 40;
    inline constexpr std::uint32_t maximum_interest_name_size = 128;
    inline constexpr std::uint32_t maximum_reference_count = 8;

} // namespace service_interest_notification

namespace connect_method {

    // Firmware-observed ARM32 MIG layout for io_connect_method. Scalar values
    // are 64-bit even though the guest is 32-bit. Variable request fields
    // following scalar_input and inband_input are compressed by MIG before
    // mach_msg.
    inline constexpr std::uint32_t selector_offset = 32;
    inline constexpr std::uint32_t scalar_input_count_offset = 36;
    inline constexpr std::uint32_t scalar_input_offset = 40;
    inline constexpr std::uint32_t maximum_scalar_count = 16;
    inline constexpr std::uint32_t maximum_inband_size = 4096;
    inline constexpr std::uint32_t scalar_size = sizeof(std::uint64_t);
    inline constexpr std::uint32_t inband_count_size = sizeof(std::uint32_t);
    // Legacy ARM clients encode each out-of-line address/size pair in two
    // natural_t words. Later clients use two 64-bit Mach VM values on each side
    // of the capacity words even though the client process is ARM32.
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

    // MIG compresses the reply to the actual scalar and inband counts.
    // Natural-32 clients rebase their fixed-array view by scalar_count * 8 -
    // 128, so inband output follows the last returned scalar rather than all 16
    // slots. Their final word reports the optional out-of-line output size.
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
    // Wide clients place the scalar array last and copy a two-word Mach VM
    // result after it. Both words are present even when the
    // optional out-of-line output is empty.
    inline constexpr std::uint32_t mach_vm64_ool_reply_size =
        2 * sizeof(std::uint32_t);
    inline constexpr std::uint32_t mach_vm64_minimum_reply_size =
        return_code_offset + sizeof(std::uint32_t) +
        sizeof(std::uint32_t) + sizeof(std::uint32_t) +
        mach_vm64_ool_reply_size;
    // Literal receive capacities passed by the firmware client stubs.
    inline constexpr std::uint32_t firmware_receive_buffer_size = 0x10b8U;
    inline constexpr std::uint32_t mach_vm64_firmware_receive_buffer_size =
        0x10bcU;

} // namespace connect_method

} // namespace shade::iokit_abi
