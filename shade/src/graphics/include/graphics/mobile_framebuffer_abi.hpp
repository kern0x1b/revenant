// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define observed IOMobileFramebuffer layer and swap argument
// layouts.

#pragma once

#include <cstddef>
#include <cstdint>

namespace shade::mobile_framebuffer_abi {

// Confirmed by the iPhone OS 1.0 IOMobileFramebuffer implementation: layer
// indices greater than 2 are rejected before the swap structure is updated.
inline constexpr std::uint32_t layer_count = 3;
inline constexpr std::uint32_t maximum_layer_index = layer_count - 1U;

// IOMobileFramebufferSwapSetLayer follows the ARM ABI below. The first CGRect
// starts in r3 and continues on the stack; the second CGRect and flags follow.
inline constexpr std::size_t source_x_argument = 3;
inline constexpr std::size_t source_y_argument = 4;
inline constexpr std::size_t source_width_argument = 5;
inline constexpr std::size_t source_height_argument = 6;
inline constexpr std::size_t destination_x_argument = 7;
inline constexpr std::size_t destination_y_argument = 8;
inline constexpr std::size_t destination_width_argument = 9;
inline constexpr std::size_t destination_height_argument = 10;
inline constexpr std::size_t flags_argument = 11;

} // namespace shade::mobile_framebuffer_abi
