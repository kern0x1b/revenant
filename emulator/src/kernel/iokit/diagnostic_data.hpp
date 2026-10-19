// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#pragma once

#include <cstdint>
#include <string_view>

namespace shade {
struct KernelSharedState;

namespace kernel_iokit {

class DiagnosticDataService {
public:
    static constexpr std::string_view service_class {
        "AppleDiagnosticDataAccessReadOnly" };

    [[nodiscard]] static std::uint32_t ensure_locked(KernelSharedState& state);
};

}
}
