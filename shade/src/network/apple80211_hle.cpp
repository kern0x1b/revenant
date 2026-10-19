// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Adapt guest Apple80211 queries and commands to virtual wireless
// state.

#include "network/apple80211_hle.hpp"

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <string>
#include <string_view>
#include <utility>

#include "foundation/address_space.hpp"
#include "foundation/cpu.hpp"
#include "foundation/output.hpp"
#include "foundation/userland_hle.hpp"

namespace shade {
namespace {

    constexpr std::string_view aeropuerto_image {
        "/System/Library/SystemConfiguration/Aeropuerto.bundle/Aeropuerto"
    };
    constexpr std::string_view preferences_image {
        "/Preferences.framework/Preferences"
    };
    constexpr std::array apple80211_provider_images {
        aeropuerto_image,
        preferences_image,
    };
    constexpr std::string_view interface_name { "en0" };
    constexpr std::uint32_t power_changed_event = 1;
    constexpr std::uint32_t ssid_changed_event = 2;
    constexpr std::uint32_t bssid_changed_event = 3;
    constexpr std::uint32_t link_changed_event = 4;
    constexpr std::uint32_t association_done_event = 9;
    constexpr std::uint32_t scan_done_event = 10;
    constexpr std::uint32_t callback_stack_scratch_space = 16;
    constexpr std::uint32_t arm_user_mode = 0x10;
    constexpr std::uint32_t arm_thumb_state_bit = 1U << 5U;

} // namespace

Apple80211Hle::Apple80211Hle(UserlandHleRegistry& registry,
    std::shared_ptr<WifiState> state, StateChangedHandler state_changed)
    : state_ { state ? std::move(state) : std::make_shared<WifiState>() }
    , state_changed_ { std::move(state_changed) }
    , registry_ { registry }
{
    const auto add = [&](const std::string& symbol,
                         const UserlandHleRegistry::Handler& handler) {
        for (const auto image : apple80211_provider_images) {
            registry.register_function(std::string { image }, symbol, handler);
        }
    };

    add("_Apple80211GetPower", [this](UserlandHleCall& call) {
        if (!valid_handle(call, call.argument(0)) || call.argument(1) == 0 ||
            !call.memory().write8(
                call.argument(1), state_->snapshot().powered ? 1U : 0U)) {
            call.set_return(apple80211_abi::invalid_argument);
            return;
        }
        call.set_return(apple80211_abi::success);
    });

    add("_Apple80211SetPower", [this](UserlandHleCall& call) {
        if (!valid_handle(call, call.argument(0))) {
            call.set_return(apple80211_abi::invalid_argument);
            return;
        }
        const auto before = state_->snapshot();
        const auto powered = call.argument(1) != 0;
        static_cast<void>(state_->set_power(powered));
        notify_change(before);
        call.set_return(apple80211_abi::success);
    });

    add("_Apple80211Associate", [this](UserlandHleCall& call) {
        if (!valid_handle(call, call.argument(0)) || call.argument(1) == 0) {
            call.set_return(apple80211_abi::invalid_argument);
            return;
        }
        const auto before = state_->snapshot();
        if (!state_->associate()) {
            call.set_return(apple80211_abi::invalid_argument);
            return;
        }
        notify_change(before);
        call.set_return(apple80211_abi::success);
    });

    add("_Apple80211EventMonitoringInit", [this](UserlandHleCall& call) {
        const auto handle = call.argument(0);
        const auto callback = call.argument(1);
        if (!valid_handle(call, handle) || callback == 0) {
            call.set_return(apple80211_abi::invalid_argument);
            return;
        }
        const auto process_id = call.process_id();
        const auto context = call.argument(2);
        call.resume_original_persistently(
            [this, process_id, handle, callback, context](
                UserlandHleCall& completed) {
                if (completed.argument(0) != apple80211_abi::success) {
                    return;
                }
                const auto scan_result_address =
                    completed.allocate_data(sizeof(std::uint32_t));
                if (scan_result_address == 0)
                    return;
                std::lock_guard broker_lock { event_broker_->mutex };
                event_broker_->registrations[process_id][handle] = {
                    .callback = callback,
                    .context = context,
                    .scan_result_address = scan_result_address,
                    .memory = &completed.memory(),
                    .processor = completed.cpu().processor_id(),
                    .scan_pending = false,
                    .callback_in_flight = false,
                    .inject_event = event_injection_handler_,
                    .monitored_events = { },
                };
            });
    });

    add("_Apple80211EventMonitoringHalt", [this](UserlandHleCall& call) {
        const auto handle = call.argument(0);
        if (!valid_handle(call, handle)) {
            call.set_return(apple80211_abi::invalid_argument);
            return;
        }
        const auto process_id = call.process_id();
        call.resume_original_persistently(
            [this, process_id, handle](UserlandHleCall&) {
                std::lock_guard broker_lock { event_broker_->mutex };
                event_broker_->registrations[process_id].erase(handle);
            });
    });

    add("_Apple80211StartMonitoringEvent", [this](UserlandHleCall& call) {
        const auto handle = call.argument(0);
        call.resume_original_persistently([this, process_id = call.process_id(),
                                              handle, event = call.argument(1)](
                                              UserlandHleCall& completed) {
            if (completed.argument(0) != apple80211_abi::success)
                return;
            std::lock_guard broker_lock { event_broker_->mutex };
            const auto process = event_broker_->registrations.find(process_id);
            if (process != event_broker_->registrations.end() &&
                process->second.contains(handle)) {
                process->second.at(handle).monitored_events.insert(event);
            }
        });
    });

    add("_Apple80211StopMonitoringEvent", [this](UserlandHleCall& call) {
        const auto handle = call.argument(0);
        call.resume_original_persistently([this, process_id = call.process_id(),
                                              handle, event = call.argument(1)](
                                              UserlandHleCall& completed) {
            if (completed.argument(0) != apple80211_abi::success)
                return;
            std::lock_guard broker_lock { event_broker_->mutex };
            const auto process = event_broker_->registrations.find(process_id);
            if (process != event_broker_->registrations.end() &&
                process->second.contains(handle)) {
                process->second.at(handle).monitored_events.erase(event);
            }
        });
    });

    add("_Apple80211ScanAsync", [this](UserlandHleCall& call) {
        const auto handle = call.argument(0);
        const auto parameters = call.argument(1);
        std::lock_guard broker_lock { event_broker_->mutex };
        const auto process =
            event_broker_->registrations.find(call.process_id());
        if (!valid_handle(call, handle) ||
            process == event_broker_->registrations.end() ||
            !process->second.contains(handle)) {
            call.set_return(apple80211_abi::invalid_argument);
            return;
        }
        auto& registration = process->second.at(handle);
        if (!registration.monitored_events.contains(scan_done_event) ||
            registration.callback == 0) {
            call.set_return(apple80211_abi::invalid_argument);
            return;
        }
        if (registration.callback_in_flight) {
            // A successful asynchronous request promises a later completion.
            // Reject recursive requests instead of acknowledging one that the
            // service cannot complete while its callback is still running.
            call.set_return(apple80211_abi::invalid_argument);
            return;
        }
        auto& registers = call.cpu().registers();
        if (registration.scan_pending ||
            !call.memory().write32(registration.scan_result_address, 0)) {
            call.set_return(apple80211_abi::invalid_argument);
            return;
        }
        registration.scan_pending = true;
        registers[0] = handle;
        registers[1] = registration.scan_result_address;
        registers[2] = parameters;
        if (!call.tail_call_registered("_Apple80211Scan")) {
            registration.scan_pending = false;
            call.set_return(apple80211_abi::invalid_argument);
        }
    });

    add("_Apple80211Scan", [this](UserlandHleCall& call) {
        const auto handle = call.argument(0);
        {
            std::lock_guard broker_lock { event_broker_->mutex };
            const auto process =
                event_broker_->registrations.find(call.process_id());
            if (process == event_broker_->registrations.end() ||
                !process->second.contains(handle) ||
                !process->second.at(handle).scan_pending) {
                call.resume_original_persistently();
                return;
            }
        }
        const auto process_id = call.process_id();
        call.resume_original_persistently([this, process_id, handle](
                                              UserlandHleCall& completed) {
            std::lock_guard broker_lock { event_broker_->mutex };
            const auto registrations =
                event_broker_->registrations.find(process_id);
            if (registrations == event_broker_->registrations.end() ||
                !registrations->second.contains(handle)) {
                completed.set_return(apple80211_abi::invalid_argument);
                return;
            }
            auto& registration = registrations->second.at(handle);
            registration.scan_pending = false;
            const auto scan_result = completed.argument(0);
            const auto results =
                completed.memory().read32(registration.scan_result_address);
            if (scan_result != apple80211_abi::success || !results ||
                *results == 0 || registration.callback == 0) {
                completed.set_return(scan_result != apple80211_abi::success
                                         ? scan_result
                                         : apple80211_abi::invalid_argument);
                return;
            }
            event_broker_->pending_events.push_back({
                .process_id = process_id,
                .handle = handle,
                .callback = registration.callback,
                .context = registration.context,
                .event = scan_done_event,
                .payload = *results,
                .processor = completed.cpu().processor_id(),
                .memory = registration.memory,
            });
            completed.set_return(apple80211_abi::success);
        });
    });
}

void Apple80211Hle::reset(std::uint32_t process_id)
{
    process_handles_.clear();
    std::lock_guard broker_lock { event_broker_->mutex };
    event_broker_->registrations.erase(process_id);
    std::erase_if(
        event_broker_->pending_events, [process_id](const PendingEvent& event) {
            return event.process_id == process_id;
        });
}

void Apple80211Hle::inherit_state(const Apple80211Hle& parent,
    std::uint32_t parent_process_id, std::uint32_t child_process_id)
{
    process_handles_.clear();
    if (const auto handles = parent.process_handles_.find(parent_process_id);
        handles != parent.process_handles_.end()) {
        process_handles_.emplace(child_process_id, handles->second);
    }
    event_broker_ = parent.event_broker_;
    std::lock_guard broker_lock { event_broker_->mutex };
    event_broker_->registrations.erase(child_process_id);
    std::erase_if(event_broker_->pending_events,
        [child_process_id](const PendingEvent& event) {
            return event.process_id == child_process_id;
        });
}

void Apple80211Hle::set_wifi_state(std::shared_ptr<WifiState> state)
{
    state_ = state ? std::move(state) : std::make_shared<WifiState>();
}

void Apple80211Hle::set_event_injection_handler(EventInjectionHandler handler)
{
    event_injection_handler_ = std::move(handler);
}

void Apple80211Hle::publish_state_change(
    const WifiSnapshot& before, const WifiSnapshot& after)
{
    if (before.powered != after.powered) {
        queue_event(power_changed_event);
    }
    const auto association_changed =
        before.associated_access_point.has_value() !=
            after.associated_access_point.has_value() ||
        (before.associated_access_point && after.associated_access_point &&
            (before.associated_access_point->ssid !=
                    after.associated_access_point->ssid ||
                before.associated_access_point->bssid !=
                    after.associated_access_point->bssid));
    if (association_changed) {
        queue_event(ssid_changed_event);
        queue_event(bssid_changed_event);
    }
    if (before.powered != after.powered || association_changed) {
        queue_event(link_changed_event);
    }
    if (association_changed && after.associated_access_point) {
        queue_event(association_done_event);
    }
}

bool Apple80211Hle::deliver_pending_event(
    Cpu& cpu, std::uint32_t process_id, std::uint32_t svc_immediate)
{
    if (!process_handles_.contains(process_id))
        return false;
    PendingEvent event;
    {
        std::lock_guard broker_lock { event_broker_->mutex };
        const auto pending = std::find_if(event_broker_->pending_events.begin(),
            event_broker_->pending_events.end(),
            [this, process_id, processor = cpu.processor_id()](
                const PendingEvent& candidate) {
                if (candidate.process_id != process_id ||
                    candidate.processor != processor) {
                    return false;
                }
                const auto registrations =
                    event_broker_->registrations.find(candidate.process_id);
                return registrations != event_broker_->registrations.end() &&
                       registrations->second.contains(candidate.handle) &&
                       !registrations->second.at(candidate.handle)
                            .callback_in_flight;
            });
        if (pending == event_broker_->pending_events.end())
            return false;
        event = *pending;
        event_broker_->pending_events.erase(pending);
        const auto registrations =
            event_broker_->registrations.find(process_id);
        if (!event.callback || event.memory == nullptr ||
            registrations == event_broker_->registrations.end() ||
            !registrations->second.contains(event.handle)) {
            return false;
        }
        registrations->second.at(event.handle).callback_in_flight = true;
    }
    auto saved_registers = cpu.registers();
    const auto saved_cpsr = cpu.cpsr();
    const auto svc_size = svc_immediate == userland_hle_thumb_svc ? 2U : 4U;
    const auto svc_entry = saved_registers[15] - svc_size;
    const auto callback_stack =
        saved_registers[13] - callback_stack_scratch_space;
    const auto callback_return = registry_.prepare_one_shot_return(cpu,
        svc_entry | ((saved_cpsr & arm_thumb_state_bit) != 0 ? 1U : 0U),
        [this, process_id, handle = event.handle, saved_registers, saved_cpsr](
            UserlandHleCall& completed) {
            std::lock_guard broker_lock { event_broker_->mutex };
            const auto process = event_broker_->registrations.find(process_id);
            if (process != event_broker_->registrations.end() &&
                process->second.contains(handle)) {
                process->second.at(handle).callback_in_flight = false;
            }
            completed.cpu().registers() = saved_registers;
            completed.cpu().set_cpsr(saved_cpsr);
        });
    if (!callback_return) {
        std::lock_guard broker_lock { event_broker_->mutex };
        const auto process = event_broker_->registrations.find(process_id);
        if (process != event_broker_->registrations.end() &&
            process->second.contains(event.handle)) {
            process->second.at(event.handle).callback_in_flight = false;
        }
        return false;
    }
    auto& registers = cpu.registers();
    // Apple80211's event callback ABI is
    // (status, context, event, event_payload). Scan completion carries the
    // firmware-created CFArray as its payload.
    registers[0] = apple80211_abi::success;
    registers[1] = event.context;
    registers[2] = event.event;
    registers[3] = event.payload;
    registers[13] = callback_stack;
    registers[14] = *callback_return;
    registers[15] = event.callback & ~1U;
    cpu.set_cpsr(arm_user_mode |
                 ((event.callback & 1U) != 0 ? arm_thumb_state_bit : 0U));
    return true;
}

bool Apple80211Hle::valid_handle(
    const UserlandHleCall& call, std::uint32_t handle)
{
    const auto process = process_handles_.find(call.process_id());
    if (handle != 0 && process != process_handles_.end() &&
        process->second.contains(handle)) {
        return true;
    }
    if (handle == 0)
        return false;
    const auto descriptor =
        call.memory().read32(handle + apple80211_abi::socket_descriptor_offset);
    const auto name = call.memory().read_c_string(
        handle + apple80211_abi::interface_name_offset,
        apple80211_abi::interface_name_capacity);
    if (!descriptor || static_cast<std::int32_t>(*descriptor) < 0 ||
        name != interface_name) {
        return false;
    }
    process_handles_[call.process_id()].insert(handle);
    return true;
}

void Apple80211Hle::notify_change(const WifiSnapshot& before)
{
    const auto after = state_->snapshot();
    if (state_changed_)
        state_changed_(before, after);
    publish_state_change(before, after);
}

void Apple80211Hle::queue_event(std::uint32_t event, std::uint32_t payload)
{
    std::lock_guard broker_lock { event_broker_->mutex };
    for (const auto& [process_id, registrations] :
        event_broker_->registrations) {
        for (const auto& [handle, registration] : registrations) {
            queue_event_locked(
                process_id, handle, registration, event, payload);
        }
    }
}

void Apple80211Hle::queue_event_locked(std::uint32_t process_id,
    std::uint32_t handle, const EventRegistration& registration,
    std::uint32_t event, std::uint32_t payload)
{
    if (!registration.monitored_events.contains(event) ||
        registration.callback == 0 || registration.memory == nullptr) {
        return;
    }
    if (registration.inject_event) {
        registration.inject_event(process_id, event);
        return;
    }
    const auto already_pending =
        std::ranges::any_of(event_broker_->pending_events,
            [process_id, handle, event](const auto& pending) {
                return pending.process_id == process_id &&
                       pending.handle == handle && pending.event == event;
            });
    if (already_pending)
        return;
    event_broker_->pending_events.push_back({
        .process_id = process_id,
        .handle = handle,
        .callback = registration.callback,
        .context = registration.context,
        .event = event,
        .payload = payload,
        .processor = registration.processor,
        .memory = registration.memory,
    });
}

} // namespace shade
