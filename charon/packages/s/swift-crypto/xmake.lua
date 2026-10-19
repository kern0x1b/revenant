package("swift-crypto")
    set_homepage("https://github.com/apple/swift-crypto")
    set_description("swift-crypto 5.0.1, Apple's Crypto module (the CryptoKit API on BoringSSL, as upstream ships it for a platform without CryptoKit): the release sources pinned by sha256, patched for the port, built for armv7 iOS 6.1.3 in Lua the way swift-system is. Apache-2.0 upstream")
    set_license("Apache-2.0")
    set_policy("package.strict_compatibility", true)

    -- The release tarball of the tag 5.0.1 (BoringSSL 0226f30467f540a3f62ef48d453f93927da199b6, vendored), pinned by its sha256.
    add_urls("https://github.com/apple/swift-crypto/archive/refs/tags/$(version).tar.gz")
    add_versions("5.0.1", "3df66e7942a2ed67ef472e9a8a6a1356a80156c4e21406b2b3b1ca5183956378")
    -- CryptoExtras depends on SwiftASN1 from swift-asn1 (upstream's `from: "1.2.0"`); the release 1.7.3 is pinned by its sha256.
    add_resources("5.0.1", "swift-asn1", "https://github.com/apple/swift-asn1/archive/refs/tags/1.7.3.tar.gz",
                  "77add3684fd75a586529893288af51ed092c565ec0c154d2b4eedb3a6bdc294c")

    -- The identity of this recipe: a changed recipe, patch or shim is a different package. The apple-compat and apple-backports
    -- inputs it builds against are part of it.
    local digests = {}
    local inputs = {os.scriptdir() .. "/xmake.lua"}
    for _, patch in ipairs(os.files(os.scriptdir() .. "/patches/*.patch")) do
        table.insert(inputs, patch)
    end
    for _, patch in ipairs(os.files(os.scriptdir() .. "/patches/swift-asn1/*.patch")) do
        table.insert(inputs, patch)
    end
    local compat = path.join(os.scriptdir(), "..", "..", "a", "apple-compat")
    table.insert(inputs, path.join(compat, "src", "memset_s.c"))
    table.insert(inputs, path.join(compat, "src", "objc_opt_self.c"))
    table.insert(inputs, path.join(compat, "src", "objc_allocWithZone.c"))
    for _, file in ipairs(os.files(path.join(compat, "include", "charon", "*.h"))) do
        table.insert(inputs, file)
    end
    table.sort(inputs)
    for _, file in ipairs(inputs) do
        table.insert(digests, path.filename(file) .. "=" .. hash.sha256(file))
    end
    add_configs("sources", {description = "The digest of this recipe, its patches and the apple-compat calls it builds, so a changed step is a different package.",
                            default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    -- The module is compiled against the runtime a port carries, against apple-compat's headers (memset_s, CharonCompat), and
    -- it links libCommonCryptoBackports for entropy: CCRandomGenerateBytes is absent on 6.1.3 and BoringSSL's iOS source calls it.
    on_load("iphoneos", function (package)
        package:add("deps", "charon@swift-runtime", {alias = "swift-runtime", configs = {backports = true}})
        package:add("deps", "charon@apple-compat", {alias = "apple-compat"})
        package:add("deps", "charon@apple-backports", {alias = "apple-backports", configs = {commoncrypto = true}})
        package:add("deps", "charon@ld64", {alias = "ld64"})
        -- What a consumer links: the dylib, found in the package's lib folder.
        package:add("links", "swiftCrypto")
        package:add("linkdirs", "lib")
    end)

    -- Installs upstream's tree with this recipe's patches applied. BoringSSL (243 .cc, the upstream C path: no armv7 asm for
    -- Apple, OPENSSL_ASM_INCOMPATIBLE), CXKCP and CXKCPShims are compiled as objects; CryptoBoringWrapper and Crypto are compiled
    -- with -c against the runtime's resource dir (swift-version 6, the mode upstream's tools 6.2 manifest declares); the dylib
    -- is linked through charon@ld64 against the runtime and libCommonCryptoBackports.
    on_install("iphoneos", function (package)
        local modules = path.join(package:scriptdir(), "..", "..", "..", "modules")
        local swift = import("apple.swift", {rootdir = modules, anonymous = true})
        local toolchain = assert(package:toolchains(), "swift-crypto is built with the apple-ios toolchain")[1]
        toolchain:load()
        local runtime = assert(package:dep("swift-runtime"), "swift-crypto is compiled against charon@swift-runtime")
        local compat = package:dep("apple-compat")
        local backports = package:dep("apple-backports")
        local swiftc = assert(table.wrap((runtime:envs() or {}).SWIFT_EXEC)[1], "swift-runtime names no compiler; reinstall it")
        local minimum = toolchain:config("deployment")
        local triple = package:arch() .. "-apple-ios" .. minimum
        local sdk = toolchain:config("sdkdir")
        local resources = path.join(runtime:installdir(), "lib", "swift")
        local tree = package:installdir("src")
        -- The objects are kept in the install, in a folder of their own, with the SDK they were compiled against beside that
        -- folder (objects/sdkdir, the record tools/release-split.lua reads): the release check runs on this build's own objects.
        local objects = package:installdir("objects", "swift-crypto")
        os.mkdir(objects)
        io.writefile(path.join(package:installdir("objects"), "sdkdir"), sdk)

        os.cp(path.join(os.curdir(), "*"), tree)
        for _, patch in ipairs(os.files(path.join(os.scriptdir(), "patches", "*.patch"))) do
            os.vrunv("patch", {"-d", tree, "-p1", "-s", "-i", patch})
        end
        local sources = path.join(tree, "Sources")
        local common = {"-target", triple, "-isysroot", sdk, "-miphoneos-version-min=" .. minimum}

        -- BoringSSL's C++ sources: the three WASI socket files are excluded upstream (they need netdb.h, which iOS has but the
        -- manifest drops for every platform).
        local bssl = path.join(sources, "CCryptoBoringSSL")
        for _, file in ipairs(os.files(path.join(bssl, "**.cc"))) do
            local rel = path.relative(file, bssl)
            if not rel:find("crypto/bio/connect.cc", 1, true) and not rel:find("crypto/bio/socket", 1, true) then
                os.vrunv(toolchain:tool("cxx"), table.join(common, {"-std=c++17", "-fno-exceptions", "-fno-rtti", "-Os",
                         "-Wno-shorten-64-to-32", "-I", path.join(bssl, "include"), "-I", bssl, "-c", file,
                         "-o", path.join(objects, "bssl_" .. rel:gsub("/", "_") .. ".o")}))
            end
        end
        -- CXKCP's Keccak and CXKCPShims: the four target-specific include paths upstream lists, and the macro the manifest sets.
        local kcp = path.join(sources, "CXKCP")
        local kcpflags = {"-DXKCP_has_KeccakP1600", "-Wno-macro-redefined", "-Os"}
        for _, dir in ipairs({"include", "high", "low", "low/KeccakP-1600", "low/common", "common"}) do
            table.join2(kcpflags, {"-I", path.join(kcp, dir)})
        end
        table.join2(kcpflags, {"-I", path.join(sources, "CXKCPShims", "include")})
        for _, file in ipairs(table.join(os.files(path.join(kcp, "**.c")), os.files(path.join(sources, "CXKCPShims", "*.c")))) do
            os.vrunv(toolchain:tool("cc"), table.join(common, kcpflags, {"-c", file, "-o", path.join(objects, "kcp_" .. path.filename(file) .. ".o")}))
        end
        -- apple-compat's memset_s: the Crypto module zeroizes through charon_memset_s, which 6.1.3 lacks as memset_s.
        os.vrunv(toolchain:tool("cc"), table.join(common, {"-Os", "-Wall", "-fvisibility=hidden",
                 "-I", path.join(compat:installdir("include")), "-c", path.join(package:scriptdir(), "..", "..", "..", "packages", "a", "apple-compat", "src", "memset_s.c"),
                 "-o", path.join(objects, "memset_s.o")}))
        -- apple-compat's objc_opt_self: Swift emits a call to it for every class whose metadata is fixed (a bare public final
        -- class does, measured with this toolchain), and no release before iOS 11 exports it. The shim is compiled in as a
        -- hidden symbol, so the dylib binds it to itself and imports nothing it lacks.
        os.vrunv(toolchain:tool("cc"), table.join(common, {"-Os", "-Wall", "-fvisibility=hidden", "-c",
                 path.join(package:scriptdir(), "..", "..", "..", "packages", "a", "apple-compat", "src", "objc_opt_self.c"),
                 "-o", path.join(objects, "objc_opt_self.o")}))
        -- apple-compat's objc_allocWithZone, the same way: Swift calls it to allocate a class that inherits from NSObject (the
        -- NSData base64 initializer is one), and no release before iOS 7 exports it. Hidden, so the dylib binds it to itself.
        os.vrunv(toolchain:tool("cc"), table.join(common, {"-Os", "-Wall", "-fvisibility=hidden", "-c",
                 path.join(package:scriptdir(), "..", "..", "..", "packages", "a", "apple-compat", "src", "objc_allocWithZone.c"),
                 "-o", path.join(objects, "objc_allocWithZone.o")}))

        -- The runtime's port overlay (CHARON_SWIFT_PORT_HEADERS), as swift-data and createml take it: the SDK's
        -- availability lowered to the 6.1.3 floor, which is what lets the modules call Foundation's base64 API through
        -- NSData (the category apple-backports adds). Every Swift compile below takes it; without it the calls are
        -- refused, 'only available in iOS 7.0 or newer'.
        local port_headers = table.wrap((runtime:envs() or {}).CHARON_SWIFT_PORT_HEADERS)
        local overlay = #port_headers > 0 and {"-vfsoverlay", table.concat(port_headers, path.envsep())} or {}

        -- Swift: the modules' include paths for the C modules (CCryptoBoringSSL, CXKCP, CXKCPShims) and for CharonCompat.
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

        -- CryptoExtras and the SwiftASN1 it imports, built into the same dylib: the module files are exported with Crypto's,
        -- and _CryptoExtras is the re-export module a program imports. SwiftASN1 is the upstream tree of swift-asn1 (a resource,
        -- pinned above), with its patch for the 6.1.3 base64 API. The module's Swift settings are upstream's
        -- (MemberImportVisibility, ExistentialAny, swift-version 6, its own package name).
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
        -- SwiftASN1 is not API of CryptoExtras (its files import it implementation-only, so no public declaration names it, and
        -- its module is not shipped), so none of its symbols is exported: a relocatable link makes every external definition a
        -- private external, which other objects of this link still bind. The object then carries no exported symbol, and
        -- release-split reads none of them as the API of the release that carries them.
        local ld64 = path.join(package:dep("ld64"):installdir("bin"), "ld")
        local hidden = path.join(swiftmods, "SwiftASN1.hidden")
        io.writefile(hidden, "*SwiftASN1*\n")
        os.vrunv(ld64, {"-r", "-keep_private_externs", "-unexported_symbols_list", hidden,
                        "-o", path.join(objects, "SwiftASN1.o"), path.join(swiftmods, "SwiftASN1.raw.o")})

        -- CryptoExtras imports Crypto, CryptoBoringWrapper, SwiftASN1 and CCryptoBoringSSL: the flags above name their folders.
        -- _CryptoExtras is one file that re-exports CryptoExtras and Crypto.
        for _, module in ipairs({"CryptoExtras", "_CryptoExtras"}) do
            local argv = swift.runtime_flags({architecture = package:arch(), deployment = minimum, sdk = sdk, resources = resources,
                                              module = module})
            table.join2(argv, swiftflags)
            table.join2(argv, {"-module-name", module, "-I", swiftmods, "-emit-module", "-emit-module-path",
                               path.join(swiftmods, module .. ".swiftmodule")},
                        swiftfiles(path.join(sources, module)), {"-o", path.join(objects, module .. ".o")})
            os.vrunv(swiftc, argv)
        end

        -- Linked through the clang driver with charon@ld64 as its linker, as swift-system is (the host ld rejects libswiftCore's
        -- immortal refcount layout). The objects of CCryptoBoringSSL, CXKCP, memset_s, objc_opt_self and objc_allocWithZone are in the dylib; the module's imports
        -- are the runtime's libraries, Foundation, libFoundationBackports (the NSData base64 category, which 6.1.3 lacks) and
        -- libCommonCryptoBackports (entropy). The category is an Objective-C category, so it has no symbol to bind: the dylib
        -- records libFoundationBackports as a load, and the import check reads that load.
        local lib = path.join(objects, "libswiftCrypto.dylib")
        os.vrunv(toolchain:tool("cc"), table.join(common, {"-fuse-ld=" .. ld64, "-dynamiclib", "-install_name", "@rpath/libswiftCrypto.dylib",
                 "-o", lib}, os.files(path.join(objects, "*.o")),
                 {"-L", path.join(resources, "iphoneos"), "-L", path.join(backports:installdir("lib")),
                  "-lswiftCore", "-lswiftDarwin", "-lswiftObjectiveC", "-lswiftDispatch", "-lswift_Concurrency",
                  "-lswiftFoundation", "-lFoundationBackports", "-lCommonCryptoBackports"}))
        os.cp(lib, package:installdir("lib"))
        -- The module files a consumer imports: Crypto and CryptoBoringWrapper (Crypto imports it, not implementation-only), and
        -- CryptoExtras and _CryptoExtras. SwiftASN1's module is not shipped: CryptoExtras imports it implementation-only.
        local module = path.join(package:installdir("lib"), "swift", "iphoneos")
        os.mkdir(module)
        os.cp(path.join(swiftmods, "Crypto.swiftmodule"), path.join(module, "Crypto.swiftmodule"))
        os.cp(path.join(swiftmods, "CryptoBoringWrapper.swiftmodule"), path.join(module, "CryptoBoringWrapper.swiftmodule"))
        for _, name in ipairs({"CryptoExtras", "_CryptoExtras"}) do
            os.cp(path.join(swiftmods, name .. ".swiftmodule"), path.join(module, name .. ".swiftmodule"))
        end
        os.cp(path.join(objects, "Crypto.o"), path.join(package:installdir("lib"), "Crypto.o"))
        -- What a program that imports Crypto compiles against: its module folder, and apple-compat's CharonCompat module, which
        -- Crypto.swiftmodule imports (rules/swift adds the -I of every dependency's CHARON_SWIFT_MODULES). CharonCompat's
        -- shims.h includes <charon/...> headers, so apple-compat's include root is on the path as well: without it a consumer
        -- fails in the module build with 'charon/aligned_alloc.h' file not found.
        package:setenv("CHARON_SWIFT_MODULES", module, path.join(compat:installdir("include"), "CharonCompat"), compat:installdir("include"))

        print("%s: %s installed; libswiftCrypto.dylib is in %s", package:name(), package:version_str(), package:installdir("lib"))
    end)
