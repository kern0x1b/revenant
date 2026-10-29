package("fast_float")
    set_homepage("https://github.com/fastfloat/fast_float")
    set_description("fast_float 8.0.0, the header-only number parser folly's conversions use, installed as the fast_float headers for armv7 iOS 6")
    set_license("MIT OR Apache-2.0 OR BSL-1.0")

    add_urls("https://github.com/fastfloat/fast_float.git")
    add_versions("8.0.0", "77cc847c842c49e7e3477c1e95da2b6540166d66")
    add_deps("cmake", "ninja", {kind = "binary"})
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = "2", readonly = true})

    on_load("iphoneos", function (package)
        package:add("deps", "revenant@libcxx", {alias = "libcxx"})
    end)

    on_install("iphoneos", function (package)
        local cmake = import("@addon.revenant.apple.cmake", {anonymous = true})
        cmake.install(package, {"-DCMAKE_POLICY_VERSION_MINIMUM=3.5", "-DFASTFLOAT_TEST=OFF","-DFASTFLOAT_BENCHMARKS=OFF", "-DFASTFLOAT_INSTALL=ON", "-DFASTFLOAT_SANITIZE=OFF"},
                      {deps = {"libcxx"}, licenses = {"LICENSE-MIT", "LICENSE-APACHE", "LICENSE-BOOST"}, prune = {"lib/cmake", "lib/pkgconfig", "share"}})
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("include"), "fast_float", "fast_float.h")), "fast_float/fast_float.h is not installed")
        local probe = import("@addon.revenant.apple.probe", {anonymous = true})
        local ok, output = probe.check(package, {source = [[
#include <fast_float/fast_float.h>
#include <cstring>
int main() {
    const char *text = "2.25";
    double value = 0;
    auto result = fast_float::from_chars(text, text + std::strlen(text), value);
    return result.ec == std::errc() && value == 2.25 ? 0 : 1;
}
]], deps = {"libcxx"}, flags = {"-std=c++20"}, link = true})
        assert(ok, "fast_float does not compile and link against armv7 libc++: " .. output)
    end)
