# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

add_library(shade_telephony STATIC
    core_telephony_hle.cpp)
add_library(Shade::telephony ALIAS shade_telephony)
shade_configure_module(shade_telephony)
target_link_libraries(shade_telephony PUBLIC
    Shade::foundation
    Shade::network)
