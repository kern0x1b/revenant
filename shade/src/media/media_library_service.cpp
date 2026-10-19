// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Provide the legacy guest media-library service boundary and empty-
// catalog behavior.

#include "media/media_library_service.hpp"

namespace shade::media_library_service {

bool can_serve_empty_catalogue(const std::filesystem::path& rootfs)
{
    if (rootfs.empty())
        return false;
    std::error_code error;
    const auto database =
        rootfs / "var/root/Media/iTunes_Control/iTunes/iTunesDB";
    const auto present = std::filesystem::exists(database, error);
    return !error && !present;
}

std::optional<std::vector<std::uint32_t>> reply_payload(
    std::uint32_t request_identifier)
{
    constexpr std::uint32_t ndr_word0 = 0;
    constexpr std::uint32_t ndr_word1 = 1;
    constexpr std::uint32_t success = 0;
    switch (request_identifier) {
    case 990000U:
        return std::vector<std::uint32_t> { ndr_word0, ndr_word1, success, 1U };
    case 990005U:
        return std::vector<std::uint32_t> { ndr_word0, ndr_word1, success, 0U,
            0U };
    case 990001U:
        return std::vector<std::uint32_t> { ndr_word0, ndr_word1, success };
    default:
        return std::nullopt;
    }
}

bool is_request_identifier(std::uint32_t identifier)
{
    return identifier >= 990000U && identifier < 990100U;
}

}
