// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Guest-free check of the --ticks rule: a bounded run asks the coordinator for
// a plain tick-budgeted Cpu::run, so its tick count depends on the budget
// alone. A cooperative slice ends on the host clock, which is the leak that
// made two identical --ticks boots consume different tick totals.

#include "foundation/address_space.hpp"
#include "foundation/cpu.hpp"
#include "foundation/guest_execution_coordinator.hpp"
#include "foundation/memory_permission.hpp"

#include <chrono>
#include <cstdint>
#include <iostream>
#include <string>

namespace {

using shade::AddressSpace;
using shade::Cpu;
using shade::GuestExecutionCoordinator;
using shade::GuestExecutionRequest;
using shade::MemoryPermission;

int failures = 0;

void expect(bool condition, const std::string& what)
{
    if (condition)
        return;
    std::cerr << "FAIL: " << what << '\n';
    ++failures;
}

constexpr std::uint32_t code_address = 0x1000U;
// A ring of ARM "b" instructions: each one branches to the next, and the last
// branches back to the first. The ring never halts, so a bounded slice runs to
// its tick budget.
constexpr std::uint32_t ring_length = 16U;
constexpr std::uint64_t tick_budget = 100'000U;

// One guest processor running the branch ring. No firmware, kernel or SVC
// handler is involved.
struct Machine {
    AddressSpace memory;
    Umbra::ExclusiveMonitor monitor { 1U };
    Cpu cpu { 0, memory, monitor };

    Machine()
    {
        memory.map(code_address, AddressSpace::page_size,
            MemoryPermission::Read | MemoryPermission::Write |
                MemoryPermission::Execute);
        for (std::uint32_t index = 0; index < ring_length; ++index) {
            // The offset is relative to pc + 8 and counts words.
            const auto next = index + 1U == ring_length ? 0U : index + 1U;
            const auto offset = static_cast<std::int32_t>(next) -
                                static_cast<std::int32_t>(index) - 2;
            const auto encoded = 0xea00'0000U |
                                 (static_cast<std::uint32_t>(offset) & 0xff'ffffU);
            memory.write32(code_address + index * 4U, encoded);
        }
        cpu.registers()[15] = code_address;
        cpu.set_cpsr(0x10U);
    }
};

GuestExecutionRequest slice(Cpu& cpu, bool cooperative,
    std::chrono::nanoseconds host_slice_budget)
{
    return GuestExecutionRequest { &cpu, 0, tick_budget, host_slice_budget,
        false, cooperative };
}

} // namespace

int main()
{
    {
        // A bounded run uses the whole budget and never yields to the host.
        Machine machine;
        auto request = slice(machine.cpu, false, std::chrono::nanoseconds { });
        GuestExecutionCoordinator::execute(request);
        expect(request.error == nullptr, "bounded slice does not throw");
        expect(request.result.ticks_consumed == tick_budget,
            "bounded slice consumes exactly its tick budget, got " +
                std::to_string(request.result.ticks_consumed));
        expect(!request.result.host_yielded,
            "bounded slice does not yield to the host");
        expect(request.result.host_yield_checks == 0U,
            "bounded slice performs no host yield checks");
    }
    {
        // Two bounded runs of the same guest state agree on every counter.
        Machine first;
        Machine second;
        auto first_request =
            slice(first.cpu, false, std::chrono::nanoseconds { });
        auto second_request =
            slice(second.cpu, false, std::chrono::nanoseconds { });
        GuestExecutionCoordinator::execute(first_request);
        GuestExecutionCoordinator::execute(second_request);
        expect(first_request.result.ticks_consumed ==
                second_request.result.ticks_consumed,
            "two bounded runs consume the same ticks");
        expect(first.cpu.registers()[15] == second.cpu.registers()[15],
            "two bounded runs stop at the same pc");
    }
    {
        // Control: a cooperative slice consults the host clock, which is what
        // the bounded run above must never do. The same guest code, with no
        // host time left, yields to the host.
        Machine machine;
        auto request = slice(machine.cpu, true, std::chrono::nanoseconds { });
        GuestExecutionCoordinator::execute(request);
        expect(request.error == nullptr, "cooperative slice does not throw");
        expect(request.result.host_yield_checks != 0U,
            "cooperative slice checks the host clock");
        expect(request.result.host_yielded,
            "cooperative slice yields to the host clock");
    }

    if (failures != 0) {
        std::cerr << failures << " check(s) failed\n";
        return 1;
    }
    std::cout << "bounded slice rule: ok\n";
    return 0;
}
