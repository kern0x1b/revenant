// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Unit test for the guest block profile: exact, chained and short runs against
// the translated cycle counts, the per-block rows, image mapping and the report
// text. Build with BUILD_TESTING and run `ctest -R block_profile`.

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
    } };
}

const shade::BlockRow* find_row(
    const std::vector<shade::BlockRow>& rows, std::uint64_t location)
{
    for (const auto& row : rows)
        if (row.location == location)
            return &row;
    return nullptr;
}

void test_image_table()
{
    const auto table = sample_table();
    CHECK(table.images().front().path == "/usr/lib/a.dylib");
    CHECK(table.find(0x1000U) != nullptr);
    CHECK(table.find(0x10ffU) != nullptr);
    CHECK(table.find(0x1100U) == nullptr); // past __TEXT, before the next image
    CHECK(table.find(0x2fffU) == nullptr);
    CHECK(table.find(0x3200U) != nullptr);
    CHECK(table.find(0x0fffU) == nullptr);
    CHECK(table.find(0x9000U) == nullptr);
}

void test_run_classification()
{
    shade::GuestBlockProfile profile;
    profile.set_enabled(true);
    CHECK(profile.enabled());

    // Block A: 5 cycles, ends in a checked link. Block B: 7 cycles, fast link.
    profile.record_translation(
        1U, 0x1000U, { 5U, shade::BlockEnd::LinkBlock });
    profile.record_translation(
        1U, 0x2000U, { 7U, shade::BlockEnd::LinkBlockFast });

    profile.record_run(1U, 0x1000U, 0x1000U, false, 5U); // exact
    profile.record_run(1U, 0x1000U, 0x1000U, false, 5U); // exact
    profile.record_run(1U, 0x2000U, 0x2000U, true, 12U); // chained: 7 + 5
    profile.record_run(1U, 0x2000U, 0x2000U, true, 3U); // short
    profile.record_run(1U, 0x3000U, 0x3000U, false, 4U); // never translated

    const auto rows = profile.rows();
    CHECK(rows.size() == 3U);
    CHECK(profile.translation_count() == 2U);

    const auto* a = find_row(rows, 0x1000U);
    CHECK(a != nullptr);
    if (a) {
        CHECK(a->runs == 2U);
        CHECK(a->ticks == 10U);
        CHECK(a->cycles == 5U);
        CHECK(a->exact_runs == 2U);
        CHECK(a->exact_ticks == 10U);
        CHECK(a->chained_runs == 0U);
        CHECK(a->short_runs == 0U);
        CHECK(a->unknown_runs == 0U);
        CHECK(a->entry == 0x1000U);
        CHECK(!a->thumb);
    }

    const auto* b = find_row(rows, 0x2000U);
    CHECK(b != nullptr);
    if (b) {
        CHECK(b->runs == 2U);
        CHECK(b->ticks == 15U);
        CHECK(b->exact_runs == 0U);
        CHECK(b->chained_runs == 1U);
        CHECK(b->short_runs == 1U);
        CHECK(b->unknown_runs == 0U);
        CHECK(b->entry == 0x2000U);
        CHECK(b->thumb);
    }

    const auto* c = find_row(rows, 0x3000U);
    CHECK(c != nullptr);
    if (c) {
        CHECK(c->runs == 1U);
        CHECK(c->cycles == 0U);
        CHECK(c->unknown_runs == 1U);
        CHECK(c->exact_runs == 0U);
    }
}

void test_pids_keep_rows_apart()
{
    shade::GuestBlockProfile profile;
    profile.record_translation(
        1U, 0x1000U, { 5U, shade::BlockEnd::LinkBlock });
    profile.record_translation(
        2U, 0x1000U, { 9U, shade::BlockEnd::Other });
    profile.record_run(1U, 0x1000U, 0x1000U, false, 5U);
    profile.record_run(2U, 0x1000U, 0x1000U, false, 9U);
    CHECK(profile.rows().size() == 2U);
    std::uint64_t exact = 0;
    for (const auto& row : profile.rows())
        exact += row.exact_runs;
    CHECK(exact == 2U);
}

void test_clear_and_images()
{
    shade::GuestBlockProfile profile;
    profile.record_translation(
        1U, 0x1000U, { 5U, shade::BlockEnd::LinkBlock });
    profile.record_run(1U, 0x1000U, 0x1000U, false, 5U);
    profile.record_images(1U, sample_table());
    CHECK(profile.image_table_count() == 0U); // not enabled: nothing recorded
    profile.set_enabled(true);
    profile.record_images(1U, sample_table());
    CHECK(profile.image_table_count() == 1U);

    profile.clear();
    CHECK(profile.rows().empty());
    CHECK(profile.translation_count() == 0U);
    CHECK(profile.image_table_count() == 0U);
    CHECK(profile.enabled()); // clearing keeps the switch
}

void test_mapping_and_order()
{
    shade::GuestBlockProfile profile;
    profile.set_enabled(true);
    profile.record_images(1U, sample_table());
    profile.record_translation(
        1U, 0x3010U, { 4U, shade::BlockEnd::LinkBlock });
    profile.record_translation(
        1U, 0x1010U, { 9U, shade::BlockEnd::LinkBlock });
    profile.record_translation(
        1U, 0x7000U, { 2U, shade::BlockEnd::LinkBlock });
    profile.record_run(1U, 0x3010U, 0x3010U, false, 4U);
    profile.record_run(1U, 0x1010U, 0x1010U, false, 9U);
    profile.record_run(1U, 0x7000U, 0x7000U, false, 2U);

    const auto mapped = shade::map_block_rows(profile);
    CHECK(mapped.size() == 3U);
    if (mapped.size() == 3U) {
        CHECK(mapped[0].row.entry == 0x1010U); // largest ticks first
        CHECK(mapped[0].image == "/usr/lib/a.dylib");
        CHECK(mapped[0].offset == 0x10U);
        CHECK(mapped[1].image == "/usr/lib/c.dylib");
        CHECK(mapped[1].offset == 0x10U);
        CHECK(mapped[2].image.empty()); // no image holds 0x7000
    }

    const auto table = shade::format_block_table(mapped);
    CHECK(contains(table,
        "pid\tentry\tthumb\tcycles\truns\tticks\texact_runs\texact_ticks\t"
        "chained_runs\tshort_runs\tunknown_runs\timage\toffset\n"));
    CHECK(contains(table, "0x00001010\t0\t9\t1\t9\t1\t9\t0\t0\t0\t"
                          "/usr/lib/a.dylib\t0x00000010"));
    CHECK(contains(table, "\t-\t-\n"));
}

void test_summary_conservation()
{
    shade::GuestBlockProfile profile;
    profile.set_enabled(true);
    profile.record_translation(
        1U, 0x1000U, { 5U, shade::BlockEnd::LinkBlock });
    profile.record_run(1U, 0x1000U, 0x1000U, false, 5U);
    profile.record_run(1U, 0x1000U, 0x1000U, false, 5U);

    const auto lines = shade::format_block_summary(profile, 10U, 30U);
    CHECK(!lines.empty());
    if (!lines.empty()) {
        CHECK(contains(lines.front(), "[perf-block] rows=1 runs=2 ticks=10 "));
        CHECK(contains(lines.front(), "cpu-ticks=10 difference=0 "));
        CHECK(contains(lines.front(), "exact-runs=2 exact-ticks=10 "));
        CHECK(contains(lines.front(), "exact-share=1.0000"));
        CHECK(contains(lines.front(), "unmapped-share=1.0000"));
    }
    bool has_top = false;
    for (const auto& line : lines)
        has_top = has_top || contains(line, "[perf-block-top] rank=1 ");
    CHECK(has_top);

    const auto off = shade::format_block_summary(profile, 12U, 30U);
    CHECK(!off.empty() && contains(off.front(), "difference=-2 "));
}

} // namespace

int main()
{
    test_image_table();
    test_run_classification();
    test_pids_keep_rows_apart();
    test_clear_and_images();
    test_mapping_and_order();
    test_summary_conservation();
    if (failures == 0) {
        std::printf("block_profile_test: all checks passed\n");
        return 0;
    }
    std::fprintf(stderr, "block_profile_test: %d check(s) failed\n", failures);
    return 1;
}
