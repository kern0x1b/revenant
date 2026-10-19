// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#pragma once

#include <cstdint>
#include <string_view>

namespace shade {
struct KernelSharedState;

namespace kernel_iokit {

// Read-only manufacturing configuration for virtual hardware. Unprovisioned
// keys remain absent so firmware retains its normal missing-value behavior.
class DiagnosticDataService {
public:
    static constexpr std::string_view service_class {
        "AppleDiagnosticDataAccessReadOnly" };

    // The caller holds KernelSharedState::mach_mutex.
    [[nodiscard]] static std::uint32_t ensure_locked(KernelSharedState& state);
};

} // namespace kernel_iokit
} // namespace shade
