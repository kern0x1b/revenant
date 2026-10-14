// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Unit test for the guest block profile: accounting, image mapping and the
// report text. Build with BUILD_TESTING and run `ctest -R block_profile`.

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

shade::GuestImageTable sample_table()
{
    // Given out of order on purpose: the table sorts by load address.
    return shade::GuestImageTable { {
        { "/usr/lib/c.dylib", 0x3000U, 0x400U },
        { "/usr/lib/a.dylib", 0x1000U, 0x100U },
        { "/usr/lib/b.dylib", 0x2000U, 0U },
    } };
}

void test_image_lookup()
{
    const auto table = sample_table();
    const auto* first = table.find(0x1000U);
    CHECK(first != nullptr && first->path == "/usr/lib/a.dylib");
    CHECK(table.find(0x10ffU) != nullptr);
    CHECK(table.find(0x1100U) == nullptr);
    CHECK(table.find(0x0fffU) == nullptr);
    // Without a recorded __TEXT size, an image reaches the next image.
    const auto* second = table.find(0x2fffU);
    CHECK(second != nullptr && second->path == "/usr/lib/b.dylib");
    CHECK(table.find(0x3000U) != nullptr);
    CHECK(table.find(0x3400U) == nullptr);
    CHECK(shade::GuestImageTable { }.find(0x1000U) == nullptr);
}

void test_disabled_profile_records_nothing()
{
    shade::GuestBlockProfile profile;
    profile.record_run(1, 0x1000U, 5);
    profile.record_images(1, sample_table());
    CHECK(profile.rows().empty());
    CHECK(profile.total_ticks() == 0U);
    CHECK(profile.total_runs() == 0U);
    CHECK(profile.image_table_count() == 0U);
}

void fill(shade::GuestBlockProfile& profile)
{
    profile.set_enabled(true);
    profile.record_run(1, 0x1010U, 5);
    profile.record_run(1, 0x1010U, 7);
    profile.record_run(2, 0x1010U, 3);
    profile.record_run(1, 0x2000U, 20);
    profile.record_images(1, sample_table());
}

void test_accounting_and_order()
{
    shade::GuestBlockProfile profile;
    fill(profile);
    const auto rows = profile.rows();
    CHECK(rows.size() == 3U);
    if (rows.size() == 3U) {
        CHECK(rows[0].pid == 1U && rows[0].entry == 0x2000U);
        CHECK(rows[0].ticks == 20U && rows[0].runs == 1U);
        CHECK(rows[1].pid == 1U && rows[1].entry == 0x1010U);
        CHECK(rows[1].ticks == 12U && rows[1].runs == 2U);
        CHECK(rows[2].pid == 2U && rows[2].ticks == 3U);
    }
    CHECK(profile.total_ticks() == 35U);
    CHECK(profile.total_runs() == 4U);
}

void test_mapping()
{
    shade::GuestBlockProfile profile;
    fill(profile);
    const auto mapped = shade::map_block_profile(profile);
    CHECK(mapped.size() == 3U);
    if (mapped.size() == 3U) {
        CHECK(mapped[0].image == "/usr/lib/b.dylib" && mapped[0].offset == 0U);
        CHECK(
            mapped[1].image == "/usr/lib/a.dylib" && mapped[1].offset == 0x10U);
        // Pid 2 has no image table, so its entry stays unmapped.
        CHECK(mapped[2].image.empty());
    }
}

void test_table_text()
{
    shade::GuestBlockProfile profile;
    fill(profile);
    const auto text =
        shade::format_block_profile_table(shade::map_block_profile(profile));
    const std::string expected =
        "pid\tentry\tticks\truns\timage\toffset\n"
        "1\t0x00002000\t20\t1\t/usr/lib/b.dylib\t0x00000000\n"
        "1\t0x00001010\t12\t2\t/usr/lib/a.dylib\t0x00000010\n"
        "2\t0x00001010\t3\t1\t-\t-\n";
    CHECK(text == expected);
}

void test_summary_text()
{
    shade::GuestBlockProfile profile;
    fill(profile);
    const auto lines = shade::format_block_profile_summary(profile, 2);
    CHECK(!lines.empty());
    if (lines.empty())
        return;
    CHECK(lines[0] == "[perf-block] runs=4 ticks=35 entries=3 image-tables=1 "
                      "unmapped-ticks=3 unmapped-share=0.0857");
    // Two top rows and two image totals, the top-N limit applied to each.
    CHECK(lines.size() == 1U + 2U + 2U);
    if (lines.size() == 5U) {
        CHECK(lines[1] == "[perf-block-top] rank=1 pid=1 entry=0x00002000 "
                          "ticks=20 runs=1 share=0.5714 "
                          "image=/usr/lib/b.dylib offset=0x00000000");
        CHECK(lines[3] == "[perf-block-image] rank=1 image=/usr/lib/b.dylib "
                          "ticks=20 runs=1 share=0.5714");
    }
}

void test_clear()
{
    shade::GuestBlockProfile profile;
    fill(profile);
    profile.clear();
    CHECK(profile.rows().empty());
    CHECK(profile.total_ticks() == 0U);
    CHECK(profile.image_table_count() == 0U);
    CHECK(profile.enabled());
}

} // namespace

int main()
{
    test_image_lookup();
    test_disabled_profile_records_nothing();
    test_accounting_and_order();
    test_mapping();
    test_table_text();
    test_summary_text();
    test_clear();
    if (failures == 0)
        std::printf("block_profile: all checks passed\n");
    return failures == 0 ? 0 : 1;
}
