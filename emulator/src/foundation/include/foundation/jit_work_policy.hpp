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
    bool realtime_work_pending { };
    bool display_started { };
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

class JitWorkPolicy {
public:
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
    [[nodiscard]] static std::size_t recommended_native_slab_bytes(
        std::uint64_t effective_memory_bytes, bool effective_memory_known,
        std::uint64_t available_memory_bytes,
        bool available_memory_known) noexcept;
    [[nodiscard]] static std::size_t recommended_translation_lanes(
        std::size_t host_worker_count) noexcept;
    [[nodiscard]] static JitNativePredictionPolicy native_prediction_policy(
        std::size_t native_slab_bytes) noexcept;
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

}
