// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Maintain pthread synchronization queues and sequence-number
// ordering.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-1699.22.73/bsd/kern/pthread_support.c

#include "kernel/darwin_psynch_runtime.hpp"

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <utility>

namespace shade {
namespace {

    constexpr std::uint32_t kernel_bit = 0x01U;
    constexpr std::uint32_t exclusive_bit = 0x02U;
    constexpr std::uint32_t write_waiter_bit = 0x04U;
    constexpr std::uint32_t sequence_save_mask = 0x1cU;
    constexpr std::uint32_t overlap_bit = 0x40U;
    constexpr std::uint32_t initial_bit = 0x80U;
    constexpr std::uint32_t condition_prepost_bit = 0x02U;
    constexpr std::uint32_t mutex_prepost_bit = 0x04U;
    constexpr std::uint32_t first_fit_policy = 0x80U;

    void append_wakeups(std::vector<DarwinPsynchThread>& destination,
        std::vector<DarwinPsynchThread> source)
    {
        destination.insert(destination.end(), source.begin(), source.end());
    }

} // namespace

DarwinPsynchRuntime::QueueKey DarwinPsynchRuntime::queue_key(
    std::uint32_t process_id, std::uint32_t address, std::uint32_t flags,
    QueueFamily family)
{
    const auto shared = (flags & process_shared_flag) != 0U;
    return { shared, shared ? 0U : process_id, address, family };
}

bool DarwinPsynchRuntime::sequence_not_after(
    std::uint32_t sequence, std::uint32_t upper_bound)
{
    constexpr std::uint32_t half_generation_space = 1U << 23U;
    const auto distance =
        ((upper_bound - sequence) & generation_mask) >> 8U;
    return distance < half_generation_space;
}

void DarwinPsynchRuntime::complete_wait_locked(const Waiter& waiter,
    std::uint32_t result,
    std::vector<DarwinPsynchThread>& woken_threads)
{
    completed_results_.insert_or_assign(waiter.thread, result);
    woken_threads.push_back(waiter.thread);
}

void DarwinPsynchRuntime::prune_queue_locked(const QueueKey& key)
{
    const auto found = queues_.find(key);
    if (found != queues_.end() && found->second.waiters.empty() &&
        found->second.preposts.empty() && !found->second.rw) {
        queues_.erase(found);
    }
}

DarwinPsynchRuntime::WaitOutcome DarwinPsynchRuntime::wait_mutex(
    DarwinPsynchThread thread, std::uint32_t address,
    std::uint32_t lock_generation, std::uint32_t unlock_generation,
    std::uint32_t flags)
{
    static_cast<void>(unlock_generation);
    std::lock_guard lock { mutex_ };
    const auto key = queue_key(
        thread.process_id, address, flags, QueueFamily::Mutex);
    auto& queue = queues_[key];
    const auto sequence = lock_generation & generation_mask;
    const auto first_fit = (flags & first_fit_policy) != 0U;
    const auto prepost = std::find_if(queue.preposts.begin(),
        queue.preposts.end(), [&](const auto& candidate) {
            return candidate.kind == DarwinPsynchWaitKind::Mutex &&
                   (first_fit || candidate.sequence == sequence);
        });
    if (prepost != queue.preposts.end()) {
        if (--prepost->count == 0U)
            queue.preposts.erase(prepost);
        const auto result = sequence | kernel_bit | exclusive_bit;
        prune_queue_locked(key);
        return { false, result, { } };
    }

    queue.waiters.push_back(
        Waiter { thread, sequence, DarwinPsynchWaitKind::Mutex });
    return { true, 0, { } };
}

DarwinPsynchRuntime::WakeOutcome DarwinPsynchRuntime::drop_mutex_locked(
    std::uint32_t process_id, std::uint32_t address,
    std::uint32_t lock_generation, std::uint32_t unlock_generation,
    std::uint32_t flags)
{
    const auto key =
        queue_key(process_id, address, flags, QueueFamily::Mutex);
    auto& queue = queues_[key];
    WakeOutcome outcome;
    const auto next_sequence =
        (unlock_generation + generation_increment) & generation_mask;
    const auto first_fit = (flags & first_fit_policy) != 0U;
    auto waiter = first_fit
                      ? queue.waiters.begin()
                      : std::find_if(queue.waiters.begin(),
                            queue.waiters.end(), [&](const auto& candidate) {
                                return candidate.kind ==
                                           DarwinPsynchWaitKind::Mutex &&
                                       candidate.sequence == next_sequence;
                            });
    if (waiter == queue.waiters.end() && !queue.waiters.empty()) {
        // The guest sequence can advance past an interrupted waiter. XNU
        // redrives that case by sequence; selecting the oldest remaining
        // waiter preserves progress without granting more than one mutex.
        waiter = queue.waiters.begin();
    }
    if (waiter != queue.waiters.end()) {
        const auto highest_sequence = std::max_element(queue.waiters.begin(),
            queue.waiters.end(), [](const auto& left, const auto& right) {
                return left.sequence < right.sequence;
            })->sequence;
        complete_wait_locked(*waiter,
            highest_sequence | kernel_bit | exclusive_bit,
            outcome.woken_threads);
        queue.waiters.erase(waiter);
    } else {
        queue.preposts.push_back(Prepost { next_sequence, 1,
            DarwinPsynchWaitKind::Mutex });
        if (first_fit) {
            outcome.result =
                (lock_generation & generation_mask) | mutex_prepost_bit;
        }
    }
    prune_queue_locked(key);
    return outcome;
}

DarwinPsynchRuntime::WakeOutcome DarwinPsynchRuntime::drop_mutex(
    std::uint32_t process_id, std::uint32_t address,
    std::uint32_t lock_generation, std::uint32_t unlock_generation,
    std::uint32_t flags)
{
    std::lock_guard lock { mutex_ };
    return drop_mutex_locked(process_id, address, lock_generation,
        unlock_generation, flags);
}

DarwinPsynchRuntime::WaitOutcome DarwinPsynchRuntime::wait_condition(
    DarwinPsynchThread thread, std::uint32_t address,
    std::uint64_t lock_and_signal_generation,
    std::uint32_t unlock_generation, std::optional<MutexDrop> mutex_drop,
    std::uint32_t flags)
{
    std::lock_guard lock { mutex_ };
    WaitOutcome outcome;
    if (mutex_drop) {
        auto dropped = drop_mutex_locked(thread.process_id,
            mutex_drop->address, mutex_drop->lock_generation,
            mutex_drop->unlock_generation, flags);
        append_wakeups(outcome.woken_threads,
            std::move(dropped.woken_threads));
    }

    const auto key = queue_key(
        thread.process_id, address, flags, QueueFamily::Condition);
    auto& queue = queues_[key];
    const auto lock_sequence =
        static_cast<std::uint32_t>(lock_and_signal_generation) &
        generation_mask;
    const auto prepost = std::find_if(queue.preposts.begin(),
        queue.preposts.end(), [&](const auto& candidate) {
            return candidate.kind == DarwinPsynchWaitKind::Condition &&
                   sequence_not_after(lock_sequence, candidate.sequence);
        });
    if (prepost != queue.preposts.end()) {
        if (--prepost->count == 0U)
            queue.preposts.erase(prepost);
        outcome.result = generation_increment;
        prune_queue_locked(key);
        return outcome;
    }

    static_cast<void>(unlock_generation);
    queue.waiters.push_back(Waiter { thread, lock_sequence,
        DarwinPsynchWaitKind::Condition });
    outcome.blocked = true;
    return outcome;
}

DarwinPsynchRuntime::WakeOutcome DarwinPsynchRuntime::signal_condition(
    std::uint32_t process_id, std::uint32_t address,
    std::uint64_t lock_and_signal_generation,
    std::uint32_t unlock_generation, std::uint32_t flags,
    std::optional<DarwinPsynchThread> target)
{
    std::lock_guard lock { mutex_ };
    const auto key =
        queue_key(process_id, address, flags, QueueFamily::Condition);
    auto& queue = queues_[key];
    WakeOutcome outcome;
    const auto upper_sequence =
        static_cast<std::uint32_t>(lock_and_signal_generation) &
        generation_mask;
    const auto signal_sequence =
        (unlock_generation + generation_increment) & generation_mask;
    auto waiter = std::find_if(queue.waiters.begin(), queue.waiters.end(),
        [&](const auto& candidate) {
            return candidate.kind == DarwinPsynchWaitKind::Condition &&
                   (!target || candidate.thread == *target) &&
                   sequence_not_after(candidate.sequence, upper_sequence) &&
                   sequence_not_after(signal_sequence, candidate.sequence);
        });
    if (waiter == queue.waiters.end() && target) {
        // Darwin converts a failed directed signal into a bounded broadcast to
        // avoid starving a waiter whose thread port raced its queue insertion.
        waiter = std::find_if(queue.waiters.begin(), queue.waiters.end(),
            [&](const auto& candidate) {
                return candidate.kind == DarwinPsynchWaitKind::Condition &&
                       sequence_not_after(
                           candidate.sequence, upper_sequence);
            });
    }
    if (waiter != queue.waiters.end()) {
        complete_wait_locked(*waiter, 0, outcome.woken_threads);
        queue.waiters.erase(waiter);
        outcome.result = generation_increment;
    } else {
        auto prepost = std::find_if(queue.preposts.begin(),
            queue.preposts.end(), [&](const auto& candidate) {
                return candidate.kind == DarwinPsynchWaitKind::Condition &&
                       candidate.sequence == upper_sequence;
            });
        if (prepost == queue.preposts.end()) {
            queue.preposts.push_back(Prepost { upper_sequence, 1,
                DarwinPsynchWaitKind::Condition });
        } else if (prepost->count < std::numeric_limits<std::uint32_t>::max()) {
            ++prepost->count;
        }
        outcome.result = condition_prepost_bit;
    }
    prune_queue_locked(key);
    return outcome;
}

DarwinPsynchRuntime::WakeOutcome DarwinPsynchRuntime::broadcast_condition(
    std::uint32_t process_id, std::uint32_t address,
    std::uint64_t lock_and_signal_generation,
    std::uint64_t unlock_and_count_generation, std::uint32_t flags)
{
    std::lock_guard lock { mutex_ };
    const auto key =
        queue_key(process_id, address, flags, QueueFamily::Condition);
    auto& queue = queues_[key];
    WakeOutcome outcome;
    const auto upper_sequence =
        static_cast<std::uint32_t>(lock_and_signal_generation) &
        generation_mask;
    for (auto waiter = queue.waiters.begin(); waiter != queue.waiters.end();) {
        if (waiter->kind != DarwinPsynchWaitKind::Condition ||
            !sequence_not_after(waiter->sequence, upper_sequence)) {
            ++waiter;
            continue;
        }
        complete_wait_locked(*waiter, 0, outcome.woken_threads);
        waiter = queue.waiters.erase(waiter);
        outcome.result += generation_increment;
    }
    if (outcome.woken_threads.empty()) {
        auto count = static_cast<std::uint32_t>(unlock_and_count_generation) &
                     generation_mask;
        count >>= 8U;
        if (count == 0U)
            count = 1U;
        queue.preposts.push_back(Prepost { upper_sequence, count,
            DarwinPsynchWaitKind::Condition });
        outcome.result = condition_prepost_bit;
    }
    prune_queue_locked(key);
    return outcome;
}

void DarwinPsynchRuntime::clear_preposts(std::uint32_t process_id,
    std::uint32_t address, std::uint32_t flags, bool mutex_object)
{
    std::lock_guard lock { mutex_ };
    const auto key = queue_key(process_id, address, flags,
        mutex_object ? QueueFamily::Mutex : QueueFamily::Condition);
    if (auto queue = queues_.find(key); queue != queues_.end()) {
        queue->second.preposts.clear();
    }
    prune_queue_locked(key);
}

DarwinPsynchRuntime::WaitOutcome DarwinPsynchRuntime::wait_rwlock(
    DarwinPsynchThread thread, std::uint32_t address,
    std::uint32_t lock_generation, std::uint32_t unlock_generation,
    std::uint32_t sequence_word, std::uint32_t flags,
    DarwinPsynchWaitKind kind)
{
    static_cast<void>(unlock_generation);
    std::lock_guard lock { mutex_ };
    const auto key =
        queue_key(thread.process_id, address, flags, QueueFamily::RwLock);
    auto& queue = queues_[key];
    if ((lock_generation & initial_bit) != 0U || !queue.rw)
        queue.rw = RwState { };
    auto& rw = *queue.rw;
    const auto lock_sequence = lock_generation & generation_mask;

    if (kind == DarwinPsynchWaitKind::ReadLock && rw.overlap_watch &&
        (sequence_word & sequence_save_mask) == 0U &&
        (lock_generation & write_waiter_bit) == 0U) {
        const auto current_sequence = sequence_word & generation_mask;
        const auto high_sequence =
            rw.next_sequence_word & generation_mask;
        const auto low_sequence = rw.last_sequence_word & generation_mask;
        const auto within_grant =
            sequence_not_after(current_sequence, high_sequence) ||
            sequence_not_after(current_sequence, low_sequence);
        if (within_grant) {
            rw.next_sequence_word += generation_increment;
            const auto result = generation_increment |
                                (rw.next_sequence_word & ~generation_mask) |
                                overlap_bit;
            return { false, result, { } };
        }
    }

    insert_rw_waiter_locked(
        queue, Waiter { thread, lock_sequence, kind });
    if (rw.prepost_count == 0U ||
        !sequence_not_after(lock_sequence, rw.prepost_lock_sequence)) {
        return { true, 0, { } };
    }

    --rw.prepost_count;
    if (rw.prepost_count != 0U)
        return { true, 0, { } };

    const auto prepost_sequence_word = rw.prepost_sequence_word;
    rw.prepost_lock_sequence = 0U;
    rw.prepost_sequence_word = 0x01U;
    auto granted = grant_rwlock_locked(queue, prepost_sequence_word);
    if (const auto result = completed_results_.find(thread);
        result != completed_results_.end()) {
        const auto value = result->second;
        completed_results_.erase(result);
        std::erase(granted.woken_threads, thread);
        return { false, value, std::move(granted.woken_threads) };
    }
    return { true, 0, std::move(granted.woken_threads) };
}

DarwinPsynchRuntime::WakeOutcome DarwinPsynchRuntime::unlock_rwlock(
    std::uint32_t process_id, std::uint32_t address,
    std::uint32_t lock_generation, std::uint32_t unlock_generation,
    std::uint32_t sequence_word, std::uint32_t flags)
{
    std::lock_guard lock { mutex_ };
    const auto key =
        queue_key(process_id, address, flags, QueueFamily::RwLock);
    auto& queue = queues_[key];
    if ((lock_generation & initial_bit) != 0U || !queue.rw)
        queue.rw = RwState { };
    auto& rw = *queue.rw;
    const auto lock_sequence = lock_generation & generation_mask;
    const auto unlock_sequence = unlock_generation & generation_mask;

    if (rw.has_last_unlock &&
        !sequence_not_after(rw.last_unlock_sequence, unlock_sequence)) {
        return { };
    }

    const auto generation_count = [](std::uint32_t upper,
                                      std::uint32_t lower) {
        return ((upper - lower) & generation_mask) >> 8U;
    };
    const auto expected_waiters =
        generation_count(lock_sequence, unlock_sequence);
    const auto queued_waiters = static_cast<std::uint32_t>(std::ranges::count_if(
        queue.waiters, [&](const auto& waiter) {
            return sequence_not_after(waiter.sequence, lock_sequence);
        }));
    if (queued_waiters < expected_waiters) {
        rw.prepost_count = expected_waiters - queued_waiters;
        rw.prepost_lock_sequence = lock_sequence;
        rw.prepost_sequence_word = sequence_word;
        return { lock_generation, { } };
    }

    rw.prepost_count = 0U;
    rw.prepost_lock_sequence = 0U;
    rw.prepost_sequence_word = 0x01U;
    return grant_rwlock_locked(queue, sequence_word);
}

void DarwinPsynchRuntime::insert_rw_waiter_locked(
    QueueState& queue, Waiter waiter)
{
    const auto position = std::find_if(queue.waiters.begin(),
        queue.waiters.end(), [&](const auto& candidate) {
            return waiter.sequence != candidate.sequence &&
                   sequence_not_after(waiter.sequence, candidate.sequence);
        });
    queue.waiters.insert(position, std::move(waiter));
}

DarwinPsynchRuntime::WakeOutcome DarwinPsynchRuntime::grant_rwlock_locked(
    QueueState& queue, std::uint32_t sequence_word)
{
    WakeOutcome outcome;
    auto& rw = *queue.rw;
    rw.last_sequence_word = sequence_word;
    rw.last_unlock_sequence = sequence_word & generation_mask;
    rw.has_last_unlock = true;
    rw.overlap_watch = false;
    if (queue.waiters.empty()) {
        rw.next_sequence_word = sequence_word;
        return outcome;
    }

    if (queue.waiters.front().kind == DarwinPsynchWaitKind::WriteLock) {
        const auto waiter = queue.waiters.front();
        queue.waiters.pop_front();
        const auto another_writer = std::ranges::any_of(queue.waiters,
            [](const auto& candidate) {
                return candidate.kind == DarwinPsynchWaitKind::WriteLock;
            });
        const auto result = generation_increment | kernel_bit | exclusive_bit |
                            (another_writer ? write_waiter_bit : 0U);
        rw.next_sequence_word =
            (sequence_word & generation_mask) + result;
        complete_wait_locked(waiter, result, outcome.woken_threads);
        return outcome;
    }

    std::vector<Waiter> granted;
    std::uint32_t generation_delta = 0U;
    while (!queue.waiters.empty() &&
           queue.waiters.front().kind == DarwinPsynchWaitKind::ReadLock) {
        granted.push_back(queue.waiters.front());
        queue.waiters.pop_front();
        generation_delta += generation_increment;
    }
    const auto writer_pending = std::ranges::any_of(queue.waiters,
        [](const auto& candidate) {
            return candidate.kind == DarwinPsynchWaitKind::WriteLock;
        });
    const auto result = generation_delta |
                        (writer_pending ? kernel_bit | write_waiter_bit : 0U);
    rw.next_sequence_word = (sequence_word & generation_mask) + result;
    rw.overlap_watch = !writer_pending;
    for (const auto& waiter : granted)
        complete_wait_locked(waiter, result, outcome.woken_threads);
    return outcome;
}

std::optional<std::uint32_t> DarwinPsynchRuntime::take_result(
    DarwinPsynchThread thread)
{
    std::lock_guard lock { mutex_ };
    const auto found = completed_results_.find(thread);
    if (found == completed_results_.end())
        return std::nullopt;
    const auto result = found->second;
    completed_results_.erase(found);
    return result;
}

void DarwinPsynchRuntime::cancel_wait(DarwinPsynchThread thread)
{
    std::lock_guard lock { mutex_ };
    completed_results_.erase(thread);
    for (auto queue = queues_.begin(); queue != queues_.end();) {
        std::erase_if(queue->second.waiters,
            [&](const auto& waiter) { return waiter.thread == thread; });
        if (queue->second.waiters.empty() && queue->second.preposts.empty())
            queue = queues_.erase(queue);
        else
            ++queue;
    }
}

void DarwinPsynchRuntime::clear_process(std::uint32_t process_id)
{
    std::lock_guard lock { mutex_ };
    std::erase_if(completed_results_, [&](const auto& entry) {
        return entry.first.process_id == process_id;
    });
    for (auto queue = queues_.begin(); queue != queues_.end();) {
        std::erase_if(queue->second.waiters, [&](const auto& waiter) {
            return waiter.thread.process_id == process_id;
        });
        const auto private_process_queue = !queue->first.process_shared &&
                                           queue->first.process_id == process_id;
        if (private_process_queue ||
            (queue->second.waiters.empty() && queue->second.preposts.empty())) {
            queue = queues_.erase(queue);
        } else {
            ++queue;
        }
    }
}

} // namespace shade
