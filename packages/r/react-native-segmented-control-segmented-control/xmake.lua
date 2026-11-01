package("react-native-segmented-control-segmented-control")
    set_kind("library", {headeronly = true})
    set_homepage("https://www.npmjs.com/package/@react-native-segmented-control/segmented-control")
    set_description("@react-native-segmented-control/segmented-control 2.5.7, from its npm tarball: the native segmented control")
    set_license("MIT")

    add_urls("https://registry.npmjs.org/@react-native-segmented-control/segmented-control/-/segmented-control-$(version).tgz")
    add_versions("2.5.7", "285b4384f944e49cb2e25ef01b4203b528e102634d828aa80ce089442669c142")
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = "1", readonly = true})

    on_install(function (package)
        os.cp("*", package:installdir() .. "/")
    end)

    on_test(function (package)
        local json = import("core.base.json")
        local manifest = json.decode(io.readfile(path.join(package:installdir(), "package.json")))
        assert(manifest.name == "@react-native-segmented-control/segmented-control" and manifest.version == "2.5.7", "the package is " .. manifest.name .. " " .. manifest.version)
    end)
