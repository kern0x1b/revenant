package("spatial")
    set_homepage("https://github.com/kern0x1b/revenant/tree/main/frameworks/Backports")
    set_description("The Spatial framework of iOS 18, as one Swift module and dylib a port writes `import Spatial` for, its value types generated from their templates against the swift package's sources, built against the revenant@swift-runtime a port carries")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)
    add_configs("apple_sdk", {description = "The iPhoneOS SDK the generated project names: the one the consumer installed, so the package is not built against a second SDK.", type = "string"})

    includes(path.join(os.scriptdir(), "port", "digest.lua"))
    add_configs("sources", {description = "The digest of this recipe and the module's sources, so a changed declaration is a different package.", default = spatial_sources_digest, type = "string", readonly = true})

    on_load("iphoneos", function (package)
        package:add("deps", "revenant@swift-runtime", {alias = "swift-runtime"})
        package:add("links", "swiftSpatial")
    end)

    on_install("iphoneos", function (package)
        local root = path.translate(path.join(package:scriptdir(), "..", "..", ".."))
        import("@addon.revenant.apple.wrapper", {anonymous = true}).install(package, {root = root,
            includes = {path.join(root, "frameworks", "Backports", "src", "Swift")}, targets = {"swiftSpatial"}, modules = true})
    end)

    on_test(function (package)
        local library = path.join(package:installdir("lib"), "libswiftSpatial.dylib")
        assert(os.isfile(library))
        assert(os.isdir(path.join(package:installdir("lib"), "swift", "iphoneos", "Spatial.swiftmodule")))
        local idle = {}
        for _, name in ipairs(import("@addon.revenant.apple.shared_runtime", {anonymous = true}).unbound_dependencies(library, package:arch())) do
            if name:startswith("libswift") then
                table.insert(idle, name)
            end
        end
        assert(#idle == 0, "libswiftSpatial.dylib names " .. table.concat(idle, ", ") .. ", which none of its symbols is bound to")
    end)
