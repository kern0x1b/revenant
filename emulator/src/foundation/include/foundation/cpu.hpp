// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Execute guest ARM code through Dynarmic and coordinate translation
// and CPU callbacks.

#pragma once

#include <array>
#include <chrono>
#include <cstddef>
#include <cstdint>
#include <functional>
#include <memory>
#include <optional>
#include <span>
#include <string>
#include <vector>

#include <dynarmic/interface/A32/a32.h>
#include <dynarmic/interface/exclusive_monitor.h>

#include "foundation/address_space.hpp"
#include "foundation/arm_cpu_model.hpp"
#include "foundation/guest_exclusive_address_resolver.hpp"
#include "foundation/jit_work_signal.hpp"

namespace shade {

enum class JitPrecompilePhase : std::uint8_t {
    Bootstrap,
    Scanout,
    PriorStartup,
    InteractiveActivation,
    Opportunistic,
};

inline constexpr std::size_t jit_precompile_phase_count =
    static_cast<std::size_t>(JitPrecompilePhase::Opportunistic) + 1U;

enum class JitPrecompileTarget : std::uint8_t {
    NativeCode,
    PortableIr,
};

inline constexpr std::size_t jit_precompile_target_count =
    static_cast<std::size_t>(JitPrecompileTarget::PortableIr) + 1U;

enum class JitPrecompileSource : std::uint8_t {
    DemandProfile,
    ExecutableCatalog,
    Other,
};

inline constexpr std::size_t jit_precompile_source_count =
    static_cast<std::size_t>(JitPrecompileSource::Other) + 1U;

struct JitPrecompileBatchResult {
    std::uint64_t elapsed_nanoseconds { };
    std::uint64_t attempted { };
    std::uint64_t native_compiled { };
    std::uint64_t portable_generated { };
    std::uint64_t portable_artifact_hits { };
    std::uint64_t artifact_imported { };
    std::uint64_t artifact_probe_hits { };
    std::uint64_t shared_slab_hits { };
    std::uint64_t deferred { };
    std::uint64_t unstable { };
    std::uint64_t cache_full { };
    std::uint64_t failed { };
    std::uint64_t cancelled { };
    std::uint64_t deadline_stops { };
};

struct JitPrecompileSourceMemoryStats {
    std::size_t queued_entries { };
    std::size_t pending_entries { };
    std::size_t inflight_entries { };
    std::size_t deferred_entries { };
    std::size_t completed_entries { };
    std::size_t estimated_queue_entry_bytes { };
    std::size_t queue_bucket_bytes { };
    std::size_t queue_node_bytes { };
    std::size_t queue_block_bytes { };
    std::size_t queued_entries_peak { };
    std::size_t pending_entries_peak { };
    std::size_t inflight_entries_peak { };
    std::size_t deferred_entries_peak { };
    std::size_t completed_entries_peak { };
    std::size_t estimated_queue_entry_bytes_peak { };
    std::size_t queue_bucket_bytes_peak { };
    std::size_t queue_node_bytes_peak { };
    std::size_t queue_block_bytes_peak { };
};

struct JitPrecompileMemoryStats {
    std::array<JitPrecompileSourceMemoryStats, jit_precompile_source_count>
        by_source { };
    std::size_t profile_queue_entries { };
    std::size_t profile_queue_capacity_entries { };
    std::size_t catalog_queue_entries { };
    std::size_t generic_queue_entries { };
    std::size_t pending_entries { };
    std::size_t inflight_entries { };
    std::size_t deferred_entries { };
    std::size_t completed_entries { };
    std::size_t estimated_queue_entry_bytes { };
    std::size_t queue_bucket_bytes { };
    std::size_t queue_node_bytes { };
    std::size_t queue_block_bytes { };
    std::size_t profile_recorder_bytes { };
    std::size_t native_profile_prediction_bytes { };
    std::size_t native_preimport_tracker_bytes { };
    std::size_t profile_queue_entries_peak { };
    std::size_t catalog_queue_entries_peak { };
    std::size_t generic_queue_entries_peak { };
    std::size_t pending_entries_peak { };
    std::size_t inflight_entries_peak { };
    std::size_t deferred_entries_peak { };
    std::size_t completed_entries_peak { };
    std::size_t estimated_queue_entry_bytes_peak { };
    std::size_t queue_bucket_bytes_peak { };
    std::size_t queue_node_bytes_peak { };
    std::size_t queue_block_bytes_peak { };
    std::size_t profile_recorder_bytes_peak { };
    std::size_t native_profile_prediction_bytes_peak { };
    std::size_t native_preimport_tracker_bytes_peak { };
};

class JitTranslationProfile;
class JitArtifactStore;
enum class JitArtifactRetention : std::uint8_t;

struct CpuRunResult {
    Dynarmic::HaltReason reason { };
    std::uint64_t ticks_consumed { };
    std::optional<std::uint32_t> svc;
    std::uint64_t svc_calls { };
    std::optional<MemoryFault> fault;
    std::optional<std::uint32_t> debug_breakpoint;
    std::string exception;
    bool host_yielded { };
    std::uint64_t host_yield_checks { };
    std::optional<Dynarmic::A32::Exception> exception_kind;
    std::uint32_t exception_pc { };
};

enum class SvcDispatchMode : std::uint8_t {
    Immediate,
    Deferred,
};

struct CpuThreadState {
    std::array<std::uint32_t, 16> registers { };
    std::array<std::uint32_t, 64> extension_registers { };
    std::uint32_t cpsr { };
    std::uint32_t fpscr { };
    std::optional<std::uint32_t> cthread_self;
};

class CpuExecutionPool;
class JitExecutor;
class JitCallbacks;

class Cpu {
public:
    using SvcHandler = std::function<void(Cpu&, std::uint32_t)>;
    using MemoryWriteHandler =
        std::function<void(Cpu&, std::uint32_t, std::size_t, std::uint64_t)>;

    Cpu(std::size_t processor_id, AddressSpace& memory,
        Dynarmic::ExclusiveMonitor& monitor);
    ~Cpu();
    Cpu(const Cpu&) = delete;
    Cpu& operator=(const Cpu&) = delete;

    CpuRunResult run(std::uint64_t ticks, std::size_t execution_slot = 0);
    CpuRunResult run_cooperatively(
        std::uint64_t ticks, std::size_t execution_slot = 0);
    CpuRunResult run_cooperatively(std::uint64_t ticks,
        std::chrono::nanoseconds host_slice_budget,
        std::size_t execution_slot = 0);
    CpuRunResult step(std::size_t execution_slot = 0);
    void reset();
    void clear_cache();
    struct CacheInvalidationRange {
        std::uint32_t address { };
        std::size_t length { };
    };
    void invalidate_cache_range(std::uint32_t address, std::size_t length);
    void invalidate_cache_ranges(
        std::span<const CacheInvalidationRange> ranges);
    void raise_memory_fault(
        std::uint32_t address, std::size_t size, MemoryPermission access);
    void clear_halt();
    void halt(Dynarmic::HaltReason reason = Dynarmic::HaltReason::UserDefined1);
    void request_guest_preemption();
    [[nodiscard]] Dynarmic::HaltReason consume_requested_halt_reason();

    [[nodiscard]] std::size_t processor_id() const { return processor_id_; }
    [[nodiscard]] std::array<std::uint32_t, 16>& registers();
    [[nodiscard]] const std::array<std::uint32_t, 16>& registers() const;
    [[nodiscard]] std::uint32_t cpsr() const;
    void set_cpsr(std::uint32_t value);
    [[nodiscard]] std::array<std::uint32_t, 64>& extension_registers();
    [[nodiscard]] const std::array<std::uint32_t, 64>&
    extension_registers() const;
    [[nodiscard]] std::uint32_t fpscr() const;
    void set_fpscr(std::uint32_t value);
    [[nodiscard]] std::optional<std::uint32_t> cthread_self() const;
    void set_cthread_self(std::optional<std::uint32_t> value);
    void set_svc_handler(SvcHandler handler);
    void set_svc_dispatch_mode(SvcDispatchMode mode);
    void set_guest_thread(std::uint32_t thread);
    void set_memory_write_watchpoint(
        std::uint32_t address, MemoryWriteHandler handler);
    void set_debug_breakpoints_enabled(bool enabled);
    void set_translation_profile(std::shared_ptr<JitTranslationProfile> profile,
        bool record = true, bool precompile = true);
    void clear_exclusive_state(std::size_t execution_slot = 0);

private:
    friend class CpuCluster;
    friend class JitExecutor;
    friend class JitCallbacks;
    Cpu(std::size_t processor_id,
        std::shared_ptr<CpuExecutionPool> execution_pool);

    std::size_t processor_id_ { };
    std::shared_ptr<CpuExecutionPool> execution_pool_;
    CpuThreadState state_;
    JitExecutor* active_executor_ { };
    SvcHandler svc_handler_;
    MemoryWriteHandler memory_write_handler_;
    SvcDispatchMode svc_dispatch_mode_ { SvcDispatchMode::Immediate };
    std::uint32_t guest_thread_ { };
    std::optional<std::uint32_t> memory_write_watch_address_;
    bool debug_breakpoints_enabled_ { };
    Dynarmic::HaltReason requested_halt_reason_ { };
};

class CpuCluster {
public:
    using PrecompileStopCondition = std::function<bool()>;

    ~CpuCluster();

    CpuCluster(std::size_t processor_count, AddressSpace& memory);
    CpuCluster(std::size_t initial_processor_count,
        std::size_t maximum_processor_count, AddressSpace& memory);
    CpuCluster(std::size_t initial_processor_count,
        std::size_t maximum_processor_count, AddressSpace& memory,
        bool serialized_execution);
    CpuCluster(std::size_t initial_processor_count,
        std::size_t maximum_processor_count, AddressSpace& memory,
        bool serialized_execution, const ArmCpuModel& cpu_model);
    CpuCluster(std::size_t initial_processor_count,
        std::size_t maximum_processor_count, AddressSpace& memory,
        std::size_t execution_slot_count, const ArmCpuModel& cpu_model);
    CpuCluster(std::size_t initial_processor_count,
        std::size_t maximum_processor_count, AddressSpace& memory,
        std::size_t execution_slot_count, const ArmCpuModel& cpu_model,
        Dynarmic::ExclusiveMonitor& monitor, std::size_t monitor_processor_base,
        std::shared_ptr<JitArtifactStore> artifact_store = { },
        std::shared_ptr<GuestExclusiveAddressResolver> address_resolver = { },
        std::size_t precompile_lane_count = 1U);

    [[nodiscard]] std::size_t size() const { return cpus_.size(); }
    [[nodiscard]] std::size_t capacity() const
    {
        return maximum_processor_count_;
    }
    [[nodiscard]] Cpu& cpu(std::size_t index) { return *cpus_.at(index); }
    [[nodiscard]] const Cpu& cpu(std::size_t index) const
    {
        return *cpus_.at(index);
    }
    [[nodiscard]] std::optional<std::size_t> add_cpu();
    void set_process_id(std::uint32_t process_id);
    void set_jit_code_cache_size(std::size_t bytes);
    void prepare_primary_execution_resource();
    [[nodiscard]] std::size_t precompile_lane_count() const noexcept;
    void set_jit_work_signal(
        std::shared_ptr<JitWorkObservationSignal> signal);
    [[nodiscard]] std::uint64_t jit_code_cache_bytes();
    void clear_cache();
    void invalidate_cache_range(std::uint32_t address, std::size_t length);
    void set_translation_profile(std::shared_ptr<JitTranslationProfile> profile,
        JitPrecompilePhase phase = JitPrecompilePhase::Opportunistic,
        bool record = true, bool precompile = true);
    void refresh_translation_profile();
    void retry_deferred_translation_profile();
    [[nodiscard]] JitPrecompileMemoryStats precompile_memory_stats() const;
    void set_jit_artifact_retention(JitArtifactRetention retention);
    void add_precompile_entries(
        const std::vector<std::uint64_t>& location_descriptors,
        JitPrecompilePhase phase = JitPrecompilePhase::Opportunistic,
        JitPrecompileSource source = JitPrecompileSource::Other);
    [[nodiscard]] std::optional<JitPrecompilePhase> next_precompile_phase(
        JitPrecompileTarget target = JitPrecompileTarget::NativeCode,
        std::optional<JitPrecompileSource> source = std::nullopt);
    JitPrecompileBatchResult precompile_pending(std::size_t maximum_blocks,
        std::uint64_t budget_nanoseconds,
        JitPrecompileTarget target = JitPrecompileTarget::NativeCode,
        PrecompileStopCondition stop_condition = { },
        std::optional<JitPrecompileSource> source = std::nullopt);
    void quiesce_precompilation();
    [[nodiscard]] std::shared_ptr<CpuExecutionPool>
    release_execution_resources();
    [[nodiscard]] bool has_execution_resources() const
    {
        return execution_pool_ != nullptr;
    }

    std::vector<CpuRunResult> run_parallel(std::uint64_t ticks_per_cpu);

private:
    AddressSpace* memory_ { };
    std::size_t maximum_processor_count_ { };
    bool serialized_execution_ { };
    const ArmCpuModel* cpu_model_ { };
    Dynarmic::ExclusiveMonitor monitor_;
    Dynarmic::ExclusiveMonitor* execution_monitor_ { };
    std::size_t monitor_processor_base_ { };
    std::size_t monitor_processor_count_ { };
    std::shared_ptr<GuestExclusiveAddressResolver> address_resolver_;
    std::shared_ptr<CpuExecutionPool> execution_pool_;
    std::vector<std::unique_ptr<Cpu>> cpus_;
};

}
