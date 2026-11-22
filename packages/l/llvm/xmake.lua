package("llvm")
    set_kind("toolchain")
    set_homepage("https://llvm.org")
    set_description("clang that compiles thread-local variables for an iOS whose dyld has none, through emulated TLS, and atomics of any size for an iOS whose libSystem has no __atomic_* calls, with compiler-rt's iOS builtins in its resource folder; with the libraries config, also the LLVM and clang libraries a program such as recompiler' xlate builds on")
    set_license("Apache-2.0 WITH LLVM-exception")

    includes(path.join(os.scriptdir(), "port", "inputs.lua"))
    local inputs = llvm_build_inputs

    add_urls(inputs.url)
    add_versions(inputs.version, inputs.commit)
    add_deps("revenant@iphoneos-sdk", {alias = "iphoneos-sdk"})
    add_deps("cmake", "ninja", {kind = "binary"})

    add_configs("libraries", {description = "Also install what a program built on LLVM and clang needs: libLLVM and libclang-cpp as shared libraries, their headers, llvm-config, and the llvm-extract, llvm-split and llvm-dis tools.", default = false, type = "boolean"})
    add_configs("recipe", {description = "The digest of what the build reads (port/inputs.lua: its flags, url, version and the patches' bytes), so a changed flag or patch is a different compiler and a changed layout of the build code is not.", default = llvm_recipe_key(os.scriptdir()), type = "string", readonly = true})

    local iphoneos = path.join(os.scriptdir(), "..", "..", "i", "iphoneos-sdk")
    local sdk = {}
    for _, file in ipairs({"xmake.lua", path.join("port", "digest.lua")}) do
        table.insert(sdk, file .. "=" .. hash.sha256(path.join(iphoneos, file)))
    end
    add_configs("sdk", {description = "The digest of the iPhoneOS SDK's recipe and the files it adds, which the iOS builtins are compiled against, so a changed SDK is a different compiler.", default = hash.strhash128(table.concat(sdk, ";")), type = "string", readonly = true})

    on_download(function (package, opt)
        if import("@addon.revenant.prebuilt", {anonymous = true}).fetch(package) then
            return
        end
        local checkout = import("@addon.revenant.checkout", {anonymous = true})
        checkout.pinned(opt.sourcedir, {{url = opt.url, tag = inputs.tag_prefix .. package:version_str(),
                                         commit = package:revision(opt.url_alias) or package:commit(),
                                         sparse = inputs.sparse}})
    end)

    on_install("@macosx", function (package)
        local prebuilt = import("@addon.revenant.prebuilt", {anonymous = true})
        if prebuilt.install(package) then
            return
        end
        os.cd(import("@addon.revenant.checkout", {anonymous = true}).keyed(os.curdir(), package:buildhash()))
        local function expand(flags, values)
            local expanded = {}
            for _, flag in ipairs(flags) do
                table.insert(expanded, (flag:gsub("{([%w_]+)}", function (name)
                    return values[name] or raise("llvm: the inputs name {%s}, which the build does not give", name)
                end)))
            end
            return expanded
        end
        for _, patch in ipairs(inputs.patches) do
            os.vrunv("git", expand(inputs.apply, {patch = path.join(package:scriptdir(), "patches", patch)}))
        end
        local major = package:version():major()
        local parallel = import("@addon.revenant.parallel", {anonymous = true})

        local compiler = path.absolute("build-clang")
        os.tryrm(compiler)
        local values = {build = compiler, install = package:installdir(), arch = os.arch(), link_jobs = tostring(parallel.link_jobs())}
        local configure = expand(inputs.compiler.configure, values)
        local targets = inputs.compiler.targets
        if package:config("libraries") then
            table.join2(configure, expand(inputs.compiler.libraries, values))
            targets = inputs.compiler.libraries_targets
        end
        os.vrunv("cmake", configure)
        os.vrunv("cmake", table.join(expand(inputs.cmake.build, values), parallel.cmake_ninja(), inputs.cmake.target, targets))
        local clang = path.join(package:installdir("bin"), "clang")

        local sdk = package:dep("iphoneos-sdk")
        local sysroot = path.join(sdk:installdir(), "Developer.app", "Contents", "Developer", "Platforms", "iPhoneOS.platform",
                                  "Developer", "SDKs", "iPhoneOS" .. sdk:version_str() .. ".sdk")
        local builtins = path.absolute("build-builtins")
        os.tryrm(builtins)
        values.build = builtins
        values.clang = clang
        values.host_linker = os.iorunv(inputs.host_linker.program, inputs.host_linker.arguments):trim()
        values.llvm_cmake_dir = path.join(compiler, "lib", "cmake", "llvm")
        values.resource_install = path.join(package:installdir(), "lib", "clang", tostring(major))
        values.sysroot = sysroot
        values.sdk_version = sdk:version_str()
        os.vrunv("cmake", expand(inputs.builtins.configure, values))
        os.vrunv("cmake", table.join(expand(inputs.cmake.build, values), parallel.cmake_ninja()))
        os.vrunv("cmake", expand(inputs.cmake.install, values))

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
        assert(os.isfile(path.join(package:installdir("lib"), "libLTO.dylib")), "the llvm install has no libLTO.dylib, which an -flto link loads for its bitcode objects")
        assert(os.isfile(path.join(package:installdir("bin"), "llvm-libtool-darwin")), "the llvm install has no llvm-libtool-darwin, which the webkit-engine archives are made with")
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
