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

[[nodiscard]] bool emulate_arm_unpredictable_instruction(
    ArmUnpredictableInstructionPolicy profile, bool thumb,
    std::uint32_t instruction,
    std::span<std::uint32_t, 64> extension_registers) noexcept;

}
