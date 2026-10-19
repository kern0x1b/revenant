package("swift-embedded")
    set_homepage("https://www.swift.org/documentation/embedded-swift/")
    set_description("Embedded Swift's standard library for an iOS device: the Swift module for the port's architecture and oldest release, compiled from the sources of the swift package, and the Unicode tables it calls")
    set_license("Apache-2.0 WITH Swift-exception")
    set_policy("package.strict_compatibility", true)

    add_deps("charon@swift 6.4.0", {alias = "swift", host = true, private = true, system = false})

    on_load("iphoneos", function (package)
        package:add("links", "swiftUnicodeDataTables")
    end)

    on_install("iphoneos", function (package)
        local modules = path.join(package:scriptdir(), "..", "..", "..", "modules")
        local swift = import("apple.swift", {rootdir = modules, anonymous = true})
        local cmake = import("apple.cmake", {rootdir = modules, anonymous = true})
        local sources = import("apple.sources", {rootdir = modules, anonymous = true})
        local toolchain = cmake.toolchain(package)
        local compiler = package:dep("swift")
        local source = path.join(compiler:installdir("share"), "swift-source")
        local swiftc = path.join(compiler:installdir("bin"), "swiftc")
        package:setenv("SWIFT_EXEC", swiftc)

        swift.build_module({
            swiftc = swiftc,
            source = source,
            architecture = package:arch(),
            deployment = toolchain:config("deployment"),
            sdk = toolchain:config("sdkdir"),
            output = path.join(package:installdir("lib"), "swift", "embedded"),
            workdir = path.absolute("module")
        })

        local tables = swift.unicode_tables(source)
        os.cp(path.join(tables.folder, "*.cpp"), "Unicode/")
        io.writefile(path.join("generated", "swift", "Runtime", "CMakeConfig.h"), swift.runtime_config(compiler:version_str()))
        os.vcp(path.join(source, "LICENSE.txt"), "LICENSE.txt")
        sources.static(package, {
            files = {"Unicode/*.cpp"},
            includedirs = table.join({path.absolute("generated")}, tables.includedirs),
            defines = tables.defines,
            cxxflags = tables.cxxflags,
            name = "swiftUnicodeDataTables",
            licenses = {"LICENSE.txt"}
        })
    end)

    on_test(function (package)
        local swift = import("apple.swift", {rootdir = path.join(package:scriptdir(), "..", "..", "..", "modules"), anonymous = true})
        local module = path.join(package:installdir("lib"), "swift", "embedded", "Swift.swiftmodule", swift.module_name(package:arch()) .. ".swiftmodule")
        assert(os.isfile(module), "swift-embedded has no " .. module)
        assert(os.isfile(path.join(package:installdir("lib"), "libswiftUnicodeDataTables.a")))
        assert(os.isfile(package:envs().SWIFT_EXEC[1]), "swift-embedded names no compiler its module was built with")
    end)
