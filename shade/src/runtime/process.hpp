// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Store guest process execution state, pending lifecycle work and
// runtime indexes.

#pragma once

#include <algorithm>
#include <array>
#include <atomic>
#include <bit>
#include <chrono>
#include <condition_variable>
#include <cstddef>
#include <cstdint>
#include <deque>
#include <exception>
#include <filesystem>
#include <fstream>
#include <functional>
#include <iomanip>
#include <iostream>
#include <limits>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <span>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <thread>
#include <unordered_map>
#include <unordered_set>
#include <variant>
#include <vector>

#include "foundation/address_space.hpp"
#include "foundation/cpu.hpp"
#include "foundation/host_resource_controller.hpp"
#include "foundation/jit_code_cache_governor.hpp"
#include "foundation/jit_translation_profile.hpp"
#include "foundation/jit_work_signal.hpp"
#include "foundation/performance.hpp"
#include "kernel/kernel.hpp"

namespace shade::runtime_detail {

constexpr std::size_t fault_stack_word_count = 32;
constexpr std::size_t maximum_watchpoint_traces = 64;
constexpr std::size_t initial_guest_thread_slots = 16;
constexpr std::size_t maximum_guest_threads = 32;
constexpr std::size_t maximum_virtual_processors = 64;
constexpr std::size_t maximum_shared_monitor_processes = 1024;
constexpr std::size_t maximum_shared_monitor_slots =
    maximum_virtual_processors * maximum_shared_monitor_processes;
constexpr std::size_t maximum_background_workers = 8;
constexpr std::size_t bytes_per_mebibyte = 1024U * 1024U;
constexpr std::size_t arm_thumb_breakpoint_size = 2;
constexpr std::size_t arm_breakpoint_size = 4;

struct PendingExec {
    std::size_t processor { };
    std::string path;
    std::vector<std::string> arguments;
    std::vector<std::string> environment;
};

struct RuntimeWorkEpoch {
    [[nodiscard]] std::uint64_t current() const noexcept
    {
        return epoch_.load(std::memory_order_acquire);
    }

    [[nodiscard]] std::uint64_t begin_transition() noexcept
    {
        cancelled_.store(true, std::memory_order_release);
        auto expected = epoch_.load(std::memory_order_relaxed);
        for (;;) {
            if (expected == std::numeric_limits<std::uint64_t>::max())
                return expected;
            if (epoch_.compare_exchange_weak(expected, expected + 1U,
                    std::memory_order_acq_rel, std::memory_order_relaxed)) {
                return expected + 1U;
            }
        }
    }

    void activate(std::uint64_t expected_epoch) noexcept
    {
        if (epoch_.load(std::memory_order_acquire) == expected_epoch)
            cancelled_.store(false, std::memory_order_release);
    }

    [[nodiscard]] bool stop_requested(
        std::uint64_t expected_epoch) const noexcept
    {
        return cancelled_.load(std::memory_order_acquire) ||
               epoch_.load(std::memory_order_acquire) != expected_epoch;
    }

private:
    std::atomic<std::uint64_t> epoch_ { 1 };
    std::atomic<bool> cancelled_ { };
};

struct RuntimePrecompileTask {
    std::shared_ptr<HostWorkToken> token;
    JitPrecompileTarget target { JitPrecompileTarget::NativeCode };
    std::shared_ptr<JitWorkObservationSignal::Activity> work_activity;

    [[nodiscard]] bool finished() const noexcept
    {
        return !token || token->finished();
    }
    void cancel() const noexcept
    {
        if (token)
            token->cancel();
    }
    void wait_finished() const
    {
        if (token)
            token->wait_finished();
    }
};

struct Runtime {
    // Keep the reservation before the native runtime fields so its destructor
    // releases the budget only after Umbra's code cache has been destroyed.
    std::shared_ptr<JitCodeCacheReservation> jit_cache_reservation;
    JitCodeCacheClass jit_cache_class { JitCodeCacheClass::Background };
    std::unique_ptr<AddressSpace> memory;
    std::unique_ptr<CpuCluster> cpus;
    std::shared_ptr<JitTranslationProfile> jit_translation_profile;
    std::unique_ptr<CompatibilityKernel> kernel;
    std::vector<bool> allocated;
    std::optional<PendingExec> pending_exec;
    std::vector<RuntimePrecompileTask> precompile_tasks;
    std::shared_ptr<HostWorkToken> execution_prepare_task;
    JitPrecompilePhase precompile_phase { JitPrecompilePhase::Opportunistic };
    std::shared_ptr<JitWorkObservationSignal> jit_work_signal;
    RuntimeWorkEpoch work_epoch;
    std::shared_ptr<JitWorkObservationSignal::Activity> activation_activity;
    std::optional<std::chrono::steady_clock::time_point>
        execution_reclaim_after;
    bool fresh_spawn_address_space { };
    bool resume_after_execution_prepare { };
    bool image_activation_pending { };
    std::optional<std::chrono::steady_clock::time_point>
        activation_release_deadline;
    bool jit_memory_accounted { };
    std::uint64_t translation_profile_mapping_generation { };
    std::uint64_t timer_deadline_generation { };
    bool timer_deadline_observed { };

    [[nodiscard]] std::uint64_t begin_image_transition(
        HostResourceController& host_resources)
    {
        const auto next_epoch = work_epoch.begin_transition();
        if (jit_work_signal)
            jit_work_signal->notify_work();
        const auto precompiles = precompile_tasks;
        const auto execution_prepare = execution_prepare_task;
        for (const auto& precompile : precompiles)
            precompile.cancel();
        if (execution_prepare)
            execution_prepare->cancel();
        host_resources.wake();
        if (cpus)
            cpus->quiesce_precompilation();
        for (const auto& precompile : precompiles)
            precompile.wait_finished();
        if (execution_prepare)
            execution_prepare->wait_finished();
        execution_prepare_task.reset();
        precompile_tasks.clear();
        resume_after_execution_prepare = false;
        set_image_activation_pending(false);
        activation_release_deadline.reset();
        return next_epoch;
    }

    void set_image_activation_pending(bool pending)
    {
        if (image_activation_pending == pending)
            return;
        image_activation_pending = pending;
        if (pending && jit_work_signal) {
            activation_activity =
                jit_work_signal->track(JitWorkActivityKind::Activation);
        } else {
            activation_activity.reset();
        }
    }

    void activate_image_epoch(std::uint64_t epoch) noexcept
    {
        work_epoch.activate(epoch);
    }

    [[nodiscard]] bool precompile_stop_requested(
        std::uint64_t expected_epoch) const noexcept
    {
        return work_epoch.stop_requested(expected_epoch);
    }

    ~Runtime()
    {
        PerformanceLatencyScope latency { PerfLatencyKind::RuntimeDestructor };
        static_cast<void>(work_epoch.begin_transition());
        for (const auto& precompile : precompile_tasks)
            precompile.cancel();
        if (execution_prepare_task)
            execution_prepare_task->cancel();
        if (cpus)
            cpus->quiesce_precompilation();
        if (execution_prepare_task)
            execution_prepare_task->wait_finished();
        pending_exec.reset();
        std::vector<bool> { }.swap(allocated);
        kernel.reset();
        cpus.reset();
        memory.reset();
    }
};

class RuntimeIndex {
public:
    RuntimeIndex() = default;
    RuntimeIndex(const RuntimeIndex&) = delete;
    RuntimeIndex& operator=(const RuntimeIndex&) = delete;

    void insert(Runtime& runtime)
    {
        const auto pid = runtime.kernel->process().pid;
        const auto [entry, inserted] = runtimes_.emplace(pid, &runtime);
        if (!inserted && entry->second != &runtime) {
            throw std::logic_error { "duplicate Runtime process id" };
        }
    }

    void erase(const Runtime& runtime)
    {
        const auto pid = runtime.kernel->process().pid;
        const auto entry = runtimes_.find(pid);
        if (entry != runtimes_.end() && entry->second == &runtime)
            runtimes_.erase(entry);
    }

    [[nodiscard]] Runtime* find(std::uint32_t pid) const
    {
        const auto entry = runtimes_.find(pid);
        return entry == runtimes_.end() ? nullptr : entry->second;
    }

private:
    std::unordered_map<std::uint32_t, Runtime*> runtimes_;
};

class RuntimeReaper {
public:
    RuntimeReaper()
        : worker_ { [this] { worker_loop(); } }
    {
    }
    RuntimeReaper(const RuntimeReaper&) = delete;
    RuntimeReaper& operator=(const RuntimeReaper&) = delete;

    ~RuntimeReaper() { finish(); }

    void retire(std::unique_ptr<Runtime> runtime)
    {
        retire_resource(std::move(runtime));
    }

    void retire_execution_resources(std::shared_ptr<CpuExecutionPool> resources)
    {
        retire_resource(std::move(resources));
    }

    void finish()
    {
        {
            std::lock_guard lock { mutex_ };
            if (joined_)
                return;
            stopping_ = true;
        }
        work_available_.notify_one();
        {
            std::unique_lock lock { mutex_ };
            idle_.wait(lock, [this] { return pending_.empty() && !active_; });
        }
        if (worker_.joinable())
            worker_.join();
        std::lock_guard lock { mutex_ };
        joined_ = true;
    }

private:
    using RetiredResource = std::variant<std::monostate,
        std::unique_ptr<Runtime>, std::shared_ptr<CpuExecutionPool>>;

    template <typename Resource> void retire_resource(Resource resource)
    {
        if (!resource)
            return;
        {
            std::lock_guard lock { mutex_ };
            if (stopping_)
                throw std::logic_error {
                    "cannot retire a Runtime after reaper stop"
                };
            pending_.push_back(std::move(resource));
        }
        work_available_.notify_one();
    }

    void worker_loop()
    {
        std::unique_lock lock { mutex_ };
        for (;;) {
            work_available_.wait(
                lock, [this] { return stopping_ || !pending_.empty(); });
            if (pending_.empty()) {
                if (stopping_)
                    break;
                continue;
            }
            auto resource = std::move(pending_.front());
            pending_.pop_front();
            active_ = true;
            lock.unlock();
            resource = std::monostate { };
            lock.lock();
            active_ = false;
            idle_.notify_all();
        }
        idle_.notify_all();
    }

    std::mutex mutex_;
    std::condition_variable work_available_;
    std::condition_variable idle_;
    std::deque<RetiredResource> pending_;
    bool active_ { };
    bool stopping_ { };
    bool joined_ { };
    std::thread worker_;
};

} // namespace shade::runtime_detail
