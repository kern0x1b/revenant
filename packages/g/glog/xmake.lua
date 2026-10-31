package("glog")
    set_homepage("https://github.com/google/glog")
    set_description("glog 0.3.5, the logging library React Native's folly writes its diagnostics with, as a static libglog for armv7 iOS 6, its configuration probed against the iOS 6 SDK and built without gflags, as React Native builds it")
    set_license("BSD-3-Clause")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/google/glog.git")
    add_versions("0.3.5", "a6a166db069520dbbd653c97c2e5b12e08a8bb26")
    add_deps("cmake", "ninja", {kind = "binary"})
    add_links("glog")
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = "2", readonly = true})

    on_load("iphoneos", function (package)
        package:add("deps", "revenant@libcxx", {alias = "libcxx"})
    end)

    on_install("iphoneos", function (package)
        local cmake = import("@addon.revenant.apple.cmake", {anonymous = true})
        cmake.install(package, {"-DCMAKE_POLICY_VERSION_MINIMUM=3.5", "-DWITH_GFLAGS=OFF","-DWITH_THREADS=ON", "-DBUILD_TESTING=OFF"},
                      {deps = {"libcxx"}, licenses = "COPYING", prune = {"lib/cmake", "lib/pkgconfig", "share"}})
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libglog.a")), "libglog.a is not installed")
        assert(os.isfile(path.join(package:installdir("include"), "glog", "logging.h")), "glog/logging.h is not installed")
        local probe = import("@addon.revenant.apple.probe", {anonymous = true})
        local ok, output = probe.check(package, {source = [[
#include <glog/logging.h>
int main(int argc, char **argv) {
    google::InitGoogleLogging(argv[0]);
    LOG(INFO) << "glog on armv7 " << argc;
    CHECK_EQ(argc, argc);
    return 0;
}
]], deps = {"libcxx"}, flags = {"-std=c++20"}, link = true, ldflags = {"-lglog"}})
        assert(ok, "glog does not compile and link against armv7 libc++: " .. output)
        probe.require_architecture(path.join(package:installdir("lib"), "libglog.a"), "armv7")
    end)
