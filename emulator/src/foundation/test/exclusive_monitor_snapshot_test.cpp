// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "foundation/address_space.hpp"
#include "foundation/cpu.hpp"
#include "foundation/memory_permission.hpp"
#include "foundation/snapshot_io.hpp"

#include <cstddef>
#include <cstdint>
#include <iostream>
#include <string>
#include <vector>

namespace {

using emulator::AddressSpace;
using emulator::Cpu;
using emulator::MemoryPermission;
using emulator::load_exclusive_monitor;
using emulator::save_exclusive_monitor;
using emulator::snapshot::FormatError;
using emulator::snapshot::Reader;
using emulator::snapshot::Writer;

constexpr std::uint32_t code_address = 0x10000U;
constexpr std::uint32_t data_address = 0x20000U;
constexpr std::uint32_t ldrex_r1_from_r0 = 0xe190'1f9fU;
constexpr std::uint32_t strex_r2_r3_to_r0 = 0xe180'2f93U;

int failures = 0;

void expect(bool condition, const std::string& what)
{
    if (condition)
        return;
    std::cerr << "FAIL: " << what << '\n';
    ++failures;
}

struct Machine {
    AddressSpace memory;
    Dynarmic::ExclusiveMonitor monitor { 1U };
    Cpu cpu { 0, memory, monitor };

    Machine()
    {
        expect(memory.map(code_address, AddressSpace::page_size,
                   MemoryPermission::Read | MemoryPermission::Write |
                       MemoryPermission::Execute),
            "map the code page");
        expect(memory.map(data_address, AddressSpace::page_size,
                   MemoryPermission::Read | MemoryPermission::Write),
            "map the data page");
        expect(memory.write32(code_address, ldrex_r1_from_r0),
            "write the ldrex");
        expect(memory.write32(code_address + 4U, strex_r2_r3_to_r0),
            "write the strex");
        cpu.registers()[0] = data_address;
        cpu.registers()[3] = 0x1234U;
        cpu.registers()[15] = code_address;
        cpu.set_cpsr(0x10U);
    }
};

void run_one(Cpu& cpu)
{
    static_cast<void>(cpu.step());
}

void control_strex_succeeds_without_a_save()
{
    Machine machine;
    run_one(machine.cpu);
    run_one(machine.cpu);
    expect(machine.cpu.registers()[2] == 0U,
        "a strex after an ldrex with no save succeeds");
}

void save_drops_the_reservation_of_the_saved_machine()
{
    Machine machine;
    run_one(machine.cpu);
    Writer out;
    save_exclusive_monitor(out, machine.monitor);
    run_one(machine.cpu);
    expect(machine.cpu.registers()[2] == 1U,
        "a strex after a save fails on the saved machine");
}

void restored_monitor_starts_without_a_reservation()
{
    Machine source;
    run_one(source.cpu);
    Writer out;
    save_exclusive_monitor(out, source.monitor);
    const auto bytes = out.bytes();

    Machine restored;
    run_one(restored.cpu);
    Reader in { bytes };
    load_exclusive_monitor(in, restored.monitor);
    expect(in.at_end(), "the monitor stream is consumed");
    restored.cpu.registers() = source.cpu.registers();
    restored.cpu.set_cpsr(source.cpu.cpsr());
    run_one(restored.cpu);
    expect(restored.cpu.registers()[2] == 1U,
        "a strex after a restore fails because no reservation came back");
}

void processor_count_mismatch_is_refused()
{
    Dynarmic::ExclusiveMonitor saved { 1U };
    Writer out;
    save_exclusive_monitor(out, saved);
    const auto bytes = out.bytes();
    Dynarmic::ExclusiveMonitor wider { 2U };
    bool threw = false;
    try {
        Reader in { bytes };
        load_exclusive_monitor(in, wider);
    } catch (const FormatError&) {
        threw = true;
    }
    expect(threw, "a monitor with a different processor count is refused");
}

void truncated_stream_is_a_format_error()
{
    const std::vector<std::byte> empty;
    Dynarmic::ExclusiveMonitor monitor { 1U };
    bool threw = false;
    try {
        Reader in { empty };
        load_exclusive_monitor(in, monitor);
    } catch (const FormatError&) {
        threw = true;
    }
    expect(threw, "a truncated monitor stream throws FormatError");
}

}

int main()
{
    control_strex_succeeds_without_a_save();
    save_drops_the_reservation_of_the_saved_machine();
    restored_monitor_starts_without_a_reservation();
    processor_count_mismatch_is_refused();
    truncated_stream_is_a_format_error();
    if (failures != 0) {
        std::cerr << failures << " exclusive monitor snapshot checks failed\n";
        return 1;
    }
    std::cout << "exclusive monitor snapshot checks passed\n";
    return 0;
}
