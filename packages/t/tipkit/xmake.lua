package("tipkit")
    set_homepage("https://github.com/kern0x1b/revenant/tree/main/frameworks/Backports")
    set_description("The TipKit framework, as one Swift module a port writes `import TipKit` for, built against the revenant@swift-runtime a port carries")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)
    add_configs("apple_sdk", {description = "The iPhoneOS SDK the generated project names: the one the consumer installed, so the package is not built against a second SDK.", default = "26.2", type = "string"})

    includes(path.join(os.scriptdir(), "port", "digest.lua"))
    add_configs("sources", {description = "The digest of this recipe and the module's sources, so a changed declaration is a different package.", default = tipkit_sources_digest, type = "string", readonly = true})

    on_load("iphoneos", function (package)
        package:add("deps", "revenant@swift-runtime", {alias = "swift-runtime"})
        package:add("deps", "revenant@appintents", {alias = "appintents"})
        package:add("links", "TipKit")
        package:add("frameworks", "Foundation", "CoreFoundation")
    end)

    on_install("iphoneos", function (package)
        local root = path.translate(path.join(package:scriptdir(), "..", "..", ".."))
        import("@addon.revenant.apple.wrapper", {anonymous = true}).install(package, {root = root,
            includes = {path.join(root, "frameworks", "Backports", "src", "Swift")}, targets = {"TipKit"}, modules = true})
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libTipKit.a")))
        assert(os.isdir(path.join(package:installdir("lib"), "swift", "iphoneos", "TipKit.swiftmodule")))
    end)
