// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "foundation/cpu.hpp"
#include "foundation/snapshot_io.hpp"

#include <cstddef>
#include <cstdint>
#include <iostream>
#include <string>
#include <vector>

namespace {

using emulator::AddressSpace;
using emulator::Cpu;
using emulator::CpuCluster;
using emulator::snapshot::FormatError;
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

void pattern(Cpu& cpu, std::uint32_t seed)
{
    for (std::size_t index = 0; index < cpu.registers().size(); ++index)
        cpu.registers()[index] = seed + static_cast<std::uint32_t>(index);
    for (std::size_t index = 0; index < cpu.extension_registers().size(); ++index)
        cpu.extension_registers()[index] = seed * 3U + static_cast<std::uint32_t>(index);
    cpu.set_cpsr(seed | 0x6000'0010U);
    cpu.set_fpscr(seed << 4U);
    cpu.set_cthread_self(seed + 0x2fe0'0000U);
}

bool same(const Cpu& expected, const Cpu& actual)
{
    return actual.registers() == expected.registers() &&
        actual.extension_registers() == expected.extension_registers() &&
        actual.cpsr() == expected.cpsr() && actual.fpscr() == expected.fpscr() &&
        actual.cthread_self() == expected.cthread_self();
}

std::vector<std::byte> save(CpuCluster& cluster)
{
    Writer out;
    cluster.save_state(out);
    return out.bytes();
}

void round_trip_restores_every_processor()
{
    AddressSpace source_memory;
    CpuCluster source { 2, source_memory };
    pattern(source.cpu(0), 0x100U);
    pattern(source.cpu(1), 0x200U);
    const auto bytes = save(source);

    AddressSpace target_memory;
    CpuCluster target { 2, target_memory };
    Reader in { bytes };
    target.load_state(in);
    expect(in.at_end(), "the cluster stream is consumed exactly");
    expect(target.size() == 2, "the restored cluster keeps two processors");
    expect(same(source.cpu(0), target.cpu(0)), "processor 0 round trips");
    expect(same(source.cpu(1), target.cpu(1)), "processor 1 round trips");
    expect(save(target) == bytes, "save, load and save reproduce the bytes");
}

void pending_halt_request_survives_round_trip()
{
    AddressSpace source_memory;
    CpuCluster source { 2, source_memory };
    pattern(source.cpu(0), 0x500U);
    source.cpu(1).halt(Dynarmic::HaltReason::UserDefined2);
    const auto bytes = save(source);

    AddressSpace target_memory;
    CpuCluster target { 2, target_memory };
    Reader in { bytes };
    target.load_state(in);
    expect(in.at_end(), "the halt request stream is consumed exactly");
    expect(target.cpu(0).consume_requested_halt_reason() == Dynarmic::HaltReason { },
        "a processor without a halt request restores none");
    expect(target.cpu(1).consume_requested_halt_reason() == Dynarmic::HaltReason::UserDefined2,
        "a pending halt request is restored");
}

void missing_processors_are_added()
{
    AddressSpace source_memory;
    CpuCluster source { 2, source_memory };
    pattern(source.cpu(1), 0x300U);
    const auto bytes = save(source);

    AddressSpace target_memory;
    CpuCluster target { 1, 2, target_memory };
    Reader in { bytes };
    target.load_state(in);
    expect(target.size() == 2, "a smaller cluster grows to the snapshot's size");
    expect(same(source.cpu(1), target.cpu(1)), "the added processor is restored");
}

void extra_processors_are_refused()
{
    AddressSpace source_memory;
    CpuCluster source { 1, source_memory };
    const auto bytes = save(source);

    AddressSpace target_memory;
    CpuCluster target { 3, target_memory };
    bool rejected = false;
    try {
        Reader in { bytes };
        target.load_state(in);
    } catch (const FormatError&) {
        rejected = true;
    }
    expect(rejected, "a cluster with more processors than the snapshot is refused");
}

void truncated_stream_is_a_format_error()
{
    AddressSpace source_memory;
    CpuCluster source { 2, source_memory };
    pattern(source.cpu(0), 0x400U);
    const auto bytes = save(source);
    const std::vector<std::byte> truncated(bytes.begin(), bytes.end() - 1);

    AddressSpace target_memory;
    CpuCluster target { 2, target_memory };
    bool rejected = false;
    try {
        Reader in { truncated };
        target.load_state(in);
    } catch (const FormatError&) {
        rejected = true;
    }
    expect(rejected, "a truncated cluster stream is a format error");
}

}

int main()
{
    round_trip_restores_every_processor();
    pending_halt_request_survives_round_trip();
    missing_processors_are_added();
    extra_processors_are_refused();
    truncated_stream_is_a_format_error();

    if (failures != 0) {
        std::cerr << failures << " CPU cluster snapshot checks failed\n";
        return 1;
    }
    std::cout << "CPU cluster snapshot checks passed\n";
    return 0;
}
