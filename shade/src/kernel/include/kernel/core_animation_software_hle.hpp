// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Adapt guest CoreAnimation software drawing calls to emulator
// surfaces.

#pragma once

namespace shade {

class UserlandHleRegistry;
void register_core_animation_software_hle(UserlandHleRegistry& registry);

} // namespace shade
