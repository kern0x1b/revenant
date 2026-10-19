// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Adapt guest MBX connection calls and command-buffer access.

#pragma once

namespace shade {

class UserlandHleRegistry;

// Registers the MBXConnect control calls that LayerKit issues directly during
// startup. Rendering and surface transport stay in the MBX2D/CoreSurface HLEs;
// no PowerVR connection, command buffer, or register interface is exposed.
void register_mbx_connect_hle(UserlandHleRegistry& registry);

} // namespace shade
