package("swift-crypto")
    set_homepage("https://github.com/apple/swift-crypto")
    set_description("swift-crypto 5.0.1, Apple's Crypto module (the CryptoKit API on BoringSSL, as upstream ships it for a platform without CryptoKit): the release sources pinned by sha256, patched for the port, built for armv7 iOS 6.1.3 in Lua the way swift-system is. Apache-2.0 upstream")
    set_license("Apache-2.0")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/apple/swift-crypto/archive/refs/tags/$(version).tar.gz")
    add_versions("5.0.1", "3df66e7942a2ed67ef472e9a8a6a1356a80156c4e21406b2b3b1ca5183956378")
    add_resources("5.0.1", "swift-asn1", "https://github.com/apple/swift-asn1/archive/refs/tags/1.7.3.tar.gz",
                  "77add3684fd75a586529893288af51ed092c565ec0c154d2b4eedb3a6bdc294c")

    local digests = {}
    local inputs = {os.scriptdir() .. "/xmake.lua"}
    for _, patch in ipairs(os.files(os.scriptdir() .. "/patches/*.patch")) do
        table.insert(inputs, patch)
    end
    for _, patch in ipairs(os.files(os.scriptdir() .. "/patches/swift-asn1/*.patch")) do
        table.insert(inputs, patch)
    end
    local compat = path.join(os.scriptdir(), "..", "..", "..", "toolchain", "src", "apple-compat")
    table.insert(inputs, path.join(compat, "src", "memset_s.c"))
    table.insert(inputs, path.join(compat, "src", "objc_opt_self.c"))
    table.insert(inputs, path.join(compat, "src", "objc_allocWithZone.c"))
    for _, file in ipairs(os.files(path.join(compat, "include", "revenant", "*.h"))) do
        table.insert(inputs, file)
    end
    table.sort(inputs)
    for _, file in ipairs(inputs) do
        table.insert(digests, path.filename(file) .. "=" .. hash.sha256(file))
    end
    add_configs("sources", {description = "The digest of this recipe, its patches and the apple-compat calls it builds, so a changed step is a different package.",
                            default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    on_load("iphoneos", function (package)
        package:add("deps", "revenant@swift-runtime", {alias = "swift-runtime", configs = {backports = true}})
        package:add("deps", "revenant@apple-compat", {alias = "apple-compat"})
        package:add("deps", "revenant@ld64", {alias = "ld64"})
        package:add("links", "swiftCrypto")
        package:add("linkdirs", "lib")
    end)

    on_install("iphoneos", function (package)
        local modules = path.join(package:scriptdir(), "..", "..", "..", "toolchain", "modules")
        local swift = import("apple.swift", {rootdir = modules, anonymous = true})
        local toolchain = assert(package:toolchains(), "swift-crypto is built with the apple-ios toolchain")[1]
        toolchain:load()
        local runtime = assert(package:dep("swift-runtime"), "swift-crypto is compiled against revenant@swift-runtime")
        local compat = package:dep("apple-compat")
        raise("swift-crypto links the CommonCrypto Backports library, which is a project target a package cannot depend on yet; see docs/explanation/backports-loading.md")
        local swiftc = assert(table.wrap((runtime:envs() or {}).SWIFT_EXEC)[1], "swift-runtime names no compiler; reinstall it")
        local minimum = toolchain:config("deployment")
        local triple = package:arch() .. "-apple-ios" .. minimum
        local sdk = toolchain:config("sdkdir")
        local resources = path.join(runtime:installdir(), "lib", "swift")
        local tree = package:installdir("src")
        local objects = package:installdir("objects", "swift-crypto")
        os.mkdir(objects)
        io.writefile(path.join(package:installdir("objects"), "sdkdir"), sdk)

        os.cp(path.join(os.curdir(), "*"), tree)
        for _, patch in ipairs(os.files(path.join(os.scriptdir(), "patches", "*.patch"))) do
            os.vrunv("patch", {"-d", tree, "-p1", "-s", "-i", patch})
        end
        local sources = path.join(tree, "Sources")
        local common = {"-target", triple, "-isysroot", sdk, "-miphoneos-version-min=" .. minimum}

        local bssl = path.join(sources, "CCryptoBoringSSL")
        for _, file in ipairs(os.files(path.join(bssl, "**.cc"))) do
            local rel = path.relative(file, bssl)
            if not rel:find("crypto/bio/connect.cc", 1, true) and not rel:find("crypto/bio/socket", 1, true) then
                os.vrunv(toolchain:tool("cxx"), table.join(common, {"-std=c++17", "-fno-exceptions", "-fno-rtti", "-Os",
                         "-Wno-shorten-64-to-32", "-I", path.join(bssl, "include"), "-I", bssl, "-c", file,
                         "-o", path.join(objects, "bssl_" .. rel:gsub("/", "_") .. ".o")}))
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
                 "-I", path.join(compat:installdir("include")), "-c", path.join(package:scriptdir(), "..", "..", "..", "toolchain", "src", "apple-compat", "src", "memset_s.c"),
                 "-o", path.join(objects, "memset_s.o")}))
        os.vrunv(toolchain:tool("cc"), table.join(common, {"-Os", "-Wall", "-fvisibility=hidden", "-c",
                 path.join(package:scriptdir(), "..", "..", "..", "toolchain", "src", "apple-compat", "src", "objc_opt_self.c"),
                 "-o", path.join(objects, "objc_opt_self.o")}))
        os.vrunv(toolchain:tool("cc"), table.join(common, {"-Os", "-Wall", "-fvisibility=hidden", "-c",
                 path.join(package:scriptdir(), "..", "..", "..", "toolchain", "src", "apple-compat", "src", "objc_allocWithZone.c"),
                 "-o", path.join(objects, "objc_allocWithZone.o")}))

        local port_headers = table.wrap((runtime:envs() or {}).REVENANT_SWIFT_PORT_HEADERS)
        local overlay = #port_headers > 0 and {"-vfsoverlay", table.concat(port_headers, path.envsep())} or {}

        local swiftflags = {"-enable-experimental-feature", "Lifetimes", "-enable-experimental-feature", "SourceWarningControl",
                            "-enable-upcoming-feature", "MemberImportVisibility", "-D", "CRYPTO_IN_SWIFTPM", "-swift-version", "6",
                            "-package-name", "swift-crypto", "-parse-as-library", "-Onone", "-wmo", "-c",
                            "-I", path.join(bssl, "include"), "-I", path.join(kcp, "include"),
                            "-I", path.join(sources, "CXKCPShims", "include"), "-I", compat:installdir("include")}
        table.join2(swiftflags, overlay)
        local swiftmods = path.join(objects, "swiftmodules")
        os.mkdir(swiftmods)
        local swiftargv = swift.runtime_flags({architecture = package:arch(), deployment = minimum, sdk = sdk, resources = resources,
                                               module = "CryptoBoringWrapper"})
        table.join2(swiftargv, swiftflags)
        local wrapper = {}
        for _, file in ipairs(os.files(path.join(sources, "CryptoBoringWrapper", "**.swift"))) do
            table.insert(wrapper, file)
        end
        table.sort(wrapper)
        table.join2(swiftargv, {"-module-name", "CryptoBoringWrapper", "-I", swiftmods, "-emit-module", "-emit-module-path",
                                path.join(swiftmods, "CryptoBoringWrapper.swiftmodule")}, wrapper, {"-o", path.join(objects, "CryptoBoringWrapper.o")})
        os.vrunv(swiftc, swiftargv)

        local crypto = {}
        for _, file in ipairs(os.files(path.join(sources, "Crypto", "**.swift"))) do
            table.insert(crypto, file)
        end
        table.sort(crypto)
        local cargv = swift.runtime_flags({architecture = package:arch(), deployment = minimum, sdk = sdk, resources = resources,
                                           module = "Crypto"})
        table.join2(cargv, swiftflags)
        table.join2(cargv, {"-module-name", "Crypto", "-I", swiftmods, "-emit-module", "-emit-module-path",
                            path.join(swiftmods, "Crypto.swiftmodule")}, crypto, {"-o", path.join(objects, "Crypto.o")})
        os.vrunv(swiftc, cargv)

        local asn1 = assert(os.dirs(path.join(package:resourcedir("swift-asn1"), "swift-asn1-*"))[1], "swift-asn1 is not fetched")
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
                           "-package-name", "swift-asn1", "-swift-version", "6"}
        table.join2(asn1flags, overlay)
        local asn1argv = swift.runtime_flags({architecture = package:arch(), deployment = minimum, sdk = sdk, resources = resources,
                                              module = "SwiftASN1"})
        table.join2(asn1argv, asn1flags, {"-c", "-module-name", "SwiftASN1", "-emit-module", "-emit-module-path",
                    path.join(swiftmods, "SwiftASN1.swiftmodule")}, swiftfiles(path.join(asn1tree, "Sources", "SwiftASN1")),
                    {"-o", path.join(swiftmods, "SwiftASN1.raw.o")})
        os.vrunv(swiftc, asn1argv)
        local ld64 = path.join(package:dep("ld64"):installdir("bin"), "ld")
        local hidden = path.join(swiftmods, "SwiftASN1.hidden")
        io.writefile(hidden, "*SwiftASN1*\n")
        os.vrunv(ld64, {"-r", "-keep_private_externs", "-unexported_symbols_list", hidden,
                        "-o", path.join(objects, "SwiftASN1.o"), path.join(swiftmods, "SwiftASN1.raw.o")})

        for _, module in ipairs({"CryptoExtras", "_CryptoExtras"}) do
            local argv = swift.runtime_flags({architecture = package:arch(), deployment = minimum, sdk = sdk, resources = resources,
                                              module = module})
            table.join2(argv, swiftflags)
            table.join2(argv, {"-module-name", module, "-I", swiftmods, "-emit-module", "-emit-module-path",
                               path.join(swiftmods, module .. ".swiftmodule")},
                        swiftfiles(path.join(sources, module)), {"-o", path.join(objects, module .. ".o")})
            os.vrunv(swiftc, argv)
        end

        local lib = path.join(objects, "libswiftCrypto.dylib")
        os.vrunv(toolchain:tool("cc"), table.join(common, {"-fuse-ld=" .. ld64, "-dynamiclib", "-install_name", "@rpath/libswiftCrypto.dylib",
                 "-o", lib}, os.files(path.join(objects, "*.o")),
                 {"-L", path.join(resources, "iphoneos"),
                  "-lswiftCore", "-lswiftDarwin", "-lswiftObjectiveC", "-lswiftDispatch", "-lswift_Concurrency",
                  "-lswiftFoundation", "-lFoundationBackports", "-lCommonCryptoBackports"}))
        os.cp(lib, package:installdir("lib"))
        local module = path.join(package:installdir("lib"), "swift", "iphoneos")
        os.mkdir(module)
        os.cp(path.join(swiftmods, "Crypto.swiftmodule"), path.join(module, "Crypto.swiftmodule"))
        os.cp(path.join(swiftmods, "CryptoBoringWrapper.swiftmodule"), path.join(module, "CryptoBoringWrapper.swiftmodule"))
        for _, name in ipairs({"CryptoExtras", "_CryptoExtras"}) do
            os.cp(path.join(swiftmods, name .. ".swiftmodule"), path.join(module, name .. ".swiftmodule"))
        end
        os.cp(path.join(objects, "Crypto.o"), path.join(package:installdir("lib"), "Crypto.o"))
        package:setenv("REVENANT_SWIFT_MODULES", module, path.join(compat:installdir("include"), "RevenantCompat"), compat:installdir("include"))

        print("%s: %s installed; libswiftCrypto.dylib is in %s", package:name(), package:version_str(), package:installdir("lib"))
    end)
