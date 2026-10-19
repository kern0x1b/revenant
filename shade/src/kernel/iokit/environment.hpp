// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Publish profile-driven environmental sensor registry services.

#pragma once

#include <cstddef>
#include <cstdint>
#include <span>

namespace shade {

struct KernelSharedState;

namespace kernel_iokit::environment {

    [[nodiscard]] bool matches_service(
        std::span<const std::byte> matching, const KernelSharedState& state);

    // The caller holds KernelSharedState::mach_mutex.
    [[nodiscard]] std::uint32_t ensure_service_locked(KernelSharedState& state);

} // namespace kernel_iokit::environment
} // namespace shade
