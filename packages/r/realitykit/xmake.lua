package("realitykit")
    set_homepage("https://github.com/kern0x1b/revenant/tree/main/frameworks/Backports")
    set_description("The RealityKit framework of iOS 13, as one Swift module and dylib a port writes `import RealityKit` for, built against the revenant@realityfoundation it imports and the revenant@swift-runtime a port carries; its SceneKit and UIKit parts are not yet backported below iOS 8")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)
    add_configs("apple_sdk", {description = "The iPhoneOS SDK the generated project names: the one the consumer installed, so the package is not built against a second SDK.", default = "16.4", type = "string"})

    includes(path.join(os.scriptdir(), "port", "digest.lua"))
    add_configs("sources", {description = "The digest of this recipe and the module's sources, so a changed declaration is a different package.", default = realitykit_sources_digest, type = "string", readonly = true})

    on_load("iphoneos", function (package)
        local toolchain = assert(package:toolchains(), "realitykit is built with the apple-ios toolchain")[1]
        toolchain:load()
        if tonumber(toolchain:config("deployment"):match("^(%d+)")) < 8 then
            raise("realitykit is not yet backported to iOS below 8, and this build targets iOS %s: its SceneKit and UIKit parts are open, see the open gaps in frameworks/Backports/README.md", toolchain:config("deployment"))
        end
        package:add("deps", "revenant@swift-runtime", {alias = "swift-runtime"})
        package:add("deps", "revenant@realityfoundation", {alias = "realityfoundation"})
        package:add("links", "swiftRealityKit")
        package:add("frameworks", "Foundation", "CoreFoundation", "QuartzCore", "SceneKit", "UIKit")
    end)

    on_install("iphoneos", function (package)
        local root = path.translate(path.join(package:scriptdir(), "..", "..", ".."))
        import("@addon.revenant.apple.wrapper", {anonymous = true}).install(package, {root = root,
            includes = {path.join(root, "frameworks", "Backports", "src", "Swift")}, targets = {"swiftRealityKit"}, modules = true})
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libswiftRealityKit.dylib")))
        assert(os.isdir(path.join(package:installdir("lib"), "swift", "iphoneos", "RealityKit.swiftmodule")))
    end)
