package("react-native-community-datetimepicker")
    set_kind("library", {headeronly = true})
    set_homepage("https://www.npmjs.com/package/@react-native-community/datetimepicker")
    set_description("@react-native-community/datetimepicker 9.1.0, from its npm tarball: the native date and time pickers")
    set_license("MIT")

    add_urls("https://registry.npmjs.org/@react-native-community/datetimepicker/-/datetimepicker-$(version).tgz")
    add_versions("9.1.0", "8a0d6fc5af2776aec94a34feeb94e98a13557057a86b3457194d8ec2409699c3")
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = "1", readonly = true})

    on_install(function (package)
        os.cp("*", package:installdir() .. "/")
    end)

    on_test(function (package)
        local json = import("core.base.json")
        local manifest = json.decode(io.readfile(path.join(package:installdir(), "package.json")))
        assert(manifest.name == "@react-native-community/datetimepicker" and manifest.version == "9.1.0", "the package is " .. manifest.name .. " " .. manifest.version)
    end)
