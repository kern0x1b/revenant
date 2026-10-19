// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Build the guest GraphicsServices capability payload from firmware
// and device state.

#pragma once

#include <cstddef>
#include <filesystem>
#include <string_view>
#include <vector>

#include "foundation/device_model.hpp"

namespace shade {

inline constexpr std::string_view graphics_services_capability_object_name {
    "GSCapabilities"
};

// Build the Darwin GraphicsServices shared-memory payload from the firmware's
// SpringBoard capability plist and the selected device profile. The returned
// bytes begin with the 32-bit XML length expected by GSCopyCapabilities.
[[nodiscard]] std::vector<std::byte>
make_graphics_services_capability_memory(
    const std::filesystem::path& rootfs, const DeviceModel& profile);

} // namespace shade
