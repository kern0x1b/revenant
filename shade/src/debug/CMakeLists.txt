# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

add_library(shade_debug STATIC gdb_rsp.cpp)
add_library(Shade::debug ALIAS shade_debug)
shade_configure_module(shade_debug)
target_link_libraries(shade_debug PUBLIC Shade::foundation)
