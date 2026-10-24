package("llvm")
    set_kind("toolchain")
    set_homepage("https://llvm.org")
    set_description("clang that compiles thread-local variables for an iOS whose dyld has none, through emulated TLS, and atomics of any size for an iOS whose libSystem has no __atomic_* calls, with compiler-rt's iOS builtins in its resource folder; with the libraries config, also the LLVM and clang libraries a program such as recompiler' xlate builds on")
    set_license("Apache-2.0 WITH LLVM-exception")

    add_urls("https://github.com/llvm/llvm-project.git")
    add_versions("23.1.3", "0d261d1ca552c95a8f007e061c787ac7132fbcbc")
    add_deps("revenant@iphoneos-sdk", {alias = "iphoneos-sdk"})
    add_deps("cmake", "ninja", {kind = "binary"})

    add_configs("libraries", {description = "Also install what a program built on LLVM and clang needs: libLLVM and libclang-cpp as shared libraries, their headers, llvm-config, and the llvm-extract, llvm-split and llvm-dis tools.", default = false, type = "boolean"})

    local patches = {"clang-emulated-tls-without-dyld.patch", "builtins-leave-emutls-to-the-runtime.patch", "clang-atomic-libcalls-from-the-runtime.patch",
                     "configure-and-build-without-python.patch"}
    local digests = {"xmake.lua=" .. hash.sha256(path.join(os.scriptdir(), "xmake.lua"))}
    for _, patch in ipairs(patches) do
        table.insert(digests, patch .. "=" .. hash.sha256(path.join(os.scriptdir(), "patches", patch)))
    end
    add_configs("recipe", {description = "The digest of this recipe and the patches it applies, so a changed flag or patch is a different compiler.", default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    on_download(function (package, opt)
        if import("@addon.revenant.prebuilt", {anonymous = true}).fetch(package) then
            return
        end
        local checkout = import("@addon.revenant.checkout", {anonymous = true})
        checkout.pinned(opt.sourcedir, {{url = opt.url, tag = "llvmorg-" .. package:version_str(),
                                         commit = package:revision(opt.url_alias) or package:commit(),
                                         sparse = {"/*", "!/*/", "/cmake/", "/third-party/", "/libc/", "!/libc/test/",
                                                   "/llvm/", "!/llvm/test/", "!/llvm/unittests/", "!/llvm/docs/",
                                                   "/clang/", "!/clang/test/", "!/clang/unittests/", "!/clang/docs/", "!/clang/www/",
                                                   "/compiler-rt/", "!/compiler-rt/test/"}}})
    end)

    on_install("@macosx", function (package)
        local prebuilt = import("@addon.revenant.prebuilt", {anonymous = true})
        if prebuilt.install(package) then
            return
        end
        for _, patch in ipairs(patches) do
            os.vrunv("git", {"apply", path.join(package:scriptdir(), "patches", patch), "-p2"})
        end
        local major = package:version():major()
        local parallel = import("@addon.revenant.parallel", {anonymous = true})

        local compiler = path.absolute("build-clang")
        os.tryrm(compiler)
        local configure = {"-G", "Ninja", "-S", "llvm", "-B", compiler, "-DCMAKE_BUILD_TYPE=Release",
                           "-DCMAKE_INSTALL_PREFIX=" .. package:installdir(), "-DCMAKE_OSX_ARCHITECTURES=" .. os.arch(),
                           "-DLLVM_ENABLE_PROJECTS=clang", "-DLLVM_TARGETS_TO_BUILD=ARM;AArch64",
                           "-DLLVM_INCLUDE_TESTS=OFF", "-DLLVM_INCLUDE_UTILS=OFF", "-DLLVM_INCLUDE_BENCHMARKS=OFF",
                           "-DLLVM_INCLUDE_EXAMPLES=OFF", "-DLLVM_INCLUDE_DOCS=OFF", "-DCLANG_INCLUDE_TESTS=OFF", "-DCLANG_INCLUDE_DOCS=OFF",
                           "-DLLVM_ENABLE_ASSERTIONS=OFF", "-DLLVM_ENABLE_ZLIB=OFF", "-DLLVM_ENABLE_ZSTD=OFF",
                           "-DLLVM_ENABLE_LIBXML2=OFF", "-DLLVM_ENABLE_TERMINFO=OFF",
                           "-DCLANG_ENABLE_STATIC_ANALYZER=OFF", "-DCLANG_ENABLE_OBJC_REWRITER=OFF",
                           "-DCMAKE_DISABLE_FIND_PACKAGE_Python3=ON", "-DLLVM_PARALLEL_LINK_JOBS=" .. parallel.link_jobs()}
        local targets = {"install-clang", "install-clang-resource-headers"}
        if package:config("libraries") then
            table.join2(configure, {"-DLLVM_BUILD_LLVM_DYLIB=ON", "-DLLVM_LINK_LLVM_DYLIB=ON",
                                    "-DLLVM_DISTRIBUTION_COMPONENTS=LLVM;clang-cpp;llvm-headers;clang-headers;llvm-config;clang;clang-resource-headers;llvm-extract;llvm-split;llvm-dis;llvm-nm;llvm-objdump"})
            targets = {"install-distribution"}
        end
        os.vrunv("cmake", configure)
        os.vrunv("cmake", table.join({"--build", compiler}, parallel.cmake_ninja(), {"--target"}, targets))
        local clang = path.join(package:installdir("bin"), "clang")

        local sdk = package:dep("iphoneos-sdk")
        local sysroot = path.join(sdk:installdir(), "Developer.app", "Contents", "Developer", "Platforms", "iPhoneOS.platform",
                                  "Developer", "SDKs", "iPhoneOS" .. sdk:version_str() .. ".sdk")
        local builtins = path.absolute("build-builtins")
        os.tryrm(builtins)
        local host_linker = os.iorunv("xcrun", {"-f", "ld"}):trim()
        os.vrunv("cmake", {"-G", "Ninja", "-S", "compiler-rt", "-B", builtins, "-DCMAKE_BUILD_TYPE=Release",
                           "-DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=" .. host_linker,
                           "-DCMAKE_C_COMPILER=" .. clang, "-DCMAKE_CXX_COMPILER=" .. clang .. "++", "-DCMAKE_ASM_COMPILER=" .. clang,
                           "-DLLVM_CMAKE_DIR=" .. path.join(compiler, "lib", "cmake", "llvm"),
                           "-DCOMPILER_RT_INSTALL_PATH=" .. path.join(package:installdir(), "lib", "clang", tostring(major)),
                           "-DCOMPILER_RT_BUILD_BUILTINS=ON", "-DCOMPILER_RT_BUILD_CRT=OFF", "-DCOMPILER_RT_BUILD_SANITIZERS=OFF",
                           "-DCOMPILER_RT_BUILD_XRAY=OFF", "-DCOMPILER_RT_BUILD_LIBFUZZER=OFF", "-DCOMPILER_RT_BUILD_PROFILE=OFF",
                           "-DCOMPILER_RT_BUILD_MEMPROF=OFF", "-DCOMPILER_RT_BUILD_ORC=OFF", "-DCOMPILER_RT_BUILD_CTX_PROFILE=OFF",
                           "-DCOMPILER_RT_INCLUDE_TESTS=OFF", "-DCMAKE_DISABLE_FIND_PACKAGE_Python3=ON",
                           "-DCOMPILER_RT_ENABLE_IOS=ON", "-DCOMPILER_RT_ENABLE_WATCHOS=OFF", "-DCOMPILER_RT_ENABLE_TVOS=OFF",
                           "-DCOMPILER_RT_ENABLE_XROS=OFF",
                           "-DDARWIN_iphoneos_CACHED_SYSROOT=" .. sysroot,
                           "-DDARWIN_iphonesimulator_OVERRIDE_SDK_VERSION=" .. sdk:version_str(),
                           "-DDARWIN_ios_BUILTIN_ARCHS=armv7;armv7s;arm64", "-DDARWIN_osx_BUILTIN_ARCHS=" .. os.arch()})
        os.vrunv("cmake", table.join({"--build", builtins}, parallel.cmake_ninja()))
        os.vrunv("cmake", {"--install", builtins})

        for _, project in ipairs({"llvm", "clang", "compiler-rt"}) do
            os.vcp(path.join(project, "LICENSE.TXT"), path.join(package:installdir("licenses"), project, "LICENSE.TXT"))
        end
        prebuilt.pack(package)
    end)

    on_test(function (package)
        local major = package:version():major()
        local archive = path.join(package:installdir("lib"), "clang", tostring(major), "lib", "darwin", "libclang_rt.ios.a")
        local architectures = os.iorunv("xcrun", {"lipo", "-archs", archive}):trim()
        for _, architecture in ipairs({"armv7", "armv7s", "arm64"}) do
            assert(architectures:find(architecture, 1, true), "the iOS builtins have no " .. architecture .. " slice: " .. architectures)
        end
        assert(not os.iorunv("xcrun", {"nm", "-g", archive}):find("___emutls_get_address", 1, true),
               "the iOS builtins carry emutls, which hands every image its own copy")
        local probe = os.tmpfile() .. ".c"
        io.writefile(probe, "_Thread_local int probe;\n")
        local clang = path.join(package:installdir("bin"), "clang")
        os.vrunv(clang, {"-target", "armv7-apple-ios6.0", "-femulated-tls", "-fsyntax-only", probe})
        io.writefile(probe, "struct wide { int a, b, c; };\n_Atomic(struct wide) probe;\nstruct wide read(void) { return probe; }\n")
        os.vrunv(clang, {"-target", "armv7-apple-ios6.0", "-fsyntax-only", probe})
        os.tryrm(probe)
        if package:config("libraries") then
            local version = os.iorunv(path.join(package:installdir("bin"), "llvm-config"), {"--version"}):trim()
            assert(version == package:version_str(), "llvm-config answers " .. version .. ", not " .. package:version_str())
            for _, file in ipairs({path.join("lib", "libLLVM.dylib"), path.join("lib", "libclang-cpp.dylib"),
                                   path.join("include", "llvm", "Config", "llvm-config.h"), path.join("include", "clang", "Basic", "LLVM.h"),
                                   path.join("bin", "llvm-extract"), path.join("bin", "llvm-split"), path.join("bin", "llvm-dis")}) do
                assert(os.isfile(path.join(package:installdir(), file)), "the libraries install has no " .. file)
            end
        end
    end)
