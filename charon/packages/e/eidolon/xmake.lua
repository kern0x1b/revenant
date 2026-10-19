package("eidolon")
    set_homepage("https://github.com/kern0x1b/eidolon")
    set_description("Eidolon, the SwiftUI API reimplemented on the UIKit of iOS 6, built against the charon@swift-runtime a port carries and against charon@styx for Combine: one module named SwiftUI, since every symbol an app takes from SwiftUI is mangled with that name, as a static library with its module, so a port writes `import SwiftUI`")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/kern0x1b/eidolon.git")
    add_versions("2026.09.23", "10f87e02eaf4545dfaff7fe30ed0d69643bbad5e")
    add_versions("2026.10.14", "9f6a4aeb716d6b928bcc995d859c0f41f0c4663c")
    add_versions("2026.10.15", "f324b949eb3bac3fc4ef73e08712ff0a528b11b7")
    add_versions("2026.10.16", "12a737b35ae64e1f4c4f1964197367841fe588d3")

    -- Eidolon is compiled against the runtime a port takes, and against Styx built against that same runtime: what the
    -- port asks of the runtime it asks here too, and Eidolon passes it on to both. (charon@swift rule refuses a link with
    -- two builds.)
    add_configs("shared", {description = "Compile against a shared swift-runtime and its packaged libc++, for a port that requires them so.", default = false, type = "boolean"})
    add_configs("backports", {description = "Compile against the swift-runtime built with the backports, for a port that requires it so.", default = false, type = "boolean"})
    add_configs("backports_uikit", {description = "With backports: the runtime whose UIKit overlay is linked to the UIKit backports.", default = false, type = "boolean"})
    add_configs("recipe", {description = "The digest of this recipe, so a changed recipe is a different package.", default = hash.strhash128("xmake.lua=" .. hash.sha256(path.join(os.scriptdir(), "xmake.lua"))), type = "string", readonly = true})

    on_load("iphoneos", function (package)
        local configs = {shared = package:config("shared") or nil, backports = package:config("backports") or nil,
                         backports_uikit = package:config("backports_uikit") or nil}
        package:add("deps", "charon@swift-runtime", {alias = "swift-runtime", configs = configs})
        package:add("deps", "charon@libcxx", {alias = "libcxx", configs = {packaged = package:config("shared") or nil}})
        package:add("deps", "charon@styx", {alias = "styx", configs = configs})
        package:add("links", "SwiftUI")
        package:add("frameworks", "UIKit", "QuartzCore", "CoreGraphics", "CoreData", "Foundation", "CoreFoundation")
    end)

    on_install("iphoneos", function (package)
        local modules = path.join(package:scriptdir(), "..", "..", "..", "modules")
        local swift = import("apple.swift", {rootdir = modules, anonymous = true})
        local toolchain = assert(package:toolchains(), "Eidolon is built with the apple-ios toolchain")[1]
        toolchain:load()
        local runtime = assert(package:dep("swift-runtime"), "Eidolon is compiled against charon@swift-runtime")
        local styx = assert(package:dep("styx"), "Eidolon imports Combine from charon@styx")
        local swiftc = assert(table.wrap((runtime:envs() or {}).SWIFT_EXEC)[1], "swift-runtime names no compiler; reinstall it")
        local swiftdir = path.join(package:installdir("lib"), "swift", "iphoneos")
        local objects = path.absolute("objects")
        os.mkdir(objects)
        os.mkdir(swiftdir)

        -- The one SwiftUI module, as Eidolon's own build compiles it: whole-module, exclusivity checked statically only.
        -- Availability checking stays on, so what a later release adds stays behind #available.
        local combine = {}
        for _, folder in ipairs(table.wrap((styx:envs() or {}).CHARON_SWIFT_MODULES)) do
            table.join2(combine, {"-I", folder})
        end
        local module = path.join(swiftdir, "SwiftUI.swiftmodule")
        os.mkdir(module)
        local argv = table.join(swift.runtime_flags({
            architecture = package:arch(), deployment = toolchain:config("deployment"), sdk = toolchain:config("sdkdir"),
            resources = path.join(runtime:installdir(), "lib", "swift"),
            plugins = table.wrap((runtime:envs() or {}).SWIFT_PLUGIN_PATH)[1],
            module = "SwiftUI", optimize = "fastest", prefix_map = os.curdir() .. "=/eidolon"}),
            combine, {"-enforce-exclusivity=unchecked", "-suppress-warnings", "-emit-module", "-emit-module-path",
                      path.join(module, package:arch() .. "-apple-ios.swiftmodule"), "-c"},
            os.files(path.join("eidolon", "Sources", "SwiftUI", "*.swift")), {"-o", path.join(objects, "SwiftUI.o")})
        os.vrunv(swiftc, argv)
        os.vrunv(toolchain:tool("ar"), {"-rcs", path.join(package:installdir("lib"), "libSwiftUI.a"), path.join(objects, "SwiftUI.o")})

        -- A port that imports SwiftUI imports Combine through it, so it finds Styx's module folders here too.
        package:setenv("CHARON_SWIFT_MODULES", swiftdir, table.unpack(table.wrap((styx:envs() or {}).CHARON_SWIFT_MODULES)))
        os.cp("LICENSE", package:installdir("licenses"))
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libSwiftUI.a")))
        assert(os.isdir(path.join(package:installdir("lib"), "swift", "iphoneos", "SwiftUI.swiftmodule")))
    end)
