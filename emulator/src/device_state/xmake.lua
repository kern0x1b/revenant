-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

target("emulator_device_state")
    set_kind("static")
    add_files("darwin_firmware_identity.cpp", "darwin_kernel_configuration.cpp", "darwin_kernel_identity.cpp",
              "graphics_services_capabilities.cpp", "launchd_job_catalog.cpp", "lockdown_state.cpp",
              "network_preferences.cpp")
    add_deps("emulator_foundation", "emulator_network", {public = true})
    add_packages("libplist")
    add_defines("REVENANT_EMULATOR_HAS_LIBPLIST=1")
