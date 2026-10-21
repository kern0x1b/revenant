package("musickit")
    set_homepage("https://developer.apple.com/documentation/musickit")
    set_description("MusicKit for a legacy Apple platform: the model types, the catalogue requests and the authorization, as a module named MusicKit a port imports. The service is Apple's own - the catalogue, the search and the previews are requests to api.music.apple.com over the Apple Music API - and what this package adds is the surface, the request building and the decoding, so that a client of an iOS 6 device can name and read the catalogue the way a program built against MusicKit 26 does. MusicAuthorization answers as a device with no Apple Music, which is every device this port runs on")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    add_links("MusicKit")

    add_configs("shared", {description = "Compile against a shared swift-runtime and its packaged libc++, for a port that requires them so.", default = false, type = "boolean"})
    add_configs("backports", {description = "Compile against the swift-runtime built with the backports, for a port that requires it so.", default = false, type = "boolean"})

    local sources = {}
    for _, file in ipairs(os.files(path.join(os.scriptdir(), "..", "..", "..", "frameworks", "Backports", "src", "MusicKit", "*.swift"))) do
        table.insert(sources, file)
    end
    table.insert(sources, path.join(os.scriptdir(), "..", "..", "..", "frameworks", "Backports", "src", "MusicKit", "RevenantC.c"))
    local digests = {path.join(os.scriptdir(), "xmake.lua"), path.join(os.scriptdir(), "..", "..", "..", "docs", "reference", "backports", "MusicKit", "README.md")}
    for _, file in ipairs(sources) do
        table.insert(digests, path.filename(file) .. "=" .. hash.sha256(file))
    end
    table.sort(digests)
    add_configs("recipe", {description = "The digest of this recipe and the sources it compiles, so a changed recipe or a changed source is a different module.", default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    on_load("iphoneos", function (package)
        package:add("deps", "revenant@swift-runtime", {alias = "swift-runtime", configs = {shared = package:config("shared") or nil,
                    backports = package:config("backports") or nil}})
        package:add("frameworks", "Foundation", "CoreGraphics")
        package:add("deps", "revenant@micro-ecc", {alias = "micro-ecc"})
    end)

    on_install("iphoneos", function (package)
        local swift = import("@addon.revenant.apple.swift", {anonymous = true})
        local toolchain = assert(package:toolchains(), "MusicKit is built with the apple-ios toolchain")[1]
        toolchain:load()
        local runtime = assert(package:dep("swift-runtime"), "MusicKit is compiled against revenant@swift-runtime")
        local swiftc = assert(table.wrap((runtime:envs() or {}).SWIFT_EXEC)[1], "swift-runtime names no compiler; reinstall it")
        local minimum = toolchain:config("deployment")
        local triple = package:arch() .. "-apple-ios" .. minimum
        local sdk = toolchain:config("sdkdir")
        local target = {"-target", package:arch() .. "-apple-ios", "-miphoneos-version-min=" .. minimum,
                        "-isysroot", sdk}
        local swiftdir = path.join(package:installdir("lib"), "swift", "iphoneos")
        local module = path.join(swiftdir, "MusicKit.swiftmodule")
        os.mkdir(module)
        local files = os.files(path.join(package:scriptdir(), "..", "..", "..", "frameworks", "Backports", "src", "MusicKit", "*.swift"))
        assert(#files > 0, "the module has no sources")
        os.mkdir(path.absolute("objects"))
        local micro = assert(package:dep("micro-ecc"), "MusicKit signs its developer token with revenant@micro-ecc")
        os.vrunv(toolchain:tool("cc"), table.join(target, {"-I" .. path.join(os.scriptdir(), "..", "..", "..", "frameworks", "Backports", "src", "MusicKit", "include"),
                 "-I" .. path.join(micro:installdir("include")), "-I" .. path.join(os.scriptdir(), "..", "..", "..", "frameworks", "Backports", "src", "MusicKit"),
                 "-Os", "-fvisibility=hidden", "-c", path.join(os.scriptdir(), "..", "..", "..", "frameworks", "Backports", "src", "MusicKit", "RevenantC.c"),
                 "-o", path.absolute(path.join("objects", "RevenantC.o"))}))
        os.vrunv(swiftc, table.join(swift.runtime_flags({
            architecture = package:arch(), deployment = minimum, sdk = sdk,
            resources = path.join(runtime:installdir(), "lib", "swift"),
            plugins = table.wrap((runtime:envs() or {}).SWIFT_PLUGIN_PATH)[1],
            module = "MusicKit", optimize = "fastest", prefix_map = os.curdir() .. "=/musickit"}),
            {"-import-objc-header", path.join(os.scriptdir(), "..", "..", "..", "frameworks", "Backports", "src", "MusicKit", "include", "MusicKitC.h"),
             "-I", path.join(os.scriptdir(), "..", "..", "..", "frameworks", "Backports", "src", "MusicKit", "include"),
             "-emit-module", "-emit-module-path", path.join(module, package:arch() .. "-apple-ios.swiftmodule"), "-c"}, files,
            {"-o", path.absolute(path.join("objects", "MusicKit.o"))}))
        os.vrunv(toolchain:tool("ar"), {"-rcs", path.join(package:installdir("lib"), "libMusicKit.a"),
                                       path.absolute(path.join("objects", "MusicKit.o")),
                                       path.absolute(path.join("objects", "RevenantC.o"))})
        package:setenv("REVENANT_SWIFT_MODULES", swiftdir)
        os.cp("LICENSE", package:installdir("licenses"))
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libMusicKit.a")))
        assert(os.isfile(path.join(package:installdir("lib", "swift", "iphoneos", "MusicKit.swiftmodule",
                                       package:arch() .. "-apple-ios.swiftmodule"))))
    end)
