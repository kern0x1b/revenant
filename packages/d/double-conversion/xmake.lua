package("double-conversion")
    set_homepage("https://github.com/google/double-conversion")
    set_description("double-conversion 1.1.6, the binary-decimal conversions React Native's folly parses and prints doubles with, as a static libdouble-conversion for armv7 iOS 6")
    set_license("BSD-3-Clause")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/google/double-conversion.git")
    add_versions("1.1.6", "361924fb61c043627d4179e941a102d543f6efa0")
    add_deps("cmake", "ninja", {kind = "binary"})
    add_links("double-conversion")
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = "2", readonly = true})

    on_load("iphoneos", function (package)
        package:add("deps", "revenant@libcxx", {alias = "libcxx"})
    end)

    on_install("iphoneos", function (package)
        local cmake = import("@addon.revenant.apple.cmake", {anonymous = true})
        cmake.install(package, {"-DCMAKE_POLICY_VERSION_MINIMUM=3.5", "-DBUILD_TESTING=OFF"}, {deps = {"libcxx"}, licenses = "LICENSE", prune = {"lib/cmake", "lib/pkgconfig", "share"}})
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libdouble-conversion.a")), "libdouble-conversion.a is not installed")
        assert(os.isfile(path.join(package:installdir("include"), "double-conversion", "double-conversion.h")), "double-conversion/double-conversion.h is not installed")
        local probe = import("@addon.revenant.apple.probe", {anonymous = true})
        local ok, output = probe.check(package, {source = [[
#include <double-conversion/double-conversion.h>
int main() {
    char buffer[64];
    double_conversion::StringBuilder builder(buffer, sizeof buffer);
    double_conversion::DoubleToStringConverter printer(0, "Infinity", "NaN", 'e', -6, 21, 6, 0);
    if (!printer.ToShortest(1.5, &builder)) return 1;
    double_conversion::StringToDoubleConverter parser(0, 0.0, 0.0, "Infinity", "NaN");
    int processed = 0;
    return parser.StringToDouble("2.25", 4, &processed) == 2.25 && processed == 4 ? 0 : 1;
}
]], deps = {"libcxx"}, flags = {"-std=c++20"}, link = true, ldflags = {"-ldouble-conversion"}})
        assert(ok, "double-conversion does not compile and link against armv7 libc++: " .. output)
        probe.require_architecture(path.join(package:installdir("lib"), "libdouble-conversion.a"), "armv7")
    end)
