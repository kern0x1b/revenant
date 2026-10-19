# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

add_library(shade_media STATIC
    audio.cpp
    pcm_sample_format.cpp
    audio_toolbox_hle.cpp
    celestial_volume_protocol.cpp
    core_audio_hle.cpp
    core_audio_native_io.cpp
    core_media_hle.cpp
    jpeg_encoder.cpp
    media_library_service.cpp)
add_library(Shade::media ALIAS shade_media)
shade_configure_module(shade_media)
target_link_libraries(shade_media PUBLIC Shade::foundation)
find_package(JPEG REQUIRED)
target_link_libraries(shade_media PRIVATE JPEG::JPEG)
if(TARGET PkgConfig::PLIST)
    target_link_libraries(shade_media PRIVATE PkgConfig::PLIST)
    target_compile_definitions(shade_media PRIVATE
        SHADE_HAS_LIBPLIST=1)
endif()
