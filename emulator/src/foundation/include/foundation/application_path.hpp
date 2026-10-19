// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Classify system and data-volume application bundle paths.

#pragma once

#include <array>
#include <string_view>

namespace emulator {

inline constexpr std::array<std::string_view, 3> application_path_prefixes {
    "/Applications/", "/var/mobile/Applications/",
    "/private/var/mobile/Applications/"
};

[[nodiscard]] constexpr bool is_application_executable_path(
    std::string_view path)
{
    for (const auto prefix : application_path_prefixes) {
        if (path.starts_with(prefix))
            return true;
    }
    return false;
}

[[nodiscard]] constexpr bool is_setup_assistant_executable_path(
    std::string_view path)
{
    return path == "/Applications/Setup.app/Setup";
}

}
