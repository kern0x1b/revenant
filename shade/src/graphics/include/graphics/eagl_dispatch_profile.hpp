// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Recognize the ARM32 EAGL context and dispatch-table calling
// convention.

#pragma once

#include <cstddef>
#include <cstdint>
#include <optional>
#include <span>

namespace shade {

// The ARM32 GLI ABI keeps an opaque context followed by a function table.
// Resolve slots from the firmware's public wrappers instead of assuming that
// an entry has the same index across driver revisions.
class EaglContextFirstArm32Profile {
public:
    // The native GLI dispatch-size query selects the ABI, independently of
    // firmware release names and of the host renderer's capabilities.
    [[nodiscard]] static std::optional<EaglContextFirstArm32Profile>
        from_dispatch_bytes(std::uint32_t bytes);
    [[nodiscard]] std::uint32_t dispatch_bytes() const { return dispatch_bytes_; }
    [[nodiscard]] std::optional<std::uint32_t> client_api(std::uint32_t flags) const;
    static constexpr std::uint32_t context_offset = 0x10U;
    static constexpr std::uint32_t front_dispatch_offset = 0x14U;

    [[nodiscard]] std::optional<std::uint32_t> dispatch_slot(
        std::span<const std::byte> thumb_wrapper) const;

private:
    explicit EaglContextFirstArm32Profile(std::uint32_t bytes)
        : dispatch_bytes_ { bytes } { }
    std::uint32_t dispatch_bytes_;
};

} // namespace shade
