// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "foundation/address_space.hpp"
#include "foundation/output.hpp"
#include "kernel/kernel.hpp"

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
};

}

namespace {

using emulator::AddressSpace;
using emulator::CompatibilityKernel;
using emulator::CompatibilityKernelSnapshot;
using emulator::Output;

constexpr std::array<std::string_view, 71> saved_members {
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
};

constexpr std::array<std::string_view, 51> open_members {
    "kss.kernel_events",
    "kss.mach_kernel_send_rights",
    "kss.task_port_pids",
    "kss.key_store",
    "kss.processes",
    "kss.process_kevent_states",
    "hid.state_",
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

int failures = 0;
std::size_t checked = 0;

void check_accounted(const std::string& name)
{
    ++checked;
    const std::string_view view { name };
    if (std::ranges::find(saved_members, view) != saved_members.end() ||
        std::ranges::find(open_members, view) != open_members.end()) {
        return;
    }
    std::cerr << "FAIL: populated member " << name
              << " has no serializer and no named refusal\n";
    ++failures;
}

}

int main()
{
    AddressSpace memory;
    std::ostringstream log;
    Output output { log };
    CompatibilityKernel kernel { memory, output };
    for (const auto& name :
        CompatibilityKernelSnapshot::populated_members(kernel)) {
        check_accounted(name);
    }
    for (const auto& name : CompatibilityKernelSnapshot::populated_memory(memory)) {
        check_accounted(name);
    }
    if (failures != 0) {
        std::cerr << failures << " populated members are unaccounted\n";
        return 1;
    }
    std::cout << "kernel snapshot probe checks passed: " << checked
              << " populated members checked, ledger has "
              << saved_members.size() << " saved and " << open_members.size()
              << " open entries\n";
    return 0;
}
