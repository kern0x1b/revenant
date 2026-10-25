-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

target("emulator_foundation_memory")
    set_kind("static")
    add_files("content_identity.cpp", "memory/file_page_cache.cpp", "memory/vm_map.cpp")

target("emulator_foundation_block_profile")
    set_kind("static")
    add_files("block_profile.cpp")

target("emulator_foundation_fault_dump")
    set_kind("static")
    add_files("fault_dump.cpp")

target("emulator_foundation")
    set_kind("static")
    add_files("address_space.cpp", "application_display.cpp", "arm_cpu_model.cpp",
              "arm_unpredictable_instruction.cpp", "cpu.cpp", "darwin_notify_state_hle.cpp", "device_model.cpp",
              "guest_image_table.cpp", "dynarmic_ir_artifact.cpp", "dyld_shared_cache.cpp",
              "executable_catalog.cpp", "firmware_prepare.cpp", "guest_execution_coordinator.cpp",
              "guest_cpu_topology.cpp", "guest_exclusive_address_resolver.cpp", "host_resource_controller.cpp",
              "host_memory.cpp", "host_file_watcher.cpp", "jit_artifact.cpp", "jit_artifact_diagnostics.cpp",
              "jit_code_cache_governor.cpp", "jit_execution_budget.cpp", "jit_translation_profile.cpp",
              "jit_work_policy.cpp", "jit_work_scheduler.cpp", "macho.cpp", "output.cpp", "performance.cpp",
              "process_loader.cpp", "rootfs_path_resolver.cpp", "scene_coordinator.cpp", "userland_hle.cpp",
              "virtual_clock.cpp")
    add_deps("emulator_xnu_adapter", "emulator_foundation_memory", "emulator_foundation_block_profile",
             "emulator_foundation_fault_dump", {public = true})
    add_packages("dynarmic", "boost", {public = true})
    add_packages("libplist")
    add_defines("REVENANT_EMULATOR_HAS_LIBPLIST=1")
    add_syslinks("pthread")

target("emulator_foundation_snapshot_io_test")
    set_kind("binary")
    set_default(false)
    add_files("test/snapshot_io_test.cpp")
    add_deps("emulator_foundation")
    add_tests("foundation.snapshot_io")

target("emulator_foundation_virtual_clock_snapshot_test")
    set_kind("binary")
    set_default(false)
    add_files("test/virtual_clock_snapshot_test.cpp")
    add_deps("emulator_foundation")
    add_tests("foundation.virtual_clock_snapshot")

target("emulator_foundation_cpu_thread_state_snapshot_test")
    set_kind("binary")
    set_default(false)
    add_files("test/cpu_thread_state_snapshot_test.cpp")
    add_deps("emulator_foundation")
    add_tests("foundation.cpu_thread_state_snapshot")

target("emulator_foundation_address_space_snapshot_test")
    set_kind("binary")
    set_default(false)
    add_files("test/address_space_snapshot_test.cpp")
    add_deps("emulator_foundation")
    add_tests("foundation.address_space_snapshot")

target("emulator_foundation_darwin_notify_snapshot_test")
    set_kind("binary")
    set_default(false)
    add_files("test/darwin_notify_state_snapshot_test.cpp")
    add_deps("emulator_foundation")
    add_tests("foundation.darwin_notify_snapshot")
