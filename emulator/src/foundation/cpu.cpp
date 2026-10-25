// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Execute guest ARM code through Dynarmic and coordinate translation
// and CPU callbacks.

#include "foundation/cpu.hpp"

#include <algorithm>
#include <array>
#include <atomic>
#include <cassert>
#include <cctype>
#include <chrono>
#include <condition_variable>
#include <cstdlib>
#include <deque>
#include <limits>
#include <mutex>
#include <optional>
#include <sstream>
#include <stdexcept>
#include <string_view>
#include <thread>
#include <unordered_map>
#include <unordered_set>
#include <utility>

#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wshadow"
#endif
#include <dynarmic/backend/x64/a32_jitstate.h>
#include <dynarmic/backend/x64/exclusive_monitor_friend.h>
#include <dynarmic/frontend/A32/a32_ir_emitter.h>
#include <dynarmic/interface/A32/coprocessor.h>
#include <dynarmic/ir/basic_block.h>
#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic pop
#endif

#include "dynarmic_ir_artifact.hpp"
#include "foundation/arm_unpredictable_instruction.hpp"
#include "foundation/jit_artifact.hpp"
#include "foundation/jit_code_cache_governor.hpp"
#include "foundation/jit_execution_budget.hpp"
#include "foundation/jit_native_preimport_tracker.hpp"
#include "foundation/jit_translation_profile.hpp"
#include "foundation/guest_image_table.hpp"
#include "foundation/jit_work_policy.hpp"
#include "foundation/performance.hpp"

namespace emulator {
namespace {

    constexpr std::uint32_t shared_region_first_address = 0x20000000U;
    constexpr std::uint32_t shared_region_end_address = 0x40000000U;

    [[nodiscard]] bool jit_env_flag(const char* name) noexcept
    {
        const char* value = std::getenv(name);
        return value != nullptr && value[0] == '1';
    }

    [[nodiscard]] bool jit_demand_disabled() noexcept
    {
        static const bool disabled =
            jit_env_flag("REVENANT_EMULATOR_JIT_DISABLE_DEMAND_ARTIFACT");
        return disabled;
    }

    [[nodiscard]] bool jit_sync_preload_disabled() noexcept
    {
        static const bool disabled =
            jit_env_flag("REVENANT_EMULATOR_JIT_DISABLE_SYNC_PRELOAD");
        return disabled;
    }

    [[nodiscard]] bool jit_portable_handoff_disabled() noexcept
    {
        static const bool disabled =
            jit_env_flag("REVENANT_EMULATOR_JIT_DISABLE_PORTABLE_HANDOFF");
        return disabled;
    }

    [[nodiscard]] bool jit_sync_disk_lookup_enabled() noexcept
    {
        static const bool enabled =
            jit_env_flag("REVENANT_EMULATOR_JIT_ALLOW_SYNC_DISK_LOOKUP") &&
            !jit_env_flag("REVENANT_EMULATOR_JIT_MEMORY_ONLY_LOOKUP");
        return enabled;
    }

    [[nodiscard]] std::uint64_t demand_probe_fingerprint(
        const JitArtifactKey& key) noexcept
    {
        static const bool force_test_collision =
            jit_env_flag("REVENANT_EMULATOR_TEST_DEMAND_PROBE_FINGERPRINT_COLLISION");
        if (force_test_collision)
            return 0x9e3779b97f4a7c15ULL;
        return static_cast<std::uint64_t>(JitArtifactKeyHash { }(key));
    }

    [[nodiscard]] bool
    jit_test_ignore_demand_probe_content_generation() noexcept
    {
        static const bool enabled =
            jit_env_flag("REVENANT_EMULATOR_TEST_DEMAND_PROBE_IGNORE_CONTENT_GENERATION");
        return enabled;
    }

    [[nodiscard]] Dynarmic::A32::ArchVersion dynarmic_architecture_version(
        ArmArchitectureVersion version)
    {
        switch (version) {
        case ArmArchitectureVersion::Armv6K:
            return Dynarmic::A32::ArchVersion::v6K;
        case ArmArchitectureVersion::Armv7:
            return Dynarmic::A32::ArchVersion::v7;
        }
        throw std::invalid_argument { "unsupported ARM architecture version" };
    }

    template <typename Jit> std::uint64_t jit_code_cache_used(const Jit& jit)
    {
        if constexpr (requires { jit.CodeCacheUsed(); }) {
            return static_cast<std::uint64_t>(jit.CodeCacheUsed());
        }
        return 0;
    }

    constexpr std::size_t jit_link_cell_count = 9U;
    constexpr std::size_t fast_dispatch_table_size = 0x10000U;
    constexpr std::size_t fast_dispatch_entry_bytes =
        sizeof(std::uint64_t) * 2U;
    constexpr std::size_t host_code_page_size = 4096U;
    constexpr auto default_host_cooperative_slice_budget =
        std::chrono::milliseconds { 2 };
    constexpr std::uint32_t host_yield_initial_check_interval = 32U;
    constexpr std::uint32_t host_yield_min_check_interval = 4U;
    constexpr std::uint32_t host_yield_max_check_interval = 64U;
    constexpr std::uint64_t host_yield_initial_tick_budget = 2048U;
    constexpr std::uint64_t host_yield_min_tick_budget = 256U;
    constexpr std::uint64_t host_yield_max_tick_budget = 8192U;
    constexpr auto host_yield_urgent_window = std::chrono::microseconds { 250 };
    constexpr auto host_yield_slow_translation_threshold =
        std::chrono::microseconds { 250 };
    constexpr std::size_t jit_profile_precompile_batch_size = 16U;
    constexpr std::size_t jit_profile_precompile_target_queue_entry_capacity =
        jit_profile_precompile_batch_size;
    constexpr std::size_t jit_profile_precompile_queue_entry_capacity =
        jit_profile_precompile_target_queue_entry_capacity *
        jit_precompile_target_count;
    constexpr std::size_t jit_profile_recency_recovery_location_capacity =
        32'768U;
    constexpr std::size_t jit_catalog_precompile_queue_entry_capacity = 512U;
    constexpr std::size_t jit_completed_precompile_entry_capacity = 2048U;
    static_assert(sizeof(void*) == sizeof(std::uint64_t));

    class AtomicJitPrecompileMemorySnapshot {
    public:
        static constexpr std::size_t top_value_count = 29U;
        static constexpr std::size_t source_value_count = 18U;

        void publish(const JitPrecompileMemoryStats& current,
            const JitPrecompileMemoryStats& peak) noexcept
        {
            sequence_.fetch_add(1U, std::memory_order_acq_rel);

            const std::array<std::size_t, top_value_count> top_values {
                current.profile_queue_entries,
                current.profile_queue_capacity_entries,
                current.catalog_queue_entries,
                current.generic_queue_entries,
                current.pending_entries,
                current.inflight_entries,
                current.deferred_entries,
                current.completed_entries,
                current.estimated_queue_entry_bytes,
                current.queue_bucket_bytes,
                current.queue_node_bytes,
                current.queue_block_bytes,
                current.profile_recorder_bytes,
                current.native_profile_prediction_bytes,
                current.native_preimport_tracker_bytes,
                peak.profile_queue_entries_peak,
                peak.catalog_queue_entries_peak,
                peak.generic_queue_entries_peak,
                peak.pending_entries_peak,
                peak.inflight_entries_peak,
                peak.deferred_entries_peak,
                peak.completed_entries_peak,
                peak.estimated_queue_entry_bytes_peak,
                peak.queue_bucket_bytes_peak,
                peak.queue_node_bytes_peak,
                peak.queue_block_bytes_peak,
                peak.profile_recorder_bytes_peak,
                peak.native_profile_prediction_bytes_peak,
                peak.native_preimport_tracker_bytes_peak,
            };
            for (std::size_t index = 0; index < top_values.size(); ++index)
                top_[index].store(
                    to_uint64(top_values[index]), std::memory_order_relaxed);

            for (std::size_t source_index = 0;
                source_index < jit_precompile_source_count; ++source_index) {
                const auto& now = current.by_source[source_index];
                const auto& source_peak = peak.by_source[source_index];
                const std::array<std::size_t, source_value_count>
                    source_values {
                        now.queued_entries,
                        now.pending_entries,
                        now.inflight_entries,
                        now.deferred_entries,
                        now.completed_entries,
                        now.estimated_queue_entry_bytes,
                        now.queue_bucket_bytes,
                        now.queue_node_bytes,
                        now.queue_block_bytes,
                        source_peak.queued_entries_peak,
                        source_peak.pending_entries_peak,
                        source_peak.inflight_entries_peak,
                        source_peak.deferred_entries_peak,
                        source_peak.completed_entries_peak,
                        source_peak.estimated_queue_entry_bytes_peak,
                        source_peak.queue_bucket_bytes_peak,
                        source_peak.queue_node_bytes_peak,
                        source_peak.queue_block_bytes_peak,
                    };
                for (std::size_t value_index = 0;
                    value_index < source_values.size(); ++value_index) {
                    by_source_[source_index][value_index].store(
                        to_uint64(source_values[value_index]),
                        std::memory_order_relaxed);
                }
            }

            sequence_.fetch_add(1U, std::memory_order_release);
        }

        [[nodiscard]] JitPrecompileMemoryStats read() const noexcept
        {
            for (;;) {
                const auto before = sequence_.load(std::memory_order_acquire);
                if ((before & 1U) != 0U)
                    continue;

                JitPrecompileMemoryStats result;
                const auto load = [&](const std::atomic<std::uint64_t>& value) {
                    return to_size(value.load(std::memory_order_relaxed));
                };
                result.profile_queue_entries = load(top_[0]);
                result.profile_queue_capacity_entries = load(top_[1]);
                result.catalog_queue_entries = load(top_[2]);
                result.generic_queue_entries = load(top_[3]);
                result.pending_entries = load(top_[4]);
                result.inflight_entries = load(top_[5]);
                result.deferred_entries = load(top_[6]);
                result.completed_entries = load(top_[7]);
                result.estimated_queue_entry_bytes = load(top_[8]);
                result.queue_bucket_bytes = load(top_[9]);
                result.queue_node_bytes = load(top_[10]);
                result.queue_block_bytes = load(top_[11]);
                result.profile_recorder_bytes = load(top_[12]);
                result.native_profile_prediction_bytes = load(top_[13]);
                result.native_preimport_tracker_bytes = load(top_[14]);
                result.profile_queue_entries_peak = load(top_[15]);
                result.catalog_queue_entries_peak = load(top_[16]);
                result.generic_queue_entries_peak = load(top_[17]);
                result.pending_entries_peak = load(top_[18]);
                result.inflight_entries_peak = load(top_[19]);
                result.deferred_entries_peak = load(top_[20]);
                result.completed_entries_peak = load(top_[21]);
                result.estimated_queue_entry_bytes_peak = load(top_[22]);
                result.queue_bucket_bytes_peak = load(top_[23]);
                result.queue_node_bytes_peak = load(top_[24]);
                result.queue_block_bytes_peak = load(top_[25]);
                result.profile_recorder_bytes_peak = load(top_[26]);
                result.native_profile_prediction_bytes_peak = load(top_[27]);
                result.native_preimport_tracker_bytes_peak = load(top_[28]);
                for (std::size_t source_index = 0;
                    source_index < jit_precompile_source_count;
                    ++source_index) {
                    auto& source = result.by_source[source_index];
                    source.queued_entries = load(by_source_[source_index][0]);
                    source.pending_entries = load(by_source_[source_index][1]);
                    source.inflight_entries = load(by_source_[source_index][2]);
                    source.deferred_entries = load(by_source_[source_index][3]);
                    source.completed_entries =
                        load(by_source_[source_index][4]);
                    source.estimated_queue_entry_bytes =
                        load(by_source_[source_index][5]);
                    source.queue_bucket_bytes =
                        load(by_source_[source_index][6]);
                    source.queue_node_bytes = load(by_source_[source_index][7]);
                    source.queue_block_bytes =
                        load(by_source_[source_index][8]);
                    source.queued_entries_peak =
                        load(by_source_[source_index][9]);
                    source.pending_entries_peak =
                        load(by_source_[source_index][10]);
                    source.inflight_entries_peak =
                        load(by_source_[source_index][11]);
                    source.deferred_entries_peak =
                        load(by_source_[source_index][12]);
                    source.completed_entries_peak =
                        load(by_source_[source_index][13]);
                    source.estimated_queue_entry_bytes_peak =
                        load(by_source_[source_index][14]);
                    source.queue_bucket_bytes_peak =
                        load(by_source_[source_index][15]);
                    source.queue_node_bytes_peak =
                        load(by_source_[source_index][16]);
                    source.queue_block_bytes_peak =
                        load(by_source_[source_index][17]);
                }

                const auto after = sequence_.load(std::memory_order_acquire);
                if (before == after)
                    return result;
            }
        }

    private:
        static std::uint64_t to_uint64(std::size_t value) noexcept
        {
            if constexpr (sizeof(std::size_t) > sizeof(std::uint64_t)) {
                return std::min<std::size_t>(
                    value, std::numeric_limits<std::uint64_t>::max());
            } else {
                return static_cast<std::uint64_t>(value);
            }
        }

        static std::size_t to_size(std::uint64_t value) noexcept
        {
            if constexpr (sizeof(std::size_t) < sizeof(std::uint64_t)) {
                return static_cast<std::size_t>(std::min<std::uint64_t>(
                    value, std::numeric_limits<std::size_t>::max()));
            } else {
                return static_cast<std::size_t>(value);
            }
        }

        std::atomic<std::uint64_t> sequence_ { };
        std::array<std::atomic<std::uint64_t>, top_value_count> top_ { };
        std::array<std::array<std::atomic<std::uint64_t>, source_value_count>,
            jit_precompile_source_count>
            by_source_ { };
    };

    class CpuRunPhaseDiagnostics {
    public:
        static constexpr auto first_kind =
            static_cast<std::size_t>(PerfLatencyKind::CpuRunLockWait);
        static constexpr auto last_kind =
            static_cast<std::size_t>(PerfLatencyKind::CpuRunTotal);
        static constexpr auto phase_count = last_kind - first_kind + 1U;

        CpuRunPhaseDiagnostics(std::uint32_t process_id,
            std::uint32_t processor_id, std::uint32_t execution_slot,
            std::uint64_t requested_ticks)
            : process_id_ { process_id }
            , processor_id_ { processor_id }
            , execution_slot_ { execution_slot }
            , requested_ticks_ { requested_ticks }
            , enabled_ {
                performance_counters().cpu_source_diagnostics_enabled()
            }
        {
            if (enabled_) {
                total_started_ = std::chrono::steady_clock::now();
                phase_started_ = total_started_;
            }
        }

        CpuRunPhaseDiagnostics(const CpuRunPhaseDiagnostics&) = delete;
        CpuRunPhaseDiagnostics& operator=(
            const CpuRunPhaseDiagnostics&) = delete;

        ~CpuRunPhaseDiagnostics()
        {
            if (!enabled_)
                return;
            const auto ended = std::chrono::steady_clock::now();
            const auto elapsed = ended - total_started_;
            phase_nanoseconds_.back() = static_cast<std::uint64_t>(
                std::chrono::duration_cast<std::chrono::nanoseconds>(elapsed)
                    .count());
            performance_counters().record_cpu_run_phases(process_id_,
                processor_id_, execution_slot_, total_started_, ended,
                phase_nanoseconds_, requested_ticks_, consumed_ticks_,
                host_yield_checks_, host_yielded_, svc_calls_, svc_,
                halt_reason_);
        }

        void checkpoint(PerfLatencyKind kind)
        {
            if (!enabled_)
                return;
            const auto ended = std::chrono::steady_clock::now();
            const auto index = static_cast<std::size_t>(kind) - first_kind;
            if (index < phase_nanoseconds_.size() - 1U) {
                phase_nanoseconds_[index] = static_cast<std::uint64_t>(
                    std::chrono::duration_cast<std::chrono::nanoseconds>(
                        ended - phase_started_)
                        .count());
            }
            phase_started_ = ended;
        }

        void record_result(std::uint64_t consumed_ticks,
            std::uint64_t host_yield_checks, bool host_yielded,
            std::uint64_t svc_calls, std::optional<std::uint32_t> svc,
            Dynarmic::HaltReason halt_reason) noexcept
        {
            consumed_ticks_ = consumed_ticks;
            host_yield_checks_ = host_yield_checks;
            host_yielded_ = host_yielded;
            svc_calls_ = svc_calls;
            svc_ = svc;
            halt_reason_ = static_cast<std::uint32_t>(halt_reason);
        }

    private:
        std::uint32_t process_id_ { };
        std::uint32_t processor_id_ { };
        std::uint32_t execution_slot_ { };
        std::uint64_t requested_ticks_ { };
        std::uint64_t consumed_ticks_ { };
        std::uint64_t host_yield_checks_ { };
        bool host_yielded_ { };
        std::uint64_t svc_calls_ { };
        std::optional<std::uint32_t> svc_;
        std::uint32_t halt_reason_ { };
        bool enabled_ { };
        std::chrono::steady_clock::time_point total_started_;
        std::chrono::steady_clock::time_point phase_started_;
        std::array<std::uint64_t, phase_count> phase_nanoseconds_ { };
    };

    [[nodiscard]] std::uint64_t logical_committed_code_bytes(
        std::uint64_t used_bytes) noexcept
    {
        if (used_bytes == 0U)
            return 0U;
        const auto remainder = used_bytes % host_code_page_size;
        return used_bytes +
               (remainder == 0U ? 0U : host_code_page_size - remainder);
    }

    constexpr std::uint32_t jit_artifact_hle_abi_version = 1U;
    constexpr std::uint32_t jit_artifact_backend_abi_version = 2U;
    constexpr std::uint64_t jit_artifact_codegen_options = 1U;
    constexpr std::uint32_t jit_artifact_format_version = 8U;

#ifndef DYNARMIC_BUILD_FINGERPRINT
#define DYNARMIC_BUILD_FINGERPRINT 0x0ULL
#endif

    constexpr std::uint64_t jit_artifact_dynarmic_build_fingerprint =
        DYNARMIC_BUILD_FINGERPRINT;
    constexpr bool jit_artifact_producer_fingerprint_available =
        jit_artifact_dynarmic_build_fingerprint != 0U;

    [[nodiscard]] ArmCpuModelKind jit_artifact_cpu_model(
        const ArmCpuModel& cpu_model) noexcept
    {
        return cpu_model.kind();
    }

    [[nodiscard]] JitHostIsa jit_artifact_host_isa() noexcept
    {
#if defined(__aarch64__) || defined(_M_ARM64)
        return JitHostIsa::Arm64;
#elif defined(__x86_64__) || defined(_M_X64)
        return JitHostIsa::X86_64;
#else
        return JitHostIsa::Unknown;
#endif
    }

    [[nodiscard]] std::uint64_t jit_artifact_host_feature_mask() noexcept
    {
        static const auto mask = [] {
            std::uint64_t result = 0;
#if (defined(__GNUC__) || defined(__clang__)) &&                               \
    (defined(__x86_64__) || defined(_M_X64))
            __builtin_cpu_init();
            if (__builtin_cpu_supports("ssse3"))
                result |= std::uint64_t { 1 } << 0U;
            if (__builtin_cpu_supports("sse4.1"))
                result |= std::uint64_t { 1 } << 1U;
            if (__builtin_cpu_supports("sse4.2"))
                result |= std::uint64_t { 1 } << 2U;
            if (__builtin_cpu_supports("avx"))
                result |= std::uint64_t { 1 } << 3U;
            if (__builtin_cpu_supports("avx2"))
                result |= std::uint64_t { 1 } << 4U;
            if (__builtin_cpu_supports("avx512f"))
                result |= std::uint64_t { 1 } << 5U;
            if (__builtin_cpu_supports("avx512cd"))
                result |= std::uint64_t { 1 } << 6U;
            if (__builtin_cpu_supports("avx512vl"))
                result |= std::uint64_t { 1 } << 7U;
            if (__builtin_cpu_supports("avx512bw"))
                result |= std::uint64_t { 1 } << 8U;
            if (__builtin_cpu_supports("avx512dq"))
                result |= std::uint64_t { 1 } << 9U;
            if (__builtin_cpu_supports("avx512bitalg"))
                result |= std::uint64_t { 1 } << 10U;
            if (__builtin_cpu_supports("avx512vbmi"))
                result |= std::uint64_t { 1 } << 11U;
            if (__builtin_cpu_supports("pclmul"))
                result |= std::uint64_t { 1 } << 12U;
            if (__builtin_cpu_supports("f16c"))
                result |= std::uint64_t { 1 } << 13U;
            if (__builtin_cpu_supports("fma"))
                result |= std::uint64_t { 1 } << 14U;
            if (__builtin_cpu_supports("aes"))
                result |= std::uint64_t { 1 } << 15U;
            if (__builtin_cpu_supports("sha"))
                result |= std::uint64_t { 1 } << 16U;
            if (__builtin_cpu_supports("popcnt"))
                result |= std::uint64_t { 1 } << 17U;
            if (__builtin_cpu_supports("bmi"))
                result |= std::uint64_t { 1 } << 18U;
            if (__builtin_cpu_supports("bmi2"))
                result |= std::uint64_t { 1 } << 19U;
            if (__builtin_cpu_supports("lzcnt"))
                result |= std::uint64_t { 1 } << 20U;
            if (__builtin_cpu_supports("gfni"))
                result |= std::uint64_t { 1 } << 21U;
#endif
            return result;
        }();
        return mask;
    }

    [[nodiscard]] constexpr bool portable_artifact_import_supported() noexcept
    {
#if defined(__x86_64__) || defined(_M_X64)
        return true;
#else
        return false;
#endif
    }

    [[nodiscard]] Dynarmic::OptimizationFlag jit_optimizations()
    {
        if (!performance_counters().block_profile_enabled())
            return Dynarmic::all_safe_optimizations;
        return Dynarmic::all_safe_optimizations &
               ~(Dynarmic::OptimizationFlag::BlockLinking |
                   Dynarmic::OptimizationFlag::ReturnStackBuffer |
                   Dynarmic::OptimizationFlag::FastDispatch);
    }

    [[nodiscard]] std::shared_ptr<JitArtifactStore> artifact_store_for_run(
        std::shared_ptr<JitArtifactStore> store)
    {
        return performance_counters().block_profile_enabled()
            ? nullptr
            : std::move(store);
    }

}

class JitCallbacks final : public Dynarmic::A32::UserCallbacks {
public:
    struct ValidatedArtifactBlock {
        Dynarmic::IR::Block block;
        JitArtifactLookup lookup;
    };

    enum class ArtifactImportOutcome : std::uint8_t {
        Unavailable,
        Imported,
        AlreadyPresent,
        Failed,
    };

    enum class DemandArtifactState : std::uint8_t {
        Empty,
        Staged,
        HandedOff,
        NativeEmitted,
    };

    JitCallbacks(AddressSpace& memory, const ArmCpuModel& cpu_model,
        std::shared_ptr<JitArtifactStore> artifact_store,
        std::shared_ptr<JitNativePreimportTracker> native_preimport_tracker)
        : memory_ { memory }
        , cpu_model_ { cpu_model }
        , artifact_store_ { std::move(artifact_store) }
        , native_preimport_tracker_ { std::move(native_preimport_tracker) }
    {
    }

    void attach(Cpu* owner, Dynarmic::A32::Jit* jit)
    {
        owner_ = owner;
        jit_ = jit;
    }

    void set_process_id(std::uint32_t process_id) noexcept
    {
        process_id_ = process_id;
    }

    bool PreCodeReadHook(bool, Dynarmic::A32::VAddr address,
        Dynarmic::A32::IREmitter& ir) override
    {
        if (ir.block.CycleCount() == 0) {
            performance_counters().record_translation_block();
            if (address >= shared_region_first_address &&
                address < shared_region_end_address) {
                performance_counters().record_translation_block_shared_region();
            }
            translation_block_ = &ir.block;
            translation_code_pages_.clear();
            translation_constant_dependencies_.clear();
            constant_dependency_failed_ = false;
        }
        if (translation_block_ == &ir.block &&
            (portable_generation_location_ || explicit_artifact_publication_)) {
            const auto page = address & ~(AddressSpace::page_size - 1U);
            if (std::find(translation_code_pages_.begin(),
                    translation_code_pages_.end(),
                    page) == translation_code_pages_.end()) {
                translation_code_pages_.push_back(page);
            }
        }
        return true;
    }

    void CodeTranslationCompleted(std::uint64_t location_descriptor,
        std::uint64_t translation_nanoseconds) noexcept override
    {
        translation_completed(
            location_descriptor, translation_nanoseconds, nullptr);
    }

    void CodeTranslationCompleted(std::uint64_t location_descriptor,
        std::uint64_t translation_nanoseconds,
        const Dynarmic::IR::Block& block) noexcept override
    {
        if (performance_counters().block_profile_enabled()) {
            const auto terminal = block.GetTerminal();
            TranslatedBlock translated { block.CycleCount(), BlockEnd::Other };
            if (boost::get<Dynarmic::IR::Term::LinkBlock>(&terminal))
                translated.end = BlockEnd::LinkBlock;
            else if (boost::get<Dynarmic::IR::Term::LinkBlockFast>(&terminal))
                translated.end = BlockEnd::LinkBlockFast;
            performance_counters().block_profile().record_translation(
                static_cast<std::uint32_t>(process_id_), location_descriptor,
                translated);
        }
        translation_completed(
            location_descriptor, translation_nanoseconds, &block);
    }

    [[nodiscard]] ArtifactImportOutcome import_artifact(Dynarmic::A32::Jit& jit,
        std::uint64_t location_descriptor) const noexcept
    {
        auto validated = validated_artifact_block(location_descriptor);
        if (!validated)
            return ArtifactImportOutcome::Unavailable;
        try {
            const auto emitted =
                jit.PrecompileWithResult(std::move(validated->block));
            if (artifact_store_) {
                if (emitted ==
                    Dynarmic::A32::Jit::PortableIREmitOutcome::NativeEmitted) {
                    artifact_store_->record_native_imported(validated->lookup);
                } else if (emitted ==
                           Dynarmic::A32::Jit::PortableIREmitOutcome::
                               AlreadyPresent) {
                    artifact_store_->record_already_present(validated->lookup);
                }
            }
            switch (emitted) {
            case Dynarmic::A32::Jit::PortableIREmitOutcome::NativeEmitted:
                return ArtifactImportOutcome::Imported;
            case Dynarmic::A32::Jit::PortableIREmitOutcome::AlreadyPresent:
                return ArtifactImportOutcome::AlreadyPresent;
            case Dynarmic::A32::Jit::PortableIREmitOutcome::EmitFailed:
                return ArtifactImportOutcome::Failed;
            }
            return ArtifactImportOutcome::Failed;
        } catch (...) {
            return ArtifactImportOutcome::Failed;
        }
    }

    [[nodiscard]] bool artifact_available(
        std::uint64_t location_descriptor) const noexcept
    {
        return validated_artifact_block(location_descriptor).has_value();
    }

    [[nodiscard]] bool generate_portable_artifact(
        Dynarmic::A32::Jit& jit, std::uint64_t location_descriptor) noexcept
    {
        if (!artifact_store_ || !jit_artifact_producer_fingerprint_available) {
            return false;
        }
        try {
            portable_generation_location_ = location_descriptor;
            portable_generation_published_ = false;
            jit.GeneratePortableIR(location_descriptor);
            portable_generation_location_.reset();
            return portable_generation_published_;
        } catch (...) {
            portable_generation_location_.reset();
            portable_generation_published_ = false;
            return false;
        }
    }

    void set_explicit_artifact_publication(bool enabled) noexcept
    {
        explicit_artifact_publication_ = enabled;
    }

    [[nodiscard]] JitArtifactLookup find_artifact(
        std::uint64_t location_descriptor) const noexcept
    {
        if (!artifact_store_)
            return { };
        const auto key = make_artifact_key(location_descriptor);
        return key ? artifact_store_->lookup(*key, artifact_retention_)
                   : JitArtifactLookup { };
    }

    [[nodiscard]] std::optional<JitArtifactKey> artifact_key(
        std::uint64_t location_descriptor) const noexcept
    {
        return make_artifact_key(location_descriptor);
    }

    [[nodiscard]] std::uint64_t artifact_publication_generation() const noexcept
    {
        return artifact_store_ ? artifact_store_->publication_generation() : 0U;
    }

    [[nodiscard]] bool demand_artifact_catalog_nonempty() const noexcept
    {
        return artifact_store_ && artifact_store_->size() != 0U;
    }

    JitDemandArtifactStageResult stage_demand_artifact(
        std::uint64_t location_descriptor, std::uint64_t slab_generation,
        const JitArtifactKey& key)
    {
        try {
            if (demand_artifact_location_ == location_descriptor &&
                demand_artifact_slab_generation_ == slab_generation &&
                demand_artifact_ &&
                demand_artifact_state_ == DemandArtifactState::Staged) {
                return JitDemandArtifactStageResult::Staged;
            }
            discard_demand_artifact();

            ArtifactValidationResult validated;
            std::uint64_t background_prepare_nanoseconds { };
            if (jit_sync_disk_lookup_enabled()) {
                validated = validate_artifact_block(location_descriptor, &key);
            } else if (!artifact_store_) {
                return JitDemandArtifactStageResult::ExactMiss;
            } else if (auto prepared =
                           artifact_store_->take_background_prepared(key)) {
                background_prepare_nanoseconds =
                    prepared->preparation_nanoseconds;
                if (!*prepared) {
                    artifact_store_->record_validation_rejection(
                        prepared->rejection);
                    return prepared->result;
                }
                if (prepared->block->Location().Value() !=
                    location_descriptor) {
                    artifact_store_->record_validation_rejection(
                        JitArtifactValidationRejection::DescriptorMismatch);
                    return JitDemandArtifactStageResult::
                        PermanentValidationFailure;
                }
                if (!dependencies_match(*prepared->lookup.artifact)) {
                    artifact_store_->record_validation_rejection(
                        JitArtifactValidationRejection::DependencyMismatch);
                    return JitDemandArtifactStageResult::
                        PermanentValidationFailure;
                }
                artifact_store_->record_validation_success();
                validated = { JitDemandArtifactStageResult::Staged,
                    ValidatedArtifactBlock { std::move(*prepared->block),
                        std::move(prepared->lookup) } };
            } else {
                switch (artifact_store_->request_background_prepare(
                    key, artifact_retention_)) {
                case JitArtifactBackgroundPrepareResult::ExactMiss:
                    return JitDemandArtifactStageResult::ExactMiss;
                case JitArtifactBackgroundPrepareResult::Queued:
                case JitArtifactBackgroundPrepareResult::Pending:
                case JitArtifactBackgroundPrepareResult::Ready:
                case JitArtifactBackgroundPrepareResult::Unavailable:
                    return JitDemandArtifactStageResult::TransientFailure;
                }
                return JitDemandArtifactStageResult::TransientFailure;
            }
            if (!validated.block) {
                return validated.result;
            }
            if (validated.block->block.Location().Value() !=
                location_descriptor) {
                return JitDemandArtifactStageResult::PermanentValidationFailure;
            }
            if (artifact_store_) {
                const auto& artifact = *validated.block->lookup.artifact;
                const auto ir_bytes = artifact.data.normalized_ir.size();
                constexpr std::uint64_t base_load_nanoseconds = 35'000U;
                constexpr std::uint64_t bytes_cost_divisor = 2U;
                auto estimated_load = background_prepare_nanoseconds;
                if (estimated_load == 0U) {
                    estimated_load = base_load_nanoseconds;
                    const auto size_cost = static_cast<std::uint64_t>(
                        std::min<std::size_t>(ir_bytes / bytes_cost_divisor,
                            std::numeric_limits<std::uint64_t>::max() -
                                base_load_nanoseconds));
                    estimated_load += size_cost;
                    switch (validated.block->lookup.provenance) {
                    case JitArtifactLookupProvenance::DiskDemand:
                        estimated_load += 150'000U;
                        break;
                    case JitArtifactLookupProvenance::DiskPrefetched:
                        estimated_load += 45'000U;
                        break;
                    case JitArtifactLookupProvenance::MemoryPublished:
                        break;
                    }
                }
                const auto estimated_saved =
                    artifact.data.translation_nanoseconds;
                const auto confidence =
                    artifact.data.translation_nanoseconds != 0U &&
                            !artifact.data.code_dependencies.empty()
                        ? static_cast<std::uint8_t>(100U)
                        : static_cast<std::uint8_t>(0U);
                if (!artifact_store_->admit_demand_artifact(
                        estimated_load, estimated_saved, confidence)) {
                    return JitDemandArtifactStageResult::ExactMiss;
                }
            }
            demand_artifact_key_ = key;
            demand_artifact_location_ = location_descriptor;
            demand_artifact_slab_generation_ = slab_generation;
            demand_artifact_lookup_ = validated.block->lookup;
            demand_artifact_.emplace(std::move(validated.block->block));
            demand_artifact_state_ = DemandArtifactState::Staged;
            if (artifact_store_) {
                artifact_store_->record_staged(demand_artifact_lookup_);
            }
            if (translation_profile_) {
                translation_profile_->note_demand_artifact_staged();
            }
            return JitDemandArtifactStageResult::Staged;
        } catch (...) {
            discard_demand_artifact();
            return JitDemandArtifactStageResult::TransientFailure;
        }
    }

    void record_demand_stage_attempt() const noexcept
    {
        if (artifact_store_)
            artifact_store_->record_demand_stage_attempt();
    }

    void record_demand_negative_probe_hit() const noexcept
    {
        if (artifact_store_)
            artifact_store_->record_demand_negative_probe_hit();
    }

    void record_demand_generation_retry() const noexcept
    {
        if (artifact_store_)
            artifact_store_->record_demand_generation_retry();
    }

    void record_demand_transient_retry() const noexcept
    {
        if (artifact_store_)
            artifact_store_->record_demand_transient_retry();
    }

    void record_demand_probe_fingerprint_hit() const noexcept
    {
        if (artifact_store_)
            artifact_store_->record_demand_probe_fingerprint_hit();
    }

    void record_demand_probe_fingerprint_collision() const noexcept
    {
        if (artifact_store_)
            artifact_store_->record_demand_probe_fingerprint_collision();
    }

    void record_demand_probe_eviction() const noexcept
    {
        if (artifact_store_)
            artifact_store_->record_demand_probe_eviction();
    }

    void record_demand_probe_size(std::size_t entries) const noexcept
    {
        if (artifact_store_)
            artifact_store_->record_demand_probe_size(entries);
    }

    [[nodiscard]] bool demand_artifact_staged(std::uint64_t location_descriptor,
        std::uint64_t slab_generation) const noexcept
    {
        return demand_artifact_location_ == location_descriptor &&
               demand_artifact_slab_generation_ == slab_generation &&
               demand_artifact_.has_value() &&
               demand_artifact_state_ == DemandArtifactState::Staged;
    }

    [[nodiscard]] bool demand_artifact_native_ready(
        std::uint64_t location_descriptor,
        std::uint64_t slab_generation) const noexcept
    {
        return demand_artifact_location_ == location_descriptor &&
               demand_artifact_slab_generation_ == slab_generation &&
               demand_artifact_state_ == DemandArtifactState::NativeEmitted;
    }

    void clear_demand_artifact() noexcept
    {
        demand_artifact_.reset();
        demand_artifact_lookup_ = { };
        demand_artifact_key_ = { };
        demand_artifact_location_ = 0;
        demand_artifact_slab_generation_ = 0;
        demand_artifact_state_ = DemandArtifactState::Empty;
    }

    void discard_demand_artifact() noexcept
    {
        if (demand_artifact_state_ != DemandArtifactState::Empty &&
            translation_profile_) {
            translation_profile_->note_demand_artifact_stage_unused();
        }
        if (demand_artifact_state_ != DemandArtifactState::Empty &&
            artifact_store_) {
            artifact_store_->record_staged_unused(demand_artifact_lookup_);
        }
        clear_demand_artifact();
    }

    void finish_demand_artifact(std::uint64_t location_descriptor) noexcept
    {
        if (demand_artifact_location_ != location_descriptor)
            return;
        if (demand_artifact_state_ == DemandArtifactState::NativeEmitted) {
            if (artifact_store_) {
                artifact_store_->record_demand_consumed(
                    demand_artifact_lookup_);
            }
            if (translation_profile_) {
                translation_profile_->note_demand_artifact_consumed();
                if (!translation_profile_->consume_profile_portable_artifact(
                        location_descriptor)) {
                    translation_profile_
                        ->note_ordinary_demand_artifact_consumed();
                }
            }
            clear_demand_artifact();
            return;
        }
        discard_demand_artifact();
    }

    [[nodiscard]] bool complete_demand_artifact_emit(
        std::uint64_t location_descriptor, std::uint64_t slab_generation,
        Dynarmic::A32::Jit::PortableIREmitOutcome outcome) noexcept
    {
        if (demand_artifact_state_ != DemandArtifactState::HandedOff ||
            demand_artifact_location_ != location_descriptor ||
            demand_artifact_slab_generation_ != slab_generation) {
            return false;
        }
        demand_artifact_.reset();
        switch (outcome) {
        case Dynarmic::A32::Jit::PortableIREmitOutcome::NativeEmitted:
            demand_artifact_state_ = DemandArtifactState::NativeEmitted;
            if (artifact_store_) {
                artifact_store_->record_demand_native_emitted();
            }
            return false;
        case Dynarmic::A32::Jit::PortableIREmitOutcome::AlreadyPresent:
            if (artifact_store_) {
                artifact_store_->record_already_present(
                    demand_artifact_lookup_);
            }
            discard_demand_artifact();
            return false;
        case Dynarmic::A32::Jit::PortableIREmitOutcome::EmitFailed:
            if (artifact_store_) {
                artifact_store_->record_demand_emit_failed();
            }
            discard_demand_artifact();
            return true;
        }
        return true;
    }

    [[nodiscard]] Dynarmic::IR::Block* take_demand_artifact(
        std::uint64_t location_descriptor,
        std::uint64_t slab_generation) noexcept
    {
        const bool hit =
            demand_artifact_ &&
            demand_artifact_state_ == DemandArtifactState::Staged &&
            demand_artifact_location_ == location_descriptor &&
            demand_artifact_slab_generation_ == slab_generation &&
            demand_artifact_key_.location_descriptor == location_descriptor &&
            demand_artifact_->Location().Value() == location_descriptor;
        performance_counters().record_jit_demand_artifact_probe(hit);
        if (!hit)
            return nullptr;
        demand_artifact_state_ = DemandArtifactState::HandedOff;
        return &*demand_artifact_;
    }

    void discard_translation_location(
        std::uint64_t location_descriptor) noexcept
    {
        if (translation_profile_) {
            translation_profile_->discard(location_descriptor);
        }
    }

private:
    struct ArtifactValidationResult {
        JitDemandArtifactStageResult result {
            JitDemandArtifactStageResult::TransientFailure
        };
        std::optional<ValidatedArtifactBlock> block;
    };

    [[nodiscard]] ArtifactValidationResult validate_artifact_block(
        std::uint64_t location_descriptor,
        const JitArtifactKey* known_key = nullptr) const noexcept
    {
        if (!artifact_store_ || !portable_artifact_import_supported() ||
            !jit_artifact_producer_fingerprint_available) {
            if (artifact_store_) {
                artifact_store_->record_validation_rejection(
                    JitArtifactValidationRejection::Unavailable);
            }
            return { JitDemandArtifactStageResult::PermanentValidationFailure,
                std::nullopt };
        }
        try {
            const auto lookup = known_key ? artifact_store_->lookup(*known_key,
                                                artifact_retention_,
                                                jit_sync_disk_lookup_enabled())
                                          : find_artifact(location_descriptor);
            if (!lookup) {
                if (lookup.transient_failure) {
                    artifact_store_->record_validation_rejection(
                        JitArtifactValidationRejection::Exception);
                    return { JitDemandArtifactStageResult::TransientFailure,
                        std::nullopt };
                }
                artifact_store_->record_validation_rejection(
                    JitArtifactValidationRejection::NoExactArtifact);
                return { JitDemandArtifactStageResult::ExactMiss,
                    std::nullopt };
            }
            const auto& artifact = *lookup.artifact;
            if (artifact.data.normalized_ir.empty()) {
                artifact_store_->record_validation_rejection(
                    JitArtifactValidationRejection::EmptyIr);
                return {
                    JitDemandArtifactStageResult::PermanentValidationFailure,
                    std::nullopt
                };
            }
            if (!dependencies_match(artifact)) {
                artifact_store_->record_validation_rejection(
                    JitArtifactValidationRejection::DependencyMismatch);
                return {
                    JitDemandArtifactStageResult::PermanentValidationFailure,
                    std::nullopt
                };
            }
            auto block = deserialize_dynarmic_ir(artifact.data.normalized_ir);
            if (!block) {
                artifact_store_->record_validation_rejection(
                    JitArtifactValidationRejection::DeserializeFailed);
                return {
                    JitDemandArtifactStageResult::PermanentValidationFailure,
                    std::nullopt
                };
            }
            if (block->Location().Value() != location_descriptor) {
                artifact_store_->record_validation_rejection(
                    JitArtifactValidationRejection::DescriptorMismatch);
                return {
                    JitDemandArtifactStageResult::PermanentValidationFailure,
                    std::nullopt
                };
            }
            artifact_store_->record_validation_success();
            return { JitDemandArtifactStageResult::Staged,
                ValidatedArtifactBlock { std::move(*block), lookup } };
        } catch (...) {
            artifact_store_->record_validation_rejection(
                JitArtifactValidationRejection::Exception);
            return { JitDemandArtifactStageResult::TransientFailure,
                std::nullopt };
        }
    }

    [[nodiscard]] std::optional<ValidatedArtifactBlock>
    validated_artifact_block(std::uint64_t location_descriptor) const noexcept
    {
        return validate_artifact_block(location_descriptor).block;
    }

    void record_constant_dependency(
        std::uint32_t address, std::uint32_t size, std::uint64_t value)
    {
        if ((!portable_generation_location_ &&
                !explicit_artifact_publication_) ||
            translation_block_ == nullptr || constant_dependency_failed_) {
            return;
        }
        const auto identity =
            memory_.executable_backing_identity(address, size);
        if (!identity) {
            constant_dependency_failed_ = true;
            return;
        }
        for (const auto& existing : translation_constant_dependencies_) {
            if (existing.address == address && existing.size == size) {
                if (existing.value != value ||
                    existing.content_identity != identity->content ||
                    existing.layout_identity != identity->layout) {
                    constant_dependency_failed_ = true;
                }
                return;
            }
        }
        translation_constant_dependencies_.push_back(JitConstantDependency {
            address, size, value, identity->content, identity->layout });
    }

    [[nodiscard]] bool dependencies_match(
        const BlockArtifact& artifact) const noexcept
    {
        if (artifact.data.code_dependencies.empty())
            return false;
        for (const auto& dependency : artifact.data.code_dependencies) {
            if (dependency.size == 0 ||
                !memory_.is_read_only_executable(
                    dependency.address, dependency.size)) {
                return false;
            }
            const auto current = memory_.executable_backing_identity(
                dependency.address, dependency.size);
            if (!current || current->content != dependency.content_identity ||
                current->layout != dependency.layout_identity) {
                return false;
            }
        }
        for (const auto& constant : artifact.data.constant_dependencies) {
            const auto current = memory_.executable_backing_identity(
                constant.address, constant.size);
            if (!current || current->content != constant.content_identity ||
                current->layout != constant.layout_identity) {
                return false;
            }
            std::optional<std::uint64_t> value;
            switch (constant.size) {
            case 1U: {
                const auto read =
                    memory_.read8(constant.address, MemoryPermission::Read);
                if (read)
                    value = *read;
                break;
            }
            case 2U: {
                const auto read =
                    memory_.read16(constant.address, MemoryPermission::Read);
                if (read)
                    value = *read;
                break;
            }
            case 4U: {
                const auto read =
                    memory_.read32(constant.address, MemoryPermission::Read);
                if (read)
                    value = *read;
                break;
            }
            case 8U: {
                const auto read =
                    memory_.read64(constant.address, MemoryPermission::Read);
                if (read)
                    value = *read;
                break;
            }
            default:
                return false;
            }
            if (!value || *value != constant.value)
                return false;
        }
        return true;
    }

    void translation_completed(std::uint64_t location_descriptor,
        std::uint64_t translation_nanoseconds,
        const Dynarmic::IR::Block* optimized_block) noexcept
    {
        maybe_check_host_yield(
            0U, translation_nanoseconds >=
                    static_cast<std::uint64_t>(
                        std::chrono::duration_cast<std::chrono::nanoseconds>(
                            host_yield_slow_translation_threshold)
                            .count()));
        if (!portable_generation_location_ && !explicit_artifact_publication_) {
            if (translation_recorder_) {
                static_cast<void>(
                    translation_recorder_->record(location_descriptor));
            }
            performance_counters().record_jit_demand_translation(
                process_id_, translation_nanoseconds);
            return;
        }
        const auto published = publish_artifact(
            location_descriptor, translation_nanoseconds, optimized_block);
        if (portable_generation_location_ == location_descriptor) {
            portable_generation_published_ = published;
        }
    }

public:
    void raise_memory_fault(
        std::uint32_t address, std::size_t size, MemoryPermission access)
    {
        memory_fault(address, size, access);
    }

    std::optional<std::uint32_t> MemoryReadCode(std::uint32_t address) override
    {
        const auto value = memory_.read32(address, MemoryPermission::Execute);
        if (!value) {
            memory_fault(address, 4, MemoryPermission::Execute);
        }
        return value;
    }

    std::uint8_t MemoryRead8(std::uint32_t address) override
    {
        const auto value = memory_.read8(address, MemoryPermission::Read);
        if (!value) {
            memory_fault(address, sizeof(std::uint8_t), MemoryPermission::Read);
            return 0;
        }
        record_constant_dependency(address, 1U, *value);
        return *value;
    }
    std::uint16_t MemoryRead16(std::uint32_t address) override
    {
        const auto value = memory_.read16(address, MemoryPermission::Read);
        if (!value) {
            memory_fault(
                address, sizeof(std::uint16_t), MemoryPermission::Read);
            return 0;
        }
        record_constant_dependency(address, 2U, *value);
        return *value;
    }
    std::uint32_t MemoryRead32(std::uint32_t address) override
    {
        const auto value = memory_.read32(address, MemoryPermission::Read);
        if (!value) {
            memory_fault(
                address, sizeof(std::uint32_t), MemoryPermission::Read);
            return 0;
        }
        record_constant_dependency(address, 4U, *value);
        return *value;
    }
    std::uint64_t MemoryRead64(std::uint32_t address) override
    {
        const auto value = memory_.read64(address, MemoryPermission::Read);
        if (!value) {
            memory_fault(
                address, sizeof(std::uint64_t), MemoryPermission::Read);
            return 0;
        }
        record_constant_dependency(address, 8U, *value);
        return *value;
    }

    void MemoryWrite8(std::uint32_t address, std::uint8_t value) override
    {
        write(address, value, &AddressSpace::write8);
    }
    void MemoryWrite16(std::uint32_t address, std::uint16_t value) override
    {
        write(address, value, &AddressSpace::write16);
    }
    void MemoryWrite32(std::uint32_t address, std::uint32_t value) override
    {
        write(address, value, &AddressSpace::write32);
    }
    void MemoryWrite64(std::uint32_t address, std::uint64_t value) override
    {
        write(address, value, &AddressSpace::write64);
    }

    void bind_exclusive_monitor(
        Dynarmic::ExclusiveMonitor& monitor, std::size_t processor)
    {
        exclusive_monitor_ = &monitor;
        exclusive_processor_ = processor;
    }

    void drop_exclusive_state()
    {
        if (jit_ != nullptr)
            jit_->ClearExclusiveState();
        if (exclusive_monitor_ != nullptr)
            exclusive_monitor_->ClearProcessor(exclusive_processor_);
    }

    void MemoryReadExclusive(std::uint32_t address, std::size_t size) override
    {
        memory_.track_exclusive_access(address, size);
    }

    std::uint8_t MemorySwap8(std::uint32_t address, std::uint8_t value) override
    {
        return swap(address, value, &AddressSpace::exchange8);
    }
    std::uint32_t MemorySwap32(
        std::uint32_t address, std::uint32_t value) override
    {
        return swap(address, value, &AddressSpace::exchange32);
    }

    bool MemoryWriteExclusive8(std::uint32_t address, std::uint8_t value,
        std::uint8_t expected) override
    {
        return write_exclusive(
            address, value, expected, &AddressSpace::compare_exchange8);
    }
    bool MemoryWriteExclusive16(std::uint32_t address, std::uint16_t value,
        std::uint16_t expected) override
    {
        return write_exclusive(
            address, value, expected, &AddressSpace::compare_exchange16);
    }
    bool MemoryWriteExclusive32(std::uint32_t address, std::uint32_t value,
        std::uint32_t expected) override
    {
        return write_exclusive(
            address, value, expected, &AddressSpace::compare_exchange32);
    }
    bool MemoryWriteExclusive64(std::uint32_t address, std::uint64_t value,
        std::uint64_t expected) override
    {
        return write_exclusive(
            address, value, expected, &AddressSpace::compare_exchange64);
    }

    bool IsReadOnlyMemory(std::uint32_t address) override
    {
        return memory_.is_read_only_executable(address, sizeof(std::uint32_t));
    }

    void InterpreterFallback(std::uint32_t pc, std::size_t count) override
    {
        std::ostringstream message;
        message << "Dynarmic interpreter fallback at 0x" << std::hex << pc
                << " for " << std::dec << count << " instruction(s)";
        exception_ = message.str();
        jit_->HaltExecution(Dynarmic::HaltReason::UserDefined3);
    }

    void CallSVC(std::uint32_t immediate) override
    {
        drop_exclusive_state();
        performance_counters().record_svc();
        ++svc_calls_;
        svc_ = immediate;
        if (owner_->svc_dispatch_mode_ == SvcDispatchMode::Deferred) {
            jit_->HaltExecution(Dynarmic::HaltReason::UserDefined2);
            return;
        }
        if (owner_->svc_handler_) {
            owner_->svc_handler_(*owner_, immediate);
            maybe_check_host_yield(0, true);
        } else {
            jit_->HaltExecution(Dynarmic::HaltReason::UserDefined2);
        }
    }

    void ExceptionRaised(
        std::uint32_t pc, Dynarmic::A32::Exception exception) override
    {
        if (exception == Dynarmic::A32::Exception::Yield) {
            jit_->HaltExecution(Dynarmic::HaltReason::UserDefined8);
            return;
        }
        if (exception == Dynarmic::A32::Exception::Breakpoint &&
            owner_->debug_breakpoints_enabled_) {
            breakpoint_ = pc;
            owner_->registers()[15] = pc;
            jit_->HaltExecution(Dynarmic::HaltReason::UserDefined7);
            return;
        }
        if (exception == Dynarmic::A32::Exception::UnpredictableInstruction) {
            const auto thumb = (jit_->Cpsr() & (1U << 5U)) != 0U;
            std::optional<std::uint32_t> instruction;
            if (thumb) {
                const auto first =
                    memory_.read16(pc, MemoryPermission::Execute);
                const auto second =
                    memory_.read16(pc + 2U, MemoryPermission::Execute);
                if (first && second) {
                    instruction =
                        (static_cast<std::uint32_t>(*first) << 16U) | *second;
                }
            } else {
                instruction = memory_.read32(pc, MemoryPermission::Execute);
            }
            if (instruction &&
                emulate_arm_unpredictable_instruction(
                    cpu_model_.unpredictable_instruction_policy(), thumb,
                    *instruction, jit_->ExtRegs())) {
                return;
            }
        }
        if (exception == Dynarmic::A32::Exception::UndefinedInstruction &&
            is_trap_instruction(pc)) {
            exception = Dynarmic::A32::Exception::Breakpoint;
        }
        std::ostringstream message;
        message << "ARM exception " << static_cast<unsigned>(exception)
                << " at 0x" << std::hex << pc;
        exception_ = message.str();
        exception_kind_ = exception;
        exception_pc_ = pc;
        jit_->HaltExecution(Dynarmic::HaltReason::UserDefined3);
    }

    bool is_trap_instruction(std::uint32_t pc)
    {
        if ((jit_->Cpsr() & (1U << 5U)) != 0U) {
            const auto half = memory_.read16(pc, MemoryPermission::Execute);
            return half && *half == 0xdefeU;
        }
        const auto word = memory_.read32(pc, MemoryPermission::Execute);
        return word && *word == 0xe7ffdefeU;
    }

    void AddTicks(std::uint64_t ticks) override
    {
        consumed_ += ticks;
        slice_ticks_remaining_ = ticks >= slice_ticks_remaining_
                                     ? 0
                                     : slice_ticks_remaining_ - ticks;
        ticks_remaining_ =
            ticks >= ticks_remaining_ ? 0 : ticks_remaining_ - ticks;
        if (!cooperative_execution_ || host_yield_requested_) {
            return;
        }
        maybe_check_host_yield(ticks, slice_ticks_remaining_ == 0U);
    }
    std::uint64_t GetTicksRemaining() override { return ticks_remaining_; }
    void begin_jit_call(std::uint64_t max_ticks)
    {
        ticks_remaining_ = std::min(max_ticks, slice_ticks_remaining_);
    }
    [[nodiscard]] std::uint64_t slice_ticks_remaining() const
    {
        return slice_ticks_remaining_;
    }
    [[nodiscard]] std::uint64_t consumed_ticks() const { return consumed_; }
    [[nodiscard]] bool host_yield_pending() const
    {
        return host_yield_requested_;
    }
    std::uint64_t GetTicksForCode(bool is_thumb, Dynarmic::A32::VAddr address,
        std::uint32_t instruction) override
    {
        return cpu_model_.ticks_for_instruction(is_thumb, address, instruction);
    }

    void begin(std::uint64_t ticks, bool cooperative_execution = false,
        std::chrono::nanoseconds host_slice_budget =
            default_host_cooperative_slice_budget)
    {
        ticks_remaining_ = ticks;
        slice_ticks_remaining_ = ticks;
        consumed_ = 0;
        svc_.reset();
        svc_calls_ = 0;
        fault_.reset();
        breakpoint_.reset();
        exception_.clear();
        exception_kind_.reset();
        exception_pc_ = 0;
        cooperative_execution_ = cooperative_execution && ticks != 0U;
        host_yield_requested_ = false;
        host_yield_probe_count_ = 0;
        host_yield_tick_accumulator_ = 0;
        host_yield_checks_ = 0;
        host_yield_check_interval_ = host_yield_initial_check_interval;
        host_yield_tick_budget_ = host_yield_initial_tick_budget;
        host_slice_deadline_ = cooperative_execution_
                                   ? std::chrono::steady_clock::now() +
                                         std::max(host_slice_budget,
                                             std::chrono::nanoseconds::zero())
                                   : std::chrono::steady_clock::time_point { };
    }

    CpuRunResult result(Dynarmic::HaltReason reason) const
    {
        return CpuRunResult { reason, consumed_, svc_, svc_calls_, fault_,
            breakpoint_, exception_, host_yield_requested_,
            host_yield_checks_, exception_kind_, exception_pc_ };
    }

    [[nodiscard]] const ArmCpuModel& cpu_model() const { return cpu_model_; }
    [[nodiscard]] Cpu* current_cpu() const { return owner_; }
    [[nodiscard]] std::uint8_t** jit_read_page_table()
    {
        return memory_.jit_read_page_table();
    }
    [[nodiscard]] std::uint8_t** jit_write_page_table()
    {
        return memory_.jit_write_page_table();
    }
    void set_translation_profile(std::shared_ptr<JitTranslationProfile> profile,
        bool record,
        std::shared_ptr<JitNativePreimportTracker> native_preimport_tracker)
    {
        flush_translation_profile_recorder();
        translation_profile_ = std::move(profile);
        native_preimport_tracker_ = std::move(native_preimport_tracker);
        if (record) {
            if (!translation_recorder_) {
                translation_recorder_ =
                    std::make_unique<JitTranslationProfileRecorder>();
                translation_recorder_->set_work_signal(jit_work_signal_);
            }
        } else {
            translation_recorder_.reset();
        }
    }

    void set_jit_work_signal(
        std::shared_ptr<JitWorkObservationSignal> signal) noexcept
    {
        jit_work_signal_ = std::move(signal);
        if (translation_recorder_)
            translation_recorder_->set_work_signal(jit_work_signal_);
    }

    void flush_translation_profile_recorder() noexcept
    {
        if (!translation_recorder_)
            return;
        const auto recorded = translation_recorder_->snapshot();
        if (recorded.empty() && translation_recorder_->deduplicated() == 0U &&
            translation_recorder_->dropped_capacity() == 0U) {
            return;
        }
        std::vector<std::uint64_t> stable_locations;
        stable_locations.reserve(recorded.size());
        const auto recorded_prefix_size = translation_recorder_->prefix_size();
        std::size_t stable_prefix_size { };
        std::unordered_map<std::uint32_t, bool> stable_pages;
        stable_pages.reserve(recorded.size() / 8U);
        std::uint64_t unstable_count { };
        for (std::size_t index = 0; index < recorded.size(); ++index) {
            const auto location_descriptor = recorded[index];
            if (native_preimport_tracker_) {
                native_preimport_tracker_->mark_demand_seen(
                    location_descriptor);
            }
            const auto code_address =
                static_cast<std::uint32_t>(location_descriptor) &
                ~std::uint32_t { 3 };
            const auto page_address =
                code_address & ~(AddressSpace::page_size - 1U);
            auto page = stable_pages.find(page_address);
            if (page == stable_pages.end()) {
                bool stable = false;
                try {
                    stable = memory_.translation_profile_stable(
                                 page_address, AddressSpace::page_size) &&
                             memory_.is_read_only_executable(
                                 page_address, AddressSpace::page_size);
                } catch (...) {
                    stable = false;
                }
                page = stable_pages.emplace(page_address, stable).first;
            }
            if (page->second) {
                stable_locations.push_back(location_descriptor);
                if (index < recorded_prefix_size)
                    ++stable_prefix_size;
            } else {
                ++unstable_count;
            }
        }
        if (translation_profile_) {
            translation_profile_->merge(stable_locations,
                translation_recorder_->deduplicated(),
                translation_recorder_->dropped_capacity() + unstable_count,
                stable_prefix_size);
            translation_profile_->note_unstable_dropped(unstable_count);
        }
        translation_recorder_->reset();
    }

    [[nodiscard]] bool demand_location_seen(
        std::uint64_t location_descriptor) const noexcept
    {
        return native_preimport_tracker_ &&
               native_preimport_tracker_->demand_seen(location_descriptor);
    }

    void clear_demand_locations() noexcept
    {
        if (native_preimport_tracker_) {
            native_preimport_tracker_->clear_demand_locations();
        }
    }

    void note_profile_portable_existence_hit() noexcept
    {
        if (translation_profile_) {
            translation_profile_->note_portable_existence_hit();
        }
    }
    void note_profile_portable_generated() noexcept
    {
        if (translation_profile_) {
            translation_profile_->note_profile_portable_generated();
        }
    }
    void note_profile_native_attempted() noexcept
    {
        if (translation_profile_) {
            translation_profile_->note_profile_native_attempted();
        }
    }
    void note_profile_native_executed() noexcept
    {
        if (translation_profile_) {
            translation_profile_->note_profile_native_executed();
        }
    }
    void note_profile_portable_attempted() noexcept
    {
        if (translation_profile_) {
            translation_profile_->note_profile_portable_attempted();
        }
    }
    void note_profile_portable_executed() noexcept
    {
        if (translation_profile_) {
            translation_profile_->note_profile_portable_executed();
        }
    }
    void note_native_preimport_attempted() noexcept
    {
        if (translation_profile_) {
            translation_profile_->note_native_preimport_attempted();
        }
    }
    void note_native_preimport_imported() noexcept
    {
        if (translation_profile_) {
            translation_profile_->note_native_preimport_imported();
        }
    }
    void note_native_preimport_already_present() noexcept
    {
        if (translation_profile_) {
            translation_profile_->note_native_preimport_already_present();
        }
    }
    void note_native_preimport_before_first_demand() noexcept
    {
        if (translation_profile_) {
            translation_profile_->note_native_preimport_before_first_demand();
        }
    }
    void note_profile_imported_before_first_run() noexcept
    {
        if (translation_profile_) {
            translation_profile_->note_profile_imported_before_first_run();
        }
    }
    void note_native_preimport_used(
        std::uint64_t first_use_distance = 0U) noexcept
    {
        if (translation_profile_) {
            translation_profile_->note_native_preimport_used(
                first_use_distance);
        }
    }

    void set_artifact_retention(JitArtifactRetention retention) noexcept
    {
        artifact_retention_ = retention;
    }

private:
    void maybe_check_host_yield(
        std::uint64_t ticks, bool force_clock_check) noexcept
    {
        if (!cooperative_execution_ || host_yield_requested_ ||
            (!force_clock_check && ticks_remaining_ == 0U)) {
            return;
        }
        host_yield_tick_accumulator_ = std::min(
            host_yield_max_tick_budget, host_yield_tick_accumulator_ + ticks);
        const auto probe_count = ++host_yield_probe_count_;
        if (!force_clock_check && probe_count < host_yield_check_interval_ &&
            host_yield_tick_accumulator_ < host_yield_tick_budget_) {
            return;
        }
        host_yield_probe_count_ = 0;
        host_yield_tick_accumulator_ = 0;
        ++host_yield_checks_;
        const auto now = std::chrono::steady_clock::now();
        if (now >= host_slice_deadline_) {
            request_host_yield();
            return;
        }

        const auto remaining =
            std::chrono::duration_cast<std::chrono::nanoseconds>(
                host_slice_deadline_ - now);
        if (remaining <= host_yield_urgent_window) {
            host_yield_check_interval_ = host_yield_min_check_interval;
            host_yield_tick_budget_ = host_yield_min_tick_budget;
        } else if (remaining <= std::chrono::milliseconds { 1 }) {
            host_yield_check_interval_ =
                (host_yield_min_check_interval +
                    host_yield_initial_check_interval) /
                2U;
            host_yield_tick_budget_ = host_yield_initial_tick_budget / 2U;
        } else {
            host_yield_check_interval_ = std::min(host_yield_max_check_interval,
                host_yield_check_interval_ + host_yield_min_check_interval);
            host_yield_tick_budget_ = std::min(
                host_yield_max_tick_budget, host_yield_tick_budget_ * 2U);
        }
    }

    [[nodiscard]] std::optional<JitArtifactKey> make_artifact_key(
        std::uint64_t location_descriptor) const noexcept
    {
        try {
            const auto pc = static_cast<std::uint32_t>(location_descriptor);
            const auto backing = memory_.executable_backing_identity(
                pc & ~std::uint32_t { 3 }, sizeof(std::uint32_t));
            if (!backing)
                return std::nullopt;

            JitArtifactKey key;
            key.content_identity = backing->content;
            key.layout_identity = backing->layout;
            key.guest_pc = pc;
            key.thumb = ((location_descriptor >> 32U) & 1U) != 0;
            key.location_descriptor = location_descriptor;
            key.architecture = cpu_model_.architecture_version();
            key.cpu_model = jit_artifact_cpu_model(cpu_model_);
            key.timing_model_version = 1U;
            key.guest_ticks_per_second = cpu_model_.ticks_per_second();
            key.image_slide = 0U;
            key.hle_abi_version = jit_artifact_hle_abi_version;
            key.backend_abi_version = jit_artifact_backend_abi_version;
            key.dynarmic_build_fingerprint =
                jit_artifact_dynarmic_build_fingerprint;
            key.codegen_options = jit_artifact_codegen_options;
            key.host_isa = jit_artifact_host_isa();
            key.host_feature_mask = jit_artifact_host_feature_mask();
            key.artifact_format_version = jit_artifact_format_version;
            return key;
        } catch (...) {
            return std::nullopt;
        }
    }

    [[nodiscard]] bool publish_artifact(std::uint64_t location_descriptor,
        std::uint64_t translation_nanoseconds,
        const Dynarmic::IR::Block* optimized_block) noexcept
    {
        if (!artifact_store_)
            return false;
        try {
            const auto* translation_block = translation_block_;
            translation_block_ = nullptr;
            auto key = make_artifact_key(location_descriptor);
            if (!key)
                return false;
            if (translation_code_pages_.empty())
                return false;
            if (constant_dependency_failed_)
                return false;

            JitArtifactData data;
            data.code_dependencies.reserve(translation_code_pages_.size());
            for (const auto page : translation_code_pages_) {
                const auto dependency = memory_.executable_backing_identity(
                    page, AddressSpace::page_size);
                if (!dependency)
                    return false;
                data.code_dependencies.push_back(
                    JitCodeDependency { page, AddressSpace::page_size,
                        dependency->content, dependency->layout });
            }
            data.constant_dependencies = translation_constant_dependencies_;
            if (optimized_block != nullptr) {
                const auto serialized = serialize_dynarmic_ir(*optimized_block);
                if (!serialized)
                    return false;
                if (portable_generation_location_ == location_descriptor) {
                    const auto validated = deserialize_dynarmic_ir(*serialized);
                    if (!validated ||
                        validated->Location().Value() != location_descriptor) {
                        return false;
                    }
                }
                data.normalized_ir = *serialized;
            } else if (translation_block != nullptr) {
                data.normalized_ir = normalized_ir(*translation_block);
            }
            data.translation_nanoseconds = translation_nanoseconds;
            return artifact_store_->publish(std::move(*key), std::move(data),
                       artifact_retention_) != nullptr;
        } catch (...) {
            return false;
        }
    }

    [[nodiscard]] static std::vector<std::byte> normalized_ir(
        const Dynarmic::IR::Block& block)
    {
        auto dump = Dynarmic::IR::DumpBlock(block);
        std::string canonical;
        canonical.reserve(dump.size());
        for (std::size_t index = 0; index < dump.size();) {
            if (dump[index] == '[' && index + 17U < dump.size() &&
                dump[index + 17U] == ']' &&
                std::all_of(
                    dump.begin() + static_cast<std::ptrdiff_t>(index + 1U),
                    dump.begin() + static_cast<std::ptrdiff_t>(index + 17U),
                    [](unsigned char value) {
                        return std::isxdigit(value) != 0;
                    })) {
                canonical += "[inst]";
                index += 18U;
                continue;
            }
            constexpr std::string_view unnamed = "<unnamed inst ";
            if (dump.compare(index, unnamed.size(), unnamed) == 0) {
                canonical += "<unnamed inst>";
                const auto end = dump.find('>', index + unnamed.size());
                index = end == std::string::npos ? dump.size() : end + 1U;
                continue;
            }
            canonical.push_back(dump[index++]);
        }
        const auto* begin =
            reinterpret_cast<const std::byte*>(canonical.data());
        return std::vector<std::byte>(begin, begin + canonical.size());
    }

    template <typename T, typename Member>
    T read(std::uint32_t address, Member member)
    {
        const auto value = (memory_.*member)(address, MemoryPermission::Read);
        if (!value) {
            memory_fault(address, sizeof(T), MemoryPermission::Read);
            return 0;
        }
        return *value;
    }

    template <typename T, typename Member>
    void write(std::uint32_t address, T value, Member member)
    {
        if (!(memory_.*member)(address, value)) {
            memory_fault(address, sizeof(T), MemoryPermission::Write);
        } else {
            notify_memory_write(address, sizeof(T), value);
        }
    }

    template <typename T, typename Member>
    T swap(std::uint32_t address, T value, Member member)
    {
        const auto previous = (memory_.*member)(address, value);
        if (!previous) {
            memory_fault(address, sizeof(T),
                MemoryPermission::Read | MemoryPermission::Write);
            return 0;
        }
        notify_memory_write(address, sizeof(T), value);
        return *previous;
    }

    template <typename T, typename Member>
    bool write_exclusive(
        std::uint32_t address, T value, T expected, Member member)
    {
        const auto written = (memory_.*member)(address, expected, value);
        if (written)
            notify_memory_write(address, sizeof(T), value);
        return written;
    }

    void notify_memory_write(
        std::uint32_t address, std::size_t size, std::uint64_t value)
    {
        if (!owner_->memory_write_watch_address_ ||
            !owner_->memory_write_handler_) {
            return;
        }
        const auto write_begin = static_cast<std::uint64_t>(address);
        const auto write_end = write_begin + size;
        const auto watched =
            static_cast<std::uint64_t>(*owner_->memory_write_watch_address_);
        if (watched >= write_begin && watched < write_end) {
            owner_->memory_write_handler_(*owner_, address, size, value);
        }
    }

    void memory_fault(
        std::uint32_t address, std::size_t size, MemoryPermission access)
    {
        performance_counters().record_page_fault();
        fault_ = MemoryFault { address, size, access,
            "unmapped address or protection failure" };
        if (jit_ != nullptr) {
            jit_->HaltExecution(Dynarmic::HaltReason::MemoryAbort);
        }
    }

    void request_host_yield() noexcept
    {
        host_yield_requested_ = true;
        ticks_remaining_ = 0;
        slice_ticks_remaining_ = 0;
        if (jit_ != nullptr) {
            jit_->HaltExecution(Dynarmic::HaltReason::UserDefined2);
        }
    }

    AddressSpace& memory_;
    const ArmCpuModel& cpu_model_;
    Cpu* owner_ { };
    Dynarmic::ExclusiveMonitor* exclusive_monitor_ { };
    std::size_t exclusive_processor_ { };
    std::uint32_t process_id_ { };
    Dynarmic::A32::Jit* jit_ { };
    std::uint64_t ticks_remaining_ { };
    std::uint64_t slice_ticks_remaining_ { };
    std::uint64_t consumed_ { };
    std::optional<std::uint32_t> svc_;
    std::uint64_t svc_calls_ { };
    std::optional<MemoryFault> fault_;
    std::optional<std::uint32_t> breakpoint_;
    std::string exception_;
    std::optional<Dynarmic::A32::Exception> exception_kind_;
    std::uint32_t exception_pc_ { };
    std::shared_ptr<JitTranslationProfile> translation_profile_;
    std::shared_ptr<JitArtifactStore> artifact_store_;
    JitArtifactRetention artifact_retention_ { JitArtifactRetention::Normal };
    bool explicit_artifact_publication_ { };
    std::optional<std::uint64_t> portable_generation_location_;
    bool portable_generation_published_ { };
    Dynarmic::IR::Block* translation_block_ { };
    std::vector<std::uint32_t> translation_code_pages_;
    std::vector<JitConstantDependency> translation_constant_dependencies_;
    bool constant_dependency_failed_ { };
    std::optional<Dynarmic::IR::Block> demand_artifact_;
    JitArtifactLookup demand_artifact_lookup_;
    JitArtifactKey demand_artifact_key_ { };
    std::uint64_t demand_artifact_location_ { };
    std::uint64_t demand_artifact_slab_generation_ { };
    DemandArtifactState demand_artifact_state_ { DemandArtifactState::Empty };
    bool cooperative_execution_ { };
    bool host_yield_requested_ { };
    std::uint32_t host_yield_probe_count_ { };
    std::uint32_t host_yield_check_interval_ { };
    std::uint64_t host_yield_tick_accumulator_ { };
    std::uint64_t host_yield_tick_budget_ { };
    std::uint64_t host_yield_checks_ { };
    std::chrono::steady_clock::time_point host_slice_deadline_ { };
    std::unique_ptr<JitTranslationProfileRecorder> translation_recorder_;
    std::shared_ptr<JitWorkObservationSignal> jit_work_signal_;
    std::shared_ptr<JitNativePreimportTracker> native_preimport_tracker_;
};

class ArmSystemControlCoprocessor final : public Dynarmic::A32::Coprocessor {
public:
    using CoprocReg = Dynarmic::A32::CoprocReg;
    using Callback = Dynarmic::A32::Coprocessor::Callback;
    using CallbackOrAccessOneWord =
        Dynarmic::A32::Coprocessor::CallbackOrAccessOneWord;
    using CallbackOrAccessTwoWords =
        Dynarmic::A32::Coprocessor::CallbackOrAccessTwoWords;

    explicit ArmSystemControlCoprocessor(JitCallbacks& callbacks)
        : callbacks_ { callbacks }
    {
    }

    std::optional<Callback> CompileInternalOperation(
        bool, unsigned, CoprocReg, CoprocReg, CoprocReg, unsigned) override
    {
        return std::nullopt;
    }

    CallbackOrAccessOneWord CompileSendOneWord(bool two, unsigned opc1,
        CoprocReg CRn, CoprocReg CRm, unsigned opc2) override
    {
        if (two || opc1 != 0) {
            return std::monostate { };
        }

        if (CRn == CoprocReg::C7 || CRn == CoprocReg::C8) {
            return Callback { &noop, nullptr };
        }

        if (CRn == CoprocReg::C13 && CRm == CoprocReg::C0 &&
            (opc2 == 2 || opc2 == 7)) {
            return Callback { &write_thread_pointer, &callbacks_ };
        }

        return std::monostate { };
    }

    CallbackOrAccessTwoWords CompileSendTwoWords(
        bool, unsigned, CoprocReg) override
    {
        return std::monostate { };
    }

    CallbackOrAccessOneWord CompileGetOneWord(bool two, unsigned opc1,
        CoprocReg CRn, CoprocReg CRm, unsigned opc2) override
    {
        if (!two && opc1 == 0 && CRn == CoprocReg::C13 &&
            CRm == CoprocReg::C0 && (opc2 == 2 || opc2 == 3 || opc2 == 7)) {
            return Callback { &read_thread_pointer, &callbacks_ };
        }
        return std::monostate { };
    }

    CallbackOrAccessTwoWords CompileGetTwoWords(
        bool, unsigned, CoprocReg) override
    {
        return std::monostate { };
    }

    std::optional<Callback> CompileLoadWords(
        bool, bool, CoprocReg, std::optional<std::uint8_t>) override
    {
        return std::nullopt;
    }

    std::optional<Callback> CompileStoreWords(
        bool, bool, CoprocReg, std::optional<std::uint8_t>) override
    {
        return std::nullopt;
    }

private:
    static std::uint64_t noop(void*, std::uint32_t, std::uint32_t) { return 0; }

    static std::uint64_t read_thread_pointer(
        void* user_arg, std::uint32_t, std::uint32_t)
    {
        const auto& callbacks = *reinterpret_cast<JitCallbacks*>(user_arg);
        const auto* cpu = callbacks.current_cpu();
        return cpu == nullptr ? 0 : cpu->cthread_self().value_or(0);
    }

    static std::uint64_t write_thread_pointer(
        void* user_arg, std::uint32_t value, std::uint32_t)
    {
        const auto& callbacks = *reinterpret_cast<JitCallbacks*>(user_arg);
        if (auto* cpu = callbacks.current_cpu(); cpu != nullptr) {
            cpu->set_cthread_self(value);
        }
        return 0;
    }

    JitCallbacks& callbacks_;
};

class JitExecutor {
public:
    enum class PrecompileDisposition : std::uint8_t {
        NativeCompiled,
        PortableGenerated,
        PortableArtifactHit,
        ArtifactImported,
        ArtifactProbeHit,
        SharedSlabHit,
        Deferred,
        Unstable,
        CacheFull,
        Failed,
    };

    JitExecutor(std::size_t processor_id, std::size_t execution_slot,
        AddressSpace& memory, Dynarmic::ExclusiveMonitor& monitor,
        const ArmCpuModel& cpu_model,
        std::shared_ptr<JitArtifactStore> artifact_store,
        std::shared_ptr<ExecutionContext> execution_context,
        std::shared_ptr<JitNativePreimportTracker> native_preimport_tracker)
        : processor_id_ { processor_id }
        , execution_slot_ { execution_slot }
        , memory_ { memory }
        , monitor_ { monitor }
        , callbacks_ { std::make_unique<JitCallbacks>(memory, cpu_model,
              std::move(artifact_store), native_preimport_tracker) }
        , cp15_ { std::make_unique<ArmSystemControlCoprocessor>(*callbacks_) }
        , execution_context_ { std::move(execution_context) }
        , native_preimport_tracker_ { std::move(native_preimport_tracker) }
    {
        if (!execution_context_) {
            throw std::invalid_argument {
                "JIT executor requires execution state"
            };
        }
        runtime_link_cell_ = execution_context_->create_link_cell();
        execution_context_->link(runtime_link_cell_,
            static_cast<std::uint64_t>(
                reinterpret_cast<std::uintptr_t>(callbacks_.get())));
        runtime_link_cell_address_ =
            execution_context_->link_cell_address(runtime_link_cell_);
        lookup_link_cell_ = execution_context_->create_link_cell();
        execution_context_->link(lookup_link_cell_, 0);
        lookup_link_cell_address_ =
            execution_context_->link_cell_address(lookup_link_cell_);
        runtime_config_link_cell_ = execution_context_->create_link_cell();
        execution_context_->link(runtime_config_link_cell_, 0);
        runtime_config_link_cell_address_ =
            execution_context_->link_cell_address(runtime_config_link_cell_);
        fast_dispatch_table_link_cell_ = execution_context_->create_link_cell();
        execution_context_->link(fast_dispatch_table_link_cell_, 0);
        fast_dispatch_table_link_cell_address_ =
            execution_context_->link_cell_address(
                fast_dispatch_table_link_cell_);
        page_table_link_cell_ = execution_context_->create_link_cell();
        execution_context_->link(page_table_link_cell_, 0);
        page_table_link_cell_address_ =
            execution_context_->link_cell_address(page_table_link_cell_);
        read_page_table_link_cell_ = execution_context_->create_link_cell();
        execution_context_->link(read_page_table_link_cell_, 0);
        read_page_table_link_cell_address_ =
            execution_context_->link_cell_address(read_page_table_link_cell_);
        exclusive_monitor_lock_link_cell_ =
            execution_context_->create_link_cell();
        execution_context_->link(exclusive_monitor_lock_link_cell_,
            static_cast<std::uint64_t>(reinterpret_cast<std::uintptr_t>(
                Dynarmic::GetExclusiveMonitorLockPointer(&monitor_))));
        exclusive_monitor_lock_link_cell_address_ =
            execution_context_->link_cell_address(
                exclusive_monitor_lock_link_cell_);
        exclusive_monitor_addresses_link_cell_ =
            execution_context_->create_link_cell();
        execution_context_->link(exclusive_monitor_addresses_link_cell_,
            static_cast<std::uint64_t>(reinterpret_cast<std::uintptr_t>(
                Dynarmic::GetExclusiveMonitorAddressPointer(&monitor_, 0))));
        exclusive_monitor_addresses_link_cell_address_ =
            execution_context_->link_cell_address(
                exclusive_monitor_addresses_link_cell_);
        exclusive_monitor_values_link_cell_ =
            execution_context_->create_link_cell();
        execution_context_->link(exclusive_monitor_values_link_cell_,
            static_cast<std::uint64_t>(reinterpret_cast<std::uintptr_t>(
                Dynarmic::GetExclusiveMonitorValuePointer(&monitor_, 0))));
        exclusive_monitor_values_link_cell_address_ =
            execution_context_->link_cell_address(
                exclusive_monitor_values_link_cell_);
    }

    ~JitExecutor()
    {
        callbacks_->flush_translation_profile_recorder();
        const bool had_jit = static_cast<bool>(jit_);
        jit_.reset();
        execution_context_->unlink(runtime_link_cell_);
        execution_context_->unlink(lookup_link_cell_);
        execution_context_->unlink(runtime_config_link_cell_);
        execution_context_->unlink(fast_dispatch_table_link_cell_);
        execution_context_->unlink(page_table_link_cell_);
        execution_context_->unlink(read_page_table_link_cell_);
        execution_context_->unlink(exclusive_monitor_lock_link_cell_);
        execution_context_->unlink(exclusive_monitor_addresses_link_cell_);
        execution_context_->unlink(exclusive_monitor_values_link_cell_);
        performance_counters().record_jit_executor_memory_usage(
            execution_context_->context_id(), process_id_,
            static_cast<std::uint32_t>(execution_slot_), 0);
        if (had_jit) {
            performance_counters().record_jit_destroyed();
        }
    }

    CpuRunResult run(Cpu& cpu, std::uint64_t ticks, bool single_step,
        bool cooperative_execution,
        std::chrono::nanoseconds host_slice_budget =
            default_host_cooperative_slice_budget)
    {
        CpuRunPhaseDiagnostics diagnostics { process_id_,
            static_cast<std::uint32_t>(cpu.processor_id()),
            static_cast<std::uint32_t>(execution_slot_),
            single_step ? 1U : ticks };
        const std::unique_lock lock { execution_mutex_ };
        diagnostics.checkpoint(PerfLatencyKind::CpuRunLockWait);
        memory_.synchronize_shared_write_tracking();
        diagnostics.checkpoint(PerfLatencyKind::CpuRunSharedWriteSync);
        ensure_jit();
        if (!demand_artifact_enabled_ &&
            callbacks_->artifact_publication_generation() != 0U &&
            callbacks_->demand_artifact_catalog_nonempty()) {
            demand_artifact_enabled_ = true;
        }
        diagnostics.checkpoint(PerfLatencyKind::CpuRunEnsureJit);
        service_pending_shared_invalidation();
        observe_shared_invalidation_epoch();
        diagnostics.checkpoint(PerfLatencyKind::CpuRunInvalidation);
        load_state(cpu);
        diagnostics.checkpoint(PerfLatencyKind::CpuRunLoadState);
        const auto effective_host_slice_budget =
            std::max(host_slice_budget, std::chrono::nanoseconds::zero());
        const auto profiling_blocks =
            performance_counters().block_profile_enabled();
        callbacks_->begin(single_step ? 1 : ticks,
            cooperative_execution && !single_step, effective_host_slice_budget);
        diagnostics.checkpoint(PerfLatencyKind::CpuRunCallbacksBegin);
        try {
            const auto entry_location =
                single_step ? 0U : current_location_descriptor();
            bool portable_demand_provider_enabled { };
            if (!single_step && demand_artifact_enabled_ &&
                !jit_demand_disabled() && !jit_portable_handoff_disabled() &&
                !jit_sync_preload_disabled()) {
                portable_demand_provider_enabled = preload_current_artifact();
                set_portable_demand_provider(portable_demand_provider_enabled);
            }
            diagnostics.checkpoint(PerfLatencyKind::CpuRunArtifactPreload);
            const auto native_block_budget =
                cooperative_execution && !single_step
                ? host_execution_budget_.next(effective_host_slice_budget)
                : 0U;
            const auto jit_started = std::chrono::steady_clock::now();
            const auto profiling_calls = profiling_blocks && !single_step;
            decltype(jit_->GetHostExecutionBudgetResult()) native_budget_result { };
            std::uint32_t native_blocks_executed { };
            Dynarmic::HaltReason reason { };
            for (;;) {
                const auto consumed_before = callbacks_->consumed_ticks();
                std::uint64_t block_location { };
                std::uint32_t block_caller { };
                std::optional<StackAttribution> block_stack;
                std::vector<std::uint32_t> block_chain;
                if (profiling_calls) {
                    callbacks_->begin_jit_call(1);
                    block_location = current_location_descriptor();
                    const Dynarmic::A32::LocationDescriptor block_descriptor {
                        Dynarmic::IR::LocationDescriptor { block_location }
                    };
                    block_caller = jit_->Regs()[14];
                    block_stack = attribute_run_stack(block_descriptor.PC());
                    block_chain = capture_run_chain(block_descriptor.PC());
                }
                jit_->SetHostExecutionBlockBudget(
                    native_block_budget == 0U
                        ? 0U
                        : native_block_budget - native_blocks_executed);
                reason = single_step ? jit_->Step() : jit_->Run();
                native_budget_result = jit_->GetHostExecutionBudgetResult();
                native_blocks_executed += native_budget_result.blocks_executed;
                if (profiling_calls) {
                    const auto block_ticks =
                        callbacks_->consumed_ticks() - consumed_before;
                    const Dynarmic::A32::LocationDescriptor block_descriptor {
                        Dynarmic::IR::LocationDescriptor { block_location }
                    };
                    performance_counters().block_profile().record_run(
                        static_cast<std::uint32_t>(process_id_), block_location,
                        block_descriptor.PC(), block_descriptor.TFlag(),
                        block_ticks, block_caller);
                    performance_counters().block_profile().record_stack(
                        static_cast<std::uint32_t>(process_id_), *block_stack,
                        block_ticks);
                    performance_counters().block_profile().record_chain(
                        static_cast<std::uint32_t>(process_id_),
                        cpu.guest_thread_, block_location,
                        block_descriptor.PC(), block_descriptor.TFlag(),
                        std::move(block_chain), block_ticks);
                }
                const auto halted_for_ticks = reason == Dynarmic::HaltReason {} ||
                                              reason == Dynarmic::HaltReason::Step;
                if (!profiling_calls || !halted_for_ticks ||
                    callbacks_->slice_ticks_remaining() == 0U ||
                    callbacks_->host_yield_pending() ||
                    native_budget_result.exhausted ||
                    (native_block_budget != 0U &&
                        native_blocks_executed >= native_block_budget)) {
                    break;
                }
                jit_->ClearHalt(Dynarmic::HaltReason::Step);
            }
            native_budget_result.blocks_executed = native_blocks_executed;
            const auto jit_elapsed =
                std::chrono::duration_cast<std::chrono::nanoseconds>(
                    std::chrono::steady_clock::now() - jit_started);
            if (portable_demand_provider_enabled)
                set_portable_demand_provider(false);
            diagnostics.checkpoint(PerfLatencyKind::CpuRunExecute);
            record_dispatch_counters();
            auto result = callbacks_->result(reason);
            const auto callback_host_yielded = result.host_yielded;
            if (native_budget_result.supported) {
                result.host_yield_checks +=
                    native_budget_result.blocks_executed;
                result.host_yielded =
                    result.host_yielded || native_budget_result.exhausted;
                if (native_budget_result.exhausted && !callback_host_yielded) {
                    host_execution_budget_.observe(
                        native_budget_result.blocks_executed, jit_elapsed);
                }
            }
            if (entry_location != 0U && result.ticks_consumed != 0U) {
                mark_native_preimport_used(entry_location);
                callbacks_->finish_demand_artifact(entry_location);
            }
            if (guest_preemption_requested_) {
                performance_counters().record_scheduler_preemption_return();
                if (guest_preemption_requested_at_) {
                    const auto elapsed =
                        std::chrono::duration_cast<std::chrono::nanoseconds>(
                            std::chrono::steady_clock::now() -
                            *guest_preemption_requested_at_)
                            .count();
                    performance_counters().record_latency(
                        PerfLatencyKind::SchedulerPreemptionRequestToReturn,
                        static_cast<std::uint64_t>(
                            std::max<std::int64_t>(0, elapsed)));
                }
                guest_preemption_requested_ = false;
                guest_preemption_requested_at_.reset();
            }
            diagnostics.record_result(result.ticks_consumed,
                result.host_yield_checks, result.host_yielded, result.svc_calls,
                result.svc, result.reason);
            performance_counters().record_jit_host_yield(
                result.host_yield_checks, result.host_yielded);
            if (cooperative_execution && !single_step) {
                performance_counters().record_jit_host_slice_budget(
                    static_cast<std::uint64_t>(
                        effective_host_slice_budget.count()));
            }
            diagnostics.checkpoint(PerfLatencyKind::CpuRunResult);
            save_state(cpu);
            diagnostics.checkpoint(PerfLatencyKind::CpuRunSaveState);
            record_code_cache_usage();
            performance_counters().record_cpu_execution(result.ticks_consumed);
            diagnostics.checkpoint(PerfLatencyKind::CpuRunCacheAccounting);
            return result;
        } catch (...) {
            set_portable_demand_provider(false);
            guest_preemption_requested_ = false;
            guest_preemption_requested_at_.reset();
            record_dispatch_counters();
            save_state(cpu);
            record_code_cache_usage();
            throw;
        }
    }

    [[nodiscard]] std::uint64_t code_cache_used()
    {
        const std::lock_guard lock { execution_mutex_ };
        return jit_ ? jit_code_cache_used(*jit_) : 0U;
    }

    void clear_halt()
    {
        guest_preemption_requested_ = false;
        guest_preemption_requested_at_.reset();
        if (jit_) {
            jit_->ClearHalt(all_halt_reasons());
        }
    }

    void halt(Dynarmic::HaltReason reason)
    {
        if (jit_) {
            jit_->HaltExecution(reason);
        }
    }

    void request_guest_preemption()
    {
        if (!guest_preemption_requested_) {
            guest_preemption_requested_ = true;
            if (performance_counters().cpu_source_diagnostics_enabled()) {
                guest_preemption_requested_at_ =
                    std::chrono::steady_clock::now();
            }
        }
        halt(Dynarmic::HaltReason::UserDefined2);
    }

    [[nodiscard]] bool guest_preemption_requested() const noexcept
    {
        return guest_preemption_requested_;
    }

    void raise_memory_fault(
        std::uint32_t address, std::size_t size, MemoryPermission access)
    {
        if (jit_ != nullptr) {
            callbacks_->raise_memory_fault(address, size, access);
        }
    }

    void clear_exclusive_state()
    {
        ensure_jit();
        jit_->ClearExclusiveState();
        monitor_.ClearProcessor(processor_id_);
        callbacks_->drop_exclusive_state();
    }

    void set_translation_profile(std::shared_ptr<JitTranslationProfile> profile,
        bool record,
        std::shared_ptr<JitNativePreimportTracker> native_preimport_tracker)
    {
        const std::lock_guard execution_lock { execution_mutex_ };
        native_prediction_baseline_bytes_.reset();
        native_preimport_tracker_ = std::move(native_preimport_tracker);
        callbacks_->set_translation_profile(
            std::move(profile), record, native_preimport_tracker_);
    }

    void set_jit_work_signal(std::shared_ptr<JitWorkObservationSignal> signal)
    {
        const std::lock_guard execution_lock { execution_mutex_ };
        callbacks_->set_jit_work_signal(std::move(signal));
    }

    void set_artifact_retention(JitArtifactRetention retention)
    {
        const std::lock_guard execution_lock { execution_mutex_ };
        callbacks_->set_artifact_retention(retention);
    }

    void flush_translation_profile()
    {
        const std::lock_guard execution_lock { execution_mutex_ };
        callbacks_->flush_translation_profile_recorder();
    }

    PrecompileDisposition precompile_descriptor(std::uint64_t descriptor,
        JitPrecompileTarget target, bool profile_derived)
    {
        const std::lock_guard execution_lock { execution_mutex_ };
        memory_.synchronize_shared_write_tracking();
        ensure_jit();
        service_pending_shared_invalidation();
        observe_shared_cache_state();
        if (target == JitPrecompileTarget::NativeCode) {
            const auto policy =
                JitWorkPolicy::native_prediction_policy(code_cache_size_);
            const auto demand_floor =
                JitCodeCacheGovernor::minimum_demand_working_set_bytes;
            const auto speculative_capacity =
                code_cache_size_ > demand_floor
                    ? std::min(policy.maximum_code_bytes,
                          code_cache_size_ - demand_floor)
                    : std::size_t { 0U };
            const auto used = jit_code_cache_used(*jit_);
            if (!native_prediction_baseline_bytes_ ||
                used < *native_prediction_baseline_bytes_) {
                native_prediction_baseline_bytes_ = used;
            }
            if (speculative_capacity == 0U ||
                used - *native_prediction_baseline_bytes_ >=
                    speculative_capacity ||
                used >= code_cache_size_ ||
                code_cache_size_ - used < host_code_page_size) {
                return PrecompileDisposition::CacheFull;
            }
        }
        const auto pc = static_cast<std::uint32_t>(descriptor);
        const auto code_address = pc & ~std::uint32_t { 3 };
        if (!memory_.accessible(code_address, sizeof(std::uint32_t),
                MemoryPermission::Execute)) {
            return PrecompileDisposition::Deferred;
        }
        if (!memory_.translation_profile_stable(
                code_address, sizeof(std::uint32_t))) {
            callbacks_->discard_translation_location(descriptor);
            return PrecompileDisposition::Unstable;
        }
        const auto key = callbacks_->artifact_key(descriptor);
        const auto probe =
            key ? artifact_probes_.find(descriptor) : artifact_probes_.end();
        if (target == JitPrecompileTarget::NativeCode && key &&
            probe != artifact_probes_.end() && probe->second.matches(*key)) {
            return PrecompileDisposition::ArtifactProbeHit;
        }
        if (target == JitPrecompileTarget::PortableIr) {
            auto available = callbacks_->artifact_available(descriptor);
            if (available) {
                if (profile_derived) {
                    callbacks_->note_profile_portable_existence_hit();
                }
                return PrecompileDisposition::PortableArtifactHit;
            }
            if (!available) {
                callbacks_->begin(0);
                available =
                    callbacks_->generate_portable_artifact(*jit_, descriptor);
            }
            record_code_cache_usage();
            if (profile_derived && available) {
                callbacks_->note_profile_portable_generated();
            }
            return available ? PrecompileDisposition::PortableGenerated
                             : PrecompileDisposition::Failed;
        }
        const bool before_first_demand =
            !callbacks_->demand_location_seen(descriptor);
        if (profile_derived) {
            callbacks_->note_native_preimport_attempted();
        }
        const auto imported = callbacks_->import_artifact(*jit_, descriptor);
        if (imported == JitCallbacks::ArtifactImportOutcome::Imported) {
            if (profile_derived) {
                callbacks_->note_native_preimport_imported();
                if (before_first_demand) {
                    callbacks_->note_native_preimport_before_first_demand();
                    callbacks_->note_profile_imported_before_first_run();
                }
            }
            if (key) {
                artifact_probes_[descriptor] =
                    ArtifactProbe { key->content_identity, key->layout_identity,
                        true, callbacks_->artifact_publication_generation() };
            }
            if (profile_derived && before_first_demand) {
                mark_native_preimported(descriptor);
            }
            record_code_cache_usage();
            return PrecompileDisposition::ArtifactImported;
        }
        if (imported == JitCallbacks::ArtifactImportOutcome::AlreadyPresent) {
            if (profile_derived) {
                callbacks_->note_native_preimport_already_present();
            }
            if (key) {
                artifact_probes_[descriptor] =
                    ArtifactProbe { key->content_identity, key->layout_identity,
                        true, callbacks_->artifact_publication_generation() };
            }
            record_code_cache_usage();
            return PrecompileDisposition::SharedSlabHit;
        }
        bool newly_emitted { };
        try {
            const auto block_started = std::chrono::steady_clock::now();
            callbacks_->set_explicit_artifact_publication(true);
            callbacks_->begin(0);
            newly_emitted = jit_->Precompile(descriptor);
            callbacks_->set_explicit_artifact_publication(false);
            performance_counters().record_jit_block_compile(
                static_cast<std::uint64_t>(
                    std::chrono::duration_cast<std::chrono::nanoseconds>(
                        std::chrono::steady_clock::now() - block_started)
                        .count()));
        } catch (...) {
            callbacks_->set_explicit_artifact_publication(false);
            return PrecompileDisposition::Failed;
        }
        if (key) {
            artifact_probes_[descriptor] =
                ArtifactProbe { key->content_identity, key->layout_identity,
                    imported == JitCallbacks::ArtifactImportOutcome::Imported ||
                        imported ==
                            JitCallbacks::ArtifactImportOutcome::AlreadyPresent,
                    callbacks_->artifact_publication_generation() };
        }
        record_code_cache_usage();
        return newly_emitted ? PrecompileDisposition::NativeCompiled
                             : PrecompileDisposition::SharedSlabHit;
    }

    void reset_live_state()
    {
        ensure_jit();
        set_portable_demand_provider(false);
        guest_preemption_requested_ = false;
        guest_preemption_requested_at_.reset();
        callbacks_->discard_demand_artifact();
        clear_demand_artifact_probes();
        if (native_preimport_tracker_)
            native_preimport_tracker_->clear();
        callbacks_->clear_demand_locations();
        jit_->Reset();
    }

    [[nodiscard]] std::array<std::uint32_t, 16>& registers()
    {
        return jit_->Regs();
    }

    [[nodiscard]] const std::array<std::uint32_t, 16>& registers() const
    {
        return jit_->Regs();
    }

    [[nodiscard]] std::array<std::uint32_t, 64>& extension_registers()
    {
        return jit_->ExtRegs();
    }

    [[nodiscard]] const std::array<std::uint32_t, 64>&
    extension_registers() const
    {
        return jit_->ExtRegs();
    }

    [[nodiscard]] std::uint32_t cpsr() const { return jit_->Cpsr(); }

    void set_cpsr(std::uint32_t value) { jit_->SetCpsr(value); }

    [[nodiscard]] std::uint32_t fpscr() const { return jit_->Fpscr(); }

    void set_fpscr(std::uint32_t value) { jit_->SetFpscr(value); }

private:
    static void native_code_block_lookup(
        void* user_arg, std::uint64_t location_descriptor) noexcept
    {
        static_cast<JitExecutor*>(user_arg)->mark_native_preimport_used(
            location_descriptor);
    }

    static Dynarmic::IR::Block* portable_ir_demand_provider(void* user_arg,
        std::uint64_t location_descriptor,
        std::uint64_t slab_generation) noexcept
    {
        auto& executor = *static_cast<JitExecutor*>(user_arg);
        return executor.callbacks_->take_demand_artifact(
            location_descriptor, slab_generation);
    }

    static void portable_ir_emit_completion(void* user_arg,
        std::uint64_t location_descriptor, std::uint64_t slab_generation,
        Dynarmic::A32::Jit::PortableIREmitOutcome outcome) noexcept
    {
        auto& executor = *static_cast<JitExecutor*>(user_arg);
        if (!executor.callbacks_->complete_demand_artifact_emit(
                location_descriptor, slab_generation, outcome)) {
            return;
        }
        const auto probe =
            executor.demand_artifact_probes_.find(location_descriptor);
        if (probe == executor.demand_artifact_probes_.end() ||
            probe->second.slab_generation != slab_generation) {
            return;
        }
        probe->second.result = JitDemandArtifactStageResult::TransientFailure;
        probe->second.transient_backoff.record_failure(
            executor.demand_artifact_attempt_generation_);
    }

    struct ArtifactProbe {
        ContentIdentity content_identity;
        ContentIdentity layout_identity;
        bool imported { };
        std::uint64_t publication_generation { };

        [[nodiscard]] bool matches(const JitArtifactKey& key) const noexcept
        {
            return imported && content_identity == key.content_identity &&
                   layout_identity == key.layout_identity;
        }
    };

    struct DemandArtifactProbe {
        JitArtifactKey key;
        std::uint64_t key_fingerprint { };
        std::uint64_t publication_generation { };
        std::uint64_t slab_generation { };
        std::uint64_t invalidation_epoch { };
        std::uint64_t executable_content_generation { };
        JitDemandArtifactStageResult result {
            JitDemandArtifactStageResult::ExactMiss
        };
        JitDemandArtifactTransientBackoff transient_backoff;

        [[nodiscard]] bool cheap_matches(
            std::uint64_t candidate_publication_generation,
            std::uint64_t candidate_slab_generation,
            std::uint64_t candidate_invalidation_epoch,
            std::uint64_t candidate_executable_content_generation)
            const noexcept
        {
            return publication_generation == candidate_publication_generation &&
                   slab_generation == candidate_slab_generation &&
                   invalidation_epoch == candidate_invalidation_epoch &&
                   (executable_content_generation ==
                           candidate_executable_content_generation ||
                       jit_test_ignore_demand_probe_content_generation());
        }

        [[nodiscard]] bool matches(const JitArtifactKey& candidate,
            std::uint64_t candidate_publication_generation,
            std::uint64_t candidate_slab_generation,
            std::uint64_t candidate_invalidation_epoch,
            std::uint64_t candidate_executable_content_generation)
            const noexcept
        {
            return key == candidate &&
                   publication_generation == candidate_publication_generation &&
                   slab_generation == candidate_slab_generation &&
                   invalidation_epoch == candidate_invalidation_epoch &&
                   executable_content_generation ==
                       candidate_executable_content_generation;
        }

        [[nodiscard]] bool fingerprint_matches(
            const JitArtifactKey& candidate) const noexcept
        {
            return key_fingerprint == demand_probe_fingerprint(candidate);
        }
    };

    void mark_native_preimported(std::uint64_t location_descriptor) noexcept
    {
        if (!native_preimport_tracker_) {
            return;
        }
        native_preimport_tracker_->mark(
            location_descriptor, native_lookup_sequence_);
    }

    void mark_native_preimport_used(std::uint64_t location_descriptor) noexcept
    {
        if (!native_preimport_tracker_) {
            return;
        }
        if (native_lookup_sequence_ !=
            std::numeric_limits<std::uint64_t>::max()) {
            ++native_lookup_sequence_;
        }
        std::uint64_t first_use_distance { };
        if (native_preimport_tracker_->has_ready() &&
            native_preimport_tracker_->consume(location_descriptor,
                native_lookup_sequence_, &first_use_distance)) {
            callbacks_->note_native_preimport_used(first_use_distance);
        }
    }

    [[nodiscard]] std::uint64_t current_location_descriptor() const
    {
        const Dynarmic::A32::LocationDescriptor descriptor { jit_->Regs()[15],
            Dynarmic::A32::PSR { jit_->Cpsr() },
            Dynarmic::A32::FPSCR { jit_->Fpscr() } };
        return static_cast<Dynarmic::IR::LocationDescriptor>(descriptor)
            .Value();
    }

    [[nodiscard]] bool preload_current_artifact()
    {
        if (demand_artifact_attempt_generation_ !=
            std::numeric_limits<std::uint64_t>::max()) {
            ++demand_artifact_attempt_generation_;
        }
        const auto location = current_location_descriptor();
        const auto slab_generation =
            execution_context_->native_code_slab()->generation_snapshot();
        if (callbacks_->demand_artifact_staged(location, slab_generation))
            return true;
        if (callbacks_->demand_artifact_native_ready(location, slab_generation))
            return false;
        const auto publication_generation =
            callbacks_->artifact_publication_generation();
        const auto invalidation_epoch =
            execution_context_->cache_invalidation_epoch();
        const auto executable_content_generation =
            memory_.executable_content_generation();
        const auto probe = demand_artifact_probes_.find(location);
        JitDemandArtifactTransientBackoff transient_backoff;
        if (probe != demand_artifact_probes_.end()) {
            const auto cheap_match = probe->second.cheap_matches(
                publication_generation, slab_generation, invalidation_epoch,
                executable_content_generation);
            if (cheap_match &&
                !jit_test_ignore_demand_probe_content_generation()) {
                if (probe->second.result !=
                        JitDemandArtifactStageResult::TransientFailure ||
                    !probe->second.transient_backoff.retry_due(
                        demand_artifact_attempt_generation_)) {
                    callbacks_->record_demand_negative_probe_hit();
                    return false;
                }
                transient_backoff = probe->second.transient_backoff;
                callbacks_->record_demand_transient_retry();
            } else if (!cheap_match) {
                callbacks_->record_demand_generation_retry();
            }
        }
        const auto key = callbacks_->artifact_key(location);
        if (!key)
            return false;
        if (probe != demand_artifact_probes_.end()) {
            if (probe->second.fingerprint_matches(*key)) {
                callbacks_->record_demand_probe_fingerprint_hit();
            }
        }
        if (probe != demand_artifact_probes_.end() &&
            probe->second.cheap_matches(publication_generation, slab_generation,
                invalidation_epoch, executable_content_generation) &&
            !probe->second.matches(*key, publication_generation,
                slab_generation, invalidation_epoch,
                executable_content_generation)) {
            if (probe->second.fingerprint_matches(*key)) {
                callbacks_->record_demand_probe_fingerprint_collision();
            }
            callbacks_->record_demand_generation_retry();
        }
        callbacks_->record_demand_stage_attempt();
        const auto result =
            callbacks_->stage_demand_artifact(location, slab_generation, *key);
        if (result == JitDemandArtifactStageResult::Staged) {
            transient_backoff.reset();
        } else {
            performance_counters().record_jit_demand_artifact_probe(false);
        }
        if (result == JitDemandArtifactStageResult::TransientFailure) {
            transient_backoff.record_failure(
                demand_artifact_attempt_generation_);
        }
        constexpr std::size_t maximum_demand_artifact_probes = 4096U;
        if (probe == demand_artifact_probes_.end()) {
            if (demand_artifact_probes_.size() >=
                maximum_demand_artifact_probes) {
                const auto victim = demand_artifact_probe_order_.front();
                demand_artifact_probe_order_.pop_front();
                demand_artifact_probes_.erase(victim);
                callbacks_->record_demand_probe_eviction();
            }
            demand_artifact_probe_order_.push_back(location);
        }
        const auto key_fingerprint = demand_probe_fingerprint(*key);
        demand_artifact_probes_.insert_or_assign(location,
            DemandArtifactProbe { *key, key_fingerprint, publication_generation,
                slab_generation, invalidation_epoch,
                executable_content_generation, result, transient_backoff });
        callbacks_->record_demand_probe_size(demand_artifact_probes_.size());
        return result == JitDemandArtifactStageResult::Staged;
    }

    void set_portable_demand_provider(bool enabled) noexcept
    {
        if (!jit_ || portable_demand_provider_installed_ == enabled)
            return;
        jit_->SetPortableIRDemandProvider(
            enabled ? &JitExecutor::portable_ir_demand_provider : nullptr,
            enabled ? this : nullptr);
        jit_->SetPortableIREmitCompletion(
            enabled ? &JitExecutor::portable_ir_emit_completion : nullptr,
            enabled ? this : nullptr);
        portable_demand_provider_installed_ = enabled;
    }

    void clear_demand_artifact_probes()
    {
        demand_artifact_probes_.clear();
        demand_artifact_probe_order_.clear();
        callbacks_->record_demand_probe_size(0U);
    }

    void observe_shared_invalidation_epoch()
    {
        const auto invalidation_epoch =
            execution_context_->cache_invalidation_epoch();
        if (invalidation_epoch == observed_invalidation_epoch_)
            return;
        artifact_probes_.clear();
        clear_demand_artifact_probes();
        callbacks_->clear_demand_locations();
        callbacks_->discard_demand_artifact();
        observed_invalidation_epoch_ = invalidation_epoch;
    }

    void service_pending_shared_invalidation()
    {
        if (execution_context_->cache_invalidation_epoch() ==
            observed_invalidation_epoch_) {
            return;
        }
        execution_context_->native_code_slab()->service_pending_invalidation();
        const auto slab_generation =
            execution_context_->native_code_slab()->generation();
        if (execution_context_->observe_slab_generation(slab_generation)) {
            performance_counters().record_jit_slab_generation_transition(
                execution_context_->process_id());
        }
    }

    void observe_shared_cache_state()
    {
        observe_shared_invalidation_epoch();
        const auto slab_generation =
            execution_context_->native_code_slab()->generation();
        if (execution_context_->observe_slab_generation(slab_generation)) {
            performance_counters().record_jit_slab_generation_transition(
                execution_context_->process_id());
        }
        if (observed_slab_generation_ == 0U) {
            observed_slab_generation_ = slab_generation;
            return;
        }
        if (slab_generation == observed_slab_generation_)
            return;
        artifact_probes_.clear();
        clear_demand_artifact_probes();
        if (native_preimport_tracker_)
            native_preimport_tracker_->clear();
        callbacks_->clear_demand_locations();
        callbacks_->discard_demand_artifact();
        observed_slab_generation_ = slab_generation;
    }

    [[nodiscard]] static constexpr Dynarmic::HaltReason all_halt_reasons()
    {
        return Dynarmic::HaltReason::CacheInvalidation |
               Dynarmic::HaltReason::MemoryAbort |
               Dynarmic::HaltReason::UserDefined1 |
               Dynarmic::HaltReason::UserDefined2 |
               Dynarmic::HaltReason::UserDefined3 |
               Dynarmic::HaltReason::UserDefined4 |
               Dynarmic::HaltReason::UserDefined5 |
               Dynarmic::HaltReason::UserDefined6 |
               Dynarmic::HaltReason::UserDefined7 |
               Dynarmic::HaltReason::UserDefined8;
    }

    void ensure_jit()
    {
        callbacks_->bind_exclusive_monitor(monitor_, processor_id_);
        if (jit_) {
            return;
        }
        if (runtime_link_cell_address_->load(std::memory_order_acquire) !=
            static_cast<std::uint64_t>(
                reinterpret_cast<std::uintptr_t>(callbacks_.get()))) {
            throw std::logic_error { "JIT runtime callback link is not bound" };
        }
        Dynarmic::A32::UserConfig config { callbacks_.get() };
        config.native_code_slab = execution_context_->native_code_slab();
        config.callbacks_link = runtime_link_cell_address_;
        if (performance_counters().native_lookup_diagnostics_enabled()) {
            config.native_code_block_lookup_callback =
                &JitExecutor::native_code_block_lookup;
            config.native_code_block_lookup_callback_arg = this;
        }
        config.lookup_link = lookup_link_cell_address_;
        config.runtime_config_link = runtime_config_link_cell_address_;
        config.fast_dispatch_table_link =
            fast_dispatch_table_link_cell_address_;
        config.page_table_link = page_table_link_cell_address_;
        config.read_page_table_link = read_page_table_link_cell_address_;
        config.coprocessor_user_arg_link = runtime_link_cell_address_;
        config.exclusive_monitor_lock_link =
            exclusive_monitor_lock_link_cell_address_;
        config.exclusive_monitor_addresses_link =
            exclusive_monitor_addresses_link_cell_address_;
        config.exclusive_monitor_values_link =
            exclusive_monitor_values_link_cell_address_;
        config.processor_id = processor_id_;
        config.global_monitor = &monitor_;
        config.arch_version = dynarmic_architecture_version(
            callbacks_->cpu_model().architecture_version());
        config.always_little_endian = true;
        config.enable_cycle_counting = true;
        config.optimizations = jit_optimizations();
        config.check_halt_on_memory_access = true;
        config.code_cache_size = code_cache_size_;
        config.coprocessors[15] = cp15_;
        using DynarmicPageTable = std::array<std::uint8_t*,
            Dynarmic::A32::UserConfig::NUM_PAGE_TABLE_ENTRIES>;
        static_assert(AddressSpace::page_count ==
                      Dynarmic::A32::UserConfig::NUM_PAGE_TABLE_ENTRIES);
        auto** read_table = callbacks_->jit_read_page_table();
        auto** write_table = callbacks_->jit_write_page_table();
        if (read_table || write_table) {
            execution_context_->link(read_page_table_link_cell_,
                static_cast<std::uint64_t>(
                    reinterpret_cast<std::uintptr_t>(read_table)));
            execution_context_->link(page_table_link_cell_,
                static_cast<std::uint64_t>(
                    reinterpret_cast<std::uintptr_t>(write_table)));
            config.read_page_table =
                reinterpret_cast<DynarmicPageTable*>(read_table);
            config.page_table =
                reinterpret_cast<DynarmicPageTable*>(write_table);
            config.absolute_offset_page_table =
                sizeof(std::uintptr_t) >= sizeof(std::uint64_t);
            config.detect_misaligned_access_via_page_table =
                static_cast<std::uint8_t>(8U | 16U | 32U | 64U);
            config.only_detect_misalignment_via_page_table_on_page_boundary =
                true;
        }
        const auto measure = performance_counters().enabled();
        const auto started = measure
                                 ? std::chrono::steady_clock::now()
                                 : std::chrono::steady_clock::time_point { };
        jit_ = std::make_unique<Dynarmic::A32::Jit>(config);
        demand_artifact_enabled_ =
            callbacks_->demand_artifact_catalog_nonempty();
        recorded_dispatch_counters_ = { };
        recorded_shared_cache_state_ = false;
        recorded_shared_range_count_ = 0;
        recorded_shared_descriptor_count_ = 0;
        recorded_invalidated_descriptors_ = 0;
        recorded_retired_code_bytes_ = 0;
        recorded_segment_recycles_ = 0;
        recorded_recycled_descriptors_ = 0;
        recorded_recycled_code_bytes_ = 0;
        recorded_full_generation_clears_ = 0;
        const auto elapsed =
            measure ? static_cast<std::uint64_t>(
                          std::chrono::duration_cast<std::chrono::nanoseconds>(
                              std::chrono::steady_clock::now() - started)
                              .count())
                    : 0;
        performance_counters().record_jit(elapsed);
        performance_counters().record_latency(
            PerfLatencyKind::JitColdPath, elapsed);
        record_code_cache_usage();
    }

    void load_state(Cpu& cpu)
    {
        if (auto** read_table = callbacks_->jit_read_page_table()) {
            execution_context_->link(read_page_table_link_cell_,
                static_cast<std::uint64_t>(
                    reinterpret_cast<std::uintptr_t>(read_table)));
        }
        if (auto** write_table = callbacks_->jit_write_page_table()) {
            execution_context_->link(page_table_link_cell_,
                static_cast<std::uint64_t>(
                    reinterpret_cast<std::uintptr_t>(write_table)));
        }
        clear_halt();
        jit_->Regs() = cpu.state_.registers;
        jit_->ExtRegs() = cpu.state_.extension_registers;
        jit_->SetCpsr(cpu.state_.cpsr);
        jit_->SetFpscr(cpu.state_.fpscr);
        cpu.active_executor_ = this;
        callbacks_->attach(&cpu, jit_.get());
        if (static_cast<std::uint32_t>(cpu.requested_halt_reason_) != 0) {
            jit_->HaltExecution(cpu.requested_halt_reason_);
        }
    }

    void save_state(Cpu& cpu)
    {
        cpu.state_.registers = jit_->Regs();
        cpu.state_.extension_registers = jit_->ExtRegs();
        cpu.state_.cpsr = jit_->Cpsr();
        cpu.state_.fpscr = jit_->Fpscr();
        cpu.active_executor_ = nullptr;
    }

    void record_code_cache_usage()
    {
        if (!jit_ || !performance_counters().enabled()) {
            return;
        }
        const auto current = jit_code_cache_used(*jit_);
        const auto committed = logical_committed_code_bytes(current);
        if (!recorded_shared_memory_ ||
            recorded_shared_used_bytes_ != current ||
            recorded_shared_committed_bytes_ != committed) {
            performance_counters().record_jit_shared_slab_usage(
                execution_context_->context_id(), code_cache_size_, committed,
                current);
            recorded_shared_memory_ = true;
            recorded_shared_used_bytes_ = current;
            recorded_shared_committed_bytes_ = committed;
        }
        const auto cache_stats =
            execution_context_->native_code_slab()->GetCacheStats();
        if (!recorded_shared_cache_state_ ||
            recorded_shared_range_count_ != cache_stats.range_count ||
            recorded_shared_descriptor_count_ != cache_stats.descriptor_count ||
            recorded_invalidated_descriptors_ !=
                cache_stats.invalidated_descriptors ||
            recorded_retired_code_bytes_ != cache_stats.retired_code_bytes ||
            recorded_segment_recycles_ != cache_stats.segment_recycles ||
            recorded_recycled_descriptors_ !=
                cache_stats.recycled_descriptors ||
            recorded_recycled_code_bytes_ != cache_stats.recycled_code_bytes ||
            recorded_full_generation_clears_ !=
                cache_stats.full_generation_clears) {
            performance_counters().record_jit_shared_cache_state(
                execution_context_->context_id(),
                execution_context_->process_id(),
                static_cast<std::uint64_t>(cache_stats.range_count),
                static_cast<std::uint64_t>(cache_stats.descriptor_count),
                cache_stats.invalidated_descriptors,
                cache_stats.retired_code_bytes, cache_stats.segment_recycles,
                cache_stats.recycled_descriptors,
                cache_stats.recycled_code_bytes,
                cache_stats.full_generation_clears);
            recorded_shared_cache_state_ = true;
            recorded_shared_range_count_ = cache_stats.range_count;
            recorded_shared_descriptor_count_ = cache_stats.descriptor_count;
            recorded_invalidated_descriptors_ =
                cache_stats.invalidated_descriptors;
            recorded_retired_code_bytes_ = cache_stats.retired_code_bytes;
            recorded_segment_recycles_ = cache_stats.segment_recycles;
            recorded_recycled_descriptors_ = cache_stats.recycled_descriptors;
            recorded_recycled_code_bytes_ = cache_stats.recycled_code_bytes;
            recorded_full_generation_clears_ =
                cache_stats.full_generation_clears;
        }
        const auto executor_local = executor_local_memory_bytes();
        if (executor_local != recorded_executor_local_bytes_) {
            performance_counters().record_jit_executor_memory_usage(
                execution_context_->context_id(), process_id_,
                static_cast<std::uint32_t>(execution_slot_), executor_local);
            recorded_executor_local_bytes_ = executor_local;
        }
    }

    StackAttribution attribute_run_stack(std::uint32_t pc)
    {
        const auto info = performance_counters().block_profile().image_info_address(
            static_cast<std::uint32_t>(process_id_));
        const auto count = info == 0U
            ? std::nullopt
            : memory_.read32(info + 4U, MemoryPermission::Read);
        if (count && *count != own_image_count_) {
            const auto images = read_guest_image_table(memory_, info);
            performance_counters().block_profile().record_images(
                static_cast<std::uint32_t>(process_id_), images);
            own_image_ranges_ = own_text_ranges(images);
            own_image_count_ = *count;
        }
        return attribute_stack(pc, jit_->Regs()[14], jit_->Regs()[7],
            own_image_ranges_, guest_word_reader());
    }

    std::vector<std::uint32_t> capture_run_chain(std::uint32_t pc)
    {
        return capture_stack_chain(pc, jit_->Regs()[14], jit_->Regs()[7],
            guest_word_reader());
    }

    GuestReader guest_word_reader()
    {
        return [this](std::uint32_t address) {
            return memory_.read32(address, MemoryPermission::Read);
        };
    }

    void record_dispatch_counters()
    {
        if (!jit_)
            return;
        const auto current = jit_->GetDispatchCounters();
        if (!performance_counters().enabled()) {
            recorded_dispatch_counters_ = current;
            return;
        }
        const auto delta = [](std::uint64_t current, std::uint64_t& recorded) {
            const auto result =
                current >= recorded ? current - recorded : current;
            recorded = current;
            return result;
        };
        performance_counters().record_jit_dispatch(
            delta(current.fast_link_hits,
                recorded_dispatch_counters_.fast_link_hits),
            delta(current.fast_link_misses,
                recorded_dispatch_counters_.fast_link_misses),
            delta(current.stable_table_probes,
                recorded_dispatch_counters_.stable_table_probes),
            delta(current.stable_table_collisions,
                recorded_dispatch_counters_.stable_table_collisions),
            delta(current.rsb_hits, recorded_dispatch_counters_.rsb_hits),
            delta(current.rsb_misses, recorded_dispatch_counters_.rsb_misses));
    }

    [[nodiscard]] std::uint64_t executor_local_memory_bytes() const noexcept
    {
        constexpr auto link_cell_bytes =
            jit_link_cell_count * sizeof(std::atomic<std::uint64_t>);
        if (!jit_)
            return link_cell_bytes;
        constexpr auto fast_dispatch_table_bytes =
            fast_dispatch_table_size * fast_dispatch_entry_bytes;
        return link_cell_bytes + sizeof(Dynarmic::Backend::X64::A32JitState) +
               fast_dispatch_table_bytes;
    }

public:
    void prepare()
    {
        const std::lock_guard lock { execution_mutex_ };
        memory_.synchronize_shared_write_tracking();
        ensure_jit();
    }

    void set_process_id(std::uint32_t process_id)
    {
        process_id_ = process_id;
        callbacks_->set_process_id(process_id);
    }

    void set_code_cache_size(std::size_t bytes)
    {
        std::lock_guard lock { execution_mutex_ };
        if (jit_) {
            throw std::logic_error {
                "cannot resize a live Dynarmic code cache"
            };
        }
        code_cache_size_ = bytes;
    }

private:
    std::size_t processor_id_ { };
    std::size_t execution_slot_ { };
    std::uint32_t process_id_ { };
    AddressSpace& memory_;
    Dynarmic::ExclusiveMonitor& monitor_;
    std::unique_ptr<JitCallbacks> callbacks_;
    std::shared_ptr<ArmSystemControlCoprocessor> cp15_;
    std::shared_ptr<ExecutionContext> execution_context_;
    std::size_t runtime_link_cell_ { };
    const std::atomic<std::uint64_t>* runtime_link_cell_address_ { };
    std::size_t lookup_link_cell_ { };
    std::atomic<std::uint64_t>* lookup_link_cell_address_ { };
    std::size_t runtime_config_link_cell_ { };
    std::atomic<std::uint64_t>* runtime_config_link_cell_address_ { };
    std::size_t fast_dispatch_table_link_cell_ { };
    std::atomic<std::uint64_t>* fast_dispatch_table_link_cell_address_ { };
    std::size_t page_table_link_cell_ { };
    std::atomic<std::uint64_t>* page_table_link_cell_address_ { };
    std::size_t read_page_table_link_cell_ { };
    std::atomic<std::uint64_t>* read_page_table_link_cell_address_ { };
    std::size_t exclusive_monitor_lock_link_cell_ { };
    const std::atomic<std::uint64_t>*
        exclusive_monitor_lock_link_cell_address_ { };
    std::size_t exclusive_monitor_addresses_link_cell_ { };
    const std::atomic<std::uint64_t>*
        exclusive_monitor_addresses_link_cell_address_ { };
    std::size_t exclusive_monitor_values_link_cell_ { };
    const std::atomic<std::uint64_t>*
        exclusive_monitor_values_link_cell_address_ { };
    std::unique_ptr<Dynarmic::A32::Jit> jit_;
    JitHostExecutionBudget host_execution_budget_;
    AddressRanges own_image_ranges_;
    std::uint32_t own_image_count_ { 0xffffffffU };
    std::size_t code_cache_size_ { 64U * 1024U * 1024U };
    bool recorded_shared_memory_ { };
    std::uint64_t recorded_shared_used_bytes_ { };
    std::uint64_t recorded_shared_committed_bytes_ { };
    bool recorded_shared_cache_state_ { };
    std::uint64_t recorded_shared_range_count_ { };
    std::uint64_t recorded_shared_descriptor_count_ { };
    std::uint64_t recorded_invalidated_descriptors_ { };
    std::uint64_t recorded_retired_code_bytes_ { };
    std::uint64_t recorded_segment_recycles_ { };
    std::uint64_t recorded_recycled_descriptors_ { };
    std::uint64_t recorded_recycled_code_bytes_ { };
    std::uint64_t recorded_full_generation_clears_ { };
    std::uint64_t recorded_executor_local_bytes_ { };
    Dynarmic::A32::DispatchCounters recorded_dispatch_counters_ { };
    std::uint64_t observed_invalidation_epoch_ { };
    std::uint64_t observed_slab_generation_ { };
    std::unordered_map<std::uint64_t, ArtifactProbe> artifact_probes_;
    std::unordered_map<std::uint64_t, DemandArtifactProbe>
        demand_artifact_probes_;
    std::deque<std::uint64_t> demand_artifact_probe_order_;
    std::uint64_t demand_artifact_attempt_generation_ { };
    std::shared_ptr<JitNativePreimportTracker> native_preimport_tracker_;
    std::optional<std::uint64_t> native_prediction_baseline_bytes_;
    std::uint64_t native_lookup_sequence_ { };
    bool demand_artifact_enabled_ { };
    bool portable_demand_provider_installed_ { };
    bool guest_preemption_requested_ { };
    std::optional<std::chrono::steady_clock::time_point>
        guest_preemption_requested_at_;
    std::mutex execution_mutex_;
};

class CpuExecutionPool {
    struct PrecompileEntry {
        std::uint64_t descriptor { };
        JitPrecompileTarget target { JitPrecompileTarget::NativeCode };
        JitPrecompileSource source { JitPrecompileSource::Other };

        friend constexpr bool operator==(
            const PrecompileEntry&, const PrecompileEntry&) = default;
    };

    struct PrecompileEntryHash {
        [[nodiscard]] std::size_t operator()(
            const PrecompileEntry& entry) const noexcept
        {
            const auto descriptor_hash =
                std::hash<std::uint64_t> { }(entry.descriptor);
            const auto target_hash = std::hash<std::uint8_t> { }(
                static_cast<std::uint8_t>(entry.target));
            const auto source_hash = std::hash<std::uint8_t> { }(
                static_cast<std::uint8_t>(entry.source));
            return descriptor_hash ^
                   (target_hash + static_cast<std::size_t>(0x9e3779b9U) +
                       (descriptor_hash << 6U) + (descriptor_hash >> 2U)) ^
                   (source_hash + static_cast<std::size_t>(0x85ebca6bU) +
                       (target_hash << 5U) + (target_hash >> 3U));
        }
    };

    struct DeferredPrecompileEntry {
        JitPrecompilePhase phase { JitPrecompilePhase::Opportunistic };
        std::optional<std::uint64_t> cache_full_invalidation_epoch;
    };

    struct CompletedPrecompileEntry {
        std::uint64_t cache_invalidation_epoch { };
        std::uint64_t cache_clear_epoch { };
        std::uint64_t slab_generation { };
        std::uint64_t profile_generation { };
    };

public:
    CpuExecutionPool(AddressSpace& memory, Dynarmic::ExclusiveMonitor& monitor,
        std::size_t execution_slot_count, std::size_t first_processor_id,
        const ArmCpuModel& cpu_model,
        std::shared_ptr<JitArtifactStore> artifact_store,
        std::size_t precompile_lane_count = 1U)
        : memory_ { memory }
        , execution_context_ { std::make_shared<ExecutionContext>() }
        , native_preimport_tracker_ { }
        , monitor_ { monitor }
        , cpu_model_ { cpu_model }
        , artifact_store_ { artifact_store_for_run(std::move(artifact_store)) }
    {
        if (execution_slot_count == 0) {
            throw std::invalid_argument {
                "execution_slot_count must be at least one"
            };
        }
        if (first_processor_id > monitor.GetProcessorCount() ||
            execution_slot_count >
                monitor.GetProcessorCount() - first_processor_id) {
            throw std::invalid_argument {
                "exclusive monitor processor range is out of bounds"
            };
        }
        executors_.reserve(execution_slot_count);
        for (std::size_t slot = 0; slot < execution_slot_count; ++slot) {
            executors_.push_back(std::make_unique<JitExecutor>(
                first_processor_id + slot, slot, memory, monitor, cpu_model,
                artifact_store_, execution_context_, nullptr));
        }
        if (precompile_lane_count == 0U) {
            throw std::invalid_argument {
                "precompile_lane_count must be at least one"
            };
        }
        precompile_executors_.reserve(precompile_lane_count);
        precompile_executor_busy_.resize(precompile_lane_count, false);
        for (std::size_t lane = 0; lane < precompile_lane_count; ++lane) {
            precompile_executors_.push_back(
                std::make_unique<JitExecutor>(first_processor_id,
                    execution_slot_count + lane, memory_, monitor_, cpu_model_,
                    artifact_store_, execution_context_, nullptr));
        }
    }

    void prepare_primary_execution_resource()
    {
        if (!executors_.empty())
            executors_.front()->prepare();
    }

    [[nodiscard]] std::size_t precompile_lane_count() const noexcept
    {
        return precompile_executors_.size();
    }

    void set_jit_work_signal(std::shared_ptr<JitWorkObservationSignal> signal)
    {
        for (const auto& executor : executors_)
            executor->set_jit_work_signal(signal);
        for (const auto& executor : precompile_executors_)
            executor->set_jit_work_signal(signal);
    }

    ~CpuExecutionPool()
    {
        quiesce_precompilation();
        precompile_executors_.clear();
        executors_.clear();
        performance_counters().release_jit_memory_context(
            execution_context_->context_id());
    }

    [[nodiscard]] std::size_t size() const { return executors_.size(); }

    [[nodiscard]] JitExecutor& executor(std::size_t slot)
    {
        return *executors_.at(slot);
    }

    void clear_exclusive_state(std::size_t slot)
    {
        executor(slot).clear_exclusive_state();
        if (executors_.size() == 1U)
            memory_.clear_exclusive_access_tracking();
    }

    void set_process_id(std::uint32_t process_id)
    {
        execution_context_->bind_process_id(process_id);
        for (auto& executor : executors_)
            executor->set_process_id(process_id);
        for (auto& executor : precompile_executors_)
            executor->set_process_id(process_id);
    }

    void set_code_cache_size(std::size_t bytes)
    {
        code_cache_size_ = bytes;
        for (auto& executor : executors_)
            executor->set_code_cache_size(bytes);
        for (auto& executor : precompile_executors_)
            executor->set_code_cache_size(bytes);
    }

    [[nodiscard]] std::uint64_t code_cache_used()
    {
        for (auto& executor : executors_) {
            const auto used = executor->code_cache_used();
            if (used != 0U)
                return used;
        }
        for (auto& executor : precompile_executors_) {
            const auto used = executor->code_cache_used();
            if (used != 0U)
                return used;
        }
        return 0U;
    }

    void clear_cache()
    {
        if (code_cache_used() == 0U)
            return;
        static_cast<void>(execution_context_->request_cache_clear());
        execution_context_->native_code_slab()->service_pending_invalidation();
        const auto slab_generation =
            execution_context_->native_code_slab()->generation();
        if (execution_context_->observe_slab_generation(slab_generation)) {
            performance_counters().record_jit_slab_generation_transition(
                execution_context_->process_id());
        }
        if (native_preimport_tracker_)
            native_preimport_tracker_->clear();
        performance_counters().record_jit_shared_invalidation(true);
    }

    void invalidate_cache_range(std::uint32_t address, std::size_t length)
    {
        if (length == 0U)
            return;
        static_cast<void>(
            execution_context_->request_cache_range(address, length));
        if (native_preimport_tracker_) {
            native_preimport_tracker_->invalidate_range(address, length);
        }
        performance_counters().record_jit_shared_invalidation(false);
    }

    void invalidate_cache_ranges(
        std::span<const Cpu::CacheInvalidationRange> ranges)
    {
        if (ranges.empty())
            return;
        std::vector<Cpu::CacheInvalidationRange> merged;
        merged.reserve(ranges.size());
        for (const auto& range : ranges) {
            if (range.length == 0U)
                continue;
            const auto begin = static_cast<std::uint64_t>(range.address);
            const auto end = begin + range.length;
            if (end > (std::uint64_t { 1 } << 32U))
                continue;
            merged.push_back(range);
        }
        if (merged.empty())
            return;
        std::sort(merged.begin(), merged.end(),
            [](const auto& left, const auto& right) {
                return left.address < right.address;
            });
        std::vector<Cpu::CacheInvalidationRange> coalesced;
        coalesced.reserve(merged.size());
        for (const auto& range : merged) {
            if (coalesced.empty()) {
                coalesced.push_back(range);
                continue;
            }
            auto& last = coalesced.back();
            const auto last_end =
                static_cast<std::uint64_t>(last.address) + last.length;
            const auto range_end =
                static_cast<std::uint64_t>(range.address) + range.length;
            if (static_cast<std::uint64_t>(range.address) <= last_end) {
                const auto merged_end = std::max(last_end, range_end);
                last.length =
                    static_cast<std::size_t>(merged_end - last.address);
            } else {
                coalesced.push_back(range);
            }
        }
        for (const auto& range : coalesced)
            invalidate_cache_range(range.address, range.length);
    }

    void disable_jit_page_table() { memory_.disable_jit_page_table(); }

    void set_translation_profile(std::shared_ptr<JitTranslationProfile> profile,
        JitPrecompilePhase phase, bool record, bool precompile)
    {
        quiesce_precompilation();
        JitTranslationProfilePrediction native_prediction;
        if (precompile && profile) {
            const auto limits =
                JitWorkPolicy::native_prediction_policy(code_cache_size_);
            native_prediction = profile->snapshot_prediction(
                JitTranslationProfilePredictionLimits {
                    limits.activation_locations, limits.recent_locations,
                    limits.historical_locations });
        }
        native_preimport_tracker_ =
            precompile ? std::make_shared<JitNativePreimportTracker>()
                       : nullptr;
        for (auto& executor : executors_) {
            executor->set_translation_profile(
                profile, record, native_preimport_tracker_);
        }
        for (auto& executor : precompile_executors_) {
            executor->set_translation_profile(
                profile, false, native_preimport_tracker_);
        }
        const std::lock_guard queue_lock { precompile_queue_mutex_ };
        for (auto& queue : pending_precompile_entries_)
            queue.clear();
        pending_precompile_phases_.clear();
        inflight_precompile_entries_.clear();
        completed_precompile_entries_.clear();
        completed_precompile_lru_.clear();
        deferred_precompile_entries_.clear();
        cache_full_epoch_observed_.fill(std::nullopt);
        pending_precompile_entries_by_source_.fill(0U);
        inflight_precompile_entries_by_source_.fill(0U);
        deferred_precompile_entries_by_source_.fill(0U);
        completed_precompile_entries_by_source_.fill(0U);
        translation_profile_ = profile;
        native_profile_locations_ =
            std::move(native_prediction.ordered_locations);
        native_profile_recency_locations_ =
            std::move(native_prediction.recent_locations);
        translation_profile_phase_ = phase;
        profile_recording_enabled_ = record;
        profile_location_cursors_.fill(0U);
        observed_profile_revisions_.fill(0U);
        profile_queue_entries_ = 0U;
        profile_queue_entries_by_target_.fill(0U);
        if (++profile_generation_ == 0U)
            profile_generation_ = 1U;
        profile_precompile_enabled_ = precompile;
        native_profile_scan_generation_ = current_completed_generation_locked();
        native_profile_recency_cursor_ = 0U;
        native_profile_recency_epoch_ =
            execution_context_->cache_invalidation_epoch();
        native_profile_recency_active_ = false;
        if (precompile) {
            for (std::size_t target = 0; target < jit_precompile_target_count;
                ++target) {
                refill_profile_entries_locked(
                    static_cast<JitPrecompileTarget>(target));
            }
        }
        update_memory_peaks_locked();
    }

    void refresh_translation_profile()
    {
        for (auto& executor : executors_)
            executor->flush_translation_profile();
        const std::lock_guard queue_lock { precompile_queue_mutex_ };
        if (precompile_quiescing_ || !translation_profile_ ||
            !profile_precompile_enabled_)
            return;
        promote_retryable_deferred_entries_locked(
            JitPrecompileSource::DemandProfile);
        const auto native_target =
            static_cast<std::size_t>(JitPrecompileTarget::NativeCode);
        const auto invalidation_epoch =
            execution_context_->cache_invalidation_epoch();
        if (profile_location_cursors_[native_target] >=
                native_profile_locations_.size() &&
            !native_profile_recency_locations_.empty() &&
            invalidation_epoch != native_profile_recency_epoch_) {
            native_profile_recency_cursor_ = 0U;
            native_profile_recency_epoch_ = invalidation_epoch;
            native_profile_recency_active_ = true;
        }
        for (std::size_t target = 0; target < jit_precompile_target_count;
            ++target) {
            refill_profile_entries_locked(
                static_cast<JitPrecompileTarget>(target));
        }
        update_memory_peaks_locked();
        assert_queue_counter_invariants_locked();
    }

    void retry_deferred_translation_profile()
    {
        const std::lock_guard queue_lock { precompile_queue_mutex_ };
        if (precompile_quiescing_ || !translation_profile_ ||
            !profile_precompile_enabled_) {
            return;
        }
        promote_retryable_deferred_entries_locked(
            JitPrecompileSource::DemandProfile);
        for (std::size_t target = 0; target < jit_precompile_target_count;
            ++target) {
            refill_profile_entries_locked(
                static_cast<JitPrecompileTarget>(target));
        }
        update_memory_peaks_locked();
        assert_queue_counter_invariants_locked();
    }

    [[nodiscard]] JitPrecompileMemoryStats precompile_memory_stats() const
    {
        return memory_snapshot_.read();
    }

    void set_artifact_retention(JitArtifactRetention retention)
    {
        for (auto& executor : executors_) {
            executor->set_artifact_retention(retention);
        }
        for (auto& executor : precompile_executors_)
            executor->set_artifact_retention(retention);
    }

    void add_precompile_entries(
        const std::vector<std::uint64_t>& location_descriptors,
        JitPrecompilePhase phase, JitPrecompileSource source)
    {
        const std::lock_guard queue_lock { precompile_queue_mutex_ };
        if (precompile_quiescing_)
            return;
        for (const auto entry : location_descriptors) {
            if (enqueue_precompile_entry_locked(
                    PrecompileEntry {
                        entry, JitPrecompileTarget::NativeCode, source },
                    phase) == PrecompileEnqueueResult::Rejected ||
                enqueue_precompile_entry_locked(
                    PrecompileEntry {
                        entry, JitPrecompileTarget::PortableIr, source },
                    phase) == PrecompileEnqueueResult::Rejected) {
                break;
            }
        }
        update_memory_peaks_locked();
    }

    [[nodiscard]] std::optional<JitPrecompilePhase> next_precompile_phase(
        JitPrecompileTarget target,
        std::optional<JitPrecompileSource> source = std::nullopt)
    {
        const std::lock_guard queue_lock { precompile_queue_mutex_ };
        if (precompile_quiescing_)
            return std::nullopt;
        return next_precompile_phase_locked(target, source);
    }

    JitPrecompileBatchResult precompile_pending(std::size_t maximum_blocks,
        std::uint64_t budget_nanoseconds, JitPrecompileTarget target,
        const CpuCluster::PrecompileStopCondition& stop_condition,
        std::optional<JitPrecompileSource> source)
    {
        JitPrecompileBatchResult result;
        if (precompile_executors_.empty() || maximum_blocks == 0 ||
            budget_nanoseconds == 0) {
            return result;
        }
        std::uint64_t cancellation_generation { };
        std::size_t precompile_lane { };
        JitExecutor* precompile_executor { };
        {
            const std::lock_guard queue_lock { precompile_queue_mutex_ };
            if (precompile_quiescing_)
                return result;
            const auto available = std::find(precompile_executor_busy_.begin(),
                precompile_executor_busy_.end(), false);
            if (available == precompile_executor_busy_.end())
                return result;
            precompile_lane = static_cast<std::size_t>(
                std::distance(precompile_executor_busy_.begin(), available));
            precompile_executor_busy_[precompile_lane] = true;
            precompile_executor = precompile_executors_[precompile_lane].get();
            cancellation_generation = precompile_cancellation_generation_;
            ++active_precompile_tasks_;
        }
        std::unordered_set<PrecompileEntry, PrecompileEntryHash>
            owned_inflight_entries;
        const auto stop_requested = [&]() {
            if (stop_condition && stop_condition())
                return true;
            const std::lock_guard queue_lock { precompile_queue_mutex_ };
            return precompile_cancellation_generation_ !=
                   cancellation_generation;
        };
        const auto cleanup = [&]() {
            const std::lock_guard queue_lock { precompile_queue_mutex_ };
            for (const auto& entry : owned_inflight_entries) {
                remove_inflight_entry_locked(entry);
                decrement_profile_queue_entries_locked(entry);
            }
            owned_inflight_entries.clear();
            update_memory_peaks_locked();
            assert_queue_counter_invariants_locked();
        };
        const auto finish = [&]() {
            const std::lock_guard queue_lock { precompile_queue_mutex_ };
            if (active_precompile_tasks_ == 0U)
                throw std::logic_error {
                    "precompile task accounting underflow"
                };
            precompile_executor_busy_[precompile_lane] = false;
            --active_precompile_tasks_;
            if (active_precompile_tasks_ == 0U)
                precompile_idle_.notify_all();
        };
        try {
            const auto started = std::chrono::steady_clock::now();
            const auto bounded_budget = std::min<std::uint64_t>(
                budget_nanoseconds,
                static_cast<std::uint64_t>(
                    std::numeric_limits<std::chrono::nanoseconds::rep>::max()));
            const auto deadline = started + std::chrono::nanoseconds {
                static_cast<std::chrono::nanoseconds::rep>(bounded_budget)
            };
            std::size_t processed = 0;
            while (processed < maximum_blocks) {
                if (stop_requested())
                    break;
                if (std::chrono::steady_clock::now() >= deadline) {
                    ++result.deadline_stops;
                    break;
                }
                std::optional<std::pair<PrecompileEntry, JitPrecompilePhase>>
                    entry;
                bool profile_derived { };
                std::shared_ptr<JitTranslationProfile> profile_for_stats;
                {
                    const std::lock_guard queue_lock {
                        precompile_queue_mutex_
                    };
                    entry = take_precompile_entry_locked(target, source);
                    if (!entry)
                        break;
                    profile_derived = entry->first.source ==
                                      JitPrecompileSource::DemandProfile;
                    profile_for_stats = translation_profile_;
                }
                owned_inflight_entries.insert(entry->first);
                ++processed;
                ++result.attempted;
                if (profile_derived && profile_for_stats) {
                    if (target == JitPrecompileTarget::NativeCode) {
                        profile_for_stats->note_profile_native_attempted();
                    } else {
                        profile_for_stats->note_profile_portable_attempted();
                    }
                }
                const auto precompile_entry = entry->first;
                const auto descriptor = precompile_entry.descriptor;
                JitExecutor::PrecompileDisposition disposition;
                try {
                    disposition = precompile_executor->precompile_descriptor(
                        descriptor, target, profile_derived);
                } catch (...) {
                    const auto cancelled = stop_requested();
                    const std::lock_guard queue_lock {
                        precompile_queue_mutex_
                    };
                    remove_inflight_entry_locked(precompile_entry);
                    owned_inflight_entries.erase(precompile_entry);
                    if (!cancelled) {
                        defer_inflight_entry_locked(precompile_entry,
                            DeferredPrecompileEntry {
                                entry->second, std::nullopt });
                    } else {
                        decrement_profile_queue_entries_locked(
                            precompile_entry);
                    }
                    update_memory_peaks_locked();
                    assert_queue_counter_invariants_locked();
                    if (cancelled) {
                        ++result.cancelled;
                    } else {
                        ++result.failed;
                    }
                    break;
                }
                const auto cancelled = stop_requested();
                {
                    const std::lock_guard queue_lock {
                        precompile_queue_mutex_
                    };
                    remove_inflight_entry_locked(precompile_entry);
                    owned_inflight_entries.erase(precompile_entry);
                    if (cancelled) {
                        decrement_profile_queue_entries_locked(
                            precompile_entry);
                    } else if (disposition ==
                               JitExecutor::PrecompileDisposition::Deferred) {
                        defer_inflight_entry_locked(precompile_entry,
                            DeferredPrecompileEntry {
                                entry->second, std::nullopt });
                    } else if (disposition ==
                               JitExecutor::PrecompileDisposition::CacheFull) {
                        defer_inflight_entry_locked(precompile_entry,
                            DeferredPrecompileEntry { entry->second,
                                execution_context_
                                    ->cache_invalidation_epoch() });
                    } else {
                        finish_inflight_entry_locked(precompile_entry,
                            precompile_disposition_completed(disposition));
                    }
                    if (!cancelled)
                        refill_profile_entries_locked(target);
                    update_memory_peaks_locked();
                    assert_queue_counter_invariants_locked();
                }
                if (cancelled) {
                    ++result.cancelled;
                    break;
                }
                if (profile_derived && profile_for_stats) {
                    const bool completed =
                        target == JitPrecompileTarget::NativeCode
                            ? disposition ==
                                      JitExecutor::PrecompileDisposition::
                                          NativeCompiled ||
                                  disposition ==
                                      JitExecutor::PrecompileDisposition::
                                          ArtifactImported ||
                                  disposition ==
                                      JitExecutor::PrecompileDisposition::
                                          ArtifactProbeHit ||
                                  disposition ==
                                      JitExecutor::PrecompileDisposition::
                                          SharedSlabHit
                            : disposition ==
                                      JitExecutor::PrecompileDisposition::
                                          PortableGenerated ||
                                  disposition ==
                                      JitExecutor::PrecompileDisposition::
                                          PortableArtifactHit;
                    if (completed) {
                        if (target == JitPrecompileTarget::NativeCode) {
                            profile_for_stats->note_profile_native_executed();
                        } else {
                            profile_for_stats->note_profile_portable_executed();
                            profile_for_stats
                                ->note_profile_portable_artifact_ready(
                                    descriptor);
                        }
                    }
                }
                switch (disposition) {
                case JitExecutor::PrecompileDisposition::NativeCompiled:
                    ++result.native_compiled;
                    break;
                case JitExecutor::PrecompileDisposition::PortableGenerated:
                    ++result.portable_generated;
                    break;
                case JitExecutor::PrecompileDisposition::PortableArtifactHit:
                    ++result.portable_artifact_hits;
                    break;
                case JitExecutor::PrecompileDisposition::ArtifactImported:
                    ++result.artifact_imported;
                    break;
                case JitExecutor::PrecompileDisposition::ArtifactProbeHit:
                    ++result.artifact_probe_hits;
                    break;
                case JitExecutor::PrecompileDisposition::SharedSlabHit:
                    ++result.shared_slab_hits;
                    break;
                case JitExecutor::PrecompileDisposition::Deferred:
                    ++result.deferred;
                    break;
                case JitExecutor::PrecompileDisposition::Unstable:
                    ++result.unstable;
                    break;
                case JitExecutor::PrecompileDisposition::CacheFull:
                    ++result.cache_full;
                    break;
                case JitExecutor::PrecompileDisposition::Failed:
                    ++result.failed;
                    break;
                }
                if (disposition ==
                    JitExecutor::PrecompileDisposition::CacheFull) {
                    break;
                }
            }
            cleanup();
            finish();
            result.elapsed_nanoseconds =
                static_cast<std::uint64_t>(std::max<std::int64_t>(
                    0, std::chrono::duration_cast<std::chrono::nanoseconds>(
                           std::chrono::steady_clock::now() - started)
                           .count()));
            return result;
        } catch (...) {
            cleanup();
            finish();
            throw;
        }
    }

    void quiesce_precompilation()
    {
        {
            const std::lock_guard queue_lock { precompile_queue_mutex_ };
            precompile_quiescing_ = true;
            profile_precompile_enabled_ = false;
            update_memory_peaks_locked();
            if (++precompile_cancellation_generation_ == 0U)
                precompile_cancellation_generation_ = 1U;
            const auto profile_source =
                static_cast<std::size_t>(JitPrecompileSource::DemandProfile);
            const auto non_inflight_profile_entries =
                pending_precompile_entries_by_source_[profile_source] +
                deferred_precompile_entries_by_source_[profile_source];
            profile_queue_entries_ =
                non_inflight_profile_entries > profile_queue_entries_
                    ? 0U
                    : profile_queue_entries_ - non_inflight_profile_entries;
            for (auto& queue : pending_precompile_entries_)
                queue.clear();
            pending_precompile_phases_.clear();
            pending_precompile_entries_by_source_.fill(0U);
            deferred_precompile_entries_.clear();
            deferred_precompile_entries_by_source_.fill(0U);
            completed_precompile_entries_.clear();
            completed_precompile_lru_.clear();
            completed_precompile_entries_by_source_.fill(0U);
            cache_full_epoch_observed_.fill(std::nullopt);
            profile_location_cursors_.fill(0U);
            native_profile_scan_generation_ =
                current_completed_generation_locked();
            profile_queue_entries_by_target_.fill(0U);
            for (const auto& entry : inflight_precompile_entries_) {
                if (entry.source == JitPrecompileSource::DemandProfile) {
                    ++profile_queue_entries_by_target_[static_cast<std::size_t>(
                        entry.target)];
                }
            }
            assert_queue_counter_invariants_locked();
        }
        std::unique_lock queue_lock { precompile_queue_mutex_ };
        precompile_idle_.wait(
            queue_lock, [this] { return active_precompile_tasks_ == 0U; });
        inflight_precompile_entries_.clear();
        inflight_precompile_entries_by_source_.fill(0U);
        profile_queue_entries_ = 0U;
        profile_queue_entries_by_target_.fill(0U);
        profile_location_cursors_.fill(0U);
        native_profile_scan_generation_ = current_completed_generation_locked();
        assert_queue_counter_invariants_locked();
        update_memory_peaks_locked();
        precompile_quiescing_ = false;
    }

private:
    template <typename Container>
    [[nodiscard]] static std::size_t estimate_unordered_buckets(
        const Container& container) noexcept
    {
        return container.empty() ? 0U
                                 : container.bucket_count() * sizeof(void*);
    }

    template <typename Container>
    [[nodiscard]] static std::size_t estimate_unordered_nodes(
        const Container& container) noexcept
    {
        return container.size() *
               (sizeof(typename Container::value_type) + 2U * sizeof(void*));
    }

    template <typename T>
    [[nodiscard]] static std::size_t estimate_deque_blocks_for_count(
        std::size_t count) noexcept
    {
        if (count == 0U)
            return 0U;
        constexpr auto elements_per_block =
            std::size_t { 4096U } / (sizeof(T) == 0U ? 1U : sizeof(T));
        constexpr auto block_elements =
            elements_per_block == 0U ? std::size_t { 1U } : elements_per_block;
        const auto blocks = (count + block_elements - 1U) / block_elements;
        return blocks * block_elements * sizeof(T) +
               (blocks + 2U) * sizeof(void*);
    }

    template <typename Container>
    [[nodiscard]] static std::size_t estimate_unordered_buckets_for_count(
        const Container& container, std::size_t count) noexcept
    {
        if (count == 0U || container.size() == 0U)
            return 0U;
        const auto bytes = estimate_unordered_buckets(container);
        return (bytes * count + container.size() - 1U) / container.size();
    }

    template <typename Container>
    [[nodiscard]] static std::size_t estimate_unordered_nodes_for_count(
        std::size_t count) noexcept
    {
        return count *
               (sizeof(typename Container::value_type) + 2U * sizeof(void*));
    }

    void fill_memory_stats_locked(
        JitPrecompileMemoryStats& result) const noexcept
    {
        result.profile_recorder_bytes =
            profile_recording_enabled_
                ? executors_.size() * sizeof(JitTranslationProfileRecorder)
                : 0U;
        result.native_profile_prediction_bytes =
            (native_profile_locations_.capacity() +
                native_profile_recency_locations_.capacity()) *
            sizeof(std::uint64_t);
        result.native_preimport_tracker_bytes =
            native_preimport_tracker_
                ? jit_native_preimport_tracker_object_bytes
                : 0U;
        result.profile_queue_capacity_entries =
            profile_precompile_enabled_
                ? jit_profile_precompile_queue_entry_capacity
                : 0U;
        const auto sum = [](const auto& counts) {
            std::size_t total { };
            for (const auto count : counts)
                total += count;
            return total;
        };
        const auto& pending_by_source = pending_precompile_entries_by_source_;
        const auto& inflight_by_source = inflight_precompile_entries_by_source_;
        const auto& deferred_by_source = deferred_precompile_entries_by_source_;
        const auto& completed_by_source =
            completed_precompile_entries_by_source_;
        result.pending_entries = sum(pending_by_source);
        result.inflight_entries = sum(inflight_by_source);
        result.deferred_entries = sum(deferred_by_source);
        result.completed_entries = sum(completed_by_source);
        result.queue_block_bytes =
            estimate_deque_blocks_for_count<PrecompileEntry>(
                result.pending_entries);
        result.queue_bucket_bytes =
            estimate_unordered_buckets(pending_precompile_phases_) +
            estimate_unordered_buckets(inflight_precompile_entries_) +
            estimate_unordered_buckets(deferred_precompile_entries_) +
            estimate_unordered_buckets(completed_precompile_entries_);
        result.queue_node_bytes =
            estimate_unordered_nodes(pending_precompile_phases_) +
            estimate_unordered_nodes(inflight_precompile_entries_) +
            estimate_unordered_nodes(deferred_precompile_entries_) +
            estimate_unordered_nodes(completed_precompile_entries_);
        result.estimated_queue_entry_bytes = result.queue_bucket_bytes +
                                             result.queue_node_bytes +
                                             result.queue_block_bytes;
        for (std::size_t source_index = 0;
            source_index < jit_precompile_source_count; ++source_index) {
            auto& source = result.by_source[source_index];
            source.pending_entries = pending_by_source[source_index];
            source.inflight_entries = inflight_by_source[source_index];
            source.deferred_entries = deferred_by_source[source_index];
            source.completed_entries = completed_by_source[source_index];
            source.queued_entries = source.pending_entries +
                                    source.inflight_entries +
                                    source.deferred_entries;
            source.queue_block_bytes =
                estimate_deque_blocks_for_count<PrecompileEntry>(
                    pending_by_source[source_index]);
            source.queue_bucket_bytes =
                estimate_unordered_buckets_for_count(pending_precompile_phases_,
                    pending_by_source[source_index]) +
                estimate_unordered_buckets_for_count(
                    inflight_precompile_entries_,
                    inflight_by_source[source_index]) +
                estimate_unordered_buckets_for_count(
                    deferred_precompile_entries_,
                    deferred_by_source[source_index]) +
                estimate_unordered_buckets_for_count(
                    completed_precompile_entries_,
                    completed_by_source[source_index]);
            source.queue_node_bytes =
                estimate_unordered_nodes_for_count<
                    decltype(pending_precompile_phases_)>(
                    pending_by_source[source_index]) +
                estimate_unordered_nodes_for_count<
                    decltype(inflight_precompile_entries_)>(
                    inflight_by_source[source_index]) +
                estimate_unordered_nodes_for_count<
                    decltype(deferred_precompile_entries_)>(
                    deferred_by_source[source_index]) +
                estimate_unordered_nodes_for_count<
                    decltype(completed_precompile_entries_)>(
                    completed_by_source[source_index]);
            source.estimated_queue_entry_bytes = source.queue_bucket_bytes +
                                                 source.queue_node_bytes +
                                                 source.queue_block_bytes;
        }
        const auto catalog_source =
            static_cast<std::size_t>(JitPrecompileSource::ExecutableCatalog);
        result.profile_queue_entries = profile_queue_entries_;
        result.catalog_queue_entries =
            result.by_source[catalog_source].queued_entries;
        for (const auto& source : result.by_source)
            result.generic_queue_entries += source.queued_entries;
#ifndef NDEBUG
        const auto profile_source =
            static_cast<std::size_t>(JitPrecompileSource::DemandProfile);
        assert(result.profile_queue_entries ==
               result.by_source[profile_source].queued_entries);
        assert(result.pending_entries == pending_precompile_phases_.size());
        assert(result.inflight_entries == inflight_precompile_entries_.size());
        assert(result.deferred_entries == deferred_precompile_entries_.size());
        assert(
            result.completed_entries == completed_precompile_entries_.size());
#endif
    }

    void update_memory_peaks_locked(
        const JitPrecompileMemoryStats& current) const noexcept
    {
        memory_peak_.profile_queue_entries_peak =
            std::max(memory_peak_.profile_queue_entries_peak,
                current.profile_queue_entries);
        memory_peak_.catalog_queue_entries_peak =
            std::max(memory_peak_.catalog_queue_entries_peak,
                current.catalog_queue_entries);
        memory_peak_.generic_queue_entries_peak =
            std::max(memory_peak_.generic_queue_entries_peak,
                current.generic_queue_entries);
        memory_peak_.pending_entries_peak = std::max(
            memory_peak_.pending_entries_peak, current.pending_entries);
        memory_peak_.inflight_entries_peak = std::max(
            memory_peak_.inflight_entries_peak, current.inflight_entries);
        memory_peak_.deferred_entries_peak = std::max(
            memory_peak_.deferred_entries_peak, current.deferred_entries);
        memory_peak_.completed_entries_peak = std::max(
            memory_peak_.completed_entries_peak, current.completed_entries);
        memory_peak_.estimated_queue_entry_bytes_peak =
            std::max(memory_peak_.estimated_queue_entry_bytes_peak,
                current.estimated_queue_entry_bytes);
        memory_peak_.queue_bucket_bytes_peak = std::max(
            memory_peak_.queue_bucket_bytes_peak, current.queue_bucket_bytes);
        memory_peak_.queue_node_bytes_peak = std::max(
            memory_peak_.queue_node_bytes_peak, current.queue_node_bytes);
        memory_peak_.queue_block_bytes_peak = std::max(
            memory_peak_.queue_block_bytes_peak, current.queue_block_bytes);
        memory_peak_.profile_recorder_bytes_peak =
            std::max(memory_peak_.profile_recorder_bytes_peak,
                current.profile_recorder_bytes);
        memory_peak_.native_profile_prediction_bytes_peak =
            std::max(memory_peak_.native_profile_prediction_bytes_peak,
                current.native_profile_prediction_bytes);
        memory_peak_.native_preimport_tracker_bytes_peak =
            std::max(memory_peak_.native_preimport_tracker_bytes_peak,
                current.native_preimport_tracker_bytes);
        for (std::size_t source_index = 0;
            source_index < jit_precompile_source_count; ++source_index) {
            const auto& now = current.by_source[source_index];
            auto& peak = memory_peak_.by_source[source_index];
            peak.queued_entries_peak =
                std::max(peak.queued_entries_peak, now.queued_entries);
            peak.pending_entries_peak =
                std::max(peak.pending_entries_peak, now.pending_entries);
            peak.inflight_entries_peak =
                std::max(peak.inflight_entries_peak, now.inflight_entries);
            peak.deferred_entries_peak =
                std::max(peak.deferred_entries_peak, now.deferred_entries);
            peak.completed_entries_peak =
                std::max(peak.completed_entries_peak, now.completed_entries);
            peak.estimated_queue_entry_bytes_peak =
                std::max(peak.estimated_queue_entry_bytes_peak,
                    now.estimated_queue_entry_bytes);
            peak.queue_bucket_bytes_peak =
                std::max(peak.queue_bucket_bytes_peak, now.queue_bucket_bytes);
            peak.queue_node_bytes_peak =
                std::max(peak.queue_node_bytes_peak, now.queue_node_bytes);
            peak.queue_block_bytes_peak =
                std::max(peak.queue_block_bytes_peak, now.queue_block_bytes);
        }
        memory_snapshot_.publish(current, memory_peak_);
    }

    void update_memory_peaks_locked() const noexcept
    {
        JitPrecompileMemoryStats current;
        fill_memory_stats_locked(current);
        update_memory_peaks_locked(current);
    }

    enum class PrecompileEnqueueResult : std::uint8_t {
        Existing,
        Inserted,
        Rejected,
    };

    static void decrement_counter_locked(std::size_t& counter) noexcept
    {
        assert(counter != 0U);
        if (counter != 0U)
            --counter;
    }

    void decrement_profile_queue_entries_locked(
        const PrecompileEntry& entry) noexcept
    {
        if (entry.source == JitPrecompileSource::DemandProfile) {
            decrement_counter_locked(profile_queue_entries_);
            decrement_counter_locked(
                profile_queue_entries_by_target_[static_cast<std::size_t>(
                    entry.target)]);
        }
    }

    [[nodiscard]] std::size_t pending_entry_count_locked() const noexcept
    {
        std::size_t result { };
        for (const auto& queue : pending_precompile_entries_)
            result += queue.size();
        return result;
    }

    void assert_queue_counter_invariants_locked() const noexcept
    {
#ifndef NDEBUG
        const auto pending = pending_entry_count_locked();
        const auto pending_by_source = [&] {
            std::size_t result { };
            for (const auto count : pending_precompile_entries_by_source_)
                result += count;
            return result;
        }();
        const auto inflight_by_source = [&] {
            std::size_t result { };
            for (const auto count : inflight_precompile_entries_by_source_)
                result += count;
            return result;
        }();
        const auto deferred_by_source = [&] {
            std::size_t result { };
            for (const auto count : deferred_precompile_entries_by_source_)
                result += count;
            return result;
        }();
        const auto completed_by_source = [&] {
            std::size_t result { };
            for (const auto count : completed_precompile_entries_by_source_)
                result += count;
            return result;
        }();
        assert(pending == pending_precompile_phases_.size());
        assert(pending == pending_by_source);
        assert(inflight_by_source == inflight_precompile_entries_.size());
        assert(deferred_by_source == deferred_precompile_entries_.size());
        assert(completed_by_source == completed_precompile_entries_.size());
        assert(
            profile_queue_entries_ ==
            pending_precompile_entries_by_source_[static_cast<std::size_t>(
                JitPrecompileSource::DemandProfile)] +
                inflight_precompile_entries_by_source_[static_cast<std::size_t>(
                    JitPrecompileSource::DemandProfile)] +
                deferred_precompile_entries_by_source_[static_cast<std::size_t>(
                    JitPrecompileSource::DemandProfile)]);
        std::size_t profile_entries_by_target { };
        for (const auto count : profile_queue_entries_by_target_) {
            assert(count <= jit_profile_precompile_target_queue_entry_capacity);
            profile_entries_by_target += count;
        }
        assert(profile_entries_by_target == profile_queue_entries_);
#endif
    }

    [[nodiscard]] CompletedPrecompileEntry
    current_completed_generation_locked() const noexcept
    {
        return CompletedPrecompileEntry {
            execution_context_->cache_invalidation_epoch(),
            execution_context_->cache_clear_epoch(),
            execution_context_->observed_slab_generation(), profile_generation_
        };
    }

    void remove_completed_entry_locked(const PrecompileEntry& entry) noexcept
    {
        const auto found = completed_precompile_entries_.find(entry);
        if (found == completed_precompile_entries_.end())
            return;
        decrement_counter_locked(
            completed_precompile_entries_by_source_[static_cast<std::size_t>(
                entry.source)]);
        completed_precompile_entries_.erase(found);
        std::erase(completed_precompile_lru_, entry);
    }

    [[nodiscard]] bool completed_entry_is_current_locked(
        const PrecompileEntry& entry) noexcept
    {
        const auto found = completed_precompile_entries_.find(entry);
        if (found == completed_precompile_entries_.end())
            return false;
        const auto current = current_completed_generation_locked();
        if (found->second.cache_invalidation_epoch ==
                current.cache_invalidation_epoch &&
            found->second.slab_generation == current.slab_generation &&
            found->second.profile_generation == current.profile_generation) {
            return true;
        }
        remove_completed_entry_locked(entry);
        return false;
    }

    void record_completed_entry_locked(const PrecompileEntry& entry) noexcept
    {
        if (completed_precompile_entries_.contains(entry)) {
            remove_completed_entry_locked(entry);
        }
        while (completed_precompile_entries_.size() >=
                   jit_completed_precompile_entry_capacity &&
               !completed_precompile_lru_.empty()) {
            remove_completed_entry_locked(completed_precompile_lru_.front());
        }
        completed_precompile_entries_.insert_or_assign(
            entry, current_completed_generation_locked());
        completed_precompile_lru_.push_back(entry);
        ++completed_precompile_entries_by_source_[static_cast<std::size_t>(
            entry.source)];
    }

    void move_deferred_to_pending_locked(
        const PrecompileEntry& entry, JitPrecompilePhase phase) noexcept
    {
        pending_precompile_phases_.emplace(entry, phase);
        pending_precompile_entries_[phase_index(phase)].push_back(entry);
        decrement_counter_locked(
            deferred_precompile_entries_by_source_[static_cast<std::size_t>(
                entry.source)]);
        ++pending_precompile_entries_by_source_[static_cast<std::size_t>(
            entry.source)];
    }

    void promote_retryable_deferred_entries_locked(
        JitPrecompileSource source) noexcept
    {
        for (auto iterator = deferred_precompile_entries_.begin();
            iterator != deferred_precompile_entries_.end();) {
            if (iterator->first.source != source ||
                iterator->second.cache_full_invalidation_epoch) {
                ++iterator;
                continue;
            }
            const auto entry = iterator->first;
            const auto phase = iterator->second.phase;
            move_deferred_to_pending_locked(entry, phase);
            iterator = deferred_precompile_entries_.erase(iterator);
        }
    }

    void remove_inflight_entry_locked(const PrecompileEntry& entry) noexcept
    {
        if (inflight_precompile_entries_.erase(entry) == 0U)
            return;
        decrement_counter_locked(
            inflight_precompile_entries_by_source_[static_cast<std::size_t>(
                entry.source)]);
    }

    void defer_inflight_entry_locked(
        const PrecompileEntry& entry, DeferredPrecompileEntry deferred) noexcept
    {
        remove_inflight_entry_locked(entry);
        const auto [iterator, inserted] =
            deferred_precompile_entries_.insert_or_assign(entry, deferred);
        static_cast<void>(iterator);
        if (inserted) {
            ++deferred_precompile_entries_by_source_[static_cast<std::size_t>(
                entry.source)];
        }
    }

    void finish_inflight_entry_locked(
        const PrecompileEntry& entry, bool completed) noexcept
    {
        remove_inflight_entry_locked(entry);
        if (completed)
            record_completed_entry_locked(entry);
        decrement_profile_queue_entries_locked(entry);
    }

    static bool precompile_disposition_completed(
        JitExecutor::PrecompileDisposition disposition) noexcept
    {
        switch (disposition) {
        case JitExecutor::PrecompileDisposition::NativeCompiled:
        case JitExecutor::PrecompileDisposition::PortableGenerated:
        case JitExecutor::PrecompileDisposition::PortableArtifactHit:
        case JitExecutor::PrecompileDisposition::ArtifactImported:
        case JitExecutor::PrecompileDisposition::ArtifactProbeHit:
        case JitExecutor::PrecompileDisposition::SharedSlabHit:
            return true;
        case JitExecutor::PrecompileDisposition::Deferred:
        case JitExecutor::PrecompileDisposition::Unstable:
        case JitExecutor::PrecompileDisposition::CacheFull:
        case JitExecutor::PrecompileDisposition::Failed:
            return false;
        }
        return false;
    }

    [[nodiscard]] std::size_t active_precompile_entries_for_source_locked(
        JitPrecompileSource source) const noexcept
    {
        const auto source_index = static_cast<std::size_t>(source);
        return pending_precompile_entries_by_source_[source_index] +
               inflight_precompile_entries_by_source_[source_index] +
               deferred_precompile_entries_by_source_[source_index];
    }

    [[nodiscard]] static constexpr std::size_t
    active_precompile_source_capacity(JitPrecompileSource source) noexcept
    {
        switch (source) {
        case JitPrecompileSource::DemandProfile:
            return jit_profile_precompile_queue_entry_capacity;
        case JitPrecompileSource::ExecutableCatalog:
            return jit_catalog_precompile_queue_entry_capacity;
        case JitPrecompileSource::Other:
            return jit_translation_profile_maximum_locations *
                   jit_precompile_target_count;
        }
        return 0U;
    }

    static constexpr std::size_t phase_index(JitPrecompilePhase phase)
    {
        return static_cast<std::size_t>(phase);
    }

    [[nodiscard]] PrecompileEnqueueResult enqueue_precompile_entry_locked(
        PrecompileEntry entry, JitPrecompilePhase phase,
        bool revive_deferred = true)
    {
        bool was_deferred = false;
        if (const auto deferred = deferred_precompile_entries_.find(entry);
            deferred != deferred_precompile_entries_.end()) {
            if (!revive_deferred) {
                assert_queue_counter_invariants_locked();
                return PrecompileEnqueueResult::Existing;
            }
            was_deferred = true;
            if (phase_index(deferred->second.phase) < phase_index(phase)) {
                phase = deferred->second.phase;
            }
            deferred_precompile_entries_.erase(deferred);
            decrement_counter_locked(
                deferred_precompile_entries_by_source_[static_cast<std::size_t>(
                    entry.source)]);
        }
        if (entry.descriptor == 0 || completed_entry_is_current_locked(entry) ||
            inflight_precompile_entries_.contains(entry)) {
            assert_queue_counter_invariants_locked();
            return PrecompileEnqueueResult::Existing;
        }
        if (const auto pending = pending_precompile_phases_.find(entry);
            pending != pending_precompile_phases_.end()) {
            if (phase_index(phase) < phase_index(pending->second)) {
                pending->second = phase;
                for (auto& queue : pending_precompile_entries_)
                    std::erase(queue, entry);
                pending_precompile_entries_[phase_index(phase)].push_back(
                    entry);
            }
            assert_queue_counter_invariants_locked();
            return PrecompileEnqueueResult::Existing;
        }
        if (!was_deferred &&
            active_precompile_entries_for_source_locked(entry.source) >=
                active_precompile_source_capacity(entry.source)) {
            assert_queue_counter_invariants_locked();
            return PrecompileEnqueueResult::Rejected;
        }
        pending_precompile_phases_.emplace(entry, phase);
        pending_precompile_entries_[phase_index(phase)].push_back(entry);
        ++pending_precompile_entries_by_source_[static_cast<std::size_t>(
            entry.source)];
        if (entry.source == JitPrecompileSource::DemandProfile) {
            if (!was_deferred) {
                ++profile_queue_entries_;
                ++profile_queue_entries_by_target_[static_cast<std::size_t>(
                    entry.target)];
            }
            if (!was_deferred && translation_profile_) {
                if (entry.target == JitPrecompileTarget::NativeCode) {
                    translation_profile_->note_profile_native_enqueued();
                } else {
                    translation_profile_->note_profile_enqueued_portable();
                }
            }
        }
        update_memory_peaks_locked();
        assert_queue_counter_invariants_locked();
        return PrecompileEnqueueResult::Inserted;
    }

    void synchronize_native_profile_generation_locked() noexcept
    {
        if (!profile_precompile_enabled_ || native_profile_locations_.empty())
            return;
        const auto current = current_completed_generation_locked();
        if (native_profile_scan_generation_.cache_clear_epoch ==
                current.cache_clear_epoch &&
            native_profile_scan_generation_.slab_generation ==
                current.slab_generation &&
            native_profile_scan_generation_.profile_generation ==
                current.profile_generation) {
            return;
        }
        if (native_profile_scan_generation_.cache_clear_epoch ==
                current.cache_clear_epoch &&
            native_profile_scan_generation_.profile_generation ==
                current.profile_generation &&
            native_profile_scan_generation_.slab_generation == 0U &&
            current.slab_generation != 0U) {
            native_profile_scan_generation_.slab_generation =
                current.slab_generation;
            native_profile_scan_generation_.cache_invalidation_epoch =
                current.cache_invalidation_epoch;
            return;
        }
        if (native_profile_scan_generation_.cache_clear_epoch ==
                current.cache_clear_epoch &&
            native_profile_scan_generation_.profile_generation ==
                current.profile_generation &&
            native_profile_scan_generation_.slab_generation != 0U &&
            current.slab_generation != 0U) {
            profile_location_cursors_[static_cast<std::size_t>(
                JitPrecompileTarget::NativeCode)] =
                native_profile_locations_.size();
            native_profile_scan_generation_ = current;
            native_profile_recency_cursor_ =
                native_profile_recency_locations_.size();
            native_profile_recency_epoch_ = current.cache_invalidation_epoch;
            native_profile_recency_active_ = false;
            return;
        }
        profile_location_cursors_[static_cast<std::size_t>(
            JitPrecompileTarget::NativeCode)] = 0U;
        native_profile_scan_generation_ = current;
        native_profile_recency_cursor_ = 0U;
        native_profile_recency_epoch_ = current.cache_invalidation_epoch;
        native_profile_recency_active_ = false;
    }

    void refill_profile_entries_locked(JitPrecompileTarget target)
    {
        if (target == JitPrecompileTarget::NativeCode)
            synchronize_native_profile_generation_locked();
        const auto profile = translation_profile_;
        const auto target_index = static_cast<std::size_t>(target);
        if (!profile_precompile_enabled_ || !profile ||
            profile_queue_entries_by_target_[target_index] >=
                jit_profile_precompile_target_queue_entry_capacity) {
            return;
        }
        auto& profile_location_cursor = profile_location_cursors_[target_index];
        const auto available_entries =
            jit_profile_precompile_target_queue_entry_capacity -
            profile_queue_entries_by_target_[target_index];
        std::vector<std::uint64_t> locations;
        std::size_t next_cursor { };
        if (target == JitPrecompileTarget::NativeCode) {
            if (native_profile_recency_active_) {
                const auto limit =
                    std::min(native_profile_recency_locations_.size(),
                        jit_profile_recency_recovery_location_capacity);
                const auto start =
                    std::min(native_profile_recency_cursor_, limit);
                const auto count =
                    std::min(std::min(jit_profile_precompile_batch_size,
                                 available_entries),
                        limit - start);
                locations.reserve(count);
                for (std::size_t index = 0; index < count; ++index) {
                    locations.push_back(
                        native_profile_recency_locations_[start + index]);
                }
                native_profile_recency_cursor_ = start + count;
                if (native_profile_recency_cursor_ >= limit)
                    native_profile_recency_active_ = false;
                next_cursor = profile_location_cursor;
            } else {
                const auto start = std::min(
                    profile_location_cursor, native_profile_locations_.size());
                const auto count =
                    std::min(std::min(jit_profile_precompile_batch_size,
                                 available_entries),
                        native_profile_locations_.size() - start);
                locations.reserve(count);
                for (std::size_t index = 0; index < count; ++index) {
                    locations.push_back(
                        native_profile_locations_[start + index]);
                }
                next_cursor = start + count;
            }
        } else if (translation_profile_phase_ ==
                   JitPrecompilePhase::InteractiveActivation) {
            auto snapshot = profile->snapshot_range(profile_location_cursor,
                std::min(jit_profile_precompile_batch_size,
                    available_entries));
            locations = std::move(snapshot.first);
            next_cursor = snapshot.second;
        } else {
            auto& observed_revision = observed_profile_revisions_[target_index];
            const auto profile_revision = profile->revision();
            if (observed_revision != profile_revision) {
                profile_location_cursor = 0U;
                observed_revision = profile_revision;
            }
            if (profile_location_cursor > profile->storage_size())
                profile_location_cursor = 0U;
            auto snapshot = profile->snapshot_recent_missing_portable_range(
                profile_location_cursor,
                std::min(jit_profile_precompile_batch_size, available_entries));
            locations = std::move(snapshot.first);
            next_cursor = snapshot.second;
        }
        profile_location_cursor = next_cursor;
        for (const auto location : locations) {
            if (location == 0U)
                continue;
            if (enqueue_precompile_entry_locked(
                    PrecompileEntry {
                        location, target, JitPrecompileSource::DemandProfile },
                    translation_profile_phase_,
                    false) == PrecompileEnqueueResult::Rejected) {
                break;
            }
        }
    }

    void promote_cache_full_entries_locked(
        std::optional<JitPrecompileSource> source = std::nullopt)
    {
        if (deferred_precompile_entries_.empty())
            return;
        const auto current_epoch =
            execution_context_->cache_invalidation_epoch();
        const auto promote_source = [&](JitPrecompileSource selected_source) {
            const auto source_index = static_cast<std::size_t>(selected_source);
            auto& observed_epoch = cache_full_epoch_observed_[source_index];
            const auto relevant =
                std::find_if(deferred_precompile_entries_.begin(),
                    deferred_precompile_entries_.end(),
                    [selected_source](const auto& entry) {
                        return entry.first.source == selected_source;
                    });
            if (relevant == deferred_precompile_entries_.end() ||
                (observed_epoch && *observed_epoch == current_epoch)) {
                return;
            }
            observed_epoch = current_epoch;
            for (auto iterator = deferred_precompile_entries_.begin();
                iterator != deferred_precompile_entries_.end();) {
                if (iterator->first.source != selected_source ||
                    !iterator->second.cache_full_invalidation_epoch ||
                    *iterator->second.cache_full_invalidation_epoch ==
                        current_epoch) {
                    ++iterator;
                    continue;
                }
                const auto entry = iterator->first;
                const auto phase = iterator->second.phase;
                move_deferred_to_pending_locked(entry, phase);
                iterator = deferred_precompile_entries_.erase(iterator);
            }
        };
        if (source) {
            promote_source(*source);
        } else {
            for (std::size_t source_index = 0;
                source_index < jit_precompile_source_count; ++source_index) {
                promote_source(static_cast<JitPrecompileSource>(source_index));
            }
        }
        update_memory_peaks_locked();
        assert_queue_counter_invariants_locked();
    }

    [[nodiscard]] std::optional<JitPrecompilePhase>
    next_precompile_phase_locked(JitPrecompileTarget target,
        std::optional<JitPrecompileSource> source = std::nullopt)
    {
        if (source && *source == JitPrecompileSource::DemandProfile &&
            !translation_profile_) {
            return std::nullopt;
        }
        promote_cache_full_entries_locked(source);
        if (!source || *source == JitPrecompileSource::DemandProfile)
            refill_profile_entries_locked(target);
        for (std::size_t index = 0; index < pending_precompile_entries_.size();
            ++index) {
            auto& queue = pending_precompile_entries_[index];
            for (auto iterator = queue.begin(); iterator != queue.end();) {
                const auto entry = *iterator;
                const auto pending = pending_precompile_phases_.find(entry);
                if (pending == pending_precompile_phases_.end() ||
                    phase_index(pending->second) != index) {
                    iterator = queue.erase(iterator);
                    continue;
                }
                if (entry.target == target &&
                    (!source || entry.source == *source)) {
                    return pending->second;
                }
                ++iterator;
            }
        }
        return std::nullopt;
    }

    [[nodiscard]] std::optional<std::pair<PrecompileEntry, JitPrecompilePhase>>
    take_precompile_entry_locked(JitPrecompileTarget target,
        std::optional<JitPrecompileSource> source = std::nullopt)
    {
        const auto phase = next_precompile_phase_locked(target, source);
        if (!phase)
            return std::nullopt;
        auto& queue = pending_precompile_entries_[phase_index(*phase)];
        for (auto iterator = queue.begin(); iterator != queue.end();) {
            const auto entry = *iterator;
            const auto pending = pending_precompile_phases_.find(entry);
            if (pending == pending_precompile_phases_.end() ||
                phase_index(pending->second) != phase_index(*phase)) {
                iterator = queue.erase(iterator);
                continue;
            }
            if (entry.target != target || (source && entry.source != *source)) {
                ++iterator;
                continue;
            }
            queue.erase(iterator);
            pending_precompile_phases_.erase(entry);
            decrement_counter_locked(
                pending_precompile_entries_by_source_[static_cast<std::size_t>(
                    entry.source)]);
            inflight_precompile_entries_.insert(entry);
            ++inflight_precompile_entries_by_source_[static_cast<std::size_t>(
                entry.source)];
            update_memory_peaks_locked();
            assert_queue_counter_invariants_locked();
            return std::pair { entry, *phase };
        }
        return std::nullopt;
    }

    AddressSpace& memory_;
    std::shared_ptr<ExecutionContext> execution_context_;
    std::shared_ptr<JitNativePreimportTracker> native_preimport_tracker_;
    Dynarmic::ExclusiveMonitor& monitor_;
    const ArmCpuModel& cpu_model_;
    std::shared_ptr<JitArtifactStore> artifact_store_;
    std::size_t code_cache_size_ { 64U * 1024U * 1024U };
    std::vector<std::unique_ptr<JitExecutor>> executors_;
    std::vector<std::unique_ptr<JitExecutor>> precompile_executors_;
    std::vector<bool> precompile_executor_busy_;
    std::array<std::deque<PrecompileEntry>, jit_precompile_phase_count>
        pending_precompile_entries_;
    std::unordered_map<PrecompileEntry, JitPrecompilePhase, PrecompileEntryHash>
        pending_precompile_phases_;
    std::unordered_set<PrecompileEntry, PrecompileEntryHash>
        inflight_precompile_entries_;
    std::unordered_map<PrecompileEntry, DeferredPrecompileEntry,
        PrecompileEntryHash>
        deferred_precompile_entries_;
    std::unordered_map<PrecompileEntry, CompletedPrecompileEntry,
        PrecompileEntryHash>
        completed_precompile_entries_;
    std::deque<PrecompileEntry> completed_precompile_lru_;
    std::shared_ptr<JitTranslationProfile> translation_profile_;
    std::vector<std::uint64_t> native_profile_locations_;
    std::vector<std::uint64_t> native_profile_recency_locations_;
    CompletedPrecompileEntry native_profile_scan_generation_ { };
    std::size_t native_profile_recency_cursor_ { };
    std::uint64_t native_profile_recency_epoch_ { };
    bool native_profile_recency_active_ { };
    JitPrecompilePhase translation_profile_phase_ {
        JitPrecompilePhase::Opportunistic
    };
    bool profile_recording_enabled_ { };
    bool profile_precompile_enabled_ { };
    std::array<std::size_t, jit_precompile_target_count>
        profile_location_cursors_ { };
    std::array<std::uint64_t, jit_precompile_target_count>
        observed_profile_revisions_ { };
    std::size_t profile_queue_entries_ { };
    std::array<std::size_t, jit_precompile_target_count>
        profile_queue_entries_by_target_ { };
    std::array<std::size_t, jit_precompile_source_count>
        pending_precompile_entries_by_source_ { };
    std::array<std::size_t, jit_precompile_source_count>
        inflight_precompile_entries_by_source_ { };
    std::array<std::size_t, jit_precompile_source_count>
        deferred_precompile_entries_by_source_ { };
    std::array<std::size_t, jit_precompile_source_count>
        completed_precompile_entries_by_source_ { };
    std::array<std::optional<std::uint64_t>, jit_precompile_source_count>
        cache_full_epoch_observed_ { };
    std::uint64_t profile_generation_ { };
    bool precompile_quiescing_ { };
    std::uint64_t precompile_cancellation_generation_ { 1 };
    std::uint64_t active_precompile_tasks_ { };
    std::condition_variable precompile_idle_;
    mutable std::mutex precompile_queue_mutex_;
    mutable JitPrecompileMemoryStats memory_peak_ { };
    mutable AtomicJitPrecompileMemorySnapshot memory_snapshot_ { };
};

Cpu::Cpu(std::size_t processor_id, AddressSpace& memory,
    Dynarmic::ExclusiveMonitor& monitor)
    : Cpu { processor_id, std::make_shared<CpuExecutionPool>(memory, monitor, 1,
                              processor_id, default_arm_cpu_model(), nullptr) }
{
}

Cpu::Cpu(
    std::size_t processor_id, std::shared_ptr<CpuExecutionPool> execution_pool)
    : processor_id_ { processor_id }
    , execution_pool_ { std::move(execution_pool) }
{
}

Cpu::~Cpu() = default;

CpuRunResult Cpu::run(std::uint64_t ticks, std::size_t execution_slot)
{
    if (!execution_pool_) {
        throw std::logic_error { "CPU execution resources have been released" };
    }
    return execution_pool_->executor(execution_slot)
        .run(*this, ticks, false, false);
}

CpuRunResult Cpu::run_cooperatively(
    std::uint64_t ticks, std::size_t execution_slot)
{
    if (!execution_pool_) {
        throw std::logic_error { "CPU execution resources have been released" };
    }
    return execution_pool_->executor(execution_slot)
        .run(*this, ticks, false, true, default_host_cooperative_slice_budget);
}

CpuRunResult Cpu::run_cooperatively(std::uint64_t ticks,
    std::chrono::nanoseconds host_slice_budget, std::size_t execution_slot)
{
    if (!execution_pool_) {
        throw std::logic_error { "CPU execution resources have been released" };
    }
    return execution_pool_->executor(execution_slot)
        .run(*this, ticks, false, true, host_slice_budget);
}

CpuRunResult Cpu::step(std::size_t execution_slot)
{
    if (!execution_pool_) {
        throw std::logic_error { "CPU execution resources have been released" };
    }
    return execution_pool_->executor(execution_slot).run(*this, 1, true, false);
}

void Cpu::reset()
{
    state_ = { };
    if (active_executor_) {
        active_executor_->reset_live_state();
    }
}
void Cpu::clear_cache()
{
    if (execution_pool_) {
        execution_pool_->clear_cache();
    }
}
void Cpu::invalidate_cache_range(std::uint32_t address, std::size_t length)
{
    if (execution_pool_) {
        execution_pool_->invalidate_cache_range(address, length);
    }
}
void Cpu::invalidate_cache_ranges(
    std::span<const CacheInvalidationRange> ranges)
{
    if (execution_pool_) {
        execution_pool_->invalidate_cache_ranges(ranges);
    }
}
void Cpu::raise_memory_fault(
    std::uint32_t address, std::size_t size, MemoryPermission access)
{
    if (active_executor_) {
        active_executor_->raise_memory_fault(address, size, access);
        return;
    }
    halt(Dynarmic::HaltReason::UserDefined4);
}
void Cpu::clear_halt()
{
    requested_halt_reason_ = { };
    if (active_executor_) {
        active_executor_->clear_halt();
    }
}
void Cpu::halt(Dynarmic::HaltReason reason)
{
    requested_halt_reason_ = requested_halt_reason_ | reason;
    if (active_executor_) {
        active_executor_->halt(reason);
    }
}

void Cpu::request_guest_preemption()
{
    performance_counters().record_scheduler_preemption_request();
    const bool coalesced = Dynarmic::Has(requested_halt_reason_,
                               Dynarmic::HaltReason::UserDefined2) ||
                           (active_executor_ != nullptr &&
                               active_executor_->guest_preemption_requested());
    if (coalesced) {
        performance_counters().record_scheduler_preemption_coalesced();
    }
    requested_halt_reason_ =
        requested_halt_reason_ | Dynarmic::HaltReason::UserDefined2;
    if (active_executor_) {
        active_executor_->request_guest_preemption();
    }
}

Dynarmic::HaltReason Cpu::consume_requested_halt_reason()
{
    const auto reason = requested_halt_reason_;
    requested_halt_reason_ = { };
    if (Dynarmic::Has(reason, Dynarmic::HaltReason::UserDefined2)) {
        performance_counters().record_scheduler_preemption_deferred_consume();
    }
    return reason;
}

std::array<std::uint32_t, 16>& Cpu::registers()
{
    return active_executor_ ? active_executor_->registers() : state_.registers;
}
const std::array<std::uint32_t, 16>& Cpu::registers() const
{
    return active_executor_ ? active_executor_->registers() : state_.registers;
}
std::uint32_t Cpu::cpsr() const
{
    return active_executor_ ? active_executor_->cpsr() : state_.cpsr;
}
void Cpu::set_cpsr(std::uint32_t value)
{
    if (active_executor_) {
        active_executor_->set_cpsr(value);
    } else {
        state_.cpsr = value;
    }
}
std::array<std::uint32_t, 64>& Cpu::extension_registers()
{
    return active_executor_ ? active_executor_->extension_registers()
                            : state_.extension_registers;
}
const std::array<std::uint32_t, 64>& Cpu::extension_registers() const
{
    return active_executor_ ? active_executor_->extension_registers()
                            : state_.extension_registers;
}
std::uint32_t Cpu::fpscr() const
{
    return active_executor_ ? active_executor_->fpscr() : state_.fpscr;
}
void Cpu::set_fpscr(std::uint32_t value)
{
    if (active_executor_) {
        active_executor_->set_fpscr(value);
    } else {
        state_.fpscr = value;
    }
}
std::optional<std::uint32_t> Cpu::cthread_self() const
{
    return state_.cthread_self;
}
void Cpu::set_cthread_self(std::optional<std::uint32_t> value)
{
    state_.cthread_self = value;
}
void Cpu::set_svc_handler(SvcHandler handler)
{
    svc_handler_ = std::move(handler);
}
void Cpu::set_svc_dispatch_mode(SvcDispatchMode mode)
{
    svc_dispatch_mode_ = mode;
}
void Cpu::set_guest_thread(std::uint32_t thread)
{
    guest_thread_ = thread;
}
void Cpu::set_memory_write_watchpoint(
    std::uint32_t address, MemoryWriteHandler handler)
{
    if (handler && execution_pool_) {
        execution_pool_->disable_jit_page_table();
    }
    memory_write_watch_address_ = address;
    memory_write_handler_ = std::move(handler);
}
void Cpu::set_debug_breakpoints_enabled(bool enabled)
{
    debug_breakpoints_enabled_ = enabled;
}
void Cpu::set_translation_profile(
    std::shared_ptr<JitTranslationProfile> profile, bool record,
    bool precompile)
{
    if (execution_pool_) {
        execution_pool_->set_translation_profile(std::move(profile),
            JitPrecompilePhase::Opportunistic, record, precompile);
    }
}
void Cpu::clear_exclusive_state(std::size_t execution_slot)
{
    if (!execution_pool_) {
        return;
    }
    execution_pool_->clear_exclusive_state(execution_slot);
}

CpuCluster::CpuCluster(std::size_t processor_count, AddressSpace& memory)
    : CpuCluster { processor_count, processor_count, memory }
{
}

CpuCluster::CpuCluster(std::size_t initial_processor_count,
    std::size_t maximum_processor_count, AddressSpace& memory)
    : CpuCluster { initial_processor_count, maximum_processor_count, memory,
        false }
{
}

CpuCluster::CpuCluster(std::size_t initial_processor_count,
    std::size_t maximum_processor_count, AddressSpace& memory,
    bool serialized_execution)
    : CpuCluster { initial_processor_count, maximum_processor_count, memory,
        serialized_execution, default_arm_cpu_model() }
{
}

CpuCluster::CpuCluster(std::size_t initial_processor_count,
    std::size_t maximum_processor_count, AddressSpace& memory,
    bool serialized_execution, const ArmCpuModel& cpu_model)
    : CpuCluster { initial_processor_count, maximum_processor_count, memory,
        serialized_execution ? 1U : maximum_processor_count, cpu_model }
{
}

CpuCluster::CpuCluster(std::size_t initial_processor_count,
    std::size_t maximum_processor_count, AddressSpace& memory,
    std::size_t execution_slot_count, const ArmCpuModel& cpu_model)
    : memory_ { &memory }
    , maximum_processor_count_ { maximum_processor_count }
    , serialized_execution_ { execution_slot_count == 1 }
    , cpu_model_ { &cpu_model }
    , monitor_ { execution_slot_count == 0 ? 1U : execution_slot_count }
    , execution_monitor_ { &monitor_ }
    , monitor_processor_base_ { }
    , execution_pool_ { std::make_shared<CpuExecutionPool>(memory,
          *execution_monitor_, execution_slot_count, monitor_processor_base_,
          cpu_model, nullptr) }
{
    if (initial_processor_count == 0) {
        throw std::invalid_argument {
            "initial_processor_count must be at least one"
        };
    }
    if (maximum_processor_count < initial_processor_count) {
        throw std::invalid_argument {
            "maximum_processor_count must cover the initial processors"
        };
    }
    cpus_.reserve(maximum_processor_count);
    while (cpus_.size() < initial_processor_count) {
        static_cast<void>(add_cpu());
    }
}

CpuCluster::CpuCluster(std::size_t initial_processor_count,
    std::size_t maximum_processor_count, AddressSpace& memory,
    std::size_t execution_slot_count, const ArmCpuModel& cpu_model,
    Dynarmic::ExclusiveMonitor& monitor, std::size_t monitor_processor_base,
    std::shared_ptr<JitArtifactStore> artifact_store,
    std::shared_ptr<GuestExclusiveAddressResolver> address_resolver,
    std::size_t precompile_lane_count)
    : memory_ { &memory }
    , maximum_processor_count_ { maximum_processor_count }
    , serialized_execution_ { execution_slot_count == 1 }
    , cpu_model_ { &cpu_model }
    , monitor_ { 1U }
    , execution_monitor_ { &monitor }
    , monitor_processor_base_ { monitor_processor_base }
    , monitor_processor_count_ { execution_slot_count }
    , address_resolver_ { std::move(address_resolver) }
    , execution_pool_ { std::make_shared<CpuExecutionPool>(memory,
          *execution_monitor_, execution_slot_count, monitor_processor_base_,
          cpu_model, std::move(artifact_store), precompile_lane_count) }
{
    if (initial_processor_count == 0) {
        throw std::invalid_argument {
            "initial_processor_count must be at least one"
        };
    }
    if (maximum_processor_count < initial_processor_count) {
        throw std::invalid_argument {
            "maximum_processor_count must cover the initial processors"
        };
    }
    if (address_resolver_) {
        address_resolver_->bind(
            monitor_processor_base_, monitor_processor_count_, memory);
        monitor.SetAddressResolver(
            &GuestExclusiveAddressResolver::resolve_callback,
            address_resolver_.get());
        if (monitor_processor_count_ > 1)
            memory.set_parallel_access(true);
    }
    if (!address_resolver_) {
        memory.set_exclusive_write_observer([&monitor] { monitor.Clear(); });
    }
    cpus_.reserve(maximum_processor_count);
    while (cpus_.size() < initial_processor_count) {
        static_cast<void>(add_cpu());
    }
}

CpuCluster::~CpuCluster()
{
    quiesce_precompilation();
    if (address_resolver_ != nullptr) {
        address_resolver_->unbind(
            monitor_processor_base_, monitor_processor_count_, *memory_);
    }
}

std::optional<std::size_t> CpuCluster::add_cpu()
{
    if (cpus_.size() >= capacity()) {
        return std::nullopt;
    }
    const auto id = cpus_.size();
    cpus_.push_back(std::unique_ptr<Cpu> { new Cpu { id, execution_pool_ } });
    return id;
}

void CpuCluster::set_process_id(std::uint32_t process_id)
{
    execution_pool_->set_process_id(process_id);
}

void CpuCluster::set_jit_code_cache_size(std::size_t bytes)
{
    execution_pool_->set_code_cache_size(bytes);
}

void CpuCluster::prepare_primary_execution_resource()
{
    if (execution_pool_)
        execution_pool_->prepare_primary_execution_resource();
}

std::size_t CpuCluster::precompile_lane_count() const noexcept
{
    return execution_pool_ ? execution_pool_->precompile_lane_count() : 0U;
}

void CpuCluster::set_jit_work_signal(
    std::shared_ptr<JitWorkObservationSignal> signal)
{
    if (execution_pool_)
        execution_pool_->set_jit_work_signal(std::move(signal));
}

std::uint64_t CpuCluster::jit_code_cache_bytes()
{
    return execution_pool_ ? execution_pool_->code_cache_used() : 0U;
}

void CpuCluster::clear_cache() { execution_pool_->clear_cache(); }

void CpuCluster::invalidate_cache_range(
    std::uint32_t address, std::size_t length)
{
    execution_pool_->invalidate_cache_range(address, length);
}

void CpuCluster::set_translation_profile(
    std::shared_ptr<JitTranslationProfile> profile, JitPrecompilePhase phase,
    bool record, bool precompile)
{
    execution_pool_->set_translation_profile(
        std::move(profile), phase, record, precompile);
}

void CpuCluster::refresh_translation_profile()
{
    if (execution_pool_)
        execution_pool_->refresh_translation_profile();
}

void CpuCluster::retry_deferred_translation_profile()
{
    if (execution_pool_)
        execution_pool_->retry_deferred_translation_profile();
}

JitPrecompileMemoryStats CpuCluster::precompile_memory_stats() const
{
    if (!execution_pool_)
        return { };
    return execution_pool_->precompile_memory_stats();
}

void CpuCluster::set_jit_artifact_retention(JitArtifactRetention retention)
{
    execution_pool_->set_artifact_retention(retention);
}

void CpuCluster::add_precompile_entries(
    const std::vector<std::uint64_t>& location_descriptors,
    JitPrecompilePhase phase, JitPrecompileSource source)
{
    if (execution_pool_) {
        execution_pool_->add_precompile_entries(
            location_descriptors, phase, source);
    }
}

std::optional<JitPrecompilePhase> CpuCluster::next_precompile_phase(
    JitPrecompileTarget target, std::optional<JitPrecompileSource> source)
{
    if (!execution_pool_)
        return std::nullopt;
    return execution_pool_->next_precompile_phase(target, source);
}

JitPrecompileBatchResult CpuCluster::precompile_pending(
    std::size_t maximum_blocks, std::uint64_t budget_nanoseconds,
    JitPrecompileTarget target, PrecompileStopCondition stop_condition,
    std::optional<JitPrecompileSource> source)
{
    if (!execution_pool_) {
        return { };
    }
    return execution_pool_->precompile_pending(
        maximum_blocks, budget_nanoseconds, target, stop_condition, source);
}

void CpuCluster::quiesce_precompilation()
{
    if (execution_pool_)
        execution_pool_->quiesce_precompilation();
}

std::shared_ptr<CpuExecutionPool> CpuCluster::release_execution_resources()
{
    if (!execution_pool_) {
        return { };
    }
    quiesce_precompilation();
    for (const auto& cpu : cpus_) {
        if (cpu->active_executor_ != nullptr) {
            throw std::logic_error {
                "cannot release CPU execution resources while executing"
            };
        }
    }
    auto retired = std::move(execution_pool_);
    for (auto& cpu : cpus_) {
        cpu->execution_pool_.reset();
    }
    return retired;
}

std::vector<CpuRunResult> CpuCluster::run_parallel(std::uint64_t ticks_per_cpu)
{
    if (!execution_pool_) {
        throw std::logic_error { "CPU execution resources have been released" };
    }
    if (serialized_execution_ && cpus_.size() > 1) {
        throw std::logic_error {
            "serialized CPU contexts cannot execute in parallel"
        };
    }
    std::vector<CpuRunResult> results(cpus_.size());
    std::vector<std::thread> workers;
    workers.reserve(cpus_.size());
    for (std::size_t index = 0; index < cpus_.size(); ++index) {
        workers.emplace_back([&, index] {
            results[index] = cpus_[index]->run(ticks_per_cpu, index);
        });
    }
    for (auto& worker : workers) {
        worker.join();
    }
    return results;
}

}
