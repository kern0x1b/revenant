-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

target("emulator_filesystem")
    set_kind("static")
    add_files("hfs_metadata.cpp", "hfs_volume_layout.cpp")
    add_deps("emulator_foundation", {public = true})

target("emulator_filesystem_guest_id_table_test")
    set_kind("binary")
    set_default(false)
    add_files("test/guest_id_table_test.cpp")
    add_deps("emulator_filesystem")
    add_tests("filesystem.guest_id_table")
