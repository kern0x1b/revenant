// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Resolve firmware capabilities for remote CoreAnimation transaction
// messages.

#include "graphics/core_animation_remote_abi.hpp"

#include <algorithm>
#include <array>
#include <bit>
#include <cstdint>
#include <limits>
#include <optional>
#include <string_view>

#include "foundation/macho.hpp"

namespace shade {
namespace {

    constexpr std::array<std::string_view, 2> encoder_send_symbols {
        "__ZN2CA6Render7Encoder8send_msgEj",
        "_CARenderEncoderSend",
    };

    constexpr std::array<std::string_view, 2> render_server_symbols {
        "_CARenderServerGetRPCRange",
        "_CARenderServerStart",
    };

    // The first ARMv7 CoreAnimation client kept the transaction encoder but
    // exposed the render-server bootstrap as GetServerPort instead of the
    // later RPC-range pair. The service port is still resolved from Mach
    // bootstrap at runtime, so this remains a capability probe rather than a
    // firmware or application selector.
    constexpr std::string_view early_render_server_port_symbol {
        "_CARenderServerGetServerPort"
    };

    std::uint32_t arm_immediate(std::uint32_t instruction)
    {
        const auto immediate = instruction & 0xffU;
        const auto rotation = ((instruction >> 8U) & 0xfU) * 2U;
        return std::rotr(immediate, static_cast<int>(rotation));
    }

    bool adds_immediate(std::uint32_t instruction,
        std::uint32_t source_register, std::uint32_t destination_register)
    {
        // ARM data-processing immediate ADD, ignoring the condition and
        // operand2.
        constexpr std::uint32_t operation_and_register_mask = 0x0ffff000U;
        constexpr std::uint32_t add_immediate = 0x02800000U;
        const auto expected = add_immediate | (source_register << 16U) |
                              (destination_register << 12U);
        return (instruction & operation_and_register_mask) == expected;
    }

    std::optional<std::uint32_t> detect_inline_transaction_message(
        const MachOImage& image, std::uint32_t function)
    {
        // Both the inline and OOL paths call one message initializer. The
        // encoder keeps the OOL selector as a boolean register and constructs
        // the message id as `protocol base + transaction opcode + is_ool`.
        // Decode those two adjacent additions from firmware code instead of
        // embedding the number.
        constexpr std::uint32_t selector_register = 8U;
        constexpr std::uint32_t message_register = 3U;
        constexpr std::uint32_t maximum_function_prefix = 512U;
        constexpr std::uint32_t maximum_following_distance = 24U;
        for (std::uint32_t offset = 0; offset != maximum_function_prefix;
            offset += sizeof(std::uint32_t)) {
            const auto base_add = image.read_vm_u32(function + offset);
            if (!base_add || !adds_immediate(*base_add, selector_register,
                                 message_register)) {
                continue;
            }
            const auto protocol_base = arm_immediate(*base_add);
            for (std::uint32_t following = sizeof(std::uint32_t);
                following <= maximum_following_distance;
                following += sizeof(std::uint32_t)) {
                const auto opcode_add =
                    image.read_vm_u32(function + offset + following);
                if (!opcode_add || !adds_immediate(*opcode_add,
                                       message_register, message_register)) {
                    continue;
                }
                const auto opcode = arm_immediate(*opcode_add);
                if (protocol_base >
                    std::numeric_limits<std::uint32_t>::max() - opcode) {
                    return std::nullopt;
                }
                const auto identifier = protocol_base + opcode;
                // Private user-space RPC families live outside the low kernel
                // MIG ranges. This also prevents an unrelated pair of
                // arithmetic instructions from being accepted as a transaction
                // protocol.
                if (identifier >= 0x8000U && identifier < 0x100000U)
                    return identifier;
                return std::nullopt;
            }
        }
        return std::nullopt;
    }

} // namespace

bool CoreAnimationRemoteAbi::is_transaction_message(
    std::uint32_t identifier) const
{
    return identifier == inline_transaction_message ||
           identifier == out_of_line_transaction_message;
}

std::optional<CoreAnimationRemoteAbi> CoreAnimationRemoteAbi::detect(
    const MachOImage& image)
{
    const MachSymbol* encoder = nullptr;
    for (const auto symbol_name : encoder_send_symbols) {
        encoder = image.find_symbol(symbol_name);
        if (encoder != nullptr)
            break;
    }
    if (encoder == nullptr)
        return std::nullopt;

    const auto inline_message =
        detect_inline_transaction_message(image, encoder->value);
    if (inline_message &&
        *inline_message != std::numeric_limits<std::uint32_t>::max()) {
        return CoreAnimationRemoteAbi {
            "core-animation-remote-transaction-v1", *inline_message,
            *inline_message + 1U, false
        };
    }

    // The Thumb-2 encoder used by early ARMv7 UIKit builds does not expose the
    // transaction selector as the ARM add/add pair above. The same image
    // exports both render-server entry points, so bind its remote scene
    // rendezvous to the service object resolved from bootstrap rather than
    // guessing an opcode from one application or OS build.
    const auto has_render_server_protocol =
        std::all_of(render_server_symbols.begin(), render_server_symbols.end(),
            [&image](const auto symbol_name) {
                return image.find_symbol(symbol_name) != nullptr;
            });
    if (has_render_server_protocol) {
        return CoreAnimationRemoteAbi {
            "core-animation-remote-render-server-v1", 0U, 0U, true
        };
    }

    if (image.find_symbol(early_render_server_port_symbol) != nullptr) {
        return CoreAnimationRemoteAbi {
            "core-animation-remote-render-server-v1", 0U, 0U, true
        };
    }
    return std::nullopt;
}

} // namespace shade
