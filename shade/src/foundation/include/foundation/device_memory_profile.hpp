// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#pragma once

#include <cstdint>

namespace shade {

struct DeviceMemoryProfile {
    std::uint64_t ram_bytes;
    // Nominal flash capacity for volume geometry. The guest sees this device
    // property, never the host filesystem's capacity.
    std::uint64_t storage_bytes;
    // Guest-visible memory after platform-reserved carve-outs. Zero follows
    // ram_bytes when the model has no separate memory-size boundary.
    std::uint64_t usable_ram_bytes { };
};

} // namespace shade
