// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Model the read, write and readiness behavior of a virtual null
// device.

#pragma once

#include <array>
#include <string_view>

namespace shade::bsd::null_device {

inline constexpr std::string_view descriptor_kind { "null" };
inline constexpr unsigned device_minor = 5;
inline constexpr std::array<std::string_view, 2> paths { "/dev/null",
    "/dev/autofs_nowait" };
inline constexpr std::array<std::string_view, 2> directory_names { "null",
    "autofs_nowait" };

[[nodiscard]] inline bool is_path(std::string_view candidate)
{
    for (const auto path : paths) {
        if (candidate == path) {
            return true;
        }
    }
    return false;
}

} // namespace shade::bsd::null_device
