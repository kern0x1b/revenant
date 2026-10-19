# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

cmake_minimum_required(VERSION 3.24)

project(Shade VERSION 0.1.0 LANGUAGES C CXX)

option(SHADE_ENABLE_IPO
    "Optimize across translation units in Release and RelWithDebInfo builds" ON)
if(SHADE_ENABLE_IPO)
    include(CheckIPOSupported)
    check_ipo_supported(RESULT SHADE_IPO_SUPPORTED
        OUTPUT SHADE_IPO_ERROR LANGUAGES C CXX)
    if(SHADE_IPO_SUPPORTED)
        # Startup spends much of its time in the JIT's small IR and emission
        # helpers. Let the compiler inline these across library boundaries.
        set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE ON)
        set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELWITHDEBINFO ON)
    else()
        message(STATUS "IPO unavailable; using standard optimization: ${SHADE_IPO_ERROR}")
    endif()
endif()

include(CTest)
find_package(Threads REQUIRED)
option(SHADE_ENABLE_SDL2 "Build the optional SDL2 display backend" ON)
option(SHADE_ENABLE_VULKAN
    "Build the optional Vulkan GLES renderer" ON)
if(SHADE_ENABLE_VULKAN)
    find_package(Vulkan QUIET)
endif()
option(SHADE_ENABLE_DYNARMIC_TEST_EMIT_FAILURE
    "Compile Dynarmic portable-emit fault injection for tests" OFF)
find_package(PkgConfig QUIET)
if(SHADE_ENABLE_SDL2 AND PkgConfig_FOUND)
    pkg_check_modules(SDL2 QUIET IMPORTED_TARGET sdl2)
endif()
if(PkgConfig_FOUND)
    pkg_check_modules(FFMPEG QUIET IMPORTED_TARGET
        libavformat libavcodec libavutil libswresample)
    pkg_check_modules(PLIST QUIET IMPORTED_TARGET libplist-2.0)
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# The source repository is usable on its own. A workspace checkout can pass
# these paths from its top-level CMake project without changing this entry
# point.
set(SHADE_WORKSPACE_DIR "${CMAKE_CURRENT_SOURCE_DIR}" CACHE PATH
    "Workspace containing optional tools, tests, docs, and firmware data")
set(SHADE_TESTS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/tests" CACHE PATH
    "Compatibility test source tree; may live in the surrounding workspace")

# Dynarmic and Boost are not kept in this tree: hades pins them in third_party/
# (the upstream commit or archive, and our patches), and third_party/fetch.lua
# prepares them under .deps/. Configure prepares them itself when they are not
# there yet, and they can be pointed elsewhere with the two cache paths.
get_filename_component(SHADE_HADES_DIR "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)
set(SHADE_DYNARMIC_DIR "${SHADE_HADES_DIR}/.deps/dynarmic" CACHE PATH
    "Path to Dynarmic at hades' pin, with its patches applied")
set(SHADE_BOOST_DIR "${SHADE_HADES_DIR}/.deps/boost" CACHE PATH
    "Path to the Boost release hades pins (its headers)")

foreach(shade_dep IN ITEMS dynarmic boost)
    string(TOUPPER "${shade_dep}" shade_dep_upper)
    if(NOT EXISTS "${SHADE_${shade_dep_upper}_DIR}" AND
       EXISTS "${SHADE_HADES_DIR}/third_party/${shade_dep}/UPSTREAM")
        execute_process(
            COMMAND xmake l "${SHADE_HADES_DIR}/third_party/fetch.lua" ${shade_dep}
                    "${SHADE_${shade_dep_upper}_DIR}"
            WORKING_DIRECTORY "${SHADE_HADES_DIR}"
            RESULT_VARIABLE shade_dep_result)
        if(NOT shade_dep_result EQUAL 0)
            message(FATAL_ERROR "preparing ${shade_dep} from third_party/${shade_dep} failed")
        endif()
    endif()
endforeach()

if(NOT EXISTS "${SHADE_DYNARMIC_DIR}/CMakeLists.txt")
    message(FATAL_ERROR
        "Dynarmic was not found at ${SHADE_DYNARMIC_DIR}. "
        "Run `xmake l third_party/fetch.lua dynarmic` in hades or set SHADE_DYNARMIC_DIR.")
endif()
if(NOT EXISTS "${SHADE_BOOST_DIR}/boost/version.hpp")
    message(FATAL_ERROR
        "Boost was not found at ${SHADE_BOOST_DIR}. "
        "Run `xmake l third_party/fetch.lua boost` in hades or set SHADE_BOOST_DIR.")
endif()

execute_process(
    COMMAND git rev-parse HEAD
    WORKING_DIRECTORY "${SHADE_DYNARMIC_DIR}"
    RESULT_VARIABLE SHADE_DYNARMIC_REVISION_RESULT
    OUTPUT_VARIABLE SHADE_DYNARMIC_CHECKED_OUT_REVISION
    ERROR_QUIET
    OUTPUT_STRIP_TRAILING_WHITESPACE)
if(SHADE_DYNARMIC_REVISION_RESULT EQUAL 0 AND
   NOT SHADE_DYNARMIC_CHECKED_OUT_REVISION STREQUAL "")
    set(SHADE_DYNARMIC_SELECTED_REVISION
        "${SHADE_DYNARMIC_CHECKED_OUT_REVISION}" CACHE INTERNAL
        "Dynarmic revision observed during configure" FORCE)
    message(STATUS
        "Using Dynarmic ${SHADE_DYNARMIC_CHECKED_OUT_REVISION}")
else()
    set(SHADE_DYNARMIC_SELECTED_REVISION "unknown" CACHE INTERNAL
        "Dynarmic revision observed during configure" FORCE)
endif()

# Force Dynarmic's FindBoost invocation to use the matching header-only tree.
set(Boost_NO_SYSTEM_PATHS ON CACHE BOOL "" FORCE)
set(BOOST_ROOT "${SHADE_BOOST_DIR}" CACHE PATH "" FORCE)
set(Boost_INCLUDE_DIR "${SHADE_BOOST_DIR}" CACHE PATH "" FORCE)
set(Boost_INCLUDE_DIRS "${SHADE_BOOST_DIR}" CACHE PATH "" FORCE)

set(DYNARMIC_FRONTENDS A32 CACHE STRING "" FORCE)
set(DYNARMIC_TESTS OFF CACHE BOOL "" FORCE)
set(DYNARMIC_ENABLE_TEST_EMIT_FAILURE
    "${SHADE_ENABLE_DYNARMIC_TEST_EMIT_FAILURE}" CACHE BOOL "" FORCE)
set(DYNARMIC_USE_BUNDLED_EXTERNALS ON CACHE BOOL "" FORCE)
set(DYNARMIC_USE_LLVM OFF CACHE BOOL "" FORCE)
set(DYNARMIC_WARNINGS_AS_ERRORS OFF CACHE BOOL "" FORCE)
set(DYNARMIC_USE_PRECOMPILED_HEADERS OFF CACHE BOOL "" FORCE)

# Public headers are kept with their owning module. The list is intentionally
# explicit so every target, including the out-of-tree workspace tests, sees
# the same <module>/<name>.hpp include spelling. A major module owns one
# include root; implementation subdirectories do not add public roots.
# Persistent portable-IR artifacts must not cross a different Dynarmic build.
# Include the actual revision and any deliberate local checkout changes in the
# artifact key so a custom development checkout cannot reuse stale artifacts.
set(SHADE_DYNARMIC_BUILD_FINGERPRINT 0x0ULL)
if(SHADE_DYNARMIC_REVISION_RESULT EQUAL 0 AND
   NOT SHADE_DYNARMIC_CHECKED_OUT_REVISION STREQUAL "")
    execute_process(
        COMMAND git diff --no-ext-diff --binary
        WORKING_DIRECTORY "${SHADE_DYNARMIC_DIR}"
        OUTPUT_VARIABLE SHADE_DYNARMIC_WORKTREE_DIFF
        ERROR_QUIET)
    string(SHA256 SHADE_DYNARMIC_BUILD_HASH
           "${SHADE_DYNARMIC_CHECKED_OUT_REVISION}\n${SHADE_DYNARMIC_WORKTREE_DIFF}")
    string(SUBSTRING "${SHADE_DYNARMIC_BUILD_HASH}" 0 16
           SHADE_DYNARMIC_BUILD_HASH_PREFIX)
    set(SHADE_DYNARMIC_BUILD_FINGERPRINT
        "0x${SHADE_DYNARMIC_BUILD_HASH_PREFIX}ULL")
endif()

add_subdirectory("${SHADE_DYNARMIC_DIR}" external/dynarmic EXCLUDE_FROM_ALL)

function(shade_configure_target target)
    target_compile_features(${target} PUBLIC cxx_std_20)
    target_compile_options(${target} PRIVATE
        $<$<CXX_COMPILER_ID:GNU,Clang>:-Wall;-Wextra;-Wpedantic;-Wconversion;-Wshadow>
    )
endfunction()

function(shade_configure_module target)
    file(RELATIVE_PATH _shade_module_path "${PROJECT_SOURCE_DIR}"
        "${CMAKE_CURRENT_SOURCE_DIR}")
    if(_shade_module_path MATCHES "^src/([^/]+)")
        set(_shade_module "${CMAKE_MATCH_1}")
        set(_shade_include_root
            "${PROJECT_SOURCE_DIR}/src/${_shade_module}/include")
    elseif(_shade_module_path MATCHES "^app($|/)")
        set(_shade_module app)
        set(_shade_include_root "${PROJECT_SOURCE_DIR}/app/include")
    else()
        message(FATAL_ERROR "No owning module for target ${target}")
    endif()
    target_include_directories(${target} PUBLIC
        "$<BUILD_INTERFACE:${_shade_include_root}>")
    # Kernel implementation subtargets share the kernel's declared header
    # contract, without linking back to the parent implementation library.
    if(_shade_module STREQUAL "kernel")
        target_link_libraries(${target} PUBLIC Shade::kernel_api)
    endif()
    shade_configure_target(${target})
endfunction()

add_subdirectory(src/mach)
add_subdirectory(src/foundation)

if(BUILD_TESTING)
    add_executable(shade_block_profile_test tests/unit/block_profile_test.cpp)
    target_link_libraries(shade_block_profile_test PRIVATE Shade::foundation_block_profile)
    add_test(NAME block_profile COMMAND shade_block_profile_test)
endif()
add_subdirectory(src/device_state)
add_subdirectory(src/filesystem)
add_subdirectory(src/network)
add_subdirectory(src/storage)
add_subdirectory(src/telephony)
add_subdirectory(src/media)
add_subdirectory(src/bluetooth)
add_subdirectory(src/crypto)
add_subdirectory(src/graphics)
add_subdirectory(src/kernel)
add_subdirectory(src/debug)
add_subdirectory(src/host)

add_library(shade_core INTERFACE)
add_library(Shade::core ALIAS shade_core)
target_link_libraries(shade_core INTERFACE
    Shade::kernel
    Shade::debug)

add_subdirectory(src/runtime)
add_subdirectory(app)
add_subdirectory(tools/guest)

if(BUILD_TESTING)
    if(EXISTS "${SHADE_TESTS_DIR}/CMakeLists.txt")
        add_subdirectory("${SHADE_TESTS_DIR}" tests)
    else()
        message(STATUS
            "Compatibility tests are not present at ${SHADE_TESTS_DIR}; "
            "set SHADE_TESTS_DIR to enable them.")
    endif()
endif()
