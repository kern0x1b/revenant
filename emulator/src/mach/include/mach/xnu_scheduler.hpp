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

#include "foundation/snapshot_io.hpp"

namespace emulator {

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

}

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
    std::size_t suspend_process(std::uint32_t process);
    std::size_t resume_process(std::uint32_t process);
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
    void set_realtime_clock_ticks(std::uint64_t elapsed_ticks);

    [[nodiscard]] std::optional<XnuScheduledSlice> choose_next(
        std::optional<XnuThreadId> preferred = std::nullopt);
    [[nodiscard]] std::optional<XnuScheduledSlice> choose_next(
        std::size_t processor,
        std::optional<XnuThreadId> preferred = std::nullopt);
    [[nodiscard]] XnuPreemption preemption_for(
        XnuThreadId running_thread, std::size_t processor) const;
    [[nodiscard]] bool should_yield(XnuThreadId running_thread) const;
    bool complete_slice(XnuThreadId thread, std::uint64_t consumed_ticks,
        XnuSliceCompletion completion,
        XnuTimeAccounting time_accounting = XnuTimeAccounting::Advance);
    void advance_time(std::uint64_t elapsed_ticks);
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
    [[nodiscard]] std::size_t runnable_count_at_or_above_priority(
        std::int32_t priority) const;
    [[nodiscard]] std::size_t process_runnable_count(
        std::uint32_t process) const;
    [[nodiscard]] std::optional<XnuThreadId> oldest_runnable_thread(
        std::uint32_t process,
        std::optional<XnuThreadId> excluded = std::nullopt) const;
    [[nodiscard]] std::optional<XnuThreadId>
    highest_priority_runnable_thread(std::uint32_t process,
        std::optional<XnuThreadId> excluded = std::nullopt) const;
    [[nodiscard]] std::size_t waiting_count() const;
    [[nodiscard]] std::int32_t highest_runnable_priority() const;
    [[nodiscard]] std::uint64_t scheduler_tick() const
    {
        return scheduler_tick_;
    }
    void save(snapshot::Writer& out) const;
    void load(snapshot::Reader& in);

private:
    using ReadyQueue = std::list<XnuThreadId>;
    using RealtimeQueueKey = std::pair<std::uint64_t, XnuThreadId>;

    struct RunQueue {
        std::array<ReadyQueue, xnu::scheduler::run_queue_count> queues;
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
    static void save_thread_record(
        snapshot::Writer& out, const ThreadRecord& record);
    [[nodiscard]] static ThreadRecord load_thread_record(snapshot::Reader& in);
    static void save_run_queue(snapshot::Writer& out, const RunQueue& run_queue);
    void load_run_queue(snapshot::Reader& in,
        std::optional<std::size_t> processor, RunQueue& run_queue);

    RunQueue processor_set_run_queue_;
    std::vector<RunQueue> processor_run_queues_;
    std::unordered_map<XnuThreadId, ThreadRecord, XnuThreadIdHash> threads_;
    std::unordered_map<std::uint32_t,
        std::unordered_set<XnuThreadId, XnuThreadIdHash>>
        process_threads_;
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

}
