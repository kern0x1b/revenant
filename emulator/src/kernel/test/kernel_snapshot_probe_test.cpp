// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "foundation/address_space.hpp"
#include "foundation/output.hpp"
#include "kernel/kernel.hpp"
#include "kernel_snapshot_booted_members.hpp"

#include <algorithm>
#include <array>
#include <cstddef>
#include <iostream>
#include <sstream>
#include <string>
#include <string_view>
#include <vector>

namespace emulator {

struct CompatibilityKernelSnapshot {
    static std::vector<std::string> populated_members(
        const CompatibilityKernel& kernel);
    static std::vector<std::string> populated_memory(
        const AddressSpace& memory);
    static void add_pending_timer(CompatibilityKernel& kernel);
};

}

namespace {

using emulator::AddressSpace;
using emulator::CompatibilityKernel;
using emulator::CompatibilityKernelSnapshot;
using emulator::Output;

constexpr std::array<std::string_view, 135> saved_members {
    "clock.now",
    "clock.wall_time",
    "display.pixels_",
    "display.sequence_",
    "display.content_revision_",
    "display.powered_on_",
    "hle.registrations_",
    "hle.guest_functions_",
    "hle.guest_data_symbols_",
    "hle.registration_generation_",
    "hle.persistent_trampoline_cursor_",
    "hle.continuation_trampoline_cursor_",
    "hle.installed_calls_",
    "hle.installed_symbol_thumb_",
    "hle.installed_symbols_",
    "hle.loaded_images_",
    "hle.shared_cache_data_symbols_",
    "hle.shared_hle_plan_",
    "hle.shared_hle_plan_architecture_",
    "hle.shared_hle_plan_registration_generation_",
    "mem.parallel_access_",
    "mem.first_region",
    "mem.resident_pages",
    "mem.pages_",
    "mem.file_mappings_",
    "mem.jit_page_table_enabled_",
    "mem.jit_write_page_table_enabled_",
    "mem.executable_content_generation_",
    "mem.translation_profile_mapping_generation_",
    "mem.next_mapping_lease_token_",
    "mem.translation_profile_map_",
    "notify.providers_",
    "notify.next_virtual_token_",
    "notify.bus_",
    "surface.display_",
    "wifi.state_",
    "wifi.access_points_",
    "wifi.link_state_",
    "ck.guest_working_directory_",
    "ck.process_image_",
    "ck.thread_ports_",
    "ck.thread_signal_masks_",
    "ck.thread_pending_signals_",
    "ck.random_state_",
    "ck.pending_event_topology_generation_",
    "ck.pending_event_poll_topology_generation_",
    "ck.pending_event_poll_io_generation_",
    "ck.pending_event_poll_mach_generation_",
    "ck.pending_event_poll_observed_",
    "ck.local_timer_deadline_cache_valid_",
    "ck.virtual_processor_count_",
    "ck.next_load_average_sample_",
    "ck.pending_event_processors_",
    "ck.pending_event_poll_deadline_",
    "ck.local_timer_deadline_cache_",
    "ck.dyld_shared_cache_attempted_",
    "ck.dyld_shared_cache_path_",
    "ck.timer_trace_count_",
    "ck.port_status_trace_count_",
    "ck.thread_trace_count_",
    "ck.mapping_trace_count_",
    "ck.socket_payload_trace_count_",
    "ck.semaphore_wait_trace_count_",
    "ck.psynch_trace_count_",
    "ck.baseband_io_trace_count_",
    "ck.signal_actions_",
    "ck.disabled_thread_signals_",
    "ck.alternate_signal_stacks_",
    "ck.pending_signals_",
    "ck.last_delivered_graphics_inputs_",
    "ck.next_display_scanout_deadline_",
    "ck.vm_purgable_states_",
    "ck.apple80211_scan_delivered_",
    "ck.file_descriptors_",
    "ck.file_offsets_",
    "ck.file_status_flags_",
    "ck.descriptor_flags_",
    "ck.duplicated_descriptors_",
    "ck.posix_semaphore_descriptors_",
    "ck.virtual_descriptors_",
    "ck.descriptor_guards_",
    "ck.bound_socket_names_",
    "ck.listening_sockets_",
    "ck.virtual_block_descriptors_",
    "ck.system_event_filters_",
    "ck.system_event_next_identifiers_",
    "ck.scheduled_wifi_driver_events_",
    "kss.apple_key_store_service",
    "kss.baseband_service",
    "kss.camera_sensor_service",
    "kss.default_processor_set_control_object",
    "kss.default_processor_set_name_object",
    "kss.effaceable_storage_service",
    "kss.external_framebuffer_service",
    "kss.jpeg_accelerator_service",
    "kss.keybag_device_tree_defaults_service",
    "kss.keybag_device_tree_options_service",
    "kss.mobile_file_integrity_service",
    "kss.mobile_framebuffer_service",
    "kss.multitouch_hid_service",
    "kss.serial_multiplexer_service",
    "kss.wifi_interface_service",
    "kss.wifi_service",
    "kss.active_application_event_object",
    "kss.pending_application_event_object",
    "kss.hostname",
    "kss.desired_vnodes",
    "kss.next_kernel_event_identifier",
    "kss.next_route_message_identifier",
    "kss.next_route_socket_identifier",
    "kss.next_mach_object",
    "kss.next_mach_wait_queue_sequence",
    "kss.mach_queue_generation",
    "kss.kernel_event_generation",
    "kss.shared_timer_deadline_cache_generation",
    "kss.shared_timer_deadline_cache",
    "kss.shared_timer_deadline_cache_valid",
    "kss.io_event_generation",
    "kss.next_graphics_input_sequence",
    "kss.next_application_launch_token",
    "kss.next_process_incarnation",
    "kss.next_audit_identity_version",
    "kss.next_foreground_transition_generation",
    "kss.next_foreground_layer_sequence",
    "kss.next_clock_alarm",
    "kss.next_keybag_handle",
    "kss.wifi_service_available",
    "kss.next_socket_pair",
    "kss.next_shared_memory_object",
    "kss.mach_kernel_send_rights",
    "kss.task_port_pids",
    "kss.kernel_events",
    "kss.process_kevent_states",
    "kss.processes",
    "kss.key_store",
};

constexpr std::array<std::string_view, 112> open_members {
    "kss.active_springboard_alert_items",
    "kss.ambient_light_sensor",
    "kss.apple_key_store_available",
    "kss.application_fullscreen_surface_publications",
    "kss.application_launch_attempts",
    "kss.application_scene_context_owners",
    "kss.application_scene_transforms",
    "kss.baseband_device_state",
    "kss.darwin_abi",
    "kss.darwin_kernel_identity",
    "kss.device_board_config",
    "kss.device_cpu_type",
    "kss.device_hardware_model",
    "kss.device_model_number",
    "kss.device_product_type",
    "kss.device_ram_bytes",
    "kss.display_geometry",
    "kss.effaceable_storage_available",
    "kss.effaceable_storage_blob",
    "kss.external_framebuffer",
    "kss.framebuffer_service_class",
    "kss.graphics_services_capability_memory",
    "kss.hfs_named_attribute_overrides",
    "kss.hid_event_queue",
    "kss.iokit_camera_accelerator_connections",
    "kss.iokit_display_connections",
    "kss.iokit_display_vsync_deadlines",
    "kss.iokit_graphics_connections",
    "kss.iokit_interest_notifications",
    "kss.iokit_multitouch_hid_connections",
    "kss.latest_application_scene_transform",
    "kss.launchd_job_catalog_once",
    "kss.mach_dead_name_notifications",
    "kss.mach_namespaces",
    "kss.mach_notifications",
    "kss.mach_port_objects",
    "kss.mach_port_set_links_by_member",
    "kss.mach_port_set_preposts",
    "kss.native_hid_touch_events",
    "kss.pending_application_event_launches",
    "kss.pending_bootstrap_retries",
    "kss.pending_foreground_transition_input_completion",
    "kss.route_table",
    "kss.socket_pair_ancillary",
    "kss.socket_pair_buffers",
    "kss.suppress_future_application_fullscreen_surface_processes",
    "kss.suppressed_application_fullscreen_surface_publications",
    "kss.surface_transport_port_leases",
    "kss.task_exception_type_count",
    "kss.task_special_ports",
    "kss.task_thread_port_objects",
    "kss.user_interface_geometry",
    "kss.virtual_effaceable_storage_available",
    "ck.dyld_shared_cache_",
    "ck.process_",
    "ck.load_average_",
    "ck.offline_serial_state_",
    "ck.bpf_descriptors_",
    "ck.kernel_control_endpoints_",
    "ck.route_socket_states_",
    "ck.socket_options_",
    "ck.unix_listener_states_",
    "ck.virtual_udp_sockets_",
    "ck.wifi_driver_event_streams_",
    "ck.directory_entries_cache_",
    "kss.mach_queues",
    "kss.mach_semaphores",
    "pthread.registration_",
    "coreaudio.service_",
    "coreaudio.buffer_frame_size_",
    "coreaudio.next_native_io_proc_id_",
    "wifi.event_broker_",
    "surface.surfaces_",
    "surface.presentation_tracker_",
    "surface.scene_coordinator_",
    "gles.dispatch_hle_",
    "gles.next_context_",
    "gles.next_surface_",
    "gles.next_framebuffer_",
    "gles.next_renderbuffer_",
    "gles.egl_error_",
    "gles.display_",
    "gles.surface_store_",
    "gles.renderer_owner_",
    "gles.renderer_",
    "gles.command_encoder_",
    "gles.shared_state_",
    "gles.scene_coordinator_",
    "mbx.next_context_",
    "mbx.next_surface_",
    "mbx.display_",
    "mbx.surface_store_",
    "mbx.presentation_tracker_",
    "mbx.renderer_owner_",
    "mbx.next_client_host_source_",
    "mbx.host_graphics_",
    "mbx.command_encoder_",
    "fb.display_",
    "fb.surface_store_",
    "fb.presentation_tracker_",
    "fb.scene_coordinator_",
    "fb.host_graphics_",
    "fb.command_encoder_",
    "fb.next_swap_id_",
    "fb.background_argb_",
    "fb.submitted_background_argb_",
    "layerkit.shared_state_",
    "layerkit.scene_coordinator_",
    "mem.jit_read_page_table_",
    "mem.jit_write_page_table_",
    "mem.direct_jit_write_pages_",
    "mem.file_page_cache_",
};

constexpr std::array<std::string_view, 1> wired_members {
    "hid.state_",
};

constexpr std::array<std::string_view, 27> refused_members {
    "ck.aio_completions_",
    "ck.host_sockets_",
    "ck.pending_baseband_writes_",
    "ck.pending_flocks_",
    "ck.pending_host_accepts_",
    "ck.pending_host_connects_",
    "ck.pending_host_writes_",
    "ck.pending_io_poll_cache_",
    "ck.pending_kevents_",
    "ck.pending_mach_receives_",
    "ck.pending_polls_",
    "ck.pending_psynch_waits_",
    "ck.pending_record_locks_",
    "ck.pending_recvmsgs_",
    "ck.pending_selects_",
    "ck.pending_semaphore_waits_",
    "ck.pending_signal_suspends_",
    "ck.pending_socket_reads_",
    "ck.pending_timers_",
    "ck.pending_unix_accepts_",
    "ck.pending_waits_",
    "ck.scheduler_handoffs_",
    "ck.scheduler_yields_",
    "ck.regular_file_open_descriptions_",
    "ck.baseband_open_descriptions_",
    "ck.kqueues_",
    "ck.socket_pair_endpoints_",
};

int failures = 0;
std::size_t checked = 0;

void check_accounted(const std::string& name)
{
    ++checked;
    const std::string_view view { name };
    if (std::ranges::find(saved_members, view) != saved_members.end() ||
        std::ranges::find(open_members, view) != open_members.end() ||
        std::ranges::find(wired_members, view) != wired_members.end() ||
        std::ranges::find(refused_members, view) != refused_members.end()) {
        return;
    }
    std::cerr << "FAIL: populated member " << name
              << " has no serializer and no named refusal\n";
    ++failures;
}

struct Machine {
    AddressSpace memory;
    std::ostringstream log;
    Output output { log };
    CompatibilityKernel kernel { memory, output };
};

void check(bool condition, const std::string& what)
{
    if (condition)
        return;
    std::cerr << "FAIL: " << what << '\n';
    ++failures;
}

bool save_refuses(CompatibilityKernel& kernel, const std::string& member)
{
    emulator::snapshot::Writer out;
    try {
        kernel.save_kernel_bookkeeping(out);
    } catch (const emulator::snapshot::RefusedError& error) {
        return std::string { error.what() }.find(member) != std::string::npos;
    }
    return false;
}

void check_live_continuation_is_refused()
{
    Machine populated;
    CompatibilityKernelSnapshot::add_pending_timer(populated.kernel);
    check(save_refuses(populated.kernel, "ck.pending_timers_"),
        "a pending timer makes the bookkeeping save refuse by name");

    Machine empty;
    emulator::snapshot::Writer empty_out;
    empty.kernel.save_kernel_bookkeeping(empty_out);
    const auto bytes = empty_out.bytes();
    CompatibilityKernelSnapshot::add_pending_timer(empty.kernel);
    emulator::snapshot::Reader in { bytes };
    bool rejected = false;
    try {
        empty.kernel.load_kernel_bookkeeping(in);
    } catch (const emulator::snapshot::FormatError&) {
        rejected = true;
    }
    check(rejected,
        "loading bookkeeping into a kernel with a pending timer throws FormatError");
}

}

int main()
{
    AddressSpace memory;
    std::ostringstream log;
    Output output { log };
    CompatibilityKernel kernel { memory, output };
    check_live_continuation_is_refused();
    for (const auto& name :
        CompatibilityKernelSnapshot::populated_members(kernel)) {
        check_accounted(name);
    }
    for (const auto& name : CompatibilityKernelSnapshot::populated_memory(memory)) {
        check_accounted(name);
    }
    for (const auto name : emulator::booted_populated_members) {
        check_accounted(std::string { name });
    }
    if (failures != 0) {
        std::cerr << failures << " checks failed\n";
        return 1;
    }
    std::cout << "kernel snapshot probe checks passed: " << checked
              << " populated members checked, "
              << emulator::booted_populated_members.size()
              << " booted members, ledger has "
              << saved_members.size() << " saved, " << open_members.size()
              << " open, " << wired_members.size() << " wired and "
              << refused_members.size() << " refused entries\n";
    return 0;
}
