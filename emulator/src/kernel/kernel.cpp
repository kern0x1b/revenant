// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Dispatch guest kernel calls and coordinate process, memory, device
// and IPC services.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/bsd/sys/stat.h
// https://github.com/apple-oss-distributions/xnu/blob/xnu-1228.15.4/bsd/sys/mount.h
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/kern/syscall_sw.c

#include "kernel/kernel.hpp"
#include "bsd/security/extensions.hpp"
#include "foundation/application_display.hpp"
#include "foundation/application_path.hpp"
#include "foundation/fault_dump.hpp"
#include "foundation/guest_image_table.hpp"
#include "foundation/macho.hpp"
#include <algorithm>
#include "device_state/darwin_kernel_identity.hpp"
#include "foundation/rootfs_path_resolver.hpp"

#include "storage/app_support_hle.hpp"
#include "bluetooth/bluetooth_manager_hle.hpp"
#include "mach/bootstrap_mig_ids.hpp"
#include "graphics/core_animation_remote_abi.hpp"
#include "telephony/core_telephony_hle.hpp"
#include "crypto/core_crypto_hle.hpp"
#include "kernel/core_animation_software_hle.hpp"
#include "kernel/darwin_abi.hpp"
#include "kernel/darwin_kqueue_abi.hpp"
#include "network/darwin_network_abi.hpp"
#include "kernel/darwin_resource_abi.hpp"
#include "kernel/mach_thread_policy_abi.hpp"
#include <fcntl.h>
#include <sys/param.h>
#include <unistd.h>
#include "network/darwin_route_socket.hpp"
#include "network/dns_configuration_hle.hpp"
#include "kernel/graphics_services_input.hpp"
#include "device_state/graphics_services_capabilities.hpp"
#include "kernel/graphics_services_input_abi.hpp"
#include "kernel/iokit_abi.hpp"
#include "kernel/kernel_bsd_interval_timer.hpp"
#include "kernel/kernel_clock.hpp"
#include "kernel/kernel_iokit.hpp"
#include "kernel/kernel_iokit_camera.hpp"
#include "kernel/kernel_iokit_display.hpp"
#include "kernel/kernel_mach_ipc.hpp"
#include "kernel/kernel_mach_task_identity.hpp"
#include "kernel/kernel_network.hpp"
#include "storage/lockdown_hle.hpp"
#include "kernel/mach_clock_abi.hpp"
#include "mach/mach_host_mig_ids.hpp"
#include "mach/mach_port_mig_ids.hpp"
#include "kernel/mach_scheduler_abi.hpp"
#include "kernel/mach_thread_policy_abi.hpp"
#include "foundation/macho.hpp"
#include "kernel/mbx_connect_hle.hpp"
#include "mach/mig_wire_abi.hpp"
#include "kernel/offline_serial_device.hpp"
#include "foundation/performance.hpp"
#include "mach/task_mig_ids.hpp"
#include "mach/thread_act_mig_ids.hpp"
#include "mach/vm_map_mig_ids.hpp"
#include "mach/xnu_mig_adapter.hpp"

#include <algorithm>
#include <array>
#include <bit>
#include <chrono>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <fstream>
#include <iterator>
#include <limits>
#include <memory>
#include <set>
#include <span>
#include <sstream>
#include <stdexcept>
#include <string_view>
#include <utility>
#include <vector>

#include <sys/stat.h>

#include "mach/support.hpp"

namespace emulator {

std::size_t CompatibilityKernel::bootstrap_checked_in_service_count() const
{
    std::lock_guard lock { shared_state_->mach_mutex };
    return shared_state_->bootstrap_checked_in_services.size();
}

namespace {

    constexpr std::string_view springboard_finished_startup_notification_name {
        "com.apple.springboard.finishedstartup"
    };
    constexpr std::uint32_t carry_flag = 1U << 29U;
    constexpr std::uint32_t ebadf = 9;
    constexpr std::uint32_t efault = 14;
    constexpr std::uint32_t virtual_disk_major = 14;
    constexpr std::uint32_t root_disk_minor = 1;
    constexpr std::uint32_t root_disk_device =
        (virtual_disk_major << 24U) | root_disk_minor;
    constexpr std::uint64_t arm_user_vm_max_address = 0x80000000ULL;

    std::pair<PerfDiagnosticSourceKind, std::uint32_t> svc_diagnostic_source(
        const Cpu& cpu, std::uint32_t immediate)
    {
        if (immediate != 0x80U) {
            return { PerfDiagnosticSourceKind::SvcHle, immediate };
        }
        const auto raw_number = cpu.registers()[12];
        if (raw_number == darwin::arm_fast_trap::syscall_number) {
            return { PerfDiagnosticSourceKind::SvcFast, cpu.registers()[3] };
        }
        const auto signed_number = std::bit_cast<std::int32_t>(raw_number);
        if (signed_number < 0) {
            return { PerfDiagnosticSourceKind::SvcMach,
                static_cast<std::uint32_t>(
                    -static_cast<std::int64_t>(signed_number)) };
        }
        const auto number = raw_number == 0U ? cpu.registers()[0] : raw_number;
        return { PerfDiagnosticSourceKind::SvcBsd, number };
    }

    class SvcDispatchDiagnostics {
    public:
        SvcDispatchDiagnostics(
            std::uint32_t process_id, const Cpu& cpu, std::uint32_t immediate)
            : enabled_ {
                performance_counters().cpu_source_diagnostics_enabled()
            }
            , process_id_ { process_id }
        {
            if (!enabled_)
                return;
            const auto [kind, number] = svc_diagnostic_source(cpu, immediate);
            kind_ = kind;
            number_ = number;
            started_ = std::chrono::steady_clock::now();
        }

        SvcDispatchDiagnostics(const SvcDispatchDiagnostics&) = delete;
        SvcDispatchDiagnostics& operator=(
            const SvcDispatchDiagnostics&) = delete;

        ~SvcDispatchDiagnostics()
        {
            if (!enabled_)
                return;
            const auto elapsed =
                std::chrono::duration_cast<std::chrono::nanoseconds>(
                    std::chrono::steady_clock::now() - started_);
            const auto nanoseconds =
                static_cast<std::uint64_t>(elapsed.count());
            performance_counters().record_diagnostic_svc_dispatch(
                kind_, process_id_, number_, nanoseconds);
        }

    private:
        bool enabled_ { };
        PerfDiagnosticSourceKind kind_ { };
        std::uint32_t process_id_ { };
        std::uint32_t number_ { };
        std::chrono::steady_clock::time_point started_;
    };

    OpenGlesGuestCapabilitySet open_gles_capabilities_for_device(
        GraphicsAcceleratorKind accelerator)
    {
        switch (accelerator) {
        case GraphicsAcceleratorKind::MbxLite:
            return OpenGlesGuestCapabilitySet::MbxLiteLegacy;
        case GraphicsAcceleratorKind::Sgx535:
            return OpenGlesGuestCapabilitySet::Sgx535;
        case GraphicsAcceleratorKind::Sgx543:
            return OpenGlesGuestCapabilitySet::Sgx543;
        }
        return OpenGlesGuestCapabilitySet::MbxLiteLegacy;
    }

}

void CompatibilityKernel::seed_random(std::uint64_t seed)
{
    random_state_ = seed | 1U;
}

CompatibilityKernel::CompatibilityKernel(AddressSpace& memory, Output& output,
    std::filesystem::path rootfs, DeviceModel device,
    std::optional<bool> activated, LockdownCapabilities lockdown_capabilities,
    std::optional<DarwinKernelConfiguration> configuration,
    std::shared_ptr<hfs::GuestIdTable> guest_ids)
    : memory_ { memory }
    , output_ { output }
    , rootfs_ { std::move(rootfs) }
    , device_model_ { device }
    , hfs_volumes_ { rootfs_, device_model_.memory.storage_bytes }
    , hfs_metadata_ { rootfs_, std::move(guest_ids) }
    , display_state_ { std::make_shared<DisplayState>(
          device_model_.screen.panel) }
    , audio_service_ { std::make_shared<AudioService>(rootfs_) }
    , userland_hle_ { memory_, output_ }
    , hid_event_system_hle_ { userland_hle_ }
    , system_configuration_hle_ { userland_hle_ }
    , darwin_notify_state_hle_ { userland_hle_ }
    , audio_toolbox_hle_ { userland_hle_ }
    , core_media_hle_ { userland_hle_ }
    , core_audio_hle_ { userland_hle_, audio_service_ }
    , apple80211_hle_ { userland_hle_, wifi_state_,
        [this](const WifiSnapshot& before, const WifiSnapshot& after) {
            apply_wifi_transition(before, after);
        } }
    , core_surface_hle_ { userland_hle_, display_state_, surface_store_,
        presentation_tracker_ }
    , opengles_hle_ { userland_hle_, display_state_, surface_store_ }
    , mbx2d_hle_ { userland_hle_, display_state_, surface_store_,
        presentation_tracker_ }
    , mobile_framebuffer_hle_ { userland_hle_, display_state_, surface_store_,
        presentation_tracker_ }
{
    memory_.set_file_generation_registry(
        shared_state_->guest_file_generation_registry);
    for (auto& entry : shared_state_->network_interfaces)
        entry.second.up_time_nanoseconds = shared_state_->clock.wall_time();
    shared_state_->shared_mapping_page_cache->set_generation_registry(
        shared_state_->guest_file_generation_registry);
    opengles_hle_.set_guest_capabilities(
        open_gles_capabilities_for_device(device_model_.screen.accelerator));
    display_state_->set_orientation_resolver(
        [state = shared_state_, scenes = scene_coordinator_](
            std::uint32_t owner_process_id) {
            const auto foreground_scene = scenes->foreground_client_scene();
            const auto active_scene = scenes->active_client_scene();
            std::lock_guard lock { state->mach_mutex };
            const auto owner = state->processes.find(owner_process_id);
            const auto owner_is_application =
                owner != state->processes.end() &&
                is_application_executable_path(owner->second.executable_path);
            if (!owner_is_application && active_scene &&
                active_scene->state == ClientSceneState::Active) {
                if (const auto client =
                        state->processes.find(active_scene->client_process_id);
                    client != state->processes.end()) {
                    return client->second.display_orientation;
                }
            }
            if (owner != state->processes.end()) {
                return owner->second.display_orientation;
            }
            if (foreground_scene) {
                if (const auto process = state->processes.find(
                        foreground_scene->client_process_id);
                    process != state->processes.end()) {
                    return process->second.display_orientation;
                }
            }
            return DisplayOrientation::Portrait;
        });
    apple80211_hle_.set_event_injection_handler(
        [this](std::uint32_t descriptor, std::uint32_t event) {
            inject_wifi_driver_event(descriptor, event);
        });
    auto resolved = configuration ? std::move(*configuration)
                                  : resolve_darwin_configuration(rootfs_);
    shared_state_->darwin_kernel_identity = std::move(resolved.identity);
    shared_state_->darwin_abi = resolved.abi;
    configure_darwin_notify_state();
    shared_state_->device_product_type = device_model_.identity.product_type;
    shared_state_->device_board_config = device_model_.identity.board_config;
    shared_state_->device_hardware_model =
        device_model_.identity.hardware_model();
    shared_state_->device_model_number = device_model_.identity.model_number;
    shared_state_->device_ram_bytes = device_model_.memory.ram_bytes;
    shared_state_->graphics_services_capability_memory =
        make_graphics_services_capability_memory(rootfs_, device_model_);
    shared_state_->device_cpu_type = arm_mach_cpu_type;
    shared_state_->graphics_accelerator = device_model_.screen.accelerator;
    shared_state_->audio_hardware_profile = device_model_.audio;
    shared_state_->graphics_driver_bundle =
        std::string { device_model_.screen.driver_bundle() };
    shared_state_->framebuffer_service_class =
        resolved.abi.framebuffer_registry ==
                DarwinFramebufferRegistryAbi::UnifiedClcdClass
            ? "AppleCLCD"
            : std::string { device_model_.screen.framebuffer_service_class };
    shared_state_->external_framebuffer =
        device_model_.screen.external_framebuffer;
    shared_state_->ambient_light_sensor = device_model_.ambient_light_sensor;
    shared_state_->native_hid_touch_events =
        device_model_.input.native_hid_touch_events;
    shared_state_->apple_key_store_available =
        device_model_.keybag.apple_key_store_available;
    shared_state_->effaceable_storage_available =
        device_model_.keybag.effaceable_storage_available;
    shared_state_->virtual_effaceable_storage_available =
        device_model_.keybag.virtual_effaceable_storage_available;
    shared_state_->effaceable_storage_blob =
        device_model_.keybag.virtual_effaceable_storage_blob;
    shared_state_->device_cpu_subtype = mach_cpu_subtype_for_architecture(
        arm_architecture_for_model(device_model_.processor.model));
    const auto virtual_baseband =
        device_model_.baseband.transport == BasebandTransport::Virtual;
    const auto offline_baseband =
        device_model_.baseband.transport == BasebandTransport::Offline;
    const auto baseband_device_available =
        virtual_baseband || device_model_.baseband.device_available;
    shared_state_->baseband_device_state.set_available(
        baseband_device_available);
    shared_state_->baseband_device_state.set_transmit_queue_writable(
        baseband_device_available);
    shared_state_->baseband_device_state.set_dynamic_channels_available(
        virtual_baseband || (offline_baseband && baseband_device_available));
    shared_state_->baseband_device_state.set_mux_channel_capacity(
        offline_baseband && baseband_device_available
            ? bsd::baseband_device::offline_mux_channel_capacity
            : 0U);
    shared_state_->baseband_device_state.set_offline_control_enabled(
        offline_baseband);
    shared_state_->mounts.clear();
    for (const auto& volume : hfs_volumes_.volumes()) {
        shared_state_->mounts.push_back({ "hfs", volume.mount_point,
            volume.mounted_device, volume.mount_flags });
    }
    device_model_.screen.panel = display_state_->geometry();
    shared_state_->display_geometry = device_model_.screen.panel;
    shared_state_->user_interface_geometry =
        device_model_.screen.user_interface;
    hid_event_system_hle_.set_shared_state(shared_state_);
    core_surface_hle_.set_shared_state(shared_state_);
    core_surface_hle_.set_scene_coordinator(scene_coordinator_);
    core_surface_hle_.set_surface_port_handlers(
        [this](std::uint32_t process_id, std::uint32_t surface_id) {
            std::lock_guard lock { shared_state_->mach_mutex };
            return mach_support::create_surface_transport_send_right_locked(
                *shared_state_, *surface_store_, process_id, surface_id);
        },
        [this](std::uint32_t process_id,
            std::uint32_t port_name) -> std::optional<std::uint32_t> {
            std::lock_guard lock { shared_state_->mach_mutex };
            return mach_support::resolve_surface_transport_locked(
                *shared_state_, process_id, port_name);
        });
    opengles_hle_.set_shared_state(shared_state_);
    opengles_hle_.set_scene_coordinator(scene_coordinator_);
    mbx2d_hle_.set_shared_state(shared_state_);
    mobile_framebuffer_hle_.set_shared_state(shared_state_);
    mobile_framebuffer_hle_.set_scene_coordinator(scene_coordinator_);
    mobile_framebuffer_hle_.set_frame_presented_handler(
        [this](std::uint32_t process_id) {
            {
                std::lock_guard lock { shared_state_->mach_mutex };
                shared_state_->mark_foreground_transition_locked(
                    KernelSharedState::ForegroundTransitionMilestone::
                        DestinationFirstFrame,
                    process_id, display_state_->presented_frames());
            }
            graphics_services_input::complete_home_transition_after_present(
                *shared_state_, process_id, scene_coordinator_.get());
        });
    mobile_framebuffer_hle_.set_semantic_presentation_handler(
        [this](std::uint32_t process_id) {
            const auto frame_sequence = display_state_->presented_frames();
            const auto content_revision = display_state_->content_revision();
            std::lock_guard lock { shared_state_->mach_mutex };
            shared_state_->mark_foreground_transition_locked(
                KernelSharedState::ForegroundTransitionMilestone::
                    DestinationFirstFrame,
                process_id, frame_sequence);
            shared_state_->note_foreground_transition_content_change_locked(
                process_id, content_revision);
        });
    register_core_telephony_hle(
        userland_hle_, [this] { return wifi_state_; },
        [this](const WifiSnapshot& before, const WifiSnapshot& after) {
            apply_wifi_transition(before, after);
            apple80211_hle_.publish_state_change(before, after);
        },
        device_model_.baseband.transport != BasebandTransport::Virtual);
    register_dns_configuration_hle(userland_hle_);
    register_app_support_hle(userland_hle_);
    register_lockdown_hle(userland_hle_, activated, lockdown_capabilities);
    register_bluetooth_manager_hle(userland_hle_);
    register_core_crypto_hle(userland_hle_);
    register_core_animation_software_hle(userland_hle_);
    register_mbx_connect_hle(userland_hle_);
    graphics_services_input::register_springboard_alert_observers(userland_hle_,
        [this](std::uint32_t object,
            graphics_services_input::SpringBoardAlertObservation observation) {
            graphics_services_input::record_springboard_alert_state(
                *shared_state_, object, observation);
        });
    graphics_services_input::register_springboard_lock_observer(
        userland_hle_, [this](bool locked) {
            graphics_services_input::record_springboard_lock_state(
                *shared_state_, locked);
        });
    graphics_services_input::register_application_suspension_observer(
        userland_hle_,
        [this](std::uint32_t process_id, bool suspended) {
            graphics_services_input::record_application_suspension_state(
                *shared_state_, process_id, suspended,
                scene_coordinator_.get());
        },
        [this](std::uint32_t process_id) {
            const auto already_recorded = [&] {
                std::lock_guard lock { shared_state_->mach_mutex };
                return shared_state_->application_touch_suspended &&
                       shared_state_->application_suspension_reason ==
                           KernelSharedState::ApplicationSuspensionReason::
                               Lock &&
                       shared_state_->suspended_application_scene_process_id ==
                           process_id;
            }();
            if (already_recorded)
                return;
            graphics_services_input::suspend_active_application(*shared_state_,
                KernelSharedState::ApplicationSuspensionReason::Lock,
                scene_coordinator_.get(), 0U);
        });
    graphics_services_input::register_springboard_application_handoff_animation(
        userland_hle_, [this] {
            return graphics_services_input::
                take_pending_application_handoff_animation(*shared_state_);
        });
    layerkit_hle_.register_handlers(
        userland_hle_, shared_state_, scene_coordinator_, output_);
    thread_ports_.emplace(0, process_.thread_port);
    if (!mach_task_identity::initialize_root(*shared_state_, process_)) {
        throw std::runtime_error {
            "failed to initialize root Mach task identity"
        };
    }
    shared_state_->processes[process_.pid] =
        KernelSharedState::ProcessRecord { process_.parent_pid,
            process_.process_group, process_.uid, process_.effective_uid,
            process_.gid, process_.effective_gid, process_.nice_value,
            process_.exit_status,
            process_.termination_signal, process_.exited, false, false,
            "launchd", "/sbin/launchd", { "/sbin/launchd" },
            { },
            KernelSharedState::GraphicsInputAbi::Darwin9_0, { }, { },
            DisplayOrientation::Portrait, { }, 0U };
    shared_state_->processes[process_.pid].memory_status =
        darwin::memorystatus::initial_state(shared_state_->darwin_abi.memory_status_priority);
    install_commpage();
}

void CompatibilityKernel::configure_darwin_notify_state()
{
    darwin_notify_state_hle_.set_abi(
        shared_state_->darwin_abi.notify_state_abi);
    darwin_notify_state_hle_.set_native_server_ready_query(
        [weak_state = std::weak_ptr<KernelSharedState> { shared_state_ }] {
            const auto state = weak_state.lock();
            if (!state)
                return false;
            std::lock_guard lock { state->mach_mutex };
            return state->bootstrap_checked_in_services.contains(
                "com.apple.system.notification_center");
        });
    darwin_notify_state_hle_.set_native_server_provider_query([this] {
        std::call_once(shared_state_->launchd_job_catalog_once, [this] {
            shared_state_->launchd_job_catalog = LaunchdJobCatalog::load(rootfs_);
        });
        std::lock_guard lock { shared_state_->mach_mutex };
        const auto process = shared_state_->processes.find(process_.pid);
        return shared_state_->launchd_job_catalog &&
               process != shared_state_->processes.end() &&
               shared_state_->launchd_job_catalog->executable_provides_service(
                   process->second.executable_path,
                   "com.apple.system.notification_center");
    });
    const auto provider = [state = ringer_switch_state_] {
        return static_cast<std::uint64_t>(state->active());
    };
    darwin_notify_state_hle_.set_provider(
        std::string { ringer_switch_notification_name }, provider);
    darwin_notify_state_hle_.set_provider(
        std::string { springboard_ringer_switch_notification_name }, provider);
    darwin_notify_state_hle_.set_notification_dispatcher(
        [weak_state = std::weak_ptr<KernelSharedState> { shared_state_ }](
            std::uint32_t process_id, std::uint32_t port_name,
            std::uint32_t token) {
            const auto state = weak_state.lock();
            if (!state)
                return;
            std::lock_guard lock { state->mach_mutex };
            const auto destination =
                state->mach_namespaces.resolve(process_id, port_name);
            if (!destination ||
                !state->mach_port_objects.contains(*destination)) {
                return;
            }
            KernelSharedState::MachMessage message;
            message.bytes.resize(
                darwin::mig_wire::message_header_size, std::byte { 0 });
            const auto write_word = [&message](std::size_t offset,
                                        std::uint32_t value) {
                for (std::size_t byte = 0; byte < sizeof(value); ++byte) {
                    message.bytes[offset + byte] =
                        static_cast<std::byte>(value >> (byte * 8U));
                }
            };
            write_word(darwin::mig_wire::header_bits_offset, 19U);
            write_word(darwin::mig_wire::header_size_offset,
                static_cast<std::uint32_t>(message.bytes.size()));
            write_word(
                darwin::mig_wire::header_remote_port_offset, *destination);
            write_word(darwin::mig_wire::header_identifier_offset, token);
            message.destination = *destination;
            message.sender_pid = 0;
            state->enqueue_mach_message_locked(
                *destination, std::move(message));
        });
    darwin_notify_state_hle_.set_post_observer(
        [this](std::string_view name, std::uint32_t process_id) {
            output_.line("[notify] post pid=" + std::to_string(process_id) +
                         " name=" + std::string { name });
            if (name != springboard_finished_startup_notification_name)
                return;
            output_.line("[boot] milestone=springboard-finished-startup pid=" +
                         std::to_string(process_id) + " host-ms=" +
                         std::to_string(host_unix_milliseconds()));
        });
}

bool CompatibilityKernel::set_virtual_processor_count(
    std::size_t processor_count)
{
    if (processor_count == 0 ||
        processor_count > std::numeric_limits<std::uint8_t>::max()) {
        return false;
    }
    virtual_processor_count_ = static_cast<std::uint32_t>(processor_count);
    install_commpage();
    return true;
}

void CompatibilityKernel::enqueue_baseband_input(
    std::span<const std::byte> bytes)
{
    shared_state_->baseband_device_state.enqueue_receive(bytes);
    shared_state_->note_io_event_transition();
}

void CompatibilityKernel::set_baseband_receive_eof(bool eof)
{
    shared_state_->baseband_device_state.set_receive_eof(eof);
    shared_state_->note_io_event_transition();
}

void CompatibilityKernel::enqueue_touch_input(const TouchInput& input)
{
    const PerformanceLatencyScope latency { PerfLatencyKind::InputEnqueue };
    performance_counters().discard_pending_vsync_callbacks();
    bool home_recovery_requested = false;
    std::uint64_t input_sequence = 0;
    const auto result = graphics_services_input::enqueue_touch(*shared_state_,
        input, scene_coordinator_.get(), presentation_tracker_.get(),
        &home_recovery_requested, &input_sequence);
    wake_graphics_input_receivers();
    const auto enqueued_at = std::chrono::steady_clock::now();
    const auto phase = [phase = input.phase] {
        switch (phase) {
        case TouchPhase::Down:
            return "down";
        case TouchPhase::Move:
            return "move";
        case TouchPhase::Up:
            return "up";
        case TouchPhase::Cancel:
            return "cancel";
        }
        return "unknown";
    }();
    performance_counters().record_diagnostic_input("touch", phase, input.x,
        input.y, result == graphics_services_input::EnqueueResult::Queued,
        input_sequence, enqueued_at);
    output_.write("[input] touch phase=" + std::string { phase } + " x=" +
                  std::to_string(input.x) + " y=" + std::to_string(input.y) +
                  (result == graphics_services_input::EnqueueResult::Queued
                          ? " queued\n"
                          : " deferred\n"));
    if (home_recovery_requested) {
        output_.line("[input] recovery=interrupted-lock-launch action=home");
        enqueue_system_button_impl(
            SystemButtonInput { SystemButton::Home, SystemButtonPhase::Down },
            true);
        enqueue_system_button_impl(
            SystemButtonInput { SystemButton::Home, SystemButtonPhase::Up },
            true);
    }
}

void CompatibilityKernel::enqueue_system_button(const SystemButtonInput& input)
{
    enqueue_system_button_impl(input, false);
}

std::optional<std::uint32_t>
CompatibilityKernel::graphics_input_receiver_process_id() const
{
    std::lock_guard lock { shared_state_->mach_mutex };
    const auto service = shared_state_->bootstrap_service_objects.find(
        std::string { graphics_services_input::system_event_service });
    if (service == shared_state_->bootstrap_service_objects.end())
        return std::nullopt;
    const auto port =
        shared_state_->mach_port_objects.lookup(service->second);
    if (!port || port->receive_owner == 0U)
        return std::nullopt;
    const auto process = shared_state_->processes.find(port->receive_owner);
    if (process == shared_state_->processes.end() || process->second.exited)
        return std::nullopt;
    return port->receive_owner;
}

void CompatibilityKernel::enqueue_system_button_impl(
    const SystemButtonInput& input, bool force_home_transition)
{
    const PerformanceLatencyScope latency { PerfLatencyKind::InputEnqueue };
    performance_counters().discard_pending_vsync_callbacks();
    bool wake_button_pressed_while_display_asleep = false;
    bool wake_only_system_button = false;
    bool begins_display_lock_transaction = false;
    if (input.phase == SystemButtonPhase::Down &&
        (input.button == SystemButton::Home ||
            input.button == SystemButton::Lock)) {
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        const auto display_asleep =
            shared_state_->requested_display_power_state.value_or(1U) == 0U;
        if (display_asleep && !force_home_transition) {
            wake_button_pressed_while_display_asleep = true;
            wake_only_system_button = true;
            shared_state_->host_display_intent =
                KernelSharedState::HostDisplayIntent::WakePending;
            shared_state_->host_display_wake_after_lock_sequence =
                shared_state_->host_display_current_lock_down_sequence;
            shared_state_->host_display_wake_power_on_acknowledged = false;
            shared_state_->host_display_hardware_wake_pending = true;
            shared_state_->requested_display_power_state = 1U;
        } else if (input.button == SystemButton::Lock &&
                   !force_home_transition) {
            shared_state_->host_display_intent =
                KernelSharedState::HostDisplayIntent::LockPending;
            shared_state_->host_display_wake_power_on_acknowledged = false;
            shared_state_->host_display_hardware_wake_pending = false;
            begins_display_lock_transaction = true;
        } else if (!force_home_transition &&
                   input.button == SystemButton::Home &&
                   (shared_state_->springboard_unlock_touch_pending ||
                       shared_state_->springboard_unlock_touch_active)) {
            wake_only_system_button = true;
        }
    }
    if (wake_button_pressed_while_display_asleep) {
        graphics_services_input::record_lock_wake_request(*shared_state_);
    }
    std::uint64_t system_input_sequence = 0;
    const auto result =
        graphics_services_input::enqueue_system_button(*shared_state_, input,
            &system_input_sequence, begins_display_lock_transaction);
    wake_graphics_input_receivers();
    const auto enqueued_at = std::chrono::steady_clock::now();
    if ((input.button == SystemButton::Home ||
            input.button == SystemButton::Lock) &&
        input.phase == SystemButtonPhase::Down &&
        (!wake_only_system_button || force_home_transition)) {
        graphics_services_input::suspend_active_application(*shared_state_,
            input.button == SystemButton::Lock
                ? KernelSharedState::ApplicationSuspensionReason::Lock
                : KernelSharedState::ApplicationSuspensionReason::Home,
            scene_coordinator_.get(), system_input_sequence);
    }
    const auto button = [value = input.button] {
        switch (value) {
        case SystemButton::Home:
            return "home";
        case SystemButton::Lock:
            return "lock";
        case SystemButton::VolumeUp:
            return "volume-up";
        case SystemButton::VolumeDown:
            return "volume-down";
        }
        return "unknown";
    }();
    performance_counters().record_diagnostic_input(
        std::string { "button-" } + button,
        input.phase == SystemButtonPhase::Down ? "down" : "up", 0.0F, 0.0F,
        result == graphics_services_input::EnqueueResult::Queued,
        system_input_sequence, enqueued_at);
    output_.write("[input] button=" + std::string { button } + " phase=" +
                  (input.phase == SystemButtonPhase::Down ? "down" : "up") +
                  (result == graphics_services_input::EnqueueResult::Queued
                          ? " queued\n"
                          : " deferred\n"));
}

void CompatibilityKernel::wake_graphics_input_receivers()
{
    if (!mach_message_wake_handler_)
        return;

    std::vector<std::pair<std::uint32_t, std::uint32_t>> receivers;
    {
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        for (const auto& [object, queue] : shared_state_->mach_queues) {
            if (queue.empty() ||
                !std::any_of(queue.begin(), queue.end(), [](const auto& message) {
                    return message.graphics_input_sequence != 0U &&
                           message.graphics_input_kind !=
                               KernelSharedState::MachMessage::GraphicsInputKind::
                                   None;
                })) {
                continue;
            }
            const auto port = shared_state_->mach_port_objects.lookup(object);
            if (!port || port->receive_owner == 0U)
                continue;
            receivers.emplace_back(port->receive_owner, object);
            if (const auto links =
                shared_state_->mach_port_set_links_by_member.find(object);
                links != shared_state_->mach_port_set_links_by_member.end()) {
                for (const auto& link : links->second) {
                    receivers.emplace_back(port->receive_owner,
                        link.set_object);
                }
            }
        }
    }

    std::sort(receivers.begin(), receivers.end());
    receivers.erase(std::unique(receivers.begin(), receivers.end()),
        receivers.end());
    if (mach_message_wake_handler_) {
        for (const auto& [process_id, object] : receivers) {
            static_cast<void>(mach_message_wake_handler_(process_id, object));
        }
    }
}

void CompatibilityKernel::set_ringer_switch_active(bool active)
{
    if (!ringer_switch_state_->set_active(active))
        return;
    performance_counters().discard_pending_vsync_callbacks();
    darwin_notify_state_hle_.publish(ringer_switch_notification_name);
    darwin_notify_state_hle_.publish(
        springboard_ringer_switch_notification_name);
    const auto result = graphics_services_input::enqueue_ringer_switch_change(
        *shared_state_, active);
    wake_graphics_input_receivers();
    output_.write(
        "[input] ringer-switch=" + std::string { active ? "ring" : "silent" } +
        (result == graphics_services_input::EnqueueResult::Queued
                ? " queued\n"
                : " deferred\n"));
}

void CompatibilityKernel::toggle_ringer_switch()
{
    const auto active = ringer_switch_state_->toggle();
    performance_counters().discard_pending_vsync_callbacks();
    darwin_notify_state_hle_.publish(ringer_switch_notification_name);
    darwin_notify_state_hle_.publish(
        springboard_ringer_switch_notification_name);
    const auto result = graphics_services_input::enqueue_ringer_switch_change(
        *shared_state_, active);
    wake_graphics_input_receivers();
    output_.write(
        "[input] ringer-switch=" + std::string { active ? "ring" : "silent" } +
        (result == graphics_services_input::EnqueueResult::Queued
                ? " queued\n"
                : " deferred\n"));
}

bool CompatibilityKernel::display_powered_on() const
{
    std::lock_guard mach_lock { shared_state_->mach_mutex };
    return shared_state_->requested_display_power_state.value_or(1U) != 0;
}

void CompatibilityKernel::set_baseband_capture_enabled(bool enabled)
{
    shared_state_->baseband_device_state.set_transmit_capture_enabled(enabled);
}

void CompatibilityKernel::set_baseband_transmit_sink(
    bsd::baseband_device::State::TransmitSink sink)
{
    shared_state_->baseband_device_state.set_transmit_sink(std::move(sink));
}

std::vector<std::byte> CompatibilityKernel::take_baseband_output()
{
    return shared_state_->baseband_device_state.take_transmitted();
}

bool CompatibilityKernel::refresh_display_scanout()
{
    bool power_on = false;
    {
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        power_on =
            shared_state_->requested_display_power_state.value_or(1U) != 0U;
    }

    if (!power_on) {
        display_state_->set_powered_on(false);
        return false;
    }

    const auto waking = !display_state_->powered_on();
    if (mobile_framebuffer_hle_.has_active_layers()) {
        display_state_->set_powered_on(true);
        return false;
    }

    if (waking) {
        const auto refreshed =
            core_surface_hle_.refresh_default_scanout(memory_, process_.pid);
        display_state_->set_powered_on(true);
        if (refreshed) {
            output_.write(
                "[display] scanout pid=" + std::to_string(process_.pid) +
                " frame=" + std::to_string(display_state_->presented_frames()) +
                "\n");
        }
        return refreshed;
    }

    display_state_->set_powered_on(true);
    const auto now = shared_state_->clock.now();
    if (next_display_scanout_deadline_ &&
        now < *next_display_scanout_deadline_) {
        return false;
    }
    next_display_scanout_deadline_ =
        now + iokit_abi::display_vsync::period_absolute_time;
    const auto refreshed =
        core_surface_hle_.refresh_default_scanout(memory_, process_.pid);
    if (refreshed) {
        output_.write(
            "[display] scanout pid=" + std::to_string(process_.pid) +
            " frame=" + std::to_string(display_state_->presented_frames()) +
            "\n");
    }
    return refreshed;
}

bool CompatibilityKernel::owns_display_scanout() const
{
    const auto backing =
        surface_store_->find(iokit_abi::mobile_framebuffer_default_surface_id);
    return backing && backing->provenance.producer_process_id == process_.pid;
}


void CompatibilityKernel::prepare_exec(std::size_t processor_id)
{
    note_timer_deadline_transition();
    release_close_on_exec_descriptors();
    install_commpage();
    hid_event_system_hle_.reset(process_.pid);
    userland_hle_.reset_mappings();
    darwin_notify_state_hle_.reset();
    core_audio_hle_.reset();
    userland_hle_.record_loaded_image(process_image_);
    apple80211_hle_.reset(process_.pid);
    core_surface_hle_.reset();
    opengles_hle_.reset();
    mbx2d_hle_.reset();
    mobile_framebuffer_hle_.reset();
    layerkit_hle_.reset();
    next_display_scanout_deadline_.reset();
    for (auto& action : signal_actions_) {
        if (action[0] != darwin::signal::ignore_action)
            action = { };
    }
    {
        const auto mask = signal_mask(processor_id);
        const auto pending = thread_pending_signals_[processor_id];
        thread_signal_masks_ = { { processor_id, mask } };
        thread_pending_signals_ = { { processor_id, pending } };
    }
    pthread_runtime_.prepare_exec();
    shared_state_->psynch_runtime->clear_process(process_.pid);
    process_.waiting_for_events = false;
    const auto current_thread_port =
        thread_ports_.find(processor_id) != thread_ports_.end()
            ? thread_ports_.at(processor_id)
            : process_.thread_port;
    std::optional<std::uint32_t> surviving_thread_object;
    std::optional<std::uint32_t> surviving_thread_policy;
    {
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        auto& thread_objects =
            shared_state_->task_thread_port_objects[process_.pid];
        if (const auto current =
                thread_objects.find(static_cast<std::uint32_t>(processor_id));
            current != thread_objects.end()) {
            surviving_thread_object = current->second;
        } else {
            surviving_thread_object = shared_state_->mach_namespaces.resolve(
                process_.pid, current_thread_port);
        }
        if (surviving_thread_object) {
            if (const auto policy = process_.thread_disk_io_policies.find(
                    *surviving_thread_object);
                policy != process_.thread_disk_io_policies.end()) {
                surviving_thread_policy = policy->second;
            }
        }
        thread_objects.clear();
        if (surviving_thread_object) {
            thread_objects[static_cast<std::uint32_t>(processor_id)] =
                *surviving_thread_object;
        }
    }
    process_.thread_disk_io_policies.clear();
    if (surviving_thread_object && surviving_thread_policy) {
        process_.thread_disk_io_policies.emplace(
            *surviving_thread_object, *surviving_thread_policy);
    }
    thread_ports_.clear();
    thread_ports_.emplace(processor_id, current_thread_port);
    last_delivered_graphics_inputs_.clear();
    disabled_thread_signals_.clear();
    pending_waits_.clear();
    pending_mach_receives_.clear();
    pending_kevents_.clear();
    pending_recvmsgs_.clear();
    pending_socket_reads_.clear();
    pending_host_connects_.clear();
    pending_host_accepts_.clear();
    pending_host_writes_.clear();
    pending_baseband_writes_.clear();
    pending_unix_accepts_.clear();
    pending_flocks_.clear();
    pending_record_locks_.clear();
    pending_polls_.clear();
    pending_selects_.clear();
    pending_timers_.clear();
    pending_semaphore_waits_.clear();
    pending_psynch_waits_.clear();
    pending_signal_suspends_.clear();
    scheduler_yields_.clear();
    scheduler_handoffs_.clear();
    aio_completions_.clear();
}

std::size_t CompatibilityKernel::install_mapped_user_image(Cpu& cpu,
    const std::filesystem::path& image_path, std::uint32_t mapping_address,
    std::uint32_t mapping_size, std::uint64_t file_offset,
    bool shared_cache_mapping)
{
    const auto diagnostics_enabled =
        performance_counters().cpu_source_diagnostics_enabled();
    auto phase_started = diagnostics_enabled
                             ? std::chrono::steady_clock::now()
                             : std::chrono::steady_clock::time_point { };
    const auto checkpoint = [&](std::uint32_t phase) {
        if (!diagnostics_enabled)
            return;
        const auto now = std::chrono::steady_clock::now();
        const auto elapsed =
            std::chrono::duration_cast<std::chrono::nanoseconds>(
                now - phase_started);
        performance_counters().record_diagnostic_svc_dispatch(
            PerfDiagnosticSourceKind::MappedImagePhase, process_.pid, phase,
            static_cast<std::uint64_t>(elapsed.count()));
        phase_started = std::chrono::steady_clock::now();
    };
    const auto architecture =
        arm_architecture_for_model(device_model_.processor.model);
    constexpr std::string_view uikit_image { "/UIKit.framework/UIKit" };
    constexpr std::string_view graphics_services_image {
        "/GraphicsServices.framework/GraphicsServices"
    };
    constexpr std::string_view quartz_core_image {
        "/QuartzCore.framework/QuartzCore"
    };
    const auto apply_image_abi =
        [&](std::string_view logical_image_path,
            const std::filesystem::path& source_path,
            std::optional<std::uint64_t> image_header_offset,
            std::optional<ContentIdentity> source_identity,
            std::shared_ptr<const MachOImage> parsed_image = { }) {
            const auto path = std::string { logical_image_path };
            if (path.ends_with(uikit_image)) {
                std::lock_guard mach_lock { shared_state_->mach_mutex };
                if (const auto process =
                        shared_state_->processes.find(process_.pid);
                    process != shared_state_->processes.end() &&
                    process->second.graphics_input_abi ==
                        KernelSharedState::GraphicsInputAbi::LegacyMouse) {
                    process->second.graphics_input_abi =
                        KernelSharedState::GraphicsInputAbi::Darwin9_0;
                }
                return;
            }
            if (!path.ends_with(graphics_services_image) &&
                !path.ends_with(quartz_core_image)) {
                return;
            }

            if (image_header_offset && !parsed_image)
                return;
            const auto image =
                parsed_image
                    ? std::move(parsed_image)
                    : std::make_shared<MachOImage>(MachOImage::parse(
                          source_path, architecture, std::move(source_identity),
                          ImmutableSnapshotKind::RuntimeHot,
                          image_header_offset));
            if (path.ends_with(graphics_services_image)) {
                const auto profile =
                    GraphicsServicesInputAbi::detect(*image);
                if (!profile)
                    return;
                std::lock_guard mach_lock { shared_state_->mach_mutex };
                if (const auto process =
                        shared_state_->processes.find(process_.pid);
                    process != shared_state_->processes.end() &&
                    process->second.graphics_input_abi != *profile) {
                    process->second.graphics_input_abi = *profile;
                    output_.write(
                        "[input] GraphicsServices touch ABI profile=" +
                        std::string {
                            GraphicsServicesInputAbi::for_abi(*profile)
                                .name } +
                        " pid=" + std::to_string(process_.pid) + "\n");
                }
                return;
            }

            const auto profile = CoreAnimationRemoteAbi::detect(*image);
            if (!profile)
                return;
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            if (const auto process =
                    shared_state_->processes.find(process_.pid);
                process != shared_state_->processes.end() &&
                process->second.core_animation_remote_abi != profile) {
                process->second.core_animation_remote_abi = *profile;
                output_.write("[scene] CoreAnimation remote profile=" +
                              std::string { profile->name } +
                              " pid=" + std::to_string(process_.pid) + "\n");
            }
        };
    std::size_t installed = 0;
    const auto* cache = dyld_shared_cache_for(image_path);
    if (cache != nullptr) {
        if (mapping_size == 0U ||
            file_offset >
                std::numeric_limits<std::uint64_t>::max() - mapping_size) {
            return 0;
        }
        const auto source_file = std::find_if(cache->files().begin(),
            cache->files().end(), [&](const DyldCacheFileView& file) {
                return std::filesystem::path { file.path } == image_path;
            });
        if (source_file == cache->files().end())
            return 0;
        const auto source_file_index = static_cast<std::uint32_t>(
            std::distance(cache->files().begin(), source_file));
        static_cast<void>(
            userland_hle_.resolve_mapped_shared_cache_data_symbols(
                image_path, mapping_address, mapping_size, file_offset));
        const auto image_indices = cache->images_intersecting_file_range(
            source_file_index, file_offset, mapping_size);
        for (const auto image_index : image_indices) {
            if (image_index >= cache->images().size())
                continue;
            const auto& image = cache->images()[image_index];
            const auto header = std::find_if(image.executable_ranges.begin(),
                image.executable_ranges.end(),
                [&](const DyldCacheRange& range) {
                    return range.address == image.unslid_load_address &&
                           range.file_index == source_file_index;
                });
            if (header == image.executable_ranges.end())
                continue;
            const auto& source = *source_file;
            const auto profile_relevant =
                image.path.ends_with(graphics_services_image) ||
                image.path.ends_with(quartz_core_image);
            std::shared_ptr<const MachOImage> parsed_image;
            if (profile_relevant) {
                parsed_image = cache->parse_image(image.index, architecture);

            }
            installed += userland_hle_.install_mapped_shared_cache_image(cpu,
                process_.pid, image.path, std::filesystem::path { source.path },
                header->file_offset, mapping_address, mapping_size, file_offset,
                source.content_identity, architecture, parsed_image,
                source_file_index, image.index);
            apply_image_abi(image.path,
                std::filesystem::path { source.path }, header->file_offset,
                source.content_identity, std::move(parsed_image));
        }
    } else if (!shared_cache_mapping) {
        installed =
            userland_hle_.install_mapped_image(cpu, process_.pid, image_path,
                mapping_address, mapping_size, file_offset, architecture);
    }
    const auto cache_mapping = shared_cache_mapping || cache != nullptr;
    checkpoint(1U);
    if (!cache_mapping && mapped_executable_handler_) {
        mapped_executable_handler_(
            image_path, mapping_address, mapping_size, file_offset);
    }
    checkpoint(2U);
    if (cache_mapping) {
        checkpoint(3U);
        return installed;
    }
    apply_image_abi(
        image_path.generic_string(), image_path, std::nullopt, std::nullopt);
    checkpoint(3U);
    return installed;
}

void CompatibilityKernel::install_main_image_hle(
    Cpu& cpu, std::string_view mapped_guest_path)
{
    const auto host_path = resolve_guest_path(mapped_guest_path.empty()
            ? process_image_
            : std::string { mapped_guest_path });
    const auto image = MachOImage::parse(
        host_path, arm_architecture_for_model(device_model_.processor.model));
    for (const auto& segment : image.segments()) {
        if (segment.file_size == 0)
            continue;
        static_cast<void>(install_mapped_user_image(cpu, host_path,
            segment.vm_address, segment.file_size, segment.file_offset));
    }
}

void CompatibilityKernel::set_process_image(std::string_view guest_path,
    std::span<const std::byte> code_signature_entitlements,
    const MachOImage* dynamic_linker, const MachOImage* executable)
{
    process_image_ = guest_path;
    if (is_application_executable_path(guest_path) &&
        guest_working_directory_ == std::filesystem::path { "/" }) {
        guest_working_directory_ =
            std::filesystem::path { guest_path }
                .parent_path()
                .lexically_normal();
        output_.write(
            "[vfs] application-cwd " +
            guest_working_directory_.string() + "\n");
    }
    auto name = std::filesystem::path { guest_path }.filename().string();
    if (name.empty())
        name = "unknown";
    if (name.size() > 16)
        name.resize(16);
    auto& record = shared_state_->processes[process_.pid];
    const auto new_process_incarnation =
        record.incarnation == 0U || record.exited;
    record.parent_pid = process_.parent_pid;
    record.process_group = process_.process_group;
    record.uid = process_.uid;
    record.effective_uid = process_.effective_uid;
    record.gid = process_.gid;
    record.effective_gid = process_.effective_gid;
    record.nice_value = process_.nice_value;
    if (new_process_incarnation) {
        record.start_wall_nanoseconds = shared_state_->clock.wall_time();
        if (const auto parent = shared_state_->processes.find(process_.parent_pid);
            parent != shared_state_->processes.end())
            record.parent_incarnation = parent->second.incarnation;
        record.memory_status = darwin::memorystatus::initial_state(
            shared_state_->darwin_abi.memory_status_priority);
        record.incarnation = shared_state_->next_process_incarnation++;
        if (record.incarnation == 0U)
            record.incarnation = shared_state_->next_process_incarnation++;
        record.pid_suspended = false;
        record.signal_stopped = false;
    }
    record.exited = false;
    record.executable_uuid = executable && executable->uuid()
        ? *executable->uuid() : std::array<std::byte, 16> { };
    record.audit_identity_version = shared_state_->next_audit_identity_version++;
    record.exit_status = 0;
    record.termination_signal = 0;
    record.command = std::move(name);
    record.executable_path = std::string { guest_path };
    record.dyld_all_image_info_address = 0;
    record.dyld_all_image_info_size = 0;
    if (dynamic_linker != nullptr) {
        for (const auto& segment : dynamic_linker->segments()) {
            for (const auto& section : segment.sections) {
                if (section.segment == "__DATA" &&
                    section.name == "__all_image_info") {
                    record.dyld_all_image_info_address = section.address;
                    record.dyld_all_image_info_size = section.size;
                }
            }
        }
    }
    if (performance_counters().block_profile_enabled()) {
        performance_counters().block_profile().note_image_info(
            static_cast<std::uint32_t>(process_.pid),
            record.dyld_all_image_info_address);
    }
    record.code_signature_entitlements.assign(
        code_signature_entitlements.begin(), code_signature_entitlements.end());
    record.display_orientation =
        detect_application_display_orientation(rootfs_, guest_path);
    record.application_display = detect_application_display(rootfs_,
        guest_path, shared_state_->user_interface_geometry);
    if (record.application_display.kind !=
        ApplicationDisplayMode::Native) {
        output_.write("[display] application profile=iphone-compatibility-1x "
                      "pid=" + std::to_string(process_.pid) + "\n");
    }
    if (record.display_orientation != DisplayOrientation::Portrait) {
        output_.write("[display] application orientation=" +
                      std::string { display_orientation_name(
                          record.display_orientation) } +
                      " pid=" + std::to_string(process_.pid) + "\n");
    }
    record.graphics_input_abi =
        KernelSharedState::GraphicsInputAbi::LegacyMouse;
    if (record.arguments.empty())
        record.arguments.push_back(record.executable_path);
    {
        std::lock_guard lock { shared_state_->mach_mutex };
        auto& events = shared_state_->process_kevent_states[process_.pid];
        ++events.exec_generation;
        if (events.exec_generation == 0U)
            events.exec_generation = 1U;
    }
    shared_state_->note_io_event_transition();
}

void CompatibilityKernel::set_process_arguments(
    const std::vector<std::string>& arguments,
    const std::vector<std::string>& environment)
{
    auto& record = shared_state_->processes[process_.pid];
    record.arguments = arguments;
    record.environment = environment;
}

bool CompatibilityKernel::complete_wait(
    Cpu& cpu, std::uint32_t child_pid, std::uint32_t wait_status)
{
    const auto pending = pending_waits_.find(cpu.processor_id());
    if (pending == pending_waits_.end())
        return false;
    if (pending->second.status_address != 0 &&
        !memory_.write32(pending->second.status_address, wait_status)) {
        bsd_error(cpu, efault);
    } else {
        bsd_success(cpu, child_pid);
    }
    pending_waits_.erase(pending);
    process_.waiting_for_events = !pending_waits_.empty();
    output_.write("[process] reap parent=" + std::to_string(process_.pid) +
                  " child=" + std::to_string(child_pid) + "\n");
    return true;
}

bool CompatibilityKernel::fail_wait(Cpu& cpu, std::uint32_t error)
{
    const auto pending = pending_waits_.find(cpu.processor_id());
    if (pending == pending_waits_.end())
        return false;
    bsd_error(cpu, error);
    pending_waits_.erase(pending);
    process_.waiting_for_events = !pending_waits_.empty();
    return true;
}

std::optional<KernelSharedState::DescriptorTransfer>
CompatibilityKernel::export_descriptor(std::uint32_t fd) const
{
    for (unsigned depth = 0; depth < 256; ++depth) {
        const auto duplicate = duplicated_descriptors_.find(fd);
        if (duplicate == duplicated_descriptors_.end())
            break;
        fd = duplicate->second;
    }
    if (const auto file = file_descriptors_.find(fd);
        file != file_descriptors_.end()) {
        KernelSharedState::DescriptorTransfer transfer;
        transfer.kind = KernelSharedState::DescriptorTransfer::Kind::File;
        transfer.file_path = file->second;
        transfer.file_offset =
            file_offsets_.contains(fd) ? file_offsets_.at(fd) : 0;
        transfer.file_status_flags =
            file_status_flags_.contains(fd) ? file_status_flags_.at(fd) : 0;
        if (const auto description = regular_file_open_descriptions_.find(fd);
            description != regular_file_open_descriptions_.end()) {
            transfer.regular_file_open_description = description->second;
        }
        if (const auto block = virtual_block_descriptors_.find(fd);
            block != virtual_block_descriptors_.end()) {
            transfer.block_device = block->second;
        }
        return transfer;
    }
    const auto virtual_descriptor = virtual_descriptors_.find(fd);
    if (virtual_descriptor == virtual_descriptors_.end())
        return std::nullopt;
    KernelSharedState::DescriptorTransfer transfer;
    transfer.kind = KernelSharedState::DescriptorTransfer::Kind::Virtual;
    transfer.virtual_type = virtual_descriptor->second;
    transfer.file_status_flags = file_status_flags_.contains(fd)
                                     ? file_status_flags_.at(fd)
                                     : darwin::open_flag::read_write;
    if (const auto baseband = baseband_open_description(fd))
        transfer.baseband_open_description = baseband;
    if (const auto endpoint = socket_pair_endpoints_.find(fd);
        endpoint != socket_pair_endpoints_.end()) {
        transfer.socket_endpoint = endpoint->second;
    }
    if (const auto listener = unix_listener_states_.find(fd);
        listener != unix_listener_states_.end()) {
        transfer.unix_listener_state = listener->second;
    }
    if (const auto state = route_socket_states_.find(fd);
        state != route_socket_states_.end()) {
        transfer.route_socket_state = state->second;
    }
    if (const auto socket = virtual_udp_sockets_.find(fd);
        socket != virtual_udp_sockets_.end()) {
        transfer.virtual_udp_socket = socket->second;
    }
    if (const auto bound = bound_socket_names_.find(fd);
        bound != bound_socket_names_.end()) {
        transfer.bound_name = bound->second;
    }
    transfer.listening = listening_sockets_.contains(fd);
    if (const auto queue = kqueues_.find(fd); queue != kqueues_.end()) {
        transfer.kqueue_registrations = queue->second;
    }
    return transfer;
}

std::optional<std::uint32_t> CompatibilityKernel::import_descriptor(
    const KernelSharedState::DescriptorTransfer& transfer)
{
    const auto fd = allocate_file_descriptor();
    if (!fd)
        return std::nullopt;
    if (transfer.kind == KernelSharedState::DescriptorTransfer::Kind::File) {
        file_descriptors_[*fd] = transfer.file_path;
        file_offsets_[*fd] = transfer.file_offset;
        file_status_flags_[*fd] = transfer.file_status_flags;
        if (transfer.regular_file_open_description) {
            regular_file_open_descriptions_[*fd] =
                transfer.regular_file_open_description;
        } else {
            static_cast<void>(ensure_regular_file_open_description(*fd));
        }
        if (transfer.block_device) {
            virtual_block_descriptors_[*fd] = *transfer.block_device;
        }
    } else {
        virtual_descriptors_[*fd] = transfer.virtual_type;
        file_status_flags_[*fd] = transfer.file_status_flags;
        if (transfer.baseband_open_description) {
            baseband_open_descriptions_[*fd] =
                transfer.baseband_open_description;
        }
        if (transfer.virtual_type == "route-socket") {
            std::lock_guard route_lock { shared_state_->route_socket_mutex };
            route_socket_states_[*fd] =
                transfer.route_socket_state
                    ? transfer.route_socket_state
                    : std::make_shared<KernelSharedState::RouteSocketState>(
                          KernelSharedState::RouteSocketState {
                              shared_state_->next_route_socket_identifier++,
                              shared_state_->next_route_message_identifier,
                              0 });
        }
        if (transfer.socket_endpoint) {
            socket_pair_endpoints_[*fd] = *transfer.socket_endpoint;
        }
        if (transfer.virtual_udp_socket) {
            virtual_udp_sockets_[*fd] = transfer.virtual_udp_socket;
        }
        if (transfer.unix_listener_state) {
            unix_listener_states_[*fd] = transfer.unix_listener_state;
        }
        if (!transfer.bound_name.empty()) {
            bound_socket_names_[*fd] = transfer.bound_name;
        }
        if (transfer.listening)
            listening_sockets_.insert(*fd);
        if (!transfer.kqueue_registrations.empty() ||
            transfer.virtual_type == "kqueue") {
            kqueues_[*fd] = transfer.kqueue_registrations;
        }
    }
    descriptor_flags_[*fd] = 0;
    return fd;
}

bool CompatibilityKernel::deliver_pending_io(Cpu& cpu)
{
    std::lock_guard lock { mutex_ };
    const auto delivered = deliver_pending_io_locked(cpu);
    if (delivered) {
        pending_io_poll_cache_.erase(cpu.processor_id());
        note_timer_deadline_transition();
    }
    refresh_pending_event_processor_locked(cpu.processor_id());
    return delivered;
}

bool CompatibilityKernel::deliver_pending_event(Cpu& cpu)
{
    std::lock_guard lock { mutex_ };
    bool delivered = false;
    const auto processor = cpu.processor_id();
    if (pending_mach_receives_.contains(processor) &&
        hid_event_system_hle_.prepare_pending_event(
            cpu, process_.pid, 0x80U) &&
        userland_hle_.dispatch(cpu, process_.pid, 0x80U)) {
        pending_mach_receives_.erase(processor);
        process_.waiting_for_events = !pending_mach_receives_.empty();
        cpu.clear_halt();
        pending_io_poll_cache_.erase(processor);
        note_timer_deadline_transition();
        delivered = true;
    } else if (pending_mach_receives_.contains(processor)) {
        delivered = deliver_pending_mach_if_ready_locked(cpu, true);
        if (delivered)
            note_timer_deadline_transition();
    } else if (pending_io_poll_required_locked(
                   processor, pending_io_deadline_locked(processor))) {
        const auto io_generation =
            shared_state_->io_event_generation_snapshot();
        const auto mach_generation =
            shared_state_->mach_queue_generation_snapshot();
        delivered = deliver_pending_io_locked(cpu);
        if (delivered) {
            pending_io_poll_cache_.erase(processor);
            note_timer_deadline_transition();
        } else {
            remember_pending_io_not_ready_locked(
                processor, io_generation, mach_generation);
        }
    }
    refresh_pending_event_processor_locked(processor);
    return delivered;
}

std::vector<std::size_t>
CompatibilityKernel::pending_event_poll_candidates()
{
    std::lock_guard lock { mutex_ };
    const auto io_generation = shared_state_->io_event_generation_snapshot();
    const auto mach_generation =
        shared_state_->mach_queue_generation_snapshot();
    const auto host_now = std::chrono::steady_clock::now();
    const auto guest_now = shared_state_->clock.now();
    const auto topology_changed = !pending_event_poll_observed_ ||
                                  pending_event_poll_topology_generation_ !=
                                      pending_event_topology_generation_;
    const auto readiness_changed = !pending_event_poll_observed_ ||
                                   pending_event_poll_io_generation_ !=
                                       io_generation ||
                                   pending_event_poll_mach_generation_ !=
                                       mach_generation;
    const auto deadline_due = pending_event_poll_deadline_ &&
                              guest_now >= *pending_event_poll_deadline_;
    const auto sample_deadline = hid_event_system_hle_.next_sample_deadline();
    const auto sample_due = sample_deadline && guest_now >= *sample_deadline;
    const auto host_probe_due = host_now >= pending_event_host_probe_;
    if (!topology_changed && !readiness_changed && !deadline_due && !sample_due &&
        !host_probe_due) {
        return { };
    }

    pending_event_poll_observed_ = true;
    pending_event_poll_topology_generation_ =
        pending_event_topology_generation_;
    pending_event_poll_io_generation_ = io_generation;
    pending_event_poll_mach_generation_ = mach_generation;

    std::vector<std::size_t> processors;
    processors.reserve(pending_event_processors_.size());
    std::optional<std::uint64_t> next_deadline;
    bool requires_host_probe = false;
    for (const auto processor : pending_event_processors_) {
        const auto deadline = pending_io_deadline_locked(processor);
        if (pending_mach_receives_.contains(processor) ||
            pending_io_poll_required_locked(processor, deadline)) {
            processors.push_back(processor);
        }
        if (deadline && *deadline > guest_now &&
            (!next_deadline || *deadline < *next_deadline)) {
            next_deadline = deadline;
        }
        requires_host_probe = requires_host_probe ||
                              pending_io_requires_host_poll_locked(processor);
    }
    pending_event_poll_deadline_ = next_deadline;
    constexpr auto host_probe_interval = std::chrono::milliseconds { 1 };
    pending_event_host_probe_ = requires_host_probe
                                    ? host_now + host_probe_interval
                                    : std::chrono::steady_clock::time_point::max();
    return processors;
}

bool CompatibilityKernel::has_pending_event_locked(
    std::size_t processor) const
{
    return pending_mach_receives_.contains(processor) ||
           pending_record_locks_.contains(processor) ||
           pending_flocks_.contains(processor) ||
           pending_host_connects_.contains(processor) ||
           pending_host_accepts_.contains(processor) ||
           pending_host_writes_.contains(processor) ||
           pending_baseband_writes_.contains(processor) ||
           pending_unix_accepts_.contains(processor) ||
           pending_semaphore_waits_.contains(processor) ||
           pending_psynch_waits_.contains(processor) ||
           pending_signal_suspends_.contains(processor) ||
           pending_timers_.contains(processor) ||
           pending_selects_.contains(processor) ||
           pending_polls_.contains(processor) ||
           pending_socket_reads_.contains(processor) ||
           pending_recvmsgs_.contains(processor) ||
           pending_kevents_.contains(processor);
}

void CompatibilityKernel::refresh_pending_event_processor_locked(
    std::size_t processor)
{
    const auto pending = has_pending_event_locked(processor);
    const auto indexed = pending_event_processors_.contains(processor);
    if (pending == indexed)
        return;
    if (pending)
        pending_event_processors_.insert(processor);
    else
        pending_event_processors_.erase(processor);
    ++pending_event_topology_generation_;
}

bool CompatibilityKernel::pending_io_poll_required_locked(
    std::size_t processor, std::optional<std::uint64_t> deadline) const
{
    const auto cached = pending_io_poll_cache_.find(processor);
    if (cached == pending_io_poll_cache_.end())
        return true;
    if (cached->second.io_generation !=
            shared_state_->io_event_generation_snapshot() ||
        cached->second.mach_generation !=
            shared_state_->mach_queue_generation_snapshot()) {
        return true;
    }
    if (deadline && shared_state_->clock.now() >= *deadline) {
        return true;
    }
    return cached->second.host_probe_required &&
           std::chrono::steady_clock::now() >=
               cached->second.next_host_probe;
}

void CompatibilityKernel::remember_pending_io_not_ready_locked(
    std::size_t processor, std::uint64_t io_generation,
    std::uint64_t mach_generation)
{
    if (io_generation != shared_state_->io_event_generation_snapshot() ||
        mach_generation != shared_state_->mach_queue_generation_snapshot()) {
        pending_io_poll_cache_.erase(processor);
        return;
    }
    constexpr auto host_probe_interval = std::chrono::milliseconds { 1 };
    const auto host_probe_required =
        pending_io_requires_host_poll_locked(processor);
    pending_io_poll_cache_[processor] = PendingIoPollCache {
        io_generation, mach_generation,
        host_probe_required
            ? std::chrono::steady_clock::now() + host_probe_interval
            : std::chrono::steady_clock::time_point::max(),
        host_probe_required
    };
}

std::optional<std::uint64_t>
CompatibilityKernel::pending_io_deadline_locked(std::size_t processor) const
{
    std::optional<std::uint64_t> deadline;
    const auto consider = [&deadline](std::optional<std::uint64_t> candidate) {
        if (candidate && (!deadline || *candidate < *deadline))
            deadline = candidate;
    };
    const auto consider_queue = [&](std::uint32_t fd) {
        if (const auto queue = kqueues_.find(fd); queue != kqueues_.end()) {
            for (const auto& event : queue->second) {
                if (event.enabled && event.timer)
                    consider(event.timer->deadline());
            }
        }
    };
    if (const auto found = pending_timers_.find(processor);
        found != pending_timers_.end()) {
        consider(found->second.deadline);
    }
    if (const auto found = pending_semaphore_waits_.find(processor);
        found != pending_semaphore_waits_.end()) {
        consider(found->second.deadline);
    }
    if (const auto found = pending_psynch_waits_.find(processor);
        found != pending_psynch_waits_.end()) {
        consider(found->second.deadline);
    }
    if (const auto found = pending_kevents_.find(processor);
        found != pending_kevents_.end()) {
        consider(found->second.deadline);
        consider_queue(found->second.queue_fd);
    }
    if (const auto found = pending_selects_.find(processor);
        found != pending_selects_.end()) {
        consider(found->second.deadline);
        for (std::size_t word = 0; word < found->second.read_words.size(); ++word) {
            auto bits = found->second.read_words[word];
            while (bits != 0U) {
                const auto bit = static_cast<std::uint32_t>(std::countr_zero(bits));
                const auto fd = static_cast<std::uint32_t>(word * 32U) + bit;
                if (fd < found->second.descriptor_count)
                    consider_queue(fd);
                bits &= bits - 1U;
            }
        }
    }
    if (const auto found = pending_polls_.find(processor);
        found != pending_polls_.end()) {
        consider(found->second.deadline);
        for (const auto& entry : found->second.entries) {
            if (entry.fd >= 0 && (entry.events & 1U) != 0U)
                consider_queue(static_cast<std::uint32_t>(entry.fd));
        }
    }
    if (const auto found = pending_socket_reads_.find(processor);
        found != pending_socket_reads_.end()) {
        consider(found->second.deadline);
    }
    if (const auto found = pending_mach_receives_.find(processor);
        found != pending_mach_receives_.end()) {
        consider(found->second.deadline);
    }
    if (!scheduled_wifi_driver_events_.empty())
        consider(scheduled_wifi_driver_events_.begin()->first);
    return deadline;
}

bool CompatibilityKernel::pending_io_requires_host_poll_locked(
    std::size_t processor) const
{
    if (pending_host_connects_.contains(processor) ||
        pending_host_accepts_.contains(processor) ||
        pending_host_writes_.contains(processor) ||
        pending_baseband_writes_.contains(processor)) {
        return true;
    }
    if (const auto found = pending_socket_reads_.find(processor);
        found != pending_socket_reads_.end()) {
        return descriptor_requires_host_poll(found->second.fd);
    }
    if (const auto found = pending_recvmsgs_.find(processor);
        found != pending_recvmsgs_.end()) {
        return descriptor_requires_host_poll(found->second.fd);
    }
    if (const auto found = pending_kevents_.find(processor);
        found != pending_kevents_.end()) {
        return descriptor_requires_host_poll(found->second.queue_fd);
    }
    if (const auto found = pending_polls_.find(processor);
        found != pending_polls_.end()) {
        return std::any_of(found->second.entries.begin(),
            found->second.entries.end(), [this](const auto& entry) {
                return entry.fd >= 0 && descriptor_requires_host_poll(
                                            static_cast<std::uint32_t>(
                                                entry.fd));
            });
    }
    if (const auto found = pending_selects_.find(processor);
        found != pending_selects_.end()) {
        for (std::size_t word = 0; word < found->second.read_words.size();
            ++word) {
            const auto requested = found->second.read_words[word] |
                                   found->second.write_words[word];
            for (std::uint32_t bit = 0; bit < 32U; ++bit) {
                const auto descriptor =
                    static_cast<std::uint32_t>(word * 32U + bit);
                if (descriptor >= found->second.descriptor_count)
                    break;
                if ((requested & (std::uint32_t { 1 } << bit)) != 0U &&
                    descriptor_requires_host_poll(descriptor)) {
                    return true;
                }
            }
        }
    }
    return false;
}

std::optional<std::uint64_t>
CompatibilityKernel::take_last_delivered_graphics_input(std::size_t processor)
{
    std::lock_guard lock { mutex_ };
    const auto found = last_delivered_graphics_inputs_.find(processor);
    if (found == last_delivered_graphics_inputs_.end())
        return std::nullopt;
    const auto sequence = found->second;
    last_delivered_graphics_inputs_.erase(found);
    return sequence;
}

bool CompatibilityKernel::deliver_pending_io_locked(Cpu& cpu)
{
    bool timer_topology_changed = false;
    for (auto event = scheduled_wifi_driver_events_.begin();
        event != scheduled_wifi_driver_events_.end();) {
        if (shared_state_->clock.now() < event->first)
            break;
        inject_wifi_driver_event(0, event->second);
        event = scheduled_wifi_driver_events_.erase(event);
        timer_topology_changed = true;
    }
    if (timer_topology_changed)
        note_timer_deadline_transition();
    if (const auto pending = pending_signal_suspends_.find(cpu.processor_id());
        pending != pending_signal_suspends_.end() &&
        pending->second.interrupted) {
        bsd_error(cpu, darwin::error::interrupted);
        pending_signal_suspends_.erase(pending);
        process_.waiting_for_events = false;
        cpu.clear_halt();
        return true;
    }
    if (const auto pending = pending_record_locks_.find(cpu.processor_id());
        pending != pending_record_locks_.end()) {
        if (!shared_state_->advisory_file_locks->try_set_record_lock(
                pending->second.permanent_file_id, process_.pid,
                pending->second.range)) {
            return false;
        }
        output_.write(
            "[vfs] fcntl lock wake pid=" + std::to_string(process_.pid) +
            " fd=" + std::to_string(pending->second.fd) + "\n");
        bsd_success(cpu, 0);
        pending_record_locks_.erase(pending);
        process_.waiting_for_events = false;
        cpu.clear_halt();
        return true;
    }
    if (const auto pending = pending_flocks_.find(cpu.processor_id());
        pending != pending_flocks_.end()) {
        if (!shared_state_->advisory_file_locks->try_acquire(
                *pending->second.description, pending->second.kind)) {
            return false;
        }
        output_.write("[vfs] flock wake pid=" + std::to_string(process_.pid) +
                      " fd=" + std::to_string(pending->second.fd) + "\n");
        bsd_success(cpu, 0);
        pending_flocks_.erase(pending);
        process_.waiting_for_events = false;
        cpu.clear_halt();
        return true;
    }
    if (const auto pending = pending_host_connects_.find(cpu.processor_id());
        pending != pending_host_connects_.end()) {
        const auto host = host_sockets_.find(pending->second.fd);
        if (host == host_sockets_.end()) {
            bsd_error(cpu, ebadf);
        } else {
            if (!host->second->writable())
                return false;
            const auto completed = host->second->finish_connect();
            if (completed.status == HostSocketStatus::WouldBlock)
                return false;
            if (completed.status == HostSocketStatus::Error) {
                bsd_error(cpu, completed.darwin_error);
            } else {
                bsd_success(cpu, 0);
            }
        }
        pending_host_connects_.erase(pending);
        process_.waiting_for_events = false;
        cpu.clear_halt();
        return true;
    }
    if (const auto pending = pending_host_accepts_.find(cpu.processor_id());
        pending != pending_host_accepts_.end()) {
        const auto host = host_sockets_.find(pending->second.fd);
        if (host == host_sockets_.end()) {
            bsd_error(cpu, ebadf);
        } else {
            const auto accepted = host->second->accept();
            if (accepted.status == HostSocketStatus::WouldBlock)
                return false;
            if (accepted.status == HostSocketStatus::Error) {
                bsd_error(cpu, accepted.darwin_error);
            } else if (const auto fd =
                           install_host_socket(accepted.accepted_socket)) {
                if (!copy_socket_address(pending->second.address,
                        pending->second.length_address, accepted.address)) {
                    host_sockets_.erase(*fd);
                    virtual_descriptors_.erase(*fd);
                    file_status_flags_.erase(*fd);
                    descriptor_flags_.erase(*fd);
                    bsd_error(cpu, efault);
                } else {
                    bsd_success(cpu, *fd);
                }
            } else {
                bsd_error(cpu, 24);
            }
        }
        pending_host_accepts_.erase(pending);
        process_.waiting_for_events = false;
        cpu.clear_halt();
        return true;
    }
    if (const auto pending = pending_host_writes_.find(cpu.processor_id());
        pending != pending_host_writes_.end()) {
        if (!pending->second.socket) {
            bsd_error(cpu, ebadf);
        } else {
            const auto sent = pending->second.socket->send(
                pending->second.bytes, pending->second.destination);
            if (sent.status == HostSocketStatus::WouldBlock)
                return false;
            count_interface_traffic(
                pending->second.socket->loopback_for(
                    pending->second.destination),
                true, sent.transferred,
                sent.status == HostSocketStatus::Error);
            if (sent.status == HostSocketStatus::Error) {
                bsd_error(cpu, sent.darwin_error);
            } else {
                bsd_success(cpu, static_cast<std::uint32_t>(sent.transferred));
                output_.write(
                    "[network] write wake pid=" + std::to_string(process_.pid) +
                    " fd=" + std::to_string(pending->second.fd) +
                    " bytes=" + std::to_string(sent.transferred) + "\n");
            }
        }
        pending_host_writes_.erase(pending);
        process_.waiting_for_events = false;
        cpu.clear_halt();
        return true;
    }
    if (const auto pending = pending_baseband_writes_.find(cpu.processor_id());
        pending != pending_baseband_writes_.end()) {
        const auto endpoint = baseband_open_description(pending->second.fd);
        if (!endpoint || !endpoint->writable()) {
            bsd_error(cpu, darwin::error::no_such_device_or_address);
            pending_baseband_writes_.erase(pending);
            process_.waiting_for_events = false;
            cpu.clear_halt();
            return true;
        }
        const auto descriptor = virtual_descriptors_.find(pending->second.fd);
        if (descriptor == virtual_descriptors_.end() ||
            descriptor->second != bsd::baseband_device::descriptor_kind) {
            bsd_error(cpu, ebadf);
        } else {
            const auto written = endpoint->write(pending->second.bytes);
            if (written != pending->second.bytes.size()) {
                bsd_error(cpu, darwin::error::io);
            } else {
                bsd_success(cpu, static_cast<std::uint32_t>(written));
                output_.write("[baseband] write wake pid=" +
                              std::to_string(process_.pid) +
                              " fd=" + std::to_string(pending->second.fd) +
                              " bytes=" + std::to_string(written) + "\n");
            }
        }
        pending_baseband_writes_.erase(pending);
        process_.waiting_for_events = false;
        cpu.clear_halt();
        return true;
    }
    if (const auto pending = pending_unix_accepts_.find(cpu.processor_id());
        pending != pending_unix_accepts_.end()) {
        if (!complete_unix_accept(cpu, pending->second.fd,
                pending->second.address, pending->second.length_address)) {
            return false;
        }
        pending_unix_accepts_.erase(pending);
        process_.waiting_for_events = false;
        cpu.clear_halt();
        return true;
    }
    if (const auto pending = pending_semaphore_waits_.find(cpu.processor_id());
        pending != pending_semaphore_waits_.end()) {
        const auto waiter = std::pair { process_.pid,
            static_cast<std::uint32_t>(cpu.processor_id()) };
        bool awakened = false;
        bool terminated = false;
        bool timed_out = false;
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            terminated =
                shared_state_->semaphore_terminations.erase(waiter) != 0;
            awakened = !terminated &&
                       shared_state_->semaphore_wakeups.erase(waiter) != 0;
            timed_out = !terminated && !awakened && pending->second.deadline &&
                        shared_state_->clock.now() >= *pending->second.deadline;
            if (timed_out) {
                if (auto semaphore = shared_state_->mach_semaphores.find(
                        pending->second.semaphore);
                    semaphore != shared_state_->mach_semaphores.end()) {
                    std::erase(semaphore->second.waiters, waiter);
                }
            }
        }
        if (!terminated && !awakened && !timed_out)
            return false;
        if (pending->second.bsd_result) {
            if (terminated)
                bsd_error(cpu, darwin::error::invalid_argument);
            else if (timed_out)
                bsd_error(cpu, 60);
            else
                bsd_success(cpu, 0);
        } else {
            cpu.registers()[0] = terminated  ? darwin::mach::terminated
                                 : timed_out ? darwin::mach::operation_timed_out
                                             : darwin::mach::success;
        }
        pending_semaphore_waits_.erase(pending);
        process_.waiting_for_events = false;
        cpu.clear_halt();
        return true;
    }
    if (const auto pending = pending_psynch_waits_.find(cpu.processor_id());
        pending != pending_psynch_waits_.end()) {
        const DarwinPsynchThread thread { process_.pid,
            static_cast<std::uint32_t>(cpu.processor_id()) };
        const auto result = shared_state_->psynch_runtime->take_result(thread);
        const auto timed_out = !result && pending->second.deadline &&
                               shared_state_->clock.now() >=
                                   *pending->second.deadline;
        if (!result && !timed_out)
            return false;
        if (timed_out) {
            shared_state_->psynch_runtime->cancel_wait(thread);
            bsd_error(cpu, 60U);
        } else {
            bsd_success(cpu, *result);
        }
        pending_psynch_waits_.erase(pending);
        process_.waiting_for_events = false;
        cpu.clear_halt();
        return true;
    }
    if (const auto timer = pending_timers_.find(cpu.processor_id());
        timer != pending_timers_.end()) {
        bool bootstrap_ready = false;
        if (timer->second.bootstrap_retry) {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            const auto generation =
                shared_state_->bootstrap_service_generations.find(
                    timer->second.bootstrap_retry->service_name);
            bootstrap_ready =
                generation !=
                    shared_state_->bootstrap_service_generations.end() &&
                generation->second >
                    timer->second.bootstrap_retry->observed_generation;
        }
        if (shared_state_->clock.now() < timer->second.deadline &&
            !bootstrap_ready) {
            return false;
        }
        const auto pending = timer->second;
        pending_timers_.erase(timer);
        process_.waiting_for_events = false;
        if (bootstrap_ready) {
            output_.write("[timer] bootstrap-retry-ready pid=" +
                          std::to_string(process_.pid) + " service=" +
                          pending.bootstrap_retry->service_name + "\n");
        }
        if (pending.kind == PendingTimerKind::ClockSleep &&
            pending.wakeup_time_address) {
            const auto now = pending.calendar_clock
                                 ? shared_state_->clock.wall_time()
                                 : shared_state_->clock.now();
            const auto seconds = static_cast<std::uint32_t>(
                now / darwin::mach::clock::nanoseconds_per_second);
            const auto nanoseconds = static_cast<std::uint32_t>(
                now % darwin::mach::clock::nanoseconds_per_second);
            static_cast<void>(memory_.write32(
                *pending.wakeup_time_address +
                    darwin::mach::clock::timespec_seconds_offset,
                seconds));
            static_cast<void>(memory_.write32(
                *pending.wakeup_time_address +
                    darwin::mach::clock::timespec_nanoseconds_offset,
                nanoseconds));
        }
        cpu.registers()[0] = darwin::mach::success;
        cpu.clear_halt();
        return true;
    }
    if (const auto pending = pending_selects_.find(cpu.processor_id());
        pending != pending_selects_.end()) {
        std::uint32_t ready_count = 0;
        std::vector<std::uint32_t> ready_read_words(
            pending->second.read_words.size());
        std::vector<std::uint32_t> ready_write_words(
            pending->second.write_words.size());
        for (std::size_t word_index = 0;
            word_index < pending->second.read_words.size(); ++word_index) {
            for (std::uint32_t bit = 0; bit < 32; ++bit) {
                const auto fd =
                    static_cast<std::uint32_t>(word_index * 32U + bit);
                if (fd >= pending->second.descriptor_count)
                    continue;
                if ((pending->second.read_words[word_index] & (1U << bit)) !=
                        0 &&
                    descriptor_readable(fd)) {
                    ready_read_words[word_index] |= 1U << bit;
                    ++ready_count;
                }
                if ((pending->second.write_words[word_index] & (1U << bit)) !=
                        0 &&
                    descriptor_writable(fd)) {
                    ready_write_words[word_index] |= 1U << bit;
                    ++ready_count;
                }
            }
        }
        const auto timed_out =
            pending->second.deadline &&
            shared_state_->clock.now() >= *pending->second.deadline;
        if (ready_count == 0 && !timed_out)
            return false;
        bool copied = true;
        for (std::size_t index = 0; index < ready_read_words.size(); ++index) {
            if (pending->second.read_address != 0) {
                copied =
                    copied &&
                    memory_.write32(pending->second.read_address +
                                        static_cast<std::uint32_t>(index * 4U),
                        ready_read_words[index]);
            }
            if (pending->second.write_address != 0) {
                copied =
                    copied &&
                    memory_.write32(pending->second.write_address +
                                        static_cast<std::uint32_t>(index * 4U),
                        ready_write_words[index]);
            }
            if (pending->second.exception_address != 0) {
                copied =
                    copied &&
                    memory_.write32(pending->second.exception_address +
                                        static_cast<std::uint32_t>(index * 4U),
                        0);
            }
        }
        if (copied)
            bsd_success(cpu, ready_count);
        else
            bsd_error(cpu, efault);
        pending_selects_.erase(pending);
        process_.waiting_for_events = false;
        cpu.clear_halt();
        return true;
    }
    if (const auto pending = pending_polls_.find(cpu.processor_id());
        pending != pending_polls_.end()) {
        std::uint32_t ready_count = 0;
        std::vector<std::uint16_t> revents(pending->second.entries.size());
        for (std::size_t index = 0; index < pending->second.entries.size();
            ++index) {
            revents[index] =
                descriptor_poll_revents(pending->second.entries[index].fd,
                    pending->second.entries[index].events);
            if (revents[index] != 0)
                ++ready_count;
        }
        const auto timed_out =
            pending->second.deadline &&
            shared_state_->clock.now() >= *pending->second.deadline;
        if (ready_count == 0 && !timed_out)
            return false;
        bool copied = true;
        for (std::size_t index = 0; index < revents.size(); ++index) {
            copied = copied &&
                     memory_.write16(pending->second.address +
                                         static_cast<std::uint32_t>(
                                             index * darwin::poll::pollfd_size +
                                             darwin::poll::revents_offset),
                         revents[index]);
        }
        if (copied)
            bsd_success(cpu, ready_count);
        else
            bsd_error(cpu, efault);
        pending_polls_.erase(pending);
        process_.waiting_for_events = false;
        cpu.clear_halt();
        return true;
    }
    if (const auto pending = pending_socket_reads_.find(cpu.processor_id());
        pending != pending_socket_reads_.end()) {
        if (const auto descriptor =
                virtual_descriptors_.find(pending->second.fd);
            descriptor != virtual_descriptors_.end() &&
            descriptor->second == bsd::offline_serial_device::descriptor_kind) {
            if (auto bytes = offline_serial_state_.read(pending->second.size);
                !bytes.empty()) {
                if (!memory_.copy_in(pending->second.address, bytes)) {
                    bsd_error(cpu, efault);
                } else {
                    bsd_success(cpu, static_cast<std::uint32_t>(bytes.size()));
                }
                pending_socket_reads_.erase(pending);
                process_.waiting_for_events = false;
                cpu.clear_halt();
                return true;
            }
            if (!pending->second.deadline ||
                shared_state_->clock.now() < *pending->second.deadline) {
                return false;
            }
            bsd_success(cpu, 0);
            pending_socket_reads_.erase(pending);
            process_.waiting_for_events = false;
            cpu.clear_halt();
            return true;
        }
        if (!receive_socket_bytes(cpu, pending->second.fd,
                pending->second.address, pending->second.size,
                pending->second.source_address,
                pending->second.source_length_address)) {
            return false;
        }
        pending_socket_reads_.erase(pending);
        process_.waiting_for_events = false;
        cpu.clear_halt();
        return true;
    }
    if (const auto pending = pending_recvmsgs_.find(cpu.processor_id());
        pending != pending_recvmsgs_.end()) {
        if (!receive_socket_message(
                cpu, pending->second.fd, pending->second.message_address)) {
            return false;
        }
        pending_recvmsgs_.erase(pending);
        process_.waiting_for_events = false;
        cpu.clear_halt();
        return true;
    }
    const auto pending_kevent = pending_kevents_.find(cpu.processor_id());
    if (pending_kevent == pending_kevents_.end())
        return false;
    const auto ready = collect_ready_kevents(cpu.processor_id(), pending_kevent->second.queue_fd,
        pending_kevent->second.event_address,
        pending_kevent->second.event_count, pending_kevent->second.extended, true);
    if (!ready) {
        bsd_error(cpu, kqueues_.contains(pending_kevent->second.queue_fd)
                           ? efault
                           : ebadf);
    } else if (*ready != 0) {
        bsd_success(cpu, *ready);
    } else if (pending_kevent->second.deadline &&
               shared_state_->clock.now() >= *pending_kevent->second.deadline) {
        bsd_success(cpu, 0);
    } else {
        return false;
    }
    pending_kevents_.erase(pending_kevent);
    process_.waiting_for_events = false;
    cpu.clear_halt();
    return true;
}

std::string CompatibilityKernel::wait_reason(std::size_t processor) const
{
    if (const auto pending = pending_flocks_.find(processor);
        pending != pending_flocks_.end()) {
        return "flock(fd=" + std::to_string(pending->second.fd) + ")";
    }
    if (const auto pending = pending_record_locks_.find(processor);
        pending != pending_record_locks_.end()) {
        return "fcntl-lock(fd=" + std::to_string(pending->second.fd) + ")";
    }
    if (const auto pending = pending_host_connects_.find(processor);
        pending != pending_host_connects_.end()) {
        return "connect(fd=" + std::to_string(pending->second.fd) + ")";
    }
    if (const auto pending = pending_host_accepts_.find(processor);
        pending != pending_host_accepts_.end()) {
        return "accept(fd=" + std::to_string(pending->second.fd) + ")";
    }
    if (const auto pending = pending_host_writes_.find(processor);
        pending != pending_host_writes_.end()) {
        return "write(fd=" + std::to_string(pending->second.fd) + ")";
    }
    if (const auto pending = pending_baseband_writes_.find(processor);
        pending != pending_baseband_writes_.end()) {
        return "write(baseband fd=" + std::to_string(pending->second.fd) + ")";
    }
    if (const auto pending = pending_unix_accepts_.find(processor);
        pending != pending_unix_accepts_.end()) {
        return "accept(fd=" + std::to_string(pending->second.fd) + ")";
    }
    if (pending_signal_suspends_.contains(processor))
        return "sigsuspend";
    if (const auto pending = pending_semaphore_waits_.find(processor);
        pending != pending_semaphore_waits_.end()) {
        return "semaphore(port=" + std::to_string(pending->second.semaphore) +
               ")";
    }
    if (const auto pending = pending_psynch_waits_.find(processor);
        pending != pending_psynch_waits_.end()) {
        const auto kind = [&] {
            switch (pending->second.kind) {
            case DarwinPsynchWaitKind::Mutex:
                return "mutex";
            case DarwinPsynchWaitKind::Condition:
                return "condition";
            case DarwinPsynchWaitKind::ReadLock:
                return "rw-read";
            case DarwinPsynchWaitKind::WriteLock:
                return "rw-write";
            }
            return "unknown";
        }();
        return "psynch(" + std::string { kind } + ",address=" +
               std::to_string(pending->second.address) + ")";
    }
    if (const auto timer = pending_timers_.find(processor);
        timer != pending_timers_.end()) {
        const auto operation = [&] {
            switch (timer->second.kind) {
            case PendingTimerKind::MachWaitUntil:
                return "mach_wait_until";
            case PendingTimerKind::ThreadSwitch:
                return "thread_switch";
            case PendingTimerKind::ClockSleep:
                return "clock_sleep";
            }
            return "timer";
        }();
        return std::string { operation } +
               "(deadline=" + std::to_string(timer->second.deadline) + ")";
    }
    if (const auto pending = pending_selects_.find(processor);
        pending != pending_selects_.end()) {
        return "select(nfds=" +
               std::to_string(pending->second.descriptor_count) + ")";
    }
    if (const auto pending = pending_polls_.find(processor);
        pending != pending_polls_.end()) {
        return "poll(nfds=" + std::to_string(pending->second.entries.size()) +
               ")";
    }
    if (const auto pending = pending_recvmsgs_.find(processor);
        pending != pending_recvmsgs_.end()) {
        return "recvmsg(fd=" + std::to_string(pending->second.fd) + ")";
    }
    if (const auto pending = pending_socket_reads_.find(processor);
        pending != pending_socket_reads_.end()) {
        return "read(fd=" + std::to_string(pending->second.fd) + ")";
    }
    if (const auto pending = pending_kevents_.find(processor);
        pending != pending_kevents_.end()) {
        const auto queue = kqueues_.find(pending->second.queue_fd);
        const auto registrations =
            queue == kqueues_.end() ? 0U : queue->second.size();
        std::string reason = "kevent(fd=" + std::to_string(pending->second.queue_fd) +
            ",registrations=" + std::to_string(registrations);
        const std::lock_guard mach_lock { shared_state_->mach_mutex };
        if (queue != kqueues_.end()) {
            for (const auto& event : queue->second) {
                reason += ";ident=" + std::to_string(event.ident) +
                    ",filter=" + std::to_string(event.filter) +
                    ",flags=" + std::to_string(event.flags) +
                    ",fflags=" + std::to_string(event.filter_flags) +
                    ",enabled=" + std::to_string(event.enabled);
                if (event.filter != darwin::kqueue::filter_mach_port)
                    continue;
                const auto object = shared_state_->mach_namespaces.resolve(
                    process_.pid, static_cast<std::uint32_t>(event.ident));
                if (!object)
                    continue;
                reason += ",object=" + std::to_string(*object);
                if (const auto members = shared_state_->mach_port_sets.find(*object);
                    members != shared_state_->mach_port_sets.end()) {
                    reason += ",members=";
                    for (const auto member : members->second)
                        reason += std::to_string(member) + "/";
                }
            }
        }
        for (const auto& named : shared_state_->mach_namespaces.entries(process_.pid)) {
            const auto messages = shared_state_->mach_queues.find(named.entry.object);
            if (messages == shared_state_->mach_queues.end() || messages->second.empty())
                continue;
            reason += ";queued-name=" + std::to_string(named.name) +
                ",object=" + std::to_string(named.entry.object) +
                ",rights=" + std::to_string(named.entry.type) +
                ",depth=" + std::to_string(messages->second.size());
        }
        return reason + ")";
    }
    if (const auto pending = pending_mach_receives_.find(processor);
        pending != pending_mach_receives_.end()) {
        std::string reason =
            "mach_msg(port=" + std::to_string(pending->second.receive_name);
        const std::lock_guard mach_lock { shared_state_->mach_mutex };
        if (const auto object = shared_state_->mach_namespaces.resolve(
                process_.pid, pending->second.receive_name)) {
            reason += ",object=" + std::to_string(*object);
            if (const auto members =
                    shared_state_->mach_port_sets.find(*object);
                members != shared_state_->mach_port_sets.end()) {
                reason += ",members=" + std::to_string(members->second.size());
            }
        }
        return reason + ")";
    }
    if (const auto pending = pending_waits_.find(processor);
        pending != pending_waits_.end()) {
        return "wait4(target=" + std::to_string(pending->second.target_pid) +
               ")";
    }
    return process_.waiting_for_events ? "generic-event" : "none";
}

std::optional<std::uint64_t> CompatibilityKernel::next_timer_deadline() const
{
    return timer_deadline_snapshot().deadline;
}

void CompatibilityKernel::note_timer_deadline_transition() noexcept
{
    local_timer_deadline_cache_valid_ = false;
    shared_state_->note_kernel_event_transition();
}

CompatibilityKernel::TimerDeadlineSnapshot
CompatibilityKernel::timer_deadline_snapshot() const
{
    const auto consider = [](std::optional<std::uint64_t>& deadline,
                              std::optional<std::uint64_t> candidate) {
        if (candidate && (!deadline || *candidate < *deadline))
            deadline = candidate;
    };

    if (!local_timer_deadline_cache_valid_) {
        std::optional<std::uint64_t> local_deadline;
        for (const auto& [processor, timer] : pending_timers_) {
            static_cast<void>(processor);
            consider(local_deadline, timer.deadline);
        }
        for (const auto& [processor, wait] : pending_semaphore_waits_) {
            static_cast<void>(processor);
            consider(local_deadline, wait.deadline);
        }
        for (const auto& [processor, wait] : pending_psynch_waits_) {
            static_cast<void>(processor);
            consider(local_deadline, wait.deadline);
        }
        for (const auto& [processor, wait] : pending_kevents_) {
            static_cast<void>(wait);
            consider(local_deadline, pending_io_deadline_locked(processor));
        }
        for (const auto& [processor, wait] : pending_selects_) {
            static_cast<void>(wait);
            consider(local_deadline, pending_io_deadline_locked(processor));
        }
        for (const auto& [processor, wait] : pending_polls_) {
            static_cast<void>(wait);
            consider(local_deadline, pending_io_deadline_locked(processor));
        }
        if (!scheduled_wifi_driver_events_.empty())
            consider(local_deadline,
                scheduled_wifi_driver_events_.begin()->first);
        for (const auto& [processor, read] : pending_socket_reads_) {
            static_cast<void>(processor);
            consider(local_deadline, read.deadline);
        }
        for (const auto& [processor, receive] : pending_mach_receives_) {
            static_cast<void>(processor);
            consider(local_deadline, receive.deadline);
        }
        consider(local_deadline, kernel_bsd::interval_timer::next_deadline(
                                     *shared_state_, process_.pid));
        local_timer_deadline_cache_ = local_deadline;
        local_timer_deadline_cache_valid_ = true;
    }

    auto deadline = local_timer_deadline_cache_;
    std::uint64_t generation = 0;
    for (unsigned attempt = 0; attempt < 2U; ++attempt) {
        deadline = local_timer_deadline_cache_;
        consider(deadline, core_audio_hle_.next_io_proc_deadline());
        consider(deadline, hid_event_system_hle_.next_sample_deadline());
        {
            std::lock_guard mach_lock { shared_state_->mach_mutex };
            generation = shared_state_->kernel_event_generation_snapshot();
            if (!shared_state_->shared_timer_deadline_cache_valid ||
                shared_state_->shared_timer_deadline_cache_generation !=
                    generation) {
                std::optional<std::uint64_t> shared_deadline;
                for (const auto& [port, timer] : shared_state_->mach_timers) {
                    static_cast<void>(port);
                    consider(shared_deadline, timer.deadline);
                }
                consider(shared_deadline,
                    next_clock_alarm_deadline_locked(*shared_state_));
                consider(shared_deadline,
                    kernel_iokit::display::next_vsync_deadline_locked(
                        *shared_state_));
                consider(shared_deadline,
                    kernel_iokit::camera::next_capture_deadline_locked(
                        *shared_state_));
                shared_state_->shared_timer_deadline_cache = shared_deadline;
                shared_state_->shared_timer_deadline_cache_generation =
                    generation;
                shared_state_->shared_timer_deadline_cache_valid = true;
            }
            consider(deadline, shared_state_->shared_timer_deadline_cache);
        }
        const auto after =
            shared_state_->kernel_event_generation_snapshot();
        if (after == generation)
            return TimerDeadlineSnapshot { generation, deadline };
        generation = after;
    }
    return TimerDeadlineSnapshot { generation, deadline };
}

std::optional<std::uint64_t>
CompatibilityKernel::next_display_vsync_deadline() const
{
    std::lock_guard mach_lock { shared_state_->mach_mutex };
    return kernel_iokit::display::next_vsync_deadline_locked(*shared_state_);
}

void CompatibilityKernel::advance_absolute_time(std::uint64_t deadline)
{
    const auto next_service_deadline = next_timer_deadline();
    shared_state_->clock.advance_to(deadline);
    if (!next_service_deadline || *next_service_deadline > deadline)
        return;
    {
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        for (auto& [port, timer] : shared_state_->mach_timers) {
            if (!timer.deadline || *timer.deadline > deadline)
                continue;
            KernelSharedState::MachMessage message;
            message.bytes.resize(48);
            const auto put32 = [&](std::size_t offset, std::uint32_t value) {
                for (std::size_t byte = 0; byte < sizeof(value); ++byte) {
                    message.bytes[offset + byte] =
                        static_cast<std::byte>(value >> (byte * 8U));
                }
            };
            put32(0, 19);
            put32(4, static_cast<std::uint32_t>(message.bytes.size()));
            put32(8, port);
            put32(12, 0);
            put32(16, 0);
            put32(20, 0);
            message.destination = port;
            shared_state_->enqueue_mach_message_locked(
                port, std::move(message));
            timer.deadline.reset();
            output_.write(
                "[timer] expired port=" + std::to_string(port) + "\n");
        }
        deliver_due_clock_alarms_locked(*shared_state_, deadline);
        kernel_iokit::display::deliver_due_vsync_locked(
            *shared_state_, deadline);
    }
    service_time_dependent_devices(deadline);
    note_timer_deadline_transition();
}

void CompatibilityKernel::service_time_dependent_devices(std::uint64_t deadline)
{
    const auto next_service_deadline = next_timer_deadline();
    if (!next_service_deadline || *next_service_deadline > deadline)
        return;
    {
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        kernel_iokit::display::deliver_due_vsync_locked(
            *shared_state_, deadline);
    }
    kernel_iokit::camera::service_due_captures(
        *shared_state_, process_.pid, memory_, *surface_store_, deadline);
    if (kernel_bsd::interval_timer::service_due(
            *shared_state_, process_.pid, deadline)) {
        static_cast<void>(
            deliver_signal(kernel_bsd::interval_timer::expiration_signal));
    }
    schedule_due_audio_io(deadline);
    note_timer_deadline_transition();
}

void CompatibilityKernel::schedule_due_audio_io(std::uint64_t deadline)
{
    auto callback = core_audio_hle_.take_due_io_proc(deadline);
    if (!callback)
        return;
    if (callback->process_id != process_.pid || !thread_create_handler_) {
        core_audio_hle_.io_proc_schedule_failed(
            callback->process_id, callback->native, callback->io_proc_id);
        return;
    }
    const auto update_thread_pointer = [&](std::size_t processor) {
        if (!thread_pointer_update_handler_)
            return !callback->cthread_self.has_value();
        return thread_pointer_update_handler_(process_.pid,
            static_cast<std::uint32_t>(processor), callback->cthread_self);
    };
    if (callback->processor) {
        darwin::arm_thread::GeneralState state { };
        std::copy(callback->registers.begin(), callback->registers.end(),
            state.begin());
        state[darwin::arm_thread::cpsr_index] = callback->cpsr;
        const auto slot = static_cast<std::uint32_t>(*callback->processor);
        if (thread_state_update_handler_ && thread_wake_handler_ &&
            update_thread_pointer(*callback->processor) &&
            thread_state_update_handler_(process_.pid, slot, state)) {
            const auto wake_result = thread_wake_handler_(process_.pid, slot);
            if (wake_result.handled)
                return;
        }
        userland_hle_.unbind_thread_callback(*callback->processor);
        if (thread_terminate_handler_) {
            static_cast<void>(
                thread_terminate_handler_(process_.pid, *callback->processor));
        }
        core_audio_hle_.io_proc_schedule_failed(
            callback->process_id, callback->native, callback->io_proc_id);
        output_.write("[coreaudio-device] io-proc wake failed pid=" +
                      std::to_string(process_.pid) + "\n");
        return;
    }
    const auto processor =
        thread_create_handler_(callback->registers, callback->cpsr);
    if (!processor || !update_thread_pointer(*processor) ||
        !userland_hle_.bind_thread_callback(
            *processor, std::move(callback->completion))) {
        if (processor && thread_terminate_handler_) {
            static_cast<void>(
                thread_terminate_handler_(process_.pid, *processor));
        }
        core_audio_hle_.io_proc_schedule_failed(
            callback->process_id, callback->native, callback->io_proc_id);
        output_.write("[coreaudio-device] io-proc schedule failed pid=" +
                      std::to_string(process_.pid) + "\n");
        return;
    }
    core_audio_hle_.io_proc_thread_scheduled(callback->process_id,
        callback->native, callback->io_proc_id, *processor);
}

std::vector<std::string> CompatibilityKernel::fault_word_report(
    const AddressSpace& memory, const std::array<std::uint32_t, 16>& registers)
{
    std::uint32_t all_image_info_address { };
    {
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        if (auto record = shared_state_->processes.find(process_.pid);
            record != shared_state_->processes.end())
            all_image_info_address = record->second.dyld_all_image_info_address;
    }
    const auto images = all_image_info_address != 0U
                            ? read_guest_image_table(memory,
                                  all_image_info_address)
                            : GuestImageTable { };
    const auto* cache = dyld_shared_cache_.get();
    const auto architecture =
        arm_architecture_for_model(device_model_.processor.model);
    struct CacheImageEntry {
        std::uint32_t index { };
        std::string name;
    };
    std::vector<CacheImageEntry> cache_images;
    std::optional<std::int64_t> slide;
    if (cache != nullptr) {
        for (const auto& image : cache->images()) {
            const auto path = std::string { image.path };
            const auto slash = path.rfind('/');
            cache_images.push_back(CacheImageEntry {
                image.index,
                slash == std::string::npos ? path : path.substr(slash + 1) });
        }
        for (const auto& guest : images.images()) {
            if (const auto view = cache->find_image(guest.path)) {
                slide = static_cast<std::int64_t>(guest.load_address) -
                        static_cast<std::int64_t>(view->unslid_load_address);
                break;
            }
        }
    }
    struct CacheSegmentSpan {
        std::uint64_t begin { };
        std::uint64_t end { };
        std::size_t entry { };
    };
    std::optional<std::vector<CacheSegmentSpan>> cache_spans;
    const auto cache_symbol = [&](std::uint32_t address) -> std::string {
        if (!slide)
            return { };
        const auto unslid = static_cast<std::uint64_t>(
            static_cast<std::int64_t>(address) - *slide);
        if (!cache_spans) {
            cache_spans.emplace();
            for (std::size_t entry = 0; entry < cache_images.size(); ++entry) {
                const auto parsed =
                    cache->parse_image(cache_images[entry].index, architecture);
                if (!parsed)
                    continue;
                for (const auto& segment : parsed->segments()) {
                    if (segment.vm_size == 0U)
                        continue;
                    cache_spans->push_back(CacheSegmentSpan {
                        segment.vm_address,
                        static_cast<std::uint64_t>(segment.vm_address) +
                            segment.vm_size,
                        entry });
                }
            }
        }
        const auto span = std::find_if(cache_spans->begin(), cache_spans->end(),
            [unslid](const CacheSegmentSpan& candidate) {
                return unslid >= candidate.begin && unslid < candidate.end;
            });
        if (span == cache_spans->end())
            return { };
        const auto& entry = cache_images[span->entry];
        const auto parsed = cache->parse_image(entry.index, architecture);
        if (!parsed)
            return { };
        std::vector<MachSection> sections;
        for (const auto& segment : parsed->segments())
            sections.insert(sections.end(), segment.sections.begin(),
                segment.sections.end());
        const auto label = symbol_offset_label(parsed->symbols(), sections,
            static_cast<std::uint32_t>(unslid));
        return label.empty() ? std::string { } : entry.name + "`" + label;
    };
    return describe_fault_words(
        registers,
        [&memory](std::uint32_t address) { return memory.read32(address); },
        [&images, &cache_symbol](std::uint32_t address) -> std::string {
            if (auto symbol = cache_symbol(address); !symbol.empty())
                return symbol;
            const auto* image = images.find(address);
            if (image == nullptr)
                return { };
            const auto slash = image->path.rfind('/');
            const auto name = slash == std::string::npos
                                  ? image->path
                                  : image->path.substr(slash + 1);
            char offset[16];
            std::snprintf(offset, sizeof offset, "+0x%x",
                address - image->load_address);
            return name + offset;
        });
}

void CompatibilityKernel::inject_wifi_driver_event(
    std::uint32_t, std::uint32_t event)
{
    if (event == 0)
        return;
    namespace wifi_driver = darwin::network::apple80211_driver;
    for (const auto& [descriptor, kind] : virtual_descriptors_) {
        if (kind == wifi_driver::event_descriptor_kind) {
            auto& stream = wifi_driver_event_streams_[descriptor];
            if (!stream)
                stream = std::make_shared<wifi_driver::EventStream>();
            stream->enqueue(event);
        }
    }
    shared_state_->note_io_event_transition();
}

void CompatibilityKernel::reap_stopped_audio_threads()
{
    for (const auto processor :
        core_audio_hle_.take_retired_io_proc_threads()) {
        userland_hle_.unbind_thread_callback(processor);
        if (thread_terminate_handler_) {
            static_cast<void>(
                thread_terminate_handler_(process_.pid, processor));
        }
    }
}

void CompatibilityKernel::advance_time_by(std::uint64_t interval)
{
    const auto now = shared_state_->clock.now();
    const auto deadline =
        interval > std::numeric_limits<std::uint64_t>::max() - now
            ? std::numeric_limits<std::uint64_t>::max()
            : now + interval;
    advance_absolute_time(deadline);
}

void CompatibilityKernel::attach(Cpu& cpu)
{
    cpu.set_svc_handler([this](Cpu& source, std::uint32_t immediate) {
        dispatch(source, immediate);
    });
}

std::optional<std::uint32_t> CompatibilityKernel::thread_object_for_processor(
    std::size_t processor) const
{
    std::lock_guard mach_lock { shared_state_->mach_mutex };
    if (const auto task =
            shared_state_->task_thread_port_objects.find(process_.pid);
        task != shared_state_->task_thread_port_objects.end()) {
        if (const auto thread =
                task->second.find(static_cast<std::uint32_t>(processor));
            thread != task->second.end()) {
            return thread->second;
        }
    }
    return std::nullopt;
}

void CompatibilityKernel::clear_thread_io_policy(std::size_t processor_id)
{
    if (const auto thread_object = thread_object_for_processor(processor_id)) {
        process_.thread_disk_io_policies.erase(*thread_object);
    }
}

std::vector<GuestFileMutationEvent>
CompatibilityKernel::take_guest_file_mutations(std::size_t maximum_events)
{
    return shared_state_->guest_file_generation_registry->take_mutations(
        maximum_events);
}

void CompatibilityKernel::inherit_process_state(
    const CompatibilityKernel& parent, std::uint32_t child_pid,
    ProcessInheritance inheritance, std::size_t parent_processor)
{
    const auto inherit_fork_state = inheritance == ProcessInheritance::Fork;
    shared_state_ = parent.shared_state_;
    display_state_ = parent.display_state_;
    presentation_tracker_ = parent.presentation_tracker_;
    scene_coordinator_ = parent.scene_coordinator_;
    surface_store_->share_registry(*parent.surface_store_);
    wifi_state_ = parent.wifi_state_;
    audio_service_ = parent.audio_service_;
    ringer_switch_state_ = parent.ringer_switch_state_;
    if (inherit_fork_state) {
        darwin_notify_state_hle_.inherit_state(parent.darwin_notify_state_hle_);
    }
    pthread_runtime_.inherit_from(parent.pthread_runtime_, inherit_fork_state);
    configure_darwin_notify_state();
    core_audio_hle_.set_service(audio_service_);
    apple80211_hle_.set_wifi_state(wifi_state_);
    core_surface_hle_.set_display(display_state_);
    core_surface_hle_.set_presentation_tracker(presentation_tracker_);
    hid_event_system_hle_.set_shared_state(shared_state_);
    core_surface_hle_.set_shared_state(shared_state_);
    core_surface_hle_.set_scene_coordinator(scene_coordinator_);
    opengles_hle_.set_shared_state(shared_state_);
    opengles_hle_.set_scene_coordinator(scene_coordinator_);
    mbx2d_hle_.set_shared_state(shared_state_);
    mobile_framebuffer_hle_.set_shared_state(shared_state_);
    mobile_framebuffer_hle_.set_presentation_tracker(presentation_tracker_);
    mobile_framebuffer_hle_.set_scene_coordinator(scene_coordinator_);
    layerkit_hle_.set_shared_state(shared_state_);
    layerkit_hle_.set_scene_coordinator(scene_coordinator_);
    opengles_hle_.set_display(display_state_);
    mbx2d_hle_.set_display(display_state_);
    mbx2d_hle_.set_presentation_tracker(presentation_tracker_);
    mobile_framebuffer_hle_.set_display(display_state_);
    if (inherit_fork_state) {
        userland_hle_.inherit_mappings(parent.userland_hle_);
        apple80211_hle_.inherit_state(
            parent.apple80211_hle_, parent.process_.pid, child_pid);
        core_surface_hle_.inherit_state(parent.core_surface_hle_);
        opengles_hle_.inherit_state(parent.opengles_hle_);
        mbx2d_hle_.inherit_state(parent.mbx2d_hle_);
        mobile_framebuffer_hle_.inherit_state(parent.mobile_framebuffer_hle_);
        layerkit_hle_.inherit_state(parent.layerkit_hle_);
    }
    guest_working_directory_ = parent.guest_working_directory_;
    if (inherit_fork_state)
        process_image_ = parent.process_image_;
    process_ = parent.process_;
    process_.parent_pid = parent.process_.pid;
    process_.pid = child_pid;
    process_.exited = false;
    process_.waiting_for_events = false;
    process_.exit_status = 0;
    process_.termination_signal = 0;
    process_.host_port = parent.process_.host_port;
    process_.clock_port = parent.process_.clock_port;
    process_.calendar_clock_port = parent.process_.calendar_clock_port;
    process_.io_master_port = parent.process_.io_master_port;
    process_.io_registry_options_port =
        parent.process_.io_registry_options_port;
    process_.thread_disk_io_policies.clear();
    file_descriptors_ = parent.file_descriptors_;
    regular_file_open_descriptions_ = parent.regular_file_open_descriptions_;
    virtual_block_descriptors_ = parent.virtual_block_descriptors_;
    file_offsets_ = parent.file_offsets_;
    file_status_flags_ = parent.file_status_flags_;
    descriptor_flags_ = parent.descriptor_flags_;
    virtual_descriptors_ = parent.virtual_descriptors_;
    posix_semaphore_descriptors_ = parent.posix_semaphore_descriptors_;
    baseband_open_descriptions_ = parent.baseband_open_descriptions_;
    wifi_driver_event_streams_ = parent.wifi_driver_event_streams_;
    offline_serial_state_.inherit_configuration(parent.offline_serial_state_);
    bpf_descriptors_ = parent.bpf_descriptors_;
    host_sockets_ = parent.host_sockets_;
    virtual_udp_sockets_ = parent.virtual_udp_sockets_;
    kernel_control_endpoints_ = parent.kernel_control_endpoints_;
    host_network_policy_ = parent.host_network_policy_;
    bound_socket_names_ = parent.bound_socket_names_;
    listening_sockets_ = parent.listening_sockets_;
    unix_listener_states_ = parent.unix_listener_states_;
    socket_options_ = parent.socket_options_;
    duplicated_descriptors_ = parent.duplicated_descriptors_;
    system_event_filters_ = parent.system_event_filters_;
    apple80211_scan_delivered_ = parent.apple80211_scan_delivered_;
    system_event_next_identifiers_ = parent.system_event_next_identifiers_;
    route_socket_states_ = parent.route_socket_states_;
    socket_pair_endpoints_ = parent.socket_pair_endpoints_;
    if (inherit_fork_state) {
        vm_purgable_states_ = parent.vm_purgable_states_;
        signal_actions_ = parent.signal_actions_;
    } else {
        for (std::size_t signal = 0; signal < signal_actions_.size(); ++signal) {
            if (parent.signal_actions_[signal][0] ==
                darwin::signal::ignore_action)
                signal_actions_[signal] = parent.signal_actions_[signal];
        }
    }
    {
        const auto mask = parent.thread_signal_masks_.find(parent_processor);
        thread_signal_masks_ = { { 0, mask != parent.thread_signal_masks_.end()
                                             ? mask->second
                                             : 0U } };
    }
    kqueues_ = parent.kqueues_;
    descriptor_guards_.clear();
    for (const auto& [fd, guard] : parent.descriptor_guards_) {
        static_cast<void>(guard);
        static_cast<void>(release_file_descriptor(fd));
    }
    random_state_ = parent.random_state_ ^ child_pid;
    thread_ports_.clear();
    thread_ports_.emplace(0, process_.thread_port);
    {
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        if (!mach_task_identity::inherit_child(
                *shared_state_, parent.process_, process_, true)) {
            throw std::runtime_error {
                "failed to inherit child Mach task identity"
            };
        }
    }
    const auto parent_record =
        shared_state_->processes.find(parent.process_.pid);
    auto child_record = parent_record != shared_state_->processes.end()
                            ? parent_record->second
                            : KernelSharedState::ProcessRecord { };
    child_record.parent_pid = process_.parent_pid;
    child_record.process_group = process_.process_group;
    child_record.uid = process_.uid;
    child_record.effective_uid = process_.effective_uid;
    child_record.gid = process_.gid;
    child_record.effective_gid = process_.effective_gid;
    child_record.nice_value = process_.nice_value;
    child_record.importance_donor = false;
    child_record.memory_status = darwin::memorystatus::initial_state(
        shared_state_->darwin_abi.memory_status_priority);
    child_record.exit_status = 0;
    child_record.termination_signal = 0;
    child_record.exited = false;
    child_record.pid_suspended = false;
    child_record.signal_stopped = false;
    child_record.incarnation = shared_state_->next_process_incarnation++;
    child_record.parent_incarnation =
        shared_state_->processes[parent.process_.pid].incarnation;
    child_record.start_wall_nanoseconds = shared_state_->clock.wall_time();
    child_record.audit_identity_version = shared_state_->next_audit_identity_version++;
    if (child_record.incarnation == 0U)
        child_record.incarnation = shared_state_->next_process_incarnation++;
    if (child_record.command.empty())
        child_record.command = "unknown";
    shared_state_->processes[child_pid] = std::move(child_record);
    if (shared_state_->sandbox_extensions)
        shared_state_->sandbox_extensions->fork_process(parent.process_.pid, child_pid);
}

void CompatibilityKernel::dispatch(Cpu& cpu, std::uint32_t svc_immediate)
{
    const SvcDispatchDiagnostics diagnostics { process_.pid, cpu,
        svc_immediate };
    note_timer_deadline_transition();
    std::lock_guard lock { mutex_ };
    static_cast<void>(hid_event_system_hle_.prepare_pending_event(
        cpu, process_.pid, svc_immediate));
    if (apple80211_hle_.deliver_pending_event(
            cpu, process_.pid, svc_immediate)) {
        output_.write(
            "[wifi-service] event-deliver pid=" + std::to_string(process_.pid) +
            " cpu=" + std::to_string(cpu.processor_id()) + "\n");
    } else if (userland_hle_.dispatch(
                   cpu, process_.pid, svc_immediate)) {
        reap_stopped_audio_threads();
    } else if (svc_immediate != 0x80) {
        trace_unknown(cpu, "SVC", svc_immediate);
        cpu.halt(Dynarmic::HaltReason::UserDefined4);
    } else if (cpu.registers()[12] ==
               darwin::arm_fast_trap::syscall_number) {
        dispatch_arm_fast_trap(cpu);
    } else {
        const auto number = static_cast<std::int32_t>(cpu.registers()[12]);
        if (number < 0) {
            dispatch_mach(cpu,
                static_cast<std::uint32_t>(
                    -static_cast<std::int64_t>(number)));
        } else {
            dispatch_bsd(cpu, static_cast<std::uint32_t>(number));
        }
    }
    refresh_pending_event_processor_locked(cpu.processor_id());
}

void CompatibilityKernel::dispatch_arm_fast_trap(Cpu& cpu)
{
    auto& registers = cpu.registers();
    const auto cache_range_valid = [](std::uint32_t address,
                                       std::uint32_t length) {
        return static_cast<std::uint64_t>(address) + length <=
               arm_user_vm_max_address;
    };
    const auto fail_cache_trap = [&cpu](std::uint32_t address,
                                     std::uint32_t length,
                                     MemoryPermission access) {
        cpu.raise_memory_fault(address, length, access);
    };
    switch (registers[3]) {
    case darwin::arm_fast_trap::instruction_cache_invalidate: {
        const auto address = registers[0];
        const auto length = registers[1];
        if (!cache_range_valid(address, length)) {
            fail_cache_trap(address, length, MemoryPermission::Execute);
            return;
        }
        if (length != 0) {
            if (!memory_.mapped(address, length)) {
                fail_cache_trap(address, length, MemoryPermission::Execute);
                return;
            }
            const auto& capabilities =
                shared_state_->darwin_abi.capabilities;
            if (capabilities.arm_cache_trap_grants_execute &&
                darwin_abi_route_supported(arm_cache_trap_execute_route,
                    shared_state_->darwin_abi.abi_epoch)) {
                static_cast<void>(
                    memory_.map(address, length, MemoryPermission::Execute));
            }
            cpu.invalidate_cache_range(address, length);
        }
        return;
    }
    case darwin::arm_fast_trap::data_cache_flush:
        if (!cache_range_valid(registers[0], registers[1])) {
            fail_cache_trap(registers[0], registers[1], MemoryPermission::Read);
            return;
        }
        if (registers[1] != 0 && !memory_.mapped(registers[0], registers[1])) {
            fail_cache_trap(registers[0], registers[1], MemoryPermission::Read);
            return;
        }
        return;
    case darwin::arm_fast_trap::thread_set_cthread_self:
        cpu.set_cthread_self(registers[0]);
        return;
    case darwin::arm_fast_trap::thread_get_cthread_self:
        registers[0] = cpu.cthread_self().value_or(0);
        return;
    default:
        trace_unknown(cpu, "ARM fast trap", registers[3]);
        return;
    }
}

void CompatibilityKernel::bsd_success(
    Cpu& cpu, std::uint32_t value, std::uint32_t second_value)
{
    cpu.registers()[0] = value;
    cpu.registers()[1] = second_value;
    cpu.set_cpsr(cpu.cpsr() & ~carry_flag);
}

void CompatibilityKernel::bsd_error(Cpu& cpu, std::uint32_t error)
{
    cpu.registers()[0] = error;
    cpu.set_cpsr(cpu.cpsr() | carry_flag);
}

void CompatibilityKernel::report_stalled_receives(
    std::uint64_t threshold_nanoseconds) const
{
    const auto now = shared_state_->clock.now();
    for (const auto& [processor, pending] : pending_mach_receives_) {
        if (!pending.awaited_request)
            continue;
        if (pending.started == 0 || now < pending.started)
            continue;
        const auto waited = now - pending.started;
        if (waited < threshold_nanoseconds)
            continue;
        std::string line = "[mach] stalled pid=" + std::to_string(process_.pid) +
            " thread=" + std::to_string(processor + 1U) + " request=" +
            std::to_string(*pending.awaited_request) + " reply-port=" +
            std::to_string(pending.receive_name);
        if (pending.receive_object) {
            line += " object=" + std::to_string(*pending.receive_object);
            const std::lock_guard mach_lock { shared_state_->mach_mutex };
            const auto owner = shared_state_->mach_port_objects
                                   .lookup(*pending.receive_object)
                                   .value_or(xnu::ipc::PortObject { })
                                   .receive_owner;
            line += " receive-owner=" + std::to_string(owner);
        }
        line += " guest-seconds=" +
            std::to_string(waited / VirtualClock::nanoseconds_per_second);
        output_.line(line);
    }
}

bool CompatibilityKernel::unmap_memory(
    Cpu& cpu, std::uint32_t address, std::uint32_t size)
{
    const auto result = memory_.unmap_with_result(address, size);
    if (!result.succeeded)
        return false;
    if (size != 0 && result.executable_unmapped) {
        constexpr std::uint64_t page_mask =
            static_cast<std::uint64_t>(AddressSpace::page_size - 1U);
        const auto first = static_cast<std::uint64_t>(address) & ~page_mask;
        const auto requested_end = static_cast<std::uint64_t>(address) + size;
        const auto rounded_end = (requested_end + page_mask) & ~page_mask;
        const auto end =
            std::min<std::uint64_t>(rounded_end, std::uint64_t { 1 } << 32U);
        if (end > first) {
            cpu.invalidate_cache_range(static_cast<std::uint32_t>(first),
                static_cast<std::size_t>(end - first));
            output_.write("[mmap] unmap-executable pid=" +
                          std::to_string(process_.pid) +
                          " address=" + std::to_string(first) +
                          " size=" + std::to_string(end - first) + "\n");
        }
    }
    return true;
}

bool CompatibilityKernel::protect_memory(Cpu& cpu, std::uint32_t address,
    std::uint32_t size, MemoryPermission permissions)
{
    const auto result = memory_.protect_with_result(address, size, permissions);
    if (!result.succeeded)
        return false;
    if (size != 0 && result.executable_permissions_changed) {
        constexpr std::uint64_t page_mask =
            static_cast<std::uint64_t>(AddressSpace::page_size - 1U);
        const auto first = static_cast<std::uint64_t>(address) & ~page_mask;
        const auto requested_end = static_cast<std::uint64_t>(address) + size;
        const auto rounded_end = (requested_end + page_mask) & ~page_mask;
        const auto end =
            std::min<std::uint64_t>(rounded_end, std::uint64_t { 1 } << 32U);
        if (end > first) {
            cpu.invalidate_cache_range(static_cast<std::uint32_t>(first),
                static_cast<std::size_t>(end - first));
        }
    }
    return true;
}

bool CompatibilityKernel::write_guest_stat(std::uint32_t address,
    const std::filesystem::path& path, bool follow_symlink, int host_descriptor)
{
    std::array<std::byte, 96> bytes { };
    auto put16 = [&](std::size_t offset, std::uint16_t value) {
        bytes[offset] = static_cast<std::byte>(value & 0xffU);
        bytes[offset + 1] = static_cast<std::byte>(value >> 8U);
    };
    auto put32 = [&](std::size_t offset, std::uint32_t value) {
        for (std::size_t i = 0; i < 4; ++i) {
            bytes[offset + i] =
                static_cast<std::byte>((value >> (i * 8U)) & 0xffU);
        }
    };
    auto put64 = [&](std::size_t offset, std::uint64_t value) {
        for (std::size_t i = 0; i < 8; ++i) {
            bytes[offset + i] =
                static_cast<std::byte>((value >> (i * 8U)) & 0xffU);
        }
    };

    auto metadata = query_hfs_metadata(path, follow_symlink);
    if (host_descriptor >= 0) {
        struct stat status { };
        if (::fstat(host_descriptor, &status) != 0)
            return false;
        struct stat path_status { };
        const auto path_result = follow_symlink
                                     ? ::stat(path.c_str(), &path_status)
                                     : ::lstat(path.c_str(), &path_status);
        if (path_result != 0 || path_status.st_dev != status.st_dev ||
            path_status.st_ino != status.st_ino) {
            hfs::Metadata open_file;
            open_file.name = path.filename().string();
            open_file.permanent_id =
                hfs_metadata_.table_id(status.st_dev, status.st_ino, path)
                    .value_or(hfs_metadata_.guest_path_id(path));
            open_file.catalog_id = open_file.permanent_id;
            open_file.mode = static_cast<std::uint32_t>(status.st_mode);
            open_file.owner = static_cast<std::uint32_t>(status.st_uid);
            open_file.group = static_cast<std::uint32_t>(status.st_gid);
            open_file.link_count = static_cast<std::uint32_t>(status.st_nlink);
            open_file.data_length = static_cast<std::uint64_t>(status.st_size);
            open_file.data_allocation_size =
                static_cast<std::uint64_t>(status.st_blocks) * 512U;
            open_file.directory = S_ISDIR(status.st_mode);
            metadata = std::move(open_file);
        }
    }
    if (!metadata)
        return false;
    put32(0, root_disk_device);
    put32(4, metadata->permanent_id);
    put16(8, static_cast<std::uint16_t>(metadata->mode));
    put16(10, static_cast<std::uint16_t>(std::min(metadata->link_count,
                  static_cast<std::uint32_t>(
                      std::numeric_limits<std::uint16_t>::max()))));
    put32(12, metadata->owner);
    put32(16, metadata->group);
    put32(20, 0);
    put32(24, static_cast<std::uint32_t>(metadata->access_time.seconds));
    put32(28, static_cast<std::uint32_t>(metadata->access_time.nanoseconds));
    put32(32, static_cast<std::uint32_t>(metadata->modification_time.seconds));
    put32(36,
        static_cast<std::uint32_t>(metadata->modification_time.nanoseconds));
    put32(40, static_cast<std::uint32_t>(metadata->change_time.seconds));
    put32(44, static_cast<std::uint32_t>(metadata->change_time.nanoseconds));
    put64(48, metadata->data_length);
    put64(56, (metadata->data_allocation_size + 511U) / 512U);
    put32(64, AddressSpace::page_size);
    put32(68, metadata->flags);
    return memory_.copy_in(address, bytes);
}

bool CompatibilityKernel::write_guest_device_stat(
    std::uint32_t address, std::uint32_t minor, bool character_device)
{
    std::array<std::byte, 96> bytes { };
    const auto put16 = [&](std::size_t offset, std::uint16_t value) {
        bytes[offset] = static_cast<std::byte>(value & 0xffU);
        bytes[offset + 1] = static_cast<std::byte>(value >> 8U);
    };
    const auto put32 = [&](std::size_t offset, std::uint32_t value) {
        for (std::size_t byte = 0; byte < 4; ++byte) {
            bytes[offset + byte] = static_cast<std::byte>(value >> (byte * 8U));
        }
    };
    put32(0, 1);
    put32(4, 0x100U + minor);
    put16(8, static_cast<std::uint16_t>(
                 (character_device ? 0020000U : 0060000U) | 0640U));
    put16(10, 1);
    put32(20, (virtual_disk_major << 24U) | minor);
    put32(64, AddressSpace::page_size);
    return memory_.copy_in(address, bytes);
}

bool CompatibilityKernel::write_guest_kqueue_stat(std::uint32_t address,
    std::uint64_t pending_event_count, bool stat64_layout)
{
    std::array<std::byte, 108> bytes { };
    const auto put16 = [&](std::size_t offset, std::uint16_t value) {
        bytes[offset] = static_cast<std::byte>(value & 0xffU);
        bytes[offset + 1] = static_cast<std::byte>(value >> 8U);
    };
    const auto put32 = [&](std::size_t offset, std::uint32_t value) {
        for (std::size_t byte = 0; byte < 4; ++byte) {
            bytes[offset + byte] =
                static_cast<std::byte>(value >> (byte * 8U));
        }
    };
    const auto put64 = [&](std::size_t offset, std::uint64_t value) {
        for (std::size_t byte = 0; byte < 8; ++byte) {
            bytes[offset + byte] =
                static_cast<std::byte>(value >> (byte * 8U));
        }
    };
    constexpr std::uint16_t fifo_mode = 0010000U;
    if (stat64_layout) {
        put16(4, fifo_mode);
        put64(60, pending_event_count);
        put32(76, darwin::kqueue::arm32_event::size);
        return memory_.copy_in(address, bytes);
    }
    put16(8, fifo_mode);
    put64(48, pending_event_count);
    put32(64, darwin::kqueue::arm32_event::size);
    return memory_.copy_in(address,
        std::span<const std::byte> { bytes }.first(96));
}

bool CompatibilityKernel::write_guest_stat64(std::uint32_t address,
    const std::filesystem::path& path, bool follow_symlink, int host_descriptor)
{
    std::array<std::byte, 108> bytes { };
    auto put16 = [&](std::size_t offset, std::uint16_t value) {
        bytes[offset] = static_cast<std::byte>(value & 0xffU);
        bytes[offset + 1] = static_cast<std::byte>(value >> 8U);
    };
    auto put32 = [&](std::size_t offset, std::uint32_t value) {
        for (std::size_t i = 0; i < 4; ++i) {
            bytes[offset + i] =
                static_cast<std::byte>((value >> (i * 8U)) & 0xffU);
        }
    };
    auto put64 = [&](std::size_t offset, std::uint64_t value) {
        for (std::size_t i = 0; i < 8; ++i) {
            bytes[offset + i] =
                static_cast<std::byte>((value >> (i * 8U)) & 0xffU);
        }
    };
    auto put_time = [&](std::size_t offset, const hfs::Timestamp& timestamp) {
        put32(offset, static_cast<std::uint32_t>(timestamp.seconds));
        put32(offset + 4U, static_cast<std::uint32_t>(timestamp.nanoseconds));
    };

    auto metadata = query_hfs_metadata(path, follow_symlink);
    if (host_descriptor >= 0) {
        struct stat status { };
        if (::fstat(host_descriptor, &status) != 0)
            return false;
        struct stat path_status { };
        const auto path_result = follow_symlink
                                     ? ::stat(path.c_str(), &path_status)
                                     : ::lstat(path.c_str(), &path_status);
        if (path_result != 0 || path_status.st_dev != status.st_dev ||
            path_status.st_ino != status.st_ino) {
            hfs::Metadata open_file;
            open_file.name = path.filename().string();
            open_file.permanent_id =
                hfs_metadata_.table_id(status.st_dev, status.st_ino, path)
                    .value_or(hfs_metadata_.guest_path_id(path));
            open_file.catalog_id = open_file.permanent_id;
            open_file.mode = static_cast<std::uint32_t>(status.st_mode);
            open_file.owner = static_cast<std::uint32_t>(status.st_uid);
            open_file.group = static_cast<std::uint32_t>(status.st_gid);
            open_file.link_count = static_cast<std::uint32_t>(status.st_nlink);
            open_file.data_length = static_cast<std::uint64_t>(status.st_size);
            open_file.data_allocation_size =
                static_cast<std::uint64_t>(status.st_blocks) * 512U;
            open_file.directory = S_ISDIR(status.st_mode);
            metadata = std::move(open_file);
        }
    }
    if (!metadata)
        return false;

    put32(0, root_disk_device);
    put16(4, static_cast<std::uint16_t>(metadata->mode));
    put16(6, static_cast<std::uint16_t>(std::min(metadata->link_count,
                 static_cast<std::uint32_t>(
                     std::numeric_limits<std::uint16_t>::max()))));
    put64(8, metadata->permanent_id);
    put32(16, metadata->owner);
    put32(20, metadata->group);
    put32(24, 0);
    put_time(28, metadata->access_time);
    put_time(36, metadata->modification_time);
    put_time(44, metadata->change_time);
    put_time(52, metadata->creation_time);
    put64(60, metadata->data_length);
    put64(68, (metadata->data_allocation_size + 511U) / 512U);
    put32(76, AddressSpace::page_size);
    put32(80, metadata->flags);
    return memory_.copy_in(address, bytes);
}

bool CompatibilityKernel::write_guest_device_stat64(
    std::uint32_t address, std::uint32_t minor, bool character_device)
{
    std::array<std::byte, 108> bytes { };
    const auto put16 = [&](std::size_t offset, std::uint16_t value) {
        bytes[offset] = static_cast<std::byte>(value & 0xffU);
        bytes[offset + 1] = static_cast<std::byte>(value >> 8U);
    };
    const auto put32 = [&](std::size_t offset, std::uint32_t value) {
        for (std::size_t byte = 0; byte < 4; ++byte) {
            bytes[offset + byte] = static_cast<std::byte>(value >> (byte * 8U));
        }
    };
    const auto put64 = [&](std::size_t offset, std::uint64_t value) {
        for (std::size_t byte = 0; byte < 8; ++byte) {
            bytes[offset + byte] = static_cast<std::byte>(value >> (byte * 8U));
        }
    };
    put32(0, 1);
    put16(4, static_cast<std::uint16_t>(
                 (character_device ? 0020000U : 0060000U) | 0640U));
    put16(6, 1);
    put64(8, 0x100U + minor);
    put32(24, (virtual_disk_major << 24U) | minor);
    put32(76, AddressSpace::page_size);
    return memory_.copy_in(address, bytes);
}

bool CompatibilityKernel::write_guest_statfs(
    std::uint32_t address, const hfs::VolumeMetadata& volume)
{
    std::array<std::byte, 272> bytes { };
    const auto put16 = [&](std::size_t offset, std::uint16_t value) {
        bytes[offset] = static_cast<std::byte>(value & 0xffU);
        bytes[offset + 1] = static_cast<std::byte>(value >> 8U);
    };
    const auto put32 = [&](std::size_t offset, std::uint32_t value) {
        for (std::size_t index = 0; index < 4; ++index) {
            bytes[offset + index] =
                static_cast<std::byte>((value >> (index * 8U)) & 0xffU);
        }
    };
    const auto put_string = [&](std::size_t offset, std::size_t capacity,
                                std::string_view value) {
        const auto count = std::min(capacity - 1, value.size());
        for (std::size_t index = 0; index < count; ++index) {
            bytes[offset + index] = static_cast<std::byte>(value[index]);
        }
    };
    put16(2, static_cast<std::uint16_t>(volume.mount_flags));
    put32(4, volume.block_size);
    put32(8, volume.io_block_size);
    put32(12, volume.total_blocks);
    put32(16, volume.free_blocks);
    put32(20, volume.free_blocks);
    put32(24, 0xffff'ffffU);
    put32(28, 0xffff'ffffU - volume.next_catalog_id);
    put32(32, 1);
    put32(48, volume.mount_flags);
    put_string(60, 15, "hfs");
    put_string(75, 90, volume.mount_point);
    put_string(165, 90, volume.mounted_device);
    return memory_.copy_in(address, bytes);
}

bool CompatibilityKernel::write_guest_statfs64(
    std::uint32_t address, const hfs::VolumeMetadata& volume)
{
    std::array<std::byte, 2168> bytes { };
    const auto put32 = [&](std::size_t offset, std::uint32_t value) {
        for (std::size_t index = 0; index < 4; ++index) {
            bytes[offset + index] =
                static_cast<std::byte>((value >> (index * 8U)) & 0xffU);
        }
    };
    const auto put64 = [&](std::size_t offset, std::uint64_t value) {
        for (std::size_t index = 0; index < 8; ++index) {
            bytes[offset + index] =
                static_cast<std::byte>((value >> (index * 8U)) & 0xffU);
        }
    };
    const auto put_string = [&](std::size_t offset, std::size_t capacity,
                                std::string_view value) {
        const auto count = std::min(capacity - 1, value.size());
        for (std::size_t index = 0; index < count; ++index) {
            bytes[offset + index] = static_cast<std::byte>(value[index]);
        }
    };

    put32(0, volume.block_size);
    put32(4, volume.io_block_size);
    put64(8, volume.total_blocks);
    put64(16, volume.free_blocks);
    put64(24, volume.free_blocks);
    put64(32, 0xffff'ffffULL);
    put64(40, 0xffff'ffffULL - volume.next_catalog_id);
    put32(48, 1);
    put32(56, 0);
    put32(60, volume.filesystem_type);
    put32(64, volume.mount_flags);
    put32(68, 0);
    put_string(72, 16, "hfs");
    put_string(88, 1024, volume.mount_point);
    put_string(1112, 1024, volume.mounted_device);
    return memory_.copy_in(address, bytes);
}

std::filesystem::path CompatibilityKernel::resolve_guest_path(
    const std::string& path, bool follow_final_symlink) const
{
    constexpr std::string_view resource_fork_suffix { "/..namedfork/rsrc" };
    if (path.ends_with(resource_fork_suffix)) {
        auto data_path =
            path.substr(0, path.size() - resource_fork_suffix.size());
        if (data_path.empty())
            data_path = "/";
        return hfs::MetadataProvider::resource_sidecar(
            resolve_guest_path(data_path, true));
    }
    return RootfsPathResolver { rootfs_ }.resolve(
        path, working_directory(), follow_final_symlink);
}

thread_local std::optional<std::size_t> CompatibilityKernel::syscall_processor_;

std::optional<std::uint32_t> CompatibilityKernel::current_thread_object() const
{
    if (!syscall_processor_)
        return std::nullopt;
    return thread_object_for_processor(*syscall_processor_);
}

std::optional<std::filesystem::path> CompatibilityKernel::guest_path_of_host(
    const std::filesystem::path& host) const
{
    std::error_code error;
    const auto root = std::filesystem::weakly_canonical(rootfs_, error);
    if (error)
        return std::nullopt;
    const auto relative = host.lexically_normal().lexically_relative(root);
    if (relative.empty() || *relative.begin() == "..")
        return std::nullopt;
    return (std::filesystem::path { "/" } / relative).lexically_normal();
}

void CompatibilityKernel::release_thread_directory_locked(
    std::uint32_t thread_object)
{
    const auto found =
        shared_state_->thread_working_directories.find(thread_object);
    if (found == shared_state_->thread_working_directories.end())
        return;
    if (found->second.host_descriptor >= 0)
        close(found->second.host_descriptor);
    shared_state_->thread_working_directories.erase(found);
}

std::filesystem::path CompatibilityKernel::working_directory() const
{
    if (const auto thread = current_thread_object()) {
        std::lock_guard mach_lock { shared_state_->mach_mutex };
        if (const auto found =
                shared_state_->thread_working_directories.find(*thread);
            found != shared_state_->thread_working_directories.end()) {
            const auto& pinned = found->second;
            if (pinned.host_descriptor >= 0) {
                char host[MAXPATHLEN];
                if (fcntl(pinned.host_descriptor, F_GETPATH, host) == 0) {
                    if (const auto guest = guest_path_of_host(host))
                        return *guest;
                }
            }
            return pinned.guest;
        }
    }
    return guest_working_directory_;
}

std::optional<hfs::Metadata> CompatibilityKernel::query_hfs_metadata(
    const std::filesystem::path& path, bool follow_symlink,
    bool include_directory_entry_count) const
{
    auto metadata = hfs_metadata_.query(
        path, follow_symlink, include_directory_entry_count);
    if (!metadata)
        return std::nullopt;
    const std::lock_guard filesystem_lock { shared_state_->filesystem_mutex };
    if (const auto override =
            shared_state_->hfs_metadata_overrides.find(metadata->permanent_id);
        override != shared_state_->hfs_metadata_overrides.end()) {
        hfs::MetadataProvider::apply_override(*metadata, override->second);
    }
    return metadata;
}

std::optional<std::vector<std::byte>>
CompatibilityKernel::query_hfs_named_attribute(
    const std::filesystem::path& path, bool follow_symlink,
    std::string_view name) const
{
    const auto metadata = hfs_metadata_.query(path, follow_symlink);
    if (!metadata)
        return std::nullopt;
    {
        const std::lock_guard filesystem_lock {
            shared_state_->filesystem_mutex
        };
        if (const auto inode =
                shared_state_->hfs_named_attribute_overrides.find(
                    metadata->permanent_id);
            inode != shared_state_->hfs_named_attribute_overrides.end()) {
            if (const auto attribute = inode->second.find(std::string { name });
                attribute != inode->second.end()) {
                return attribute->second;
            }
        }
    }
    return hfs_metadata_.named_attribute(path, name, follow_symlink);
}

std::vector<std::string> CompatibilityKernel::query_hfs_named_attributes(
    const std::filesystem::path& path, bool follow_symlink) const
{
    const auto metadata = hfs_metadata_.query(path, follow_symlink);
    if (!metadata)
        return { };
    std::set<std::string> names;
    for (auto& name : hfs_metadata_.named_attributes(path, follow_symlink)) {
        names.emplace(std::move(name));
    }
    {
        const std::lock_guard filesystem_lock {
            shared_state_->filesystem_mutex
        };
        if (const auto inode =
                shared_state_->hfs_named_attribute_overrides.find(
                    metadata->permanent_id);
            inode != shared_state_->hfs_named_attribute_overrides.end()) {
            for (const auto& [name, value] : inode->second) {
                if (value)
                    names.emplace(name);
                else
                    names.erase(name);
            }
        }
    }
    return { names.begin(), names.end() };
}

std::uint32_t CompatibilityKernel::file_descriptor_limit() const
{
    return static_cast<std::uint32_t>(std::min<std::uint64_t>(
        process_.resource_limits[darwin::resource::open_files].current,
        darwin::resource::maximum_open_files));
}

std::optional<std::uint32_t>
CompatibilityKernel::allocate_file_descriptor() const
{
    for (std::uint32_t descriptor = 3; descriptor < file_descriptor_limit();
        ++descriptor) {
        if (!file_descriptors_.contains(descriptor) &&
            !virtual_descriptors_.contains(descriptor) &&
            !duplicated_descriptors_.contains(descriptor)) {
            return descriptor;
        }
    }
    return std::nullopt;
}

void CompatibilityKernel::copy_kqueue_descriptor_state(
    std::uint32_t source, std::uint32_t destination)
{
    for (unsigned depth = 0; depth < 256U; ++depth) {
        if (const auto queue = kqueues_.find(source);
            queue != kqueues_.end()) {
            kqueues_[destination] = queue->second;
            return;
        }
        const auto duplicate = duplicated_descriptors_.find(source);
        if (duplicate == duplicated_descriptors_.end())
            return;
        source = duplicate->second;
    }
}

void CompatibilityKernel::trace_unknown(
    Cpu& cpu, std::string kind, std::uint32_t number)
{
    {
        constexpr std::size_t maximum_reported_unknown_calls = 4096;
        const std::lock_guard lock { reported_unknown_mutex_ };
        if (reported_unknown_calls_.size() >= maximum_reported_unknown_calls ||
            !reported_unknown_calls_.emplace(process_.pid, kind, number).second)
            return;
    }
    std::ostringstream message;
    message << "[kernel] unsupported " << kind << ' ' << number
            << " pid=" << process_.pid << " process=" << process_image_
            << " pc=0x" << std::hex << cpu.registers()[15];
    for (std::size_t index = 0; index < 7; ++index) {
        message << " r" << std::dec << index << "=0x" << std::hex
                << cpu.registers()[index];
    }
    message << std::dec << '\n';
    output_.write(message.str());
}

void CompatibilityKernel::sample_load_average(std::size_t runnable_threads)
{
    constexpr auto period =
        static_cast<std::uint64_t>(foundation::load_average_period_seconds) *
        darwin::mach::thread_policy::absolute_time_units_per_second;
    const auto now = current_absolute_time();
    const auto runnable = static_cast<std::uint32_t>(std::min<std::size_t>(
        runnable_threads, std::numeric_limits<std::uint32_t>::max()));
    std::lock_guard lock { load_average_mutex_ };
    if (next_load_average_sample_ == 0) {
        next_load_average_sample_ = now + period;
        return;
    }
    while (next_load_average_sample_ <= now) {
        load_average_.sample(runnable);
        next_load_average_sample_ += period;
    }
}

foundation::LoadAverage CompatibilityKernel::load_average() const
{
    std::lock_guard lock { load_average_mutex_ };
    return load_average_;
}

void CompatibilityKernel::count_interface_traffic(bool loopback, bool output,
    std::size_t bytes, bool failed)
{
    std::lock_guard network_lock { shared_state_->network_mutex };
    const auto found = shared_state_->network_interfaces.find(
        loopback ? "lo0" : "en0");
    if (found != shared_state_->network_interfaces.end())
        found->second.counters.record(output, bytes, failed);
}

}
