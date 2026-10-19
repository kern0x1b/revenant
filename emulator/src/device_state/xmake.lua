-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

target("shade_device_state")
    set_kind("static")
    add_files("darwin_firmware_identity.cpp", "darwin_kernel_configuration.cpp", "darwin_kernel_identity.cpp",
              "graphics_services_capabilities.cpp", "launchd_job_catalog.cpp", "lockdown_state.cpp",
              "network_preferences.cpp")
    add_deps("shade_foundation", "shade_network", {public = true})
    add_packages("libplist")
    add_defines("SHADE_HAS_LIBPLIST=1")
