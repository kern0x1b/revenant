// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Expose virtual telephony and carrier state to guest CoreTelephony
// clients.

#include "telephony/core_telephony_hle.hpp"

#include <algorithm>
#include <array>
#include <atomic>
#include <cstdint>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <string_view>
#include <utility>

#include "foundation/address_space.hpp"
#include "foundation/application_path.hpp"
#include "foundation/cpu.hpp"
#include "foundation/output.hpp"
#include "foundation/userland_hle.hpp"
#include "network/wifi_state.hpp"

namespace shade {
namespace {

    constexpr std::string_view core_telephony_image {
        "/CoreTelephony.framework/CoreTelephony"
    };
    constexpr std::string_view core_foundation_image {
        "/CoreFoundation.framework/CoreFoundation"
    };
    constexpr std::string_view springboard_image {
        "/System/Library/CoreServices/SpringBoard.app/SpringBoard"
    };
    constexpr std::array<std::string_view, 3> application_image_directories {
        "Applications/", "var/mobile/Applications/",
        "private/var/mobile/Applications/"
    };
    constexpr std::string_view offline_sim_status_export {
        "_kCTSIMSupportSIMStatusReady"
    };
    constexpr std::string_view create_call_from_info {
        "__CTCallCreateFromCallInfo"
    };
    constexpr std::string_view copy_next_call {
        "__CTServerConnectionCopyNextCall"
    };
    constexpr std::string_view copy_cf_string { "_CFStringGetCString" };
    constexpr std::string_view call_status_change_notification {
        "_kCTCallStatusChangeNotification"
    };
    constexpr std::string_view telephony_center_add_observer {
        "_CTTelephonyCenterAddObserver"
    };
    constexpr std::string_view notification_center_add_observer {
        "_CFNotificationCenterAddObserver"
    };
    constexpr std::string_view radio_module_dead_notification {
        "_kCTPowerRadioModuleDeadNotification"
    };
    constexpr std::string_view radio_module_dead_notification_text {
        "kCTPowerRadioModuleDeadNotification"
    };
    constexpr std::string_view call_dictionary_key { "_kCTCall" };
    constexpr std::string_view server_connection_callback {
        "__ServerConnectionCallback"
    };
    constexpr std::string_view cf_dictionary_create_mutable {
        "_CFDictionaryCreateMutable"
    };
    constexpr std::string_view cf_dictionary_set_value {
        "_CFDictionarySetValue"
    };
    constexpr std::string_view cf_dictionary_key_callbacks {
        "_kCFTypeDictionaryKeyCallBacks"
    };
    constexpr std::string_view cf_dictionary_value_callbacks {
        "_kCFTypeDictionaryValueCallBacks"
    };
    constexpr std::string_view cf_release { "_CFRelease" };
    // These are exported CF objects rather than callable entry points. Keep the
    // data and function dependencies separate so shared-cache mappings publish
    // __DATA exports without treating their bytes as executable code.
    constexpr std::array<std::string_view, 6> core_telephony_data_exports {
        "_kCTRegistrationStatusNotRegistered",
        "_kCTRegistrationNetworkSelectionModeDisabled",
        "_kCTRegistrationRadioAccessTechnologyUnknown",
        offline_sim_status_export,
        call_status_change_notification,
        call_dictionary_key,
    };
    constexpr std::array<std::string_view, 2> core_foundation_data_exports {
        cf_dictionary_key_callbacks,
        cf_dictionary_value_callbacks,
    };
    constexpr std::uint32_t cf_string_encoding_utf8 { 0x08000100U };
    constexpr std::uint32_t call_argument_words { 8U };
    constexpr std::uint32_t call_argument_bytes { call_argument_words *
                                                  sizeof(std::uint32_t) };
    constexpr std::uint32_t dialing_call_state { 2U };
    constexpr std::uint32_t disconnected_call_state { 4U };
    constexpr std::size_t maximum_dialed_number_bytes { 256U };
    // The offline transport has no modem to become ready. Report ENODEV in
    // CoreTelephony's POSIX error domain so firmware can use its native
    // no-equipment fallback instead of repeatedly sleeping on EAGAIN.
    constexpr std::uint32_t equipment_info_unavailable_error { 19U };

    // SpringBoard's private registration enum predates the public CoreTelephony
    // status objects. On the offline path, value 3 selects the firmware's
    // localized No Service view on the iPhoneOS 1.x-3.x SpringBoard builds in
    // this matrix; it is a UI state, not a modem or AT reply.
    constexpr std::uint32_t offline_springboard_registration_status { 3U };

    // These APIs have scalar return values in iPhoneOS 1.0. An offline handset
    // has no data attachment, active data context, signal, airplane mode, or
    // calls.
    constexpr std::array<std::string_view, 4> offline_scalar_queries {
        "_CTRegistrationGetDataAttached",
        "_CTRegistrationGetDataContextActive",
        "_CTGetSignalStrength",
        "_CTGetCurrentCallCount",
    };

    // These direct queries return retained CF objects. With no registered
    // carrier there is no operator or service-provider name to expose.
    constexpr std::array<std::string_view, 4> offline_direct_string_queries {
        "_CTRegistrationCopyAbbreviatedOperatorName",
        "_CTRegistrationCopyOperatorName",
        "_CTRegistrationCopyServiceProviderName",
        "_CTSettingCopyMyPhoneNumber",
    };

    // These server queries normally write a retained CFString through
    // argument 2. The offline profile has no CommCenter-backed values, so
    // terminate the queries at this HLE boundary.
    constexpr std::array<std::string_view, 6> offline_server_string_queries {
        "__CTServerConnectionCopyFirmwareVersion",
        "__CTServerConnectionCopySIMIdentity",
        "__CTServerConnectionCopyMobileIdentity",
        "__CTServerConnectionGetMobileSubscriberCountryCode",
        "__CTServerConnectionCopyOperatorName",
        "__CTServerConnectionCopyProviderName",
    };

    bool is_offline_ui_client(const UserlandHleCall& call)
    {
        if (call.image_loaded(springboard_image))
            return true;
        return std::any_of(application_image_directories.begin(),
            application_image_directories.end(), [&call](const auto directory) {
                return call.image_loaded_beneath(directory);
            });
    }

    std::uint32_t exported_object(
        UserlandHleCall& call, std::string_view variable)
    {
        const auto address = call.symbol_address(variable);
        return address ? call.memory().read32(*address).value_or(0) : 0;
    }

    void return_firmware_object(UserlandHleCall& call,
        std::string_view variable, bool force_offline = false)
    {
        if (!force_offline && !is_offline_ui_client(call)) {
            call.resume_original();
            return;
        }
        call.set_return(exported_object(call, variable));
    }

    void return_empty_server_string(UserlandHleCall& call, bool offline_transport)
    {
        if (!offline_transport && !is_offline_ui_client(call)) {
            call.resume_original();
            return;
        }
        const auto result = call.argument(0);
        const auto value_output = call.argument(2);
        if (result == 0 || value_output == 0 || !call.write32(result, 0) ||
            !call.write32(result + 4U, 0) || !call.write32(value_output, 0)) {
            call.set_return(0);
            return;
        }
        call.set_return(result);
    }

    void return_server_value(
        UserlandHleCall& call, std::uint32_t value, bool force_offline = false)
    {
        if (!force_offline && !is_offline_ui_client(call)) {
            call.resume_original();
            return;
        }
        const auto result = call.argument(0);
        const auto value_output = call.argument(2);
        if (result == 0 || value_output == 0 || !call.write32(result, 0) ||
            !call.write32(result + 4U, 0) ||
            !call.write32(value_output, value)) {
            call.set_return(0);
            return;
        }
        call.set_return(result);
    }

    bool is_radio_dead_notification(
        UserlandHleCall& call, std::uint32_t notification_argument)
    {
        const auto symbol = call.symbol_address(radio_module_dead_notification);
        if (symbol) {
            const auto notification = call.memory().read32(*symbol);
            if (notification &&
                call.argument(notification_argument) == *notification)
                return true;
        }
        // CFNotificationCenter and CTTelephonyCenter use the same constant
        // CFString, but a framework's imported pointer can be relocated per
        // task. Compare the constant's bytes as a fallback so the profile
        // remains independent of a particular shared-region slide.
        const auto object = call.argument(notification_argument);
        const auto data = call.memory().read32(object + 8U);
        const auto length = call.memory().read32(object + 12U);
        if (!data || !length ||
            *length != radio_module_dead_notification_text.size())
            return false;
        const auto bytes = call.memory().read_bytes(*data, *length);
        if (!bytes)
            return false;
        return std::equal(bytes->begin(), bytes->end(),
            radio_module_dead_notification_text.begin(),
            radio_module_dead_notification_text.end(),
            [](std::byte byte, char character) {
                return std::to_integer<unsigned char>(byte) ==
                       static_cast<unsigned char>(character);
            });
    }

    void return_server_boolean(UserlandHleCall& call, bool value)
    {
        if (!is_offline_ui_client(call)) {
            call.resume_original();
            return;
        }
        const auto result = call.argument(0);
        const auto value_output = call.argument(2);
        if (result == 0 || value_output == 0 || !call.write32(result, 0) ||
            !call.write32(result + 4U, 0) ||
            !call.memory().write8(value_output, value ? 1U : 0U)) {
            call.set_return(0);
            return;
        }
        call.set_return(result);
    }

    void return_server_success(UserlandHleCall& call)
    {
        if (!is_offline_ui_client(call)) {
            call.resume_original();
            return;
        }
        const auto result = call.argument(0);
        if (result == 0 || !call.write32(result, 0) ||
            !call.write32(result + 4U, 0)) {
            call.set_return(0);
            return;
        }
        call.set_return(result);
    }

    void return_server_success(UserlandHleCall& call, std::uint32_t result)
    {
        if (result == 0 || !call.write32(result, 0) ||
            !call.write32(result + 4U, 0)) {
            call.set_return(0);
            return;
        }
        call.set_return(result);
    }

    void return_server_failure(UserlandHleCall& call, std::uint32_t result,
        std::uint32_t call_output, std::uint32_t error)
    {
        if (call_output != 0) {
            static_cast<void>(call.write32(call_output, 0));
        }
        if (result != 0) {
            static_cast<void>(call.write32(result, 1));
            static_cast<void>(call.write32(result + 4U, error));
        }
        call.set_return(result);
    }

    struct OfflineCallRequest {
        std::uint32_t result { };
        std::uint32_t call_output { };
        std::uint32_t number { };
        struct Record {
            std::uint32_t dial_identifier { };
            std::uint32_t sequence { };
            std::uint32_t address { };
            // Preserve the server source verbatim. A null value is valid when
            // the firmware's telephony center has no live CommCenter transport,
            // and still selects its native UUID-map/object-reuse path.
            std::uint32_t source { };
        } record;
    };

    struct OfflineCallState {
        std::atomic<std::uint32_t> next_identifier { 1U };
        std::mutex mutex;
        std::map<std::uint32_t, OfflineCallRequest::Record> calls;
    };

    using CreatedCallContinuation =
        std::function<void(UserlandHleCall&, std::uint32_t)>;

    bool prepare_firmware_call(UserlandHleCall& call,
        const OfflineCallRequest::Record& record, std::uint32_t source,
        std::uint32_t call_state, std::uint32_t empty)
    {
        if (empty == 0)
            return false;
        auto& registers = call.cpu().registers();
        const auto caller_stack = registers[13];
        if (caller_stack < call_argument_bytes)
            return false;

        const auto call_stack = caller_stack - call_argument_bytes;
        const std::array<std::uint32_t, call_argument_words> arguments {
            0x694c5349U, // Fourth CFUUID word.
            record.address, // Dialed address.
            empty, // No network-provided display name.
            0U, // Start time is unknown while dialing.
            0U, // Connected duration.
            record.sequence, // Stable call identifier.
            call_state,
            record.dial_identifier,
        };
        for (std::size_t index = 0; index < arguments.size(); ++index) {
            if (!call.write32(call_stack + static_cast<std::uint32_t>(index) *
                                               static_cast<std::uint32_t>(
                                                   sizeof(std::uint32_t)),
                    arguments[index])) {
                return false;
            }
        }

        registers[0] = source;
        registers[1] = 0x694c6567U;
        registers[2] = call.process_id();
        registers[3] = record.sequence;
        registers[13] = call_stack;
        return true;
    }

    bool create_firmware_call(UserlandHleCall& call,
        const OfflineCallRequest::Record& record, std::uint32_t call_state,
        CreatedCallContinuation continuation)
    {
        if (!continuation)
            return false;
        const auto caller_stack = call.cpu().registers()[13];
        const auto empty = call.intern_string("");
        if (!prepare_firmware_call(
                call, record, record.source, call_state, empty))
            return false;
        auto& registers = call.cpu().registers();
        if (call.call_guest_function(create_call_from_info,
                [caller_stack, continuation = std::move(continuation)](
                    UserlandHleCall& completed) mutable {
                    completed.cpu().registers()[13] = caller_stack;
                    const auto created = completed.cpu().registers()[0];
                    continuation(completed, created);
                })) {
            return true;
        }
        registers[13] = caller_stack;
        return false;
    }

    bool create_firmware_call(UserlandHleCall& call,
        const OfflineCallRequest& request,
        const std::shared_ptr<OfflineCallState>& state)
    {
        return create_firmware_call(call, request.record, dialing_call_state,
            [request, state](
                UserlandHleCall& completed, std::uint32_t created) {
                if (created != 0 &&
                    completed.write32(request.call_output, created) &&
                    completed.write32(request.result, 0) &&
                    completed.write32(request.result + 4U, 0)) {
                    {
                        std::lock_guard lock { state->mutex };
                        state->calls.insert_or_assign(created, request.record);
                    }
                    completed.set_return(request.result);
                    return;
                }
                return_server_failure(
                    completed, request.result, request.call_output, 12U);
            });
    }

    void erase_offline_call(const std::shared_ptr<OfflineCallState>& state,
        std::uint32_t original_call)
    {
        std::lock_guard lock { state->mutex };
        state->calls.erase(original_call);
    }

    void release_disconnected_call(UserlandHleCall& call,
        const std::shared_ptr<OfflineCallState>& state,
        std::uint32_t original_call, std::uint32_t disconnected_call)
    {
        if (disconnected_call == 0 ||
            !call.continue_deferred_guest_function(
                cf_release,
                [disconnected_call](UserlandHleCall& release) {
                    release.cpu().registers()[0] = disconnected_call;
                },
                [state, original_call](UserlandHleCall&) {
                    erase_offline_call(state, original_call);
                })) {
            erase_offline_call(state, original_call);
        }
    }

    void release_disconnect_objects(UserlandHleCall& call,
        const std::shared_ptr<OfflineCallState>& state,
        std::uint32_t original_call, std::uint32_t dictionary,
        std::uint32_t disconnected_call)
    {
        if (dictionary == 0 ||
            !call.continue_deferred_guest_function(
                cf_release,
                [dictionary](UserlandHleCall& release) {
                    release.cpu().registers()[0] = dictionary;
                },
                [state, original_call, disconnected_call](
                    UserlandHleCall& released) {
                    release_disconnected_call(
                        released, state, original_call, disconnected_call);
                })) {
            release_disconnected_call(
                call, state, original_call, disconnected_call);
        }
    }

    void complete_disconnect_service(UserlandHleCall& call,
        std::uint32_t result, std::uint32_t original_call,
        const OfflineCallRequest::Record& record,
        const std::shared_ptr<OfflineCallState>& state)
    {
        const auto notification =
            exported_object(call, call_status_change_notification);
        const auto dictionary_key = exported_object(call, call_dictionary_key);
        const auto key_callbacks =
            call.symbol_address(cf_dictionary_key_callbacks).value_or(0);
        const auto value_callbacks =
            call.symbol_address(cf_dictionary_value_callbacks).value_or(0);
        const auto empty = call.intern_string("");
        const auto source = record.source;
        const auto queued =
            notification != 0 && dictionary_key != 0 && key_callbacks != 0 &&
            value_callbacks != 0 && empty != 0 &&
            call.defer_guest_function(
                create_call_from_info,
                [record, empty](UserlandHleCall& deferred) {
                    static_cast<void>(prepare_firmware_call(deferred, record,
                        record.source, disconnected_call_state, empty));
                },
                [state, notification, dictionary_key, key_callbacks,
                    value_callbacks, original_call,
                    source](UserlandHleCall& created) {
                    const auto disconnected_call = created.cpu().registers()[0];
                    const auto dictionary_queued =
                        disconnected_call != 0 &&
                        created.continue_deferred_guest_function(
                            cf_dictionary_create_mutable,
                            [key_callbacks, value_callbacks](
                                UserlandHleCall& deferred) {
                                auto& registers = deferred.cpu().registers();
                                registers[0] = 0;
                                registers[1] = 1U;
                                registers[2] = key_callbacks;
                                registers[3] = value_callbacks;
                            },
                            [state, notification, dictionary_key, original_call,
                                disconnected_call,
                                source](UserlandHleCall& dictionary_created) {
                                const auto dictionary =
                                    dictionary_created.cpu().registers()[0];
                                const auto value_queued =
                                    dictionary != 0 &&
                                    dictionary_created.continue_deferred_guest_function(
                                        cf_dictionary_set_value,
                                        [dictionary, dictionary_key,
                                            disconnected_call](
                                            UserlandHleCall& deferred) {
                                            auto& registers =
                                                deferred.cpu().registers();
                                            registers[0] = dictionary;
                                            registers[1] = dictionary_key;
                                            registers[2] = disconnected_call;
                                        },
                                        [state, notification, original_call,
                                            dictionary, disconnected_call,
                                            source](
                                            UserlandHleCall& value_set) {
                                            const auto handled =
                                                value_set.continue_deferred_guest_function(
                                                    server_connection_callback,
                                                    [source, notification,
                                                        dictionary](
                                                        UserlandHleCall&
                                                            deferred) {
                                                        auto& registers =
                                                            deferred.cpu()
                                                                .registers();
                                                        registers[0] = source;
                                                        registers[1] =
                                                            notification;
                                                        registers[2] =
                                                            dictionary;
                                                    },
                                                    [state, original_call,
                                                        dictionary,
                                                        disconnected_call](
                                                        UserlandHleCall&
                                                            completed) {
                                                        release_disconnect_objects(
                                                            completed, state,
                                                            original_call,
                                                            dictionary,
                                                            disconnected_call);
                                                    });
                                            if (!handled) {
                                                release_disconnect_objects(
                                                    value_set, state,
                                                    original_call, dictionary,
                                                    disconnected_call);
                                            }
                                        });
                                if (!value_queued) {
                                    release_disconnect_objects(
                                        dictionary_created, state,
                                        original_call, dictionary,
                                        disconnected_call);
                                }
                            });
                    if (!dictionary_queued) {
                        release_disconnected_call(
                            created, state, original_call, disconnected_call);
                    }
                });
        if (!queued)
            erase_offline_call(state, original_call);
        return_server_success(call, result);
    }

} // namespace

void register_core_telephony_hle(UserlandHleRegistry& registry)
{
    const auto wifi_state = std::make_shared<WifiState>();
    register_core_telephony_hle(registry, [wifi_state] { return wifi_state; });
}

void register_core_telephony_hle(UserlandHleRegistry& registry,
    WifiStateProvider wifi_state,
    std::function<void(const WifiSnapshot&, const WifiSnapshot&)>
        wifi_state_changed,
    bool offline_transport)
{
    for (const auto symbol : core_telephony_data_exports) {
        registry.register_guest_data_symbol(
            std::string { core_telephony_image }, std::string { symbol });
    }
    for (const auto symbol : core_foundation_data_exports) {
        registry.register_guest_data_symbol(
            std::string { core_foundation_image }, std::string { symbol });
    }
    for (const auto symbol : {
             copy_cf_string,
             cf_dictionary_create_mutable,
             cf_dictionary_set_value,
             cf_release,
         }) {
        registry.register_guest_function(
            std::string { core_foundation_image }, std::string { symbol });
    }
    // Every stock UI process shares one offline compatibility backend. Match
    // the application directory instead of maintaining a bundle whitelist,
    // while allowing CommCenter and other system daemons to keep their native
    // internal object lifecycles.
    // Without CommCenter, the stock method would keep the status controller in
    // its pre-check-in state and pass nil into SBStatusBarNoServiceView. Report
    // the already-implemented offline CoreTelephony boundary as checked in so
    // SpringBoard chooses and localizes its own NO_SERVICE/SEARCHING string.
    registry.register_objc_instance_method(std::string { springboard_image },
        "SBStatusBarController", "telephonyControllerCheckedIn",
        "-[SBStatusBarController telephonyControllerCheckedIn]",
        [](UserlandHleCall& call) { call.set_return(1); });

    registry.register_objc_instance_method(std::string { springboard_image },
        "SBTelephonyManager", "registrationStatus",
        "-[SBTelephonyManager registrationStatus]",
        [offline_transport](UserlandHleCall& call) {
            if (offline_transport && is_offline_ui_client(call)) {
                call.set_return(offline_springboard_registration_status);
                return;
            }
            call.resume_original_persistently();
        });
    // SBTelephonyManager registers this observer before it has any SIM or
    // service state. A silent transport is not evidence that a physical radio
    // died, so suppress only that firmware-owned observer in the offline
    // device profile. Other telephony notifications and every explicit
    // virtual/replay transport keep their native registration path.
    registry.register_function(std::string { core_telephony_image },
        std::string { telephony_center_add_observer },
        [offline_transport](UserlandHleCall& call) {
            if (offline_transport && is_offline_ui_client(call) &&
                // This firmware's private CoreTelephony wrapper receives
                // (center, observer, callback, name, context), so the name is
                // in r3 (confirmed by its native argument shuffle).
                is_radio_dead_notification(call, 3U)) {
                call.output().line(
                    "[telephony] offline radio-dead observer suppressed pid=" +
                    std::to_string(call.process_id()));
                call.set_return(0);
                return;
            }
            // Keep the boundary installed for later registrations in this
            // process. SpringBoard registers a group of telephony
            // notifications during SBTelephonyManager initialization; a
            // one-shot resume would let the later radio-dead registration
            // bypass the offline transport policy.
            call.resume_original_persistently();
        });
    registry.register_function(std::string { core_foundation_image },
        std::string { notification_center_add_observer },
        [offline_transport](UserlandHleCall& call) {
            if (offline_transport && is_offline_ui_client(call) &&
                // CFNotificationCenterAddObserver(center, observer,
                // callback, name, object, behavior) places it in r3.
                is_radio_dead_notification(call, 3U)) {
                call.output().line(
                    "[telephony] offline radio-dead observer suppressed pid=" +
                    std::to_string(call.process_id()));
                call.set_return(0);
                return;
            }
            // Keep the boundary installed for later Darwin notification
            // registrations in this process; only the offline radio-dead
            // notification is consumed above.
            call.resume_original_persistently();
        });

    // Preserve the firmware's CTCall CFRuntime object and MobilePhone flow.
    // Only adapt the missing baseband service reply into the same call-info
    // record that a real CommCenter response would have produced.
    const auto offline_calls = std::make_shared<OfflineCallState>();
    registry.register_function(std::string { core_telephony_image },
        "__CTServerConnectionCreateCall",
        [offline_calls](UserlandHleCall& call) {
            if (!is_offline_ui_client(call)) {
                call.resume_original();
                return;
            }

            OfflineCallRequest request {
                call.argument(0),
                call.argument(4),
                call.argument(2),
                {
                    call.argument(3),
                    offline_calls->next_identifier.fetch_add(
                        1U, std::memory_order_relaxed),
                    call.allocate_data(maximum_dialed_number_bytes, 1U),
                    call.argument(1),
                },
            };
            if (request.result == 0 || request.call_output == 0 ||
                request.number == 0 || request.record.address == 0) {
                return_server_failure(
                    call, request.result, request.call_output, 22U);
                return;
            }

            auto& registers = call.cpu().registers();
            registers[0] = request.number;
            registers[1] = request.record.address;
            registers[2] =
                static_cast<std::uint32_t>(maximum_dialed_number_bytes);
            registers[3] = cf_string_encoding_utf8;
            if (!call.call_guest_function(copy_cf_string,
                    [request, offline_calls](UserlandHleCall& copied) {
                        if (copied.cpu().registers()[0] == 0) {
                            return_server_failure(copied, request.result,
                                request.call_output, 22U);
                            return;
                        }
                        if (!create_firmware_call(
                                copied, request, offline_calls)) {
                            return_server_failure(copied, request.result,
                                request.call_output, 38U);
                        }
                    })) {
                return_server_failure(
                    call, request.result, request.call_output, 38U);
            }
        });
    registry.register_function(std::string { core_telephony_image },
        "__CTServerConnectionEndCall", [offline_calls](UserlandHleCall& call) {
            if (!is_offline_ui_client(call)) {
                call.resume_original();
                return;
            }

            const auto result = call.argument(0);
            const auto original_call = call.argument(2);
            OfflineCallRequest::Record record;
            bool found_call = false;
            {
                std::lock_guard lock { offline_calls->mutex };
                const auto found = offline_calls->calls.find(original_call);
                if (found != offline_calls->calls.end()) {
                    record = found->second;
                    found_call = true;
                }
            }
            if (result == 0 || original_call == 0 || !found_call) {
                return_server_success(call, result);
                return;
            }
            complete_disconnect_service(
                call, result, original_call, record, offline_calls);
        });
    registry.register_function(std::string { core_telephony_image },
        std::string { copy_next_call }, [](UserlandHleCall& call) {
            if (!is_offline_ui_client(call)) {
                call.resume_original();
                return;
            }
            static_cast<void>(call.write32(call.argument(2), 0));
            static_cast<void>(call.write32(call.argument(3), 0));
            return_server_success(call, call.argument(0));
        });
    for (const auto symbol : offline_scalar_queries) {
        registry.register_function(std::string { core_telephony_image },
            std::string { symbol }, [](UserlandHleCall& call) {
                if (is_offline_ui_client(call)) {
                    call.set_return(0);
                } else {
                    call.resume_original();
                }
            });
    }
    registry.register_function(std::string { core_telephony_image },
        "__CTServerConnectionCallListEnd",
        [offline_calls](UserlandHleCall& call) {
            if (!is_offline_ui_client(call)) {
                call.resume_original();
                return;
            }

            const auto result = call.argument(0);
            std::uint32_t original_call = 0;
            OfflineCallRequest::Record record;
            {
                std::lock_guard lock { offline_calls->mutex };
                for (const auto& [candidate, candidate_record] :
                    offline_calls->calls) {
                    if (original_call == 0 ||
                        candidate_record.sequence > record.sequence) {
                        original_call = candidate;
                        record = candidate_record;
                    }
                }
            }
            if (result == 0 || original_call == 0) {
                return_server_success(call, result);
                return;
            }
            complete_disconnect_service(
                call, result, original_call, record, offline_calls);
        });
    registry.register_function(std::string { core_telephony_image },
        "_CTPowerGetAirplaneMode", [wifi_state](UserlandHleCall& call) {
            if (!is_offline_ui_client(call)) {
                call.resume_original();
                return;
            }
            const auto state = wifi_state ? wifi_state() : nullptr;
            call.set_return(state && state->snapshot().airplane_mode ? 1U : 0U);
        });
    registry.register_function(std::string { core_telephony_image },
        "_CTPowerSetAirplaneMode",
        [wifi_state, wifi_state_changed](UserlandHleCall& call) {
            if (!is_offline_ui_client(call)) {
                call.resume_original();
                return;
            }
            const auto state = wifi_state ? wifi_state() : nullptr;
            if (!state) {
                call.set_return(0);
                return;
            }
            const auto before = state->snapshot();
            static_cast<void>(state->set_airplane_mode(call.argument(0) != 0));
            const auto after = state->snapshot();
            if (wifi_state_changed)
                wifi_state_changed(before, after);
            call.set_return(0);
        });

    registry.register_function(std::string { core_telephony_image },
        "_CTRegistrationGetStatus", [](UserlandHleCall& call) {
            return_firmware_object(call, "_kCTRegistrationStatusNotRegistered");
        });
    registry.register_function(std::string { core_telephony_image },
        "_CTRegistrationGetNetworkSelectionMode", [](UserlandHleCall& call) {
            return_firmware_object(
                call, "_kCTRegistrationNetworkSelectionModeDisabled");
        });
    registry.register_function(std::string { core_telephony_image },
        "_CTSIMSupportGetSIMStatus",
        [offline_transport](UserlandHleCall& call) {
            // The offline transport intentionally has no modem, but stock
            // SpringBoard turns NotInserted into a blocking modal. Expose the
            // simulator's logical SIM-ready capability instead; explicit
            // replay/virtual transports continue through their native path.
            if (offline_transport) {
                return_firmware_object(call, offline_sim_status_export, true);
            }
            call.resume_original();
        });
    for (const auto symbol : offline_direct_string_queries) {
        registry.register_function(std::string { core_telephony_image },
            std::string { symbol },
            [](UserlandHleCall& call) { call.set_return(0); });
    }
    for (const auto symbol : offline_server_string_queries) {
        registry.register_function(std::string { core_telephony_image },
            std::string { symbol }, [offline_transport](UserlandHleCall& call) {
                return_empty_server_string(call, offline_transport);
            });
    }
    registry.register_function(std::string { core_telephony_image },
        "__CTServerConnectionGetRadioAccessTechnology",
        [offline_transport](UserlandHleCall& call) {
            if (!offline_transport) {
                call.resume_original();
                return;
            }
            // An unregistered offline radio has no selected access technology.
            // Use the firmware's own constant, also for daemon audio clients.
            return_server_value(call,
                exported_object(
                    call, "_kCTRegistrationRadioAccessTechnologyUnknown"),
                true);
        });
    registry.register_function(std::string { core_telephony_image },
        "__CTServerConnectionGetEmergencyCallBackMode",
        [offline_transport](UserlandHleCall& call) {
            if (!offline_transport) {
                call.resume_original();
                return;
            }
            // An offline transport cannot enter emergency callback mode.
            // This is a known inactive state, not an equipment lookup failure:
            // clients use it when refreshing their idle timers, and a server
            // error would trigger connection recovery on every input event.
            // The native status output is a Boolean byte, not a CF object.
            if (call.argument(2) != 0)
                static_cast<void>(call.memory().write8(call.argument(2), 0));
            return_server_success(call, call.argument(0));
        });
    registry.register_function(std::string { core_telephony_image },
        "__CTServerConnectionCopySystemCapabilities",
        [offline_transport](UserlandHleCall& call) {
            if (!offline_transport) {
                call.resume_original();
                return;
            }
            // The native API returns a retained dictionary and a byte-sized
            // availability flag. An offline modem cannot supply either.
            if (call.argument(3) != 0) {
                static_cast<void>(
                    call.memory().write8(call.argument(3), 0));
            }
            return_server_failure(call, call.argument(0), call.argument(2),
                equipment_info_unavailable_error);
        });
    // These queries require physical modem/SIM data. The offline transport
    // cannot provide it, including to system services starting before
    // CommCenter. Let each native client handle the missing hardware result.
    for (const auto symbol : {
             "__CTServerConnectionCopyMobileEquipmentInfo",
             "__CTServerConnectionCopyAudioVocoderInfo",
             "__CTServerConnectionCopyGid1",
             "__CTServerConnectionCopyGid2",
         }) {
        registry.register_function(std::string { core_telephony_image }, symbol,
            [offline_transport](UserlandHleCall& call) {
                if (!offline_transport) {
                    call.resume_original();
                    return;
                }
                return_server_failure(call, call.argument(0), call.argument(2),
                    call.argument(1) && call.argument(2)
                        ? equipment_info_unavailable_error
                        : 22U);
            });
    }
    registry.register_function(std::string { core_telephony_image },
        "__CTServerConnectionGetSIMStatus",
        [offline_transport](UserlandHleCall& call) {
            if (offline_transport) {
                return_server_value(call,
                    exported_object(call, offline_sim_status_export), true);
                return;
            }
            call.resume_original();
        });

    // The offline adapter supplies service results directly, so registration
    // cannot produce remote CommCenter updates and is a successful no-op.
    for (const auto symbol : {
             "__CTServerConnectionRegisterForNotification",
             "__CTServerConnectionUnregisterForNotification",
         }) {
        registry.register_function(std::string { core_telephony_image }, symbol,
            [](UserlandHleCall& call) { return_server_success(call); });
    }
    registry.register_function(std::string { core_telephony_image },
        "__CTServerConnectionSetCTMMode",
        [](UserlandHleCall& call) { return_server_success(call); });
    registry.register_function(std::string { core_telephony_image },
        "__CTServerConnectionNetworkTimeUpdatesAllowed",
        [](UserlandHleCall& call) { return_server_boolean(call, false); });
    // Automatic carrier selection eventually dereferences the connection's
    // CommCenter CFMachPort. Baseband transport is intentionally parked, so
    // terminate the request at the user-space CoreTelephony boundary.
    registry.register_function(std::string { core_telephony_image },
        "__CTServerConnectionSelectNetwork",
        [](UserlandHleCall& call) { return_server_success(call); });
}

} // namespace shade
