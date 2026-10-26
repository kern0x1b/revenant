// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "runtime/session_state.hpp"

#include <cstddef>
#include <iostream>
#include <string>

#include "foundation/snapshot_io.hpp"

namespace {

int failures = 0;

void expect(bool condition, const std::string& what)
{
    if (condition)
        return;
    std::cerr << "FAIL: " << what << '\n';
    ++failures;
}

std::string refusal_of(std::size_t runtime_count)
{
    try {
        emulator::require_single_process(runtime_count);
    } catch (const emulator::snapshot::RefusedError& error) {
        return error.member();
    }
    return {};
}

void one_process_is_accepted()
{
    expect(refusal_of(1).empty(), "a session with one process is not refused");
}

void several_processes_are_refused_by_name()
{
    expect(refusal_of(0) == "runtime.children", "no process is refused by name");
    expect(refusal_of(2) == "runtime.children", "two processes are refused by name");
    expect(refusal_of(63) == "runtime.children", "a multi-process session is refused by name");
}

}

int main()
{
    one_process_is_accepted();
    several_processes_are_refused_by_name();
    if (failures != 0) {
        std::cerr << failures << " failure(s)\n";
        return 1;
    }
    return 0;
}
