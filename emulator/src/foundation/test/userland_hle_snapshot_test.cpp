// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "foundation/address_space.hpp"
#include "foundation/cpu.hpp"
#include "foundation/output.hpp"
#include "foundation/snapshot_io.hpp"
#include "foundation/userland_hle.hpp"

#include <cstddef>
#include <cstdint>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

namespace {

using emulator::AddressSpace;
using emulator::Cpu;
using emulator::Output;
using emulator::UserlandHleCall;
using emulator::UserlandHleRegistry;
using emulator::snapshot::FormatError;
using emulator::snapshot::RefusedError;
using emulator::snapshot::Reader;
using emulator::snapshot::Writer;

constexpr std::uint32_t code_address = 0x10000U;

int failures = 0;

void expect(bool condition, const std::string& what)
{
    if (condition)
        return;
    std::cerr << "FAIL: " << what << '\n';
    ++failures;
}

void register_wiring(UserlandHleRegistry& registry, const std::string& symbol)
{
    registry.register_function("libSystem.B.dylib", symbol,
        [](UserlandHleCall&) { });
}

std::vector<std::byte> save_memory_and_registry(
    AddressSpace& memory, const UserlandHleRegistry& registry)
{
    Writer out;
    memory.save(out);
    registry.save(out);
    return out.bytes();
}

void round_trip_keeps_strings_data_and_images()
{
    AddressSpace memory;
    std::ostringstream log;
    Output output { log };
    UserlandHleRegistry source { memory, output };
    register_wiring(source, "_strlen");
    source.record_loaded_image("/usr/lib/libSystem.B.dylib");
    const auto alpha = source.intern_string("alpha");
    static_cast<void>(source.allocate_data(32));
    const auto bytes = save_memory_and_registry(memory, source);

    AddressSpace restored_memory;
    std::ostringstream restored_log;
    Output restored_output { restored_log };
    UserlandHleRegistry restored { restored_memory, restored_output };
    register_wiring(restored, "_strlen");
    Reader in { bytes };
    restored_memory.load(in);
    restored.load(in);
    expect(in.at_end(), "the registry stream is consumed");

    expect(save_memory_and_registry(restored_memory, restored) == bytes,
        "saving the restored registry reproduces the same stream");
    expect(restored.image_loaded("libSystem.B.dylib"),
        "a loaded image stays loaded");
    expect(restored.intern_string("alpha") == alpha,
        "an interned string keeps its address");
    expect(restored.allocate_data(32) == source.allocate_data(32),
        "the data cursor continues where the source stopped");
}

void pending_thread_callback_is_refused()
{
    AddressSpace memory;
    Dynarmic::ExclusiveMonitor monitor { 1U };
    Cpu cpu { 0, memory, monitor };
    cpu.registers()[15] = code_address;
    cpu.set_cpsr(0x10U);
    std::ostringstream log;
    Output output { log };
    UserlandHleRegistry registry { memory, output };
    register_wiring(registry, "_strlen");
    expect(registry.prepare_thread_callback_return(cpu).has_value(),
        "prepare the thread callback return");
    expect(registry.bind_thread_callback(0, [](UserlandHleCall&) { }),
        "bind a thread callback");

    bool refused = false;
    std::string member;
    try {
        Writer out;
        registry.save(out);
    } catch (const RefusedError& error) {
        refused = true;
        member = error.member();
    }
    expect(refused, "a pending thread callback is refused");
    expect(member == "userland.thread_callbacks",
        "the refusal names userland.thread_callbacks");
}

void different_wiring_is_refused()
{
    AddressSpace memory;
    std::ostringstream log;
    Output output { log };
    UserlandHleRegistry source { memory, output };
    register_wiring(source, "_strlen");
    const auto bytes = save_memory_and_registry(memory, source);

    AddressSpace restored_memory;
    UserlandHleRegistry restored { restored_memory, output };
    register_wiring(restored, "_strcpy");
    bool threw = false;
    try {
        Reader in { bytes };
        restored_memory.load(in);
        restored.load(in);
    } catch (const FormatError&) {
        threw = true;
    }
    expect(threw, "a registry wired with other symbols is refused");
}

void truncated_stream_is_a_format_error()
{
    AddressSpace memory;
    std::ostringstream log;
    Output output { log };
    UserlandHleRegistry source { memory, output };
    register_wiring(source, "_strlen");
    static_cast<void>(source.intern_string("alpha"));
    const auto bytes = save_memory_and_registry(memory, source);
    const std::vector<std::byte> truncated { bytes.begin(),
        bytes.end() - 16 };

    AddressSpace restored_memory;
    UserlandHleRegistry restored { restored_memory, output };
    register_wiring(restored, "_strlen");
    bool threw = false;
    try {
        Reader in { truncated };
        restored_memory.load(in);
        restored.load(in);
    } catch (const FormatError&) {
        threw = true;
    }
    expect(threw, "a truncated registry stream throws FormatError");
}

}

int main()
{
    round_trip_keeps_strings_data_and_images();
    pending_thread_callback_is_refused();
    different_wiring_is_refused();
    truncated_stream_is_a_format_error();
    if (failures != 0) {
        std::cerr << failures << " userland HLE snapshot checks failed\n";
        return 1;
    }
    std::cout << "userland HLE snapshot checks passed\n";
    return 0;
}
