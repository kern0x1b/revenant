package("react-native-community-slider")
    set_kind("library", {headeronly = true})
    set_homepage("https://www.npmjs.com/package/@react-native-community/slider")
    set_description("@react-native-community/slider 5.2.0, from its npm tarball: the native slider, with isSliding declared BOOL to match its instance variable on 32-bit ARM")
    set_license("MIT")

    add_urls("https://registry.npmjs.org/@react-native-community/slider/-/slider-$(version).tgz")
    add_versions("5.2.0", "ed4bd124b24f0605d180f73d495823e1562b378c2e6ebaadba0e9be316f74c24")
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = "1", readonly = true})

    local patches = {"0001-Declare-isSliding-as-BOOL-to-match-its-ivar.patch"}
    local digests = {"xmake.lua=" .. hash.sha256(path.join(os.scriptdir(), "xmake.lua"))}
    for _, name in ipairs(patches) do
        local file = path.join(os.scriptdir(), "patches", name)
        local digest = hash.sha256(file)
        add_patches("5.2.0", file, digest)
        table.insert(digests, name .. "=" .. digest)
    end
    add_configs("recipe", {description = "The digest of this recipe and the patches it applies, so a changed patch is a different build.",
                           default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    on_install(function (package)
        os.cp("*", package:installdir() .. "/")
    end)

    on_test(function (package)
        local json = import("core.base.json")
        local manifest = json.decode(io.readfile(path.join(package:installdir(), "package.json")))
        assert(manifest.name == "@react-native-community/slider" and manifest.version == "5.2.0", "the package is " .. manifest.name .. " " .. manifest.version)
        assert(io.readfile(path.join(package:installdir(), "ios", "RNCSlider.h")):find("BOOL isSliding", 1, true), "the isSliding patch is not applied")
    end)
