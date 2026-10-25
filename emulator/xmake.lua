-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

option("emulator_vulkan")
    set_default(true)
    set_showmenu(true)
    set_description("Build the Vulkan GLES renderer (needs the Vulkan loader and glslc)")
option_end()

option("emulator_sdl")
    set_default(false)
    set_showmenu(true)
    set_description("Build the SDL2 window backend, for watching a guest on the desktop")
option_end()

option("emulator_ffmpeg")
    set_default(false)
    set_showmenu(true)
    set_description("Build the FFmpeg audio decoder, for a guest that plays compressed audio")
option_end()

option("emulator_lto")
    set_default(true)
    set_showmenu(true)
    set_description("Optimize across translation units in release builds")
option_end()

option("emulator_dynarmic_test_emit_failure")
    set_default(false)
    set_showmenu(true)
    set_description("Compile Dynarmic's portable-emit fault injection, for tests")
option_end()

includes("tests/guest/dns-probe")

if get_config("component") ~= "" or is_plat("iphoneos") then
    return
end

local host = {plat = "macosx", arch = "arm64"}
add_requires("revenant@dynarmic 6.7.0", table.join(host, {alias = "dynarmic",
             configs = {test_emit_failure = has_config("emulator_dynarmic_test_emit_failure")}}))
add_requires("revenant@boost 1.81.0", table.join(host, {alias = "boost"}))
add_requires("revenant@openssl 4.0.2", {alias = "openssl"})
add_requires("revenant@libplist 2.7.0", {alias = "libplist"})
add_requires("libpng", "libjpeg-turbo", table.join(host, {system = false}))
if has_config("emulator_vulkan") then
    add_requires("vulkan-headers 1.4.335+0", "vulkan-loader 1.4.335+0", table.join(host, {system = false}))
    add_requires("vulkan-memory-allocator v3.4.0", table.join(host, {system = false}))
    add_requireconfs("vulkan-memory-allocator.vulkan-headers", {version = "1.4.335+0", override = true, system = false})
    add_requires("glslang 1.4.335+0", table.join(host, {system = false, configs = {default_resource_limits = true, hlsl = false}}))
    add_requires("revenant@swiftshader", {alias = "swiftshader"})
end
if has_config("emulator_sdl") then
    add_requires("libsdl2", table.join(host, {system = false}))
end
if has_config("emulator_ffmpeg") then
    add_requires("ffmpeg", table.join(host, {system = false}))
end

rule("emulator.module")
    on_load(function (target)
        target:set("languages", "c++20")
        target:add("cxflags", "-Wall", "-Wextra", "-Wpedantic", "-Wconversion", "-Wshadow")
        local include = path.join(target:scriptdir(), "include")
        if os.isdir(include) then
            target:add("includedirs", include, {public = true})
        end
        if has_config("emulator_lto") and is_mode("release") then
            target:set("policy", "build.optimization.lto", true)
        end
    end)
rule_end()

rule("emulator.glsl")
    set_extensions(".vert", ".frag")
    on_load(function (target)
        target:add("includedirs", path.join(target:autogendir(), "shaders"))
    end)
    before_build(function (target)
        local compiler = target:dep("emulator_glsl_to_spirv"):targetfile()
        local outdir = path.join(target:autogendir(), "shaders")
        os.mkdir(outdir)
        for _, sourcefile in ipairs(target:sourcefiles()) do
            local extension = path.extension(sourcefile)
            local output = path.join(outdir, path.filename(sourcefile) .. ".inc")
            if (extension == ".vert" or extension == ".frag") and
                (not os.isfile(output) or os.mtime(output) < os.mtime(sourcefile) or os.mtime(output) < os.mtime(compiler)) then
                cprint("${color.build.object}compiling.glsl %s", sourcefile)
                os.vrunv(compiler, {path.extension(sourcefile):sub(2), sourcefile, output})
            end
        end
    end)
    on_buildcmd_file(function () end)
rule_end()

set_plat("macosx")
set_arch("arm64")
add_rules("emulator.module")

includes("src/mach", "src/foundation", "src/device_state", "src/filesystem", "src/network", "src/storage",
         "src/telephony", "src/media", "src/bluetooth", "src/crypto", "src/graphics", "src/kernel", "src/debug",
         "src/host", "src/runtime", "src/app", "src/glsl")

target("emulator_block_profile_test")
    set_kind("binary")
    set_default(false)
    add_files("tests/unit/block_profile_test.cpp")
    add_deps("emulator_foundation_block_profile")
    add_tests("block_profile")

target("emulator_machine_image_region_test")
    set_kind("binary")
    set_default(false)
    add_files("tests/unit/machine_image_region_test.cpp")
    add_deps("emulator_foundation")
    add_tests("machine_image_region")

target("emulator_load_average_test")
    set_kind("binary")
    set_default(false)
    add_files("tests/unit/load_average_test.cpp")
    add_deps("emulator_foundation_block_profile")
    add_tests("load_average")

target("emulator_ifmibdata_test")
    set_kind("binary")
    set_default(false)
    add_files("tests/unit/ifmibdata_test.cpp")
    add_deps("emulator_network")
    add_tests("ifmibdata")

target("emulator_interface_counters_test")
    set_kind("binary")
    set_default(false)
    add_files("tests/unit/interface_counters_test.cpp")
    add_deps("emulator_network")
    add_tests("interface_counters")

target("emulator_darwin_notify_post_test")
    set_kind("binary")
    set_default(false)
    add_files("tests/unit/darwin_notify_post_test.cpp")
    add_deps("emulator_foundation")
    add_tests("darwin_notify_post")

target("emulator_materialized_page_counts_test")
    set_kind("binary")
    set_default(false)
    add_files("tests/unit/materialized_page_counts_test.cpp")
    add_deps("emulator_foundation")
    add_tests("materialized_page_counts")

target("emulator_fault_dump_test")
    set_kind("binary")
    set_default(false)
    add_files("tests/unit/fault_dump_test.cpp")
    add_deps("emulator_foundation_fault_dump")
    add_tests("fault_dump")
