// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Resolve virtual kernel-control endpoint names and numeric
// identities.

#include "kernel/kernel_control.hpp"

namespace shade::bsd::kernel_control {

std::optional<std::uint32_t> identifier_for_name(std::string_view name)
{
    if (name == ip_interface_name)
        return ip_interface_identifier;
    return std::nullopt;
}

std::optional<std::string_view> name_for_identifier(std::uint32_t identifier)
{
    if (identifier == ip_interface_identifier)
        return ip_interface_name;
    return std::nullopt;
}

} // namespace shade::bsd::kernel_control
