package("fmt")
    set_homepage("https://fmt.dev")
    set_description("{fmt} 12.1.0, the formatting library React Native's folly and glog format with, as a static libfmt for armv7 iOS 6, with the format.cc and os.cc of the release")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/fmtlib/fmt.git")
    add_versions("12.1.0", "407c905e45ad75fc29bf0f9bb7c5c2fd3475976f")
    add_deps("cmake", "ninja", {kind = "binary"})
    add_links("fmt")
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = "2", readonly = true})

    on_load("iphoneos", function (package)
        package:add("deps", "revenant@libcxx", {alias = "libcxx"})
    end)

    on_install("iphoneos", function (package)
        local cmake = import("@addon.revenant.apple.cmake", {anonymous = true})
        cmake.install(package, {"-DCMAKE_POLICY_VERSION_MINIMUM=3.5", "-DFMT_TEST=OFF","-DFMT_DOC=OFF", "-DFMT_INSTALL=ON", "-DFMT_FUZZ=OFF", "-DFMT_CUDA_TEST=OFF"},
                      {deps = {"libcxx"}, licenses = "LICENSE", prune = {"lib/cmake", "lib/pkgconfig", "share"}})
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libfmt.a")), "libfmt.a is not installed")
        local probe = import("@addon.revenant.apple.probe", {anonymous = true})
        local ok, output = probe.check(package, {source = [[
#include <fmt/format.h>
#include <string>
int main(int argc, char **argv) {
    std::string text = fmt::format("{} {:.3f} {:>4}", argc, 2.5, "x");
    return text.size() == 14 ? 0 : 1;
}
]], deps = {"libcxx"}, flags = {"-std=c++20"}, link = true, ldflags = {"-lfmt"}})
        assert(ok, "fmt does not compile and link against armv7 libc++: " .. output)
        probe.require_architecture(path.join(package:installdir("lib"), "libfmt.a"), "armv7")
    end)
