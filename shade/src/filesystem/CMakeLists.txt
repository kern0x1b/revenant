# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

add_library(shade_filesystem STATIC hfs_metadata.cpp hfs_volume_layout.cpp)
add_library(Shade::filesystem ALIAS shade_filesystem)
shade_configure_module(shade_filesystem)
target_link_libraries(shade_filesystem PUBLIC Shade::foundation)

if(BUILD_TESTING)
    add_executable(shade_filesystem_guest_id_table_test
        test/guest_id_table_test.cpp)
    target_link_libraries(shade_filesystem_guest_id_table_test
        PRIVATE Shade::filesystem)
    add_test(NAME filesystem.guest_id_table
        COMMAND shade_filesystem_guest_id_table_test)
endif()
