package("swiftui")
    set_homepage("https://github.com/kern0x1b/revenant/tree/main/frameworks/SwiftUI")
    set_description("Revenant's SwiftUI for iOS 6 as a module and a static library a port imports, with Apple's module name, built against the revenant@swift-runtime and revenant@combine a port carries")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)
    add_configs("apple_sdk", {description = "The iPhoneOS SDK the generated project names: the one the consumer installed, so the package is not built against a second SDK.", default = "16.4", type = "string"})

    includes(path.join(os.scriptdir(), "port", "digest.lua"))
    add_configs("sources", {description = "The digest of this recipe and the SwiftUI sources it builds, so a changed source is a different package.", default = swiftui_sources_digest, type = "string", readonly = true})

    on_load("iphoneos", function (package)
        package:add("deps", "revenant@swift-runtime", {alias = "swift-runtime"})
        package:add("deps", "revenant@combine", {alias = "combine"})
        package:add("links", "SwiftUI")
        package:add("frameworks", "UIKit", "CoreGraphics", "QuartzCore", "CoreData", "CoreImage", "Foundation", "CoreFoundation")
    end)

    on_install("iphoneos", function (package)
        local toolchain = assert(package:toolchains(), "SwiftUI is built with the apple-ios toolchain")[1]
        toolchain:load()
        import("core.package.addon")
        local revenant = addon.addons()[addon.dirname("revenant")] or raise("SwiftUI is built with the revenant addon's rules, and no revenant addon is installed")
        local root = path.translate(path.join(package:scriptdir(), "..", "..", ".."))
        local project = path.absolute("swiftui")
        os.mkdir(project)
        io.writefile(path.join(project, "xmake.lua"), table.concat({
            "add_repositories(\"revenant " .. root .. "\")",
            "add_addons(\"revenant\")",
            "set_config(\"apple_minimum\", \"" .. toolchain:config("deployment") .. "\")",
            "set_config(\"apple_sdk\", \"" .. package:config("apple_sdk") .. "\")",
            "includes(\"@addon/revenant/apple-ios\")",
            "option(\"component\", {type = \"string\", default = \"\"})",
            "add_requires(\"revenant@swift-runtime\", {alias = \"swift-runtime\"})",
            "add_requires(\"revenant@libcxx\", {alias = \"libcxx\"})",
            "add_requires(\"revenant@combine\", {alias = \"combine\"})",
            "includes(\"" .. path.join(root, "frameworks", "SwiftUI") .. "\")",
            "set_defaultplat(\"iphoneos\")",
            "set_defaultarchs(\"iphoneos|" .. package:arch() .. "\")",
            ""}, "\n"))
        io.save(path.join(project, "xmake-addons.lock"), {__meta__ = {version = "1.0"}, revenant = {version = revenant.version}})
        os.vrunv(os.programfile(), {"f", "-p", "iphoneos", "-a", package:arch(), "-m", "release", "-y"}, {curdir = project})
        os.vrunv(os.programfile(), {"build", "-y", "SwiftUI"}, {curdir = project, envs = {REVENANT_RELEASE = "1"}})
        os.vrunv(os.programfile(), {"install", "-y", "-o", package:installdir(), "SwiftUI"}, {curdir = project})
        package:setenv("REVENANT_SWIFT_MODULES", path.join(package:installdir("lib"), "swift", "iphoneos"))
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libSwiftUI.a")))
        assert(os.isdir(path.join(package:installdir("lib"), "swift", "iphoneos", "SwiftUI.swiftmodule")))
    end)
