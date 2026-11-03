package("react-native-picker-picker")
    set_kind("library", {headeronly = true})
    set_homepage("https://www.npmjs.com/package/@react-native-picker/picker")
    set_description("@react-native-picker/picker 2.11.4, from its npm tarball: the native picker of React Native")
    set_license("MIT")

    add_urls("https://registry.npmjs.org/@react-native-picker/picker/-/picker-$(version).tgz")
    add_versions("2.11.4", "f6c708f1ca8a94a4a1e364623f97ac92709e419bddcc579e71e0c662ab4d548b")
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = "1", readonly = true})

    on_install(function (package)
        os.cp("*", package:installdir() .. "/")
    end)

    on_test(function (package)
        local json = import("core.base.json")
        local manifest = json.decode(io.readfile(path.join(package:installdir(), "package.json")))
        assert(manifest.name == "@react-native-picker/picker" and manifest.version == "2.11.4", "the package is " .. manifest.name .. " " .. manifest.version)
    end)
