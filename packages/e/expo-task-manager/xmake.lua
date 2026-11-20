package("expo-task-manager")
    set_kind("library", {headeronly = true})
    set_homepage("https://github.com/expo/expo/tree/main/packages/expo-task-manager")
    set_description("expo-task-manager 57.0.21, the background task manager of the Expo SDK, from its npm tarball: the iOS module sources the host builds from, unpatched so far")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    add_deps("unimodules-app-loader")

    add_urls("https://registry.npmjs.org/expo-task-manager/-/expo-task-manager-$(version).tgz")
    add_versions("57.0.21", "c5742c062555e6a0d847fcaafcf4ccbdd94c272341401499dc17fdad0265b350")

    on_install(function (package)
        os.cp("*", package:installdir() .. "/")
    end)

    on_test(function (package)
        local json = import("core.base.json")
        local manifest = json.decode(io.readfile(path.join(package:installdir(), "package.json")))
        assert(manifest.name == "expo-task-manager" and manifest.version == "57.0.21", "the package is " .. manifest.name .. " " .. manifest.version)
        assert(os.isfile(path.join(package:installdir(), "ios", "TaskManagerModule.swift")), "expo-task-manager has no iOS module")
        assert(os.isfile(path.join(package:installdir(), "expo-module.config.json")), "expo-task-manager has no expo-module.config.json")
    end)
