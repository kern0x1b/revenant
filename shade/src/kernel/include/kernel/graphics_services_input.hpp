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

// Early SpringBoard separates alerts owned by its lock scene from ordinary
// modal overlays without changing the foreground application lifecycle.
// Observe its own classifier and lifecycle so input follows the visible layer.
void register_springboard_alert_observers(UserlandHleRegistry& registry,
    std::function<void(std::uint32_t, SpringBoardAlertObservation)> observer);

// Observe SpringBoard's own away-screen lifecycle. Host panel power alone
// cannot distinguish a dimmed desktop from an active lock screen.
void register_springboard_lock_observer(
    UserlandHleRegistry& registry, std::function<void(bool)> observer);

// UIKit owns the ordinary application suspension state independently of its
// event-only and under-lock modes. Observe the native under-lock transition
// before the ordinary `_setSuspended:` callback so automatic lock can reuse the
// same Lock barrier as a physical lock; do not infer lifecycle from GSEvent
// numbers. The under-lock observer establishes that barrier, while the
// ordinary observer retains the native suspension state.
void register_application_suspension_observer(UserlandHleRegistry& registry,
    std::function<void(std::uint32_t, bool)> observer,
    std::function<void(std::uint32_t)> under_lock_observer);

// Applies one observed alert-stack transition to the shared foreground-layer
// ordering. This keeps the firmware observer independent of kernel locking.
void record_springboard_alert_state(KernelSharedState& state,
    std::uint32_t object, SpringBoardAlertObservation observation);

void record_springboard_lock_state(KernelSharedState& state, bool active);

// Restores the firmware's own launch animation when an active application
// asks SpringBoard to hand the foreground to another ordinary application.
// Objective-C metadata and libobjc dispatch are used instead of fixed firmware
// addresses; the observer keeps lifecycle policy in the emulated kernel.
void register_springboard_application_handoff_animation(
    UserlandHleRegistry& registry,
    std::function<bool()> foreground_application_observer);

// Thread-safe lifecycle query shared by the SpringBoard compatibility hook
// and the spawn classifier.
[[nodiscard]] bool take_pending_application_handoff_animation(
    KernelSharedState& state);

// Extracts the leading GSEventRecord type from a message with id 123. This is
// shared by input injection and Mach tracing so application lifecycle events
// can be diagnosed without duplicating the private wire offsets.
[[nodiscard]] std::optional<std::uint32_t> event_type(
    std::span<const std::byte> message);

// These functions observe launchd's ordinary bootstrap MIG traffic. The caller
// must hold KernelSharedState::mach_mutex.
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

// Thread-safe host entry point. Input arriving before SpringBoard has resolved
// its event service is retained and flushed as soon as launchd replies.
[[nodiscard]] EnqueueResult enqueue_touch(KernelSharedState& state,
    const TouchInput& input, SceneCoordinator* scenes = nullptr,
    PresentationTracker* presentations = nullptr,
    bool* home_recovery_requested = nullptr,
    std::uint64_t* input_sequence = nullptr);

// A complete Home Down/Up pair wakes a sleeping lock screen before touch.
[[nodiscard]] EnqueueResult enqueue_system_button(KernelSharedState& state,
    const SystemButtonInput& input, std::uint64_t* input_sequence = nullptr,
    bool begins_display_lock_transaction = false);

// Marks the first subsequent SpringBoard touch gesture as lock-screen unlock
// input. Its service lookups are not foreground launch intents.
void record_lock_wake_request(KernelSharedState& state);

// Publishes the firmware event for the new physical ringer/silent switch
// position. The switch value remains in the device-state provider.
[[nodiscard]] EnqueueResult enqueue_ringer_switch_change(
    KernelSharedState& state, bool active);

// Re-evaluates the PID-bound foreground readiness rendezvous. Version adapters
// can contribute a committed client scene, while flattened display stacks can
// contribute live display timing; neither becomes an input owner without the
// firmware-delivered application event route and an authorized launch token.
// The operation is idempotent and safe to call as those signals arrive in any
// order; background/prewarmed services cannot steal SpringBoard touches.
void activate_resolved_application(KernelSharedState& state,
    std::uint32_t process_id, SceneCoordinator* scenes = nullptr);

// SpringBoard's successful, non-prewarmed posix_spawn is the earliest event
// that identifies a cold foreground target exactly. It creates a PID-bound
// launch token before scene or lifecycle callbacks can publish that App.
void record_application_spawn(KernelSharedState& state,
    std::uint32_t sender_process_id, std::uint32_t process_id,
    std::string_view executable_path, std::span<const std::string> arguments,
    SceneCoordinator* scenes = nullptr, bool force_foreground = false);

// Starts a new generation for a server-side LayerKit render context. The next
// visible root commit binds the context to the then-pending App event route.
void reset_application_scene_context(KernelSharedState& state,
    std::uint32_t render_process_id, std::uint32_t context);

// Binds a version-adapter render context to the App process identified through
// its emulated Mach event route and retains legacy exit-snapshot geometry.
// Returns that App PID so the adapter can publish its native geometry to the
// common SceneCoordinator without teaching Mach IPC about LayerKit.
std::optional<std::uint32_t> record_application_scene_transform(
    KernelSharedState& state, std::uint32_t render_process_id,
    std::uint32_t context,
    const KernelSharedState::ApplicationTouchTransform& transform);

// Releases every cached scene/routing record owned by one exiting process.
// The caller holds mach_mutex because receive-right termination and scene
// invalidation must be one transaction. Explicit scene ownership remains
// authoritative even after the process has relinquished its receive right.
void release_application_process_locked(
    KernelSharedState& state, std::uint32_t process_id);

// HOME/lock temporarily return touch ownership to SpringBoard. Lock keeps the
// visible App scene transform available across the unlock lifecycle, while a
// real Home transition releases it after the exit snapshot is prepared.
void suspend_active_application(KernelSharedState& state,
    KernelSharedState::ApplicationSuspensionReason reason,
    SceneCoordinator* scenes = nullptr,
    std::uint64_t system_input_sequence = 0);

// Observes a firmware-generated system button at its native service receive
// boundary. The caller holds mach_mutex and excludes host-tagged input.
void record_system_event_delivery_locked(KernelSharedState& state,
    std::uint32_t destination, std::uint32_t event_type,
    SceneCoordinator* scenes = nullptr);

// Observes SpringBoard composition after Home. The first desktop frame starts
// the native exit animation; final ownership remains with the ordered App
// background event (or the next deliberate gesture as a stale-state fallback).
void complete_home_transition_after_present(KernelSharedState& state,
    std::uint32_t presenter_process_id, SceneCoordinator* scenes = nullptr);

// Records the PID-bound application event port from ordinary GSEvent delivery,
// retries foreground readiness without assigning lifecycle meaning to private
// event numbers, and observes the ordered App-to-SpringBoard background
// completion. The caller holds KernelSharedState::mach_mutex; ordinary
// suspension meaning remains in UIKit.
void record_application_event_delivery_locked(KernelSharedState& state,
    std::uint32_t sender_pid, std::uint32_t destination,
    std::uint32_t event_type, SceneCoordinator* scenes = nullptr);

// Publishes one firmware-owned remote window-server transaction as a logical
// client scene. The caller has already selected the transaction ABI and
// holds KernelSharedState::mach_mutex; App identity, destination ownership,
// launch intent, and event-port readiness remain independently validated.
void record_application_remote_scene_commit_locked(KernelSharedState& state,
    std::uint32_t sender_pid, std::uint32_t destination,
    SceneCoordinator* scenes = nullptr);

// Applies UIKit's completed ordinary `_setSuspended:` transition. This is a
// thread-safe observer entry point and deliberately ignores its separate
// event-only and under-lock suspension modes.
void record_application_suspension_state(KernelSharedState& state,
    std::uint32_t process_id, bool suspended,
    SceneCoordinator* scenes = nullptr);

} // namespace shade::graphics_services_input
