// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Describe process lifecycle and execution snapshots for diagnostics.

#pragma once

#include <cstdint>
#include <string>

namespace shade {

// A copied observation of the guest process table. Clients never receive a
// mutable process record or hold a kernel lock while formatting diagnostics.
struct ProcessSnapshot {
    std::uint32_t pid { };
    std::uint32_t parent_pid { };
    std::string command;
    std::string executable_path;
    bool exited { };
    bool pid_suspended { };
    bool signal_stopped { };
    std::uint32_t exit_status { };
    std::uint32_t termination_signal { };
};

} // namespace shade
