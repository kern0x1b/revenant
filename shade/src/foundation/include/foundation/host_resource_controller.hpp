// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Budget and schedule optional host work under CPU, memory and
// storage limits.

#pragma once

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstddef>
#include <cstdint>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <thread>
#include <vector>

namespace shade {

enum class HostWorkKind : std::uint8_t {
    ForegroundPrepare,
    BackgroundCompile,
    OfflineCompile,
    Maintenance,
    ArtifactCompaction,
};

struct HostResourceBudget {
    std::size_t worker_count { 1 };
    std::chrono::nanoseconds duty_period { std::chrono::seconds { 1 } };
    // Aggregate worker-time per duty window. A multi-worker controller may
    // spend more than one wall-clock period, but never more than worker_count
    // periods, across concurrently executing interactive compile tasks.
    std::chrono::nanoseconds interactive_compile_budget {
        std::chrono::milliseconds { 100 }
    };
    std::chrono::nanoseconds offline_compile_budget {
        std::chrono::milliseconds { 800 }
    };
    std::chrono::nanoseconds deadline_reserve { std::chrono::milliseconds {
        2 } };
};

struct ArtifactCompactionAdmissionSnapshot {
    std::chrono::steady_clock::time_point now;
    std::size_t runnable_count { };
    bool pending_input { };
    bool deadline_within_reserve { };
    bool memory_pressure { };
    bool controller_available { true };
};

enum class ArtifactCompactionAdmissionDecision : std::uint8_t {
    Blocked,
    WaitingForQuiet,
    Eligible,
    KeepActive,
    CancelActive,
};

class ArtifactCompactionAdmission {
public:
    struct Config {
        std::chrono::nanoseconds quiet_period { std::chrono::milliseconds {
            25 } };
        std::chrono::nanoseconds cancellation_cooldown {
            std::chrono::milliseconds { 250 }
        };
        std::chrono::nanoseconds negative_probe_interval {
            std::chrono::milliseconds { 250 }
        };
        std::chrono::nanoseconds recovery_quiet_period {
            std::chrono::milliseconds { 25 }
        };
    };

    ArtifactCompactionAdmission();
    explicit ArtifactCompactionAdmission(Config config);

    [[nodiscard]] ArtifactCompactionAdmissionDecision observe(
        const ArtifactCompactionAdmissionSnapshot& snapshot,
        bool task_active) noexcept;
    [[nodiscard]] bool store_probe_due(
        std::chrono::steady_clock::time_point now) const noexcept;
    void note_store_probe_miss(
        std::chrono::steady_clock::time_point now) noexcept;
    void note_cancellation_request(
        std::chrono::steady_clock::time_point now) noexcept;
    void note_submission_rejected(
        std::chrono::steady_clock::time_point now) noexcept;
    void note_task_admitted() noexcept;
    void note_task_terminal(std::chrono::steady_clock::time_point now) noexcept;

private:
    [[nodiscard]] static bool blocked(
        const ArtifactCompactionAdmissionSnapshot& snapshot) noexcept;

    Config config_;
    std::optional<std::chrono::steady_clock::time_point> quiet_since_;
    std::chrono::steady_clock::time_point cooldown_until_ { };
    std::chrono::steady_clock::time_point next_store_probe_ { };
    bool recovering_ { };
};

enum class ArtifactCompactionTaskState : std::uint8_t {
    Queued,
    Running,
    Completed,
    CancelledBeforeStart,
    CancelledInProgress,
    Failed,
};

class ArtifactCompactionTaskRecord {
public:
    ArtifactCompactionTaskRecord(
        std::uint64_t id, std::uint64_t admitted_nanoseconds) noexcept
        : id_ { id }
        , admitted_nanoseconds_ { admitted_nanoseconds }
    {
    }

    [[nodiscard]] bool mark_running(std::uint64_t started_nanoseconds) noexcept;
    [[nodiscard]] bool request_cancellation(
        std::uint64_t requested_nanoseconds) noexcept;
    [[nodiscard]] bool publish_terminal(ArtifactCompactionTaskState terminal,
        std::uint64_t terminal_nanoseconds) noexcept;

    [[nodiscard]] std::uint64_t id() const noexcept { return id_; }
    [[nodiscard]] std::uint64_t admitted_nanoseconds() const noexcept
    {
        return admitted_nanoseconds_;
    }
    [[nodiscard]] std::uint64_t started_nanoseconds() const noexcept
    {
        return started_nanoseconds_.load(std::memory_order_acquire);
    }
    [[nodiscard]] std::uint64_t
    cancellation_requested_nanoseconds() const noexcept
    {
        return cancellation_requested_nanoseconds_.load(
            std::memory_order_acquire);
    }
    [[nodiscard]] std::uint64_t terminal_nanoseconds() const noexcept
    {
        return terminal_nanoseconds_.load(std::memory_order_acquire);
    }
    [[nodiscard]] ArtifactCompactionTaskState state() const noexcept
    {
        return state_.load(std::memory_order_acquire);
    }

private:
    std::uint64_t id_ { };
    std::uint64_t admitted_nanoseconds_ { };
    std::atomic<std::uint64_t> started_nanoseconds_ { };
    std::atomic<std::uint64_t> cancellation_requested_nanoseconds_ { };
    std::atomic<std::uint64_t> terminal_nanoseconds_ { };
    std::atomic<ArtifactCompactionTaskState> state_ {
        ArtifactCompactionTaskState::Queued
    };
};

class HostWorkToken {
public:
    void cancel() noexcept
    {
        cancelled_.store(true, std::memory_order_release);
    }
    [[nodiscard]] bool cancelled() const noexcept
    {
        return cancelled_.load(std::memory_order_acquire);
    }
    [[nodiscard]] bool finished() const noexcept
    {
        return finished_.load(std::memory_order_acquire);
    }
    void wait_finished() const;

private:
    friend class HostResourceController;
    void mark_finished() noexcept
    {
        finished_.store(true, std::memory_order_release);
        finished_condition_.notify_all();
    }

    std::atomic<bool> cancelled_ { };
    std::atomic<bool> finished_ { };
    mutable std::mutex finished_mutex_;
    mutable std::condition_variable finished_condition_;
};

class HostResourceController {
public:
    using Clock = std::chrono::steady_clock;
    using Work = std::function<void()>;
    using CancellableWork = std::function<void(const HostWorkToken&)>;

    explicit HostResourceController(HostResourceBudget budget = { });
    ~HostResourceController();

    HostResourceController(const HostResourceController&) = delete;
    HostResourceController& operator=(const HostResourceController&) = delete;

    // A deadline is advisory: work is rejected only when the controller knows
    // that the next deadline is inside the reserve window. The caller can retry
    // after the deadline advances. Background work reserves estimated_cost when
    // it starts; a zero estimate conservatively consumes the full configured
    // interactive compile budget for that duty window.
    [[nodiscard]] std::shared_ptr<HostWorkToken> submit(HostWorkKind kind,
        std::optional<Clock::time_point> deadline, Work work,
        std::chrono::nanoseconds estimated_cost =
            std::chrono::nanoseconds::zero());
    // The token is passed to the work body so a task that has already started
    // can stop at its own safe points. Cancellation remains cooperative: the
    // controller never interrupts a host function in the middle of an ABI or
    // filesystem operation.
    [[nodiscard]] std::shared_ptr<HostWorkToken> submit_cancellable(
        HostWorkKind kind, std::optional<Clock::time_point> deadline,
        CancellableWork work,
        std::chrono::nanoseconds estimated_cost =
            std::chrono::nanoseconds::zero());
    void set_next_deadline(std::optional<Clock::time_point> deadline);
    // Wakes workers after a queued token is cancelled so the cancellation can
    // be observed without waiting for the current duty window to expire.
    void wake() noexcept;
    void wait_idle();

    [[nodiscard]] std::size_t queued() const;
    [[nodiscard]] std::size_t active() const;
    [[nodiscard]] bool accepting_work() const;
    [[nodiscard]] std::uint64_t completed() const;
    [[nodiscard]] std::uint64_t rejected() const;

private:
    struct Task {
        HostWorkKind kind { };
        std::optional<Clock::time_point> deadline;
        std::uint64_t sequence { };
        std::shared_ptr<HostWorkToken> token;
        Work work;
        std::chrono::nanoseconds estimated_cost { };
        bool budget_reserved { };
    };

    [[nodiscard]] static bool task_precedes(
        const Task& left, const Task& right);
    [[nodiscard]] std::shared_ptr<HostWorkToken> submit_impl(HostWorkKind kind,
        std::optional<Clock::time_point> deadline, Work work,
        CancellableWork cancellable_work,
        std::chrono::nanoseconds estimated_cost);
    void worker_loop();
    void stop();

    const HostResourceBudget budget_;
    mutable std::mutex mutex_;
    std::condition_variable work_available_;
    std::condition_variable idle_;
    std::map<std::uint64_t, Task> tasks_;
    std::vector<std::thread> workers_;
    std::optional<Clock::time_point> next_deadline_;
    Clock::time_point duty_window_start_ { };
    std::chrono::nanoseconds interactive_work_ { };
    std::chrono::nanoseconds interactive_reserved_ { };
    std::chrono::nanoseconds offline_work_ { };
    std::chrono::nanoseconds offline_reserved_ { };
    std::uint64_t next_sequence_ { 1 };
    std::uint64_t active_tasks_ { };
    std::uint64_t completed_ { };
    std::uint64_t rejected_ { };
    bool stopping_ { };
};

} // namespace shade
