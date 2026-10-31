package("yoga")
    set_homepage("https://yogalayout.dev")
    set_description("Yoga 0.86.3, the flexbox layout engine React Native 0.86 ships in ReactCommon/yoga, taken from the react-native 0.86.3 npm package (the same tree as its v0.86.3 tag), as a static libyoga for armv7 iOS 6, compiled as React Native's Release build compiles it")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    add_urls("https://registry.npmjs.org/react-native/-/react-native-$(version).tgz")
    add_versions("0.86.3", "04e0ef4284ef9e2fb94075b0f98c6371d12ea1b31c2e42540a900a1e86ea46f5")
    add_links("yoga")
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = "2", readonly = true})

    on_load("iphoneos", function (package)
        package:add("deps", "revenant@libcxx", {alias = "libcxx"})
    end)

    on_install("iphoneos", function (package)
        local sources = import("@addon.revenant.apple.sources", {anonymous = true})
        os.mkdir(package:installdir("lib"))
        sources.static(package, {
            sourcedir = "ReactCommon/yoga",
            files = {"yoga/**.cpp"},
            includedirs = {"."},
            cxxflags = {"-std=c++20", "-DNDEBUG", "-fexceptions", "-fno-omit-frame-pointer", "-Wall", "-Werror", "-Wno-incompatible-sysroot"},
            deps = {"libcxx"},
            headers = {"yoga/**.h"},
            licenses = {"../../LICENSE"},
            name = "yoga"
        })
    end)

    on_test(function (package)
        for _, file in ipairs({"lib/libyoga.a", "include/yoga/Yoga.h", "include/yoga/YGNodeLayout.h"}) do
            assert(os.isfile(path.join(package:installdir(), file)), file .. " is not installed")
        end
        local probe = import("@addon.revenant.apple.probe", {anonymous = true})
        local ok, output = probe.check(package, {source = [[
#include <yoga/Yoga.h>
int main(int argc, char **argv) {
    (void)argv;
    YGNodeRef root = YGNodeNew();
    YGNodeRef child = YGNodeNew();
    YGNodeStyleSetWidth(root, 320);
    YGNodeStyleSetHeight(root, 480);
    YGNodeStyleSetFlexGrow(child, 1);
    YGNodeInsertChild(root, child, 0);
    YGNodeCalculateLayout(root, YGUndefined, YGUndefined, YGDirectionLTR);
    float width = YGNodeLayoutGetWidth(child);
    YGNodeFree(root);
    return width == 320 && argc > 0 ? 0 : 1;
}
]], deps = {"libcxx"}, flags = {"-std=c++20"}, link = true, ldflags = {"-lyoga"}})
        assert(ok, "yoga does not compile and link against armv7 libc++: " .. output)
        probe.require_architecture(path.join(package:installdir("lib"), "libyoga.a"), "armv7")
    end)
