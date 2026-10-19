// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Collect bounded emulator performance counters and diagnostic
// snapshots.

#include "foundation/performance.hpp"

#include <algorithm>
#include <cmath>
#include <cstring>
#include <iomanip>
#include <limits>
#include <sstream>

namespace shade {
namespace {

    void add_if_enabled(std::atomic<std::uint64_t>& counter,
        const std::atomic<bool>& enabled, std::uint64_t value = 1)
    {
        if (enabled.load(std::memory_order_relaxed)) {
            counter.fetch_add(value, std::memory_order_relaxed);
        }
    }

    constexpr std::uint64_t ten_milliseconds = 10'000'000;
    constexpr std::uint64_t one_sixtieth_second = 16'666'667;
    constexpr std::uint64_t twenty_milliseconds = 20'000'000;
    constexpr std::uint64_t one_thirtieth_second = 33'333'334;
    constexpr std::uint64_t fifty_milliseconds = 50'000'000;
    constexpr std::uint64_t one_hundred_milliseconds = 100'000'000;
    constexpr std::uint64_t one_second = 1'000'000'000;
    constexpr std::uint64_t ten_seconds = 10'000'000'000;
    constexpr std::size_t diagnostic_source_table_capacity = 4096;

    constexpr std::array diagnostic_sequence_kinds {
        PerfLatencyKind::DisplayMailbox,
        PerfLatencyKind::NativeMailbox,
        PerfLatencyKind::Acquire,
        PerfLatencyKind::QueuePresent,
        PerfLatencyKind::PresentReturn,
        PerfLatencyKind::PresentInterval,
        PerfLatencyKind::VsyncDueToCallback,
        PerfLatencyKind::VsyncCallbackToSwapEnd,
        PerfLatencyKind::VsyncSwapEndToGuestSubmit,
        PerfLatencyKind::VsyncDueToGuestSubmit,
        PerfLatencyKind::MachMessageSendToReceive,
    };
    std::array<std::vector<std::uint64_t>, diagnostic_sequence_kinds.size()>
        diagnostic_display_sequences;
    constexpr std::size_t maximum_diagnostic_sequence_samples = 512;

    struct DiagnosticFrameWork {
        std::uint64_t translation_blocks { };
        std::uint64_t cpu_executions { };
        std::uint64_t cpu_ticks { };
        std::uint64_t svc_calls { };
        std::uint64_t page_misses { };
        std::uint64_t page_faults { };
        std::uint64_t draws { };
        std::uint64_t submits { };
        std::uint64_t fence_waits { };
        std::uint64_t fence_wait_nanoseconds { };
        std::array<std::uint64_t, perf_submit_reason_count> submit_reasons { };
        std::uint64_t hle_calls { };
        std::uint64_t hle_nanoseconds { };
        std::array<std::uint64_t, perf_diagnostic_graphics_hle_count>
            graphics_hle_calls { };
        std::array<std::uint64_t, perf_diagnostic_graphics_hle_count>
            graphics_hle_nanoseconds { };
    };

    struct DiagnosticDisplayFrame {
        std::uint64_t sequence { };
        std::uint32_t owner_process_id { };
        std::uint64_t vsync_sequence { };
        std::uint32_t framebuffer { };
        std::chrono::steady_clock::time_point submitted;
        std::chrono::steady_clock::time_point display_dequeued;
        std::chrono::steady_clock::time_point native_queued;
        std::chrono::steady_clock::time_point native_dequeued;
        std::chrono::steady_clock::time_point present_returned;
        char present_kind { '-' };
    };

    struct DiagnosticVsyncFrame {
        std::uint64_t sequence { };
        std::uint32_t process_id { };
        std::uint32_t framebuffer { };
        std::uint64_t display_sequence { };
        std::chrono::steady_clock::time_point due;
        std::chrono::steady_clock::time_point received;
        std::chrono::steady_clock::time_point callback;
        std::chrono::steady_clock::time_point swap_end;
        std::chrono::steady_clock::time_point guest_submit;
        std::uint32_t receiver_processor { };
        std::uint32_t callback_processor { };
        std::uint32_t swap_end_processor { };
        DiagnosticFrameWork work;
    };

    constexpr auto diagnostic_cpu_run_phase_kinds = std::array {
        PerfLatencyKind::CpuRunLockWait,
        PerfLatencyKind::CpuRunSharedWriteSync,
        PerfLatencyKind::CpuRunEnsureJit,
        PerfLatencyKind::CpuRunInvalidation,
        PerfLatencyKind::CpuRunLoadState,
        PerfLatencyKind::CpuRunCallbacksBegin,
        PerfLatencyKind::CpuRunArtifactPreload,
        PerfLatencyKind::CpuRunExecute,
        PerfLatencyKind::CpuRunResult,
        PerfLatencyKind::CpuRunSaveState,
        PerfLatencyKind::CpuRunCacheAccounting,
        PerfLatencyKind::CpuRunTotal,
    };

    constexpr auto diagnostic_cpu_run_phase_count =
        diagnostic_cpu_run_phase_kinds.size();
    constexpr std::uint64_t minimum_diagnostic_cpu_run_nanoseconds = 8'000'000;

    struct DiagnosticCpuRun {
        std::uint32_t process_id { };
        std::uint32_t processor_id { };
        std::uint32_t execution_slot { };
        std::chrono::steady_clock::time_point started;
        std::chrono::steady_clock::time_point ended;
        std::array<std::uint64_t, diagnostic_cpu_run_phase_count>
            phase_nanoseconds { };
        std::uint64_t requested_ticks { };
        std::uint64_t consumed_ticks { };
        std::uint64_t host_yield_checks { };
        bool host_yielded { };
        std::uint64_t svc_calls { };
        std::optional<std::uint32_t> svc;
        std::uint32_t halt_reason { };
    };

    struct DiagnosticContentFrame {
        std::uint64_t sequence { };
        std::uint32_t owner_process_id { };
        std::chrono::steady_clock::time_point submitted;
        bool comparable { };
        std::uint64_t changed_pixels { };
        std::uint64_t absolute_rgb_delta { };
        std::uint64_t hash { };
    };

    struct DiagnosticInputEvent {
        std::string kind;
        std::string phase;
        float x { };
        float y { };
        bool queued { };
        std::uint64_t sequence { };
        std::uint32_t process_id { };
        std::uint32_t thread { };
        std::chrono::steady_clock::time_point enqueued;
        std::chrono::steady_clock::time_point guest_entered;
        std::chrono::steady_clock::time_point runnable;
        std::chrono::steady_clock::time_point executed;
    };

    std::chrono::steady_clock::time_point diagnostic_window_started_at;
    std::vector<DiagnosticDisplayFrame> diagnostic_display_frames;
    std::vector<DiagnosticVsyncFrame> diagnostic_vsync_frames;
    std::vector<DiagnosticCpuRun> diagnostic_cpu_runs;
    std::vector<DiagnosticContentFrame> diagnostic_content_frames;
    std::vector<DiagnosticInputEvent> diagnostic_input_events;
    std::vector<std::uint32_t> diagnostic_previous_content_pixels;
    std::uint32_t diagnostic_previous_content_width { };
    std::uint32_t diagnostic_previous_content_height { };
    std::uint64_t diagnostic_previous_content_hash { };
    bool diagnostic_previous_content_hash_valid { };
    DiagnosticFrameWork diagnostic_previous_frame_work;
    PerformanceSnapshot diagnostic_work_baseline;
    std::map<std::string, HlePerformanceSnapshot, std::less<>>
        diagnostic_hle_baseline;

    std::uint64_t diagnostic_content_hash(std::span<const std::uint32_t> pixels)
    {
        std::uint64_t hash { 14695981039346656037ULL };
        for (const auto pixel : pixels) {
            hash ^= pixel;
            hash *= 1099511628211ULL;
        }
        return hash;
    }

    std::optional<std::size_t> diagnostic_sequence_index(PerfLatencyKind kind)
    {
        const auto found = std::find(diagnostic_sequence_kinds.begin(),
            diagnostic_sequence_kinds.end(), kind);
        if (found == diagnostic_sequence_kinds.end())
            return std::nullopt;
        return static_cast<std::size_t>(
            std::distance(diagnostic_sequence_kinds.begin(), found));
    }

    std::uint64_t diagnostic_delta(
        std::uint64_t current, std::uint64_t baseline)
    {
        return current >= baseline ? current - baseline : 0;
    }

    DiagnosticFrameWork diagnostic_work_delta(
        const DiagnosticFrameWork& current, const DiagnosticFrameWork& previous)
    {
        auto result = DiagnosticFrameWork {
            diagnostic_delta(
                current.translation_blocks, previous.translation_blocks),
            diagnostic_delta(current.cpu_executions, previous.cpu_executions),
            diagnostic_delta(current.cpu_ticks, previous.cpu_ticks),
            diagnostic_delta(current.svc_calls, previous.svc_calls),
            diagnostic_delta(current.page_misses, previous.page_misses),
            diagnostic_delta(current.page_faults, previous.page_faults),
            diagnostic_delta(current.draws, previous.draws),
            diagnostic_delta(current.submits, previous.submits),
            diagnostic_delta(current.fence_waits, previous.fence_waits),
            diagnostic_delta(current.fence_wait_nanoseconds,
                previous.fence_wait_nanoseconds),
            { },
            diagnostic_delta(current.hle_calls, previous.hle_calls),
            diagnostic_delta(current.hle_nanoseconds, previous.hle_nanoseconds),
        };
        for (std::size_t index = 0; index < result.submit_reasons.size();
            ++index) {
            result.submit_reasons[index] = diagnostic_delta(
                current.submit_reasons[index], previous.submit_reasons[index]);
        }
        for (std::size_t index = 0; index < result.graphics_hle_calls.size();
            ++index) {
            result.graphics_hle_calls[index] =
                diagnostic_delta(current.graphics_hle_calls[index],
                    previous.graphics_hle_calls[index]);
            result.graphics_hle_nanoseconds[index] =
                diagnostic_delta(current.graphics_hle_nanoseconds[index],
                    previous.graphics_hle_nanoseconds[index]);
        }
        return result;
    }

    DiagnosticDisplayFrame* diagnostic_display_frame(std::uint64_t sequence)
    {
        const auto found = std::find_if(diagnostic_display_frames.rbegin(),
            diagnostic_display_frames.rend(), [sequence](const auto& frame) {
                return frame.sequence == sequence;
            });
        return found == diagnostic_display_frames.rend() ? nullptr : &*found;
    }

    void append_diagnostic_timestamp(std::ostringstream& text,
        std::chrono::steady_clock::time_point timestamp)
    {
        if (timestamp == std::chrono::steady_clock::time_point { } ||
            diagnostic_window_started_at ==
                std::chrono::steady_clock::time_point { }) {
            text << '-';
            return;
        }
        text << std::chrono::duration_cast<std::chrono::microseconds>(
            timestamp - diagnostic_window_started_at)
                    .count();
    }

    std::size_t latency_bucket(std::uint64_t nanoseconds)
    {
        if (nanoseconds < ten_milliseconds)
            return static_cast<std::size_t>(nanoseconds / 10'000);
        if (nanoseconds < one_hundred_milliseconds) {
            return 1000U + static_cast<std::size_t>(
                               (nanoseconds - ten_milliseconds) / 100'000);
        }
        if (nanoseconds < one_second) {
            return 1900U +
                   static_cast<std::size_t>(
                       (nanoseconds - one_hundred_milliseconds) / 1'000'000);
        }
        if (nanoseconds < ten_seconds) {
            return 2800U + static_cast<std::size_t>(
                               (nanoseconds - one_second) / 10'000'000);
        }
        return 3700U;
    }

    std::uint64_t latency_bucket_upper_bound(
        std::size_t bucket, std::uint64_t maximum)
    {
        if (bucket < 1000U)
            return (bucket + 1U) * 10'000U;
        if (bucket < 1900U)
            return ten_milliseconds + (bucket - 999U) * 100'000U;
        if (bucket < 2800U) {
            return one_hundred_milliseconds + (bucket - 1899U) * 1'000'000U;
        }
        if (bucket < 3700U)
            return one_second + (bucket - 2799U) * 10'000'000U;
        return maximum;
    }

    std::uint64_t steady_nanoseconds(
        std::chrono::steady_clock::time_point timestamp)
    {
        if (timestamp == std::chrono::steady_clock::time_point { })
            return 0;
        return static_cast<std::uint64_t>(
            std::chrono::duration_cast<std::chrono::nanoseconds>(
                timestamp.time_since_epoch())
                .count());
    }

    void record_timestamp_span(std::atomic<std::uint64_t>& samples,
        std::atomic<std::uint64_t>& first, std::atomic<std::uint64_t>& last,
        std::uint64_t timestamp)
    {
        samples.fetch_add(1, std::memory_order_relaxed);
        auto unset = std::uint64_t { };
        static_cast<void>(first.compare_exchange_strong(unset, timestamp,
            std::memory_order_relaxed, std::memory_order_relaxed));
        last.store(timestamp, std::memory_order_relaxed);
    }

    double frames_per_second(
        std::uint64_t frames, std::uint64_t first, std::uint64_t last)
    {
        if (frames < 2 || last <= first)
            return 0.0;
        return static_cast<double>(frames - 1U) * 1'000'000'000.0 /
               static_cast<double>(last - first);
    }

    std::string diagnostic_source_name(const DiagnosticSourceSnapshot& source)
    {
        std::string name;
        switch (source.kind) {
        case PerfDiagnosticSourceKind::SchedulerBack:
            name = "scheduler-pid-" + std::to_string(source.process_id) +
                   "-thread-" + std::to_string(source.number) + "-back-gen-" +
                   std::to_string(source.runnable_generation);
            break;
        case PerfDiagnosticSourceKind::SchedulerFront:
            name = "scheduler-pid-" + std::to_string(source.process_id) +
                   "-thread-" + std::to_string(source.number) + "-front-gen-" +
                   std::to_string(source.runnable_generation);
            break;
        case PerfDiagnosticSourceKind::SvcBsd:
            name = "svc-pid-" + std::to_string(source.process_id) + "-bsd-" +
                   std::to_string(source.number);
            break;
        case PerfDiagnosticSourceKind::SvcMach:
            name = "svc-pid-" + std::to_string(source.process_id) + "-mach-" +
                   std::to_string(source.number);
            break;
        case PerfDiagnosticSourceKind::SvcFast:
            name = "svc-pid-" + std::to_string(source.process_id) + "-fast-" +
                   std::to_string(source.number);
            break;
        case PerfDiagnosticSourceKind::SvcHle:
            name = "svc-pid-" + std::to_string(source.process_id) + "-hle-" +
                   std::to_string(source.number);
            break;
        case PerfDiagnosticSourceKind::SharedRegionPhase: {
            constexpr std::array<std::string_view, 9> phase_names { "unknown",
                "preflight", "cache-probe", "cache-parse", "read-mappings",
                "choose-slide", "resolve-source", "map", "install-image" };
            const auto phase = source.number < phase_names.size()
                                   ? phase_names[source.number]
                                   : phase_names.front();
            name = "shared-region-pid-" + std::to_string(source.process_id) +
                   "-" + std::string { phase };
            break;
        }
        case PerfDiagnosticSourceKind::MappedImagePhase: {
            constexpr std::array<std::string_view, 4> phase_names { "unknown",
                "hle-install", "catalog-hints", "profile-detect" };
            const auto phase = source.number < phase_names.size()
                                   ? phase_names[source.number]
                                   : phase_names.front();
            name = "mapped-image-pid-" + std::to_string(source.process_id) +
                   "-" + std::string { phase };
            break;
        }
        }
        return name;
    }

    std::uint64_t diagnostic_source_key(PerfDiagnosticSourceKind kind,
        std::uint32_t process_id, std::uint32_t number)
    {
        constexpr std::uint32_t maximum_process_id = 0x0fffffffU;
        if (process_id > maximum_process_id)
            return 0;
        return (static_cast<std::uint64_t>(kind) + 1U) << 60U |
               static_cast<std::uint64_t>(process_id) << 32U | number;
    }

    std::size_t diagnostic_source_index(
        std::uint64_t key, std::uint64_t runnable_generation)
    {
        const auto generation_hash =
            runnable_generation * 0x9e3779b97f4a7c15ULL;
        return static_cast<std::size_t>((key ^ (key >> 32U) ^ generation_hash) *
                                        0x9e3779b97f4a7c15ULL) &
               (diagnostic_source_table_capacity - 1U);
    }

    DiagnosticSourceSnapshot diagnostic_source_snapshot(std::uint64_t key,
        std::uint64_t runnable_generation, std::uint64_t calls,
        std::uint64_t nanoseconds)
    {
        return DiagnosticSourceSnapshot { static_cast<PerfDiagnosticSourceKind>(
                                              (key >> 60U) - 1U),
            static_cast<std::uint32_t>((key >> 32U) & 0x0fffffffU),
            static_cast<std::uint32_t>(key), runnable_generation, calls,
            nanoseconds };
    }

    std::tuple<PerfDiagnosticSourceKind, std::uint32_t, std::uint32_t,
        std::uint64_t>
    diagnostic_source_tuple(const DiagnosticSourceSnapshot& source)
    {
        return { source.kind, source.process_id, source.number,
            source.runnable_generation };
    }

    bool is_display_window_latency(PerfLatencyKind kind)
    {
        switch (kind) {
        case PerfLatencyKind::DisplayMailbox:
        case PerfLatencyKind::NativeMailbox:
        case PerfLatencyKind::Acquire:
        case PerfLatencyKind::QueuePresent:
        case PerfLatencyKind::PresentReturn:
        case PerfLatencyKind::PresentInterval:
        case PerfLatencyKind::VsyncDueToCallback:
        case PerfLatencyKind::VsyncCallbackToSwapEnd:
        case PerfLatencyKind::VsyncSwapEndToGuestSubmit:
        case PerfLatencyKind::VsyncDueToGuestSubmit:
        case PerfLatencyKind::CpuRunLockWait:
        case PerfLatencyKind::CpuRunSharedWriteSync:
        case PerfLatencyKind::CpuRunEnsureJit:
        case PerfLatencyKind::CpuRunInvalidation:
        case PerfLatencyKind::CpuRunLoadState:
        case PerfLatencyKind::CpuRunCallbacksBegin:
        case PerfLatencyKind::CpuRunArtifactPreload:
        case PerfLatencyKind::CpuRunExecute:
        case PerfLatencyKind::CpuRunResult:
        case PerfLatencyKind::CpuRunSaveState:
        case PerfLatencyKind::CpuRunCacheAccounting:
        case PerfLatencyKind::CpuRunTotal:
        case PerfLatencyKind::SchedulerSelection:
        case PerfLatencyKind::GuestExecutionBudget:
        case PerfLatencyKind::SchedulerPreemptionCheck:
        case PerfLatencyKind::SchedulerSliceCompletion:
        case PerfLatencyKind::SchedulerRunnableToDispatch:
        case PerfLatencyKind::SchedulerPreemptionRequestToReturn:
        case PerfLatencyKind::MachMessageSendToReceive:
        case PerfLatencyKind::PosixSpawnTotal:
        case PerfLatencyKind::PosixSpawnDecode:
        case PerfLatencyKind::PosixSpawnFork:
        case PerfLatencyKind::PosixSpawnCreate:
        case PerfLatencyKind::ProcessFreshMemory:
        case PerfLatencyKind::ProcessCloneMemory:
        case PerfLatencyKind::ProcessCreateCpu:
        case PerfLatencyKind::ProcessCreateKernel:
        case PerfLatencyKind::ProcessInheritKernel:
        case PerfLatencyKind::ProcessInheritSpawnKernel:
        case PerfLatencyKind::ProcessConfigureRuntime:
        case PerfLatencyKind::SpawnMemoryClear:
        case PerfLatencyKind::SpawnImageLoad:
        case PerfLatencyKind::SpawnResetRuntime:
            return true;
        case PerfLatencyKind::InputEnqueue:
        case PerfLatencyKind::DisplayPresent:
        case PerfLatencyKind::JitColdPath:
        case PerfLatencyKind::JitDemandTranslation:
        case PerfLatencyKind::JitBlockCompile:
        case PerfLatencyKind::RuntimeDestructor:
        case PerfLatencyKind::GlesTargetRelease:
        case PerfLatencyKind::Count:
            return false;
        }
        return false;
    }

}

void PerformanceCounters::reset(bool enabled)
{
    enabled_.store(false, std::memory_order_relaxed);
    display_window_active_.store(false, std::memory_order_release);
    frame_content_diagnostics_enabled_.store(false, std::memory_order_release);
    cpu_source_diagnostics_configured_.store(false, std::memory_order_release);
    block_profile_.set_enabled(false);
    block_profile_.clear();
    native_lookup_diagnostics_configured_.store(
        false, std::memory_order_release);
    jit_instances_.store(0, std::memory_order_relaxed);
    jit_live_instances_.store(0, std::memory_order_relaxed);
    jit_live_peak_instances_.store(0, std::memory_order_relaxed);
    jit_creation_nanoseconds_.store(0, std::memory_order_relaxed);
    jit_block_compile_p95_nanoseconds_.store(0, std::memory_order_relaxed);
    jit_block_compile_p99_nanoseconds_.store(0, std::memory_order_relaxed);
    jit_code_cache_current_bytes_.store(0, std::memory_order_relaxed);
    jit_code_cache_peak_bytes_.store(0, std::memory_order_relaxed);
    jit_shared_reserved_bytes_.store(0, std::memory_order_relaxed);
    jit_shared_committed_bytes_.store(0, std::memory_order_relaxed);
    jit_shared_used_bytes_.store(0, std::memory_order_relaxed);
    jit_executor_local_bytes_.store(0, std::memory_order_relaxed);
    jit_executor_local_peak_bytes_.store(0, std::memory_order_relaxed);
    jit_shared_invalidation_requests_.store(0, std::memory_order_relaxed);
    jit_full_invalidation_requests_.store(0, std::memory_order_relaxed);
    jit_range_invalidation_requests_.store(0, std::memory_order_relaxed);
    jit_slab_generation_transitions_.store(0, std::memory_order_relaxed);
    jit_shared_range_count_.store(0, std::memory_order_relaxed);
    jit_shared_descriptor_count_.store(0, std::memory_order_relaxed);
    jit_invalidated_descriptors_.store(0, std::memory_order_relaxed);
    jit_retired_code_bytes_.store(0, std::memory_order_relaxed);
    jit_segment_recycles_.store(0, std::memory_order_relaxed);
    jit_recycled_descriptors_.store(0, std::memory_order_relaxed);
    jit_recycled_code_bytes_.store(0, std::memory_order_relaxed);
    jit_full_generation_clears_.store(0, std::memory_order_relaxed);
    jit_fast_link_hits_.store(0, std::memory_order_relaxed);
    jit_fast_link_misses_.store(0, std::memory_order_relaxed);
    jit_stable_table_probes_.store(0, std::memory_order_relaxed);
    jit_stable_table_collisions_.store(0, std::memory_order_relaxed);
    jit_rsb_hits_.store(0, std::memory_order_relaxed);
    jit_rsb_misses_.store(0, std::memory_order_relaxed);
    jit_host_yield_checks_.store(0, std::memory_order_relaxed);
    jit_host_yields_.store(0, std::memory_order_relaxed);
    jit_host_slice_budget_samples_.store(0, std::memory_order_relaxed);
    jit_host_slice_budget_total_nanoseconds_.store(
        0, std::memory_order_relaxed);
    jit_host_slice_budget_min_nanoseconds_.store(0, std::memory_order_relaxed);
    jit_host_slice_budget_max_nanoseconds_.store(0, std::memory_order_relaxed);
    jit_demand_artifact_probes_.store(0, std::memory_order_relaxed);
    jit_demand_artifact_hits_.store(0, std::memory_order_relaxed);
    jit_demand_artifact_misses_.store(0, std::memory_order_relaxed);
    scheduler_runnable_transitions_.store(0, std::memory_order_relaxed);
    scheduler_dispatches_.store(0, std::memory_order_relaxed);
    scheduler_wakeups_.store(0, std::memory_order_relaxed);
    scheduler_wake_pending_.store(0, std::memory_order_relaxed);
    scheduler_blocks_.store(0, std::memory_order_relaxed);
    scheduler_preemption_checks_.store(0, std::memory_order_relaxed);
    scheduler_preemptions_.store(0, std::memory_order_relaxed);
    scheduler_urgent_preemptions_.store(0, std::memory_order_relaxed);
    scheduler_preemption_requests_.store(0, std::memory_order_relaxed);
    scheduler_preemption_coalesced_.store(0, std::memory_order_relaxed);
    scheduler_preemption_returns_.store(0, std::memory_order_relaxed);
    scheduler_preemption_deferred_consumes_.store(0, std::memory_order_relaxed);
    scheduler_quantum_expirations_.store(0, std::memory_order_relaxed);
    translation_blocks_.store(0, std::memory_order_relaxed);
    translation_blocks_shared_region_.store(0, std::memory_order_relaxed);
    cpu_executions_.store(0, std::memory_order_relaxed);
    cpu_ticks_.store(0, std::memory_order_relaxed);
    svc_calls_.store(0, std::memory_order_relaxed);
    page_misses_.store(0, std::memory_order_relaxed);
    page_faults_.store(0, std::memory_order_relaxed);
    draws_.store(0, std::memory_order_relaxed);
    submits_.store(0, std::memory_order_relaxed);
    for (auto& counter : submit_reasons_)
        counter.store(0, std::memory_order_relaxed);
    fence_waits_.store(0, std::memory_order_relaxed);
    fence_wait_nanoseconds_.store(0, std::memory_order_relaxed);
    upload_bytes_.store(0, std::memory_order_relaxed);
    readback_bytes_.store(0, std::memory_order_relaxed);
    host_fills_.store(0, std::memory_order_relaxed);
    host_copies_.store(0, std::memory_order_relaxed);
    display_submissions_.store(0, std::memory_order_relaxed);
    display_first_nanoseconds_.store(0, std::memory_order_relaxed);
    display_last_nanoseconds_.store(0, std::memory_order_relaxed);
    display_mailbox_coalesced_.store(0, std::memory_order_relaxed);
    display_vsync_queued_.store(0, std::memory_order_relaxed);
    display_vsync_coalesced_.store(0, std::memory_order_relaxed);
    display_vsync_budget_cuts_.store(0, std::memory_order_relaxed);
    display_vsync_budget_saved_ticks_.store(0, std::memory_order_relaxed);
    display_queue_depth_.store(0, std::memory_order_relaxed);
    display_queue_high_watermark_.store(0, std::memory_order_relaxed);
    display_queue_backpressure_waits_.store(0, std::memory_order_relaxed);
    display_queue_backpressure_max_wait_nanoseconds_.store(
        0, std::memory_order_relaxed);
    display_queue_backpressure_timeouts_.store(0, std::memory_order_relaxed);
    sdl_idle_waits_.store(0, std::memory_order_relaxed);
    native_present_attempts_.store(0, std::memory_order_relaxed);
    native_present_mailbox_coalesced_.store(0, std::memory_order_relaxed);
    native_present_skipped_.store(0, std::memory_order_relaxed);
    native_present_failures_.store(0, std::memory_order_relaxed);
    native_presents_.store(0, std::memory_order_relaxed);
    present_first_nanoseconds_.store(0, std::memory_order_relaxed);
    present_last_nanoseconds_.store(0, std::memory_order_relaxed);
    cpu_present_fallbacks_.store(0, std::memory_order_relaxed);
    cpu_map_reads_.store(0, std::memory_order_relaxed);
    cpu_map_writes_.store(0, std::memory_order_relaxed);
    forks_.store(0, std::memory_order_relaxed);
    execs_.store(0, std::memory_order_relaxed);
    abnormal_exits_.store(0, std::memory_order_relaxed);
    for (auto& counter : cpu_map_read_reasons_)
        counter.store(0, std::memory_order_relaxed);
    for (auto& counter : cpu_map_write_reasons_)
        counter.store(0, std::memory_order_relaxed);
    for (auto& counter : surface_upload_bytes_)
        counter.store(0, std::memory_order_relaxed);
    for (auto& counter : surface_readback_bytes_)
        counter.store(0, std::memory_order_relaxed);
    for (auto& counter : fallback_reasons_)
        counter.store(0, std::memory_order_relaxed);
    for (auto& histogram : latencies_) {
        for (auto& bucket : histogram.buckets)
            bucket.store(0, std::memory_order_relaxed);
        histogram.samples.store(0, std::memory_order_relaxed);
        histogram.total_nanoseconds.store(0, std::memory_order_relaxed);
        histogram.maximum_nanoseconds.store(0, std::memory_order_relaxed);
        histogram.over_16_7ms.store(0, std::memory_order_relaxed);
        histogram.over_20ms.store(0, std::memory_order_relaxed);
        histogram.over_33_3ms.store(0, std::memory_order_relaxed);
        histogram.over_50ms.store(0, std::memory_order_relaxed);
    }
    {
        std::lock_guard lock { vsync_timeline_mutex_ };
        vsync_timelines_.clear();
    }
    {
        std::lock_guard lock { jit_cache_slots_mutex_ };
        jit_cache_slots_.clear();
    }
    {
        std::lock_guard lock { jit_memory_mutex_ };
        jit_shared_slabs_.clear();
        jit_executor_memory_.clear();
    }
    {
        std::lock_guard lock { hle_mutex_ };
        hle_subsystems_.clear();
    }
    diagnostic_hle_calls_.store(0, std::memory_order_relaxed);
    diagnostic_hle_nanoseconds_.store(0, std::memory_order_relaxed);
    for (auto& counter : diagnostic_graphics_hle_calls_)
        counter.store(0, std::memory_order_relaxed);
    for (auto& counter : diagnostic_graphics_hle_nanoseconds_)
        counter.store(0, std::memory_order_relaxed);
    {
        std::lock_guard lock { display_window_mutex_ };
        std::lock_guard source_lock { diagnostic_source_mutex_ };
        for (auto& source : diagnostic_source_counters_) {
            source.key.store(0, std::memory_order_relaxed);
            source.runnable_generation.store(0, std::memory_order_relaxed);
            source.calls.store(0, std::memory_order_relaxed);
            source.nanoseconds.store(0, std::memory_order_relaxed);
            source.last_used.store(0, std::memory_order_relaxed);
        }
        diagnostic_source_use_clock_ = 0;
        diagnostic_source_occupancy_.store(0, std::memory_order_relaxed);
        diagnostic_source_inserted_.store(0, std::memory_order_relaxed);
        diagnostic_source_updated_.store(0, std::memory_order_relaxed);
        diagnostic_source_evicted_.store(0, std::memory_order_relaxed);
        diagnostic_source_dropped_.store(0, std::memory_order_relaxed);
        diagnostic_source_peak_occupancy_.store(0, std::memory_order_relaxed);
        display_window_diagnostic_source_baseline_.clear();
        reset_display_window_locked();
        diagnostic_previous_content_pixels.clear();
        diagnostic_previous_content_width = 0;
        diagnostic_previous_content_height = 0;
        diagnostic_previous_content_hash = 0;
        diagnostic_previous_content_hash_valid = false;
    }
    enabled_.store(enabled, std::memory_order_release);
}

void PerformanceCounters::reset_display_window_locked()
{
    display_window_snapshot_ = PerformanceSnapshot { };
    {
        std::lock_guard process_lock { diagnostic_process_mutex_ };
        diagnostic_processes_.clear();
    }
    for (auto& histogram : display_window_latencies_)
        histogram = DisplayWindowLatencyHistogram { };
    for (auto& sequence : diagnostic_display_sequences)
        sequence.clear();
    diagnostic_window_started_at = { };
    diagnostic_display_frames.clear();
    diagnostic_vsync_frames.clear();
    diagnostic_cpu_runs.clear();
    diagnostic_content_frames.clear();
    diagnostic_input_events.clear();
    diagnostic_previous_frame_work = { };
}

bool PerformanceCounters::begin_display_window()
{
    if (!enabled())
        return false;
    std::lock_guard lock { display_window_mutex_ };
    if (display_window_active_.load(std::memory_order_relaxed))
        return false;
    reset_display_window_locked();
    diagnostic_window_started_at = std::chrono::steady_clock::now();
    diagnostic_previous_frame_work = {
        translation_blocks_.load(std::memory_order_relaxed),
        cpu_executions_.load(std::memory_order_relaxed),
        cpu_ticks_.load(std::memory_order_relaxed),
        svc_calls_.load(std::memory_order_relaxed),
        page_misses_.load(std::memory_order_relaxed),
        page_faults_.load(std::memory_order_relaxed),
        draws_.load(std::memory_order_relaxed),
        submits_.load(std::memory_order_relaxed),
        fence_waits_.load(std::memory_order_relaxed),
        fence_wait_nanoseconds_.load(std::memory_order_relaxed),
    };
    for (std::size_t index = 0;
        index < diagnostic_previous_frame_work.submit_reasons.size(); ++index) {
        diagnostic_previous_frame_work.submit_reasons[index] =
            submit_reasons_[index].load(std::memory_order_relaxed);
    }
    diagnostic_previous_frame_work.hle_calls =
        diagnostic_hle_calls_.load(std::memory_order_relaxed);
    diagnostic_previous_frame_work.hle_nanoseconds =
        diagnostic_hle_nanoseconds_.load(std::memory_order_relaxed);
    for (std::size_t index = 0;
        index < diagnostic_previous_frame_work.graphics_hle_calls.size();
        ++index) {
        diagnostic_previous_frame_work.graphics_hle_calls[index] =
            diagnostic_graphics_hle_calls_[index].load(
                std::memory_order_relaxed);
        diagnostic_previous_frame_work.graphics_hle_nanoseconds[index] =
            diagnostic_graphics_hle_nanoseconds_[index].load(
                std::memory_order_relaxed);
    }
    diagnostic_work_baseline.jit_instances =
        jit_instances_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.jit_creation_nanoseconds =
        jit_creation_nanoseconds_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.jit_shared_invalidation_requests =
        jit_shared_invalidation_requests_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.jit_full_invalidation_requests =
        jit_full_invalidation_requests_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.jit_range_invalidation_requests =
        jit_range_invalidation_requests_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.jit_slab_generation_transitions =
        jit_slab_generation_transitions_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.jit_invalidated_descriptors =
        jit_invalidated_descriptors_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.jit_retired_code_bytes =
        jit_retired_code_bytes_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.jit_segment_recycles =
        jit_segment_recycles_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.jit_recycled_descriptors =
        jit_recycled_descriptors_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.jit_recycled_code_bytes =
        jit_recycled_code_bytes_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.jit_full_generation_clears =
        jit_full_generation_clears_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.jit_demand_artifact_probes =
        jit_demand_artifact_probes_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.jit_demand_artifact_hits =
        jit_demand_artifact_hits_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.jit_demand_artifact_misses =
        jit_demand_artifact_misses_.load(std::memory_order_relaxed);
    constexpr auto jit_demand_index =
        static_cast<std::size_t>(PerfLatencyKind::JitDemandTranslation);
    diagnostic_work_baseline.latencies[jit_demand_index].samples =
        latencies_[jit_demand_index].samples.load(std::memory_order_relaxed);
    diagnostic_work_baseline.latencies[jit_demand_index].total_nanoseconds =
        latencies_[jit_demand_index].total_nanoseconds.load(
            std::memory_order_relaxed);
    diagnostic_work_baseline.translation_blocks =
        translation_blocks_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.cpu_executions =
        cpu_executions_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.cpu_ticks =
        cpu_ticks_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.svc_calls =
        svc_calls_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.draws = draws_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.submits = submits_.load(std::memory_order_relaxed);
    for (std::size_t index = 0;
        index < diagnostic_work_baseline.submit_reasons.size(); ++index) {
        diagnostic_work_baseline.submit_reasons[index] =
            submit_reasons_[index].load(std::memory_order_relaxed);
    }
    diagnostic_work_baseline.fence_waits =
        fence_waits_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.fence_wait_nanoseconds =
        fence_wait_nanoseconds_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.upload_bytes =
        upload_bytes_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.readback_bytes =
        readback_bytes_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.host_fills =
        host_fills_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.host_copies =
        host_copies_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.scheduler_runnable_transitions =
        scheduler_runnable_transitions_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.scheduler_dispatches =
        scheduler_dispatches_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.scheduler_wakeups =
        scheduler_wakeups_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.scheduler_wake_pending =
        scheduler_wake_pending_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.scheduler_blocks =
        scheduler_blocks_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.scheduler_preemption_checks =
        scheduler_preemption_checks_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.scheduler_preemptions =
        scheduler_preemptions_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.scheduler_urgent_preemptions =
        scheduler_urgent_preemptions_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.scheduler_preemption_requests =
        scheduler_preemption_requests_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.scheduler_preemption_coalesced =
        scheduler_preemption_coalesced_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.scheduler_preemption_returns =
        scheduler_preemption_returns_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.scheduler_preemption_deferred_consumes =
        scheduler_preemption_deferred_consumes_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.scheduler_quantum_expirations =
        scheduler_quantum_expirations_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.cpu_map_reads =
        cpu_map_reads_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.cpu_map_writes =
        cpu_map_writes_.load(std::memory_order_relaxed);
    {
        std::lock_guard hle_lock { hle_mutex_ };
        diagnostic_hle_baseline = hle_subsystems_;
    }
    {
        std::lock_guard source_lock { diagnostic_source_mutex_ };
        display_window_diagnostic_source_baseline_.clear();
        for (const auto& source : diagnostic_source_counters_) {
            const auto key = source.key.load(std::memory_order_relaxed);
            if (key == 0)
                continue;
            const auto snapshot = diagnostic_source_snapshot(key,
                source.runnable_generation.load(std::memory_order_relaxed),
                source.calls.load(std::memory_order_relaxed),
                source.nanoseconds.load(std::memory_order_relaxed));
            display_window_diagnostic_source_baseline_.emplace(
                diagnostic_source_tuple(snapshot), snapshot);
        }
    }
    diagnostic_work_baseline.diagnostic_source_inserted =
        diagnostic_source_inserted_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.diagnostic_source_updated =
        diagnostic_source_updated_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.diagnostic_source_evicted =
        diagnostic_source_evicted_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.diagnostic_source_dropped =
        diagnostic_source_dropped_.load(std::memory_order_relaxed);
    diagnostic_work_baseline.diagnostic_source_capacity =
        diagnostic_source_capacity;
    diagnostic_work_baseline.diagnostic_source_peak_occupancy =
        diagnostic_source_peak_occupancy_.load(std::memory_order_relaxed);
    display_window_active_.store(true, std::memory_order_release);
    return true;
}

std::optional<PerformanceSnapshot> PerformanceCounters::end_display_window()
{
    std::lock_guard lock { display_window_mutex_ };
    if (!display_window_active_.load(std::memory_order_relaxed))
        return std::nullopt;
    display_window_active_.store(false, std::memory_order_release);

    auto result = display_window_snapshot_;
    for (std::size_t index = 0; index < display_window_latencies_.size();
        ++index) {
        const auto& histogram = display_window_latencies_[index];
        auto& latency = result.latencies[index];
        latency.samples = histogram.samples;
        latency.total_nanoseconds = histogram.total_nanoseconds;
        latency.maximum_nanoseconds = histogram.maximum_nanoseconds;
        latency.over_16_7ms = histogram.over_16_7ms;
        latency.over_20ms = histogram.over_20ms;
        latency.over_33_3ms = histogram.over_33_3ms;
        latency.over_50ms = histogram.over_50ms;
        if (latency.samples == 0)
            continue;
        const auto percentile = [&](std::uint64_t numerator) {
            const auto rank = (latency.samples * numerator + 99U) / 100U;
            std::uint64_t cumulative { };
            for (std::size_t bucket = 0; bucket < histogram.buckets.size();
                ++bucket) {
                cumulative += histogram.buckets[bucket];
                if (cumulative >= rank) {
                    return latency_bucket_upper_bound(
                        bucket, latency.maximum_nanoseconds);
                }
            }
            return latency.maximum_nanoseconds;
        };
        latency.p50_nanoseconds = percentile(50);
        latency.p95_nanoseconds = percentile(95);
        latency.p99_nanoseconds = percentile(99);
    }
    result.jit_instances =
        diagnostic_delta(jit_instances_.load(std::memory_order_relaxed),
            diagnostic_work_baseline.jit_instances);
    result.jit_creation_nanoseconds = diagnostic_delta(
        jit_creation_nanoseconds_.load(std::memory_order_relaxed),
        diagnostic_work_baseline.jit_creation_nanoseconds);
    result.jit_shared_invalidation_requests = diagnostic_delta(
        jit_shared_invalidation_requests_.load(std::memory_order_relaxed),
        diagnostic_work_baseline.jit_shared_invalidation_requests);
    result.jit_full_invalidation_requests = diagnostic_delta(
        jit_full_invalidation_requests_.load(std::memory_order_relaxed),
        diagnostic_work_baseline.jit_full_invalidation_requests);
    result.jit_range_invalidation_requests = diagnostic_delta(
        jit_range_invalidation_requests_.load(std::memory_order_relaxed),
        diagnostic_work_baseline.jit_range_invalidation_requests);
    result.jit_slab_generation_transitions = diagnostic_delta(
        jit_slab_generation_transitions_.load(std::memory_order_relaxed),
        diagnostic_work_baseline.jit_slab_generation_transitions);
    result.jit_invalidated_descriptors = diagnostic_delta(
        jit_invalidated_descriptors_.load(std::memory_order_relaxed),
        diagnostic_work_baseline.jit_invalidated_descriptors);
    result.jit_retired_code_bytes = diagnostic_delta(
        jit_retired_code_bytes_.load(std::memory_order_relaxed),
        diagnostic_work_baseline.jit_retired_code_bytes);
    result.jit_segment_recycles =
        diagnostic_delta(jit_segment_recycles_.load(std::memory_order_relaxed),
            diagnostic_work_baseline.jit_segment_recycles);
    result.jit_recycled_descriptors = diagnostic_delta(
        jit_recycled_descriptors_.load(std::memory_order_relaxed),
        diagnostic_work_baseline.jit_recycled_descriptors);
    result.jit_recycled_code_bytes = diagnostic_delta(
        jit_recycled_code_bytes_.load(std::memory_order_relaxed),
        diagnostic_work_baseline.jit_recycled_code_bytes);
    result.jit_full_generation_clears = diagnostic_delta(
        jit_full_generation_clears_.load(std::memory_order_relaxed),
        diagnostic_work_baseline.jit_full_generation_clears);
    result.jit_demand_artifact_probes = diagnostic_delta(
        jit_demand_artifact_probes_.load(std::memory_order_relaxed),
        diagnostic_work_baseline.jit_demand_artifact_probes);
    result.jit_demand_artifact_hits = diagnostic_delta(
        jit_demand_artifact_hits_.load(std::memory_order_relaxed),
        diagnostic_work_baseline.jit_demand_artifact_hits);
    result.jit_demand_artifact_misses = diagnostic_delta(
        jit_demand_artifact_misses_.load(std::memory_order_relaxed),
        diagnostic_work_baseline.jit_demand_artifact_misses);
    constexpr auto jit_demand_index =
        static_cast<std::size_t>(PerfLatencyKind::JitDemandTranslation);
    result.latencies[jit_demand_index].samples = diagnostic_delta(
        latencies_[jit_demand_index].samples.load(std::memory_order_relaxed),
        diagnostic_work_baseline.latencies[jit_demand_index].samples);
    result.latencies[jit_demand_index].total_nanoseconds = diagnostic_delta(
        latencies_[jit_demand_index].total_nanoseconds.load(
            std::memory_order_relaxed),
        diagnostic_work_baseline.latencies[jit_demand_index].total_nanoseconds);
    result.scheduler_runnable_transitions = diagnostic_delta(
        scheduler_runnable_transitions_.load(std::memory_order_relaxed),
        diagnostic_work_baseline.scheduler_runnable_transitions);
    result.scheduler_dispatches =
        diagnostic_delta(scheduler_dispatches_.load(std::memory_order_relaxed),
            diagnostic_work_baseline.scheduler_dispatches);
    result.scheduler_wakeups =
        diagnostic_delta(scheduler_wakeups_.load(std::memory_order_relaxed),
            diagnostic_work_baseline.scheduler_wakeups);
    result.scheduler_wake_pending = diagnostic_delta(
        scheduler_wake_pending_.load(std::memory_order_relaxed),
        diagnostic_work_baseline.scheduler_wake_pending);
    result.scheduler_blocks =
        diagnostic_delta(scheduler_blocks_.load(std::memory_order_relaxed),
            diagnostic_work_baseline.scheduler_blocks);
    result.scheduler_preemption_checks = diagnostic_delta(
        scheduler_preemption_checks_.load(std::memory_order_relaxed),
        diagnostic_work_baseline.scheduler_preemption_checks);
    result.scheduler_preemptions =
        diagnostic_delta(scheduler_preemptions_.load(std::memory_order_relaxed),
            diagnostic_work_baseline.scheduler_preemptions);
    result.scheduler_urgent_preemptions = diagnostic_delta(
        scheduler_urgent_preemptions_.load(std::memory_order_relaxed),
        diagnostic_work_baseline.scheduler_urgent_preemptions);
    result.scheduler_preemption_requests = diagnostic_delta(
        scheduler_preemption_requests_.load(std::memory_order_relaxed),
        diagnostic_work_baseline.scheduler_preemption_requests);
    result.scheduler_preemption_coalesced = diagnostic_delta(
        scheduler_preemption_coalesced_.load(std::memory_order_relaxed),
        diagnostic_work_baseline.scheduler_preemption_coalesced);
    result.scheduler_preemption_returns = diagnostic_delta(
        scheduler_preemption_returns_.load(std::memory_order_relaxed),
        diagnostic_work_baseline.scheduler_preemption_returns);
    result.scheduler_preemption_deferred_consumes = diagnostic_delta(
        scheduler_preemption_deferred_consumes_.load(std::memory_order_relaxed),
        diagnostic_work_baseline.scheduler_preemption_deferred_consumes);
    result.scheduler_quantum_expirations = diagnostic_delta(
        scheduler_quantum_expirations_.load(std::memory_order_relaxed),
        diagnostic_work_baseline.scheduler_quantum_expirations);
    result.translation_blocks_shared_region =
        translation_blocks_shared_region_.load(std::memory_order_relaxed);
    result.translation_blocks =
        diagnostic_delta(translation_blocks_.load(std::memory_order_relaxed),
            diagnostic_work_baseline.translation_blocks);
    result.cpu_executions =
        diagnostic_delta(cpu_executions_.load(std::memory_order_relaxed),
            diagnostic_work_baseline.cpu_executions);
    result.cpu_ticks =
        diagnostic_delta(cpu_ticks_.load(std::memory_order_relaxed),
            diagnostic_work_baseline.cpu_ticks);
    result.svc_calls =
        diagnostic_delta(svc_calls_.load(std::memory_order_relaxed),
            diagnostic_work_baseline.svc_calls);
    result.draws = diagnostic_delta(
        draws_.load(std::memory_order_relaxed), diagnostic_work_baseline.draws);
    result.submits = diagnostic_delta(submits_.load(std::memory_order_relaxed),
        diagnostic_work_baseline.submits);
    for (std::size_t index = 0; index < result.submit_reasons.size(); ++index) {
        result.submit_reasons[index] = diagnostic_delta(
            submit_reasons_[index].load(std::memory_order_relaxed),
            diagnostic_work_baseline.submit_reasons[index]);
    }
    result.fence_waits =
        diagnostic_delta(fence_waits_.load(std::memory_order_relaxed),
            diagnostic_work_baseline.fence_waits);
    result.fence_wait_nanoseconds = diagnostic_delta(
        fence_wait_nanoseconds_.load(std::memory_order_relaxed),
        diagnostic_work_baseline.fence_wait_nanoseconds);
    result.upload_bytes =
        diagnostic_delta(upload_bytes_.load(std::memory_order_relaxed),
            diagnostic_work_baseline.upload_bytes);
    result.readback_bytes =
        diagnostic_delta(readback_bytes_.load(std::memory_order_relaxed),
            diagnostic_work_baseline.readback_bytes);
    result.host_fills =
        diagnostic_delta(host_fills_.load(std::memory_order_relaxed),
            diagnostic_work_baseline.host_fills);
    result.host_copies =
        diagnostic_delta(host_copies_.load(std::memory_order_relaxed),
            diagnostic_work_baseline.host_copies);
    result.cpu_map_reads =
        diagnostic_delta(cpu_map_reads_.load(std::memory_order_relaxed),
            diagnostic_work_baseline.cpu_map_reads);
    result.cpu_map_writes =
        diagnostic_delta(cpu_map_writes_.load(std::memory_order_relaxed),
            diagnostic_work_baseline.cpu_map_writes);
    {
        std::lock_guard hle_lock { hle_mutex_ };
        for (const auto& [name, current] : hle_subsystems_) {
            const auto baseline = diagnostic_hle_baseline.find(name);
            const auto baseline_calls =
                baseline == diagnostic_hle_baseline.end()
                    ? 0
                    : baseline->second.calls;
            const auto baseline_nanoseconds =
                baseline == diagnostic_hle_baseline.end()
                    ? 0
                    : baseline->second.nanoseconds;
            const auto calls = diagnostic_delta(current.calls, baseline_calls);
            const auto nanoseconds =
                diagnostic_delta(current.nanoseconds, baseline_nanoseconds);
            if (calls != 0 || nanoseconds != 0) {
                result.hle_subsystems.push_back(
                    HlePerformanceSnapshot { name, calls, nanoseconds });
            }
        }
    }
    {
        std::lock_guard process_lock { diagnostic_process_mutex_ };
        result.diagnostic_processes.reserve(diagnostic_processes_.size());
        for (const auto& [process_id, stats] : diagnostic_processes_) {
            static_cast<void>(process_id);
            result.diagnostic_processes.push_back(stats);
        }
    }
    {
        std::lock_guard source_lock { diagnostic_source_mutex_ };
        for (const auto& source : diagnostic_source_counters_) {
            const auto encoded_key = source.key.load(std::memory_order_relaxed);
            if (encoded_key == 0)
                continue;
            const auto current = diagnostic_source_snapshot(encoded_key,
                source.runnable_generation.load(std::memory_order_relaxed),
                source.calls.load(std::memory_order_relaxed),
                source.nanoseconds.load(std::memory_order_relaxed));
            const auto key = diagnostic_source_tuple(current);
            const auto baseline =
                display_window_diagnostic_source_baseline_.find(key);
            const auto baseline_calls =
                baseline == display_window_diagnostic_source_baseline_.end()
                    ? 0
                    : baseline->second.calls;
            const auto baseline_nanoseconds =
                baseline == display_window_diagnostic_source_baseline_.end()
                    ? 0
                    : baseline->second.nanoseconds;
            const auto calls = diagnostic_delta(current.calls, baseline_calls);
            const auto nanoseconds =
                diagnostic_delta(current.nanoseconds, baseline_nanoseconds);
            if (calls != 0 || nanoseconds != 0) {
                auto snapshot = current;
                snapshot.calls = calls;
                snapshot.nanoseconds = nanoseconds;
                result.diagnostic_sources.push_back(snapshot);
            }
        }
    }
    result.diagnostic_source_inserted = diagnostic_delta(
        diagnostic_source_inserted_.load(std::memory_order_relaxed),
        diagnostic_work_baseline.diagnostic_source_inserted);
    result.diagnostic_source_updated = diagnostic_delta(
        diagnostic_source_updated_.load(std::memory_order_relaxed),
        diagnostic_work_baseline.diagnostic_source_updated);
    result.diagnostic_source_evicted = diagnostic_delta(
        diagnostic_source_evicted_.load(std::memory_order_relaxed),
        diagnostic_work_baseline.diagnostic_source_evicted);
    result.diagnostic_source_dropped = diagnostic_delta(
        diagnostic_source_dropped_.load(std::memory_order_relaxed),
        diagnostic_work_baseline.diagnostic_source_dropped);
    result.diagnostic_source_capacity = diagnostic_source_capacity;
    result.diagnostic_source_peak_occupancy =
        diagnostic_source_peak_occupancy_.load(std::memory_order_relaxed);
    return result;
}

void PerformanceCounters::record_jit(std::uint64_t creation_nanoseconds)
{
    if (!enabled())
        return;
    jit_instances_.fetch_add(1, std::memory_order_relaxed);
    jit_creation_nanoseconds_.fetch_add(
        creation_nanoseconds, std::memory_order_relaxed);
    const auto live =
        jit_live_instances_.fetch_add(1, std::memory_order_relaxed) + 1;
    auto peak = jit_live_peak_instances_.load(std::memory_order_relaxed);
    while (live > peak &&
           !jit_live_peak_instances_.compare_exchange_weak(peak, live,
               std::memory_order_relaxed, std::memory_order_relaxed)) { }
}

void PerformanceCounters::record_jit_block_compile(std::uint64_t nanoseconds)
{
    record_global_latency(PerfLatencyKind::JitBlockCompile, nanoseconds);
    refresh_jit_block_compile_percentiles();
}

void PerformanceCounters::refresh_jit_block_compile_percentiles()
{
    const auto& histogram =
        latencies_[static_cast<std::size_t>(PerfLatencyKind::JitBlockCompile)];
    const auto samples = histogram.samples.load(std::memory_order_relaxed);
    if (samples == 0)
        return;
    const auto percentile = [&](std::uint64_t numerator) {
        const auto rank = (samples * numerator + 99U) / 100U;
        std::uint64_t cumulative { };
        for (std::size_t bucket = 0; bucket < histogram.buckets.size();
            ++bucket) {
            cumulative +=
                histogram.buckets[bucket].load(std::memory_order_relaxed);
            if (cumulative >= rank) {
                return latency_bucket_upper_bound(
                    bucket, histogram.maximum_nanoseconds.load(
                                std::memory_order_relaxed));
            }
        }
        return histogram.maximum_nanoseconds.load(std::memory_order_relaxed);
    };
    jit_block_compile_p95_nanoseconds_.store(
        percentile(95), std::memory_order_relaxed);
    jit_block_compile_p99_nanoseconds_.store(
        percentile(99), std::memory_order_relaxed);
}

void PerformanceCounters::record_jit_destroyed()
{
    if (!enabled())
        return;
    auto live = jit_live_instances_.load(std::memory_order_relaxed);
    while (live != 0 &&
           !jit_live_instances_.compare_exchange_weak(live, live - 1,
               std::memory_order_relaxed, std::memory_order_relaxed)) { }
}

void PerformanceCounters::record_jit_shared_slab_usage(std::uint64_t slab_id,
    std::uint64_t reserved_bytes, std::uint64_t committed_bytes,
    std::uint64_t used_bytes)
{
    if (!enabled())
        return;
    std::lock_guard lock { jit_memory_mutex_ };
    auto& slab = jit_shared_slabs_[slab_id];
    slab.reserved_bytes = reserved_bytes;
    slab.committed_bytes = committed_bytes;
    slab.used_bytes = used_bytes;
    std::uint64_t reserved { };
    std::uint64_t committed { };
    std::uint64_t used { };
    for (const auto& [id, usage] : jit_shared_slabs_) {
        static_cast<void>(id);
        reserved =
            std::min(std::numeric_limits<std::uint64_t>::max() - reserved,
                usage.reserved_bytes) +
            reserved;
        committed =
            std::min(std::numeric_limits<std::uint64_t>::max() - committed,
                usage.committed_bytes) +
            committed;
        used = std::min(std::numeric_limits<std::uint64_t>::max() - used,
                   usage.used_bytes) +
               used;
    }
    jit_shared_reserved_bytes_.store(reserved, std::memory_order_relaxed);
    jit_shared_committed_bytes_.store(committed, std::memory_order_relaxed);
    jit_shared_used_bytes_.store(used, std::memory_order_relaxed);
    jit_code_cache_current_bytes_.store(used, std::memory_order_relaxed);
    auto peak = jit_code_cache_peak_bytes_.load(std::memory_order_relaxed);
    while (used > peak &&
           !jit_code_cache_peak_bytes_.compare_exchange_weak(peak, used,
               std::memory_order_relaxed, std::memory_order_relaxed)) { }
    refresh_jit_shared_cache_stats_locked();
}

void PerformanceCounters::record_jit_shared_cache_state(std::uint64_t slab_id,
    std::uint32_t process_id, std::uint64_t range_count,
    std::uint64_t descriptor_count,
    std::uint64_t invalidated_descriptors, std::uint64_t retired_code_bytes,
    std::uint64_t segment_recycles, std::uint64_t recycled_descriptors,
    std::uint64_t recycled_code_bytes, std::uint64_t full_generation_clears)
{
    if (!enabled())
        return;
    std::uint64_t segment_recycle_delta { };
    std::uint64_t recycled_descriptor_delta { };
    std::uint64_t recycled_code_delta { };
    std::uint64_t full_clear_delta { };
    const auto delta = [](std::uint64_t current, std::uint64_t previous) {
        return current >= previous ? current - previous : current;
    };
    {
        std::lock_guard lock { jit_memory_mutex_ };
        auto& slab = jit_shared_slabs_[slab_id];
        const auto invalidated_delta =
            delta(invalidated_descriptors, slab.invalidated_descriptors);
        const auto retired_delta =
            delta(retired_code_bytes, slab.retired_code_bytes);
        segment_recycle_delta =
            delta(segment_recycles, slab.segment_recycles);
        recycled_descriptor_delta =
            delta(recycled_descriptors, slab.recycled_descriptors);
        recycled_code_delta =
            delta(recycled_code_bytes, slab.recycled_code_bytes);
        full_clear_delta =
            delta(full_generation_clears, slab.full_generation_clears);
        jit_invalidated_descriptors_.fetch_add(
            invalidated_delta, std::memory_order_relaxed);
        jit_retired_code_bytes_.fetch_add(
            retired_delta, std::memory_order_relaxed);
        jit_segment_recycles_.fetch_add(
            segment_recycle_delta, std::memory_order_relaxed);
        jit_recycled_descriptors_.fetch_add(
            recycled_descriptor_delta, std::memory_order_relaxed);
        jit_recycled_code_bytes_.fetch_add(
            recycled_code_delta, std::memory_order_relaxed);
        jit_full_generation_clears_.fetch_add(
            full_clear_delta, std::memory_order_relaxed);
        slab.range_count = range_count;
        slab.descriptor_count = descriptor_count;
        slab.invalidated_descriptors = invalidated_descriptors;
        slab.retired_code_bytes = retired_code_bytes;
        slab.segment_recycles = segment_recycles;
        slab.recycled_descriptors = recycled_descriptors;
        slab.recycled_code_bytes = recycled_code_bytes;
        slab.full_generation_clears = full_generation_clears;
        refresh_jit_shared_cache_stats_locked();
    }
    if (!display_window_active_.load(std::memory_order_relaxed) ||
        (segment_recycle_delta == 0U && recycled_descriptor_delta == 0U &&
            recycled_code_delta == 0U && full_clear_delta == 0U)) {
        return;
    }
    std::lock_guard process_lock { diagnostic_process_mutex_ };
    auto [found, inserted] = diagnostic_processes_.try_emplace(
        process_id, DiagnosticProcessSnapshot { });
    auto& process = found->second;
    if (inserted)
        process.process_id = process_id;
    process.jit_segment_recycles += segment_recycle_delta;
    process.jit_recycled_descriptors += recycled_descriptor_delta;
    process.jit_recycled_code_bytes += recycled_code_delta;
    process.jit_full_generation_clears += full_clear_delta;
}

void PerformanceCounters::refresh_jit_shared_cache_stats_locked()
{
    std::uint64_t ranges { };
    std::uint64_t descriptors { };
    for (const auto& [id, usage] : jit_shared_slabs_) {
        static_cast<void>(id);
        ranges = std::min(std::numeric_limits<std::uint64_t>::max() - ranges,
                     usage.range_count) +
                 ranges;
        descriptors =
            std::min(std::numeric_limits<std::uint64_t>::max() - descriptors,
                usage.descriptor_count) +
            descriptors;
    }
    jit_shared_range_count_.store(ranges, std::memory_order_relaxed);
    jit_shared_descriptor_count_.store(descriptors, std::memory_order_relaxed);
}

void PerformanceCounters::record_jit_executor_memory_usage(
    std::uint64_t slab_id, std::uint32_t process_id, std::uint32_t slot,
    std::uint64_t current_bytes)
{
    if (!enabled())
        return;
    std::unique_lock memory_lock { jit_memory_mutex_ };
    jit_executor_memory_[{ slab_id, process_id, slot }] = current_bytes;
    std::uint64_t aggregate { };
    for (const auto& [key, bytes] : jit_executor_memory_) {
        static_cast<void>(key);
        aggregate =
            std::min(
                std::numeric_limits<std::uint64_t>::max() - aggregate, bytes) +
            aggregate;
    }
    jit_executor_local_bytes_.store(aggregate, std::memory_order_relaxed);
    auto peak = jit_executor_local_peak_bytes_.load(std::memory_order_relaxed);
    while (
        aggregate > peak &&
        !jit_executor_local_peak_bytes_.compare_exchange_weak(peak, aggregate,
            std::memory_order_relaxed, std::memory_order_relaxed)) { }
    memory_lock.unlock();

    std::lock_guard slot_lock { jit_cache_slots_mutex_ };
    auto [found, inserted] = jit_cache_slots_.try_emplace({ process_id, slot });
    auto& usage = found->second;
    if (inserted) {
        usage.process_id = process_id;
        usage.slot = slot;
    }
    usage.current_bytes = current_bytes;
    usage.peak_bytes = std::max(usage.peak_bytes, current_bytes);
}

void PerformanceCounters::release_jit_memory_context(std::uint64_t slab_id)
{
    if (!enabled())
        return;
    std::lock_guard lock { jit_memory_mutex_ };
    jit_shared_slabs_.erase(slab_id);
    for (auto iterator = jit_executor_memory_.begin();
        iterator != jit_executor_memory_.end();) {
        if (std::get<0>(iterator->first) == slab_id) {
            iterator = jit_executor_memory_.erase(iterator);
        } else {
            ++iterator;
        }
    }
    std::uint64_t reserved { };
    std::uint64_t committed { };
    std::uint64_t used { };
    for (const auto& [id, usage] : jit_shared_slabs_) {
        static_cast<void>(id);
        reserved =
            std::min(std::numeric_limits<std::uint64_t>::max() - reserved,
                usage.reserved_bytes) +
            reserved;
        committed =
            std::min(std::numeric_limits<std::uint64_t>::max() - committed,
                usage.committed_bytes) +
            committed;
        used = std::min(std::numeric_limits<std::uint64_t>::max() - used,
                   usage.used_bytes) +
               used;
    }
    std::uint64_t local { };
    for (const auto& [key, bytes] : jit_executor_memory_) {
        static_cast<void>(key);
        local =
            std::min(std::numeric_limits<std::uint64_t>::max() - local, bytes) +
            local;
    }
    jit_shared_reserved_bytes_.store(reserved, std::memory_order_relaxed);
    jit_shared_committed_bytes_.store(committed, std::memory_order_relaxed);
    jit_shared_used_bytes_.store(used, std::memory_order_relaxed);
    jit_code_cache_current_bytes_.store(used, std::memory_order_relaxed);
    jit_executor_local_bytes_.store(local, std::memory_order_relaxed);
    refresh_jit_shared_cache_stats_locked();
}

void PerformanceCounters::record_jit_shared_invalidation(bool full)
{
    if (!enabled())
        return;
    jit_shared_invalidation_requests_.fetch_add(1, std::memory_order_relaxed);
    auto& scoped_counter = full ? jit_full_invalidation_requests_
                                : jit_range_invalidation_requests_;
    scoped_counter.fetch_add(1, std::memory_order_relaxed);
}

void PerformanceCounters::record_jit_slab_generation_transition(
    std::uint32_t process_id)
{
    if (!enabled())
        return;
    jit_slab_generation_transitions_.fetch_add(1, std::memory_order_relaxed);
    if (!display_window_active_.load(std::memory_order_relaxed))
        return;
    std::lock_guard lock { diagnostic_process_mutex_ };
    auto [found, inserted] = diagnostic_processes_.try_emplace(
        process_id, DiagnosticProcessSnapshot { });
    auto& process = found->second;
    if (inserted)
        process.process_id = process_id;
    ++process.jit_slab_generation_transitions;
}

void PerformanceCounters::record_jit_demand_translation(
    std::uint32_t process_id, std::uint64_t nanoseconds)
{
    record_latency(PerfLatencyKind::JitDemandTranslation, nanoseconds);
    if (!cpu_source_diagnostics_enabled())
        return;
    std::lock_guard lock { diagnostic_process_mutex_ };
    auto [found, inserted] = diagnostic_processes_.try_emplace(
        process_id, DiagnosticProcessSnapshot { });
    auto& process = found->second;
    if (inserted)
        process.process_id = process_id;
    ++process.jit_demand_translations;
    process.jit_demand_translation_nanoseconds += nanoseconds;
}

void PerformanceCounters::record_jit_dispatch(std::uint64_t fast_link_hits,
    std::uint64_t fast_link_misses, std::uint64_t stable_table_probes,
    std::uint64_t stable_table_collisions, std::uint64_t rsb_hits,
    std::uint64_t rsb_misses)
{
    if (!enabled())
        return;
    jit_fast_link_hits_.fetch_add(fast_link_hits, std::memory_order_relaxed);
    jit_fast_link_misses_.fetch_add(
        fast_link_misses, std::memory_order_relaxed);
    jit_stable_table_probes_.fetch_add(
        stable_table_probes, std::memory_order_relaxed);
    jit_stable_table_collisions_.fetch_add(
        stable_table_collisions, std::memory_order_relaxed);
    jit_rsb_hits_.fetch_add(rsb_hits, std::memory_order_relaxed);
    jit_rsb_misses_.fetch_add(rsb_misses, std::memory_order_relaxed);
}

void PerformanceCounters::record_jit_dispatch(std::uint64_t stable_link_hits,
    std::uint64_t stable_link_misses, std::uint64_t rsb_hits,
    std::uint64_t rsb_misses)
{
    record_jit_dispatch(stable_link_hits, stable_link_misses,
        stable_link_hits + stable_link_misses, 0, rsb_hits, rsb_misses);
}

void PerformanceCounters::record_jit_host_yield(
    std::uint64_t checks, bool yielded)
{
    if (!enabled())
        return;
    jit_host_yield_checks_.fetch_add(checks, std::memory_order_relaxed);
    if (yielded) {
        jit_host_yields_.fetch_add(1, std::memory_order_relaxed);
    }
}

void PerformanceCounters::record_jit_host_slice_budget(
    std::uint64_t nanoseconds)
{
    if (!enabled())
        return;
    jit_host_slice_budget_samples_.fetch_add(1, std::memory_order_relaxed);
    jit_host_slice_budget_total_nanoseconds_.fetch_add(
        nanoseconds, std::memory_order_relaxed);
    auto minimum =
        jit_host_slice_budget_min_nanoseconds_.load(std::memory_order_relaxed);
    while ((minimum == 0 || nanoseconds < minimum) &&
           !jit_host_slice_budget_min_nanoseconds_.compare_exchange_weak(
               minimum, nanoseconds, std::memory_order_relaxed,
               std::memory_order_relaxed)) { }
    auto maximum =
        jit_host_slice_budget_max_nanoseconds_.load(std::memory_order_relaxed);
    while (nanoseconds > maximum &&
           !jit_host_slice_budget_max_nanoseconds_.compare_exchange_weak(
               maximum, nanoseconds, std::memory_order_relaxed,
               std::memory_order_relaxed)) { }
}

void PerformanceCounters::record_jit_demand_artifact_probe(bool hit)
{
    if (!enabled())
        return;
    jit_demand_artifact_probes_.fetch_add(1, std::memory_order_relaxed);
    (hit ? jit_demand_artifact_hits_ : jit_demand_artifact_misses_)
        .fetch_add(1, std::memory_order_relaxed);
}

void PerformanceCounters::record_scheduler_runnable_transition()
{
    if (!enabled())
        return;
    scheduler_runnable_transitions_.fetch_add(1, std::memory_order_relaxed);
}

void PerformanceCounters::record_scheduler_dispatch()
{
    if (!enabled())
        return;
    scheduler_dispatches_.fetch_add(1, std::memory_order_relaxed);
}

void PerformanceCounters::record_scheduler_wakeup(
    bool pending_on_running_thread, bool became_pending)
{
    if (!enabled())
        return;
    scheduler_wakeups_.fetch_add(1, std::memory_order_relaxed);
    if (pending_on_running_thread && became_pending) {
        scheduler_wake_pending_.fetch_add(1, std::memory_order_relaxed);
    }
}

void PerformanceCounters::record_scheduler_block()
{
    if (!enabled())
        return;
    scheduler_blocks_.fetch_add(1, std::memory_order_relaxed);
}

void PerformanceCounters::record_scheduler_preemption_check(
    PerfSchedulerPreemptionKind result)
{
    if (!enabled())
        return;
    scheduler_preemption_checks_.fetch_add(1, std::memory_order_relaxed);
    if (result != PerfSchedulerPreemptionKind::None) {
        scheduler_preemptions_.fetch_add(1, std::memory_order_relaxed);
    }
    if (result == PerfSchedulerPreemptionKind::Urgent) {
        scheduler_urgent_preemptions_.fetch_add(1, std::memory_order_relaxed);
    }
}

void PerformanceCounters::record_scheduler_preemption_request()
{
    if (!enabled())
        return;
    scheduler_preemption_requests_.fetch_add(1, std::memory_order_relaxed);
}

void PerformanceCounters::record_scheduler_preemption_coalesced()
{
    if (!enabled())
        return;
    scheduler_preemption_coalesced_.fetch_add(1, std::memory_order_relaxed);
}

void PerformanceCounters::record_scheduler_preemption_return()
{
    if (!enabled())
        return;
    scheduler_preemption_returns_.fetch_add(1, std::memory_order_relaxed);
}

void PerformanceCounters::record_scheduler_preemption_deferred_consume()
{
    if (!enabled())
        return;
    scheduler_preemption_deferred_consumes_.fetch_add(
        1, std::memory_order_relaxed);
}

void PerformanceCounters::record_scheduler_quantum_expiry()
{
    if (!enabled())
        return;
    scheduler_quantum_expirations_.fetch_add(1, std::memory_order_relaxed);
}

void PerformanceCounters::record_translation_block()
{
    add_if_enabled(translation_blocks_, enabled_);
}

void PerformanceCounters::record_translation_block_shared_region()
{
    add_if_enabled(translation_blocks_shared_region_, enabled_);
}

void PerformanceCounters::record_cpu_execution(std::uint64_t ticks)
{
    if (!enabled())
        return;
    cpu_executions_.fetch_add(1, std::memory_order_relaxed);
    cpu_ticks_.fetch_add(ticks, std::memory_order_relaxed);
}

void PerformanceCounters::record_svc() { add_if_enabled(svc_calls_, enabled_); }

void PerformanceCounters::record_page_miss()
{
    add_if_enabled(page_misses_, enabled_);
}

void PerformanceCounters::record_page_fault()
{
    add_if_enabled(page_faults_, enabled_);
}

void PerformanceCounters::record_draw() { add_if_enabled(draws_, enabled_); }

void PerformanceCounters::record_submit(PerfSubmitReason reason)
{
    add_if_enabled(submits_, enabled_);
    const auto index = static_cast<std::size_t>(reason);
    if (enabled() && index < submit_reasons_.size())
        submit_reasons_[index].fetch_add(1, std::memory_order_relaxed);
}

void PerformanceCounters::record_fence_wait(std::uint64_t nanoseconds)
{
    if (!enabled())
        return;
    fence_waits_.fetch_add(1, std::memory_order_relaxed);
    fence_wait_nanoseconds_.fetch_add(nanoseconds, std::memory_order_relaxed);
}

void PerformanceCounters::record_upload(
    std::uint64_t bytes, PerfSurfaceKind surface)
{
    add_if_enabled(upload_bytes_, enabled_, bytes);
    const auto index = static_cast<std::size_t>(surface);
    if (enabled() && index < surface_upload_bytes_.size()) {
        surface_upload_bytes_[index].fetch_add(
            bytes, std::memory_order_relaxed);
    }
}

void PerformanceCounters::record_readback(
    std::uint64_t bytes, PerfSurfaceKind surface)
{
    add_if_enabled(readback_bytes_, enabled_, bytes);
    const auto index = static_cast<std::size_t>(surface);
    if (enabled() && index < surface_readback_bytes_.size()) {
        surface_readback_bytes_[index].fetch_add(
            bytes, std::memory_order_relaxed);
    }
}

void PerformanceCounters::record_host_fill()
{
    add_if_enabled(host_fills_, enabled_);
}

void PerformanceCounters::record_host_copy()
{
    add_if_enabled(host_copies_, enabled_);
}

void PerformanceCounters::record_display_submission(
    std::uint64_t frame_sequence, std::uint32_t owner_process_id,
    std::chrono::steady_clock::time_point submitted_at)
{
    if (!enabled())
        return;
    const auto timestamp = steady_nanoseconds(submitted_at);
    if (timestamp == 0)
        return;
    record_timestamp_span(display_submissions_, display_first_nanoseconds_,
        display_last_nanoseconds_, timestamp);
    if (!display_window_active_.load(std::memory_order_acquire))
        return;
    std::lock_guard lock { display_window_mutex_ };
    if (!display_window_active_.load(std::memory_order_relaxed))
        return;
    auto& window = display_window_snapshot_;
    ++window.display_submissions;
    if (window.display_first_nanoseconds == 0)
        window.display_first_nanoseconds = timestamp;
    window.display_last_nanoseconds = timestamp;
    if (frame_sequence != 0 && diagnostic_display_frames.size() <
                                   maximum_diagnostic_sequence_samples) {
        DiagnosticDisplayFrame frame;
        frame.sequence = frame_sequence;
        frame.owner_process_id = owner_process_id;
        frame.submitted = submitted_at;
        diagnostic_display_frames.push_back(frame);
    }
}

void PerformanceCounters::record_diagnostic_frame_content(
    std::uint64_t frame_sequence, std::uint32_t owner_process_id,
    std::chrono::steady_clock::time_point submitted_at, std::uint32_t width,
    std::uint32_t height, std::span<const std::uint32_t> pixels)
{
    if (!enabled() || !frame_content_diagnostics_enabled() || width == 0 ||
        height == 0 ||
        pixels.size() != static_cast<std::size_t>(width) * height) {
        return;
    }

    std::lock_guard lock { display_window_mutex_ };
    if (!display_window_active_.load(std::memory_order_relaxed)) {
        diagnostic_previous_content_width = width;
        diagnostic_previous_content_height = height;
        diagnostic_previous_content_pixels.assign(pixels.begin(), pixels.end());
        diagnostic_previous_content_hash_valid = false;
        return;
    }
    const auto comparable =
        diagnostic_previous_content_width == width &&
        diagnostic_previous_content_height == height &&
        diagnostic_previous_content_pixels.size() == pixels.size();
    const auto unchanged =
        comparable &&
        std::memcmp(pixels.data(), diagnostic_previous_content_pixels.data(),
            pixels.size_bytes()) == 0;
    std::uint64_t changed_pixels { };
    std::uint64_t absolute_rgb_delta { };
    auto hash = diagnostic_previous_content_hash;
    if (unchanged) {
        if (!diagnostic_previous_content_hash_valid) {
            hash = diagnostic_content_hash(pixels);
            diagnostic_previous_content_hash = hash;
            diagnostic_previous_content_hash_valid = true;
        }
        if (diagnostic_content_frames.size() <
            maximum_diagnostic_sequence_samples) {
            diagnostic_content_frames.push_back(DiagnosticContentFrame {
                frame_sequence, owner_process_id, submitted_at, comparable,
                changed_pixels, absolute_rgb_delta, hash });
        }
        return;
    }

    hash = 14695981039346656037ULL;
    for (std::size_t index = 0; index < pixels.size(); ++index) {
        const auto pixel = pixels[index];
        hash ^= pixel;
        hash *= 1099511628211ULL;
        if (!comparable || pixel == diagnostic_previous_content_pixels[index])
            continue;
        ++changed_pixels;
        const auto previous = diagnostic_previous_content_pixels[index];
        for (const auto shift : { 0U, 8U, 16U }) {
            const auto current_channel =
                static_cast<int>((pixel >> shift) & 0xffU);
            const auto previous_channel =
                static_cast<int>((previous >> shift) & 0xffU);
            absolute_rgb_delta += static_cast<std::uint64_t>(
                std::abs(current_channel - previous_channel));
        }
    }

    if (diagnostic_content_frames.size() <
        maximum_diagnostic_sequence_samples) {
        diagnostic_content_frames.push_back(DiagnosticContentFrame {
            frame_sequence, owner_process_id, submitted_at, comparable,
            changed_pixels, absolute_rgb_delta, hash });
    }
    diagnostic_previous_content_hash = hash;
    diagnostic_previous_content_hash_valid = true;
    diagnostic_previous_content_width = width;
    diagnostic_previous_content_height = height;
    diagnostic_previous_content_pixels.assign(pixels.begin(), pixels.end());
}

void PerformanceCounters::record_diagnostic_input(std::string_view kind,
    std::string_view phase, float x, float y, bool queued,
    std::uint64_t input_sequence,
    std::chrono::steady_clock::time_point enqueued_at)
{
    if (!enabled() || !frame_content_diagnostics_enabled() ||
        !display_window_active_.load(std::memory_order_acquire)) {
        return;
    }
    std::lock_guard lock { display_window_mutex_ };
    if (!display_window_active_.load(std::memory_order_relaxed) ||
        diagnostic_input_events.size() >= maximum_diagnostic_sequence_samples) {
        return;
    }
    diagnostic_input_events.push_back(
        DiagnosticInputEvent { std::string { kind }, std::string { phase }, x,
            y, queued, input_sequence, 0, 0, enqueued_at, { }, { }, { } });
}

void PerformanceCounters::record_diagnostic_input_guest(
    std::uint64_t input_sequence, std::uint32_t process_id,
    std::uint32_t thread, std::chrono::steady_clock::time_point entered_at)
{
    if (!enabled() || !frame_content_diagnostics_enabled() ||
        !display_window_active_.load(std::memory_order_acquire) ||
        input_sequence == 0) {
        return;
    }
    std::lock_guard lock { display_window_mutex_ };
    if (!display_window_active_.load(std::memory_order_relaxed))
        return;
    const auto found = std::find_if(diagnostic_input_events.rbegin(),
        diagnostic_input_events.rend(), [input_sequence](const auto& event) {
            return event.sequence == input_sequence;
        });
    if (found == diagnostic_input_events.rend())
        return;
    found->process_id = process_id;
    found->thread = thread;
    found->guest_entered = entered_at;
}

void PerformanceCounters::record_diagnostic_input_runnable(
    std::uint64_t input_sequence, std::uint32_t process_id,
    std::uint32_t thread, std::chrono::steady_clock::time_point runnable_at)
{
    if (!enabled() || !frame_content_diagnostics_enabled() ||
        !display_window_active_.load(std::memory_order_acquire) ||
        input_sequence == 0) {
        return;
    }
    std::lock_guard lock { display_window_mutex_ };
    if (!display_window_active_.load(std::memory_order_relaxed))
        return;
    const auto found = std::find_if(diagnostic_input_events.rbegin(),
        diagnostic_input_events.rend(), [input_sequence](const auto& event) {
            return event.sequence == input_sequence;
        });
    if (found == diagnostic_input_events.rend())
        return;
    found->process_id = process_id;
    found->thread = thread;
    found->runnable = runnable_at;
}

void PerformanceCounters::record_diagnostic_input_execute(
    std::uint32_t process_id, std::uint32_t thread,
    std::chrono::steady_clock::time_point executed_at)
{
    if (!enabled() || !frame_content_diagnostics_enabled() ||
        !display_window_active_.load(std::memory_order_acquire)) {
        return;
    }
    std::lock_guard lock { display_window_mutex_ };
    if (!display_window_active_.load(std::memory_order_relaxed))
        return;
    const auto found = std::find_if(diagnostic_input_events.begin(),
        diagnostic_input_events.end(), [process_id, thread](const auto& event) {
            return event.process_id == process_id && event.thread == thread &&
                   event.runnable !=
                       std::chrono::steady_clock::time_point { } &&
                   event.executed == std::chrono::steady_clock::time_point { };
        });
    if (found == diagnostic_input_events.end())
        return;
    found->executed = executed_at;
}

void PerformanceCounters::record_diagnostic_display_dequeue(
    std::uint64_t frame_sequence,
    std::chrono::steady_clock::time_point dequeued_at)
{
    if (!enabled() || frame_sequence == 0 ||
        !display_window_active_.load(std::memory_order_acquire)) {
        return;
    }
    std::lock_guard lock { display_window_mutex_ };
    if (!display_window_active_.load(std::memory_order_relaxed))
        return;
    if (auto* frame = diagnostic_display_frame(frame_sequence))
        frame->display_dequeued = dequeued_at;
}

void PerformanceCounters::record_diagnostic_native_queue(
    std::uint64_t frame_sequence,
    std::chrono::steady_clock::time_point queued_at)
{
    if (!enabled() || frame_sequence == 0 ||
        !display_window_active_.load(std::memory_order_acquire)) {
        return;
    }
    std::lock_guard lock { display_window_mutex_ };
    if (!display_window_active_.load(std::memory_order_relaxed))
        return;
    if (auto* frame = diagnostic_display_frame(frame_sequence))
        frame->native_queued = queued_at;
}

void PerformanceCounters::record_diagnostic_native_dequeue(
    std::uint64_t frame_sequence,
    std::chrono::steady_clock::time_point dequeued_at)
{
    if (!enabled() || frame_sequence == 0 ||
        !display_window_active_.load(std::memory_order_acquire)) {
        return;
    }
    std::lock_guard lock { display_window_mutex_ };
    if (!display_window_active_.load(std::memory_order_relaxed))
        return;
    if (auto* frame = diagnostic_display_frame(frame_sequence))
        frame->native_dequeued = dequeued_at;
}

void PerformanceCounters::add_display_window_counter(
    std::uint64_t PerformanceSnapshot::* counter, std::uint64_t value)
{
    if (!display_window_active_.load(std::memory_order_acquire))
        return;
    std::lock_guard lock { display_window_mutex_ };
    if (!display_window_active_.load(std::memory_order_relaxed))
        return;
    display_window_snapshot_.*counter += value;
}

void PerformanceCounters::record_display_mailbox_coalesced()
{
    if (!enabled())
        return;
    display_mailbox_coalesced_.fetch_add(1, std::memory_order_relaxed);
    add_display_window_counter(&PerformanceSnapshot::display_mailbox_coalesced);
}

void PerformanceCounters::record_display_vsync_queued()
{
    if (!enabled())
        return;
    display_vsync_queued_.fetch_add(1, std::memory_order_relaxed);
    add_display_window_counter(&PerformanceSnapshot::display_vsync_queued);
}

void PerformanceCounters::record_display_vsync_coalesced()
{
    if (!enabled())
        return;
    display_vsync_coalesced_.fetch_add(1, std::memory_order_relaxed);
    add_display_window_counter(&PerformanceSnapshot::display_vsync_coalesced);
}

void PerformanceCounters::record_display_vsync_budget(
    std::uint64_t original_ticks, std::uint64_t limited_ticks)
{
    if (!enabled() || limited_ticks >= original_ticks)
        return;
    display_vsync_budget_cuts_.fetch_add(1, std::memory_order_relaxed);
    display_vsync_budget_saved_ticks_.fetch_add(
        original_ticks - limited_ticks, std::memory_order_relaxed);
    add_display_window_counter(&PerformanceSnapshot::display_vsync_budget_cuts);
    add_display_window_counter(
        &PerformanceSnapshot::display_vsync_budget_saved_ticks,
        original_ticks - limited_ticks);
}

void PerformanceCounters::record_display_queue_depth(std::uint64_t depth)
{
    if (!enabled())
        return;
    display_queue_depth_.store(depth, std::memory_order_relaxed);
    auto high_watermark =
        display_queue_high_watermark_.load(std::memory_order_relaxed);
    while (high_watermark < depth &&
           !display_queue_high_watermark_.compare_exchange_weak(high_watermark,
               depth, std::memory_order_relaxed, std::memory_order_relaxed)) { }
    if (!display_window_active_.load(std::memory_order_acquire))
        return;
    std::lock_guard lock { display_window_mutex_ };
    if (!display_window_active_.load(std::memory_order_relaxed))
        return;
    display_window_snapshot_.display_queue_depth = depth;
    display_window_snapshot_.display_queue_high_watermark =
        std::max(display_window_snapshot_.display_queue_high_watermark, depth);
}

void PerformanceCounters::record_display_queue_wait(
    std::uint64_t nanoseconds, bool timed_out)
{
    if (!enabled())
        return;
    display_queue_backpressure_waits_.fetch_add(1, std::memory_order_relaxed);
    auto maximum = display_queue_backpressure_max_wait_nanoseconds_.load(
        std::memory_order_relaxed);
    while (
        maximum < nanoseconds &&
        !display_queue_backpressure_max_wait_nanoseconds_.compare_exchange_weak(
            maximum, nanoseconds, std::memory_order_relaxed,
            std::memory_order_relaxed)) { }
    if (timed_out)
        display_queue_backpressure_timeouts_.fetch_add(
            1, std::memory_order_relaxed);
    add_display_window_counter(
        &PerformanceSnapshot::display_queue_backpressure_waits);
    if (timed_out)
        add_display_window_counter(
            &PerformanceSnapshot::display_queue_backpressure_timeouts);
    if (display_window_active_.load(std::memory_order_acquire)) {
        std::lock_guard lock { display_window_mutex_ };
        if (display_window_active_.load(std::memory_order_relaxed)) {
            display_window_snapshot_
                .display_queue_backpressure_max_wait_nanoseconds =
                std::max(display_window_snapshot_
                             .display_queue_backpressure_max_wait_nanoseconds,
                    nanoseconds);
        }
    }
}

void PerformanceCounters::record_sdl_idle_wait()
{
    if (!enabled())
        return;
    sdl_idle_waits_.fetch_add(1, std::memory_order_relaxed);
}

void PerformanceCounters::record_native_present_attempt()
{
    if (!enabled())
        return;
    native_present_attempts_.fetch_add(1, std::memory_order_relaxed);
    add_display_window_counter(&PerformanceSnapshot::native_present_attempts);
}

void PerformanceCounters::record_native_present_mailbox_coalesced()
{
    if (!enabled())
        return;
    native_present_mailbox_coalesced_.fetch_add(1, std::memory_order_relaxed);
    add_display_window_counter(
        &PerformanceSnapshot::native_present_mailbox_coalesced);
}

void PerformanceCounters::record_native_present_skipped()
{
    if (!enabled())
        return;
    native_present_skipped_.fetch_add(1, std::memory_order_relaxed);
    add_display_window_counter(&PerformanceSnapshot::native_present_skipped);
}

void PerformanceCounters::record_native_present_failure()
{
    if (!enabled())
        return;
    native_present_failures_.fetch_add(1, std::memory_order_relaxed);
    add_display_window_counter(&PerformanceSnapshot::native_present_failures);
}

void PerformanceCounters::record_present_completion(bool native,
    std::uint64_t frame_sequence,
    std::chrono::steady_clock::time_point submitted_at)
{
    if (!enabled())
        return;
    std::lock_guard timeline_lock { present_timeline_mutex_ };
    const auto returned_at = std::chrono::steady_clock::now();
    const auto returned_nanoseconds = steady_nanoseconds(returned_at);
    auto& global_count = native ? native_presents_ : cpu_present_fallbacks_;
    global_count.fetch_add(1, std::memory_order_relaxed);
    if (present_first_nanoseconds_.load(std::memory_order_relaxed) == 0) {
        present_first_nanoseconds_.store(
            returned_nanoseconds, std::memory_order_relaxed);
    }
    const auto previous =
        present_last_nanoseconds_.load(std::memory_order_relaxed);
    present_last_nanoseconds_.store(
        returned_nanoseconds, std::memory_order_relaxed);
    if (previous != 0)
        record_global_latency(
            PerfLatencyKind::PresentInterval, returned_nanoseconds - previous);
    const auto submitted_nanoseconds = steady_nanoseconds(submitted_at);
    if (submitted_nanoseconds != 0 &&
        returned_nanoseconds > submitted_nanoseconds) {
        record_global_latency(PerfLatencyKind::PresentReturn,
            returned_nanoseconds - submitted_nanoseconds);
    }

    if (!display_window_active_.load(std::memory_order_acquire))
        return;
    std::lock_guard window_lock { display_window_mutex_ };
    if (!display_window_active_.load(std::memory_order_relaxed))
        return;
    auto& window = display_window_snapshot_;
    if (native)
        ++window.native_presents;
    else
        ++window.cpu_present_fallbacks;
    if (window.present_first_nanoseconds == 0)
        window.present_first_nanoseconds = returned_nanoseconds;
    const auto window_previous = window.present_last_nanoseconds;
    window.present_last_nanoseconds = returned_nanoseconds;
    if (window_previous != 0) {
        record_display_window_latency_locked(PerfLatencyKind::PresentInterval,
            returned_nanoseconds - window_previous);
    }
    if (submitted_nanoseconds != 0 &&
        returned_nanoseconds > submitted_nanoseconds) {
        record_display_window_latency_locked(PerfLatencyKind::PresentReturn,
            returned_nanoseconds - submitted_nanoseconds);
    }
    if (auto* frame = diagnostic_display_frame(frame_sequence)) {
        frame->present_returned = returned_at;
        frame->present_kind = native ? 'n' : 'c';
    }
}

void PerformanceCounters::record_native_present(std::uint64_t frame_sequence,
    std::chrono::steady_clock::time_point submitted_at)
{
    record_present_completion(true, frame_sequence, submitted_at);
}

void PerformanceCounters::record_cpu_present_fallback(
    std::uint64_t frame_sequence,
    std::chrono::steady_clock::time_point submitted_at)
{
    record_present_completion(false, frame_sequence, submitted_at);
}

void PerformanceCounters::record_cpu_map(bool write, PerfCpuMapReason reason)
{
    const auto index = static_cast<std::size_t>(reason);
    if (!enabled() || index >= perf_cpu_map_reason_count)
        return;
    auto& total = write ? cpu_map_writes_ : cpu_map_reads_;
    auto& reasons = write ? cpu_map_write_reasons_ : cpu_map_read_reasons_;
    total.fetch_add(1, std::memory_order_relaxed);
    reasons[index].fetch_add(1, std::memory_order_relaxed);
}

void PerformanceCounters::record_vsync_due(
    std::uint32_t process_id, std::uint32_t framebuffer, std::uint64_t sequence)
{
    if (!enabled() || process_id == 0 || framebuffer == 0 || sequence == 0)
        return;
    std::lock_guard lock { vsync_timeline_mutex_ };
    auto& timelines = vsync_timelines_[{ process_id, framebuffer }];
    constexpr std::size_t maximum_pending_timelines = 8;
    if (timelines.size() == maximum_pending_timelines)
        timelines.pop_front();
    timelines.push_back(
        VsyncTimeline {
            sequence, std::chrono::steady_clock::now(), { }, { }, { } });
}

void PerformanceCounters::record_vsync_receiver(
    std::uint32_t process_id, std::uint32_t processor_id,
    std::uint64_t sequence)
{
    if (!enabled() || process_id == 0)
        return;
    std::lock_guard lock { vsync_timeline_mutex_ };
    VsyncTimeline* best = nullptr;
    for (auto& [key, timelines] : vsync_timelines_) {
        if (key.first != process_id)
            continue;
        for (auto iterator = timelines.rbegin(); iterator != timelines.rend();
            ++iterator) {
            if ((sequence != 0 && iterator->sequence != sequence) ||
                iterator->callback !=
                    std::chrono::steady_clock::time_point { } ||
                iterator->receiver_processor != 0) {
                continue;
            }
            if (best == nullptr || iterator->due > best->due)
                best = &*iterator;
            break;
        }
    }
    if (best != nullptr) {
        best->received = std::chrono::steady_clock::now();
        best->receiver_processor = processor_id;
    }
}

void PerformanceCounters::record_vsync_callback(std::uint32_t process_id,
    std::uint32_t framebuffer, std::uint64_t sequence,
    std::uint32_t processor_id)
{
    if (!enabled() || process_id == 0 || framebuffer == 0)
        return;
    const auto now = std::chrono::steady_clock::now();
    std::optional<std::uint64_t> due_to_callback;
    std::vector<VsyncTimeline> superseded;
    {
        std::lock_guard lock { vsync_timeline_mutex_ };
        const auto found = vsync_timelines_.find({ process_id, framebuffer });
        if (found == vsync_timelines_.end())
            return;
        auto timeline = found->second.end();
        if (sequence != 0) {
            const auto matching = std::find_if(found->second.rbegin(),
                found->second.rend(), [sequence](const auto& candidate) {
                    return candidate.sequence == sequence;
                });
            if (matching != found->second.rend()) {
                timeline = matching.base();
                --timeline;
            }
        } else {
            const auto pending = std::find_if(found->second.rbegin(),
                found->second.rend(), [](const auto& candidate) {
                    return candidate.callback ==
                           std::chrono::steady_clock::time_point { };
                });
            if (pending != found->second.rend()) {
                timeline = pending.base();
                --timeline;
            }
        }
        if (timeline == found->second.end())
            return;
        superseded.assign(found->second.begin(), timeline);
        found->second.erase(found->second.begin(), timeline);
        auto& current = found->second.front();
        current.callback = now;
        current.callback_processor = processor_id;
        if (current.due != std::chrono::steady_clock::time_point { } &&
            now >= current.due) {
            due_to_callback = static_cast<std::uint64_t>(
                std::chrono::duration_cast<std::chrono::nanoseconds>(
                    now - current.due)
                    .count());
        }
    }
    if (!superseded.empty() &&
        display_window_active_.load(std::memory_order_acquire)) {
        std::lock_guard window_lock { display_window_mutex_ };
        if (display_window_active_.load(std::memory_order_relaxed)) {
            for (const auto& timeline : superseded) {
                if (diagnostic_vsync_frames.size() >=
                    maximum_diagnostic_sequence_samples) {
                    break;
                }
                diagnostic_vsync_frames.push_back(DiagnosticVsyncFrame {
                    timeline.sequence,
                    process_id,
                    framebuffer,
                    0,
                    timeline.due,
                    timeline.received,
                    timeline.callback,
                    timeline.swap_end,
                    { },
                    timeline.receiver_processor,
                    timeline.callback_processor,
                    timeline.swap_end_processor,
                    { },
                });
            }
        }
    }
    if (due_to_callback)
        record_latency(PerfLatencyKind::VsyncDueToCallback, *due_to_callback);
}

void PerformanceCounters::record_vsync_swap_end(std::uint32_t process_id,
    std::uint32_t framebuffer, std::uint32_t processor_id)
{
    if (!enabled() || process_id == 0 || framebuffer == 0)
        return;
    const auto now = std::chrono::steady_clock::now();
    std::optional<std::uint64_t> callback_to_swap_end;
    {
        std::lock_guard lock { vsync_timeline_mutex_ };
        const auto found = vsync_timelines_.find({ process_id, framebuffer });
        if (found == vsync_timelines_.end())
            return;
        const auto timeline = std::find_if(
            found->second.rbegin(), found->second.rend(), [](const auto& item) {
                return item.callback !=
                           std::chrono::steady_clock::time_point { } &&
                       item.swap_end ==
                           std::chrono::steady_clock::time_point { };
            });
        if (timeline == found->second.rend())
            return;
        timeline->swap_end = now;
        timeline->swap_end_processor = processor_id;
        if (now >= timeline->callback) {
            callback_to_swap_end = static_cast<std::uint64_t>(
                std::chrono::duration_cast<std::chrono::nanoseconds>(
                    now - timeline->callback)
                    .count());
        }
    }
    if (callback_to_swap_end) {
        record_latency(
            PerfLatencyKind::VsyncCallbackToSwapEnd, *callback_to_swap_end);
    }
}

void PerformanceCounters::record_vsync_guest_submit(
    std::uint32_t process_id, std::uint32_t framebuffer)
{
    if (!enabled() || process_id == 0 || framebuffer == 0)
        return;
    const auto now = std::chrono::steady_clock::now();
    std::optional<std::uint64_t> swap_end_to_submit;
    std::optional<std::uint64_t> due_to_submit;
    std::optional<VsyncTimeline> completed_timeline;
    {
        std::lock_guard lock { vsync_timeline_mutex_ };
        const auto found = vsync_timelines_.find({ process_id, framebuffer });
        if (found == vsync_timelines_.end())
            return;
        const auto timeline = std::find_if(
            found->second.rbegin(), found->second.rend(), [](const auto& item) {
                return item.swap_end !=
                       std::chrono::steady_clock::time_point { };
            });
        if (timeline == found->second.rend())
            return;
        if (now >= timeline->swap_end) {
            swap_end_to_submit = static_cast<std::uint64_t>(
                std::chrono::duration_cast<std::chrono::nanoseconds>(
                    now - timeline->swap_end)
                    .count());
        }
        if (timeline->due != std::chrono::steady_clock::time_point { } &&
            now >= timeline->due) {
            due_to_submit = static_cast<std::uint64_t>(
                std::chrono::duration_cast<std::chrono::nanoseconds>(
                    now - timeline->due)
                    .count());
        }
        completed_timeline = *timeline;
        const auto erase_end = timeline.base();
        found->second.erase(found->second.begin(), erase_end);
        if (found->second.empty())
            vsync_timelines_.erase(found);
    }
    if (swap_end_to_submit) {
        record_latency(
            PerfLatencyKind::VsyncSwapEndToGuestSubmit, *swap_end_to_submit);
    }
    if (due_to_submit)
        record_latency(PerfLatencyKind::VsyncDueToGuestSubmit, *due_to_submit);

    if (!completed_timeline ||
        !display_window_active_.load(std::memory_order_acquire)) {
        return;
    }
    auto current_work = DiagnosticFrameWork {
        translation_blocks_.load(std::memory_order_relaxed),
        cpu_executions_.load(std::memory_order_relaxed),
        cpu_ticks_.load(std::memory_order_relaxed),
        svc_calls_.load(std::memory_order_relaxed),
        page_misses_.load(std::memory_order_relaxed),
        page_faults_.load(std::memory_order_relaxed),
        draws_.load(std::memory_order_relaxed),
        submits_.load(std::memory_order_relaxed),
        fence_waits_.load(std::memory_order_relaxed),
        fence_wait_nanoseconds_.load(std::memory_order_relaxed),
    };
    for (std::size_t index = 0; index < current_work.submit_reasons.size();
        ++index) {
        current_work.submit_reasons[index] =
            submit_reasons_[index].load(std::memory_order_relaxed);
    }
    current_work.hle_calls =
        diagnostic_hle_calls_.load(std::memory_order_relaxed);
    current_work.hle_nanoseconds =
        diagnostic_hle_nanoseconds_.load(std::memory_order_relaxed);
    for (std::size_t index = 0; index < current_work.graphics_hle_calls.size();
        ++index) {
        current_work.graphics_hle_calls[index] =
            diagnostic_graphics_hle_calls_[index].load(
                std::memory_order_relaxed);
        current_work.graphics_hle_nanoseconds[index] =
            diagnostic_graphics_hle_nanoseconds_[index].load(
                std::memory_order_relaxed);
    }
    std::lock_guard window_lock { display_window_mutex_ };
    if (!display_window_active_.load(std::memory_order_relaxed))
        return;

    std::uint64_t display_sequence { };
    const auto display = std::find_if(diagnostic_display_frames.rbegin(),
        diagnostic_display_frames.rend(), [process_id, now](const auto& frame) {
            return frame.owner_process_id == process_id &&
                   frame.vsync_sequence == 0 &&
                   frame.submitted !=
                       std::chrono::steady_clock::time_point { } &&
                   frame.submitted <= now;
        });
    if (display != diagnostic_display_frames.rend()) {
        display_sequence = display->sequence;
        display->vsync_sequence = completed_timeline->sequence;
        display->framebuffer = framebuffer;
    }
    if (diagnostic_vsync_frames.size() < maximum_diagnostic_sequence_samples) {
        diagnostic_vsync_frames.push_back(DiagnosticVsyncFrame {
            completed_timeline->sequence,
            process_id,
            framebuffer,
            display_sequence,
            completed_timeline->due,
            completed_timeline->received,
            completed_timeline->callback,
            completed_timeline->swap_end,
            now,
            completed_timeline->receiver_processor,
            completed_timeline->callback_processor,
            completed_timeline->swap_end_processor,
            diagnostic_work_delta(current_work, diagnostic_previous_frame_work),
        });
    }
    diagnostic_previous_frame_work = current_work;
}

void PerformanceCounters::discard_pending_vsync_callbacks()
{
    if (!enabled())
        return;
    std::lock_guard lock { vsync_timeline_mutex_ };
    for (auto timeline = vsync_timelines_.begin();
        timeline != vsync_timelines_.end();) {
        std::erase_if(timeline->second, [](const auto& candidate) {
            return candidate.callback !=
                       std::chrono::steady_clock::time_point { } &&
                   candidate.swap_end ==
                       std::chrono::steady_clock::time_point { };
        });
        if (timeline->second.empty()) {
            timeline = vsync_timelines_.erase(timeline);
        } else {
            ++timeline;
        }
    }
}

void PerformanceCounters::record_hle(
    std::string_view subsystem, std::uint64_t nanoseconds)
{
    if (!enabled())
        return;
    diagnostic_hle_calls_.fetch_add(1, std::memory_order_relaxed);
    diagnostic_hle_nanoseconds_.fetch_add(
        nanoseconds, std::memory_order_relaxed);
    auto graphics_kind = PerfDiagnosticGraphicsHleKind::Count;
    if (subsystem == "_mbx2DBlitCopy" || subsystem == "_mbx2DCtxBlitCopy") {
        graphics_kind = PerfDiagnosticGraphicsHleKind::BlitCopy;
    } else if (subsystem == "_mbx2DBlitColor" ||
               subsystem == "_mbx2DCtxBlitColor") {
        graphics_kind = PerfDiagnosticGraphicsHleKind::BlitColor;
    } else if (subsystem == "_mbx3DQuadCopy") {
        graphics_kind = PerfDiagnosticGraphicsHleKind::QuadCopy;
    }
    if (graphics_kind != PerfDiagnosticGraphicsHleKind::Count)
        record_diagnostic_graphics_hle(graphics_kind, nanoseconds);
    std::lock_guard lock { hle_mutex_ };
    auto [found, inserted] =
        hle_subsystems_.try_emplace(std::string { subsystem });
    auto& stats = found->second;
    if (inserted)
        stats.subsystem = subsystem;
    ++stats.calls;
    stats.nanoseconds += nanoseconds;
}

void PerformanceCounters::record_cpu_run_phases(std::uint32_t process_id,
    std::uint32_t processor_id, std::uint32_t execution_slot,
    std::chrono::steady_clock::time_point started_at,
    std::chrono::steady_clock::time_point ended_at,
    std::span<const std::uint64_t> phase_nanoseconds,
    std::uint64_t requested_ticks, std::uint64_t consumed_ticks,
    std::uint64_t host_yield_checks, bool host_yielded, std::uint64_t svc_calls,
    std::optional<std::uint32_t> svc, std::uint32_t halt_reason)
{
    constexpr auto first_kind =
        static_cast<std::size_t>(PerfLatencyKind::CpuRunLockWait);
    constexpr auto last_kind =
        static_cast<std::size_t>(PerfLatencyKind::CpuRunTotal);
    constexpr auto expected_count = last_kind - first_kind + 1U;
    if (!cpu_source_diagnostics_enabled() ||
        phase_nanoseconds.size() != expected_count) {
        return;
    }
    for (std::size_t index = 0; index < phase_nanoseconds.size(); ++index) {
        record_global_latency(static_cast<PerfLatencyKind>(first_kind + index),
            phase_nanoseconds[index]);
    }
    std::lock_guard lock { display_window_mutex_ };
    if (!display_window_active_.load(std::memory_order_relaxed))
        return;
    for (std::size_t index = 0; index < phase_nanoseconds.size(); ++index) {
        record_display_window_latency_locked(
            static_cast<PerfLatencyKind>(first_kind + index),
            phase_nanoseconds[index]);
    }
    {
        std::lock_guard process_lock { diagnostic_process_mutex_ };
        auto [found, inserted] = diagnostic_processes_.try_emplace(
            process_id, DiagnosticProcessSnapshot { });
        auto& process = found->second;
        if (inserted)
            process.process_id = process_id;
        const auto phase = [&](PerfLatencyKind kind) {
            return phase_nanoseconds[static_cast<std::size_t>(kind) -
                                     first_kind];
        };
        ++process.cpu_runs;
        process.cpu_ticks += consumed_ticks;
        process.cpu_execute_nanoseconds +=
            phase(PerfLatencyKind::CpuRunExecute);
        process.cpu_total_nanoseconds += phase(PerfLatencyKind::CpuRunTotal);
        process.cpu_ensure_jit_nanoseconds +=
            phase(PerfLatencyKind::CpuRunEnsureJit);
        process.cpu_invalidation_nanoseconds +=
            phase(PerfLatencyKind::CpuRunInvalidation);
        process.cpu_artifact_preload_nanoseconds +=
            phase(PerfLatencyKind::CpuRunArtifactPreload);
        process.svc_calls += svc_calls;
        process.host_yield_checks += host_yield_checks;
        if (host_yielded)
            ++process.host_yields;
    }
    if (phase_nanoseconds.back() >= minimum_diagnostic_cpu_run_nanoseconds &&
        diagnostic_cpu_runs.size() < maximum_diagnostic_sequence_samples) {
        DiagnosticCpuRun run;
        run.process_id = process_id;
        run.processor_id = processor_id;
        run.execution_slot = execution_slot;
        run.started = started_at;
        run.ended = ended_at;
        std::copy(phase_nanoseconds.begin(), phase_nanoseconds.end(),
            run.phase_nanoseconds.begin());
        run.requested_ticks = requested_ticks;
        run.consumed_ticks = consumed_ticks;
        run.host_yield_checks = host_yield_checks;
        run.host_yielded = host_yielded;
        run.svc_calls = svc_calls;
        run.svc = svc;
        run.halt_reason = halt_reason;
        diagnostic_cpu_runs.push_back(run);
    }
}

void PerformanceCounters::record_diagnostic_scheduler_dispatch(
    std::uint32_t process_id, std::uint32_t thread_id,
    std::uint64_t runnable_generation, bool front_continuation,
    std::uint64_t nanoseconds)
{
    if (!cpu_source_diagnostics_enabled())
        return;
    const auto kind = front_continuation
                          ? PerfDiagnosticSourceKind::SchedulerFront
                          : PerfDiagnosticSourceKind::SchedulerBack;
    if (runnable_generation == 0 ||
        diagnostic_source_key(kind, process_id, thread_id) == 0) {
        record_diagnostic_source(
            kind, process_id, thread_id, runnable_generation, nanoseconds);
        return;
    }
    record_latency(PerfLatencyKind::SchedulerRunnableToDispatch, nanoseconds);
    record_diagnostic_source(
        kind, process_id, thread_id, runnable_generation, nanoseconds);
}

void PerformanceCounters::record_diagnostic_svc_dispatch(
    PerfDiagnosticSourceKind kind, std::uint32_t process_id,
    std::uint32_t number, std::uint64_t nanoseconds)
{
    if (!cpu_source_diagnostics_enabled())
        return;
    record_diagnostic_source(kind, process_id, number, 0, nanoseconds);
}

void PerformanceCounters::record_diagnostic_source(
    PerfDiagnosticSourceKind kind, std::uint32_t process_id,
    std::uint32_t number, std::uint64_t runnable_generation,
    std::uint64_t nanoseconds)
{
    if (!cpu_source_diagnostics_enabled())
        return;
    if (runnable_generation == 0 &&
        (kind == PerfDiagnosticSourceKind::SchedulerBack ||
            kind == PerfDiagnosticSourceKind::SchedulerFront)) {
        diagnostic_source_dropped_.fetch_add(1, std::memory_order_relaxed);
        return;
    }
    const auto key = diagnostic_source_key(kind, process_id, number);
    if (key == 0) {
        diagnostic_source_dropped_.fetch_add(1, std::memory_order_relaxed);
        return;
    }

    std::lock_guard source_lock { diagnostic_source_mutex_ };

    const auto use = ++diagnostic_source_use_clock_;
    auto index = diagnostic_source_index(key, runnable_generation);
    std::optional<std::size_t> empty_index;
    for (std::size_t probe = 0; probe < diagnostic_source_capacity; ++probe) {
        auto& source = diagnostic_source_counters_[index];
        const auto observed = source.key.load(std::memory_order_relaxed);
        const auto observed_generation =
            source.runnable_generation.load(std::memory_order_relaxed);
        if (observed == key && observed_generation == runnable_generation) {
            source.calls.fetch_add(1, std::memory_order_relaxed);
            source.nanoseconds.fetch_add(
                nanoseconds, std::memory_order_relaxed);
            source.last_used.store(use, std::memory_order_relaxed);
            diagnostic_source_updated_.fetch_add(1, std::memory_order_relaxed);
            return;
        }
        if (observed == 0) {
            empty_index = index;
            break;
        }
        index = (index + 1U) & (diagnostic_source_capacity - 1U);
    }

    std::optional<std::size_t> target = empty_index;
    if (!target) {
        std::uint64_t least_recent_use =
            std::numeric_limits<std::uint64_t>::max();
        for (std::size_t slot = 0; slot < diagnostic_source_capacity; ++slot) {
            auto& source = diagnostic_source_counters_[slot];
            const auto last_used =
                source.last_used.load(std::memory_order_relaxed);
            if (!target || last_used < least_recent_use) {
                least_recent_use = last_used;
                target = slot;
            }
        }
    }
    const auto target_index = *target;
    auto& source = diagnostic_source_counters_[target_index];
    if (!empty_index) {
        diagnostic_source_evicted_.fetch_add(1, std::memory_order_relaxed);
    } else {
        const auto occupancy = diagnostic_source_occupancy_.fetch_add(
                                   1, std::memory_order_relaxed) +
                               1;
        auto peak =
            diagnostic_source_peak_occupancy_.load(std::memory_order_relaxed);
        while (occupancy > peak &&
               !diagnostic_source_peak_occupancy_.compare_exchange_weak(peak,
                   occupancy, std::memory_order_relaxed,
                   std::memory_order_relaxed)) { }
    }
    source.calls.store(1, std::memory_order_relaxed);
    source.nanoseconds.store(nanoseconds, std::memory_order_relaxed);
    source.runnable_generation.store(
        runnable_generation, std::memory_order_relaxed);
    source.last_used.store(use, std::memory_order_relaxed);
    source.key.store(key, std::memory_order_relaxed);
    diagnostic_source_inserted_.fetch_add(1, std::memory_order_relaxed);
}

void PerformanceCounters::record_diagnostic_graphics_hle(
    PerfDiagnosticGraphicsHleKind kind, std::uint64_t nanoseconds)
{
    const auto index = static_cast<std::size_t>(kind);
    if (!enabled() || index >= diagnostic_graphics_hle_calls_.size())
        return;
    diagnostic_graphics_hle_calls_[index].fetch_add(
        1, std::memory_order_relaxed);
    diagnostic_graphics_hle_nanoseconds_[index].fetch_add(
        nanoseconds, std::memory_order_relaxed);
}

void PerformanceCounters::record_fork() { add_if_enabled(forks_, enabled_); }

void PerformanceCounters::record_exec() { add_if_enabled(execs_, enabled_); }

void PerformanceCounters::record_abnormal_exit()
{
    add_if_enabled(abnormal_exits_, enabled_);
}

void PerformanceCounters::record_fallback(PerfFallbackReason reason)
{
    const auto index = static_cast<std::size_t>(reason);
    if (!enabled() || reason == PerfFallbackReason::None ||
        index >= fallback_reasons_.size()) {
        return;
    }
    fallback_reasons_[index].fetch_add(1, std::memory_order_relaxed);
}

void PerformanceCounters::record_global_latency(
    PerfLatencyKind kind, std::uint64_t nanoseconds)
{
    const auto index = static_cast<std::size_t>(kind);
    if (index >= latencies_.size())
        return;
    auto& histogram = latencies_[index];
    histogram.buckets[latency_bucket(nanoseconds)].fetch_add(
        1, std::memory_order_relaxed);
    histogram.samples.fetch_add(1, std::memory_order_relaxed);
    histogram.total_nanoseconds.fetch_add(
        nanoseconds, std::memory_order_relaxed);
    if (nanoseconds > one_sixtieth_second)
        histogram.over_16_7ms.fetch_add(1, std::memory_order_relaxed);
    if (nanoseconds > twenty_milliseconds)
        histogram.over_20ms.fetch_add(1, std::memory_order_relaxed);
    if (nanoseconds > one_thirtieth_second)
        histogram.over_33_3ms.fetch_add(1, std::memory_order_relaxed);
    if (nanoseconds > fifty_milliseconds)
        histogram.over_50ms.fetch_add(1, std::memory_order_relaxed);
    auto maximum =
        histogram.maximum_nanoseconds.load(std::memory_order_relaxed);
    while (nanoseconds > maximum &&
           !histogram.maximum_nanoseconds.compare_exchange_weak(maximum,
               nanoseconds, std::memory_order_relaxed,
               std::memory_order_relaxed)) { }
}

void PerformanceCounters::record_display_window_latency_locked(
    PerfLatencyKind kind, std::uint64_t nanoseconds)
{
    const auto index = static_cast<std::size_t>(kind);
    if (!is_display_window_latency(kind) ||
        index >= display_window_latencies_.size()) {
        return;
    }
    auto& histogram = display_window_latencies_[index];
    ++histogram.buckets[latency_bucket(nanoseconds)];
    ++histogram.samples;
    histogram.total_nanoseconds += nanoseconds;
    if (nanoseconds > one_sixtieth_second)
        ++histogram.over_16_7ms;
    if (nanoseconds > twenty_milliseconds)
        ++histogram.over_20ms;
    if (nanoseconds > one_thirtieth_second)
        ++histogram.over_33_3ms;
    if (nanoseconds > fifty_milliseconds)
        ++histogram.over_50ms;
    histogram.maximum_nanoseconds =
        std::max(histogram.maximum_nanoseconds, nanoseconds);
    if (const auto sequence = diagnostic_sequence_index(kind);
        sequence && diagnostic_display_sequences[*sequence].size() <
                        maximum_diagnostic_sequence_samples) {
        diagnostic_display_sequences[*sequence].push_back(nanoseconds);
    }
}

void PerformanceCounters::record_display_window_latency(
    PerfLatencyKind kind, std::uint64_t nanoseconds)
{
    if (!is_display_window_latency(kind) ||
        !display_window_active_.load(std::memory_order_acquire)) {
        return;
    }
    std::lock_guard lock { display_window_mutex_ };
    if (!display_window_active_.load(std::memory_order_relaxed))
        return;
    record_display_window_latency_locked(kind, nanoseconds);
}

void PerformanceCounters::record_latency(
    PerfLatencyKind kind, std::uint64_t nanoseconds)
{
    const auto index = static_cast<std::size_t>(kind);
    if (!enabled() || index >= latencies_.size())
        return;
    record_global_latency(kind, nanoseconds);
    record_display_window_latency(kind, nanoseconds);
}

PerformanceSnapshot PerformanceCounters::snapshot() const
{
    PerformanceSnapshot result;
    result.jit_instances = jit_instances_.load(std::memory_order_relaxed);
    result.jit_live_instances =
        jit_live_instances_.load(std::memory_order_relaxed);
    result.jit_live_peak_instances =
        jit_live_peak_instances_.load(std::memory_order_relaxed);
    result.jit_creation_nanoseconds =
        jit_creation_nanoseconds_.load(std::memory_order_relaxed);
    result.jit_code_cache_bytes =
        jit_code_cache_current_bytes_.load(std::memory_order_relaxed);
    result.jit_code_cache_peak_bytes =
        jit_code_cache_peak_bytes_.load(std::memory_order_relaxed);
    result.jit_shared_reserved_bytes =
        jit_shared_reserved_bytes_.load(std::memory_order_relaxed);
    result.jit_shared_committed_bytes =
        jit_shared_committed_bytes_.load(std::memory_order_relaxed);
    result.jit_shared_used_bytes =
        jit_shared_used_bytes_.load(std::memory_order_relaxed);
    result.jit_executor_local_bytes =
        jit_executor_local_bytes_.load(std::memory_order_relaxed);
    result.jit_executor_local_peak_bytes =
        jit_executor_local_peak_bytes_.load(std::memory_order_relaxed);
    result.jit_shared_invalidation_requests =
        jit_shared_invalidation_requests_.load(std::memory_order_relaxed);
    result.jit_full_invalidation_requests =
        jit_full_invalidation_requests_.load(std::memory_order_relaxed);
    result.jit_range_invalidation_requests =
        jit_range_invalidation_requests_.load(std::memory_order_relaxed);
    result.jit_slab_generation_transitions =
        jit_slab_generation_transitions_.load(std::memory_order_relaxed);
    result.jit_shared_range_count =
        jit_shared_range_count_.load(std::memory_order_relaxed);
    result.jit_shared_descriptor_count =
        jit_shared_descriptor_count_.load(std::memory_order_relaxed);
    result.jit_invalidated_descriptors =
        jit_invalidated_descriptors_.load(std::memory_order_relaxed);
    result.jit_retired_code_bytes =
        jit_retired_code_bytes_.load(std::memory_order_relaxed);
    result.jit_segment_recycles =
        jit_segment_recycles_.load(std::memory_order_relaxed);
    result.jit_recycled_descriptors =
        jit_recycled_descriptors_.load(std::memory_order_relaxed);
    result.jit_recycled_code_bytes =
        jit_recycled_code_bytes_.load(std::memory_order_relaxed);
    result.jit_full_generation_clears =
        jit_full_generation_clears_.load(std::memory_order_relaxed);
    result.jit_fast_link_hits =
        jit_fast_link_hits_.load(std::memory_order_relaxed);
    result.jit_fast_link_misses =
        jit_fast_link_misses_.load(std::memory_order_relaxed);
    result.jit_stable_table_probes =
        jit_stable_table_probes_.load(std::memory_order_relaxed);
    result.jit_stable_table_collisions =
        jit_stable_table_collisions_.load(std::memory_order_relaxed);
    result.jit_rsb_hits = jit_rsb_hits_.load(std::memory_order_relaxed);
    result.jit_rsb_misses = jit_rsb_misses_.load(std::memory_order_relaxed);
    result.jit_stable_link_hits = result.jit_fast_link_hits;
    result.jit_stable_link_misses = result.jit_fast_link_misses;
    result.jit_host_yield_checks =
        jit_host_yield_checks_.load(std::memory_order_relaxed);
    result.jit_host_yields = jit_host_yields_.load(std::memory_order_relaxed);
    result.jit_host_slice_budget_samples =
        jit_host_slice_budget_samples_.load(std::memory_order_relaxed);
    result.jit_host_slice_budget_total_nanoseconds =
        jit_host_slice_budget_total_nanoseconds_.load(
            std::memory_order_relaxed);
    result.jit_host_slice_budget_min_nanoseconds =
        jit_host_slice_budget_min_nanoseconds_.load(std::memory_order_relaxed);
    result.jit_host_slice_budget_max_nanoseconds =
        jit_host_slice_budget_max_nanoseconds_.load(std::memory_order_relaxed);
    result.jit_demand_artifact_probes =
        jit_demand_artifact_probes_.load(std::memory_order_relaxed);
    result.jit_demand_artifact_hits =
        jit_demand_artifact_hits_.load(std::memory_order_relaxed);
    result.jit_demand_artifact_misses =
        jit_demand_artifact_misses_.load(std::memory_order_relaxed);
    result.scheduler_runnable_transitions =
        scheduler_runnable_transitions_.load(std::memory_order_relaxed);
    result.scheduler_dispatches =
        scheduler_dispatches_.load(std::memory_order_relaxed);
    result.scheduler_wakeups =
        scheduler_wakeups_.load(std::memory_order_relaxed);
    result.scheduler_wake_pending =
        scheduler_wake_pending_.load(std::memory_order_relaxed);
    result.scheduler_blocks = scheduler_blocks_.load(std::memory_order_relaxed);
    result.scheduler_preemption_checks =
        scheduler_preemption_checks_.load(std::memory_order_relaxed);
    result.scheduler_preemptions =
        scheduler_preemptions_.load(std::memory_order_relaxed);
    result.scheduler_urgent_preemptions =
        scheduler_urgent_preemptions_.load(std::memory_order_relaxed);
    result.scheduler_preemption_requests =
        scheduler_preemption_requests_.load(std::memory_order_relaxed);
    result.scheduler_preemption_coalesced =
        scheduler_preemption_coalesced_.load(std::memory_order_relaxed);
    result.scheduler_preemption_returns =
        scheduler_preemption_returns_.load(std::memory_order_relaxed);
    result.scheduler_preemption_deferred_consumes =
        scheduler_preemption_deferred_consumes_.load(std::memory_order_relaxed);
    result.scheduler_quantum_expirations =
        scheduler_quantum_expirations_.load(std::memory_order_relaxed);
    result.translation_blocks =
        translation_blocks_.load(std::memory_order_relaxed);
    result.translation_blocks_shared_region =
        translation_blocks_shared_region_.load(std::memory_order_relaxed);
    result.cpu_executions = cpu_executions_.load(std::memory_order_relaxed);
    result.cpu_ticks = cpu_ticks_.load(std::memory_order_relaxed);
    result.svc_calls = svc_calls_.load(std::memory_order_relaxed);
    result.page_misses = page_misses_.load(std::memory_order_relaxed);
    result.page_faults = page_faults_.load(std::memory_order_relaxed);
    result.draws = draws_.load(std::memory_order_relaxed);
    result.submits = submits_.load(std::memory_order_relaxed);
    for (std::size_t index = 0; index < result.submit_reasons.size(); ++index) {
        result.submit_reasons[index] =
            submit_reasons_[index].load(std::memory_order_relaxed);
    }
    result.fence_waits = fence_waits_.load(std::memory_order_relaxed);
    result.fence_wait_nanoseconds =
        fence_wait_nanoseconds_.load(std::memory_order_relaxed);
    result.upload_bytes = upload_bytes_.load(std::memory_order_relaxed);
    result.readback_bytes = readback_bytes_.load(std::memory_order_relaxed);
    result.host_fills = host_fills_.load(std::memory_order_relaxed);
    result.host_copies = host_copies_.load(std::memory_order_relaxed);
    result.display_submissions =
        display_submissions_.load(std::memory_order_relaxed);
    result.display_first_nanoseconds =
        display_first_nanoseconds_.load(std::memory_order_relaxed);
    result.display_last_nanoseconds =
        display_last_nanoseconds_.load(std::memory_order_relaxed);
    result.display_mailbox_coalesced =
        display_mailbox_coalesced_.load(std::memory_order_relaxed);
    result.display_vsync_queued =
        display_vsync_queued_.load(std::memory_order_relaxed);
    result.display_vsync_coalesced =
        display_vsync_coalesced_.load(std::memory_order_relaxed);
    result.display_vsync_budget_cuts =
        display_vsync_budget_cuts_.load(std::memory_order_relaxed);
    result.display_vsync_budget_saved_ticks =
        display_vsync_budget_saved_ticks_.load(std::memory_order_relaxed);
    result.display_queue_depth =
        display_queue_depth_.load(std::memory_order_relaxed);
    result.display_queue_high_watermark =
        display_queue_high_watermark_.load(std::memory_order_relaxed);
    result.display_queue_backpressure_waits =
        display_queue_backpressure_waits_.load(std::memory_order_relaxed);
    result.display_queue_backpressure_max_wait_nanoseconds =
        display_queue_backpressure_max_wait_nanoseconds_.load(
            std::memory_order_relaxed);
    result.display_queue_backpressure_timeouts =
        display_queue_backpressure_timeouts_.load(std::memory_order_relaxed);
    result.sdl_idle_waits = sdl_idle_waits_.load(std::memory_order_relaxed);
    result.native_present_attempts =
        native_present_attempts_.load(std::memory_order_relaxed);
    result.native_present_mailbox_coalesced =
        native_present_mailbox_coalesced_.load(std::memory_order_relaxed);
    result.native_present_skipped =
        native_present_skipped_.load(std::memory_order_relaxed);
    result.native_present_failures =
        native_present_failures_.load(std::memory_order_relaxed);
    result.native_presents = native_presents_.load(std::memory_order_relaxed);
    result.present_first_nanoseconds =
        present_first_nanoseconds_.load(std::memory_order_relaxed);
    result.present_last_nanoseconds =
        present_last_nanoseconds_.load(std::memory_order_relaxed);
    result.cpu_present_fallbacks =
        cpu_present_fallbacks_.load(std::memory_order_relaxed);
    result.cpu_map_reads = cpu_map_reads_.load(std::memory_order_relaxed);
    result.cpu_map_writes = cpu_map_writes_.load(std::memory_order_relaxed);
    result.forks = forks_.load(std::memory_order_relaxed);
    result.execs = execs_.load(std::memory_order_relaxed);
    result.abnormal_exits = abnormal_exits_.load(std::memory_order_relaxed);
    for (std::size_t index = 0; index < perf_cpu_map_reason_count; ++index) {
        result.cpu_map_read_reasons[index] =
            cpu_map_read_reasons_[index].load(std::memory_order_relaxed);
        result.cpu_map_write_reasons[index] =
            cpu_map_write_reasons_[index].load(std::memory_order_relaxed);
    }
    for (std::size_t index = 0; index < perf_surface_kind_count; ++index) {
        result.surface_upload_bytes[index] =
            surface_upload_bytes_[index].load(std::memory_order_relaxed);
        result.surface_readback_bytes[index] =
            surface_readback_bytes_[index].load(std::memory_order_relaxed);
    }
    for (std::size_t index = 0; index < fallback_reasons_.size(); ++index) {
        result.fallback_reasons[index] =
            fallback_reasons_[index].load(std::memory_order_relaxed);
    }
    for (std::size_t index = 0; index < latencies_.size(); ++index) {
        const auto& histogram = latencies_[index];
        auto& latency = result.latencies[index];
        latency.samples = histogram.samples.load(std::memory_order_relaxed);
        latency.total_nanoseconds =
            histogram.total_nanoseconds.load(std::memory_order_relaxed);
        latency.maximum_nanoseconds =
            histogram.maximum_nanoseconds.load(std::memory_order_relaxed);
        latency.over_16_7ms =
            histogram.over_16_7ms.load(std::memory_order_relaxed);
        latency.over_20ms = histogram.over_20ms.load(std::memory_order_relaxed);
        latency.over_33_3ms =
            histogram.over_33_3ms.load(std::memory_order_relaxed);
        latency.over_50ms = histogram.over_50ms.load(std::memory_order_relaxed);
        if (latency.samples == 0)
            continue;
        const auto percentile = [&](std::uint64_t numerator) {
            const auto rank = (latency.samples * numerator + 99U) / 100U;
            std::uint64_t cumulative { };
            for (std::size_t bucket = 0; bucket < histogram.buckets.size();
                ++bucket) {
                cumulative +=
                    histogram.buckets[bucket].load(std::memory_order_relaxed);
                if (cumulative >= rank) {
                    return latency_bucket_upper_bound(
                        bucket, latency.maximum_nanoseconds);
                }
            }
            return latency.maximum_nanoseconds;
        };
        latency.p50_nanoseconds = percentile(50);
        latency.p95_nanoseconds = percentile(95);
        latency.p99_nanoseconds = percentile(99);
    }
    {
        std::lock_guard lock { jit_cache_slots_mutex_ };
        result.jit_cache_slots.reserve(jit_cache_slots_.size());
        for (const auto& [key, usage] : jit_cache_slots_) {
            static_cast<void>(key);
            result.jit_cache_slots.push_back(usage);
        }
    }
    {
        std::lock_guard lock { hle_mutex_ };
        result.hle_subsystems.reserve(hle_subsystems_.size());
        for (const auto& [name, stats] : hle_subsystems_) {
            static_cast<void>(name);
            result.hle_subsystems.push_back(stats);
        }
    }
    {
        std::lock_guard process_lock { diagnostic_process_mutex_ };
        result.diagnostic_processes.reserve(diagnostic_processes_.size());
        for (const auto& [process_id, stats] : diagnostic_processes_) {
            static_cast<void>(process_id);
            result.diagnostic_processes.push_back(stats);
        }
    }
    {
        std::lock_guard source_lock { diagnostic_source_mutex_ };
        for (const auto& source : diagnostic_source_counters_) {
            const auto key = source.key.load(std::memory_order_relaxed);
            if (key == 0)
                continue;
            result.diagnostic_sources.push_back(diagnostic_source_snapshot(key,
                source.runnable_generation.load(std::memory_order_relaxed),
                source.calls.load(std::memory_order_relaxed),
                source.nanoseconds.load(std::memory_order_relaxed)));
        }
    }
    result.diagnostic_source_inserted =
        diagnostic_source_inserted_.load(std::memory_order_relaxed);
    result.diagnostic_source_updated =
        diagnostic_source_updated_.load(std::memory_order_relaxed);
    result.diagnostic_source_evicted =
        diagnostic_source_evicted_.load(std::memory_order_relaxed);
    result.diagnostic_source_dropped =
        diagnostic_source_dropped_.load(std::memory_order_relaxed);
    result.diagnostic_source_capacity = diagnostic_source_capacity;
    result.diagnostic_source_peak_occupancy =
        diagnostic_source_peak_occupancy_.load(std::memory_order_relaxed);
    return result;
}

PerformanceCounters& performance_counters()
{
    static PerformanceCounters counters;
    return counters;
}

PerformanceLatencyScope::PerformanceLatencyScope(
    PerfLatencyKind kind, bool enabled)
    : kind_ { kind }
    , enabled_ { enabled && performance_counters().enabled() }
    , started_ { enabled_ ? std::chrono::steady_clock::now()
                          : std::chrono::steady_clock::time_point { } }
{
}

PerformanceLatencyScope::~PerformanceLatencyScope()
{
    if (!enabled_)
        return;
    const auto elapsed = std::chrono::steady_clock::now() - started_;
    performance_counters().record_latency(
        kind_, static_cast<std::uint64_t>(
                   std::chrono::duration_cast<std::chrono::nanoseconds>(elapsed)
                       .count()));
}

std::string_view perf_fallback_reason_name(PerfFallbackReason reason)
{
    switch (reason) {
    case PerfFallbackReason::None:
        return "none";
    case PerfFallbackReason::VulkanUnavailable:
        return "vulkan-unavailable";
    case PerfFallbackReason::InvalidTarget:
        return "invalid-target";
    case PerfFallbackReason::UnsupportedPrimitive:
        return "unsupported-primitive";
    case PerfFallbackReason::InvalidVertex:
        return "invalid-vertex";
    case PerfFallbackReason::UnsupportedBlend:
        return "unsupported-blend";
    case PerfFallbackReason::PipelineUnavailable:
        return "pipeline-unavailable";
    case PerfFallbackReason::TargetBusy:
        return "target-busy";
    case PerfFallbackReason::BackendFailure:
        return "backend-failure";
    case PerfFallbackReason::Count:
        break;
    }
    return "unknown";
}

std::string_view perf_cpu_map_reason_name(PerfCpuMapReason reason)
{
    switch (reason) {
    case PerfCpuMapReason::Internal:
        return "internal";
    case PerfCpuMapReason::HostUpload:
        return "host-upload";
    case PerfCpuMapReason::GpuReadback:
        return "gpu-readback";
    case PerfCpuMapReason::CoreSurface:
        return "core-surface";
    case PerfCpuMapReason::SoftwareFallback:
        return "software-fallback";
    case PerfCpuMapReason::DeferredDisplayRead:
        return "deferred-display-read";
    case PerfCpuMapReason::NativePresent:
        return "native-present";
    case PerfCpuMapReason::Count:
        break;
    }
    return "unknown";
}

std::string_view perf_surface_kind_name(PerfSurfaceKind kind)
{
    switch (kind) {
    case PerfSurfaceKind::Unknown:
        return "unknown";
    case PerfSurfaceKind::CoreSurface:
        return "core-surface";
    case PerfSurfaceKind::Scanout:
        return "scanout";
    case PerfSurfaceKind::GlesRenderTarget:
        return "gles-target";
    case PerfSurfaceKind::Count:
        break;
    }
    return "unknown";
}

std::string_view perf_latency_kind_name(PerfLatencyKind kind)
{
    switch (kind) {
    case PerfLatencyKind::InputEnqueue:
        return "input-enqueue";
    case PerfLatencyKind::DisplayPresent:
        return "display-present";
    case PerfLatencyKind::DisplayMailbox:
        return "display-mailbox";
    case PerfLatencyKind::NativeMailbox:
        return "native-mailbox";
    case PerfLatencyKind::Acquire:
        return "acquire";
    case PerfLatencyKind::QueuePresent:
        return "queue-present";
    case PerfLatencyKind::PresentReturn:
        return "present-return";
    case PerfLatencyKind::PresentInterval:
        return "present-interval";
    case PerfLatencyKind::VsyncDueToCallback:
        return "vsync-due-callback";
    case PerfLatencyKind::VsyncCallbackToSwapEnd:
        return "vsync-callback-swap-end";
    case PerfLatencyKind::VsyncSwapEndToGuestSubmit:
        return "vsync-swap-end-guest-submit";
    case PerfLatencyKind::VsyncDueToGuestSubmit:
        return "vsync-due-guest-submit";
    case PerfLatencyKind::JitColdPath:
        return "jit-cold-path";
    case PerfLatencyKind::JitDemandTranslation:
        return "jit-demand-translation";
    case PerfLatencyKind::JitBlockCompile:
        return "jit-block-compile";
    case PerfLatencyKind::RuntimeDestructor:
        return "runtime-destructor";
    case PerfLatencyKind::GlesTargetRelease:
        return "gles-target-release";
    case PerfLatencyKind::PosixSpawnTotal:
        return "posix-spawn-total";
    case PerfLatencyKind::PosixSpawnDecode:
        return "posix-spawn-decode";
    case PerfLatencyKind::PosixSpawnFork:
        return "posix-spawn-fork";
    case PerfLatencyKind::PosixSpawnCreate:
        return "posix-spawn-create";
    case PerfLatencyKind::ProcessFreshMemory:
        return "process-fresh-memory";
    case PerfLatencyKind::ProcessCloneMemory:
        return "process-clone-memory";
    case PerfLatencyKind::ProcessCreateCpu:
        return "process-create-cpu";
    case PerfLatencyKind::ProcessCreateKernel:
        return "process-create-kernel";
    case PerfLatencyKind::ProcessInheritKernel:
        return "process-inherit-kernel";
    case PerfLatencyKind::ProcessInheritSpawnKernel:
        return "process-inherit-spawn-kernel";
    case PerfLatencyKind::ProcessConfigureRuntime:
        return "process-configure-runtime";
    case PerfLatencyKind::SpawnMemoryClear:
        return "spawn-memory-clear";
    case PerfLatencyKind::SpawnImageLoad:
        return "spawn-image-load";
    case PerfLatencyKind::SpawnResetRuntime:
        return "spawn-reset-runtime";
    case PerfLatencyKind::CpuRunLockWait:
        return "cpu-run-lock-wait";
    case PerfLatencyKind::CpuRunSharedWriteSync:
        return "cpu-run-shared-write-sync";
    case PerfLatencyKind::CpuRunEnsureJit:
        return "cpu-run-ensure-jit";
    case PerfLatencyKind::CpuRunInvalidation:
        return "cpu-run-invalidation";
    case PerfLatencyKind::CpuRunLoadState:
        return "cpu-run-load-state";
    case PerfLatencyKind::CpuRunCallbacksBegin:
        return "cpu-run-callbacks-begin";
    case PerfLatencyKind::CpuRunArtifactPreload:
        return "cpu-run-artifact-preload";
    case PerfLatencyKind::CpuRunExecute:
        return "cpu-run-execute";
    case PerfLatencyKind::CpuRunResult:
        return "cpu-run-result";
    case PerfLatencyKind::CpuRunSaveState:
        return "cpu-run-save-state";
    case PerfLatencyKind::CpuRunCacheAccounting:
        return "cpu-run-cache-accounting";
    case PerfLatencyKind::CpuRunTotal:
        return "cpu-run-total";
    case PerfLatencyKind::SchedulerSelection:
        return "scheduler-selection";
    case PerfLatencyKind::GuestExecutionBudget:
        return "guest-execution-budget";
    case PerfLatencyKind::SchedulerPreemptionCheck:
        return "scheduler-preemption-check";
    case PerfLatencyKind::SchedulerSliceCompletion:
        return "scheduler-slice-completion";
    case PerfLatencyKind::SchedulerRunnableToDispatch:
        return "scheduler-runnable-dispatch";
    case PerfLatencyKind::SchedulerPreemptionRequestToReturn:
        return "scheduler-preemption-request-return";
    case PerfLatencyKind::MachMessageSendToReceive:
        return "mach-message-send-to-receive";
    case PerfLatencyKind::Count:
        break;
    }
    return "unknown";
}

void append_diagnostic_process_summary(std::ostringstream& text,
    const std::vector<DiagnosticProcessSnapshot>& processes)
{
    text << " diagnostic-process-format="
            "pid:runs/ticks/execute-ns/total-ns/ensure-jit-ns/"
            "invalidation-ns/artifact-preload-ns/svc/yields/yield-checks/"
            "jit-demand/jit-demand-ns/segment-recycles/recycled-descriptors/"
            "recycled-code-bytes/full-generation-clears/jit-slab-generations"
         << " diagnostic-process=";
    if (processes.empty()) {
        text << "none";
        return;
    }
    for (std::size_t index = 0; index < processes.size(); ++index) {
        if (index != 0)
            text << ',';
        const auto& process = processes[index];
        text << process.process_id << ':' << process.cpu_runs << '/'
             << process.cpu_ticks << '/' << process.cpu_execute_nanoseconds
             << '/' << process.cpu_total_nanoseconds << '/'
             << process.cpu_ensure_jit_nanoseconds << '/'
             << process.cpu_invalidation_nanoseconds << '/'
             << process.cpu_artifact_preload_nanoseconds << '/'
             << process.svc_calls << '/' << process.host_yields << '/'
             << process.host_yield_checks << '/'
             << process.jit_demand_translations << '/'
             << process.jit_demand_translation_nanoseconds << '/'
             << process.jit_segment_recycles << '/'
             << process.jit_recycled_descriptors << '/'
             << process.jit_recycled_code_bytes << '/'
             << process.jit_full_generation_clears << '/'
             << process.jit_slab_generation_transitions;
    }
}

std::string format_performance_summary(const PerformanceSnapshot& snapshot)
{
    std::uint64_t fallback_total = 0;
    for (const auto count : snapshot.fallback_reasons)
        fallback_total += count;
    const auto host_budget_average =
        snapshot.jit_host_slice_budget_samples == 0
            ? 0
            : snapshot.jit_host_slice_budget_total_nanoseconds /
                  snapshot.jit_host_slice_budget_samples;

    std::ostringstream text;
    text << "[perf] jit=" << snapshot.jit_instances
         << " jit-live=" << snapshot.jit_live_instances
         << " jit-live-peak=" << snapshot.jit_live_peak_instances
         << " jit-create-ns=" << snapshot.jit_creation_nanoseconds
         << " jit-shared-reserved=" << snapshot.jit_shared_reserved_bytes
         << " jit-shared-committed=" << snapshot.jit_shared_committed_bytes
         << " jit-shared-used=" << snapshot.jit_shared_used_bytes
         << " jit-executor-local=" << snapshot.jit_executor_local_bytes
         << " jit-executor-local-peak="
         << snapshot.jit_executor_local_peak_bytes
         << " jit-cache-bytes=" << snapshot.jit_code_cache_bytes
         << " jit-cache-peak-bytes=" << snapshot.jit_code_cache_peak_bytes
         << " jit-shared-invalidations="
         << snapshot.jit_shared_invalidation_requests
         << " jit-full-invalidations="
         << snapshot.jit_full_invalidation_requests
         << " jit-range-invalidations="
         << snapshot.jit_range_invalidation_requests
         << " jit-slab-generations=" << snapshot.jit_slab_generation_transitions
         << " jit-cache-ranges=" << snapshot.jit_shared_range_count
         << " jit-cache-descriptors=" << snapshot.jit_shared_descriptor_count
         << " jit-invalidated-descriptors="
         << snapshot.jit_invalidated_descriptors
         << " jit-retired-code-bytes=" << snapshot.jit_retired_code_bytes
         << " jit-segment-recycles=" << snapshot.jit_segment_recycles
         << " jit-recycled-descriptors=" << snapshot.jit_recycled_descriptors
         << " jit-recycled-code-bytes=" << snapshot.jit_recycled_code_bytes
         << " jit-full-generation-clears="
         << snapshot.jit_full_generation_clears
         << " jit-fast-link=" << snapshot.jit_fast_link_hits << "/"
         << snapshot.jit_fast_link_misses << " jit-stable-table-collision-rate="
         << snapshot.jit_stable_table_collisions << "/"
         << snapshot.jit_stable_table_probes
         << " jit-rsb=" << snapshot.jit_rsb_hits << "/"
         << snapshot.jit_rsb_misses
         << " jit-host-yield-checks=" << snapshot.jit_host_yield_checks
         << " jit-host-yields=" << snapshot.jit_host_yields
         << " jit-host-budget-ns="
         << snapshot.jit_host_slice_budget_min_nanoseconds << "/"
         << host_budget_average << "/"
         << snapshot.jit_host_slice_budget_max_nanoseconds
         << " jit-demand-artifact=" << snapshot.jit_demand_artifact_probes
         << "/" << snapshot.jit_demand_artifact_hits << "/"
         << snapshot.jit_demand_artifact_misses
         << " scheduler-runnable=" << snapshot.scheduler_runnable_transitions
         << " scheduler-dispatch=" << snapshot.scheduler_dispatches
         << " scheduler-wake=" << snapshot.scheduler_wakeups << "/"
         << snapshot.scheduler_wake_pending
         << " scheduler-block=" << snapshot.scheduler_blocks
         << " scheduler-preempt=" << snapshot.scheduler_preemption_checks << "/"
         << snapshot.scheduler_preemptions << "/"
         << snapshot.scheduler_urgent_preemptions << "/"
         << snapshot.scheduler_preemption_requests << "/"
         << snapshot.scheduler_preemption_coalesced << "/"
         << snapshot.scheduler_preemption_returns << "/"
         << snapshot.scheduler_preemption_deferred_consumes
         << " scheduler-quantum-expired="
         << snapshot.scheduler_quantum_expirations
         << " translation-blocks=" << snapshot.translation_blocks
         << " translation-blocks-shared-region="
         << snapshot.translation_blocks_shared_region
         << " cpu-exec=" << snapshot.cpu_executions
         << " cpu-ticks=" << snapshot.cpu_ticks << " svc=" << snapshot.svc_calls
         << " page-misses=" << snapshot.page_misses
         << " page-faults=" << snapshot.page_faults
         << " draw=" << snapshot.draws << " submit=" << snapshot.submits
         << " fence-wait=" << snapshot.fence_waits
         << " fence-wait-ns=" << snapshot.fence_wait_nanoseconds
         << " upload-bytes=" << snapshot.upload_bytes
         << " readback-bytes=" << snapshot.readback_bytes
         << " host-fill=" << snapshot.host_fills
         << " host-copy=" << snapshot.host_copies
         << " display-submit=" << snapshot.display_submissions
         << " display-coalesced=" << snapshot.display_mailbox_coalesced
         << " display-vsync=" << snapshot.display_vsync_queued << '/'
         << snapshot.display_vsync_coalesced
         << " display-vsync-budget=" << snapshot.display_vsync_budget_cuts
         << '/' << snapshot.display_vsync_budget_saved_ticks
         << " display-queue=" << snapshot.display_queue_depth << '/'
         << snapshot.display_queue_high_watermark
         << " display-queue-waits=" << snapshot.display_queue_backpressure_waits
         << " display-queue-max-wait-ns="
         << snapshot.display_queue_backpressure_max_wait_nanoseconds
         << " display-queue-timeouts="
         << snapshot.display_queue_backpressure_timeouts
         << " sdl-idle-waits=" << snapshot.sdl_idle_waits
         << " native-attempt=" << snapshot.native_present_attempts
         << " native-coalesced=" << snapshot.native_present_mailbox_coalesced
         << " native-skipped=" << snapshot.native_present_skipped
         << " native-failed=" << snapshot.native_present_failures
         << " native-present=" << snapshot.native_presents
         << " cpu-present-fallback=" << snapshot.cpu_present_fallbacks
         << " cpu-map-read=" << snapshot.cpu_map_reads
         << " cpu-map-write=" << snapshot.cpu_map_writes
         << " fork=" << snapshot.forks << " exec=" << snapshot.execs
         << " abnormal-exit=" << snapshot.abnormal_exits
         << " fallback-total=" << fallback_total << " fallback-reasons=";
    bool first = true;
    for (std::size_t index = 1; index < snapshot.fallback_reasons.size();
        ++index) {
        const auto count = snapshot.fallback_reasons[index];
        if (count == 0)
            continue;
        if (!first)
            text << ',';
        first = false;
        text << perf_fallback_reason_name(
                    static_cast<PerfFallbackReason>(index))
             << ':' << count;
    }
    if (first)
        text << "none";
    text << " cpu-map-reasons=";
    first = true;
    for (std::size_t index = 0; index < perf_cpu_map_reason_count; ++index) {
        const auto reads = snapshot.cpu_map_read_reasons[index];
        const auto writes = snapshot.cpu_map_write_reasons[index];
        if (reads == 0 && writes == 0)
            continue;
        if (!first)
            text << ',';
        first = false;
        text << perf_cpu_map_reason_name(static_cast<PerfCpuMapReason>(index))
             << ':' << reads << '/' << writes;
    }
    if (first)
        text << "none";
    text << " surface-transfer=";
    first = true;
    for (std::size_t index = 0; index < perf_surface_kind_count; ++index) {
        const auto uploads = snapshot.surface_upload_bytes[index];
        const auto readbacks = snapshot.surface_readback_bytes[index];
        if (uploads == 0 && readbacks == 0)
            continue;
        if (!first)
            text << ',';
        first = false;
        text << perf_surface_kind_name(static_cast<PerfSurfaceKind>(index))
             << ':' << uploads << '/' << readbacks;
    }
    if (first)
        text << "none";
    text << " latency-format=samples/p50/p95/p99/max/>16.7/>20/>33.3/>50"
         << " latency-ns=";
    first = true;
    for (std::size_t index = 0; index < snapshot.latencies.size(); ++index) {
        const auto& latency = snapshot.latencies[index];
        if (!first)
            text << ',';
        first = false;
        text << perf_latency_kind_name(static_cast<PerfLatencyKind>(index))
             << ':' << latency.samples << '/' << latency.p50_nanoseconds << '/'
             << latency.p95_nanoseconds << '/' << latency.p99_nanoseconds << '/'
             << latency.maximum_nanoseconds << '/' << latency.over_16_7ms << '/'
             << latency.over_20ms << '/' << latency.over_33_3ms << '/'
             << latency.over_50ms;
    }
    const auto& jit_demand = snapshot.latencies[static_cast<std::size_t>(
        PerfLatencyKind::JitDemandTranslation)];
    text << " jit-demand-translation=" << jit_demand.samples << '/'
         << jit_demand.p50_nanoseconds << '/' << jit_demand.p95_nanoseconds
         << '/' << jit_demand.p99_nanoseconds << '/'
         << jit_demand.maximum_nanoseconds
         << " jit-demand-translation-total-ns=" << jit_demand.total_nanoseconds;
    text << " jit-cache-slots=";
    first = true;
    for (const auto& usage : snapshot.jit_cache_slots) {
        if (!first)
            text << ',';
        first = false;
        text << usage.process_id << ':' << usage.slot << ':'
             << usage.current_bytes << '/' << usage.peak_bytes;
    }
    if (first)
        text << "none";
    text << " hle=";
    first = true;
    for (const auto& stats : snapshot.hle_subsystems) {
        if (!first)
            text << ',';
        first = false;
        text << stats.subsystem << ':' << stats.calls << '/'
             << stats.nanoseconds;
    }
    if (first)
        text << "none";
    text << " diagnostic-source=";
    first = true;
    for (const auto& stats : snapshot.diagnostic_sources) {
        if (!first)
            text << ',';
        first = false;
        text << diagnostic_source_name(stats) << ':' << stats.calls << '/'
             << stats.nanoseconds;
    }
    if (first)
        text << "none";
    text << " diagnostic-source-stats=" << snapshot.diagnostic_source_inserted
         << '/' << snapshot.diagnostic_source_updated << '/'
         << snapshot.diagnostic_source_evicted << '/'
         << snapshot.diagnostic_source_dropped << '/'
         << snapshot.diagnostic_source_capacity << '/'
         << snapshot.diagnostic_source_peak_occupancy;
    append_diagnostic_process_summary(text, snapshot.diagnostic_processes);
    return text.str();
}

std::string format_display_performance_summary(
    const PerformanceSnapshot& snapshot, std::string_view label)
{
    const auto present_returns =
        snapshot.native_presents + snapshot.cpu_present_fallbacks;
    std::ostringstream text;
    text << std::fixed << std::setprecision(2)
         << "[perf-display] label=" << label
         << " guest-submit=" << snapshot.display_submissions << " guest-fps="
         << frames_per_second(snapshot.display_submissions,
                snapshot.display_first_nanoseconds,
                snapshot.display_last_nanoseconds)
         << " display-coalesced=" << snapshot.display_mailbox_coalesced
         << " display-vsync-budget=" << snapshot.display_vsync_budget_cuts
         << '/' << snapshot.display_vsync_budget_saved_ticks
         << " scheduler-runnable=" << snapshot.scheduler_runnable_transitions
         << " scheduler-dispatch=" << snapshot.scheduler_dispatches
         << " scheduler-wake=" << snapshot.scheduler_wakeups << "/"
         << snapshot.scheduler_wake_pending
         << " scheduler-block=" << snapshot.scheduler_blocks
         << " scheduler-preempt=" << snapshot.scheduler_preemption_checks << "/"
         << snapshot.scheduler_preemptions << "/"
         << snapshot.scheduler_urgent_preemptions << "/"
         << snapshot.scheduler_preemption_requests << "/"
         << snapshot.scheduler_preemption_coalesced << "/"
         << snapshot.scheduler_preemption_returns << "/"
         << snapshot.scheduler_preemption_deferred_consumes
         << " scheduler-quantum-expired="
         << snapshot.scheduler_quantum_expirations
         << " jit-demand-artifact=" << snapshot.jit_demand_artifact_probes
         << "/" << snapshot.jit_demand_artifact_hits << "/"
         << snapshot.jit_demand_artifact_misses << " jit-demand-translation="
         << snapshot
                .latencies[static_cast<std::size_t>(
                    PerfLatencyKind::JitDemandTranslation)]
                .samples
         << "/"
         << snapshot
                .latencies[static_cast<std::size_t>(
                    PerfLatencyKind::JitDemandTranslation)]
                .total_nanoseconds
         << " jit-full-invalidations="
         << snapshot.jit_full_invalidation_requests
         << " jit-range-invalidations="
         << snapshot.jit_range_invalidation_requests
         << " jit-slab-generations=" << snapshot.jit_slab_generation_transitions
         << " jit-cache-retire=" << snapshot.jit_invalidated_descriptors << "/"
         << snapshot.jit_retired_code_bytes
         << " jit-segment-recycle=" << snapshot.jit_segment_recycles << "/"
         << snapshot.jit_recycled_descriptors << "/"
         << snapshot.jit_recycled_code_bytes << " jit-full-generation-clears="
         << snapshot.jit_full_generation_clears
         << " native-attempt=" << snapshot.native_present_attempts
         << " native-coalesced=" << snapshot.native_present_mailbox_coalesced
         << " native-queued=" << snapshot.native_presents
         << " native-skipped=" << snapshot.native_present_skipped
         << " native-failed=" << snapshot.native_present_failures
         << " cpu-present=" << snapshot.cpu_present_fallbacks
         << " present-return=" << present_returns << " present-return-fps="
         << frames_per_second(present_returns,
                snapshot.present_first_nanoseconds,
                snapshot.present_last_nanoseconds)
         << " display-vsync=" << snapshot.display_vsync_queued << '/'
         << snapshot.display_vsync_coalesced
         << " latency-format=samples/p50/p95/p99/max/>16.7/>20/>33.3/>50"
         << " latency-ns=";
    constexpr std::array display_latencies {
        PerfLatencyKind::DisplayMailbox,
        PerfLatencyKind::NativeMailbox,
        PerfLatencyKind::Acquire,
        PerfLatencyKind::QueuePresent,
        PerfLatencyKind::PresentReturn,
        PerfLatencyKind::PresentInterval,
        PerfLatencyKind::VsyncDueToCallback,
        PerfLatencyKind::VsyncCallbackToSwapEnd,
        PerfLatencyKind::VsyncSwapEndToGuestSubmit,
        PerfLatencyKind::VsyncDueToGuestSubmit,
        PerfLatencyKind::PosixSpawnTotal,
        PerfLatencyKind::PosixSpawnDecode,
        PerfLatencyKind::PosixSpawnFork,
        PerfLatencyKind::PosixSpawnCreate,
        PerfLatencyKind::ProcessFreshMemory,
        PerfLatencyKind::ProcessCloneMemory,
        PerfLatencyKind::ProcessCreateCpu,
        PerfLatencyKind::ProcessCreateKernel,
        PerfLatencyKind::ProcessInheritKernel,
        PerfLatencyKind::ProcessInheritSpawnKernel,
        PerfLatencyKind::ProcessConfigureRuntime,
        PerfLatencyKind::SpawnMemoryClear,
        PerfLatencyKind::SpawnImageLoad,
        PerfLatencyKind::SpawnResetRuntime,
    };
    bool first = true;
    for (const auto kind : display_latencies) {
        if (!first)
            text << ',';
        first = false;
        const auto& latency =
            snapshot.latencies[static_cast<std::size_t>(kind)];
        text << perf_latency_kind_name(kind) << ':' << latency.samples << '/'
             << latency.p50_nanoseconds << '/' << latency.p95_nanoseconds << '/'
             << latency.p99_nanoseconds << '/' << latency.maximum_nanoseconds
             << '/' << latency.over_16_7ms << '/' << latency.over_20ms << '/'
             << latency.over_33_3ms << '/' << latency.over_50ms;
    }
    constexpr std::array cpu_source_latencies {
        PerfLatencyKind::CpuRunLockWait,
        PerfLatencyKind::CpuRunSharedWriteSync,
        PerfLatencyKind::CpuRunEnsureJit,
        PerfLatencyKind::CpuRunInvalidation,
        PerfLatencyKind::CpuRunLoadState,
        PerfLatencyKind::CpuRunCallbacksBegin,
        PerfLatencyKind::CpuRunArtifactPreload,
        PerfLatencyKind::CpuRunExecute,
        PerfLatencyKind::CpuRunResult,
        PerfLatencyKind::CpuRunSaveState,
        PerfLatencyKind::CpuRunCacheAccounting,
        PerfLatencyKind::CpuRunTotal,
        PerfLatencyKind::SchedulerSelection,
        PerfLatencyKind::GuestExecutionBudget,
        PerfLatencyKind::SchedulerPreemptionCheck,
        PerfLatencyKind::SchedulerSliceCompletion,
        PerfLatencyKind::SchedulerRunnableToDispatch,
        PerfLatencyKind::SchedulerPreemptionRequestToReturn,
    };
    text << " diagnostic-cpu-latency-ns=";
    for (std::size_t index = 0; index < cpu_source_latencies.size(); ++index) {
        if (index != 0)
            text << ',';
        const auto kind = cpu_source_latencies[index];
        const auto& latency =
            snapshot.latencies[static_cast<std::size_t>(kind)];
        text << perf_latency_kind_name(kind) << ':' << latency.samples << '/'
             << latency.p50_nanoseconds << '/' << latency.p95_nanoseconds << '/'
             << latency.p99_nanoseconds << '/' << latency.maximum_nanoseconds
             << '/' << latency.over_16_7ms << '/' << latency.over_20ms << '/'
             << latency.over_33_3ms << '/' << latency.over_50ms;
    }
    text << " diagnostic-cpu-total-ns=";
    for (std::size_t index = 0; index < cpu_source_latencies.size(); ++index) {
        if (index != 0)
            text << ',';
        const auto kind = cpu_source_latencies[index];
        const auto& latency =
            snapshot.latencies[static_cast<std::size_t>(kind)];
        text << perf_latency_kind_name(kind) << ':'
             << latency.total_nanoseconds;
    }
    text << " diagnostic-cpu-run-format="
            "pid:processor:slot:start-us/end-us:"
            "lock-wait/shared-write-sync/ensure-jit/invalidation/load-state/"
            "callbacks-begin/artifact-preload/execute/result/save-state/"
            "cache-accounting/total-us:requested-ticks/consumed-ticks/"
            "host-yielded/host-yield-checks/svc-calls/svc-immediate/"
            "halt-reason"
         << " diagnostic-cpu-run=";
    if (diagnostic_cpu_runs.empty()) {
        text << "none";
    } else {
        for (std::size_t index = 0; index < diagnostic_cpu_runs.size();
            ++index) {
            if (index != 0)
                text << ',';
            const auto& run = diagnostic_cpu_runs[index];
            text << run.process_id << ':' << run.processor_id << ':'
                 << run.execution_slot << ':';
            append_diagnostic_timestamp(text, run.started);
            text << '/';
            append_diagnostic_timestamp(text, run.ended);
            text << ':';
            for (std::size_t phase = 0; phase < run.phase_nanoseconds.size();
                ++phase) {
                if (phase != 0)
                    text << '/';
                text << run.phase_nanoseconds[phase] / 1'000U;
            }
            text << ':' << run.requested_ticks << '/' << run.consumed_ticks
                 << '/' << (run.host_yielded ? 1U : 0U) << '/'
                 << run.host_yield_checks << '/' << run.svc_calls << '/';
            if (run.svc) {
                text << *run.svc;
            } else {
                text << '-';
            }
            text << '/' << run.halt_reason;
        }
    }
    text << " diagnostic-sequence-us=";
    for (std::size_t index = 0; index < diagnostic_sequence_kinds.size();
        ++index) {
        if (index != 0)
            text << ';';
        text << perf_latency_kind_name(diagnostic_sequence_kinds[index]) << ':';
        const auto& sequence = diagnostic_display_sequences[index];
        for (std::size_t sample = 0; sample < sequence.size(); ++sample) {
            if (sample != 0)
                text << ',';
            text << sequence[sample] / 1'000U;
        }
    }
    text << " diagnostic-window-start-ns="
         << steady_nanoseconds(diagnostic_window_started_at)
         << " diagnostic-input-format="
            "kind:phase:x:y:sequence:queued:pid:thread:"
            "enqueued-us/guest-us/runnable-us/execute-us"
         << " diagnostic-input=";
    if (diagnostic_input_events.empty()) {
        text << "none";
    } else {
        for (std::size_t index = 0; index < diagnostic_input_events.size();
            ++index) {
            if (index != 0)
                text << ',';
            const auto& event = diagnostic_input_events[index];
            text << event.kind << ':' << event.phase << ':' << event.x << ':'
                 << event.y << ':' << event.sequence << ':'
                 << (event.queued ? 'q' : 'd') << ':' << event.process_id << ':'
                 << event.thread << ':';
            append_diagnostic_timestamp(text, event.enqueued);
            text << '/';
            append_diagnostic_timestamp(text, event.guest_entered);
            text << '/';
            append_diagnostic_timestamp(text, event.runnable);
            text << '/';
            append_diagnostic_timestamp(text, event.executed);
        }
    }
    text << " diagnostic-content-format="
            "frame:pid:submitted-us:changed-pixels:rgb-delta:hash"
         << " diagnostic-content=";
    if (diagnostic_content_frames.empty()) {
        text << "none";
    } else {
        for (std::size_t index = 0; index < diagnostic_content_frames.size();
            ++index) {
            if (index != 0)
                text << ',';
            const auto& frame = diagnostic_content_frames[index];
            text << frame.sequence << ':' << frame.owner_process_id << ':';
            append_diagnostic_timestamp(text, frame.submitted);
            text << ':';
            if (frame.comparable)
                text << frame.changed_pixels;
            else
                text << '-';
            text << ':';
            if (frame.comparable)
                text << frame.absolute_rgb_delta;
            else
                text << '-';
            text << ':' << std::hex << frame.hash << std::dec;
        }
    }
    text << " diagnostic-timeline-format="
         << "d:frame:pid:vsync:fb:"
            "submit/display-dequeue/native-queue/native-dequeue/"
            "present-return:present-kind|"
         << "v:vsync:pid:fb:frame:"
            "due/received/callback/swap-end/guest-submit:"
            "receiver/callback-processor/swap-end-processor:"
            "blocks/cpu-exec/cpu-ticks/svc/page-miss/page-fault/"
            "draw/submit/fence/fence-ns:"
            "r/submit-reasons:"
            "h/all-calls/all-ns/blit-copy-calls/blit-copy-ns/"
            "blit-color-calls/blit-color-ns/quad-copy-calls/quad-copy-ns"
            "/source-sync-calls/source-sync-ns/"
            "host-copy-calls/host-copy-ns/"
            "host-quad-calls/host-quad-ns"
         << " diagnostic-timeline-us=";
    const auto timeline_empty =
        diagnostic_display_frames.empty() && diagnostic_vsync_frames.empty();
    if (timeline_empty)
        text << "none";
    bool first_timeline = true;
    for (const auto& frame : diagnostic_display_frames) {
        if (!first_timeline)
            text << ',';
        first_timeline = false;
        text << "d:" << frame.sequence << ':' << frame.owner_process_id << ':';
        if (frame.vsync_sequence != 0)
            text << frame.vsync_sequence;
        else
            text << '-';
        text << ':';
        if (frame.framebuffer != 0)
            text << frame.framebuffer;
        else
            text << '-';
        text << ':';
        append_diagnostic_timestamp(text, frame.submitted);
        text << '/';
        append_diagnostic_timestamp(text, frame.display_dequeued);
        text << '/';
        append_diagnostic_timestamp(text, frame.native_queued);
        text << '/';
        append_diagnostic_timestamp(text, frame.native_dequeued);
        text << '/';
        append_diagnostic_timestamp(text, frame.present_returned);
        text << ':' << frame.present_kind;
    }
    if (!timeline_empty)
        text << '|';
    bool first_vsync = true;
    for (const auto& frame : diagnostic_vsync_frames) {
        if (!first_vsync)
            text << ',';
        first_vsync = false;
        text << "v:" << frame.sequence << ':' << frame.process_id << ':'
             << frame.framebuffer << ':';
        if (frame.display_sequence != 0)
            text << frame.display_sequence;
        else
            text << '-';
        text << ':';
        append_diagnostic_timestamp(text, frame.due);
        text << '/';
        append_diagnostic_timestamp(text, frame.received);
        text << '/';
        append_diagnostic_timestamp(text, frame.callback);
        text << '/';
        append_diagnostic_timestamp(text, frame.swap_end);
        text << '/';
        append_diagnostic_timestamp(text, frame.guest_submit);
        text << ':' << frame.receiver_processor << '/'
             << frame.callback_processor << '/' << frame.swap_end_processor;
        text << ':' << frame.work.translation_blocks << '/'
             << frame.work.cpu_executions << '/' << frame.work.cpu_ticks << '/'
             << frame.work.svc_calls << '/' << frame.work.page_misses << '/'
             << frame.work.page_faults << '/' << frame.work.draws << '/'
             << frame.work.submits << '/' << frame.work.fence_waits << '/'
             << frame.work.fence_wait_nanoseconds;
        text << ":r";
        for (const auto count : frame.work.submit_reasons)
            text << '/' << count;
        text << ":h/" << frame.work.hle_calls << '/'
             << frame.work.hle_nanoseconds;
        for (std::size_t index = 0;
            index < frame.work.graphics_hle_calls.size(); ++index) {
            text << '/' << frame.work.graphics_hle_calls[index] << '/'
                 << frame.work.graphics_hle_nanoseconds[index];
        }
    }
    text << " diagnostic-work=jit:" << snapshot.jit_instances << '/'
         << snapshot.jit_creation_nanoseconds
         << ",blocks:" << snapshot.translation_blocks
         << ",cpu:" << snapshot.cpu_executions << '/' << snapshot.cpu_ticks
         << ",svc:" << snapshot.svc_calls << ",draw-submit:" << snapshot.draws
         << '/' << snapshot.submits
         << ",submit-reason[other/mbx-flush/mbx-finish/mbx-surface/"
            "compositor/gles-sync/present/staging/readback/resource/"
            "batch/texture]:";
    for (std::size_t index = 0; index < snapshot.submit_reasons.size();
        ++index) {
        if (index != 0)
            text << '/';
        text << snapshot.submit_reasons[index];
    }
    text << ",fence:" << snapshot.fence_waits << '/'
         << snapshot.fence_wait_nanoseconds
         << ",upload-readback:" << snapshot.upload_bytes << '/'
         << snapshot.readback_bytes << ",fill-copy:" << snapshot.host_fills
         << '/' << snapshot.host_copies << ",cpu-map:" << snapshot.cpu_map_reads
         << '/' << snapshot.cpu_map_writes << " diagnostic-hle=";
    for (std::size_t index = 0; index < snapshot.hle_subsystems.size();
        ++index) {
        if (index != 0)
            text << ',';
        const auto& hle = snapshot.hle_subsystems[index];
        text << hle.subsystem << ':' << hle.calls << '/' << hle.nanoseconds;
    }
    if (snapshot.hle_subsystems.empty())
        text << "none";
    text << " diagnostic-source=";
    for (std::size_t index = 0; index < snapshot.diagnostic_sources.size();
        ++index) {
        if (index != 0)
            text << ',';
        const auto& stats = snapshot.diagnostic_sources[index];
        text << diagnostic_source_name(stats) << ':' << stats.calls << '/'
             << stats.nanoseconds;
    }
    if (snapshot.diagnostic_sources.empty())
        text << "none";
    text << " diagnostic-source-stats=" << snapshot.diagnostic_source_inserted
         << '/' << snapshot.diagnostic_source_updated << '/'
         << snapshot.diagnostic_source_evicted << '/'
         << snapshot.diagnostic_source_dropped << '/'
         << snapshot.diagnostic_source_capacity << '/'
         << snapshot.diagnostic_source_peak_occupancy;
    append_diagnostic_process_summary(text, snapshot.diagnostic_processes);
    return text.str();
}

}
