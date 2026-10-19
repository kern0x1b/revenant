# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

add_library(shade_host_audio STATIC
    audio/ffmpeg_audio_decoder.cpp)
add_library(Shade::host_audio ALIAS shade_host_audio)
shade_configure_module(shade_host_audio)
target_link_libraries(shade_host_audio PUBLIC Shade::media)
if(TARGET PkgConfig::FFMPEG)
    target_link_libraries(shade_host_audio PRIVATE PkgConfig::FFMPEG)
    target_compile_definitions(shade_host_audio PRIVATE
        SHADE_HAS_FFMPEG=1)
endif()

add_library(shade_host_graphics STATIC
    graphics/native_gles.cpp)
add_library(Shade::host_graphics ALIAS shade_host_graphics)
shade_configure_module(shade_host_graphics)
target_link_libraries(shade_host_graphics PUBLIC Shade::graphics)
if(SHADE_ENABLE_VULKAN AND Vulkan_FOUND AND Vulkan_GLSLC_EXECUTABLE)
    set(SHADE_VMA_DIR
        "${PROJECT_SOURCE_DIR}/external/vulkan-memory-allocator")
    if(NOT EXISTS "${SHADE_VMA_DIR}/include/vk_mem_alloc.h")
        message(FATAL_ERROR
            "Vulkan Memory Allocator was not found at ${SHADE_VMA_DIR}.")
    endif()
    set(SHADE_VULKAN_SHADER_DIR
        "${CMAKE_CURRENT_BINARY_DIR}/graphics/generated/vulkan")
    set(SHADE_VULKAN_VERTEX_SHADER
        "${SHADE_VULKAN_SHADER_DIR}/gles.vert.inc")
    set(SHADE_VULKAN_FRAGMENT_SHADER
        "${SHADE_VULKAN_SHADER_DIR}/gles.frag.inc")
    add_custom_command(
        OUTPUT
            "${SHADE_VULKAN_VERTEX_SHADER}"
            "${SHADE_VULKAN_FRAGMENT_SHADER}"
        COMMAND "${CMAKE_COMMAND}" -E make_directory
            "${SHADE_VULKAN_SHADER_DIR}"
        COMMAND "${Vulkan_GLSLC_EXECUTABLE}" -O -mfmt=c
            -fshader-stage=vert
            -o "${SHADE_VULKAN_VERTEX_SHADER}"
            "${CMAKE_CURRENT_SOURCE_DIR}/graphics/shaders/gles.vert"
        COMMAND "${Vulkan_GLSLC_EXECUTABLE}" -O -mfmt=c
            -fshader-stage=frag
            -o "${SHADE_VULKAN_FRAGMENT_SHADER}"
            "${CMAKE_CURRENT_SOURCE_DIR}/graphics/shaders/gles.frag"
        DEPENDS
            graphics/shaders/gles.vert
            graphics/shaders/gles.frag
        VERBATIM)
    add_custom_target(shade_vulkan_shaders DEPENDS
        "${SHADE_VULKAN_VERTEX_SHADER}"
        "${SHADE_VULKAN_FRAGMENT_SHADER}")
    target_sources(shade_host_graphics PRIVATE
        graphics/vulkan_gles_renderer.cpp
        graphics/vulkan_memory_allocator.cpp)
    add_dependencies(shade_host_graphics shade_vulkan_shaders)
    target_include_directories(shade_host_graphics PRIVATE
        "${SHADE_VULKAN_SHADER_DIR}")
    target_include_directories(shade_host_graphics SYSTEM PRIVATE
        "${SHADE_VMA_DIR}/include")
    target_link_libraries(shade_host_graphics PRIVATE Vulkan::Vulkan)
    target_compile_definitions(shade_host_graphics PRIVATE
        SHADE_HAS_VULKAN=1)
endif()

add_library(shade_host_system STATIC system/resource_usage.cpp)
add_library(Shade::host_system ALIAS shade_host_system)
shade_configure_module(shade_host_system)
target_link_libraries(shade_host_system PUBLIC Shade::foundation)

add_library(shade_host INTERFACE)
add_library(Shade::host ALIAS shade_host)
target_link_libraries(shade_host INTERFACE
    Shade::host_audio
    Shade::host_graphics
    Shade::host_system)
