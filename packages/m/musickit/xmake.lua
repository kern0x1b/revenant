package("musickit")
    set_homepage("https://developer.apple.com/documentation/musickit")
    set_description("MusicKit for a legacy Apple platform: the model types, the catalogue requests and the authorization, as a module named MusicKit a port imports, built against the revenant@swift-runtime and revenant@micro-ecc a port carries")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    includes(path.join(os.scriptdir(), "port", "digest.lua"))
    add_configs("recipe", {description = "The digest of this recipe and the sources it compiles, so a changed recipe or a changed source is a different module.", default = musickit_sources_digest, type = "string", readonly = true})

    on_load("iphoneos", function (package)
        package:add("deps", "revenant@swift-runtime", {alias = "swift-runtime"})
        package:add("deps", "revenant@micro-ecc", {alias = "micro-ecc"})
        package:add("links", "MusicKit")
        package:add("frameworks", "Foundation", "CoreGraphics")
    end)

    on_install("iphoneos", function (package)
        local root = path.translate(path.join(package:scriptdir(), "..", "..", ".."))
        import("@addon.revenant.apple.wrapper", {anonymous = true}).install(package, {root = root,
            includes = {path.join(root, "frameworks", "Backports", "src", "Swift")}, targets = {"MusicKit"}, modules = true})
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libMusicKit.a")))
        assert(os.isdir(path.join(package:installdir("lib"), "swift", "iphoneos", "MusicKit.swiftmodule")))
    end)
