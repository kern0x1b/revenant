// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
#include "foundation/load_average.hpp"

#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstdio>

namespace {

int failures = 0;

std::uint32_t read32(const std::array<std::byte, 16>& bytes, std::size_t offset)
{
    std::uint32_t value { };
    for (std::size_t index = 0; index < 4; ++index)
        value |= std::to_integer<std::uint32_t>(bytes[offset + index])
                 << (index * 8U);
    return value;
}

void check(bool condition, const char* expression, int line)
{
    if (condition)
        return;
    ++failures;
    std::fprintf(stderr, "load_average_test.cpp:%d: check failed: %s\n", line,
        expression);
}

#define CHECK(expression) check((expression), #expression, __LINE__)

}

int main()
{
    using emulator::foundation::LoadAverage;
    using emulator::foundation::load_average_decay;
    using emulator::foundation::load_average_period_seconds;
    using emulator::foundation::load_average_scale;

    CHECK(load_average_scale == 2048U);
    CHECK(load_average_period_seconds == 5U);

    CHECK(load_average_decay[0] == 1884U);
    CHECK(load_average_decay[1] == 2014U);
    CHECK(load_average_decay[2] == 2036U);
    for (std::size_t index = 0; index < load_average_decay.size(); ++index) {
        const double exponent = index == 0 ? -1.0 / 12.0 : index == 1 ? -1.0 / 60.0 : -1.0 / 180.0;
        const auto independent = static_cast<std::uint32_t>(std::exp(exponent) * 2048.0);
        CHECK(load_average_decay[index] == independent);
    }

    LoadAverage average;
    CHECK(average.fscale == 2048);
    CHECK(average.ldavg[0] == 0U && average.ldavg[1] == 0U && average.ldavg[2] == 0U);

    average.sample(1);
    CHECK(average.ldavg[0] == 164U);
    CHECK(average.ldavg[1] == 34U);
    CHECK(average.ldavg[2] == 12U);

    LoadAverage busy;
    for (int step = 0; step < 2000; ++step)
        busy.sample(3);
    CHECK(busy.ldavg[0] == 6132U);
    CHECK(busy.ldavg[1] == 6084U);
    CHECK(busy.ldavg[2] == 5974U);

    LoadAverage settling = busy;
    settling.sample(0);
    CHECK(settling.ldavg[0] < busy.ldavg[0]);
    LoadAverage idle = busy;
    for (int step = 0; step < 2000; ++step)
        idle.sample(0);
    CHECK(idle.ldavg[0] == 0U && idle.ldavg[1] == 0U && idle.ldavg[2] == 0U);

    const auto bytes = emulator::foundation::encode_user32_loadavg(busy);
    CHECK(bytes.size() == 16);
    CHECK(read32(bytes, 0) == 6132U);
    CHECK(read32(bytes, 4) == 6084U);
    CHECK(read32(bytes, 8) == 5974U);
    CHECK(read32(bytes, 12) == 2048U);
    CHECK(bytes[0] == std::byte { 0xf4 });

    if (failures == 0)
        std::printf("load_average: all checks passed\n");
    return failures == 0 ? 0 : 1;
}
