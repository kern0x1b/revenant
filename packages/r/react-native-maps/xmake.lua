package("react-native-maps")
    set_kind("library", {headeronly = true})
    set_homepage("https://github.com/react-native-maps/react-native-maps")
    set_description("react-native-maps 1.27.2, the map view of React Native on MapKit, from its npm tarball: the iOS sources the host builds from, unpatched so far")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    add_urls("https://registry.npmjs.org/react-native-maps/-/react-native-maps-$(version).tgz")
    add_versions("1.27.2", "5c118ad7813402e7763dd9b97c2068fdc1bfc46a45e698c0e8a3aa010b4591b0")

    local patches = {
        {"0001-Build-the-Apple-maps-path-with-the-Google-provider-off.patch", "90adc5864fbe7b90f868a9426db9d6dad8e9cc590854ed8da90d476e8142b894"}}

    local digests = {"xmake.lua=" .. hash.sha256(path.join(os.scriptdir(), "xmake.lua"))}
    for _, patch in ipairs(patches) do
        local file = path.join(os.scriptdir(), "patches", patch[1])
        add_patches("1.27.2", file, patch[2])
        table.insert(digests, patch[1] .. "=" .. hash.sha256(file))
    end

    add_configs("recipe", {description = "The digest of this recipe and the patches it applies, so a changed recipe is a different package.", default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    on_install(function (package)
        os.cp("*", package:installdir() .. "/")
    end)

    on_test(function (package)
        local json = import("core.base.json")
        local manifest = json.decode(io.readfile(path.join(package:installdir(), "package.json")))
        assert(manifest.name == "react-native-maps" and manifest.version == "1.27.2", "the package is " .. manifest.name .. " " .. manifest.version)
        assert(os.isdir(path.join(package:installdir(), "ios")), "react-native-maps has no iOS sources")
        assert(io.readfile(path.join(package:installdir(), "ios", "AirMaps", "RNMapsDefines.h")):find("HAVE_GOOGLE_MAPS 0", 1, true), "the Google provider is not switched off")
    end)
