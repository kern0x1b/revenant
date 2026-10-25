// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "kernel/kernel_shared_state.hpp"

#include "crypto/key_store.hpp"
#include "foundation/snapshot_io.hpp"

#include <array>
#include <atomic>
#include <bit>
#include <filesystem>
#include <map>
#include <set>
#include <string>

namespace emulator {

namespace {

template <typename T>
void load_atomic(snapshot::Reader& in, std::atomic<T>& value)
{
    T loaded { };
    snapshot::load(in, loaded);
    value.store(loaded);
}

void save_float(snapshot::Writer& out, float value)
{
    snapshot::save(out, std::bit_cast<std::uint32_t>(value));
}

void load_float(snapshot::Reader& in, float& value)
{
    std::uint32_t bits { };
    snapshot::load(in, bits);
    value = std::bit_cast<float>(bits);
}

void save_kernel_event(
    snapshot::Writer& out, const KernelSharedState::KernelEvent& event)
{
    snapshot::save(out, event.identifier);
    snapshot::save(out, event.vendor);
    snapshot::save(out, event.event_class);
    snapshot::save(out, event.event_subclass);
    snapshot::save(out, event.event_code);
    snapshot::save(out, event.bytes);
}

KernelSharedState::KernelEvent load_kernel_event(snapshot::Reader& in)
{
    KernelSharedState::KernelEvent event;
    snapshot::load(in, event.identifier);
    snapshot::load(in, event.vendor);
    snapshot::load(in, event.event_class);
    snapshot::load(in, event.event_subclass);
    snapshot::load(in, event.event_code);
    snapshot::load(in, event.bytes);
    return event;
}

void save_kevent_state(
    snapshot::Writer& out, const KernelSharedState::ProcessKeventState& state)
{
    snapshot::save(out, state.exec_generation);
    snapshot::save(out, state.exit_generation);
    snapshot::save(out, state.wait_status);
}

KernelSharedState::ProcessKeventState load_kevent_state(snapshot::Reader& in)
{
    KernelSharedState::ProcessKeventState state;
    snapshot::load(in, state.exec_generation);
    snapshot::load(in, state.exit_generation);
    snapshot::load(in, state.wait_status);
    return state;
}

void save_display_geometry(snapshot::Writer& out, const DisplayGeometry& geometry)
{
    snapshot::save(out, geometry.width);
    snapshot::save(out, geometry.height);
}

DisplayGeometry load_display_geometry(snapshot::Reader& in)
{
    DisplayGeometry geometry;
    snapshot::load(in, geometry.width);
    snapshot::load(in, geometry.height);
    return geometry;
}

void save_application_display(
    snapshot::Writer& out, const ApplicationDisplay& display)
{
    snapshot::save(out, display.kind);
    save_display_geometry(out, display.logical_geometry);
}

ApplicationDisplay load_application_display(snapshot::Reader& in)
{
    ApplicationDisplay display;
    snapshot::load(in, display.kind);
    display.logical_geometry = load_display_geometry(in);
    return display;
}

void save_core_animation_abi(
    snapshot::Writer& out, const CoreAnimationRemoteAbi& abi)
{
    snapshot::save(out, std::string { abi.name });
    snapshot::save(out, abi.inline_transaction_message);
    snapshot::save(out, abi.out_of_line_transaction_message);
    snapshot::save(out, abi.render_server_port_rendezvous);
}

CoreAnimationRemoteAbi load_core_animation_abi(snapshot::Reader& in)
{
    std::string name;
    snapshot::load(in, name);
    CoreAnimationRemoteAbi abi;
    if (name == core_animation_transaction_v1_name) {
        abi.name = core_animation_transaction_v1_name;
    } else if (name == core_animation_render_server_v1_name) {
        abi.name = core_animation_render_server_v1_name;
    } else {
        throw snapshot::FormatError {
            "snapshot names an unknown Core Animation ABI"
        };
    }
    snapshot::load(in, abi.inline_transaction_message);
    snapshot::load(in, abi.out_of_line_transaction_message);
    snapshot::load(in, abi.render_server_port_rendezvous);
    return abi;
}

void save_process_record(
    snapshot::Writer& out, const KernelSharedState::ProcessRecord& record)
{
    snapshot::save(out, record.parent_pid);
    snapshot::save(out, record.process_group);
    snapshot::save(out, record.uid);
    snapshot::save(out, record.effective_uid);
    snapshot::save(out, record.gid);
    snapshot::save(out, record.effective_gid);
    snapshot::save(out, record.nice_value);
    snapshot::save(out, record.exit_status);
    snapshot::save(out, record.termination_signal);
    snapshot::save(out, record.exited);
    snapshot::save(out, record.pid_suspended);
    snapshot::save(out, record.signal_stopped);
    snapshot::save(out, record.command);
    snapshot::save(out, record.executable_path);
    snapshot::save(out, record.arguments);
    snapshot::save(out, record.environment);
    snapshot::save(out, record.graphics_input_abi);
    snapshot::save(out, record.code_signature_entitlements);
    snapshot::save(out, record.core_animation_remote_abi.has_value());
    if (record.core_animation_remote_abi)
        save_core_animation_abi(out, *record.core_animation_remote_abi);
    snapshot::save(out, record.display_orientation);
    save_application_display(out, record.application_display);
    snapshot::save(out, record.incarnation);
    snapshot::save(out, record.parent_incarnation);
    snapshot::save(out, record.start_wall_nanoseconds);
    snapshot::save(out, record.executable_uuid);
    snapshot::save(out, record.audit_identity_version);
    snapshot::save(out, record.memory_status.priority);
    snapshot::save(out, record.memory_status.user_data);
    snapshot::save(out, record.importance_donor);
    snapshot::save(out, record.dyld_all_image_info_address);
    snapshot::save(out, record.dyld_all_image_info_size);
}

KernelSharedState::ProcessRecord load_process_record(snapshot::Reader& in)
{
    KernelSharedState::ProcessRecord record;
    snapshot::load(in, record.parent_pid);
    snapshot::load(in, record.process_group);
    snapshot::load(in, record.uid);
    snapshot::load(in, record.effective_uid);
    snapshot::load(in, record.gid);
    snapshot::load(in, record.effective_gid);
    snapshot::load(in, record.nice_value);
    snapshot::load(in, record.exit_status);
    snapshot::load(in, record.termination_signal);
    snapshot::load(in, record.exited);
    snapshot::load(in, record.pid_suspended);
    snapshot::load(in, record.signal_stopped);
    snapshot::load(in, record.command);
    snapshot::load(in, record.executable_path);
    snapshot::load(in, record.arguments);
    snapshot::load(in, record.environment);
    snapshot::load(in, record.graphics_input_abi);
    snapshot::load(in, record.code_signature_entitlements);
    bool has_core_animation_abi { };
    snapshot::load(in, has_core_animation_abi);
    if (has_core_animation_abi)
        record.core_animation_remote_abi = load_core_animation_abi(in);
    snapshot::load(in, record.display_orientation);
    record.application_display = load_application_display(in);
    snapshot::load(in, record.incarnation);
    snapshot::load(in, record.parent_incarnation);
    snapshot::load(in, record.start_wall_nanoseconds);
    snapshot::load(in, record.executable_uuid);
    snapshot::load(in, record.audit_identity_version);
    snapshot::load(in, record.memory_status.priority);
    snapshot::load(in, record.memory_status.user_data);
    snapshot::load(in, record.importance_donor);
    snapshot::load(in, record.dyld_all_image_info_address);
    snapshot::load(in, record.dyld_all_image_info_size);
    return record;
}

}

void KernelSharedState::save_scalar_state(snapshot::Writer& out) const
{
    if (host_display_hardware_wake_pending)
        throw snapshot::RefusedError { "kss.host_display_hardware_wake_pending" };
    snapshot::save(out, hostname);
    snapshot::save(out, desired_vnodes);
    snapshot::save(out, next_kernel_event_identifier);
    snapshot::save(out, next_route_message_identifier);
    snapshot::save(out, next_route_socket_identifier);
    snapshot::save(out, next_mach_object);
    snapshot::save(out, next_mach_wait_queue_sequence);
    snapshot::save(out, mach_queue_generation.load());
    snapshot::save(out, kernel_event_generation.load());
    snapshot::save(out, shared_timer_deadline_cache_generation);
    snapshot::save(out, shared_timer_deadline_cache);
    snapshot::save(out, shared_timer_deadline_cache_valid);
    snapshot::save(out, io_event_generation.load());
    snapshot::save(out, next_graphics_input_sequence);
    snapshot::save(out, next_application_launch_token);
    snapshot::save(out, next_process_incarnation);
    snapshot::save(out, next_audit_identity_version);
    snapshot::save(out, next_foreground_transition_generation);
    snapshot::save(out, next_foreground_layer_sequence);
    snapshot::save(out, next_clock_alarm);
    snapshot::save(out, next_keybag_handle);
    snapshot::save(out, wifi_service_available);
    snapshot::save(out, next_socket_pair);
    snapshot::save(out, next_shared_memory_object);
    snapshot::save(out, apple_key_store_service);
    snapshot::save(out, baseband_service);
    snapshot::save(out, camera_sensor_service);
    snapshot::save(out, default_processor_set_control_object);
    snapshot::save(out, default_processor_set_name_object);
    snapshot::save(out, effaceable_storage_service);
    snapshot::save(out, external_framebuffer_service);
    snapshot::save(out, jpeg_accelerator_service);
    snapshot::save(out, keybag_device_tree_defaults_service);
    snapshot::save(out, keybag_device_tree_options_service);
    snapshot::save(out, mobile_file_integrity_service);
    snapshot::save(out, mobile_framebuffer_service);
    snapshot::save(out, multitouch_hid_service);
    snapshot::save(out, serial_multiplexer_service);
    snapshot::save(out, wifi_interface_service);
    snapshot::save(out, wifi_service);
    snapshot::save(out, active_application_event_object);
    snapshot::save(out, pending_application_event_object);
    snapshot::save(out, springboard_active_touch_begin_sequence);
    snapshot::save(out, springboard_enqueued_active_touch_begin_sequence);
    snapshot::save(out, springboard_enqueued_last_touch_begin_sequence);
    snapshot::save(out, springboard_enqueued_last_touch_end_sequence);
    save_float(out, springboard_enqueued_last_touch_end_x);
    save_float(out, springboard_enqueued_last_touch_end_y);
    snapshot::save(out, springboard_last_consumed_touch_sequence);
    snapshot::save(out, springboard_last_touch_begin_sequence);
    snapshot::save(out, springboard_pending_launch_touch_sequence);
    snapshot::save(out, springboard_unlock_touch_active);
    snapshot::save(out, springboard_unlock_touch_begin_sequence);
    snapshot::save(out, springboard_unlock_touch_end_sequence);
    save_float(out, springboard_unlock_touch_end_x);
    save_float(out, springboard_unlock_touch_end_y);
    snapshot::save(out, springboard_unlock_touch_pending);
    save_float(out, springboard_unlock_touch_start_x);
    save_float(out, springboard_unlock_touch_start_y);
    snapshot::save(out, springboard_lock_screen_active);
    snapshot::save(out, active_application_layer_sequence);
    snapshot::save(out, last_home_launch_barrier_sequence);
    snapshot::save(out, display_vsync_last_delivered_deadline);
    snapshot::save(out, display_vsync_pulse_count);
    snapshot::save(out, host_display_current_lock_down_sequence);
    snapshot::save(out, host_display_wake_after_lock_sequence);
    snapshot::save(out, host_display_wake_power_on_acknowledged);
    snapshot::save(out, iokit_display_vsync_registration_generation);
    snapshot::save(out, system_keybag_handle);
    snapshot::save(out, application_touch_suspended);
    snapshot::save(out, requested_display_power_state);
    snapshot::save(out, suspended_application_scene_process_id);
    snapshot::save(out, foreground_application_attempt_process_id);
    snapshot::save(out, pending_application_handoff_process_id);
    snapshot::save(out, interrupted_home_exit_lock_sequence);
    snapshot::save(out, security_level.load());
    snapshot::save(out, task_for_pid_groups);
}

void KernelSharedState::load_scalar_state(snapshot::Reader& in)
{
    snapshot::load(in, hostname);
    snapshot::load(in, desired_vnodes);
    snapshot::load(in, next_kernel_event_identifier);
    snapshot::load(in, next_route_message_identifier);
    snapshot::load(in, next_route_socket_identifier);
    snapshot::load(in, next_mach_object);
    snapshot::load(in, next_mach_wait_queue_sequence);
    load_atomic(in, mach_queue_generation);
    load_atomic(in, kernel_event_generation);
    snapshot::load(in, shared_timer_deadline_cache_generation);
    snapshot::load(in, shared_timer_deadline_cache);
    snapshot::load(in, shared_timer_deadline_cache_valid);
    load_atomic(in, io_event_generation);
    snapshot::load(in, next_graphics_input_sequence);
    snapshot::load(in, next_application_launch_token);
    snapshot::load(in, next_process_incarnation);
    snapshot::load(in, next_audit_identity_version);
    snapshot::load(in, next_foreground_transition_generation);
    snapshot::load(in, next_foreground_layer_sequence);
    snapshot::load(in, next_clock_alarm);
    snapshot::load(in, next_keybag_handle);
    snapshot::load(in, wifi_service_available);
    snapshot::load(in, next_socket_pair);
    snapshot::load(in, next_shared_memory_object);
    snapshot::load(in, apple_key_store_service);
    snapshot::load(in, baseband_service);
    snapshot::load(in, camera_sensor_service);
    snapshot::load(in, default_processor_set_control_object);
    snapshot::load(in, default_processor_set_name_object);
    snapshot::load(in, effaceable_storage_service);
    snapshot::load(in, external_framebuffer_service);
    snapshot::load(in, jpeg_accelerator_service);
    snapshot::load(in, keybag_device_tree_defaults_service);
    snapshot::load(in, keybag_device_tree_options_service);
    snapshot::load(in, mobile_file_integrity_service);
    snapshot::load(in, mobile_framebuffer_service);
    snapshot::load(in, multitouch_hid_service);
    snapshot::load(in, serial_multiplexer_service);
    snapshot::load(in, wifi_interface_service);
    snapshot::load(in, wifi_service);
    snapshot::load(in, active_application_event_object);
    snapshot::load(in, pending_application_event_object);
    snapshot::load(in, springboard_active_touch_begin_sequence);
    snapshot::load(in, springboard_enqueued_active_touch_begin_sequence);
    snapshot::load(in, springboard_enqueued_last_touch_begin_sequence);
    snapshot::load(in, springboard_enqueued_last_touch_end_sequence);
    load_float(in, springboard_enqueued_last_touch_end_x);
    load_float(in, springboard_enqueued_last_touch_end_y);
    snapshot::load(in, springboard_last_consumed_touch_sequence);
    snapshot::load(in, springboard_last_touch_begin_sequence);
    snapshot::load(in, springboard_pending_launch_touch_sequence);
    snapshot::load(in, springboard_unlock_touch_active);
    snapshot::load(in, springboard_unlock_touch_begin_sequence);
    snapshot::load(in, springboard_unlock_touch_end_sequence);
    load_float(in, springboard_unlock_touch_end_x);
    load_float(in, springboard_unlock_touch_end_y);
    snapshot::load(in, springboard_unlock_touch_pending);
    load_float(in, springboard_unlock_touch_start_x);
    load_float(in, springboard_unlock_touch_start_y);
    snapshot::load(in, springboard_lock_screen_active);
    snapshot::load(in, active_application_layer_sequence);
    snapshot::load(in, last_home_launch_barrier_sequence);
    snapshot::load(in, display_vsync_last_delivered_deadline);
    snapshot::load(in, display_vsync_pulse_count);
    snapshot::load(in, host_display_current_lock_down_sequence);
    snapshot::load(in, host_display_wake_after_lock_sequence);
    snapshot::load(in, host_display_wake_power_on_acknowledged);
    snapshot::load(in, iokit_display_vsync_registration_generation);
    snapshot::load(in, system_keybag_handle);
    snapshot::load(in, application_touch_suspended);
    snapshot::load(in, requested_display_power_state);
    snapshot::load(in, suspended_application_scene_process_id);
    snapshot::load(in, foreground_application_attempt_process_id);
    snapshot::load(in, pending_application_handoff_process_id);
    snapshot::load(in, interrupted_home_exit_lock_sequence);
    load_atomic(in, security_level);
    snapshot::load(in, task_for_pid_groups);
}

void KernelSharedState::save_port_and_event_tables(snapshot::Writer& out) const
{
    snapshot::save(out, mach_kernel_send_rights);
    snapshot::save(out, task_port_pids);
    snapshot::save(out, static_cast<std::uint64_t>(kernel_events.size()));
    for (const auto& event : kernel_events)
        save_kernel_event(out, event);
    snapshot::save(
        out, static_cast<std::uint64_t>(process_kevent_states.size()));
    for (const auto& [pid, state] : process_kevent_states) {
        snapshot::save(out, pid);
        save_kevent_state(out, state);
    }
}

void KernelSharedState::load_port_and_event_tables(snapshot::Reader& in)
{
    snapshot::load(in, mach_kernel_send_rights);
    snapshot::load(in, task_port_pids);
    std::uint64_t event_count { };
    snapshot::load(in, event_count);
    kernel_events.clear();
    for (std::uint64_t index = 0; index < event_count; ++index)
        kernel_events.push_back(load_kernel_event(in));
    std::uint64_t kevent_count { };
    snapshot::load(in, kevent_count);
    process_kevent_states.clear();
    for (std::uint64_t index = 0; index < kevent_count; ++index) {
        std::uint32_t pid { };
        snapshot::load(in, pid);
        if (!process_kevent_states.emplace(pid, load_kevent_state(in)).second)
            throw snapshot::FormatError { "snapshot repeats a kevent state" };
    }
}

void KernelSharedState::save_process_table(snapshot::Writer& out) const
{
    snapshot::save(out, static_cast<std::uint64_t>(processes.size()));
    for (const auto& [pid, record] : processes) {
        snapshot::save(out, pid);
        save_process_record(out, record);
    }
}

void KernelSharedState::load_process_table(snapshot::Reader& in)
{
    std::uint64_t process_count { };
    snapshot::load(in, process_count);
    processes.clear();
    for (std::uint64_t index = 0; index < process_count; ++index) {
        std::uint32_t pid { };
        snapshot::load(in, pid);
        if (!processes.emplace(pid, load_process_record(in)).second)
            throw snapshot::FormatError { "snapshot repeats a process" };
    }
}

void KernelSharedState::save_service_tables(snapshot::Writer& out) const
{
    snapshot::save(out, bootstrap_checked_in_services);
    snapshot::save(out, bootstrap_service_generations);
    snapshot::save(out, bootstrap_service_objects);
    snapshot::save(out, camera_accelerator_services);
    snapshot::save(out, camera_sensor_variables);
    snapshot::save(out, ioaudio2_services);
    snapshot::save(out, iokit_iterators);
    snapshot::save(out, host_display_pending_lock_power_off_sequences);
    snapshot::save(out, nvram_serialized);
    snapshot::save(out, package_extensions);
    snapshot::save(out, posix_named_semaphore_objects);
    snapshot::save(out, unix_socket_nodes);
    snapshot::save(out, application_event_objects_by_process);
    snapshot::save(out, audit_session_port_objects);
    snapshot::save(out, mach_inflight_send_rights);
    snapshot::save(out, mach_port_contexts);
    snapshot::save(out, mach_port_sets);
    snapshot::save(out, mach_ports_being_removed);
    snapshot::save(out, mach_registered_ports);
    snapshot::save(out, mach_send_possible_armed_destinations);
    snapshot::save(out, task_name_port_pids);
    snapshot::save(out, semaphore_wakeups);
    snapshot::save(out, semaphore_terminations);
    snapshot::save(out, surface_transport_port_surfaces);
    snapshot::save(out, surface_transport_surface_ports);
    std::map<std::string, std::string> shared_memory_paths;
    for (const auto& [name, path] : shared_memory_objects)
        shared_memory_paths.emplace(name, path.string());
    snapshot::save(out, shared_memory_paths);
    std::set<std::string> volatile_paths;
    for (const auto& path : volatile_shared_memory_backings)
        volatile_paths.insert(path.string());
    snapshot::save(out, volatile_paths);
}

void KernelSharedState::load_service_tables(snapshot::Reader& in)
{
    snapshot::load(in, bootstrap_checked_in_services);
    snapshot::load(in, bootstrap_service_generations);
    snapshot::load(in, bootstrap_service_objects);
    snapshot::load(in, camera_accelerator_services);
    snapshot::load(in, camera_sensor_variables);
    snapshot::load(in, ioaudio2_services);
    snapshot::load(in, iokit_iterators);
    snapshot::load(in, host_display_pending_lock_power_off_sequences);
    snapshot::load(in, nvram_serialized);
    snapshot::load(in, package_extensions);
    snapshot::load(in, posix_named_semaphore_objects);
    snapshot::load(in, unix_socket_nodes);
    snapshot::load(in, application_event_objects_by_process);
    snapshot::load(in, audit_session_port_objects);
    snapshot::load(in, mach_inflight_send_rights);
    snapshot::load(in, mach_port_contexts);
    snapshot::load(in, mach_port_sets);
    snapshot::load(in, mach_ports_being_removed);
    snapshot::load(in, mach_registered_ports);
    snapshot::load(in, mach_send_possible_armed_destinations);
    snapshot::load(in, task_name_port_pids);
    snapshot::load(in, semaphore_wakeups);
    snapshot::load(in, semaphore_terminations);
    snapshot::load(in, surface_transport_port_surfaces);
    snapshot::load(in, surface_transport_surface_ports);
    std::map<std::string, std::string> shared_memory_paths;
    snapshot::load(in, shared_memory_paths);
    shared_memory_objects.clear();
    for (const auto& [name, path] : shared_memory_paths)
        shared_memory_objects.emplace(name, std::filesystem::path { path });
    std::set<std::string> volatile_paths;
    snapshot::load(in, volatile_paths);
    volatile_shared_memory_backings.clear();
    for (const auto& path : volatile_paths)
        volatile_shared_memory_backings.insert(std::filesystem::path { path });
}

void KernelSharedState::save_key_store_identity(snapshot::Writer& out) const
{
    snapshot::save(out, key_store != nullptr);
    if (!key_store)
        return;
    const auto identity = key_store->identity();
    if (!identity)
        throw snapshot::RefusedError { "kss.key_store" };
    snapshot::save(out, *identity);
}

void KernelSharedState::load_key_store_identity(snapshot::Reader& in)
{
    bool present { };
    snapshot::load(in, present);
    if (!present) {
        if (key_store)
            throw snapshot::FormatError {
                "snapshot has no key store but the wiring does"
            };
        return;
    }
    std::array<std::byte, 32> saved { };
    snapshot::load(in, saved);
    if (!key_store)
        throw snapshot::FormatError {
            "snapshot has a key store but the wiring does not"
        };
    if (key_store->identity() != saved)
        throw snapshot::FormatError {
            "snapshot key store differs from the wiring"
        };
}

}
