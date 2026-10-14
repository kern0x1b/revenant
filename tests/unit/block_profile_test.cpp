// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Unit test for the guest block profile: counter slots, executions and ticks,
// image mapping and the report text. Build with BUILD_TESTING and run
// `ctest -R block_profile`.

#include "foundation/block_profile.hpp"

#include <cstdio>
#include <string>
#include <vector>

namespace {

int failures = 0;

void check(bool condition, const char* expression, int line)
{
    if (condition)
        return;
    ++failures;
    std::fprintf(stderr, "block_profile_test.cpp:%d: check failed: %s\n", line,
        expression);
}

#define CHECK(expression) check((expression), #expression, __LINE__)

bool contains(const std::string& text, const std::string& part)
{
    return text.find(part) != std::string::npos;
}

shade::GuestImageTable sample_table()
{
    // Given out of order on purpose: the table sorts by load address.
    return shade::GuestImageTable { {
        { "/usr/lib/c.dylib", 0x3000U, 0x400U },
        { "/usr/lib/a.dylib", 0x1000U, 0x100U },
        { "/usr/lib/b.dylib", 0x2000U, 0U },
    } };
}

void test_slots_need_a_reserved_table()
{
    shade::GuestBlockProfile profile;
    CHECK(!profile.allocate_counter(1U, 0x1000U, false).has_value());
    profile.reserve_counters(2U);
    CHECK(profile.allocate_counter(1U, 0x1000U, false) == 0U);
    CHECK(profile.allocate_counter(1U, 0x1004U, true) == 1U);
    CHECK(!profile.allocate_counter(1U, 0x1008U, false).has_value());
    CHECK(profile.dropped_blocks() == 1U);
    CHECK(profile.counters().size() == 2U);
}

void test_executions_and_cycles()
{
    shade::GuestBlockProfile profile;
    profile.reserve_counters(4U);
    const auto slot = profile.allocate_counter(3U, 0x1010U, false);
    CHECK(slot.has_value());
    profile.set_counter_cycles(*slot, 5U);
    profile.count_execution(*slot);
    profile.count_execution(*slot);
    profile.count_execution(*slot);
    const auto counters = profile.counters();
    CHECK(counters.size() == 1U);
    CHECK(counters[0].pid == 3U);
    CHECK(counters[0].entry == 0x1010U);
    CHECK(!counters[0].thumb);
    CHECK(counters[0].cycles == 5U);
    CHECK(counters[0].executions == 3U);
    const auto mapped = shade::map_block_counters(profile);
    CHECK(mapped.size() == 1U);
    CHECK(mapped[0].ticks == 15U);
}

void test_mapping_and_order()
{
    shade::GuestBlockProfile profile;
    profile.set_enabled(true);
    profile.reserve_counters(8U);
    profile.record_images(3U, sample_table());
    const auto inside_a = profile.allocate_counter(3U, 0x1010U, false);
    const auto inside_c = profile.allocate_counter(3U, 0x3008U, true);
    const auto unmapped = profile.allocate_counter(3U, 0x5000U, false);
    profile.set_counter_cycles(*inside_a, 4U);
    profile.set_counter_cycles(*inside_c, 100U);
    profile.set_counter_cycles(*unmapped, 1U);
    profile.count_execution(*inside_a);
    profile.count_execution(*inside_a);
    profile.count_execution(*inside_c);
    profile.count_execution(*unmapped);

    const auto mapped = shade::map_block_counters(profile);
    CHECK(mapped.size() == 3U);
    // Largest ticks first: 100 (c), 8 (a), 1 (unmapped).
    CHECK(mapped[0].ticks == 100U);
    CHECK(mapped[0].counter.thumb);
    CHECK(mapped[0].image == "/usr/lib/c.dylib");
    CHECK(mapped[0].offset == 0x8U);
    CHECK(mapped[1].ticks == 8U);
    CHECK(mapped[1].image == "/usr/lib/a.dylib");
    CHECK(mapped[1].offset == 0x10U);
    CHECK(mapped[2].ticks == 1U);
    CHECK(mapped[2].image.empty());
}

void test_table_text()
{
    shade::GuestBlockProfile profile;
    profile.set_enabled(true);
    profile.reserve_counters(2U);
    profile.record_images(3U, sample_table());
    const auto slot = profile.allocate_counter(3U, 0x1010U, false);
    profile.set_counter_cycles(*slot, 4U);
    profile.count_execution(*slot);
    profile.count_execution(*slot);
    const auto text =
        shade::format_block_counter_table(shade::map_block_counters(profile));
    CHECK(text.rfind("pid\tentry\tthumb\tcycles\texecutions\tticks\timage\toffset\n",
              0) == 0);
    CHECK(contains(text,
        "3\t0x00001010\t0\t4\t2\t8\t/usr/lib/a.dylib\t0x00000010\n"));
}

void test_summary_conservation()
{
    shade::GuestBlockProfile profile;
    profile.set_enabled(true);
    profile.reserve_counters(8U);
    profile.record_images(3U, sample_table());
    const auto inside_c = profile.allocate_counter(3U, 0x3008U, true);
    const auto unmapped = profile.allocate_counter(3U, 0x5000U, false);
    profile.set_counter_cycles(*inside_c, 100U);
    profile.set_counter_cycles(*unmapped, 1U);
    profile.count_execution(*inside_c);
    profile.count_execution(*unmapped);

    const auto lines = shade::format_block_counter_summary(profile, 100U, 5U);
    CHECK(!lines.empty());
    CHECK(contains(lines[0], " ticks=101 "));
    CHECK(contains(lines[0], " cpu-ticks=100 "));
    CHECK(contains(lines[0], " difference=1 "));
    CHECK(contains(lines[0], " unmapped-ticks=1 "));
    CHECK(contains(lines[0], " dropped-blocks=0 "));
    CHECK(lines.size() == 4U); // totals, two blocks, one image
    CHECK(contains(lines[1], "[perf-block-top] rank=1 pid=3 entry=0x00003008 thumb=1"));
    CHECK(contains(lines[3], "[perf-block-image] rank=1 image=/usr/lib/c.dylib ticks=100"));
}

void test_clear_keeps_reserved_slots()
{
    shade::GuestBlockProfile profile;
    profile.set_enabled(true);
    profile.reserve_counters(2U);
    const auto slot = profile.allocate_counter(1U, 0x1000U, false);
    profile.count_execution(*slot);
    profile.clear();
    CHECK(profile.counters().empty());
    CHECK(profile.dropped_blocks() == 0U);
    CHECK(profile.allocate_counter(1U, 0x1000U, false) == 0U);
    CHECK(profile.counters()[0].executions == 0U);
}

} // namespace

int main()
{
    test_slots_need_a_reserved_table();
    test_executions_and_cycles();
    test_mapping_and_order();
    test_table_text();
    test_summary_conservation();
    test_clear_keeps_reserved_slots();
    if (failures != 0) {
        std::fprintf(stderr, "block_profile_test: %d failure(s)\n", failures);
        return 1;
    }
    std::puts("block_profile_test: all checks passed");
    return 0;
}
