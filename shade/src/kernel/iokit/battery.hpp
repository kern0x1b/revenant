// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Declare virtual battery registry matching and property helpers.

#pragma once

#include <cstddef>
#include <cstdint>
#include <span>
#include <string_view>

namespace shade {

struct KernelSharedState;

namespace kernel_iokit::battery {

    inline constexpr std::string_view service_class { "IOPMPowerSource" };

    [[nodiscard]] bool matches_service(std::span<const std::byte> matching);

    // The caller holds KernelSharedState::mach_mutex.
    [[nodiscard]] std::uint32_t ensure_service_locked(KernelSharedState& state);

} // namespace kernel_iokit::battery
} // namespace shade
