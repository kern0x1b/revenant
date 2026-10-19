# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

add_library(shade_app_control STATIC control/live_control.cpp)
add_library(Shade::app_control ALIAS shade_app_control)
shade_configure_module(shade_app_control)
target_link_libraries(shade_app_control PUBLIC
    Shade::foundation Shade::debug)

add_library(shade_app_sdl STATIC
    sdl/sdl_display.cpp
    sdl/sdl_input.cpp
    sdl/sdl_audio_sink.cpp)
add_library(Shade::app_sdl ALIAS shade_app_sdl)
shade_configure_module(shade_app_sdl)
target_link_libraries(shade_app_sdl PUBLIC
    Shade::graphics
    Shade::media)
if(TARGET PkgConfig::SDL2)
    target_link_libraries(shade_app_sdl PRIVATE PkgConfig::SDL2)
    target_compile_definitions(shade_app_sdl PRIVATE SHADE_HAS_SDL2=1)
    if(SHADE_ENABLE_VULKAN AND Vulkan_FOUND AND Vulkan_GLSLC_EXECUTABLE)
        target_link_libraries(shade_app_sdl PRIVATE Vulkan::Headers)
        target_compile_definitions(shade_app_sdl PRIVATE SHADE_HAS_VULKAN=1)
    endif()
endif()

add_executable(shade main.cpp desktop_host.cpp abi_command.cpp)
target_link_libraries(shade PRIVATE
    Shade::host
    Shade::app_control
    Shade::app_sdl
    Shade::runtime)
set_target_properties(shade PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}")
