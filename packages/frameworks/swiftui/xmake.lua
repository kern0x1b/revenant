package("swiftui")
    set_homepage("https://github.com/kern0x1b/revenant/tree/main/frameworks/SwiftUI")
    set_description("Revenant's SwiftUI for iOS 6 as a module and a static library a port imports: the module keeps Apple's name on purpose, because the mangled names of every symbol an app takes from SwiftUI depend on it. The sources are the SwiftUI repository at the version below, built with the flags SwiftUI's own build uses, so the module a port compiles against is the one SwiftUI's own binaries are proven with. The textual interface of the module is written beside it, for a reader and for a diff.")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/kern0x1b/revenant.git")
    add_versions("2026.09.28", "cc5f8b59259fa247799ae259a110d9328a9cf9cb")

    add_configs("shared", {description = "Compile against a shared swift-runtime and its packaged libc++, for a port that requires them so.", default = false, type = "boolean"})
    add_configs("backports", {description = "Compile against the swift-runtime built with the backports, for a port that requires it so.", default = false, type = "boolean"})
    add_configs("backports_uikit", {description = "With backports: the runtime whose UIKit overlay is linked to the UIKit backports.", default = false, type = "boolean"})

    add_configs("recipe", {description = "The digest of this recipe, so a changed one is a different package.", default = hash.strhash128(hash.sha256(path.join(os.scriptdir(), "xmake.lua"))), type = "string", readonly = true})

    on_load("iphoneos", function (package)
        package:add("deps", "revenant@swift-runtime", {alias = "swift-runtime", configs = {shared = package:config("shared") or nil,
                    backports = package:config("backports") or nil, backports_uikit = package:config("backports_uikit") or nil}})
        package:add("deps", "revenant@combine", {alias = "combine", configs = {shared = package:config("shared") or nil,
                    backports = package:config("backports") or nil, backports_uikit = package:config("backports_uikit") or nil}})
        package:add("links", "RevenantSwiftUI")
        package:add("frameworks", "UIKit", "CoreGraphics", "QuartzCore", "CoreData", "CoreImage", "Foundation", "CoreFoundation")
    end)

    on_install("iphoneos", function (package)
        local modules = path.join(package:scriptdir(), "..", "..", "..", "toolchain", "modules")
        local swift = import("apple.swift", {rootdir = modules, anonymous = true})
        local toolchain = assert(package:toolchains(), "SwiftUI is built with the apple-ios toolchain")[1]
        toolchain:load()
        local runtime = assert(package:dep("swift-runtime"), "SwiftUI is compiled against revenant@swift-runtime")
        local combine = assert(package:dep("combine"), "SwiftUI imports Combine, the module revenant@combine builds")
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

        local argv = table.join(swift.runtime_flags({
            architecture = package:arch(), deployment = minimum, sdk = sdk,
            resources = path.join(runtime:installdir(), "lib", "swift"),
            plugins = table.wrap((runtime:envs() or {}).SWIFT_PLUGIN_PATH)[1],
            module = "SwiftUI", optimize = "fastest",
            prefix_map = os.curdir() .. "=/SwiftUI"}),
            {"-I", path.join(combine:installdir(), "lib", "swift", "iphoneos"),
             "-I", path.join(combine:installdir(), "include", "CombineHelpers"),
             "-enforce-exclusivity=unchecked", "-suppress-warnings",
             "-emit-module", "-emit-module-path", path.join(module, package:arch() .. "-apple-ios.swiftmodule"),
             "-swift-version", "5", "-emit-module-interface-path", path.join(module, "SwiftUI.swiftinterface"),
             "-c"}, sources, {"-o", path.join(objects, "SwiftUI.o")})
        os.vrunv(swiftc, argv)

        os.vrunv(toolchain:tool("ar"), {"-rcs", path.join(package:installdir("lib"), "libRevenantSwiftUI.a"),
                 path.join(objects, "SwiftUI.o")})

        package:setenv("REVENANT_SWIFT_MODULES", swiftdir)
        os.cp(path.join("eidolon", "LICENSE"), package:installdir("licenses"))
    end)
