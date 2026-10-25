// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "kernel/kernel.hpp"

#include "foundation/address_space.hpp"
#include "foundation/snapshot_io.hpp"
#include "foundation/virtual_clock.hpp"

#include <string>
#include <string_view>
#include <vector>

namespace emulator {

struct CompatibilityKernelSnapshot {
    static std::vector<std::string> populated_members(
        const CompatibilityKernel& kernel);
    static std::vector<std::string> populated_memory(
        const AddressSpace& memory);
};

namespace {

template <typename T>
void note(std::vector<std::string>& out, std::string_view name, const T& value)
{
    if (!snapshot::is_default(value))
        out.emplace_back(name);
}

}

std::vector<std::string> CompatibilityKernelSnapshot::populated_members(
    const CompatibilityKernel& kernel)
{
    std::vector<std::string> out;
    note(out, "ck.dyld_shared_cache_attempted_", kernel.dyld_shared_cache_attempted_);
    note(out, "ck.dyld_shared_cache_path_", kernel.dyld_shared_cache_path_);
    note(out, "ck.guest_working_directory_", kernel.guest_working_directory_);
    note(out, "ck.process_image_", kernel.process_image_);
    note(out, "ck.file_descriptors_", kernel.file_descriptors_);
    note(out, "ck.file_offsets_", kernel.file_offsets_);
    note(out, "ck.file_status_flags_", kernel.file_status_flags_);
    note(out, "ck.descriptor_flags_", kernel.descriptor_flags_);
    note(out, "ck.descriptor_guards_", kernel.descriptor_guards_);
    note(out, "ck.aio_completions_", kernel.aio_completions_);
    note(out, "ck.virtual_descriptors_", kernel.virtual_descriptors_);
    note(out, "ck.posix_semaphore_descriptors_", kernel.posix_semaphore_descriptors_);
    note(out, "ck.host_sockets_", kernel.host_sockets_);
    note(out, "ck.scheduled_wifi_driver_events_", kernel.scheduled_wifi_driver_events_);
    note(out, "ck.bound_socket_names_", kernel.bound_socket_names_);
    note(out, "ck.listening_sockets_", kernel.listening_sockets_);
    note(out, "ck.duplicated_descriptors_", kernel.duplicated_descriptors_);
    note(out, "ck.system_event_filters_", kernel.system_event_filters_);
    note(out, "ck.apple80211_scan_delivered_", kernel.apple80211_scan_delivered_);
    note(out, "ck.system_event_next_identifiers_", kernel.system_event_next_identifiers_);
    note(out, "ck.socket_pair_endpoints_", kernel.socket_pair_endpoints_);
    note(out, "ck.kqueues_", kernel.kqueues_);
    note(out, "ck.thread_ports_", kernel.thread_ports_);
    note(out, "ck.vm_purgable_states_", kernel.vm_purgable_states_);
    note(out, "ck.disabled_thread_signals_", kernel.disabled_thread_signals_);
    note(out, "ck.signal_actions_", kernel.signal_actions_);
    note(out, "ck.thread_signal_masks_", kernel.thread_signal_masks_);
    note(out, "ck.pending_signals_", kernel.pending_signals_);
    note(out, "ck.thread_pending_signals_", kernel.thread_pending_signals_);
    note(out, "ck.alternate_signal_stacks_", kernel.alternate_signal_stacks_);
    note(out, "ck.random_state_", kernel.random_state_);
    note(out, "ck.scheduler_yields_", kernel.scheduler_yields_);
    note(out, "ck.scheduler_handoffs_", kernel.scheduler_handoffs_);
    note(out, "ck.pending_waits_", kernel.pending_waits_);
    note(out, "ck.pending_mach_receives_", kernel.pending_mach_receives_);
    note(out, "ck.last_delivered_graphics_inputs_", kernel.last_delivered_graphics_inputs_);
    note(out, "ck.pending_kevents_", kernel.pending_kevents_);
    note(out, "ck.pending_recvmsgs_", kernel.pending_recvmsgs_);
    note(out, "ck.pending_socket_reads_", kernel.pending_socket_reads_);
    note(out, "ck.pending_host_connects_", kernel.pending_host_connects_);
    note(out, "ck.pending_host_accepts_", kernel.pending_host_accepts_);
    note(out, "ck.pending_host_writes_", kernel.pending_host_writes_);
    note(out, "ck.pending_baseband_writes_", kernel.pending_baseband_writes_);
    note(out, "ck.pending_unix_accepts_", kernel.pending_unix_accepts_);
    note(out, "ck.pending_flocks_", kernel.pending_flocks_);
    note(out, "ck.pending_record_locks_", kernel.pending_record_locks_);
    note(out, "ck.pending_polls_", kernel.pending_polls_);
    note(out, "ck.pending_selects_", kernel.pending_selects_);
    note(out, "ck.pending_timers_", kernel.pending_timers_);
    note(out, "ck.pending_semaphore_waits_", kernel.pending_semaphore_waits_);
    note(out, "ck.pending_psynch_waits_", kernel.pending_psynch_waits_);
    note(out, "ck.pending_signal_suspends_", kernel.pending_signal_suspends_);
    note(out, "ck.pending_io_poll_cache_", kernel.pending_io_poll_cache_);
    note(out, "ck.pending_event_processors_", kernel.pending_event_processors_);
    note(out, "ck.pending_event_topology_generation_", kernel.pending_event_topology_generation_);
    note(out, "ck.pending_event_poll_topology_generation_", kernel.pending_event_poll_topology_generation_);
    note(out, "ck.pending_event_poll_io_generation_", kernel.pending_event_poll_io_generation_);
    note(out, "ck.pending_event_poll_mach_generation_", kernel.pending_event_poll_mach_generation_);
    note(out, "ck.pending_event_poll_deadline_", kernel.pending_event_poll_deadline_);
    note(out, "ck.pending_event_poll_observed_", kernel.pending_event_poll_observed_);
    note(out, "ck.local_timer_deadline_cache_", kernel.local_timer_deadline_cache_);
    note(out, "ck.local_timer_deadline_cache_valid_", kernel.local_timer_deadline_cache_valid_);
    note(out, "ck.timer_trace_count_", kernel.timer_trace_count_);
    note(out, "ck.port_status_trace_count_", kernel.port_status_trace_count_);
    note(out, "ck.thread_trace_count_", kernel.thread_trace_count_);
    note(out, "ck.mapping_trace_count_", kernel.mapping_trace_count_);
    note(out, "ck.socket_payload_trace_count_", kernel.socket_payload_trace_count_);
    note(out, "ck.semaphore_wait_trace_count_", kernel.semaphore_wait_trace_count_);
    note(out, "ck.psynch_trace_count_", kernel.psynch_trace_count_);
    note(out, "ck.baseband_io_trace_count_", kernel.baseband_io_trace_count_);
    note(out, "ck.next_display_scanout_deadline_", kernel.next_display_scanout_deadline_);
    note(out, "ck.virtual_processor_count_", kernel.virtual_processor_count_);
    note(out, "ck.next_load_average_sample_", kernel.next_load_average_sample_);

    const auto& shared = *kernel.shared_state_;
    note(out, "kss.security_level", shared.security_level);
    note(out, "kss.hostname", shared.hostname);
    note(out, "kss.task_for_pid_groups", shared.task_for_pid_groups);
    note(out, "kss.desired_vnodes", shared.desired_vnodes);
    note(out, "kss.next_kernel_event_identifier", shared.next_kernel_event_identifier);
    note(out, "kss.kernel_events", shared.kernel_events);
    note(out, "kss.next_route_message_identifier", shared.next_route_message_identifier);
    note(out, "kss.next_route_socket_identifier", shared.next_route_socket_identifier);
    note(out, "kss.route_socket_messages", shared.route_socket_messages);
    note(out, "kss.nvram_serialized", shared.nvram_serialized);
    note(out, "kss.next_mach_object", shared.next_mach_object);
    note(out, "kss.default_processor_set_name_object", shared.default_processor_set_name_object);
    note(out, "kss.default_processor_set_control_object", shared.default_processor_set_control_object);
    note(out, "kss.mach_port_contexts", shared.mach_port_contexts);
    note(out, "kss.audit_session_port_objects", shared.audit_session_port_objects);
    note(out, "kss.mach_registered_ports", shared.mach_registered_ports);
    note(out, "kss.mach_inflight_send_rights", shared.mach_inflight_send_rights);
    note(out, "kss.mach_kernel_send_rights", shared.mach_kernel_send_rights);
    note(out, "kss.mach_ports_being_removed", shared.mach_ports_being_removed);
    note(out, "kss.mach_port_sets", shared.mach_port_sets);
    note(out, "kss.next_mach_wait_queue_sequence", shared.next_mach_wait_queue_sequence);
    note(out, "kss.task_port_pids", shared.task_port_pids);
    note(out, "kss.task_name_port_pids", shared.task_name_port_pids);
    note(out, "kss.thread_working_directories", shared.thread_working_directories);
    note(out, "kss.task_exception_actions", shared.task_exception_actions);
    note(out, "kss.mach_queues", shared.mach_queues);
    note(out, "kss.mach_queue_generation", shared.mach_queue_generation);
    note(out, "kss.kernel_event_generation", shared.kernel_event_generation);
    note(out, "kss.shared_timer_deadline_cache_generation", shared.shared_timer_deadline_cache_generation);
    note(out, "kss.shared_timer_deadline_cache", shared.shared_timer_deadline_cache);
    note(out, "kss.shared_timer_deadline_cache_valid", shared.shared_timer_deadline_cache_valid);
    note(out, "kss.io_event_generation", shared.io_event_generation);
    note(out, "kss.bootstrap_service_objects", shared.bootstrap_service_objects);
    note(out, "kss.bootstrap_service_generations", shared.bootstrap_service_generations);
    note(out, "kss.bootstrap_checked_in_services", shared.bootstrap_checked_in_services);
    note(out, "kss.launchd_job_catalog", shared.launchd_job_catalog);
    note(out, "kss.pending_application_event_object", shared.pending_application_event_object);
    note(out, "kss.active_application_event_object", shared.active_application_event_object);
    note(out, "kss.application_event_objects_by_process", shared.application_event_objects_by_process);
    note(out, "kss.application_touch_suspended", shared.application_touch_suspended);
    note(out, "kss.suspended_application_scene_process_id", shared.suspended_application_scene_process_id);
    note(out, "kss.next_graphics_input_sequence", shared.next_graphics_input_sequence);
    note(out, "kss.active_graphics_touch_route", shared.active_graphics_touch_route);
    note(out, "kss.springboard_last_consumed_touch_sequence", shared.springboard_last_consumed_touch_sequence);
    note(out, "kss.springboard_active_touch_begin_sequence", shared.springboard_active_touch_begin_sequence);
    note(out, "kss.springboard_last_touch_begin_sequence", shared.springboard_last_touch_begin_sequence);
    note(out, "kss.springboard_pending_launch_touch_sequence", shared.springboard_pending_launch_touch_sequence);
    note(out, "kss.springboard_enqueued_active_touch_begin_sequence", shared.springboard_enqueued_active_touch_begin_sequence);
    note(out, "kss.springboard_enqueued_last_touch_begin_sequence", shared.springboard_enqueued_last_touch_begin_sequence);
    note(out, "kss.springboard_enqueued_last_touch_end_sequence", shared.springboard_enqueued_last_touch_end_sequence);
    note(out, "kss.springboard_enqueued_last_touch_end_x", shared.springboard_enqueued_last_touch_end_x);
    note(out, "kss.springboard_enqueued_last_touch_end_y", shared.springboard_enqueued_last_touch_end_y);
    note(out, "kss.springboard_unlock_touch_pending", shared.springboard_unlock_touch_pending);
    note(out, "kss.springboard_unlock_touch_active", shared.springboard_unlock_touch_active);
    note(out, "kss.springboard_lock_screen_active", shared.springboard_lock_screen_active);
    note(out, "kss.springboard_unlock_touch_begin_sequence", shared.springboard_unlock_touch_begin_sequence);
    note(out, "kss.springboard_unlock_touch_end_sequence", shared.springboard_unlock_touch_end_sequence);
    note(out, "kss.springboard_unlock_touch_start_x", shared.springboard_unlock_touch_start_x);
    note(out, "kss.springboard_unlock_touch_start_y", shared.springboard_unlock_touch_start_y);
    note(out, "kss.springboard_unlock_touch_end_x", shared.springboard_unlock_touch_end_x);
    note(out, "kss.springboard_unlock_touch_end_y", shared.springboard_unlock_touch_end_y);
    note(out, "kss.next_application_launch_token", shared.next_application_launch_token);
    note(out, "kss.next_process_incarnation", shared.next_process_incarnation);
    note(out, "kss.next_audit_identity_version", shared.next_audit_identity_version);
    note(out, "kss.next_foreground_transition_generation", shared.next_foreground_transition_generation);
    note(out, "kss.foreground_transition_snapshot", shared.foreground_transition_snapshot);
    note(out, "kss.application_launch_barrier", shared.application_launch_barrier);
    note(out, "kss.last_home_launch_barrier_sequence", shared.last_home_launch_barrier_sequence);
    note(out, "kss.foreground_application_attempt_process_id", shared.foreground_application_attempt_process_id);
    note(out, "kss.held_application_launch", shared.held_application_launch);
    note(out, "kss.interrupted_home_exit_lock_sequence", shared.interrupted_home_exit_lock_sequence);
    note(out, "kss.surface_transport_port_surfaces", shared.surface_transport_port_surfaces);
    note(out, "kss.surface_transport_surface_ports", shared.surface_transport_surface_ports);
    note(out, "kss.host_display_pending_lock_power_off_sequences", shared.host_display_pending_lock_power_off_sequences);
    note(out, "kss.host_display_current_lock_down_sequence", shared.host_display_current_lock_down_sequence);
    note(out, "kss.host_display_wake_after_lock_sequence", shared.host_display_wake_after_lock_sequence);
    note(out, "kss.host_display_wake_power_on_acknowledged", shared.host_display_wake_power_on_acknowledged);
    note(out, "kss.host_display_hardware_wake_pending", shared.host_display_hardware_wake_pending);
    note(out, "kss.active_application_scene", shared.active_application_scene);
    note(out, "kss.pending_application_handoff_process_id", shared.pending_application_handoff_process_id);
    note(out, "kss.next_foreground_layer_sequence", shared.next_foreground_layer_sequence);
    note(out, "kss.active_application_layer_sequence", shared.active_application_layer_sequence);
    note(out, "kss.pending_graphics_inputs", shared.pending_graphics_inputs);
    note(out, "kss.mach_semaphores", shared.mach_semaphores);
    note(out, "kss.posix_named_semaphore_objects", shared.posix_named_semaphore_objects);
    note(out, "kss.mach_timers", shared.mach_timers);
    note(out, "kss.process_interval_timers", shared.process_interval_timers);
    note(out, "kss.mach_memory_entries", shared.mach_memory_entries);
    note(out, "kss.mach_fileports", shared.mach_fileports);
    note(out, "kss.clock_alarms", shared.clock_alarms);
    note(out, "kss.next_clock_alarm", shared.next_clock_alarm);
    note(out, "kss.mach_send_possible_armed_destinations", shared.mach_send_possible_armed_destinations);
    note(out, "kss.semaphore_wakeups", shared.semaphore_wakeups);
    note(out, "kss.semaphore_terminations", shared.semaphore_terminations);
    note(out, "kss.iokit_iterators", shared.iokit_iterators);
    note(out, "kss.iokit_services", shared.iokit_services);
    note(out, "kss.iokit_connections", shared.iokit_connections);
    note(out, "kss.iokit_display_vsync", shared.iokit_display_vsync);
    note(out, "kss.iokit_display_vsync_registration_generation", shared.iokit_display_vsync_registration_generation);
    note(out, "kss.display_vsync_pulse_count", shared.display_vsync_pulse_count);
    note(out, "kss.display_vsync_last_delivered_deadline", shared.display_vsync_last_delivered_deadline);
    note(out, "kss.iokit_audio_connections", shared.iokit_audio_connections);
    note(out, "kss.iokit_camera_capture_requests", shared.iokit_camera_capture_requests);
    note(out, "kss.iokit_mbx_connections", shared.iokit_mbx_connections);
    note(out, "kss.requested_display_power_state", shared.requested_display_power_state);
    note(out, "kss.baseband_service", shared.baseband_service);
    note(out, "kss.serial_multiplexer_service", shared.serial_multiplexer_service);
    note(out, "kss.camera_sensor_service", shared.camera_sensor_service);
    note(out, "kss.camera_accelerator_services", shared.camera_accelerator_services);
    note(out, "kss.jpeg_accelerator_service", shared.jpeg_accelerator_service);
    note(out, "kss.camera_sensor_variables", shared.camera_sensor_variables);
    note(out, "kss.mobile_file_integrity_service", shared.mobile_file_integrity_service);
    note(out, "kss.apple_key_store_service", shared.apple_key_store_service);
    note(out, "kss.effaceable_storage_service", shared.effaceable_storage_service);
    note(out, "kss.keybag_device_tree_defaults_service", shared.keybag_device_tree_defaults_service);
    note(out, "kss.keybag_device_tree_options_service", shared.keybag_device_tree_options_service);
    note(out, "kss.next_keybag_handle", shared.next_keybag_handle);
    note(out, "kss.system_keybag_handle", shared.system_keybag_handle);
    note(out, "kss.key_store", shared.key_store);
    note(out, "kss.mobile_framebuffer_service", shared.mobile_framebuffer_service);
    note(out, "kss.external_framebuffer_service", shared.external_framebuffer_service);
    note(out, "kss.multitouch_hid_service", shared.multitouch_hid_service);
    note(out, "kss.ioaudio2_services", shared.ioaudio2_services);
    note(out, "kss.wifi_service_available", shared.wifi_service_available);
    note(out, "kss.wifi_service", shared.wifi_service);
    note(out, "kss.wifi_interface_service", shared.wifi_interface_service);
    note(out, "kss.iokit_notifications", shared.iokit_notifications);
    note(out, "kss.next_socket_pair", shared.next_socket_pair);
    note(out, "kss.unix_listeners", shared.unix_listeners);
    note(out, "kss.unix_socket_nodes", shared.unix_socket_nodes);
    note(out, "kss.next_shared_memory_object", shared.next_shared_memory_object);
    note(out, "kss.shared_memory_objects", shared.shared_memory_objects);
    note(out, "kss.volatile_shared_memory_backings", shared.volatile_shared_memory_backings);
    note(out, "kss.hfs_metadata_overrides", shared.hfs_metadata_overrides);
    note(out, "kss.package_extensions", shared.package_extensions);
    note(out, "kss.processes", shared.processes);
    note(out, "kss.process_kevent_states", shared.process_kevent_states);
    note(out, "kss.sandbox_extensions", shared.sandbox_extensions);
    note(out, "clock.now", shared.clock.now());
    note(out, "clock.wall_time", shared.clock.wall_time());

    const auto& hle = kernel.userland_hle_;
    note(out, "hle.registrations_", hle.registrations_);
    note(out, "hle.guest_functions_", hle.guest_functions_);
    note(out, "hle.guest_data_symbols_", hle.guest_data_symbols_);
    note(out, "hle.shared_cache_data_symbols_", hle.shared_cache_data_symbols_);
    note(out, "hle.registration_generation_", hle.registration_generation_);
    note(out, "hle.parsed_image_cache_", hle.parsed_image_cache_);
    note(out, "hle.shared_hle_plan_", hle.shared_hle_plan_);
    note(out, "hle.shared_hle_plan_architecture_", hle.shared_hle_plan_architecture_);
    note(out, "hle.shared_hle_plan_registration_generation_", hle.shared_hle_plan_registration_generation_);
    note(out, "hle.installed_calls_", hle.installed_calls_);
    note(out, "hle.callable_aliases_", hle.callable_aliases_);
    note(out, "hle.installed_symbols_", hle.installed_symbols_);
    note(out, "hle.installed_symbol_thumb_", hle.installed_symbol_thumb_);
    note(out, "hle.loaded_images_", hle.loaded_images_);
    note(out, "hle.interned_strings_", hle.interned_strings_);
    note(out, "hle.string_page_", hle.string_page_);
    note(out, "hle.string_cursor_", hle.string_cursor_);
    note(out, "hle.data_pages_", hle.data_pages_);
    note(out, "hle.data_cursor_", hle.data_cursor_);
    note(out, "hle.persistent_trampolines_", hle.persistent_trampolines_);
    note(out, "hle.persistent_trampoline_cursor_", hle.persistent_trampoline_cursor_);
    note(out, "hle.pending_continuations_", hle.pending_continuations_);
    note(out, "hle.deferred_guest_calls_", hle.deferred_guest_calls_);
    note(out, "hle.available_continuation_trampolines_", hle.available_continuation_trampolines_);
    note(out, "hle.continuation_trampoline_cursor_", hle.continuation_trampoline_cursor_);
    note(out, "hle.thread_callback_return_address_", hle.thread_callback_return_address_);
    note(out, "hle.pending_thread_callbacks_", hle.pending_thread_callbacks_);
    note(out, "hle.traced_symbols_", hle.traced_symbols_);

    const auto& hid = kernel.hid_event_system_hle_;
    note(out, "hid.consumer_process_", hid.consumer_process_);
    note(out, "hid.consumer_processor_", hid.consumer_processor_);
    note(out, "hid.delivering_", hid.delivering_);
    note(out, "hid.state_", hid.state_);

    const auto& notify = kernel.darwin_notify_state_hle_;
    note(out, "notify.providers_", notify.providers_);
    note(out, "notify.token_names_", notify.token_names_);
    note(out, "notify.virtual_tokens_", notify.virtual_tokens_);
    note(out, "notify.next_virtual_token_", notify.next_virtual_token_);
    note(out, "notify.owned_registrations_", notify.owned_registrations_);
    note(out, "notify.bus_", notify.bus_);

    const auto& coreaudio = kernel.core_audio_hle_;
    note(out, "coreaudio.service_", coreaudio.service_);
    note(out, "coreaudio.buffer_frame_size_", coreaudio.buffer_frame_size_);
    note(out, "coreaudio.stream_formats_", coreaudio.stream_formats_);
    note(out, "coreaudio.device_volumes_", coreaudio.device_volumes_);
    note(out, "coreaudio.hardware_control_states_", coreaudio.hardware_control_states_);
    note(out, "coreaudio.io_procs_", coreaudio.io_procs_);
    note(out, "coreaudio.native_io_procs_", coreaudio.native_io_procs_);
    note(out, "coreaudio.next_native_io_proc_id_", coreaudio.next_native_io_proc_id_);
    note(out, "coreaudio.retired_io_proc_threads_", coreaudio.retired_io_proc_threads_);

    const auto& wifi = kernel.apple80211_hle_;
    note(out, "wifi.state_", wifi.state_);
    note(out, "wifi.process_handles_", wifi.process_handles_);
    note(out, "wifi.event_broker_", wifi.event_broker_);

    const auto& surface = kernel.core_surface_hle_;
    note(out, "surface.buffers_", surface.buffers_);
    note(out, "surface.free_client_buffers_", surface.free_client_buffers_);
    note(out, "surface.free_imported_mappings_", surface.free_imported_mappings_);
    note(out, "surface.unsupported_trace_count_", surface.unsupported_trace_count_);
    note(out, "surface.last_scanout_generation_", surface.last_scanout_generation_);
    note(out, "surface.last_scanout_pixels_", surface.last_scanout_pixels_);
    note(out, "surface.display_", surface.display_);
    note(out, "surface.surfaces_", surface.surfaces_);
    note(out, "surface.presentation_tracker_", surface.presentation_tracker_);
    note(out, "surface.scene_coordinator_", surface.scene_coordinator_);

    const auto& gles = kernel.opengles_hle_;
    note(out, "gles.threads_", gles.threads_);
    note(out, "gles.contexts_", gles.contexts_);
    note(out, "gles.eagl_context_abi_", gles.eagl_context_abi_);
    note(out, "gles.dispatch_hle_", gles.dispatch_hle_);
    note(out, "gles.surfaces_", gles.surfaces_);
    note(out, "gles.compatibility_display_process_id_", gles.compatibility_display_process_id_);
    note(out, "gles.next_context_", gles.next_context_);
    note(out, "gles.next_surface_", gles.next_surface_);
    note(out, "gles.next_framebuffer_", gles.next_framebuffer_);
    note(out, "gles.next_renderbuffer_", gles.next_renderbuffer_);
    note(out, "gles.egl_error_", gles.egl_error_);
    note(out, "gles.frame_count_", gles.frame_count_);
    note(out, "gles.unsupported_trace_count_", gles.unsupported_trace_count_);
    note(out, "gles.shader_trace_count_", gles.shader_trace_count_);
    note(out, "gles.display_", gles.display_);
    note(out, "gles.surface_store_", gles.surface_store_);
    note(out, "gles.renderer_owner_", gles.renderer_owner_);
    note(out, "gles.compatibility_surfaces_", gles.compatibility_surfaces_);
    note(out, "gles.compatibility_surface_index_", gles.compatibility_surface_index_);
    note(out, "gles.next_compatibility_surface_", gles.next_compatibility_surface_);
    note(out, "gles.renderer_", gles.renderer_);
    note(out, "gles.command_encoder_", gles.command_encoder_);
    note(out, "gles.shared_state_", gles.shared_state_);
    note(out, "gles.scene_coordinator_", gles.scene_coordinator_);

    const auto& mbx = kernel.mbx2d_hle_;
    note(out, "mbx.contexts_", mbx.contexts_);
    note(out, "mbx.next_context_", mbx.next_context_);
    note(out, "mbx.surfaces_", mbx.surfaces_);
    note(out, "mbx.initialized_destinations_", mbx.initialized_destinations_);
    note(out, "mbx.destination_frame_sequences_", mbx.destination_frame_sequences_);
    note(out, "mbx.destination_scene_damage_", mbx.destination_scene_damage_);
    note(out, "mbx.destination_scene_sources_", mbx.destination_scene_sources_);
    note(out, "mbx.next_surface_", mbx.next_surface_);
    note(out, "mbx.framebuffer_surface_", mbx.framebuffer_surface_);
    note(out, "mbx.initialized_", mbx.initialized_);
    note(out, "mbx.deferred_trace_count_", mbx.deferred_trace_count_);
    note(out, "mbx.display_", mbx.display_);
    note(out, "mbx.surface_store_", mbx.surface_store_);
    note(out, "mbx.presentation_tracker_", mbx.presentation_tracker_);
    note(out, "mbx.renderer_owner_", mbx.renderer_owner_);
    note(out, "mbx.next_client_host_source_", mbx.next_client_host_source_);
    note(out, "mbx.retired_client_host_sources_", mbx.retired_client_host_sources_);
    note(out, "mbx.host_graphics_", mbx.host_graphics_);
    note(out, "mbx.command_encoder_", mbx.command_encoder_);

    const auto& fb = kernel.mobile_framebuffer_hle_;
    note(out, "fb.display_", fb.display_);
    note(out, "fb.surface_store_", fb.surface_store_);
    note(out, "fb.presentation_tracker_", fb.presentation_tracker_);
    note(out, "fb.scene_coordinator_", fb.scene_coordinator_);
    note(out, "fb.host_graphics_", fb.host_graphics_);
    note(out, "fb.command_encoder_", fb.command_encoder_);
    note(out, "fb.scanout_surface_", fb.scanout_surface_);
    note(out, "fb.composition_surfaces_", fb.composition_surfaces_);
    note(out, "fb.composition_surface_index_", fb.composition_surface_index_);
    note(out, "fb.layers_", fb.layers_);
    note(out, "fb.external_framebuffers_", fb.external_framebuffers_);
    note(out, "fb.submitted_layers_", fb.submitted_layers_);
    note(out, "fb.next_swap_id_", fb.next_swap_id_);
    note(out, "fb.background_argb_", fb.background_argb_);
    note(out, "fb.submitted_background_argb_", fb.submitted_background_argb_);
    note(out, "fb.scanout_contents_valid_", fb.scanout_contents_valid_);
    note(out, "fb.deferred_foreground_frame_", fb.deferred_foreground_frame_);

    const auto& pthread = kernel.pthread_runtime_;
    note(out, "pthread.registration_", pthread.registration_);
    note(out, "pthread.workqueue_open_", pthread.workqueue_open_);
    note(out, "pthread.workqueue_priority_count_", pthread.workqueue_priority_count_);
    note(out, "pthread.workers_", pthread.workers_);

    const auto& layerkit = kernel.layerkit_hle_;
    note(out, "layerkit.shared_state_", layerkit.shared_state_);
    note(out, "layerkit.scene_coordinator_", layerkit.scene_coordinator_);

    if (fb.surface_store_) {
        const auto& store = *fb.surface_store_;
        note(out, "store.backings_", store.backings_);
        note(out, "store.backing_references_", store.backing_references_);
    }
    if (fb.display_) {
        const auto& display = *fb.display_;
        note(out, "display.pixels_", display.pixels_);
        note(out, "display.surface_content_generation_", display.surface_content_generation_);
        note(out, "display.content_owner_process_id_", display.content_owner_process_id_);
        note(out, "display.sequence_", display.sequence_);
        note(out, "display.content_revision_", display.content_revision_);
        note(out, "display.powered_on_", display.powered_on_);
        note(out, "display.content_orientation_", display.content_orientation_);
        note(out, "display.host_surface_", display.host_surface_);
    }
    if (wifi.state_) {
        const auto& state = *wifi.state_;
        note(out, "wifi.access_points_", state.access_points_);
        note(out, "wifi.preferred_networks_", state.preferred_networks_);
        note(out, "wifi.link_state_", state.link_state_);
        note(out, "wifi.airplane_mode_", state.airplane_mode_);
        note(out, "wifi.powered_before_airplane_mode_", state.powered_before_airplane_mode_);
        note(out, "wifi.associated_index_", state.associated_index_);
        note(out, "wifi.ipv4_", state.ipv4_);
    }
    if (notify.bus_) {
        note(out, "bus.registrations", notify.bus_->registrations);
    }
    return out;
}

std::vector<std::string> CompatibilityKernelSnapshot::populated_memory(
    const AddressSpace& memory)
{
    std::vector<std::string> out;
    note(out, "mem.parallel_access_", memory.parallel_access_);
    note(out, "mem.first_region", memory.mapping_region_at_or_after(0));
    note(out, "mem.resident_pages", memory.resident_page_count());
    note(out, "mem.pages_", memory.pages_);
    note(out, "mem.file_mappings_", memory.file_mappings_);
    note(out, "mem.jit_read_page_table_", memory.jit_read_page_table_);
    note(out, "mem.jit_write_page_table_", memory.jit_write_page_table_);
    note(out, "mem.jit_page_table_enabled_", memory.jit_page_table_enabled_);
    note(out, "mem.jit_write_page_table_enabled_", memory.jit_write_page_table_enabled_);
    note(out, "mem.exclusive_write_tracking_active_", memory.exclusive_write_tracking_active_);
    note(out, "mem.observed_shared_write_tracking_epoch_", memory.observed_shared_write_tracking_epoch_);
    note(out, "mem.tracked_write_ranges_", memory.tracked_write_ranges_);
    if (!memory.write_tracked_pages_.empty())
        out.emplace_back("mem.write_tracked_pages_");
    if (!memory.direct_jit_write_pages_.empty())
        out.emplace_back("mem.direct_jit_write_pages_");
    note(out, "mem.write_generation_", memory.write_generation_);
    note(out, "mem.executable_content_generation_", memory.executable_content_generation_);
    note(out, "mem.translation_profile_mapping_generation_", memory.translation_profile_mapping_generation_);
    note(out, "mem.mapping_leases_", memory.mapping_leases_);
    note(out, "mem.next_mapping_lease_token_", memory.next_mapping_lease_token_);
    note(out, "mem.file_page_cache_", memory.file_page_cache_);
    if (memory.translation_profile_map_.region_count() != 0)
        out.emplace_back("mem.translation_profile_map_");
    return out;
}

}
