// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Unit test for the fault word report: the registers described, the eight
// words at a register, the four words at the address held in its first word,
// the label on words that land in an image, the stop at an unmapped word and
// the exclusion of the program counter. Build with BUILD_TESTING and run
// `ctest -R fault_dump`.

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
    CHECK(lines.size() == 3U);
    if (lines.size() < 3U)
        return;
    CHECK(lines[0].starts_with("[fault-words] r0 0x10000000:"));
    CHECK(count_of(lines[0], "0x") == 9U);
    CHECK(lines[0].find("0x39000100 [image]") != std::string::npos);
    CHECK(lines[0].find("0x00000099") == std::string::npos);
    CHECK(lines[1] ==
          "[fault-words] r0 -> 0x39000100: 0x39000200 [image] "
          "0x39000300 [image] 0x39000400 [image] 0x39000500 [image]");
    CHECK(lines[2].starts_with("[fault-words] r2 0x30000000:"));
    CHECK(lines[2].ends_with(" 0x00000005 unmapped"));
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

}

int main()
{
    test_registers_and_words();
    test_unmapped_registers_are_skipped();
    if (failures == 0) {
        std::printf("fault_dump_test: all checks passed\n");
        return 0;
    }
    std::fprintf(stderr, "fault_dump_test: %d check(s) failed\n", failures);
    return 1;
}
