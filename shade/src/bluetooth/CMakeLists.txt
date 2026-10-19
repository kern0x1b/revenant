# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

add_library(shade_bluetooth STATIC
    bluetooth_manager_hle.cpp)
add_library(Shade::bluetooth ALIAS shade_bluetooth)
shade_configure_module(shade_bluetooth)
target_link_libraries(shade_bluetooth PUBLIC Shade::foundation)
