// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Select optional JIT work classes and limits from backend and
// runtime conditions.

#pragma once

#include <chrono>
#include <cstddef>
#include <cstdint>
#include <optional>

namespace shade {

inline constexpr std::size_t jit_work_policy_maximum_translation_lanes = 4U;

struct JitNativePredictionPolicy {
    std::size_t activation_locations { };
    std::size_t recent_locations { };
    std::size_t historical_locations { };
    std::size_t maximum_code_bytes { };
};

enum class JitNativeBackend : std::uint8_t {
    X64RelativeCodeModel,
    Arm64AddressSpace,
};

enum class JitWorkClass : std::uint8_t {
    ActivationNative,
    ActivationPortable,
    InteractiveNative,
    PredictiveNative,
    OfflinePortable,
};

enum class JitWorkBlockReason : std::uint8_t {
    None,
    MemoryPressure,
    DisplayBusy,
    GuestBusy,
    DeadlineReserve,
    ZeroBudget,
};

struct JitWorkObservation {
    bool memory_pressure { };
    // Host interaction and realtime callback facts are intentionally supplied
    // without frontend or renderer identity. Native prediction shares the
    // demand emitter, so a runnable interactive image may use it only after a
    // real quiet period and outside an active callback dependency.
    bool realtime_work_pending { };
    // Offline persistence is not useful before a display session has produced
    // its first frame; startup gaps are interactive work, not idle time.
    bool display_started { };
    // Empty means that neither guest realtime nor host control currently has
    // a finite deadline. The client supplies the nearer delay when both exist.
    std::optional<std::chrono::nanoseconds> deadline_remaining;
    std::optional<std::chrono::nanoseconds> display_quiet_for;
    std::optional<std::chrono::nanoseconds> guest_idle_for;
    std::optional<std::chrono::nanoseconds> interaction_quiet_for;
    std::uint64_t block_compile_p95_nanoseconds { };
    std::uint64_t block_compile_p99_nanoseconds { };
};

struct JitWorkDecision {
    std::uint64_t budget_nanoseconds { };
    std::size_t maximum_blocks { };
    JitWorkBlockReason blocked_by { JitWorkBlockReason::ZeroBudget };

    [[nodiscard]] explicit operator bool() const noexcept
    {
        return budget_nanoseconds != 0U && maximum_blocks != 0U;
    }
};

// Pure simulator-core admission policy. Frontends provide host observations
// and execute the returned bounded work; renderer, event-loop, app and firmware
// identities never enter the algorithm.
class JitWorkPolicy {
public:
    // Native-cache limits are host code-generator profiles, not Guest device,
    // application or firmware profiles. x64 keeps the complete mapping safely
    // inside the signed rel32 reach used by generated terminals; arm64 retains
    // Umbra's current address-space limit.
    [[nodiscard]] static constexpr JitNativeBackend
    native_backend() noexcept
    {
#if defined(__x86_64__) || defined(_M_X64)
        return JitNativeBackend::X64RelativeCodeModel;
#else
        return JitNativeBackend::Arm64AddressSpace;
#endif
    }
    [[nodiscard]] static constexpr std::size_t
    maximum_native_slab_bytes() noexcept
    {
        return native_backend() ==
                       JitNativeBackend::X64RelativeCodeModel
                   ? 1536ULL * 1024ULL * 1024ULL
                   : 128ULL * 1024ULL * 1024ULL;
    }
    // Choose the per-runtime native slab ceiling from host facts. The frontend
    // may provide an explicit override, but default sizing belongs to the
    // simulator core rather than a particular window/client implementation.
    [[nodiscard]] static std::size_t recommended_native_slab_bytes(
        std::uint64_t effective_memory_bytes, bool effective_memory_known,
        std::uint64_t available_memory_bytes,
        bool available_memory_known) noexcept;
    // Preserve at least half of a multi-worker host pool for Guest-adjacent
    // services while allowing portable translation to outrun serial demand.
    // Native publication remains single-lane per shared code slab; this count
    // is the heterogeneous translation-pipeline width.
    [[nodiscard]] static std::size_t recommended_translation_lanes(
        std::size_t host_worker_count) noexcept;
    // Native prediction is advisory and shares the demand emitter. Keep the
    // frozen plan and emitted bytes independently bounded rather than scaling
    // speculative work with a large virtual mapping.
    // Size the frozen prediction from the runtime's immutable native mapping.
    // The prefix is the learned activation order, followed by the newest
    // interaction tail and only then older history. The byte budget remains
    // independently enforced while code is emitted, so descriptor count is a
    // useful ordering horizon rather than a commitment of executable memory.
    [[nodiscard]] static JitNativePredictionPolicy native_prediction_policy(
        std::size_t native_slab_bytes) noexcept;
    // A newly prepared image remains suspended while bounded prediction can
    // overlap its caller's transition. The window scales with independent
    // translation lanes and is zero when no host worker is available.
    [[nodiscard]] static std::chrono::milliseconds
    activation_preparation_window(std::size_t translation_lanes) noexcept;
    [[nodiscard]] static constexpr std::chrono::milliseconds
    interactive_native_quiet_period() noexcept
    {
        return std::chrono::milliseconds { 1000 };
    }
    [[nodiscard]] JitWorkDecision decide(JitWorkClass work,
        const JitWorkObservation& observation) const noexcept;
};

} // namespace shade
