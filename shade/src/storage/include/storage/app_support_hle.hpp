// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Adapt legacy AppSupport database entry points while retaining
// firmware-owned behavior.

#pragma once

namespace shade {

class UserlandHleRegistry;

// Narrow compatibility boundary for legacy AppSupport database entry points.
void register_app_support_hle(UserlandHleRegistry& registry);

} // namespace shade
