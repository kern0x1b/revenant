// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Unit test for the guest block profile: exact, chained and short runs against
// the translated cycle counts, the per-block rows, the caller rows (block by
// guest LR), image mapping and the report text. Build with BUILD_TESTING and
// run `ctest -R block_profile`.

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

const shade::MappedCallerRow* find_caller(
    const std::vector<shade::MappedCallerRow>& rows, std::uint32_t caller)
{
    for (const auto& row : rows)
        if (row.row.caller == caller)
            return &row;
    return nullptr;
}

void test_image_table()
{
    const auto table = sample_table();
    CHECK(table.images().front().path == "/usr/lib/a.dylib");
    CHECK(table.find(0x1000U) != nullptr);
    CHECK(table.find(0x10ffU) != nullptr);
    CHECK(table.find(0x1100U) == nullptr);
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

    profile.record_translation(
        1U, 0x1000U, { 5U, shade::BlockEnd::LinkBlock });
    profile.record_translation(
        1U, 0x2000U, { 7U, shade::BlockEnd::LinkBlockFast });

    profile.record_run(1U, 0x1000U, 0x1000U, false, 5U, 0U);
    profile.record_run(1U, 0x1000U, 0x1000U, false, 5U, 0U);
    profile.record_run(1U, 0x2000U, 0x2000U, true, 12U, 0U);
    profile.record_run(1U, 0x2000U, 0x2000U, true, 3U, 0U);
    profile.record_run(1U, 0x3000U, 0x3000U, false, 4U, 0U);

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
    profile.record_run(1U, 0x1000U, 0x1000U, false, 5U, 0U);
    profile.record_run(2U, 0x1000U, 0x1000U, false, 9U, 0U);
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
    profile.record_run(1U, 0x1000U, 0x1000U, false, 5U, 0x3020U);
    profile.record_images(1U, sample_table());
    CHECK(profile.image_table_count() == 0U);
    profile.set_enabled(true);
    profile.record_images(1U, sample_table());
    CHECK(profile.image_table_count() == 1U);

    profile.clear();
    CHECK(profile.rows().empty());
    CHECK(profile.callers().empty());
    CHECK(profile.translation_count() == 0U);
    CHECK(profile.image_table_count() == 0U);
    CHECK(profile.enabled());
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
    profile.record_run(1U, 0x3010U, 0x3010U, false, 4U, 0U);
    profile.record_run(1U, 0x1010U, 0x1010U, false, 9U, 0U);
    profile.record_run(1U, 0x7000U, 0x7000U, false, 2U, 0U);

    const auto mapped = shade::map_block_rows(profile);
    CHECK(mapped.size() == 3U);
    if (mapped.size() == 3U) {
        CHECK(mapped[0].row.entry == 0x1010U);
        CHECK(mapped[0].image == "/usr/lib/a.dylib");
        CHECK(mapped[0].offset == 0x10U);
        CHECK(mapped[1].image == "/usr/lib/c.dylib");
        CHECK(mapped[1].offset == 0x10U);
        CHECK(mapped[2].image.empty());
    }

    const auto table = shade::format_block_table(mapped);
    CHECK(contains(table,
        "pid\tentry\tthumb\tcycles\truns\tticks\texact_runs\texact_ticks\t"
        "chained_runs\tshort_runs\tunknown_runs\timage\toffset\n"));
    CHECK(contains(table, "0x00001010\t0\t9\t1\t9\t1\t9\t0\t0\t0\t"
                          "/usr/lib/a.dylib\t0x00000010"));
    CHECK(contains(table, "\t-\t-\n"));
}

void test_caller_rows()
{
    shade::GuestBlockProfile profile;
    profile.set_enabled(true);
    profile.record_images(1U, sample_table());
    profile.record_translation(
        1U, 0x1010U, { 5U, shade::BlockEnd::LinkBlock });
    profile.record_translation(
        1U, 0x3010U, { 4U, shade::BlockEnd::LinkBlock });

    profile.record_run(1U, 0x1010U, 0x1010U, false, 5U, 0x3021U);
    profile.record_run(1U, 0x1010U, 0x1010U, false, 5U, 0x3021U);
    profile.record_run(1U, 0x1010U, 0x1010U, false, 5U, 0x3100U);
    profile.record_run(1U, 0x1010U, 0x1010U, false, 5U, 0x7000U);
    profile.record_run(1U, 0x3010U, 0x3010U, false, 4U, 0x3021U);

    const auto callers = profile.callers();
    CHECK(callers.size() == 4U);
    std::uint64_t caller_ticks = 0;
    for (const auto& row : callers)
        caller_ticks += row.ticks;
    std::uint64_t block_ticks = 0;
    for (const auto& row : profile.rows())
        block_ticks += row.ticks;
    CHECK(caller_ticks == block_ticks);

    const auto mapped = shade::map_caller_rows(profile);
    CHECK(mapped.size() == 4U);
    const auto* thumb = find_caller(mapped, 0x3021U);
    CHECK(thumb != nullptr);
    if (thumb) {
        CHECK(thumb->row.location == 0x1010U);
        CHECK(thumb->row.runs == 2U);
        CHECK(thumb->row.ticks == 10U);
        CHECK(thumb->image == "/usr/lib/a.dylib");
        CHECK(thumb->offset == 0x10U);
        CHECK(thumb->caller_image == "/usr/lib/c.dylib");
        CHECK(thumb->caller_offset == 0x20U);
    }
    const auto* plain = find_caller(mapped, 0x3100U);
    CHECK(plain != nullptr);
    if (plain) {
        CHECK(plain->row.runs == 1U);
        CHECK(plain->caller_image == "/usr/lib/c.dylib");
        CHECK(plain->caller_offset == 0x100U);
    }
    const auto* unmapped = find_caller(mapped, 0x7000U);
    CHECK(unmapped != nullptr);
    if (unmapped) {
        CHECK(unmapped->caller_image.empty());
        CHECK(unmapped->image == "/usr/lib/a.dylib");
    }

    CHECK(!mapped.empty() && mapped.front().row.caller == 0x3021U);

    const auto table = shade::format_caller_table(mapped);
    CHECK(contains(table,
        "pid\tentry\tthumb\timage\toffset\tcaller\tcaller_image\t"
        "caller_offset\truns\tticks\n"));
    CHECK(contains(table, "1\t0x00001010\t0\t/usr/lib/a.dylib\t0x00000010\t"
                          "0x00003021\t/usr/lib/c.dylib\t0x00000020\t2\t10\n"));
    CHECK(contains(table, "1\t0x00001010\t0\t/usr/lib/a.dylib\t0x00000010\t"
                          "0x00007000\t-\t-\t1\t5\n"));
}

void test_mapping_order_and_summary()
{
    shade::GuestBlockProfile profile;
    profile.set_enabled(true);
    profile.record_translation(
        1U, 0x1000U, { 5U, shade::BlockEnd::LinkBlock });
    profile.record_run(1U, 0x1000U, 0x1000U, false, 5U, 0U);
    profile.record_run(1U, 0x1000U, 0x1000U, false, 5U, 0U);

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

struct SyntheticStack {
    std::map<std::uint32_t, std::uint32_t> words;

    shade::GuestReader reader() const
    {
        return [this](std::uint32_t address)
                   -> std::optional<std::uint32_t> {
            const auto found = words.find(address);
            if (found == words.end())
                return std::nullopt;
            return found->second;
        };
    }
};

const shade::AddressRanges kOwn { { 0x1000U, 0x2000U } };

void test_own_ranges()
{
    const shade::GuestImageTable images { {
        shade::GuestImage { "/usr/lib/charon/org.charon.emulatelaunchd/"
                     "libFoundationBackports.dylib",
            0x1000U, 0x800U },
        shade::GuestImage { "/usr/lib/libobjc.A.dylib", 0x3000U, 0x1000U },
        shade::GuestImage { "/usr/lib/charon/no-text.dylib", 0x6000U, 0U },
    } };
    const auto ranges = shade::own_text_ranges(images);
    CHECK(ranges.size() == 1);
    CHECK(ranges.size() == 1 && ranges.front().first == 0x1000U);
    CHECK(ranges.size() == 1 && ranges.front().second == 0x1800U);
}

void test_stack_walk()
{
    using Kind = shade::StackAttribution::Kind;
    const auto walk = [](std::uint32_t pc, std::uint32_t lr,
                          std::uint32_t frame, const SyntheticStack& stack,
                          std::size_t max_frames = 32) {
        return shade::attribute_stack(
            pc, lr, frame, kOwn, stack.reader(), max_frames);
    };

    const auto self = walk(0x1040U, 0x3000U, 0U, {});
    CHECK(self.kind == Kind::Self && self.address == 0x1040U);

    const auto leaf = walk(0x3010U, 0x1045U, 0x9999U, {});
    CHECK(leaf.kind == Kind::Caller && leaf.address == 0x1044U);

    SyntheticStack ours_second;
    ours_second.words = { { 0x8000U, 0x8100U }, { 0x8004U, 0x3030U },
        { 0x8100U, 0x8200U }, { 0x8104U, 0x1050U } };
    const auto chained = walk(0x3010U, 0x3020U, 0x8000U, ours_second);
    CHECK(chained.kind == Kind::Caller && chained.address == 0x1050U);

    SyntheticStack apple_only;
    apple_only.words = { { 0x8000U, 0x8100U }, { 0x8004U, 0x3030U },
        { 0x8100U, 0U }, { 0x8104U, 0x3090U } };
    const auto system = walk(0x3010U, 0x3020U, 0x8000U, apple_only);
    CHECK(system.kind == Kind::System && system.address == 0x3090U);

    SyntheticStack falling;
    falling.words = { { 0x8000U, 0x7f00U }, { 0x8004U, 0x3030U },
        { 0x7f00U, 0x0U }, { 0x7f04U, 0x1050U } };
    const auto stopped = walk(0x3010U, 0x3020U, 0x8000U, falling);
    CHECK(stopped.kind == Kind::System && stopped.address == 0x3030U);

    const auto misaligned = walk(0x3010U, 0x3020U, 0x8002U, ours_second);
    CHECK(misaligned.kind == Kind::System && misaligned.address == 0x3010U);

    const auto unreadable = walk(0x3010U, 0x3020U, 0x9000U, ours_second);
    CHECK(unreadable.kind == Kind::System && unreadable.address == 0x3010U);

    SyntheticStack deep;
    for (std::uint32_t index = 0; index < 40; ++index) {
        const auto frame = 0x10000U + index * 0x100U;
        deep.words[frame] = frame + 0x100U;
        deep.words[frame + 4U] = index == 34U ? 0x1050U : 0x3030U;
    }
    const auto bounded = walk(0x3010U, 0x3020U, 0x10000U, deep, 32);
    CHECK(bounded.kind == Kind::System && bounded.address == 0x3030U);
    const auto reached = walk(0x3010U, 0x3020U, 0x10000U, deep, 40);
    CHECK(reached.kind == Kind::Caller && reached.address == 0x1050U);
}

void test_stack_rows()
{
    shade::GuestBlockProfile profile;
    profile.set_enabled(true);
    profile.record_images(1, shade::GuestImageTable { {
        shade::GuestImage { "/usr/lib/charon/a.dylib", 0x1000U, 0x800U },
        shade::GuestImage { "/usr/lib/libobjc.A.dylib", 0x3000U, 0x1000U },
    } });
    profile.record_stack(1, { shade::StackAttribution::Kind::Self, 0x1040U }, 10);
    profile.record_stack(1, { shade::StackAttribution::Kind::Caller, 0x1050U }, 5);
    profile.record_stack(1, { shade::StackAttribution::Kind::Caller, 0x1050U }, 7);
    profile.record_stack(1, { shade::StackAttribution::Kind::System, 0x3030U }, 3);
    CHECK(profile.stacks().size() == 3);

    const auto mapped = shade::map_stack_rows(profile);
    CHECK(mapped.size() == 3);
    CHECK(mapped.size() == 3 && mapped.front().row.ticks == 12U);
    CHECK(mapped.size() == 3 && mapped.front().image == "/usr/lib/charon/a.dylib");
    CHECK(mapped.size() == 3 && mapped.front().offset == 0x50U);

    const auto summary = shade::format_stack_summary(profile);
    CHECK(summary == "[perf-block-stack] self-ticks=10 caller-ticks=12 "
                     "system-ticks=3 total-ticks=25");
    const auto table = shade::format_stack_table(mapped);
    CHECK(contains(table, "pid\tkind\taddress\timage\toffset\truns\tticks\n"));
    CHECK(contains(table, "1\tcaller\t0x00001050\t/usr/lib/charon/a.dylib\t"
                          "0x00000050\t2\t12\n"));

    profile.note_image_info(1, 0x5000U);
    CHECK(profile.image_info_address(1) == 0x5000U);
    CHECK(profile.image_info_address(2) == 0U);
    profile.clear();
    CHECK(profile.stacks().empty());
    CHECK(profile.image_info_address(1) == 0x5000U);
}

void test_stack_chain()
{
    SyntheticStack ours_second;
    ours_second.words = { { 0x8000U, 0x8100U }, { 0x8004U, 0x3030U },
        { 0x8100U, 0x8200U }, { 0x8104U, 0x1050U } };
    const auto chain = shade::capture_stack_chain(
        0x3010U, 0x3021U, 0x8000U, ours_second.reader());
    CHECK(chain == std::vector<std::uint32_t>({ 0x3010U, 0x3020U, 0x3030U,
                       0x1050U }));

    SyntheticStack falling;
    falling.words = { { 0x8000U, 0x7f00U }, { 0x8004U, 0x3030U },
        { 0x7f00U, 0x0U }, { 0x7f04U, 0x1050U } };
    const auto stopped = shade::capture_stack_chain(
        0x3010U, 0x3020U, 0x8000U, falling.reader());
    CHECK(stopped == std::vector<std::uint32_t>({ 0x3010U, 0x3020U,
                         0x3030U }));

    const auto misaligned = shade::capture_stack_chain(
        0x3010U, 0x3020U, 0x8002U, ours_second.reader());
    CHECK(misaligned == std::vector<std::uint32_t>({ 0x3010U, 0x3020U }));

    SyntheticStack deep;
    for (std::uint32_t index = 0; index < 40; ++index) {
        const auto frame = 0x10000U + index * 0x100U;
        deep.words[frame] = frame + 0x100U;
        deep.words[frame + 4U] = index == 34U ? 0x1050U : 0x3030U;
    }
    const auto bounded = shade::capture_stack_chain(
        0x3010U, 0x3020U, 0x10000U, deep.reader());
    CHECK(bounded.size() == 2 + 16);
    const auto longer = shade::capture_stack_chain(
        0x3010U, 0x3020U, 0x10000U, deep.reader(), 40);
    CHECK(longer.size() == 2 + 40);
    CHECK(longer.size() == 42 && longer[36] == 0x1050U);
}

void test_chain_rows()
{
    shade::GuestBlockProfile profile;
    profile.set_enabled(true);
    profile.record_images(1, shade::GuestImageTable { {
        shade::GuestImage { "/usr/lib/charon/a.dylib", 0x1000U, 0x800U },
        shade::GuestImage { "/usr/lib/libsystem_c.dylib", 0x3000U, 0x1000U },
    } });
    profile.record_chain(
        1, 7, 0x3010U, 0x3010U, false, { 0x3010U, 0x3020U, 0x1050U }, 10);
    profile.record_chain(
        1, 7, 0x3010U, 0x3010U, false, { 0x3010U, 0x3020U, 0x1050U }, 5);
    profile.record_chain(
        1, 7, 0x3010U, 0x3010U, false, { 0x3010U, 0x3020U, 0x3090U }, 3);
    CHECK(profile.chains().size() == 2);
    profile.record_chain(
        1, 8, 0x3010U, 0x3010U, false, { 0x3010U, 0x3020U, 0x1050U }, 4);
    CHECK(profile.chains().size() == 3);

    const auto table = shade::format_chain_table(profile);
    CHECK(contains(table,
        "pid\tthread\tlocation\tentry\tthumb\truns\tticks\tdepth\tframes\n"));
    CHECK(contains(table, "1\t7\t0x0000000000003010\t0x00003010\t0\t2\t15\t3\t"
                          "/usr/lib/libsystem_c.dylib+0x00000010 "
                          "/usr/lib/libsystem_c.dylib+0x00000020 "
                          "/usr/lib/charon/a.dylib+0x00000050\n"));
    CHECK(contains(table, "1\t8\t0x0000000000003010\t0x00003010\t0\t1\t4\t3\t"
                          "/usr/lib/libsystem_c.dylib+0x00000010 "
                          "/usr/lib/libsystem_c.dylib+0x00000020 "
                          "/usr/lib/charon/a.dylib+0x00000050\n"));
    CHECK(contains(table, "1\t7\t0x0000000000003010\t0x00003010\t0\t1\t3\t3\t"
                          "/usr/lib/libsystem_c.dylib+0x00000010 "
                          "/usr/lib/libsystem_c.dylib+0x00000020 "
                          "/usr/lib/libsystem_c.dylib+0x00000090\n"));

    const auto capped = shade::format_chain_table(profile, 1);
    CHECK(contains(capped,
        "1\t7\t0x0000000000003010\t0x00003010\t0\t2\t15\t3\t"));
    CHECK(!contains(capped, "1\t8\t"));
    CHECK(shade::format_chain_table(profile, 0) ==
          "pid\tthread\tlocation\tentry\tthumb\truns\tticks\tdepth\tframes\n");

    const auto threads = shade::format_thread_summary(profile);
    CHECK(threads.size() == 2);
    CHECK(threads.size() == 2 &&
          threads[0] == "[perf-block-thread] pid=1 thread=7 runs=3 ticks=18 "
                        "share=0.8182");
    CHECK(threads.size() == 2 &&
          threads[1] == "[perf-block-thread] pid=1 thread=8 runs=1 ticks=4 "
                        "share=0.1818");

    profile.clear();
    CHECK(profile.chains().empty());
}

}

int main()
{
    test_image_table();
    test_own_ranges();
    test_stack_walk();
    test_stack_rows();
    test_stack_chain();
    test_chain_rows();
    test_run_classification();
    test_pids_keep_rows_apart();
    test_clear_and_images();
    test_mapping_and_order();
    test_caller_rows();
    test_mapping_order_and_summary();
    if (failures == 0) {
        std::printf("block_profile_test: all checks passed\n");
        return 0;
    }
    std::fprintf(stderr, "block_profile_test: %d check(s) failed\n", failures);
    return 1;
}
