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

[[nodiscard]] bool can_serve_empty_catalogue(
    const std::filesystem::path& rootfs);

[[nodiscard]] std::optional<std::vector<std::uint32_t>> reply_payload(
    std::uint32_t request_identifier);

[[nodiscard]] bool is_request_identifier(std::uint32_t identifier);

}
