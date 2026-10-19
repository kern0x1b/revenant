// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Load baseband transport replay records and write captured
// exchanges.

#pragma once

#include <cstddef>
#include <filesystem>
#include <span>
#include <vector>

namespace shade::bsd::baseband_device {

inline constexpr std::size_t maximum_replay_bytes = 64U * 1024U * 1024U;

[[nodiscard]] std::vector<std::byte> load_replay_file(
    const std::filesystem::path& path);
void write_capture_file(
    const std::filesystem::path& path, std::span<const std::byte> bytes);

} // namespace shade::bsd::baseband_device
