// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Adapt guest Apple80211 queries and commands to virtual wireless
// state.

#pragma once

#include <cstddef>
#include <cstdint>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <set>
#include <vector>

#include "network/wifi_state.hpp"

namespace shade {

class UserlandHleCall;
class UserlandHleRegistry;
class Cpu;
class AddressSpace;

namespace apple80211_abi {

    inline constexpr std::uint32_t socket_descriptor_offset = 0;
    inline constexpr std::uint32_t interface_name_offset = 4;
    inline constexpr std::uint32_t interface_name_capacity = 16;
    inline constexpr std::uint32_t event_callback_offset = 28;
    inline constexpr std::uint32_t event_context_offset = 32;
    inline constexpr std::uint32_t success = 0;
    inline constexpr std::uint32_t invalid_argument = 0xffff'ffffU;

} // namespace apple80211_abi

class Apple80211Hle {
public:
    using StateChangedHandler =
        std::function<void(const WifiSnapshot&, const WifiSnapshot&)>;
    using EventInjectionHandler =
        std::function<void(std::uint32_t, std::uint32_t)>;

    Apple80211Hle(UserlandHleRegistry& registry,
        std::shared_ptr<WifiState> state,
        StateChangedHandler state_changed = { });

    void reset(std::uint32_t process_id);
    void inherit_state(const Apple80211Hle& parent,
        std::uint32_t parent_process_id, std::uint32_t child_process_id);
    void set_wifi_state(std::shared_ptr<WifiState> state);
    void set_event_injection_handler(EventInjectionHandler handler);
    void publish_state_change(
        const WifiSnapshot& before, const WifiSnapshot& after);
    [[nodiscard]] bool deliver_pending_event(
        Cpu& cpu, std::uint32_t process_id, std::uint32_t svc_immediate);

private:
    struct EventRegistration {
        std::uint32_t callback { };
        std::uint32_t context { };
        std::uint32_t scan_result_address { };
        AddressSpace* memory { };
        std::size_t processor { };
        bool scan_pending { };
        bool callback_in_flight { };
        EventInjectionHandler inject_event;
        std::set<std::uint32_t> monitored_events;
    };

    struct PendingEvent {
        std::uint32_t process_id { };
        std::uint32_t handle { };
        std::uint32_t callback { };
        std::uint32_t context { };
        std::uint32_t event { };
        std::uint32_t payload { };
        std::size_t processor { };
        AddressSpace* memory { };
    };

    struct EventBroker {
        std::mutex mutex;
        std::map<std::uint32_t, std::map<std::uint32_t, EventRegistration>>
            registrations;
        std::vector<PendingEvent> pending_events;
    };

    [[nodiscard]] bool valid_handle(
        const UserlandHleCall& call, std::uint32_t handle);
    void notify_change(const WifiSnapshot& before);
    void queue_event(std::uint32_t event, std::uint32_t payload = 0);
    void queue_event_locked(std::uint32_t process_id, std::uint32_t handle,
        const EventRegistration& registration, std::uint32_t event,
        std::uint32_t payload = 0);

    std::shared_ptr<WifiState> state_;
    StateChangedHandler state_changed_;
    EventInjectionHandler event_injection_handler_;
    std::map<std::uint32_t, std::set<std::uint32_t>> process_handles_;
    std::shared_ptr<EventBroker> event_broker_ {
        std::make_shared<EventBroker>()
    };
    UserlandHleRegistry& registry_;
};

} // namespace shade
