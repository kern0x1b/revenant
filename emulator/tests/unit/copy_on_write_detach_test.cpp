// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
#include "foundation/address_space.hpp"
#include "foundation/performance.hpp"

#include <cstdint>
#include <cstdio>
#include <memory>

using namespace emulator;

namespace {

int failures = 0;

void check(bool condition, const char* expression, int line)
{
    if (condition)
        return;
    ++failures;
    std::fprintf(stderr,
        "copy_on_write_detach_test.cpp:%d: check failed: %s\n", line,
        expression);
}

#define CHECK(expression) check((expression), #expression, __LINE__)

}

int main()
{
    performance_counters().reset(true);

    AddressSpace parent;
    CHECK(parent.map(0x1000U, 0x3000U,
        MemoryPermission::Read | MemoryPermission::Write));
    CHECK(parent.write8(0x1000U, std::uint8_t { 1U }));
    CHECK(parent.write8(0x2000U, std::uint8_t { 1U }));
    CHECK(parent.write8(0x3000U, std::uint8_t { 1U }));

    auto child = parent.clone();
    CHECK(child != nullptr);
    CHECK(parent.unmap(0x2000U, 0x1000U));

    const auto before = address_space_write_stats().copy_on_write_detaches;
    CHECK(child->write8(0x1000U, std::uint8_t { 2U }));
    CHECK(child->write8(0x2000U, std::uint8_t { 2U }));
    CHECK(parent.write8(0x3000U, std::uint8_t { 2U }));
    const auto detaches =
        address_space_write_stats().copy_on_write_detaches - before;
    CHECK(detaches == 2U);

    CHECK(parent.read8(0x1000U, MemoryPermission::Read) ==
          std::optional<std::uint8_t> { 1U });
    CHECK(child->read8(0x1000U, MemoryPermission::Read) ==
          std::optional<std::uint8_t> { 2U });
    CHECK(child->read8(0x2000U, MemoryPermission::Read) ==
          std::optional<std::uint8_t> { 2U });
    CHECK(parent.read8(0x3000U, MemoryPermission::Read) ==
          std::optional<std::uint8_t> { 2U });
    CHECK(child->read8(0x3000U, MemoryPermission::Read) ==
          std::optional<std::uint8_t> { 1U });

    if (failures == 0)
        std::puts("copy_on_write_detach_test: ok");
    return failures == 0 ? 0 : 1;
}
