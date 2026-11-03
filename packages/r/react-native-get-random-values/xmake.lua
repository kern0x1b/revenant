package("react-native-get-random-values")
    set_kind("library", {headeronly = true})
    set_homepage("https://www.npmjs.com/package/react-native-get-random-values")
    set_description("react-native-get-random-values 1.11.0, from its npm tarball: random values from the platform's secure random source for crypto.getRandomValues")
    set_license("MIT")

    add_urls("https://registry.npmjs.org/react-native-get-random-values/-/react-native-get-random-values-$(version).tgz")
    add_versions("1.11.0", "261ce90a6ff0c933b7cbd523c84cf37b783542c0a50f6d88562e7a1a75c032b8")
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = "1", readonly = true})

    on_install(function (package)
        os.cp("*", package:installdir() .. "/")
    end)

    on_test(function (package)
        local json = import("core.base.json")
        local manifest = json.decode(io.readfile(path.join(package:installdir(), "package.json")))
        assert(manifest.name == "react-native-get-random-values" and manifest.version == "1.11.0", "the package is " .. manifest.name .. " " .. manifest.version)
    end)
