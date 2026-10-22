package("swift-embedded")
    set_homepage("https://www.swift.org/documentation/embedded-swift/")
    set_description("Embedded Swift's standard library for an iOS device: the Swift module for the port's architecture and oldest release, compiled from the sources of the swift package, and the Unicode tables it calls")
    set_license("Apache-2.0 WITH Swift-exception")
    set_policy("package.strict_compatibility", true)
    add_configs("apple_sdk", {description = "The iPhoneOS SDK the generated project names: the one the consumer installed, so the package is not built against a second SDK.", type = "string"})

    includes(path.join(os.scriptdir(), "port", "digest.lua"))
    add_configs("sources", {description = "The digest of this recipe, the component that builds the module and the Swift module builder, so a changed build is a different package.", default = swift_embedded_sources_digest, type = "string", readonly = true})

    add_deps("revenant@swift 6.4.0", {alias = "swift", host = true, private = true, system = false})

    on_load("iphoneos", function (package)
        package:add("links", "swiftUnicodeDataTables")
    end)

    on_install("iphoneos", function (package)
        local root = path.translate(path.join(package:scriptdir(), "..", "..", ".."))
        import("@addon.revenant.apple.wrapper", {anonymous = true}).install(package, {root = root,
            includes = {path.join(root, "toolchain", "src", "swift-embedded")}, targets = {"swiftUnicodeDataTables"}})
        package:setenv("SWIFT_EXEC", path.join(package:dep("swift"):installdir("bin"), "swiftc"))
    end)

    on_test(function (package)
        local swift = import("@addon.revenant.apple.swift", {anonymous = true})
        local module = path.join(package:installdir("lib"), "swift", "embedded", "Swift.swiftmodule", swift.module_name(package:arch()) .. ".swiftmodule")
        assert(os.isfile(module), "swift-embedded has no " .. module)
        assert(os.isfile(path.join(package:installdir("lib"), "libswiftUnicodeDataTables.a")))
        assert(os.isfile(package:envs().SWIFT_EXEC[1]), "swift-embedded names no compiler its module was built with")
    end)
