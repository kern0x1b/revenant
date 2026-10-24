// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Dispatch guest kernel calls and coordinate process, memory, device
// and IPC services.

#pragma once

#include "kernel/darwin_file_guard.hpp"
#include <array>
#include <chrono>
#include <cstddef>
#include <cstdint>
#include <deque>
#include <filesystem>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <set>
#include <span>
#include <string>
#include <string_view>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

#include "foundation/address_space.hpp"
#include "foundation/load_average.hpp"
#include "network/apple80211_event_stream.hpp"
#include "network/apple80211_hle.hpp"
#include "media/audio.hpp"
#include "media/audio_toolbox_hle.hpp"
#include "media/core_audio_hle.hpp"
#include "media/core_media_hle.hpp"
#include "kernel/core_surface_hle.hpp"
#include "kernel/hid_event_system_hle.hpp"
#include "foundation/cpu.hpp"
#include "kernel/darwin_bpf_abi.hpp"
#include "foundation/darwin_notify_state_hle.hpp"
#include "kernel/darwin_pthread_runtime.hpp"
#include "kernel/darwin_tty_abi.hpp"
#include "foundation/device_model.hpp"
#include "graphics/display.hpp"
#include "foundation/dyld_shared_cache.hpp"
#include "filesystem/hfs_metadata.hpp"
#include "filesystem/hfs_volume_layout.hpp"
#include "network/host_network.hpp"
#include "kernel/kernel_control.hpp"
#include "kernel/kernel_shared_state.hpp"
#include "kernel/process_snapshot.hpp"
#include "kernel/layerkit_hle.hpp"
#include "device_state/lockdown_state.hpp"
#include "device_state/darwin_kernel_configuration.hpp"
#include "kernel/mach_arm_thread_abi.hpp"
#include "kernel/mbx2d_hle.hpp"
#include "kernel/mobile_framebuffer_hle.hpp"
#include "kernel/offline_serial_device.hpp"
#include "kernel/opengles_hle.hpp"
#include "foundation/output.hpp"
#include "graphics/presentation_tracker.hpp"
#include "kernel/ringer_switch_state.hpp"
#include "foundation/scene_coordinator.hpp"
#include "graphics/surface_store.hpp"
#include "foundation/system_button_input.hpp"
#include "network/system_configuration_hle.hpp"
#include "foundation/touch_input.hpp"
#include "foundation/userland_hle.hpp"
#include "network/virtual_udp.hpp"
#include "network/wifi_state.hpp"
#include "mach/xnu_scheduler.hpp"

namespace emulator {

class MachOImage;

class CompatibilityKernel {
public:
    enum class ProcessInheritance : std::uint8_t {
        Fork,
        SpawnExec,
    };

    struct TimerDeadlineSnapshot {
        std::uint64_t generation { };
        std::optional<std::uint64_t> deadline;
    };

    struct SchedulerYieldRequest {
        bool depress { };
        std::uint32_t duration_milliseconds { };
    };
    struct WaitChildResult {
        bool has_child { };
        std::optional<std::uint32_t> child_pid;
        std::uint32_t status { };
    };
    using ThreadCreateHandler = std::function<std::optional<std::size_t>(
        const std::array<std::uint32_t, 16>&, std::uint32_t)>;
    using ThreadTerminateHandler =
        std::function<bool(std::uint32_t, std::size_t)>;
    using ThreadStateQuery =
        std::function<std::optional<darwin::arm_thread::GeneralState>(
            std::uint32_t, std::uint32_t, std::uint32_t)>;
    using ThreadStateUpdateHandler = std::function<bool(
        std::uint32_t, std::uint32_t, const darwin::arm_thread::GeneralState&)>;
    using ThreadPointerUpdateHandler = std::function<bool(
        std::uint32_t, std::uint32_t, std::optional<std::uint32_t>)>;
    using ThreadRunnableHandler =
        std::function<bool(std::uint32_t, std::uint32_t, bool)>;
    using ProcessRunnableHandler =
        std::function<void(std::uint32_t, bool)>;
    using ProcessSocketsShutdownHandler =
        std::function<void(std::uint32_t, std::uint32_t)>;
    using ThreadWakeHandler =
        std::function<XnuThreadWakeResult(std::uint32_t, std::uint32_t)>;
    using ThreadSchedulingStateQuery = std::function<std::optional<XnuThreadState>(
        std::uint32_t, std::uint32_t)>;
    using MachMessageWakeHandler =
        std::function<XnuThreadWakeResult(std::uint32_t, std::uint32_t)>;
    using ForkHandler = std::function<std::optional<std::uint32_t>(Cpu&)>;
    using SpawnCreateHandler =
        std::function<std::optional<std::uint32_t>(Cpu&)>;
    using ExecHandler = std::function<bool(
        Cpu&, std::string, std::vector<std::string>, std::vector<std::string>)>;
    using SpawnExecHandler = std::function<bool(std::uint32_t, std::string,
        std::vector<std::string>, std::vector<std::string>, bool)>;
    using SchedulerRunnableQuery = std::function<bool(std::size_t)>;
    using LegacyThreadPolicyHandler =
        std::function<bool(std::size_t, std::uint32_t, std::int32_t, bool)>;
    using ThreadPolicyHandler = std::function<bool(
        std::size_t, std::uint32_t, std::span<const std::uint32_t>)>;
    using TaskPriorityHandler = std::function<void(std::int32_t)>;
    using SchedulerPreemptionQuery = std::function<bool(std::size_t)>;
    using SignalDeliveryHandler =
        std::function<std::uint32_t(std::uint32_t, std::uint32_t)>;
    using TaskMemoryRegionQuery =
        std::function<std::optional<AddressSpace::MappingRegion>(
            std::uint32_t, std::uint32_t)>;
    struct SharedTaskMemoryRange {
        std::vector<std::shared_ptr<GuestPageBacking>> pages;
        MemoryPermission permissions { MemoryPermission::None };
    };
    using TaskMemoryShareQuery =
        std::function<std::optional<SharedTaskMemoryRange>(
            std::uint32_t, std::uint32_t, std::uint32_t)>;
    struct RemapPlacement {
        std::uint32_t requested_address { };
        std::uint32_t size { };
        std::uint32_t mask { };
        bool anywhere { };
        bool copy { };
        std::uint32_t inheritance { };
        SharedTaskMemoryRange source;
    };
    struct RemapResult {
        std::uint32_t result { };
        std::uint32_t address { };
    };
    using TaskMemoryRemapHandler =
        std::function<std::optional<RemapResult>(std::uint32_t, RemapPlacement)>;
    [[nodiscard]] static RemapResult remap_into(
        AddressSpace& memory, RemapPlacement placement);
    using MappedExecutableHandler =
        std::function<void(const std::filesystem::path&, std::uint32_t,
            std::uint32_t, std::uint64_t)>;

    CompatibilityKernel(AddressSpace& memory, Output& output,
        std::filesystem::path rootfs = { },
        DeviceModel device = DeviceModel::default_model(),
        std::optional<bool> activated = std::nullopt,
        LockdownCapabilities lockdown_capabilities = { },
        std::optional<DarwinKernelConfiguration> configuration = std::nullopt,
        std::shared_ptr<hfs::GuestIdTable> guest_ids = nullptr);

    static constexpr std::uint64_t kDefaultRandomSeed = 0x69a5'1e8d'4c3b'2701ULL;
    void seed_random(std::uint64_t seed);

    void attach(Cpu& cpu);
    void set_key_store(std::shared_ptr<KeyStore> key_store)
    {
        shared_state_->key_store = std::move(key_store);
    }
    void dispatch(Cpu& cpu, std::uint32_t svc_immediate);
    void notify_thread_blocked(std::size_t processor);

    [[nodiscard]] ProcessContext& process() { return process_; }
    [[nodiscard]] const ProcessContext& process() const { return process_; }
    [[nodiscard]] std::vector<ProcessSnapshot> process_snapshots() const;
    [[nodiscard]] std::shared_ptr<GuestFileGenerationRegistry>
    guest_file_generation_registry() const
    {
        return shared_state_->guest_file_generation_registry;
    }
    [[nodiscard]] std::vector<GuestFileMutationEvent> take_guest_file_mutations(
        std::size_t maximum_events);
    void clear_thread_io_policy(std::size_t processor_id);
    void exit_process(std::uint32_t status, std::uint32_t signal = 0);
    [[nodiscard]] WaitChildResult wait_child(
        std::int32_t target_pid, bool reap);
    void set_thread_create_handler(ThreadCreateHandler handler)
    {
        thread_create_handler_ = std::move(handler);
    }
    void set_thread_terminate_handler(ThreadTerminateHandler handler)
    {
        thread_terminate_handler_ = std::move(handler);
    }
    void set_thread_state_query(ThreadStateQuery query)
    {
        thread_state_query_ = std::move(query);
    }
    void set_thread_state_update_handler(ThreadStateUpdateHandler handler)
    {
        thread_state_update_handler_ = std::move(handler);
    }
    void set_thread_pointer_update_handler(ThreadPointerUpdateHandler handler)
    {
        thread_pointer_update_handler_ = std::move(handler);
    }
    void set_thread_runnable_handler(ThreadRunnableHandler handler)
    {
        thread_runnable_handler_ = std::move(handler);
    }
    void set_process_runnable_handler(ProcessRunnableHandler handler)
    {
        process_runnable_handler_ = std::move(handler);
    }
    void set_process_sockets_shutdown_handler(ProcessSocketsShutdownHandler handler)
    {
        process_sockets_shutdown_handler_ = std::move(handler);
    }
    void shutdown_process_sockets(std::uint32_t level);
    void set_thread_wake_handler(ThreadWakeHandler handler)
    {
        thread_wake_handler_ = std::move(handler);
    }
    void set_thread_scheduling_state_query(ThreadSchedulingStateQuery query)
    {
        thread_scheduling_state_query_ = std::move(query);
    }
    void set_mach_message_wake_handler(MachMessageWakeHandler handler)
    {
        mach_message_wake_handler_ = std::move(handler);
    }
    void set_fork_handler(ForkHandler handler)
    {
        fork_handler_ = std::move(handler);
    }
    void set_spawn_create_handler(SpawnCreateHandler handler)
    {
        spawn_create_handler_ = std::move(handler);
    }
    void set_exec_handler(ExecHandler handler)
    {
        exec_handler_ = std::move(handler);
    }
    void set_spawn_exec_handler(SpawnExecHandler handler)
    {
        spawn_exec_handler_ = std::move(handler);
    }
    void set_mapped_executable_handler(MappedExecutableHandler handler)
    {
        mapped_executable_handler_ = std::move(handler);
    }
    void set_scheduler_runnable_query(SchedulerRunnableQuery query)
    {
        scheduler_runnable_query_ = std::move(query);
    }
    void set_legacy_thread_policy_handler(LegacyThreadPolicyHandler handler)
    {
        legacy_thread_policy_handler_ = std::move(handler);
    }
    void set_thread_policy_handler(ThreadPolicyHandler handler)
    {
        thread_policy_handler_ = std::move(handler);
    }
    void set_task_priority_handler(TaskPriorityHandler handler)
    {
        task_priority_handler_ = std::move(handler);
    }
    void set_scheduler_preemption_query(SchedulerPreemptionQuery query)
    {
        scheduler_preemption_query_ = std::move(query);
    }
    void set_signal_delivery_handler(SignalDeliveryHandler handler)
    {
        signal_delivery_handler_ = std::move(handler);
    }
    void set_task_memory_region_query(TaskMemoryRegionQuery query)
    {
        task_memory_region_query_ = std::move(query);
    }
    void set_task_memory_share_query(TaskMemoryShareQuery query)
    {
        task_memory_share_query_ = std::move(query);
    }
    void set_task_memory_remap_handler(TaskMemoryRemapHandler handler)
    {
        task_memory_remap_handler_ = std::move(handler);
    }
    [[nodiscard]] std::uint32_t deliver_signal(std::uint32_t signal);
    struct GuestFault {
        enum class Kind : std::uint8_t {
            DataAccess,
            InstructionFetch,
            Undefined,
            Breakpoint,
        };
        Kind kind { };
        std::uint32_t pc { };
        std::uint32_t address { };
        bool write { };
    };
    [[nodiscard]] std::optional<std::uint32_t> deliver_fault_signal(
        Cpu& cpu, const GuestFault& fault);
    void deliver_pending_signals(Cpu& cpu);
    [[nodiscard]] std::optional<SchedulerYieldRequest> consume_scheduler_yield(
        std::size_t processor_id);
    [[nodiscard]] std::optional<XnuThreadId> consume_scheduler_handoff(
        std::size_t processor_id);
    void set_display_presenter(DisplayState::Presenter presenter)
    {
        display_state_->set_presenter(std::move(presenter));
    }
    void initialize_boot_display(std::vector<std::uint32_t> pixels)
    {
        if (display_state_->presented_frames() != 0)
            return;
        display_state_->replace_pixels(std::move(pixels));
        display_state_->present();
    }
    void set_audio_sink(std::shared_ptr<AudioSink> sink)
    {
        audio_service_->set_sink(std::move(sink));
    }
    void set_audio_decoder(std::shared_ptr<AudioDecoder> decoder)
    {
        audio_service_->set_decoder(std::move(decoder));
    }
    [[nodiscard]] DisplayFrame display_snapshot() const
    {
        return display_state_->snapshot();
    }
    [[nodiscard]] std::uint64_t display_submitted_frames() const
    {
        return display_state_->presented_frames();
    }
    [[nodiscard]] std::uint64_t display_content_revision() const
    {
        return display_state_->content_revision();
    }
    [[nodiscard]] std::uint32_t display_content_owner_process_id() const
    {
        return display_state_->content_owner_process_id();
    }
    [[nodiscard]] std::uint64_t display_vsync_pulse_count() const
    {
        return shared_state_->display_vsync_pulse_count;
    }
    [[nodiscard]] std::optional<KernelSharedState::ForegroundTransitionSnapshot>
    foreground_transition_snapshot() const
    {
        std::lock_guard lock { shared_state_->mach_mutex };
        return shared_state_->foreground_transition_snapshot;
    }
    void note_foreground_transition_content_change(
        std::uint32_t process_id, std::uint64_t content_revision)
    {
        std::lock_guard lock { shared_state_->mach_mutex };
        shared_state_->note_foreground_transition_content_change_locked(
            process_id, content_revision);
    }
    void record_foreground_transition_display_submission(
        std::uint32_t process_id, std::uint64_t frame_sequence)
    {
        if (process_id == 0U)
            return;
        const auto content_revision = display_state_->content_revision();
        std::lock_guard lock { shared_state_->mach_mutex };
        shared_state_->mark_foreground_transition_locked(
            KernelSharedState::ForegroundTransitionMilestone::
                DestinationFirstFrame,
            process_id, frame_sequence);
        shared_state_->note_foreground_transition_content_change_locked(
            process_id, content_revision);
    }
    void mark_foreground_transition_input_complete()
    {
        std::lock_guard lock { shared_state_->mach_mutex };
        shared_state_->mark_foreground_transition_input_complete_locked();
    }
    void mark_foreground_transition_stable()
    {
        std::lock_guard lock { shared_state_->mach_mutex };
        shared_state_->mark_foreground_transition_stable_locked();
    }
    [[nodiscard]] std::optional<std::uint32_t> active_client_process_id() const
    {
        const auto active_scene = scene_coordinator_->active_client_scene();
        return active_scene ? std::optional<std::uint32_t> { active_scene
                                  ->client_process_id }
                            : std::nullopt;
    }
    [[nodiscard]] std::uint64_t current_absolute_time() const
    {
        return shared_state_->clock.now();
    }
    [[nodiscard]] std::uint64_t current_wall_time() const
    {
        return shared_state_->clock.wall_time();
    }
    void sample_load_average(std::size_t runnable_threads);
    [[nodiscard]] foundation::LoadAverage load_average() const;
    [[nodiscard]] std::size_t bootstrap_checked_in_service_count() const;
    void report_stalled_receives(std::uint64_t threshold_nanoseconds) const;
    void set_wall_time(std::uint64_t unix_time_nanoseconds)
    {
        shared_state_->clock.set_wall_time(unix_time_nanoseconds);
    }
    void synchronize_wall_time(std::uint64_t unix_time_nanoseconds)
    {
        set_wall_time(unix_time_nanoseconds);
    }
    bool refresh_display_scanout();
    [[nodiscard]] bool owns_display_scanout() const;
    bool set_virtual_processor_count(std::size_t processor_count);
    void set_preferred_wifi_networks(std::vector<std::string> ssids)
    {
        wifi_state_->set_preferred_networks(std::move(ssids));
    }
    void set_host_network_policy(HostNetworkPolicy policy);
    [[nodiscard]] WifiSnapshot wifi_snapshot() const
    {
        return wifi_state_->snapshot();
    }
    [[nodiscard]] std::optional<darwin::network::InterfaceSnapshot>
    network_interface_snapshot(std::string_view name) const;
    [[nodiscard]] std::vector<darwin::route::Entry> route_snapshot() const;
    void enqueue_baseband_input(std::span<const std::byte> bytes);
    void set_baseband_receive_eof(bool eof);
    void set_baseband_capture_enabled(bool enabled);
    void set_baseband_transmit_sink(
        bsd::baseband_device::State::TransmitSink sink);
    void enqueue_touch_input(const TouchInput& input);
    void enqueue_system_button(const SystemButtonInput& input);
    [[nodiscard]] std::optional<std::uint32_t>
    graphics_input_receiver_process_id() const;
    void set_ringer_switch_active(bool active);
    void toggle_ringer_switch();
    [[nodiscard]] bool display_powered_on() const;
    [[nodiscard]] std::vector<std::byte> take_baseband_output();
    void inherit_process_state(const CompatibilityKernel& parent,
        std::uint32_t child_pid,
        ProcessInheritance inheritance = ProcessInheritance::Fork,
        std::size_t parent_processor = 0);
    void prepare_exec(std::size_t processor_id);
    void install_main_image_hle(
        Cpu& cpu, std::string_view mapped_guest_path = { });
    void set_process_image(std::string_view guest_path,
        std::span<const std::byte> code_signature_entitlements = { },
        const MachOImage* dynamic_linker = nullptr,
        const MachOImage* executable = nullptr);
    void set_process_arguments(const std::vector<std::string>& arguments,
        const std::vector<std::string>& environment);
    [[nodiscard]] const std::map<std::size_t, PendingWait>&
    pending_waits() const
    {
        return pending_waits_;
    }
    bool complete_wait(
        Cpu& cpu, std::uint32_t child_pid, std::uint32_t wait_status);
    bool fail_wait(Cpu& cpu, std::uint32_t error);
    bool deliver_pending_mach(Cpu& cpu);
    bool deliver_pending_io(Cpu& cpu);
    [[nodiscard]] std::optional<std::size_t> pending_mach_receiver_processor(
        std::uint32_t object);
    bool deliver_pending_event(Cpu& cpu);
    [[nodiscard]] std::vector<std::size_t> pending_event_poll_candidates();
    [[nodiscard]] std::optional<std::uint64_t>
    take_last_delivered_graphics_input(std::size_t processor);
    [[nodiscard]] std::optional<std::uint64_t> next_timer_deadline() const;
    [[nodiscard]] TimerDeadlineSnapshot timer_deadline_snapshot() const;
    [[nodiscard]] std::optional<std::uint64_t>
    next_display_vsync_deadline() const;
    [[nodiscard]] std::optional<std::size_t> display_vsync_receiver_processor();
    [[nodiscard]] std::optional<std::size_t>
    display_vsync_dependency_processor();
    [[nodiscard]] std::optional<std::size_t> display_vsync_callback_processor();
    [[nodiscard]] std::optional<std::pair<std::size_t, std::uint64_t>>
    display_vsync_inflight_callback_dependency();
    [[nodiscard]] bool display_vsync_callback_pending();
    void advance_absolute_time(std::uint64_t deadline);
    void advance_time_by(std::uint64_t interval);
    void service_time_dependent_devices(std::uint64_t deadline);
    [[nodiscard]] std::string wait_reason(std::size_t processor) const;
    [[nodiscard]] std::optional<std::uint32_t> guest_thread_id(
        std::size_t processor) const
    {
        return thread_object_for_processor(processor);
    }

private:
    struct CreatedGuestThread {
        std::size_t processor { };
        std::uint32_t port_name { };
    };

    void enqueue_system_button_impl(
        const SystemButtonInput& input, bool force_home_transition);
    void wake_graphics_input_receivers();

    struct MachMessageRequest {
        std::uint32_t address { };
        std::uint32_t bits { };
        std::uint32_t remote_port { };
        std::uint32_t local_port { };
        std::uint32_t identifier { };
    };

    struct AioCompletion {
        std::uint32_t descriptor { };
        std::int32_t result { };
        std::uint32_t error { };
    };

    struct DirectoryEntry {
        std::string name;
        std::uint8_t type { };
        std::uint32_t catalog_id { };
    };

    void dispatch_arm_fast_trap(Cpu& cpu);
    void dispatch_bsd(Cpu& cpu, std::uint32_t number);
    void dispatch_bsd_process_sockets(Cpu& cpu);
    [[nodiscard]] bool dispatch_bsd_pthread(Cpu& cpu, std::uint32_t number);
    [[nodiscard]] bool dispatch_bsd_thread_directory(
        Cpu& cpu, std::uint32_t number);
    [[nodiscard]] std::optional<std::filesystem::path>
    guest_directory_of_descriptor(std::uint32_t descriptor, std::uint32_t& error) const;
    void dispatch_bsd_psynch(Cpu& cpu, std::uint32_t number);
    [[nodiscard]] bool service_bsd_workqueue(Cpu* requesting_cpu);
    void dispatch_bsd_nosys(Cpu& cpu, bool send_sigsys);
    [[nodiscard]] std::optional<std::uint32_t> thread_object_for_processor(
        std::size_t processor) const;
    [[nodiscard]] std::optional<CreatedGuestThread> create_guest_thread(
        const std::array<std::uint32_t, 16>& state, std::uint32_t cpsr,
        bool start_suspended, std::uint32_t& kernel_error);
    void dispatch_bsd_aio(Cpu& cpu, std::uint32_t number);
    void dispatch_bsd_audit_session(Cpu& cpu, std::uint32_t number);
    void dispatch_bsd_fileport(Cpu& cpu, std::uint32_t number);
    void dispatch_bsd_platform(Cpu& cpu, std::uint32_t number);
    void dispatch_bsd_process(Cpu& cpu, std::uint32_t number);
    void dispatch_bsd_posix_semaphore(Cpu& cpu, std::uint32_t number);
    void release_process_mach_rights();
    void release_process_descriptors();
    [[nodiscard]] bool release_file_descriptor(std::uint32_t descriptor);
    void release_close_on_exec_descriptors();
    [[nodiscard]] bool dispatch_bsd_process_credentials(
        Cpu& cpu, std::uint32_t number);
    [[nodiscard]] bool dispatch_bsd_process_information(
        Cpu& cpu, std::uint32_t number);
    [[nodiscard]] bool dispatch_bsd_memorystatus(
        Cpu& cpu, std::uint32_t number);
    [[nodiscard]] bool dispatch_bsd_process_policy(
        Cpu& cpu, std::uint32_t number);
    [[nodiscard]] bool dispatch_bsd_process_spawn(
        Cpu& cpu, std::uint32_t number);
    void dispatch_bsd_filesystem(Cpu& cpu, std::uint32_t number);
    [[nodiscard]] bool dispatch_bsd_filesystem_control(
        Cpu& cpu, std::uint32_t number);
    [[nodiscard]] bool dispatch_bsd_filesystem_ownership(
        Cpu& cpu, std::uint32_t number);
    [[nodiscard]] bool dispatch_bsd_filesystem_locking(
        Cpu& cpu, std::uint32_t number);
    [[nodiscard]] bool dispatch_bsd_record_locking(
        Cpu& cpu, std::uint32_t command);
    void release_record_locks_for_descriptor(std::uint32_t fd);
    [[nodiscard]] bool dispatch_bsd_filesystem_persistence(
        Cpu& cpu, std::uint32_t number);
    [[nodiscard]] bool dispatch_bsd_filesystem_timestamps(
        Cpu& cpu, std::uint32_t number);
    void dispatch_bsd_descriptor_memory(Cpu& cpu, std::uint32_t number);
    [[nodiscard]] bool dispatch_bsd_shared_region(
        Cpu& cpu, std::uint32_t number);
    [[nodiscard]] const DyldSharedCache* dyld_shared_cache_for(
        const std::filesystem::path& path);
    [[nodiscard]] bool dispatch_bsd_debug(Cpu& cpu, std::uint32_t number);
    [[nodiscard]] bool dispatch_bsd_security(Cpu& cpu, std::uint32_t number);
    void dispatch_bsd_code_signing(Cpu& cpu, bool require_audit_token = false);
    void dispatch_bsd_socket(Cpu& cpu, std::uint32_t number);
    void dispatch_bsd_kqueue(Cpu& cpu, std::uint32_t number);
    void dispatch_bsd_guarded_file(Cpu& cpu, std::uint32_t number);
    bool reject_guarded_descriptor(Cpu& cpu, std::uint32_t fd, std::uint32_t flags);
    void dispatch_bsd_events(Cpu& cpu, std::uint32_t number);
    [[nodiscard]] bool ioctl_bpf_device(Cpu& cpu, std::uint32_t fd);
    [[nodiscard]] bool create_kernel_control_socket(Cpu& cpu);
    [[nodiscard]] bool connect_kernel_control_socket(Cpu& cpu);
    [[nodiscard]] bool ioctl_kernel_control_socket(Cpu& cpu);
    [[nodiscard]] bool name_kernel_control_socket(Cpu& cpu, bool peer);
    [[nodiscard]] bool write_kernel_control_socket(
        Cpu& cpu, std::uint32_t fd, std::span<const std::byte> bytes);
    void dispatch_bsd_signal(Cpu& cpu, std::uint32_t number);
    void dispatch_mach(Cpu& cpu, std::uint32_t trap);
    [[nodiscard]] bool dispatch_mach_port_kernel_rpc_trap(
        Cpu& cpu, std::uint32_t trap);
    [[nodiscard]] bool dispatch_mach_vm_kernel_rpc_trap(
        Cpu& cpu, std::uint32_t trap);
    void dispatch_mach_message(Cpu& cpu,
        std::optional<std::uint32_t> receive_address = std::nullopt);
    [[nodiscard]] bool dispatch_mach_host_message(
        Cpu& cpu, const MachMessageRequest& request);
    [[nodiscard]] bool dispatch_mach_processor_message(
        Cpu& cpu, const MachMessageRequest& request);
    [[nodiscard]] bool dispatch_mach_port_message(
        Cpu& cpu, const MachMessageRequest& request);
    [[nodiscard]] bool dispatch_mach_port_context_message(
        Cpu& cpu, const MachMessageRequest& request);
    [[nodiscard]] bool dispatch_mach_port_limit_message(
        Cpu& cpu, const MachMessageRequest& request);
    [[nodiscard]] bool dispatch_mach_port_membership_message(
        Cpu& cpu, const MachMessageRequest& request);
    [[nodiscard]] bool dispatch_mach_port_query_message(
        Cpu& cpu, const MachMessageRequest& request);
    [[nodiscard]] bool dispatch_mach_task_vm_message(
        Cpu& cpu, const MachMessageRequest& request);
    [[nodiscard]] bool dispatch_mach_task_enumeration_message(
        Cpu& cpu, const MachMessageRequest& request);
    [[nodiscard]] bool dispatch_mach_task_info_message(
        Cpu& cpu, const MachMessageRequest& request);
    [[nodiscard]] bool dispatch_mach_task_exception_message(
        Cpu& cpu, const MachMessageRequest& request);
    [[nodiscard]] bool dispatch_mach_thread_state_message(
        Cpu& cpu, const MachMessageRequest& request);
    [[nodiscard]] bool dispatch_mach_thread_lifecycle_message(
        Cpu& cpu, const MachMessageRequest& request);
    void dispatch_mach_thread_self_trap(Cpu& cpu);
    [[nodiscard]] bool dispatch_mach_vm_allocate_message(
        Cpu& cpu, const MachMessageRequest& request);
    [[nodiscard]] bool dispatch_mach_vm_deallocate_message(
        Cpu& cpu, const MachMessageRequest& request);
    [[nodiscard]] bool dispatch_mach_vm_protect_message(
        Cpu& cpu, const MachMessageRequest& request);
    [[nodiscard]] bool dispatch_mach_vm_inherit_message(
        Cpu& cpu, const MachMessageRequest& request);
    [[nodiscard]] bool dispatch_mach_vm_copy_message(
        Cpu& cpu, const MachMessageRequest& request);
    [[nodiscard]] bool dispatch_mach_vm_read_message(
        Cpu& cpu, const MachMessageRequest& request);
    [[nodiscard]] bool dispatch_mach_vm_purgable_message(
        Cpu& cpu, const MachMessageRequest& request);
    [[nodiscard]] bool dispatch_mach_vm_memory_entry_message(
        Cpu& cpu, const MachMessageRequest& request);
    [[nodiscard]] bool dispatch_mach_vm_map_message(
        Cpu& cpu, const MachMessageRequest& request);
    [[nodiscard]] bool dispatch_mach_vm_remap_message(
        Cpu& cpu, const MachMessageRequest& request);
    [[nodiscard]] bool dispatch_mach_vm_region_message(
        Cpu& cpu, const MachMessageRequest& request);
    [[nodiscard]] bool dispatch_mach_rights_message(
        Cpu& cpu, const MachMessageRequest& request);
    [[nodiscard]] bool dispatch_mach_notification_message(
        Cpu& cpu, const MachMessageRequest& request);
    void bsd_success(
        Cpu& cpu, std::uint32_t value, std::uint32_t second_value = 0);
    void bsd_error(Cpu& cpu, std::uint32_t error);
    bool unmap_memory(Cpu& cpu, std::uint32_t address, std::uint32_t size);
    [[nodiscard]] bool protect_memory(Cpu& cpu, std::uint32_t address,
        std::uint32_t size, MemoryPermission permissions);
    void trace_unknown(Cpu& cpu, std::string kind, std::uint32_t number);
    [[nodiscard]] std::filesystem::path resolve_guest_path(
        const std::string& path, bool follow_final_symlink = true) const;
    [[nodiscard]] std::filesystem::path working_directory() const;
    void release_thread_directory_locked(std::uint32_t thread_object);
    [[nodiscard]] std::optional<std::filesystem::path> guest_path_of_host(
        const std::filesystem::path& host) const;
    [[nodiscard]] std::optional<std::uint32_t> current_thread_object() const;
    [[nodiscard]] std::optional<hfs::Metadata> query_hfs_metadata(
        const std::filesystem::path& path, bool follow_symlink,
        bool include_directory_entry_count = true) const;
    [[nodiscard]] std::optional<std::vector<std::byte>>
    query_hfs_named_attribute(const std::filesystem::path& path,
        bool follow_symlink, std::string_view name) const;
    [[nodiscard]] std::vector<std::string> query_hfs_named_attributes(
        const std::filesystem::path& path, bool follow_symlink) const;
    [[nodiscard]] std::uint32_t file_descriptor_limit() const;
    [[nodiscard]] std::optional<std::uint32_t> allocate_file_descriptor() const;
    void copy_kqueue_descriptor_state(
        std::uint32_t source, std::uint32_t destination);
    [[nodiscard]] std::shared_ptr<bsd::RegularFileOpenDescription>
    ensure_regular_file_open_description(std::uint32_t fd);
    bool write_guest_stat(std::uint32_t address,
        const std::filesystem::path& path, bool follow_symlink = true,
        int host_descriptor = -1);
    bool write_guest_device_stat(
        std::uint32_t address, std::uint32_t minor, bool character_device);
    bool write_guest_kqueue_stat(std::uint32_t address,
        std::uint64_t pending_event_count, bool stat64_layout);
    bool write_guest_stat64(std::uint32_t address,
        const std::filesystem::path& path, bool follow_symlink = true,
        int host_descriptor = -1);
    bool write_guest_device_stat64(
        std::uint32_t address, std::uint32_t minor, bool character_device);
    bool write_guest_statfs(
        std::uint32_t address, const hfs::VolumeMetadata& volume);
    bool write_guest_statfs64(
        std::uint32_t address, const hfs::VolumeMetadata& volume);
    std::size_t install_mapped_user_image(Cpu& cpu,
        const std::filesystem::path& image_path, std::uint32_t mapping_address,
        std::uint32_t mapping_size, std::uint64_t file_offset,
        bool shared_cache_mapping = false);
    void install_commpage();
    void configure_darwin_notify_state();
    bool deliver_pending_mach_if_ready_locked(
        Cpu& cpu, bool waking_blocked_receiver);
    [[nodiscard]] std::optional<std::size_t>
    preferred_pending_mach_receiver_locked(std::uint32_t queued_port);
    bool deliver_pending_mach_locked(Cpu& cpu, bool waking_blocked_receiver);
    struct MachReceiveResult {
        std::uint32_t status { };
        std::uint32_t message_size { };
    };
    [[nodiscard]] std::optional<MachReceiveResult> receive_mach_message_locked(
        PendingMachReceive& receive, bool queued_receiver,
        bool waking_blocked_receiver);
    [[nodiscard]] std::optional<MachReceiveResult> receive_kevent_mach_message(
        const KeventRegistration& registration, std::size_t processor,
        bool waking_blocked_receiver);
    bool deliver_pending_io_locked(Cpu& cpu);
    [[nodiscard]] bool pending_io_poll_required_locked(
        std::size_t processor) const;
    void remember_pending_io_not_ready_locked(std::size_t processor,
        std::uint64_t io_generation, std::uint64_t mach_generation);
    [[nodiscard]] std::optional<std::uint64_t>
    pending_io_deadline_locked(std::size_t processor) const;
    [[nodiscard]] bool pending_io_requires_host_poll_locked(
        std::size_t processor) const;
    [[nodiscard]] bool has_pending_event_locked(
        std::size_t processor) const;
    void refresh_pending_event_processor_locked(std::size_t processor);
    void note_timer_deadline_transition() noexcept;
    bool receive_socket_message(
        Cpu& cpu, std::uint32_t fd, std::uint32_t message_address);
    bool send_socket_message(Cpu& cpu, std::uint32_t fd,
        std::uint32_t message_address, std::uint32_t flags);
    bool send_host_socket_bytes(Cpu& cpu, std::uint32_t fd,
        std::vector<std::byte> bytes, std::vector<std::byte> destination,
        bool nonblocking);
    bool receive_bpf_bytes(
        Cpu& cpu, std::uint32_t fd, std::uint32_t address, std::uint32_t size);
    bool write_bpf_bytes(
        Cpu& cpu, std::uint32_t fd, std::uint32_t address, std::uint32_t size);
    [[nodiscard]] bool bpf_descriptor_readable(std::uint32_t fd) const;
    bool receive_socket_bytes(Cpu& cpu, std::uint32_t fd, std::uint32_t address,
        std::uint32_t size, std::uint32_t source_address = 0,
        std::uint32_t source_length_address = 0);
    bool copy_socket_address(std::uint32_t address,
        std::uint32_t length_address,
        std::span<const std::byte> socket_address);
    bool complete_unix_accept(Cpu& cpu, std::uint32_t listener_fd,
        std::uint32_t address, std::uint32_t length_address);
    [[nodiscard]] std::optional<std::uint32_t> install_host_socket(
        std::shared_ptr<HostSocket> socket);
    void apply_wifi_transition(
        const WifiSnapshot& before, const WifiSnapshot& after);
    void post_network_event(std::string_view interface_name,
        std::uint32_t event_subclass, std::uint32_t event_code,
        std::optional<darwin::network::InterfaceSnapshot> address_snapshot =
            std::nullopt);
    void post_data_link_event(
        std::string_view interface_name, std::uint32_t event_code);
    [[nodiscard]] bool system_event_matches(
        std::uint32_t fd, const KernelSharedState::KernelEvent& event) const;
    [[nodiscard]] bool system_event_available(std::uint32_t fd) const;
    [[nodiscard]] std::optional<KernelSharedState::KernelEvent>
    consume_system_event(std::uint32_t fd);
    [[nodiscard]] bool route_message_available(std::uint32_t fd) const;
    [[nodiscard]] std::optional<KernelSharedState::RouteSocketMessage>
    consume_route_message(std::uint32_t fd);
    void post_route_message(std::vector<std::byte> bytes, std::uint8_t family,
        std::optional<std::uint64_t> receiver_socket = std::nullopt);
    void synchronize_interface_routes(
        std::string_view interface_name, std::uint8_t family);
    [[nodiscard]] std::optional<KernelSharedState::DescriptorTransfer>
    export_descriptor(std::uint32_t fd) const;
    [[nodiscard]] std::optional<std::uint32_t> import_descriptor(
        const KernelSharedState::DescriptorTransfer& transfer);
    [[nodiscard]] bool descriptor_readable(std::uint32_t fd) const;
    [[nodiscard]] bool descriptor_writable(std::uint32_t fd) const;
    [[nodiscard]] bool descriptor_requires_host_poll(
        std::uint32_t fd) const;
    [[nodiscard]] bool descriptor_requires_host_poll(std::uint32_t fd,
        std::unordered_set<std::uint32_t>& visited) const;
    [[nodiscard]] bool descriptor_valid(std::uint32_t fd) const;
    [[nodiscard]] std::uint16_t descriptor_poll_revents(
        std::int32_t fd, std::uint16_t events) const;
    [[nodiscard]] std::optional<std::uint32_t> ready_mach_port_name(
        std::uint32_t name) const;
    [[nodiscard]] std::optional<std::uint32_t> ready_mach_kevent_name(
        const KeventRegistration& registration) const;
    [[nodiscard]] std::optional<std::uint32_t> socket_pending_byte_count(
        std::uint32_t fd, std::uint32_t& darwin_error) const;
    [[nodiscard]] std::shared_ptr<bsd::baseband_device::OpenDescription>
    baseband_open_description(std::uint32_t fd) const;
    [[nodiscard]] std::optional<std::uint32_t> collect_ready_kevents(
        std::size_t processor, std::uint32_t queue_fd, std::uint32_t event_address,
        std::uint32_t event_count, bool extended = false,
        bool waking_blocked_receiver = false);
    void detach_kevents_for_descriptor(std::uint32_t fd);
    using WokenThread = std::pair<std::uint32_t, std::uint32_t>;
    [[nodiscard]] std::uint32_t signal_semaphore_object_locked(
        std::uint32_t object, bool all, bool prepost = true,
        std::optional<WokenThread>* woken_thread = nullptr,
        std::vector<WokenThread>* woken_threads = nullptr);
    [[nodiscard]] std::uint32_t signal_semaphore_locked(std::uint32_t name,
        bool all, bool prepost = true,
        std::optional<WokenThread>* woken_thread = nullptr,
        std::vector<WokenThread>* woken_threads = nullptr);
    [[nodiscard]] std::uint32_t signal_semaphore_thread_locked(
        std::uint32_t semaphore_name, std::uint32_t thread_name,
        std::optional<WokenThread>* woken_thread = nullptr);
    void wake_thread_and_maybe_preempt(
        Cpu& cpu, const std::optional<WokenThread>& thread);
    void wake_threads_and_maybe_preempt(
        Cpu& cpu, std::span<const WokenThread> threads);
    void wait_on_semaphore(Cpu& cpu, std::uint32_t wait_name,
        std::uint32_t signal_name,
        std::optional<std::uint64_t> timeout_interval, bool bsd_result);
    void wait_on_semaphore_object(Cpu& cpu, std::uint32_t wait_object,
        std::optional<std::uint32_t> signal_object,
        std::optional<std::uint64_t> timeout_interval, bool bsd_result,
        std::uint32_t wait_trace_identifier,
        std::optional<std::uint32_t> signal_trace_identifier = std::nullopt);
    void schedule_due_audio_io(std::uint64_t deadline);
    void inject_wifi_driver_event(
        std::uint32_t descriptor, std::uint32_t event);
    void reap_stopped_audio_threads();

    AddressSpace& memory_;
    Output& output_;
    std::filesystem::path rootfs_;
    std::shared_ptr<const DyldSharedCache> dyld_shared_cache_;
    std::filesystem::path dyld_shared_cache_path_;
    bool dyld_shared_cache_attempted_ { };
    DeviceModel device_model_;
    hfs::VolumeLayout hfs_volumes_;
    hfs::MetadataProvider hfs_metadata_;
    std::shared_ptr<DisplayState> display_state_;
    std::shared_ptr<WifiState> wifi_state_ { std::make_shared<WifiState>() };
    std::shared_ptr<AudioService> audio_service_;
    std::shared_ptr<RingerSwitchState> ringer_switch_state_ {
        std::make_shared<RingerSwitchState>()
    };
    UserlandHleRegistry userland_hle_;
    HidEventSystemHle hid_event_system_hle_;
    SystemConfigurationHle system_configuration_hle_;
    DarwinNotifyStateHle darwin_notify_state_hle_;
    AudioToolboxHle audio_toolbox_hle_;
    CoreMediaHle core_media_hle_;
    CoreAudioHle core_audio_hle_;
    Apple80211Hle apple80211_hle_;
    std::shared_ptr<SurfaceStore> surface_store_ {
        std::make_shared<SurfaceStore>()
    };
    std::shared_ptr<PresentationTracker> presentation_tracker_ {
        std::make_shared<PresentationTracker>()
    };
    std::shared_ptr<SceneCoordinator> scene_coordinator_ {
        std::make_shared<SceneCoordinator>()
    };
    CoreSurfaceHle core_surface_hle_;
    OpenGlesHle opengles_hle_;
    Mbx2dHle mbx2d_hle_;
    MobileFramebufferHle mobile_framebuffer_hle_;
    std::filesystem::path guest_working_directory_ { "/" };
    static thread_local std::optional<std::size_t> syscall_processor_;
    std::string process_image_ { "/sbin/launchd" };
    ProcessContext process_;
    DarwinPthreadRuntime pthread_runtime_;
    std::map<std::uint32_t, std::filesystem::path> file_descriptors_;
    std::map<std::uint32_t, std::shared_ptr<bsd::RegularFileOpenDescription>>
        regular_file_open_descriptions_;
    std::map<std::uint32_t, std::pair<std::uint32_t, bool>>
        virtual_block_descriptors_;
    std::map<std::uint32_t, std::uint64_t> file_offsets_;
    std::map<std::filesystem::path, std::vector<DirectoryEntry>>
        directory_entries_cache_;
    std::map<std::uint32_t, std::uint32_t> file_status_flags_;
    std::map<std::uint32_t, std::uint32_t> descriptor_flags_;
    std::map<std::uint32_t, DarwinFileGuard> descriptor_guards_;
    std::map<std::uint32_t, AioCompletion> aio_completions_;
    std::unordered_map<std::uint32_t, std::string> virtual_descriptors_;
    std::map<std::uint32_t, std::uint32_t> posix_semaphore_descriptors_;
    std::map<std::uint32_t,
        std::shared_ptr<bsd::baseband_device::OpenDescription>>
        baseband_open_descriptions_;
    bsd::offline_serial_device::State offline_serial_state_;
    std::map<std::uint32_t, std::shared_ptr<darwin::bpf::DescriptorState>>
        bpf_descriptors_;
    std::map<std::uint32_t, std::shared_ptr<HostSocket>> host_sockets_;
    std::map<std::uint32_t,
        std::shared_ptr<darwin::network::apple80211_driver::EventStream>>
        wifi_driver_event_streams_;
    std::multimap<std::uint64_t, std::uint32_t> scheduled_wifi_driver_events_;
    std::map<std::uint32_t, std::shared_ptr<bsd::VirtualUdpSocket>>
        virtual_udp_sockets_;
    std::map<std::uint32_t, std::shared_ptr<bsd::kernel_control::Endpoint>>
        kernel_control_endpoints_;
    std::map<std::uint32_t, std::string> bound_socket_names_;
    std::set<std::uint32_t> listening_sockets_;
    std::map<std::uint32_t, std::shared_ptr<KernelSharedState::UnixListener>>
        unix_listener_states_;
    std::map<std::uint32_t, std::map<std::pair<std::uint32_t, std::uint32_t>,
                                std::vector<std::byte>>>
        socket_options_;
    std::map<std::uint32_t, std::uint32_t> duplicated_descriptors_;
    std::map<std::uint32_t, std::array<std::uint32_t, 3>> system_event_filters_;
    std::set<std::uint32_t> apple80211_scan_delivered_;
    std::map<std::uint32_t, std::uint32_t> system_event_next_identifiers_;
    std::map<std::uint32_t,
        std::shared_ptr<KernelSharedState::RouteSocketState>>
        route_socket_states_;
    std::map<std::uint32_t, SocketPairEndpoint> socket_pair_endpoints_;
    std::map<std::uint32_t, std::vector<KeventRegistration>> kqueues_;
    std::map<std::size_t, std::uint32_t> thread_ports_;
    std::map<std::uint32_t, std::uint32_t> vm_purgable_states_;
    std::set<std::size_t> disabled_thread_signals_;
    std::array<std::array<std::uint32_t, 4>, 32> signal_actions_ { };
    std::map<std::size_t, std::uint32_t> thread_signal_masks_;
    [[nodiscard]] std::uint32_t& signal_mask(std::size_t processor)
    {
        return thread_signal_masks_[processor];
    }
    void start_thread_signals(std::size_t processor,
        std::optional<std::size_t> creator, bool workqueue = false);
    void end_thread_signals(std::size_t processor);
    std::uint32_t pending_signals_ { };
    std::map<std::size_t, std::uint32_t> thread_pending_signals_;
    struct AlternateSignalStack {
        std::uint32_t base { };
        std::uint32_t size { };
        bool disabled { true };
        bool active { };
    };
    std::map<std::size_t, AlternateSignalStack> alternate_signal_stacks_;
    struct GuestSignalInfo {
        std::int32_t code { };
        std::uint32_t address { };
        std::uint32_t sender { };
        std::uint32_t sender_uid { };
        std::array<std::uint32_t, 3> exception_state { };
    };
    bool send_signal_frame(
        Cpu& cpu, std::uint32_t signal, const GuestSignalInfo& info);
    void dispatch_sigreturn(Cpu& cpu);
    void dispatch_sigaltstack(Cpu& cpu);
    std::uint64_t random_state_ { kDefaultRandomSeed };
    std::shared_ptr<KernelSharedState> shared_state_ {
        std::make_shared<KernelSharedState>()
    };
    ThreadCreateHandler thread_create_handler_;
    ThreadTerminateHandler thread_terminate_handler_;
    ThreadStateQuery thread_state_query_;
    ThreadStateUpdateHandler thread_state_update_handler_;
    ThreadPointerUpdateHandler thread_pointer_update_handler_;
    ThreadRunnableHandler thread_runnable_handler_;
    ProcessRunnableHandler process_runnable_handler_;
    ProcessSocketsShutdownHandler process_sockets_shutdown_handler_;
    ThreadWakeHandler thread_wake_handler_;
    ThreadSchedulingStateQuery thread_scheduling_state_query_;
    MachMessageWakeHandler mach_message_wake_handler_;
    ForkHandler fork_handler_;
    SpawnCreateHandler spawn_create_handler_;
    ExecHandler exec_handler_;
    SpawnExecHandler spawn_exec_handler_;
    MappedExecutableHandler mapped_executable_handler_;
    SchedulerRunnableQuery scheduler_runnable_query_;
    LegacyThreadPolicyHandler legacy_thread_policy_handler_;
    ThreadPolicyHandler thread_policy_handler_;
    TaskPriorityHandler task_priority_handler_;
    SchedulerPreemptionQuery scheduler_preemption_query_;
    SignalDeliveryHandler signal_delivery_handler_;
    TaskMemoryRegionQuery task_memory_region_query_;
    TaskMemoryShareQuery task_memory_share_query_;
    TaskMemoryRemapHandler task_memory_remap_handler_;
    std::map<std::size_t, SchedulerYieldRequest> scheduler_yields_;
    std::map<std::size_t, XnuThreadId> scheduler_handoffs_;
    std::map<std::size_t, PendingWait> pending_waits_;
    std::map<std::size_t, PendingMachReceive> pending_mach_receives_;
    std::map<std::size_t, std::uint64_t> last_delivered_graphics_inputs_;
    std::map<std::size_t, PendingKevent> pending_kevents_;
    std::map<std::size_t, PendingRecvmsg> pending_recvmsgs_;
    std::map<std::size_t, PendingSocketRead> pending_socket_reads_;
    std::map<std::size_t, PendingHostConnect> pending_host_connects_;
    std::map<std::size_t, PendingHostAccept> pending_host_accepts_;
    std::map<std::size_t, PendingHostWrite> pending_host_writes_;
    std::map<std::size_t, PendingBasebandWrite> pending_baseband_writes_;
    std::map<std::size_t, PendingUnixAccept> pending_unix_accepts_;
    std::map<std::size_t, PendingFlock> pending_flocks_;
    std::map<std::size_t, PendingRecordLock> pending_record_locks_;
    std::map<std::size_t, PendingPoll> pending_polls_;
    std::map<std::size_t, PendingSelect> pending_selects_;
    std::map<std::size_t, PendingTimer> pending_timers_;
    std::map<std::size_t, PendingSemaphoreWait> pending_semaphore_waits_;
    std::map<std::size_t, PendingPsynchWait> pending_psynch_waits_;
    std::map<std::size_t, PendingSignalSuspend> pending_signal_suspends_;
    struct PendingIoPollCache {
        std::uint64_t io_generation { };
        std::uint64_t mach_generation { };
        std::chrono::steady_clock::time_point next_host_probe;
        bool host_probe_required { };
    };
    std::map<std::size_t, PendingIoPollCache> pending_io_poll_cache_;
    std::set<std::size_t> pending_event_processors_;
    std::uint64_t pending_event_topology_generation_ { 1 };
    std::uint64_t pending_event_poll_topology_generation_ { };
    std::uint64_t pending_event_poll_io_generation_ { };
    std::uint64_t pending_event_poll_mach_generation_ { };
    std::optional<std::uint64_t> pending_event_poll_deadline_;
    std::chrono::steady_clock::time_point pending_event_host_probe_ {
        std::chrono::steady_clock::time_point::min()
    };
    bool pending_event_poll_observed_ { };
    mutable std::optional<std::uint64_t> local_timer_deadline_cache_;
    mutable bool local_timer_deadline_cache_valid_ { };
    std::uint32_t timer_trace_count_ { };
    std::uint32_t port_status_trace_count_ { };
    std::uint32_t thread_trace_count_ { };
    std::uint32_t mapping_trace_count_ { };
    std::uint32_t socket_payload_trace_count_ { };
    std::uint32_t semaphore_wait_trace_count_ { };
    std::uint32_t psynch_trace_count_ { };
    LayerKitHle layerkit_hle_;
    std::uint32_t baseband_io_trace_count_ { };
    std::optional<std::uint64_t> next_display_scanout_deadline_;
    std::uint32_t virtual_processor_count_ { 1 };
    HostNetworkPolicy host_network_policy_ { HostNetworkPolicy::Isolated };
    std::mutex mutex_;
    mutable std::mutex load_average_mutex_;
    foundation::LoadAverage load_average_;
    std::uint64_t next_load_average_sample_ { };
};

}
