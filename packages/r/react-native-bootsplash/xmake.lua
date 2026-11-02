package("react-native-bootsplash")
    set_kind("library", {headeronly = true})
    set_homepage("https://www.npmjs.com/package/react-native-bootsplash")
    set_description("react-native-bootsplash 6.3.12, from its npm tarball: the native splash screen of the app shell")
    set_license("MIT")

    add_urls("https://registry.npmjs.org/react-native-bootsplash/-/react-native-bootsplash-$(version).tgz")
    add_versions("6.3.12", "273e43a090ced61690323bd46291052022b03f28246fba8afe27cb54a3a43339")
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = "1", readonly = true})

    on_install(function (package)
        os.cp("*", package:installdir() .. "/")
    end)

    on_test(function (package)
        local json = import("core.base.json")
        local manifest = json.decode(io.readfile(path.join(package:installdir(), "package.json")))
        assert(manifest.name == "react-native-bootsplash" and manifest.version == "6.3.12", "the package is " .. manifest.name .. " " .. manifest.version)
    end)
