// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Own a boot session and coordinate guest scheduling, lifecycle, time
// and shutdown.

#pragma once

#include <utility>

#include "runtime/boot_options.hpp"

namespace shade {

class Output;
class SessionHost;

// Owns one boot, including guest scheduling, lifecycle, time and shutdown.
// Options and host services are independent of command-line argument syntax.
class EmulatorSession {
public:
    EmulatorSession(BootOptions options, SessionHost& host, Output& output)
        : options_ { std::move(options) }
        , host_ { host }
        , output_ { output }
    {
    }
    EmulatorSession(const EmulatorSession&) = delete;
    EmulatorSession& operator=(const EmulatorSession&) = delete;

    void run();

private:
    BootOptions options_;
    SessionHost& host_;
    Output& output_;
    bool started_ { };
};

} // namespace shade
