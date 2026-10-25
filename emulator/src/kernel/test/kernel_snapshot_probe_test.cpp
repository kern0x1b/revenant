// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "foundation/address_space.hpp"
#include "foundation/output.hpp"
#include "kernel/kernel.hpp"
#include "kernel/snapshot_census.hpp"
#include "kernel/snapshot_ledger.hpp"
#include "kernel_snapshot_booted_members.hpp"

#include <algorithm>
#include <array>
#include <cstddef>
#include <iostream>
#include <sstream>
#include <string>
#include <string_view>
#include <vector>

namespace {

using emulator::AddressSpace;
using emulator::CompatibilityKernel;
using emulator::CompatibilityKernelSnapshot;
using emulator::Output;
using emulator::snapshot_ledger::open_members;
using emulator::snapshot_ledger::refused_members;
using emulator::snapshot_ledger::saved_members;
using emulator::snapshot_ledger::wired_members;

int failures = 0;
std::size_t checked = 0;

void check_accounted(const std::string& name)
{
    ++checked;
    const std::string_view view { name };
    if (std::ranges::find(saved_members, view) != saved_members.end() ||
        std::ranges::find(open_members, view) != open_members.end() ||
        std::ranges::find(wired_members, view) != wired_members.end() ||
        std::ranges::find(refused_members, view) != refused_members.end()) {
        return;
    }
    std::cerr << "FAIL: populated member " << name
              << " has no serializer and no named refusal\n";
    ++failures;
}

struct Machine {
    AddressSpace memory;
    std::ostringstream log;
    Output output { log };
    CompatibilityKernel kernel { memory, output };
};

void check(bool condition, const std::string& what)
{
    if (condition)
        return;
    std::cerr << "FAIL: " << what << '\n';
    ++failures;
}

bool save_refuses(CompatibilityKernel& kernel, const std::string& member)
{
    emulator::snapshot::Writer out;
    try {
        kernel.save_kernel_bookkeeping(out);
    } catch (const emulator::snapshot::RefusedError& error) {
        return std::string { error.what() }.find(member) != std::string::npos;
    }
    return false;
}

void check_live_continuation_is_refused()
{
    Machine populated;
    CompatibilityKernelSnapshot::add_pending_timer(populated.kernel);
    check(save_refuses(populated.kernel, "ck.pending_timers_"),
        "a pending timer makes the bookkeeping save refuse by name");

    Machine empty;
    emulator::snapshot::Writer empty_out;
    empty.kernel.save_kernel_bookkeeping(empty_out);
    const auto bytes = empty_out.bytes();
    CompatibilityKernelSnapshot::add_pending_timer(empty.kernel);
    emulator::snapshot::Reader in { bytes };
    bool rejected = false;
    try {
        empty.kernel.load_kernel_bookkeeping(in);
    } catch (const emulator::snapshot::FormatError&) {
        rejected = true;
    }
    check(rejected,
        "loading bookkeeping into a kernel with a pending timer throws FormatError");
}

}

void check_uncovered_members_are_refused_by_name(
    CompatibilityKernel& kernel, AddressSpace& memory)
{
    const auto populated = CompatibilityKernelSnapshot::populated_members(kernel);
    bool refused = false;
    std::string member;
    try {
        emulator::require_covered_members(kernel, memory);
    } catch (const emulator::snapshot::RefusedError& error) {
        refused = true;
        member = error.member();
    }
    check(refused, "a kernel with uncovered populated members is refused");
    check(std::ranges::find(populated, member) != populated.end(),
        "the refusal names a populated member");
}

int main()
{
    AddressSpace memory;
    std::ostringstream log;
    Output output { log };
    CompatibilityKernel kernel { memory, output };
    check_live_continuation_is_refused();
    check_uncovered_members_are_refused_by_name(kernel, memory);
    for (const auto& name :
        CompatibilityKernelSnapshot::populated_members(kernel)) {
        check_accounted(name);
    }
    for (const auto& name : CompatibilityKernelSnapshot::populated_memory(memory)) {
        check_accounted(name);
    }
    for (const auto name : emulator::booted_populated_members) {
        check_accounted(std::string { name });
    }
    if (failures != 0) {
        std::cerr << failures << " checks failed\n";
        return 1;
    }
    std::cout << "kernel snapshot probe checks passed: " << checked
              << " populated members checked, "
              << emulator::booted_populated_members.size()
              << " booted members, ledger has "
              << saved_members.size() << " saved, " << open_members.size()
              << " open, " << wired_members.size() << " wired and "
              << refused_members.size() << " refused entries\n";
    return 0;
}
