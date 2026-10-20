-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

local headers = path.join(os.scriptdir(), "..", "..", "include")

target("emulator_app_control")
    set_kind("static")
    add_files("control/live_control.cpp")
    add_includedirs(headers, {public = true})
    add_deps("emulator_foundation", "emulator_debug", {public = true})

target("emulator_app_sdl")
    set_kind("static")
    add_files("sdl/sdl_display.cpp", "sdl/sdl_input.cpp", "sdl/sdl_audio_sink.cpp")
    add_includedirs(headers, {public = true})
    add_deps("emulator_graphics", "emulator_media", {public = true})
    if has_config("emulator_sdl") then
        add_packages("libsdl2")
        add_defines("REVENANT_EMULATOR_HAS_SDL2=1")
        if has_config("emulator_vulkan") then
            add_packages("vulkan-headers")
            add_defines("REVENANT_EMULATOR_HAS_VULKAN=1")
        end
    end

target("emulator")
    set_kind("binary")
    add_files("main.cpp", "desktop_host.cpp", "abi_command.cpp")
    add_includedirs(headers, {public = true})
    add_deps("emulator_host", "emulator_app_control", "emulator_app_sdl", "emulator_runtime")
    if has_config("emulator_vulkan") then
        add_packages("vulkan-loader", "swiftshader")
        on_config(function (target)
            local loader = target:pkg("vulkan-loader")
            if loader then
                target:add("rpathdirs", path.join(loader:installdir(), "lib"))
            end
        end)
        after_build(function (target)
            local driver = path.join(target:pkg("swiftshader"):installdir(), "lib", "libvk_swiftshader.dylib")
            os.cp(driver, path.join(target:targetdir(), path.filename(driver)), {copy_if_different = true})
        end)
    end
