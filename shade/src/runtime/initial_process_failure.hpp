// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Name the way the first process ended when it did not exit by itself.

#pragma once

#include <cstdint>
#include <sstream>
#include <string>

namespace shade::runtime_detail {

struct InitialProcessFailure {
    enum class Kind : std::uint8_t {
        UndefinedInstruction,
        DataAbort,
        PrefetchAbort,
        Breakpoint,
        UnclassifiedStop,
        Signal,
    };
    Kind kind { };
    std::uint32_t pid { };
    std::uint32_t pc { };
    std::uint32_t address { };
};

[[nodiscard]] inline std::string initial_process_failure_message(
    const InitialProcessFailure& failure)
{
    using Kind = InitialProcessFailure::Kind;
    std::ostringstream message;
    message << "pid " << failure.pid << " died of ";
    switch (failure.kind) {
    case Kind::UndefinedInstruction:
        message << "an undefined instruction at 0x" << std::hex << failure.pc;
        break;
    case Kind::DataAbort:
        message << "a data abort at 0x" << std::hex << failure.pc
                << " accessing 0x" << failure.address;
        break;
    case Kind::PrefetchAbort:
        message << "a prefetch abort fetching 0x" << std::hex
                << failure.address;
        break;
    case Kind::Breakpoint:
        message << "a breakpoint at 0x" << std::hex << failure.pc;
        break;
    case Kind::UnclassifiedStop:
        message << "an unclassified fatal stop at 0x" << std::hex << failure.pc;
        break;
    case Kind::Signal:
        message << "signal " << std::dec << failure.address;
        break;
    }
    message << "; the run failed";
    return message.str();
}

}
