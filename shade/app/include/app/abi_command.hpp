// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Report the selected firmware ABI and device capabilities from the
// CLI.

#pragma once

#include <filesystem>
#include <optional>
#include <string>

namespace shade {

class Output;

void inspect_abi(const std::optional<std::filesystem::path>& rootfs,
    const std::optional<std::string>& ios_build, Output& output);

} // namespace shade
