// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Describe guest ARM core capabilities and unpredictable-instruction
// policies.

#include "foundation/arm_cpu_model.hpp"

#include <array>
#include <stdexcept>

namespace shade {
namespace {

    struct TimingRule {
        std::uint32_t mask;
        std::uint32_t value;
        std::uint8_t ticks;
    };

    constexpr std::array arm1176_arm_rules {
        TimingRule { 0x0FFFFFF0U, 0x012FFF10U, 1 },
        TimingRule { 0x0FFFFFF0U, 0x012FFF30U, 1 },
        TimingRule { 0x0FFF0FF0U, 0x016F0F10U, 1 },
        TimingRule { 0x0F9000F0U, 0x01000050U, 1 },
        TimingRule { 0x0FFFFFF0U, 0x01600070U, 8 },
        TimingRule { 0x0FF000F0U, 0x01200070U, 8 },
        TimingRule { 0x0F000000U, 0x0F000000U, 8 },
        TimingRule { 0x0FB00FF0U, 0x01000090U, 2 },
        TimingRule { 0x0F9000F0U, 0x00900090U, 6 },
        TimingRule { 0x0F8000F0U, 0x00800090U, 3 },
        TimingRule { 0x0FD000F0U, 0x00100090U, 5 },
        TimingRule { 0x0FC000F0U, 0x00000090U, 2 },
        TimingRule { 0x0E000090U, 0x00000010U, 2 },
        TimingRule { 0x0FFFFFFFU, 0x01A00000U, 2 },
        TimingRule { 0x0FFFFFFFU, 0x0320F000U, 2 },
    };

    constexpr std::array arm1176_thumb16_rules {
        TimingRule { 0x0000FF00U, 0x0000BE00U, 8 },
        TimingRule { 0x0000FF00U, 0x0000DF00U, 8 },
        TimingRule { 0x0000FFC0U, 0x00004340U, 2 },
        TimingRule { 0x0000FFFFU, 0x000046C0U, 2 },
        TimingRule { 0x0000FFFFU, 0x0000BF00U, 2 },
    };

    template <std::size_t Size>
    [[nodiscard]] constexpr std::uint64_t lookup_ticks(
        std::uint32_t instruction,
        const std::array<TimingRule, Size>& rules) noexcept
    {
        for (const auto& rule : rules) {
            if ((instruction & rule.mask) == rule.value) {
                return rule.ticks;
            }
        }
        return 1;
    }

    class Arm1176CpuModel final : public ArmCpuModel {
    public:
        explicit Arm1176CpuModel(std::uint32_t clock_hz)
            : clock_hz_ { clock_hz }
        {
            if (clock_hz_ == 0) {
                throw std::invalid_argument {
                    "instruction timing clock must be non-zero"
                };
            }
        }

        [[nodiscard]] ArmArchitectureVersion
        architecture_version() const noexcept override
        {
            return ArmArchitectureVersion::Armv6K;
        }

        [[nodiscard]] ArmUnpredictableInstructionPolicy
        unpredictable_instruction_policy() const noexcept override
        {
            return ArmUnpredictableInstructionPolicy::Strict;
        }

        [[nodiscard]] std::uint32_t ticks_per_second() const noexcept override
        {
            return clock_hz_;
        }

        [[nodiscard]] std::uint64_t ticks_for_instruction(bool thumb,
            std::uint32_t, std::uint32_t instruction) const noexcept override
        {
            if (!thumb) {
                return lookup_ticks(instruction, arm1176_arm_rules);
            }
            if ((instruction & 0xFFFF0000U) != 0) {
                return 1;
            }
            return lookup_ticks(instruction, arm1176_thumb16_rules);
        }

    private:
        std::uint32_t clock_hz_;
    };

    class Armv7CpuModel final : public ArmCpuModel {
    public:
        Armv7CpuModel(ArmCpuModelKind kind, std::uint32_t clock_hz)
            : kind_ { kind }
            , clock_hz_ { clock_hz }
        {
            if (clock_hz_ == 0) {
                throw std::invalid_argument {
                    "instruction timing clock must be non-zero"
                };
            }
        }

        [[nodiscard]] ArmCpuModelKind kind() const noexcept override
        {
            return kind_;
        }

        [[nodiscard]] ArmArchitectureVersion
        architecture_version() const noexcept override
        {
            return ArmArchitectureVersion::Armv7;
        }

        [[nodiscard]] ArmUnpredictableInstructionPolicy
        unpredictable_instruction_policy() const noexcept override
        {
            return kind_ == ArmCpuModelKind::CortexA8
                       ? ArmUnpredictableInstructionPolicy::CortexA8
                       : ArmUnpredictableInstructionPolicy::Strict;
        }

        [[nodiscard]] std::uint32_t ticks_per_second() const noexcept override
        {
            return clock_hz_;
        }

        [[nodiscard]] std::uint64_t ticks_for_instruction(bool thumb,
            std::uint32_t, std::uint32_t instruction) const noexcept override
        {
            if (!thumb) {
                return lookup_ticks(instruction, arm1176_arm_rules);
            }
            if ((instruction & 0xFFFF0000U) != 0) {
                return 1;
            }
            return lookup_ticks(instruction, arm1176_thumb16_rules);
        }

    private:
        ArmCpuModelKind kind_;
        std::uint32_t clock_hz_;
    };

}

std::unique_ptr<ArmCpuModel> make_arm_cpu_model(
    ArmCpuModelKind kind, std::uint32_t clock_hz)
{
    switch (kind) {
    case ArmCpuModelKind::Arm1176JzfS:
        return std::make_unique<Arm1176CpuModel>(clock_hz);
    case ArmCpuModelKind::CortexA8:
    case ArmCpuModelKind::CortexA9:
        return std::make_unique<Armv7CpuModel>(kind, clock_hz);
    }
    throw std::invalid_argument { "unsupported ARM CPU model" };
}

const ArmCpuModel& default_arm_cpu_model()
{
    static const Arm1176CpuModel model { 400'000'000 };
    return model;
}

}
