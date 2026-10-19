# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# Build a real ARMv6/iPhoneOS executable that is loaded by the extracted dyld
# and calls the firmware libSystem resolver APIs. Modern ld64.lld no longer
# supports ARM32, so this optional target uses the cctools-port linker produced
# by tools/bootstrap_armv6_ld.sh (or a caller-supplied compatible ld64).
set(SHADE_ROOTFS "${SHADE_WORKSPACE_DIR}/build/rootfs" CACHE PATH
    "Extracted iPhoneOS root filesystem used by guest integration probes")
set(SHADE_ARMV6_LD
    "${SHADE_WORKSPACE_DIR}/build/toolchain/bin/arm-apple-darwin9-ld"
    CACHE FILEPATH "cctools ld64 with ARMv6 output support")
find_program(SHADE_GUEST_CLANG NAMES clang)
set(SHADE_GUEST_DNS_PROBE
    "${PROJECT_BINARY_DIR}/guest/dns_async_probe")
if(SHADE_GUEST_CLANG AND EXISTS "${SHADE_ARMV6_LD}" AND
   EXISTS "${SHADE_ROOTFS}/usr/lib/libSystem.B.dylib")
    add_custom_command(
        OUTPUT "${SHADE_GUEST_DNS_PROBE}"
        COMMAND "${CMAKE_COMMAND}" -E make_directory
                "${PROJECT_BINARY_DIR}/guest"
        COMMAND "${SHADE_GUEST_CLANG}"
                -target armv6-apple-ios1.0 -march=armv6 -marm -Oz
                -ffreestanding -fno-stack-protector -fno-builtin
                -c "${CMAKE_CURRENT_SOURCE_DIR}/dns_async_probe.c"
                -o "${PROJECT_BINARY_DIR}/guest/dns_async_probe.o"
        COMMAND "${SHADE_GUEST_CLANG}"
                -target armv6-apple-ios1.0 -march=armv6 -marm -Oz
                -ffreestanding -fno-stack-protector -fno-builtin
                -c "${CMAKE_CURRENT_SOURCE_DIR}/system_configuration_probe.c"
                -o "${PROJECT_BINARY_DIR}/guest/system_configuration_probe.o"
        COMMAND "${SHADE_GUEST_CLANG}"
                -target armv6-apple-ios1.0 -march=armv6 -marm -Oz
                -ffreestanding -fno-stack-protector -fno-builtin
                -c "${CMAKE_CURRENT_SOURCE_DIR}/runtime_initializers.c"
                -o "${PROJECT_BINARY_DIR}/guest/runtime_initializers.o"
        COMMAND "${SHADE_GUEST_CLANG}"
                -target armv6-apple-ios1.0 -march=armv6 -marm
                -c "${CMAKE_CURRENT_SOURCE_DIR}/armv6_crt.S"
                -o "${PROJECT_BINARY_DIR}/guest/armv6_crt.o"
        COMMAND "${SHADE_ARMV6_LD}"
                -arch armv6 -execute -e _start
                -syslibroot "${SHADE_ROOTFS}"
                -iphoneos_version_min 1.0 -no_pie -segalign 0x1000
                -bind_at_load -no_uuid -no_function_starts
                -no_data_in_code_info -no_encryption
                -o "${SHADE_GUEST_DNS_PROBE}"
                "${PROJECT_BINARY_DIR}/guest/armv6_crt.o"
                "${PROJECT_BINARY_DIR}/guest/dns_async_probe.o"
                "${PROJECT_BINARY_DIR}/guest/system_configuration_probe.o"
                "${PROJECT_BINARY_DIR}/guest/runtime_initializers.o"
                "${SHADE_ROOTFS}/System/Library/Frameworks/SystemConfiguration.framework/SystemConfiguration"
                "${SHADE_ROOTFS}/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation"
                "${SHADE_ROOTFS}/usr/lib/libSystem.B.dylib"
        DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/armv6_crt.S"
                "${CMAKE_CURRENT_SOURCE_DIR}/dns_async_probe.c"
                "${CMAKE_CURRENT_SOURCE_DIR}/system_configuration_probe.c"
                "${CMAKE_CURRENT_SOURCE_DIR}/system_configuration_probe.h"
                "${CMAKE_CURRENT_SOURCE_DIR}/runtime_initializers.c"
                "${CMAKE_CURRENT_SOURCE_DIR}/runtime_initializers.h"
                "${SHADE_ROOTFS}/System/Library/Frameworks/SystemConfiguration.framework/SystemConfiguration"
                "${SHADE_ROOTFS}/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation"
                "${SHADE_ROOTFS}/usr/lib/libSystem.B.dylib"
        VERBATIM
        COMMENT "Building ARMv6 firmware DNS/SystemConfiguration callback probe"
    )
    add_custom_target(shade_guest_dns_probe ALL
        DEPENDS "${SHADE_GUEST_DNS_PROBE}")
    add_custom_target(shade_install_guest_dns_probe
        COMMAND "${CMAKE_COMMAND}" -E make_directory
                "${SHADE_ROOTFS}/usr/libexec"
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different
                "${SHADE_GUEST_DNS_PROBE}"
                "${SHADE_ROOTFS}/usr/libexec/shade-dns-probe"
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different
                "${CMAKE_CURRENT_SOURCE_DIR}/com.shade.dns-probe.plist"
                "${SHADE_ROOTFS}/System/Library/LaunchDaemons/com.shade.dns-probe.plist"
        DEPENDS shade_guest_dns_probe
                "${CMAKE_CURRENT_SOURCE_DIR}/com.shade.dns-probe.plist"
        COMMENT "Installing opt-in DNS/Libinfo probe into the extracted rootfs"
        VERBATIM)
else()
    message(STATUS
        "ARMv6 guest DNS probe disabled: clang, cctools ld64, or firmware "
        "libSystem is unavailable")
endif()
