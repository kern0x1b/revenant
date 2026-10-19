// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Collect bounded emulator performance counters and diagnostic
// snapshots.

#pragma once

#include <array>
#include <atomic>
#include <chrono>
#include <cstddef>
#include <cstdint>
#include <deque>
#include <map>
#include <mutex>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <tuple>
#include <vector>

#include "foundation/block_profile.hpp"

namespace shade {

enum class PerfFallbackReason : std::uint8_t {
    None,
    VulkanUnavailable,
    InvalidTarget,
    UnsupportedPrimitive,
    InvalidVertex,
    UnsupportedBlend,
    PipelineUnavailable,
    TargetBusy,
    BackendFailure,
    Count,
};

inline constexpr auto perf_fallback_reason_count =
    static_cast<std::size_t>(PerfFallbackReason::Count);

enum class PerfCpuMapReason : std::uint8_t {
    Internal,
    HostUpload,
    GpuReadback,
    CoreSurface,
    SoftwareFallback,
    DeferredDisplayRead,
    NativePresent,
    Count,
};

inline constexpr auto perf_cpu_map_reason_count =
    static_cast<std::size_t>(PerfCpuMapReason::Count);

enum class PerfSurfaceKind : std::uint8_t {
    Unknown,
    CoreSurface,
    Scanout,
    GlesRenderTarget,
    Count,
};

inline constexpr auto perf_surface_kind_count =
    static_cast<std::size_t>(PerfSurfaceKind::Count);

// Temporary frame-hitch probe. Remove after the Vulkan submission stalls are
// localized.
enum class PerfSubmitReason : std::uint8_t {
    Other,
    MbxFlush,
    MbxFinish,
    MbxSurfaceFlush,
    Compositor,
    GlesSync,
    Presentation,
    StagingCapacity,
    CpuReadback,
    ResourceLifetime,
    BatchCapacity,
    TextureHazard,
    Count,
};

inline constexpr auto perf_submit_reason_count =
    static_cast<std::size_t>(PerfSubmitReason::Count);

// Temporary per-frame HLE work probe. Remove after the cold unlock stall is
// localized.
enum class PerfDiagnosticGraphicsHleKind : std::uint8_t {
    BlitCopy,
    BlitColor,
    QuadCopy,
    SynchronizeHostSource,
    HostCopyEncode,
    HostQuadEncode,
    Count,
};

inline constexpr auto perf_diagnostic_graphics_hle_count =
    static_cast<std::size_t>(PerfDiagnosticGraphicsHleKind::Count);

enum class PerfLatencyKind : std::uint8_t {
    InputEnqueue,
    DisplayPresent,
    DisplayMailbox,
    NativeMailbox,
    Acquire,
    QueuePresent,
    PresentReturn,
    PresentInterval,
    VsyncDueToCallback,
    VsyncCallbackToSwapEnd,
    VsyncSwapEndToGuestSubmit,
    VsyncDueToGuestSubmit,
    JitColdPath,
    JitDemandTranslation,
    JitBlockCompile,
    RuntimeDestructor,
    GlesTargetRelease,
    PosixSpawnTotal,
    PosixSpawnDecode,
    PosixSpawnFork,
    PosixSpawnCreate,
    ProcessFreshMemory,
    ProcessCloneMemory,
    ProcessCreateCpu,
    ProcessCreateKernel,
    ProcessInheritKernel,
    ProcessInheritSpawnKernel,
    ProcessConfigureRuntime,
    SpawnMemoryClear,
    SpawnImageLoad,
    SpawnResetRuntime,
    CpuRunLockWait,
    CpuRunSharedWriteSync,
    CpuRunEnsureJit,
    CpuRunInvalidation,
    CpuRunLoadState,
    CpuRunCallbacksBegin,
    CpuRunArtifactPreload,
    CpuRunExecute,
    CpuRunResult,
    CpuRunSaveState,
    CpuRunCacheAccounting,
    CpuRunTotal,
    SchedulerSelection,
    GuestExecutionBudget,
    SchedulerPreemptionCheck,
    SchedulerSliceCompletion,
    SchedulerRunnableToDispatch,
    SchedulerPreemptionRequestToReturn,
    MachMessageSendToReceive,
    Count,
};

inline constexpr auto perf_latency_kind_count =
    static_cast<std::size_t>(PerfLatencyKind::Count);

struct PerfLatencySnapshot {
    std::uint64_t samples { };
    std::uint64_t total_nanoseconds { };
    std::uint64_t p50_nanoseconds { };
    std::uint64_t p95_nanoseconds { };
    std::uint64_t p99_nanoseconds { };
    std::uint64_t maximum_nanoseconds { };
    std::uint64_t over_16_7ms { };
    std::uint64_t over_20ms { };
    std::uint64_t over_33_3ms { };
    std::uint64_t over_50ms { };
};

struct JitCacheSlotSnapshot {
    std::uint32_t process_id { };
    std::uint32_t slot { };
    std::uint64_t current_bytes { };
    std::uint64_t peak_bytes { };
};

struct HlePerformanceSnapshot {
    std::string subsystem;
    std::uint64_t calls { };
    std::uint64_t nanoseconds { };
};

// Per-guest-process CPU attribution is collected only inside an explicit
// display performance window.  Keeping this separate from the global
// histograms lets transition diagnostics distinguish application work from
// SpringBoard and system-service work without adding a production hot-path
// branch when telemetry is disabled.
struct DiagnosticProcessSnapshot {
    std::uint32_t process_id { };
    std::uint64_t cpu_runs { };
    std::uint64_t cpu_ticks { };
    std::uint64_t cpu_execute_nanoseconds { };
    std::uint64_t cpu_total_nanoseconds { };
    std::uint64_t cpu_ensure_jit_nanoseconds { };
    std::uint64_t cpu_invalidation_nanoseconds { };
    std::uint64_t cpu_artifact_preload_nanoseconds { };
    std::uint64_t svc_calls { };
    std::uint64_t host_yield_checks { };
    std::uint64_t host_yields { };
    std::uint64_t jit_demand_translations { };
    std::uint64_t jit_demand_translation_nanoseconds { };
    std::uint64_t jit_segment_recycles { };
    std::uint64_t jit_recycled_descriptors { };
    std::uint64_t jit_recycled_code_bytes { };
    std::uint64_t jit_full_generation_clears { };
    std::uint64_t jit_slab_generation_transitions { };
};

enum class PerfDiagnosticSourceKind : std::uint8_t {
    SchedulerBack,
    SchedulerFront,
    SvcBsd,
    SvcMach,
    SvcFast,
    SvcHle,
    SharedRegionPhase,
    MappedImagePhase,
};

struct DiagnosticSourceSnapshot {
    PerfDiagnosticSourceKind kind { };
    std::uint32_t process_id { };
    std::uint32_t number { };
    // Scheduler sources are keyed by concrete Guest thread, queue side, and
    // runnable generation so distinct wakeups are never merged.
    std::uint64_t runnable_generation { };
    std::uint64_t calls { };
    std::uint64_t nanoseconds { };
};

enum class PerfSchedulerPreemptionKind : std::uint8_t {
    None,
    Preempt,
    Urgent,
};

struct PerformanceSnapshot {
    std::uint64_t jit_instances { };
    std::uint64_t jit_live_instances { };
    std::uint64_t jit_live_peak_instances { };
    std::uint64_t jit_creation_nanoseconds { };
    std::uint64_t jit_code_cache_bytes { };
    std::uint64_t jit_code_cache_peak_bytes { };
    std::uint64_t jit_shared_reserved_bytes { };
    std::uint64_t jit_shared_committed_bytes { };
    std::uint64_t jit_shared_used_bytes { };
    std::uint64_t jit_executor_local_bytes { };
    std::uint64_t jit_executor_local_peak_bytes { };
    std::uint64_t jit_shared_invalidation_requests { };
    std::uint64_t jit_full_invalidation_requests { };
    std::uint64_t jit_range_invalidation_requests { };
    std::uint64_t jit_slab_generation_transitions { };
    std::uint64_t jit_shared_range_count { };
    std::uint64_t jit_shared_descriptor_count { };
    std::uint64_t jit_invalidated_descriptors { };
    std::uint64_t jit_retired_code_bytes { };
    std::uint64_t jit_segment_recycles { };
    std::uint64_t jit_recycled_descriptors { };
    std::uint64_t jit_recycled_code_bytes { };
    std::uint64_t jit_full_generation_clears { };
    std::uint64_t jit_fast_link_hits { };
    std::uint64_t jit_fast_link_misses { };
    std::uint64_t jit_stable_table_probes { };
    std::uint64_t jit_stable_table_collisions { };
    std::uint64_t jit_rsb_hits { };
    std::uint64_t jit_rsb_misses { };
    // Deprecated aliases retained for consumers of the former summary shape.
    // New code must use the separate fast-link/table/RSB fields above.
    std::uint64_t jit_stable_link_hits { };
    std::uint64_t jit_stable_link_misses { };
    std::uint64_t jit_host_yield_checks { };
    std::uint64_t jit_host_yields { };
    std::uint64_t jit_host_slice_budget_samples { };
    std::uint64_t jit_host_slice_budget_total_nanoseconds { };
    std::uint64_t jit_host_slice_budget_min_nanoseconds { };
    std::uint64_t jit_host_slice_budget_max_nanoseconds { };
    std::uint64_t jit_demand_artifact_probes { };
    std::uint64_t jit_demand_artifact_hits { };
    std::uint64_t jit_demand_artifact_misses { };
    std::uint64_t scheduler_runnable_transitions { };
    std::uint64_t scheduler_dispatches { };
    std::uint64_t scheduler_wakeups { };
    std::uint64_t scheduler_wake_pending { };
    std::uint64_t scheduler_blocks { };
    std::uint64_t scheduler_preemption_checks { };
    std::uint64_t scheduler_preemptions { };
    std::uint64_t scheduler_urgent_preemptions { };
    std::uint64_t scheduler_preemption_requests { };
    std::uint64_t scheduler_preemption_coalesced { };
    std::uint64_t scheduler_preemption_returns { };
    std::uint64_t scheduler_preemption_deferred_consumes { };
    std::uint64_t scheduler_quantum_expirations { };
    std::uint64_t translation_blocks { };
    std::uint64_t translation_blocks_shared_region { };
    std::uint64_t cpu_executions { };
    std::uint64_t cpu_ticks { };
    std::uint64_t svc_calls { };
    std::uint64_t page_misses { };
    std::uint64_t page_faults { };
    std::uint64_t draws { };
    std::uint64_t submits { };
    std::array<std::uint64_t, perf_submit_reason_count> submit_reasons { };
    std::uint64_t fence_waits { };
    std::uint64_t fence_wait_nanoseconds { };
    std::uint64_t upload_bytes { };
    std::uint64_t readback_bytes { };
    std::uint64_t host_fills { };
    std::uint64_t host_copies { };
    std::uint64_t display_submissions { };
    std::uint64_t display_first_nanoseconds { };
    std::uint64_t display_last_nanoseconds { };
    std::uint64_t display_mailbox_coalesced { };
    std::uint64_t display_vsync_queued { };
    std::uint64_t display_vsync_coalesced { };
    std::uint64_t display_vsync_budget_cuts { };
    std::uint64_t display_vsync_budget_saved_ticks { };
    std::uint64_t display_queue_depth { };
    std::uint64_t display_queue_high_watermark { };
    std::uint64_t display_queue_backpressure_waits { };
    std::uint64_t display_queue_backpressure_max_wait_nanoseconds { };
    std::uint64_t display_queue_backpressure_timeouts { };
    std::uint64_t sdl_idle_waits { };
    std::uint64_t native_present_attempts { };
    std::uint64_t native_present_mailbox_coalesced { };
    std::uint64_t native_present_skipped { };
    std::uint64_t native_present_failures { };
    std::uint64_t native_presents { };
    std::uint64_t present_first_nanoseconds { };
    std::uint64_t present_last_nanoseconds { };
    std::uint64_t cpu_present_fallbacks { };
    std::uint64_t cpu_map_reads { };
    std::uint64_t cpu_map_writes { };
    std::array<std::uint64_t, perf_cpu_map_reason_count>
        cpu_map_read_reasons { };
    std::array<std::uint64_t, perf_cpu_map_reason_count>
        cpu_map_write_reasons { };
    std::array<std::uint64_t, perf_surface_kind_count> surface_upload_bytes { };
    std::array<std::uint64_t, perf_surface_kind_count>
        surface_readback_bytes { };
    std::uint64_t forks { };
    std::uint64_t execs { };
    std::uint64_t abnormal_exits { };
    std::array<std::uint64_t, perf_fallback_reason_count> fallback_reasons { };
    std::array<PerfLatencySnapshot, perf_latency_kind_count> latencies { };
    std::vector<JitCacheSlotSnapshot> jit_cache_slots;
    std::vector<HlePerformanceSnapshot> hle_subsystems;
    std::vector<DiagnosticProcessSnapshot> diagnostic_processes;
    std::vector<DiagnosticSourceSnapshot> diagnostic_sources;
    std::uint64_t diagnostic_source_inserted { };
    std::uint64_t diagnostic_source_updated { };
    std::uint64_t diagnostic_source_evicted { };
    std::uint64_t diagnostic_source_dropped { };
    std::uint64_t diagnostic_source_capacity { };
    std::uint64_t diagnostic_source_peak_occupancy { };
};

class PerformanceCounters {
public:
    void reset(bool enabled);
    [[nodiscard]] bool begin_display_window();
    [[nodiscard]] std::optional<PerformanceSnapshot> end_display_window();
    [[nodiscard]] bool enabled() const
    {
        return enabled_.load(std::memory_order_relaxed);
    }
    void set_frame_content_diagnostics(bool enabled)
    {
        frame_content_diagnostics_enabled_.store(
            enabled, std::memory_order_release);
    }
    [[nodiscard]] bool frame_content_diagnostics_enabled() const
    {
        return frame_content_diagnostics_enabled_.load(
            std::memory_order_acquire);
    }
    [[nodiscard]] bool display_window_active() const
    {
        return display_window_active_.load(std::memory_order_acquire);
    }
    void set_cpu_source_diagnostics(bool enabled)
    {
        cpu_source_diagnostics_configured_.store(
            enabled, std::memory_order_release);
    }
    [[nodiscard]] bool cpu_source_diagnostics_configured() const
    {
        return cpu_source_diagnostics_configured_.load(
            std::memory_order_acquire);
    }
    // CPU phase timing is deliberately limited to explicit perf windows. It
    // performs several host-clock reads per guest slice and must not perturb
    // ordinary execution or the unmeasured boot path.
    [[nodiscard]] bool cpu_source_diagnostics_enabled() const
    {
        return enabled() && cpu_source_diagnostics_configured() &&
               display_window_active_.load(std::memory_order_acquire);
    }
    // Native block lookup observation is an explicit opt-in diagnostic. It
    // is intentionally independent of the display-window CPU phase switch:
    // when disabled, Dynarmic receives a null observer and the guest lookup
    // path has no host-side callback or tracker probe.
    void set_native_lookup_diagnostics(bool enabled)
    {
        native_lookup_diagnostics_configured_.store(
            enabled, std::memory_order_release);
    }
    [[nodiscard]] bool native_lookup_diagnostics_enabled() const
    {
        return enabled() && native_lookup_diagnostics_configured_.load(
                                std::memory_order_acquire);
    }

    // Ticks per translated block (`--perf-block-profile`). The profile records
    // only inside an enabled perf summary.
    void set_block_profile_diagnostics(bool enabled)
    {
        block_profile_.set_enabled(enabled);
    }
    [[nodiscard]] bool block_profile_enabled() const
    {
        return enabled() && block_profile_.enabled();
    }
    [[nodiscard]] GuestBlockProfile& block_profile()
    {
        return block_profile_;
    }

    void record_jit(std::uint64_t creation_nanoseconds = 0);
    // Background precompilation uses this always-on history to reserve time
    // for one non-preemptible Dynarmic block even when verbose perf output is
    // disabled.
    void record_jit_block_compile(std::uint64_t nanoseconds);
    [[nodiscard]] std::uint64_t jit_block_compile_p95_nanoseconds() const
    {
        return jit_block_compile_p95_nanoseconds_.load(
            std::memory_order_relaxed);
    }
    [[nodiscard]] std::uint64_t jit_block_compile_p99_nanoseconds() const
    {
        return jit_block_compile_p99_nanoseconds_.load(
            std::memory_order_relaxed);
    }
    void record_jit_destroyed();
    void record_jit_shared_slab_usage(std::uint64_t slab_id,
        std::uint64_t reserved_bytes, std::uint64_t committed_bytes,
        std::uint64_t used_bytes);
    void record_jit_shared_cache_state(std::uint64_t slab_id,
        std::uint32_t process_id,
        std::uint64_t range_count, std::uint64_t descriptor_count,
        std::uint64_t invalidated_descriptors, std::uint64_t retired_code_bytes,
        std::uint64_t segment_recycles, std::uint64_t recycled_descriptors,
        std::uint64_t recycled_code_bytes,
        std::uint64_t full_generation_clears);
    void record_jit_executor_memory_usage(std::uint64_t slab_id,
        std::uint32_t process_id, std::uint32_t slot,
        std::uint64_t current_bytes);
    void release_jit_memory_context(std::uint64_t slab_id);
    void record_jit_shared_invalidation(bool full);
    void record_jit_slab_generation_transition(std::uint32_t process_id);
    void record_jit_demand_translation(
        std::uint32_t process_id, std::uint64_t nanoseconds);
    void record_jit_dispatch(std::uint64_t fast_link_hits,
        std::uint64_t fast_link_misses, std::uint64_t stable_table_probes,
        std::uint64_t stable_table_collisions, std::uint64_t rsb_hits,
        std::uint64_t rsb_misses);
    // Compatibility overload for callers built against the former mixed
    // dispatch counter API. It does not affect the new separate counters.
    void record_jit_dispatch(std::uint64_t stable_link_hits,
        std::uint64_t stable_link_misses, std::uint64_t rsb_hits,
        std::uint64_t rsb_misses);
    void record_jit_host_yield(std::uint64_t checks, bool yielded);
    void record_jit_host_slice_budget(std::uint64_t nanoseconds);
    void record_jit_demand_artifact_probe(bool hit);
    void record_scheduler_runnable_transition();
    void record_scheduler_dispatch();
    void record_scheduler_wakeup(
        bool pending_on_running_thread, bool became_pending);
    void record_scheduler_block();
    void record_scheduler_preemption_check(PerfSchedulerPreemptionKind result);
    void record_scheduler_preemption_request();
    void record_scheduler_preemption_coalesced();
    void record_scheduler_preemption_return();
    void record_scheduler_preemption_deferred_consume();
    void record_scheduler_quantum_expiry();
    void record_translation_block();
    // Blocks first read from the dyld shared cache's address range. The cache
    // is the same read-only code at the same addresses in every process, so
    // this counts the work every process repeats for it.
    void record_translation_block_shared_region();
    void record_cpu_execution(std::uint64_t ticks);
    void record_svc();
    void record_page_miss();
    void record_page_fault();
    void record_draw();
    void record_submit(PerfSubmitReason reason = PerfSubmitReason::Other);
    void record_fence_wait(std::uint64_t nanoseconds);
    void record_upload(std::uint64_t bytes,
        PerfSurfaceKind surface = PerfSurfaceKind::Unknown);
    void record_readback(std::uint64_t bytes,
        PerfSurfaceKind surface = PerfSurfaceKind::Unknown);
    void record_host_fill();
    void record_host_copy();
    void record_display_submission(std::uint64_t frame_sequence,
        std::uint32_t owner_process_id,
        std::chrono::steady_clock::time_point submitted_at);
    // Optional software-present diagnostics used to identify the semantic
    // start and end of an animation independently from the perf-window first
    // and last submission. The previous visible frame is retained while the
    // diagnostic is enabled so the first in-window frame has a real baseline.
    void record_diagnostic_frame_content(std::uint64_t frame_sequence,
        std::uint32_t owner_process_id,
        std::chrono::steady_clock::time_point submitted_at, std::uint32_t width,
        std::uint32_t height, std::span<const std::uint32_t> pixels);
    void record_diagnostic_input(std::string_view kind, std::string_view phase,
        float x, float y, bool queued, std::uint64_t input_sequence,
        std::chrono::steady_clock::time_point enqueued_at =
            std::chrono::steady_clock::now());
    void record_diagnostic_input_guest(std::uint64_t input_sequence,
        std::uint32_t process_id, std::uint32_t thread,
        std::chrono::steady_clock::time_point entered_at =
            std::chrono::steady_clock::now());
    void record_diagnostic_input_runnable(std::uint64_t input_sequence,
        std::uint32_t process_id, std::uint32_t thread,
        std::chrono::steady_clock::time_point runnable_at =
            std::chrono::steady_clock::now());
    void record_diagnostic_input_execute(std::uint32_t process_id,
        std::uint32_t thread,
        std::chrono::steady_clock::time_point executed_at =
            std::chrono::steady_clock::now());
    // Temporary frame-hitch timeline probes. Remove these together with the
    // ordered display diagnostics once the exit/unlock stall is localized.
    void record_diagnostic_display_dequeue(std::uint64_t frame_sequence,
        std::chrono::steady_clock::time_point dequeued_at);
    void record_diagnostic_native_queue(std::uint64_t frame_sequence,
        std::chrono::steady_clock::time_point queued_at);
    void record_diagnostic_native_dequeue(std::uint64_t frame_sequence,
        std::chrono::steady_clock::time_point dequeued_at);
    void record_display_mailbox_coalesced();
    void record_display_vsync_queued();
    void record_display_vsync_coalesced();
    void record_display_vsync_budget(
        std::uint64_t original_ticks, std::uint64_t limited_ticks);
    void record_display_queue_depth(std::uint64_t depth);
    void record_display_queue_wait(std::uint64_t nanoseconds, bool timed_out);
    void record_sdl_idle_wait();
    void record_native_present_attempt();
    void record_native_present_mailbox_coalesced();
    void record_native_present_skipped();
    void record_native_present_failure();
    void record_native_present(std::uint64_t frame_sequence,
        std::chrono::steady_clock::time_point submitted_at);
    void record_cpu_present_fallback(std::uint64_t frame_sequence,
        std::chrono::steady_clock::time_point submitted_at = { });
    void record_cpu_map(bool write, PerfCpuMapReason reason);
    void record_vsync_due(std::uint32_t process_id, std::uint32_t framebuffer,
        std::uint64_t sequence);
    void record_vsync_receiver(std::uint32_t process_id,
        std::uint32_t processor_id, std::uint64_t sequence = 0);
    void record_vsync_callback(std::uint32_t process_id,
        std::uint32_t framebuffer, std::uint64_t sequence,
        std::uint32_t processor_id = 0);
    void record_vsync_swap_end(std::uint32_t process_id,
        std::uint32_t framebuffer, std::uint32_t processor_id = 0);
    void record_vsync_guest_submit(
        std::uint32_t process_id, std::uint32_t framebuffer);
    void discard_pending_vsync_callbacks();
    void record_hle(std::string_view subsystem, std::uint64_t nanoseconds);
    void record_cpu_run_phases(std::uint32_t process_id,
        std::uint32_t processor_id, std::uint32_t execution_slot,
        std::chrono::steady_clock::time_point started_at,
        std::chrono::steady_clock::time_point ended_at,
        std::span<const std::uint64_t> phase_nanoseconds,
        std::uint64_t requested_ticks, std::uint64_t consumed_ticks,
        std::uint64_t host_yield_checks, bool host_yielded,
        std::uint64_t svc_calls, std::optional<std::uint32_t> svc,
        std::uint32_t halt_reason);
    void record_diagnostic_scheduler_dispatch(std::uint32_t process_id,
        std::uint32_t thread_id, std::uint64_t runnable_generation,
        bool front_continuation, std::uint64_t nanoseconds);
    void record_diagnostic_svc_dispatch(PerfDiagnosticSourceKind kind,
        std::uint32_t process_id, std::uint32_t number,
        std::uint64_t nanoseconds);
    void record_diagnostic_graphics_hle(
        PerfDiagnosticGraphicsHleKind kind, std::uint64_t nanoseconds);
    void record_fork();
    void record_exec();
    void record_abnormal_exit();
    void record_fallback(PerfFallbackReason reason);
    void record_latency(PerfLatencyKind kind, std::uint64_t nanoseconds);

    [[nodiscard]] PerformanceSnapshot snapshot() const;

private:
    // Four linear ranges retain useful precision from sub-millisecond host
    // calls through multi-second teardown without growing with run duration:
    // 10 us to 10 ms, 100 us to 100 ms, 1 ms to 1 s, and 10 ms to 10 s.
    static constexpr std::size_t latency_bucket_count = 3701;
    struct LatencyHistogram {
        std::array<std::atomic<std::uint64_t>, latency_bucket_count>
            buckets { };
        std::atomic<std::uint64_t> samples { };
        std::atomic<std::uint64_t> total_nanoseconds { };
        std::atomic<std::uint64_t> maximum_nanoseconds { };
        std::atomic<std::uint64_t> over_16_7ms { };
        std::atomic<std::uint64_t> over_20ms { };
        std::atomic<std::uint64_t> over_33_3ms { };
        std::atomic<std::uint64_t> over_50ms { };
    };

    struct DisplayWindowLatencyHistogram {
        std::array<std::uint64_t, latency_bucket_count> buckets { };
        std::uint64_t samples { };
        std::uint64_t total_nanoseconds { };
        std::uint64_t maximum_nanoseconds { };
        std::uint64_t over_16_7ms { };
        std::uint64_t over_20ms { };
        std::uint64_t over_33_3ms { };
        std::uint64_t over_50ms { };
    };

    void reset_display_window_locked();
    void refresh_jit_shared_cache_stats_locked();
    void add_display_window_counter(
        std::uint64_t PerformanceSnapshot::* counter, std::uint64_t value = 1);
    void record_global_latency(PerfLatencyKind kind, std::uint64_t nanoseconds);
    void refresh_jit_block_compile_percentiles();
    void record_display_window_latency(
        PerfLatencyKind kind, std::uint64_t nanoseconds);
    void record_display_window_latency_locked(
        PerfLatencyKind kind, std::uint64_t nanoseconds);
    void record_present_completion(bool native, std::uint64_t frame_sequence,
        std::chrono::steady_clock::time_point submitted_at);
    void record_diagnostic_source(PerfDiagnosticSourceKind kind,
        std::uint32_t process_id, std::uint32_t number,
        std::uint64_t runnable_generation, std::uint64_t nanoseconds);

    std::atomic<bool> enabled_ { false };
    std::atomic<bool> frame_content_diagnostics_enabled_ { false };
    std::atomic<bool> cpu_source_diagnostics_configured_ { false };
    std::atomic<bool> native_lookup_diagnostics_configured_ { false };
    GuestBlockProfile block_profile_;
    std::atomic<std::uint64_t> jit_instances_ { };
    std::atomic<std::uint64_t> jit_live_instances_ { };
    std::atomic<std::uint64_t> jit_live_peak_instances_ { };
    std::atomic<std::uint64_t> jit_creation_nanoseconds_ { };
    std::atomic<std::uint64_t> jit_block_compile_p95_nanoseconds_ { };
    std::atomic<std::uint64_t> jit_block_compile_p99_nanoseconds_ { };
    std::atomic<std::uint64_t> jit_code_cache_current_bytes_ { };
    std::atomic<std::uint64_t> jit_code_cache_peak_bytes_ { };
    std::atomic<std::uint64_t> jit_shared_reserved_bytes_ { };
    std::atomic<std::uint64_t> jit_shared_committed_bytes_ { };
    std::atomic<std::uint64_t> jit_shared_used_bytes_ { };
    std::atomic<std::uint64_t> jit_executor_local_bytes_ { };
    std::atomic<std::uint64_t> jit_executor_local_peak_bytes_ { };
    std::atomic<std::uint64_t> jit_shared_invalidation_requests_ { };
    std::atomic<std::uint64_t> jit_full_invalidation_requests_ { };
    std::atomic<std::uint64_t> jit_range_invalidation_requests_ { };
    std::atomic<std::uint64_t> jit_slab_generation_transitions_ { };
    std::atomic<std::uint64_t> jit_shared_range_count_ { };
    std::atomic<std::uint64_t> jit_shared_descriptor_count_ { };
    std::atomic<std::uint64_t> jit_invalidated_descriptors_ { };
    std::atomic<std::uint64_t> jit_retired_code_bytes_ { };
    std::atomic<std::uint64_t> jit_segment_recycles_ { };
    std::atomic<std::uint64_t> jit_recycled_descriptors_ { };
    std::atomic<std::uint64_t> jit_recycled_code_bytes_ { };
    std::atomic<std::uint64_t> jit_full_generation_clears_ { };
    std::atomic<std::uint64_t> jit_fast_link_hits_ { };
    std::atomic<std::uint64_t> jit_fast_link_misses_ { };
    std::atomic<std::uint64_t> jit_stable_table_probes_ { };
    std::atomic<std::uint64_t> jit_stable_table_collisions_ { };
    std::atomic<std::uint64_t> jit_rsb_hits_ { };
    std::atomic<std::uint64_t> jit_rsb_misses_ { };
    std::atomic<std::uint64_t> jit_host_yield_checks_ { };
    std::atomic<std::uint64_t> jit_host_yields_ { };
    std::atomic<std::uint64_t> jit_host_slice_budget_samples_ { };
    std::atomic<std::uint64_t> jit_host_slice_budget_total_nanoseconds_ { };
    std::atomic<std::uint64_t> jit_host_slice_budget_min_nanoseconds_ { };
    std::atomic<std::uint64_t> jit_host_slice_budget_max_nanoseconds_ { };
    std::atomic<std::uint64_t> jit_demand_artifact_probes_ { };
    std::atomic<std::uint64_t> jit_demand_artifact_hits_ { };
    std::atomic<std::uint64_t> jit_demand_artifact_misses_ { };
    std::atomic<std::uint64_t> scheduler_runnable_transitions_ { };
    std::atomic<std::uint64_t> scheduler_dispatches_ { };
    std::atomic<std::uint64_t> scheduler_wakeups_ { };
    std::atomic<std::uint64_t> scheduler_wake_pending_ { };
    std::atomic<std::uint64_t> scheduler_blocks_ { };
    std::atomic<std::uint64_t> scheduler_preemption_checks_ { };
    std::atomic<std::uint64_t> scheduler_preemptions_ { };
    std::atomic<std::uint64_t> scheduler_urgent_preemptions_ { };
    std::atomic<std::uint64_t> scheduler_preemption_requests_ { };
    std::atomic<std::uint64_t> scheduler_preemption_coalesced_ { };
    std::atomic<std::uint64_t> scheduler_preemption_returns_ { };
    std::atomic<std::uint64_t> scheduler_preemption_deferred_consumes_ { };
    std::atomic<std::uint64_t> scheduler_quantum_expirations_ { };
    std::atomic<std::uint64_t> translation_blocks_ { };
    std::atomic<std::uint64_t> translation_blocks_shared_region_ { };
    std::atomic<std::uint64_t> cpu_executions_ { };
    std::atomic<std::uint64_t> cpu_ticks_ { };
    std::atomic<std::uint64_t> svc_calls_ { };
    std::atomic<std::uint64_t> page_misses_ { };
    std::atomic<std::uint64_t> page_faults_ { };
    std::atomic<std::uint64_t> draws_ { };
    std::atomic<std::uint64_t> submits_ { };
    std::array<std::atomic<std::uint64_t>, perf_submit_reason_count>
        submit_reasons_ { };
    std::atomic<std::uint64_t> fence_waits_ { };
    std::atomic<std::uint64_t> fence_wait_nanoseconds_ { };
    std::atomic<std::uint64_t> upload_bytes_ { };
    std::atomic<std::uint64_t> readback_bytes_ { };
    std::atomic<std::uint64_t> host_fills_ { };
    std::atomic<std::uint64_t> host_copies_ { };
    std::atomic<std::uint64_t> display_submissions_ { };
    std::atomic<std::uint64_t> display_first_nanoseconds_ { };
    std::atomic<std::uint64_t> display_last_nanoseconds_ { };
    std::atomic<std::uint64_t> display_mailbox_coalesced_ { };
    std::atomic<std::uint64_t> display_vsync_queued_ { };
    std::atomic<std::uint64_t> display_vsync_coalesced_ { };
    std::atomic<std::uint64_t> display_vsync_budget_cuts_ { };
    std::atomic<std::uint64_t> display_vsync_budget_saved_ticks_ { };
    std::atomic<std::uint64_t> display_queue_depth_ { };
    std::atomic<std::uint64_t> display_queue_high_watermark_ { };
    std::atomic<std::uint64_t> display_queue_backpressure_waits_ { };
    std::atomic<std::uint64_t>
        display_queue_backpressure_max_wait_nanoseconds_ { };
    std::atomic<std::uint64_t> display_queue_backpressure_timeouts_ { };
    std::atomic<std::uint64_t> sdl_idle_waits_ { };
    std::atomic<std::uint64_t> native_present_attempts_ { };
    std::atomic<std::uint64_t> native_present_mailbox_coalesced_ { };
    std::atomic<std::uint64_t> native_present_skipped_ { };
    std::atomic<std::uint64_t> native_present_failures_ { };
    std::atomic<std::uint64_t> native_presents_ { };
    std::atomic<std::uint64_t> present_first_nanoseconds_ { };
    std::atomic<std::uint64_t> present_last_nanoseconds_ { };
    std::atomic<std::uint64_t> cpu_present_fallbacks_ { };
    std::atomic<std::uint64_t> cpu_map_reads_ { };
    std::atomic<std::uint64_t> cpu_map_writes_ { };
    std::array<std::atomic<std::uint64_t>, perf_cpu_map_reason_count>
        cpu_map_read_reasons_ { };
    std::array<std::atomic<std::uint64_t>, perf_cpu_map_reason_count>
        cpu_map_write_reasons_ { };
    std::array<std::atomic<std::uint64_t>, perf_surface_kind_count>
        surface_upload_bytes_ { };
    std::array<std::atomic<std::uint64_t>, perf_surface_kind_count>
        surface_readback_bytes_ { };
    std::atomic<std::uint64_t> forks_ { };
    std::atomic<std::uint64_t> execs_ { };
    std::atomic<std::uint64_t> abnormal_exits_ { };
    std::array<std::atomic<std::uint64_t>, perf_fallback_reason_count>
        fallback_reasons_ { };
    std::array<LatencyHistogram, perf_latency_kind_count> latencies_ { };
    struct VsyncTimeline {
        std::uint64_t sequence { };
        std::chrono::steady_clock::time_point due;
        std::chrono::steady_clock::time_point received;
        std::chrono::steady_clock::time_point callback;
        std::chrono::steady_clock::time_point swap_end;
        std::uint32_t receiver_processor { };
        std::uint32_t callback_processor { };
        std::uint32_t swap_end_processor { };
    };
    mutable std::mutex vsync_timeline_mutex_;
    std::map<std::pair<std::uint32_t, std::uint32_t>, std::deque<VsyncTimeline>>
        vsync_timelines_;
    std::mutex present_timeline_mutex_;
    std::atomic<bool> display_window_active_ { false };
    mutable std::mutex display_window_mutex_;
    PerformanceSnapshot display_window_snapshot_;
    std::array<DisplayWindowLatencyHistogram, perf_latency_kind_count>
        display_window_latencies_ { };
    mutable std::mutex jit_cache_slots_mutex_;
    std::map<std::pair<std::uint32_t, std::uint32_t>, JitCacheSlotSnapshot>
        jit_cache_slots_;
    struct SharedSlabUsage {
        std::uint64_t reserved_bytes { };
        std::uint64_t committed_bytes { };
        std::uint64_t used_bytes { };
        std::uint64_t range_count { };
        std::uint64_t descriptor_count { };
        std::uint64_t invalidated_descriptors { };
        std::uint64_t retired_code_bytes { };
        std::uint64_t segment_recycles { };
        std::uint64_t recycled_descriptors { };
        std::uint64_t recycled_code_bytes { };
        std::uint64_t full_generation_clears { };
    };
    mutable std::mutex jit_memory_mutex_;
    std::map<std::uint64_t, SharedSlabUsage> jit_shared_slabs_;
    std::map<std::tuple<std::uint64_t, std::uint32_t, std::uint32_t>,
        std::uint64_t>
        jit_executor_memory_;
    mutable std::mutex hle_mutex_;
    std::map<std::string, HlePerformanceSnapshot, std::less<>> hle_subsystems_;
    mutable std::mutex diagnostic_process_mutex_;
    std::map<std::uint32_t, DiagnosticProcessSnapshot> diagnostic_processes_;
    using DiagnosticSourceKey = std::tuple<PerfDiagnosticSourceKind,
        std::uint32_t, std::uint32_t, std::uint64_t>;
    static constexpr std::size_t diagnostic_source_capacity = 4096;
    // Source diagnostics are explicitly opt-in, so serialize the bounded
    // table to make (thread, runnable generation) insertion atomic. The
    // normal scheduler path returns before touching this lock.
    mutable std::mutex diagnostic_source_mutex_;
    struct DiagnosticSourceCounter {
        std::atomic<std::uint64_t> key { };
        std::atomic<std::uint64_t> runnable_generation { };
        std::atomic<std::uint64_t> calls { };
        std::atomic<std::uint64_t> nanoseconds { };
        std::atomic<std::uint64_t> last_used { };
    };
    std::array<DiagnosticSourceCounter, diagnostic_source_capacity>
        diagnostic_source_counters_;
    std::uint64_t diagnostic_source_use_clock_ { };
    std::atomic<std::uint64_t> diagnostic_source_occupancy_ { };
    std::atomic<std::uint64_t> diagnostic_source_inserted_ { };
    std::atomic<std::uint64_t> diagnostic_source_updated_ { };
    std::atomic<std::uint64_t> diagnostic_source_evicted_ { };
    std::atomic<std::uint64_t> diagnostic_source_dropped_ { };
    std::atomic<std::uint64_t> diagnostic_source_peak_occupancy_ { };
    std::map<DiagnosticSourceKey, DiagnosticSourceSnapshot>
        display_window_diagnostic_source_baseline_;
    std::atomic<std::uint64_t> diagnostic_hle_calls_ { };
    std::atomic<std::uint64_t> diagnostic_hle_nanoseconds_ { };
    std::array<std::atomic<std::uint64_t>, perf_diagnostic_graphics_hle_count>
        diagnostic_graphics_hle_calls_ { };
    std::array<std::atomic<std::uint64_t>, perf_diagnostic_graphics_hle_count>
        diagnostic_graphics_hle_nanoseconds_ { };
};

[[nodiscard]] PerformanceCounters& performance_counters();

class PerformanceLatencyScope {
public:
    explicit PerformanceLatencyScope(PerfLatencyKind kind, bool enabled = true);
    PerformanceLatencyScope(const PerformanceLatencyScope&) = delete;
    PerformanceLatencyScope& operator=(const PerformanceLatencyScope&) = delete;
    ~PerformanceLatencyScope();

private:
    PerfLatencyKind kind_;
    bool enabled_ { };
    std::chrono::steady_clock::time_point started_;
};

[[nodiscard]] std::string_view perf_fallback_reason_name(
    PerfFallbackReason reason);
[[nodiscard]] std::string_view perf_cpu_map_reason_name(
    PerfCpuMapReason reason);
[[nodiscard]] std::string_view perf_surface_kind_name(PerfSurfaceKind kind);
[[nodiscard]] std::string_view perf_latency_kind_name(PerfLatencyKind kind);
[[nodiscard]] std::string format_performance_summary(
    const PerformanceSnapshot& snapshot);
[[nodiscard]] std::string format_display_performance_summary(
    const PerformanceSnapshot& snapshot, std::string_view label);

} // namespace shade
