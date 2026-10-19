-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

target("shade_runtime")
    set_kind("static")
    add_files("boot_options.cpp", "emulator_session.cpp", "realtime_pacer.cpp", "resource_policy.cpp",
              "session_catalog.cpp", "session_diagnostics.cpp", "input/live_button_scheduler.cpp",
              "input/live_touch_scheduler.cpp")
    add_deps("shade_foundation", "shade_device_state", "shade_graphics", "shade_network", {public = true})
    add_deps("shade_kernel", "shade_debug", "shade_crypto")

target("shade_runtime_initial_process_failure_test")
    set_kind("binary")
    set_default(false)
    add_files("test/initial_process_failure_test.cpp")
    add_includedirs(".")
    add_tests("runtime.initial_process_failure")

target("shade_runtime_bounded_slice_rule_test")
    set_kind("binary")
    set_default(false)
    add_files("test/bounded_slice_rule_test.cpp")
    add_deps("shade_foundation")
    add_tests("runtime.bounded_slice_rule")
