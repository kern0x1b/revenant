package("lottie-react-native")
    set_kind("library", {headeronly = true})
    set_homepage("https://www.npmjs.com/package/lottie-react-native")
    set_description("lottie-react-native 7.3.8, from its npm tarball: plays Lottie animations on the native side")
    set_license("Apache-2.0")

    add_urls("https://registry.npmjs.org/lottie-react-native/-/lottie-react-native-$(version).tgz")
    add_versions("7.3.8", "fa2a962022c972fcaf75e68206ed92b46bc39c22c82165ae04c097c157b61307")
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = "1", readonly = true})

    on_install(function (package)
        os.cp("*", package:installdir() .. "/")
    end)

    on_test(function (package)
        local json = import("core.base.json")
        local manifest = json.decode(io.readfile(path.join(package:installdir(), "package.json")))
        assert(manifest.name == "lottie-react-native" and manifest.version == "7.3.8", "the package is " .. manifest.name .. " " .. manifest.version)
    end)
