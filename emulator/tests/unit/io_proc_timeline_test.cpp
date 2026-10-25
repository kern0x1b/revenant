#include "media/io_proc_timeline.hpp"

#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstring>

namespace {

int failures = 0;

void check(bool ok, const char* name)
{
    std::printf("%s %s\n", ok ? "ok" : "FAIL", name);
    if (!ok)
        ++failures;
}

struct Run {
    std::uint64_t dispatches = 0;
    std::uint64_t underruns = 0;
    std::uint64_t last_dispatch = 0;
    bool off_grid = false;
};

Run simulate(bool timeline, std::uint64_t start, std::uint64_t period, std::uint64_t until)
{
    Run run;
    std::uint64_t next = 0;
    std::uint64_t now = start;
    bool in_flight = false;
    std::uint64_t complete_at = 0;
    std::uint64_t duration_index = 0;
    while (now <= until) {
        if (in_flight && complete_at <= now)
            in_flight = false;
        if (!in_flight && (next == 0 || next <= now)) {
            const auto due = next == 0 ? now : next;
            if (next != 0 && (due - start) % period != 0)
                run.off_grid = true;
            std::uint64_t following = 0;
            if (timeline) {
                const auto step = emulator::io_proc_timeline_after(due, now, period);
                following = step.next_deadline;
                run.underruns += step.underruns;
            } else {
                following = std::max(now, next) + period;
            }
            next = following;
            run.dispatches++;
            run.last_dispatch = now;
            const auto delayed = duration_index % 7 == 6;
            ++duration_index;
            in_flight = true;
            complete_at = now + (delayed ? 3 * period + period / 2 : period / 3);
        }
        std::uint64_t step_to = until + 1;
        if (in_flight)
            step_to = std::min(step_to, complete_at);
        else if (next != 0 && next > now)
            step_to = std::min(step_to, next);
        if (step_to <= now)
            step_to = now + 1;
        now = step_to;
    }
    return run;
}

}

int main(int argc, char** argv)
{
    const bool negative = argc > 1 && std::strcmp(argv[1], "--negative") == 0;
    const std::uint64_t period = 11'609'977ULL;
    const std::uint64_t start = 1'000'000'000ULL;

    const auto on_time = emulator::io_proc_timeline_after(start, start, period);
    check(on_time.next_deadline == start + period && on_time.underruns == 0,
        "a buffer on time schedules the next grid point with no underrun");
    const auto late = emulator::io_proc_timeline_after(start, start + 3 * period + period / 2, period);
    check(late.next_deadline == start + 4 * period && late.underruns == 3,
        "a buffer three and a half periods late records three underruns and stays on the grid");

    const auto timeline = simulate(true, start, period, start + 400 * period);
    const std::uint64_t covered = (timeline.last_dispatch - start) / period + 1;
    check(!timeline.off_grid, "every dispatch is due on the grid of the start time");
    check(timeline.dispatches + timeline.underruns == covered,
        "every grid point up to the last dispatch is either played or an underrun");
    check(timeline.underruns > 0, "delayed callbacks record underruns");

    if (negative) {
        const auto old = simulate(false, start, period, start + 400 * period);
        const std::uint64_t old_covered = (old.last_dispatch - start) / period + 1;
        check(old.dispatches + old.underruns == old_covered,
            "negative control: the old schedule drifts off the grid of the start time");
    }
    return failures == 0 ? 0 : 1;
}
