-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

target("emulator_debug")
    set_kind("static")
    add_files("gdb_rsp.cpp")
    add_deps("emulator_foundation", {public = true})
