-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

target("shade_app_control")
    set_kind("static")
    add_files("control/live_control.cpp")
    add_deps("shade_foundation", "shade_debug", {public = true})

target("shade_app_sdl")
    set_kind("static")
    add_files("sdl/sdl_display.cpp", "sdl/sdl_input.cpp", "sdl/sdl_audio_sink.cpp")
    add_deps("shade_graphics", "shade_media", {public = true})
    if has_config("shade_sdl") then
        add_packages("libsdl2")
        add_defines("SHADE_HAS_SDL2=1")
        if has_config("shade_vulkan") then
            add_packages("vulkan-headers")
            add_defines("SHADE_HAS_VULKAN=1")
        end
    end

target("shade")
    set_kind("binary")
    add_files("main.cpp", "desktop_host.cpp", "abi_command.cpp")
    add_deps("shade_host", "shade_app_control", "shade_app_sdl", "shade_runtime")
    if has_config("shade_vulkan") then
        add_packages("vulkan-loader", "swiftshader")
        on_config(function (target)
            target:add("rpathdirs", path.join(target:pkg("vulkan-loader"):installdir(), "lib"))
        end)
        after_build(function (target)
            local driver = path.join(target:pkg("swiftshader"):installdir(), "lib", "libvk_swiftshader.dylib")
            os.cp(driver, path.join(target:targetdir(), path.filename(driver)), {copy_if_different = true})
        end)
    end
