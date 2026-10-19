// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Reads a guest process's dyld image list out of its own memory.

#pragma once

#include "foundation/address_space.hpp"
#include "foundation/block_profile.hpp"

#include <cstdint>

namespace emulator {

[[nodiscard]] GuestImageTable read_guest_image_table(
    const AddressSpace& memory, std::uint32_t all_image_info_address);

}
