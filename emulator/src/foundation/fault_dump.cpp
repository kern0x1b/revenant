// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "foundation/fault_dump.hpp"

#include <cstddef>
#include <cstdio>

namespace emulator {
namespace {

    constexpr std::size_t fault_register_count = 16;
    constexpr std::size_t register_word_count = 8;
    constexpr std::size_t target_word_count = 4;
    constexpr std::uint8_t stab_mask = 0xe0U;
    constexpr std::uint8_t external_symbol = 0x01U;
    constexpr const char* fault_register_names[fault_register_count] = {
        "r0", "r1", "r2", "r3", "r4", "r5", "r6", "r7", "r8", "r9", "r10",
        "r11", "r12", "sp", "lr", "pc"
    };

    std::string hex32(std::uint32_t value)
    {
        char text[11];
        std::snprintf(text, sizeof text, "0x%08x", value);
        return text;
    }

    std::string labelled_word(std::uint32_t value, const GuestWordLabel& label)
    {
        auto text = hex32(value);
        const auto name = label(value);
        if (!name.empty())
            text += " [" + name + "]";
        return text;
    }

    std::string words_text(std::uint32_t address, std::size_t count,
        const GuestWordReader& read32, const GuestWordLabel& label)
    {
        std::string text;
        for (std::size_t index = 0; index < count; ++index) {
            const auto word =
                read32(address + static_cast<std::uint32_t>(4U * index));
            if (!word) {
                text += " unmapped";
                break;
            }
            text += " " + labelled_word(*word, label);
        }
        return text;
    }

}

std::string symbol_offset_label(const std::vector<MachSymbol>& symbols,
    const std::vector<MachSection>& sections, std::uint32_t address)
{
    std::size_t section_number = 0;
    for (std::size_t index = 0; index < sections.size(); ++index) {
        const auto& section = sections[index];
        if (section.size != 0U && address >= section.address &&
            address - section.address < section.size) {
            section_number = index + 1U;
            break;
        }
    }
    if (section_number == 0U)
        return { };
    const MachSymbol* best = nullptr;
    for (const auto& symbol : symbols) {
        if (symbol.section != section_number || symbol.name.empty() ||
            (symbol.type & stab_mask) != 0U || symbol.value > address)
            continue;
        if (best == nullptr || symbol.value > best->value ||
            (symbol.value == best->value &&
                (symbol.type & external_symbol) != 0U &&
                (best->type & external_symbol) == 0U))
            best = &symbol;
    }
    if (best == nullptr)
        return { };
    const auto offset = address - best->value;
    if (offset == 0U)
        return best->name;
    char text[16];
    std::snprintf(text, sizeof text, "+0x%x", offset);
    return best->name + text;
}

std::vector<std::string> describe_fault_words(
    const std::array<std::uint32_t, 16>& registers,
    const GuestWordReader& read32, const GuestWordLabel& label)
{
    std::vector<std::string> lines;
    for (std::size_t index = 0; index < fault_register_count; ++index) {
        const auto name = fault_register_names[index];
        const auto value = registers[index];
        const auto first = read32(value);
        if (!first)
            continue;
        lines.push_back(std::string { "[fault-words] " } + name + " " +
                        labelled_word(value, label) + ":" +
                        words_text(value, register_word_count, read32, label));
        if (read32(*first)) {
            lines.push_back(std::string { "[fault-words] " } + name + " -> " +
                            labelled_word(*first, label) + ":" +
                            words_text(*first, target_word_count, read32,
                                label));
        }
    }
    return lines;
}

}
