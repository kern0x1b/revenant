// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Guest-free check that each way the first process can die has its own named
// message, and that every message ends the run as a failure.

#include "initial_process_failure.hpp"

#include <cstdint>
#include <iostream>
#include <set>
#include <string>

namespace {

using shade::runtime_detail::InitialProcessFailure;
using Kind = InitialProcessFailure::Kind;

int failures = 0;

void expect(bool condition, const std::string& what)
{
    if (condition)
        return;
    std::cerr << "FAIL: " << what << '\n';
    ++failures;
}

std::string message_of(Kind kind)
{
    constexpr std::uint32_t pc = 0x8000;
    constexpr std::uint32_t address = 0x4000;
    return shade::runtime_detail::initial_process_failure_message(
        { kind, 1, pc, address });
}

} // namespace

int main()
{
    expect(shade::runtime_detail::initial_process_failure_message(
               { Kind::UndefinedInstruction, 1, 0x8000, 0 }) ==
            "pid 1 died of an undefined instruction at 0x8000; the run failed",
        "undefined instruction message");
    expect(message_of(Kind::DataAbort).find("a data abort at 0x8000 accessing "
                                            "0x4000; the run failed") !=
            std::string::npos,
        "data abort message");
    expect(message_of(Kind::PrefetchAbort).find("a prefetch abort fetching "
                                                "0x4000; the run failed") !=
            std::string::npos,
        "prefetch abort message");
    expect(message_of(Kind::Breakpoint).find("a breakpoint at 0x8000; the run "
                                             "failed") != std::string::npos,
        "breakpoint message");
    expect(message_of(Kind::UnclassifiedStop).find("an unclassified fatal stop "
                                                   "at 0x8000; the run failed") !=
            std::string::npos,
        "unclassified stop message");
    expect(shade::runtime_detail::initial_process_failure_message(
               { Kind::Signal, 1, 0, 9 }) ==
            "pid 1 died of signal 9; the run failed",
        "signal message");

    std::set<std::string> distinct;
    for (const auto kind : { Kind::UndefinedInstruction, Kind::DataAbort,
             Kind::PrefetchAbort, Kind::Breakpoint, Kind::UnclassifiedStop }) {
        const auto text = message_of(kind);
        expect(text.rfind("pid 1 died of ", 0) == 0,
            "message names the pid: " + text);
        expect(text.find("; the run failed") != std::string::npos,
            "message fails the run: " + text);
        distinct.insert(text);
    }
    expect(distinct.size() == 5, "each fatal stop kind has its own message");

    if (failures != 0) {
        std::cerr << failures << " check(s) failed\n";
        return 1;
    }
    std::cout << "initial process failure messages: ok\n";
    return 0;
}
