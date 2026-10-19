// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Correlate native artifact preimports with later demand in bounded
// diagnostic windows.

#pragma once

#include <array>
#include <atomic>
#include <cstddef>
#include <cstdint>
#include <limits>

namespace shade {

// The tracker is a bounded diagnostic correlation window, not a copy of the
// complete profile. Eight 32-entry queue windows cover the largest expected
// sequence of imports that can remain unused while keeping the hot-pool
// accounting independent of profile history size.
inline constexpr std::size_t jit_native_preimport_tracker_capacity = 256U;
inline constexpr std::size_t jit_native_preimport_tracker_hash_capacity = 512U;
inline constexpr std::size_t jit_demand_seen_tracker_capacity = 8'192U;
inline constexpr std::size_t jit_demand_seen_tracker_hash_capacity = 16'384U;

// This tracker correlates profile-originated native imports with later
// execution. It is deliberately bounded and host-only. Tombstones preserve
// open-addressing probe chains after consume or range invalidation; a zero
// slot remains the only end-of-chain marker.
class JitNativePreimportTracker {
public:
    JitNativePreimportTracker() noexcept { clear(); }

    void mark(std::uint64_t location_descriptor,
        std::uint64_t lookup_sequence = 0U) noexcept
    {
        if (invalid_descriptor(location_descriptor))
            return;
        SpinLockGuard guard { preimport_lock_ };
        auto slot = hash(location_descriptor) &
                    (jit_native_preimport_tracker_hash_capacity - 1U);
        std::size_t tombstone_slot = no_slot;
        for (std::size_t probe = 0;
            probe < jit_native_preimport_tracker_hash_capacity; ++probe) {
            const auto known = locations_[slot].load(std::memory_order_acquire);
            if (known == location_descriptor)
                return;
            if (known == tombstone) {
                if (tombstone_slot == no_slot)
                    tombstone_slot = slot;
            } else if (known == 0U) {
                break;
            }
            slot = next_slot(slot, jit_native_preimport_tracker_hash_capacity);
        }

        if (ready_count_.load(std::memory_order_acquire) >=
            jit_native_preimport_tracker_capacity) {
            return;
        }
        const auto insertion_slot =
            tombstone_slot == no_slot ? slot : tombstone_slot;
        const auto expected_value = tombstone_slot == no_slot ? 0U : tombstone;
        auto expected = expected_value;
        for (;;) {
            if (locations_[insertion_slot].compare_exchange_weak(expected,
                    location_descriptor, std::memory_order_acq_rel,
                    std::memory_order_acquire)) {
                marked_lookup_sequences_[insertion_slot].store(
                    lookup_sequence, std::memory_order_release);
                ready_count_.fetch_add(1U, std::memory_order_release);
                return;
            }
            // compare_exchange_weak may fail spuriously without changing
            // expected. Retry the same slot instead of skipping a chain link.
            if (expected != expected_value)
                return;
        }
    }

    [[nodiscard]] bool has_ready() const noexcept
    {
        return ready_count_.load(std::memory_order_acquire) != 0U;
    }

    void mark_demand_seen(std::uint64_t location_descriptor) noexcept
    {
        if (invalid_descriptor(location_descriptor))
            return;
        SpinLockGuard guard { demand_lock_ };
        auto slot = hash(location_descriptor) &
                    (jit_demand_seen_tracker_hash_capacity - 1U);
        for (std::size_t probe = 0;
            probe < jit_demand_seen_tracker_hash_capacity; ++probe) {
            auto known =
                demand_locations_[slot].load(std::memory_order_acquire);
            if (known == location_descriptor)
                return;
            if (known == 0U) {
                for (;;) {
                    if (demand_locations_[slot].compare_exchange_weak(known,
                            location_descriptor, std::memory_order_acq_rel,
                            std::memory_order_acquire)) {
                        demand_seen_count_.fetch_add(
                            1U, std::memory_order_release);
                        return;
                    }
                    // Retry a spurious weak-CAS failure at this slot. A
                    // genuine change is impossible while demand_lock_ is
                    // held, but is handled conservatively by continuing the
                    // probe if one is observed.
                    if (known != 0U)
                        break;
                }
            }
            slot = next_slot(slot, jit_demand_seen_tracker_hash_capacity);
        }
    }

    [[nodiscard]] bool demand_seen(
        std::uint64_t location_descriptor) const noexcept
    {
        if (invalid_descriptor(location_descriptor))
            return false;
        SpinLockGuard guard { demand_lock_ };
        auto slot = hash(location_descriptor) &
                    (jit_demand_seen_tracker_hash_capacity - 1U);
        for (std::size_t probe = 0;
            probe < jit_demand_seen_tracker_hash_capacity; ++probe) {
            const auto known =
                demand_locations_[slot].load(std::memory_order_acquire);
            if (known == 0U)
                return false;
            if (known == location_descriptor)
                return true;
            slot = next_slot(slot, jit_demand_seen_tracker_hash_capacity);
        }
        return false;
    }

    [[nodiscard]] bool consume(std::uint64_t location_descriptor,
        std::uint64_t lookup_sequence = 0U,
        std::uint64_t* first_use_distance = nullptr) noexcept
    {
        if (invalid_descriptor(location_descriptor))
            return false;
        SpinLockGuard guard { preimport_lock_ };
        auto slot = hash(location_descriptor) &
                    (jit_native_preimport_tracker_hash_capacity - 1U);
        for (std::size_t probe = 0;
            probe < jit_native_preimport_tracker_hash_capacity; ++probe) {
            const auto known = locations_[slot].load(std::memory_order_acquire);
            if (known == 0U)
                return false;
            if (known == location_descriptor) {
                auto expected = known;
                for (;;) {
                    if (locations_[slot].compare_exchange_weak(expected,
                            tombstone, std::memory_order_acq_rel,
                            std::memory_order_acquire)) {
                        const auto marked_sequence =
                            marked_lookup_sequences_[slot].load(
                                std::memory_order_acquire);
                        if (first_use_distance != nullptr) {
                            *first_use_distance =
                                lookup_sequence >= marked_sequence
                                    ? lookup_sequence - marked_sequence
                                    : 0U;
                        }
                        marked_lookup_sequences_[slot].store(
                            0U, std::memory_order_release);
                        decrement_ready();
                        return true;
                    }
                    // Do not advance on a spurious weak-CAS failure.
                    if (expected != known)
                        return false;
                }
            }
            slot = next_slot(slot, jit_native_preimport_tracker_hash_capacity);
        }
        return false;
    }

    void clear() noexcept
    {
        SpinLockGuard preimport_guard { preimport_lock_ };
        for (std::size_t index = 0; index < locations_.size(); ++index) {
            auto& location = locations_[index];
            location.store(0U, std::memory_order_release);
        }
        for (auto& sequence : marked_lookup_sequences_) {
            sequence.store(0U, std::memory_order_release);
        }
        ready_count_.store(0U, std::memory_order_release);
        SpinLockGuard demand_guard { demand_lock_ };
        clear_demand_locations_locked();
    }

    void clear_demand_locations() noexcept
    {
        SpinLockGuard guard { demand_lock_ };
        clear_demand_locations_locked();
    }

    void invalidate_range(std::uint32_t address, std::size_t length) noexcept
    {
        if (length == 0U)
            return;
        const auto lower = static_cast<std::uint64_t>(address);
        constexpr auto guest_address_limit = std::uint64_t { 1 } << 32U;
        const auto requested_length = static_cast<std::uint64_t>(length);
        const auto upper = requested_length > guest_address_limit - lower
                               ? guest_address_limit
                               : lower + requested_length;
        if (lower >= upper)
            return;

        SpinLockGuard guard { preimport_lock_ };
        for (std::size_t index = 0; index < locations_.size(); ++index) {
            auto& location = locations_[index];
            const auto known = location.load(std::memory_order_acquire);
            if (known == 0U || known == tombstone)
                continue;
            const auto pc = static_cast<std::uint32_t>(known);
            if (static_cast<std::uint64_t>(pc) < lower ||
                static_cast<std::uint64_t>(pc) >= upper) {
                continue;
            }
            auto expected = known;
            for (;;) {
                if (location.compare_exchange_weak(expected, tombstone,
                        std::memory_order_acq_rel, std::memory_order_acquire)) {
                    decrement_ready();
                    marked_lookup_sequences_[index].store(
                        0U, std::memory_order_release);
                    break;
                }
                // A weak CAS can fail spuriously. Retry the same location;
                // only a genuine value change ends this deletion attempt.
                if (expected != known)
                    break;
            }
        }
    }

private:
    static constexpr auto tombstone = std::numeric_limits<std::uint64_t>::max();
    static constexpr std::size_t no_slot =
        std::numeric_limits<std::size_t>::max();

    class SpinLockGuard {
    public:
        explicit SpinLockGuard(std::atomic_flag& lock) noexcept
            : lock_ { lock }
        {
            while (lock_.test_and_set(std::memory_order_acquire)) { }
        }
        ~SpinLockGuard() { lock_.clear(std::memory_order_release); }

        SpinLockGuard(const SpinLockGuard&) = delete;
        SpinLockGuard& operator=(const SpinLockGuard&) = delete;

    private:
        std::atomic_flag& lock_;
    };

    [[nodiscard]] static constexpr bool invalid_descriptor(
        std::uint64_t location_descriptor) noexcept
    {
        return location_descriptor == 0U || location_descriptor == tombstone;
    }

    [[nodiscard]] static constexpr std::size_t next_slot(
        std::size_t slot, std::size_t capacity) noexcept
    {
        return (slot + 1U) & (capacity - 1U);
    }

    [[nodiscard]] static std::size_t hash(
        std::uint64_t location_descriptor) noexcept
    {
        auto value = location_descriptor;
        value ^= value >> 30U;
        value *= 0xbf58476d1ce4e5b9ULL;
        value ^= value >> 27U;
        value *= 0x94d049bb133111ebULL;
        value ^= value >> 31U;
        return static_cast<std::size_t>(value);
    }

    void decrement_ready() noexcept
    {
        const auto current = ready_count_.load(std::memory_order_relaxed);
        if (current != 0U)
            ready_count_.store(current - 1U, std::memory_order_release);
    }

    void clear_demand_locations_locked() noexcept
    {
        for (auto& location : demand_locations_) {
            location.store(0U, std::memory_order_release);
        }
        demand_seen_count_.store(0U, std::memory_order_release);
    }

    std::array<std::atomic<std::uint64_t>,
        jit_native_preimport_tracker_hash_capacity>
        locations_ { };
    std::array<std::atomic<std::uint64_t>,
        jit_native_preimport_tracker_hash_capacity>
        marked_lookup_sequences_ { };
    std::atomic<std::uint64_t> ready_count_ { };
    std::array<std::atomic<std::uint64_t>,
        jit_demand_seen_tracker_hash_capacity>
        demand_locations_ { };
    std::atomic<std::uint64_t> demand_seen_count_ { };
    mutable std::atomic_flag preimport_lock_ = ATOMIC_FLAG_INIT;
    mutable std::atomic_flag demand_lock_ = ATOMIC_FLAG_INIT;
};

inline constexpr std::size_t jit_native_preimport_tracker_object_bytes =
    sizeof(JitNativePreimportTracker);

} // namespace shade
