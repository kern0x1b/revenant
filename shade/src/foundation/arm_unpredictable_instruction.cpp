// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Apply the selected ARM core policy to unpredictable instruction
// results.

#include "foundation/arm_unpredictable_instruction.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <utility>

namespace shade {
namespace {

    constexpr std::uint32_t asimd_vtrn_mask = 0xffb30f90U;
    constexpr std::uint32_t asimd_vtrn_value = 0xf3b20080U;
    constexpr std::uint32_t asimd_vuzp_value = 0xf3b20100U;
    constexpr std::uint32_t asimd_vzip_value = 0xf3b20180U;

    [[nodiscard]] std::uint32_t asimd_instruction(
        bool thumb, std::uint32_t instruction)
    {
        if (!thumb)
            return instruction;
        // Thumb-2 Advanced SIMD keeps the low 24 bits of the ARM encoding and
        // moves U from bit 28 to bit 24.
        if ((instruction & 0xef000000U) != 0xef000000U)
            return 0U;
        const auto u = (instruction >> 28U) & 1U;
        return 0xf2000000U | (u << 24U) | (instruction & 0x00ffffffU);
    }

} // namespace

bool emulate_arm_unpredictable_instruction(
    ArmUnpredictableInstructionPolicy profile, bool thumb,
    std::uint32_t instruction,
    std::span<std::uint32_t, 64> extension_registers) noexcept
{
    if (profile != ArmUnpredictableInstructionPolicy::CortexA8)
        return false;

    const auto decoded = asimd_instruction(thumb, instruction);
    const auto operation = decoded & asimd_vtrn_mask;
    if (operation != asimd_vtrn_value && operation != asimd_vuzp_value &&
        operation != asimd_vzip_value) {
        return false;
    }

    const auto element_size = (decoded >> 18U) & 0x3U;
    const auto q = ((decoded >> 6U) & 1U) != 0U;
    const auto destination =
        (((decoded >> 22U) & 1U) << 4U) | ((decoded >> 12U) & 0xfU);
    const auto source = (((decoded >> 5U) & 1U) << 4U) | (decoded & 0xfU);
    // The architecture marks equal source/destination results UNKNOWN.
    // This Cortex-A8 profile follows the ordered NEON writes: the
    // destination-side result remains visible after the aliased source-side
    // result has been written.  Vectorized system codecs in iOS 4 rely on
    // this deterministic hardware behavior.
    if (element_size > 2U || destination != source ||
        (q && (destination & 1U) != 0U)) {
        return false;
    }

    // VUZP/VZIP have no D-register encoding for 32-bit elements.
    if (operation != asimd_vtrn_value && element_size == 2U && !q)
        return false;

    const auto first_word = static_cast<std::size_t>(destination) * 2U;
    const auto word_count = q ? 4U : 2U;
    if (first_word + word_count > extension_registers.size())
        return false;

    if (operation == asimd_vuzp_value || operation == asimd_vzip_value) {
        const auto element_bytes = std::size_t{1U} << element_size;
        const auto vector_bytes = q ? 16U : 8U;
        const auto element_count = vector_bytes / element_bytes;
        std::array<std::uint8_t, 16> source_bytes{};
        std::array<std::uint8_t, 16> result_bytes{};

        for (std::size_t index = 0; index < vector_bytes; ++index) {
            const auto word = extension_registers[first_word + index / 4U];
            source_bytes[index] = static_cast<std::uint8_t>(
                word >> ((index % 4U) * 8U));
        }

        for (std::size_t output_element = 0;
             output_element < element_count; ++output_element) {
            const auto source_element =
                operation == asimd_vuzp_value
                    ? (output_element * 2U) % element_count
                    : output_element / 2U;
            for (std::size_t byte = 0; byte < element_bytes; ++byte) {
                result_bytes[output_element * element_bytes + byte] =
                    source_bytes[source_element * element_bytes + byte];
            }
        }

        for (std::size_t word_index = 0; word_index < word_count;
             ++word_index) {
            std::uint32_t word = 0U;
            for (std::size_t byte = 0; byte < 4U; ++byte) {
                word |= static_cast<std::uint32_t>(
                            result_bytes[word_index * 4U + byte])
                    << (byte * 8U);
            }
            extension_registers[first_word + word_index] = word;
        }
        return true;
    }

    if (element_size == 0U) {
        for (std::size_t index = 0; index < word_count; ++index) {
            const auto value = extension_registers[first_word + index];
            const auto first_byte = value & 0xffU;
            const auto third_byte = (value >> 16U) & 0xffU;
            extension_registers[first_word + index] =
                first_byte | (first_byte << 8U) | (third_byte << 16U) |
                (third_byte << 24U);
        }
        return true;
    }

    if (element_size == 1U) {
        for (std::size_t index = 0; index < word_count; ++index) {
            const auto even_lane =
                extension_registers[first_word + index] & 0xffffU;
            extension_registers[first_word + index] =
                even_lane | (even_lane << 16U);
        }
        return true;
    }

    for (std::size_t index = 0; index < word_count; index += 2U) {
        std::swap(extension_registers[first_word + index],
            extension_registers[first_word + index + 1U]);
    }
    return true;
}

} // namespace shade
