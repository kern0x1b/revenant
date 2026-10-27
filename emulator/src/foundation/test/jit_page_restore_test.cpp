// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "foundation/address_space.hpp"
#include "foundation/cpu.hpp"
#include "foundation/guest_execution_coordinator.hpp"
#include "foundation/memory_permission.hpp"
#include "foundation/snapshot_io.hpp"

#include <chrono>
#include <cstddef>
#include <cstdint>
#include <iostream>
#include <string>
#include <vector>

namespace {

using emulator::AddressSpace;
using emulator::Cpu;
using emulator::CpuCluster;
using emulator::GuestExecutionCoordinator;
using emulator::GuestExecutionRequest;
using emulator::MemoryPermission;
using emulator::snapshot::Reader;
using emulator::snapshot::Writer;

int failures = 0;

void expect(bool condition, const std::string& what)
{
    if (condition)
        return;
    std::cerr << "FAIL: " << what << '\n';
    ++failures;
}

constexpr std::uint32_t code_address = 0x1000U;
constexpr std::uint64_t prefix_ticks = 1'000U;
constexpr std::uint64_t continuation_ticks = 5'000U;

void map_counting_loop(AddressSpace& memory)
{
    memory.map(code_address, AddressSpace::page_size,
        MemoryPermission::Read | MemoryPermission::Write |
            MemoryPermission::Execute);
    memory.write32(code_address, 0xe280'0001U);
    memory.write32(code_address + 4U, 0xeaff'fffdU);
}

void run(Cpu& cpu, std::uint64_t ticks)
{
    auto request = GuestExecutionRequest { &cpu, 0, ticks,
        std::chrono::nanoseconds { }, false, false };
    GuestExecutionCoordinator::execute(request);
    expect(request.error == nullptr, "a bounded run does not throw");
    expect(request.result.ticks_consumed == ticks,
        "a bounded run consumes exactly its tick budget");
}

void restored_machine_runs_the_same_guest_code(bool parallel_access,
    std::size_t processor_count)
{
    AddressSpace source_memory;
    map_counting_loop(source_memory);
    source_memory.set_parallel_access(parallel_access);
    CpuCluster source_cluster { processor_count, source_memory };
    auto& source_cpu = source_cluster.cpu(0);
    source_cpu.registers()[15] = code_address;
    source_cpu.set_cpsr(0x10U);
    run(source_cpu, prefix_ticks);
    const auto prefix_counter = source_cpu.registers()[0];
    const auto prefix_pc = source_cpu.registers()[15];

    Writer out;
    source_memory.save(out);
    source_cluster.save_state(out);
    const auto bytes = out.bytes();
    run(source_cpu, continuation_ticks);

    AddressSpace restored_memory;
    CpuCluster restored_cluster { processor_count, restored_memory };
    Reader in { bytes };
    restored_memory.load(in);
    restored_cluster.load_state(in);
    expect(in.at_end(), "the machine stream is consumed");

    if (!parallel_access) {
        const auto* read_table = restored_memory.jit_read_page_table();
        expect(read_table != nullptr &&
                read_table[code_address / AddressSpace::page_size] != nullptr,
            "the restored read table maps the code page rebuilt from the pages");
    }

    auto& restored_cpu = restored_cluster.cpu(0);
    expect(restored_cpu.registers()[0] == prefix_counter &&
            restored_cpu.registers()[15] == prefix_pc,
        "the restored processor resumes at the saved registers");
    run(restored_cpu, continuation_ticks);
    expect(restored_cpu.registers()[0] == source_cpu.registers()[0] &&
            restored_cpu.registers()[15] == source_cpu.registers()[15],
        "the restored machine ends in the same state as the original");
}

}

int main()
{
    restored_machine_runs_the_same_guest_code(false, 1U);
    restored_machine_runs_the_same_guest_code(true, 2U);
    if (failures != 0) {
        std::cerr << failures << " JIT page restore checks failed\n";
        return 1;
    }
    std::cout << "JIT page restore checks passed\n";
    return 0;
}
