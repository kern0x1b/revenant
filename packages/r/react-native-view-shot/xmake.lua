package("react-native-view-shot")
    set_kind("library", {headeronly = true})
    set_homepage("https://www.npmjs.com/package/react-native-view-shot")
    set_description("react-native-view-shot 5.1.0, from its npm tarball: captures a React view as an image")
    set_license("MIT")

    add_urls("https://registry.npmjs.org/react-native-view-shot/-/react-native-view-shot-$(version).tgz")
    add_versions("5.1.0", "4a3bbb53024b9733653856cfb3d932587d3774c8e57c9d19a46637222f4aa7ea")
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = "1", readonly = true})

    on_install(function (package)
        os.cp("*", package:installdir() .. "/")
    end)

    on_test(function (package)
        local json = import("core.base.json")
        local manifest = json.decode(io.readfile(path.join(package:installdir(), "package.json")))
        assert(manifest.name == "react-native-view-shot" and manifest.version == "5.1.0", "the package is " .. manifest.name .. " " .. manifest.version)
    end)
