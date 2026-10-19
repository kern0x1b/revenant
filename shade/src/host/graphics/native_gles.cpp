// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Register and select the host accelerated GLES renderer.

#include "host/native_gles.hpp"

#include "graphics/gles_renderer.hpp"

#if defined(SHADE_HAS_VULKAN)
#include "vulkan_gles_renderer.hpp"
#endif

namespace shade {

void register_native_gles_renderer()
{
#if defined(SHADE_HAS_VULKAN)
    configure_gles_accelerated_factory(create_vulkan_gles_renderer);
#else
    // Without Vulkan there is no accelerated factory: the software renderer
    // is then the one a boot gets. A factory that always fails would make
    // every software boot throw instead.
    configure_gles_accelerated_factory(nullptr);
#endif
}

} // namespace shade
