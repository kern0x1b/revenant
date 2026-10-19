// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Serialize and validate portable Dynarmic IR translation artifacts.

#pragma once

#include <cstddef>
#include <cstdint>
#include <span>

namespace shade {

[[nodiscard]] bool validate_dynarmic_ir(std::span<const std::byte> bytes);

}
