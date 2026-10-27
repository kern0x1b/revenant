// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Unit test for the surface attribute list and the surface use count: append,
// replace in place, erase by index, and the use count that never goes below
// zero. Run with `./xmakew test -P . surface_attributes` from the emulator.

#include "graphics/surface_attributes.hpp"

#include <cstdio>
#include <optional>

namespace {

int failures = 0;

void check(bool condition, const char* expression, int line)
{
    if (condition)
        return;
    ++failures;
    std::fprintf(stderr, "surface_attributes_test.cpp:%d: check failed: %s\n",
        line, expression);
}

#define CHECK(expression) check((expression), #expression, __LINE__)

void attributes_keep_their_order()
{
    emulator::SurfaceAttributes attributes;
    attributes.append(10, 11);
    attributes.append(20, 21);
    attributes.append(30, 31);
    CHECK(attributes.size() == 3);
    CHECK(attributes.at(1).key == 20 && attributes.at(1).value == 21);
}

void replace_keeps_the_position()
{
    emulator::SurfaceAttributes attributes;
    attributes.append(10, 11);
    attributes.append(20, 21);
    attributes.replace(0, 40, 41);
    CHECK(attributes.size() == 2);
    CHECK(attributes.at(0).key == 40 && attributes.at(0).value == 41);
    CHECK(attributes.at(1).key == 20);
}

void erase_shifts_the_later_entries()
{
    emulator::SurfaceAttributes attributes;
    attributes.append(10, 11);
    attributes.append(20, 21);
    attributes.append(30, 31);
    attributes.erase(1);
    CHECK(attributes.size() == 2);
    CHECK(attributes.at(0).key == 10);
    CHECK(attributes.at(1).key == 30 && attributes.at(1).value == 31);
}

void stale_indexes_are_ignored()
{
    emulator::SurfaceAttributes attributes;
    attributes.append(10, 11);
    attributes.erase(1);
    attributes.erase(5);
    attributes.replace(1, 40, 41);
    CHECK(attributes.size() == 1);
    CHECK(attributes.at(0).key == 10 && attributes.at(0).value == 11);
}

void find_key_locates_the_current_index()
{
    emulator::SurfaceAttributes attributes;
    attributes.append(10, 11);
    attributes.append(20, 21);
    attributes.append(30, 31);
    CHECK(attributes.find_key(30) == std::optional<std::size_t> { 2 });
    attributes.erase(0);
    CHECK(attributes.find_key(30) == std::optional<std::size_t> { 1 });
    CHECK(!attributes.find_key(10).has_value());
}

void use_count_never_goes_below_zero()
{
    emulator::SurfaceUseCount count;
    CHECK(count.count() == 0);
    CHECK(!count.in_use());
    count.decrement();
    CHECK(count.count() == 0);
    CHECK(!count.in_use());
}

void use_count_follows_increments_and_decrements()
{
    emulator::SurfaceUseCount count;
    count.increment();
    count.increment();
    CHECK(count.count() == 2);
    count.decrement();
    CHECK(count.count() == 1);
    CHECK(count.in_use());
    count.decrement();
    CHECK(count.count() == 0);
    CHECK(!count.in_use());
}

}

int main()
{
    attributes_keep_their_order();
    replace_keeps_the_position();
    erase_shifts_the_later_entries();
    stale_indexes_are_ignored();
    find_key_locates_the_current_index();
    use_count_never_goes_below_zero();
    use_count_follows_increments_and_decrements();
    if (failures != 0) {
        std::fprintf(stderr, "%d check(s) failed\n", failures);
        return 1;
    }
    return 0;
}
