-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

target("emulator_host_audio")
    set_kind("static")
    add_files("audio/ffmpeg_audio_decoder.cpp")
    add_deps("emulator_media", {public = true})
    if has_config("emulator_ffmpeg") then
        add_packages("ffmpeg")
        add_defines("REVENANT_EMULATOR_HAS_FFMPEG=1")
    end

target("emulator_host_graphics")
    set_kind("static")
    add_files("graphics/native_gles.cpp")
    add_deps("emulator_graphics", {public = true})
    if has_config("emulator_vulkan") then
        add_rules("emulator.glsl")
        add_deps("emulator_glsl_to_spirv")
        add_files("graphics/vulkan_gles_renderer.cpp", "graphics/vulkan_memory_allocator.cpp")
        add_files("graphics/shaders/gles.vert", "graphics/shaders/gles.frag")
        add_packages("vulkan-headers", "vulkan-loader", "vulkan-memory-allocator")
        add_defines("REVENANT_EMULATOR_HAS_VULKAN=1", 'REVENANT_EMULATOR_VULKAN_DRIVER_FILE="libvk_swiftshader.dylib"')
    end

target("emulator_host_system")
    set_kind("static")
    add_files("system/resource_usage.cpp")
    add_deps("emulator_foundation", {public = true})

target("emulator_host")
    set_kind("phony")
    add_deps("emulator_host_audio", "emulator_host_graphics", "emulator_host_system", {public = true})
