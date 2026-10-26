-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

target("emulator_graphics")
    set_kind("static")
    add_files("boot_logo.cpp", "display.cpp", "core_animation_remote_abi.cpp", "gles_renderer.cpp",
              "gles_primitive_assembler.cpp", "gles_resources.cpp", "gles_rasterizer.cpp",
              "gles_shaded_rasterizer.cpp", "glsl_es.cpp", "gles_math.cpp", "host_graphics.cpp",
              "frame_file_presenter.cpp", "fixed8_pixel_blender.cpp", "fixed_point_texture_sampler.cpp",
              "layerkit_compatibility.cpp", "local_scene_background.cpp", "opengles_guest_capabilities.cpp",
              "eagl_dispatch_profile.cpp", "gles_program_state.cpp", "presentation_tracker.cpp",
              "scanout_composition.cpp", "surface_store.cpp", "touch_replay.cpp")
    add_deps("emulator_foundation", {public = true})
    add_packages("libpng")
    on_config(function (target)
        local png = io.readfile(path.join(target:scriptdir(), "assets", "boot-placeholder.png"), {encoding = "binary"})
        local bytes = {}
        for i = 1, #png do
            bytes[i] = string.format("0x%02x,", png:byte(i))
        end
        local template = io.readfile(path.join(target:scriptdir(), "assets", "boot_placeholder.hpp.in"))
        local header = template:gsub("@BOOT_PLACEHOLDER_BYTES@", function () return table.concat(bytes) end)
        local output = path.join(target:autogendir(), "boot_placeholder.hpp")
        if not os.isfile(output) or io.readfile(output) ~= header then
            io.writefile(output, header)
        end
        target:add("includedirs", target:autogendir())
    end)

target("emulator_graphics_display_snapshot_test")
    set_kind("binary")
    set_default(false)
    add_files("test/display_snapshot_test.cpp")
    add_deps("emulator_graphics")
    add_tests("graphics.display_snapshot")

target("emulator_graphics_surface_store_snapshot_test")
    set_kind("binary")
    set_default(false)
    add_files("test/surface_store_snapshot_test.cpp")
    add_deps("emulator_graphics")
    add_tests("graphics.surface_store_snapshot")
