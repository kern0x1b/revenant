// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
#include "foundation/address_space.hpp"

#include <cstdint>
#include <cstdio>

using namespace emulator;

namespace {

int failures = 0;

void check(bool condition, const char* expression, int line)
{
    if (condition)
        return;
    ++failures;
    std::fprintf(stderr,
        "materialized_page_counts_test.cpp:%d: check failed: %s\n", line,
        expression);
}

#define CHECK(expression) check((expression), #expression, __LINE__)

}

int main()
{
    AddressSpace memory;
    CHECK(memory.map(0x1000U, 0x3000U,
        MemoryPermission::Read | MemoryPermission::Write));
    CHECK(memory.materialized_page_counts().total() == 0U);

    CHECK(memory.write8(0x1000U, std::uint8_t { 1U }));
    CHECK(memory.write8(0x1004U, std::uint8_t { 2U }));
    CHECK(memory.write8(0x3000U, std::uint8_t { 3U }));
    const auto counts = memory.materialized_page_counts();
    CHECK(counts.total() == 2U);
    CHECK(counts.anonymous == 2U);
    CHECK(counts.file_cached == 0U);
    CHECK(counts.copy_on_write_possible == 0U);
    CHECK(counts.shared_writable == 0U);

    MaterializedPageCounts sum { };
    sum += counts;
    sum += counts;
    CHECK(sum.total() == 4U);
    CHECK(sum.anonymous == 4U);

    if (failures == 0)
        std::puts("materialized_page_counts_test: ok");
    return failures == 0 ? 0 : 1;
}
