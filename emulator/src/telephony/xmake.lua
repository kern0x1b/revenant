-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

target("emulator_telephony")
    set_kind("static")
    add_files("core_telephony_hle.cpp")
    add_deps("emulator_foundation", "emulator_network", {public = true})
