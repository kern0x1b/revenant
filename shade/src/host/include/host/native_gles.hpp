// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Register and select the host accelerated GLES renderer.

#pragma once

namespace shade {

// Install native backend support before configuring or creating a renderer.
// Hardware and CPU devices use the same native renderer. A host built without
// Vulkan reports its missing dependency instead of changing renderers.
void register_native_gles_renderer();

} // namespace shade
