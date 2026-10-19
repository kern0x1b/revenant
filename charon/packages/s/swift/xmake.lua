package("swift")
    set_kind("toolchain")
    set_homepage("https://www.swift.org")
    set_description("The Swift compiler of a release, built from its sources with the changes an iOS older than the compiler's own minimum needs: the frontend takes a Swift runtime the program carries, and the driver stops refusing those releases")
    set_license("Apache-2.0 WITH Swift-exception")

    -- The tag of the release; every repository it is built from is cloned by the download below, each at its own pin.
    add_urls("https://github.com/swiftlang/swift.git")
    add_versions("6.4.0", "b8189d766d86ad7fc8106787d6ce9e402f38dd72")

    add_deps("charon@swift-bootstrap 6.4.0", {host = true, private = true, system = false})
    add_deps("cmake", "ninja", {kind = "binary", host = true})

    -- Every repository the compiler is built from, at the tag of the release, with the commit that tag names when this
    -- package was written: a tag that moved is not the release it names.
    local sources = {
        ["6.4.0"] = {
            {name = "swift", url = "https://github.com/swiftlang/swift.git", tag = "swift-6.4.0-RELEASE",
             commit = "b8189d766d86ad7fc8106787d6ce9e402f38dd72"},
            {name = "llvm-project", url = "https://github.com/swiftlang/llvm-project.git", tag = "swift-6.4.0-RELEASE",
             commit = "903b9faaae5c43ecc9b7e33f8db9c94c7429374a"},
            {name = "cmark", url = "https://github.com/swiftlang/swift-cmark.git", tag = "swift-6.4.0-RELEASE",
             commit = "924936d0427cb25a61169739a7660230bffa6ea6"},
            {name = "swift-syntax", url = "https://github.com/swiftlang/swift-syntax.git", tag = "swift-6.4.0-RELEASE",
             commit = "050f1a346fbbac0ca2cfb15a95274f7bd1cf0ccf"},
            {name = "swift-experimental-string-processing", url = "https://github.com/swiftlang/swift-experimental-string-processing.git",
             tag = "swift-6.4.0-RELEASE", commit = "bf9cd9a0cfb0481f0825509aeb81ff3135bac250"},
            {name = "swift-driver", url = "https://github.com/swiftlang/swift-driver.git", tag = "swift-6.4.0-RELEASE",
             commit = "174567a5681a9a949bcd52f821deb8fa65105434"},
            {name = "llbuild", url = "https://github.com/swiftlang/swift-llbuild.git", tag = "swift-6.4.0-RELEASE",
             commit = "ab6421207b9e4971c94e97c5832a3d8a4cae9092"},
            {name = "swift-tools-support-core", url = "https://github.com/swiftlang/swift-tools-support-core.git",
             tag = "swift-6.4.0-RELEASE", commit = "d45c8b38d2824498b7863d3d5f0227937a53c177"},
            {name = "swift-argument-parser", url = "https://github.com/apple/swift-argument-parser.git", tag = "1.6.2",
             commit = "cdd0ef3755280949551dc26dee5de9ddeda89f54"},
            {name = "swift-toolchain-sqlite", url = "https://github.com/swiftlang/swift-toolchain-sqlite.git", tag = "1.0.7",
             commit = "b45b80b943e88db3cb8ddea798fa3fa9912375ff"}
        }
    }

    -- The compiler runs on this machine, so it is built for the macOS the Swift build itself targets.
    local host_deployment = "13.0"

    local digests = {"xmake.lua=" .. hash.sha256(path.join(os.scriptdir(), "xmake.lua"))}
    for _, patch in ipairs(os.files(path.join(os.scriptdir(), "patches", "*.patch"))) do
        table.insert(digests, path.filename(patch) .. "=" .. hash.sha256(patch))
    end
    table.sort(digests)
    add_configs("recipe", {description = "The digest of this recipe and the changes it makes to the compiler's sources, so a changed flag or patch is a different compiler.", default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    on_download(function (package, opt)
        local checkout = import("checkout", {rootdir = path.join(package:scriptdir(), "..", "..", "..", "modules"), anonymous = true})
        checkout.pinned(opt.sourcedir, assert(sources[package:version_str()],
                        "this package knows no sources for Swift " .. package:version_str()))
    end)

    on_install("@macosx", function (package)
        local swift = import("apple.swift", {rootdir = path.join(package:scriptdir(), "..", "..", "..", "modules"), anonymous = true})
        local bootstrap = assert(package:dep("swift-bootstrap"), "charon@swift is built with the swift.org toolchain of the same release")
        local build = path.absolute("build")
        local prefix = package:installdir()
        local jobs = math.min(import("core.base.option").get("jobs") or 8, 8)

        for _, source in ipairs(assert(sources[package:version_str()], "this package knows no sources for Swift " .. package:version_str())) do
            if not os.isdir(source.name) then
                raise("%s is not beside this build (%s holds %s); the sources of the release did not arrive whole",
                      source.name, os.curdir(), table.concat(os.dirs("*"), " "))
            end
        end
        for _, patch in ipairs({{"swift", "a-runtime-the-program-brings-with-it.patch"},
                                {"swift-driver", "no-minimum-ios-for-a-bundled-runtime.patch"}}) do
            os.vrunv("git", {"-C", patch[1], "apply", path.join(package:scriptdir(), "patches", patch[2])})
        end

        local sdk = os.iorunv("xcrun", {"--sdk", "macosx", "--show-sdk-path"}):trim()
        local common = {"-G", "Ninja", "-DCMAKE_BUILD_TYPE=Release", "-DCMAKE_C_COMPILER=/usr/bin/clang",
                        "-DCMAKE_CXX_COMPILER=/usr/bin/clang++", "-DCMAKE_OSX_SYSROOT=" .. sdk,
                        "-DCMAKE_OSX_ARCHITECTURES=" .. os.arch(), "-DCMAKE_OSX_DEPLOYMENT_TARGET=" .. host_deployment}

        os.vrunv("cmake", table.join({"-S", "cmark", "-B", path.join(build, "cmark")}, common,
                                     {"-DCMARK_THREADING=ON", "-DBUILD_TESTING=OFF"}))
        os.vrunv("ninja", {"-C", path.join(build, "cmark"), "-j" .. jobs})

        -- clang's own tools are built because Swift's CMake makes libSwiftScan depend on the clang driver; the rest of
        -- LLVM's tools, its tests and everything it can link against optionally are left out.
        os.vrunv("cmake", table.join({"-S", path.join("llvm-project", "llvm"), "-B", path.join(build, "llvm")}, common, {
            "-DLLVM_ENABLE_ASSERTIONS=OFF", "-DLLVM_TARGETS_TO_BUILD=AArch64;ARM", "-DLLVM_ENABLE_PROJECTS=clang",
            "-DLLVM_ENABLE_RUNTIMES=", "-DLLVM_TOOL_SWIFT_BUILD=FALSE", "-DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=OFF",
            "-DLLVM_BUILD_TOOLS=OFF", "-DCLANG_BUILD_TOOLS=ON", "-DLLVM_INCLUDE_TESTS=OFF", "-DCLANG_INCLUDE_TESTS=OFF",
            "-DLLVM_INCLUDE_BENCHMARKS=OFF", "-DLLVM_INCLUDE_EXAMPLES=OFF", "-DLLVM_INCLUDE_DOCS=OFF", "-DCLANG_INCLUDE_DOCS=OFF",
            "-DLLVM_ENABLE_ZLIB=ON", "-DLLVM_ENABLE_ZSTD=OFF", "-DLLVM_ENABLE_LIBXML2=OFF", "-DLLVM_ENABLE_LIBEDIT=OFF",
            "-DLLVM_ENABLE_LIBPFM=OFF", "-DLLVM_ENABLE_Z3_SOLVER=OFF", "-DLLVM_ENABLE_CURL=OFF", "-DLLVM_ENABLE_HTTPLIB=OFF",
            "-DLLVM_PARALLEL_LINK_JOBS=" .. math.max(math.floor(jobs / 2), 1), "-DCLANG_VENDOR=Apple",
            "-DCLANG_VENDOR_UTI=com.apple.compilers.llvm.clang", "-DPACKAGE_VERSION=21.0.0"}))
        os.vrunv("ninja", {"-C", path.join(build, "llvm"), "-j" .. jobs})

        -- Only the compiler is built: the standard library and the SDK overlays of this release are for the machine's own
        -- platform, and what an iOS port runs is charon@swift-runtime, built for its architecture and oldest release.
        os.vrunv("cmake", table.join({"-S", "swift", "-B", path.join(build, "swift")}, common, {
            "-DCMAKE_Swift_COMPILER=" .. path.join(bootstrap:installdir("bin"), "swiftc"),
            "-DCMAKE_INSTALL_PREFIX=" .. prefix,
            "-DLLVM_DIR=" .. path.join(build, "llvm", "lib", "cmake", "llvm"),
            "-DClang_DIR=" .. path.join(build, "llvm", "lib", "cmake", "clang"),
            "-DSWIFT_PATH_TO_CMARK_SOURCE=" .. path.absolute("cmark"),
            "-DSWIFT_PATH_TO_CMARK_BUILD=" .. path.join(build, "cmark"),
            "-DSWIFT_PATH_TO_SWIFT_SYNTAX_SOURCE=" .. path.absolute("swift-syntax"),
            "-DSWIFT_PATH_TO_STRING_PROCESSING_SOURCE=" .. path.absolute("swift-experimental-string-processing"),
            "-DSWIFT_BUILD_SWIFT_SYNTAX=ON", "-DSWIFT_ENABLE_SWIFT_IN_SWIFT=ON", "-DBOOTSTRAPPING_MODE=HOSTTOOLS",
            "-DLLVM_ENABLE_ASSERTIONS=OFF", "-DSWIFT_STDLIB_ASSERTIONS=OFF",
            "-DSWIFT_HOST_VARIANT=macosx", "-DSWIFT_HOST_VARIANT_SDK=OSX", "-DSWIFT_HOST_VARIANT_ARCH=" .. os.arch(),
            "-DSWIFT_HOST_TRIPLE=" .. os.arch() .. "-apple-macosx" .. host_deployment,
            "-DSWIFT_DARWIN_DEPLOYMENT_VERSION_OSX=" .. host_deployment, "-DSWIFT_SDKS=OSX", "-DSWIFT_PRIMARY_VARIANT_SDK=OSX",
            "-DSWIFT_PRIMARY_VARIANT_ARCH=" .. os.arch(), "-DSWIFT_DARWIN_SUPPORTED_ARCHS=" .. os.arch(),
            "-DSWIFT_INCLUDE_TOOLS=ON", "-DSWIFT_BUILD_DYNAMIC_STDLIB=OFF", "-DSWIFT_BUILD_STATIC_STDLIB=OFF",
            "-DSWIFT_BUILD_DYNAMIC_SDK_OVERLAY=OFF", "-DSWIFT_BUILD_STATIC_SDK_OVERLAY=OFF",
            "-DSWIFT_BUILD_STDLIB_EXTRA_TOOLCHAIN_CONTENT=OFF", "-DSWIFT_BUILD_STDLIB_CXX_MODULE=OFF",
            "-DSWIFT_BUILD_REMOTE_MIRROR=OFF", "-DSWIFT_BUILD_LIBEXEC=OFF", "-DSWIFT_BUILD_SOURCEKIT=OFF",
            "-DSWIFT_ENABLE_SOURCEKIT_TESTS=OFF", "-DSWIFT_INCLUDE_TESTS=OFF", "-DSWIFT_INCLUDE_TEST_BINARIES=OFF",
            "-DSWIFT_INCLUDE_DOCS=OFF", "-DSWIFT_BUILD_PERF_TESTSUITE=OFF", "-DSWIFT_BUILD_REGEX_PARSER_IN_COMPILER=ON",
            "-DSWIFT_ENABLE_EXPERIMENTAL_STRING_PROCESSING=ON", "-DSWIFT_STDLIB_INSTALL_PARENT_MODULE_FOR_SHIMS=ON",
            "-DSWIFT_ENABLE_EXPERIMENTAL_DISTRIBUTED=ON", "-DSWIFT_ENABLE_EXPERIMENTAL_PARSER_VALIDATION=ON",
            "-DSWIFT_VENDOR=Apple", "-DSWIFT_VERSION=" .. package:version():major() .. "." .. package:version():minor(),
            "-DSWIFT_PARALLEL_LINK_JOBS=" .. math.max(math.floor(jobs / 2), 1),
            "-DSWIFT_INSTALL_COMPONENTS=compiler;compiler-swift-syntax-lib;swift-syntax-lib;clang-resource-dir-symlink;clang-builtin-headers-in-clang-resource-dir;stdlib"}))
        -- "compiler" does not build the macro plugins and "stdlib" does not copy the shim headers, although the install
        -- rules of those components lay both down.
        os.vrunv("ninja", {"-C", path.join(build, "swift"), "-j" .. jobs, "compiler", "compiler-swift-syntax-lib",
                           "swift-syntax-lib", "stdlib", "copy_shim_headers", "SwiftMacros", "ObservationMacros",
                           "clang-resource-dir-symlink", "clang-builtin-headers-in-clang-resource-dir"})
        for _, component in ipairs({"compiler", "compiler-swift-syntax-lib", "swift-syntax-lib", "clang-resource-dir-symlink",
                                    "clang-builtin-headers-in-clang-resource-dir", "stdlib"}) do
            os.vrunv("cmake", {"--install", path.join(build, "swift"), "--component", component})
        end

        -- The driver is a Swift package; its dependencies are checked out beside it and SWIFTCI_USE_LOCAL_DEPS makes it
        -- build against those instead of resolving the versions its Package.resolved pins.
        os.tryrm(path.join("swift-driver", "Package.resolved"))
        os.vrunv(path.join(bootstrap:installdir("bin"), "swift-build"), {"-c", "release", "--product", "swift-driver",
                 "--package-path", path.absolute("swift-driver"), "--scratch-path", path.join(build, "driver")},
                 {envs = {SWIFTCI_USE_LOCAL_DEPS = "1"}})
        os.vcp(path.join(build, "driver", "release", "swift-driver"), path.join(package:installdir("bin"), "swift-driver"))
        os.tryrm(path.join(package:installdir("bin"), "swiftc"))
        os.ln("swift-driver", path.join(package:installdir("bin"), "swiftc"))
        os.tryrm(path.join(package:installdir("bin"), "swift"))
        os.ln("swift-driver", path.join(package:installdir("bin"), "swift"))

        -- The sources of the same tag, for the packages that build a module or a runtime from them.
        local source = path.join(package:installdir("share"), "swift-source")
        local copied = {}
        for _, kept in ipairs(table.join(swift.runtime_source_paths(), swift.source_paths())) do
            local inside = kept:gsub("^/", ""):gsub("/$", "")
            local covered = false
            for _, before in ipairs(copied) do
                covered = covered or inside == before or inside:startswith(before .. "/")
            end
            if not covered then
                local from = path.join("swift", inside)
                if not os.exists(from) then
                    raise("the Swift %s sources have no %s", package:version_str(), inside)
                end
                os.mkdir(path.directory(path.join(source, inside)))
                os.vcp(from, path.join(source, inside), {symlink = true})
                table.insert(copied, inside)
            end
        end
        os.vcp(path.join("swift", "LICENSE.txt"), path.join(source, "LICENSE.txt"))

        -- The regular expression libraries are a repository of their own, and the runtime's resync of the standard
        -- library's sources looks for it beside the release's, under the name it has in a checkout of Swift.
        local regex = path.join(package:installdir("share"), "swift-experimental-string-processing")
        os.mkdir(regex)
        os.vcp(path.join("swift-experimental-string-processing", "Sources"), path.join(regex, "Sources"), {symlink = true})
        os.vcp(path.join("swift-experimental-string-processing", "LICENSE.txt"), path.join(regex, "LICENSE.txt"))
        os.vcp(path.join("swift", "LICENSE.txt"), package:installdir("licenses") .. "/")

        os.tryrm(build)
    end)

    on_test(function (package)
        local version = os.iorunv(path.join(package:installdir("bin"), "swiftc"), {"--version"})
        local release = "swift-" .. package:version():major() .. "." .. package:version():minor() .. "-RELEASE"
        assert(version:find(release, 1, true), "swiftc of the swift package reports " .. version)
        assert(os.isfile(path.join(package:installdir("share", "swift-source", "stdlib", "public", "core"), "CMakeLists.txt")))
        assert(os.isdir(path.join(package:installdir("share", "swift-experimental-string-processing", "Sources"), "_RegexParser")),
               "the regular expression sources are not beside the release's, and a runtime built from these would have no Regex")

        -- The driver compiles for a release older than the one it used to refuse, and the frontend takes the features of
        -- this Swift release at that deployment target only when the runtime is said to come with the program.
        local folder = os.tmpfile() .. ".dir"
        os.mkdir(folder)
        -- Parsed as the standard library itself, so the file brings the one type it needs; the feature under test is the
        -- value generic, which this Swift release has and the deployment target's own runtime would not.
        io.writefile(path.join(folder, "generic.swift"),
                     "public struct Int { public var _value: Builtin.Word }\npublic struct Held<let count: Int> { public var value: Int }\n")
        local argv = {"-frontend", "-typecheck", "-parse-stdlib", "-module-name", "Swift", "-target", "armv7-apple-ios6.0",
                      path.join(folder, "generic.swift")}
        local frontend = path.join(package:installdir("bin"), "swift-frontend")
        local refused = try { function () os.vrunv(frontend, argv); return true end }
        assert(not refused, "the frontend must refuse a feature of this Swift release at iOS 6.0 without -bundled-swift-runtime")
        os.vrunv(frontend, table.join(argv, {"-bundled-swift-runtime"}))
        os.tryrm(folder)
    end)
