// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Host readiness for one probe pass: the host descriptors a pass asks about
// are polled together, so the pass makes one poll(2) call instead of one per
// descriptor.

#pragma once

#include <cstddef>
#include <cstdint>
#include <optional>
#include <unordered_map>
#include <vector>

#include <poll.h>

namespace emulator {

class HostReadinessProbe {
public:
    void request_readable(int descriptor);
    void request_writable(int descriptor);

    void run();

    [[nodiscard]] std::optional<bool> readable(int descriptor) const;
    [[nodiscard]] std::optional<bool> writable(int descriptor) const;

private:
    void request(int descriptor, std::int16_t events);
    [[nodiscard]] std::optional<bool> answer(int descriptor,
        std::int16_t events) const;

    std::vector<pollfd> requests_;
    std::unordered_map<std::uint64_t, std::size_t> slots_;
};

}
