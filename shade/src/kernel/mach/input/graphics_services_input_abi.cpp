// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Encode touch paths and button events using firmware input
// capability profiles.

#include "kernel/graphics_services_input_abi.hpp"

#include <bit>
#include <cstdint>
#include <string_view>

#include "foundation/macho.hpp"

namespace shade {
namespace {

    constexpr GraphicsServicesInputAbi darwin9_0_abi{
    .name = "darwin9.0",
    .event_record_size = 48,
    .record_timestamp_offset = 24,
    .record_info_size_offset = 44,
    .hand_info_size = 20,
    .path_info_size = 16,
    .hand_path_count_offset = 17,
    .path_location_offset = 8,
    .hand_phase_types = {1, 2, 6, 3},
    .path_phase_types = {2, 2, 2, 2},
    .idle_duration_reset_event_type = 101,
    .idle_duration_reset_info_size = sizeof(std::uint64_t),
    .system_events = {
        .home = {1000, 1001},
        .lock = {1010, 1011},
        .volume_up = {1006, 1007},
        .volume_down = {1008, 1009},
        .ringer_switch = {1012, 1013},
    },
};

    constexpr GraphicsServicesInputAbi darwin9_3_abi{
    .name = "darwin9.3",
    .event_record_size = 48,
    .record_timestamp_offset = 24,
    .record_info_size_offset = 44,
    .hand_info_size = 36,
    .path_info_size = 24,
    .hand_path_count_offset = 33,
    .path_location_offset = 12,
    .hand_phase_types = {1, 2, 6, 3},
    .path_phase_types = {1, 2, 5, 3},
    .idle_duration_reset_event_type = 101,
    .idle_duration_reset_info_size = sizeof(std::uint64_t),
    .system_events = {
        .home = {1000, 1001},
        .lock = {1010, 1011},
        .volume_up = {1006, 1007},
        .volume_down = {1008, 1009},
        .ringer_switch = {1012, 1013},
    },
};

constexpr GraphicsServicesInputAbi darwin9_4_abi{
    .name = "darwin9.4",
    .event_record_size = 52,
    .record_timestamp_offset = 28,
    .record_info_size_offset = 48,
    .hand_info_size = 36,
    .path_info_size = 24,
    .hand_path_count_offset = 33,
    .path_location_offset = 12,
    .hand_phase_types = {1, 2, 6, 3},
    .path_phase_types = {1, 2, 5, 3},
    .idle_duration_reset_event_type = 101,
    .idle_duration_reset_info_size = sizeof(std::uint64_t),
    .system_events = {
        .home = {1000, 1001},
        .lock = {1010, 1011},
        .volume_up = {1006, 1007},
        .volume_down = {1008, 1009},
        .ringer_switch = {1012, 1013},
    },
};

    // Darwin 11's GraphicsServices keeps the modern hand/path layout but
    // exposes the reset-idle operation as GSEventResetIdleTimer (100) and
    // sends a 52-byte record with no trailing event-info payload.  Keep this
    // ABI separate from the older 101 profile so the wire record follows the
    // accessor implementation loaded by the guest.
constexpr GraphicsServicesInputAbi darwin11_0_abi{
    .name = "darwin11.0",
    .event_record_size = 52,
    .record_timestamp_offset = 28,
    .record_info_size_offset = 48,
    .hand_info_size = 36,
    .path_info_size = 24,
    // This UIKit ABI reads the count at GSEventRecord+0x56 (hand+34); the
    // preceding hand byte is reserved in this ABI.  Keep the offset in the
    // profile because earlier GraphicsServices layouts place the count at
    // hand+33.
    .hand_path_count_offset = 34,
    .path_location_offset = 12,
    // UIKit establishes the hand's window at type 1, completes remaining
    // contacts at type 6, and cancels all contacts at type 8. These are
    // GSEvent hand states; pathIdentity stays stable through the gesture.
    .hand_phase_types = {1, 2, 6, 8},
    .path_phase_types = {1, 1, 1, 1},
    .idle_duration_reset_event_type = 100,
    .idle_duration_reset_info_size = 0,
    .system_events = {
        .home = {1000, 1001},
        .lock = {1010, 1011},
        .volume_up = {1006, 1007},
        .volume_down = {1008, 1009},
        .ringer_switch = {1012, 1013},
    },
    .application_events = { .resume = 2000U, .background_complete = 2008U },
};

    std::uint32_t rotate_right(std::uint32_t value, std::uint32_t amount)
    {
        return std::rotr(value, static_cast<int>(amount));
    }

    std::optional<std::uint16_t> read_thumb_halfword(
        const MachOImage& image, const MachSymbol& symbol, std::uint32_t offset)
    {
        if (!symbol.thumb_definition())
            return std::nullopt;
        return image.read_vm_u16((symbol.value & ~1U) + offset);
    }

    std::optional<std::uint32_t> thumb_movs_immediate(const MachOImage& image,
        const MachSymbol& symbol, std::uint8_t destination)
    {
        constexpr std::uint16_t movs_immediate_mask = 0xf800U;
        constexpr std::uint16_t movs_immediate = 0x2000U;
        for (std::uint32_t offset = 0; offset < 32U; offset += 2U) {
            const auto instruction = read_thumb_halfword(image, symbol, offset);
            if (instruction &&
                (*instruction & movs_immediate_mask) == movs_immediate &&
                ((*instruction >> 8U) & 0x7U) == destination) {
                return *instruction & 0xffU;
            }
        }
        return std::nullopt;
    }

    std::optional<std::uint32_t> thumb_adds_immediate(const MachOImage& image,
        const MachSymbol& symbol, std::uint8_t destination)
    {
        // ADD (immediate, Thumb-1) with the destination also used as Rn.
        constexpr std::uint16_t adds_immediate_mask = 0xf800U;
        constexpr std::uint16_t adds_immediate = 0x3000U;
        for (std::uint32_t offset = 0; offset < 32U; offset += 2U) {
            const auto instruction = read_thumb_halfword(image, symbol, offset);
            if (instruction &&
                (*instruction & adds_immediate_mask) == adds_immediate &&
                ((*instruction >> 8U) & 0x7U) == destination) {
                return *instruction & 0xffU;
            }
        }
        return std::nullopt;
    }

    std::optional<std::uint32_t> thumb_add_w_immediate(
        const MachOImage& image, const MachSymbol& symbol,
        std::uint8_t source)
    {
        // ADD.W (immediate) is used by the ARMv7 GraphicsServices accessors
        // when they advance past the CFRuntime header. Ignore the i bit so the
        // full 12-bit immediate form is accepted, while bit 7 excludes SUB.W.
        constexpr std::uint16_t add_w_mask = 0xfb80U;
        constexpr std::uint16_t add_w = 0xf100U;
        for (std::uint32_t offset = 0; offset < 64U; offset += 2U) {
            const auto first = read_thumb_halfword(image, symbol, offset);
            const auto second =
                read_thumb_halfword(image, symbol, offset + 2U);
            if (!first || !second || (*first & add_w_mask) != add_w ||
                (*first & 0xfU) != source || (*second & 0x8000U) != 0U) {
                continue;
            }
            const auto immediate =
                (((*first >> 10U) & 1U) << 11U) |
                (((*second >> 12U) & 0x7U) << 8U) | (*second & 0xffU);
            return immediate;
        }
        return std::nullopt;
    }

    std::uint32_t thumb_register_count(std::uint16_t register_list)
    {
        return static_cast<std::uint32_t>(
                   std::popcount(static_cast<unsigned>(register_list))) *
               static_cast<std::uint32_t>(sizeof(std::uint32_t));
    }

    std::optional<std::uint32_t> thumb_inline_store_size(
        const MachOImage& image, const MachSymbol& symbol)
    {
        // A newer compiler may emit individual stores instead of one
        // contiguous LDM/STM copy. Recover the output structure extent from
        // stores based at ABI argument r0.
        std::uint32_t size = 0;
        for (std::uint32_t offset = 0; offset < 128U; offset += 2U) {
            const auto first = read_thumb_halfword(image, symbol, offset);
            if (!first)
                break;
            // Accessors are leaf functions; do not read the following
            // function when an inline store sequence ends with POP {...,pc}
            // (or the equivalent BX LR).
            if ((*first & 0xff00U) == 0xbd00U || *first == 0x4770U)
                break;

            // STR (word, immediate), Thumb-1: 0110 imm5 Rn Rt.
            if ((*first & 0xf800U) == 0x6000U &&
                ((*first >> 3U) & 0x7U) == 0U) {
                size = std::max(size,
                    (((*first >> 6U) & 0x1fU) * 4U) + 4U);
                continue;
            }

            // STMIA.W r0, {registers}. Other base registers may refer to a
            // later chunk of an LDM/STM copy; that is decoded separately.
            if (*first == 0xe880U) {
                const auto second =
                    read_thumb_halfword(image, symbol, offset + 2U);
                if (second)
                    size = std::max(size, thumb_register_count(*second));
                // The loop advances by one halfword after this body; skip the
                // second halfword of the wide instruction as well.
                offset += 2U;
                continue;
            }

            // STMIA r0!, {registers}, Thumb-1.
            if ((*first & 0xf800U) == 0xc000U &&
                ((*first >> 8U) & 0x7U) == 0U) {
                size = std::max(size,
                    thumb_register_count(*first & 0xffU));
            }
        }
        return size == 0U ? std::nullopt
                          : std::optional<std::uint32_t> { size };
    }

    std::optional<std::uint32_t> thumb_inline_copy_size(
        const MachOImage& image, const MachSymbol& symbol)
    {
        constexpr std::uint32_t maximum_accessor_size = 64U;
        std::uint32_t inline_copy_size = 0U;
        for (std::uint32_t offset = 0; offset < maximum_accessor_size;
            offset += 2U) {
            const auto first = read_thumb_halfword(image, symbol, offset);
            if (!first)
                break;
            if ((*first & 0xff00U) == 0xbd00U)
                break;

            // LDMIA/STMIA Rn!, register-list. The early GraphicsServices
            // accessor places a small register move between the load and store,
            // so allow a short gap while keeping the base register and list
            // tied together.
            if ((*first & 0xf800U) == 0xc800U) {
                const auto base = (*first >> 8U) & 0x7U;
                const auto registers =
                    static_cast<std::uint16_t>(*first & 0xffU);
                for (std::uint32_t following_offset = offset + 2U;
                    following_offset < offset + 12U; following_offset += 2U) {
                    const auto following =
                        read_thumb_halfword(image, symbol, following_offset);
                    if (following && (*following & 0xf800U) == 0xc000U &&
                        ((*following >> 8U) & 0x7U) == base &&
                        (*following & 0xffU) == registers) {
                        inline_copy_size += thumb_register_count(registers);
                        break;
                    }
                }
                continue;
            }

            // LDM.W/STM.W use two halfwords. Their register list is the second
            // halfword; matching adjacent load/store pairs avoids treating the
            // second halfword as an independent Thumb instruction.
            if ((*first & 0xfff0U) != 0xe890U)
                continue;
            const auto load_registers =
                read_thumb_halfword(image, symbol, offset + 2U);
            const auto store_first =
                read_thumb_halfword(image, symbol, offset + 4U);
            const auto store_registers =
                read_thumb_halfword(image, symbol, offset + 6U);
            if (load_registers && store_first && store_registers &&
                (*store_first & 0xfff0U) == 0xe880U &&
                *store_registers == *load_registers) {
                inline_copy_size += thumb_register_count(*load_registers);
                offset += 6U;
            }
        }
        return inline_copy_size == 0U
                   ? std::nullopt
                   : std::optional<std::uint32_t> { inline_copy_size };
    }

    std::optional<std::uint32_t> structure_copy_size(
        const MachOImage& image, std::string_view symbol_name)
    {
        const auto* symbol = image.find_symbol(symbol_name);
        if (symbol == nullptr)
            return std::nullopt;

        // Accessors either call memcpy with the complete public structure size
        // or inline that copy as adjacent ARM LDM/STM pairs. Decode both
        // compiler forms instead of depending on a framework generation or
        // symbol address.
        constexpr std::uint32_t mov_immediate_r2_mask = 0x0ffff000U;
        constexpr std::uint32_t mov_immediate_r2 = 0x03a02000U;
        constexpr std::uint32_t block_transfer_mask = 0x0e000000U;
        constexpr std::uint32_t block_transfer = 0x08000000U;
        constexpr std::uint32_t block_transfer_load = 0x00100000U;
        constexpr std::uint32_t register_list_mask = 0x0000ffffU;
        constexpr std::uint32_t maximum_accessor_size = 64U;
        std::uint32_t inline_copy_size = 0U;
        for (std::uint32_t offset = 0; offset != maximum_accessor_size;
            offset += 4) {
            const auto instruction = image.read_vm_u32(symbol->value + offset);
            if (!instruction)
                break;
            if ((*instruction & mov_immediate_r2_mask) == mov_immediate_r2) {
                const auto immediate = *instruction & 0xffU;
                const auto rotation = ((*instruction >> 8U) & 0xfU) * 2U;
                return rotate_right(immediate, rotation);
            }
            if ((*instruction & block_transfer_mask) != block_transfer ||
                (*instruction & block_transfer_load) == 0U) {
                continue;
            }
            const auto following =
                image.read_vm_u32(symbol->value + offset + 4U);
            if (!following ||
                (*following & block_transfer_mask) != block_transfer ||
                (*following & block_transfer_load) != 0U ||
                (*following & register_list_mask) !=
                    (*instruction & register_list_mask)) {
                continue;
            }
            inline_copy_size +=
                static_cast<std::uint32_t>(
                    std::popcount(*instruction & register_list_mask)) *
                static_cast<std::uint32_t>(sizeof(std::uint32_t));
            offset += 4U;
        }
        if (inline_copy_size != 0U)
            return inline_copy_size;
        if (const auto size = thumb_movs_immediate(image, *symbol, 2U); size)
            return size;
        if (const auto size = thumb_inline_store_size(image, *symbol); size)
            return size;
        return thumb_inline_copy_size(image, *symbol);
    }

    std::optional<std::uint32_t> detected_event_record_size(
        const MachOImage& image)
    {
        const auto* symbol = image.find_symbol("_GSEventGetHandInfo");
        if (symbol == nullptr)
            return std::nullopt;

        // GSEventRef is a 32-bit CFRuntime object. The accessor advances its
        // source argument past CFRuntimeBase and GSEventRecord before copying
        // HandInfo. Decode that firmware-owned field offset and remove the
        // stable runtime header instead of assuming a public record layout.
        constexpr std::uint32_t cf_runtime_base_size = 8U;
        constexpr std::uint32_t add_immediate_r1_mask = 0x0ffff000U;
        constexpr std::uint32_t add_immediate_r1 = 0x02811000U;
        constexpr std::uint32_t maximum_prefix_size = 32U;
        for (std::uint32_t offset = 0; offset != maximum_prefix_size;
            offset += 4U) {
            const auto instruction = image.read_vm_u32(symbol->value + offset);
            if (!instruction ||
                (*instruction & add_immediate_r1_mask) != add_immediate_r1) {
                continue;
            }
            const auto immediate = *instruction & 0xffU;
            const auto rotation = ((*instruction >> 8U) & 0xfU) * 2U;
            const auto object_offset = rotate_right(immediate, rotation);
            if (object_offset >= cf_runtime_base_size)
                return object_offset - cf_runtime_base_size;
        }

        // ARMv7 GraphicsServices is commonly compiled in Thumb-2. In that form
        // the accessor uses `adds r1, #record_offset` instead of the ARM
        // immediate form above; the same CF runtime header adjustment still
        // identifies the complete GSEventRecord size.
        if (const auto record_offset = thumb_adds_immediate(image, *symbol, 1U);
            record_offset && *record_offset >= cf_runtime_base_size) {
            return *record_offset - cf_runtime_base_size;
        }
        if (const auto record_offset = thumb_add_w_immediate(image, *symbol, 1U);
            record_offset && *record_offset >= cf_runtime_base_size) {
            return *record_offset - cf_runtime_base_size;
        }
        return std::nullopt;
    }

    std::optional<std::uint32_t> detected_idle_reset_event_type(
        const MachOImage& image)
    {
        // GraphicsServices has used both GSEventResetIdleDuration and
        // GSEventResetIdleTimer.  Read the event type emitted by the exported
        // helper instead of assuming it from a firmware/build identifier.
        for (const auto symbol_name : { "_GSEventResetIdleTimer",
                 "_GSEventResetIdleDuration" }) {
            const auto* symbol = image.find_symbol(symbol_name);
            if (symbol == nullptr)
                continue;
            if (const auto event_type =
                    thumb_movs_immediate(image, *symbol, 0U);
                event_type) {
                return event_type;
            }
        }
        return std::nullopt;
    }

} // namespace

std::uint8_t GraphicsServicesInputAbi::hand_type(TouchPhase phase) const
{
    return hand_phase_types[static_cast<std::size_t>(phase)];
}

std::uint8_t GraphicsServicesInputAbi::path_type(TouchPhase phase) const
{
    return path_phase_types[static_cast<std::size_t>(phase)];
}

std::uint32_t GraphicsServicesInputAbi::system_button_type(
    const SystemButtonInput& input) const
{
    const auto index = input.phase == SystemButtonPhase::Down ? 0U : 1U;
    switch (input.button) {
    case SystemButton::Home:
        return system_events.home[index];
    case SystemButton::Lock:
        return system_events.lock[index];
    case SystemButton::VolumeUp:
        return system_events.volume_up[index];
    case SystemButton::VolumeDown:
        return system_events.volume_down[index];
    }
    return system_events.home[1];
}

std::uint32_t GraphicsServicesInputAbi::ringer_switch_type(
    bool active) const
{
    return system_events.ringer_switch[active ? 1U : 0U];
}

const GraphicsServicesInputAbi& GraphicsServicesInputAbi::for_abi(
    KernelSharedState::GraphicsInputAbi abi)
{
    switch (abi) {
    case KernelSharedState::GraphicsInputAbi::Darwin9_4:
        return darwin9_4_abi;
    case KernelSharedState::GraphicsInputAbi::Darwin11_0:
        return darwin11_0_abi;
    case KernelSharedState::GraphicsInputAbi::Darwin9_3:
        return darwin9_3_abi;
    case KernelSharedState::GraphicsInputAbi::LegacyMouse:
    case KernelSharedState::GraphicsInputAbi::Darwin9_0:
        return darwin9_0_abi;
    }
    return darwin9_0_abi;
}

std::optional<KernelSharedState::GraphicsInputAbi>
GraphicsServicesInputAbi::detect(const MachOImage& image)
{
    const auto record_size = detected_event_record_size(image);
    const auto hand_size = structure_copy_size(image, "_GSEventGetHandInfo");
    const auto path_size =
        structure_copy_size(image, "_GSEventGetPathInfoAtIndex");
    if (record_size == darwin9_0_abi.event_record_size &&
        hand_size == darwin9_0_abi.hand_info_size &&
        path_size == darwin9_0_abi.path_info_size) {
        return KernelSharedState::GraphicsInputAbi::Darwin9_0;
    }
    if (record_size == darwin9_3_abi.event_record_size &&
        hand_size == darwin9_3_abi.hand_info_size &&
        path_size == darwin9_3_abi.path_info_size) {
        return KernelSharedState::GraphicsInputAbi::Darwin9_3;
    }
    if (record_size == darwin9_4_abi.event_record_size &&
        hand_size == darwin9_4_abi.hand_info_size &&
        path_size == darwin9_4_abi.path_info_size) {
        if (const auto event_type = detected_idle_reset_event_type(image);
            event_type &&
            *event_type == darwin11_0_abi.idle_duration_reset_event_type) {
            return KernelSharedState::GraphicsInputAbi::Darwin11_0;
        }
        return KernelSharedState::GraphicsInputAbi::Darwin9_4;
    }
    return std::nullopt;
}

} // namespace shade
