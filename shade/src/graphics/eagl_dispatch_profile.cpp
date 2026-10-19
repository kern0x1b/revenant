// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Recognize the ARM32 EAGL context and dispatch-table calling
// convention.

#include "graphics/eagl_dispatch_profile.hpp"

#include <array>

namespace shade {

namespace {
    // The layout of the flags word a GLI driver is given when EAGL creates a
    // context, by the size of the dispatch table the driver reports. The 0xe48
    // row is read from the iOS 6.1.3 GLEngine's gliCreateContext: bit 4 selects
    // an ES 3 context, else bit 3 an ES 2 one, else bit 2 an ES 1 one.
    struct FlagsLayout {
        std::uint32_t dispatch_bytes;
        std::uint32_t mask;
        std::uint32_t es1;
        std::uint32_t es2;
        std::uint32_t es3; // zero where the driver has no ES 3 context
    };
    constexpr std::array<FlagsLayout, 3> flags_layouts {
        FlagsLayout { 0xe24U, 0x0cU, 0x04U, 0x08U, 0U },
        FlagsLayout { 0xe48U, 0x1cU, 0x04U, 0x08U, 0x10U },
        FlagsLayout { 0x102cU, 0x78U, 0x10U, 0x20U, 0x40U },
    };

    const FlagsLayout* flags_layout(std::uint32_t dispatch_bytes)
    {
        for (const auto& layout : flags_layouts) {
            if (layout.dispatch_bytes == dispatch_bytes)
                return &layout;
        }
        return nullptr;
    }
}

std::optional<EaglContextFirstArm32Profile>
EaglContextFirstArm32Profile::from_dispatch_bytes(std::uint32_t bytes)
{
    if (flags_layout(bytes) != nullptr)
        return EaglContextFirstArm32Profile { bytes };
    return std::nullopt;
}

std::optional<std::uint32_t> EaglContextFirstArm32Profile::client_api(
    std::uint32_t flags) const
{
    const auto* layout = flags_layout(dispatch_bytes_);
    if (layout == nullptr)
        return std::nullopt;
    const auto api_flags = flags & layout->mask;
    if (api_flags == layout->es1)
        return 1U;
    if (api_flags == layout->es2)
        return 2U;
    if (layout->es3 != 0U && api_flags == layout->es3)
        return 3U;
    return std::nullopt;
}

std::optional<std::uint32_t> EaglContextFirstArm32Profile::dispatch_slot(
    std::span<const std::byte> code) const
{
    const auto halfword = [&](std::size_t offset) {
        return std::to_integer<std::uint32_t>(code[offset]) |
               (std::to_integer<std::uint32_t>(code[offset + 1U]) << 8U);
    };
    std::array<bool, 16> private_context { };
    std::array<std::optional<std::uint32_t>, 16> function_offsets { };
    std::optional<std::uint32_t> tls_register;
    bool passes_context = false;
    for (std::size_t offset = 0; offset + 2U <= code.size();) {
        const auto first = halfword(offset);
        const bool wide = (first & 0xf800U) >= 0xe800U;
        if (wide && offset + 4U > code.size())
            return std::nullopt;
        const auto second = wide ? halfword(offset + 2U) : 0U;
        std::optional<std::uint32_t> base;
        std::uint32_t destination { };
        std::uint32_t immediate { };
        if (wide && first == 0xee1dU && (second & 0x0fffU) == 0x0f70U) {
            tls_register = second >> 12U; // MRC p15, 0, Rt, c13, c0, 3
        } else if (!wide && (first & 0xf800U) == 0x6800U) {
            base = (first >> 3U) & 7U;
            destination = first & 7U;
            immediate = ((first >> 6U) & 31U) * 4U;
        } else if (wide && (first & 0xfff0U) == 0xf8d0U) {
            base = first & 15U;
            destination = second >> 12U;
            immediate = second & 0xfffU;
        } else if (!wide && (first & 0xff07U) == 0x4700U) {
            const auto target = (first >> 3U) & 15U;
            if (passes_context && function_offsets[target])
                return (*function_offsets[target] - front_dispatch_offset) / 4U;
            // Leaf wrappers tail-call the driver with BX; their earlier
            // conditional BX LR handles a missing current context.
            if (target != 14U || (first & 0x80U) != 0U)
                return std::nullopt;
        }
        if (!tls_register && (offset >= 24U || first == 0x4770U ||
                (first & 0xff00U) == 0xbd00U ||
                (!wide && (first & 0xf800U) == 0xe000U)))
            return std::nullopt;
        if (base) {
            const bool from_private = private_context[*base];
            function_offsets[destination].reset();
            private_context[destination] = tls_register == base && immediate == 0x78U;
            if (from_private) {
                if (destination == 0U && immediate == context_offset)
                    passes_context = true;
                else if (immediate >= front_dispatch_offset &&
                         immediate - front_dispatch_offset < dispatch_bytes_ &&
                         (immediate & 3U) == 0U)
                    function_offsets[destination] = immediate;
            }
        }
        offset += wide ? 4U : 2U;
    }
    return std::nullopt;
}

} // namespace shade
