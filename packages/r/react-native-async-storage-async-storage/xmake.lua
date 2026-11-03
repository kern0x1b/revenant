package("react-native-async-storage-async-storage")
    set_kind("library", {headeronly = true})
    set_homepage("https://www.npmjs.com/package/@react-native-async-storage/async-storage")
    set_description("@react-native-async-storage/async-storage 2.2.0, from its npm tarball: asynchronous persistent key-value storage")
    set_license("MIT")

    add_urls("https://registry.npmjs.org/@react-native-async-storage/async-storage/-/async-storage-$(version).tgz")
    add_versions("2.2.0", "8f708f4558256be3d7dcdfcc0aafdbd37bea517b48fcb7d1446f2c2c6e18afdf")
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = "1", readonly = true})

    on_install(function (package)
        os.cp("*", package:installdir() .. "/")
    end)

    on_test(function (package)
        local json = import("core.base.json")
        local manifest = json.decode(io.readfile(path.join(package:installdir(), "package.json")))
        assert(manifest.name == "@react-native-async-storage/async-storage" and manifest.version == "2.2.0", "the package is " .. manifest.name .. " " .. manifest.version)
    end)
