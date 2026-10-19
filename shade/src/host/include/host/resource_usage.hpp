// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Sample host process CPU, memory and storage resource usage.

#pragma once

#include "foundation/host_memory.hpp"

namespace shade {

[[nodiscard]] HostMemorySnapshot host_memory_snapshot();
[[nodiscard]] HostMemoryBudgetSnapshot host_memory_budget_snapshot();

} // namespace shade
