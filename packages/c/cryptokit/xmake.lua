package("cryptokit")
    set_homepage("https://github.com/kern0x1b/revenant/tree/main/frameworks/Backports")
    set_description("The CryptoKit module of the iOS 26.2 SDK as one Swift module and dylib a port writes `import CryptoKit` for: swift-crypto's Crypto module re-exported, with the nested names the SDK declares and swift-crypto does not, built against the revenant@swift-runtime and revenant@swift-crypto a port carries. Secure Enclave types are not covered: the device class has no Secure Enclave")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)
    add_configs("apple_sdk", {description = "The iPhoneOS SDK the generated project names: the one the consumer installed, so the package is not built against a second SDK.", type = "string"})

    add_configs("shared", {description = "Compile and link against a shared swift-runtime, whose libraries the result binds by their absolute install names. The package is not yet one of a Debian package: its own install names stay @rpath and it writes no shared-packages description.", default = false, type = "boolean"})
    includes(path.join(os.scriptdir(), "port", "digest.lua"))
    add_configs("sources", {description = "The digest of this recipe and the module's sources, so a changed declaration is a different package.", default = cryptokit_sources_digest, type = "string", readonly = true})

    on_load("iphoneos", function (package)
        package:add("deps", "revenant@swift-runtime", {alias = "swift-runtime", configs = {shared = package:config("shared") or nil}})
        package:add("deps", "revenant@swift-crypto", {alias = "swift-crypto", configs = {shared = package:config("shared") or nil}})
        package:add("links", "swiftCryptoKit")
    end)

    on_install("iphoneos", function (package)
        local root = path.translate(path.join(package:scriptdir(), "..", "..", ".."))
        local modules = path.absolute(path.join(package:name(), "modulecache"))
        local extra = path.absolute(path.join(package:name(), "extra"))
        os.mkdir(extra)
        io.writefile(path.join(extra, "xmake.lua"), table.concat({
            "target(\"swiftCryptoKit\")",
            "    add_values(\"swift.flags\", \"-module-cache-path\", \"" .. modules .. "\")",
            "target_end()",
            ""}, "\n"))
        import("@addon.revenant.apple.wrapper", {anonymous = true}).install(package, {root = root,
            includes = {path.join(root, "frameworks", "Backports", "src", "Swift"), extra}, targets = {"swiftCryptoKit"}, modules = true})
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libswiftCryptoKit.dylib")))
        assert(os.isdir(path.join(package:installdir("lib"), "swift", "iphoneos", "CryptoKit.swiftmodule")))
    end)
