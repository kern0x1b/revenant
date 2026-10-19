// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Encode device-profile hardware values for guest sysctl queries.

#include "kernel/darwin_sysctl.hpp"

namespace shade::darwin::sysctl {

std::optional<std::string_view> hardware_string(
    std::uint32_t selector, std::string_view machine, std::string_view model)
{
    switch (selector) {
    case hardware_machine:
        return machine;
    case hardware_model:
        return model;
    default:
        return std::nullopt;
    }
}

} // namespace shade::darwin::sysctl
