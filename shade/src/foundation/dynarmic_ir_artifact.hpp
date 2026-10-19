// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Declare internal Umbra IR artifact helpers shared by the
// serialization implementation.

#pragma once

#include <foundation/umbra_ir_artifact.hpp>

#include <optional>
#include <vector>

#include <umbra/ir/basic_block.h>

namespace shade {

[[nodiscard]] std::optional<std::vector<std::byte>> serialize_umbra_ir(
    const Umbra::IR::Block& block);

[[nodiscard]] std::optional<Umbra::IR::Block> deserialize_umbra_ir(
    std::span<const std::byte> bytes);

} // namespace shade
