// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Describe guest touch phases and coordinates independently of host
// input APIs.

#pragma once

#include <cstdint>

namespace shade {

enum class TouchPhase : std::uint8_t {
    Down,
    Move,
    Up,
    Cancel,
};

struct TouchInput {
    TouchPhase phase { TouchPhase::Down };
    float x { };
    float y { };
};

} // namespace shade
