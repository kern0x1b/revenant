// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Accelerate supported guest corecrypto big-integer operations with
// firmware fallback.

#pragma once

namespace shade {

class UserlandHleRegistry;

void register_core_crypto_hle(UserlandHleRegistry& registry);

} // namespace shade
