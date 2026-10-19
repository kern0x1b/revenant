// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Apply the selected ARM core policy to unpredictable instruction
// results.

#pragma once

#include <cstdint>
#include <span>

#include "foundation/arm_cpu_model.hpp"

namespace shade {

// Applies the selected core's deterministic behavior for an instruction that
// Umbra reports as unpredictable. Thumb-2 instructions use the decoder
// order `first_halfword << 16 | second_halfword`; ARM instructions use their
// architectural 32-bit encoding. Returns false when the strict exception path
// must remain in effect.
[[nodiscard]] bool emulate_arm_unpredictable_instruction(
    ArmUnpredictableInstructionPolicy profile, bool thumb,
    std::uint32_t instruction,
    std::span<std::uint32_t, 64> extension_registers) noexcept;

} // namespace shade
