// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Read firmware metadata used to identify the guest Darwin
// environment.

#pragma once

#include <filesystem>
#include <string>

namespace shade {

[[nodiscard]] std::string read_darwin_build_version(
    const std::filesystem::path& rootfs);

} // namespace shade
