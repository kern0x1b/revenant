// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Route touch and hardware-button input through guest
// GraphicsServices callbacks.

#pragma once

#include <cstddef>
#include <cstdint>
#include <functional>
#include <optional>
#include <span>
#include <string>
#include <string_view>

#include "kernel/kernel_shared_state.hpp"
#include "foundation/system_button_input.hpp"
#include "foundation/touch_input.hpp"

namespace shade {
class PresentationTracker;
class SceneCoordinator;
class UserlandHleRegistry;
}

namespace shade::graphics_services_input {

inline constexpr std::string_view system_event_service {
    "PurpleSystemEventPort"
};
inline constexpr std::string_view render_server_service {
    "com.apple.CARenderServer"
};

enum class EnqueueResult {
    Queued,
    Deferred,
};

struct ServiceResolution {
    std::uint32_t object { };
    std::size_t flushed_events { };
    bool application_event_port { };
    std::string service_name;
};

enum class SpringBoardAlertObservation {
    ActivationBegan,
    ClassifiedLockScreen,
    ClassifiedApplicationOverlay,
    Deactivated,
};

void register_springboard_alert_observers(UserlandHleRegistry& registry,
    std::function<void(std::uint32_t, SpringBoardAlertObservation)> observer);

void register_springboard_lock_observer(
    UserlandHleRegistry& registry, std::function<void(bool)> observer);

void register_application_suspension_observer(UserlandHleRegistry& registry,
    std::function<void(std::uint32_t, bool)> observer,
    std::function<void(std::uint32_t)> under_lock_observer);

void record_springboard_alert_state(KernelSharedState& state,
    std::uint32_t object, SpringBoardAlertObservation observation);

void record_springboard_lock_state(KernelSharedState& state, bool active);

void register_springboard_application_handoff_animation(
    UserlandHleRegistry& registry,
    std::function<bool()> foreground_application_observer);

[[nodiscard]] bool take_pending_application_handoff_animation(
    KernelSharedState& state);

[[nodiscard]] std::optional<std::uint32_t> event_type(
    std::span<const std::byte> message);

void record_bootstrap_lookup_locked(KernelSharedState& state,
    std::uint32_t reply_object, std::string_view service_name,
    std::uint32_t requester_process_id = 0);
void record_bootstrap_check_in_locked(KernelSharedState& state,
    std::uint32_t reply_object, std::string_view service_name,
    std::uint32_t requester_process_id = 0);
void record_bootstrap_registration_locked(
    KernelSharedState& state, std::string_view service_name);
[[nodiscard]] ServiceResolution record_bootstrap_reply_locked(
    KernelSharedState& state, std::uint32_t reply_object,
    std::span<const KernelSharedState::MachMessage::PortTransfer> transfers,
    std::uint32_t receiver_process_id = 0);

[[nodiscard]] EnqueueResult enqueue_touch(KernelSharedState& state,
    const TouchInput& input, SceneCoordinator* scenes = nullptr,
    PresentationTracker* presentations = nullptr,
    bool* home_recovery_requested = nullptr,
    std::uint64_t* input_sequence = nullptr);

[[nodiscard]] EnqueueResult enqueue_system_button(KernelSharedState& state,
    const SystemButtonInput& input, std::uint64_t* input_sequence = nullptr,
    bool begins_display_lock_transaction = false);

void record_lock_wake_request(KernelSharedState& state);

[[nodiscard]] EnqueueResult enqueue_ringer_switch_change(
    KernelSharedState& state, bool active);

void activate_resolved_application(KernelSharedState& state,
    std::uint32_t process_id, SceneCoordinator* scenes = nullptr);

void record_application_spawn(KernelSharedState& state,
    std::uint32_t sender_process_id, std::uint32_t process_id,
    std::string_view executable_path, std::span<const std::string> arguments,
    SceneCoordinator* scenes = nullptr, bool force_foreground = false);

void reset_application_scene_context(KernelSharedState& state,
    std::uint32_t render_process_id, std::uint32_t context);

std::optional<std::uint32_t> record_application_scene_transform(
    KernelSharedState& state, std::uint32_t render_process_id,
    std::uint32_t context,
    const KernelSharedState::ApplicationTouchTransform& transform);

void release_application_process_locked(
    KernelSharedState& state, std::uint32_t process_id);

void suspend_active_application(KernelSharedState& state,
    KernelSharedState::ApplicationSuspensionReason reason,
    SceneCoordinator* scenes = nullptr,
    std::uint64_t system_input_sequence = 0);

void record_system_event_delivery_locked(KernelSharedState& state,
    std::uint32_t destination, std::uint32_t event_type,
    SceneCoordinator* scenes = nullptr);

void complete_home_transition_after_present(KernelSharedState& state,
    std::uint32_t presenter_process_id, SceneCoordinator* scenes = nullptr);

void record_application_event_delivery_locked(KernelSharedState& state,
    std::uint32_t sender_pid, std::uint32_t destination,
    std::uint32_t event_type, SceneCoordinator* scenes = nullptr);

void record_application_remote_scene_commit_locked(KernelSharedState& state,
    std::uint32_t sender_pid, std::uint32_t destination,
    SceneCoordinator* scenes = nullptr);

void record_application_suspension_state(KernelSharedState& state,
    std::uint32_t process_id, bool suspended,
    SceneCoordinator* scenes = nullptr);

}
