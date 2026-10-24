// This Source Code Form is subject to the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Unit test for the machine image slab's region: the slab is kept while the
// region and its size stay the same, a new size retires it (the size set by
// --image-slab-mib), and a disabled region drops it. Build with BUILD_TESTING
// and run `ctest -R machine_image_region`.

#include "foundation/jit_artifact.hpp"

#include <cstddef>
#include <cstdio>

using namespace emulator;

namespace {

int failures = 0;

void check(bool condition, const char* expression, int line)
{
    if (condition)
        return;
    ++failures;
    std::fprintf(stderr, "machine_image_region_test.cpp:%d: check failed: %s\n",
        line, expression);
}

#define CHECK(expression) check((expression), #expression, __LINE__)

constexpr std::size_t mebibyte = 1024U * 1024U;

ImageCodeRegion region(std::size_t cache_bytes)
{
    return ImageCodeRegion { "rootfs|iPhone4,1", 0x30000000U, 0x40000000U,
        cache_bytes };
}

}  // namespace

int main()
{
    set_machine_image_code_region(region(8U * mebibyte));
    const auto first = machine_image_code_slab();
    CHECK(first != nullptr);
    CHECK(machine_image_code_region().cache_bytes == 8U * mebibyte);

    set_machine_image_code_region(region(8U * mebibyte));
    CHECK(machine_image_code_slab() == first);

    set_machine_image_code_region(region(16U * mebibyte));
    const auto resized = machine_image_code_slab();
    CHECK(resized != nullptr);
    CHECK(resized != first);
    CHECK(machine_image_code_region().cache_bytes == 16U * mebibyte);

    set_machine_image_code_region(ImageCodeRegion { });
    CHECK(machine_image_code_slab() == nullptr);
    CHECK(machine_image_code_region().cache_bytes == 0U);

    if (failures == 0)
        std::puts("machine_image_region_test: ok");
    return failures == 0 ? 0 : 1;
}
