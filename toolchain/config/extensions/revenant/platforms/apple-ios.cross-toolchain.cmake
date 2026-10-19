{generated}
set(CMAKE_SYSTEM_NAME {system})
set(CMAKE_SYSTEM_PROCESSOR {processor})

if (NOT CHARON_SDK OR NOT CHARON_DEPLOYMENT_TARGET OR NOT CHARON_ARCHITECTURE OR NOT CHARON_TRIPLE)
    message(FATAL_ERROR
        "CHARON_SDK, CHARON_DEPLOYMENT_TARGET, CHARON_ARCHITECTURE and CHARON_TRIPLE come from the profile Charon wrote. Reading them from the "
        "environment instead would leave them empty when ninja re-runs cmake by itself, and cmake would "
        "quietly fall back to the newest installed SDK")
endif ()
set(CHARON_SDK "${{CHARON_SDK}}" CACHE PATH "SDK this port is compiled against" FORCE)
set(CHARON_DEPLOYMENT_TARGET "${{CHARON_DEPLOYMENT_TARGET}}" CACHE STRING "Oldest release this runs on" FORCE)
set(CHARON_ARCHITECTURE "${{CHARON_ARCHITECTURE}}" CACHE STRING "Architecture as the Apple tools name it" FORCE)
set(CHARON_TRIPLE "${{CHARON_TRIPLE}}" CACHE STRING "Target the compiler is asked for" FORCE)
set(CMAKE_OSX_SYSROOT ${{CHARON_SDK}} CACHE PATH "SDK the compiler is pointed at" FORCE)
set(CHARON_PATH_MAPS "${{CHARON_PATH_MAPS}}" CACHE STRING "Machine folders compiled in under stable names" FORCE)
set(CHARON_FRAMEWORK_ROOT "${{CHARON_FRAMEWORK_ROOT}}" CACHE PATH "Frameworks where the target release keeps them" FORCE)
list(APPEND CMAKE_TRY_COMPILE_PLATFORM_VARIABLES CHARON_SDK CHARON_DEPLOYMENT_TARGET CHARON_ARCHITECTURE CHARON_TRIPLE CHARON_PATH_MAPS CHARON_FRAMEWORK_ROOT)
set(CMAKE_OSX_ARCHITECTURES ${{CHARON_ARCHITECTURE}})
set(CMAKE_OSX_DEPLOYMENT_TARGET ${{CHARON_DEPLOYMENT_TARGET}})

if (DEFINED ENV{{DEVELOPER_DIR}})
    set(DEVELOPER_ROOT $ENV{{DEVELOPER_DIR}})
else ()
    execute_process(COMMAND xcode-select -p
        OUTPUT_VARIABLE DEVELOPER_ROOT OUTPUT_STRIP_TRAILING_WHITESPACE)
endif ()
if (EXISTS ${{DEVELOPER_ROOT}}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang)
    set(TOOLCHAIN_BIN ${{DEVELOPER_ROOT}}/Toolchains/XcodeDefault.xctoolchain/usr/bin)
else ()
    set(TOOLCHAIN_BIN ${{DEVELOPER_ROOT}}/usr/bin)
endif ()
set(CMAKE_C_COMPILER ${{TOOLCHAIN_BIN}}/clang)
set(CMAKE_CXX_COMPILER ${{TOOLCHAIN_BIN}}/clang++)

set(CHARON_SYSROOT ${{CHARON_SDK}})
set(COMMON "-target ${{CHARON_TRIPLE}} -isysroot ${{CHARON_SYSROOT}}")
set(CMAKE_C_FLAGS_INIT "${{COMMON}}{defines} ${{CHARON_PATH_MAPS}}")
set(CMAKE_OBJC_FLAGS_INIT "${{COMMON}}{defines} ${{CHARON_PATH_MAPS}}")
set(CMAKE_CXX_FLAGS_INIT "${{COMMON}}{defines} ${{CHARON_PATH_MAPS}}")
set(CMAKE_OBJCXX_FLAGS_INIT "${{COMMON}}{defines} ${{CHARON_PATH_MAPS}}")
set(CMAKE_EXE_LINKER_FLAGS_INIT "${{COMMON}}")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "${{COMMON}}")

set(CMAKE_FIND_ROOT_PATH ${{CHARON_FRAMEWORK_ROOT}} ${{CHARON_SYSROOT}})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

if (EXISTS ${{DEVELOPER_ROOT}}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk)
    set(MIG_SYSROOT ${{DEVELOPER_ROOT}}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk)
else ()
    set(MIG_SYSROOT ${{DEVELOPER_ROOT}}/SDKs/MacOSX.sdk)
endif ()
