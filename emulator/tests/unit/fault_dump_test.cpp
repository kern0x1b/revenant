// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Unit test for the fault word report: the registers described, including the
// program counter, the eight words at a register, the four words at the
// address held in its first word, the label on words that land in an image,
// the stop at an unmapped word, and the symbol of an address picked from the
// symbols of its section. Build with BUILD_TESTING and run `ctest -R fault_dump`.

#include "foundation/fault_dump.hpp"

#include <array>
#include <cstdint>
#include <cstdio>
#include <map>
#include <optional>
#include <string>
#include <vector>

namespace {

int failures = 0;

void check(bool condition, const char* expression, int line)
{
    if (condition)
        return;
    ++failures;
    std::fprintf(stderr, "fault_dump_test.cpp:%d: check failed: %s\n", line,
        expression);
}

#define CHECK(expression) check((expression), #expression, __LINE__)

using Words = std::map<std::uint32_t, std::uint32_t>;

emulator::GuestWordReader reader_for(const Words& words)
{
    return [&words](std::uint32_t address) -> std::optional<std::uint32_t> {
        const auto found = words.find(address);
        if (found == words.end())
            return std::nullopt;
        return found->second;
    };
}

std::string label_for(std::uint32_t address)
{
    if (address >= 0x39000000U && address < 0x39100000U)
        return "image";
    return { };
}

std::size_t count_of(const std::string& text, const std::string& needle)
{
    std::size_t count = 0;
    for (auto position = text.find(needle); position != std::string::npos;
        position = text.find(needle, position + needle.size()))
        ++count;
    return count;
}

Words fixture_words()
{
    Words words;
    words[0x10000000U] = 0x39000100U;
    for (std::uint32_t index = 1; index <= 8; ++index)
        words[0x10000000U + 4U * index] = index;
    words[0x10000000U + 32U] = 0x99U;
    words[0x39000100U] = 0x39000200U;
    words[0x39000104U] = 0x39000300U;
    words[0x39000108U] = 0x39000400U;
    words[0x3900010cU] = 0x39000500U;
    words[0x39000110U] = 0x39000600U;
    words[0x30000000U] = 5U;
    return words;
}

void test_registers_and_words()
{
    const auto words = fixture_words();
    std::array<std::uint32_t, 16> registers { };
    registers[0] = 0x10000000U;
    registers[1] = 0x20000000U;
    registers[2] = 0x30000000U;
    registers[15] = 0x10000000U;
    const auto lines = emulator::describe_fault_words(
        registers, reader_for(words), label_for);
    CHECK(lines.size() == 5U);
    if (lines.size() < 5U)
        return;
    CHECK(lines[0].starts_with("[fault-words] r0 0x10000000:"));
    CHECK(count_of(lines[0], "0x") == 9U);
    CHECK(lines[0].find("0x39000100 [image]") != std::string::npos);
    CHECK(lines[0].find("0x00000099") == std::string::npos);
    CHECK(lines[1] ==
          "[fault-words] r0 -> 0x39000100 [image]: 0x39000200 [image] "
          "0x39000300 [image] 0x39000400 [image] 0x39000500 [image]");
    CHECK(lines[2].starts_with("[fault-words] r2 0x30000000:"));
    CHECK(lines[2].ends_with(" 0x00000005 unmapped"));
    CHECK(lines[3].starts_with("[fault-words] pc 0x10000000:"));
    CHECK(lines[4].starts_with("[fault-words] pc -> 0x39000100 [image]:"));
}

void test_unmapped_registers_are_skipped()
{
    const Words words = fixture_words();
    std::array<std::uint32_t, 16> registers { };
    registers[0] = 0x20000000U;
    const auto lines = emulator::describe_fault_words(
        registers, reader_for(words), label_for);
    CHECK(lines.empty());
}

emulator::MachSection section(const char* name, std::uint32_t address,
    std::uint32_t size)
{
    emulator::MachSection result;
    result.name = name;
    result.address = address;
    result.size = size;
    return result;
}

emulator::MachSymbol symbol(const char* name, std::uint32_t value,
    std::uint8_t type, std::uint8_t number)
{
    emulator::MachSymbol result;
    result.name = name;
    result.value = value;
    result.type = type;
    result.section = number;
    return result;
}

void test_symbol_offset_label()
{
    const std::vector<emulator::MachSection> sections {
        section("__text", 0x1000U, 0x1000U),
        section("__objc_data", 0x3000U, 0x100U),
        section("__const", 0x5000U, 0x100U),
    };
    const std::vector<emulator::MachSymbol> symbols {
        symbol("_f", 0x1000U, 0x0fU, 1U),
        symbol("_g", 0x1100U, 0x0eU, 1U),
        symbol("_stab", 0x1010U, 0x24U, 1U),
        symbol("_a_local", 0x1200U, 0x0eU, 1U),
        symbol("_b_ext", 0x1200U, 0x0fU, 1U),
        symbol("_vt", 0x3000U, 0x0eU, 2U),
    };
    CHECK(emulator::symbol_offset_label(symbols, sections, 0x1050U) ==
          "_f+0x50");
    CHECK(emulator::symbol_offset_label(symbols, sections, 0x1150U) ==
          "_g+0x50");
    CHECK(emulator::symbol_offset_label(symbols, sections, 0x1100U) == "_g");
    CHECK(emulator::symbol_offset_label(symbols, sections, 0x1010U) ==
          "_f+0x10");
    CHECK(emulator::symbol_offset_label(symbols, sections, 0x1200U) ==
          "_b_ext");
    CHECK(emulator::symbol_offset_label(symbols, sections, 0x1234U) ==
          "_b_ext+0x34");
    CHECK(emulator::symbol_offset_label(symbols, sections, 0x3010U) ==
          "_vt+0x10");
    CHECK(emulator::symbol_offset_label(symbols, sections, 0x3080U) ==
          "_vt+0x80");
    CHECK(emulator::symbol_offset_label(symbols, sections, 0x5010U).empty());
    CHECK(emulator::symbol_offset_label(symbols, sections, 0x2100U).empty());
    CHECK(emulator::symbol_offset_label(symbols, sections, 0x0fffU).empty());
}

}

int main()
{
    test_registers_and_words();
    test_unmapped_registers_are_skipped();
    test_symbol_offset_label();
    if (failures == 0) {
        std::printf("fault_dump_test: all checks passed\n");
        return 0;
    }
    std::fprintf(stderr, "fault_dump_test: %d check(s) failed\n", failures);
    return 1;
}
