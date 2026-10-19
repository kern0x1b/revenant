# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

add_library(shade_xnu_adapter STATIC adapter/xnu_mig_adapter.cpp)
add_library(Shade::xnu_adapter ALIAS shade_xnu_adapter)
shade_configure_module(shade_xnu_adapter)

add_library(shade_mach STATIC
    guest_dispatch_policy.cpp
    guest_execution_policy.cpp
    guest_parallelism_policy.cpp
    mach_namespace.cpp
    xnu_scheduler.cpp)
add_library(Shade::mach ALIAS shade_mach)
shade_configure_module(shade_mach)
target_link_libraries(shade_mach PUBLIC
    Shade::foundation Shade::xnu_adapter)
