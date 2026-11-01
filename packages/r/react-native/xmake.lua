package("react-native")
    set_kind("library", {headeronly = true})
    set_homepage("https://reactnative.dev")
    set_description("React Native 0.86.3, its headers only, from the react-native npm tarball: React's Objective-C headers flattened under include/React as CocoaPods exposes them, the C++ tree of ReactCommon under include/ beside include/jsi, the layout the Fabric and native module sources of other packages include against")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    add_urls("https://registry.npmjs.org/react-native/-/react-native-$(version).tgz")
    add_versions("0.86.3", "04e0ef4284ef9e2fb94075b0f98c6371d12ea1b31c2e42540a900a1e86ea46f5")
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = "6", readonly = true})

    on_load("iphoneos", function (package)
        package:add("deps", "revenant@libcxx", {alias = "libcxx"})
    end)

    local FLAT_HEADERS = {"React/**.h", "Libraries/Image/*.h"}
    local SUBSPEC_HEADERS = {
        {path.join("ReactApple", "Libraries", "RCTFoundation", "RCTDeprecation", "Exported"), "RCTDeprecation"},
        {path.join("Libraries", "Required"), "RCTRequired"},
        {path.join("Libraries", "TypeSafety"), "RCTTypeSafety"},
        {path.join("Libraries", "FBLazyVector"), "FBLazyVector"},
    }

    on_install(function (package)
        local include = package:installdir("include")
        local flat = path.join(include, "React")
        os.mkdir(flat)
        for _, pattern in ipairs(FLAT_HEADERS) do
            for _, header in ipairs(os.files(pattern)) do
                local destination = path.join(flat, path.filename(header))
                assert(not os.isfile(destination), path.filename(header) .. " is in two folders of React")
                os.cp(header, destination)
            end
        end
        local common = path.absolute("ReactCommon")
        local mirror = path.join(include, "ReactCommon")
        for _, header in ipairs(os.files(path.join(common, "**.h"))) do
            local relative = path.relative(header, common)
            if not relative:startswith("yoga/") and not relative:startswith("jsi/") then
                local destination = path.join(include, relative)
                os.cp(header, destination)
                local inside = relative:match("^.*/ReactCommon/(.+)$")
                if inside and not relative:find("/platform/cxx/", 1, true) then
                    local link = path.join(mirror, inside)
                    assert(not os.isfile(link), inside .. " is in two folders of ReactCommon")
                    os.mkdir(path.directory(link))
                    os.ln(destination, link)
                end
            end
        end
        local jsi = path.join(common, "jsi")
        for _, header in ipairs(os.files(path.join(jsi, "**.h"))) do
            os.cp(header, path.join(include, path.relative(header, jsi)))
        end
        for _, subspec in ipairs(SUBSPEC_HEADERS) do
            local folder, name = subspec[1], subspec[2]
            os.mkdir(path.join(include, name))
            for _, header in ipairs(os.files(path.join(folder, "**.h"))) do
                local destination = path.join(include, name, path.filename(header))
                assert(not os.isfile(destination), path.filename(header) .. " is in two folders of " .. name)
                os.cp(header, destination)
            end
        end
        for _, platform in ipairs({"ios", "cxx"}) do
            for _, header in ipairs(os.files(path.join(include, "**.h"))) do
                local inside = header:match("/platform/" .. platform .. "/(.+)$")
                local destination = inside and path.join(include, inside)
                if destination and not os.isfile(destination) then
                    os.mkdir(path.directory(destination))
                    os.ln(header, destination)
                end
            end
        end
        os.cp("LICENSE", package:installdir("licenses") .. "/")
    end)

    on_test(function (package)
        for _, file in ipairs({"include/React/RCTLog.h", "include/React/RCTImageLoader.h", "include/React/RCTViewComponentView.h",
                               "include/jsi/jsi.h", "include/react/renderer/mapbuffer/MapBuffer.h", "include/ReactCommon/TurboModuleUtils.h",
                               "include/ReactCommon/RuntimeExecutor.h", "include/RCTDeprecation/RCTDeprecation.h", "include/RCTRequired/RCTRequired.h",
                               "include/React/renderer/components/view/platform/cxx/react/renderer/components/view/HostPlatformViewEventEmitter.h"}) do
            assert(os.isfile(path.join(package:installdir(), file)), file .. " is not installed")
        end
        assert(not os.isfile(path.join(package:installdir("include"), "yoga", "Yoga.h")), "yoga belongs to the yoga package")
        local probe = import("@addon.revenant.apple.probe", {anonymous = true})
        local ok, output = probe.check(package, {source = [[
#include <jsi/jsi.h>
int main(int argc, char **argv) {
    facebook::jsi::Value value(42);
    return value.isNumber() && argc > 0 ? 0 : 1;
}
]], deps = {"libcxx"}, flags = {"-std=c++20"}})
        assert(ok, "react-native headers do not compile against armv7 libc++: " .. output)
    end)
