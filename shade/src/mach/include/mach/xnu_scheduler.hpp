// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Model guest thread run queues, priorities, time slices, realtime
// policy and preemption.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/kern/sched.h
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/kern/sched_prim.c
// https://github.com/apple-oss-distributions/xnu/blob/xnu-792.24.17/osfmk/kern/priority.c

#pragma once

#include <array>
#include <chrono>
#include <compare>
#include <cstddef>
#include <cstdint>
#include <functional>
#include <list>
#include <optional>
#include <set>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace shade {

// Constants and ordering are taken from XNU osfmk/kern/sched.h
// and sched_prim.c. These defaults serve CPU-only helpers and unit tests. A
// full boot derives its tick rate from the selected device instruction-timing
// model instead of assuming that the CPU clock equals the system bus clock.
namespace xnu::scheduler {

    constexpr std::size_t run_queue_count = 128;
    constexpr std::int32_t minimum_priority = 0;
    constexpr std::int32_t maximum_priority = 127;
    constexpr std::int32_t realtime_base_priority = 96;
    constexpr std::int32_t realtime_queue_priority = realtime_base_priority + 1;
    constexpr std::int32_t maximum_kernel_priority = 95;
    constexpr std::int32_t preempt_priority = maximum_kernel_priority - 2;
    constexpr std::int32_t maximum_user_priority = 63;
    constexpr std::int32_t default_base_priority = 31;
    constexpr std::uint64_t default_guest_ticks_per_second = 400'000'000;
    constexpr std::uint64_t default_preemption_rate = 100;
    constexpr std::uint64_t scheduler_ticks_per_second = 8;
    constexpr std::uint64_t scheduling_usage_decay_ticks = 32;
    constexpr std::uint64_t maximum_unsafe_quanta = 800;
    constexpr std::uint64_t scheduler_tick_shift = 3;
    constexpr std::uint64_t failsafe_release_scheduler_ticks =
        (2 * maximum_unsafe_quanta / default_preemption_rate) *
        (std::uint64_t { 1 } << scheduler_tick_shift);
    constexpr std::uint64_t milliseconds_per_second = 1'000;
    constexpr std::uint64_t standard_quantum_ticks =
        default_guest_ticks_per_second / default_preemption_rate;
    constexpr std::uint64_t scheduler_tick_interval =
        default_guest_ticks_per_second / scheduler_ticks_per_second;
    constexpr std::uint64_t microseconds_per_second = 1'000'000;
    constexpr std::uint64_t minimum_realtime_computation_ticks =
        default_guest_ticks_per_second * 50 / microseconds_per_second;
    constexpr std::uint64_t maximum_realtime_computation_ticks =
        default_guest_ticks_per_second * 50'000 / microseconds_per_second;

} // namespace xnu::scheduler

struct XnuThreadId {
    std::uint32_t process { };
    std::uint32_t thread { };

    auto operator<=>(const XnuThreadId&) const = default;
};

struct XnuThreadWakeResult {
    bool handled { };
    bool preemption_needed { };

    constexpr explicit operator bool() const noexcept { return handled; }
};

struct XnuThreadIdHash {
    [[nodiscard]] std::size_t operator()(XnuThreadId thread) const noexcept
    {
        const auto value = (static_cast<std::uint64_t>(thread.process) << 32U) |
                           static_cast<std::uint64_t>(thread.thread);
        return std::hash<std::uint64_t> { }(value);
    }
};

enum class XnuThreadState : std::uint8_t {
    Runnable,
    Running,
    Waiting,
};

enum class XnuSliceCompletion : std::uint8_t {
    Continue,
    HostCooperate,
    Yield,
    Block,
    Terminate,
};

enum class XnuTimeAccounting : std::uint8_t {
    Advance,
    Deferred,
};

enum class XnuPreemption : std::uint8_t {
    None,
    Preempt,
    Urgent,
};

struct XnuScheduledSlice {
    XnuThreadId thread;
    std::size_t processor { };
    std::uint64_t tick_budget { };
    std::chrono::steady_clock::time_point runnable_since;
    std::uint64_t runnable_generation { };
    bool front_continuation { };
};

struct XnuThreadSchedulingInfo {
    XnuThreadState state { XnuThreadState::Waiting };
    std::int32_t base_priority { xnu::scheduler::default_base_priority };
    std::int32_t scheduled_priority {
        xnu::scheduler::default_base_priority
    };
    std::uint64_t remaining_quantum {
        xnu::scheduler::standard_quantum_ticks
    };
    std::uint64_t scheduling_usage { };
    std::uint64_t cpu_usage { };
    std::uint64_t scheduler_stamp { };
    std::optional<std::size_t> bound_processor;
    std::optional<std::size_t> last_processor;
    std::uint64_t realtime_period { };
    std::uint64_t realtime_computation { };
    std::uint64_t realtime_constraint { };
    std::uint64_t realtime_deadline { };
    std::uint64_t computation_metered { };
    std::uint64_t failsafe_release_tick { };
    std::uint32_t remaining_timeslices { };
    std::optional<std::size_t> timeslice_processor;
    bool timeshare { true };
    bool realtime { };
    bool realtime_preemptible { };
    bool failsafe { };
    bool depressed { };
};

// A deterministic implementation of XNU's traditional processor-set run
// queue. It preserves FIFO order at each of the 128 priorities. A thread keeps
// the head position while its first timeslice remains; equal-priority threads
// rotate only when that quantum expires, matching csw_needed().
class XnuScheduler {
public:
    explicit XnuScheduler(
        std::uint64_t quantum_ticks = xnu::scheduler::standard_quantum_ticks,
        std::uint64_t scheduler_tick_ticks =
            xnu::scheduler::scheduler_tick_interval,
        std::size_t processor_count = 1);

    void set_dispatch_diagnostics(bool enabled);

    bool register_thread(XnuThreadId thread,
        std::int32_t base_priority = xnu::scheduler::default_base_priority,
        bool runnable = true);
    bool remove_thread(XnuThreadId thread);
    std::size_t remove_process(std::uint32_t process);

    bool make_runnable(XnuThreadId thread);
    // Process-level pid_suspend/pid_resume operate on every thread in the
    // task while retaining each thread's independent suspend count.
    std::size_t suspend_process(std::uint32_t process);
    std::size_t resume_process(std::uint32_t process);
    // Device and IPC completion can race a thread's final blocking SVC. Keep
    // that wake pending until complete_slice observes the Block transition.
    // `handled` reports whether the thread identity/state was valid; the
    // separate preemption bit lets callers coalesce a queued or duplicate
    // wake without treating it as a failed wake.
    XnuThreadWakeResult wake_thread(XnuThreadId thread);
    bool block(XnuThreadId thread);
    bool suspend_thread(XnuThreadId thread);
    bool resume_thread(XnuThreadId thread);
    bool set_base_priority(XnuThreadId thread, std::int32_t priority);
    bool depress(XnuThreadId thread, std::uint64_t duration_ticks = 0);
    bool bind_thread(XnuThreadId thread, std::optional<std::size_t> processor);
    bool set_timeshare(XnuThreadId thread, bool timeshare);
    bool set_realtime(XnuThreadId thread, std::uint64_t period_ticks,
        std::uint64_t computation_ticks, std::uint64_t constraint_ticks,
        bool preemptible);
    // Realtime policy deadlines are defined from mach_absolute_time(), not
    // from the amount of guest execution that has completed. The interactive
    // host loop updates this converted device-clock value before processing
    // wakeups and policy changes; deterministic callers retain the scheduler
    // execution clock until they opt into this source.
    void set_realtime_clock_ticks(std::uint64_t elapsed_ticks);

    [[nodiscard]] std::optional<XnuScheduledSlice> choose_next(
        std::optional<XnuThreadId> preferred = std::nullopt);
    [[nodiscard]] std::optional<XnuScheduledSlice> choose_next(
        std::size_t processor,
        std::optional<XnuThreadId> preferred = std::nullopt);
    [[nodiscard]] XnuPreemption preemption_for(
        XnuThreadId running_thread, std::size_t processor) const;
    // XNU's scheduler policy owns the yield decision. Resolve the physical
    // processor from the running thread instead of confusing it with the
    // emulator's per-process CPU-context slot.
    [[nodiscard]] bool should_yield(XnuThreadId running_thread) const;
    bool complete_slice(XnuThreadId thread, std::uint64_t consumed_ticks,
        XnuSliceCompletion completion,
        XnuTimeAccounting time_accounting = XnuTimeAccounting::Advance);
    void advance_time(std::uint64_t elapsed_ticks);
    // XNU's scheduler tick is a periodic mach_absolute_time event. Interactive
    // execution can advance that device clock beyond instruction accounting
    // while the host services an expensive syscall or translation. Catch the
    // scheduler housekeeping clock up to the same absolute point without
    // synthesizing CPU usage or changing thread quanta.
    void synchronize_time(std::uint64_t elapsed_ticks);

    [[nodiscard]] bool contains(XnuThreadId thread) const;
    [[nodiscard]] std::optional<XnuThreadSchedulingInfo> info(
        XnuThreadId thread) const;
    [[nodiscard]] std::size_t thread_count() const { return threads_.size(); }
    [[nodiscard]] std::size_t processor_count() const
    {
        return processor_run_queues_.size();
    }
    [[nodiscard]] std::size_t runnable_count() const { return runnable_count_; }
    // Host cooperation may use this read-only count to bound one wall-clock
    // scheduling round. It does not alter XNU queue order or policy.
    [[nodiscard]] std::size_t runnable_count_at_or_above_priority(
        std::int32_t priority) const;
    // Process exit can retire a task's host execution pool while unrelated
    // Guest processes remain runnable. Count only this process's Runnable or
    // Running threads so reclamation never depends on global queue activity.
    [[nodiscard]] std::size_t process_runnable_count(
        std::uint32_t process) const;
    // Return the oldest runnable thread for a process without changing any
    // Guest scheduling state.  Interactive display completion uses this only
    // inside a bounded host-side callback lease to let a blocked callback's
    // same-process dependency make progress.
    [[nodiscard]] std::optional<XnuThreadId> oldest_runnable_thread(
        std::uint32_t process,
        std::optional<XnuThreadId> excluded = std::nullopt) const;
    // Host role dispatch uses the process's own XNU ordering: highest
    // scheduled priority first, realtime deadline next, then FIFO age.
    [[nodiscard]] std::optional<XnuThreadId>
    highest_priority_runnable_thread(std::uint32_t process,
        std::optional<XnuThreadId> excluded = std::nullopt) const;
    [[nodiscard]] std::size_t waiting_count() const;
    [[nodiscard]] std::int32_t highest_runnable_priority() const;
    [[nodiscard]] std::uint64_t scheduler_tick() const
    {
        return scheduler_tick_;
    }

private:
    using ReadyQueue = std::list<XnuThreadId>;
    using RealtimeQueueKey = std::pair<std::uint64_t, XnuThreadId>;

    struct RunQueue {
        std::array<ReadyQueue, xnu::scheduler::run_queue_count> queues;
        // Realtime queues are ordered by deadline. The list remains the
        // removal index for all priorities; this side index avoids a linear
        // deadline insertion/search on the scheduler hot path.
        std::set<RealtimeQueueKey> realtime_order;
        std::array<std::uint32_t, xnu::scheduler::run_queue_count / 32>
            bitmap { };
        std::int32_t high_queue { -1 };
        std::size_t count { };
    };

    struct QueueCandidate {
        XnuThreadId thread;
        std::int32_t priority { };
        std::uint64_t realtime_deadline { };
        std::uint64_t enqueue_sequence { };
        bool realtime { };
        bool front_continuation { };
        bool local { };
    };

    struct ThreadRecord {
        XnuThreadSchedulingInfo info;
        bool queued { };
        std::int32_t queued_priority { };
        std::uint64_t enqueue_sequence { };
        std::chrono::steady_clock::time_point enqueued_at;
        std::uint64_t runnable_generation { };
        // A partially used quantum stays at the queue head. Preserve that
        // continuation priority when local and global queues are compared.
        bool front_continuation { };
        std::optional<ReadyQueue::iterator> queue_position;
        std::optional<RealtimeQueueKey> realtime_queue_key;
        std::optional<std::uint32_t> priority_usage_shift;
        std::optional<std::size_t> queued_processor;
        std::optional<std::uint64_t> depression_deadline;
        std::uint32_t suspend_count { };
        bool resume_runnable { };
        bool wake_pending { };
        std::int32_t failsafe_saved_base_priority { };
        bool failsafe_saved_timeshare { };
        bool failsafe_saved_realtime { };
    };

    enum class QueuePosition { Front, Back };

    static std::int32_t clamp_priority(std::int32_t priority);
    static std::uint32_t priority_usage_shift(
        std::uint64_t scheduler_tick_ticks);
    static void begin_runnable_generation(ThreadRecord& record);
    [[nodiscard]] static bool is_runnable_state(XnuThreadState state);
    void transition_state(XnuThreadId thread, ThreadRecord& record,
        XnuThreadState state);
    void enqueue(XnuThreadId thread, QueuePosition position);
    void remove_from_queue(XnuThreadId thread, ThreadRecord& record);
    void index_depression(XnuThreadId thread, const ThreadRecord& record);
    void unindex_depression(XnuThreadId thread, const ThreadRecord& record);
    void index_failsafe(XnuThreadId thread, const ThreadRecord& record);
    void unindex_failsafe(XnuThreadId thread, const ThreadRecord& record);
    void unindex_thread(XnuThreadId thread);
    [[nodiscard]] std::optional<QueueCandidate> candidate_for_queue(
        const RunQueue& run_queue, bool local) const;
    [[nodiscard]] static bool candidate_is_better(
        const QueueCandidate& left, const QueueCandidate& right);
    [[nodiscard]] RunQueue* selected_run_queue(std::size_t processor);
    [[nodiscard]] const RunQueue* selected_run_queue(
        std::size_t processor) const;
    [[nodiscard]] XnuThreadId peek_highest(const RunQueue& run_queue) const;
    [[nodiscard]] std::optional<XnuThreadId> peek_next_for_processor(
        std::size_t processor) const;
    static void refresh_high_queue(RunQueue& run_queue);
    [[nodiscard]] XnuThreadId pop_highest(RunQueue& run_queue);
    void advance_scheduler_time(std::uint64_t consumed_ticks);
    void age_priorities(std::uint64_t elapsed_ticks);
    void expire_depressions();
    void restore_depression(XnuThreadId thread, ThreadRecord& record);
    void recompute_priority(XnuThreadId thread, ThreadRecord& record);
    [[nodiscard]] std::uint64_t quantum_for(const ThreadRecord& record) const;
    [[nodiscard]] std::optional<std::uint32_t>
    processor_set_priority_shift() const;
    void apply_failsafe(XnuThreadId thread, ThreadRecord& record);
    void release_failsafe(XnuThreadId thread, ThreadRecord& record);
    [[nodiscard]] std::uint32_t timeshare_quanta() const;

    RunQueue processor_set_run_queue_;
    std::vector<RunQueue> processor_run_queues_;
    std::unordered_map<XnuThreadId, ThreadRecord, XnuThreadIdHash> threads_;
    std::unordered_map<std::uint32_t,
        std::unordered_set<XnuThreadId, XnuThreadIdHash>>
        process_threads_;
    // Runnable/Running membership is a scheduler state-machine invariant.
    // Keep its per-task projection beside the run queues so host cooperation
    // and JIT policy observations do not rescan every thread on each turn.
    std::unordered_map<std::uint32_t, std::size_t> process_runnable_counts_;
    std::set<std::pair<std::uint64_t, XnuThreadId>> depression_order_;
    std::set<std::pair<std::uint64_t, XnuThreadId>> failsafe_order_;
    std::size_t runnable_count_ { };
    std::size_t waiting_count_ { };
    std::size_t active_timeshare_count_ { };
    std::uint64_t quantum_ticks_ { };
    std::uint64_t scheduler_tick_ticks_ { };
    std::uint32_t priority_usage_shift_ { };
    std::uint64_t elapsed_since_scheduler_tick_ { };
    std::uint64_t elapsed_ticks_ { };
    std::uint64_t realtime_clock_ticks_ { };
    bool external_realtime_clock_ { };
    std::uint64_t scheduler_tick_ { };
    std::uint64_t next_enqueue_sequence_ { };
    bool dispatch_diagnostics_enabled_ { };
};

} // namespace shade
