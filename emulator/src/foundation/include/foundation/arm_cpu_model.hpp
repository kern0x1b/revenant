// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Describe guest ARM core capabilities and unpredictable-instruction
// policies.

#pragma once

#include <cstdint>
#include <memory>

namespace shade {

inline constexpr std::uint32_t arm_mach_cpu_type = 12U;

enum class ArmArchitectureVersion : std::uint8_t {
    Armv6K,
    Armv7,
};

enum class ArmCpuModelKind : std::uint8_t {
    Arm1176JzfS,
    CortexA8,
    CortexA9,
};

enum class ArmUnpredictableInstructionPolicy : std::uint8_t {
    Strict,
    CortexA8,
};

[[nodiscard]] constexpr ArmArchitectureVersion arm_architecture_for_model(
    ArmCpuModelKind kind) noexcept
{
    switch (kind) {
    case ArmCpuModelKind::Arm1176JzfS:
        return ArmArchitectureVersion::Armv6K;
    case ArmCpuModelKind::CortexA8:
    case ArmCpuModelKind::CortexA9:
        return ArmArchitectureVersion::Armv7;
    }
    return ArmArchitectureVersion::Armv6K;
}

[[nodiscard]] constexpr std::uint32_t mach_cpu_subtype_for_architecture(
    ArmArchitectureVersion version) noexcept
{
    switch (version) {
    case ArmArchitectureVersion::Armv6K:
        return 6U;
    case ArmArchitectureVersion::Armv7:
        return 9U;
    }
    return 6U;
}

class ArmCpuModel {
public:
    virtual ~ArmCpuModel() = default;

    [[nodiscard]] virtual ArmCpuModelKind kind() const noexcept
    {
        return architecture_version() == ArmArchitectureVersion::Armv7
                   ? ArmCpuModelKind::CortexA8
                   : ArmCpuModelKind::Arm1176JzfS;
    }

    [[nodiscard]] virtual ArmArchitectureVersion
    architecture_version() const noexcept = 0;
    [[nodiscard]] virtual ArmUnpredictableInstructionPolicy
    unpredictable_instruction_policy() const noexcept = 0;
    [[nodiscard]] virtual std::uint32_t ticks_per_second() const noexcept = 0;
    [[nodiscard]] virtual std::uint64_t ticks_for_instruction(bool thumb,
        std::uint32_t address, std::uint32_t instruction) const noexcept = 0;
};

[[nodiscard]] std::unique_ptr<ArmCpuModel> make_arm_cpu_model(
    ArmCpuModelKind kind, std::uint32_t clock_hz);

[[nodiscard]] const ArmCpuModel& default_arm_cpu_model();

}
