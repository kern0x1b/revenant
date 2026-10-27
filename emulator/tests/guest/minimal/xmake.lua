-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

if not is_plat("iphoneos") then
    return
end

target("emulator_minimal_guest")
    set_kind("binary")
    set_default(false)
    add_rules("@addon/revenant/apple-ios")
    add_files("minimal.c")
    add_cflags("-Os", "-ffreestanding", "-fno-builtin", "-fno-stack-protector", {force = true})
