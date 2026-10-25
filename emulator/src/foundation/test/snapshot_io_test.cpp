// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "foundation/snapshot_io.hpp"

#include <array>
#include <atomic>
#include <cstddef>
#include <cstdint>
#include <deque>
#include <functional>
#include <initializer_list>
#include <iostream>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <set>
#include <string>
#include <utility>
#include <vector>

namespace {

using emulator::snapshot::FormatError;
using emulator::snapshot::Reader;
using emulator::snapshot::RefusedError;
using emulator::snapshot::Writer;

int failures = 0;

void expect(bool condition, const std::string& what)
{
    if (condition)
        return;
    std::cerr << "FAIL: " << what << '\n';
    ++failures;
}

enum class Mode : std::uint16_t {
    Off,
    On = 7,
};

std::vector<std::byte> bytes_of(std::initializer_list<unsigned> values)
{
    std::vector<std::byte> result;
    for (const auto value : values)
        result.push_back(static_cast<std::byte>(value));
    return result;
}

template <typename T> std::vector<std::byte> encode(const T& value)
{
    Writer out;
    emulator::snapshot::save(out, value);
    return out.bytes();
}

template <typename T> T decode(const std::vector<std::byte>& data)
{
    Reader in { data };
    T value { };
    emulator::snapshot::load(in, value);
    return value;
}

void scalars_are_little_endian()
{
    expect(encode<std::uint32_t>(0x01020304U) == bytes_of({ 4, 3, 2, 1 }),
        "uint32 is little endian");
    expect(encode<std::int16_t>(-2) == bytes_of({ 0xfe, 0xff }),
        "int16 is two's complement little endian");
    expect(decode<std::uint64_t>(encode<std::uint64_t>(0x1122334455667788ULL))
            == 0x1122334455667788ULL,
        "uint64 round trip");
    expect(decode<std::int64_t>(encode<std::int64_t>(-5)) == -5,
        "int64 round trip");
}

void bools_and_enums_round_trip()
{
    expect(encode(true) == bytes_of({ 1 }), "true is one byte");
    expect(decode<bool>(encode(false)) == false, "false round trip");
    expect(decode<bool>(encode(true)) == true, "true round trip");
    expect(encode(Mode::On) == bytes_of({ 7, 0 }), "enum uses its underlying width");
    expect(decode<Mode>(encode(Mode::On)) == Mode::On, "enum round trip");
}

void strings_and_optionals_round_trip()
{
    expect(decode<std::string>(encode(std::string { "abc" })) == "abc",
        "string round trip");
    expect(decode<std::string>(encode(std::string {})).empty(),
        "empty string round trip");
    expect(encode(std::optional<std::uint32_t> {}) == bytes_of({ 0 }),
        "absent optional is one flag byte");
    expect(decode<std::optional<std::uint32_t>>(
               encode(std::optional<std::uint32_t> { 9U })) == 9U,
        "present optional round trip");
    expect(!decode<std::optional<std::uint32_t>>(
               encode(std::optional<std::uint32_t> {}))
                .has_value(),
        "absent optional round trip");
}

void containers_round_trip()
{
    const std::pair<std::uint8_t, std::string> pair { 3, "pair" };
    expect(decode<std::pair<std::uint8_t, std::string>>(encode(pair)) == pair,
        "pair round trip");

    const std::array<std::uint16_t, 3> array { 1, 2, 3 };
    expect((decode<std::array<std::uint16_t, 3>>(encode(array)) == array),
        "array round trip");

    const std::vector<std::uint32_t> vector { 5, 6, 7 };
    expect(decode<std::vector<std::uint32_t>>(encode(vector)) == vector,
        "vector round trip");

    const std::deque<std::string> deque { "x", "yz" };
    expect(decode<std::deque<std::string>>(encode(deque)) == deque,
        "deque round trip");

    const std::set<std::uint32_t> set { 4, 1, 9 };
    expect(decode<std::set<std::uint32_t>>(encode(set)) == set,
        "set round trip");

    const std::set<std::string, std::less<>> named { "b", "a" };
    expect((decode<std::set<std::string, std::less<>>>(encode(named)) == named),
        "transparent set round trip");

    const std::map<std::string, std::uint32_t, std::less<>> map {
        { "one", 1U }, { "two", 2U } };
    expect((decode<std::map<std::string, std::uint32_t, std::less<>>>(
                encode(map))
            == map),
        "transparent map round trip");
}

void truncated_input_is_a_format_error()
{
    bool threw = false;
    try {
        static_cast<void>(decode<std::uint32_t>(bytes_of({ 1, 2 })));
    } catch (const FormatError&) {
        threw = true;
    }
    expect(threw, "truncated uint32 throws FormatError");

    threw = false;
    try {
        static_cast<void>(decode<bool>(bytes_of({ 2 })));
    } catch (const FormatError&) {
        threw = true;
    }
    expect(threw, "bad bool byte throws FormatError");
}

void defaults_match_zero_and_empty()
{
    expect(emulator::snapshot::is_default(0U), "zero is default");
    expect(!emulator::snapshot::is_default(1U), "one is not default");
    expect(emulator::snapshot::is_default(Mode::Off), "enum zero is default");
    expect(!emulator::snapshot::is_default(Mode::On), "enum seven is not default");
    expect(emulator::snapshot::is_default(std::string {}), "empty string is default");
    expect(!emulator::snapshot::is_default(std::string { "a" }),
        "non-empty string is not default");
    expect(emulator::snapshot::is_default(std::optional<int> {}),
        "empty optional is default");
    expect(!emulator::snapshot::is_default(std::optional<int> { 0 }),
        "engaged optional is not default");
    expect(emulator::snapshot::is_default(std::atomic<std::uint64_t> { 0 }),
        "atomic zero is default");
    expect(!emulator::snapshot::is_default(std::atomic<std::uint64_t> { 1 }),
        "atomic one is not default");
    expect(emulator::snapshot::is_default(std::mutex {}),
        "mutex is default");
    expect(emulator::snapshot::is_default(std::shared_ptr<int> {}),
        "null shared_ptr is default");
    expect(!emulator::snapshot::is_default(std::make_shared<int>(1)),
        "live shared_ptr is not default");
    expect(emulator::snapshot::is_default(std::vector<int> {}),
        "empty vector is default");
    expect(!emulator::snapshot::is_default(std::vector<int> { 0 }),
        "vector holding a zero is not default");
    expect(emulator::snapshot::is_default(std::map<std::string, int, std::less<>> {}),
        "empty map is default");
    expect(emulator::snapshot::is_default(std::array<int, 2> {}),
        "zero array is default");
    expect(!emulator::snapshot::is_default(std::array<int, 2> { 0, 3 }),
        "array with a non-zero element is not default");
}

void refusal_names_the_member()
{
    bool caught = false;
    try {
        throw RefusedError { "kss.processes" };
    } catch (const RefusedError& error) {
        caught = true;
        expect(error.member() == "kss.processes", "refusal keeps the member name");
        expect(std::string { error.what() }.find("kss.processes") != std::string::npos,
            "refusal message names the member");
    }
    expect(caught, "refusal is catchable as RefusedError");
}

}

int main()
{
    scalars_are_little_endian();
    bools_and_enums_round_trip();
    strings_and_optionals_round_trip();
    containers_round_trip();
    truncated_input_is_a_format_error();
    defaults_match_zero_and_empty();
    refusal_names_the_member();
    if (failures != 0) {
        std::cerr << failures << " snapshot_io checks failed\n";
        return 1;
    }
    std::cout << "snapshot_io checks passed\n";
    return 0;
}
