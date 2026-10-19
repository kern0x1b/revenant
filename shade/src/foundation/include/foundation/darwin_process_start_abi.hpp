// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define the firmware capability profile for the initial Darwin
// apple-vector entries.

#pragma once

#include <cstdint>

namespace shade {

// Darwin loaders differ in whether apple[0] is a bare path or a keyed
// executable_path entry. Select the audited loader contract through a named
// profile rather than inferring it from a firmware or application name.
enum class DarwinInitialAppleVectorAbi : std::uint8_t {
    KeyedExecutablePath,
    LegacyExecutablePath,
};

} // namespace shade
