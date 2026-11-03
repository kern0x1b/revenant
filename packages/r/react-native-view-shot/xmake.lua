package("react-native-view-shot")
    set_kind("library", {headeronly = true})
    set_homepage("https://github.com/gre/react-native-view-shot")
    set_description("react-native-view-shot 5.1.0, capturing a React Native view as a PNG or JPEG file, from its npm tarball: RNViewShot over the CoreGraphics context of the release, on iOS 6 through UIGraphicsBeginImageContextWithOptions and layer renderInContext, which is what UIGraphicsImageRenderer and drawViewHierarchyInRect replaced on iOS 10 and 7")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    add_urls("https://registry.npmjs.org/react-native-view-shot/-/react-native-view-shot-$(version).tgz")
    add_versions("5.1.0", "4a3bbb53024b9733653856cfb3d932587d3774c8e57c9d19a46637222f4aa7ea")

    local patches = {
        {"0001-Capture-through-the-CoreGraphics-context-and-the-layer-path.patch", "be8ffd661e0ef67373c54c2c48a319a12e6eac16819e1b18a111104d0f19664e"}}

    local digests = {"xmake.lua=" .. hash.sha256(path.join(os.scriptdir(), "xmake.lua"))}
    for _, patch in ipairs(patches) do
        local file = path.join(os.scriptdir(), "patches", patch[1])
        add_patches("5.1.0", file, patch[2])
        table.insert(digests, patch[1] .. "=" .. hash.sha256(file))
    end
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    on_install(function (package)
        os.cp("*", package:installdir() .. "/")
    end)

    on_test(function (package)
        local json = import("core.base.json")
        local manifest = json.decode(io.readfile(path.join(package:installdir(), "package.json")))
        assert(manifest.name == "react-native-view-shot" and manifest.version == "5.1.0", "the package is " .. manifest.name .. " " .. manifest.version)
        local capture = io.readfile(path.join(package:installdir(), "ios", "RNViewShot.mm"))
        assert(capture:find("UIGraphicsBeginImageContextWithOptions", 1, true), "the iOS 6 capture path is not in RNViewShot.mm")
    end)
