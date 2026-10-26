-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

target("emulator_runtime")
    set_kind("static")
    add_files("boot_options.cpp", "emulator_session.cpp", "realtime_pacer.cpp", "resource_policy.cpp", "loop_carried_state.cpp", "session_snapshot.cpp",
              "session_state.cpp", "session_catalog.cpp", "session_diagnostics.cpp", "input/live_button_scheduler.cpp",
              "input/live_touch_scheduler.cpp")
    add_deps("emulator_foundation", "emulator_device_state", "emulator_graphics", "emulator_network", {public = true})
    add_deps("emulator_kernel", "emulator_debug", "emulator_crypto")

target("emulator_runtime_initial_process_failure_test")
    set_kind("binary")
    set_default(false)
    add_files("test/initial_process_failure_test.cpp")
    add_includedirs(".")
    add_tests("runtime.initial_process_failure")

target("emulator_runtime_loop_carried_state_test")
    set_kind("binary")
    set_default(false)
    add_files("test/loop_carried_state_test.cpp")
    add_deps("emulator_runtime")
    add_tests("runtime.loop_carried_state")

target("emulator_runtime_guest_timing_test")
    set_kind("binary")
    set_default(false)
    add_files("test/guest_timing_test.cpp")
    add_deps("emulator_runtime", "emulator_kernel")
    add_tests("runtime.guest_timing")

target("emulator_runtime_session_snapshot_test")
    set_kind("binary")
    set_default(false)
    add_files("test/session_snapshot_test.cpp")
    add_deps("emulator_runtime")
    add_tests("runtime.session_snapshot")

target("emulator_runtime_session_state_test")
    set_kind("binary")
    set_default(false)
    add_files("test/session_state_test.cpp")
    add_deps("emulator_runtime")
    add_tests("runtime.session_state")

target("emulator_runtime_bounded_slice_rule_test")
    set_kind("binary")
    set_default(false)
    add_files("test/bounded_slice_rule_test.cpp")
    add_deps("emulator_foundation")
    add_tests("runtime.bounded_slice_rule")
