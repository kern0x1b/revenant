# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

find_package(OpenSSL REQUIRED COMPONENTS Crypto)

add_library(shade_crypto STATIC
    core_crypto_hle.cpp
    prime_field_layout.cpp
    host/key_store.cpp
    host/big_number.cpp)
add_library(Shade::crypto ALIAS shade_crypto)
shade_configure_module(shade_crypto)
target_include_directories(shade_crypto PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(shade_crypto PUBLIC Shade::foundation
    PRIVATE OpenSSL::Crypto)
