package("swiftui")
    set_homepage("https://github.com/kern0x1b/eidolon")
    set_description("Eidolon's SwiftUI for iOS 6 as a module and a static library a port imports: the module keeps Apple's name on purpose, because the mangled names of every symbol an app takes from SwiftUI depend on it. The sources are the eidolon repository at the version below, built with the flags Eidolon's own build uses, so the module a port compiles against is the one Eidolon's own binaries are proven with. The textual interface of the module is written beside it, for a reader and for a diff.")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/kern0x1b/eidolon.git")
    add_versions("2026.09.28", "cc5f8b59259fa247799ae259a110d9328a9cf9cb")

    -- The three things the runtime a port carries is built with, named the way the runtime names them, so that a port that
    -- requires this package with them requires a runtime of the same build: the module is read against that runtime's own
    -- resource directory and its overlays, and a module read against another one is another package.
    add_configs("shared", {description = "Compile against a shared swift-runtime and its packaged libc++, for a port that requires them so.", default = false, type = "boolean"})
    add_configs("backports", {description = "Compile against the swift-runtime built with the backports, for a port that requires it so.", default = false, type = "boolean"})
    add_configs("backports_uikit", {description = "With backports: the runtime whose UIKit overlay is linked to the UIKit backports.", default = false, type = "boolean"})

    -- The sources come from the pinned ref above, so the digest is this recipe: a change to how the module is built is a
    -- different package with its own install path, and a comment is not.
    add_configs("recipe", {description = "The digest of this recipe, so a changed one is a different package.", default = hash.strhash128(hash.sha256(path.join(os.scriptdir(), "xmake.lua"))), type = "string", readonly = true})

    on_load("iphoneos", function (package)
        package:add("deps", "charon@swift-runtime", {alias = "swift-runtime", configs = {shared = package:config("shared") or nil,
                    backports = package:config("backports") or nil, backports_uikit = package:config("backports_uikit") or nil}})
        -- The module imports Combine (Text's publisher overloads, a handful of files), so it is compiled against the module
        -- charon@styx builds and a program that links this one links that: the dep is not private for the same reason the
        -- runtime's own overlays are not.
        package:add("deps", "charon@styx", {alias = "styx", configs = {shared = package:config("shared") or nil,
                    backports = package:config("backports") or nil, backports_uikit = package:config("backports_uikit") or nil}})
        -- The module's own object, archived: a program takes the whole module with one -l, the way Eidolon's own build links
        -- the same object into each of its binaries.
        package:add("links", "EidolonSwiftUI")
        package:add("frameworks", "UIKit", "CoreGraphics", "QuartzCore", "CoreData", "CoreImage", "Foundation", "CoreFoundation")
    end)

    on_install("iphoneos", function (package)
        local modules = path.join(package:scriptdir(), "..", "..", "..", "modules")
        local swift = import("apple.swift", {rootdir = modules, anonymous = true})
        local toolchain = assert(package:toolchains(), "SwiftUI is built with the apple-ios toolchain")[1]
        toolchain:load()
        local runtime = assert(package:dep("swift-runtime"), "SwiftUI is compiled against charon@swift-runtime")
        local styx = assert(package:dep("styx"), "SwiftUI imports Combine, the module charon@styx builds")
        local swiftc = assert(table.wrap((runtime:envs() or {}).SWIFT_EXEC)[1], "swift-runtime names no compiler; reinstall it")
        local minimum = toolchain:config("deployment")
        local sdk = toolchain:config("sdkdir")
        local sources = os.files(path.join("eidolon", "Sources", "SwiftUI", "*.swift"))
        assert(#sources > 0, "the sources of the module are missing from the package")

        local objects = path.absolute("objects")
        os.mkdir(objects)
        local swiftdir = path.join(package:installdir("lib"), "swift", "iphoneos")
        local module = path.join(swiftdir, "SwiftUI.swiftmodule")
        os.mkdir(module)

        -- One compile of the whole module, as Eidolon's own build compiles it: the whole-module object and the module beside
        -- it, with the marks of the release the port builds for. The flags of the runtime are the ones Eidolon's PKGFLAGS
        -- spells out, so the module is read against that runtime and no other.
        local argv = table.join(swift.runtime_flags({
            architecture = package:arch(), deployment = minimum, sdk = sdk,
            resources = path.join(runtime:installdir(), "lib", "swift"),
            plugins = table.wrap((runtime:envs() or {}).SWIFT_PLUGIN_PATH)[1],
            module = "SwiftUI", optimize = "fastest",
            prefix_map = os.curdir() .. "=/eidolon"}),
            {"-I", path.join(styx:installdir(), "lib", "swift", "iphoneos"),
             "-I", path.join(styx:installdir(), "include", "CombineHelpers"),
             -- as Eidolon's own build has it: exclusivity unchecked is the mode of the sources as they are written, and the
             -- warnings of a package build are its own, not a gate on the reader
             "-enforce-exclusivity=unchecked", "-suppress-warnings",
             "-emit-module", "-emit-module-path", path.join(module, package:arch() .. "-apple-ios.swiftmodule"),
             -- the textual interface, which no build here needs and every reader does: the module as it is written,
             -- readable and diffable. The compiler refuses to write one without a language mode ("emitting module interface
             -- files requires '-language-mode'", measured on this release), and a build's default mode is 5: the module
             -- written with -swift-version 5 is byte for byte the module a build writes without it (measured on the same
             -- flags), so the flag is what lets the interface out and changes nothing else. The interface is written without
             -- library evolution and says so in its own header, so it is for reading and for this compiler; the binary module
             -- beside it is what a port compiles with.
             "-swift-version", "5", "-emit-module-interface-path", path.join(module, "SwiftUI.swiftinterface"),
             "-c"}, sources, {"-o", path.join(objects, "SwiftUI.o")})
        os.vrunv(swiftc, argv)

        os.vrunv(toolchain:tool("ar"), {"-rcs", path.join(package:installdir("lib"), "libEidolonSwiftUI.a"),
                 path.join(objects, "SwiftUI.o")})

        -- What a program that imports SwiftUI compiles against: rules/swift reads this env of every dependency and adds the
        -- folder to its -I, so requiring this package is all a port's own Swift sources need.
        package:setenv("CHARON_SWIFT_MODULES", swiftdir)
        os.cp(path.join("eidolon", "LICENSE"), package:installdir("licenses"))
    end)
