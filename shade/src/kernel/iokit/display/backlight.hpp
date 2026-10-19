// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#pragma once

#include "kernel/kernel_shared_state.hpp"

namespace shade::kernel_iokit {

// Registry contract for the built-in panel's integer brightness control.
// Native IOHIDDisplay owns brightness curves and session properties.
class BacklightControl {
public:
    [[nodiscard]] static bool matches(std::span<const std::byte> matching);
    static void publish(KernelSharedState::IOKitService& service);
    [[nodiscard]] static std::uint32_t set_properties(
        KernelSharedState::IOKitService& service,
        std::span<const std::byte> data);
};

} // namespace shade::kernel_iokit
