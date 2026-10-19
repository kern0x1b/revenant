-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

target("shade_host_audio")
    set_kind("static")
    add_files("audio/ffmpeg_audio_decoder.cpp")
    add_deps("shade_media", {public = true})
    if has_config("shade_ffmpeg") then
        add_packages("ffmpeg")
        add_defines("SHADE_HAS_FFMPEG=1")
    end

target("shade_host_graphics")
    set_kind("static")
    add_files("graphics/native_gles.cpp")
    add_deps("shade_graphics", {public = true})
    if has_config("shade_vulkan") then
        add_rules("shade.glsl")
        add_deps("shade_glsl_to_spirv")
        add_files("graphics/vulkan_gles_renderer.cpp", "graphics/vulkan_memory_allocator.cpp")
        add_files("graphics/shaders/gles.vert", "graphics/shaders/gles.frag")
        add_packages("vulkan-headers", "vulkan-loader", "vulkan-memory-allocator")
        add_defines("SHADE_HAS_VULKAN=1", 'SHADE_VULKAN_DRIVER_FILE="libvk_swiftshader.dylib"')
    end

target("shade_host_system")
    set_kind("static")
    add_files("system/resource_usage.cpp")
    add_deps("shade_foundation", {public = true})

target("shade_host")
    set_kind("phony")
    add_deps("shade_host_audio", "shade_host_graphics", "shade_host_system", {public = true})
