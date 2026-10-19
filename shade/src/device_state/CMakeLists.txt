# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

add_library(shade_device_state STATIC
    darwin_firmware_identity.cpp
    darwin_kernel_configuration.cpp
    darwin_kernel_identity.cpp
    graphics_services_capabilities.cpp
    launchd_job_catalog.cpp
    lockdown_state.cpp
    network_preferences.cpp)
add_library(Shade::device_state ALIAS shade_device_state)
shade_configure_module(shade_device_state)
target_link_libraries(shade_device_state PUBLIC
    Shade::foundation Shade::network)
if(TARGET PkgConfig::PLIST)
    target_link_libraries(shade_device_state PRIVATE PkgConfig::PLIST)
    target_compile_definitions(shade_device_state PRIVATE
        SHADE_HAS_LIBPLIST=1)
endif()
