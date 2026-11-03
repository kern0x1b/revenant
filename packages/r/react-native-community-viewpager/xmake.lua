package("react-native-community-viewpager")
    set_kind("library", {headeronly = true})
    set_homepage("https://www.npmjs.com/package/@react-native-community/viewpager")
    set_description("@react-native-community/viewpager 5.0.11, from its npm tarball: the Android-style view pager")
    set_license("MIT")

    add_urls("https://registry.npmjs.org/@react-native-community/viewpager/-/viewpager-$(version).tgz")
    add_versions("5.0.11", "6f50e969f529099554cbd88809f170d793d24aee65fc9d67efe4d95d5f2607f7")
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = "1", readonly = true})

    on_install(function (package)
        os.cp("*", package:installdir() .. "/")
    end)

    on_test(function (package)
        local json = import("core.base.json")
        local manifest = json.decode(io.readfile(path.join(package:installdir(), "package.json")))
        assert(manifest.name == "@react-native-community/viewpager" and manifest.version == "5.0.11", "the package is " .. manifest.name .. " " .. manifest.version)
    end)
