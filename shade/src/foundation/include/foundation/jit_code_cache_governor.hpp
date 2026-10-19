// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Allocate native-code cache budgets and reclaim code according to
// runtime value.

#pragma once

#include <cstddef>
#include <cstdint>
#include <memory>
#include <mutex>
#include <optional>

namespace shade {

// A class describes how valuable already-emitted native code is when the host
// asks the simulator to release memory. It never controls whether a process is
// allowed enough address space for demand translation.
enum class JitCodeCacheClass : std::uint8_t {
    BootCritical,
    Foreground,
    Background,
};

class JitCodeCacheGovernor;

class JitCodeCacheReservation {
public:
    ~JitCodeCacheReservation();

    JitCodeCacheReservation(const JitCodeCacheReservation&) = delete;
    JitCodeCacheReservation& operator=(const JitCodeCacheReservation&) = delete;

    // This is lazily committed executable address space, not resident memory.
    [[nodiscard]] std::size_t shared_slab_bytes() const noexcept
    {
        return shared_slab_bytes_;
    }

private:
    friend class JitCodeCacheGovernor;

    JitCodeCacheReservation(JitCodeCacheGovernor& governor,
        std::size_t shared_slab_bytes, JitCodeCacheClass cache_class) noexcept;

    JitCodeCacheGovernor* governor_ { };
    std::size_t shared_slab_bytes_ { };
    JitCodeCacheClass cache_class_ { JitCodeCacheClass::Background };
    std::uint64_t actual_bytes_ { };
};

// Simulator-core capacity governor for per-process native-code slabs. Native
// mappings are virtual, immutable after emitter construction and committed on
// first use. The aggregate budget therefore governs measured live code and
// reclamation; it is deliberately not a first-come mapping admission pool.
class JitCodeCacheGovernor {
public:
    static constexpr std::size_t bytes_per_mebibyte = 1024U * 1024U;
    // A 64 MiB uniform-cap control retained the measured SpringBoard working
    // set without a single recycle. Keep that backend-independent demand floor
    // available to every runtime, including one created late in boot.
    static constexpr std::size_t minimum_demand_working_set_bytes =
        64U * bytes_per_mebibyte;
    static constexpr std::size_t maximum_background_retention_bytes =
        256U * bytes_per_mebibyte;
    static constexpr std::size_t maximum_adaptive_budget_bytes =
        8192U * bytes_per_mebibyte;

    JitCodeCacheGovernor(
        std::size_t shared_slab_cap, std::size_t total_budget) noexcept;

    JitCodeCacheGovernor(const JitCodeCacheGovernor&) = delete;
    JitCodeCacheGovernor& operator=(const JitCodeCacheGovernor&) = delete;

    [[nodiscard]] std::shared_ptr<JitCodeCacheReservation> reserve(
        std::size_t processor_count,
        JitCodeCacheClass cache_class = JitCodeCacheClass::Background);
    [[nodiscard]] std::optional<std::size_t> reclassify(
        JitCodeCacheReservation& reservation, JitCodeCacheClass cache_class,
        bool slab_can_resize) noexcept;
    void refresh_actual(JitCodeCacheReservation& reservation,
        std::uint64_t actual_bytes) noexcept;

    void set_pressure_limited(bool limited) noexcept;
    [[nodiscard]] bool pressure_limited() const noexcept;
    // Every class receives the same lazy mapping capacity. The class-specific
    // distinction is exposed separately as a soft retention target.
    [[nodiscard]] std::size_t shared_slab_cap(
        JitCodeCacheClass cache_class) const noexcept;
    [[nodiscard]] std::size_t retention_target(
        JitCodeCacheClass cache_class) const noexcept;
    [[nodiscard]] std::size_t retention_target(
        const JitCodeCacheReservation& reservation) const noexcept;
    // Returns bytes above the reservation's retention target only while the
    // aggregate live-code budget or host pressure requires reclamation.
    [[nodiscard]] std::size_t reclaimable_bytes(
        const JitCodeCacheReservation& reservation) const noexcept;
    [[nodiscard]] std::size_t total_budget() const noexcept;
    [[nodiscard]] std::size_t total_mapped() const noexcept;
    [[nodiscard]] std::size_t total_actual() const noexcept;
    // Convert normalized host-memory facts into one process-wide live-code
    // target. Frontends collect platform facts; simulator policy owns the
    // fractions, safety floor and ceiling.
    [[nodiscard]] static std::size_t recommended_total_budget(
        std::uint64_t effective_memory_bytes, bool effective_memory_known,
        std::uint64_t available_headroom_bytes,
        bool available_headroom_known) noexcept;

private:
    friend class JitCodeCacheReservation;

    [[nodiscard]] std::size_t retention_target_for_locked(
        JitCodeCacheClass cache_class) const noexcept;
    void release(std::size_t mapped_bytes, std::uint64_t actual_bytes) noexcept;

    const std::size_t shared_slab_cap_;
    const std::size_t total_budget_;
    mutable std::mutex mutex_;
    std::size_t mapped_bytes_total_ { };
    std::size_t actual_bytes_total_ { };
    bool pressure_limited_ { };
};

} // namespace shade
