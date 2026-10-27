-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

target("emulator_media")
    set_kind("static")
    add_files("audio.cpp", "pcm_sample_format.cpp", "audio_toolbox_hle.cpp", "celestial_volume_protocol.cpp",
              "core_audio_hle.cpp", "core_audio_native_io.cpp", "core_media_hle.cpp", "jpeg_encoder.cpp",
              "media_library_service.cpp")
    add_deps("emulator_foundation", {public = true})
    add_packages("libjpeg-turbo", "libplist")
    add_defines("REVENANT_EMULATOR_HAS_LIBPLIST=1")

target("emulator_media_core_audio_snapshot_test")
    set_kind("binary")
    set_default(false)
    add_files("test/core_audio_hle_snapshot_test.cpp")
    add_deps("emulator_media")
    add_tests("media.core_audio_snapshot")
