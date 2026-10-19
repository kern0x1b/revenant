-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

target("emulator_crypto")
    set_kind("static")
    add_files("core_crypto_hle.cpp", "prime_field_layout.cpp", "host/key_store.cpp", "host/big_number.cpp")
    add_deps("emulator_foundation", {public = true})
    add_packages("openssl")
