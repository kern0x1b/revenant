#pragma once

#include <cstdint>

namespace emulator {

struct IoProcTimelineStep {
    std::uint64_t next_deadline;
    std::uint64_t underruns;
};

[[nodiscard]] inline IoProcTimelineStep io_proc_timeline_after(
    std::uint64_t due_deadline, std::uint64_t now, std::uint64_t period)
{
    const auto missed = now > due_deadline ? (now - due_deadline) / period : 0U;
    return { due_deadline + (missed + 1U) * period, missed };
}

}
