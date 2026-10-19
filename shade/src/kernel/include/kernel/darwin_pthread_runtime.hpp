// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Manage guest pthread registration, thread-local state and workqueue
// requests.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/xnu/blob/xnu-1699.22.73/bsd/kern/pthread_support.c

#pragma once

#include <array>
#include <cstdint>
#include <deque>
#include <map>
#include <optional>
#include <vector>

namespace shade {

struct DarwinPthreadRegistration {
    std::uint32_t thread_start { };
    std::uint32_t workqueue_thread_start { };
    std::uint32_t pthread_size { };
    std::uint32_t reserved { };
    std::uint32_t target_concurrency { };
    std::uint32_t dispatch_queue_offset { };
};

enum class DarwinWorkqueueDelivery { WorkItem, DispatchThread };

struct DarwinWorkqueueItem {
    std::uint32_t address { };
    std::uint32_t priority { };
    std::uint32_t affinity { };
    bool overcommit { };
    DarwinWorkqueueDelivery delivery { DarwinWorkqueueDelivery::WorkItem };
};

struct DarwinWorkqueueWorker {
    std::uint32_t processor { };
    std::uint32_t port_name { };
    std::uint32_t allocation_base { };
    std::uint32_t allocation_size { };
    std::uint32_t pthread_address { };
    std::uint32_t stack_bottom { };
    std::uint32_t priority { };
    bool idle { };
};

// Per-process state installed by Darwin's bsdthread_register syscall. The
// compatibility kernel owns scheduling and memory; this object only retains
// the Guest ABI registration across fork and clears it across exec.
class DarwinPthreadRuntime {
public:
    static constexpr std::uint32_t maximum_pthread_size = 64U * 1024U;
    // Storage covers the largest audited v1 contract. The active count is
    // configured from the firmware ABI when workq_open is handled.
    static constexpr std::uint32_t maximum_workqueue_priority_count = 4U;
    static constexpr std::uint32_t workqueue_overcommit = 0x0001'0000U;
    static constexpr std::size_t maximum_workqueue_workers = 64U;
    static constexpr std::size_t maximum_workqueue_items_per_priority = 64U;

    [[nodiscard]] bool register_process(DarwinPthreadRegistration registration);
    [[nodiscard]] const std::optional<DarwinPthreadRegistration>&
    registration() const noexcept
    {
        return registration_;
    }
    [[nodiscard]] bool open_workqueue(std::uint32_t processor_count,
        std::uint32_t priority_count) noexcept
    {
        if (!registration_ || priority_count == 0U ||
            priority_count > maximum_workqueue_priority_count) {
            return false;
        }
        workqueue_open_ = true;
        workqueue_priority_count_ = priority_count;
        target_concurrency_.fill(0U);
        for (std::uint32_t priority = 0; priority < priority_count; ++priority) {
            target_concurrency_[priority] =
                processor_count == 0U ? 1U : processor_count;
        }
        return true;
    }
    [[nodiscard]] bool workqueue_open() const noexcept
    {
        return workqueue_open_;
    }
    [[nodiscard]] std::uint32_t workqueue_priority_count() const noexcept
    {
        return workqueue_priority_count_;
    }

    [[nodiscard]] bool enqueue_workitem(
        DarwinWorkqueueItem item, bool front = false);
    [[nodiscard]] bool request_dispatch_threads(
        std::uint32_t count, std::uint32_t priority, bool overcommit);
    [[nodiscard]] std::optional<DarwinWorkqueueItem> take_workitem();
    [[nodiscard]] bool remove_workitem(
        std::uint32_t address, std::uint32_t priority);
    [[nodiscard]] bool should_create_worker(
        std::uint32_t priority, bool overcommit,
        std::size_t active_worker_count) const noexcept;
    [[nodiscard]] bool add_worker(DarwinWorkqueueWorker worker);
    [[nodiscard]] std::optional<DarwinWorkqueueWorker> worker(
        std::uint32_t processor) const;
    [[nodiscard]] std::optional<DarwinWorkqueueWorker> idle_worker() const;
    [[nodiscard]] std::vector<std::uint32_t> active_worker_processors() const;
    void mark_worker_running(std::uint32_t processor, std::uint32_t priority);
    void park_worker(std::uint32_t processor);
    void remove_worker(std::uint32_t processor);
    [[nodiscard]] bool set_target_concurrency(
        std::uint32_t priority, std::uint32_t concurrency);

    void prepare_exec() noexcept
    {
        registration_.reset();
        reset_workqueue();
    }
    void inherit_from(const DarwinPthreadRuntime& parent, bool fork) noexcept
    {
        registration_ = fork ? parent.registration_ : std::nullopt;
        // XNU constructs a fresh workqueue for a child process.  The pthread
        // ABI registration survives fork, but kernel workqueue state does not.
        reset_workqueue();
    }

private:
    void reset_workqueue() noexcept;

    std::optional<DarwinPthreadRegistration> registration_;
    bool workqueue_open_ { };
    std::uint32_t workqueue_priority_count_ { };
    std::array<std::deque<DarwinWorkqueueItem>,
        maximum_workqueue_priority_count>
        workitems_;
    std::map<std::uint32_t, DarwinWorkqueueWorker> workers_;
    std::array<std::uint32_t, maximum_workqueue_priority_count>
        target_concurrency_ { };
};

} // namespace shade
