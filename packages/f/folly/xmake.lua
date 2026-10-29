package("folly")
    set_homepage("https://github.com/facebook/folly")
    set_description("folly 2024.11.18.00, the RCT-Folly subset React Native 0.86 builds (its Default and Fabric subspecs) with the flags it compiles them with, as a static libfolly for armv7 iOS 6 against revenant's libc++, its platform configuration measured against the iOS 6 SDK")
    set_license("Apache-2.0")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/facebook/folly.git")
    add_versions("2024.11.18.00", "0660ead5b610047a279cc291129e98e3f2a1fc37")
    add_cxxflags("-fno-aligned-allocation", {force = true})
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = "4", readonly = true})

    on_load("iphoneos", function (package)
        package:add("deps", "revenant@libcxx", {alias = "libcxx"})
        package:add("deps", "revenant@apple-compat", {alias = "apple-compat"})
        package:add("deps", "revenant@boost 1.84.0", {alias = "boost"})
        package:add("deps", "revenant@glog 0.3.5", {alias = "glog"})
        package:add("deps", "revenant@fmt 12.1.0", {alias = "fmt"})
        package:add("deps", "revenant@double-conversion 1.1.6", {alias = "double-conversion"})
        package:add("deps", "revenant@fast_float 8.0.0", {alias = "fast_float"})
    end)

    local DEFAULT_SOURCES = {
        "folly/String.cpp", "folly/Conv.cpp", "folly/Demangle.cpp", "folly/FileUtil.cpp", "folly/Format.cpp",
        "folly/lang/SafeAssert.cpp", "folly/lang/ToAscii.cpp", "folly/ScopeGuard.cpp", "folly/Unicode.cpp",
        "folly/json/dynamic.cpp", "folly/json/json.cpp", "folly/json/json_pointer.cpp",
        "folly/container/detail/F14Table.cpp", "folly/detail/FileUtilDetail.cpp",
        "folly/detail/SplitStringSimd.cpp", "folly/detail/StaticSingletonManager.cpp", "folly/detail/UniqueInstance.cpp",
        "folly/hash/SpookyHashV2.cpp", "folly/lang/CString.cpp", "folly/lang/Exception.cpp",
        "folly/memory/ReentrantAllocator.cpp", "folly/memory/detail/MallocImpl.cpp", "folly/memory/SanitizeLeak.cpp",
        "folly/net/NetOps.cpp", "folly/portability/SysUio.cpp", "folly/synchronization/SanitizeThread.cpp",
        "folly/system/AtFork.cpp", "folly/system/ThreadId.cpp"
    }

    local FABRIC_SOURCES = {
        "folly/SharedMutex.cpp", "folly/concurrency/CacheLocality.cpp", "folly/detail/Futex.cpp",
        "folly/synchronization/ParkingLot.cpp"
    }

    local HEADER_FOLDERS = {
        "folly/*.h", "folly/algorithm/simd/*.h", "folly/algorithm/simd/detail/*.h", "folly/chrono/*.h",
        "folly/container/*.h", "folly/container/detail/*.h", "folly/detail/*.h", "folly/functional/*.h",
        "folly/hash/*.h", "folly/json/*.h", "folly/lang/*.h", "folly/memory/*.h", "folly/memory/detail/*.h",
        "folly/net/*.h", "folly/net/detail/*.h", "folly/portability/*.h", "folly/system/*.h",
        "folly/concurrency/CacheLocality.h", "folly/synchronization/*.h", "folly/system/ThreadId.h"
    }

    local RN_COMPILE_FLAGS = {"-std=c++20", "-DFOLLY_MOBILE=1", "-DFOLLY_USE_LIBCPP=1", "-DFOLLY_CFG_NO_COROUTINES=1",
                              "-Wno-comma", "-Wno-shorten-64-to-32", "-Wno-documentation", "-fno-aligned-allocation"}

    local PROBE_FLAGS = {"-Werror=unguarded-availability-new"}

    local PROBES = {
        {macro = "FOLLY_HAVE_PTHREAD", link = true, source = [[
#include <pthread.h>
int main(int argc, char **argv) {
    (void)argv;
    return pthread_self() == nullptr && argc < 0 ? 1 : 0;
}
]]},
        {macro = "FOLLY_HAVE_PTHREAD_ATFORK", link = true, source = [[
#include <pthread.h>
int main(int argc, char **argv) {
    (void)argv;
    return pthread_atfork(nullptr, nullptr, nullptr) == 0 && argc < 0 ? 1 : 0;
}
]]},
        {macro = "FOLLY_HAVE_ACCEPT4", source = [[
#include <sys/socket.h>
int main(int argc, char **argv) {
    (void)argv;
    (void)&accept4;
    return argc < 0 ? 1 : 0;
}
]]},
        {macro = "FOLLY_HAVE_GETRANDOM", source = [[
#include <sys/random.h>
int main(int argc, char **argv) {
    (void)argv;
    (void)&getrandom;
    return argc < 0 ? 1 : 0;
}
]]},
        {macro = "FOLLY_HAVE_PREADV", source = [[
#include <sys/uio.h>
int main(int argc, char **argv) {
    (void)argv;
    (void)&preadv;
    return argc < 0 ? 1 : 0;
}
]]},
        {macro = "FOLLY_HAVE_PWRITEV", source = [[
#include <sys/uio.h>
int main(int argc, char **argv) {
    (void)argv;
    (void)&pwritev;
    return argc < 0 ? 1 : 0;
}
]]},
        {macro = "FOLLY_HAVE_CLOCK_GETTIME", shim = true, link = true, forbid = {"_clock_gettime"}, source = [[
#include <time.h>
int main(int argc, char **argv) {
    struct timespec now;
    return argc < 0 ? clock_gettime(CLOCK_MONOTONIC, &now) : 0;
}
]]},
        {macro = "FOLLY_HAVE_PIPE2", source = [[
#include <unistd.h>
int main(int argc, char **argv) {
    (void)argv;
    (void)&pipe2;
    return argc < 0 ? 1 : 0;
}
]]},
        {macro = "FOLLY_HAVE_MALLOC_USABLE_SIZE", source = [[
#include <stdlib.h>
int main(int argc, char **argv) {
    (void)argv;
    (void)&malloc_usable_size;
    return argc < 0 ? 1 : 0;
}
]]},
        {macro = "FOLLY_HAVE_SWAPCONTEXT", source = [[
#include <ucontext.h>
int main(int argc, char **argv) {
    (void)argv;
    (void)&swapcontext;
    return argc < 0 ? 1 : 0;
}
]]},
        {macro = "FOLLY_HAVE_WCHAR_SUPPORT", link = true, source = [[
#include <cwchar>
#include <cstdlib>
int main(int argc, char **argv) {
    (void)argv;
    return std::wcstol(L"01", nullptr, 10) == 1 && argc < 0 ? 1 : 0;
}
]]},
        {macro = "FOLLY_HAVE_INT128_T", source = [[
int main(int argc, char **argv) {
    (void)argv;
    __int128 value = argc;
    return value < 0 ? 1 : 0;
}
]]},
        {macro = "FOLLY_HAVE_VLA", source = [[
int main(int argc, char **argv) {
    (void)argv;
    unsigned size = argc;
    char data[size];
    return data[0] == data[0] ? 0 : 1;
}
]]},
        {macro = "FOLLY_HAVE_WEAK_SYMBOLS", link = true, source = [[
extern "C" int folly_example_undefined_weak_symbol() __attribute__((weak));
int main(int argc, char **argv) {
    (void)argv;
    auto f = folly_example_undefined_weak_symbol;
    return f ? f() : argc - argc;
}
]]}
    }

    local function measure(package, probe, shim_flags)
        local found = {}
        for _, item in ipairs(PROBES) do
            local flags = table.join(PROBE_FLAGS, item.shim and shim_flags or {})
            local ok, output = probe.check(package, {source = item.source, deps = item.shim and {"libcxx", "apple-compat"} or {"libcxx"},
                                                     flags = flags, link = item.link or false, forbid = item.forbid})
            if ok then
                table.insert(found, item.macro)
            end
            print("folly probe %s: %s", item.macro, ok and "yes" or "no")
        end
        return found
    end

    on_install("iphoneos", function (package)
        local probe = import("@addon.revenant.apple.probe", {anonymous = true})
        local compat = import("@addon.revenant.apple.compat", {anonymous = true})
        local sources = import("@addon.revenant.apple.sources", {anonymous = true})
        local shim_flags = compat.force_includes(package:dep("apple-compat"), {"clock_gettime"})
        local measured = measure(package, probe, shim_flags)
        local config = {"#pragma once", "", "#define FOLLY_MOBILE 1", "#define FOLLY_USE_LIBCPP 1",
                        "#define FOLLY_CFG_NO_COROUTINES 1", "#define FOLLY_DEMANGLE_MAX_SYMBOL_SIZE 1024"}
        for _, macro in ipairs(measured) do
            table.insert(config, "#define " .. macro .. " 1")
        end
        io.writefile(path.join("folly", "folly-config.h"), table.concat(config, "\n") .. "\n")
        os.mkdir(package:installdir("lib"))
        sources.static(package, {
            files = table.join(DEFAULT_SOURCES, FABRIC_SOURCES),
            includedirs = {"."},
            flags = shim_flags,
            cxxflags = RN_COMPILE_FLAGS,
            deps = {"libcxx", "apple-compat", "boost", "glog", "fmt", "double-conversion", "fast_float"},
            headers = table.join(HEADER_FOLDERS, {"folly/folly-config.h"}),
            licenses = {"LICENSE"},
            name = "folly"
        })
    end)

    on_test(function (package)
        for _, file in ipairs({"lib/libfolly.a", "include/folly/Conv.h", "include/folly/folly-config.h", "include/folly/json/dynamic.h"}) do
            assert(os.isfile(path.join(package:installdir(), file)), file .. " is not installed")
        end
        local probe = import("@addon.revenant.apple.probe", {anonymous = true})
        local ok, output = probe.check(package, {source = [[
#include <folly/Conv.h>
#include <folly/Format.h>
#include <folly/json/dynamic.h>
#include <folly/json/json.h>
#include <string>
int main(int argc, char **argv) {
    (void)argv;
    std::string text = folly::to<std::string>(argc + 41);
    std::string formatted = folly::sformat("{}-{}", 1, 2);
    folly::dynamic value = folly::parseJson("{\"a\": 1}");
    return text == "42" && formatted == "1-2" && value["a"].asInt() == 1 ? 0 : 1;
}
]], deps = {"libcxx", "apple-compat", "boost", "glog", "fmt", "double-conversion", "fast_float"}, flags = RN_COMPILE_FLAGS,
            link = true, ldflags = {"-lfolly"}})
        assert(ok, "folly does not compile and link against armv7 libc++: " .. output)
        probe.require_architecture(path.join(package:installdir("lib"), "libfolly.a"), "armv7")
    end)
