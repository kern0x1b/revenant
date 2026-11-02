package("expo-battery")
    set_homepage("https://github.com/expo/expo/tree/main/packages/expo-battery")
    set_description("expo-battery 57.0.3, the battery level, state and low-power mode of the Expo SDK, from its npm tarball, with the low-power mode API guarded for iOS 6")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    local patches = {"0001-Answer-the-low-power-mode-as-off-before-iOS-9.patch"}
    add_urls("https://registry.npmjs.org/expo-battery/-/expo-battery-$(version).tgz")
    add_versions("57.0.3", "d043d13364185cf0deeaf68c0df32129f84ecf88ac0fcd8cadffa430d685c80c")
    for _, name in ipairs(patches) do
        local file = path.join(os.scriptdir(), "patches", name)
        add_patches("57.0.3", file, hash.sha256(file))
    end
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = "1", readonly = true})

    on_install(function (package)
        os.cp("*", package:installdir() .. "/")
    end)

    on_test(function (package)
        local json = import("core.base.json")
        local manifest = json.decode(io.readfile(path.join(package:installdir(), "package.json")))
        assert(manifest.name == "expo-battery" and manifest.version == "57.0.3", "the package is " .. manifest.name .. " " .. manifest.version)
        local source = io.readfile(path.join(package:installdir(), "ios", "BatteryModule.swift"))
        assert(source:find("@available", 1, true) or source:find("#available(iOS 9.0", 1, true), "the low-power mode API is not guarded")
    end)
