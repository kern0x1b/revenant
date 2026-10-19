# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

add_library(shade_graphics STATIC
    boot_logo.cpp
    display.cpp
    core_animation_remote_abi.cpp
    gles_renderer.cpp
    gles_primitive_assembler.cpp
    gles_resources.cpp
    gles_rasterizer.cpp
    gles_shaded_rasterizer.cpp
    glsl_es.cpp
    gles_math.cpp
    host_graphics.cpp
    frame_file_presenter.cpp
    fixed8_pixel_blender.cpp
    fixed_point_texture_sampler.cpp
    layerkit_compatibility.cpp
    local_scene_background.cpp
    opengles_guest_capabilities.cpp
    eagl_dispatch_profile.cpp
    gles_program_state.cpp
    presentation_tracker.cpp
    scanout_composition.cpp
    surface_store.cpp)
target_sources(shade_graphics PRIVATE touch_replay.cpp)
find_package(PNG REQUIRED)
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/assets/boot-placeholder.png")
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/assets/boot-placeholder.png"
    BOOT_PLACEHOLDER_BYTES HEX)
string(REGEX REPLACE "(..)" "0x\\1," BOOT_PLACEHOLDER_BYTES "${BOOT_PLACEHOLDER_BYTES}")
configure_file(assets/boot_placeholder.hpp.in boot_placeholder.hpp @ONLY)
target_include_directories(shade_graphics PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")
add_library(Shade::graphics ALIAS shade_graphics)
shade_configure_module(shade_graphics)
target_link_libraries(shade_graphics
    PUBLIC Shade::foundation
    PRIVATE PNG::PNG)
