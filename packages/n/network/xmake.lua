package("network")
    set_homepage("https://github.com/kern0x1b/revenant/tree/main/frameworks/Backports")
    set_description("The Network framework of iOS 12, as one Swift module and dylib a port writes `import Network` for, built against the revenant@swift-runtime a port carries, with the Network C seam its module imports; below iOS 12 the seam's Network types are not yet backported")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)
    add_configs("apple_sdk", {description = "The iPhoneOS SDK the generated project names: the one the consumer installed, so the package is not built against a second SDK.", default = "16.4", type = "string"})

    includes(path.join(os.scriptdir(), "port", "digest.lua"))
    add_configs("sources", {description = "The digest of this recipe and the module's sources, so a changed declaration is a different package.", default = network_sources_digest, type = "string", readonly = true})

    on_load("iphoneos", function (package)
        local toolchain = assert(package:toolchains(), "network is built with the apple-ios toolchain")[1]
        toolchain:load()
        if tonumber(toolchain:config("deployment"):match("^(%d+)")) < 12 then
            raise("network is not yet backported to iOS below 12, and this build targets iOS %s: see the open gaps in frameworks/Backports/README.md", toolchain:config("deployment"))
        end
        package:add("deps", "revenant@swift-runtime", {alias = "swift-runtime"})
        package:add("links", "swiftNetwork")
    end)

    on_install("iphoneos", function (package)
        local root = path.translate(path.join(package:scriptdir(), "..", "..", ".."))
        import("@addon.revenant.apple.wrapper", {anonymous = true}).install(package, {root = root,
            includes = {path.join(root, "frameworks", "Backports", "src", "Swift")}, targets = {"swiftNetwork"}, modules = true})
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libswiftNetwork.dylib")))
        assert(os.isdir(path.join(package:installdir("lib"), "swift", "iphoneos", "Network.swiftmodule")))
    end)
