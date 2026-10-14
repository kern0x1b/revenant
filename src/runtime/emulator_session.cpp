// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Own a boot session and coordinate guest scheduling, lifecycle, time
// and shutdown.

#include "runtime/emulator_session.hpp"
#include "crypto/key_store.hpp"
#include "debug/control_channel.hpp"
#include "foundation/host_memory.hpp"
#include "graphics/display_presenter.hpp"
#include "graphics/boot_logo.hpp"
#include "guest_timing.hpp"
#include "jit_diagnostics.hpp"
#include "jit_policy.hpp"
#include "process.hpp"
#include "resource_policy.hpp"
#include "runtime/live_button_scheduler.hpp"
#include "runtime/live_touch_scheduler.hpp"
#include "runtime/realtime_pacer.hpp"
#include "runtime/session_host.hpp"
#include "session_catalog.hpp"
#include "session_debugger.hpp"
#include "session_diagnostics.hpp"

#include <sys/random.h>

#include <algorithm>
#include <array>
#include <atomic>
#include <cerrno>
#include <cstring>
#include <bit>
#include <chrono>
#include <condition_variable>
#include <cstddef>
#include <cstdint>
#include <deque>
#include <exception>
#include <filesystem>
#include <fstream>
#include <functional>
#include <iomanip>
#include <iostream>
#include <limits>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <span>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <thread>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <variant>
#include <vector>

#include "debug/gdb_rsp.hpp"
#include "device_state/darwin_kernel_configuration.hpp"
#include "device_state/lockdown_state.hpp"
#include "device_state/network_preferences.hpp"
#include "foundation/address_space.hpp"
#include "foundation/cpu.hpp"
#include "foundation/deadline_queue.hpp"
#include "foundation/device_model.hpp"
#include "graphics/display.hpp"
#include "foundation/executable_catalog.hpp"
#include "foundation/firmware_prepare.hpp"
#include "foundation/guest_execution_coordinator.hpp"
#include "foundation/host_resource_controller.hpp"
#include "foundation/jit_artifact.hpp"
#include "foundation/jit_code_cache_governor.hpp"
#include "foundation/jit_translation_profile.hpp"
#include "foundation/jit_work_scheduler.hpp"
#include "foundation/jit_work_signal.hpp"
#include "foundation/macho.hpp"
#include "foundation/output.hpp"
#include "foundation/performance.hpp"
#include "foundation/process_loader.hpp"
#include "foundation/userland_hle.hpp"
#include "graphics/frame_file_presenter.hpp"
#include "graphics/gles_renderer.hpp"
#include "graphics/touch_replay.hpp"
#include "kernel/baseband_replay.hpp"
#include "kernel/darwin_abi.hpp"
#include "kernel/iokit_abi.hpp"
#include "kernel/kernel.hpp"
#include "kernel/mach_thread_policy_abi.hpp"
#include "mach/guest_dispatch_policy.hpp"
#include "mach/guest_execution_policy.hpp"
#include "mach/guest_parallelism_policy.hpp"
#include "mach/xnu_scheduler.hpp"
#include "network/virtual_network.hpp"
#include "network/wifi_state.hpp"

namespace shade {
using namespace runtime_detail;
namespace {

    // One 64-bit seed from the host's entropy source, for the guest's /dev/random at boot. A failure stops the boot: a fixed
    // fallback would hand every boot the same keys, which is what this seed exists to prevent.
    std::uint64_t host_random_seed()
    {
        std::uint64_t seed = 0;
        if (getentropy(&seed, sizeof seed) != 0) {
            throw std::runtime_error { "getentropy failed for the guest's random seed: " +
                                       std::string { std::strerror(errno) } };
        }
        return seed;
    }

    // What the CPU reported, as the ARM exception a kernel sees: nothing for a
    // stop that is not the guest's fault (an interpreter fallback).
    std::optional<CompatibilityKernel::GuestFault> guest_fault_of(
        const CpuRunResult& result, const Cpu& cpu)
    {
        using Kind = CompatibilityKernel::GuestFault::Kind;
        using Exception = Umbra::A32::Exception;
        if (result.exception_kind) {
            switch (*result.exception_kind) {
            case Exception::NoExecuteFault:
                return CompatibilityKernel::GuestFault { Kind::InstructionFetch,
                    result.exception_pc,
                    result.fault ? result.fault->address : result.exception_pc,
                    false };
            case Exception::UndefinedInstruction:
            case Exception::UnpredictableInstruction:
            case Exception::DecodeError:
                return CompatibilityKernel::GuestFault {
                    Kind::Undefined, result.exception_pc, result.exception_pc,
                    false };
            case Exception::Breakpoint:
                return CompatibilityKernel::GuestFault {
                    Kind::Breakpoint, result.exception_pc, result.exception_pc,
                    false };
            default:
                return std::nullopt;
            }
        }
        if (!result.fault)
            return std::nullopt;
        if (has_permission(result.fault->access, MemoryPermission::Execute)) {
            return CompatibilityKernel::GuestFault { Kind::InstructionFetch,
                result.fault->address, result.fault->address, false };
        }
        return CompatibilityKernel::GuestFault { Kind::DataAccess,
            cpu.registers()[15], result.fault->address,
            has_permission(result.fault->access, MemoryPermission::Write) };
    }
    // Mixed host-control and debugger sessions use a bounded poll fallback.
    constexpr auto host_event_poll_fallback = std::chrono::milliseconds { 4 };
    struct PreparedGuestSlice {
        XnuScheduledSlice scheduled;
        Runtime* runtime { };
        std::size_t thread_index { };
        GuestExecutionRequest execution;
        bool deferred_svc { };
    };

} // namespace

void EmulatorSession::run()
{
    if (started_)
        throw std::logic_error { "an emulator session can only run once" };
    started_ = true;
    const auto& options = options_;
    auto& host = host_;
    auto& output = output_;
    if (options.rootfs.empty())
        throw std::invalid_argument { "boot requires a firmware rootfs" };
    const auto darwin_configuration = resolve_darwin_configuration(
        options.rootfs, options.ios_build);
    if (darwin_configuration.abi_source == DarwinAbiSource::Unresolved) {
        throw std::runtime_error {
            "cannot select Darwin/ABI configuration: firmware iOS build is " +
            (darwin_configuration.abi_source_detail.empty()
                    ? std::string { "missing" }
                    : "unsupported (" +
                          darwin_configuration.abi_source_detail + ")") +
            "; provide a supported iOS build code"
        };
    }
    host.initialize_graphics();
    const auto& rootfs = options.rootfs;
    const auto host_cache = options.host_cache.empty()
                                ? default_host_cache_directory(rootfs)
                                : options.host_cache;
    const auto catalog_manifest = options.catalog.value_or(
        (host_cache / "executable-catalog.bin").string());
    auto device = options.device;
    const auto& darwin_abi = darwin_configuration.abi;
    SessionCatalog session_catalog { rootfs,
        arm_architecture_for_model(device.processor.model), catalog_manifest,
        output };
    const auto gles_backend = options.gles_backend;
    configure_gles_pipeline_cache(host_cache / "vulkan-pipeline-cache.bin");
    configure_gles_backend(gles_backend);
    const auto binary = options.binary;
    const auto guest_command = options.guest_command;
    std::vector<std::string> initial_arguments;
    if (guest_command) {
        // This is intentionally an argv-level test hook for firmware profiles
        // that ship a shell but do not ship SpringBoard. It never changes the
        // normal launchd/SpringBoard boot path.
        initial_arguments = { binary, "-c", *guest_command };
    } else {
        initial_arguments = { binary };
    }
    if (const auto display_size = options.display_geometry) {
        const auto profile_display = device.screen.panel;
        device.screen.panel = *display_size;
        // Preserve the explicit Retina split when a native framebuffer size is
        // overridden. Legacy profiles have one geometry, so their diagnostic
        // display-size option keeps the historical window/input behavior.
        if (device.screen.user_interface.width == profile_display.width &&
            device.screen.user_interface.height == profile_display.height) {
            device.screen.user_interface = device.screen.panel;
        }
    }
    output.line(
        "[device] product=" + std::string { device.identity.product_type } +
        " display=" + std::to_string(device.screen.panel.width) + "x" +
        std::to_string(device.screen.panel.height) +
        " ui=" + std::to_string(device.screen.user_interface.width) + "x" +
        std::to_string(device.screen.user_interface.height));
    output.line(
        "[abi-profile] kernel=" + darwin_configuration.identity.name +
        " initial-apple-vector=" +
        (darwin_abi.initial_apple_vector_abi ==
                    DarwinInitialAppleVectorAbi::LegacyExecutablePath
                ? "legacy-path"
                : "keyed-path"));
    output.line("[abi] contract=" + std::string { darwin_configuration.abi_name } +
                " source=" + std::string { darwin_abi_source_name(
                    darwin_configuration.abi_source) } +
                " detail=" + darwin_configuration.abi_source_detail);
    const auto activation = options.activation;
    const std::string activation_value =
        activation == LockdownActivation::Activated     ? "activated"
        : activation == LockdownActivation::Unactivated ? "unactivated"
                                                        : "preserve";
    const auto lockdown_capabilities = detect_lockdown_capabilities(
        rootfs, arm_architecture_for_model(device.processor.model));
    const auto activation_result =
        apply_lockdown_state(rootfs, activation, lockdown_capabilities);
    output.line(
        "[device-state] activation=" + activation_value +
        " path=" + activation_result.path.string() + " changed=" +
        std::to_string(activation_result.changed) + " registration-profile=" +
        std::to_string(lockdown_capabilities.registration_state) +
        " brick-profile=" + std::to_string(lockdown_capabilities.brick_state));
    const auto activation_override =
        activation == LockdownActivation::Preserve
            ? std::optional<bool> { }
            : std::optional<bool> { activation ==
                                    LockdownActivation::Activated };
    const auto activation_hardware_model_policy =
        darwin_abi.abi_epoch != DarwinAbiEpoch::Unknown
            ? darwin_abi.activation_hardware_model_policy
            : device.identity.activation_hardware_model_policy;
    if (activation_override && activation_override &&
        activation_hardware_model_policy ==
            ActivationHardwareModelPolicy::DevelopmentBoard) {
        // The stock daemon has a firmware-supported development-board escape
        // hatch for a device without a baseband/activation record. Selecting it
        // only for the explicit activated simulator profile leaves preserve
        // mode as the authentic retail contract.
        device.identity.hardware_model_override =
            device.identity.activation_hardware_model;
    }
    const auto ticks_option = options.ticks;
    const auto bounded_execution = ticks_option.has_value();
    const auto device_time_policy =
        bounded_execution ? DeviceTimePolicy::DeterministicExecution
                          : DeviceTimePolicy::HostMappedInteractive;
    const auto ticks = ticks_option ? *ticks_option
                                    : std::numeric_limits<std::uint64_t>::max();
    const bool disable_scheduler_preemption =
        options.disable_scheduler_preemption;
    const bool jit_observer_only = options.jit_observer_only;
    const auto jit_profile_mode = options.jit_profile_mode;
    const auto jit_catalog_warming_mode = options.jit_catalog_warming;
    const bool profile_enabled = jit_profile_mode != JitProfileMode::Off;
    const bool profile_recording_enabled =
        jit_profile_records(jit_profile_mode);
    const bool profile_loading_enabled = jit_profile_loads(jit_profile_mode);
    const bool profile_saving_enabled = jit_profile_saves(jit_profile_mode);
    const bool profile_precompile_enabled =
        jit_profile_precompiles(jit_profile_mode);
    const bool startup_profile_enabled =
        jit_profile_startup_work(jit_profile_mode);
    const bool idle_profile_enabled = jit_profile_idle_work(jit_profile_mode);
    const bool profile_background_warming_enabled = idle_profile_enabled;
    // Adaptive mode learns and reuses the current interactive working set only
    // on actual demand. Predictive Native imports and Portable persistence are
    // explicit idle/startup experiments: their host work must not become a
    // default foreground-launch tenant merely because a profile is present.
    const bool profile_offline_warming_enabled =
        jit_profile_mode == JitProfileMode::Idle;
    const auto startup_profile_blocks = options.startup_profile_blocks;
    const auto startup_profile_budget_us = options.startup_profile_budget_us;
    if (startup_profile_blocks == 0 || startup_profile_budget_us == 0)
        throw std::invalid_argument { "JIT startup budgets must be positive" };
    if (startup_profile_blocks > 64U) {
        throw std::runtime_error {
            "--jit-startup-profile-blocks must be in the range 1..64"
        };
    }
    output.line(
        std::string { "[jit-profile] mode=" } +
        std::string { jit_profile_mode_name(jit_profile_mode) } +
        " record=" + (profile_recording_enabled ? "enabled" : "disabled") +
        " load=" + (profile_loading_enabled ? "enabled" : "disabled") +
        " save=" + (profile_saving_enabled ? "enabled" : "disabled") +
        " idle=" + (idle_profile_enabled ? "enabled" : "disabled") +
        " offline=" +
        (profile_offline_warming_enabled ? "enabled" : "disabled") +
        " startup-sync=" + (startup_profile_enabled ? "enabled" : "disabled") +
        " catalog-warming=" +
        std::string {
            jit_catalog_warming_mode_name(jit_catalog_warming_mode) } +
        " blocks=" + std::to_string(startup_profile_blocks) +
        " budget-us=" + std::to_string(startup_profile_budget_us));
    if (disable_scheduler_preemption) {
        output.line("[scheduler] semantic-preemption=disabled "
                    "host-cooperation=enabled");
    }
    const auto default_processor_count =
        static_cast<std::size_t>(device.processor.topology.logical_cpu_count);
    if (!device.processor.topology.valid()) {
        throw std::runtime_error {
            "device profile has invalid guest CPU topology"
        };
    }
    const auto cpu_model = make_arm_cpu_model(
        device.processor.model, device.processor.frequency_hz());
    const auto guest_architecture = cpu_model->architecture_version();
    const auto guest_ticks_per_second = cpu_model->ticks_per_second();
    GuestTickClock guest_tick_clock { guest_ticks_per_second };
    const auto explicit_processor_count = options.cores;
    const auto guest_processor_count =
        explicit_processor_count.value_or(default_processor_count);
    if (guest_processor_count == 0 ||
        guest_processor_count > maximum_virtual_processors) {
        throw std::runtime_error { "--cores must be in the range 1.." +
                                   std::to_string(maximum_virtual_processors) };
    }
    if (explicit_processor_count) {
        output.line(
            "[cpu] mode=stress/dev cores=" +
            std::to_string(guest_processor_count) +
            " profile-cores=" + std::to_string(default_processor_count) +
            " warning=\"--cores overrides the device topology; execution-slot "
            "LDREX state follows the host slot and process-local "
            "ExclusiveMonitor does not model cross-process shared-page "
            "atomics\"");
    } else {
        output.line(
            "[cpu] mode=faithful guest-cores=" +
            std::to_string(guest_processor_count) + " physical-cores=" +
            std::to_string(device.processor.topology.physical_core_count) +
            " topology-cache-id=" +
            std::to_string(device.processor.topology.cache_topology_id));
    }
    const auto configured_jit_code_cache_size =
        (options.jit_cache_bytes
                ? *options.jit_cache_bytes
                : adaptive_jit_code_cache_size(host.memory_budget_snapshot()));
    const auto jit_cache_budget = jit_code_cache_budget(
        options.jit_cache_budget_bytes, host.memory_budget_snapshot());
    output.line("[jit] code-cache-mib=" +
                std::to_string(configured_jit_code_cache_size / 1024U / 1024U));
    output.line(
        "[jit] host-memory physical-mib=" +
        std::to_string(
            jit_cache_budget.memory.physical_bytes / bytes_per_mebibyte) +
        " available-mib=" +
        std::to_string(
            jit_cache_budget.memory.available_bytes / bytes_per_mebibyte) +
        " rss-mib=" +
        std::to_string(jit_cache_budget.memory.rss_bytes / bytes_per_mebibyte) +
        " cgroup-limit-mib=" +
        (!jit_cache_budget.memory.cgroup_limit_known
                ? std::string { "unlimited" }
                : std::to_string(jit_cache_budget.memory.cgroup_limit_bytes /
                                 bytes_per_mebibyte)) +
        " cgroup-current-mib=" +
        std::to_string(
            jit_cache_budget.memory.cgroup_current_bytes / bytes_per_mebibyte) +
        " budget-source=" +
        (jit_cache_budget.explicit_override ? "explicit" : "adaptive") +
        " physical-state=" +
        (jit_cache_budget.memory.physical_known ? "known" : "unavailable") +
        " available-state=" +
        (jit_cache_budget.memory.available_known ? "known" : "unavailable") +
        " rss-state=" +
        (jit_cache_budget.memory.rss_known ? "known" : "unavailable") +
        " cgroup-limit-state=" +
        (jit_cache_budget.memory.cgroup_limit_known ? "known" : "unavailable") +
        " cgroup-current-state=" +
        (jit_cache_budget.memory.cgroup_current_known ? "known"
                                                      : "unavailable") +
        " pressure=" +
        std::string { host_memory_pressure_name(jit_cache_budget.memory) } +
        " total-budget-mib=" +
        std::to_string(jit_cache_budget.total_bytes / bytes_per_mebibyte));
    std::unique_ptr<GuestExecutionCoordinator> guest_execution_coordinator;
    if (guest_processor_count > 1) {
        guest_execution_coordinator =
            std::make_unique<GuestExecutionCoordinator>(guest_processor_count);
    }
    const auto network_policy = options.network;
    const auto airport_configuration = NetworkPreferencesAirport {
        .interface_name = "en0",
        .mac_address = wifi_interface_mac_address,
        .ipv4 =
            NetworkPreferencesIpv4 {
                .address = virtual_network::client_address,
                .netmask = virtual_network::netmask,
                .gateway = virtual_network::gateway_address,
                .dns_servers = { virtual_network::dns_proxy_address },
            },
    };
    const auto network_preferences =
        ensure_network_preferences(rootfs, airport_configuration);
    auto preferred_wifi_networks = network_preferences.preferred_wifi_networks;
    output.line("[device-state] airport-service=" +
                (network_preferences.service_identifier.empty()
                        ? std::string { "unavailable" }
                        : network_preferences.service_identifier) +
                " path=" + network_preferences.path.string() +
                " supported=" + std::to_string(network_preferences.supported) +
                " changed=" + std::to_string(network_preferences.changed));
    if (options.quiet_output)
        output.set_verbose(false);
    std::unique_ptr<DisplayPresenter> display_presenter;
    std::unique_ptr<FrameFilePresenter> frame_file_presenter;
    std::unique_ptr<TouchReplay> touch_replay;
    std::unique_ptr<ControlChannel> live_control;
    LiveButtonScheduler live_button_scheduler;
    LiveTouchScheduler live_touch_scheduler;
    struct TransitionAttribution {
        std::mutex mutex;
        std::atomic<bool> internal_stability_active { false };
        std::uint64_t next_transition_id { };
        std::uint64_t active_transition_id { };
        bool awaiting_first_submission { };
        bool internal_stability_marker_emitted { };
        bool stability_baseline_set { };
        std::uint64_t input_complete_nanoseconds { };
        std::uint64_t first_submission_sequence { };
        std::uint64_t latest_content_revision { };
        std::uint64_t stability_baseline_vsync_pulses { };
        std::uint64_t stability_baseline_display_time { };
        std::uint64_t stability_observation_count { };
        std::uint64_t stability_content_reset_count { };
        std::uint64_t stability_last_observed_content_revision { };
        std::uint64_t stability_last_observed_vsync_pulses { };
        // Catch-ups to host time inside the window being counted, and the
        // guest time they moved on that the guest was owed and did not run.
        std::uint64_t stability_window_host_syncs { };
        std::uint64_t stability_window_starved_time { };
    } transition_attribution;
    std::optional<std::string> pending_touch_input_completion;
    std::optional<std::string> pending_button_input_completion;
    if (options.windowed) {
        display_presenter = host.create_display(device);
        if (!display_presenter)
            throw std::runtime_error {
                "host did not provide a display presenter"
            };
        if (const auto presenter =
                display_presenter->vulkan_presenter_configuration()) {
            configure_gles_vulkan_presenter(*presenter);
        }
    }
    auto gles_renderer = shared_gles_renderer();
    if (display_presenter)
        display_presenter->set_host_graphics(gles_renderer);
    output.line(
        "[gles] requested=" + std::string { gles_backend_name(gles_backend) } +
        " renderer=\"" + std::string { gles_renderer->name() } +
        "\" accelerated=" + std::to_string(gles_renderer->accelerated()) +
        " hardware-accelerated=" +
        std::to_string(gles_renderer->hardware_accelerated()) +
        " software-fallback=" +
        (gles_renderer->software_fallback_allowed() ? "allowed" : "disabled") +
        " direct-present=" +
        (gles_renderer->native_presentation_available() ? "yes" : "no"));
    struct RendererLifetime {
        std::shared_ptr<GlesRenderer>& renderer;
        DisplayPresenter* display;
        ~RendererLifetime()
        {
            if (display)
                display->set_host_graphics({ });
            renderer.reset();
            shutdown_gles_renderer();
        }
    } renderer_lifetime { gles_renderer, display_presenter.get() };
    if (const auto path = options.frame_output) {
        frame_file_presenter = std::make_unique<FrameFilePresenter>(*path);
    }
    if (const auto path = options.touch_replay) {
        touch_replay = std::make_unique<TouchReplay>(*path);
    }
    if (options.control_enabled) {
        live_control = host.create_control(device);
        if (!live_control)
            throw std::runtime_error {
                "host did not provide a control channel"
            };
        output.marker("[control] ready; use help for commands");
    }
    const auto gdb_port = options.gdb_port;
    const auto watch_address = options.watch_address;
    const auto baseband_input_path = options.baseband_input;
    const auto baseband_output_path = options.baseband_output;
    std::optional<std::ofstream> baseband_capture_stream;
    std::uint64_t baseband_capture_bytes { };
    if (baseband_output_path) {
        baseband_capture_stream.emplace(
            *baseband_output_path, std::ios::binary | std::ios::trunc);
        if (!*baseband_capture_stream) {
            throw std::runtime_error { "cannot open baseband capture output: " +
                                       *baseband_output_path };
        }
    }
    const auto baseband_input =
        baseband_input_path
            ? bsd::baseband_device::load_replay_file(*baseband_input_path)
            : std::vector<std::byte> { };
    // A replay input is the only fixture that supplies a device-side transport
    // contract. Without one, retain the common Offline/no-modem policy so a
    // missing radio cannot block the rest of the system.
    device.baseband.transport = baseband_input_path ? BasebandTransport::Virtual
                                                    : device.baseband.transport;

    auto initial_memory = std::make_unique<AddressSpace>();
    initial_memory->set_parallel_access(guest_processor_count > 1);
    ProcessLoader loader { rootfs, *initial_memory, guest_architecture,
        session_catalog.index(), darwin_abi.initial_apple_vector_abi, darwin_abi.address_layout };
    std::vector<std::string> initial_environment {
        "PATH=/usr/bin:/bin:/usr/sbin:/sbin", "HOME=/var/root", "SHELL=/bin/sh"
    };
    auto process =
        loader.load(binary, std::move(initial_arguments), initial_environment);
    // Umbra's global monitor indexes reservations by processor id. Reserve
    // disjoint ranges for boot-created Guest processes so same-address shared
    // mappings can invalidate reservations across process boundaries.
    Umbra::ExclusiveMonitor shared_exclusive_monitor {
        maximum_shared_monitor_slots
    };
    auto shared_exclusive_address_resolver =
        std::make_shared<GuestExclusiveAddressResolver>();
    std::size_t next_shared_monitor_slot { };
    const auto allocate_shared_monitor_slots = [&]() {
        if (guest_processor_count >
            maximum_shared_monitor_slots - next_shared_monitor_slot) {
            throw std::runtime_error {
                "shared exclusive monitor processor capacity exhausted"
            };
        }
        const auto base = next_shared_monitor_slot;
        next_shared_monitor_slot += guest_processor_count;
        return base;
    };
    JitCodeCacheGovernor jit_code_cache_governor {
        configured_jit_code_cache_size, jit_cache_budget.total_bytes
    };
    jit_code_cache_governor.set_pressure_limited(
        host_memory_is_pressured(jit_cache_budget.memory));
    output.line(
        "[jit] global-code-cache-budget-mib=" +
        std::to_string(jit_code_cache_governor.total_budget() / 1024U / 1024U));
    output.line(
        "[jit] shared-slab-map-mib=" +
        std::to_string(jit_code_cache_governor.shared_slab_cap(
                           JitCodeCacheClass::BootCritical) /
                       1024U / 1024U) +
        " retention-mib=critical:" +
        std::to_string(jit_code_cache_governor.retention_target(
                           JitCodeCacheClass::BootCritical) /
                       1024U / 1024U) +
        " interactive:" +
        std::to_string(jit_code_cache_governor.retention_target(
                           JitCodeCacheClass::Foreground) /
                       1024U / 1024U) +
        " background:" +
        std::to_string(jit_code_cache_governor.retention_target(
                           JitCodeCacheClass::Background) /
                       1024U / 1024U) +
        " pressure-limited=" +
        std::to_string(jit_code_cache_governor.pressure_limited() ? 1 : 0));
    RuntimeReaper runtime_reaper;
    std::vector<std::unique_ptr<Runtime>> runtimes;
    std::optional<RuntimeJitMemoryAggregate> runtime_jit_memory;
    if (performance_counters().enabled() || jit_observer_only)
        runtime_jit_memory.emplace();
    JitPrecompileMemoryStats concurrent_live_current_at_stop { };
    const auto observe_runtime_jit_memory = [&runtime_jit_memory](
                                                Runtime& runtime) {
        if (!runtime_jit_memory || !runtime.cpus ||
            !runtime.cpus->has_execution_resources()) {
            return;
        }
        runtime_jit_memory->observe(static_cast<const void*>(&runtime),
            runtime.cpus->precompile_memory_stats());
    };
    const auto observe_runtime_jit_memory_counted =
        [&runtime_jit_memory, &observe_runtime_jit_memory](Runtime& runtime) {
            if (!runtime_jit_memory)
                return;
            ++runtime_jit_memory->runtime_scan_iterations;
            observe_runtime_jit_memory(runtime);
        };
    std::optional<std::chrono::steady_clock::time_point>
        next_runtime_jit_sample;
    if (runtime_jit_memory && !jit_observer_only) {
        // Observer-only mode is lifecycle-accounted and takes one final atomic
        // snapshot. It must not periodically walk every live Runtime just to
        // produce a diagnostic line whose queue fields are final-state values.
        next_runtime_jit_sample =
            std::chrono::steady_clock::now() + std::chrono::milliseconds { 50 };
    }
    constexpr auto runtime_jit_sample_interval =
        std::chrono::milliseconds { 50 };
    const auto observe_all_runtime_jit_memory = [&]() {
        if (!runtime_jit_memory)
            return;
        runtime_jit_memory->runtime_scan_iterations += runtimes.size();
        for (auto& runtime : runtimes)
            observe_runtime_jit_memory(*runtime);
        next_runtime_jit_sample =
            std::chrono::steady_clock::now() + runtime_jit_sample_interval;
    };
    const auto observe_runtime_jit_memory_if_due = [&]() {
        if (jit_observer_only || !runtime_jit_memory ||
            !next_runtime_jit_sample ||
            std::chrono::steady_clock::now() < *next_runtime_jit_sample) {
            return;
        }
        observe_all_runtime_jit_memory();
    };
    const auto account_runtime_jit_memory =
        [&runtime_jit_memory](Runtime& runtime, bool already_observed = false) {
            if (!runtime_jit_memory || runtime.jit_memory_accounted ||
                !runtime.cpus || !runtime.cpus->has_execution_resources()) {
                return;
            }
            const auto key = static_cast<const void*>(&runtime);
            if (already_observed) {
                runtime_jit_memory->retire(key);
            } else {
                runtime_jit_memory->note_stats_sample();
                runtime_jit_memory->retire(
                    key, runtime.cpus->precompile_memory_stats());
            }
            runtime.jit_memory_accounted = true;
        };
    RuntimeIndex runtime_index;
    HostResourceBudget host_resource_budget;
    const auto host_concurrency =
        std::max<unsigned>(1U, std::thread::hardware_concurrency());
    const auto reserved_guest_workers =
        std::max<std::size_t>(1U, guest_processor_count);
    const auto spare_host_workers =
        host_concurrency > reserved_guest_workers
            ? static_cast<std::size_t>(host_concurrency) -
                  reserved_guest_workers
            : 0U;
    host_resource_budget.worker_count = std::clamp(
        spare_host_workers, std::size_t { 0 }, maximum_background_workers);
    const auto translation_lanes =
        JitWorkScheduler::recommended_translation_lanes(
            host_resource_budget.worker_count);
    if (host_resource_budget.worker_count != 0U) {
        // The core policy reserves at least half of a multi-worker pool for
        // Guest-adjacent services. Host admission accounts concurrent compile
        // wall time as aggregate worker-time while retaining per-task deadline
        // protection.
        host_resource_budget.interactive_compile_budget =
            host_resource_budget.duty_period *
            static_cast<std::int64_t>(translation_lanes);
    }
    output.line(
        "[host] background-workers=" +
        std::to_string(host_resource_budget.worker_count) +
        " translation-lanes=" + std::to_string(translation_lanes) +
        " host-concurrency=" + std::to_string(host_concurrency) +
        " guest-workers-reserved=" + std::to_string(reserved_guest_workers));
    HostResourceController host_resources { host_resource_budget };
    std::unique_ptr<JitTranslationProfileStore> translation_profiles;
    if (profile_enabled) {
        translation_profiles = std::make_unique<JitTranslationProfileStore>(
            host_cache / "jit-translation-profiles", profile_saving_enabled);
    }
    JitArtifactLimits jit_artifact_limits;
    jit_artifact_limits.resident_bytes = options.artifact_memory_bytes;
    constexpr auto minimum_artifact_free_bytes =
        std::uintmax_t { 128U } * 1024U * 1024U;
    constexpr auto maximum_artifact_disk_bytes =
        std::uintmax_t { 4U } * 1024U * 1024U * 1024U;
    jit_artifact_limits.minimum_free_bytes = minimum_artifact_free_bytes;
    const auto configured_disk_bytes = options.artifact_disk_bytes;
    const auto artifact_filesystem =
        nearest_existing_filesystem_path(host_cache);
    if (configured_disk_bytes) {
        const auto configured_bytes = *configured_disk_bytes;
        if (configured_bytes == 0U) {
            jit_artifact_limits.persistence_enabled = false;
        } else {
            jit_artifact_limits.persistence_bytes = static_cast<std::size_t>(
                std::min(configured_bytes, maximum_artifact_disk_bytes));
        }
    } else {
        std::error_code disk_space_error;
        const auto disk_space =
            std::filesystem::space(artifact_filesystem, disk_space_error);
        if (!disk_space_error &&
            disk_space.available > minimum_artifact_free_bytes) {
            const auto available_budget =
                disk_space.available - minimum_artifact_free_bytes;
            jit_artifact_limits.persistence_bytes = static_cast<std::size_t>(
                std::min(available_budget, maximum_artifact_disk_bytes));
        } else {
            jit_artifact_limits.persistence_enabled = false;
        }
    }
    output.line(
        "[jit-artifact] memory-mib=" +
        std::to_string(jit_artifact_limits.resident_bytes / 1024U / 1024U) +
        " writeback-mib=" +
        std::to_string(jit_artifact_limits.writeback_bytes / 1024U / 1024U) +
        " disk-mib=" +
        std::to_string(jit_artifact_limits.persistence_bytes / 1024U / 1024U) +
        " persistence=" +
        (jit_artifact_limits.persistence_enabled ? "enabled" : "disabled") +
        " filesystem=" +
        (artifact_filesystem.empty() ? std::string { "unavailable" }
                                     : artifact_filesystem.string()));
    auto jit_artifacts = std::make_shared<JitArtifactStore>(
        host_cache / "jit-artifacts.bin", jit_artifact_limits);
    std::shared_ptr<HostWorkToken> artifact_compaction_task;
    std::shared_ptr<ArtifactCompactionTaskRecord> artifact_compaction_record;
    ArtifactCompactionAdmission artifact_compaction_admission {
        ArtifactCompactionAdmission::Config { std::chrono::milliseconds { 2 },
            std::chrono::seconds { 15 }, std::chrono::milliseconds { 250 },
            std::chrono::milliseconds { 2 } }
    };
    constexpr auto artifact_compaction_deadline_reserve =
        std::chrono::milliseconds { 2 };
    struct ArtifactCompactionTelemetry {
        std::atomic<std::uint64_t> next_task_id { 1U };
        std::atomic<std::uint64_t> admitted { };
        std::atomic<std::uint64_t> rejected { };
        std::atomic<std::uint64_t> cancellation_requests { };
        std::atomic<std::uint64_t> completed { };
        std::atomic<std::uint64_t> cancelled_before_start { };
        std::atomic<std::uint64_t> cancelled_in_progress { };
        std::atomic<std::uint64_t> failures { };
        std::atomic<std::uint64_t> outstanding { };
        std::atomic<std::uint64_t> worker_execution_count { };
        std::atomic<std::uint64_t> worker_execution_total_nanoseconds { };
        std::atomic<std::uint64_t> worker_execution_max_nanoseconds { };
        std::atomic<std::uint64_t> lifecycle_count { };
        std::atomic<std::uint64_t> lifecycle_total_nanoseconds { };
        std::atomic<std::uint64_t> lifecycle_max_nanoseconds { };
        std::atomic<std::uint64_t> cancellation_observed_count { };
        std::atomic<std::uint64_t>
            cancellation_request_to_observed_nanoseconds { };
        std::atomic<std::uint64_t>
            cancellation_request_to_observed_max_nanoseconds { };
        std::atomic<std::uint64_t> lock_wait_total_nanoseconds { };
        std::atomic<std::uint64_t> lock_wait_max_nanoseconds { };
        std::atomic<std::uint64_t> snapshot_total_nanoseconds { };
        std::atomic<std::uint64_t> snapshot_max_nanoseconds { };
        std::atomic<std::uint64_t> save_total_nanoseconds { };
        std::atomic<std::uint64_t> save_max_nanoseconds { };
        std::atomic<std::uint64_t> cleanup_total_nanoseconds { };
        std::atomic<std::uint64_t> cleanup_max_nanoseconds { };
        std::atomic<std::uint64_t> rename_total_nanoseconds { };
        std::atomic<std::uint64_t> rename_max_nanoseconds { };
        std::atomic<std::uint64_t> return_total_nanoseconds { };
        std::atomic<std::uint64_t> return_max_nanoseconds { };
        std::atomic<std::uint64_t> bytes_before_cancel { };
        std::atomic<std::uint64_t> records_before_cancel { };
        std::atomic<std::uint64_t> temporary_cleanup_attempted { };
        std::atomic<std::uint64_t> temporary_cleanup_succeeded { };
        std::atomic<std::uint64_t> temporary_cleanup_failed { };
        std::atomic<std::uint64_t> temporary_residue_found { };
        std::mutex timing_samples_mutex;
        std::vector<std::uint64_t> cancellation_request_to_observed_samples;
        std::vector<std::uint64_t> lifecycle_samples;
        std::vector<std::uint64_t> lock_wait_samples;
        std::vector<std::uint64_t> snapshot_samples;
        std::vector<std::uint64_t> save_samples;
        std::vector<std::uint64_t> cleanup_samples;
        std::vector<std::uint64_t> rename_samples;
        std::vector<std::uint64_t> return_samples;
    } artifact_compaction_telemetry;
    const auto atomic_max = [](std::atomic<std::uint64_t>& target,
                                std::uint64_t value) {
        auto current = target.load(std::memory_order_relaxed);
        while (current < value &&
               !target.compare_exchange_weak(current, value,
                   std::memory_order_relaxed, std::memory_order_relaxed)) { }
    };
    const auto steady_nanoseconds = [] {
        return static_cast<std::uint64_t>(
            std::chrono::duration_cast<std::chrono::nanoseconds>(
                std::chrono::steady_clock::now().time_since_epoch())
                .count());
    };
    // A transition is watched until the display content has not changed for
    // internal_stability_vsync_pulses display periods of guest time; its
    // internal-stable marker says so. An input's transition is watched from
    // the first frame submitted after it; a settle's from the frame on screen,
    // since nothing may be drawn again.
    const auto begin_transition = [&](std::uint64_t started_at,
                                      std::uint64_t on_screen) {
        transition_attribution.active_transition_id =
            ++transition_attribution.next_transition_id;
        transition_attribution.internal_stability_active.store(
            true, std::memory_order_release);
        transition_attribution.input_complete_nanoseconds = started_at;
        transition_attribution.awaiting_first_submission = on_screen == 0;
        transition_attribution.internal_stability_marker_emitted = false;
        transition_attribution.stability_baseline_set = false;
        transition_attribution.first_submission_sequence = on_screen;
        transition_attribution.latest_content_revision = 0;
        transition_attribution.stability_baseline_vsync_pulses = 0;
        transition_attribution.stability_baseline_display_time = 0;
        transition_attribution.stability_observation_count = 0;
        transition_attribution.stability_content_reset_count = 0;
        transition_attribution.stability_last_observed_content_revision = 0;
        transition_attribution.stability_last_observed_vsync_pulses = 0;
        transition_attribution.stability_window_host_syncs = 0;
        transition_attribution.stability_window_starved_time = 0;
    };
    const auto mark_transition_input_complete = [&](std::string_view kind) {
        const auto completed_at = steady_nanoseconds();
        if (!runtimes.empty())
            runtimes.front()
                ->kernel->mark_foreground_transition_input_complete();
        std::lock_guard lock { transition_attribution.mutex };
        begin_transition(completed_at, 0);
        output.marker(
            "[transition] input-complete id=" +
            std::to_string(transition_attribution.active_transition_id) +
            " kind=" + std::string { kind } +
            " completed-ns=" + std::to_string(completed_at));
    };
    const auto begin_settle = [&]() {
        const auto started_at = steady_nanoseconds();
        const auto on_screen = runtimes.empty()
            ? std::uint64_t { 0 }
            : runtimes.front()->kernel->display_submitted_frames();
        std::lock_guard lock { transition_attribution.mutex };
        begin_transition(started_at, on_screen);
        output.marker(
            "[transition] settle id=" +
            std::to_string(transition_attribution.active_transition_id) +
            " sequence=" + std::to_string(on_screen) +
            " started-ns=" + std::to_string(started_at));
    };
    const auto timing_p95 =
        [&artifact_compaction_telemetry](
            std::vector<std::uint64_t> ArtifactCompactionTelemetry::* field) {
            std::vector<std::uint64_t> samples;
            {
                const std::lock_guard lock {
                    artifact_compaction_telemetry.timing_samples_mutex
                };
                const auto& source = artifact_compaction_telemetry.*field;
                samples.assign(source.begin(), source.end());
            }
            if (samples.empty())
                return std::uint64_t { 0U };
            const auto rank = (samples.size() * 95U + 99U) / 100U;
            const auto index = rank == 0U ? 0U : rank - 1U;
            auto selected = samples.begin() +
                            static_cast<std::ptrdiff_t>(std::min<std::size_t>(
                                index, samples.size() - 1U));
            std::nth_element(samples.begin(), selected, samples.end());
            return *selected;
        };
    const auto record_timing_sample =
        [&artifact_compaction_telemetry](
            std::vector<std::uint64_t> ArtifactCompactionTelemetry::* field,
            std::uint64_t value) {
            if (value == 0U)
                return;
            const std::lock_guard lock {
                artifact_compaction_telemetry.timing_samples_mutex
            };
            (artifact_compaction_telemetry.*field).push_back(value);
        };
    const auto observe_compaction_execution =
        [&artifact_compaction_telemetry, &atomic_max](std::uint64_t elapsed) {
            artifact_compaction_telemetry.worker_execution_count.fetch_add(
                1U, std::memory_order_relaxed);
            artifact_compaction_telemetry.worker_execution_total_nanoseconds
                .fetch_add(elapsed, std::memory_order_relaxed);
            atomic_max(
                artifact_compaction_telemetry.worker_execution_max_nanoseconds,
                elapsed);
        };
    const auto observe_compaction_terminal =
        [&artifact_compaction_telemetry, &atomic_max, &record_timing_sample](
            const ArtifactCompactionTaskRecord& record,
            ArtifactCompactionTaskState terminal, std::uint64_t terminal_time,
            std::uint64_t cancellation_observed,
            std::uint64_t bytes_before_cancel,
            std::uint64_t records_before_cancel,
            std::uint64_t cleanup_attempted, std::uint64_t cleanup_succeeded,
            std::uint64_t cleanup_failed, std::uint64_t cleanup_residue,
            std::uint64_t lock_wait_nanoseconds,
            std::uint64_t snapshot_nanoseconds, std::uint64_t save_nanoseconds,
            std::uint64_t cleanup_nanoseconds, std::uint64_t rename_nanoseconds,
            std::uint64_t return_nanoseconds) {
            switch (terminal) {
            case ArtifactCompactionTaskState::Completed:
                artifact_compaction_telemetry.completed.fetch_add(
                    1U, std::memory_order_relaxed);
                break;
            case ArtifactCompactionTaskState::CancelledBeforeStart:
                artifact_compaction_telemetry.cancelled_before_start.fetch_add(
                    1U, std::memory_order_relaxed);
                break;
            case ArtifactCompactionTaskState::CancelledInProgress:
                artifact_compaction_telemetry.cancelled_in_progress.fetch_add(
                    1U, std::memory_order_relaxed);
                break;
            case ArtifactCompactionTaskState::Failed:
                artifact_compaction_telemetry.failures.fetch_add(
                    1U, std::memory_order_relaxed);
                break;
            case ArtifactCompactionTaskState::Queued:
            case ArtifactCompactionTaskState::Running:
                return;
            }
            artifact_compaction_telemetry.outstanding.fetch_sub(
                1U, std::memory_order_relaxed);
            const auto lifecycle =
                terminal_time >= record.admitted_nanoseconds()
                    ? terminal_time - record.admitted_nanoseconds()
                    : 0U;
            artifact_compaction_telemetry.lifecycle_count.fetch_add(
                1U, std::memory_order_relaxed);
            artifact_compaction_telemetry.lifecycle_total_nanoseconds.fetch_add(
                lifecycle, std::memory_order_relaxed);
            atomic_max(artifact_compaction_telemetry.lifecycle_max_nanoseconds,
                lifecycle);
            artifact_compaction_telemetry.bytes_before_cancel.fetch_add(
                bytes_before_cancel, std::memory_order_relaxed);
            artifact_compaction_telemetry.records_before_cancel.fetch_add(
                records_before_cancel, std::memory_order_relaxed);
            artifact_compaction_telemetry.temporary_cleanup_attempted.fetch_add(
                cleanup_attempted, std::memory_order_relaxed);
            artifact_compaction_telemetry.temporary_cleanup_succeeded.fetch_add(
                cleanup_succeeded, std::memory_order_relaxed);
            artifact_compaction_telemetry.temporary_cleanup_failed.fetch_add(
                cleanup_failed, std::memory_order_relaxed);
            artifact_compaction_telemetry.temporary_residue_found.fetch_add(
                cleanup_residue, std::memory_order_relaxed);
            artifact_compaction_telemetry.lock_wait_total_nanoseconds.fetch_add(
                lock_wait_nanoseconds, std::memory_order_relaxed);
            atomic_max(artifact_compaction_telemetry.lock_wait_max_nanoseconds,
                lock_wait_nanoseconds);
            artifact_compaction_telemetry.snapshot_total_nanoseconds.fetch_add(
                snapshot_nanoseconds, std::memory_order_relaxed);
            atomic_max(artifact_compaction_telemetry.snapshot_max_nanoseconds,
                snapshot_nanoseconds);
            artifact_compaction_telemetry.save_total_nanoseconds.fetch_add(
                save_nanoseconds, std::memory_order_relaxed);
            atomic_max(artifact_compaction_telemetry.save_max_nanoseconds,
                save_nanoseconds);
            artifact_compaction_telemetry.cleanup_total_nanoseconds.fetch_add(
                cleanup_nanoseconds, std::memory_order_relaxed);
            atomic_max(artifact_compaction_telemetry.cleanup_max_nanoseconds,
                cleanup_nanoseconds);
            artifact_compaction_telemetry.rename_total_nanoseconds.fetch_add(
                rename_nanoseconds, std::memory_order_relaxed);
            atomic_max(artifact_compaction_telemetry.rename_max_nanoseconds,
                rename_nanoseconds);
            artifact_compaction_telemetry.return_total_nanoseconds.fetch_add(
                return_nanoseconds, std::memory_order_relaxed);
            atomic_max(artifact_compaction_telemetry.return_max_nanoseconds,
                return_nanoseconds);
            record_timing_sample(
                &ArtifactCompactionTelemetry::lifecycle_samples, lifecycle);
            record_timing_sample(
                &ArtifactCompactionTelemetry::lock_wait_samples,
                lock_wait_nanoseconds);
            record_timing_sample(&ArtifactCompactionTelemetry::snapshot_samples,
                snapshot_nanoseconds);
            record_timing_sample(
                &ArtifactCompactionTelemetry::save_samples, save_nanoseconds);
            record_timing_sample(&ArtifactCompactionTelemetry::cleanup_samples,
                cleanup_nanoseconds);
            record_timing_sample(&ArtifactCompactionTelemetry::rename_samples,
                rename_nanoseconds);
            record_timing_sample(&ArtifactCompactionTelemetry::return_samples,
                return_nanoseconds);
            const auto requested = record.cancellation_requested_nanoseconds();
            if ((terminal ==
                        ArtifactCompactionTaskState::CancelledBeforeStart ||
                    terminal ==
                        ArtifactCompactionTaskState::CancelledInProgress) &&
                requested != 0U && cancellation_observed >= requested) {
                const auto elapsed = cancellation_observed - requested;
                artifact_compaction_telemetry.cancellation_observed_count
                    .fetch_add(1U, std::memory_order_relaxed);
                artifact_compaction_telemetry
                    .cancellation_request_to_observed_nanoseconds.fetch_add(
                        elapsed, std::memory_order_relaxed);
                atomic_max(
                    artifact_compaction_telemetry
                        .cancellation_request_to_observed_max_nanoseconds,
                    elapsed);
                record_timing_sample(
                    &ArtifactCompactionTelemetry::
                        cancellation_request_to_observed_samples,
                    elapsed);
            }
        };
    const auto precompile_phase_for_lifecycle =
        [](bool interactive_activation) {
            return interactive_activation
                       ? JitPrecompilePhase::InteractiveActivation
                       : JitPrecompilePhase::PriorStartup;
        };
    struct PrecompileOutcomeCounters {
        std::atomic<std::uint64_t> elapsed_nanoseconds { };
        std::atomic<std::uint64_t> attempted { };
        std::atomic<std::uint64_t> native_compiled { };
        std::atomic<std::uint64_t> portable_generated { };
        std::atomic<std::uint64_t> portable_artifact_hits { };
        std::atomic<std::uint64_t> artifact_imported { };
        std::atomic<std::uint64_t> artifact_probe_hits { };
        std::atomic<std::uint64_t> shared_slab_hits { };
        std::atomic<std::uint64_t> deferred { };
        std::atomic<std::uint64_t> unstable { };
        std::atomic<std::uint64_t> cache_full { };
        std::atomic<std::uint64_t> failed { };
        std::atomic<std::uint64_t> cancelled { };
        std::atomic<std::uint64_t> deadline_stops { };
    } precompile_outcomes;
    struct PrecompileSourceOutcomeCounters {
        std::atomic<std::uint64_t> elapsed_nanoseconds { };
        std::atomic<std::uint64_t> attempted { };
        std::atomic<std::uint64_t> native_compiled { };
        std::atomic<std::uint64_t> portable_generated { };
        std::atomic<std::uint64_t> portable_artifact_hits { };
        std::atomic<std::uint64_t> artifact_imported { };
        std::atomic<std::uint64_t> artifact_probe_hits { };
        std::atomic<std::uint64_t> shared_slab_hits { };
        std::atomic<std::uint64_t> deferred { };
        std::atomic<std::uint64_t> unstable { };
        std::atomic<std::uint64_t> cache_full { };
        std::atomic<std::uint64_t> failed { };
        std::atomic<std::uint64_t> cancelled { };
    };
    std::array<PrecompileSourceOutcomeCounters, jit_precompile_source_count>
        precompile_source_outcomes { };
    enum class PrecompileScheduleSkip : std::uint8_t {
        NoRuntime,
        TaskBusy,
        NoPhase,
        MemoryPressure,
        DisplayQuiet,
        GuestNotIdle,
        DeadlineReserve,
        ZeroBudget,
        HostRejected,
        Count,
    };
    constexpr auto precompile_schedule_skip_count =
        static_cast<std::size_t>(PrecompileScheduleSkip::Count);
    JitWorkScheduler jit_work_scheduler;
    auto jit_work_signal = std::make_shared<JitWorkObservationSignal>();
    std::array<std::uint64_t, precompile_schedule_skip_count>
        precompile_schedule_skips { };
    const auto record_precompile_schedule_skip =
        [&precompile_schedule_skips](PrecompileScheduleSkip reason) {
            ++precompile_schedule_skips[static_cast<std::size_t>(reason)];
        };
    const auto record_jit_schedule_skips =
        [&precompile_schedule_skips](const JitWorkSchedule& schedule) {
            const auto core_count = [&schedule](JitWorkScheduleSkip reason) {
                return schedule.skipped[static_cast<std::size_t>(reason)];
            };
            precompile_schedule_skips[static_cast<std::size_t>(
                PrecompileScheduleSkip::NoRuntime)] +=
                core_count(JitWorkScheduleSkip::NoCandidate);
            precompile_schedule_skips[static_cast<std::size_t>(
                PrecompileScheduleSkip::TaskBusy)] +=
                core_count(JitWorkScheduleSkip::WorkerBusy);
            precompile_schedule_skips[static_cast<std::size_t>(
                PrecompileScheduleSkip::NoPhase)] +=
                core_count(JitWorkScheduleSkip::NoWork);
            precompile_schedule_skips[static_cast<std::size_t>(
                PrecompileScheduleSkip::MemoryPressure)] +=
                core_count(JitWorkScheduleSkip::MemoryPressure);
            precompile_schedule_skips[static_cast<std::size_t>(
                PrecompileScheduleSkip::DisplayQuiet)] +=
                core_count(JitWorkScheduleSkip::DisplayBusy);
            precompile_schedule_skips[static_cast<std::size_t>(
                PrecompileScheduleSkip::GuestNotIdle)] +=
                core_count(JitWorkScheduleSkip::GuestBusy);
            precompile_schedule_skips[static_cast<std::size_t>(
                PrecompileScheduleSkip::DeadlineReserve)] +=
                core_count(JitWorkScheduleSkip::DeadlineReserve);
            precompile_schedule_skips[static_cast<std::size_t>(
                PrecompileScheduleSkip::ZeroBudget)] +=
                core_count(JitWorkScheduleSkip::ZeroBudget);
        };
    const auto record_precompile_outcomes =
        [&precompile_outcomes, &precompile_source_outcomes](
            const JitPrecompileBatchResult& result,
            JitPrecompileSource source) {
            precompile_outcomes.elapsed_nanoseconds.fetch_add(
                result.elapsed_nanoseconds, std::memory_order_relaxed);
            precompile_outcomes.attempted.fetch_add(
                result.attempted, std::memory_order_relaxed);
            precompile_outcomes.native_compiled.fetch_add(
                result.native_compiled, std::memory_order_relaxed);
            precompile_outcomes.portable_generated.fetch_add(
                result.portable_generated, std::memory_order_relaxed);
            precompile_outcomes.portable_artifact_hits.fetch_add(
                result.portable_artifact_hits, std::memory_order_relaxed);
            precompile_outcomes.artifact_imported.fetch_add(
                result.artifact_imported, std::memory_order_relaxed);
            precompile_outcomes.artifact_probe_hits.fetch_add(
                result.artifact_probe_hits, std::memory_order_relaxed);
            precompile_outcomes.shared_slab_hits.fetch_add(
                result.shared_slab_hits, std::memory_order_relaxed);
            precompile_outcomes.deferred.fetch_add(
                result.deferred, std::memory_order_relaxed);
            precompile_outcomes.unstable.fetch_add(
                result.unstable, std::memory_order_relaxed);
            precompile_outcomes.cache_full.fetch_add(
                result.cache_full, std::memory_order_relaxed);
            precompile_outcomes.failed.fetch_add(
                result.failed, std::memory_order_relaxed);
            precompile_outcomes.cancelled.fetch_add(
                result.cancelled, std::memory_order_relaxed);
            precompile_outcomes.deadline_stops.fetch_add(
                result.deadline_stops, std::memory_order_relaxed);
            auto& source_outcome =
                precompile_source_outcomes[static_cast<std::size_t>(source)];
            source_outcome.elapsed_nanoseconds.fetch_add(
                result.elapsed_nanoseconds, std::memory_order_relaxed);
            source_outcome.attempted.fetch_add(
                result.attempted, std::memory_order_relaxed);
            source_outcome.native_compiled.fetch_add(
                result.native_compiled, std::memory_order_relaxed);
            source_outcome.portable_generated.fetch_add(
                result.portable_generated, std::memory_order_relaxed);
            source_outcome.portable_artifact_hits.fetch_add(
                result.portable_artifact_hits, std::memory_order_relaxed);
            source_outcome.artifact_imported.fetch_add(
                result.artifact_imported, std::memory_order_relaxed);
            source_outcome.artifact_probe_hits.fetch_add(
                result.artifact_probe_hits, std::memory_order_relaxed);
            source_outcome.shared_slab_hits.fetch_add(
                result.shared_slab_hits, std::memory_order_relaxed);
            source_outcome.deferred.fetch_add(
                result.deferred, std::memory_order_relaxed);
            source_outcome.unstable.fetch_add(
                result.unstable, std::memory_order_relaxed);
            source_outcome.cache_full.fetch_add(
                result.cache_full, std::memory_order_relaxed);
            source_outcome.failed.fetch_add(
                result.failed, std::memory_order_relaxed);
            source_outcome.cancelled.fetch_add(
                result.cancelled, std::memory_order_relaxed);
        };
    const auto assign_jit_process_profile = [&translation_profiles,
                                                profile_enabled,
                                                profile_recording_enabled,
                                                profile_loading_enabled,
                                                profile_precompile_enabled](
                                                Runtime& runtime,
                                                const LoadedProcess& loaded,
                                                JitPrecompilePhase phase) {
        runtime.precompile_phase = phase;
        if (profile_enabled && translation_profiles) {
            runtime.jit_translation_profile = translation_profiles->profile_for(
                loaded.executable.content_identity(), profile_loading_enabled);
            runtime.cpus->set_translation_profile(
                runtime.jit_translation_profile, phase,
                profile_recording_enabled, profile_precompile_enabled);
        } else {
            runtime.jit_translation_profile.reset();
            runtime.cpus->set_translation_profile(nullptr, phase, false, false);
        }
        runtime.translation_profile_mapping_generation =
            runtime.memory->translation_profile_mapping_generation();
    };
    const auto apply_jit_runtime_class = [&jit_code_cache_governor](
                                             Runtime& runtime,
                                             JitCodeCacheClass cache_class) {
        if (runtime.jit_cache_class == cache_class)
            return;
        runtime.jit_cache_class = cache_class;
        if (runtime.jit_cache_reservation) {
            const auto shared_slab = jit_code_cache_governor.reclassify(
                *runtime.jit_cache_reservation, cache_class,
                runtime.fresh_spawn_address_space);
            if (shared_slab && runtime.fresh_spawn_address_space)
                runtime.cpus->set_jit_code_cache_size(*shared_slab);
        }
        runtime.cpus->set_jit_artifact_retention(
            cache_class == JitCodeCacheClass::BootCritical
                ? JitArtifactRetention::BootWorkingSet
                : JitArtifactRetention::Normal);
    };
    const auto precompile_startup_profile =
        [&output, &record_precompile_outcomes, startup_profile_enabled,
            startup_profile_blocks, startup_profile_budget_us](
            Runtime& runtime, std::string_view executable_path) {
            if (!startup_profile_enabled)
                return;
            if (runtime.cpus->next_precompile_phase(
                    JitPrecompileTarget::NativeCode,
                    JitPrecompileSource::DemandProfile)) {
                const auto result = runtime.cpus->precompile_pending(
                    static_cast<std::size_t>(startup_profile_blocks),
                    startup_profile_budget_us * 1'000U,
                    JitPrecompileTarget::NativeCode, { },
                    JitPrecompileSource::DemandProfile);
                record_precompile_outcomes(
                    result, JitPrecompileSource::DemandProfile);
                output.line(
                    "[jit-profile] startup-native-warm executable=" +
                    std::string { executable_path } +
                    " blocks=" + std::to_string(result.native_compiled) +
                    " attempted=" + std::to_string(result.attempted) +
                    " elapsed-ns=" +
                    std::to_string(result.elapsed_nanoseconds) +
                    " artifact-imported=" +
                    std::to_string(result.artifact_imported) +
                    " shared-slab=" + std::to_string(result.shared_slab_hits) +
                    " deferred=" + std::to_string(result.deferred) +
                    " failed=" + std::to_string(result.failed));
            }
            const auto native_remaining = runtime.cpus->next_precompile_phase(
                JitPrecompileTarget::NativeCode,
                JitPrecompileSource::DemandProfile);
            const auto portable_remaining = runtime.cpus->next_precompile_phase(
                JitPrecompileTarget::PortableIr,
                JitPrecompileSource::DemandProfile);
            if (native_remaining || portable_remaining) {
                output.line("[jit-profile] startup-remaining-cancelled=1");
                // Startup mode has a synchronous, bounded contract. Any
                // remainder is an explicit terminal cancellation; it must not
                // leak into the idle scheduler after the startup window closes.
                runtime.cpus->quiesce_precompilation();
            }
        };
    auto initial = std::make_unique<Runtime>();
    initial->jit_work_signal = jit_work_signal;
    initial->memory = std::move(initial_memory);
    initial->jit_cache_reservation = jit_code_cache_governor.reserve(
        guest_processor_count, JitCodeCacheClass::BootCritical);
    initial->jit_cache_class = JitCodeCacheClass::BootCritical;
    if (!initial->jit_cache_reservation) {
        throw std::runtime_error { "failed to reserve initial JIT code cache" };
    }
    initial->cpus = std::make_unique<CpuCluster>(initial_guest_thread_slots,
        maximum_guest_threads, *initial->memory, guest_processor_count,
        *cpu_model, shared_exclusive_monitor, allocate_shared_monitor_slots(),
        jit_artifacts, shared_exclusive_address_resolver,
        std::max<std::size_t>(1U, translation_lanes));
    initial->cpus->set_jit_code_cache_size(
        initial->jit_cache_reservation->shared_slab_bytes());
    initial->cpus->set_jit_work_signal(jit_work_signal);
    initial->cpus->set_jit_artifact_retention(
        JitArtifactRetention::BootWorkingSet);
    output.line(
        "[jit] initial-runtime-shared-slab-mib=" +
        std::to_string(initial->jit_cache_reservation->shared_slab_bytes() /
                       1024U / 1024U));
    assign_jit_process_profile(
        *initial, process, JitPrecompilePhase::Bootstrap);
    initial->kernel = std::make_unique<CompatibilityKernel>(*initial->memory,
        output, rootfs, device, activation_override, lockdown_capabilities,
        darwin_configuration);
    // The guest's entropy is the host's, once per boot. Only a deterministic run (bounded by --ticks) keeps the fixed seed,
    // so its output repeats by request and not by accident.
    if (bounded_execution) {
        initial->kernel->seed_random(CompatibilityKernel::kDefaultRandomSeed);
        output.line("[entropy] source=fixed-seed (deterministic run)");
    } else {
        initial->kernel->seed_random(host_random_seed());
        output.line("[entropy] source=host-getentropy");
    }
    if (device.keybag.apple_key_store_available) {
        const auto canonical_rootfs = std::filesystem::canonical(rootfs);
        const auto device_state = canonical_rootfs.parent_path() /
                                  ".shade-device-state" /
                                  canonical_rootfs.filename() / "key-store-v1.key";
        auto key_store = KeyStore::open(device_state);
        if (!key_store)
            throw std::runtime_error("cannot open persistent device key store");
        initial->kernel->set_key_store(std::move(key_store));
    }
    if (baseband_capture_stream) {
        auto* stream = &*baseband_capture_stream;
        initial->kernel->set_baseband_transmit_sink(
            [stream, &baseband_capture_bytes](
                std::span<const std::byte> bytes) {
                stream->write(reinterpret_cast<const char*>(bytes.data()),
                    static_cast<std::streamsize>(bytes.size()));
                if (!*stream)
                    return false;
                baseband_capture_bytes += bytes.size();
                return true;
            });
        output.line(
            "[baseband] capture mode=stream output=" + *baseband_output_path);
    } else {
        initial->kernel->set_baseband_capture_enabled(false);
        output.line("[baseband] capture mode=null");
    }
    output.line(std::string { "[baseband] profile=" } +
                (baseband_input_path ? "virtual" : "offline") + " service=" +
                ((baseband_input_path || device.baseband.device_available)
                        ? "visible"
                        : "unavailable") +
                " mux=" + (baseband_input_path ? "enabled" : "disabled") +
                " data=" + (baseband_input_path ? "replay-only" : "none"));
    initial->cpus->set_process_id(initial->kernel->process().pid);
    auto audio = host.create_audio();
    auto audio_sink = audio.sink;
    if (audio_sink) {
        initial->kernel->set_audio_sink(audio_sink);
        output.line("[audio] backend=" + audio.backend_name + " open=lazy");
    } else {
        output.line("[audio] backend=none");
    }
    if (audio.decoder)
        initial->kernel->set_audio_decoder(audio.decoder);
    output.line("[audio] decoder=" + audio.decoder_name);
    initial->kernel->set_process_arguments(
        process.arguments, initial_environment);
    initial->kernel->set_process_image(process.executable_path,
        process.executable.code_signature_entitlements(),
        &process.dynamic_linker, &process.executable);
    precompile_startup_profile(*initial, process.executable_path);
    observe_runtime_jit_memory_counted(*initial);
    initial->kernel->enqueue_baseband_input(baseband_input);
    initial->kernel->set_baseband_receive_eof(baseband_input_path.has_value());
    if (baseband_input_path) {
        output.line("[baseband] replay input=" + *baseband_input_path +
                    " bytes=" + std::to_string(baseband_input.size()));
    }
    const auto record_first_transition_submission =
        [&](const DisplayFrame& frame) {
            std::lock_guard lock { transition_attribution.mutex };
            if (!transition_attribution.awaiting_first_submission)
                return;
            transition_attribution.awaiting_first_submission = false;
            transition_attribution.first_submission_sequence = frame.sequence;
            transition_attribution.stability_baseline_set = false;
            transition_attribution.stability_baseline_display_time = 0;
            transition_attribution.internal_stability_marker_emitted = false;
            const auto submitted_nanoseconds =
                frame.submitted_at == std::chrono::steady_clock::time_point { }
                    ? steady_nanoseconds()
                    : static_cast<std::uint64_t>(
                          std::chrono::duration_cast<std::chrono::nanoseconds>(
                              frame.submitted_at.time_since_epoch())
                              .count());
            output.marker(
                "[transition] frame-submit id=" +
                std::to_string(transition_attribution.active_transition_id) +
                " sequence=" + std::to_string(frame.sequence) +
                " owner-pid=" + std::to_string(frame.owner_process_id) +
                " submitted-ns=" + std::to_string(submitted_nanoseconds) +
                " input-complete-ns=" +
                std::to_string(
                    transition_attribution.input_complete_nanoseconds));
        };
    if (display_presenter) {
        initial->kernel->set_display_presenter(
            [backend = display_presenter.get(), kernel = initial->kernel.get(),
                &record_first_transition_submission](DisplayFrame frame) {
                kernel->record_foreground_transition_display_submission(
                    frame.owner_process_id, frame.sequence);
                record_first_transition_submission(frame);
                backend->present(std::move(frame));
            });
    } else if (frame_file_presenter) {
        initial->kernel->set_display_presenter(
            [backend = frame_file_presenter.get(),
                kernel = initial->kernel.get(), &output,
                &record_first_transition_submission](DisplayFrame frame) {
                kernel->record_foreground_transition_display_submission(
                    frame.owner_process_id, frame.sequence);
                record_first_transition_submission(frame);
                // Animation diagnostics must not turn the measured window into
                // a PNG-writing benchmark. The presenter callback is still the
                // actual CPU-present boundary for the headless sink; retain
                // pixels already carried by the frame for in-memory change
                // detection.
                const auto diagnostic_window =
                    performance_counters()
                        .frame_content_diagnostics_enabled() &&
                    performance_counters().display_window_active();
                const auto file_output_enabled = backend->enabled();
                if (!diagnostic_window && file_output_enabled)
                    backend->present(frame);
                performance_counters().record_cpu_present_fallback(
                    frame.sequence, frame.submitted_at);
                if (diagnostic_window) {
                    const auto pixels = frame.pixels;
                    performance_counters().record_diagnostic_frame_content(
                        frame.sequence, frame.owner_process_id,
                        frame.submitted_at, frame.width, frame.height, pixels);
                    return;
                }
                if (!file_output_enabled)
                    return;
                const auto pixels =
                    !frame.pixels.empty()
                        ? frame.pixels
                        : (frame.read_pixels ? frame.read_pixels()
                                             : std::vector<std::uint32_t> { });
                // A content-diagnostic window is part of the measured presenter
                // path. Do not turn it into a per-frame stdout-flush benchmark:
                // the in-memory content record above already retains the
                // semantic change evidence needed by the offline analyzer.
                if (!diagnostic_window) {
                    const auto visible = std::count_if(
                        pixels.begin(), pixels.end(), [](std::uint32_t pixel) {
                            return (pixel & 0x00ffffffU) != 0;
                        });
                    output.line(
                        "[display] frame=" + std::to_string(frame.sequence) +
                        " visible-pixels=" + std::to_string(visible));
                }
            });
    }
    std::vector<std::uint32_t> boot_pixels;
    const std::filesystem::path boot_logo_paths[] {
        options.boot_logo.value_or(std::filesystem::path { }),
        host_cache / "boot-logos" / device.identity.product_type /
            (darwin_configuration.identity.build_version + ".png"),
    };
    for (const auto& path : boot_logo_paths) {
        if (path.empty())
            continue;
        try {
            if (!std::filesystem::exists(path))
                continue;
            boot_pixels = BootLogo::load(path, device.screen.panel);
            output.marker("[boot] logo-loaded " + path.string());
            break;
        } catch (const std::exception& error) {
            output.marker("[boot] logo-unavailable " + path.string() + ": " +
                          error.what());
        }
    }
    if (boot_pixels.empty()) {
        boot_pixels = BootLogo::placeholder(device.screen.panel);
        output.marker("[boot] logo-source=built-in-placeholder");
    }
    initial->kernel->initialize_boot_display(std::move(boot_pixels));
    if (display_presenter)
        display_presenter->flush_presentation();
    initial->allocated.assign(initial_guest_thread_slots, false);
    Runtime* initial_runtime = initial.get();
    CatalogMaintenance catalog_maintenance {
        session_catalog, guest_architecture, host_resources };
    runtimes.push_back(std::move(initial));
    runtime_index.insert(*initial_runtime);
    initial_runtime->kernel->set_preferred_wifi_networks(
        preferred_wifi_networks);
    BootGdbTarget debug_target { runtimes };
    XnuScheduler scheduler { guest_ticks_per_second /
                                 xnu::scheduler::default_preemption_rate,
        guest_ticks_per_second / xnu::scheduler::scheduler_ticks_per_second,
        guest_processor_count };
    GuestExecutionPolicy guest_execution_policy { std::chrono::nanoseconds {
        static_cast<std::int64_t>(
            iokit_abi::display_vsync::period_absolute_time) } };
    GuestDispatchPolicy guest_dispatch_policy { std::chrono::nanoseconds {
        static_cast<std::int64_t>(
            iokit_abi::display_vsync::period_absolute_time) } };
    GuestParallelismPolicy guest_parallelism_policy { guest_ticks_per_second };
    std::optional<XnuThreadId> last_serial_thread;
    std::optional<XnuThreadId> scheduler_handoff_thread;
    std::optional<std::uint32_t> display_urgent_process;
    std::optional<XnuThreadId> display_urgent_thread;
    std::optional<XnuThreadId> display_urgent_receiver_thread;
    std::optional<XnuThreadId> display_yielded_thread;
    std::optional<XnuThreadId> display_inflight_callback_thread;
    std::uint64_t display_inflight_callback_sequence { };
    std::optional<std::chrono::steady_clock::time_point>
        display_inflight_callback_deadline;
    std::optional<std::chrono::steady_clock::time_point>
        display_urgent_lease_deadline;
    std::optional<std::chrono::steady_clock::time_point>
        display_callback_pending_since;
    bool display_callback_pending_reported = false;
    std::optional<XnuThreadId> diagnostic_svc_spin_thread;
    std::uint64_t diagnostic_svc_spin_calls = 0;
    std::uint64_t diagnostic_svc_spin_report_at = 1'000;
    std::uint64_t diagnostic_display_yield_count = 0;

    std::uint32_t next_pid = 2;
    std::size_t watchpoint_trace_count = 0;
    std::mutex watchpoint_mutex;
    std::uint64_t catalog_mapped_executable_ranges = 0;
    std::uint64_t catalog_mapped_entry_hints = 0;
    std::array<std::uint64_t, jit_precompile_phase_count>
        catalog_mapped_entry_hints_by_phase { };
    std::array<std::uint64_t, jit_precompile_phase_count>
        precompile_tasks_by_phase { };
    std::array<std::atomic<std::uint64_t>, jit_precompile_phase_count>
        precompile_blocks_by_phase { };
    std::array<std::uint64_t, jit_precompile_target_count>
        precompile_tasks_by_target { };
    std::array<std::atomic<std::uint64_t>, jit_precompile_target_count>
        precompile_blocks_by_target { };
    std::function<void(Runtime&)> configure_runtime;
    configure_runtime = [&](Runtime& runtime) {
        auto* runtime_ptr = &runtime;
        runtime.kernel->set_host_network_policy(network_policy);
        runtime.kernel->set_mapped_executable_handler(
            [runtime_ptr, &session_catalog, &catalog_mapped_executable_ranges,
                &catalog_mapped_entry_hints,
                &catalog_mapped_entry_hints_by_phase](
                const std::filesystem::path& path,
                std::uint32_t mapping_address, std::uint32_t mapping_size,
                std::uint64_t file_offset) {
                if (session_catalog.index() == nullptr)
                    return;
                auto entry_points =
                    session_catalog.index()->fixed_mapping_entry_points(
                        path, mapping_address, mapping_size, file_offset);
                if (entry_points.empty())
                    return;
                ++catalog_mapped_executable_ranges;
                catalog_mapped_entry_hints += entry_points.size();
                catalog_mapped_entry_hints_by_phase[static_cast<std::size_t>(
                    runtime_ptr->precompile_phase)] += entry_points.size();
            });
        if (!runtime.kernel->set_virtual_processor_count(
                guest_processor_count)) {
            throw std::runtime_error { "invalid virtual processor topology" };
        }
        const auto configure_cpu = [&, runtime_ptr](std::size_t index) {
            auto& cpu = runtime.cpus->cpu(index);
            runtime.kernel->attach(cpu);
            cpu.set_svc_dispatch_mode(guest_processor_count > 1
                                          ? SvcDispatchMode::Deferred
                                          : SvcDispatchMode::Immediate);
            cpu.set_debug_breakpoints_enabled(gdb_port.has_value());
            if (watch_address) {
                cpu.set_memory_write_watchpoint(*watch_address,
                    [&, runtime_ptr](Cpu& source, std::uint32_t address,
                        std::size_t size, std::uint64_t value) {
                        const std::scoped_lock lock { watchpoint_mutex };
                        if (watchpoint_trace_count >= maximum_watchpoint_traces)
                            return;
                        ++watchpoint_trace_count;
                        std::ostringstream message;
                        message << "[watch] pid="
                                << runtime_ptr->kernel->process().pid
                                << " cpu=" << source.processor_id() << " pc=0x"
                                << std::hex << source.registers()[15]
                                << " address=0x" << address << " size=0x"
                                << size << " value=0x" << value;
                        for (std::size_t register_index = 0; register_index < 4;
                            ++register_index) {
                            message << " r" << std::dec << register_index
                                    << "=0x" << std::hex
                                    << source.registers()[register_index];
                        }
                        message << " sp=0x" << source.registers()[13]
                                << " lr=0x" << source.registers()[14]
                                << " frames=";
                        // The writer is usually a library routine; the frame
                        // chain says who called it.
                        const auto stack = source.registers()[13];
                        auto frame = source.registers()[7];
                        for (unsigned depth = 0; depth < 16; ++depth) {
                            if ((frame & 3U) != 0 || frame < stack ||
                                frame - stack > 1024U * 1024U)
                                break;
                            const auto next = runtime_ptr->memory->read32(frame);
                            const auto link =
                                runtime_ptr->memory->read32(frame + 4U);
                            if (!next || !link)
                                break;
                            if (depth != 0)
                                message << ',';
                            message << "0x" << *link;
                            if (*next <= frame)
                                break;
                            frame = *next;
                        }
                        output.line(message.str());
                    });
            }
        };
        for (std::size_t index = 0; index < runtime.cpus->size(); ++index) {
            configure_cpu(index);
        }
        runtime.kernel->set_thread_create_handler(
            [runtime_ptr, &scheduler, configure_cpu](
                const std::array<std::uint32_t, 16>& registers,
                std::uint32_t cpsr) -> std::optional<std::size_t> {
                const auto allocate_slot =
                    [&](std::size_t index) -> std::optional<std::size_t> {
                    if (runtime_ptr->allocated[index])
                        return std::nullopt;
                    auto& child = runtime_ptr->cpus->cpu(index);
                    child.reset();
                    child.registers() = registers;
                    child.set_cpsr(cpsr);
                    runtime_ptr->allocated[index] = true;
                    const auto registered = scheduler.register_thread(
                        XnuThreadId { runtime_ptr->kernel->process().pid,
                            static_cast<std::uint32_t>(index) },
                        runtime_ptr->kernel->process().thread_base_priority);
                    if (!registered) {
                        runtime_ptr->allocated[index] = false;
                        return std::nullopt;
                    }
                    return index;
                };
                for (std::size_t index = 1; index < runtime_ptr->cpus->size();
                    ++index) {
                    if (runtime_ptr->allocated[index])
                        continue;
                    return allocate_slot(index);
                }
                const auto added = runtime_ptr->cpus->add_cpu();
                if (!added)
                    return std::nullopt;
                runtime_ptr->allocated.push_back(false);
                configure_cpu(*added);
                return allocate_slot(*added);
            });
        runtime.kernel->set_thread_terminate_handler(
            [runtime_ptr, &scheduler, &guest_execution_policy,
                &guest_parallelism_policy](
                std::uint32_t pid, std::size_t processor) {
                if (pid != runtime_ptr->kernel->process().pid ||
                    processor >= runtime_ptr->allocated.size() ||
                    !runtime_ptr->allocated[processor] ||
                    !scheduler.remove_thread(XnuThreadId {
                        pid, static_cast<std::uint32_t>(processor) })) {
                    return false;
                }
                runtime_ptr->kernel->clear_thread_io_policy(processor);
                guest_execution_policy.forget(
                    XnuThreadId { pid, static_cast<std::uint32_t>(processor) });
                guest_parallelism_policy.forget(
                    XnuThreadId { pid, static_cast<std::uint32_t>(processor) });
                runtime_ptr->allocated[processor] = false;
                return true;
            });
        runtime.kernel->set_thread_state_query(
            [&runtime_index](
                std::uint32_t pid, std::uint32_t slot, std::uint32_t flavor)
                -> std::optional<darwin::arm_thread::GeneralState> {
                if (flavor != darwin::arm_thread::general_state_flavor) {
                    return std::nullopt;
                }
                const auto* runtime = runtime_index.find(pid);
                if (runtime == nullptr || slot >= runtime->cpus->size() ||
                    slot >= runtime->allocated.size() ||
                    !runtime->allocated[slot]) {
                    return std::nullopt;
                }
                const auto& thread = runtime->cpus->cpu(slot);
                darwin::arm_thread::GeneralState state { };
                std::copy(thread.registers().begin(), thread.registers().end(),
                    state.begin());
                state[darwin::arm_thread::cpsr_index] = thread.cpsr();
                return state;
            });
        runtime.kernel->set_thread_state_update_handler(
            [&runtime_index](std::uint32_t pid, std::uint32_t slot,
                const darwin::arm_thread::GeneralState& state) {
                const auto* runtime = runtime_index.find(pid);
                if (runtime == nullptr || slot >= runtime->cpus->size() ||
                    slot >= runtime->allocated.size() ||
                    !runtime->allocated[slot]) {
                    return false;
                }
                auto& thread = runtime->cpus->cpu(slot);
                std::copy_n(state.begin(), thread.registers().size(),
                    thread.registers().begin());
                thread.set_cpsr(state[darwin::arm_thread::cpsr_index] | 0x10U);
                return true;
            });
        runtime.kernel->set_thread_pointer_update_handler(
            [&runtime_index](std::uint32_t pid, std::uint32_t slot,
                std::optional<std::uint32_t> cthread_self) {
                const auto* runtime = runtime_index.find(pid);
                if (runtime == nullptr || slot >= runtime->cpus->size() ||
                    slot >= runtime->allocated.size() ||
                    !runtime->allocated[slot]) {
                    return false;
                }
                runtime->cpus->cpu(slot).set_cthread_self(cthread_self);
                return true;
            });
        runtime.kernel->set_thread_runnable_handler(
            [&scheduler](std::uint32_t pid, std::uint32_t slot, bool runnable) {
                const XnuThreadId thread { pid, slot };
                return runnable ? scheduler.resume_thread(thread)
                                : scheduler.suspend_thread(thread);
            });
        runtime.kernel->set_process_runnable_handler(
            [&scheduler](std::uint32_t pid, bool runnable) {
                if (runnable)
                    static_cast<void>(scheduler.resume_process(pid));
                else
                    static_cast<void>(scheduler.suspend_process(pid));
            });
        runtime.kernel->set_thread_wake_handler(
            [&scheduler](std::uint32_t pid, std::uint32_t slot) {
                return scheduler.wake_thread(XnuThreadId { pid, slot });
            });
        runtime.kernel->set_process_sockets_shutdown_handler(
            [&runtime_index](std::uint32_t pid, std::uint32_t level) {
                if (auto* target = runtime_index.find(pid))
                    target->kernel->shutdown_process_sockets(level);
            });
        runtime.kernel->set_thread_scheduling_state_query(
            [&scheduler](std::uint32_t pid,
                std::uint32_t slot) -> std::optional<XnuThreadState> {
                const auto info = scheduler.info(XnuThreadId { pid, slot });
                return info ? std::optional { info->state } : std::nullopt;
            });
        runtime.kernel->set_mach_message_wake_handler(
            [&runtime_index, &scheduler](
                std::uint32_t pid, std::uint32_t object) {
                auto* receiver = runtime_index.find(pid);
                if (receiver == nullptr)
                    return XnuThreadWakeResult { };
                const auto processor =
                    receiver->kernel->pending_mach_receiver_processor(object);
                if (!processor)
                    return XnuThreadWakeResult { };
                return scheduler.wake_thread(XnuThreadId {
                    pid, static_cast<std::uint32_t>(*processor) });
            });
        const auto create_child_runtime =
            [&, runtime_ptr](Cpu* parent_cpu,
                CompatibilityKernel::ProcessInheritance inheritance)
            -> std::optional<std::uint32_t> {
            const auto child_pid = next_pid++;
            auto child = std::make_unique<Runtime>();
            child->jit_work_signal = jit_work_signal;
            // A child starts without an externally observed interactive role.
            // Its full slab mapping remains available regardless; later
            // lifecycle facts change only retention priority.
            const auto child_cache_class = JitCodeCacheClass::Background;
            child->jit_cache_reservation = jit_code_cache_governor.reserve(
                guest_processor_count, child_cache_class);
            if (!child->jit_cache_reservation) {
                return std::nullopt;
            }
            child->jit_cache_class = child_cache_class;
            if (inheritance ==
                CompatibilityKernel::ProcessInheritance::SpawnExec) {
                PerformanceLatencyScope latency {
                    PerfLatencyKind::ProcessFreshMemory
                };
                child->memory = std::make_unique<AddressSpace>();
                child->memory->set_parallel_access(guest_processor_count > 1);
                child->fresh_spawn_address_space = true;
            } else {
                PerformanceLatencyScope latency {
                    PerfLatencyKind::ProcessCloneMemory
                };
                child->memory = runtime_ptr->memory->clone();
                debug_target.prepare_fork_child(
                    runtime_ptr->kernel->process().pid, *child->memory);
            }
            {
                PerformanceLatencyScope latency {
                    PerfLatencyKind::ProcessCreateCpu
                };
                child->cpus = std::make_unique<CpuCluster>(
                    initial_guest_thread_slots, maximum_guest_threads,
                    *child->memory, guest_processor_count, *cpu_model,
                    shared_exclusive_monitor, allocate_shared_monitor_slots(),
                    jit_artifacts, shared_exclusive_address_resolver,
                    std::max<std::size_t>(1U, translation_lanes));
                child->cpus->set_jit_code_cache_size(
                    child->jit_cache_reservation->shared_slab_bytes());
                child->cpus->set_jit_work_signal(jit_work_signal);
            }
            {
                PerformanceLatencyScope latency {
                    PerfLatencyKind::ProcessCreateKernel
                };
                child->kernel = std::make_unique<CompatibilityKernel>(
                    *child->memory, output, rootfs, device, activation_override,
                    lockdown_capabilities, darwin_configuration);
            }
            if (inheritance ==
                CompatibilityKernel::ProcessInheritance::SpawnExec) {
                PerformanceLatencyScope latency {
                    PerfLatencyKind::ProcessInheritSpawnKernel
                };
                child->kernel->inherit_process_state(
                    *runtime_ptr->kernel, child_pid, inheritance,
                    parent_cpu ? parent_cpu->processor_id() : 0U);
            } else {
                PerformanceLatencyScope latency {
                    PerfLatencyKind::ProcessInheritKernel
                };
                child->kernel->inherit_process_state(
                    *runtime_ptr->kernel, child_pid, inheritance,
                    parent_cpu ? parent_cpu->processor_id() : 0U);
            }
            child->cpus->set_process_id(child_pid);
            child->allocated.assign(initial_guest_thread_slots, false);
            {
                PerformanceLatencyScope latency {
                    PerfLatencyKind::ProcessConfigureRuntime
                };
                configure_runtime(*child);
            }
            if (parent_cpu != nullptr) {
                auto& child_cpu = child->cpus->cpu(0);
                child_cpu.registers() = parent_cpu->registers();
                child_cpu.extension_registers() =
                    parent_cpu->extension_registers();
                child_cpu.registers()[0] = 0;
                child_cpu.set_cpsr(parent_cpu->cpsr() & ~(1U << 29U));
                child_cpu.set_fpscr(parent_cpu->fpscr());
                child_cpu.set_cthread_self(parent_cpu->cthread_self());
            }
            child->allocated[0] = true;
            static_cast<void>(
                scheduler.register_thread(XnuThreadId { child_pid, 0 },
                    child->kernel->process().thread_base_priority));
            observe_runtime_jit_memory_counted(*child);
            runtime_index.insert(*child);
            runtimes.push_back(std::move(child));
            return child_pid;
        };
        runtime.kernel->set_fork_handler(
            [create_child_runtime](Cpu& parent_cpu) {
                return create_child_runtime(
                    &parent_cpu, CompatibilityKernel::ProcessInheritance::Fork);
            });
        runtime.kernel->set_spawn_create_handler([create_child_runtime](Cpu&) {
            return create_child_runtime(
                nullptr, CompatibilityKernel::ProcessInheritance::SpawnExec);
        });
        runtime.kernel->set_exec_handler(
            [&, runtime_ptr](Cpu& source, std::string path,
                std::vector<std::string> arguments,
                std::vector<std::string> environment) {
                catalog_maintenance.poll(*initial_runtime->kernel, true);
                ProcessLoader validator { rootfs, *runtime_ptr->memory,
                    guest_architecture, session_catalog.index(),
                    darwin_abi.initial_apple_vector_abi, darwin_abi.address_layout };
                if (!validator.validate(path)) {
                    output.line(
                        "[process] exec rejected pid=" +
                        std::to_string(runtime_ptr->kernel->process().pid) +
                        " path=" + path);
                    return false;
                }
                runtime_ptr->pending_exec = PendingExec {
                    source.processor_id(),
                    std::move(path),
                    std::move(arguments),
                    std::move(environment),
                };
                return true;
            });
        runtime.kernel->set_spawn_exec_handler([&](std::uint32_t child_pid,
                                                   std::string path,
                                                   std::vector<std::string>
                                                       arguments,
                                                   std::vector<std::string>
                                                       environment,
                                                   bool start_suspended) {
            auto* child_runtime = runtime_index.find(child_pid);
            if (child_runtime == nullptr)
                return false;

            const auto transition =
                initial_runtime->kernel->foreground_transition_snapshot();
            using TransitionTerminal =
                KernelSharedState::ForegroundTransitionTerminalState;
            const auto transition_destination =
                transition && transition->destination &&
                transition->destination->process_id == child_pid &&
                transition->terminal_state == TransitionTerminal::Pending;
            const auto interactive_activation =
                transition_destination || start_suspended;

            const auto image_epoch =
                child_runtime->begin_image_transition(host_resources);
            try {
                catalog_maintenance.poll(*initial_runtime->kernel, true);
                debug_target.notify_exec(child_pid);
                if (!child_runtime->fresh_spawn_address_space) {
                    PerformanceLatencyScope latency {
                        PerfLatencyKind::SpawnMemoryClear
                    };
                    child_runtime->memory->clear();
                }
                LoadedProcess loaded;
                {
                    PerformanceLatencyScope latency {
                        PerfLatencyKind::SpawnImageLoad
                    };
                    ProcessLoader loader { rootfs, *child_runtime->memory,
                        guest_architecture, session_catalog.index(),
                        darwin_abi.initial_apple_vector_abi, darwin_abi.address_layout };
                    loaded =
                        loader.load(path, std::move(arguments), environment);
                }
                {
                    PerformanceLatencyScope latency {
                        PerfLatencyKind::SpawnResetRuntime
                    };
                    child_runtime->kernel->set_process_arguments(
                        loaded.arguments, environment);
                    child_runtime->kernel->set_process_image(
                        path, loaded.executable.code_signature_entitlements(),
                        &loaded.dynamic_linker, &loaded.executable);
                    child_runtime->kernel->prepare_exec(0);
                    auto& child_cpu = child_runtime->cpus->cpu(0);
                    child_cpu.reset();
                    child_cpu.clear_cache();
                    child_cpu.registers().fill(0);
                    child_cpu.registers()[13] = loaded.stack_pointer;
                    child_cpu.registers()[15] = loaded.entry_point;
                    child_cpu.set_cpsr(0x10);
                    // Install the new image's frozen prediction only after the
                    // old native cache has been cleared. Otherwise the clear
                    // immediately restarts the same complete plan.
                    apply_jit_runtime_class(*child_runtime,
                        interactive_activation ? JitCodeCacheClass::Foreground
                                               : JitCodeCacheClass::Background);
                    assign_jit_process_profile(*child_runtime, loaded,
                        precompile_phase_for_lifecycle(interactive_activation));
                    child_runtime->kernel->install_main_image_hle(
                        child_cpu, loaded.executable_path);
                    precompile_startup_profile(
                        *child_runtime, loaded.executable_path);
                    observe_runtime_jit_memory_counted(*child_runtime);
                }
                child_runtime->activate_image_epoch(image_epoch);
                child_runtime->fresh_spawn_address_space = false;
                if (transition_destination || start_suspended) {
                    const auto initial_thread = XnuThreadId { child_pid, 0 };
                    const auto held_for_prepare =
                        start_suspended ||
                        scheduler.suspend_thread(initial_thread);
                    if (held_for_prepare) {
                        child_runtime
                            ->execution_prepare_task = host_resources.submit(
                            HostWorkKind::ForegroundPrepare, std::nullopt,
                            [child_runtime] {
                                try {
                                    child_runtime->cpus
                                        ->prepare_primary_execution_resource();
                                } catch (...) {
                                    // The first Guest slice retains
                                    // ensure_jit() as the safe fallback if
                                    // Host-side preparation fails.
                                }
                            });
                    }
                    if (child_runtime->execution_prepare_task) {
                        child_runtime->resume_after_execution_prepare =
                            !start_suspended;
                        child_runtime->set_image_activation_pending(
                            transition_destination && !start_suspended);
                    } else if (held_for_prepare && !start_suspended) {
                        static_cast<void>(
                            scheduler.resume_thread(initial_thread));
                    }
                }
                if (start_suspended) {
                    static_cast<void>(
                        scheduler.block(XnuThreadId { child_pid, 0 }));
                }
            } catch (const std::exception& error) {
                output.line("[process] spawn exec failed pid=" +
                            std::to_string(child_pid) + " path=" + path +
                            " error=" + error.what());
                child_runtime->kernel->exit_process(127);
                scheduler.remove_process(child_pid);
                guest_execution_policy.forget_process(child_pid);
                guest_parallelism_policy.forget_process(child_pid);
                std::fill(child_runtime->allocated.begin(),
                    child_runtime->allocated.end(), false);
                return false;
            }
            return true;
        });
        runtime.kernel->set_scheduler_runnable_query(
            [&scheduler, runtime_ptr](std::size_t thread_slot) {
                return scheduler.should_yield(
                    XnuThreadId { runtime_ptr->kernel->process().pid,
                        static_cast<std::uint32_t>(thread_slot) });
            });
        runtime.kernel->set_signal_delivery_handler(
            [&runtime_index, &scheduler, &guest_execution_policy,
                &guest_parallelism_policy](
                std::uint32_t target_pid, std::uint32_t signal) {
                auto* target = runtime_index.find(target_pid);
                if (target == nullptr)
                    return darwin::error::no_such_process;
                const auto error = target->kernel->deliver_signal(signal);
                if (error == 0 && target->kernel->process().exited) {
                    scheduler.remove_process(target_pid);
                    guest_execution_policy.forget_process(target_pid);
                    guest_parallelism_policy.forget_process(target_pid);
                }
                return error;
            });
        runtime.kernel->set_task_memory_region_query(
            [&runtime_index](std::uint32_t pid, std::uint32_t address)
                -> std::optional<AddressSpace::MappingRegion> {
                const auto* runtime = runtime_index.find(pid);
                if (runtime == nullptr)
                    return std::nullopt;
                return runtime->memory->mapping_region_at_or_after(address);
            });
        runtime.kernel->set_task_memory_share_query(
            [&runtime_index](
                std::uint32_t pid, std::uint32_t address, std::uint32_t size)
                -> std::optional<CompatibilityKernel::SharedTaskMemoryRange> {
                const auto* runtime = runtime_index.find(pid);
                if (runtime == nullptr)
                    return std::nullopt;
                const auto region =
                    runtime->memory->mapping_region_at_or_after(address);
                const auto end = static_cast<std::uint64_t>(address) + size;
                if (!region || region->address > address || region->end < end)
                    return std::nullopt;
                auto pages = runtime->memory->share_pages(address, size);
                if (!pages)
                    return std::nullopt;
                return CompatibilityKernel::SharedTaskMemoryRange {
                    std::move(*pages), region->permissions
                };
            });
        runtime.kernel->set_task_memory_remap_handler(
            [&runtime_index](std::uint32_t pid,
                CompatibilityKernel::RemapPlacement placement)
                -> std::optional<CompatibilityKernel::RemapResult> {
                const auto* runtime = runtime_index.find(pid);
                if (runtime == nullptr)
                    return std::nullopt;
                return CompatibilityKernel::remap_into(
                    *runtime->memory, std::move(placement));
            });
        runtime.kernel->set_scheduler_preemption_query(
            [runtime_ptr, &scheduler, disable_scheduler_preemption](
                std::size_t processor) {
                if (disable_scheduler_preemption)
                    return false;
                const XnuThreadId thread { runtime_ptr->kernel->process().pid,
                    static_cast<std::uint32_t>(processor) };
                const auto scheduling_info = scheduler.info(thread);
                return scheduling_info && scheduling_info->last_processor &&
                       scheduler.preemption_for(
                           thread, *scheduling_info->last_processor) !=
                           XnuPreemption::None;
            });
        runtime.kernel->set_task_priority_handler(
            [runtime_ptr, &scheduler](std::int32_t priority) {
                for (std::size_t processor = 0;
                    processor < runtime_ptr->allocated.size(); ++processor) {
                    if (!runtime_ptr->allocated[processor])
                        continue;
                    static_cast<void>(scheduler.set_base_priority(
                        XnuThreadId { runtime_ptr->kernel->process().pid,
                            static_cast<std::uint32_t>(processor) },
                        priority));
                }
            });
        runtime.kernel->set_legacy_thread_policy_handler(
            [runtime_ptr, &scheduler](std::size_t processor,
                std::uint32_t policy, std::int32_t base_priority, bool) {
                using namespace darwin::mach::thread_policy;
                const XnuThreadId thread { runtime_ptr->kernel->process().pid,
                    static_cast<std::uint32_t>(processor) };
                const auto timeshare = policy == legacy_timeshare_policy;
                if (!timeshare && policy != legacy_round_robin_policy &&
                    policy != legacy_fifo_policy) {
                    return false;
                }
                return scheduler.set_timeshare(thread, timeshare) &&
                       scheduler.set_base_priority(thread, base_priority);
            });
        runtime.kernel->set_thread_policy_handler(
            [runtime_ptr, &scheduler, guest_ticks_per_second](
                std::size_t processor, std::uint32_t flavor,
                std::span<const std::uint32_t> policy) {
                using namespace darwin::mach::thread_policy;
                const XnuThreadId thread { runtime_ptr->kernel->process().pid,
                    static_cast<std::uint32_t>(processor) };
                if (flavor == extended_policy &&
                    policy.size() >= extended_policy_word_count) {
                    return scheduler.set_timeshare(thread, policy[0] != 0);
                }
                if (flavor == time_constraint_policy &&
                    policy.size() >= time_constraint_policy_word_count) {
                    scheduler.set_realtime_clock_ticks(duration_to_guest_ticks(
                        runtime_ptr->kernel->current_absolute_time(),
                        darwin::mach::thread_policy::
                            absolute_time_units_per_second,
                        guest_ticks_per_second));
                    const auto to_scheduler_ticks = [guest_ticks_per_second](
                                                        std::uint32_t value) {
                        return duration_to_guest_ticks(value,
                            absolute_time_units_per_second,
                            guest_ticks_per_second);
                    };
                    return scheduler.set_realtime(thread,
                        to_scheduler_ticks(policy[realtime_period_index]),
                        to_scheduler_ticks(policy[realtime_computation_index]),
                        to_scheduler_ticks(policy[realtime_constraint_index]),
                        policy[realtime_preemptible_index] != 0);
                }
                if (flavor == precedence_policy &&
                    policy.size() >= precedence_policy_word_count) {
                    const auto importance = std::bit_cast<std::int32_t>(
                        policy[precedence_importance_index]);
                    return scheduler.set_base_priority(thread,
                        runtime_ptr->kernel->process().thread_base_priority +
                            importance);
                }
                return false;
            });
    };
    configure_runtime(*initial_runtime);

    auto& initial_cpu = initial_runtime->cpus->cpu(0);
    initial_runtime->allocated[0] = true;
    static_cast<void>(scheduler.register_thread(
        XnuThreadId { initial_runtime->kernel->process().pid, 0 },
        initial_runtime->kernel->process().thread_base_priority));
    initial_cpu.registers()[13] = process.stack_pointer;
    initial_cpu.registers()[15] = process.entry_point;
    initial_cpu.set_cpsr(0x10);

    {
        std::ostringstream message;
        message << "[loader] main=0x" << std::hex << process.main_header
                << " dyld_entry=0x" << process.entry_point << " sp=0x"
                << process.stack_pointer << std::dec
                << " processors=" << guest_processor_count
                << " network=" << host_network_policy_name(network_policy)
                << '\n';
        output.write(message.str());
    }
    std::uint64_t remaining_ticks = ticks;
    std::uint64_t consumed_ticks = 0;
    std::uint32_t stopped_pid = 1;
    std::size_t stopped_cpu = 0;
    CpuRunResult stopped_result { };
    bool hard_stop = false;
    std::unique_ptr<GdbRemoteServer> gdb_server;
    std::optional<GdbResumeRequest> debug_request;
    if (gdb_port) {
        gdb_server = std::make_unique<GdbRemoteServer>(*gdb_port, output);
        gdb_server->listen_and_accept();
        const GdbThreadId initial_thread { 1, 1 };
        debug_target.set_current_thread(initial_thread);
        auto request = gdb_server->command_loop(debug_target, initial_thread);
        if (request.kind == GdbResumeKind::Detach) {
            debug_target.remove_all_breakpoints();
            gdb_server->detach();
            gdb_server.reset();
            for (auto& runtime : runtimes) {
                for (std::size_t processor = 0;
                    processor < runtime->cpus->size(); ++processor) {
                    runtime->cpus->cpu(processor).set_debug_breakpoints_enabled(
                        false);
                }
            }
        } else if (request.kind == GdbResumeKind::Kill) {
            hard_stop = true;
        } else {
            debug_request = request;
        }
    }
    if (touch_replay) {
        touch_replay->start();
    }
    std::optional<RealtimePacer> realtime_pacer;
    std::vector<
        std::pair<std::chrono::steady_clock::time_point, std::filesystem::path>>
        scheduled_snapshots;
    enum class HostDeadlineSource : std::uint8_t {
        TouchReplay,
        LiveButton,
        LiveTouch,
        Snapshot,
    };
    DeadlineQueue<HostDeadlineSource, std::chrono::steady_clock::time_point>
        host_deadlines;
    const auto refresh_host_deadlines = [&]() {
        if (touch_replay) {
            if (const auto deadline = touch_replay->next_deadline())
                host_deadlines.upsert(
                    HostDeadlineSource::TouchReplay, *deadline);
            else
                host_deadlines.erase(HostDeadlineSource::TouchReplay);
        } else {
            host_deadlines.erase(HostDeadlineSource::TouchReplay);
        }
        if (const auto deadline = live_button_scheduler.next_deadline())
            host_deadlines.upsert(HostDeadlineSource::LiveButton, *deadline);
        else
            host_deadlines.erase(HostDeadlineSource::LiveButton);
        if (const auto deadline = live_touch_scheduler.next_deadline())
            host_deadlines.upsert(HostDeadlineSource::LiveTouch, *deadline);
        else
            host_deadlines.erase(HostDeadlineSource::LiveTouch);
        if (!scheduled_snapshots.empty())
            host_deadlines.upsert(HostDeadlineSource::Snapshot,
                scheduled_snapshots.front().first);
        else
            host_deadlines.erase(HostDeadlineSource::Snapshot);
    };
    const auto next_host_control_deadline = [&]() {
        refresh_host_deadlines();
        return host_deadlines.next_deadline();
    };
    const auto wait_for_host_activity = [&](std::chrono::nanoseconds delay) {
        if (delay <= std::chrono::nanoseconds::zero())
            return;
        // A display submission may be the final Guest action before VSync is
        // disabled.  Do not let the idle wait hide an already queued frame
        // until an unrelated window event wakes the loop; the next iteration will
        // drain the mailbox without changing Guest time or presentation
        // cadence.
        if (display_presenter && display_presenter->has_pending_presentation())
            return;
        const auto waitable_window_session =
            display_presenter && (!live_control || live_control->closed()) &&
            !gdb_server;
        if (waitable_window_session) {
            static_cast<void>(display_presenter->wait_for_event(delay));
        } else if (display_presenter) {
            delay = std::min(
                delay, std::chrono::duration_cast<std::chrono::nanoseconds>(
                           host_event_poll_fallback));
        }
        if (live_control && !live_control->closed()) {
            live_control->wait_for(delay);
        } else {
            std::this_thread::sleep_for(delay);
        }
    };
    std::optional<std::string> display_performance_window;
    struct DisplayClockWindow {
        std::chrono::steady_clock::time_point started_at;
        std::uint64_t guest_started_at { };
        std::uint64_t pacer_started_at { };
        std::uint64_t host_sync_count { };
        std::uint64_t host_sync_deficit_total_nanoseconds { };
        std::uint64_t host_sync_deficit_max_nanoseconds { };
    };
    std::optional<DisplayClockWindow> display_clock_window;
    Runtime* display_scanout_owner = nullptr;
    const auto refresh_jit_runtime_classes = [&]() {
        const auto active_process =
            initial_runtime->kernel->active_client_process_id();
        const auto transition =
            initial_runtime->kernel->foreground_transition_snapshot();
        using TransitionTerminal =
            KernelSharedState::ForegroundTransitionTerminalState;
        std::optional<std::uint32_t> transition_destination;
        if (transition && transition->destination &&
            transition->terminal_state == TransitionTerminal::Pending) {
            transition_destination = transition->destination->process_id;
        }
        for (auto& runtime : runtimes) {
            if (runtime->kernel->process().exited)
                continue;
            const auto process_id = runtime->kernel->process().pid;
            const auto critical = runtime.get() == initial_runtime ||
                                  runtime.get() == display_scanout_owner;
            const auto interactive =
                runtime->image_activation_pending ||
                (active_process && *active_process == process_id) ||
                (transition_destination &&
                    *transition_destination == process_id);
            apply_jit_runtime_class(
                *runtime, critical      ? JitCodeCacheClass::BootCritical
                          : interactive ? JitCodeCacheClass::Foreground
                                        : JitCodeCacheClass::Background);
        }
    };
    auto observed_display_submissions =
        initial_runtime->kernel->display_submitted_frames();
    auto last_display_submission = std::chrono::steady_clock::now();
    constexpr std::uint64_t internal_stability_vsync_pulses = 60;
    const auto transition_timestamp = [](const auto& timestamp) {
        if (!timestamp)
            return std::string { "none" };
        return std::to_string(timestamp->device_monotonic_time) + "/" +
               std::to_string(timestamp->host_steady_nanoseconds);
    };
    const auto transition_process = [](const auto& process) {
        if (!process)
            return std::string { "none" };
        return std::to_string(process->process_id) + "/" +
               std::to_string(process->incarnation);
    };
    const auto transition_terminal = [](const auto terminal) {
        using Terminal = KernelSharedState::ForegroundTransitionTerminalState;
        switch (terminal) {
        case Terminal::Pending:
            return std::string { "pending" };
        case Terminal::Stable:
            return std::string { "stable" };
        case Terminal::Cancelled:
            return std::string { "cancelled" };
        case Terminal::Superseded:
            return std::string { "superseded" };
        }
        return std::string { "unknown" };
    };
    const auto emit_foreground_transition_snapshot =
        [&](std::string_view phase) {
            const auto snapshot =
                initial_runtime->kernel->foreground_transition_snapshot();
            if (!snapshot) {
                output.marker("[transition-snapshot] phase=" +
                              std::string { phase } + " state=none");
                return;
            }
            output.marker(
                "[transition-snapshot] phase=" + std::string { phase } +
                " generation=" + std::to_string(snapshot->generation) +
                " token=" + std::to_string(snapshot->launch_token) +
                " input-sequence=" + std::to_string(snapshot->input_sequence) +
                " source=" + transition_process(snapshot->source) +
                " destination=" + transition_process(snapshot->destination) +
                " input-complete=" +
                transition_timestamp(snapshot->input_completed) + " spawned=" +
                transition_timestamp(snapshot->spawned) + " event-port-ready=" +
                transition_timestamp(snapshot->event_port_ready) +
                " lifecycle=" + transition_timestamp(snapshot->lifecycle) +
                " scene-committed=" +
                transition_timestamp(snapshot->scene_committed) +
                " vsync-disabled=" +
                transition_timestamp(snapshot->vsync_disabled) +
                " vsync-enabled=" +
                transition_timestamp(snapshot->vsync_enabled) +
                " destination-first-frame=" +
                transition_timestamp(snapshot->destination_first_frame) +
                " destination-first-frame-sequence=" +
                std::to_string(snapshot->destination_first_frame_sequence) +
                " first-content-change=" +
                transition_timestamp(snapshot->first_content_change) +
                " first-content-revision=" +
                std::to_string(snapshot->first_content_revision) +
                " last-content-change=" +
                transition_timestamp(snapshot->last_content_change) +
                " last-content-revision=" +
                std::to_string(snapshot->last_content_revision) +
                " terminal=" + transition_terminal(snapshot->terminal_state) +
                " terminal-time=" + transition_timestamp(snapshot->terminal));
        };
    const auto observe_transition_stability = [&]() {
        if (!transition_attribution.internal_stability_active.load(
                std::memory_order_acquire)) {
            return;
        }
        const auto vsync_pulses =
            initial_runtime->kernel->display_vsync_pulse_count();
        const auto content_revision =
            initial_runtime->kernel->display_content_revision();
        const auto display_time =
            initial_runtime->kernel->current_absolute_time();
        initial_runtime->kernel->note_foreground_transition_content_change(
            initial_runtime->kernel->display_content_owner_process_id(),
            content_revision);
        std::lock_guard lock { transition_attribution.mutex };
        ++transition_attribution.stability_observation_count;
        transition_attribution.stability_last_observed_content_revision =
            content_revision;
        transition_attribution.stability_last_observed_vsync_pulses =
            vsync_pulses;
        if (!transition_attribution.internal_stability_active.load(
                std::memory_order_relaxed) ||
            transition_attribution.awaiting_first_submission ||
            transition_attribution.first_submission_sequence == 0 ||
            transition_attribution.internal_stability_marker_emitted) {
            return;
        }
        if (!transition_attribution.stability_baseline_set) {
            transition_attribution.latest_content_revision = content_revision;
            transition_attribution.stability_baseline_vsync_pulses =
                vsync_pulses;
            transition_attribution.stability_baseline_display_time =
                display_time;
            transition_attribution.stability_baseline_set = true;
            transition_attribution.stability_window_host_syncs = 0;
            transition_attribution.stability_window_starved_time = 0;
            return;
        }
        if (content_revision !=
            transition_attribution.latest_content_revision) {
            transition_attribution.latest_content_revision = content_revision;
            ++transition_attribution.stability_content_reset_count;
            transition_attribution.stability_baseline_set = false;
            transition_attribution.stability_baseline_display_time = 0;
        }
        if (!transition_attribution.stability_baseline_set) {
            transition_attribution.stability_baseline_vsync_pulses =
                vsync_pulses;
            transition_attribution.stability_baseline_display_time =
                display_time;
            transition_attribution.stability_baseline_set = true;
            transition_attribution.stability_window_host_syncs = 0;
            transition_attribution.stability_window_starved_time = 0;
            return;
        }
        constexpr auto display_period =
            iokit_abi::display_vsync::period_absolute_time;
        constexpr auto internal_stability_display_time =
            internal_stability_vsync_pulses * display_period;
        const auto window_time = display_time >
                transition_attribution.stability_baseline_display_time
            ? display_time -
                transition_attribution.stability_baseline_display_time
            : std::uint64_t { 0 };
        const auto attended_time = window_time -
            std::min(window_time,
                transition_attribution.stability_window_starved_time);
        if (attended_time < internal_stability_display_time)
            return;
        transition_attribution.internal_stability_marker_emitted = true;
        transition_attribution.internal_stability_active.store(
            false, std::memory_order_release);
        const auto stable_nanoseconds = steady_nanoseconds();
        initial_runtime->kernel->mark_foreground_transition_stable();
        emit_foreground_transition_snapshot("stable");
        output.marker(
            "[transition] internal-stable id=" +
            std::to_string(transition_attribution.active_transition_id) +
            " sequence=" +
            std::to_string(transition_attribution.first_submission_sequence) +
            " content-revision=" +
            std::to_string(transition_attribution.latest_content_revision) +
            " delivered-vsync-pulses=" + std::to_string(vsync_pulses) +
            " host-syncs=" +
            std::to_string(transition_attribution.stability_window_host_syncs) +
            " starved-display-periods=" +
            std::to_string(
                (window_time - attended_time) / display_period) +
            " stable-display-periods=" +
            std::to_string(attended_time / display_period) +
            " stable-ns=" + std::to_string(stable_nanoseconds) +
            " input-complete-ns=" +
            std::to_string(transition_attribution.input_complete_nanoseconds));
    };
    auto last_jit_quota_refresh = last_display_submission;
    auto latest_host_memory_budget = jit_cache_budget.memory;
    bool pressure_reclamation_applied { };
    std::optional<std::chrono::steady_clock::time_point> guest_idle_since;
    std::uint64_t guest_timer_overshoot_samples { };
    std::uint64_t guest_timer_overshoot_total_nanoseconds { };
    std::uint64_t guest_timer_overshoot_max_nanoseconds { };
    std::optional<std::uint64_t> observed_guest_timer_deadline;
    DeadlineQueue<std::uint32_t, std::uint64_t> guest_deadlines;
    // The earliest deadline any guest process waits for: its timers, waits
    // with a timeout and the display's next VSync.
    const auto next_guest_deadline = [&]() {
        for (const auto& runtime : runtimes) {
            const auto process_id = runtime->kernel->process().pid;
            // An exited Runtime may remain here while asynchronous image
            // work drains. Its timers no longer have Guest-visible
            // lifetime, so retire the keyed cache entry immediately rather
            // than letting a past deadline spin the host loop.
            if (runtime->kernel->process().exited) {
                guest_deadlines.erase(process_id);
                continue;
            }
            const auto deadline = runtime->kernel->timer_deadline_snapshot();
            if (!runtime->timer_deadline_observed ||
                runtime->timer_deadline_generation != deadline.generation) {
                if (deadline.deadline) {
                    guest_deadlines.upsert(process_id, *deadline.deadline);
                } else {
                    guest_deadlines.erase(process_id);
                }
                runtime->timer_deadline_generation = deadline.generation;
                runtime->timer_deadline_observed = true;
            }
        }
        return guest_deadlines.next_deadline();
    };
    if (device_time_policy == DeviceTimePolicy::HostMappedInteractive) {
        realtime_pacer.emplace(
            initial_runtime->kernel->current_absolute_time(),
            options.time_scale);
        if (realtime_pacer->time_scale() != 1.0) {
            std::ostringstream scale;
            scale << "[time] scale=" << std::fixed << std::setprecision(2)
                  << realtime_pacer->time_scale()
                  << " (one guest second takes that many host seconds)";
            output.line(scale.str());
        }
        const auto host_wall_time =
            std::chrono::duration_cast<std::chrono::nanoseconds>(
                std::chrono::system_clock::now().time_since_epoch())
                .count();
        if (host_wall_time > 0) {
            initial_runtime->kernel->set_wall_time(
                static_cast<std::uint64_t>(host_wall_time));
        }
        output.line("[clock] mode=virtual-rtc seed=host-once rate=realtime "
                    "timezone=guest");
    }
    // A still screen is counted in guest time, and without --ticks guest time
    // follows the host's whether or not the guest ran. As QEMU's -icount
    // sleep=on counts virtual time, a catch-up counts what the guest executed
    // since the previous one and, when it has nothing runnable, the time it
    // waited up to its earliest deadline; past that deadline a timer or VSync
    // was due that it did not get to run. The clock stands still while the
    // guest executes, so both are measured from the previous catch-up: from
    // there the guest worked for what it executed and slept up to the
    // deadline, and it had the later of the two, not their sum. The rest
    // was owed and not given, a starved guest cannot draw in it, and it is
    // kept out of the window.
    GuestTickClock executed_time_clock { guest_ticks_per_second };
    std::uint64_t executed_ticks_since_catch_up { };
    const auto account_stability_catch_up = [&](std::uint64_t advance) {
        const auto executed = executed_time_clock.absolute_time_units(
            std::exchange(executed_ticks_since_catch_up, 0));
        if (!transition_attribution.internal_stability_active.load(
                std::memory_order_acquire)) {
            return;
        }
        auto waited = std::uint64_t { 0 };
        if (scheduler.runnable_count() == 0) {
            const auto now = initial_runtime->kernel->current_absolute_time();
            const auto deadline = next_guest_deadline();
            waited = !deadline ? advance
                : *deadline > now ? *deadline - now
                                  : std::uint64_t { 0 };
        }
        std::lock_guard lock { transition_attribution.mutex };
        if (!transition_attribution.stability_baseline_set)
            return;
        const auto attended = std::min(advance, std::max(executed, waited));
        ++transition_attribution.stability_window_host_syncs;
        transition_attribution.stability_window_starved_time +=
            advance - attended;
    };
    // Interactive DeviceMonotonicTime is mapped to host steady time exactly
    // once. CPU execution accounting never advances this domain; after a slow
    // translated slice or host-backed syscall, the next synchronization moves
    // directly to the fixed mapping and services every due device without
    // rebasing it. Deterministic runs intentionally bypass this path.
    const auto synchronize_device_time_to_host = [&]() {
        if (!realtime_pacer)
            return;
        const auto current_time =
            initial_runtime->kernel->current_absolute_time();
        const auto host_time = realtime_pacer->allowed_device_monotonic_time();
        if (current_time >= host_time)
            return;
        const auto deficit = host_time - current_time;
        if (display_clock_window) {
            ++display_clock_window->host_sync_count;
            display_clock_window->host_sync_deficit_total_nanoseconds =
                deficit > std::numeric_limits<std::uint64_t>::max() -
                              display_clock_window
                                  ->host_sync_deficit_total_nanoseconds
                    ? std::numeric_limits<std::uint64_t>::max()
                    : display_clock_window
                              ->host_sync_deficit_total_nanoseconds +
                          deficit;
            display_clock_window->host_sync_deficit_max_nanoseconds = std::max(
                display_clock_window->host_sync_deficit_max_nanoseconds,
                deficit);
        }
        account_stability_catch_up(deficit);
        initial_runtime->kernel->advance_absolute_time(host_time);
        for (auto& runtime : runtimes) {
            if (runtime.get() != initial_runtime &&
                !runtime->kernel->process().exited) {
                runtime->kernel->service_time_dependent_devices(host_time);
            }
        }
    };
    const auto synchronize_scheduler_time = [&]() {
        const auto scheduler_time = duration_to_guest_ticks(
            initial_runtime->kernel->current_absolute_time(),
            darwin::mach::thread_policy::absolute_time_units_per_second,
            guest_ticks_per_second);
        scheduler.synchronize_time(scheduler_time);
        scheduler.set_realtime_clock_ticks(scheduler_time);
    };
    const auto jit_work_observation_due =
        [&](std::chrono::steady_clock::time_point now, bool guest_quiet) {
            const auto activity = jit_work_signal->snapshot();
            return jit_work_scheduler.observation_due(
                JitWorkObservationGateRequest { now, activity.generation,
                    guest_quiet, activity.activation_pending,
                    activity.worker_active });
        };
    const auto schedule_jit_profile_work = [&](JitWorkObservation observation,
                                               std::optional<
                                                   HostResourceController::
                                                       Clock::time_point>
                                                   host_compile_deadline,
                                               bool guest_quiet) {
        if (!profile_background_warming_enabled)
            return;
        if (!jit_work_observation_due(
                std::chrono::steady_clock::now(), guest_quiet)) {
            return;
        }
        const auto transition =
            initial_runtime->kernel->foreground_transition_snapshot();
        using TransitionTerminal =
            KernelSharedState::ForegroundTransitionTerminalState;
        std::optional<std::uint32_t> transition_destination;
        if (transition && transition->destination &&
            transition->terminal_state == TransitionTerminal::Pending) {
            transition_destination = transition->destination->process_id;
        }
        const auto active_process =
            initial_runtime->kernel->active_client_process_id();
        const auto scanout_process =
            display_scanout_owner == nullptr
                ? std::optional<std::uint32_t> { }
                : std::optional<std::uint32_t> {
                      display_scanout_owner->kernel->process().pid
                  };

        std::vector<JitWorkCandidate> candidates;
        candidates.reserve(runtimes.size());
        for (const auto& runtime : runtimes) {
            std::erase_if(runtime->precompile_tasks,
                [](const auto& task) { return task.finished(); });
            const auto process_id = runtime->kernel->process().pid;
            JitWorkCandidate candidate;
            candidate.identity = process_id;
            candidate.exited = runtime->kernel->process().exited;
            candidate.image_activation_pending =
                runtime->image_activation_pending;
            candidate.foreground_transition_destination =
                transition_destination && *transition_destination == process_id;
            candidate.active_client =
                active_process && *active_process == process_id;
            candidate.scanout_owner =
                scanout_process && *scanout_process == process_id;
            candidate.guest_runnable =
                scheduler.process_runnable_count(process_id) != 0U;
            candidate.active_native_workers = static_cast<std::size_t>(
                std::count_if(runtime->precompile_tasks.begin(),
                    runtime->precompile_tasks.end(), [](const auto& task) {
                        return task.target == JitPrecompileTarget::NativeCode;
                    }));
            candidate.active_portable_workers =
                runtime->precompile_tasks.size() -
                candidate.active_native_workers;
            candidate.worker_capacity = runtime->cpus->precompile_lane_count();
            const auto interactive_role =
                candidate.image_activation_pending ||
                candidate.foreground_transition_destination ||
                candidate.active_client || candidate.scanout_owner;
            if (!candidate.exited &&
                runtime->precompile_tasks.size() < candidate.worker_capacity &&
                runtime->cpus->has_execution_resources() &&
                (interactive_role ||
                    (!guest_quiet && candidate.guest_runnable) ||
                    (guest_quiet && profile_offline_warming_enabled))) {
                // Current demand is merged only at a Guest-quiet safe
                // boundary. While Guest code is runnable, the independent
                // executor consumes only the frozen prior-image queue.
                if (guest_quiet && interactive_role)
                    runtime->cpus->refresh_translation_profile();
                if (interactive_role || !candidate.guest_runnable) {
                    if (const auto phase = runtime->cpus->next_precompile_phase(
                            JitPrecompileTarget::NativeCode,
                            JitPrecompileSource::DemandProfile)) {
                        candidate.native_phase_priority =
                            static_cast<std::size_t>(*phase);
                    }
                }
                if (candidate.image_activation_pending ||
                    (guest_quiet && profile_offline_warming_enabled)) {
                    if (const auto phase = runtime->cpus->next_precompile_phase(
                            JitPrecompileTarget::PortableIr,
                            JitPrecompileSource::DemandProfile)) {
                        candidate.portable_phase_priority =
                            static_cast<std::size_t>(*phase);
                    }
                }
            }
            candidates.push_back(candidate);
        }

        const auto schedule = jit_work_scheduler.schedule(
            JitWorkScheduleRequest { candidates, observation, true, true,
                guest_quiet, guest_quiet && profile_offline_warming_enabled,
                translation_lanes });
        record_jit_schedule_skips(schedule);
        for (const auto& planned : schedule.work()) {
            auto* runtime = runtime_index.find(
                static_cast<std::uint32_t>(planned.candidate_identity));
            if (runtime == nullptr || runtime->kernel->process().exited) {
                record_precompile_schedule_skip(
                    PrecompileScheduleSkip::NoRuntime);
                continue;
            }
            if (runtime->precompile_tasks.size() >=
                runtime->cpus->precompile_lane_count()) {
                record_precompile_schedule_skip(
                    PrecompileScheduleSkip::TaskBusy);
                continue;
            }
            if (planned.phase_priority >= jit_precompile_phase_count) {
                record_precompile_schedule_skip(
                    PrecompileScheduleSkip::NoPhase);
                continue;
            }
            const auto phase =
                static_cast<JitPrecompilePhase>(planned.phase_priority);
            const auto target = planned.target == JitScheduledTarget::NativeCode
                                    ? JitPrecompileTarget::NativeCode
                                    : JitPrecompileTarget::PortableIr;
            const auto work_kind =
                planned.work_class == JitWorkClass::OfflinePortable
                    ? HostWorkKind::OfflineCompile
                    : HostWorkKind::BackgroundCompile;
            const auto expected_epoch = runtime->work_epoch.current();
            const auto decision = planned.decision;
            auto precompile_task = host_resources.submit_cancellable(
                work_kind, host_compile_deadline,
                [runtime, expected_epoch, decision, phase, target,
                    &precompile_blocks_by_phase, &precompile_blocks_by_target,
                    &record_precompile_outcomes,
                    jit_work_signal](const HostWorkToken& token) {
                    const auto source = JitPrecompileSource::DemandProfile;
                    const auto result = runtime->cpus->precompile_pending(
                        decision.maximum_blocks, decision.budget_nanoseconds,
                        target,
                        [runtime, expected_epoch, &token] {
                            return token.cancelled() ||
                                   runtime->precompile_stop_requested(
                                       expected_epoch);
                        },
                        source);
                    record_precompile_outcomes(result, source);
                    const auto compiled =
                        target == JitPrecompileTarget::NativeCode
                            ? result.native_compiled
                            : result.portable_generated;
                    precompile_blocks_by_phase[static_cast<std::size_t>(phase)]
                        .fetch_add(compiled, std::memory_order_relaxed);
                    precompile_blocks_by_target[static_cast<std::size_t>(
                                                    target)]
                        .fetch_add(compiled, std::memory_order_relaxed);
                    jit_work_signal->notify_work();
                },
                std::chrono::nanoseconds {
                    static_cast<std::chrono::nanoseconds::rep>(
                        decision.budget_nanoseconds) });
            if (precompile_task) {
                runtime->precompile_tasks.push_back(
                    RuntimePrecompileTask { std::move(precompile_task), target,
                        jit_work_signal->track(JitWorkActivityKind::Worker) });
                ++precompile_tasks_by_phase[static_cast<std::size_t>(phase)];
                ++precompile_tasks_by_target[static_cast<std::size_t>(target)];
            } else {
                record_precompile_schedule_skip(
                    PrecompileScheduleSkip::HostRejected);
            }
        }
    };
    auto last_interactive_host_activity = std::chrono::steady_clock::now();
    std::uint64_t interaction_generation { 1U };
    std::optional<std::uint32_t> input_receiver_process;
    const auto note_interactive_host_activity = [&]() {
        last_interactive_host_activity = std::chrono::steady_clock::now();
        input_receiver_process =
            initial_runtime->kernel->graphics_input_receiver_process_id();
        if (++interaction_generation == 0U)
            ++interaction_generation;
        jit_work_signal->notify_work();
        // Native prediction shares the demand slab. Tokens are checked between
        // descriptors, so new interaction stops a live micro-batch at its next
        // safe publication boundary.
        for (const auto& runtime : runtimes) {
            for (const auto& task : runtime->precompile_tasks) {
                if (task.target == JitPrecompileTarget::NativeCode)
                    task.cancel();
            }
        }
        host_resources.wake();
    };
    SessionDiagnostics diagnostics { *initial_runtime, runtimes, scheduler,
        display_presenter.get(), output };
    while ((!bounded_execution || remaining_ticks != 0) &&
           !initial_runtime->kernel->process().exited && !hard_stop) {
        synchronize_device_time_to_host();
        synchronize_scheduler_time();
        observe_transition_stability();
        std::optional<XnuThreadId> input_preferred_thread;
        catalog_maintenance.poll(
            *initial_runtime->kernel, scheduler.runnable_count() == 0);
        if (display_presenter && !display_presenter->poll_events()) {
            hard_stop = true;
            break;
        }
        if (display_presenter) {
            for (const auto& input : display_presenter->take_touch_events()) {
                note_interactive_host_activity();
                initial_runtime->kernel->enqueue_touch_input(input);
            }
            for (const auto& input : display_presenter->take_button_events()) {
                note_interactive_host_activity();
                initial_runtime->kernel->enqueue_system_button(input);
            }
            for (const auto& input :
                display_presenter->take_ringer_switch_events()) {
                static_cast<void>(input);
                note_interactive_host_activity();
                initial_runtime->kernel->toggle_ringer_switch();
            }
        }
        if (touch_replay) {
            for (const auto& input : touch_replay->poll()) {
                note_interactive_host_activity();
                initial_runtime->kernel->enqueue_touch_input(input);
            }
        }
        for (const auto& input : live_touch_scheduler.poll()) {
            note_interactive_host_activity();
            initial_runtime->kernel->enqueue_touch_input(input);
        }
        if (pending_touch_input_completion && live_touch_scheduler.empty()) {
            mark_transition_input_complete(*pending_touch_input_completion);
            pending_touch_input_completion.reset();
        }
        for (const auto& input : live_button_scheduler.poll()) {
            note_interactive_host_activity();
            initial_runtime->kernel->enqueue_system_button(input);
            output.marker("[control] button=up scheduled event queued");
        }
        if (pending_button_input_completion && live_button_scheduler.empty()) {
            mark_transition_input_complete(*pending_button_input_completion);
            pending_button_input_completion.reset();
        }
        if (live_control) {
            for (const auto& command : live_control->poll()) {
                switch (command.kind) {
                case LiveControlCommandKind::Touch:
                    note_interactive_host_activity();
                    initial_runtime->kernel->enqueue_touch_input(command.touch);
                    output.marker("[control] touch queued");
                    mark_transition_input_complete("touch");
                    break;
                case LiveControlCommandKind::Gesture:
                    note_interactive_host_activity();
                    // Display power does not prove that the firmware is awake.
                    // Keep unlock's physical HOME and swipe sequence together.
                    if (command.wake_display) {
                        initial_runtime->kernel->enqueue_system_button(
                            SystemButtonInput {
                                SystemButton::Home, SystemButtonPhase::Down });
                        initial_runtime->kernel->enqueue_system_button(
                            SystemButtonInput {
                                SystemButton::Home, SystemButtonPhase::Up });
                        output.marker(
                            "[control] home requested before unlock gesture");
                    }
                    pending_touch_input_completion = "gesture";
                    live_touch_scheduler.schedule(command.gesture);
                    // Preserve control command order. In particular, "tap"
                    // followed by "lock" begins the touch before the button
                    // barrier even though the remainder of the gesture is paced
                    // over later host iterations.
                    for (const auto& input : live_touch_scheduler.poll()) {
                        initial_runtime->kernel->enqueue_touch_input(input);
                    }
                    output.marker("[control] gesture=" + command.message +
                                " scheduled events=" +
                                std::to_string(command.gesture.size()));
                    if (live_touch_scheduler.empty()) {
                        mark_transition_input_complete(
                            *pending_touch_input_completion);
                        pending_touch_input_completion.reset();
                    }
                    break;
                case LiveControlCommandKind::Button:
                    note_interactive_host_activity();
                    initial_runtime->kernel->enqueue_system_button(
                        command.system_button);
                    output.marker("[control] button event queued");
                    mark_transition_input_complete("button");
                    break;
                case LiveControlCommandKind::ButtonHold:
                    note_interactive_host_activity();
                    initial_runtime->kernel->enqueue_system_button(
                        SystemButtonInput { command.system_button.button,
                            SystemButtonPhase::Down });
                    live_button_scheduler.schedule(
                        command.system_button, command.button_hold);
                    pending_button_input_completion = "button-hold";
                    output.marker("[control] button hold scheduled duration-ms=" +
                                std::to_string(command.button_hold.count()));
                    if (live_button_scheduler.empty()) {
                        mark_transition_input_complete(
                            *pending_button_input_completion);
                        pending_button_input_completion.reset();
                    }
                    break;
                case LiveControlCommandKind::Home:
                    note_interactive_host_activity();
                    initial_runtime->kernel->enqueue_system_button(
                        SystemButtonInput {
                            SystemButton::Home, SystemButtonPhase::Down });
                    initial_runtime->kernel->enqueue_system_button(
                        SystemButtonInput {
                            SystemButton::Home, SystemButtonPhase::Up });
                    output.marker("[control] home requested");
                    mark_transition_input_complete("home");
                    break;
                case LiveControlCommandKind::Lock:
                    note_interactive_host_activity();
                    initial_runtime->kernel->enqueue_system_button(
                        SystemButtonInput {
                            SystemButton::Lock, SystemButtonPhase::Down });
                    initial_runtime->kernel->enqueue_system_button(
                        SystemButtonInput {
                            SystemButton::Lock, SystemButtonPhase::Up });
                    output.marker("[control] display lock requested");
                    mark_transition_input_complete("lock");
                    break;
                case LiveControlCommandKind::VolumeUp:
                case LiveControlCommandKind::VolumeDown: {
                    note_interactive_host_activity();
                    const auto button =
                        command.kind == LiveControlCommandKind::VolumeUp
                            ? SystemButton::VolumeUp
                            : SystemButton::VolumeDown;
                    initial_runtime->kernel->enqueue_system_button(
                        SystemButtonInput { button, SystemButtonPhase::Down });
                    initial_runtime->kernel->enqueue_system_button(
                        SystemButtonInput { button, SystemButtonPhase::Up });
                    output.marker(command.kind == LiveControlCommandKind::VolumeUp
                                    ? "[control] volume up requested"
                                    : "[control] volume down requested");
                    mark_transition_input_complete("volume");
                    break;
                }
                case LiveControlCommandKind::RingerRing:
                case LiveControlCommandKind::RingerSilent: {
                    note_interactive_host_activity();
                    const auto active =
                        command.kind == LiveControlCommandKind::RingerRing;
                    initial_runtime->kernel->set_ringer_switch_active(active);
                    output.marker(active ? "[control] ringer set to ring"
                                       : "[control] ringer set to silent");
                    break;
                }
                case LiveControlCommandKind::Snapshot: {
                    FrameFilePresenter snapshot_writer { command.path };
                    const auto frame =
                        initial_runtime->kernel->display_snapshot();
                    snapshot_writer.present(frame);
                    output.marker("[control] snapshot=" + command.path.string() +
                                " frame=" + std::to_string(frame.sequence));
                    break;
                }
                case LiveControlCommandKind::SnapshotSequence: {
                    const auto start = std::chrono::steady_clock::now();
                    for (std::size_t index = 0; index < command.snapshot_count;
                        ++index) {
                        std::ostringstream suffix;
                        suffix << '-' << std::setfill('0') << std::setw(4)
                               << index << ".ppm";
                        scheduled_snapshots.emplace_back(
                            start + command.snapshot_interval * index,
                            command.path.string() + suffix.str());
                    }
                    std::stable_sort(scheduled_snapshots.begin(),
                        scheduled_snapshots.end(),
                        [](const auto& left, const auto& right) {
                            return left.first < right.first;
                        });
                    output.marker(
                        "[control] snapshot-sequence prefix=" +
                        command.path.string() + " interval-ms=" +
                        std::to_string(command.snapshot_interval.count()) +
                        " count=" + std::to_string(command.snapshot_count));
                    break;
                }
                case LiveControlCommandKind::Settle:
                    begin_settle();
                    break;
                case LiveControlCommandKind::PerfBegin:
                    if (!performance_counters().enabled()) {
                        output.marker("[control] error: perf-begin requires "
                                    "--perf-summary");
                    } else if (display_performance_window) {
                        output.marker("[control] error: perf window already "
                                    "active label=" +
                                    *display_performance_window);
                    } else {
                        if (display_presenter)
                            display_presenter->flush_presentation();
                        if (!performance_counters().begin_display_window()) {
                            output.marker(
                                "[control] error: perf window could not begin");
                        } else {
                            if (performance_counters()
                                    .cpu_source_diagnostics_configured()) {
                                scheduler.set_dispatch_diagnostics(true);
                            }
                            display_performance_window = command.message;
                            // A formal no-content performance window must not
                            // fall back to the headless presenter's per-frame
                            // PNG writes. The first frame was already captured
                            // before the animation window, and explicit
                            // snapshots use their own presenter below.
                            if (frame_file_presenter &&
                                command.message == "animation")
                                frame_file_presenter->set_enabled(false);
                            if (realtime_pacer) {
                                display_clock_window = DisplayClockWindow {
                                    std::chrono::steady_clock::now(),
                                    initial_runtime->kernel
                                        ->current_absolute_time(),
                                    realtime_pacer
                                        ->allowed_device_monotonic_time()
                                };
                            }
                            output.marker("[control] perf-begin label=" +
                                          command.message);
                        }
                    }
                    break;
                case LiveControlCommandKind::PerfEnd:
                    if (!display_performance_window) {
                        output.marker("[control] error: no active perf window");
                    } else {
                        const auto clock_ended_at =
                            std::chrono::steady_clock::now();
                        const auto guest_ended_at =
                            initial_runtime->kernel->current_absolute_time();
                        const auto pacer_ended_at =
                            realtime_pacer
                                ? realtime_pacer
                                      ->allowed_device_monotonic_time()
                                : 0U;
                        if (performance_counters()
                                .cpu_source_diagnostics_configured()) {
                            scheduler.set_dispatch_diagnostics(false);
                        }
                        if (display_presenter)
                            display_presenter->flush_presentation();
                        const auto snapshot =
                            performance_counters().end_display_window();
                        if (snapshot) {
                            output.line(format_display_performance_summary(
                                *snapshot, *display_performance_window));
                        } else {
                            output.marker(
                                "[control] error: perf window could not end");
                        }
                        if (display_clock_window) {
                            const auto host_elapsed =
                                static_cast<std::uint64_t>(
                                    std::chrono::duration_cast<
                                        std::chrono::nanoseconds>(
                                        clock_ended_at -
                                        display_clock_window->started_at)
                                        .count());
                            const auto guest_elapsed =
                                guest_ended_at >=
                                        display_clock_window->guest_started_at
                                    ? guest_ended_at -
                                          display_clock_window->guest_started_at
                                    : 0U;
                            const auto pacer_elapsed =
                                pacer_ended_at >=
                                        display_clock_window->pacer_started_at
                                    ? pacer_ended_at -
                                          display_clock_window->pacer_started_at
                                    : 0U;
                            output.line(
                                "[perf-clock] label=" +
                                *display_performance_window +
                                " host-ns=" + std::to_string(host_elapsed) +
                                " guest-ns=" + std::to_string(guest_elapsed) +
                                " pacer-ns=" + std::to_string(pacer_elapsed) +
                                " host-sync=" +
                                std::to_string(
                                    display_clock_window->host_sync_count) +
                                " host-sync-deficit-total-ns=" +
                                std::to_string(display_clock_window
                                        ->host_sync_deficit_total_nanoseconds) +
                                " host-sync-deficit-max-ns=" +
                                std::to_string(display_clock_window
                                        ->host_sync_deficit_max_nanoseconds));
                        }
                        if (frame_file_presenter)
                            frame_file_presenter->set_enabled(true);
                        display_clock_window.reset();
                        display_performance_window.reset();
                    }
                    break;
                case LiveControlCommandKind::Status:
                    diagnostics.status();
                    break;
                case LiveControlCommandKind::Processes:
                    diagnostics.processes(command.message);
                    break;
                case LiveControlCommandKind::Threads:
                    diagnostics.threads(command.message);
                    break;
                case LiveControlCommandKind::Help:
                    output.marker(
                        "[control] commands: touch down|move|up|cancel x y; "
                        "tap x y [hold-ms]; unlock; "
                        "drag x1 y1 x2 y2 [duration-ms] [steps]; "
                        "button home|lock|volume-up|volume-down down|up; "
                        "hold BUTTON DURATION-MS; home; lock [hold-ms]; "
                        "volume-up; volume-down; snapshot PATH; "
                        "ringer ring|silent; "
                        "snapshot-sequence PATH-PREFIX INTERVAL-MS COUNT; "
                        "settle; "
                        "perf-begin LABEL; perf-end; "
                        "status; ps [PID|NAME]; threads PID|NAME; quit");
                    break;
                case LiveControlCommandKind::Quit:
                    output.marker("[control] quit requested");
                    hard_stop = true;
                    break;
                case LiveControlCommandKind::Error:
                    output.marker("[control] error: " + command.message);
                    break;
                }
            }
            if (hard_stop)
                break;
        }
        while (!scheduled_snapshots.empty() &&
               std::chrono::steady_clock::now() >=
                   scheduled_snapshots.front().first) {
            FrameFilePresenter snapshot_writer {
                scheduled_snapshots.front().second
            };
            snapshot_writer.present(
                initial_runtime->kernel->display_snapshot());
            output.marker("[control] snapshot-sequence frame=" +
                        scheduled_snapshots.front().second.string());
            scheduled_snapshots.erase(scheduled_snapshots.begin());
        }
        const auto resolve_display_urgent_threads = [&]() {
            if (!display_urgent_process)
                return;
            for (auto& runtime : runtimes) {
                if (runtime->kernel->process().pid != *display_urgent_process ||
                    runtime->kernel->process().exited) {
                    continue;
                }
                // Keep the Mach receiver and firmware NotifyFunc continuation
                // as distinct dependencies. After receive copyout, the former
                // remains the dependency processor until NotifyFunc advances
                // its watermark; storing it as the callback would discard the
                // last processor observed at the real callback boundary.
                if (const auto processor =
                        runtime->kernel->display_vsync_dependency_processor();
                    processor) {
                    const XnuThreadId receiver_thread { *display_urgent_process,
                        static_cast<std::uint32_t>(*processor) };
                    if (!display_urgent_receiver_thread ||
                        *display_urgent_receiver_thread != receiver_thread) {
                        display_urgent_receiver_thread = receiver_thread;
                        // Keep the receive itself preferred until the queued
                        // message has been materialized. The callback lease
                        // starts after delivery.
                        display_urgent_lease_deadline =
                            std::chrono::steady_clock::now() +
                            std::chrono::milliseconds { 50 };
                    }
                }
                if (runtime->kernel->display_vsync_callback_pending()) {
                    if (const auto processor = runtime->kernel
                            ->display_vsync_callback_processor()) {
                        const XnuThreadId callback_thread {
                            *display_urgent_process,
                            static_cast<std::uint32_t>(*processor)
                        };
                        if (!display_urgent_thread ||
                            *display_urgent_thread != callback_thread) {
                            display_urgent_thread = callback_thread;
                            display_urgent_lease_deadline =
                                std::chrono::steady_clock::now() +
                                std::chrono::milliseconds { 50 };
                        }
                    }
                }
                break;
            }
        };
        resolve_display_urgent_threads();
        synchronize_device_time_to_host();
        synchronize_scheduler_time();
        // Host synchronization can deliver a VSync notification without guest
        // execution consuming a slice. Re-resolve here so the already-pending
        // receive gets the same bounded callback lease in this iteration.
        resolve_display_urgent_threads();
        // Materialize a queued VSync receive before realtime pacing. If guest
        // execution is slightly ahead of the fixed host mapping, sleeping first
        // hides the already-due display callback and turns a small pacing lead
        // into a full submission interval. Delivery does not advance guest
        // time; the urgent display thread below is the only exception that may
        // execute while the guest is ahead.
        for (auto& runtime : runtimes) {
            const auto display_vsync_receiver =
                display_urgent_process && runtime->kernel->process().pid ==
                                              *display_urgent_process
                    ? runtime->kernel->display_vsync_receiver_processor()
                    : std::nullopt;
            for (const auto processor :
                runtime->kernel->pending_event_poll_candidates()) {
                if (processor >= runtime->cpus->size() ||
                    !runtime->allocated[processor]) {
                    continue;
                }
                const XnuThreadId thread { runtime->kernel->process().pid,
                    static_cast<std::uint32_t>(processor) };
                auto& waiting_cpu = runtime->cpus->cpu(processor);
                const auto delivered_display_vsync =
                    display_vsync_receiver &&
                    *display_vsync_receiver == processor;
                if (runtime->kernel->deliver_pending_event(waiting_cpu)) {
                    if (delivered_display_vsync) {
                        auto callback_processor =
                            runtime->kernel->display_vsync_callback_processor();
                        if (!callback_processor ||
                            !scheduler.info(
                                XnuThreadId { runtime->kernel->process().pid,
                                    static_cast<std::uint32_t>(
                                        *callback_processor) })) {
                            callback_processor = processor;
                        }
                        display_urgent_thread = XnuThreadId {
                            runtime->kernel->process().pid,
                            static_cast<std::uint32_t>(*callback_processor)
                        };
                        // The callback can be a continuation of a different
                        // thread than the one that consumed the Mach receive.
                        // If the callback thread is still waiting, schedule
                        // this exact receiver once instead of guessing with
                        // same-process thread age.
                        display_urgent_receiver_thread = thread;
                        display_urgent_lease_deadline =
                            std::chrono::steady_clock::now() +
                            std::chrono::milliseconds { 50 };
                    }
                    const auto delivered_input =
                        runtime->kernel->take_last_delivered_graphics_input(
                            processor);
                    // Every delivered event wakes its blocked guest receiver.
                    // Input attribution is a separate diagnostic concern;
                    // keeping the wake inside that conditional left pure
                    // Mach/VSync receivers Waiting.
                    const auto made_runnable = scheduler.make_runnable(thread);
                    if (made_runnable && delivered_input) {
                        // A just-delivered input event is a generic interactive
                        // wakeup, not a process-specific priority. Let its
                        // receiver run once before ordinary runnable
                        // continuations consume another slice. The preference
                        // is scoped to this host-loop iteration and does not
                        // alter Guest priority, quantum, wait/wake state, or
                        // clocks.
                        input_preferred_thread = thread;
                        performance_counters().record_diagnostic_input_runnable(
                            *delivered_input, thread.process, thread.thread);
                    }
                }
            }
        }
        if (realtime_pacer) {
            const auto display_urgent_runnable = [&]() {
                const auto is_runnable = [&](const auto& thread) {
                    if (!thread)
                        return false;
                    if (const auto info = scheduler.info(*thread);
                        info.has_value())
                        return info->state == XnuThreadState::Runnable;
                    return false;
                };
                // A waiting callback can have a runnable receive dependency. Do
                // not let realtime pacing sleep through that handoff; the
                // receiver must execute before the callback can become
                // runnable.
                return is_runnable(display_urgent_thread) ||
                       is_runnable(display_urgent_receiver_thread);
            }();
            const auto guest_ahead_delay =
                display_urgent_runnable
                    ? std::chrono::nanoseconds::zero()
                    : realtime_pacer->delay_until(
                          initial_runtime->kernel->current_absolute_time());
            if (guest_ahead_delay > std::chrono::nanoseconds::zero()) {
                const auto sleep_delay = realtime_pacer->limit_delay(
                    guest_ahead_delay, next_host_control_deadline());
                if (sleep_delay > std::chrono::nanoseconds::zero()) {
                    wait_for_host_activity(sleep_delay);
                }
                // A due host control should wake the polling loop, not make a
                // guest that is still ahead appear eligible to execute.
                continue;
            }
        }
        // XNU keeps a compact zombie process record until its parent waits, but
        // the dead task's translated host code has no guest-visible lifetime.
        // Give the compositor a short, generic grace interval before background
        // reclamation: destroying a large JIT immediately after Home otherwise
        // competes with the exit animation for host CPU. The FIFO reaper
        // destroys the pool before any later retirement of the owning Runtime,
        // preserving the AddressSpace and exclusive-monitor lifetimes.
        constexpr auto execution_reclaim_grace =
            std::chrono::milliseconds { 1500 };
        const auto activation_prepare_lead =
            JitWorkScheduler::activation_preparation_window(translation_lanes);
        const auto reclaim_now = std::chrono::steady_clock::now();
        const auto foreground_transition =
            initial_runtime->kernel->foreground_transition_snapshot();
        using ForegroundTransitionTerminal =
            KernelSharedState::ForegroundTransitionTerminalState;
        for (auto& runtime : runtimes) {
            std::erase_if(runtime->precompile_tasks,
                [](const auto& task) { return task.finished(); });
            if (!runtime->execution_prepare_task ||
                !runtime->execution_prepare_task->finished()) {
                continue;
            }
            runtime->execution_prepare_task.reset();
            if (runtime->resume_after_execution_prepare &&
                !runtime->kernel->process().exited) {
                if (runtime->image_activation_pending) {
                    const auto foreground_destination =
                        foreground_transition &&
                        foreground_transition->destination &&
                        foreground_transition->terminal_state ==
                            ForegroundTransitionTerminal::Pending &&
                        foreground_transition->destination->process_id ==
                            runtime->kernel->process().pid;
                    if (!runtime->activation_release_deadline) {
                        runtime->activation_release_deadline =
                            reclaim_now + activation_prepare_lead;
                    }
                    const auto activation_work_remaining =
                        runtime->cpus->next_precompile_phase(
                            JitPrecompileTarget::NativeCode,
                            JitPrecompileSource::DemandProfile) ||
                        runtime->cpus->next_precompile_phase(
                            JitPrecompileTarget::PortableIr,
                            JitPrecompileSource::DemandProfile);
                    const auto activation_ready =
                        runtime->precompile_tasks.empty() &&
                        (foreground_destination || !activation_work_remaining);
                    if (!activation_ready &&
                        reclaim_now < *runtime->activation_release_deadline) {
                        continue;
                    }
                    runtime->set_image_activation_pending(false);
                    runtime->activation_release_deadline.reset();
                }
                static_cast<void>(scheduler.resume_thread(
                    XnuThreadId { runtime->kernel->process().pid, 0 }));
            }
            runtime->resume_after_execution_prepare = false;
        }
        const auto precompile_finished = [&](Runtime& runtime) {
            std::erase_if(runtime.precompile_tasks,
                [](const auto& task) { return task.finished(); });
            if (runtime.precompile_tasks.empty())
                return true;
            static_cast<void>(runtime.begin_image_transition(host_resources));
            return false;
        };
        for (auto& runtime : runtimes) {
            if (runtime->kernel->process().exited &&
                runtime->cpus->has_execution_resources()) {
                if (runtime->execution_prepare_task &&
                    !runtime->execution_prepare_task->finished()) {
                    continue;
                }
                if (!runtime->execution_reclaim_after) {
                    if (runtime->kernel->process().termination_signal != 0)
                        diagnostics.threads(std::to_string(
                            runtime->kernel->process().pid));
                    runtime->execution_reclaim_after =
                        reclaim_now + execution_reclaim_grace;
                }
                if (reclaim_now < *runtime->execution_reclaim_after ||
                    scheduler.process_runnable_count(
                        runtime->kernel->process().pid) != 0) {
                    continue;
                }
                if (!precompile_finished(*runtime))
                    continue;
                account_runtime_jit_memory(*runtime);
                runtime_reaper.retire_execution_resources(
                    runtime->cpus->release_execution_resources());
                runtime->execution_reclaim_after.reset();
            }
        }
        for (auto& parent : runtimes) {
            const auto pending_waits = parent->kernel->pending_waits();
            for (const auto& [processor, pending] : pending_waits) {
                const auto child =
                    parent->kernel->wait_child(pending.target_pid, false);
                if (child.child_pid &&
                    parent->kernel->complete_wait(parent->cpus->cpu(processor),
                        *child.child_pid, child.status)) {
                    static_cast<void>(parent->kernel->wait_child(
                        static_cast<std::int32_t>(*child.child_pid), true));
                    static_cast<void>(scheduler.make_runnable(
                        XnuThreadId { parent->kernel->process().pid,
                            static_cast<std::uint32_t>(processor) }));
                } else if (!child.has_child) {
                    if (parent->kernel->fail_wait(
                            parent->cpus->cpu(processor), 10)) {
                        static_cast<void>(scheduler.make_runnable(
                            XnuThreadId { parent->kernel->process().pid,
                                static_cast<std::uint32_t>(processor) }));
                    }
                }
            }
        }
        for (auto runtime = runtimes.begin(); runtime != runtimes.end();) {
            if (runtime->get() != initial_runtime &&
                (*runtime)->kernel->process().exited &&
                !(*runtime)->cpus->has_execution_resources()) {
                if (runtime->get() == display_scanout_owner)
                    display_scanout_owner = nullptr;
                if (!precompile_finished(**runtime)) {
                    ++runtime;
                    continue;
                }
                account_runtime_jit_memory(**runtime);
                guest_deadlines.erase((*runtime)->kernel->process().pid);
                runtime_index.erase(**runtime);
                runtime_reaper.retire(std::move(*runtime));
                runtime = runtimes.erase(runtime);
            } else {
                ++runtime;
            }
        }
        const auto display_callback_pending = [&]() {
            if (!display_urgent_process)
                return false;
            for (const auto& runtime : runtimes) {
                if (!runtime->kernel->process().exited &&
                    runtime->kernel->process().pid == *display_urgent_process) {
                    return runtime->kernel->display_vsync_callback_pending();
                }
            }
            return false;
        }();
        const auto observed_inflight_callback =
            [&]() -> std::optional<std::pair<XnuThreadId, std::uint64_t>> {
            // A callback can become in-flight only after the queued
            // notification established one of these local dependencies. Avoid
            // another pair of kernel/Mach locks on every idle host-loop
            // iteration.
            if (!display_urgent_process ||
                (!display_urgent_thread && !display_urgent_receiver_thread))
                return std::nullopt;
            for (const auto& runtime : runtimes) {
                if (!runtime->kernel->process().exited &&
                    runtime->kernel->process().pid == *display_urgent_process) {
                    if (const auto dependency = runtime->kernel
                            ->display_vsync_inflight_callback_dependency()) {
                        return std::pair {
                            XnuThreadId { *display_urgent_process,
                                static_cast<std::uint32_t>(dependency->first) },
                            dependency->second
                        };
                    }
                    break;
                }
            }
            return std::nullopt;
        }();
        if (!observed_inflight_callback) {
            display_inflight_callback_thread.reset();
            display_inflight_callback_sequence = 0U;
            display_inflight_callback_deadline.reset();
        } else if (!display_inflight_callback_thread ||
                   *display_inflight_callback_thread !=
                       observed_inflight_callback->first ||
                   display_inflight_callback_sequence !=
                       observed_inflight_callback->second) {
            display_inflight_callback_thread =
                observed_inflight_callback->first;
            display_inflight_callback_sequence =
                observed_inflight_callback->second;
            // SwapEnd normally retires this ownership within one display
            // period. Keep a bounded safety lease so a firmware callback that
            // elects not to submit cannot retain host preference indefinitely.
            display_inflight_callback_deadline =
                std::chrono::steady_clock::now() +
                std::chrono::milliseconds { 100 };
        }
        const auto display_inflight_callback_active =
            display_inflight_callback_thread &&
            display_inflight_callback_deadline &&
            std::chrono::steady_clock::now() <
                *display_inflight_callback_deadline;
        const auto display_callback_work_active =
            display_callback_pending || display_inflight_callback_active;
        if (!display_callback_work_active)
            display_yielded_thread.reset();
        if (performance_counters().cpu_source_diagnostics_enabled() &&
            display_callback_pending) {
            const auto now = std::chrono::steady_clock::now();
            if (!display_callback_pending_since)
                display_callback_pending_since = now;
            if (!display_callback_pending_reported &&
                now - *display_callback_pending_since >=
                    std::chrono::milliseconds { 100 }) {
                const auto format_thread = [&](const auto& thread) {
                    if (!thread)
                        return std::string { "none" };
                    const auto info = scheduler.info(*thread);
                    return std::to_string(thread->process) + ":" +
                           std::to_string(thread->thread) + ":" +
                           (info ? std::to_string(
                                       static_cast<unsigned>(info->state))
                                 : "missing");
                };
                output.line("[perf] display-callback-pending duration-ms=100 "
                            "callback=" +
                            format_thread(display_urgent_thread) +
                            " receiver=" +
                            format_thread(display_urgent_receiver_thread));
                display_callback_pending_reported = true;
            }
        } else {
            display_callback_pending_since.reset();
            display_callback_pending_reported = false;
        }
        if (display_urgent_lease_deadline && !display_callback_pending &&
            std::chrono::steady_clock::now() >=
                *display_urgent_lease_deadline) {
            display_urgent_thread.reset();
            display_urgent_receiver_thread.reset();
            display_urgent_lease_deadline.reset();
        }
        const auto debugger_thread =
            debug_request && debug_request->thread &&
                    debug_request->thread->thread != 0
                ? std::optional<XnuThreadId> { XnuThreadId {
                      debug_request->thread->process,
                      debug_request->thread->thread - 1U } }
                : std::nullopt;
        const auto dispatch_now = std::chrono::steady_clock::now();
        const auto transition =
            initial_runtime->kernel->foreground_transition_snapshot();
        using TransitionTerminal =
            KernelSharedState::ForegroundTransitionTerminalState;
        const auto transition_process =
            transition && transition->destination &&
                    transition->terminal_state == TransitionTerminal::Pending &&
                    !transition->destination_first_frame
                ? std::optional<std::uint32_t> { transition->destination
                          ->process_id }
                : std::nullopt;
        const auto active_process =
            initial_runtime->kernel->active_client_process_id();
        const auto dispatch = guest_dispatch_policy.decide(scheduler,
            GuestDispatchObservation {
                .now = dispatch_now,
                .debugger_thread = debugger_thread,
                .explicit_handoff_thread = scheduler_handoff_thread,
                .realtime_process = display_urgent_process,
                .realtime_callback_thread = display_urgent_thread,
                .realtime_receiver_thread = display_urgent_receiver_thread,
                .realtime_yielded_thread = display_yielded_thread,
                .realtime_inflight_thread = display_inflight_callback_thread,
                .input_target_thread = input_preferred_thread,
                .input_receiver_process = input_receiver_process,
                .foreground_transition_process = transition_process,
                .active_process = active_process,
                .interaction_generation = interaction_generation,
                .realtime_notification_pending = display_callback_pending,
                .realtime_work_pending = display_callback_work_active,
                .realtime_inflight = display_inflight_callback_active,
                .realtime_lease_active =
                    display_urgent_lease_deadline &&
                    dispatch_now < *display_urgent_lease_deadline,
            });
        if (dispatch.explicit_handoff_stale)
            scheduler_handoff_thread.reset();
        const auto preferred_thread = dispatch.preferred_thread;
        // Keep the scanout owner identity across scheduler iterations.  The
        // realtime pacer can take the `guest ahead` path below without
        // executing a guest slice; clearing this identity here would then make
        // the next host-synchronized VSync wake an ordinary runnable thread
        // instead of allowing resolve_display_urgent_threads() to select its
        // receiver. Ownership is refreshed after guest execution and stale
        // identities are harmless because resolution still requires a live
        // matching runtime and a pending VSync receive.
        std::vector<XnuScheduledSlice> scheduled_batch;
        scheduled_batch.reserve(guest_processor_count);
        auto reservable_ticks = remaining_ticks;
        for (std::size_t processor = 0; processor < guest_processor_count;
            ++processor) {
            if (bounded_execution && reservable_ticks == 0)
                break;
            const auto scheduled =
                scheduler.choose_next(processor, preferred_thread);
            if (scheduled) {
                if (scheduler_handoff_thread &&
                    *scheduler_handoff_thread == scheduled->thread) {
                    scheduler_handoff_thread.reset();
                }
                if (display_yielded_thread &&
                    *display_yielded_thread != scheduled->thread) {
                    // One different runnable dependency has now received the
                    // processor; the Guest yield has been honored and the
                    // callback source may be considered again on the following
                    // scheduler iteration.
                    display_yielded_thread.reset();
                }
                performance_counters().record_diagnostic_input_execute(
                    scheduled->thread.process, scheduled->thread.thread);
                if (performance_counters().cpu_source_diagnostics_enabled() &&
                    scheduled->runnable_since !=
                        std::chrono::steady_clock::time_point { }) {
                    const auto elapsed = std::chrono::steady_clock::now() -
                                         scheduled->runnable_since;
                    const auto nanoseconds = static_cast<std::uint64_t>(
                        std::chrono::duration_cast<std::chrono::nanoseconds>(
                            elapsed)
                            .count());
                    performance_counters().record_diagnostic_scheduler_dispatch(
                        scheduled->thread.process, scheduled->thread.thread,
                        scheduled->runnable_generation,
                        scheduled->front_continuation, nanoseconds);
                    // Transition-localization probe. It records only severe
                    // runnable starvation while CPU source diagnostics are
                    // explicitly active.
                    if (nanoseconds >= 50'000'000U) {
                        const auto info = scheduler.info(scheduled->thread);
                        const auto active_process =
                            initial_runtime->kernel->active_client_process_id();
                        const auto transition =
                            initial_runtime->kernel
                                ->foreground_transition_snapshot();
                        output.line(
                            "[perf] scheduler-stall pid=" +
                            std::to_string(scheduled->thread.process) +
                            " thread=" +
                            std::to_string(scheduled->thread.thread) +
                            " wait-ns=" + std::to_string(nanoseconds) +
                            " priority=" +
                            (info ? std::to_string(info->scheduled_priority)
                                  : "none") +
                            " base-priority=" +
                            (info ? std::to_string(info->base_priority)
                                  : "none") +
                            " active-process=" +
                            (active_process ? std::to_string(*active_process)
                                            : "none") +
                            " transition-destination=" +
                            (transition && transition->destination
                                    ? std::to_string(
                                          transition->destination->process_id)
                                    : "none") +
                            " preferred=" +
                            std::to_string(
                                preferred_thread &&
                                *preferred_thread == scheduled->thread) +
                            " display-pending=" +
                            std::to_string(display_callback_pending));
                    }
                }
                scheduled_batch.push_back(*scheduled);
                if (bounded_execution) {
                    reservable_ticks -=
                        std::min(reservable_ticks, scheduled->tick_budget);
                }
                if (scheduled_batch.size() == 1U &&
                    guest_processor_count > 1U &&
                    guest_parallelism_policy.should_serialize(
                        scheduled->thread)) {
                    break;
                }
            }
            // A debugger-selected thread is the only thread allowed to make
            // progress for this resume request.
            if (preferred_thread)
                break;
        }

        std::vector<PreparedGuestSlice> prepared_slices;
        prepared_slices.reserve(scheduled_batch.size());
        std::optional<std::uint64_t> display_vsync_tick_budget;
        std::optional<std::uint64_t> display_vsync_deadline;
        for (auto& runtime : runtimes) {
            if (runtime->kernel->process().exited)
                continue;
            const auto deadline =
                runtime->kernel->next_display_vsync_deadline();
            if (deadline && (!display_vsync_deadline ||
                                *deadline < *display_vsync_deadline))
                display_vsync_deadline = deadline;
        }
        if (display_vsync_deadline) {
            const auto now = initial_runtime->kernel->current_absolute_time();
            if (*display_vsync_deadline > now) {
                display_vsync_tick_budget = std::max<std::uint64_t>(
                    1, duration_to_guest_ticks(*display_vsync_deadline - now,
                           darwin::mach::thread_policy::
                               absolute_time_units_per_second,
                           guest_ticks_per_second));
            }
        }
        auto batch_ticks = remaining_ticks;
        const auto host_slice_now = std::chrono::steady_clock::now();
        const auto host_control_deadline = next_host_control_deadline();
        const auto host_control_delay =
            host_control_deadline
                ? std::optional<std::chrono::nanoseconds> { std::chrono::
                          duration_cast<std::chrono::nanoseconds>(
                              *host_control_deadline - host_slice_now) }
                : std::nullopt;
        const auto display_deadline_delay =
            realtime_pacer && display_vsync_deadline
                ? std::optional<std::chrono::nanoseconds> { realtime_pacer
                          ->delay_until(*display_vsync_deadline) }
                : std::nullopt;
        const auto measured_jit_block = std::chrono::nanoseconds {
            static_cast<std::chrono::nanoseconds::rep>(
                performance_counters().jit_block_compile_p99_nanoseconds())
        };
        for (const auto& scheduled_value : scheduled_batch) {
            if (!scheduler.contains(scheduled_value.thread))
                continue;
            Runtime* selected_runtime = nullptr;
            for (auto& candidate : runtimes) {
                if (candidate->kernel->process().pid ==
                    scheduled_value.thread.process) {
                    selected_runtime = candidate.get();
                    break;
                }
            }
            if (selected_runtime == nullptr ||
                scheduled_value.thread.thread >=
                    selected_runtime->cpus->size()) {
                throw std::runtime_error {
                    "scheduler selected an unknown guest thread"
                };
            }
            if (selected_runtime->kernel->process().exited) {
                scheduler.remove_process(
                    selected_runtime->kernel->process().pid);
                guest_execution_policy.forget_process(
                    selected_runtime->kernel->process().pid);
                guest_parallelism_policy.forget_process(
                    selected_runtime->kernel->process().pid);
                continue;
            }
            const auto index =
                static_cast<std::size_t>(scheduled_value.thread.thread);
            auto& cpu = selected_runtime->cpus->cpu(index);
            cpu.clear_halt();
            // Signals that became deliverable while this thread was away run
            // their handlers now, as on XNU's way back to user mode.
            selected_runtime->kernel->deliver_pending_signals(cpu);
            if (selected_runtime->kernel->process().exited)
                continue;
            const auto host_slice_budget = guest_execution_policy.budget(
                scheduler,
                GuestExecutionBudgetRequest {
                    scheduled_value.thread,
                    measured_jit_block,
                    host_control_delay,
                    display_deadline_delay,
                    display_callback_work_active ||
                        (input_preferred_thread &&
                            *input_preferred_thread == scheduled_value.thread),
                });
            auto slice = bounded_execution ? std::min(batch_ticks,
                                                 scheduled_value.tick_budget)
                                           : scheduled_value.tick_budget;
            if (display_vsync_tick_budget &&
                *display_vsync_tick_budget < slice) {
                performance_counters().record_display_vsync_budget(
                    slice, *display_vsync_tick_budget);
                slice = *display_vsync_tick_budget;
            }
            if (bounded_execution)
                batch_ticks -= slice;
            prepared_slices.push_back(PreparedGuestSlice {
                scheduled_value,
                selected_runtime,
                index,
                GuestExecutionRequest {
                    &cpu,
                    scheduled_value.processor,
                    slice,
                    host_slice_budget,
                    debug_request && debug_request->kind == GdbResumeKind::Step,
                },
                false,
            });
        }

        const auto parallel_guest_batch =
            prepared_slices.size() > 1U &&
            std::none_of(prepared_slices.begin(), prepared_slices.end(),
                [&guest_parallelism_policy](const auto& prepared) {
                    return guest_parallelism_policy.should_serialize(
                        prepared.scheduled.thread);
                });
        for (auto& prepared : prepared_slices) {
            prepared.deferred_svc = parallel_guest_batch;
            prepared.execution.cpu->set_svc_dispatch_mode(
                parallel_guest_batch ? SvcDispatchMode::Deferred
                                     : SvcDispatchMode::Immediate);
        }

        if (guest_processor_count == 1 && !prepared_slices.empty() &&
            last_serial_thread !=
                std::optional<XnuThreadId> {
                    prepared_slices.front().scheduled.thread }) {
            // A local ARM exclusive reservation belongs to the physical
            // processor, not to the saved register context. Clear it only at a
            // real serialized thread switch; repeated slices of the same thread
            // retain the ordinary Umbra fast path.
            prepared_slices.front().execution.cpu->clear_exclusive_state(
                prepared_slices.front().scheduled.processor);
            last_serial_thread = prepared_slices.front().scheduled.thread;
        }
        if (parallel_guest_batch) {
            std::vector<GuestExecutionRequest*> execution_requests;
            execution_requests.reserve(prepared_slices.size());
            for (auto& prepared : prepared_slices)
                execution_requests.push_back(&prepared.execution);
            guest_execution_coordinator->run(execution_requests);
        } else {
            for (auto& prepared : prepared_slices) {
                if (scheduler.contains(prepared.scheduled.thread)) {
                    // Background compilation has its own executor/memory
                    // lock order. Batch scalar accesses only when no such
                    // compiler can compete with this serialized guest slice.
                    std::optional<AddressSpace::ExclusiveAccess> access;
                    if (!profile_precompile_enabled)
                        access.emplace(*prepared.runtime->memory);
                    GuestExecutionCoordinator::execute(prepared.execution);
                }
            }
        }

        // Guest dyld can publish its fixed shared-cache mappings from an SVC.
        // Observe that publication only after every Cpu::run has returned: the
        // profile queue has its own lock, while executing JIT callbacks must
        // remain free of cross-executor lock acquisition. Repeated slices for
        // one process collapse through the monotonic generation comparison.
        for (auto& prepared : prepared_slices) {
            auto& runtime = *prepared.runtime;
            const auto generation =
                runtime.memory->translation_profile_mapping_generation();
            if (generation != runtime.translation_profile_mapping_generation) {
                runtime.translation_profile_mapping_generation = generation;
                runtime.cpus->retry_deferred_translation_profile();
                if (runtime.jit_work_signal)
                    runtime.jit_work_signal->notify_work();
            }
        }

        const bool ran_thread = !prepared_slices.empty();
        std::uint64_t scheduler_round_ticks = 0;
        for (auto& prepared : prepared_slices) {
            if (prepared.execution.error)
                std::rethrow_exception(prepared.execution.error);
            const auto scheduled =
                std::optional<XnuScheduledSlice> { prepared.scheduled };
            if (!scheduler.contains(scheduled->thread))
                continue;
            auto& runtime = *prepared.runtime;
            const auto index = prepared.thread_index;
            auto& cpu = *prepared.execution.cpu;
            auto result = std::move(prepared.execution.result);
            if (performance_counters().cpu_source_diagnostics_enabled() &&
                result.svc_calls != 0 && result.ticks_consumed < 10'000U) {
                if (diagnostic_svc_spin_thread != scheduled->thread) {
                    diagnostic_svc_spin_thread = scheduled->thread;
                    diagnostic_svc_spin_calls = 0;
                    diagnostic_svc_spin_report_at = 1'000;
                }
                diagnostic_svc_spin_calls += result.svc_calls;
                if (diagnostic_svc_spin_calls >=
                    diagnostic_svc_spin_report_at) {
                    const auto& registers = cpu.registers();
                    output.line(
                        "[perf] svc-spin pid=" +
                        std::to_string(scheduled->thread.process) +
                        " thread=" + std::to_string(scheduled->thread.thread) +
                        " calls=" + std::to_string(diagnostic_svc_spin_calls) +
                        " r12=" + std::to_string(registers[12]) +
                        " r0=" + std::to_string(registers[0]) +
                        " pc=" + std::to_string(registers[15]) + " lr=" +
                        std::to_string(registers[14]) + " display-pending=" +
                        std::to_string(display_callback_pending));
                    diagnostic_svc_spin_report_at *= 10U;
                }
            } else {
                diagnostic_svc_spin_thread.reset();
                diagnostic_svc_spin_calls = 0;
                diagnostic_svc_spin_report_at = 1'000;
            }
            guest_parallelism_policy.observe(
                scheduled->thread, result.ticks_consumed, result.svc_calls);
            if (prepared.deferred_svc && result.svc) {
                runtime.kernel->dispatch(cpu, *result.svc);
                // UserDefined2 is shared by deferred SVC and host cooperation.
                // The explicit host-only marker remains attached to the result;
                // only the reason explicitly requested by the serial kernel
                // dispatch represents the guest thread's scheduler state here.
                result.reason = cpu.consume_requested_halt_reason();
            }
            if (const auto handoff =
                    runtime.kernel->consume_scheduler_handoff(index)) {
                scheduler_handoff_thread = *handoff;
            }
            scheduler_round_ticks =
                std::max(scheduler_round_ticks, result.ticks_consumed);
            stopped_pid = runtime.kernel->process().pid;
            stopped_cpu = index;
            stopped_result = result;
            consumed_ticks += result.ticks_consumed;
            if (bounded_execution) {
                remaining_ticks -=
                    std::min(remaining_ticks, result.ticks_consumed);
            }
            bool debug_stop = result.debug_breakpoint.has_value() ||
                              prepared.execution.single_step;
            std::uint8_t debug_signal = gdb_signal::trap;
            const auto fatal_result = result.fault ||
                                      !result.exception.empty() ||
                                      Umbra::Has(result.reason,
                                          Umbra::HaltReason::UserDefined4);
            if (fatal_result) {
                const auto& registers = cpu.registers();
                std::ostringstream failure;
                failure << "[cpu] fatal pid=" << runtime.kernel->process().pid
                        << " cpu=" << index << " pc=0x" << std::hex
                        << registers[15] << " lr=0x" << registers[14];
                if (result.fault) {
                    failure << " fault=0x" << result.fault->address
                            << " access=0x"
                            << static_cast<unsigned>(result.fault->access)
                            << " size=0x" << result.fault->size;
                }
                if (!result.exception.empty())
                    failure << " exception=\"" << result.exception << '"';
                failure << " sp=0x" << registers[13] << " cpsr=0x"
                        << cpu.cpsr();
                for (std::size_t index = 0; index < 13; ++index)
                    failure << " r" << std::dec << index << "=0x" << std::hex
                            << registers[index];
                output.line(failure.str());
            }
            auto completion = XnuSliceCompletion::Continue;
            bool scheduler_completed = false;
            if (Umbra::Has(
                    result.reason, Umbra::HaltReason::UserDefined5)) {
                completion = XnuSliceCompletion::Block;
            } else if (Umbra::Has(
                           result.reason, Umbra::HaltReason::UserDefined6) &&
                       runtime.pending_exec) {
                auto pending = std::move(*runtime.pending_exec);
                runtime.pending_exec.reset();
                const auto image_epoch =
                    runtime.begin_image_transition(host_resources);
                try {
                    catalog_maintenance.poll(*initial_runtime->kernel, true);
                    debug_target.notify_exec(runtime.kernel->process().pid);
                    runtime.memory->clear();
                    ProcessLoader exec_loader { rootfs, *runtime.memory,
                        guest_architecture, session_catalog.index(),
                        darwin_abi.initial_apple_vector_abi, darwin_abi.address_layout };
                    auto loaded = exec_loader.load(pending.path,
                        std::move(pending.arguments), pending.environment);
                    runtime.kernel->set_process_arguments(
                        loaded.arguments, pending.environment);
                    runtime.kernel->set_process_image(pending.path,
                        loaded.executable.code_signature_entitlements(),
                        &loaded.dynamic_linker, &loaded.executable);
                    runtime.kernel->prepare_exec(pending.processor);
                    auto& exec_cpu = runtime.cpus->cpu(pending.processor);
                    exec_cpu.reset();
                    exec_cpu.clear_cache();
                    exec_cpu.registers().fill(0);
                    exec_cpu.registers()[13] = loaded.stack_pointer;
                    exec_cpu.registers()[15] = loaded.entry_point;
                    exec_cpu.set_cpsr(0x10);
                    const auto process_id = runtime.kernel->process().pid;
                    const auto transition =
                        initial_runtime->kernel
                            ->foreground_transition_snapshot();
                    using TransitionTerminal =
                        KernelSharedState::ForegroundTransitionTerminalState;
                    const auto transition_destination =
                        transition && transition->destination &&
                        transition->destination->process_id == process_id &&
                        transition->terminal_state ==
                            TransitionTerminal::Pending;
                    const auto active_process =
                        initial_runtime->kernel->active_client_process_id();
                    const auto interactive_activation =
                        transition_destination ||
                        (active_process && *active_process == process_id);
                    const auto critical_runtime =
                        &runtime == initial_runtime ||
                        display_scanout_owner == &runtime;
                    apply_jit_runtime_class(runtime,
                        critical_runtime ? JitCodeCacheClass::BootCritical
                        : interactive_activation
                            ? JitCodeCacheClass::Foreground
                            : JitCodeCacheClass::Background);
                    assign_jit_process_profile(runtime, loaded,
                        precompile_phase_for_lifecycle(interactive_activation));
                    runtime.kernel->install_main_image_hle(
                        exec_cpu, loaded.executable_path);
                    precompile_startup_profile(runtime, loaded.executable_path);
                    observe_runtime_jit_memory_counted(runtime);
                    runtime.activate_image_epoch(image_epoch);
                    static_cast<void>(scheduler.complete_slice(
                        scheduled->thread, result.ticks_consumed,
                        XnuSliceCompletion::Terminate,
                        XnuTimeAccounting::Deferred));
                    scheduler.remove_process(runtime.kernel->process().pid);
                    guest_execution_policy.forget_process(
                        runtime.kernel->process().pid);
                    guest_parallelism_policy.forget_process(
                        runtime.kernel->process().pid);
                    std::fill(runtime.allocated.begin(),
                        runtime.allocated.end(), false);
                    runtime.allocated[pending.processor] = true;
                    static_cast<void>(scheduler.register_thread(
                        XnuThreadId { runtime.kernel->process().pid,
                            static_cast<std::uint32_t>(pending.processor) },
                        runtime.kernel->process().thread_base_priority));
                    scheduler_completed = true;
                } catch (const std::exception& error) {
                    output.line("[process] exec failed pid=" +
                                std::to_string(runtime.kernel->process().pid) +
                                " path=" + pending.path +
                                " error=" + error.what());
                    runtime.kernel->exit_process(127);
                    completion = XnuSliceCompletion::Terminate;
                }
            } else if (fatal_result) {
                if (gdb_server) {
                    debug_stop = true;
                    debug_signal = result.fault
                                       ? gdb_signal::segmentation_fault
                                       : gdb_signal::illegal_instruction;
                } else if (runtime.kernel->process().pid !=
                           initial_runtime->kernel->process().pid) {
                    // The fault becomes the signal a device raises for it; the
                    // thread goes on in its handler or the process dies of it.
                    const auto fault = guest_fault_of(result, cpu);
                    const auto fatal_signal = fault
                        ? runtime.kernel->deliver_fault_signal(cpu, *fault)
                        : std::optional<std::uint32_t> {
                              result.fault ? gdb_signal::segmentation_fault
                                           : gdb_signal::illegal_instruction };
                    if (fatal_signal) {
                        runtime.kernel->exit_process(0, *fatal_signal);
                        completion = XnuSliceCompletion::Terminate;
                    } else {
                        completion = XnuSliceCompletion::Continue;
                    }
                } else {
                    completion = XnuSliceCompletion::Terminate;
                    hard_stop = true;
                }
            } else if (Umbra::Has(result.reason,
                           Umbra::HaltReason::CacheInvalidation)) {
                // Umbra may return after completing a shared code-cache
                // invalidation at a safe host boundary. This is not a guest
                // wait or scheduler state transition; resume the same runnable
                // slice.
                completion = XnuSliceCompletion::Continue;
            } else if (Umbra::Has(
                           result.reason, Umbra::HaltReason::UserDefined1)) {
                completion = XnuSliceCompletion::Terminate;
            } else if (Umbra::Has(
                           result.reason, Umbra::HaltReason::UserDefined8)) {
                if (const auto request =
                        runtime.kernel->consume_scheduler_yield(index);
                    request) {
                    if (performance_counters()
                            .cpu_source_diagnostics_enabled() &&
                        display_callback_pending &&
                        diagnostic_display_yield_count++ < 32U) {
                        output.line(
                            "[perf] display-yield source=" +
                            std::to_string(scheduled->thread.process) + ":" +
                            std::to_string(scheduled->thread.thread) +
                            " handoff=" +
                            (scheduler_handoff_thread
                                    ? std::to_string(
                                          scheduler_handoff_thread->process) +
                                          ":" +
                                          std::to_string(
                                              scheduler_handoff_thread->thread)
                                    : "none") +
                            " depress=" + std::to_string(request->depress));
                    }
                    if (request->depress) {
                        const auto duration_ticks = duration_to_guest_ticks(
                            request->duration_milliseconds,
                            xnu::scheduler::milliseconds_per_second,
                            guest_ticks_per_second);
                        static_cast<void>(scheduler.depress(
                            scheduled->thread, duration_ticks));
                    }
                }
                completion = XnuSliceCompletion::Yield;
            } else if (result.host_yielded) {
                // Host cooperation is not a Guest AST or a guest scheduler
                // yield. Preserve the current quantum and priority while
                // releasing only the emulator's queue-head continuation so an
                // equal-priority peer can run after a wall-time-expensive
                // translation or immediate SVC.
                completion = XnuSliceCompletion::HostCooperate;
            } else if (Umbra::Has(
                           result.reason, Umbra::HaltReason::UserDefined2)) {
                // XNU AST preemption retains the current quantum. The
                // scheduler requeues this thread at the head of its
                // priority, while a higher priority still wins selection.
                completion = XnuSliceCompletion::Continue;
            } else if (result.ticks_consumed == 0 && !debug_stop) {
                // A runnable CPU returning without executing an instruction
                // and without a classified wait/exit/fault would otherwise
                // make the unbounded scheduler spin forever. This is an
                // internal emulation failure, not a normal stop condition.
                std::ostringstream error;
                error << "scheduler made no progress for pid="
                      << runtime.kernel->process().pid << " cpu=" << index
                      << " pc=0x" << std::hex << cpu.registers()[15]
                      << " halt_reason=0x"
                      << static_cast<std::uint64_t>(result.reason);
                throw std::runtime_error { error.str() };
            }
            if (completion == XnuSliceCompletion::Yield &&
                display_callback_work_active &&
                ((display_urgent_thread &&
                     *display_urgent_thread == scheduled->thread) ||
                    (display_urgent_receiver_thread &&
                        *display_urgent_receiver_thread == scheduled->thread) ||
                    (display_inflight_callback_thread &&
                        *display_inflight_callback_thread ==
                            scheduled->thread))) {
                // thread_switch is an explicit Guest request for another
                // runnable dependency to make progress. Suppress this source
                // for one host selection instead of either immediately
                // reselecting it (which can spin) or discarding all callback
                // ownership (which can starve the pending VSync behind
                // unrelated cold-start work).
                display_yielded_thread = scheduled->thread;
            }
            if (!scheduler_completed) {
                guest_execution_policy.observe(scheduled->thread, completion);
                const auto slice_completed = scheduler.complete_slice(
                    scheduled->thread, result.ticks_consumed, completion,
                    XnuTimeAccounting::Deferred);
                if (slice_completed && completion == XnuSliceCompletion::Block)
                    runtime.kernel->notify_thread_blocked(index);
                if (completion == XnuSliceCompletion::Terminate &&
                    runtime.kernel->process().exited) {
                    scheduler.remove_process(runtime.kernel->process().pid);
                    guest_execution_policy.forget_process(
                        runtime.kernel->process().pid);
                    guest_parallelism_policy.forget_process(
                        runtime.kernel->process().pid);
                }
            }
            if (gdb_server && gdb_server->poll_interrupt()) {
                debug_stop = true;
                debug_signal = gdb_signal::interrupt;
            }
            if (debug_stop && gdb_server && !hard_stop) {
                const GdbThreadId stopped_thread {
                    runtime.kernel->process().pid,
                    static_cast<std::uint32_t>(index + 1U)
                };
                debug_target.set_current_thread(stopped_thread);
                auto request = gdb_server->command_loop(
                    debug_target, stopped_thread, debug_signal, true);
                if (request.kind == GdbResumeKind::Detach) {
                    debug_target.remove_all_breakpoints();
                    gdb_server->detach();
                    gdb_server.reset();
                    debug_request.reset();
                    for (auto& candidate : runtimes) {
                        for (std::size_t processor = 0;
                            processor < candidate->cpus->size(); ++processor) {
                            candidate->cpus->cpu(processor)
                                .set_debug_breakpoints_enabled(false);
                        }
                    }
                } else if (request.kind == GdbResumeKind::Kill) {
                    hard_stop = true;
                } else {
                    debug_request = request;
                }
            }
            if (hard_stop)
                break;
        }
        if (realtime_pacer)
            executed_ticks_since_catch_up += scheduler_round_ticks;
        if (device_time_policy == DeviceTimePolicy::DeterministicExecution) {
            // Bounded runs derive DeterministicTime from executed guest ticks.
            // CPU usage and quantum accounting already happened in
            // complete_slice(); this advances only their deterministic
            // scheduler/device timeline.
            scheduler.advance_time(scheduler_round_ticks);
            if (scheduler_round_ticks != 0) {
                initial_runtime->kernel->advance_time_by(
                    guest_tick_clock.absolute_time_units(
                        scheduler_round_ticks));
                const auto advanced_time =
                    initial_runtime->kernel->current_absolute_time();
                for (auto& runtime : runtimes) {
                    if (runtime.get() != initial_runtime &&
                        !runtime->kernel->process().exited) {
                        runtime->kernel->service_time_dependent_devices(
                            advanced_time);
                    }
                }
            }
        }
        if (scheduler_round_ticks != 0) {
            // IOMobileFramebuffer scans its reserved CoreSurface directly;
            // firmware does not unlock or swap that front buffer. Cache the
            // publishing task after the first lookup; imported task-local
            // mappings retain the producer provenance and cannot steal
            // ownership.
            if (display_scanout_owner == nullptr ||
                display_scanout_owner->kernel->process().exited ||
                !display_scanout_owner->kernel->owns_display_scanout()) {
                display_scanout_owner = nullptr;
                for (auto& runtime : runtimes) {
                    if (!runtime->kernel->process().exited &&
                        runtime->kernel->owns_display_scanout()) {
                        display_scanout_owner = runtime.get();
                        output.line(
                            "[display] scanout-owner pid=" +
                            std::to_string(
                                display_scanout_owner->kernel->process().pid));
                        break;
                    }
                }
            }
            if (display_scanout_owner != nullptr)
                static_cast<void>(
                    display_scanout_owner->kernel->refresh_display_scanout());
        }
        refresh_jit_runtime_classes();
        if (display_scanout_owner != nullptr) {
            // A realtime host-sync step at the top of the loop can advance the
            // device clock and enqueue a VSync message without passing through
            // the guest-time advance above. Keep the scanout owner marked for
            // the next polling iteration in both cases;
            // resolve_display_urgent_threads() still selects a thread only when
            // it has a pending VSync receive.
            display_urgent_process.reset();
            std::optional<std::uint64_t> earliest_vsync;
            for (auto& runtime : runtimes) {
                if (runtime->kernel->process().exited)
                    continue;
                const auto deadline =
                    runtime->kernel->next_display_vsync_deadline();
                if (deadline &&
                    (!earliest_vsync || *deadline < *earliest_vsync)) {
                    earliest_vsync = deadline;
                    display_urgent_process = runtime->kernel->process().pid;
                }
            }
            if (!display_urgent_process)
                display_urgent_process =
                    display_scanout_owner->kernel->process().pid;
        }
        const auto display_submissions =
            initial_runtime->kernel->display_submitted_frames();
        if (display_submissions != observed_display_submissions) {
            observed_display_submissions = display_submissions;
            last_display_submission = std::chrono::steady_clock::now();
            display_urgent_thread.reset();
            display_urgent_receiver_thread.reset();
            display_yielded_thread.reset();
            display_inflight_callback_thread.reset();
            display_inflight_callback_sequence = 0U;
            display_inflight_callback_deadline.reset();
            display_urgent_lease_deadline.reset();
        }
        if (ran_thread) {
            guest_idle_since.reset();
        } else if (!guest_idle_since) {
            guest_idle_since = std::chrono::steady_clock::now();
        }
        if (ran_thread && profile_background_warming_enabled) {
            const auto now = std::chrono::steady_clock::now();
            std::optional<HostResourceController::Clock::time_point>
                host_compile_deadline = next_host_control_deadline();
            if (realtime_pacer) {
                std::optional<std::uint64_t> display_deadline;
                for (auto& runtime : runtimes) {
                    if (runtime->kernel->process().exited)
                        continue;
                    const auto candidate =
                        runtime->kernel->next_display_vsync_deadline();
                    if (candidate &&
                        (!display_deadline || *candidate < *display_deadline))
                        display_deadline = candidate;
                }
                if (display_deadline) {
                    const auto host_display_deadline =
                        realtime_pacer->host_deadline_for(*display_deadline);
                    if (!host_compile_deadline ||
                        host_display_deadline < *host_compile_deadline) {
                        host_compile_deadline = host_display_deadline;
                    }
                }
            }
            host_resources.set_next_deadline(host_compile_deadline);
            JitWorkObservation observation;
            observation.memory_pressure =
                host_memory_is_pressured(latest_host_memory_budget) ||
                jit_code_cache_governor.total_actual() >
                    jit_code_cache_governor.total_budget();
            observation.realtime_work_pending =
                display_callback_work_active || input_preferred_thread;
            observation.display_started = observed_display_submissions != 0U;
            if (now >= last_display_submission)
                observation.display_quiet_for = now - last_display_submission;
            if (host_compile_deadline) {
                observation.deadline_remaining =
                    *host_compile_deadline > now
                        ? std::chrono::duration_cast<std::chrono::nanoseconds>(
                              *host_compile_deadline - now)
                        : std::chrono::nanoseconds::zero();
            }
            if (now >= last_interactive_host_activity) {
                observation.interaction_quiet_for =
                    now - last_interactive_host_activity;
            }
            observation.block_compile_p95_nanoseconds =
                performance_counters().jit_block_compile_p95_nanoseconds();
            observation.block_compile_p99_nanoseconds =
                performance_counters().jit_block_compile_p99_nanoseconds();
            // Guest-busy admission is intentionally role-only. Generic
            // prediction and portable persistence remain idle-bound.
            schedule_jit_profile_work(
                observation, host_compile_deadline, false);
        }
        if (!ran_thread) {
            constexpr auto jit_quota_refresh_period =
                std::chrono::milliseconds { 250 };
            const auto quota_now = std::chrono::steady_clock::now();
            if (quota_now - last_jit_quota_refresh >=
                jit_quota_refresh_period) {
                last_jit_quota_refresh = quota_now;
                const auto memory = host.memory_budget_snapshot();
                latest_host_memory_budget = memory;
                const auto memory_pressured = host_memory_is_pressured(memory);
                jit_code_cache_governor.set_pressure_limited(memory_pressured);
                for (auto& runtime : runtimes) {
                    if (!runtime->jit_cache_reservation ||
                        !runtime->cpus->has_execution_resources()) {
                        continue;
                    }
                    const auto actual = runtime->cpus->jit_code_cache_bytes();
                    jit_code_cache_governor.refresh_actual(
                        *runtime->jit_cache_reservation, actual);
                }
                const auto cache_budget_exceeded =
                    jit_code_cache_governor.total_actual() >
                    jit_code_cache_governor.total_budget();
                const auto reclamation_needed =
                    memory_pressured || cache_budget_exceeded;
                if (reclamation_needed && !pressure_reclamation_applied) {
                    // Pressure handling is ordered: cancel optional compile
                    // work first, then stop artifact writeback, then reclaim
                    // unreferenced artifacts.
                    for (auto& runtime : runtimes) {
                        bool active_precompile { };
                        for (const auto& task : runtime->precompile_tasks) {
                            if (!task.finished()) {
                                task.cancel();
                                active_precompile = true;
                            }
                        }
                        if (active_precompile) {
                            runtime->cpus->quiesce_precompilation();
                            for (const auto& task : runtime->precompile_tasks) {
                                task.wait_finished();
                            }
                        }
                        runtime->precompile_tasks.clear();
                    }
                    jit_artifacts->cancel_writeback();
                    const auto artifact_before = jit_artifacts->stats();
                    const auto target = artifact_before.resident_bytes / 2U;
                    const auto reclaimed =
                        jit_artifacts->trim_resident_bytes(target);
                    output.line(
                        "[jit-pressure] level=" +
                        std::string { host_memory_pressure_name(memory) } +
                        " compile=stopped writeback=stopped "
                        "artifact-reclaimed-bytes=" +
                        std::to_string(reclaimed) +
                        " target-resident-bytes=" + std::to_string(target));
                    pressure_reclamation_applied = true;
                }
                if (reclamation_needed) {
                    // Native mappings stay intact. At a global Guest-idle safe
                    // point, discard only an ordinary runtime whose measured
                    // live code exceeds its core-owned retention target. This
                    // is intentionally after optional work cancellation.
                    std::uint64_t native_reclaimed { };
                    std::size_t native_runtimes { };
                    for (auto& runtime : runtimes) {
                        if (!runtime->jit_cache_reservation ||
                            !runtime->cpus->has_execution_resources() ||
                            runtime->jit_cache_class !=
                                JitCodeCacheClass::Background ||
                            scheduler.process_runnable_count(
                                runtime->kernel->process().pid) != 0U ||
                            jit_code_cache_governor.reclaimable_bytes(
                                *runtime->jit_cache_reservation) == 0U) {
                            continue;
                        }
                        const auto before =
                            runtime->cpus->jit_code_cache_bytes();
                        runtime->cpus->clear_cache();
                        const auto after =
                            runtime->cpus->jit_code_cache_bytes();
                        jit_code_cache_governor.refresh_actual(
                            *runtime->jit_cache_reservation, after);
                        native_reclaimed +=
                            before > after ? before - after : 0U;
                        ++native_runtimes;
                    }
                    if (native_runtimes != 0U) {
                        output.line(
                            "[jit-pressure] native-runtimes=" +
                            std::to_string(native_runtimes) +
                            " native-reclaimed-bytes=" +
                            std::to_string(native_reclaimed) +
                            " live-code-bytes=" +
                            std::to_string(
                                jit_code_cache_governor.total_actual()) +
                            " live-code-budget-bytes=" +
                            std::to_string(
                                jit_code_cache_governor.total_budget()));
                    }
                } else {
                    pressure_reclamation_applied = false;
                }
            }
            if (gdb_server && gdb_server->poll_interrupt()) {
                const auto stopped_thread =
                    debug_target.current_thread().value_or(
                        GdbThreadId { 1, 1 });
                auto request = gdb_server->command_loop(
                    debug_target, stopped_thread, gdb_signal::interrupt, true);
                if (request.kind == GdbResumeKind::Detach) {
                    debug_target.remove_all_breakpoints();
                    gdb_server->detach();
                    gdb_server.reset();
                    debug_request.reset();
                    for (auto& runtime : runtimes) {
                        for (std::size_t processor = 0;
                            processor < runtime->cpus->size(); ++processor) {
                            runtime->cpus->cpu(processor)
                                .set_debug_breakpoints_enabled(false);
                        }
                    }
                } else if (request.kind == GdbResumeKind::Kill) {
                    hard_stop = true;
                } else {
                    debug_request = request;
                }
                continue;
            }
            // Sample live execution pools at most 20 Hz. Lifecycle transitions
            // and final retirement take immediate snapshots so short-lived
            // runtimes are still represented without turning the idle loop into
            // a queue probe.
            observe_runtime_jit_memory_if_due();
            const auto next_deadline = next_guest_deadline();
            const auto next_host_deadline = next_host_control_deadline();
            std::optional<HostResourceController::Clock::time_point>
                host_compile_deadline;
            if (realtime_pacer && next_deadline) {
                const auto delay = realtime_pacer->delay_until(*next_deadline);
                if (delay > std::chrono::nanoseconds::zero()) {
                    host_compile_deadline =
                        realtime_pacer->host_deadline_for(*next_deadline);
                }
            }
            if (next_host_deadline &&
                (!host_compile_deadline ||
                    *next_host_deadline < *host_compile_deadline)) {
                host_compile_deadline = *next_host_deadline;
            }
            // Host maintenance remains deadline-aware even when profile warming
            // is disabled. The profile branch may submit optional compile work,
            // but it must not own publication of the deadline used by the
            // controller.
            host_resources.set_next_deadline(host_compile_deadline);
            const auto schedule_artifact_compaction = [&]() {
                const auto now = std::chrono::steady_clock::now();
                const auto input_deadline_pending =
                    (touch_replay &&
                        touch_replay->next_deadline().has_value()) ||
                    live_button_scheduler.next_deadline().has_value() ||
                    live_touch_scheduler.next_deadline().has_value();
                const ArtifactCompactionAdmissionSnapshot admission_snapshot {
                    now, scheduler.runnable_count(), input_deadline_pending,
                    host_compile_deadline &&
                        *host_compile_deadline <=
                            now + artifact_compaction_deadline_reserve,
                    host_memory_is_pressured(latest_host_memory_budget),
                    host_resources.accepting_work()
                };
                if (artifact_compaction_task) {
                    if (!artifact_compaction_task->finished()) {
                        if (artifact_compaction_admission.observe(
                                admission_snapshot, true) ==
                            ArtifactCompactionAdmissionDecision::CancelActive) {
                            if (!artifact_compaction_task->cancelled()) {
                                const auto requested = steady_nanoseconds();
                                if (artifact_compaction_record &&
                                    artifact_compaction_record
                                        ->request_cancellation(requested)) {
                                    artifact_compaction_task->cancel();
                                    artifact_compaction_admission
                                        .note_cancellation_request(now);
                                    artifact_compaction_telemetry
                                        .cancellation_requests.fetch_add(
                                            1U, std::memory_order_relaxed);
                                }
                            }
                            host_resources.wake();
                        }
                        return;
                    }
                    if (artifact_compaction_record &&
                        artifact_compaction_record->state() ==
                            ArtifactCompactionTaskState::Queued &&
                        artifact_compaction_task->cancelled()) {
                        const auto terminal_time = steady_nanoseconds();
                        if (artifact_compaction_record->publish_terminal(
                                ArtifactCompactionTaskState::
                                    CancelledBeforeStart,
                                terminal_time)) {
                            observe_compaction_terminal(
                                *artifact_compaction_record,
                                ArtifactCompactionTaskState::
                                    CancelledBeforeStart,
                                terminal_time, terminal_time, 0U, 0U, 0U, 0U,
                                0U, 0U, 0U, 0U, 0U, 0U, 0U, 0U);
                        }
                    }
                    artifact_compaction_task.reset();
                    artifact_compaction_record.reset();
                    artifact_compaction_admission.note_task_terminal(now);
                }
                if (artifact_compaction_admission.observe(
                        admission_snapshot, false) !=
                        ArtifactCompactionAdmissionDecision::Eligible ||
                    !artifact_compaction_admission.store_probe_due(now)) {
                    return;
                }
                if (!jit_artifacts->compaction_needed()) {
                    artifact_compaction_admission.note_store_probe_miss(now);
                    return;
                }
                const auto task_id =
                    artifact_compaction_telemetry.next_task_id.fetch_add(
                        1U, std::memory_order_relaxed);
                const auto task_record =
                    std::make_shared<ArtifactCompactionTaskRecord>(
                        task_id, steady_nanoseconds());
                artifact_compaction_telemetry.admitted.fetch_add(
                    1U, std::memory_order_relaxed);
                artifact_compaction_telemetry.outstanding.fetch_add(
                    1U, std::memory_order_relaxed);
                const auto task = host_resources.submit_cancellable(
                    HostWorkKind::ArtifactCompaction, host_compile_deadline,
                    [jit_artifacts, &artifact_compaction_telemetry,
                        &observe_compaction_execution,
                        &observe_compaction_terminal, &steady_nanoseconds,
                        task_record](const HostWorkToken& token) {
                        const auto started = std::chrono::steady_clock::now();
                        const auto started_nanoseconds = steady_nanoseconds();
                        if (!task_record->mark_running(started_nanoseconds))
                            return;
                        const auto result = jit_artifacts->compact_with_result(
                            [&token] { return token.cancelled(); });
                        const auto elapsed = static_cast<std::uint64_t>(
                            std::chrono::duration_cast<
                                std::chrono::nanoseconds>(
                                std::chrono::steady_clock::now() - started)
                                .count());
                        observe_compaction_execution(elapsed);
                        const auto terminal_time = steady_nanoseconds();
                        const auto terminal =
                            result.cancelled
                                ? ArtifactCompactionTaskState::
                                      CancelledInProgress
                                : (result.completed
                                          ? ArtifactCompactionTaskState::
                                                Completed
                                          : ArtifactCompactionTaskState::
                                                Failed);
                        if (task_record->publish_terminal(
                                terminal, terminal_time)) {
                            const auto cancellation_observed =
                                result.first_cancellation_observed_nanoseconds !=
                                        0U
                                    ? result
                                          .first_cancellation_observed_nanoseconds
                                    : terminal_time;
                            observe_compaction_terminal(*task_record, terminal,
                                terminal_time, cancellation_observed,
                                result.bytes_before_cancel,
                                result.records_before_cancel,
                                result.temporary_cleanup_attempts,
                                result.temporary_cleanup_successes,
                                result.temporary_cleanup_failures,
                                result.temporary_residues,
                                result.lock_wait_nanoseconds,
                                result.snapshot_nanoseconds,
                                result.save_nanoseconds,
                                result.cleanup_nanoseconds,
                                result.rename_nanoseconds,
                                result.return_nanoseconds);
                        }
                    },
                    artifact_compaction_deadline_reserve);
                if (task) {
                    artifact_compaction_admission.note_task_admitted();
                    artifact_compaction_task = task;
                    artifact_compaction_record = task_record;
                } else {
                    artifact_compaction_telemetry.admitted.fetch_sub(
                        1U, std::memory_order_relaxed);
                    artifact_compaction_telemetry.outstanding.fetch_sub(
                        1U, std::memory_order_relaxed);
                    artifact_compaction_admission.note_submission_rejected(now);
                    artifact_compaction_telemetry.rejected.fetch_add(
                        1U, std::memory_order_relaxed);
                }
            };
            if (profile_background_warming_enabled) {
                const auto now = std::chrono::steady_clock::now();
                JitWorkObservation observation;
                observation.memory_pressure =
                    host_memory_is_pressured(latest_host_memory_budget) ||
                    jit_code_cache_governor.total_actual() >
                        jit_code_cache_governor.total_budget();
                observation.realtime_work_pending =
                    display_callback_work_active || input_preferred_thread;
                observation.display_started =
                    observed_display_submissions != 0U;
                if (now >= last_display_submission) {
                    observation.display_quiet_for =
                        now - last_display_submission;
                }
                if (guest_idle_since && now >= *guest_idle_since) {
                    observation.guest_idle_for = now - *guest_idle_since;
                }
                if (now >= last_interactive_host_activity) {
                    observation.interaction_quiet_for =
                        now - last_interactive_host_activity;
                }
                if (realtime_pacer) {
                    auto available = std::chrono::nanoseconds::max();
                    if (next_deadline) {
                        available = realtime_pacer->delay_until(*next_deadline);
                    }
                    available = realtime_pacer->limit_delay(
                        available, next_host_control_deadline());
                    if (available != std::chrono::nanoseconds::max()) {
                        observation.deadline_remaining = available;
                    }
                }
                observation.block_compile_p95_nanoseconds =
                    performance_counters().jit_block_compile_p95_nanoseconds();
                observation.block_compile_p99_nanoseconds =
                    performance_counters().jit_block_compile_p99_nanoseconds();
                schedule_jit_profile_work(
                    observation, host_compile_deadline, true);
            }
            // Artifact maintenance is independent of profile warming.
            schedule_artifact_compaction();
            if (next_deadline) {
                if (realtime_pacer) {
                    const auto guest_ahead_delay =
                        realtime_pacer->delay_until(*next_deadline);
                    if (guest_ahead_delay <= std::chrono::nanoseconds::zero()) {
                        if (!observed_guest_timer_deadline ||
                            *observed_guest_timer_deadline != *next_deadline) {
                            const auto allowed =
                                realtime_pacer->allowed_device_monotonic_time();
                            if (allowed > *next_deadline) {
                                const auto overshoot = allowed - *next_deadline;
                                ++guest_timer_overshoot_samples;
                                guest_timer_overshoot_total_nanoseconds =
                                    overshoot >
                                            std::numeric_limits<
                                                std::uint64_t>::max() -
                                                guest_timer_overshoot_total_nanoseconds
                                        ? std::numeric_limits<
                                              std::uint64_t>::max()
                                        : guest_timer_overshoot_total_nanoseconds +
                                              overshoot;
                                guest_timer_overshoot_max_nanoseconds =
                                    std::max(
                                        guest_timer_overshoot_max_nanoseconds,
                                        overshoot);
                            }
                            observed_guest_timer_deadline = *next_deadline;
                        }
                    } else {
                        observed_guest_timer_deadline.reset();
                    }
                    if (guest_ahead_delay > std::chrono::nanoseconds::zero()) {
                        const auto sleep_delay = realtime_pacer->limit_delay(
                            guest_ahead_delay, next_host_control_deadline());
                        if (sleep_delay > std::chrono::nanoseconds::zero()) {
                            wait_for_host_activity(sleep_delay);
                        }
                        // Keep guest-time advancement gated by the raw pacing
                        // result. A clipped host sleep only makes input polling
                        // responsive.
                        continue;
                    }
                    const auto current_time =
                        initial_runtime->kernel->current_absolute_time();
                    if (*next_deadline > current_time)
                        account_stability_catch_up(
                            *next_deadline - current_time);
                }
                initial_runtime->kernel->advance_absolute_time(*next_deadline);
                for (auto& runtime : runtimes) {
                    if (runtime.get() != initial_runtime &&
                        !runtime->kernel->process().exited) {
                        runtime->kernel->service_time_dependent_devices(
                            *next_deadline);
                    }
                }
                continue;
            }
            constexpr auto touch_replay_quiet_period =
                std::chrono::seconds { 2 };
            if (bounded_execution && touch_replay &&
                !touch_replay->settled(touch_replay_quiet_period)) {
                // A finite headless run must not terminate during a guest idle
                // window while host-time UI automation still has events
                // scheduled or the guest is draining the final event. Keep the
                // same low-overhead idle behavior as the unbounded interactive
                // loop.
                auto replay_deadline = touch_replay->next_deadline();
                if (!replay_deadline) {
                    replay_deadline = touch_replay->settled_deadline(
                        touch_replay_quiet_period);
                }
                if (replay_deadline) {
                    const auto now = std::chrono::steady_clock::now();
                    wait_for_host_activity(
                        *replay_deadline > now
                            ? std::chrono::duration_cast<
                                  std::chrono::nanoseconds>(
                                  *replay_deadline - now)
                            : std::chrono::nanoseconds::zero());
                }
                continue;
            }
            if (bounded_execution)
                break;
            // An interactive emulator remains alive while every guest thread
            // is blocked: wait for the next automation deadline or control
            // input. Standalone window sessions block on host events; GDB
            // and mixed control sessions retain the bounded compatibility
            // fallback.
            auto delay = std::chrono::nanoseconds::max();
            if (const auto deadline = next_host_control_deadline()) {
                const auto now = std::chrono::steady_clock::now();
                if (*deadline > now) {
                    delay =
                        std::chrono::duration_cast<std::chrono::nanoseconds>(
                            *deadline - now);
                } else {
                    delay = std::chrono::nanoseconds::zero();
                }
            } else if ((!live_control || live_control->closed()) &&
                       (display_presenter || gdb_server)) {
                delay = std::chrono::duration_cast<std::chrono::nanoseconds>(
                    host_event_poll_fallback);
            }
            if (realtime_pacer)
                delay = realtime_pacer->limit_delay(
                    delay, next_host_control_deadline());
            wait_for_host_activity(delay);
        }
    }
    output.line(
        "[display-attribution] vsync-pulses=" +
        std::to_string(initial_runtime->kernel->display_vsync_pulse_count()) +
        " content-revision=" +
        std::to_string(initial_runtime->kernel->display_content_revision()) +
        " submitted-frames=" +
        std::to_string(initial_runtime->kernel->display_submitted_frames()) +
        " stability-active=" +
        (transition_attribution.internal_stability_active.load(
             std::memory_order_relaxed)
                ? "1"
                : "0") +
        " active-transition-id=" +
        std::to_string(transition_attribution.active_transition_id) +
        " stability-observations=" +
        std::to_string(transition_attribution.stability_observation_count) +
        " stability-resets=" +
        std::to_string(transition_attribution.stability_content_reset_count) +
        " stability-baseline-vsync=" +
        std::to_string(transition_attribution.stability_baseline_vsync_pulses) +
        " stability-baseline-display-time=" +
        std::to_string(transition_attribution.stability_baseline_display_time) +
        " stability-last-vsync=" +
        std::to_string(
            transition_attribution.stability_last_observed_vsync_pulses) +
        " stability-last-content=" +
        std::to_string(
            transition_attribution.stability_last_observed_content_revision));
    diagnostics.stopped(stopped_pid, stopped_cpu, consumed_ticks, stopped_result);
    if (baseband_capture_stream) {
        baseband_capture_stream->flush();
        if (!*baseband_capture_stream) {
            throw std::runtime_error {
                "cannot flush baseband capture output: " + *baseband_output_path
            };
        }
        output.line("[baseband] capture output=" + *baseband_output_path +
                    " bytes=" + std::to_string(baseband_capture_bytes));
    }
    const auto report_performance = options.report_performance;
    if (display_presenter)
        display_presenter->flush_presentation();
    PerformanceSnapshot stopped_guest;
    FilePageCacheStats file_cache_stats;
    std::uint64_t file_page_cache_bytes { };
    // Guest and display pacing have stopped, so the last interactive deadline
    // is no longer meaningful. Let already-admitted bounded host work drain
    // instead of leaving it permanently ineligible behind a stale deadline.
    host_resources.set_next_deadline(std::nullopt);
    host_resources.wait_idle();
    catalog_maintenance.poll(*initial_runtime->kernel, true, false);
    catalog_maintenance.publish_stable(*initial_runtime->kernel);
    host_resources.wait_idle();
    if (artifact_compaction_task && artifact_compaction_record &&
        artifact_compaction_record->state() ==
            ArtifactCompactionTaskState::Queued &&
        artifact_compaction_task->cancelled()) {
        const auto terminal_time = steady_nanoseconds();
        if (artifact_compaction_record->publish_terminal(
                ArtifactCompactionTaskState::CancelledBeforeStart,
                terminal_time)) {
            observe_compaction_terminal(*artifact_compaction_record,
                ArtifactCompactionTaskState::CancelledBeforeStart,
                terminal_time, terminal_time, 0U, 0U, 0U, 0U, 0U, 0U, 0U, 0U,
                0U, 0U, 0U, 0U);
        }
    }
    artifact_compaction_task.reset();
    artifact_compaction_record.reset();
    const auto compaction_terminal_count =
        artifact_compaction_telemetry.completed.load(
            std::memory_order_relaxed) +
        artifact_compaction_telemetry.cancelled_before_start.load(
            std::memory_order_relaxed) +
        artifact_compaction_telemetry.cancelled_in_progress.load(
            std::memory_order_relaxed) +
        artifact_compaction_telemetry.failures.load(std::memory_order_relaxed);
    const auto compaction_admitted =
        artifact_compaction_telemetry.admitted.load(std::memory_order_relaxed);
    const auto compaction_outstanding =
        artifact_compaction_telemetry.outstanding.load(
            std::memory_order_relaxed);
    if (compaction_admitted != compaction_terminal_count ||
        compaction_outstanding != 0U) {
        throw std::runtime_error {
            "artifact compaction terminal accounting invariant failed"
        };
    }
    if (report_performance) {
        stopped_guest = performance_counters().snapshot();
        file_cache_stats = initial_runtime->memory->file_page_cache_stats();
        file_page_cache_bytes =
            static_cast<std::uint64_t>(
                initial_runtime->memory->cached_file_page_count()) *
            AddressSpace::page_size;
    }
    catalog_maintenance.report_watch_stats();
    output.line(
        "[host-maintenance] artifact-compaction-admitted=" +
        std::to_string(artifact_compaction_telemetry.admitted.load(
            std::memory_order_relaxed)) +
        " artifact-compaction-rejected=" +
        std::to_string(artifact_compaction_telemetry.rejected.load(
            std::memory_order_relaxed)) +
        " artifact-compaction-cancel-requests=" +
        std::to_string(artifact_compaction_telemetry.cancellation_requests.load(
            std::memory_order_relaxed)) +
        " artifact-compaction-cancelled=" +
        std::to_string(
            artifact_compaction_telemetry.cancelled_before_start.load(
                std::memory_order_relaxed) +
            artifact_compaction_telemetry.cancelled_in_progress.load(
                std::memory_order_relaxed)) +
        " artifact-compaction-cancelled-before-start=" +
        std::to_string(
            artifact_compaction_telemetry.cancelled_before_start.load(
                std::memory_order_relaxed)) +
        " artifact-compaction-cancelled-in-progress=" +
        std::to_string(artifact_compaction_telemetry.cancelled_in_progress.load(
            std::memory_order_relaxed)) +
        " artifact-compaction-completed=" +
        std::to_string(artifact_compaction_telemetry.completed.load(
            std::memory_order_relaxed)) +
        " artifact-compaction-failures=" +
        std::to_string(artifact_compaction_telemetry.failures.load(
            std::memory_order_relaxed)) +
        " artifact-compaction-outstanding=" +
        std::to_string(artifact_compaction_telemetry.outstanding.load(
            std::memory_order_relaxed)) +
        " artifact-compaction-terminal-conserved=" +
        std::to_string(compaction_admitted == compaction_terminal_count &&
                               compaction_outstanding == 0U
                           ? 1U
                           : 0U) +
        " artifact-compaction-worker-execution-count=" +
        std::to_string(
            artifact_compaction_telemetry.worker_execution_count.load(
                std::memory_order_relaxed)) +
        " artifact-compaction-worker-execution-total-ns=" +
        std::to_string(
            artifact_compaction_telemetry.worker_execution_total_nanoseconds
                .load(std::memory_order_relaxed)) +
        " artifact-compaction-worker-execution-max-ns=" +
        std::to_string(
            artifact_compaction_telemetry.worker_execution_max_nanoseconds.load(
                std::memory_order_relaxed)) +
        " artifact-compaction-lifecycle-count=" +
        std::to_string(artifact_compaction_telemetry.lifecycle_count.load(
            std::memory_order_relaxed)) +
        " artifact-compaction-lifecycle-total-ns=" +
        std::to_string(
            artifact_compaction_telemetry.lifecycle_total_nanoseconds.load(
                std::memory_order_relaxed)) +
        " artifact-compaction-lifecycle-max-ns=" +
        std::to_string(
            artifact_compaction_telemetry.lifecycle_max_nanoseconds.load(
                std::memory_order_relaxed)) +
        " artifact-compaction-lifecycle-p95-ns=" +
        std::to_string(
            timing_p95(&ArtifactCompactionTelemetry::lifecycle_samples)) +
        " artifact-compaction-cancel-observed-count=" +
        std::to_string(
            artifact_compaction_telemetry.cancellation_observed_count.load(
                std::memory_order_relaxed)) +
        " artifact-compaction-cancel-request-to-observed-ns=" +
        std::to_string(artifact_compaction_telemetry
                .cancellation_request_to_observed_nanoseconds.load(
                    std::memory_order_relaxed)) +
        " artifact-compaction-cancel-request-to-observed-max-ns=" +
        std::to_string(artifact_compaction_telemetry
                .cancellation_request_to_observed_max_nanoseconds.load(
                    std::memory_order_relaxed)) +
        " artifact-compaction-cancel-request-to-observed-p95-ns=" +
        std::to_string(timing_p95(&ArtifactCompactionTelemetry::
                cancellation_request_to_observed_samples)) +
        " artifact-compaction-bytes-before-cancel=" +
        std::to_string(artifact_compaction_telemetry.bytes_before_cancel.load(
            std::memory_order_relaxed)) +
        " artifact-compaction-records-before-cancel=" +
        std::to_string(artifact_compaction_telemetry.records_before_cancel.load(
            std::memory_order_relaxed)) +
        " artifact-compaction-temporary-cleanup-attempted=" +
        std::to_string(
            artifact_compaction_telemetry.temporary_cleanup_attempted.load(
                std::memory_order_relaxed)) +
        " artifact-compaction-temporary-cleanup-succeeded=" +
        std::to_string(
            artifact_compaction_telemetry.temporary_cleanup_succeeded.load(
                std::memory_order_relaxed)) +
        " artifact-compaction-temporary-cleanup-failed=" +
        std::to_string(
            artifact_compaction_telemetry.temporary_cleanup_failed.load(
                std::memory_order_relaxed)) +
        " artifact-compaction-temporary-residue-found=" +
        std::to_string(
            artifact_compaction_telemetry.temporary_residue_found.load(
                std::memory_order_relaxed)) +
        " artifact-compaction-lock-wait-total-ns=" +
        std::to_string(
            artifact_compaction_telemetry.lock_wait_total_nanoseconds.load(
                std::memory_order_relaxed)) +
        " artifact-compaction-lock-wait-max-ns=" +
        std::to_string(
            artifact_compaction_telemetry.lock_wait_max_nanoseconds.load(
                std::memory_order_relaxed)) +
        " artifact-compaction-lock-wait-p95-ns=" +
        std::to_string(
            timing_p95(&ArtifactCompactionTelemetry::lock_wait_samples)) +
        " artifact-compaction-snapshot-total-ns=" +
        std::to_string(
            artifact_compaction_telemetry.snapshot_total_nanoseconds.load(
                std::memory_order_relaxed)) +
        " artifact-compaction-snapshot-max-ns=" +
        std::to_string(
            artifact_compaction_telemetry.snapshot_max_nanoseconds.load(
                std::memory_order_relaxed)) +
        " artifact-compaction-snapshot-p95-ns=" +
        std::to_string(
            timing_p95(&ArtifactCompactionTelemetry::snapshot_samples)) +
        " artifact-compaction-save-total-ns=" +
        std::to_string(
            artifact_compaction_telemetry.save_total_nanoseconds.load(
                std::memory_order_relaxed)) +
        " artifact-compaction-save-max-ns=" +
        std::to_string(artifact_compaction_telemetry.save_max_nanoseconds.load(
            std::memory_order_relaxed)) +
        " artifact-compaction-save-p95-ns=" +
        std::to_string(timing_p95(&ArtifactCompactionTelemetry::save_samples)) +
        " artifact-compaction-cleanup-total-ns=" +
        std::to_string(
            artifact_compaction_telemetry.cleanup_total_nanoseconds.load(
                std::memory_order_relaxed)) +
        " artifact-compaction-cleanup-max-ns=" +
        std::to_string(
            artifact_compaction_telemetry.cleanup_max_nanoseconds.load(
                std::memory_order_relaxed)) +
        " artifact-compaction-cleanup-p95-ns=" +
        std::to_string(
            timing_p95(&ArtifactCompactionTelemetry::cleanup_samples)) +
        " artifact-compaction-rename-total-ns=" +
        std::to_string(
            artifact_compaction_telemetry.rename_total_nanoseconds.load(
                std::memory_order_relaxed)) +
        " artifact-compaction-rename-max-ns=" +
        std::to_string(
            artifact_compaction_telemetry.rename_max_nanoseconds.load(
                std::memory_order_relaxed)) +
        " artifact-compaction-rename-p95-ns=" +
        std::to_string(
            timing_p95(&ArtifactCompactionTelemetry::rename_samples)) +
        " artifact-compaction-return-total-ns=" +
        std::to_string(
            artifact_compaction_telemetry.return_total_nanoseconds.load(
                std::memory_order_relaxed)) +
        " artifact-compaction-return-max-ns=" +
        std::to_string(
            artifact_compaction_telemetry.return_max_nanoseconds.load(
                std::memory_order_relaxed)) +
        " artifact-compaction-return-p95-ns=" +
        std::to_string(
            timing_p95(&ArtifactCompactionTelemetry::return_samples)) +
        " controller-rejected=" + std::to_string(host_resources.rejected()) +
        " controller-completed=" + std::to_string(host_resources.completed()));
    output.line("[host-timing] guest-timer-overshoot-samples=" +
                std::to_string(guest_timer_overshoot_samples) +
                " guest-timer-overshoot-total-ns=" +
                std::to_string(guest_timer_overshoot_total_nanoseconds) +
                " guest-timer-overshoot-max-ns=" +
                std::to_string(guest_timer_overshoot_max_nanoseconds));
    output.line(
        "[precompile] loader=" + std::to_string(precompile_tasks_by_phase[0]) +
        "/" +
        std::to_string(
            precompile_blocks_by_phase[0].load(std::memory_order_relaxed)) +
        " system-ui=" + std::to_string(precompile_tasks_by_phase[1]) + "/" +
        std::to_string(
            precompile_blocks_by_phase[1].load(std::memory_order_relaxed)) +
        " startup-service=" + std::to_string(precompile_tasks_by_phase[2]) +
        "/" +
        std::to_string(
            precompile_blocks_by_phase[2].load(std::memory_order_relaxed)) +
        " foreground-application=" +
        std::to_string(precompile_tasks_by_phase[3]) + "/" +
        std::to_string(
            precompile_blocks_by_phase[3].load(std::memory_order_relaxed)) +
        " remaining=" + std::to_string(precompile_tasks_by_phase[4]) + "/" +
        std::to_string(
            precompile_blocks_by_phase[4].load(std::memory_order_relaxed)) +
        " native=" + std::to_string(precompile_tasks_by_target[0]) + "/" +
        std::to_string(
            precompile_blocks_by_target[0].load(std::memory_order_relaxed)) +
        " portable-ir=" + std::to_string(precompile_tasks_by_target[1]) + "/" +
        std::to_string(
            precompile_blocks_by_target[1].load(std::memory_order_relaxed)));
    output.line(
        "[precompile-outcomes] elapsed-ns=" +
        std::to_string(precompile_outcomes.elapsed_nanoseconds.load(
            std::memory_order_relaxed)) +
        " attempted=" +
        std::to_string(
            precompile_outcomes.attempted.load(std::memory_order_relaxed)) +
        " native-compiled=" +
        std::to_string(precompile_outcomes.native_compiled.load(
            std::memory_order_relaxed)) +
        " portable-generated=" +
        std::to_string(precompile_outcomes.portable_generated.load(
            std::memory_order_relaxed)) +
        " portable-artifact-hits=" +
        std::to_string(precompile_outcomes.portable_artifact_hits.load(
            std::memory_order_relaxed)) +
        " artifact-imported=" +
        std::to_string(precompile_outcomes.artifact_imported.load(
            std::memory_order_relaxed)) +
        " artifact-probe-hits=" +
        std::to_string(precompile_outcomes.artifact_probe_hits.load(
            std::memory_order_relaxed)) +
        " shared-slab-hits=" +
        std::to_string(precompile_outcomes.shared_slab_hits.load(
            std::memory_order_relaxed)) +
        " deferred=" +
        std::to_string(
            precompile_outcomes.deferred.load(std::memory_order_relaxed)) +
        " unstable=" +
        std::to_string(
            precompile_outcomes.unstable.load(std::memory_order_relaxed)) +
        " cache-full=" +
        std::to_string(
            precompile_outcomes.cache_full.load(std::memory_order_relaxed)) +
        " failed=" +
        std::to_string(
            precompile_outcomes.failed.load(std::memory_order_relaxed)) +
        " cancelled=" +
        std::to_string(
            precompile_outcomes.cancelled.load(std::memory_order_relaxed)) +
        " deadline-stops=" +
        std::to_string(precompile_outcomes.deadline_stops.load(
            std::memory_order_relaxed)));
    const auto schedule_skip = [&precompile_schedule_skips](
                                   PrecompileScheduleSkip reason) {
        return std::to_string(
            precompile_schedule_skips[static_cast<std::size_t>(reason)]);
    };
    output.line(
        "[precompile-schedule] no-runtime=" +
        schedule_skip(PrecompileScheduleSkip::NoRuntime) +
        " task-busy=" + schedule_skip(PrecompileScheduleSkip::TaskBusy) +
        " no-phase=" + schedule_skip(PrecompileScheduleSkip::NoPhase) +
        " memory-pressure=" +
        schedule_skip(PrecompileScheduleSkip::MemoryPressure) +
        " display-quiet=" +
        schedule_skip(PrecompileScheduleSkip::DisplayQuiet) +
        " guest-not-idle=" +
        schedule_skip(PrecompileScheduleSkip::GuestNotIdle) +
        " deadline-reserve=" +
        schedule_skip(PrecompileScheduleSkip::DeadlineReserve) +
        " zero-budget=" + schedule_skip(PrecompileScheduleSkip::ZeroBudget) +
        " host-rejected=" +
        schedule_skip(PrecompileScheduleSkip::HostRejected));
    catalog_maintenance.report_refresh_stats();
    if (session_catalog.available()) {
        output.line("[catalog] mapped-executable-ranges=" +
                    std::to_string(catalog_mapped_executable_ranges) +
                    " mapped-entry-hints=" +
                    std::to_string(catalog_mapped_entry_hints));
        output.line("[catalog] mapped-entry-phases=loader:" +
                    std::to_string(catalog_mapped_entry_hints_by_phase[0]) +
                    ",system-ui:" +
                    std::to_string(catalog_mapped_entry_hints_by_phase[1]) +
                    ",startup-service:" +
                    std::to_string(catalog_mapped_entry_hints_by_phase[2]) +
                    ",foreground-application:" +
                    std::to_string(catalog_mapped_entry_hints_by_phase[3]) +
                    ",remaining:" +
                    std::to_string(catalog_mapped_entry_hints_by_phase[4]));
    }
    session_catalog.save();
    if (runtime_jit_memory) {
        observe_all_runtime_jit_memory();
        concurrent_live_current_at_stop =
            runtime_jit_memory->concurrent_live_current;
    }
    // A run that ends while a guest thread is still waiting for a mach reply
    // names what it waited on. A request the kernel never answers looks, from
    // the guest, exactly like one a guest server answers slowly, and only the
    // wait itself distinguishes them.
    constexpr std::uint64_t stalled_receive_guest_nanoseconds =
        10ULL * VirtualClock::nanoseconds_per_second;
    for (auto& runtime : runtimes) {
        runtime->kernel->report_stalled_receives(
            stalled_receive_guest_nanoseconds);
    }
    for (auto& runtime : runtimes) {
        account_runtime_jit_memory(*runtime, true);
        runtime_index.erase(*runtime);
        runtime_reaper.retire(std::move(runtime));
    }
    runtimes.clear();
    runtime_reaper.finish();
    if (activation != LockdownActivation::Preserve) {
        // Native lockdownd may publish its runtime decision back into data_ark
        // during boot. Reapply the explicit simulator profile only after every
        // Guest runtime has been retired, so the requested state persists for
        // the next launch without racing a live daemon.
        const auto shutdown_activation_result =
            apply_lockdown_state(rootfs, activation, lockdown_capabilities);
        output.line(
            "[device-state] shutdown-reapply=" + activation_value +
            " path=" + shutdown_activation_result.path.string() +
            " changed=" + std::to_string(shutdown_activation_result.changed));
    }
    if (report_performance) {
        // Make the reported disk footprint include artifacts generated during
        // the run. The store still performs the same atomic save again at
        // destruction.
        static_cast<void>(jit_artifacts->save());
        if (profile_saving_enabled && translation_profiles) {
            translation_profiles->save();
        }
        const auto artifact_stats = jit_artifacts->stats();
        output.line(
            "[perf-artifact] lookup=" + std::to_string(artifact_stats.lookups) +
            " memory-hit=" + std::to_string(artifact_stats.memory_hits) +
            " disk-hit=" + std::to_string(artifact_stats.disk_hits) +
            " disk-hit-fingerprints=" +
            disk_hit_fingerprint_text(artifact_stats) +
            " lookup-memory-published=" +
            std::to_string(artifact_stats.memory_published_lookups) +
            " lookup-disk-demand=" +
            std::to_string(artifact_stats.disk_demand_lookups) +
            " lookup-disk-prefetched=" +
            std::to_string(artifact_stats.disk_prefetched_lookups) +
            " validation-successes=" +
            std::to_string(artifact_stats.validation_successes) + " staged=" +
            std::to_string(artifact_stats.staged) + " native-imported=" +
            std::to_string(artifact_stats.native_imported) +
            " already-present=" +
            std::to_string(artifact_stats.already_present) +
            " demand-native-emitted=" +
            std::to_string(artifact_stats.demand_native_emitted) +
            " demand-emit-failed=" +
            std::to_string(artifact_stats.demand_emit_failed) +
            " demand-consumed=" +
            std::to_string(artifact_stats.demand_consumed) +
            " staged-unused=" + std::to_string(artifact_stats.staged_unused) +
            " duplicate-consumptions=" +
            std::to_string(artifact_stats.duplicate_consumptions) +
            " unique-stage-attempt=" +
            std::to_string(artifact_stats.unique_stage_attempts) +
            " negative-probe-hit=" +
            std::to_string(artifact_stats.negative_probe_hits) +
            " generation-retry=" +
            std::to_string(artifact_stats.generation_retries) +
            " transient-retry=" +
            std::to_string(artifact_stats.transient_retries) +
            " probe-fingerprint-hit=" +
            std::to_string(artifact_stats.probe_fingerprint_hits) +
            " probe-fingerprint-collision=" +
            std::to_string(artifact_stats.probe_fingerprint_collisions) +
            " probe-evictions=" +
            std::to_string(artifact_stats.probe_evictions) + " probe-entries=" +
            std::to_string(artifact_stats.probe_table_entries) +
            " probe-peak-entries=" +
            std::to_string(artifact_stats.probe_table_peak_entries) +
            " disk-retry=" + std::to_string(artifact_stats.disk_read_retries) +
            " disk-wait=" + std::to_string(artifact_stats.disk_read_waits) +
            " miss=" + std::to_string(artifact_stats.misses) +
            " publish=" + std::to_string(artifact_stats.publish_calls) +
            " dedup=" + std::to_string(artifact_stats.deduplicated_publishes) +
            " disk-indexed=" +
            std::to_string(artifact_stats.disk_records_indexed) +
            " index-bytes=" + std::to_string(artifact_stats.index_bytes) +
            " hotset-candidates=" +
            std::to_string(artifact_stats.hotset_candidates) +
            " hotset-selected=" +
            std::to_string(artifact_stats.hotset_selected) +
            " hotset-skipped-byte-limit=" +
            std::to_string(artifact_stats.hotset_skipped_byte_limit) +
            " startup-prefetch=" +
            std::to_string(artifact_stats.startup_payloads_prefetched) +
            " startup-prefetch-bytes=" +
            std::to_string(artifact_stats.startup_prefetch_bytes) +
            " prefetched-useful=" +
            std::to_string(artifact_stats.prefetched_useful) +
            " prefetched-unused=" +
            std::to_string(artifact_stats.prefetched_unused) +
            " saved-translation-ns=" +
            std::to_string(artifact_stats.saved_translation_nanoseconds) +
            " load-cost-ns=" +
            std::to_string(artifact_stats.load_cost_nanoseconds) +
            " net-benefit-ns=" +
            std::to_string(artifact_stats.net_benefit_nanoseconds) +
            " demand-payload-loads=" +
            std::to_string(artifact_stats.demand_payload_disk_loads) +
            " background-prepare-requests=" +
            std::to_string(artifact_stats.background_prepare_requests) +
            " background-prepare-deduplicated=" +
            std::to_string(artifact_stats.background_prepare_deduplicated) +
            " background-prepare-rejected=" +
            std::to_string(artifact_stats.background_prepare_rejected) +
            " background-prepare-completed=" +
            std::to_string(artifact_stats.background_prepare_completed) +
            " background-prepare-failed=" +
            std::to_string(artifact_stats.background_prepare_failed) +
            " background-prepare-unused=" +
            std::to_string(artifact_stats.background_prepare_unused) +
            " background-prepare-queue=" +
            std::to_string(artifact_stats.background_prepare_queue_entries) +
            " background-prepare-queue-peak=" +
            std::to_string(
                artifact_stats.background_prepare_queue_peak_entries) +
            " background-prepared=" +
            std::to_string(artifact_stats.background_prepared_entries) +
            " background-prepared-peak=" +
            std::to_string(artifact_stats.background_prepared_peak_entries) +
            " background-ir-ns=" +
            std::to_string(
                artifact_stats.background_ir_deserialization_nanoseconds) +
            " admission-attempts=" +
            std::to_string(artifact_stats.admission_attempts) +
            " admission-rejected=" +
            std::to_string(artifact_stats.admission_rejected) +
            " admission-positive=" +
            std::to_string(artifact_stats.admission_positive) +
            " admission-low-confidence=" +
            std::to_string(artifact_stats.admission_low_confidence) +
            " admission-estimated-load-ns=" +
            std::to_string(
                artifact_stats.admission_estimated_load_nanoseconds) +
            " admission-estimated-saved-ns=" +
            std::to_string(
                artifact_stats.admission_estimated_saved_nanoseconds) +
            " demand-deserialization-ns=" +
            std::to_string(artifact_stats.demand_deserialization_nanoseconds) +
            " initialization-ns=" +
            std::to_string(artifact_stats.initialization_nanoseconds) +
            " disk-load=" + std::to_string(artifact_stats.disk_loaded_entries) +
            " evict=" + std::to_string(artifact_stats.evictions) +
            " payload-evict=" +
            std::to_string(artifact_stats.payload_evictions) + " compactions=" +
            std::to_string(artifact_stats.compactions) + " quota-evictions=" +
            std::to_string(artifact_stats.quota_evictions) +
            " boot-working-set=" +
            std::to_string(artifact_stats.boot_working_set_artifacts) +
            " writeback-enqueued=" +
            std::to_string(artifact_stats.writeback_enqueued) +
            " writeback-saved=" +
            std::to_string(artifact_stats.writeback_saved) +
            " writeback-dropped=" +
            std::to_string(artifact_stats.writeback_dropped) +
            " writeback-failures=" +
            std::to_string(artifact_stats.writeback_failures) +
            " writeback-cancellations=" +
            std::to_string(artifact_stats.writeback_cancellations) +
            " resident-bytes=" + std::to_string(artifact_stats.resident_bytes) +
            " writeback-pending-bytes=" +
            std::to_string(artifact_stats.writeback_pending_bytes) +
            " disk-bytes=" + std::to_string(artifact_stats.disk_bytes));
        const auto profile_stats = translation_profiles
                                       ? translation_profiles->stats()
                                       : JitTranslationProfileStats { };
        const auto demand_latency =
            stopped_guest.latencies[static_cast<std::size_t>(
                PerfLatencyKind::JitDemandTranslation)];
        const auto saturating_add = [](std::uint64_t left,
                                        std::uint64_t right) noexcept {
            return right > std::numeric_limits<std::uint64_t>::max() - left
                       ? std::numeric_limits<std::uint64_t>::max()
                       : left + right;
        };
        const auto profile_native_used = profile_stats.native_preimport_used;
        const auto profile_portable_used =
            profile_stats.profile_portable_artifact_consumed;
        const auto ordinary_artifact_used =
            profile_stats.ordinary_demand_artifact_consumed;
        const auto profile_avoided_demand_translations =
            saturating_add(profile_native_used, profile_portable_used);
        const auto avoided_demand_translations = saturating_add(
            profile_avoided_demand_translations, ordinary_artifact_used);
        const auto actually_used_total = avoided_demand_translations;
        const auto estimated_avoided_demand_total_ns =
            demand_latency.p50_nanoseconds != 0U &&
                    avoided_demand_translations >
                        std::numeric_limits<std::uint64_t>::max() /
                            demand_latency.p50_nanoseconds
                ? std::numeric_limits<std::uint64_t>::max()
                : avoided_demand_translations * demand_latency.p50_nanoseconds;
        output.line(
            "[perf-jit-profile] newly-recorded-descriptors=" +
            std::to_string(profile_stats.newly_recorded_descriptors) +
            " recorder-deduplicated=" +
            std::to_string(profile_stats.recorder_deduplicated) +
            " recorder-dropped-capacity=" +
            std::to_string(profile_stats.recorder_dropped_capacity) +
            " deduplicated=" + std::to_string(profile_stats.deduplicated) +
            " dropped-capacity=" +
            std::to_string(profile_stats.dropped_capacity) +
            " working-set-evicted=" +
            std::to_string(profile_stats.working_set_evicted) +
            " unstable-dropped=" +
            std::to_string(profile_stats.unstable_dropped) +
            " disk-descriptors-loaded=" +
            std::to_string(profile_stats.disk_descriptors_loaded) +
            " disk-files-loaded=" +
            std::to_string(profile_stats.disk_files_loaded) +
            " native-enqueued=" +
            std::to_string(profile_stats.profile_native_enqueued) +
            " portable-enqueued=" +
            std::to_string(profile_stats.profile_enqueued_portable) +
            " native-attempted=" +
            std::to_string(profile_stats.profile_native_attempted) +
            " native-executed=" +
            std::to_string(profile_stats.profile_native_executed) +
            " portable-attempted=" +
            std::to_string(profile_stats.profile_portable_attempted) +
            " portable-executed=" +
            std::to_string(profile_stats.profile_portable_executed) +
            " portable-generated=" +
            std::to_string(profile_stats.profile_portable_generated) +
            " portable-existence-hit=" +
            std::to_string(profile_stats.portable_existence_hits) +
            " native-preimport-attempted=" +
            std::to_string(profile_stats.native_preimport_attempted) +
            " native-preimport-imported=" +
            std::to_string(profile_stats.native_preimport_imported) +
            " native-preimport-already-present=" +
            std::to_string(profile_stats.native_preimport_already_present) +
            " native-preimport-before-first-demand=" +
            std::to_string(profile_stats.native_preimport_before_first_demand) +
            " native-preimport-used=" +
            std::to_string(profile_stats.native_preimport_used) +
            " actually-used-profile-native-preimport=" +
            std::to_string(profile_native_used) +
            " actually-used-demandprofile-portable-ir=" +
            std::to_string(profile_portable_used) +
            " actually-used-ordinary-demand-artifact=" +
            std::to_string(ordinary_artifact_used) +
            " actually-used-total=" + std::to_string(actually_used_total) +
            " first-use-distance-samples=" +
            std::to_string(
                profile_stats.native_preimport_first_use_distance_samples) +
            " first-use-distance-total=" +
            std::to_string(
                profile_stats.native_preimport_first_use_distance_total) +
            " demand-translation-p50-ns=" +
            std::to_string(demand_latency.p50_nanoseconds) +
            " avoided-demand-translations-profile-native=" +
            std::to_string(profile_native_used) +
            " avoided-demand-translations-demandprofile-portable-ir=" +
            std::to_string(profile_portable_used) +
            " avoided-demand-translations-ordinary-demand-artifact=" +
            std::to_string(ordinary_artifact_used) +
            " profile-avoided-demand-translations=" +
            std::to_string(profile_avoided_demand_translations) +
            " avoided-demand-translations-total=" +
            std::to_string(avoided_demand_translations) +
            " estimated-avoided-demand-total-ns=" +
            std::to_string(estimated_avoided_demand_total_ns) +
            " demand-artifact-staged=" +
            std::to_string(profile_stats.demand_artifact_staged) +
            " demand-artifact-consumed=" +
            std::to_string(profile_stats.demand_artifact_consumed) +
            " profile-portable-artifact-consumed=" +
            std::to_string(profile_stats.profile_portable_artifact_consumed) +
            " ordinary-demand-artifact-consumed=" +
            std::to_string(profile_stats.ordinary_demand_artifact_consumed) +
            " demand-artifact-stage-unused=" +
            std::to_string(profile_stats.demand_artifact_stage_unused) +
            " imported-before-first-run=" +
            std::to_string(profile_stats.profile_imported_before_first_run) +
            " merge-calls=" + std::to_string(profile_stats.merge_calls) +
            " merge-ns=" + std::to_string(profile_stats.merge_nanoseconds) +
            " save-calls=" + std::to_string(profile_stats.save_calls) +
            " save-ns=" + std::to_string(profile_stats.save_nanoseconds) +
            " load-ns=" + std::to_string(profile_stats.load_nanoseconds) +
            " profile-bytes=" + std::to_string(profile_stats.profile_bytes) +
            " resident-bytes-est=" +
            std::to_string(profile_stats.resident_bytes) + " save-failures=" +
            std::to_string(profile_stats.profile_save_failures));
        const auto& runtime_final_memory =
            runtime_jit_memory->final_before_retirement;
        const auto& concurrent_live_current = concurrent_live_current_at_stop;
        const auto& concurrent_live_peak =
            runtime_jit_memory->concurrent_live_peak;
        const auto& per_runtime_peak_sum_upper_bound =
            runtime_jit_memory->per_runtime_peak_sum_upper_bound;
        const auto format_queue_memory =
            [](std::string_view prefix, const JitPrecompileMemoryStats& stats) {
                return std::string { prefix } + "-profile-entries=" +
                       std::to_string(stats.profile_queue_entries) +
                       "-profile-capacity-entries=" +
                       std::to_string(stats.profile_queue_capacity_entries) +
                       "-catalog-entries=" +
                       std::to_string(stats.catalog_queue_entries) +
                       "-generic-entries=" +
                       std::to_string(stats.generic_queue_entries) +
                       "-pending-entries=" +
                       std::to_string(stats.pending_entries) +
                       "-inflight-entries=" +
                       std::to_string(stats.inflight_entries) +
                       "-deferred-entries=" +
                       std::to_string(stats.deferred_entries) +
                       "-completed-entries=" +
                       std::to_string(stats.completed_entries) +
                       "-queue-bytes-est=" +
                       std::to_string(stats.estimated_queue_entry_bytes) +
                       "-queue-bucket-bytes-est=" +
                       std::to_string(stats.queue_bucket_bytes) +
                       "-queue-node-bytes-est=" +
                       std::to_string(stats.queue_node_bytes) +
                       "-queue-block-bytes-est=" +
                       std::to_string(stats.queue_block_bytes) +
                       "-recorder-bytes=" +
                       std::to_string(stats.profile_recorder_bytes) +
                       "-native-prediction-bytes=" +
                       std::to_string(stats.native_profile_prediction_bytes) +
                       "-tracker-bytes=" +
                       std::to_string(stats.native_preimport_tracker_bytes);
            };
        for (std::size_t source_index = 0;
            source_index < jit_precompile_source_count; ++source_index) {
            const auto source = static_cast<JitPrecompileSource>(source_index);
            const auto& final_source =
                runtime_final_memory.by_source[source_index];
            const auto& current_source =
                concurrent_live_current.by_source[source_index];
            const auto& peak_source =
                concurrent_live_peak.by_source[source_index];
            const auto& upper_bound_source =
                per_runtime_peak_sum_upper_bound.by_source[source_index];
            const auto used =
                source == JitPrecompileSource::DemandProfile
                    ? std::to_string(profile_avoided_demand_translations)
                    : std::string { "unavailable" };
            output.line(
                "[perf-jit-queue-source] source=" +
                std::string { jit_precompile_source_name(source) } +
                " final-queued=" + std::to_string(final_source.queued_entries) +
                " final-pending=" +
                std::to_string(final_source.pending_entries) +
                " final-inflight=" +
                std::to_string(final_source.inflight_entries) +
                " final-deferred=" +
                std::to_string(final_source.deferred_entries) +
                " final-completed=" +
                std::to_string(final_source.completed_entries) +
                " final-bytes-est=" +
                std::to_string(final_source.estimated_queue_entry_bytes) +
                " concurrent-live-current-queued=" +
                std::to_string(current_source.queued_entries) +
                " concurrent-live-current-pending=" +
                std::to_string(current_source.pending_entries) +
                " concurrent-live-current-inflight=" +
                std::to_string(current_source.inflight_entries) +
                " concurrent-live-current-deferred=" +
                std::to_string(current_source.deferred_entries) +
                " concurrent-live-current-completed=" +
                std::to_string(current_source.completed_entries) +
                " concurrent-live-current-bytes-est=" +
                std::to_string(current_source.estimated_queue_entry_bytes) +
                " concurrent-live-peak-queued=" +
                std::to_string(peak_source.queued_entries) +
                " concurrent-live-peak-bytes-est=" +
                std::to_string(peak_source.estimated_queue_entry_bytes) +
                " per-runtime-peak-sum-upper-bound-queued=" +
                std::to_string(upper_bound_source.queued_entries) +
                " per-runtime-peak-sum-upper-bound-bytes-est=" +
                std::to_string(upper_bound_source.estimated_queue_entry_bytes) +
                " attempted=" +
                std::to_string(
                    precompile_source_outcomes[source_index].attempted.load(
                        std::memory_order_relaxed)) +
                " executed=" +
                std::to_string(saturating_add(
                    saturating_add(
                        saturating_add(precompile_source_outcomes[source_index]
                                           .native_compiled.load(
                                               std::memory_order_relaxed),
                            precompile_source_outcomes[source_index]
                                .portable_generated.load(
                                    std::memory_order_relaxed)),
                        precompile_source_outcomes[source_index]
                            .portable_artifact_hits.load(
                                std::memory_order_relaxed)),
                    saturating_add(
                        saturating_add(precompile_source_outcomes[source_index]
                                           .artifact_imported.load(
                                               std::memory_order_relaxed),
                            precompile_source_outcomes[source_index]
                                .artifact_probe_hits.load(
                                    std::memory_order_relaxed)),
                        precompile_source_outcomes[source_index]
                            .shared_slab_hits.load(
                                std::memory_order_relaxed)))) +
                " used=" + used + " cancelled=" +
                std::to_string(
                    precompile_source_outcomes[source_index].cancelled.load(
                        std::memory_order_relaxed)) +
                " deferred=" +
                std::to_string(
                    precompile_source_outcomes[source_index].deferred.load(
                        std::memory_order_relaxed)) +
                " failed=" +
                std::to_string(
                    precompile_source_outcomes[source_index].failed.load(
                        std::memory_order_relaxed)));
        }
        output.line(
            "[perf-jit-observer] mode=full-summary runtime-scan-iterations=" +
            std::to_string(runtime_jit_memory->runtime_scan_iterations) +
            " stats-samples=" +
            std::to_string(runtime_jit_memory->stats_samples) +
            " queue-lock-acquisitions-invariant=" +
            std::to_string(runtime_jit_memory->queue_lock_acquisitions) +
            " queue-container-scans-invariant=0 "
            "queue-entry-visits-invariant=0");
        output.line(
            "[perf-jit-memory] profile-object-bytes=" +
            std::to_string(profile_stats.profile_object_bytes) +
            " profile-vector-bytes=" +
            std::to_string(profile_stats.location_vector_bytes) +
            " profile-known-buckets-bytes=" +
            std::to_string(profile_stats.known_set_bucket_bytes) +
            " profile-known-nodes-est-bytes=" +
            std::to_string(profile_stats.known_set_node_bytes) +
            " profile-discarded-buckets-bytes=" +
            std::to_string(profile_stats.discarded_set_bucket_bytes) +
            " profile-discarded-nodes-est-bytes=" +
            std::to_string(profile_stats.discarded_set_node_bytes) +
            " profile-portable-ready-buckets-bytes=" +
            std::to_string(profile_stats.portable_ready_set_bucket_bytes) +
            " profile-portable-ready-nodes-est-bytes=" +
            std::to_string(profile_stats.portable_ready_set_node_bytes) +
            " catalog-bytes-est=" +
            std::to_string(session_catalog.resident_bytes_estimate()) +
            " runtime-count=" +
            std::to_string(runtime_jit_memory->runtime_count) + " " +
            format_queue_memory(
                "final-before-retirement", runtime_final_memory) +
            " " +
            format_queue_memory(
                "concurrent-live-current", concurrent_live_current) +
            " " +
            format_queue_memory("concurrent-live-peak", concurrent_live_peak) +
            " " +
            format_queue_memory("per-runtime-peak-sum-upper-bound",
                per_runtime_peak_sum_upper_bound) +
            " native-slab-used-bytes=" +
            std::to_string(stopped_guest.jit_shared_used_bytes));
        const auto& validation = artifact_stats.validation_rejections;
        output.line("[perf-artifact-validation] unavailable=" +
                    std::to_string(validation[static_cast<std::size_t>(
                        JitArtifactValidationRejection::Unavailable)]) +
                    " no-exact-artifact=" +
                    std::to_string(validation[static_cast<std::size_t>(
                        JitArtifactValidationRejection::NoExactArtifact)]) +
                    " empty-ir=" +
                    std::to_string(validation[static_cast<std::size_t>(
                        JitArtifactValidationRejection::EmptyIr)]) +
                    " dependency-mismatch=" +
                    std::to_string(validation[static_cast<std::size_t>(
                        JitArtifactValidationRejection::DependencyMismatch)]) +
                    " deserialize-failed=" +
                    std::to_string(validation[static_cast<std::size_t>(
                        JitArtifactValidationRejection::DeserializeFailed)]) +
                    " descriptor-mismatch=" +
                    std::to_string(validation[static_cast<std::size_t>(
                        JitArtifactValidationRejection::DescriptorMismatch)]) +
                    " exception=" +
                    std::to_string(validation[static_cast<std::size_t>(
                        JitArtifactValidationRejection::Exception)]));
        const auto graphics_resource_bytes =
            gles_renderer ? gles_renderer->resource_bytes() : 0U;
        std::uint64_t host_resource_total = stopped_guest.jit_code_cache_bytes;
        const auto add_host_resource = [&host_resource_total](
                                           std::uint64_t bytes) {
            host_resource_total =
                bytes > std::numeric_limits<std::uint64_t>::max() -
                            host_resource_total
                    ? std::numeric_limits<std::uint64_t>::max()
                    : host_resource_total + bytes;
        };
        add_host_resource(artifact_stats.resident_bytes);
        add_host_resource(artifact_stats.writeback_pending_bytes);
        add_host_resource(file_page_cache_bytes);
        add_host_resource(graphics_resource_bytes);
        output.line(
            "[perf-host-resources] jit-native-bytes=" +
            std::to_string(stopped_guest.jit_code_cache_bytes) +
            " artifact-resident-bytes=" +
            std::to_string(artifact_stats.resident_bytes) +
            " artifact-writeback-bytes=" +
            std::to_string(artifact_stats.writeback_pending_bytes) +
            " file-page-cache-bytes=" + std::to_string(file_page_cache_bytes) +
            " graphics-bytes=" + std::to_string(graphics_resource_bytes) +
            " total-bytes=" + std::to_string(host_resource_total));
        const auto host_memory = host.memory_snapshot();
        output.line(
            "[perf-host-memory] rss-bytes=" +
            std::to_string(host_memory.rss_bytes) +
            " rss-peak-bytes=" + std::to_string(host_memory.peak_rss_bytes) +
            " virtual-bytes=" + std::to_string(host_memory.virtual_bytes) +
            " mmap-file-bytes=" +
            std::to_string(host_memory.file_mapped_bytes));
        output.line(
            "[perf-file-cache] identity-queries=" +
            std::to_string(file_cache_stats.identity_queries) +
            " sha-computations=" +
            std::to_string(file_cache_stats.sha_computations) +
            " sha-bytes=" + std::to_string(file_cache_stats.sha_bytes) +
            " identity-hits=" + std::to_string(file_cache_stats.identity_hits) +
            " generation-invalidations=" +
            std::to_string(file_cache_stats.generation_invalidations));
        const auto snapshot_stats = immutable_snapshot_stats();
        output.line(
            "[perf-snapshots] entries=" +
            std::to_string(snapshot_stats.entries) + " bytes=" +
            std::to_string(snapshot_stats.bytes) + " runtime-hot-entries=" +
            std::to_string(snapshot_stats.runtime_hot_entries) +
            " runtime-hot-bytes=" +
            std::to_string(snapshot_stats.runtime_hot_bytes) +
            " catalog-scan-entries=" +
            std::to_string(snapshot_stats.catalog_scan_entries) +
            " catalog-scan-bytes=" +
            std::to_string(snapshot_stats.catalog_scan_bytes) +
            " budget-bytes=" + std::to_string(snapshot_stats.budget_bytes) +
            " catalog-scan-budget-bytes=" +
            std::to_string(snapshot_stats.catalog_scan_budget_bytes) +
            " hits=" + std::to_string(snapshot_stats.hits) +
            " evictions=" + std::to_string(snapshot_stats.evictions));
        const auto dyld_stats = DyldSharedCache::parse_stats();
        output.line(
            "[perf-dyld] generation-builds=" +
            std::to_string(dyld_stats.generation_builds) +
            " generation-hits=" + std::to_string(dyld_stats.generation_hits) +
            " generation-artifact-builds=" +
            std::to_string(dyld_stats.generation_artifact_builds) +
            " generation-artifact-hits=" +
            std::to_string(dyld_stats.generation_artifact_hits) +
            " file-view-builds=" + std::to_string(dyld_stats.file_view_builds) +
            " file-view-hits=" + std::to_string(dyld_stats.file_view_hits) +
            " image-builds=" + std::to_string(dyld_stats.image_builds) +
            " image-hits=" + std::to_string(dyld_stats.image_hits));
        const auto hle_stats = userland_hle_stats();
        output.line(
            "[perf-hle] generation-plan-builds=" +
            std::to_string(hle_stats.generation_plan_builds) +
            " generation-plan-hits=" +
            std::to_string(hle_stats.generation_plan_hits) +
            " generation-plan-artifact-builds=" +
            std::to_string(hle_stats.generation_plan_artifact_builds) +
            " generation-plan-artifact-hits=" +
            std::to_string(hle_stats.generation_plan_artifact_hits) +
            " image-plan-builds=" +
            std::to_string(hle_stats.image_plan_builds) +
            " image-plan-hits=" + std::to_string(hle_stats.image_plan_hits) +
            " relevant-images=" + std::to_string(hle_stats.relevant_images) +
            " expected-patches=" + std::to_string(hle_stats.expected_patches) +
            " installed-patches=" +
            std::to_string(hle_stats.installed_patches) + " batch-applies=" +
            std::to_string(hle_stats.batch_applies) + " invalidation-ranges=" +
            std::to_string(hle_stats.invalidation_ranges) +
            " batch-failures=" + std::to_string(hle_stats.batch_failures));
        const auto write_stats = address_space_write_stats();
        output.line(
            "[perf-memory-writes] batch-calls=" +
            std::to_string(write_stats.batch_calls) + " batch-operations=" +
            std::to_string(write_stats.batch_operations) +
            " batch-failures=" + std::to_string(write_stats.batch_failures) +
            " touched-pages=" + std::to_string(write_stats.touched_pages) +
            " copy-on-write-detaches=" +
            std::to_string(write_stats.copy_on_write_detaches));
        // Preserve stopped-guest live/current values, then include Runtime
        // destructor latency measured by the reaper in the final snapshot.
        auto final_snapshot = performance_counters().snapshot();
        final_snapshot.jit_live_instances = stopped_guest.jit_live_instances;
        final_snapshot.jit_code_cache_bytes =
            stopped_guest.jit_code_cache_bytes;
        final_snapshot.jit_shared_reserved_bytes =
            stopped_guest.jit_shared_reserved_bytes;
        final_snapshot.jit_shared_committed_bytes =
            stopped_guest.jit_shared_committed_bytes;
        final_snapshot.jit_shared_used_bytes =
            stopped_guest.jit_shared_used_bytes;
        final_snapshot.jit_executor_local_bytes =
            stopped_guest.jit_executor_local_bytes;
        final_snapshot.jit_executor_local_peak_bytes =
            stopped_guest.jit_executor_local_peak_bytes;
        final_snapshot.jit_cache_slots = stopped_guest.jit_cache_slots;
        output.line(format_performance_summary(final_snapshot));
    }
    if (jit_observer_only && runtime_jit_memory) {
        const auto& queue = concurrent_live_current_at_stop;
        output.line(
            "[perf-jit-observer] mode=observer-only sampling=lifecycle-final "
            "runtime-count=" +
            std::to_string(runtime_jit_memory->runtime_count) +
            " runtime-scan-iterations=" +
            std::to_string(runtime_jit_memory->runtime_scan_iterations) +
            " stats-samples=" +
            std::to_string(runtime_jit_memory->stats_samples) +
            " queue-lock-acquisitions-invariant=0 "
            "queue-container-scans-invariant=0 queue-entry-visits-invariant=0 "
            "atomic-queue-snapshot-profile-entries=" +
            std::to_string(queue.profile_queue_entries) +
            " atomic-queue-snapshot-catalog-entries=" +
            std::to_string(queue.catalog_queue_entries) +
            " atomic-queue-snapshot-generic-entries=" +
            std::to_string(queue.generic_queue_entries) +
            " atomic-queue-snapshot-pending-entries=" +
            std::to_string(queue.pending_entries) +
            " atomic-queue-snapshot-inflight-entries=" +
            std::to_string(queue.inflight_entries) +
            " atomic-queue-snapshot-deferred-entries=" +
            std::to_string(queue.deferred_entries) +
            " atomic-queue-snapshot-completed-entries=" +
            std::to_string(queue.completed_entries) +
            " atomic-queue-snapshot-bytes=" +
            std::to_string(queue.estimated_queue_entry_bytes) +
            " atomic-queue-snapshot-recorder-bytes=" +
            std::to_string(queue.profile_recorder_bytes) +
            " atomic-queue-snapshot-native-prediction-bytes=" +
            std::to_string(queue.native_profile_prediction_bytes) +
            " atomic-queue-snapshot-tracker-bytes=" +
            std::to_string(queue.native_preimport_tracker_bytes));
    }
}

} // namespace shade
