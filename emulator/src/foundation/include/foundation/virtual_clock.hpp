// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Maintain guest monotonic and calendar time and convert between
// device time domains.

#pragma once

#include "foundation/snapshot_io.hpp"

#include <atomic>
#include <cstdint>

namespace emulator {

class VirtualClock {
public:
    static constexpr std::uint64_t default_initial_time = 1'000'000;
    static constexpr std::uint64_t default_wall_time_epoch_seconds =
        1'180'000'000;
    static constexpr std::uint64_t nanoseconds_per_second = 1'000'000'000;

    explicit VirtualClock(std::uint64_t initial_time = default_initial_time);

    [[nodiscard]] std::uint64_t now() const;
    [[nodiscard]] std::uint64_t wall_time() const;
    [[nodiscard]] std::uint64_t boot_time() const;
    void set_wall_time(std::uint64_t unix_time_nanoseconds);
    void synchronize_wall_time(std::uint64_t unix_time_nanoseconds);
    std::uint64_t tick(std::uint64_t increment);
    void advance_to(std::uint64_t deadline);
    void save(snapshot::Writer& out) const;
    void load(snapshot::Reader& in);

private:
    std::atomic_uint64_t now_;
    std::atomic_int64_t wall_time_offset_;
};

}
