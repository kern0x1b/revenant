// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Model named PF_SYSTEM control endpoints and their peer identities.

#pragma once

#include <cstdint>
#include <optional>
#include <string_view>

namespace shade::bsd::kernel_control {

inline constexpr std::string_view descriptor_kind { "system-control-socket" };
inline constexpr std::string_view ip_interface_name { "com.apple.ipif" };
inline constexpr std::uint32_t ip_interface_identifier = 1;

struct Address {
    std::uint32_t identifier { };
    std::uint32_t unit { };
};

struct Endpoint {
    std::uint32_t socket_type { };
    std::optional<Address> peer;
    std::uint64_t transmitted_bytes { };
};

[[nodiscard]] std::optional<std::uint32_t> identifier_for_name(
    std::string_view name);
[[nodiscard]] std::optional<std::string_view> name_for_identifier(
    std::uint32_t identifier);

} // namespace shade::bsd::kernel_control
