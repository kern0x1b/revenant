# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

add_library(shade_runtime STATIC
    boot_options.cpp
    emulator_session.cpp
    realtime_pacer.cpp
    resource_policy.cpp
    session_catalog.cpp
    session_diagnostics.cpp
    input/live_button_scheduler.cpp
    input/live_touch_scheduler.cpp)
add_library(Shade::runtime ALIAS shade_runtime)
shade_configure_module(shade_runtime)
target_link_libraries(shade_runtime
    PUBLIC Shade::foundation Shade::device_state Shade::graphics Shade::network
    PRIVATE Shade::kernel Shade::debug Shade::crypto)

if(BUILD_TESTING)
    add_executable(shade_runtime_initial_process_failure_test
        test/initial_process_failure_test.cpp)
    target_include_directories(shade_runtime_initial_process_failure_test
        PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
    add_test(NAME runtime.initial_process_failure
        COMMAND shade_runtime_initial_process_failure_test)

    add_executable(shade_runtime_bounded_slice_rule_test
        test/bounded_slice_rule_test.cpp)
    target_link_libraries(shade_runtime_bounded_slice_rule_test
        PRIVATE Shade::foundation)
    add_test(NAME runtime.bounded_slice_rule
        COMMAND shade_runtime_bounded_slice_rule_test)
endif()
