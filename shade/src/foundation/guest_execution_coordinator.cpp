// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Run scheduler-selected guest CPU batches on coordinated host
// execution lanes.

#include "foundation/guest_execution_coordinator.hpp"

#include <condition_variable>
#include <memory>
#include <mutex>
#include <stdexcept>
#include <thread>
#include <vector>

namespace shade {

struct GuestExecutionCoordinator::Impl {
    std::mutex mutex;
    std::condition_variable work_available;
    std::condition_variable batch_complete;
    std::vector<std::thread> workers;
    std::span<GuestExecutionRequest*> requests;
    std::size_t next_request { };
    std::size_t remaining { };
    std::uint64_t generation { };
    bool stopping { };
};

GuestExecutionCoordinator::GuestExecutionCoordinator(std::size_t worker_count)
    : impl_ { std::make_unique<Impl>() }
{
    if (worker_count == 0U) {
        throw std::invalid_argument {
            "guest execution coordinator requires a worker"
        };
    }
    impl_->workers.reserve(worker_count);
    try {
        for (std::size_t index = 0; index < worker_count; ++index)
            impl_->workers.emplace_back([this] { worker_loop(); });
    } catch (...) {
        {
            std::lock_guard lock { impl_->mutex };
            impl_->stopping = true;
        }
        impl_->work_available.notify_all();
        for (auto& worker : impl_->workers)
            worker.join();
        throw;
    }
}

GuestExecutionCoordinator::~GuestExecutionCoordinator()
{
    {
        std::lock_guard lock { impl_->mutex };
        impl_->stopping = true;
    }
    impl_->work_available.notify_all();
    for (auto& worker : impl_->workers)
        worker.join();
}

void GuestExecutionCoordinator::run(
    std::span<GuestExecutionRequest*> requests)
{
    if (requests.empty())
        return;
    for (auto* request : requests) {
        if (request == nullptr || request->cpu == nullptr) {
            throw std::invalid_argument {
                "guest execution request requires a CPU"
            };
        }
    }
    {
        std::lock_guard lock { impl_->mutex };
        if (impl_->remaining != 0U) {
            throw std::logic_error {
                "guest execution batches cannot overlap"
            };
        }
        impl_->requests = requests;
        impl_->next_request = 0U;
        impl_->remaining = requests.size();
        if (++impl_->generation == 0U)
            ++impl_->generation;
    }
    impl_->work_available.notify_all();
    std::unique_lock lock { impl_->mutex };
    impl_->batch_complete.wait(lock, [this] {
        return impl_->remaining == 0U;
    });
    impl_->requests = { };
}

void GuestExecutionCoordinator::execute(GuestExecutionRequest& request) noexcept
{
    request.result = { };
    request.error = nullptr;
    try {
        if (request.single_step) {
            request.result = request.cpu->step(request.execution_slot);
        } else if (request.cooperative) {
            request.result = request.cpu->run_cooperatively(
                request.tick_budget,
                request.host_slice_budget,
                request.execution_slot);
        } else {
            request.result =
                request.cpu->run(request.tick_budget, request.execution_slot);
        }
    } catch (...) {
        request.error = std::current_exception();
    }
}

void GuestExecutionCoordinator::worker_loop()
{
    std::uint64_t observed_generation { };
    std::unique_lock lock { impl_->mutex };
    for (;;) {
        impl_->work_available.wait(lock, [this, &observed_generation] {
            return impl_->stopping ||
                   impl_->generation != observed_generation;
        });
        if (impl_->stopping)
            return;
        observed_generation = impl_->generation;
        while (impl_->next_request < impl_->requests.size()) {
            auto* request = impl_->requests[impl_->next_request++];
            lock.unlock();
            execute(*request);
            lock.lock();
            if (--impl_->remaining == 0U)
                impl_->batch_complete.notify_one();
        }
    }
}

}
