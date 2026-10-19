# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

add_library(shade_storage STATIC
    app_support_hle.cpp
    lockdown_hle.cpp)
add_library(Shade::storage ALIAS shade_storage)
shade_configure_module(shade_storage)
target_link_libraries(shade_storage PUBLIC
    Shade::foundation Shade::device_state)
