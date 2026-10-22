package("musickit")
    set_homepage("https://developer.apple.com/documentation/musickit")
    set_description("MusicKit for a legacy Apple platform: the model types, the catalogue requests and the authorization, as a module named MusicKit a port imports, built against the revenant@swift-runtime and revenant@micro-ecc a port carries")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)
    add_configs("apple_sdk", {description = "The iPhoneOS SDK the generated project names: the one the consumer installed, so the package is not built against a second SDK.", type = "string"})

    includes(path.join(os.scriptdir(), "port", "digest.lua"))
    add_configs("recipe", {description = "The digest of this recipe and the sources it compiles, so a changed recipe or a changed source is a different module.", default = musickit_sources_digest, type = "string", readonly = true})

    on_load("iphoneos", function (package)
        local toolchain = assert(package:toolchains(), "musickit is built with the apple-ios toolchain")[1]
        toolchain:load()
        raise("musickit is not yet backported to iOS %s: Catalog.swift uses URLComponents, which needs iOS 7, and URLQueryItem, which needs iOS 8; see the open gaps in frameworks/Backports/README.md", toolchain:config("deployment"))
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
