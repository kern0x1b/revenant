// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Inject guest GraphicsServices input and coordinate lock-screen
// lifecycle callbacks.

#include "kernel/graphics_services_input.hpp"

#include <algorithm>
#include <array>
#include <bit>
#include <cmath>
#include <mutex>
#include <utility>
#include <vector>

#include "foundation/application_display.hpp"
#include "foundation/application_path.hpp"
#include "foundation/cpu.hpp"
#include "kernel/graphics_services_input_abi.hpp"
#include "kernel/iokit_abi.hpp"
#include "kernel/kernel_iokit_display.hpp"
#include "mach/mig_wire_abi.hpp"
#include "graphics/presentation_tracker.hpp"
#include "foundation/scene_coordinator.hpp"
#include "foundation/userland_hle.hpp"

namespace shade::graphics_services_input {
namespace {

    constexpr std::uint32_t copy_send_bits = 19;
    constexpr std::uint32_t graphics_event_message_id = 123;
    constexpr std::uint32_t hand_event_type = 3001;

    constexpr std::size_t record_location_offset = 8;
    constexpr std::size_t record_window_location_offset = 16;
    constexpr std::uint8_t path_index = 1;
    constexpr std::uint8_t path_proximity_touching = 3;

    constexpr std::string_view springboard_image {
        "/System/Library/CoreServices/SpringBoard.app/SpringBoard"
    };
    constexpr std::string_view ui_kit_image {
        "/System/Library/Frameworks/UIKit.framework/UIKit"
    };
    constexpr std::string_view objc_image { "/usr/lib/libobjc.A.dylib" };
    constexpr std::string_view objc_get_class { "_objc_getClass" };
    constexpr std::string_view objc_message_send { "_objc_msgSend" };
    constexpr std::string_view selector_register_name { "_sel_registerName" };
    constexpr std::uint32_t application_display_setting = 2U;

    void write_word(
        std::span<std::byte> bytes, std::size_t offset, std::uint32_t value)
    {
        for (std::size_t byte = 0; byte < sizeof(value); ++byte) {
            bytes[offset + byte] = static_cast<std::byte>(value >> (byte * 8U));
        }
    }

    void write_float(
        std::span<std::byte> bytes, std::size_t offset, float value)
    {
        write_word(bytes, offset, std::bit_cast<std::uint32_t>(value));
    }

    std::uint32_t read_word(
        std::span<const std::byte> bytes, std::size_t offset)
    {
        std::uint32_t value = 0;
        for (std::size_t byte = 0; byte < sizeof(value); ++byte) {
            value |= std::to_integer<std::uint32_t>(bytes[offset + byte])
                     << (byte * 8U);
        }
        return value;
    }

    std::uint32_t mouse_event_type(TouchPhase phase)
    {
        switch (phase) {
        case TouchPhase::Down:
            return 1;
        case TouchPhase::Move:
            return 6;
        case TouchPhase::Up:
        case TouchPhase::Cancel:
            return 2;
        }
        return 2;
    }

    bool active(TouchPhase phase)
    {
        return phase == TouchPhase::Down || phase == TouchPhase::Move;
    }

    bool valid_unlock_trajectory(
        float start_x, float start_y, float end_x, float end_y)
    {
        const auto horizontal_distance = end_x - start_x;
        const auto vertical_distance = std::fabs(end_y - start_y);
        return horizontal_distance >= 96.0F &&
               vertical_distance <=
                   std::max(64.0F, horizontal_distance * 0.75F);
    }

    KernelSharedState::MachMessage::GraphicsInputKind system_button_input_kind(
        SystemButton button)
    {
        switch (button) {
        case SystemButton::Home:
            return KernelSharedState::MachMessage::GraphicsInputKind::Home;
        case SystemButton::Lock:
            return KernelSharedState::MachMessage::GraphicsInputKind::Lock;
        case SystemButton::VolumeUp:
        case SystemButton::VolumeDown:
            return KernelSharedState::MachMessage::GraphicsInputKind::
                OtherSystem;
        }
        return KernelSharedState::MachMessage::GraphicsInputKind::OtherSystem;
    }

    HidEventQueue::KeyboardInput hid_button(const SystemButtonInput& input)
    {
        // USB HID Consumer page: Menu, Power, Volume Increment/Decrement.
        std::uint32_t usage = 0;
        switch (input.button) {
        case SystemButton::Home: usage = 0x40U; break;
        case SystemButton::Lock: usage = 0x30U; break;
        case SystemButton::VolumeUp: usage = 0xe9U; break;
        case SystemButton::VolumeDown: usage = 0xeaU; break;
        }
        return { 0x0cU, usage, input.phase == SystemButtonPhase::Down };
    }

    std::uint64_t allocate_graphics_input_sequence_locked(
        KernelSharedState& state)
    {
        auto sequence = state.next_graphics_input_sequence++;
        if (sequence == 0U) {
            sequence = 1U;
            state.next_graphics_input_sequence = 2U;
        }
        return sequence;
    }

    void clear_springboard_enqueued_gesture_locked(KernelSharedState& state)
    {
        state.springboard_enqueued_active_touch_begin_sequence = 0U;
        state.springboard_enqueued_last_touch_begin_sequence = 0U;
        state.springboard_enqueued_last_touch_end_sequence = 0U;
        state.springboard_enqueued_last_touch_end_x = 0.0F;
        state.springboard_enqueued_last_touch_end_y = 0.0F;
        state.springboard_pending_launch_touch_sequence = 0U;
    }

    KernelSharedState::MachMessage make_touch_message(std::uint32_t destination,
        std::uint64_t timestamp, const TouchInput& input,
        KernelSharedState::GraphicsInputAbi abi, std::uint64_t input_sequence)
    {
        const auto& profile = GraphicsServicesInputAbi::for_abi(abi);
        const auto hand_offset =
            darwin::mig_wire::message_header_size + profile.event_record_size;
        const auto path_offset = hand_offset + profile.hand_info_size;
        const auto hand_message_size = path_offset + profile.path_info_size;
        const auto hand_path_count_offset =
            hand_offset + profile.hand_path_count_offset;
        const auto path_pressure_offset = path_offset + 4;
        const auto path_location_offset =
            path_offset + profile.path_location_offset;

        KernelSharedState::MachMessage message;
        message.bytes.resize(hand_message_size, std::byte { 0 });
        message.destination = destination;
        message.sender_pid = 0;
        message.graphics_input_sequence = input_sequence;
        message.graphics_input_kind =
            KernelSharedState::MachMessage::GraphicsInputKind::Touch;
        message.graphics_touch_phase = input.phase;

        write_word(message.bytes, darwin::mig_wire::header_bits_offset,
            copy_send_bits);
        write_word(message.bytes, darwin::mig_wire::header_size_offset,
            static_cast<std::uint32_t>(hand_message_size));
        write_word(message.bytes, darwin::mig_wire::header_remote_port_offset,
            destination);
        write_word(message.bytes, darwin::mig_wire::header_identifier_offset,
            graphics_event_message_id);

        const auto record = darwin::mig_wire::message_header_size;
        write_word(message.bytes, record,
            abi != KernelSharedState::GraphicsInputAbi::LegacyMouse
                ? hand_event_type
                : mouse_event_type(input.phase));
        write_float(message.bytes, record + record_location_offset, input.x);
        write_float(
            message.bytes, record + record_location_offset + 4, input.y);
        write_float(
            message.bytes, record + record_window_location_offset, input.x);
        write_float(
            message.bytes, record + record_window_location_offset + 4, input.y);
        write_word(message.bytes, record + profile.record_timestamp_offset,
            static_cast<std::uint32_t>(timestamp));
        write_word(message.bytes, record + profile.record_timestamp_offset + 4,
            static_cast<std::uint32_t>(timestamp >> 32U));
        write_word(message.bytes, record + profile.record_info_size_offset,
            static_cast<std::uint32_t>(
                profile.hand_info_size + profile.path_info_size));

        write_word(message.bytes, hand_offset, profile.hand_type(input.phase));
        message.bytes[hand_path_count_offset] = std::byte { 1 };
        message.bytes[path_offset] = static_cast<std::byte>(path_index);
        // The second path byte is ABI-defined: the early profile uses a stable
        // identity, while later UIKit keyboard layouts consume the touch stage.
        message.bytes[path_offset + 1] =
            static_cast<std::byte>(profile.path_type(input.phase));
        // Proximity is a contact-lifetime bit field. UIKit matches a terminal
        // path by index, then retires that contact only when proximity is fully
        // clear.
        message.bytes[path_offset + 2] = static_cast<std::byte>(
            active(input.phase) ? path_proximity_touching : 0U);
        write_float(message.bytes, path_pressure_offset,
            active(input.phase) ? 1.0F : 0.0F);
        write_float(message.bytes, path_location_offset, input.x);
        write_float(message.bytes, path_location_offset + 4, input.y);
        return message;
    }

    KernelSharedState::MachMessage make_simple_event_message(
        std::uint32_t destination, std::uint64_t timestamp,
        std::uint32_t event_type, std::uint64_t input_sequence,
        KernelSharedState::MachMessage::GraphicsInputKind input_kind,
        KernelSharedState::GraphicsInputAbi abi,
        std::span<const std::byte> event_info = { })
    {
        const auto& profile = GraphicsServicesInputAbi::for_abi(abi);
        const auto simple_event_message_size =
            darwin::mig_wire::message_header_size + profile.event_record_size +
            event_info.size();
        KernelSharedState::MachMessage message;
        message.bytes.resize(simple_event_message_size, std::byte { 0 });
        message.destination = destination;
        message.sender_pid = 0;
        message.graphics_input_sequence = input_sequence;
        message.graphics_input_kind = input_kind;

        write_word(message.bytes, darwin::mig_wire::header_bits_offset,
            copy_send_bits);
        write_word(message.bytes, darwin::mig_wire::header_size_offset,
            static_cast<std::uint32_t>(simple_event_message_size));
        write_word(message.bytes, darwin::mig_wire::header_remote_port_offset,
            destination);
        write_word(message.bytes, darwin::mig_wire::header_identifier_offset,
            graphics_event_message_id);
        const auto record = darwin::mig_wire::message_header_size;
        write_word(message.bytes, record, event_type);
        write_word(message.bytes, record + profile.record_timestamp_offset,
            static_cast<std::uint32_t>(timestamp));
        write_word(message.bytes, record + profile.record_timestamp_offset + 4,
            static_cast<std::uint32_t>(timestamp >> 32U));
        write_word(message.bytes, record + profile.record_info_size_offset,
            static_cast<std::uint32_t>(event_info.size()));
        for (std::size_t index = 0; index < event_info.size(); ++index) {
            message.bytes[record + profile.event_record_size + index] =
                event_info[index];
        }
        return message;
    }

    KernelSharedState::GraphicsInputAbi graphics_input_abi_for_object_locked(
        const KernelSharedState& state, std::uint32_t destination)
    {
        if (const auto port = state.mach_port_objects.lookup(destination)) {
            if (const auto process = state.processes.find(port->receive_owner);
                process != state.processes.end()) {
                return process->second.graphics_input_abi;
            }
        }
        return KernelSharedState::GraphicsInputAbi::Darwin9_0;
    }

    KernelSharedState::GraphicsInputAbi system_graphics_input_abi_locked(
        const KernelSharedState& state, std::uint32_t destination = 0U)
    {
        if (destination != 0U)
            return graphics_input_abi_for_object_locked(state, destination);
        const auto process = std::find_if(state.processes.begin(),
            state.processes.end(), [](const auto& entry) {
                return !entry.second.exited &&
                       entry.second.executable_path.ends_with(
                           "/SpringBoard.app/SpringBoard");
            });
        return process != state.processes.end()
                   ? process->second.graphics_input_abi
                   : KernelSharedState::GraphicsInputAbi::Darwin9_0;
    }

    void queue_locked(KernelSharedState& state, std::uint32_t destination,
        const TouchInput& input, std::uint64_t input_sequence)
    {
        const auto abi =
            graphics_input_abi_for_object_locked(state, destination);
        state.enqueue_mach_message_locked(
            destination, make_touch_message(destination, state.clock.now(),
                             input, abi, input_sequence));
    }

    void queue_simple_event_locked(KernelSharedState& state,
        std::uint32_t destination, std::uint32_t event_type,
        std::uint64_t input_sequence,
        KernelSharedState::MachMessage::GraphicsInputKind input_kind)
    {
        const auto abi =
            graphics_input_abi_for_object_locked(state, destination);
        const auto& profile = GraphicsServicesInputAbi::for_abi(abi);
        std::array<std::byte, sizeof(std::uint64_t)> idle_duration { };
        const auto event_info_size =
            event_type == profile.idle_duration_reset_event_type
                ? std::min(profile.idle_duration_reset_info_size,
                      idle_duration.size())
                : 0U;
        const auto event_info = std::span<const std::byte> {
            idle_duration.data(), event_info_size };
        state.enqueue_mach_message_locked(destination,
            make_simple_event_message(destination, state.clock.now(),
                event_type, input_sequence, input_kind, abi, event_info));
    }

    void queue_idle_duration_reset_locked(
        KernelSharedState& state, std::uint64_t input_sequence)
    {
        const auto service = state.bootstrap_service_objects.find(
            std::string { system_event_service });
        const auto destination =
            service == state.bootstrap_service_objects.end() ? 0U
                                                             : service->second;
        const auto abi = system_graphics_input_abi_locked(state, destination);
        const auto event_type = GraphicsServicesInputAbi::for_abi(abi)
                                    .idle_duration_reset_event_type;
        constexpr auto input_kind =
            KernelSharedState::MachMessage::GraphicsInputKind::OtherSystem;
        if (service == state.bootstrap_service_objects.end()) {
            state.pending_graphics_inputs.push_back(
                KernelSharedState::PendingGraphicsInput {
                    KernelSharedState::PendingGraphicsInput::Kind::SystemEvent,
                    { }, event_type, input_sequence, input_kind });
            return;
        }
        queue_simple_event_locked(
            state, service->second, event_type, input_sequence, input_kind);
    }

    bool object_owned_by_process_locked(const KernelSharedState& state,
        std::uint32_t object, std::uint32_t process_id)
    {
        const auto port = state.mach_port_objects.lookup(object);
        return port && port->receive_owner == process_id;
    }

    bool process_is_springboard_locked(
        const KernelSharedState& state, std::uint32_t process_id)
    {
        const auto process = state.processes.find(process_id);
        return process != state.processes.end() && !process->second.exited &&
               process->second.executable_path.ends_with(
                   "/SpringBoard.app/SpringBoard");
    }

    bool has_active_application_route_locked(const KernelSharedState& state)
    {
        if (!state.active_application_scene ||
            state.active_application_event_object == 0U ||
            state.application_touch_suspended ||
            state.application_suspension_reason !=
                KernelSharedState::ApplicationSuspensionReason::None) {
            return false;
        }
        const auto& scene = *state.active_application_scene;
        const auto port = state.mach_port_objects.lookup(scene.event_object);
        if (!port || port->receive_owner != scene.process_id)
            return false;
        const auto process = state.processes.find(scene.process_id);
        return process != state.processes.end() && !process->second.exited &&
               is_application_executable_path(process->second.executable_path);
    }

    std::uint64_t allocate_foreground_layer_sequence_locked(
        KernelSharedState& state)
    {
        return state.next_foreground_layer_sequence++;
    }

    void mark_application_layer_active_locked(KernelSharedState& state)
    {
        state.active_application_layer_sequence =
            allocate_foreground_layer_sequence_locked(state);
    }

    bool springboard_alert_owns_input_locked(const KernelSharedState& state)
    {
        if (state.active_springboard_alert_items.empty())
            return false;
        if (!has_active_application_route_locked(state))
            return true;
        return std::any_of(state.active_springboard_alert_items.begin(),
            state.active_springboard_alert_items.end(),
            [&state](const auto& item) {
                return item.second.presentation !=
                           KernelSharedState::SpringBoardAlertPresentation::
                               LockScreen &&
                       item.second.sequence >
                           state.active_application_layer_sequence;
            });
    }

    std::optional<std::uint32_t> application_event_object_for_process_locked(
        KernelSharedState& state, std::uint32_t process_id)
    {
        const auto process = state.processes.find(process_id);
        if (process == state.processes.end() || process->second.exited ||
            !is_application_executable_path(process->second.executable_path)) {
            return std::nullopt;
        }

        const auto owned = [&state, process_id](std::uint32_t object) {
            return object != 0U &&
                   object_owned_by_process_locked(state, object, process_id);
        };
        if (const auto known =
                state.application_event_objects_by_process.find(process_id);
            known != state.application_event_objects_by_process.end() &&
            owned(known->second)) {
            return known->second;
        }

        const std::array candidates { state.active_application_event_object,
            state.active_application_scene &&
                    state.active_application_scene->process_id == process_id
                ? state.active_application_scene->event_object
                : 0U,
            state.pending_application_event_object };
        const auto candidate =
            std::find_if(candidates.begin(), candidates.end(), owned);
        if (candidate == candidates.end())
            return std::nullopt;
        state.application_event_objects_by_process[process_id] = *candidate;
        return *candidate;
    }

    std::optional<KernelSharedState::GraphicsTouchTransform>
    application_touch_transform_locked(const KernelSharedState& state,
        std::uint32_t process_id, SceneCoordinator* scenes)
    {
        if (scenes) {
            const auto scene = scenes->client_scene(process_id);
            if (scene && scene->input_transform) {
                const auto& transform = *scene->input_transform;
                return KernelSharedState::GraphicsTouchTransform { transform.xx,
                    transform.xy, transform.yx, transform.yy, transform.tx,
                    transform.ty };
            }
        }

        std::optional<KernelSharedState::ApplicationTouchTransform> transform;
        if (state.active_application_scene &&
            state.active_application_scene->process_id == process_id &&
            state.active_application_scene->touch_transform) {
            transform = state.active_application_scene->touch_transform;
        } else if (const auto cached =
                       state.application_scene_transforms.find(process_id);
            cached != state.application_scene_transforms.end()) {
            transform = cached->second;
        }
        if (!transform) {
            const auto process = state.processes.find(process_id);
            if (process != state.processes.end() &&
                process->second.application_display.kind !=
                    ApplicationDisplayMode::Native) {
                const auto& profile = process->second.application_display;
                const auto viewport = application_display_viewport(
                    profile, state.display_geometry);
                if (viewport.width == 0U || viewport.height == 0U ||
                    !profile.logical_geometry.valid())
                    return std::nullopt;
                const auto scale_x =
                    static_cast<float>(profile.logical_geometry.width) /
                    static_cast<float>(viewport.width);
                const auto scale_y =
                    static_cast<float>(profile.logical_geometry.height) /
                    static_cast<float>(viewport.height);
                return KernelSharedState::GraphicsTouchTransform {
                    scale_x, 0.0F, 0.0F, scale_y,
                    -static_cast<float>(viewport.x) * scale_x,
                    -static_cast<float>(viewport.y) * scale_y };
            }
        }
        if (!transform)
            return std::nullopt;
        return KernelSharedState::GraphicsTouchTransform { 1.0F, 0.0F, 0.0F,
            1.0F, -transform->presentation_offset_x,
            -transform->presentation_offset_y };
    }

    KernelSharedState::GraphicsTouchRoute springboard_touch_route(
        std::uint32_t process_id = 0U)
    {
        return KernelSharedState::GraphicsTouchRoute { 0U, process_id,
            std::nullopt, false };
    }

    std::optional<KernelSharedState::GraphicsTouchRoute>
    application_touch_route_locked(KernelSharedState& state,
        std::uint32_t process_id, SceneCoordinator* scenes)
    {
        const auto event_object =
            application_event_object_for_process_locked(state, process_id);
        if (!event_object)
            return std::nullopt;
        return KernelSharedState::GraphicsTouchRoute { *event_object,
            process_id,
            application_touch_transform_locked(state, process_id, scenes),
            true };
    }

    bool application_fullscreen_publication_locked(
        const KernelSharedState& state, std::uint32_t process_id,
        std::uint64_t publication_sequence)
    {
        const auto publications =
            state.application_fullscreen_surface_publications.find(process_id);
        return publications !=
                   state.application_fullscreen_surface_publications.end() &&
               publications->second.contains(publication_sequence);
    }

    std::optional<KernelSharedState::GraphicsTouchRoute>
    semantic_touch_route_locked(
        KernelSharedState& state, SceneCoordinator* scenes);

    std::optional<KernelSharedState::GraphicsTouchRoute>
    presentation_touch_route_locked(KernelSharedState& state,
        const PresentationHitTest& presentation, SceneCoordinator* scenes)
    {
        // A version adapter can establish a logical App scene even when an
        // early compositor flattens all of its pixels into SpringBoard-owned
        // surfaces. That semantic identity belongs to this exact completed
        // frame, so consult it before physical provenance unless a newer
        // firmware-classified system alert is above the App.
        if (presentation.logical_client_scene &&
            presentation.logical_client_scene->state ==
                ClientSceneState::Active &&
            !springboard_alert_owns_input_locked(state)) {
            if (const auto route = application_touch_route_locked(state,
                    presentation.logical_client_scene->client_process_id,
                    scenes)) {
                return route;
            }
        }

        // Early firmware flattens an application's full-screen scene into a
        // SpringBoard-owned presentation. In that mode the physical layer list
        // can name SpringBoard even though the semantic application route is
        // still the active foreground owner. Prefer that exact route before
        // treating the compositor's owner as the touch target; system alerts
        // and lock state have already been excluded by the checks above.
        if (!springboard_alert_owns_input_locked(state)) {
            if (const auto route = semantic_touch_route_locked(state, scenes))
                return route;
        }

        for (const auto& layer : presentation.layers_front_to_back) {
            const auto process_id =
                layer.surface_provenance.producer_process_id;
            if (process_is_springboard_locked(state, process_id))
                return springboard_touch_route(process_id);

            const auto process = state.processes.find(process_id);
            if (process == state.processes.end() || process->second.exited)
                continue;
            if (!is_application_executable_path(
                    process->second.executable_path))
                return springboard_touch_route();

            // SpringBoard's desktop can retain App-produced icon/snapshot
            // assets. Only a publication already classified as a display-sized
            // App scene is an input owner; otherwise continue to the layer
            // beneath it.
            if (!application_fullscreen_publication_locked(state, process_id,
                    layer.surface_provenance.publication_sequence)) {
                continue;
            }
            if (const auto route =
                    application_touch_route_locked(state, process_id, scenes)) {
                return route;
            }
            return springboard_touch_route();
        }

        if (process_is_springboard_locked(
                state, presentation.submitting_process_id)) {
            return springboard_touch_route(presentation.submitting_process_id);
        }
        if (const auto route = application_touch_route_locked(
                state, presentation.submitting_process_id, scenes)) {
            return route;
        }
        return std::nullopt;
    }

    std::optional<KernelSharedState::GraphicsTouchRoute>
    semantic_touch_route_locked(
        KernelSharedState& state, SceneCoordinator* scenes)
    {
        if (springboard_alert_owns_input_locked(state) ||
            state.active_application_event_object == 0U ||
            state.application_touch_suspended) {
            return std::nullopt;
        }
        const auto port = state.mach_port_objects.lookup(
            state.active_application_event_object);
        if (!port)
            return std::nullopt;
        const auto process = state.processes.find(port->receive_owner);
        if (process == state.processes.end() || process->second.exited ||
            !is_application_executable_path(process->second.executable_path)) {
            state.active_application_event_object = 0U;
            state.application_touch_suspended = false;
            return std::nullopt;
        }
        if (scenes) {
            const auto scene = scenes->client_scene(port->receive_owner);
            // Some early firmware flattens the App into a SpringBoard-owned
            // presentation without publishing a ClientScene for the App. The
            // active event port and foreground route above are still
            // authoritative in that case. An explicitly published non-active
            // scene remains a hard rejection so a stale route cannot cross a
            // lifecycle boundary.
            if (scene && scene->state != ClientSceneState::Active)
                return std::nullopt;
        }
        state.application_event_objects_by_process[port->receive_owner] =
            state.active_application_event_object;
        return KernelSharedState::GraphicsTouchRoute {
            state.active_application_event_object, port->receive_owner,
            application_touch_transform_locked(
                state, port->receive_owner, scenes),
            true
        };
    }

    TouchInput transform_touch(const TouchInput& input,
        const std::optional<KernelSharedState::GraphicsTouchTransform>&
            transform)
    {
        if (!transform)
            return input;
        const auto x =
            transform->xx * input.x + transform->xy * input.y + transform->tx;
        const auto y =
            transform->yx * input.x + transform->yy * input.y + transform->ty;
        if (!std::isfinite(x) || !std::isfinite(y))
            return input;
        return TouchInput { input.phase, x, y };
    }

    void animate_application_handoff(
        UserlandHleCall& call, std::uint32_t application)
    {
        const auto controller_class_name = call.intern_string("SBUIController");
        const auto shared_instance_name = call.intern_string("sharedInstance");
        const auto animate_launch_name =
            call.intern_string("animateLaunchOfApplication:");
        if (application == 0U || controller_class_name == 0U ||
            shared_instance_name == 0U || animate_launch_name == 0U) {
            return;
        }

        call.cpu().registers()[0] = controller_class_name;
        static_cast<void>(call.call_guest_function(objc_get_class,
            [application, shared_instance_name, animate_launch_name](
                UserlandHleCall& class_call) {
                const auto controller_class = class_call.cpu().registers()[0];
                if (controller_class == 0U)
                    return;
                class_call.cpu().registers()[0] = shared_instance_name;
                static_cast<void>(class_call.call_guest_function(
                    selector_register_name,
                    [application, controller_class, animate_launch_name](
                        UserlandHleCall& shared_selector_call) {
                        const auto shared_instance_selector =
                            shared_selector_call.cpu().registers()[0];
                        if (shared_instance_selector == 0U)
                            return;
                        auto& registers =
                            shared_selector_call.cpu().registers();
                        registers[0] = controller_class;
                        registers[1] = shared_instance_selector;
                        static_cast<
                            void>(shared_selector_call.call_guest_function(
                            objc_message_send,
                            [application, animate_launch_name](
                                UserlandHleCall& controller_call) {
                                const auto controller =
                                    controller_call.cpu().registers()[0];
                                if (controller == 0U)
                                    return;
                                controller_call.cpu().registers()[0] =
                                    animate_launch_name;
                                static_cast<void>(
                                    controller_call.call_guest_function(
                                        selector_register_name,
                                        [application, controller](
                                            UserlandHleCall&
                                                animate_selector_call) {
                                            const auto animate_selector =
                                                animate_selector_call.cpu()
                                                    .registers()[0];
                                            if (animate_selector == 0U)
                                                return;
                                            auto& message_registers =
                                                animate_selector_call.cpu()
                                                    .registers();
                                            message_registers[0] = controller;
                                            message_registers[1] =
                                                animate_selector;
                                            message_registers[2] = application;
                                            static_cast<void>(
                                                animate_selector_call
                                                    .call_guest_function(
                                                        objc_message_send,
                                                        [](UserlandHleCall&) {
                                                        }));
                                        }));
                            }));
                    }));
            }));
    }

    std::uint64_t allocate_application_launch_token_locked(
        KernelSharedState& state)
    {
        auto token = state.next_application_launch_token++;
        if (token == 0U) {
            token = 1U;
            state.next_application_launch_token = 2U;
        }
        return token;
    }

    std::uint64_t springboard_launch_origin_touch_sequence_locked(
        const KernelSharedState& state)
    {
        if (state.springboard_pending_launch_touch_sequence != 0U)
            return state.springboard_pending_launch_touch_sequence;
        if (state.foreground_application_attempt_process_id) {
            const auto attempt = state.application_launch_attempts.find(
                *state.foreground_application_attempt_process_id);
            if (attempt != state.application_launch_attempts.end() &&
                attempt->second.origin_touch_sequence != 0U) {
                return attempt->second.origin_touch_sequence;
            }
        }
        // Home can arrive after SpringBoard has selected and spawned an App but
        // before it asks launchd for that App's event service. The foreground
        // authorization is deliberately cleared at Home, so retain causality
        // through the exact outgoing PID instead of falling back to an
        // unrelated historical touch.
        if (state.application_touch_suspended &&
            state.application_suspension_reason ==
                KernelSharedState::ApplicationSuspensionReason::Home &&
            state.suspended_application_scene_process_id) {
            const auto attempt = state.application_launch_attempts.find(
                *state.suspended_application_scene_process_id);
            if (attempt != state.application_launch_attempts.end() &&
                attempt->second.origin_touch_sequence != 0U) {
                return attempt->second.origin_touch_sequence;
            }
        }
        return 0U;
    }

    std::optional<std::uint64_t> pending_held_application_origin_locked(
        const KernelSharedState& state, std::uint32_t process_id = 0U)
    {
        if (!state.held_application_launch ||
            !state.application_launch_barrier ||
            state.application_launch_barrier->reason !=
                KernelSharedState::ApplicationSuspensionReason::Lock) {
            return std::nullopt;
        }
        const auto& held = *state.held_application_launch;
        if (held.origin_touch_sequence == 0U ||
            held.origin_touch_sequence >= held.lock_input_sequence ||
            held.lock_input_sequence !=
                state.application_launch_barrier->input_sequence ||
            (state.last_home_launch_barrier_sequence != 0U &&
                held.origin_touch_sequence <
                    state.last_home_launch_barrier_sequence) ||
            (process_id != 0U && held.process_id != 0U &&
                held.process_id != process_id)) {
            return std::nullopt;
        }
        return held.origin_touch_sequence;
    }

    KernelSharedState::ApplicationSuspensionReason interruption_reason(
        KernelSharedState::ApplicationLaunchPhase phase)
    {
        switch (phase) {
        case KernelSharedState::ApplicationLaunchPhase::InterruptedHome:
            return KernelSharedState::ApplicationSuspensionReason::Home;
        case KernelSharedState::ApplicationLaunchPhase::Launching:
        case KernelSharedState::ApplicationLaunchPhase::Active:
        case KernelSharedState::ApplicationLaunchPhase::Suspended:
        case KernelSharedState::ApplicationLaunchPhase::HeldLock:
            return KernelSharedState::ApplicationSuspensionReason::None;
        }
        return KernelSharedState::ApplicationSuspensionReason::None;
    }

    bool attempt_interrupted(
        const KernelSharedState::ApplicationLaunchAttempt& attempt)
    {
        return attempt.phase ==
               KernelSharedState::ApplicationLaunchPhase::InterruptedHome;
    }

    bool attempt_held_by_lock(
        const KernelSharedState::ApplicationLaunchAttempt& attempt)
    {
        return attempt.phase ==
               KernelSharedState::ApplicationLaunchPhase::HeldLock;
    }

    bool origin_is_unlock_touch_locked(
        const KernelSharedState& state, std::uint64_t origin_touch_sequence)
    {
        if (state.springboard_unlock_touch_begin_sequence == 0U ||
            origin_touch_sequence <
                state.springboard_unlock_touch_begin_sequence) {
            return false;
        }
        if (state.springboard_unlock_touch_active)
            return true;
        return state.springboard_unlock_touch_end_sequence != 0U &&
               origin_touch_sequence <=
                   state.springboard_unlock_touch_end_sequence;
    }

    KernelSharedState::ApplicationLaunchAttempt* launch_attempt_locked(
        KernelSharedState& state, std::uint32_t process_id)
    {
        const auto attempt = state.application_launch_attempts.find(process_id);
        return attempt == state.application_launch_attempts.end()
                   ? nullptr
                   : &attempt->second;
    }

    bool attempt_is_home_exit_target_locked(const KernelSharedState& state,
        std::uint32_t process_id,
        const KernelSharedState::ApplicationLaunchAttempt& attempt)
    {
        return state.application_touch_suspended &&
               state.application_suspension_reason ==
                   KernelSharedState::ApplicationSuspensionReason::Home &&
               state.suspended_application_scene_process_id == process_id &&
               state.last_home_launch_barrier_sequence != 0U &&
               attempt.origin_touch_sequence <
                   state.last_home_launch_barrier_sequence;
    }

    bool different_foreground_attempt_locked(
        const KernelSharedState& state, std::uint32_t process_id)
    {
        return state.foreground_application_attempt_process_id &&
               *state.foreground_application_attempt_process_id != process_id;
    }

    bool attempt_authorized_for_foreground_locked(
        const KernelSharedState& state, std::uint32_t process_id,
        const KernelSharedState::ApplicationLaunchAttempt& attempt)
    {
        return !attempt_interrupted(attempt) &&
               state.foreground_application_attempt_process_id == process_id &&
               (attempt.phase ==
                       KernelSharedState::ApplicationLaunchPhase::Launching ||
                   attempt.phase ==
                       KernelSharedState::ApplicationLaunchPhase::Active);
    }

    bool process_has_display_timing_client_locked(
        const KernelSharedState& state, std::uint32_t process_id)
    {
        return std::any_of(state.iokit_display_vsync.begin(),
            state.iokit_display_vsync.end(),
            [&state, process_id](const auto& entry) {
                const auto& [connection_object, registration] = entry;
                // GraphicsServices deliberately toggles its VSync callback
                // around lifecycle transitions. Scene admission still needs to
                // see the registered display client while that callback is
                // disabled; the callback path itself independently gates on
                // `enabled` and therefore sends no notifications and produces
                // no client animation frames. Keeping the retained deadline
                // here preserves the last frame and lets the causal foreground
                // handoff finish before the next enable.
                if (registration.owner_pid != process_id ||
                    !registration.next_deadline) {
                    return false;
                }
                const auto connection =
                    state.iokit_connections.find(connection_object);
                if (connection == state.iokit_connections.end() ||
                    connection->second.owner_pid != process_id) {
                    return false;
                }
                const auto service =
                    state.iokit_services.find(connection->second.service_port);
                return service != state.iokit_services.end() &&
                       service->second.user_client_kind ==
                           KernelSharedState::IOKitUserClientKind::Display;
            });
    }

    bool flattened_display_scene_available_locked(
        const KernelSharedState& state, std::uint32_t process_id,
        bool requests_userspace_prewarm)
    {
        const auto owns_only_scene =
            !state.active_application_scene ||
            state.active_application_scene->process_id == process_id;
        return !requests_userspace_prewarm &&
               !state.application_touch_suspended &&
               state.application_suspension_reason ==
                   KernelSharedState::ApplicationSuspensionReason::None &&
               owns_only_scene && !has_active_application_route_locked(state) &&
               !different_foreground_attempt_locked(state, process_id) &&
               process_has_display_timing_client_locked(state, process_id);
    }

    void release_application_fullscreen_suppression_locked(
        KernelSharedState& state, std::uint32_t process_id);

    bool resolve_flattened_display_scene_locked(KernelSharedState& state,
        std::uint32_t process_id,
        KernelSharedState::ApplicationLaunchAttempt& attempt,
        bool requests_userspace_prewarm, SceneCoordinator* scenes)
    {
        // Some early UIKit stacks render through a display connection owned by
        // the App while SpringBoard flattens those pixels into its own
        // hardware-layer surfaces. There is no cross-process CoreSurface
        // placement for LayerKit to commit, so rendezvous the firmware's
        // independent intent and presentation signals instead. A lifecycle
        // message alone remains insufficient.
        const auto lifecycle_resume_origin =
            attempt.origin ==
                KernelSharedState::ApplicationLaunchOrigin::Spawn ||
            attempt.origin ==
                KernelSharedState::ApplicationLaunchOrigin::ForegroundLifecycle;
        const auto authorized_cold_launch =
            attempt.phase ==
                KernelSharedState::ApplicationLaunchPhase::Launching &&
            attempt_authorized_for_foreground_locked(
                state, process_id, attempt);
        const auto lifecycle_resume =
            attempt.phase ==
                KernelSharedState::ApplicationLaunchPhase::Suspended &&
            lifecycle_resume_origin && attempt.origin_touch_sequence == 0U;
        if (!flattened_display_scene_available_locked(
                state, process_id, requests_userspace_prewarm) ||
            (!authorized_cold_launch && !lifecycle_resume)) {
            return false;
        }

        if (lifecycle_resume) {
            attempt.phase =
                KernelSharedState::ApplicationLaunchPhase::Launching;
            state.foreground_application_attempt_process_id = process_id;
        }
        release_application_fullscreen_suppression_locked(state, process_id);
        if (scenes && !scenes->client_scene(process_id)) {
            state.mark_foreground_transition_locked(
                KernelSharedState::ForegroundTransitionMilestone::
                    SceneCommitted,
                process_id);
            scenes->commit_client_scene(process_id, std::nullopt);
        }
        return true;
    }

    void suppress_application_fullscreen_surfaces_locked(
        KernelSharedState& state, std::uint32_t process_id)
    {
        if (process_id == 0U)
            return;
        state.suppress_future_application_fullscreen_surface_processes.insert(
            process_id);
        const auto publications =
            state.application_fullscreen_surface_publications.find(process_id);
        if (publications ==
            state.application_fullscreen_surface_publications.end()) {
            return;
        }
        for (const auto publication_sequence : publications->second) {
            state.suppressed_application_fullscreen_surface_publications
                .emplace(process_id, publication_sequence);
        }
        if (!publications->second.empty()) {
            state.application_fullscreen_surface_suppression_active.store(
                true, std::memory_order_release);
        }
    }

    void release_application_fullscreen_suppression_locked(
        KernelSharedState& state, std::uint32_t process_id)
    {
        state.suppress_future_application_fullscreen_surface_processes.erase(
            process_id);
        std::erase_if(
            state.suppressed_application_fullscreen_surface_publications,
            [process_id](const auto& publication) {
                return publication.first == process_id;
            });
        state.application_fullscreen_surface_suppression_active.store(
            !state.suppressed_application_fullscreen_surface_publications
                .empty(),
            std::memory_order_release);
    }

    bool held_launch_matches_locked(const KernelSharedState& state,
        std::uint32_t process_id,
        const KernelSharedState::ApplicationLaunchAttempt& attempt)
    {
        return state.held_application_launch &&
               state.held_application_launch->process_id == process_id &&
               state.held_application_launch->launch_token == attempt.token &&
               state.held_application_launch->origin_touch_sequence ==
                   attempt.origin_touch_sequence &&
               pending_held_application_origin_locked(state, process_id)
                   .has_value();
    }

    void bind_held_launch_locked(KernelSharedState& state,
        std::uint32_t process_id,
        const KernelSharedState::ApplicationLaunchAttempt& attempt)
    {
        if (!attempt_held_by_lock(attempt) ||
            !pending_held_application_origin_locked(state, process_id) ||
            attempt.origin_touch_sequence !=
                state.held_application_launch->origin_touch_sequence) {
            return;
        }
        state.held_application_launch->process_id = process_id;
        state.held_application_launch->launch_token = attempt.token;
    }

    bool resume_held_launch_after_unlock_locked(KernelSharedState& state,
        std::uint32_t process_id,
        KernelSharedState::ApplicationLaunchAttempt& attempt)
    {
        if (!held_launch_matches_locked(state, process_id, attempt) ||
            state.held_application_launch->unlock_up_sequence == 0U) {
            return false;
        }
        attempt.phase = KernelSharedState::ApplicationLaunchPhase::Launching;
        state.foreground_application_attempt_process_id = process_id;
        release_application_fullscreen_suppression_locked(state, process_id);
        return true;
    }

    struct UnlockTransitionCompletion {
        bool completes_interrupted_home_exit { };
        std::optional<std::uint32_t> resume_process_id;
    };

    UnlockTransitionCompletion complete_unlock_transition_locked(
        KernelSharedState& state, std::uint64_t unlock_up_sequence)
    {
        UnlockTransitionCompletion completion;
        const auto retained_lock_process_id =
            [&]() -> std::optional<std::uint32_t> {
            if (!state.application_launch_barrier ||
                state.application_launch_barrier->reason !=
                    KernelSharedState::ApplicationSuspensionReason::Lock) {
                return std::nullopt;
            }
            const auto candidate =
                state.application_launch_barrier->retained_process_id
                    ? state.application_launch_barrier->retained_process_id
                    : state.suspended_application_scene_process_id;
            if (!candidate)
                return std::nullopt;
            const auto process_id = *candidate;
            const auto process = state.processes.find(process_id);
            if (process == state.processes.end() || process->second.exited ||
                !is_application_executable_path(
                    process->second.executable_path) ||
                !application_event_object_for_process_locked(
                    state, process_id)) {
                return std::nullopt;
            }
            return process_id;
        }();
        if (!state.application_launch_barrier ||
            state.application_launch_barrier->reason !=
                KernelSharedState::ApplicationSuspensionReason::Lock) {
            state.held_application_launch.reset();
            state.interrupted_home_exit_lock_sequence.reset();
            return completion;
        }

        const auto lock_input_sequence =
            state.application_launch_barrier->input_sequence;
        completion.completes_interrupted_home_exit =
            state.interrupted_home_exit_lock_sequence &&
            *state.interrupted_home_exit_lock_sequence == lock_input_sequence;
        if (completion.completes_interrupted_home_exit)
            state.interrupted_home_exit_lock_sequence.reset();

        if (state.held_application_launch &&
            state.held_application_launch->lock_input_sequence ==
                lock_input_sequence &&
            pending_held_application_origin_locked(state)) {
            state.held_application_launch->unlock_up_sequence =
                unlock_up_sequence;
            const auto process_id = state.held_application_launch->process_id;
            const auto attempt =
                state.application_launch_attempts.find(process_id);
            if (process_id != 0U &&
                attempt != state.application_launch_attempts.end() &&
                attempt->second.token ==
                    state.held_application_launch->launch_token &&
                attempt_held_by_lock(attempt->second)) {
                // The host has validated a complete rightward unlock gesture.
                // Promote the exact held token now; waiting for another
                // lifecycle callback after SpringBoard consumes Up can strand
                // an App whose only callback raced just before that receive.
                attempt->second.phase =
                    KernelSharedState::ApplicationLaunchPhase::Launching;
                state.foreground_application_attempt_process_id = process_id;
                release_application_fullscreen_suppression_locked(
                    state, process_id);
                completion.resume_process_id = process_id;
            }
        } else {
            state.held_application_launch.reset();
        }
        if (!completion.resume_process_id &&
            !completion.completes_interrupted_home_exit &&
            retained_lock_process_id) {
            // Lock suspends the already-active scene without destroying its
            // event route. A completed unlock must promote that same resident
            // scene even when no launch/lifecycle callback follows; otherwise
            // its retained pixels return while all later touches continue to
            // route to SpringBoard.
            const auto process_id = *retained_lock_process_id;
            if (auto* attempt = launch_attempt_locked(state, process_id);
                attempt && !attempt_interrupted(*attempt)) {
                attempt->phase =
                    KernelSharedState::ApplicationLaunchPhase::Launching;
                state.foreground_application_attempt_process_id = process_id;
                state.application_touch_suspended = true;
                state.application_suspension_reason =
                    KernelSharedState::ApplicationSuspensionReason::Lock;
                state.suspended_application_scene_process_id = process_id;
                release_application_fullscreen_suppression_locked(
                    state, process_id);
                completion.resume_process_id = process_id;
            }
        }
        return completion;
    }

    KernelSharedState::ApplicationLaunchAttempt& begin_launch_attempt_locked(
        KernelSharedState& state, std::uint32_t process_id,
        std::uint64_t origin_touch_sequence,
        KernelSharedState::ApplicationLaunchOrigin origin)
    {
        // A foreground application can ask SpringBoard to open another ordinary
        // application (for example through the system URL launcher). Such a
        // spawn has no SpringBoard icon touch sequence, but it is still a real
        // foreground intent. Keep lookup-only/background work suspended while
        // accepting this generic process-owned handoff.
        const auto active_application_route =
            has_active_application_route_locked(state);
        const auto pending_application_handoff =
            state.pending_application_handoff_process_id && [&state] {
                const auto process = state.processes.find(
                    *state.pending_application_handoff_process_id);
                return process != state.processes.end() &&
                       !process->second.exited &&
                       is_application_executable_path(
                           process->second.executable_path);
            }();
        const auto programmatic_foreground_spawn =
            origin == KernelSharedState::ApplicationLaunchOrigin::Spawn &&
            origin_touch_sequence == 0U && active_application_route;
        const auto handoff_foreground_spawn =
            origin == KernelSharedState::ApplicationLaunchOrigin::Spawn &&
            origin_touch_sequence == 0U && pending_application_handoff;
        auto phase = origin_touch_sequence == 0U &&
                             !programmatic_foreground_spawn &&
                             !handoff_foreground_spawn
                         ? KernelSharedState::ApplicationLaunchPhase::Suspended
                         : KernelSharedState::ApplicationLaunchPhase::Launching;
        const auto cancelled_by_home =
            origin_touch_sequence != 0U &&
            state.last_home_launch_barrier_sequence != 0U &&
            origin_touch_sequence < state.last_home_launch_barrier_sequence;
        const auto held_origin =
            pending_held_application_origin_locked(state, process_id);
        if (cancelled_by_home) {
            phase = KernelSharedState::ApplicationLaunchPhase::InterruptedHome;
        } else if (held_origin && *held_origin == origin_touch_sequence) {
            phase = KernelSharedState::ApplicationLaunchPhase::HeldLock;
        } else if (state.application_launch_barrier &&
                   state.application_launch_barrier->reason ==
                       KernelSharedState::ApplicationSuspensionReason::Lock &&
                   origin_touch_sequence <
                       state.application_launch_barrier->input_sequence) {
            phase = KernelSharedState::ApplicationLaunchPhase::Suspended;
        } else if (origin_is_unlock_touch_locked(
                       state, origin_touch_sequence)) {
            phase = KernelSharedState::ApplicationLaunchPhase::Suspended;
        }
        auto [attempt, inserted] =
            state.application_launch_attempts.insert_or_assign(process_id,
                KernelSharedState::ApplicationLaunchAttempt {
                    allocate_application_launch_token_locked(state),
                    origin_touch_sequence, origin, phase,
                    programmatic_foreground_spawn || handoff_foreground_spawn,
                    false });
        static_cast<void>(inserted);
        const auto foreground_transition_phase =
            attempt->second.phase ==
                KernelSharedState::ApplicationLaunchPhase::Launching ||
            attempt->second.phase ==
                KernelSharedState::ApplicationLaunchPhase::Active ||
            attempt->second.phase ==
                KernelSharedState::ApplicationLaunchPhase::HeldLock ||
            attempt->second.foreground_handoff;
        if (foreground_transition_phase) {
            std::optional<KernelSharedState::ForegroundTransitionProcess>
                source;
            if (state.active_application_scene &&
                state.active_application_scene->process_id != process_id) {
                source = state.process_identity_locked(
                    state.active_application_scene->process_id);
            }
            state.begin_foreground_transition_locked(attempt->second.token,
                origin_touch_sequence, std::move(source),
                state.process_identity_locked(process_id));
            if (origin == KernelSharedState::ApplicationLaunchOrigin::Spawn)
                state.mark_foreground_transition_locked(
                    KernelSharedState::ForegroundTransitionMilestone::Spawned,
                    process_id);
        }
        if (attempt->second.phase ==
                KernelSharedState::ApplicationLaunchPhase::Launching ||
            attempt->second.phase ==
                KernelSharedState::ApplicationLaunchPhase::Active) {
            release_application_fullscreen_suppression_locked(
                state, process_id);
            state.foreground_application_attempt_process_id = process_id;
        } else if (attempt_held_by_lock(attempt->second)) {
            suppress_application_fullscreen_surfaces_locked(state, process_id);
            state.foreground_application_attempt_process_id = process_id;
            bind_held_launch_locked(state, process_id, attempt->second);
        } else {
            if (attempt_interrupted(attempt->second) &&
                !attempt_is_home_exit_target_locked(
                    state, process_id, attempt->second)) {
                suppress_application_fullscreen_surfaces_locked(
                    state, process_id);
            } else {
                release_application_fullscreen_suppression_locked(
                    state, process_id);
            }
            if (state.foreground_application_attempt_process_id == process_id)
                state.foreground_application_attempt_process_id.reset();
        }
        return attempt->second;
    }

    bool foreground_transition_attempt(
        const KernelSharedState::ApplicationLaunchAttempt& attempt)
    {
        return attempt.phase ==
                   KernelSharedState::ApplicationLaunchPhase::Launching ||
               attempt.phase ==
                   KernelSharedState::ApplicationLaunchPhase::Active ||
               attempt.phase ==
                   KernelSharedState::ApplicationLaunchPhase::HeldLock ||
               attempt.foreground_handoff;
    }

    void ensure_foreground_transition_snapshot_locked(KernelSharedState& state,
        std::uint32_t process_id,
        const KernelSharedState::ApplicationLaunchAttempt& attempt,
        bool force_foreground, bool mark_spawned)
    {
        // A lifecycle/scene rendezvous is the authoritative foreground decision
        // for the rare path where a process-owned attempt was initially
        // Suspended. The normal launch path remains gated by the causal attempt
        // phase.
        if (!force_foreground && !foreground_transition_attempt(attempt))
            return;
        const auto destination = state.process_identity_locked(process_id);
        if (!destination)
            return;
        std::optional<KernelSharedState::ForegroundTransitionProcess> source;
        if (state.active_application_scene &&
            state.active_application_scene->process_id != process_id) {
            source = state.process_identity_locked(
                state.active_application_scene->process_id);
        }
        state.begin_foreground_transition_locked(attempt.token,
            attempt.origin_touch_sequence, std::move(source), destination);
        if (mark_spawned ||
            attempt.origin ==
                KernelSharedState::ApplicationLaunchOrigin::Spawn) {
            state.mark_foreground_transition_locked(
                KernelSharedState::ForegroundTransitionMilestone::Spawned,
                process_id);
        }
    }

    void record_resident_lookup_locked(KernelSharedState& state,
        std::uint32_t process_id, std::uint64_t origin_touch_sequence)
    {
        // Unlock may cause SpringBoard to probe resident application services.
        // It is never a foreground selection, so preserve an exact existing
        // token (or leave a prewarmed process without one) until a later icon
        // gesture.
        if (origin_is_unlock_touch_locked(state, origin_touch_sequence))
            return;
        if (const auto* existing = launch_attempt_locked(state, process_id)) {
            // Repeated lookups caused by one icon/unlock gesture are one
            // intent. In particular, unlock-triggered lookups must retain the
            // HeldLock token.
            if (existing->origin_touch_sequence == origin_touch_sequence) {
                bind_held_launch_locked(state, process_id, *existing);
                if (state.springboard_pending_launch_touch_sequence ==
                    origin_touch_sequence) {
                    state.springboard_pending_launch_touch_sequence = 0U;
                }
                return;
            }
            const auto owns_live_foreground_route =
                !state.application_touch_suspended &&
                object_owned_by_process_locked(
                    state, state.active_application_event_object, process_id);
            if ((existing->phase ==
                        KernelSharedState::ApplicationLaunchPhase::Launching &&
                    state.foreground_application_attempt_process_id ==
                        process_id) ||
                (existing->phase ==
                        KernelSharedState::ApplicationLaunchPhase::Active &&
                    owns_live_foreground_route) ||
                existing->phase ==
                    KernelSharedState::ApplicationLaunchPhase::HeldLock) {
                return;
            }
        }
        static_cast<void>(begin_launch_attempt_locked(state, process_id,
            origin_touch_sequence,
            KernelSharedState::ApplicationLaunchOrigin::EventServiceLookup));
        if (state.springboard_pending_launch_touch_sequence ==
            origin_touch_sequence) {
            state.springboard_pending_launch_touch_sequence = 0U;
        }
    }

    void apply_launch_barrier_locked(KernelSharedState& state,
        KernelSharedState::ApplicationSuspensionReason reason,
        std::uint64_t input_sequence,
        std::optional<std::uint32_t> sampleable_home_exit_process_id)
    {
        const auto prior_held_application_launch =
            state.held_application_launch;
        state.application_launch_barrier =
            KernelSharedState::ApplicationLaunchBarrier { reason,
                input_sequence, std::nullopt };
        // A Home/Lock barrier supersedes an incomplete App-to-App transition.
        // Do not let a later process spawn consume a foreground intent that the
        // user has already interrupted.
        state.pending_application_handoff_process_id.reset();
        state.interrupted_home_exit_lock_sequence.reset();

        if (reason == KernelSharedState::ApplicationSuspensionReason::Home) {
            state.last_home_launch_barrier_sequence = std::max(
                state.last_home_launch_barrier_sequence, input_sequence);
            state.held_application_launch.reset();
            state.springboard_pending_launch_touch_sequence = 0U;
            for (auto& [process_id, attempt] :
                state.application_launch_attempts) {
                const auto selected =
                    state.foreground_application_attempt_process_id ==
                    process_id;
                if (selected &&
                    (attempt.phase == KernelSharedState::
                                          ApplicationLaunchPhase::Launching ||
                        attempt.phase ==
                            KernelSharedState::ApplicationLaunchPhase::
                                HeldLock) &&
                    attempt.origin_touch_sequence < input_sequence) {
                    attempt.phase = KernelSharedState::ApplicationLaunchPhase::
                        InterruptedHome;
                    // SpringBoard may defer Home until the App publishes its
                    // first real frame. Keep that exact outgoing surface
                    // sampleable for the native shrink animation; foreground
                    // authorization, not black pixels, prevents the cancelled
                    // App from taking ownership again.
                    if (sampleable_home_exit_process_id == process_id) {
                        release_application_fullscreen_suppression_locked(
                            state, process_id);
                    } else {
                        suppress_application_fullscreen_surfaces_locked(
                            state, process_id);
                    }
                    state.foreground_application_attempt_process_id.reset();
                } else if (attempt.phase !=
                           KernelSharedState::ApplicationLaunchPhase::Active) {
                    if (attempt.phase ==
                            KernelSharedState::ApplicationLaunchPhase::
                                Launching &&
                        attempt.origin_touch_sequence < input_sequence) {
                        attempt.phase = KernelSharedState::
                            ApplicationLaunchPhase::Suspended;
                    }
                    if (attempt_interrupted(attempt) &&
                        sampleable_home_exit_process_id != process_id) {
                        suppress_application_fullscreen_surfaces_locked(
                            state, process_id);
                    } else {
                        release_application_fullscreen_suppression_locked(
                            state, process_id);
                    }
                }
            }
            return;
        }

        const auto active_foreground =
            !state.application_touch_suspended &&
            state.active_application_event_object != 0U &&
            state.active_application_scene &&
            state.active_application_scene->event_object ==
                state.active_application_event_object &&
            object_owned_by_process_locked(state,
                state.active_application_event_object,
                state.active_application_scene->process_id);

        std::optional<std::uint32_t> selected_process_id;
        if (state.foreground_application_attempt_process_id) {
            const auto attempt = state.application_launch_attempts.find(
                *state.foreground_application_attempt_process_id);
            if (attempt != state.application_launch_attempts.end() &&
                (attempt->second.phase ==
                        KernelSharedState::ApplicationLaunchPhase::Launching ||
                    attempt->second.phase ==
                        KernelSharedState::ApplicationLaunchPhase::HeldLock) &&
                attempt->second.origin_touch_sequence < input_sequence) {
                selected_process_id = attempt->first;
            }
        }

        state.held_application_launch.reset();
        if (!active_foreground) {
            auto gesture_origin = std::uint64_t { };
            if (selected_process_id) {
                gesture_origin =
                    state.application_launch_attempts.at(*selected_process_id)
                        .origin_touch_sequence;
            } else if (prior_held_application_launch &&
                       prior_held_application_launch->origin_touch_sequence !=
                           0U &&
                       prior_held_application_launch->origin_touch_sequence >=
                           state.last_home_launch_barrier_sequence) {
                gesture_origin =
                    prior_held_application_launch->origin_touch_sequence;
            } else if (!springboard_alert_owns_input_locked(state) &&
                       !state.springboard_unlock_touch_pending &&
                       !state.springboard_unlock_touch_active) {
                gesture_origin =
                    state.springboard_pending_launch_touch_sequence;
                if (gesture_origin == 0U)
                    gesture_origin =
                        state.springboard_enqueued_active_touch_begin_sequence;
                if (gesture_origin == 0U)
                    gesture_origin =
                        state.springboard_active_touch_begin_sequence;
                if (gesture_origin == 0U &&
                    state.springboard_enqueued_last_touch_begin_sequence !=
                        0U &&
                    state.springboard_enqueued_last_touch_end_sequence <
                        input_sequence &&
                    input_sequence -
                            state
                                .springboard_enqueued_last_touch_end_sequence <=
                        2U) {
                    gesture_origin =
                        state.springboard_enqueued_last_touch_begin_sequence;
                }
            }
            if (gesture_origin != 0U && gesture_origin < input_sequence &&
                gesture_origin >= state.last_home_launch_barrier_sequence) {
                state.held_application_launch =
                    KernelSharedState::HeldApplicationLaunch { gesture_origin,
                        input_sequence, 0U, 0U, 0U };
            }
        }

        for (auto& [process_id, attempt] : state.application_launch_attempts) {
            if (attempt.phase ==
                KernelSharedState::ApplicationLaunchPhase::Active)
                continue;
            if (attempt_interrupted(attempt)) {
                // A Lock that follows Home must not turn the already-outgoing
                // snapshot black while SpringBoard finishes the exit behind the
                // lock screen.
                if (sampleable_home_exit_process_id == process_id) {
                    release_application_fullscreen_suppression_locked(
                        state, process_id);
                } else {
                    suppress_application_fullscreen_surfaces_locked(
                        state, process_id);
                }
                if (state.foreground_application_attempt_process_id ==
                    process_id)
                    state.foreground_application_attempt_process_id.reset();
                continue;
            }
            if (selected_process_id == process_id &&
                attempt.origin_touch_sequence < input_sequence &&
                attempt.origin_touch_sequence >=
                    state.last_home_launch_barrier_sequence) {
                attempt.phase =
                    KernelSharedState::ApplicationLaunchPhase::HeldLock;
                suppress_application_fullscreen_surfaces_locked(
                    state, process_id);
                state.held_application_launch =
                    KernelSharedState::HeldApplicationLaunch {
                        attempt.origin_touch_sequence, input_sequence,
                        process_id, attempt.token, 0U
                    };
                state.foreground_application_attempt_process_id = process_id;
                continue;
            }
            if (attempt.phase ==
                    KernelSharedState::ApplicationLaunchPhase::Launching &&
                attempt.origin_touch_sequence < input_sequence)
                attempt.phase =
                    KernelSharedState::ApplicationLaunchPhase::Suspended;
            release_application_fullscreen_suppression_locked(
                state, process_id);
            if (state.foreground_application_attempt_process_id == process_id)
                state.foreground_application_attempt_process_id.reset();
        }
    }

    void suspend_interrupted_process_locked(KernelSharedState& state,
        std::uint32_t process_id,
        KernelSharedState::ApplicationSuspensionReason reason,
        SceneCoordinator* scenes)
    {
        if (scenes)
            scenes->suspend_client_scene(process_id);

        const auto owns_global_scene =
            state.active_application_scene &&
            state.active_application_scene->process_id == process_id;
        const auto owns_global_route = object_owned_by_process_locked(
            state, state.active_application_event_object, process_id);
        if (!owns_global_scene && !owns_global_route)
            return;

        state.application_touch_suspended = true;
        state.application_suspension_reason = reason;
        state.suspended_application_scene_process_id = process_id;
    }

    void maintain_home_exit_process_locked(KernelSharedState& state,
        std::uint32_t process_id, SceneCoordinator* scenes)
    {
        release_application_fullscreen_suppression_locked(state, process_id);
        state.application_touch_suspended = true;
        state.application_suspension_reason =
            KernelSharedState::ApplicationSuspensionReason::Home;
        state.suspended_application_scene_process_id = process_id;
        if (scenes)
            scenes->begin_client_scene_exit(process_id);

        auto event_object = std::uint32_t { };
        if (const auto pending = state.mach_port_objects.lookup(
                state.pending_application_event_object);
            pending && pending->receive_owner == process_id) {
            event_object = state.pending_application_event_object;
        } else if (state.active_application_scene &&
                   state.active_application_scene->process_id == process_id) {
            event_object = state.active_application_scene->event_object;
        }
        if (event_object == 0U)
            return;

        std::optional<KernelSharedState::ApplicationTouchTransform> transform;
        if (state.latest_application_scene_transform &&
            state.latest_application_scene_transform->process_id ==
                process_id) {
            transform = state.latest_application_scene_transform->transform;
        } else if (const auto cached =
                       state.application_scene_transforms.find(process_id);
            cached != state.application_scene_transforms.end()) {
            transform = cached->second;
        } else if (state.active_application_scene &&
                   state.active_application_scene->process_id == process_id) {
            transform = state.active_application_scene->touch_transform;
        }
        state.active_application_scene =
            KernelSharedState::ActiveApplicationScene { process_id,
                event_object, transform };
        state.active_application_event_object = event_object;
    }

    void complete_home_transition_locked(KernelSharedState& state,
        std::uint32_t process_id, SceneCoordinator* scenes)
    {
        if (scenes)
            scenes->suspend_client_scene(process_id);
        if (state.active_application_scene &&
            state.active_application_scene->process_id == process_id) {
            state.active_application_scene.reset();
        }
        if (object_owned_by_process_locked(
                state, state.active_application_event_object, process_id)) {
            state.active_application_event_object = 0U;
        }
        if (object_owned_by_process_locked(
                state, state.pending_application_event_object, process_id)) {
            state.pending_application_event_object = 0U;
        }
        if (auto* attempt = launch_attempt_locked(state, process_id); attempt) {
            attempt->phase =
                KernelSharedState::ApplicationLaunchPhase::Suspended;
        }
        if (state.latest_application_scene_transform &&
            state.latest_application_scene_transform->process_id ==
                process_id) {
            state.latest_application_scene_transform.reset();
        }
        std::erase_if(state.application_scene_context_owners,
            [process_id](
                const auto& owner) { return owner.second == process_id; });
        if (state.held_application_launch &&
            state.held_application_launch->process_id == process_id) {
            state.held_application_launch.reset();
        }
        if (state.foreground_application_attempt_process_id == process_id)
            state.foreground_application_attempt_process_id.reset();
        release_application_fullscreen_suppression_locked(state, process_id);
        state.application_touch_suspended = false;
        state.application_suspension_reason =
            KernelSharedState::ApplicationSuspensionReason::None;
        state.suspended_application_scene_process_id.reset();
    }

} // namespace

void register_springboard_alert_observers(UserlandHleRegistry& registry,
    std::function<void(std::uint32_t, SpringBoardAlertObservation)> observer)
{
    registry.register_objc_instance_method(std::string { springboard_image },
        "SBAlertItemsController",
        "activateAlertItem:", "-[SBAlertItemsController activateAlertItem:]",
        [observer](UserlandHleCall& call) {
            const auto object = call.argument(2);
            observer(object, SpringBoardAlertObservation::ActivationBegan);
            call.resume_original_persistently();
        });
    registry.register_objc_instance_method(std::string { springboard_image },
        "SBAwayController",
        "wantsToHandleAlert:", "-[SBAwayController wantsToHandleAlert:]",
        [observer](UserlandHleCall& call) {
            const auto object = call.argument(2);
            call.resume_original_persistently(
                [observer, object](UserlandHleCall& completed) {
                    observer(object,
                        completed.argument(0) != 0U
                            ? SpringBoardAlertObservation::ClassifiedLockScreen
                            : SpringBoardAlertObservation::
                                  ClassifiedApplicationOverlay);
                });
        });
    constexpr std::array<std::string_view, 3> deactivation_selectors {
        "deactivateAlertItem:", "deactivateAlertItem:reason:",
        "_deactivateAlertItem:reason:"
    };
    for (const auto selector : deactivation_selectors) {
        registry.register_objc_instance_method(
            std::string { springboard_image }, "SBAlertItemsController",
            std::string { selector },
            "-[SBAlertItemsController " + std::string { selector } + "]",
            [observer](UserlandHleCall& call) {
                const auto object = call.argument(2);
                call.resume_original_persistently(
                    [observer, object](UserlandHleCall& completed) {
                        static_cast<void>(completed);
                        observer(
                            object, SpringBoardAlertObservation::Deactivated);
                    });
            });
    }
}

void register_springboard_lock_observer(
    UserlandHleRegistry& registry, std::function<void(bool)> observer)
{
    registry.register_objc_instance_method(std::string { springboard_image },
        "SBAwayController", "activate", "-[SBAwayController activate]",
        [observer](UserlandHleCall& call) {
            call.resume_original_persistently(
                [observer](UserlandHleCall& completed) {
                    static_cast<void>(completed);
                    observer(true);
                });
        });
    registry.register_objc_instance_method(std::string { springboard_image },
        "SBAwayController", "deactivate", "-[SBAwayController deactivate]",
        [observer](UserlandHleCall& call) {
            call.resume_original_persistently(
                [observer](UserlandHleCall& completed) {
                    if (completed.argument(0) != 0U)
                        observer(false);
                });
        });
}

void register_application_suspension_observer(UserlandHleRegistry& registry,
    std::function<void(std::uint32_t, bool)> observer,
    std::function<void(std::uint32_t)> under_lock_observer)
{
    const auto native_under_lock_observer = under_lock_observer;
    registry.register_objc_instance_method(std::string { ui_kit_image },
        "UIApplication", "applicationWillSuspendUnderLock",
        "-[UIApplication applicationWillSuspendUnderLock]",
        [observer = native_under_lock_observer](UserlandHleCall& call) {
            const auto process_id = call.process_id();
            call.resume_original_persistently(
                [observer, process_id](UserlandHleCall& completed) {
                    static_cast<void>(completed);
                    if (observer)
                        observer(process_id);
                });
        });
    registry.register_objc_instance_method(std::string { ui_kit_image },
        "UIApplication",
        "_setSuspendedUnderLock:", "-[UIApplication _setSuspendedUnderLock:]",
        [observer = std::move(under_lock_observer)](UserlandHleCall& call) {
            const auto process_id = call.process_id();
            const auto suspended = call.argument(2) != 0U;
            call.resume_original_persistently(
                [observer, process_id, suspended](UserlandHleCall& completed) {
                    static_cast<void>(completed);
                    // Under-lock resume is completed by the native unlock
                    // gesture; only its entering edge establishes the Lock
                    // barrier here.
                    if (observer && suspended)
                        observer(process_id);
                });
        });
    registry.register_objc_instance_method(std::string { ui_kit_image },
        "UIApplication", "_setSuspended:", "-[UIApplication _setSuspended:]",
        [observer = std::move(observer)](UserlandHleCall& call) {
            const auto process_id = call.process_id();
            const auto suspended = call.argument(2) != 0U;
            call.resume_original_persistently(
                [observer, process_id, suspended](UserlandHleCall& completed) {
                    static_cast<void>(completed);
                    if (observer)
                        observer(process_id, suspended);
                });
        });
}

void record_springboard_alert_state(KernelSharedState& state,
    std::uint32_t object, SpringBoardAlertObservation observation)
{
    if (object == 0U)
        return;
    std::lock_guard lock { state.mach_mutex };
    using Presentation = KernelSharedState::SpringBoardAlertPresentation;
    switch (observation) {
    case SpringBoardAlertObservation::ActivationBegan:
        state.active_springboard_alert_items[object] = { Presentation::Pending,
            allocate_foreground_layer_sequence_locked(state) };
        break;
    case SpringBoardAlertObservation::ClassifiedLockScreen:
    case SpringBoardAlertObservation::ClassifiedApplicationOverlay:
        if (auto item = state.active_springboard_alert_items.find(object);
            item != state.active_springboard_alert_items.end() &&
            item->second.presentation == Presentation::Pending) {
            item->second.presentation =
                observation == SpringBoardAlertObservation::ClassifiedLockScreen
                    ? Presentation::LockScreen
                    : Presentation::ApplicationOverlay;
        }
        break;
    case SpringBoardAlertObservation::Deactivated:
        state.active_springboard_alert_items.erase(object);
        break;
    }
}

void record_springboard_lock_state(KernelSharedState& state, bool active)
{
    std::lock_guard lock { state.mach_mutex };
    state.springboard_lock_screen_active = active;
    if (!active) {
        const auto period = iokit_abi::display_vsync::period_absolute_time;
        const auto now = state.clock.now();
        for (auto& [connection_object, registration] :
            state.iokit_display_vsync) {
            // A notification port can outlive the firmware's callback. A
            // selector-off request withdraws the callout and refcon; waking
            // the panel must not turn that port into a null callback.
            if (registration.notification_port == 0U ||
                registration.async_reference
                    [iokit_abi::display_vsync::async_callout_index] == 0U ||
                registration.async_reference
                    [iokit_abi::display_vsync::async_refcon_index] == 0U)
                continue;
            // Preserve the valid callback window on the panel's fixed phase.
            registration.enabled = true;
            registration.last_notification_frame_time.reset();
            if (!registration.next_deadline ||
                *registration.next_deadline <= now) {
                registration.next_deadline = now - now % period + period;
            }
            kernel_iokit::display::index_vsync_deadline_locked(
                state, connection_object);
        }
    }
    if (active) {
        const auto in_flight_touch_begin =
            state.springboard_enqueued_active_touch_begin_sequence != 0U
                ? state.springboard_enqueued_active_touch_begin_sequence
                : state.springboard_active_touch_begin_sequence;
        const auto completed_unlock_begin =
            state.springboard_unlock_touch_begin_sequence;
        const auto completed_unlock_end =
            state.springboard_unlock_touch_end_sequence;
        const auto completed_before_classification =
            in_flight_touch_begin == 0U && completed_unlock_begin != 0U &&
            completed_unlock_end >= completed_unlock_begin &&
            state.next_graphics_input_sequence != 0U &&
            completed_unlock_end == state.next_graphics_input_sequence - 1U &&
            valid_unlock_trajectory(state.springboard_unlock_touch_start_x,
                state.springboard_unlock_touch_start_y,
                state.springboard_unlock_touch_end_x,
                state.springboard_unlock_touch_end_y);
        if (completed_before_classification) {
            // A loaded SpringBoard can return from -activate only after the
            // native slider has already completed. Reconcile that stale
            // activation with the exact immediately preceding trajectory; it
            // must not turn the first desktop alert or icon tap into another
            // unlock gesture.
            state.springboard_lock_screen_active = false;
            state.springboard_unlock_touch_pending = false;
            state.springboard_unlock_touch_active = false;
            state.springboard_unlock_touch_begin_sequence =
                completed_unlock_begin;
            state.springboard_unlock_touch_end_sequence = completed_unlock_end;
            clear_springboard_enqueued_gesture_locked(state);
            static_cast<void>(
                complete_unlock_transition_locked(state, completed_unlock_end));
            return;
        }
        if (!state.springboard_unlock_touch_active &&
            in_flight_touch_begin != 0U) {
            // SBAwayController can finish activating after the firmware has
            // already consumed the slider's Down event. Adopt that exact
            // in-flight gesture instead of making its trailing Up arm another
            // unlock attempt.
            state.springboard_unlock_touch_pending = false;
            state.springboard_unlock_touch_active = true;
            state.springboard_unlock_touch_begin_sequence =
                in_flight_touch_begin;
        } else if (!state.springboard_unlock_touch_active) {
            state.springboard_unlock_touch_pending = true;
        }
        return;
    }
    if (state.springboard_pending_launch_touch_sequence ==
        state.springboard_unlock_touch_begin_sequence) {
        state.springboard_pending_launch_touch_sequence = 0U;
    }
    state.springboard_unlock_touch_pending = false;
    state.springboard_unlock_touch_active = false;
}

void register_springboard_application_handoff_animation(
    UserlandHleRegistry& registry,
    std::function<bool()> foreground_application_observer)
{
    registry.register_guest_function(
        std::string { objc_image }, std::string { objc_get_class });
    registry.register_guest_function(
        std::string { objc_image }, std::string { selector_register_name });
    registry.register_guest_function(
        std::string { objc_image }, std::string { objc_message_send });
    registry.register_objc_instance_method(std::string { springboard_image },
        "SBDisplay", "setActivationSetting:value:",
        "-[SBDisplay setActivationSetting:value:]", [](UserlandHleCall& call) {
            constexpr std::uint32_t animation_start_time_setting = 0x1000U;
            if (call.argument(2) == animation_start_time_setting &&
                call.argument(3) != 0U) {
                // SpringBoard records the start before preparing the zoom
                // layers. Removing only this explicit start lets the
                // transaction choose its commit time while retaining the
                // firmware's animation definition.
                call.cpu().registers()[3] = 0U;
            }
            call.resume_original_persistently();
        });
    registry.register_objc_instance_method(std::string { springboard_image },
        "SBDisplay",
        "setActivationSetting:flag:", "-[SBDisplay setActivationSetting:flag:]",
        [foreground_application_observer = std::move(
             foreground_application_observer)](UserlandHleCall& call) {
            const auto application = call.argument(0);
            const auto setting = call.argument(2);
            const auto flag = call.argument(3);
            if (application == 0U || setting != application_display_setting ||
                flag != 0U || !foreground_application_observer ||
                !foreground_application_observer()) {
                call.resume_original_persistently();
                return;
            }
            // Finish the firmware's setting mutation exactly once, then
            // schedule its native launch animation before
            // applicationOpenURL:asPanel: continues into the display-stack
            // push.
            call.resume_original_persistently(
                [application](UserlandHleCall& return_call) {
                    animate_application_handoff(return_call, application);
                });
        });
}

bool take_pending_application_handoff_animation(KernelSharedState& state)
{
    std::lock_guard lock { state.mach_mutex };
    if (!state.foreground_application_attempt_process_id)
        return false;
    auto* attempt = launch_attempt_locked(
        state, *state.foreground_application_attempt_process_id);
    if (!attempt || !attempt->foreground_handoff ||
        attempt->handoff_animation_dispatched ||
        attempt_interrupted(*attempt) || attempt_held_by_lock(*attempt) ||
        (attempt->phase !=
                KernelSharedState::ApplicationLaunchPhase::Launching &&
            attempt->phase !=
                KernelSharedState::ApplicationLaunchPhase::Active)) {
        return false;
    }
    attempt->handoff_animation_dispatched = true;
    return true;
}

std::optional<std::uint32_t> event_type(std::span<const std::byte> message)
{
    constexpr std::size_t event_type_offset =
        darwin::mig_wire::message_header_size;
    if (message.size() < event_type_offset + sizeof(std::uint32_t) ||
        read_word(message, darwin::mig_wire::header_identifier_offset) !=
            graphics_event_message_id) {
        return std::nullopt;
    }
    return read_word(message, event_type_offset);
}

void record_bootstrap_lookup_locked(KernelSharedState& state,
    std::uint32_t reply_object, std::string_view service_name,
    std::uint32_t requester_process_id)
{
    if (reply_object != 0 && !service_name.empty()) {
        const auto origin_touch_sequence =
            springboard_launch_origin_touch_sequence_locked(state);
        state.pending_bootstrap_service_requests[reply_object].push_back(
            KernelSharedState::PendingBootstrapServiceRequest {
                KernelSharedState::PendingBootstrapServiceRequest::Kind::Lookup,
                std::string { service_name }, requester_process_id,
                origin_touch_sequence,
                process_is_springboard_locked(state, requester_process_id) &&
                    !state.springboard_unlock_touch_pending &&
                    !state.springboard_unlock_touch_active &&
                    origin_touch_sequence != 0U });
    }
}

void record_bootstrap_check_in_locked(KernelSharedState& state,
    std::uint32_t reply_object, std::string_view service_name,
    std::uint32_t requester_process_id)
{
    if (reply_object == 0 || service_name.empty())
        return;
    state.pending_bootstrap_service_requests[reply_object].push_back(
        KernelSharedState::PendingBootstrapServiceRequest {
            KernelSharedState::PendingBootstrapServiceRequest::Kind::CheckIn,
            std::string { service_name }, requester_process_id, 0, false });
}

void record_bootstrap_registration_locked(
    KernelSharedState& state, std::string_view service_name)
{
    if (service_name.empty())
        return;
    auto& generation =
        state.bootstrap_service_generations[std::string { service_name }];
    ++generation;
    if (generation == 0U)
        generation = 1U;
}

ServiceResolution record_bootstrap_reply_locked(KernelSharedState& state,
    std::uint32_t reply_object,
    std::span<const KernelSharedState::MachMessage::PortTransfer> transfers,
    std::uint32_t receiver_process_id)
{
    const auto pending =
        state.pending_bootstrap_service_requests.find(reply_object);
    if (pending == state.pending_bootstrap_service_requests.end() ||
        pending->second.empty()) {
        return { };
    }

    const auto request = std::move(pending->second.front());
    pending->second.pop_front();
    if (pending->second.empty())
        state.pending_bootstrap_service_requests.erase(pending);
    const auto service_name = request.service_name;
    const auto check_in =
        request.kind ==
        KernelSharedState::PendingBootstrapServiceRequest::Kind::CheckIn;
    const auto expected_right = check_in ? xnu::ipc::Right::Receive
                                         : xnu::ipc::Right::Send;
    const auto service = std::find_if(transfers.begin(), transfers.end(),
        [expected_right](const auto& transfer) {
            return transfer.right == expected_right;
        });
    const auto reply_port = state.mach_port_objects.lookup(reply_object);
    const auto receiver = reply_port && reply_port->receive_owner != 0U
                              ? reply_port->receive_owner
                              : receiver_process_id;
    if (service == transfers.end()) {
        if (!check_in && receiver != 0U) {
            const auto generation =
                state.bootstrap_service_generations[service_name];
            state.pending_bootstrap_retries[receiver] =
                PendingTimer::BootstrapRetry { service_name, generation };
        }
        return ServiceResolution { 0, 0, false, service_name };
    }
    if (!check_in && receiver != 0U) {
        const auto retry = state.pending_bootstrap_retries.find(receiver);
        if (retry != state.pending_bootstrap_retries.end() &&
            retry->second.service_name == service_name) {
            state.pending_bootstrap_retries.erase(retry);
        }
    }

    // Keep the firmware-resolved service object available to protocol Profiles.
    // The object is refreshed on every successful bootstrap reply so a service
    // generation cannot leave a stale remote-renderer rendezvous behind.
    state.bootstrap_service_objects[service_name] = service->object;

    std::size_t flushed = 0;
    bool application_event_port = false;
    if (service_name == system_event_service) {
        while (!state.pending_graphics_inputs.empty()) {
            const auto& input = state.pending_graphics_inputs.front();
            if (input.kind ==
                KernelSharedState::PendingGraphicsInput::Kind::Touch) {
                queue_locked(
                    state, service->object, input.touch, input.input_sequence);
            } else {
                queue_simple_event_locked(state, service->object,
                    input.system_event_type, input.input_sequence,
                    input.input_kind);
            }
            state.pending_graphics_inputs.pop_front();
            ++flushed;
        }
    } else if (const auto port =
                   state.mach_port_objects.lookup(service->object);
               !check_in && port) {
        const auto exact_springboard_request =
            request.requester_process_id == receiver &&
            process_is_springboard_locked(state, receiver);
        const auto exact_pending_gesture =
            request.application_launch_candidate &&
            state.springboard_pending_launch_touch_sequence != 0U &&
            state.springboard_pending_launch_touch_sequence ==
                request.origin_touch_sequence;
        const auto process = state.processes.find(port->receive_owner);
        if (process != state.processes.end() && !process->second.exited &&
            is_application_executable_path(process->second.executable_path)) {
            if (exact_springboard_request) {
                const auto* existing =
                    launch_attempt_locked(state, port->receive_owner);
                const auto exact_existing_intent =
                    existing &&
                    (request.origin_touch_sequence == 0U ||
                        existing->origin_touch_sequence ==
                            request.origin_touch_sequence) &&
                    (state.foreground_application_attempt_process_id ==
                            port->receive_owner ||
                        attempt_held_by_lock(*existing) ||
                        attempt_is_home_exit_target_locked(
                            state, port->receive_owner, *existing));
                const auto effective_origin_touch_sequence =
                    request.origin_touch_sequence != 0U
                        ? request.origin_touch_sequence
                    : exact_existing_intent ? existing->origin_touch_sequence
                                            : 0U;
                const auto exact_effective_pending_gesture =
                    exact_pending_gesture &&
                    request.origin_touch_sequence ==
                        effective_origin_touch_sequence;
                if (exact_existing_intent || exact_effective_pending_gesture) {
                    record_resident_lookup_locked(state, port->receive_owner,
                        effective_origin_touch_sequence);
                    const auto* attempt =
                        launch_attempt_locked(state, port->receive_owner);
                    const auto accepted_foreground_route =
                        attempt &&
                        attempt->origin_touch_sequence ==
                            effective_origin_touch_sequence &&
                        (state.foreground_application_attempt_process_id ==
                                port->receive_owner ||
                            attempt_held_by_lock(*attempt) ||
                            attempt_is_home_exit_target_locked(
                                state, port->receive_owner, *attempt));
                    if (accepted_foreground_route) {
                        if (state.pending_application_event_object !=
                                service->object &&
                            state.latest_application_scene_transform &&
                            state.latest_application_scene_transform
                                    ->process_id == port->receive_owner) {
                            state.latest_application_scene_transform.reset();
                        }
                        state.pending_application_event_object =
                            service->object;
                        state.application_event_objects_by_process[port
                                ->receive_owner] = service->object;
                        application_event_port = true;
                    }
                }
            }
        } else if (exact_springboard_request && exact_pending_gesture) {
            state.pending_application_event_launches.insert_or_assign(
                service->object,
                KernelSharedState::PendingApplicationEventLaunch {
                    receiver, request.origin_touch_sequence });
        }
    }
    return ServiceResolution { service->object, flushed, application_event_port,
        service_name };
}

EnqueueResult enqueue_touch(KernelSharedState& state, const TouchInput& input,
    SceneCoordinator* scenes, PresentationTracker* presentations,
    bool* home_recovery_requested, std::uint64_t* input_sequence_output)
{
    if (home_recovery_requested)
        *home_recovery_requested = false;
    const TouchInput sanitized { input.phase,
        std::isfinite(input.x) ? input.x : 0.0F,
        std::isfinite(input.y) ? input.y : 0.0F };
    const auto presentation =
        presentations && sanitized.phase == TouchPhase::Down
            ? presentations->hit_test(sanitized.x, sanitized.y)
            : std::nullopt;
    std::unique_lock lock { state.mach_mutex };
    const auto input_sequence = allocate_graphics_input_sequence_locked(state);
    if (input_sequence_output)
        *input_sequence_output = input_sequence;

    // Preserve host transition tracking, but let an open firmware HID system
    // classify physical contacts before routing them to system gestures,
    // accessibility services or an application window.
    const auto native_input = state.native_hid_touch_events
        ? state.hid_event_queue.enqueue({ sanitized, state.clock.now() })
        : false;
    if (native_input)
        state.note_io_event_transition();

    const auto terminal = sanitized.phase == TouchPhase::Up ||
                          sanitized.phase == TouchPhase::Cancel;
    if (sanitized.phase == TouchPhase::Down)
        state.active_graphics_touch_route.reset();

    auto route = sanitized.phase == TouchPhase::Down
                     ? std::optional<KernelSharedState::GraphicsTouchRoute> { }
                     : state.active_graphics_touch_route;
    if (route && route->application &&
        !object_owned_by_process_locked(
            state, route->destination_object, route->process_id)) {
        route.reset();
        state.active_graphics_touch_route.reset();
    }

    const auto system_owns_transition =
        state.springboard_unlock_touch_pending ||
        state.springboard_unlock_touch_active ||
        state.application_touch_suspended;
    if (!route && !system_owns_transition && presentation) {
        route = presentation_touch_route_locked(state, *presentation, scenes);
    }
    if (!route && !system_owns_transition)
        route = semantic_touch_route_locked(state, scenes);
    if (!route)
        route = springboard_touch_route();

    if (!terminal)
        state.active_graphics_touch_route = route;

    if (route->application) {
        clear_springboard_enqueued_gesture_locked(state);
        if (!native_input)
            queue_locked(state, route->destination_object,
                transform_touch(sanitized, route->transform), input_sequence);
        // App-owned event ports do not pass the physical touch through
        // SpringBoard. Preserve the firmware's separate idle-duration event so
        // SpringBoard can run its native resetIdleDuration: path as it would
        // for input consumed by the system event port.
        queue_idle_duration_reset_locked(state, input_sequence);
        if (terminal)
            state.active_graphics_touch_route.reset();
        return EnqueueResult::Queued;
    }

    const auto unlock_touch_input = state.springboard_unlock_touch_pending ||
                                    state.springboard_unlock_touch_active;
    auto completed_unlock_gesture = false;
    if (sanitized.phase == TouchPhase::Down) {
        // Retain the origin even before SpringBoard has classified the visible
        // layer as its lock scene. The classification callback can race this
        // already-enqueued Down event on another guest CPU.
        state.springboard_unlock_touch_start_x = sanitized.x;
        state.springboard_unlock_touch_start_y = sanitized.y;
    }
    if (state.springboard_unlock_touch_pending &&
        sanitized.phase == TouchPhase::Down) {
        state.springboard_unlock_touch_pending = false;
        state.springboard_unlock_touch_active = true;
        state.springboard_unlock_touch_begin_sequence = input_sequence;
        state.springboard_unlock_touch_end_sequence = 0U;
        state.springboard_unlock_touch_start_x = sanitized.x;
        state.springboard_unlock_touch_start_y = sanitized.y;
    } else if (state.springboard_unlock_touch_active &&
               (sanitized.phase == TouchPhase::Up ||
                   sanitized.phase == TouchPhase::Cancel)) {
        state.springboard_unlock_touch_active = false;
        state.springboard_unlock_touch_end_sequence = input_sequence;
        state.springboard_unlock_touch_end_x = sanitized.x;
        state.springboard_unlock_touch_end_y = sanitized.y;
        // The iPhone OS 1.x lock control is a deliberate rightward slider. Do
        // not turn a tap, failed drag, or cancelled gesture into a synthetic
        // Home.
        completed_unlock_gesture =
            sanitized.phase == TouchPhase::Up &&
            valid_unlock_trajectory(state.springboard_unlock_touch_start_x,
                state.springboard_unlock_touch_start_y, sanitized.x,
                sanitized.y);
        state.springboard_unlock_touch_pending = !completed_unlock_gesture;
    }
    if (!unlock_touch_input) {
        if (sanitized.phase == TouchPhase::Down) {
            if (state.application_touch_suspended &&
                state.application_suspension_reason ==
                    KernelSharedState::ApplicationSuspensionReason::Home &&
                state.suspended_application_scene_process_id) {
                complete_home_transition_locked(state,
                    *state.suspended_application_scene_process_id, scenes);
            }
            // A deliberate post-unlock gesture supersedes a held launch that
            // still has not become foreground. The exact PID/token remains
            // suppressed; a later lookup for it is background work, not the
            // user's new selection.
            if (state.held_application_launch &&
                state.held_application_launch->unlock_up_sequence != 0U) {
                const auto held = *state.held_application_launch;
                const auto attempt =
                    state.application_launch_attempts.find(held.process_id);
                if (held.process_id != 0U &&
                    attempt != state.application_launch_attempts.end() &&
                    attempt->second.token == held.launch_token &&
                    attempt->second.phase !=
                        KernelSharedState::ApplicationLaunchPhase::Active) {
                    attempt->second.phase =
                        KernelSharedState::ApplicationLaunchPhase::Suspended;
                    suppress_application_fullscreen_surfaces_locked(
                        state, held.process_id);
                    if (state.foreground_application_attempt_process_id ==
                        held.process_id) {
                        state.foreground_application_attempt_process_id.reset();
                    }
                }
                state.held_application_launch.reset();
            }
            state.springboard_pending_launch_touch_sequence = input_sequence;
            state.springboard_enqueued_active_touch_begin_sequence =
                input_sequence;
        } else if (sanitized.phase == TouchPhase::Up ||
                   sanitized.phase == TouchPhase::Cancel) {
            state.springboard_enqueued_last_touch_begin_sequence =
                state.springboard_enqueued_active_touch_begin_sequence != 0U
                    ? state.springboard_enqueued_active_touch_begin_sequence
                    : input_sequence;
            state.springboard_enqueued_last_touch_end_sequence = input_sequence;
            state.springboard_enqueued_last_touch_end_x = sanitized.x;
            state.springboard_enqueued_last_touch_end_y = sanitized.y;
            state.springboard_enqueued_active_touch_begin_sequence = 0U;
        }
    }
    auto unlock_completion = UnlockTransitionCompletion { };
    if (completed_unlock_gesture) {
        state.springboard_lock_screen_active = false;
        // Keep the completed trajectory until the asynchronous SpringBoard lock
        // classification observes it. SBAwayController can report the old
        // active state after the slider's Up event;
        // record_springboard_lock_state uses these exact sequence fields to
        // reconcile that stale callback instead of arming the next desktop tap
        // as another unlock gesture.
        unlock_completion =
            complete_unlock_transition_locked(state, input_sequence);
    }
    // Native HID owns the unlock and application-exit sequence. A second
    // physical HOME after its swipe would act on the newly unlocked screen.
    if (!native_input && unlock_completion.completes_interrupted_home_exit &&
        home_recovery_requested) {
        *home_recovery_requested = true;
    }
    const auto resume_process_id = unlock_completion.resume_process_id;
    if (terminal)
        state.active_graphics_touch_route.reset();
    const auto service = state.bootstrap_service_objects.find(
        std::string { system_event_service });
    if (service == state.bootstrap_service_objects.end()) {
        if (!native_input) {
            state.pending_graphics_inputs.push_back(
                KernelSharedState::PendingGraphicsInput {
                    KernelSharedState::PendingGraphicsInput::Kind::Touch,
                    sanitized,
                    0, input_sequence,
                    KernelSharedState::MachMessage::GraphicsInputKind::Touch });
        }
        queue_idle_duration_reset_locked(state, input_sequence);
        lock.unlock();
        if (resume_process_id) {
            activate_resolved_application(state, *resume_process_id, scenes);
        }
        return native_input ? EnqueueResult::Queued : EnqueueResult::Deferred;
    }
    if (!native_input)
        queue_locked(state, service->second, sanitized, input_sequence);
    // Hardware input reaches SpringBoard through this event port. The device
    // also emits its separate idle-duration event for the same input, which
    // lets SpringBoard run resetIdleDuration: even when the touch is consumed
    // by the desktop or by a SpringBoard launch control.
    queue_idle_duration_reset_locked(state, input_sequence);
    lock.unlock();
    if (resume_process_id) {
        activate_resolved_application(state, *resume_process_id, scenes);
    }
    return EnqueueResult::Queued;
}

EnqueueResult enqueue_system_button(KernelSharedState& state,
    const SystemButtonInput& input, std::uint64_t* input_sequence,
    bool begins_display_lock_transaction)
{
    const auto input_kind = system_button_input_kind(input.button);
    std::lock_guard lock { state.mach_mutex };
    const auto sequence = allocate_graphics_input_sequence_locked(state);
    if (input_sequence)
        *input_sequence = sequence;
    if (begins_display_lock_transaction) {
        state.host_display_current_lock_down_sequence = sequence;
        state.host_display_pending_lock_power_off_sequences.push_back(sequence);
    }
    const auto service = state.bootstrap_service_objects.find(
        std::string { system_event_service });
    const auto destination =
        service == state.bootstrap_service_objects.end() ? 0U : service->second;
    const auto& profile = GraphicsServicesInputAbi::for_abi(
        system_graphics_input_abi_locked(state, destination));
    const auto event_type = profile.system_button_type(input);
    if (service == state.bootstrap_service_objects.end()) {
        // A firmware HID consumer can own system controls without publishing
        // the legacy GraphicsServices system-event port. Let that consumer
        // classify the physical key and perform its native wake/idle handling.
        if (state.hid_event_queue.enqueue({ hid_button(input), state.clock.now() })) {
            state.note_io_event_transition();
            return EnqueueResult::Queued;
        }
        state.pending_graphics_inputs.push_back(
            KernelSharedState::PendingGraphicsInput {
                KernelSharedState::PendingGraphicsInput::Kind::SystemEvent, { },
                event_type, sequence, input_kind });
        return EnqueueResult::Deferred;
    }
    queue_simple_event_locked(
        state, service->second, event_type, sequence, input_kind);
    return EnqueueResult::Queued;
}

void record_lock_wake_request(KernelSharedState& state)
{
    std::lock_guard lock { state.mach_mutex };
    if (state.springboard_unlock_touch_pending ||
        state.springboard_unlock_touch_active) {
        return;
    }
    if (state.springboard_lock_screen_active == false)
        return;
    state.springboard_unlock_touch_pending = true;
}

EnqueueResult enqueue_ringer_switch_change(
    KernelSharedState& state, bool active)
{
    std::lock_guard lock { state.mach_mutex };
    const auto input_sequence = allocate_graphics_input_sequence_locked(state);
    constexpr auto input_kind =
        KernelSharedState::MachMessage::GraphicsInputKind::OtherSystem;
    const auto service = state.bootstrap_service_objects.find(
        std::string { system_event_service });
    const auto destination =
        service == state.bootstrap_service_objects.end() ? 0U : service->second;
    const auto& profile = GraphicsServicesInputAbi::for_abi(
        system_graphics_input_abi_locked(state, destination));
    const auto event_type = profile.ringer_switch_type(active);
    if (service == state.bootstrap_service_objects.end()) {
        state.pending_graphics_inputs.push_back(
            KernelSharedState::PendingGraphicsInput {
                KernelSharedState::PendingGraphicsInput::Kind::SystemEvent, { },
                event_type, input_sequence, input_kind });
        return EnqueueResult::Deferred;
    }
    queue_simple_event_locked(
        state, service->second, event_type, input_sequence, input_kind);
    return EnqueueResult::Queued;
}

namespace {

    void suspend_active_application_locked(KernelSharedState& state,
        KernelSharedState::ApplicationSuspensionReason reason,
        SceneCoordinator* scenes, std::uint64_t system_input_sequence)
    {
        if (system_input_sequence == 0U) {
            system_input_sequence = allocate_graphics_input_sequence_locked(state);
        }
        if (reason == KernelSharedState::ApplicationSuspensionReason::Lock) {
            state.springboard_lock_screen_active = true;
            if (!state.springboard_unlock_touch_active)
                state.springboard_unlock_touch_pending = true;
        }
        const auto prior_home_exit_process_id =
            state.application_touch_suspended &&
                    state.application_suspension_reason ==
                        KernelSharedState::ApplicationSuspensionReason::Home
                ? state.suspended_application_scene_process_id
                : std::nullopt;

        std::optional<std::uint32_t> target_process_id;
        if (state.foreground_application_attempt_process_id) {
            const auto process = state.processes.find(
                *state.foreground_application_attempt_process_id);
            if (process != state.processes.end() && !process->second.exited &&
                launch_attempt_locked(
                    state, *state.foreground_application_attempt_process_id)) {
                target_process_id = process->first;
            } else {
                state.foreground_application_attempt_process_id.reset();
            }
        }

        std::optional<std::uint32_t> routed_process_id;
        if (const auto active_port = state.mach_port_objects.lookup(
                state.active_application_event_object)) {
            routed_process_id = active_port->receive_owner;
        }
        const auto active_process_id =
            state.active_application_scene
                ? std::optional<std::uint32_t> { state.active_application_scene
                          ->process_id }
                : routed_process_id;
        if (!target_process_id &&
            reason == KernelSharedState::ApplicationSuspensionReason::Lock &&
            state.application_touch_suspended &&
            state.application_suspension_reason ==
                KernelSharedState::ApplicationSuspensionReason::Home &&
            state.suspended_application_scene_process_id &&
            ((state.active_application_scene &&
                 state.active_application_scene->process_id ==
                     *state.suspended_application_scene_process_id) ||
                routed_process_id ==
                    state.suspended_application_scene_process_id)) {
            target_process_id = *state.suspended_application_scene_process_id;
        }
        if (!target_process_id && active_process_id &&
            state.active_application_event_object != 0U &&
            !state.application_touch_suspended &&
            (!scenes || scenes->client_scene_active(*active_process_id))) {
            target_process_id = active_process_id;
        }
        // Capture the exact selected token before Home updates the cancellation
        // watermark and clears foreground authorization. This narrow interval is
        // where SpringBoard has finished the opening animation but the App has not
        // yet published its first UI frame.
        const auto sampleable_home_exit_process_id =
            reason == KernelSharedState::ApplicationSuspensionReason::Home
                ? target_process_id ? target_process_id : prior_home_exit_process_id
                : prior_home_exit_process_id;
        apply_launch_barrier_locked(
            state, reason, system_input_sequence, sampleable_home_exit_process_id);
        if (reason == KernelSharedState::ApplicationSuspensionReason::Lock &&
            target_process_id && state.application_launch_barrier &&
            state.application_launch_barrier->input_sequence ==
                system_input_sequence) {
            state.application_launch_barrier->retained_process_id =
                *target_process_id;
        }

        // With no exact current target, the sequence barrier is sufficient. A later
        // SpringBoard spawn/lookup will create a PID-bound attempt and compare its
        // causal touch sequence with this barrier.
        if (!target_process_id)
            return;

        if (prior_home_exit_process_id == target_process_id) {
            state.interrupted_home_exit_lock_sequence = system_input_sequence;
        }
        state.application_touch_suspended = true;
        state.application_suspension_reason = reason;
        state.suspended_application_scene_process_id = *target_process_id;
        if (reason == KernelSharedState::ApplicationSuspensionReason::Home) {
            release_application_fullscreen_suppression_locked(
                state, *target_process_id);
        }
        if (scenes) {
            if (reason == KernelSharedState::ApplicationSuspensionReason::Home) {
                scenes->begin_client_scene_exit(*target_process_id);
            } else {
                scenes->suspend_client_scene(*target_process_id);
            }
        }
    }

} // namespace

void suspend_active_application(KernelSharedState& state,
    KernelSharedState::ApplicationSuspensionReason reason,
    SceneCoordinator* scenes, std::uint64_t system_input_sequence)
{
    std::lock_guard lock { state.mach_mutex };
    suspend_active_application_locked(
        state, reason, scenes, system_input_sequence);
}

void record_system_event_delivery_locked(KernelSharedState& state,
    std::uint32_t destination, std::uint32_t event_type, SceneCoordinator* scenes)
{
    const auto service = state.bootstrap_service_objects.find(
        std::string { system_event_service });
    if (service == state.bootstrap_service_objects.end() ||
        service->second != destination)
        return;
    const auto& profile = GraphicsServicesInputAbi::for_abi(
        graphics_input_abi_for_object_locked(state, destination));
    const auto home = event_type == profile.system_events.home[0];
    const auto lock = event_type == profile.system_events.lock[0];
    if ((!home && !lock) ||
        state.requested_display_power_state.value_or(1U) == 0U)
        return;
    if (home && (state.springboard_unlock_touch_pending ||
                    state.springboard_unlock_touch_active))
        return;
    // Firmware event producers (accessibility and other system services) own
    // the wire event. Apply the same scene barrier as physical input without
    // injecting a second button event.
    suspend_active_application_locked(state,
        home ? KernelSharedState::ApplicationSuspensionReason::Home
             : KernelSharedState::ApplicationSuspensionReason::Lock,
        scenes, 0U);
}

void complete_home_transition_after_present(KernelSharedState& state,
    std::uint32_t presenter_process_id, SceneCoordinator* scenes)
{
    std::lock_guard lock { state.mach_mutex };
    if (!process_is_springboard_locked(state, presenter_process_id) ||
        !state.application_touch_suspended ||
        state.application_suspension_reason !=
            KernelSharedState::ApplicationSuspensionReason::Home ||
        !state.suspended_application_scene_process_id) {
        return;
    }
    const auto process_id = *state.suspended_application_scene_process_id;
    // The first SpringBoard SwapEnd starts the animation; it is not an
    // ownership completion point. Keep any live, PID-bound attempt sampleable
    // until the ordered native background event. A later user gesture provides
    // a deterministic stale-exit fallback if that private event never arrives.
    const auto process = state.processes.find(process_id);
    if (launch_attempt_locked(state, process_id) &&
        process != state.processes.end() && !process->second.exited) {
        return;
    }
    complete_home_transition_locked(state, process_id, scenes);
}

void record_application_spawn(KernelSharedState& state,
    std::uint32_t sender_process_id, std::uint32_t process_id,
    std::string_view executable_path, std::span<const std::string> arguments,
    SceneCoordinator* scenes, bool force_foreground)
{
    std::lock_guard lock { state.mach_mutex };
    // Older SpringBoard launches fork through launchd and then SETEXEC in the
    // child, so that successful child has parent PID 1 rather than the
    // SpringBoard PID. Keep this exception causal: a SETEXEC application is
    // foreground-observable only while a recent host input or exact handoff is
    // still pending. Ordinary/background launches retain the sender guard.
    const auto exact_foreground_handoff =
        state.foreground_application_attempt_process_id == process_id ||
        state.pending_application_handoff_process_id == process_id;
    const auto causal_setexec_foreground =
        force_foreground &&
        (state.pending_foreground_transition_input_completion ||
            exact_foreground_handoff);
    if ((!process_is_springboard_locked(state, sender_process_id) &&
            !causal_setexec_foreground) ||
        process_id == 0U || !is_application_executable_path(executable_path) ||
        std::find(arguments.begin(), arguments.end(), "--suspended") !=
            arguments.end()) {
        return;
    }
    const auto held_origin =
        pending_held_application_origin_locked(state, process_id);
    const auto origin_touch_sequence = held_origin.value_or(
        springboard_launch_origin_touch_sequence_locked(state));
    auto* attempt = launch_attempt_locked(state, process_id);
    if (!attempt || attempt->origin_touch_sequence != origin_touch_sequence) {
        attempt = &begin_launch_attempt_locked(state, process_id,
            origin_touch_sequence,
            KernelSharedState::ApplicationLaunchOrigin::Spawn);
    } else {
        bind_held_launch_locked(state, process_id, *attempt);
    }
    ensure_foreground_transition_snapshot_locked(
        state, process_id, *attempt, force_foreground, true);
    if (origin_touch_sequence == 0U &&
        state.pending_application_handoff_process_id) {
        state.pending_application_handoff_process_id.reset();
    }
    if (state.springboard_pending_launch_touch_sequence ==
        origin_touch_sequence) {
        state.springboard_pending_launch_touch_sequence = 0U;
    }
    if (attempt_is_home_exit_target_locked(state, process_id, *attempt)) {
        maintain_home_exit_process_locked(state, process_id, scenes);
    } else if ((attempt_interrupted(*attempt) ||
                   attempt_held_by_lock(*attempt)) &&
               scenes) {
        scenes->suspend_client_scene(process_id);
    }
}

namespace {

    void activate_resolved_application_locked(KernelSharedState& state,
        std::uint32_t process_id, SceneCoordinator* scenes)
    {
        const auto route_was_active =
            has_active_application_route_locked(state) &&
            state.active_application_scene->process_id == process_id;
        if (route_was_active &&
            (!scenes || scenes->client_scene_active(process_id))) {
            return;
        }
        auto* attempt = launch_attempt_locked(state, process_id);
        if (!attempt) {
            if (scenes)
                scenes->suspend_client_scene(process_id);
            return;
        }
        if (attempt_is_home_exit_target_locked(state, process_id, *attempt)) {
            maintain_home_exit_process_locked(state, process_id, scenes);
            return;
        }
        if (attempt_held_by_lock(*attempt) &&
            !resume_held_launch_after_unlock_locked(
                state, process_id, *attempt)) {
            if (scenes)
                scenes->suspend_client_scene(process_id);
            state.application_touch_suspended = true;
            state.application_suspension_reason =
                KernelSharedState::ApplicationSuspensionReason::Lock;
            state.suspended_application_scene_process_id = process_id;
            return;
        }
        if (attempt_interrupted(*attempt)) {
            suspend_interrupted_process_locked(
                state, process_id, interruption_reason(attempt->phase), scenes);
            return;
        }
        const auto process = state.processes.find(process_id);
        const auto valid_application =
            process != state.processes.end() && !process->second.exited &&
            is_application_executable_path(process->second.executable_path);
        if (!valid_application)
            return;
        const auto requests_userspace_prewarm =
            std::find(process->second.arguments.begin(),
                process->second.arguments.end(),
                "--suspended") != process->second.arguments.end();
        const auto timing_client =
            process_has_display_timing_client_locked(state, process_id);
        const auto resolved = resolve_flattened_display_scene_locked(
            state, process_id, *attempt, requests_userspace_prewarm, scenes);
        const auto resumes_locked_scene =
            attempt->phase ==
                KernelSharedState::ApplicationLaunchPhase::Suspended &&
            state.application_touch_suspended &&
            state.application_suspension_reason ==
                KernelSharedState::ApplicationSuspensionReason::Lock &&
            state.suspended_application_scene_process_id == process_id;
        if (!attempt_authorized_for_foreground_locked(
                state, process_id, *attempt) &&
            !resumes_locked_scene) {
            if (scenes)
                scenes->suspend_client_scene(process_id);
            return;
        }
        if (different_foreground_attempt_locked(state, process_id)) {
            if (scenes)
                scenes->suspend_client_scene(process_id);
            return;
        }
        const auto scene_committed =
            scenes ? scenes->client_scene(process_id).has_value()
                   : state.active_application_scene &&
                         state.active_application_scene->touch_transform
                             .has_value();
        const auto owns_active_intent =
            state.active_application_scene &&
            state.active_application_scene->process_id == process_id;
        const auto event_object =
            application_event_object_for_process_locked(state, process_id)
                .value_or(0U);
        const auto preserves_committed_foreground =
            state.active_application_scene && !owns_active_intent &&
            state.active_application_event_object ==
                state.active_application_scene->event_object &&
            !state.application_touch_suspended &&
            (scenes ? scenes->client_scene_active(
                          state.active_application_scene->process_id)
                    : state.active_application_scene->touch_transform
                          .has_value());
        if (scene_committed && event_object != 0U && valid_application &&
            !preserves_committed_foreground &&
            (!requests_userspace_prewarm || owns_active_intent)) {
            // Some firmware builds bind the resident process first and only
            // later promote its Suspended attempt through this scene/event
            // rendezvous. Start the bounded observation at the point foreground
            // ownership is actually accepted, then fill milestones already
            // proven by this block.
            ensure_foreground_transition_snapshot_locked(
                state, process_id, *attempt, true, false);
            state.mark_foreground_transition_locked(
                KernelSharedState::ForegroundTransitionMilestone::
                    EventPortReady,
                process_id);
            state.mark_foreground_transition_locked(
                KernelSharedState::ForegroundTransitionMilestone::Lifecycle,
                process_id);
            state.mark_foreground_transition_locked(
                KernelSharedState::ForegroundTransitionMilestone::
                    SceneCommitted,
                process_id);
            std::optional<KernelSharedState::ApplicationTouchTransform>
                transform;
            if (const auto cached =
                    state.application_scene_transforms.find(process_id);
                cached != state.application_scene_transforms.end()) {
                transform = cached->second;
            } else if (owns_active_intent) {
                transform = state.active_application_scene->touch_transform;
            }
            state.active_application_scene =
                KernelSharedState::ActiveApplicationScene { process_id,
                    event_object, transform };
            state.active_application_event_object = event_object;
            state.application_touch_suspended = false;
            state.application_suspension_reason =
                KernelSharedState::ApplicationSuspensionReason::None;
            state.suspended_application_scene_process_id.reset();
            attempt->phase = KernelSharedState::ApplicationLaunchPhase::Active;
            if (!route_was_active)
                mark_application_layer_active_locked(state);
            clear_springboard_enqueued_gesture_locked(state);
            if (held_launch_matches_locked(state, process_id, *attempt))
                state.held_application_launch.reset();
            if (scenes)
                scenes->activate_client_scene(process_id);
        }
    }

    // A prewarmed application can receive its first lifecycle event only after
    // the lock slider has completed.  That event is the firmware's foreground
    // rendezvous for the application that was already rendering behind the
    // lock scene; it is not an icon-selection lookup and therefore has no
    // launch attempt to consume.  Bind a normal lifecycle-origin attempt to
    // this exact completed unlock so the existing scene admission path can
    // promote it without naming an application or page.
    bool promote_application_after_unlock_locked(
        KernelSharedState& state, std::uint32_t process_id)
    {
        if (state.springboard_lock_screen_active != false ||
            state.springboard_unlock_touch_pending ||
            state.springboard_unlock_touch_active ||
            state.springboard_unlock_touch_end_sequence == 0U ||
            state.springboard_pending_launch_touch_sequence != 0U ||
            has_active_application_route_locked(state) ||
            state.application_touch_suspended ||
            !application_event_object_for_process_locked(state, process_id)) {
            return false;
        }
        const auto process = state.processes.find(process_id);
        if (process == state.processes.end() || process->second.exited ||
            !is_application_executable_path(process->second.executable_path)) {
            return false;
        }
        const auto existing = launch_attempt_locked(state, process_id);
        if (existing && existing->phase !=
                            KernelSharedState::ApplicationLaunchPhase::Suspended) {
            return false;
        }
        auto& attempt = begin_launch_attempt_locked(state, process_id, 0U,
            KernelSharedState::ApplicationLaunchOrigin::ForegroundLifecycle);
        // The lifecycle event is already the post-unlock foreground proof.
        // Display timing may still be disabled while SpringBoard is handing
        // the panel back, so do not wait for the first VSync registration to
        // authorize this exact route; the normal scene/event checks below
        // still gate ownership.
        attempt.phase = KernelSharedState::ApplicationLaunchPhase::Launching;
        state.foreground_application_attempt_process_id = process_id;
        release_application_fullscreen_suppression_locked(state, process_id);
        ensure_foreground_transition_snapshot_locked(
            state, process_id, attempt, true, false);
        return true;
    }

} // namespace

void activate_resolved_application(KernelSharedState& state,
    std::uint32_t process_id, SceneCoordinator* scenes)
{
    std::lock_guard lock { state.mach_mutex };
    activate_resolved_application_locked(state, process_id, scenes);
}

void reset_application_scene_context(KernelSharedState& state,
    std::uint32_t render_process_id, std::uint32_t context)
{
    std::lock_guard lock { state.mach_mutex };
    state.application_scene_context_owners.erase(
        std::pair { render_process_id, context });
}

std::optional<std::uint32_t> record_application_scene_transform(
    KernelSharedState& state, std::uint32_t render_process_id,
    std::uint32_t context,
    const KernelSharedState::ApplicationTouchTransform& transform)
{
    if (!std::isfinite(transform.presentation_offset_x) ||
        !std::isfinite(transform.presentation_offset_y) ||
        !std::isfinite(transform.screen_origin_y)) {
        return std::nullopt;
    }
    std::lock_guard lock { state.mach_mutex };
    const auto context_key = std::pair { render_process_id, context };
    auto owner = state.application_scene_context_owners.find(context_key);
    // During early boot launchd can start the first UIKit client before
    // SpringBoard has delivered its event-port/lifecycle rendezvous.  The
    // client's own LayerKit transform is nevertheless a process-owned display
    // admission signal.  Bind a lifecycle attempt here so the normal scene
    // activation path can consume the transform and establish touch routing;
    // do not steal an already-resolved foreground route.
    if (!has_active_application_route_locked(state) &&
        state.application_suspension_reason ==
            KernelSharedState::ApplicationSuspensionReason::None) {
        // LayerKit may be serviced by a shared renderer (for example lsd),
        // so the caller PID is not necessarily the UIKit client's PID. When
        // that happens, use the pending event right as the capability-bound
        // client identity rather than dropping the first live transform.
        auto candidate_process_id = render_process_id;
        const auto render_process = state.processes.find(render_process_id);
        if (render_process == state.processes.end() ||
            !is_application_executable_path(
                render_process->second.executable_path)) {
            if (const auto pending = state.mach_port_objects.lookup(
                    state.pending_application_event_object);
                pending && pending->receive_owner != 0U) {
                candidate_process_id = pending->receive_owner;
            }
        }
        const auto process = state.processes.find(candidate_process_id);
        if (process != state.processes.end() && !process->second.exited &&
            is_application_executable_path(process->second.executable_path)) {
            auto* existing = launch_attempt_locked(state, candidate_process_id);
            auto& attempt = existing
                ? *existing
                : begin_launch_attempt_locked(state, candidate_process_id, 0U,
                      KernelSharedState::ApplicationLaunchOrigin::
                          ForegroundLifecycle);
            // A stale prewarm/lookup token must not mask the first live root;
            // the capability-bound pending event and transform re-authorize
            // this client while no other foreground route is active.
            attempt.phase =
                KernelSharedState::ApplicationLaunchPhase::Launching;
            state.foreground_application_attempt_process_id =
                candidate_process_id;
        }
    }
    const auto exact_scene_target = [&state](std::uint32_t candidate) {
        const auto* attempt = launch_attempt_locked(state, candidate);
        if (!attempt)
            return false;
        const auto exact_held_launch =
            attempt_held_by_lock(*attempt) &&
            held_launch_matches_locked(state, candidate, *attempt);
        const auto exact_home_exit =
            attempt_is_home_exit_target_locked(state, candidate, *attempt);
        return (attempt_authorized_for_foreground_locked(
                    state, candidate, *attempt) ||
                   exact_held_launch || exact_home_exit) &&
               !different_foreground_attempt_locked(state, candidate);
    };
    const auto exact_unbound_target =
        [&state, &exact_scene_target,
            render_process_id]() -> std::optional<std::uint32_t> {
        if (!process_is_springboard_locked(state, render_process_id))
            return std::nullopt;
        if (state.foreground_application_attempt_process_id &&
            exact_scene_target(
                *state.foreground_application_attempt_process_id)) {
            return state.foreground_application_attempt_process_id;
        }
        if (state.application_touch_suspended &&
            state.application_suspension_reason ==
                KernelSharedState::ApplicationSuspensionReason::Home &&
            state.suspended_application_scene_process_id &&
            exact_scene_target(*state.suspended_application_scene_process_id)) {
            return state.suspended_application_scene_process_id;
        }
        return std::nullopt;
    };

    std::uint32_t process_id { };
    if (owner != state.application_scene_context_owners.end() &&
        exact_scene_target(owner->second)) {
        process_id = owner->second;
    }
    if (process_id == 0U) {
        const auto pending_port = state.mach_port_objects.lookup(
            state.pending_application_event_object);
        if (pending_port && exact_scene_target(pending_port->receive_owner))
            process_id = pending_port->receive_owner;
    }
    if (process_id == 0U) {
        const auto unbound_target = exact_unbound_target();
        if (!unbound_target)
            return std::nullopt;
        process_id = *unbound_target;
    }
    if (owner != state.application_scene_context_owners.end() &&
        owner->second != process_id) {
        // LayerKit contexts are reused by SpringBoard. A retired owner must not
        // permanently redirect a new exact launch to the previous App.
        owner->second = process_id;
    }
    // SpringBoard publishes separate full-screen roots for the outgoing App's
    // lock screen and exit snapshots. Ignore only that App's roots: a different
    // App can publish its first live root before didBecomeActive arrives.
    const auto* attempt = launch_attempt_locked(state, process_id);
    const auto exact_held_launch =
        attempt && attempt_held_by_lock(*attempt) &&
        held_launch_matches_locked(state, process_id, *attempt);
    const auto exact_home_exit = attempt && attempt_is_home_exit_target_locked(
                                                state, process_id, *attempt);
    // While the display is locked, SpringBoard publishes its own full-screen
    // root using the same rendering process/context machinery. A launch token
    // held behind that lock proves which App may resume after unlock; it does
    // not make the current lock-screen root an App scene. Accept the App's next
    // transform only after unlock promotes the token back to Launching.
    if (exact_held_launch && state.application_touch_suspended &&
        state.application_suspension_reason ==
            KernelSharedState::ApplicationSuspensionReason::Lock &&
        state.suspended_application_scene_process_id == process_id) {
        return std::nullopt;
    }
    const auto reactivation_in_progress =
        attempt && (attempt_authorized_for_foreground_locked(
                        state, process_id, *attempt) ||
                       exact_held_launch || exact_home_exit);
    if (state.application_touch_suspended &&
        state.suspended_application_scene_process_id == process_id &&
        !reactivation_in_progress) {
        return std::nullopt;
    }
    const auto process = state.processes.find(process_id);
    if (process == state.processes.end() || process->second.exited ||
        !is_application_executable_path(process->second.executable_path)) {
        return std::nullopt;
    }
    if (!attempt ||
        (!attempt_authorized_for_foreground_locked(
             state, process_id, *attempt) &&
            !exact_held_launch && !exact_home_exit) ||
        different_foreground_attempt_locked(state, process_id)) {
        return std::nullopt;
    }
    if (owner == state.application_scene_context_owners.end()) {
        state.application_scene_context_owners.emplace(context_key, process_id);
    }
    const auto owns_active_route =
        state.active_application_scene &&
        state.active_application_scene->process_id == process_id;
    state.latest_application_scene_transform =
        KernelSharedState::PendingApplicationSceneTransform { process_id,
            transform };
    state.application_scene_transforms[process_id] = transform;
    if (owns_active_route && !exact_held_launch) {
        state.active_application_scene->touch_transform = transform;
        state.active_application_event_object =
            state.active_application_scene->event_object;
    }
    return process_id;
}

void release_application_process_locked(
    KernelSharedState& state, std::uint32_t process_id)
{
    const auto object_owned_by_process = [&state, process_id](
                                             std::uint32_t object) {
        const auto port = state.mach_port_objects.lookup(object);
        return port && port->receive_owner == process_id;
    };
    const auto active_scene_owned =
        state.active_application_scene &&
        state.active_application_scene->process_id == process_id;
    const auto suspended_scene_owned =
        state.suspended_application_scene_process_id == process_id;
    const auto active_event = state.active_application_event_object;
    const auto active_route_owned = active_scene_owned ||
                                    suspended_scene_owned ||
                                    object_owned_by_process(active_event);

    if (object_owned_by_process(state.pending_application_event_object) ||
        (active_route_owned &&
            state.pending_application_event_object == active_event)) {
        state.pending_application_event_object = 0;
    }
    if (active_route_owned) {
        state.active_application_event_object = 0;
    }
    if (active_route_owned || suspended_scene_owned) {
        state.application_touch_suspended = false;
        state.application_suspension_reason =
            KernelSharedState::ApplicationSuspensionReason::None;
    }
    if (suspended_scene_owned) {
        state.suspended_application_scene_process_id.reset();
    }
    if (state.latest_application_scene_transform &&
        state.latest_application_scene_transform->process_id == process_id) {
        state.latest_application_scene_transform.reset();
    }
    if (active_scene_owned) {
        state.active_application_scene.reset();
    }
    if (state.pending_application_handoff_process_id == process_id) {
        state.pending_application_handoff_process_id.reset();
    }
    if (state.foreground_application_attempt_process_id == process_id) {
        state.foreground_application_attempt_process_id.reset();
    }
    if (state.held_application_launch &&
        state.held_application_launch->process_id == process_id) {
        if (state.held_application_launch->unlock_up_sequence == 0U &&
            state.held_application_launch->origin_touch_sequence >=
                state.last_home_launch_barrier_sequence) {
            state.held_application_launch->process_id = 0U;
            state.held_application_launch->launch_token = 0U;
        } else {
            state.held_application_launch.reset();
        }
    }
    release_application_fullscreen_suppression_locked(state, process_id);
    state.application_event_objects_by_process.erase(process_id);
    if (state.active_graphics_touch_route &&
        state.active_graphics_touch_route->process_id == process_id) {
        state.active_graphics_touch_route.reset();
    }
    state.application_launch_attempts.erase(process_id);
    state.application_fullscreen_surface_publications.erase(process_id);
    state.application_scene_transforms.erase(process_id);
    std::erase_if(state.application_scene_context_owners,
        [process_id](const auto& owner) { return owner.second == process_id; });
}

void record_application_event_delivery_locked(KernelSharedState& state,
    std::uint32_t sender_pid, std::uint32_t destination,
    std::uint32_t event_type, SceneCoordinator* scenes)
{
    const auto& application_events =
        GraphicsServicesInputAbi::for_abi(
            graphics_input_abi_for_object_locked(state, destination))
            .application_events;
    if (event_type == application_events.background_complete) {
        const auto sender = state.processes.find(sender_pid);
        const auto destination_port =
            state.mach_port_objects.lookup(destination);
        const auto valid_background_completion =
            sender != state.processes.end() && !sender->second.exited &&
            is_application_executable_path(sender->second.executable_path) &&
            destination_port &&
            process_is_springboard_locked(
                state, destination_port->receive_owner);
        if (valid_background_completion) {
            if (state.application_touch_suspended &&
                state.application_suspension_reason ==
                    KernelSharedState::ApplicationSuspensionReason::Home &&
                state.suspended_application_scene_process_id == sender_pid) {
                complete_home_transition_locked(state, sender_pid, scenes);
            }
            return;
        }
    }

    const auto sender = state.processes.find(sender_pid);
    if (sender == state.processes.end() || sender->second.exited ||
        !sender->second.executable_path.ends_with(
            "/SpringBoard.app/SpringBoard")) {
        return;
    }
    const auto destination_port = state.mach_port_objects.lookup(destination);
    const auto application =
        destination_port ? state.processes.find(destination_port->receive_owner)
                         : state.processes.end();
    if (!destination_port || application == state.processes.end() ||
        application->second.exited ||
        !is_application_executable_path(application->second.executable_path)) {
        return;
    }
    const auto process_id = destination_port->receive_owner;
    const auto resume_origin_touch_sequence =
        event_type == application_events.resume
            ? state.springboard_pending_launch_touch_sequence
            : 0U;
    if (const auto pending =
            state.pending_application_event_launches.find(destination);
        pending != state.pending_application_event_launches.end() &&
        pending->second.springboard_process_id == sender_pid) {
        const auto origin_touch_sequence =
            pending->second.origin_touch_sequence;
        state.pending_application_event_launches.erase(pending);
        record_resident_lookup_locked(state, process_id, origin_touch_sequence);
    } else if (resume_origin_touch_sequence != 0U) {
        // A resident event port remains cached after Home, so SpringBoard can
        // send the resume lifecycle event without another bootstrap lookup.
        // Bind that firmware-owned event to the exact icon gesture still
        // pending in the system input queue; otherwise the committed App
        // snapshot becomes visible while touch continues to route to
        // SpringBoard.
        record_resident_lookup_locked(
            state, process_id, resume_origin_touch_sequence);
    }
    state.application_event_objects_by_process[process_id] = destination;
    const auto unlock_promotion =
        event_type == application_events.resume &&
        promote_application_after_unlock_locked(state, process_id);
    state.mark_foreground_transition_locked(
        KernelSharedState::ForegroundTransitionMilestone::EventPortReady,
        process_id);
    state.mark_foreground_transition_locked(
        KernelSharedState::ForegroundTransitionMilestone::Lifecycle,
        process_id);
    // Event delivery proves the PID-owned route, not lifecycle meaning. Retry
    // the readiness rendezvous for every firmware event so an event port that
    // arrives after a LayerKit commit, or after display timing becomes live,
    // cannot strand an otherwise authorized foreground launch.
    activate_resolved_application_locked(state, process_id, scenes);
    if (unlock_promotion && state.active_application_scene &&
        state.active_application_scene->process_id == process_id &&
        state.active_application_event_object == destination) {
        state.springboard_unlock_touch_begin_sequence = 0U;
        state.springboard_unlock_touch_end_sequence = 0U;
    }
}

void record_application_remote_scene_commit_locked(KernelSharedState& state,
    std::uint32_t sender_pid, std::uint32_t destination,
    SceneCoordinator* scenes)
{
    const auto application = state.processes.find(sender_pid);
    const auto destination_port = state.mach_port_objects.lookup(destination);
    if (application == state.processes.end() || application->second.exited ||
        !is_application_executable_path(application->second.executable_path) ||
        !destination_port ||
        !process_is_springboard_locked(
            state, destination_port->receive_owner) ||
        scenes == nullptr) {
        return;
    }

    state.mark_foreground_transition_locked(
        KernelSharedState::ForegroundTransitionMilestone::SceneCommitted,
        sender_pid);
    scenes->commit_client_scene(sender_pid, std::nullopt);
    // Early boot clients can publish their remote scene before SpringBoard
    // delivers the application event port. Preserve the semantic foreground
    // state in that interval; event delivery will still establish the input
    // route and full activation later.
    if (!scenes->active_client_scene())
        scenes->activate_client_scene(sender_pid);
    activate_resolved_application_locked(state, sender_pid, scenes);
}

void record_application_suspension_state(KernelSharedState& state,
    std::uint32_t process_id, bool suspended, SceneCoordinator* scenes)
{
    std::lock_guard lock { state.mach_mutex };
    const auto application = state.processes.find(process_id);
    const auto event_object =
        state.application_event_objects_by_process.find(process_id);
    const auto destination =
        event_object == state.application_event_objects_by_process.end()
            ? 0U
            : event_object->second;
    const auto destination_port = state.mach_port_objects.lookup(destination);
    if (application == state.processes.end() || application->second.exited ||
        !is_application_executable_path(application->second.executable_path) ||
        !destination_port || destination_port->receive_owner != process_id) {
        return;
    }

    if (!suspended) {
        auto* attempt = launch_attempt_locked(state, process_id);
        if (!attempt && flattened_display_scene_available_locked(
                            state, process_id, false)) {
            // launchd-mediated jobs fork and SETEXEC in the child, so there is
            // no SpringBoard-owned posix_spawn call from which to bind a token.
            // The verified lifecycle destination and active display client
            // supply the missing current-process identity without borrowing a
            // historical touch sequence.
            attempt = &begin_launch_attempt_locked(state, process_id, 0U,
                KernelSharedState::ApplicationLaunchOrigin::
                    ForegroundLifecycle);
        }
        if (!attempt) {
            if (scenes)
                scenes->suspend_client_scene(process_id);
            if (state.latest_application_scene_transform &&
                state.latest_application_scene_transform->process_id ==
                    process_id) {
                state.latest_application_scene_transform.reset();
            }
            return;
        }
        if (attempt_is_home_exit_target_locked(state, process_id, *attempt)) {
            state.pending_application_event_object = destination;
            maintain_home_exit_process_locked(state, process_id, scenes);
            return;
        }
        if (attempt_held_by_lock(*attempt)) {
            state.pending_application_event_object = destination;
            if (!resume_held_launch_after_unlock_locked(
                    state, process_id, *attempt)) {
                if (scenes)
                    scenes->suspend_client_scene(process_id);
                state.application_touch_suspended = true;
                state.application_suspension_reason =
                    KernelSharedState::ApplicationSuspensionReason::Lock;
                state.suspended_application_scene_process_id = process_id;
                return;
            }
        }
        if (attempt_interrupted(*attempt)) {
            suspend_interrupted_process_locked(
                state, process_id, interruption_reason(attempt->phase), scenes);
            if (state.latest_application_scene_transform &&
                state.latest_application_scene_transform->process_id ==
                    process_id) {
                state.latest_application_scene_transform.reset();
            }
            return;
        }
        static_cast<void>(resolve_flattened_display_scene_locked(
            state, process_id, *attempt, false, scenes));
        const auto resumes_locked_scene =
            attempt->phase ==
                KernelSharedState::ApplicationLaunchPhase::Suspended &&
            state.application_touch_suspended &&
            state.application_suspension_reason ==
                KernelSharedState::ApplicationSuspensionReason::Lock &&
            state.suspended_application_scene_process_id == process_id;
        if (!attempt_authorized_for_foreground_locked(
                state, process_id, *attempt) &&
            !resumes_locked_scene) {
            if (scenes)
                scenes->suspend_client_scene(process_id);
            if (state.latest_application_scene_transform &&
                state.latest_application_scene_transform->process_id ==
                    process_id) {
                state.latest_application_scene_transform.reset();
            }
            return;
        }
        if (different_foreground_attempt_locked(state, process_id)) {
            if (scenes)
                scenes->suspend_client_scene(process_id);
            if (state.latest_application_scene_transform &&
                state.latest_application_scene_transform->process_id ==
                    process_id) {
                state.latest_application_scene_transform.reset();
            }
            return;
        }
        state.pending_application_event_object = destination;
        std::optional<KernelSharedState::ApplicationTouchTransform> transform;
        if (state.latest_application_scene_transform &&
            state.latest_application_scene_transform->process_id ==
                destination_port->receive_owner) {
            transform = state.latest_application_scene_transform->transform;
        } else if (state.active_application_scene &&
                   state.active_application_scene->process_id ==
                       destination_port->receive_owner &&
                   state.active_application_scene->event_object ==
                       destination) {
            transform = state.active_application_scene->touch_transform;
        } else if (const auto cached = state.application_scene_transforms.find(
                       destination_port->receive_owner);
            cached != state.application_scene_transforms.end()) {
            transform = cached->second;
        }
        const auto semantic_scene_committed =
            scenes &&
            scenes->client_scene(destination_port->receive_owner).has_value();
        // Native resume is foreground intent, not proof that the replacement
        // has become visible. Preserve a different committed foreground until
        // it suspends or this process owns the only committed scene.
        const auto preserves_committed_foreground =
            state.active_application_scene &&
            state.active_application_scene->process_id !=
                destination_port->receive_owner &&
            (scenes ? scenes->client_scene_active(
                          state.active_application_scene->process_id)
                    : state.active_application_scene->touch_transform
                          .has_value()) &&
            state.active_application_event_object ==
                state.active_application_scene->event_object &&
            !state.application_touch_suspended;
        if (preserves_committed_foreground) {
            if (state.latest_application_scene_transform &&
                state.latest_application_scene_transform->process_id ==
                    destination_port->receive_owner) {
                state.latest_application_scene_transform.reset();
            }
            return;
        }
        state.active_application_scene =
            KernelSharedState::ActiveApplicationScene {
                destination_port->receive_owner, destination, transform
            };
        if (scenes ? semantic_scene_committed : transform.has_value()) {
            state.active_application_event_object = destination;
            state.application_touch_suspended = false;
            mark_application_layer_active_locked(state);
            if (scenes)
                scenes->activate_client_scene(destination_port->receive_owner);
        } else {
            state.active_application_event_object = 0;
            state.application_touch_suspended = false;
        }
        state.application_suspension_reason =
            KernelSharedState::ApplicationSuspensionReason::None;
        state.suspended_application_scene_process_id.reset();
        if (state.active_application_event_object != 0U) {
            attempt->phase = KernelSharedState::ApplicationLaunchPhase::Active;
            clear_springboard_enqueued_gesture_locked(state);
            if (held_launch_matches_locked(state, process_id, *attempt))
                state.held_application_launch.reset();
        }
        if (state.latest_application_scene_transform &&
            state.latest_application_scene_transform->process_id ==
                process_id) {
            state.latest_application_scene_transform.reset();
        }
    } else {
        auto* attempt = launch_attempt_locked(state, process_id);
        if (attempt &&
            attempt_is_home_exit_target_locked(state, process_id, *attempt)) {
            maintain_home_exit_process_locked(state, process_id, scenes);
            return;
        }
        if (attempt && attempt_held_by_lock(*attempt)) {
            if (scenes)
                scenes->suspend_client_scene(process_id);
            state.application_touch_suspended = true;
            state.application_suspension_reason =
                KernelSharedState::ApplicationSuspensionReason::Lock;
            state.suspended_application_scene_process_id = process_id;
            return;
        }
        if (attempt && attempt_interrupted(*attempt)) {
            const auto reason = interruption_reason(attempt->phase);
            if (scenes)
                scenes->suspend_client_scene(process_id);
            if (state.latest_application_scene_transform &&
                state.latest_application_scene_transform->process_id ==
                    process_id) {
                state.latest_application_scene_transform.reset();
            }
            std::erase_if(state.application_scene_context_owners,
                [process_id](
                    const auto& owner) { return owner.second == process_id; });

            const auto owns_global_scene =
                state.active_application_scene &&
                state.active_application_scene->process_id == process_id;
            const auto owns_global_route = object_owned_by_process_locked(
                state, state.active_application_event_object, process_id);
            if (reason ==
                KernelSharedState::ApplicationSuspensionReason::Home) {
                // This is an older Home-cancelled background App, not the exact
                // outgoing PID retained by maintain_home_exit_process_locked.
                // Keep its publications suppressed and retire any stale global
                // route.
                if (owns_global_scene)
                    state.active_application_scene.reset();
                if (owns_global_route)
                    state.active_application_event_object = 0;
                if (state.suspended_application_scene_process_id ==
                    process_id) {
                    state.application_touch_suspended = false;
                    state.application_suspension_reason =
                        KernelSharedState::ApplicationSuspensionReason::None;
                    state.suspended_application_scene_process_id.reset();
                }
            } else if (owns_global_scene || owns_global_route) {
                state.application_touch_suspended = true;
                state.application_suspension_reason =
                    KernelSharedState::ApplicationSuspensionReason::Lock;
                state.suspended_application_scene_process_id = process_id;
            }
            if (state.foreground_application_attempt_process_id == process_id)
                state.foreground_application_attempt_process_id.reset();
            return;
        }

        const auto owns_current_scene =
            state.active_application_scene &&
            state.active_application_scene->process_id == process_id;
        const auto owns_current_route = object_owned_by_process_locked(
            state, state.active_application_event_object, process_id);
        if (!owns_current_scene && !owns_current_route) {
            // Lifecycle messages are asynchronous. A previous App may resign
            // after a newer launch or Home exit has already become
            // authoritative; such a callback must not overwrite the singleton
            // suspended PID/reason.
            return;
        }

        const auto prior_suspension_reason =
            state.application_suspension_reason;
        if (scenes) {
            // A completed native suspension transition from a live App is the
            // display-stack
            // handoff boundary. Keep its committed scene presentable until
            // SpringBoard has pushed the replacement display; only Lock retains
            // a suspended scene without an outgoing display-stack transition.
            if (prior_suspension_reason ==
                KernelSharedState::ApplicationSuspensionReason::Lock) {
                scenes->suspend_client_scene(process_id);
            } else {
                scenes->begin_client_scene_exit(process_id);
            }
        }
        state.application_touch_suspended = true;
        state.suspended_application_scene_process_id = process_id;
        const auto preserve_locked_scene =
            prior_suspension_reason ==
                KernelSharedState::ApplicationSuspensionReason::Lock &&
            state.active_application_scene &&
            state.active_application_scene->process_id == process_id;
        const auto preserve_home_exit_scene =
            prior_suspension_reason ==
                KernelSharedState::ApplicationSuspensionReason::Home &&
            state.active_application_scene &&
            state.active_application_scene->process_id == process_id;
        if (preserve_locked_scene) {
            if (attempt) {
                attempt->phase =
                    KernelSharedState::ApplicationLaunchPhase::Suspended;
            }
            state.application_suspension_reason =
                KernelSharedState::ApplicationSuspensionReason::Lock;
            return;
        }
        if (preserve_home_exit_scene) {
            state.application_suspension_reason =
                KernelSharedState::ApplicationSuspensionReason::Home;
            if (state.foreground_application_attempt_process_id == process_id)
                state.foreground_application_attempt_process_id.reset();
            return;
        }
        // Preserve one exact outgoing identity while SpringBoard performs a
        // normal App-to-App handoff. It may deliver the replacement spawn after
        // this callback has already retired the active input route.
        state.pending_application_handoff_process_id = process_id;
        if (attempt) {
            attempt->phase =
                KernelSharedState::ApplicationLaunchPhase::Suspended;
        }
        // A normally active App remains the source of SpringBoard's shrinking
        // exit snapshot after willResignActive. Suppression is reserved for an
        // interrupted launch above; hiding this surface here turns the
        // otherwise valid Home animation black.
        state.application_suspension_reason =
            KernelSharedState::ApplicationSuspensionReason::None;
        if (state.latest_application_scene_transform &&
            state.latest_application_scene_transform->process_id ==
                process_id) {
            state.latest_application_scene_transform.reset();
        }
        for (auto context = state.application_scene_context_owners.begin();
            context != state.application_scene_context_owners.end();) {
            if (context->second == process_id) {
                context = state.application_scene_context_owners.erase(context);
            } else {
                ++context;
            }
        }
        if (state.active_application_scene &&
            state.active_application_scene->process_id == process_id) {
            state.active_application_scene.reset();
        }
        if (object_owned_by_process_locked(
                state, state.active_application_event_object, process_id)) {
            state.active_application_event_object = 0;
        }
        if (state.foreground_application_attempt_process_id == process_id)
            state.foreground_application_attempt_process_id.reset();
        state.application_touch_suspended = false;
        state.suspended_application_scene_process_id.reset();
    }
}

} // namespace shade::graphics_services_input
