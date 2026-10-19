// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Run scheduler-selected guest CPU batches on coordinated host
// execution lanes.

#pragma once

#include <chrono>
#include <cstddef>
#include <cstdint>
#include <exception>
#include <memory>
#include <span>

#include "foundation/cpu.hpp"

namespace emulator {

struct GuestExecutionRequest {
    Cpu* cpu { };
    std::size_t execution_slot { };
    std::uint64_t tick_budget { };
    std::chrono::nanoseconds host_slice_budget { };
    bool single_step { };
    bool cooperative { true };
    CpuRunResult result;
    std::exception_ptr error;
};

class GuestExecutionCoordinator {
public:
    explicit GuestExecutionCoordinator(std::size_t worker_count);
    ~GuestExecutionCoordinator();

    GuestExecutionCoordinator(const GuestExecutionCoordinator&) = delete;
    GuestExecutionCoordinator& operator=(
        const GuestExecutionCoordinator&) = delete;

    void run(std::span<GuestExecutionRequest*> requests);
    static void execute(GuestExecutionRequest& request) noexcept;

private:
    void worker_loop();

    struct Impl;
    std::unique_ptr<Impl> impl_;
};

}
