// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Publish lightweight runtime activity epochs for optional JIT
// scheduling.

#pragma once

#include <atomic>
#include <cstddef>
#include <cstdint>
#include <memory>

namespace shade {

enum class JitWorkActivityKind : std::uint8_t {
    Activation,
    Worker,
};

// One simulator-core change signal shared by every runtime. Demand recorders
// publish directly to it, while frontend lifecycle adapters hold activities.
// Sampling is O(1) regardless of the number of Guest processes or executors.
class JitWorkObservationSignal final
    : public std::enable_shared_from_this<JitWorkObservationSignal> {
public:
    struct Snapshot {
        std::uint64_t generation { };
        bool activation_pending { };
        bool worker_active { };
    };

    class Activity final {
    public:
        Activity(const Activity&) = delete;
        Activity& operator=(const Activity&) = delete;
        ~Activity() { signal_->end_activity(kind_); }

    private:
        friend class JitWorkObservationSignal;

        Activity(std::shared_ptr<JitWorkObservationSignal> signal,
            JitWorkActivityKind kind) noexcept
            : signal_ { std::move(signal) }
            , kind_ { kind }
        {
            signal_->begin_activity(kind_);
        }

        std::shared_ptr<JitWorkObservationSignal> signal_;
        JitWorkActivityKind kind_;
    };

    void notify_work() noexcept
    {
        generation_.fetch_add(1U, std::memory_order_release);
    }

    [[nodiscard]] std::shared_ptr<Activity> track(
        JitWorkActivityKind kind)
    {
        return std::shared_ptr<Activity> {
            new Activity { shared_from_this(), kind }
        };
    }

    [[nodiscard]] Snapshot snapshot() const noexcept
    {
        return Snapshot {
            generation_.load(std::memory_order_acquire),
            activation_count_.load(std::memory_order_relaxed) != 0U,
            worker_count_.load(std::memory_order_relaxed) != 0U,
        };
    }

private:
    [[nodiscard]] std::atomic_size_t& counter(
        JitWorkActivityKind kind) noexcept
    {
        return kind == JitWorkActivityKind::Activation ? activation_count_
                                                       : worker_count_;
    }

    void begin_activity(JitWorkActivityKind kind) noexcept
    {
        counter(kind).fetch_add(1U, std::memory_order_relaxed);
        notify_work();
    }

    void end_activity(JitWorkActivityKind kind) noexcept
    {
        auto& value = counter(kind);
        auto observed = value.load(std::memory_order_relaxed);
        while (observed != 0U &&
               !value.compare_exchange_weak(observed, observed - 1U,
                   std::memory_order_relaxed, std::memory_order_relaxed)) {
        }
        notify_work();
    }

    std::atomic_uint64_t generation_ { 1U };
    std::atomic_size_t activation_count_ { };
    std::atomic_size_t worker_count_ { };
};

} // namespace shade
