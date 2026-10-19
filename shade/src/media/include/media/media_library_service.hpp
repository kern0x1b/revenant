// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Provide the legacy guest media-library service boundary and empty-
// catalog behavior.

#pragma once

#include <cstdint>
#include <filesystem>
#include <optional>
#include <string_view>
#include <vector>

namespace shade::media_library_service {

inline constexpr std::string_view bootstrap_name { "com.apple.musicplayer" };

// The legacy media provider returns an empty catalogue when no iTunesDB is
// present. Model that small service in the compatibility layer so clients do
// not have to cold-launch the full graphical Music application merely to ask
// for zero counts. A real database/provider always takes precedence.
[[nodiscard]] bool can_serve_empty_catalogue(
    const std::filesystem::path& rootfs);

// Returns the words following the 24-byte Mach header (NDR, result and
// operation-specific values) for the service's stable request ABI.
[[nodiscard]] std::optional<std::vector<std::uint32_t>> reply_payload(
    std::uint32_t request_identifier);

[[nodiscard]] bool is_request_identifier(std::uint32_t identifier);

} // namespace shade::media_library_service
