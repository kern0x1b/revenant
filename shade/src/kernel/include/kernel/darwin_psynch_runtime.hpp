// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Manage guest pthread synchronization queues and sequence-number
// state.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-1699.22.73/bsd/kern/pthread_support.c

#pragma once

#include <compare>
#include <cstdint>
#include <deque>
#include <map>
#include <mutex>
#include <optional>
#include <vector>

namespace shade {

struct DarwinPsynchThread {
    std::uint32_t process_id { };
    std::uint32_t processor { };

    auto operator<=>(const DarwinPsynchThread&) const = default;
};

enum class DarwinPsynchWaitKind : std::uint8_t {
    Mutex,
    Condition,
    ReadLock,
    WriteLock,
};

// Shared kernel-side state for Darwin's generation-counted pthread waits.
// Guest libpthread owns the uncontended fast paths and sequence words; this
// object retains only wait queues, missed-wakeup preposts, and completed wait
// results.  It is shared by task kernels so process-shared pthread objects can
// use the same wakeup path as process-private objects.
class DarwinPsynchRuntime {
public:
    static constexpr std::uint32_t generation_increment = 0x100U;
    static constexpr std::uint32_t generation_mask = 0xffff'ff00U;
    static constexpr std::uint32_t process_shared_flag = 0x10U;

    struct MutexDrop {
        std::uint32_t address { };
        std::uint32_t lock_generation { };
        std::uint32_t unlock_generation { };
    };

    struct WaitOutcome {
        bool blocked { };
        std::uint32_t result { };
        std::vector<DarwinPsynchThread> woken_threads;
    };

    struct WakeOutcome {
        std::uint32_t result { };
        std::vector<DarwinPsynchThread> woken_threads;
    };

    [[nodiscard]] WaitOutcome wait_mutex(DarwinPsynchThread thread,
        std::uint32_t address, std::uint32_t lock_generation,
        std::uint32_t unlock_generation, std::uint32_t flags);
    [[nodiscard]] WakeOutcome drop_mutex(std::uint32_t process_id,
        std::uint32_t address, std::uint32_t lock_generation,
        std::uint32_t unlock_generation, std::uint32_t flags);

    [[nodiscard]] WaitOutcome wait_condition(DarwinPsynchThread thread,
        std::uint32_t address, std::uint64_t lock_and_signal_generation,
        std::uint32_t unlock_generation,
        std::optional<MutexDrop> mutex_drop, std::uint32_t flags);
    [[nodiscard]] WakeOutcome signal_condition(std::uint32_t process_id,
        std::uint32_t address, std::uint64_t lock_and_signal_generation,
        std::uint32_t unlock_generation, std::uint32_t flags,
        std::optional<DarwinPsynchThread> target = std::nullopt);
    [[nodiscard]] WakeOutcome broadcast_condition(std::uint32_t process_id,
        std::uint32_t address, std::uint64_t lock_and_signal_generation,
        std::uint64_t unlock_and_count_generation, std::uint32_t flags);
    void clear_preposts(std::uint32_t process_id, std::uint32_t address,
        std::uint32_t flags, bool mutex_object);

    [[nodiscard]] WaitOutcome wait_rwlock(DarwinPsynchThread thread,
        std::uint32_t address, std::uint32_t lock_generation,
        std::uint32_t unlock_generation, std::uint32_t sequence_word,
        std::uint32_t flags, DarwinPsynchWaitKind kind);
    [[nodiscard]] WakeOutcome unlock_rwlock(std::uint32_t process_id,
        std::uint32_t address, std::uint32_t lock_generation,
        std::uint32_t unlock_generation, std::uint32_t sequence_word,
        std::uint32_t flags);

    [[nodiscard]] std::optional<std::uint32_t> take_result(
        DarwinPsynchThread thread);
    void cancel_wait(DarwinPsynchThread thread);
    void clear_process(std::uint32_t process_id);

private:
    enum class QueueFamily : std::uint8_t { Mutex, Condition, RwLock };

    struct QueueKey {
        bool process_shared { };
        std::uint32_t process_id { };
        std::uint32_t address { };
        QueueFamily family { QueueFamily::Mutex };

        auto operator<=>(const QueueKey&) const = default;
    };

    struct Waiter {
        DarwinPsynchThread thread;
        std::uint32_t sequence { };
        DarwinPsynchWaitKind kind { DarwinPsynchWaitKind::Mutex };
    };

    struct Prepost {
        std::uint32_t sequence { };
        std::uint32_t count { };
        DarwinPsynchWaitKind kind { DarwinPsynchWaitKind::Condition };
    };

    struct RwState {
        std::uint32_t next_sequence_word { 0x01U };
        std::uint32_t last_sequence_word { 0x01U };
        std::uint32_t last_unlock_sequence { };
        std::uint32_t prepost_count { };
        std::uint32_t prepost_lock_sequence { };
        std::uint32_t prepost_sequence_word { 0x01U };
        bool has_last_unlock { };
        bool overlap_watch { };
    };

    struct QueueState {
        std::deque<Waiter> waiters;
        std::deque<Prepost> preposts;
        std::optional<RwState> rw;
    };

    [[nodiscard]] static QueueKey queue_key(std::uint32_t process_id,
        std::uint32_t address, std::uint32_t flags, QueueFamily family);
    [[nodiscard]] static bool sequence_not_after(
        std::uint32_t sequence, std::uint32_t upper_bound);
    [[nodiscard]] WakeOutcome drop_mutex_locked(std::uint32_t process_id,
        std::uint32_t address, std::uint32_t lock_generation,
        std::uint32_t unlock_generation, std::uint32_t flags);
    void insert_rw_waiter_locked(QueueState& queue, Waiter waiter);
    [[nodiscard]] WakeOutcome grant_rwlock_locked(
        QueueState& queue, std::uint32_t sequence_word);
    void complete_wait_locked(const Waiter& waiter, std::uint32_t result,
        std::vector<DarwinPsynchThread>& woken_threads);
    void prune_queue_locked(const QueueKey& key);

    std::mutex mutex_;
    std::map<QueueKey, QueueState> queues_;
    std::map<DarwinPsynchThread, std::uint32_t> completed_results_;
};

} // namespace shade
