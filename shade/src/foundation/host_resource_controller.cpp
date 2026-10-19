// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Budget and schedule optional host work under CPU, memory and
// storage limits.

#include "foundation/host_resource_controller.hpp"

#include <algorithm>
#include <stdexcept>
#include <utility>

namespace shade {
namespace {

    [[nodiscard]] unsigned work_priority(HostWorkKind kind)
    {
        switch (kind) {
        case HostWorkKind::ForegroundPrepare:
            return 0;
        case HostWorkKind::Maintenance:
            return 1;
        case HostWorkKind::BackgroundCompile:
            return 2;
        case HostWorkKind::OfflineCompile:
            return 3;
        case HostWorkKind::ArtifactCompaction:
            return 4;
        }
        return 4;
    }

    [[nodiscard]] bool is_budgeted_compile(HostWorkKind kind)
    {
        return kind == HostWorkKind::BackgroundCompile ||
               kind == HostWorkKind::OfflineCompile;
    }

    [[nodiscard]] bool is_interactive_work(HostWorkKind kind)
    {
        return kind == HostWorkKind::BackgroundCompile;
    }

    [[nodiscard]] bool is_offline_work(HostWorkKind kind)
    {
        return kind == HostWorkKind::OfflineCompile;
    }

    [[nodiscard]] bool is_best_effort_work(HostWorkKind kind)
    {
        return is_budgeted_compile(kind) ||
               kind == HostWorkKind::ArtifactCompaction;
    }

    [[nodiscard]] std::chrono::nanoseconds deadline_reserve_for(
        HostWorkKind kind, std::chrono::nanoseconds estimated_cost,
        std::chrono::nanoseconds configured_reserve) noexcept
    {
        if (kind == HostWorkKind::ArtifactCompaction) {
            return std::max(configured_reserve, estimated_cost);
        }
        return configured_reserve;
    }

} // namespace

ArtifactCompactionAdmission::ArtifactCompactionAdmission()
    : ArtifactCompactionAdmission { Config { } }
{
}

ArtifactCompactionAdmission::ArtifactCompactionAdmission(Config config)
    : config_ { config }
{
    if (config_.quiet_period < std::chrono::nanoseconds::zero() ||
        config_.cancellation_cooldown < std::chrono::nanoseconds::zero() ||
        config_.negative_probe_interval < std::chrono::nanoseconds::zero() ||
        config_.recovery_quiet_period < std::chrono::nanoseconds::zero()) {
        throw std::invalid_argument { "invalid artifact compaction admission" };
    }
}

bool ArtifactCompactionAdmission::blocked(
    const ArtifactCompactionAdmissionSnapshot& snapshot) noexcept
{
    return snapshot.runnable_count != 0U || snapshot.pending_input ||
           snapshot.deadline_within_reserve || snapshot.memory_pressure ||
           !snapshot.controller_available;
}

ArtifactCompactionAdmissionDecision ArtifactCompactionAdmission::observe(
    const ArtifactCompactionAdmissionSnapshot& snapshot,
    bool task_active) noexcept
{
    if (blocked(snapshot)) {
        quiet_since_.reset();
        return task_active ? ArtifactCompactionAdmissionDecision::CancelActive
                           : ArtifactCompactionAdmissionDecision::Blocked;
    }
    if (task_active)
        return ArtifactCompactionAdmissionDecision::KeepActive;
    if (snapshot.now < cooldown_until_) {
        quiet_since_.reset();
        return ArtifactCompactionAdmissionDecision::Blocked;
    }
    if (!quiet_since_) {
        quiet_since_ = snapshot.now;
        const auto required_quiet =
            recovering_ ? config_.recovery_quiet_period : config_.quiet_period;
        return required_quiet == std::chrono::nanoseconds::zero()
                   ? ArtifactCompactionAdmissionDecision::Eligible
                   : ArtifactCompactionAdmissionDecision::WaitingForQuiet;
    }
    const auto required_quiet =
        recovering_ ? config_.recovery_quiet_period : config_.quiet_period;
    return snapshot.now - *quiet_since_ >= required_quiet
               ? ArtifactCompactionAdmissionDecision::Eligible
               : ArtifactCompactionAdmissionDecision::WaitingForQuiet;
}

bool ArtifactCompactionAdmission::store_probe_due(
    std::chrono::steady_clock::time_point now) const noexcept
{
    return now >= next_store_probe_;
}

void ArtifactCompactionAdmission::note_store_probe_miss(
    std::chrono::steady_clock::time_point now) noexcept
{
    next_store_probe_ = now + config_.negative_probe_interval;
}

void ArtifactCompactionAdmission::note_cancellation_request(
    std::chrono::steady_clock::time_point now) noexcept
{
    quiet_since_.reset();
    recovering_ = true;
    cooldown_until_ = now + config_.cancellation_cooldown;
    next_store_probe_ = cooldown_until_;
}

void ArtifactCompactionAdmission::note_submission_rejected(
    std::chrono::steady_clock::time_point now) noexcept
{
    quiet_since_.reset();
    cooldown_until_ = now + config_.cancellation_cooldown;
    next_store_probe_ = cooldown_until_;
}

void ArtifactCompactionAdmission::note_task_admitted() noexcept
{
    recovering_ = false;
}

void ArtifactCompactionAdmission::note_task_terminal(
    std::chrono::steady_clock::time_point now) noexcept
{
    quiet_since_.reset();
    next_store_probe_ = now + config_.negative_probe_interval;
}

bool ArtifactCompactionTaskRecord::mark_running(
    std::uint64_t started_nanoseconds) noexcept
{
    auto expected = ArtifactCompactionTaskState::Queued;
    if (!state_.compare_exchange_strong(expected,
            ArtifactCompactionTaskState::Running, std::memory_order_acq_rel,
            std::memory_order_acquire)) {
        return false;
    }
    started_nanoseconds_.store(started_nanoseconds, std::memory_order_release);
    return true;
}

bool ArtifactCompactionTaskRecord::request_cancellation(
    std::uint64_t requested_nanoseconds) noexcept
{
    const auto state = state_.load(std::memory_order_acquire);
    if (state != ArtifactCompactionTaskState::Queued &&
        state != ArtifactCompactionTaskState::Running) {
        return false;
    }
    auto expected = std::uint64_t { };
    if (!cancellation_requested_nanoseconds_.compare_exchange_strong(expected,
            requested_nanoseconds, std::memory_order_acq_rel,
            std::memory_order_acquire)) {
        return false;
    }
    // A terminal publisher can win between the active-state observation and
    // the timestamp CAS above. Recheck and roll back so cancellation never
    // reports success after terminal publication. If terminal publication wins
    // after this acquire, the request linearizes first and remains valid.
    const auto confirmed = state_.load(std::memory_order_acquire);
    if (confirmed == ArtifactCompactionTaskState::Queued ||
        confirmed == ArtifactCompactionTaskState::Running) {
        return true;
    }
    auto rollback = requested_nanoseconds;
    static_cast<void>(
        cancellation_requested_nanoseconds_.compare_exchange_strong(rollback,
            0U, std::memory_order_acq_rel, std::memory_order_acquire));
    return false;
}

bool ArtifactCompactionTaskRecord::publish_terminal(
    ArtifactCompactionTaskState terminal,
    std::uint64_t terminal_nanoseconds) noexcept
{
    const auto before_start =
        terminal == ArtifactCompactionTaskState::CancelledBeforeStart;
    if (terminal != ArtifactCompactionTaskState::Completed &&
        terminal != ArtifactCompactionTaskState::CancelledBeforeStart &&
        terminal != ArtifactCompactionTaskState::CancelledInProgress &&
        terminal != ArtifactCompactionTaskState::Failed) {
        return false;
    }
    auto expected = before_start ? ArtifactCompactionTaskState::Queued
                                 : ArtifactCompactionTaskState::Running;
    if (!state_.compare_exchange_strong(expected, terminal,
            std::memory_order_acq_rel, std::memory_order_acquire)) {
        return false;
    }
    terminal_nanoseconds_.store(
        terminal_nanoseconds, std::memory_order_release);
    return true;
}

void HostWorkToken::wait_finished() const
{
    if (finished())
        return;
    std::unique_lock lock { finished_mutex_ };
    finished_condition_.wait(lock, [this] { return finished(); });
}

bool HostResourceController::task_precedes(const Task& left, const Task& right)
{
    const auto left_priority = work_priority(left.kind);
    const auto right_priority = work_priority(right.kind);
    if (left_priority != right_priority)
        return left_priority < right_priority;
    if (left.deadline && right.deadline && *left.deadline != *right.deadline)
        return *left.deadline < *right.deadline;
    if (left.deadline != right.deadline)
        return left.deadline.has_value();
    return left.sequence < right.sequence;
}

HostResourceController::HostResourceController(HostResourceBudget budget)
    : budget_ { std::move(budget) }
    , duty_window_start_ { Clock::now() }
{
    const auto aggregate_interactive_limit =
        budget_.duty_period * static_cast<std::int64_t>(
                                  std::max<std::size_t>(1U,
                                      budget_.worker_count));
    if (budget_.duty_period <= std::chrono::nanoseconds::zero() ||
        budget_.interactive_compile_budget < std::chrono::nanoseconds::zero() ||
        budget_.interactive_compile_budget > aggregate_interactive_limit ||
        budget_.offline_compile_budget < std::chrono::nanoseconds::zero() ||
        budget_.deadline_reserve < std::chrono::nanoseconds::zero()) {
        throw std::invalid_argument { "invalid host resource budget" };
    }
    workers_.reserve(budget_.worker_count);
    for (std::size_t index = 0; index < budget_.worker_count; ++index) {
        workers_.emplace_back([this] { worker_loop(); });
    }
}

HostResourceController::~HostResourceController() { stop(); }

std::shared_ptr<HostWorkToken> HostResourceController::submit(HostWorkKind kind,
    std::optional<Clock::time_point> deadline, Work work,
    std::chrono::nanoseconds estimated_cost)
{
    return submit_impl(kind, deadline, std::move(work), { }, estimated_cost);
}

std::shared_ptr<HostWorkToken> HostResourceController::submit_cancellable(
    HostWorkKind kind, std::optional<Clock::time_point> deadline,
    CancellableWork work, std::chrono::nanoseconds estimated_cost)
{
    return submit_impl(kind, deadline, { }, std::move(work), estimated_cost);
}

std::shared_ptr<HostWorkToken> HostResourceController::submit_impl(
    HostWorkKind kind, std::optional<Clock::time_point> deadline, Work work,
    CancellableWork cancellable_work, std::chrono::nanoseconds estimated_cost)
{
    if (!work && !cancellable_work)
        return nullptr;
    const auto token = std::make_shared<HostWorkToken>();
    const auto now = Clock::now();
    const std::lock_guard lock { mutex_ };
    const auto deadline_reserve =
        deadline_reserve_for(kind, estimated_cost, budget_.deadline_reserve);
    if (stopping_ || workers_.empty() ||
        (is_best_effort_work(kind) && next_deadline_ &&
            *next_deadline_ <= now + deadline_reserve)) {
        ++rejected_;
        return nullptr;
    }
    if (is_budgeted_compile(kind)) {
        const auto limit = is_interactive_work(kind)
                               ? budget_.interactive_compile_budget
                               : budget_.offline_compile_budget;
        if (estimated_cost < std::chrono::nanoseconds::zero()) {
            ++rejected_;
            return nullptr;
        }
        if (estimated_cost == std::chrono::nanoseconds::zero())
            estimated_cost = limit;
        if (limit == std::chrono::nanoseconds::zero() ||
            estimated_cost > limit) {
            ++rejected_;
            return nullptr;
        }
    } else if (kind != HostWorkKind::ArtifactCompaction) {
        estimated_cost = std::chrono::nanoseconds::zero();
    } else if (estimated_cost < std::chrono::nanoseconds::zero()) {
        ++rejected_;
        return nullptr;
    }
    Work task_work;
    if (cancellable_work) {
        task_work = [work = std::move(cancellable_work), token] {
            work(*token);
        };
    } else {
        task_work = std::move(work);
    }
    const auto sequence = next_sequence_++;
    tasks_.emplace(sequence, Task { kind, deadline, sequence, token,
                                 std::move(task_work), estimated_cost });
    work_available_.notify_one();
    return token;
}

void HostResourceController::set_next_deadline(
    std::optional<Clock::time_point> deadline)
{
    {
        const std::lock_guard lock { mutex_ };
        if (next_deadline_ == deadline)
            return;
        next_deadline_ = deadline;
    }
    work_available_.notify_all();
}

void HostResourceController::wake() noexcept { work_available_.notify_all(); }

void HostResourceController::wait_idle()
{
    std::unique_lock lock { mutex_ };
    idle_.wait(lock, [this] { return tasks_.empty() && active_tasks_ == 0U; });
}

std::size_t HostResourceController::queued() const
{
    const std::lock_guard lock { mutex_ };
    return tasks_.size();
}

std::size_t HostResourceController::active() const
{
    const std::lock_guard lock { mutex_ };
    return static_cast<std::size_t>(active_tasks_);
}

bool HostResourceController::accepting_work() const
{
    const std::lock_guard lock { mutex_ };
    return !stopping_ && !workers_.empty();
}

std::uint64_t HostResourceController::completed() const
{
    const std::lock_guard lock { mutex_ };
    return completed_;
}

std::uint64_t HostResourceController::rejected() const
{
    const std::lock_guard lock { mutex_ };
    return rejected_;
}

void HostResourceController::worker_loop()
{
    for (;;) {
        Task task;
        {
            std::unique_lock lock { mutex_ };
            for (;;) {
                work_available_.wait(
                    lock, [this] { return stopping_ || !tasks_.empty(); });
                if (tasks_.empty() && stopping_)
                    return;
                if (tasks_.empty())
                    continue;

                const auto now = Clock::now();
                if (now - duty_window_start_ >= budget_.duty_period) {
                    duty_window_start_ = now;
                    interactive_work_ = std::chrono::nanoseconds::zero();
                    offline_work_ = std::chrono::nanoseconds::zero();
                }
                auto iterator = tasks_.end();
                for (auto candidate = tasks_.begin(); candidate != tasks_.end();
                    ++candidate) {
                    if (candidate->second.token->cancelled()) {
                        iterator = candidate;
                        break;
                    }
                    const auto budgeted =
                        is_budgeted_compile(candidate->second.kind);
                    if (!stopping_ &&
                        is_best_effort_work(candidate->second.kind)) {
                        const auto reserve =
                            deadline_reserve_for(candidate->second.kind,
                                candidate->second.estimated_cost,
                                budget_.deadline_reserve);
                        if (next_deadline_ && *next_deadline_ <= now + reserve)
                            continue;
                    }
                    if (!stopping_ && budgeted) {
                        const auto interactive =
                            is_interactive_work(candidate->second.kind);
                        const auto limit =
                            interactive ? budget_.interactive_compile_budget
                                        : budget_.offline_compile_budget;
                        const auto work =
                            interactive ? interactive_work_ : offline_work_;
                        const auto reserved = interactive
                                                  ? interactive_reserved_
                                                  : offline_reserved_;
                        if (work >= limit)
                            continue;
                        const auto available = limit - work;
                        if (reserved > available ||
                            candidate->second.estimated_cost >
                                available - reserved) {
                            continue;
                        }
                    }
                    if (iterator == tasks_.end() ||
                        task_precedes(candidate->second, iterator->second)) {
                        iterator = candidate;
                    }
                }
                if (iterator == tasks_.end()) {
                    const auto wake_at =
                        duty_window_start_ + budget_.duty_period;
                    work_available_.wait_until(lock, wake_at);
                    continue;
                }
                task = std::move(iterator->second);
                tasks_.erase(iterator);
                if (is_interactive_work(task.kind)) {
                    interactive_reserved_ += task.estimated_cost;
                    task.budget_reserved = true;
                } else if (is_offline_work(task.kind)) {
                    offline_reserved_ += task.estimated_cost;
                    task.budget_reserved = true;
                }
                ++active_tasks_;
                break;
            }
        }

        const auto started = Clock::now();
        if (!task.token->cancelled()) {
            try {
                task.work();
            } catch (...) {
                // Host maintenance and optional compilation are isolated from
                // guest execution. A failed task is observable through its
                // absence, not an exception escaping the worker thread.
            }
        }
        const auto elapsed = Clock::now() - started;
        {
            const std::lock_guard lock { mutex_ };
            task.token->mark_finished();
            if (task.budget_reserved) {
                if (is_interactive_work(task.kind)) {
                    interactive_reserved_ -= task.estimated_cost;
                    interactive_work_ += elapsed;
                } else if (is_offline_work(task.kind)) {
                    offline_reserved_ -= task.estimated_cost;
                    offline_work_ += elapsed;
                }
            }
            --active_tasks_;
            ++completed_;
            if (tasks_.empty() && active_tasks_ == 0U)
                idle_.notify_all();
        }
        work_available_.notify_all();
    }
}

void HostResourceController::stop()
{
    {
        const std::lock_guard lock { mutex_ };
        if (stopping_)
            return;
        stopping_ = true;
        for (auto& [sequence, task] : tasks_) {
            static_cast<void>(sequence);
            task.token->cancel();
        }
    }
    work_available_.notify_all();
    for (auto& worker : workers_) {
        if (worker.joinable())
            worker.join();
    }
    workers_.clear();
}

} // namespace shade
