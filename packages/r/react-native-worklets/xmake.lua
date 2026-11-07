package("react-native-worklets")
    set_kind("library", {headeronly = true})
    set_homepage("https://docs.swmansion.com/react-native-worklets")
    set_description("react-native-worklets 0.10.4 from its npm tarball: without RN_HERMES the native sources get the JavaScriptCore runtime patch, since Hermes is not available on iOS 6; with RN_HERMES they are the unpatched sources, whose runtime is Hermes")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    add_urls("https://registry.npmjs.org/react-native-worklets/-/react-native-worklets-$(version).tgz")
    add_versions("0.10.4", "73fb2142ccb8b9ee1485948123922f137ac02cdfa2c731216497c80eddda3b23")
    if not os.getenv("RN_HERMES") then
        add_patches("0.10.4", path.join(os.scriptdir(), "patches", "worklets-jsc.patch"), "89d75465fcec06558a918f7b8c471d012909e6a144b836add2964031c9438e36")
    end
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path, and when the patches differ (RN_HERMES).", default = os.getenv("RN_HERMES") and "1-hermes" or "1", readonly = true})

    on_install(function (package)
        os.cp("*", package:installdir() .. "/")
    end)

    on_test(function (package)
        local json = import("core.base.json")
        local manifest = json.decode(io.readfile(path.join(package:installdir(), "package.json")))
        assert(manifest.name == "react-native-worklets" and manifest.version == "0.10.4", "the package is " .. manifest.name .. " " .. manifest.version)
        assert(os.isfile(path.join(package:installdir(), "Common/cpp/worklets/WorkletRuntime/WorkletRuntime.cpp")), "Common/cpp/worklets/WorkletRuntime/WorkletRuntime.cpp is not installed")
        local patched = io.readfile(path.join(package:installdir(), "Common/cpp/worklets/WorkletRuntime/WorkletRuntime.cpp"))
        if os.getenv("RN_HERMES") then
            assert(patched:find("makeHermesRuntime", 1, true), "the Hermes runtime is not in the installed sources")
        else
            assert(patched:find("jsc/JSCRuntime.h", 1, true), "the patches are not in the installed sources")
        end
    end)
