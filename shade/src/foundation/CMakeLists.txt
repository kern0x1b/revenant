# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

add_library(shade_foundation_memory STATIC
    content_identity.cpp
    memory/file_page_cache.cpp
    memory/vm_map.cpp)
add_library(Shade::foundation_memory ALIAS shade_foundation_memory)
shade_configure_module(shade_foundation_memory)

add_library(shade_foundation_block_profile STATIC
    block_profile.cpp)
add_library(Shade::foundation_block_profile ALIAS shade_foundation_block_profile)
shade_configure_module(shade_foundation_block_profile)

add_library(shade_foundation STATIC
    address_space.cpp
    application_display.cpp
    arm_cpu_model.cpp
    arm_unpredictable_instruction.cpp
    cpu.cpp
    darwin_notify_state_hle.cpp
    device_model.cpp
    guest_image_table.cpp
    dynarmic_ir_artifact.cpp
    dyld_shared_cache.cpp
    executable_catalog.cpp
    firmware_prepare.cpp
    guest_execution_coordinator.cpp
    guest_cpu_topology.cpp
    guest_exclusive_address_resolver.cpp
    host_resource_controller.cpp
    host_memory.cpp
    host_file_watcher.cpp
    jit_artifact.cpp
    jit_artifact_diagnostics.cpp
    jit_code_cache_governor.cpp
    jit_execution_budget.cpp
    jit_translation_profile.cpp
    jit_work_policy.cpp
    jit_work_scheduler.cpp
    macho.cpp
    output.cpp
    performance.cpp
    process_loader.cpp
    rootfs_path_resolver.cpp
    scene_coordinator.cpp
    userland_hle.cpp
    virtual_clock.cpp)
add_library(Shade::foundation ALIAS shade_foundation)
shade_configure_module(shade_foundation)
target_compile_definitions(shade_foundation PRIVATE
    SHADE_DYNARMIC_BUILD_FINGERPRINT=${SHADE_DYNARMIC_BUILD_FINGERPRINT})
target_include_directories(shade_foundation SYSTEM PRIVATE
    "${SHADE_DYNARMIC_DIR}/externals/mcl/include"
    "${SHADE_DYNARMIC_DIR}/externals/fmt/include"
    "${SHADE_BOOST_DIR}")
target_link_libraries(shade_foundation PUBLIC
    dynarmic Threads::Threads Shade::xnu_adapter
    Shade::foundation_memory Shade::foundation_block_profile)
if(TARGET PkgConfig::PLIST)
    target_link_libraries(shade_foundation PRIVATE PkgConfig::PLIST)
    target_compile_definitions(shade_foundation PRIVATE
        SHADE_HAS_LIBPLIST=1)
endif()
