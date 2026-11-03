package("react-native-community-netinfo")
    set_kind("library", {headeronly = true})
    set_homepage("https://www.npmjs.com/package/@react-native-community/netinfo")
    set_description("@react-native-community/netinfo 12.0.1, from its npm tarball: network state for React Native")
    set_license("MIT")

    add_urls("https://registry.npmjs.org/@react-native-community/netinfo/-/netinfo-$(version).tgz")
    add_versions("12.0.1", "2f7de0df879f66281b537a8b64b7ba2039fe9cd6d3da3e43b32f6ce44df58bed")
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = "1", readonly = true})

    on_install(function (package)
        os.cp("*", package:installdir() .. "/")
    end)

    on_test(function (package)
        local json = import("core.base.json")
        local manifest = json.decode(io.readfile(path.join(package:installdir(), "package.json")))
        assert(manifest.name == "@react-native-community/netinfo" and manifest.version == "12.0.1", "the package is " .. manifest.name .. " " .. manifest.version)
    end)
