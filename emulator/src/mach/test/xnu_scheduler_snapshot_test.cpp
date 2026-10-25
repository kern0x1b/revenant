// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "mach/xnu_scheduler.hpp"
#include "foundation/snapshot_io.hpp"

#include <cstddef>
#include <cstdint>
#include <iostream>
#include <optional>
#include <string>
#include <vector>

namespace {

using emulator::XnuScheduledSlice;
using emulator::XnuScheduler;
using emulator::XnuSliceCompletion;
using emulator::XnuThreadId;
using emulator::snapshot::FormatError;
using emulator::snapshot::Reader;
using emulator::snapshot::Writer;

constexpr std::uint64_t quantum_ticks = 1000;
constexpr std::uint64_t tick_interval = 100;
constexpr std::size_t processor_count = 2;

int failures = 0;

void expect(bool condition, const std::string& what)
{
    if (condition)
        return;
    std::cerr << "FAIL: " << what << '\n';
    ++failures;
}

XnuScheduler make_scheduler(std::size_t processors)
{
    return XnuScheduler { quantum_ticks, tick_interval, processors };
}

std::vector<std::byte> save_scheduler(const XnuScheduler& scheduler)
{
    Writer out;
    scheduler.save(out);
    return out.bytes();
}

bool same_slice(const std::optional<XnuScheduledSlice>& left,
    const std::optional<XnuScheduledSlice>& right)
{
    if (!left || !right)
        return !left && !right;
    return left->thread == right->thread &&
           left->processor == right->processor &&
           left->tick_budget == right->tick_budget &&
           left->runnable_generation == right->runnable_generation &&
           left->front_continuation == right->front_continuation;
}

void populate(XnuScheduler& scheduler)
{
    expect(scheduler.register_thread({ 1, 1 }, 31, true),
        "register a runnable timeshare thread");
    expect(scheduler.register_thread({ 1, 2 }, 40, true),
        "register a second runnable thread");
    expect(scheduler.register_thread({ 2, 1 }, 20, true),
        "register a runnable thread in another process");
    expect(scheduler.register_thread({ 2, 2 }, 31, false),
        "register a waiting thread");
    expect(scheduler.bind_thread({ 1, 2 }, std::size_t { 1 }),
        "bind a thread to processor 1");
    expect(scheduler.set_realtime({ 2, 1 }, 100000, 20000, 50000, true),
        "make a thread realtime");
    expect(scheduler.depress({ 1, 1 }, 5000), "depress a thread");
    expect(scheduler.block({ 1, 1 }), "block the depressed thread");
    static_cast<void>(scheduler.choose_next(std::size_t { 0 }));
    scheduler.advance_time(300);
}

void round_trip_restores_the_queues_and_clocks()
{
    auto source = make_scheduler(processor_count);
    populate(source);
    const auto bytes = save_scheduler(source);

    auto restored = make_scheduler(processor_count);
    Reader in { bytes };
    restored.load(in);
    expect(in.at_end(), "the scheduler stream is consumed");
    expect(save_scheduler(restored) == bytes,
        "saving the restored scheduler reproduces the same stream");

    for (int step = 0; step < 6; ++step) {
        source.advance_time(1000);
        restored.advance_time(1000);
        const auto processor = static_cast<std::size_t>(step % 2);
        const auto from_source = source.choose_next(processor);
        const auto from_restored = restored.choose_next(processor);
        expect(same_slice(from_source, from_restored),
            "dispatch decisions match after the restore");
        if (from_source) {
            source.complete_slice(
                from_source->thread, 100, XnuSliceCompletion::Yield);
            restored.complete_slice(
                from_restored->thread, 100, XnuSliceCompletion::Yield);
        }
    }
    expect(save_scheduler(restored) == save_scheduler(source),
        "the restored and the source scheduler end in the same state");
}

void processor_count_mismatch_is_refused()
{
    auto source = make_scheduler(processor_count);
    populate(source);
    const auto bytes = save_scheduler(source);
    auto restored = make_scheduler(1);
    bool threw = false;
    try {
        Reader in { bytes };
        restored.load(in);
    } catch (const FormatError&) {
        threw = true;
    }
    expect(threw, "a scheduler with another processor count is refused");
}

void non_empty_scheduler_is_refused()
{
    auto source = make_scheduler(processor_count);
    populate(source);
    const auto bytes = save_scheduler(source);
    auto restored = make_scheduler(processor_count);
    expect(restored.register_thread({ 9, 9 }, 31, true),
        "register a thread before the restore");
    bool threw = false;
    try {
        Reader in { bytes };
        restored.load(in);
    } catch (const FormatError&) {
        threw = true;
    }
    expect(threw, "a scheduler that already holds threads is refused");
}

void truncated_stream_is_a_format_error()
{
    auto source = make_scheduler(processor_count);
    populate(source);
    const auto bytes = save_scheduler(source);
    const std::vector<std::byte> truncated { bytes.begin(),
        bytes.begin() + static_cast<std::ptrdiff_t>(bytes.size() / 2) };
    auto restored = make_scheduler(processor_count);
    bool threw = false;
    try {
        Reader in { truncated };
        restored.load(in);
    } catch (const FormatError&) {
        threw = true;
    }
    expect(threw, "a truncated scheduler stream throws FormatError");
}

}

int main()
{
    round_trip_restores_the_queues_and_clocks();
    processor_count_mismatch_is_refused();
    non_empty_scheduler_is_refused();
    truncated_stream_is_a_format_error();
    if (failures != 0) {
        std::cerr << failures << " XNU scheduler snapshot checks failed\n";
        return 1;
    }
    std::cout << "XNU scheduler snapshot checks passed\n";
    return 0;
}
