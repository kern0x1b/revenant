// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
#pragma once

#include "foundation/virtual_clock.hpp"
#include <cstdint>
#include <optional>

namespace shade {

// A knote's timer uses the guest clock. Expirations accumulate lazily, so a
// disabled or unobserved queue needs no host callback or polling thread.
class KeventTimer {
public:
    static std::optional<KeventTimer> create(std::int64_t data,
        std::uint32_t flags, const VirtualClock& clock, bool one_shot);
    [[nodiscard]] std::optional<std::uint64_t> deadline() const;
    [[nodiscard]] std::int64_t expirations(std::uint64_t now) const;
    void consume(std::uint64_t now);

private:
    std::optional<std::uint64_t> deadline_;
    std::uint64_t interval_ { };
};

} // namespace shade
