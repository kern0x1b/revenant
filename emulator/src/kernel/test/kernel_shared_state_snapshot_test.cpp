// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "kernel/kernel_shared_state.hpp"

#include "crypto/key_store.hpp"
#include "foundation/application_display.hpp"
#include "foundation/display_geometry.hpp"
#include "foundation/snapshot_io.hpp"
#include "graphics/core_animation_remote_abi.hpp"

#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <iostream>
#include <map>
#include <random>
#include <string>
#include <vector>

namespace {

using emulator::CoreAnimationRemoteAbi;
using emulator::KernelSharedState;
namespace snapshot = emulator::snapshot;
using emulator::snapshot::FormatError;
using emulator::snapshot::Reader;
using emulator::snapshot::Writer;

int failures = 0;

void expect(bool condition, const std::string& what)
{
    if (condition)
        return;
    std::cerr << "FAIL: " << what << '\n';
    ++failures;
}

void populate(KernelSharedState& state)
{
    state.hostname = "snapshot-host";
    state.desired_vnodes = 4096;
    state.next_kernel_event_identifier = 11;
    state.next_route_message_identifier = 12;
    state.next_route_socket_identifier = 13;
    state.next_mach_object = 0x20100;
    state.next_mach_wait_queue_sequence = 14;
    state.mach_queue_generation = 15;
    state.kernel_event_generation = 16;
    state.shared_timer_deadline_cache_generation = 17;
    state.shared_timer_deadline_cache = 18;
    state.shared_timer_deadline_cache_valid = true;
    state.io_event_generation = 19;
    state.next_graphics_input_sequence = 20;
    state.next_application_launch_token = 21;
    state.next_process_incarnation = 22;
    state.next_audit_identity_version = 23;
    state.next_foreground_transition_generation = 24;
    state.next_foreground_layer_sequence = 25;
    state.next_clock_alarm = 26;
    state.next_keybag_handle = 27;
    state.wifi_service_available = true;
    state.next_socket_pair = 28;
    state.next_shared_memory_object = 29;
    state.apple_key_store_service = 40;
    state.baseband_service = 41;
    state.camera_sensor_service = 42;
    state.default_processor_set_control_object = 43;
    state.default_processor_set_name_object = 44;
    state.effaceable_storage_service = 45;
    state.external_framebuffer_service = 46;
    state.jpeg_accelerator_service = 47;
    state.keybag_device_tree_defaults_service = 48;
    state.keybag_device_tree_options_service = 49;
    state.mobile_file_integrity_service = 50;
    state.mobile_framebuffer_service = 51;
    state.multitouch_hid_service = 52;
    state.serial_multiplexer_service = 53;
    state.wifi_interface_service = 54;
    state.wifi_service = 55;
    state.active_application_event_object = 56;
    state.pending_application_event_object = 57;
    state.springboard_active_touch_begin_sequence = 60;
    state.springboard_enqueued_active_touch_begin_sequence = 61;
    state.springboard_enqueued_last_touch_begin_sequence = 62;
    state.springboard_enqueued_last_touch_end_sequence = 63;
    state.springboard_enqueued_last_touch_end_x = 1.5F;
    state.springboard_enqueued_last_touch_end_y = 2.5F;
    state.springboard_last_consumed_touch_sequence = 64;
    state.springboard_last_touch_begin_sequence = 65;
    state.springboard_pending_launch_touch_sequence = 66;
    state.springboard_unlock_touch_active = true;
    state.springboard_unlock_touch_begin_sequence = 67;
    state.springboard_unlock_touch_end_sequence = 68;
    state.springboard_unlock_touch_end_x = 3.5F;
    state.springboard_unlock_touch_end_y = 4.5F;
    state.springboard_unlock_touch_pending = true;
    state.springboard_unlock_touch_start_x = 5.5F;
    state.springboard_unlock_touch_start_y = 6.5F;
    state.springboard_lock_screen_active = false;
    state.active_application_layer_sequence = 69;
    state.last_home_launch_barrier_sequence = 70;
    state.display_vsync_last_delivered_deadline = 71;
    state.display_vsync_pulse_count = 72;
    state.host_display_current_lock_down_sequence = 73;
    state.host_display_wake_after_lock_sequence = 74;
    state.host_display_wake_power_on_acknowledged = true;
    state.iokit_display_vsync_registration_generation = 75;
    state.system_keybag_handle = 76;
    state.application_touch_suspended = true;
    state.requested_display_power_state = 77;
    state.suspended_application_scene_process_id = 78;
    state.foreground_application_attempt_process_id = 79;
    state.pending_application_handoff_process_id = 80;
    state.interrupted_home_exit_lock_sequence = 81;
    state.security_level = 82;
    state.task_for_pid_groups = { 83, 84 };
}

std::vector<std::byte> save_scalars(const KernelSharedState& state)
{
    Writer out;
    state.save_scalar_state(out);
    return out.bytes();
}

void refused_host_wake_is_named()
{
    KernelSharedState state;
    state.host_display_hardware_wake_pending = true;
    bool refused = false;
    try {
        save_scalars(state);
    } catch (const snapshot::RefusedError& error) {
        refused = std::string { error.what() }.find(
                      "kss.host_display_hardware_wake_pending") != std::string::npos;
    }
    expect(refused, "a pending host wake refuses the scalar save by name");
}

void round_trip_restores_the_scalars()
{
    KernelSharedState source;
    populate(source);
    const auto bytes = save_scalars(source);

    KernelSharedState restored;
    expect(save_scalars(restored) != bytes,
        "a fresh state saves differently from the populated one");
    Reader in { bytes };
    restored.load_scalar_state(in);
    expect(in.at_end(), "the scalar stream is consumed");
    expect(restored.hostname == "snapshot-host", "the host name is restored");
    expect(restored.mach_queue_generation.load() == 15,
        "an atomic generation is restored");
    expect(restored.wifi_service_available, "the wifi flag is restored");
    expect(restored.wifi_service == 55, "the wifi service id is restored");
    expect(save_scalars(restored) == bytes,
        "saving the restored state reproduces the same stream");
}

void truncated_stream_is_a_format_error()
{
    KernelSharedState source;
    populate(source);
    const auto bytes = save_scalars(source);
    const std::vector<std::byte> truncated { bytes.begin(),
        bytes.begin() + static_cast<std::ptrdiff_t>(bytes.size() / 2) };
    KernelSharedState restored;
    bool threw = false;
    try {
        Reader in { truncated };
        restored.load_scalar_state(in);
    } catch (const FormatError&) {
        threw = true;
    }
    expect(threw, "a truncated scalar stream throws FormatError");
}

void populate_tables(KernelSharedState& state)
{
    state.mach_kernel_send_rights = { { 0x100, 2 }, { 0x200, 3 } };
    state.task_port_pids = { { 0x300, 7 } };
    state.kernel_events.push_back(KernelSharedState::KernelEvent { 1, 2, 3, 4, 5,
        { std::byte { 0xaa }, std::byte { 0xbb } } });
    state.kernel_events.push_back(KernelSharedState::KernelEvent { 6, 7, 8, 9, 10, { } });
    state.process_kevent_states.emplace(7,
        KernelSharedState::ProcessKeventState { 3, 4, 5 });
    state.process_kevent_states.emplace(9,
        KernelSharedState::ProcessKeventState { 6, 0, 0 });
}

std::vector<std::byte> save_tables(const KernelSharedState& state)
{
    Writer out;
    state.save_port_and_event_tables(out);
    return out.bytes();
}

void round_trip_restores_the_tables()
{
    KernelSharedState source;
    populate_tables(source);
    const auto bytes = save_tables(source);

    KernelSharedState restored;
    expect(save_tables(restored) != bytes,
        "a fresh state saves its tables differently from the populated one");
    Reader in { bytes };
    restored.load_port_and_event_tables(in);
    expect(in.at_end(), "the table stream is consumed");
    expect(restored.kernel_events.size() == 2,
        "both kernel events are restored");
    expect(restored.process_kevent_states.at(7).exec_generation == 3,
        "a kevent state is restored");
    expect(save_tables(restored) == bytes,
        "saving the restored tables reproduces the same stream");
}

void repeated_kevent_state_is_refused()
{
    Writer out;
    snapshot::save(out, std::map<std::uint32_t, std::uint32_t> { });
    snapshot::save(out, std::map<std::uint32_t, std::uint32_t> { });
    snapshot::save(out, std::uint64_t { 0 });
    snapshot::save(out, std::uint64_t { 2 });
    for (int index = 0; index < 2; ++index) {
        snapshot::save(out, std::uint32_t { 7 });
        snapshot::save(out, std::uint64_t { 1 });
        snapshot::save(out, std::uint64_t { 2 });
        snapshot::save(out, std::uint32_t { 3 });
    }
    const auto stream = out.bytes();
    KernelSharedState restored;
    bool threw = false;
    try {
        Reader in { stream };
        restored.load_port_and_event_tables(in);
    } catch (const FormatError&) {
        threw = true;
    }
    expect(threw, "a repeated kevent state is refused with FormatError");
}

void populate_processes(KernelSharedState& state)
{
    KernelSharedState::ProcessRecord record;
    record.parent_pid = 1;
    record.process_group = 42;
    record.uid = 501;
    record.effective_uid = 501;
    record.gid = 20;
    record.effective_gid = 20;
    record.nice_value = -4;
    record.pid_suspended = true;
    record.command = "Snapshot";
    record.executable_path = "/Applications/Snapshot.app/Snapshot";
    record.arguments = { "Snapshot", "--check" };
    record.environment = { "HOME=/var/mobile" };
    record.graphics_input_abi = KernelSharedState::GraphicsInputAbi::Darwin11_0;
    record.code_signature_entitlements = { std::byte { 1 }, std::byte { 2 } };
    record.core_animation_remote_abi = CoreAnimationRemoteAbi {
        emulator::core_animation_transaction_v1_name, 0x41U, 0x42U, false
    };
    record.display_orientation = emulator::DisplayOrientation::LandscapeRight;
    record.application_display = emulator::ApplicationDisplay {
        emulator::ApplicationDisplayMode::IPhoneCompatibility1x,
        emulator::DisplayGeometry { 320, 480 }
    };
    record.incarnation = 9;
    record.parent_incarnation = 3;
    record.start_wall_nanoseconds = 1'000'000'000ULL;
    record.executable_uuid[0] = std::byte { 0x5a };
    record.audit_identity_version = 4;
    record.memory_status.priority = 5;
    record.memory_status.user_data = 9;
    record.importance_donor = true;
    record.dyld_all_image_info_address = 0x1000;
    record.dyld_all_image_info_size = 0x40;
    state.processes.emplace(42, record);

    KernelSharedState::ProcessRecord helper;
    helper.command = "helper";
    state.processes.emplace(43, helper);
}

std::vector<std::byte> save_processes(const KernelSharedState& state)
{
    Writer out;
    state.save_process_table(out);
    return out.bytes();
}

void round_trip_restores_the_processes()
{
    KernelSharedState source;
    populate_processes(source);
    const auto bytes = save_processes(source);

    KernelSharedState restored;
    expect(save_processes(restored) != bytes,
        "a fresh state saves its processes differently from the populated one");
    Reader in { bytes };
    restored.load_process_table(in);
    expect(in.at_end(), "the process stream is consumed");
    expect(restored.processes.size() == 2, "both processes are restored");
    expect(restored.processes.at(42).command == "Snapshot",
        "a process command is restored");
    const auto& abi = restored.processes.at(42).core_animation_remote_abi;
    expect(abi && abi->name == emulator::core_animation_transaction_v1_name,
        "the Core Animation ABI is restored by its name");
    expect(save_processes(restored) == bytes,
        "saving the restored processes reproduces the same stream");
}

void unknown_core_animation_abi_is_refused()
{
    KernelSharedState source;
    KernelSharedState::ProcessRecord record;
    record.core_animation_remote_abi =
        CoreAnimationRemoteAbi { "core-animation-unknown", 0U, 0U, false };
    source.processes.emplace(7, record);
    const auto stream = save_processes(source);
    KernelSharedState restored;
    bool threw = false;
    try {
        Reader in { stream };
        restored.load_process_table(in);
    } catch (const FormatError&) {
        threw = true;
    }
    expect(threw,
        "an unknown Core Animation ABI name is refused with FormatError");
}

std::vector<std::byte> save_key_store(const KernelSharedState& state)
{
    Writer out;
    state.save_key_store_identity(out);
    return out.bytes();
}

bool key_store_load_throws(
    KernelSharedState& state, const std::vector<std::byte>& bytes)
{
    Reader in { bytes };
    try {
        state.load_key_store_identity(in);
    } catch (const FormatError&) {
        return true;
    }
    return false;
}

void key_store_identity_is_checked_on_restore()
{
    std::random_device device;
    const auto root = std::filesystem::temp_directory_path() /
        ("kernel-key-store-" + std::to_string(device()));
    const auto first = emulator::KeyStore::open(root / "first" / "state");
    const auto same = emulator::KeyStore::open(root / "first" / "state");
    const auto other = emulator::KeyStore::open(root / "other" / "state");
    expect(first && same && other, "three key stores open");

    KernelSharedState source;
    source.key_store = first;
    const auto bytes = save_key_store(source);

    KernelSharedState matching;
    matching.key_store = same;
    Reader in { bytes };
    matching.load_key_store_identity(in);
    expect(in.at_end(), "the key store identity is consumed");
    expect(save_key_store(matching) == bytes,
        "the same key store file restores the same identity");

    KernelSharedState mismatched;
    mismatched.key_store = other;
    expect(key_store_load_throws(mismatched, bytes),
        "a different key store file is refused with FormatError");

    KernelSharedState absent;
    expect(key_store_load_throws(absent, bytes),
        "a saved key store with no wiring is refused with FormatError");

    KernelSharedState bare_source;
    const auto bare_bytes = save_key_store(bare_source);
    KernelSharedState bare_restored;
    expect(!key_store_load_throws(bare_restored, bare_bytes),
        "no key store on either side restores");

    KernelSharedState wired;
    wired.key_store = first;
    expect(key_store_load_throws(wired, bare_bytes),
        "a wired key store with no saved one is refused with FormatError");

    std::filesystem::remove_all(root);
}

}

int main()
{
    round_trip_restores_the_scalars();
    refused_host_wake_is_named();
    truncated_stream_is_a_format_error();
    round_trip_restores_the_tables();
    repeated_kevent_state_is_refused();
    round_trip_restores_the_processes();
    unknown_core_animation_abi_is_refused();
    key_store_identity_is_checked_on_restore();
    if (failures != 0) {
        std::cerr << failures << " kernel shared state snapshot checks failed\n";
        return 1;
    }
    std::cout << "kernel shared state snapshot checks passed\n";
    return 0;
}
