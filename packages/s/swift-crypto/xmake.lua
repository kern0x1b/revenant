package("swift-crypto")
    set_homepage("https://github.com/apple/swift-crypto")
    set_description("swift-crypto 5.0.1, Apple's Crypto module (the CryptoKit API on BoringSSL, as upstream ships it for a platform without CryptoKit): the release sources pinned by sha256, patched for the port, built for armv7 iOS 6.0 in Lua the way swift-system is. Apache-2.0 upstream")
    set_license("Apache-2.0")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/apple/swift-crypto/archive/refs/tags/$(version).tar.gz")
    add_versions("5.0.1", "3df66e7942a2ed67ef472e9a8a6a1356a80156c4e21406b2b3b1ca5183956378")
    add_resources("5.0.1", "swift-asn1", "https://github.com/apple/swift-asn1/archive/refs/tags/1.7.3.tar.gz",
                  "77add3684fd75a586529893288af51ed092c565ec0c154d2b4eedb3a6bdc294c")

    add_configs("shared", {description = "Compile and link against a shared swift-runtime, whose libraries the result binds by their absolute install names. The package is not yet one of a Debian package: its own install names stay @rpath and it writes no shared-packages description.", default = false, type = "boolean"})
    includes(path.join(os.scriptdir(), "port", "digest.lua"))
    add_configs("sources", {description = "The digest of this recipe, its patches and the apple-compat calls it builds, so a changed step is a different package.",
                            default = swift_crypto_sources_digest, type = "string", readonly = true})

    add_configs("evolution", {description = "arm64 only: compile the Crypto sources as the module CryptoKit with library evolution and install libswiftCryptoKit.dylib instead of libswiftCrypto.dylib, so the symbols of the CryptoKit that a program compiled by the SDK's Swift binds to resolve (its mangled names carry the module name, and its protocol requirements and enums are resilient). CryptoExtras are not built.", default = false, type = "boolean"})

    local FLOOR = "6.0"

    on_load("iphoneos", function (package)
        assert(not package:config("evolution") or package:is_arch("arm64"), "swift-crypto with evolution is an arm64 guest build")
        package:add("deps", "revenant@swift-runtime", {alias = "swift-runtime", configs = {shared = package:config("shared") or nil,
                                                                                         library_evolution = package:config("evolution") or nil}})
        package:add("deps", "revenant@apple-compat", {alias = "apple-compat"})
        package:add("deps", "revenant@ld64", {alias = "ld64"})
        package:add("links", package:config("evolution") and "swiftCryptoKit" or "swiftCrypto")
        package:add("linkdirs", "lib")
    end)

    on_install("iphoneos", function (package)
        local swift = import("@addon.revenant.apple.swift", {anonymous = true})
        local toolchain = assert(package:toolchains(), "swift-crypto is built with the apple-ios toolchain")[1]
        toolchain:load()
        local runtime = assert(package:dep("swift-runtime"), "swift-crypto is compiled against revenant@swift-runtime")
        local compat = package:dep("apple-compat")
        local swiftc = assert(table.wrap((runtime:envs() or {}).SWIFT_EXEC)[1], "swift-runtime names no compiler; reinstall it")
        local evolution = package:config("evolution")
        local minimum = evolution and "7.0" or FLOOR
        local triple = package:arch() .. "-apple-ios" .. minimum
        local sdk = toolchain:config("sdkdir")
        local resources = path.join(runtime:installdir(), "lib", "swift")
        local tree = package:installdir("src")
        local objects = package:installdir("objects", "swift-crypto")
        os.mkdir(objects)
        io.writefile(path.join(package:installdir("objects"), "sdkdir"), sdk)
        local shims = path.join(objects, "shims", "RevenantCompat")
        os.mkdir(shims)
        local headers = {}
        for _, file in ipairs(os.files(path.join(compat:installdir("include"), "revenant", "*.h"))) do
            table.insert(headers, "#include <revenant/" .. path.filename(file) .. ">")
        end
        if not os.isfile(path.join(compat:installdir("include"), "revenant", "memset_s.h")) then
            table.insert(headers, "#include <stddef.h>")
            table.insert(headers, "int revenant_memset_s(void *bytes, size_t capacity, int value, size_t count);")
        end
        table.sort(headers)
        io.writefile(path.join(shims, "shims.h"), table.concat(headers, "\n") .. "\n")
        io.writefile(path.join(shims, "module.modulemap"), "module RevenantCompat {\n    header \"shims.h\"\n    export *\n}\n")

        os.cp(path.join(os.curdir(), "*"), tree)
        for _, patch in ipairs(os.files(path.join(os.scriptdir(), "patches", "*.patch"))) do
            os.vrunv("patch", {"-d", tree, "-p1", "-s", "-i", patch})
        end
        local sources = path.join(tree, "Sources")
        if evolution then
            for _, file in ipairs(os.files(path.join(sources, "Crypto", "**.swift"))) do
                local text = io.readfile(file)
                local changed = text:gsub("canImport%(CryptoKit%)", "canImport(RevenantSystemCryptoKit)")
                changed = changed:gsub("%f[%w_]Crypto%.", "CryptoKit.")
                local name = path.filename(file)
                if name == "X25519Keys_boring.swift" or name == "Ed25519_boring.swift" or name == "NISTCurvesKeys_boring.swift" then
                    changed = changed:gsub("@inlinable(%s+)init", "@usableFromInline%1init")
                end
                if changed ~= text then
                    io.writefile(file, changed)
                end
            end
        end
        local common ={"-target", triple, "-isysroot", sdk, "-miphoneos-version-min=" .. minimum}

        local bssl = path.join(sources, "CCryptoBoringSSL")
        for _, file in ipairs(os.files(path.join(bssl, "**.cc"))) do
            local rel = path.relative(file, bssl)
            if not rel:find("crypto/bio/connect.cc", 1, true) and not rel:find("crypto/bio/socket", 1, true) then
                os.vrunv(toolchain:tool("cxx"), table.join(common, {"-std=c++17", "-fno-exceptions", "-fno-rtti", "-Os",
                         "-Wno-shorten-64-to-32", "-I", path.join(bssl, "include"), "-I", bssl, "-c", file,
                         "-o", path.join(objects, "bssl_" .. rel:gsub("/", "_") .. ".o")}))
            end
        end
        if package:is_arch("arm64") then
            for _, file in ipairs(os.files(path.join(bssl, "gen", "**-apple.S"))) do
                os.vrunv(toolchain:tool("cc"), table.join(common, {"-Os", "-I", path.join(bssl, "include"), "-I", bssl, "-c", file,
                         "-o", path.join(objects, "bsslasm_" .. path.relative(file, bssl):gsub("/", "_") .. ".o")}))
            end
        end
        local kcp = path.join(sources, "CXKCP")
        local kcpflags = {"-DXKCP_has_KeccakP1600", "-Wno-macro-redefined", "-Os"}
        for _, dir in ipairs({"include", "high", "low", "low/KeccakP-1600", "low/common", "common"}) do
            table.join2(kcpflags, {"-I", path.join(kcp, dir)})
        end
        table.join2(kcpflags, {"-I", path.join(sources, "CXKCPShims", "include")})
        for _, file in ipairs(table.join(os.files(path.join(kcp, "**.c")), os.files(path.join(sources, "CXKCPShims", "*.c")))) do
            os.vrunv(toolchain:tool("cc"), table.join(common, kcpflags, {"-c", file, "-o", path.join(objects, "kcp_" .. path.filename(file) .. ".o")}))
        end
        os.vrunv(toolchain:tool("cc"), table.join(common, {"-Os", "-Wall", "-fvisibility=hidden",
                 "-I", path.join(compat:installdir("include")), "-c", import("@addon.revenant.data", {anonymous = true}).src("apple-compat", "src", "memset_s.c"),
                 "-o", path.join(objects, "memset_s.o")}))
        os.vrunv(toolchain:tool("cc"), table.join(common, {"-Os", "-Wall", "-fvisibility=hidden", "-c",
                 import("@addon.revenant.data", {anonymous = true}).src("apple-compat", "src", "objc_opt_self.c"),
                 "-o", path.join(objects, "objc_opt_self.o")}))
        os.vrunv(toolchain:tool("cc"), table.join(common, {"-Os", "-Wall", "-fvisibility=hidden", "-c",
                 import("@addon.revenant.data", {anonymous = true}).src("apple-compat", "src", "objc_allocWithZone.c"),
                 "-o", path.join(objects, "objc_allocWithZone.o")}))

        if evolution then
            local markers = path.join(objects, "autolink_markers.c")
            io.writefile(markers, table.concat({
                "__attribute__((visibility(\"hidden\"))) const char _swift_FORCE_LOAD_$_swiftXPC = 0;",
                "__attribute__((visibility(\"hidden\"))) const char _swift_FORCE_LOAD_$_swift_Builtin_float = 0;",
                ""}, "\n"))
            os.vrunv(toolchain:tool("cc"), table.join(common, {"-Os", "-c", markers, "-o", path.join(objects, "autolink_markers.o")}))
        end

        local main = evolution and "CryptoKit" or "Crypto"
        local overlays = evolution and {"-I", path.join(resources, "iphoneos")} or {}
        local swiftflags = {"-enable-experimental-feature", "Lifetimes", "-enable-experimental-feature", "SourceWarningControl",
                            "-enable-upcoming-feature", "MemberImportVisibility", "-D", "CRYPTO_IN_SWIFTPM", "-swift-version", "6",
                            "-package-name", "swift-crypto", "-parse-as-library", "-O", "-wmo", "-c",
                            "-I", path.join(bssl, "include"), "-I", path.join(kcp, "include"),
                            "-I", path.join(sources, "CXKCPShims", "include"), "-I", path.join(objects, "shims"), "-I", compat:installdir("include"),
                            "-module-cache-path", path.join(objects, "modulecache")}
        table.join2(swiftflags, overlays)
        local swiftmods = path.join(objects, "swiftmodules")
        os.mkdir(swiftmods)
        local function swiftmodule_path(name)
            os.mkdir(path.join(swiftmods, name .. ".swiftmodule"))
            return path.join(swiftmods, name .. ".swiftmodule", package:arch() .. "-apple-ios.swiftmodule")
        end
        local swiftargv = swift.runtime_flags({architecture = package:arch(), deployment = minimum, sdk = sdk, resources = resources,
                                               module = "CryptoBoringWrapper"})
        table.join2(swiftargv, swiftflags)
        local wrapper = {}
        for _, file in ipairs(os.files(path.join(sources, "CryptoBoringWrapper", "**.swift"))) do
            table.insert(wrapper, file)
        end
        table.sort(wrapper)
        table.join2(swiftargv, {"-module-name", "CryptoBoringWrapper", "-I", swiftmods, "-emit-module", "-emit-module-path",
                                swiftmodule_path("CryptoBoringWrapper")}, wrapper, {"-o", path.join(objects, "CryptoBoringWrapper.o")})
        os.vrunv(swiftc, swiftargv)

        local crypto = {}
        for _, file in ipairs(os.files(path.join(sources, "Crypto", "**.swift"))) do
            table.insert(crypto, file)
        end
        table.sort(crypto)
        local cargv = swift.runtime_flags({architecture = package:arch(), deployment = minimum, sdk = sdk, resources = resources,
                                           module = main})
        table.join2(cargv, swiftflags, evolution and {"-enable-library-evolution"} or {})
        table.join2(cargv, {"-module-name", main, "-I", swiftmods, "-emit-module", "-emit-module-path",
                            swiftmodule_path(main)}, crypto, {"-o", path.join(objects, main .. ".o")})
        os.vrunv(swiftc, cargv)

        local asn1 =assert(os.dirs(path.join(package:resourcedir("swift-asn1"), "swift-asn1-*"))[1], "swift-asn1 is not fetched")
        local asn1tree = package:installdir("swift-asn1")
        os.cp(path.join(asn1, "*"), asn1tree)
        for _, patch in ipairs(os.files(path.join(package:scriptdir(), "patches", "swift-asn1", "*.patch"))) do
            os.vrunv("patch", {"-d", asn1tree, "-p1", "-s", "-i", patch})
        end
        local function swiftfiles(dir)
            local files = {}
            for _, file in ipairs(os.files(path.join(dir, "**.swift"))) do
                table.insert(files, file)
            end
            table.sort(files)
            return files
        end
        local asn1flags = {"-enable-upcoming-feature", "MemberImportVisibility", "-enable-upcoming-feature", "ExistentialAny",
                           "-package-name", "swift-asn1", "-swift-version", "6", "-O", "-module-cache-path", path.join(objects, "modulecache")}
        table.join2(asn1flags, overlays)
        local asn1argv = swift.runtime_flags({architecture = package:arch(), deployment = minimum, sdk = sdk, resources = resources,
                                              module = "SwiftASN1"})
        table.join2(asn1argv, asn1flags, {"-c", "-module-name", "SwiftASN1", "-emit-module", "-emit-module-path",
                    swiftmodule_path("SwiftASN1")}, swiftfiles(path.join(asn1tree, "Sources", "SwiftASN1")),
                    {"-o", path.join(swiftmods, "SwiftASN1.raw.o")})
        os.vrunv(swiftc, asn1argv)
        local ld64 = path.join(package:dep("ld64"):installdir("bin"), "ld")
        local hidden = path.join(swiftmods, "SwiftASN1.hidden")
        io.writefile(hidden, "*SwiftASN1*\n")
        os.vrunv(ld64, {"-r", "-keep_private_externs", "-unexported_symbols_list", hidden,
                        "-o", path.join(objects, "SwiftASN1.o"), path.join(swiftmods, "SwiftASN1.raw.o")})

        for _, module in ipairs(evolution and {} or {"CryptoExtras", "_CryptoExtras"}) do
            local argv = swift.runtime_flags({architecture = package:arch(), deployment = minimum, sdk = sdk, resources = resources,
                                              module = module})
            table.join2(argv, swiftflags)
            table.join2(argv, {"-module-name", module, "-I", swiftmods, "-emit-module", "-emit-module-path",
                               swiftmodule_path(module)},
                        swiftfiles(path.join(sources, module)), {"-o", path.join(objects, module .. ".o")})
            os.vrunv(swiftc, argv)
        end

        local libdir = path.join(resources, "iphoneos")
        if package:config("shared") then
            local shared = import("@addon.revenant.apple.shared_runtime", {anonymous = true})
            libdir = path.join(runtime:installdir("share"), "root", shared.folder_of(shared.package_name("swift-runtime", runtime:buildhash())))
        end
        local lib = path.join(objects, "libswift" .. main .. ".dylib")
        os.vrunv(toolchain:tool("cc"), table.join(common, {"-fuse-ld=" .. ld64, "-dynamiclib", "-install_name", "@rpath/libswift" .. main .. ".dylib",
                 "-Wl,-dead_strip_dylibs", "-o", lib}, os.files(path.join(objects, "*.o")),
                 {"-L", libdir,
                  "-lswiftCore", "-lswiftDarwin", "-lswiftObjectiveC", "-lswiftDispatch", "-lswift_Concurrency",
                  "-lswiftFoundation", "-framework", "Security"}))
        os.cp(lib, package:installdir("lib"))
        local module = path.join(package:installdir("lib"), "swift", "iphoneos")
        os.mkdir(module)
        os.cp(path.join(swiftmods, main .. ".swiftmodule"), path.join(module, main .. ".swiftmodule"))
        os.cp(path.join(swiftmods, "CryptoBoringWrapper.swiftmodule"), path.join(module, "CryptoBoringWrapper.swiftmodule"))
        for _, name in ipairs(evolution and {} or {"CryptoExtras", "_CryptoExtras"}) do
            os.cp(path.join(swiftmods, name .. ".swiftmodule"), path.join(module, name .. ".swiftmodule"))
        end
        os.cp(path.join(objects, main .. ".o"), path.join(package:installdir("lib"), main .. ".o"))
        package:setenv("REVENANT_SWIFT_MODULES", module, path.join(compat:installdir("include"), "RevenantCompat"), compat:installdir("include"))

        print("%s: %s installed; libswift%s.dylib is in %s", package:name(), package:version_str(), main, package:installdir("lib"))
    end)
