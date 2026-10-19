// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define the firmware capability profile for the initial Darwin
// apple-vector entries.

#pragma once

#include <cstdint>

namespace shade {

enum class DarwinInitialAppleVectorAbi : std::uint8_t {
    KeyedExecutablePath,
    LegacyExecutablePath,
};

}
