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

using emulator::CpuThreadState;
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

std::vector<std::byte> save_state(const CpuThreadState& state)
{
    Writer out;
    state.save(out);
    return out.bytes();
}

CpuThreadState patterned_state()
{
    CpuThreadState state;
    for (std::size_t index = 0; index < state.registers.size(); ++index)
        state.registers[index] = static_cast<std::uint32_t>(0x1000U + index);
    for (std::size_t index = 0; index < state.extension_registers.size(); ++index)
        state.extension_registers[index] = static_cast<std::uint32_t>(0xa5000000U + index);
    state.cpsr = 0x6000'0010U;
    state.fpscr = 0x0300'0000U;
    state.cthread_self = 0x2fe0'0000U;
    return state;
}

void expect_same(const CpuThreadState& expected, const CpuThreadState& actual)
{
    expect(actual.registers == expected.registers, "registers");
    expect(actual.extension_registers == expected.extension_registers,
        "extension registers");
    expect(actual.cpsr == expected.cpsr, "cpsr");
    expect(actual.fpscr == expected.fpscr, "fpscr");
    expect(actual.cthread_self == expected.cthread_self, "cthread_self");
}

void round_trip_keeps_every_field()
{
    const auto source = patterned_state();
    const auto bytes = save_state(source);
    CpuThreadState restored;
    Reader in { bytes };
    restored.load(in);
    expect(in.at_end(), "the stream is consumed");
    expect_same(source, restored);
}

void absent_cthread_self_round_trips()
{
    auto source = patterned_state();
    source.cthread_self.reset();
    CpuThreadState restored;
    restored.cthread_self = 7U;
    const auto bytes = save_state(source);
    Reader in { bytes };
    restored.load(in);
    expect_same(source, restored);
}

void layout_has_a_fixed_width()
{
    expect(save_state(patterned_state()).size() == 16U * 4U + 64U * 4U + 4U + 4U + 1U + 4U,
        "a present cthread_self adds one flag and one word");
    CpuThreadState absent;
    expect(save_state(absent).size() == 16U * 4U + 64U * 4U + 4U + 4U + 1U,
        "an absent cthread_self is one flag");
}

void truncated_state_is_a_format_error()
{
    const auto bytes = save_state(patterned_state());
    std::vector<std::byte> truncated { bytes.begin(), bytes.begin() + 100 };
    bool threw = false;
    try {
        CpuThreadState restored;
        Reader in { truncated };
        restored.load(in);
    } catch (const FormatError&) {
        threw = true;
    }
    expect(threw, "a truncated thread state throws FormatError");
}

}

int main()
{
    round_trip_keeps_every_field();
    absent_cthread_self_round_trips();
    layout_has_a_fixed_width();
    truncated_state_is_a_format_error();
    if (failures != 0) {
        std::cerr << failures << " cpu thread state snapshot checks failed\n";
        return 1;
    }
    std::cout << "cpu thread state snapshot checks passed\n";
    return 0;
}
