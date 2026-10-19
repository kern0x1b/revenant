package("matter")
    set_homepage("https://github.com/project-chip/connectedhomeip")
    set_description("The Matter stack, built as the port builds it: connectedhomeip's own GN build of libCHIP for the release, and then the framework's own Objective-C++ wrapper over it")
    set_license("Apache-2.0")
    set_policy("package.strict_compatibility", true)

    -- submodules = false: connectedhomeip declares about two hundred submodules, almost all of them the
    -- vendor SDKs of embedded platforms this build never reads, and xmake clones a git source's submodules
    -- recursively unless a url says otherwise. The six this build does read are checked out below, at the
    -- commits the tag pins.
    add_urls("https://github.com/project-chip/connectedhomeip.git", {submodules = false})
    add_versions("v1.6.1.0", "3bcdd56ba54fb88b2afb4bfef575014671df7aa7")
    add_patches("v1.6.1.0", "patches/clock-alignment.patch", "2f0b8e3e0672cd2ebe2a4e4343f11ac550c0aec89f97d85367ecb60da30e902a")
    -- BleConnectionDelegateImpl.mm reads CBAdvertisementDataIsConnectable and drops an advertisement whose key is nil; iOS 6.1.3's
    -- CoreBluetooth never sends the key, so every commissionable advertisement would be dropped there. An absent key counts as
    -- connectable (the patch's own comment; facts/MatterFramework.md has the measurement).
    add_patches("v1.6.1.0", "patches/ble-connectable.patch", "2ca2a6a7b2e6aa493fe6151ebf3ce63c41954776bc4bea0dee3dbbdb633a3325")

    add_deps("charon@apple-compat", {alias = "apple-compat"})
    -- The backports the process carries are a project decision (includes/apple-ios/xmake.lua's apple_backports):
    -- this package needs network, and swift-runtime's port headers need coredata, and one package has one set of configs.
    -- The port's apple_backports must name security, commoncrypto and corebluetooth too: xmake refuses two dependents whose configs differ
    -- ("conflict version dependencies" on apple-backports), and swift-runtime's dependency takes the port's set, not this one.
    -- security: SecKeyCopyExternalRepresentation (MTRP256KeypairBridge.mm), which iOS 6.1.3's Security lacks. commoncrypto:
    -- CCRandomGenerateBytes, which BoringSSL's iOS random source calls without a guard (third_party/boringssl/repo/src/crypto/
    -- rand_extra/ios.c:25), so it must bind to the backport and not to a null weak import on 6.1.3. corebluetooth:
    -- CBAdvertisementDataIsConnectable, which the 6.1.3 CoreBluetooth does not export (facts/CoreBluetooth in the backports).
    add_deps("charon@apple-backports", {alias = "backports", configs = {network = true, security = true, commoncrypto = true, corebluetooth = true}})
    -- The port's headers, from the one swift-runtime the workspace builds: what the backports implement of later
    -- releases is available from this release's own, which is what a port compiles against. The framework's Darwin
    -- platform asks os_signpost_* of iOS 12, which apple-compat now provides, and without the port's headers its
    -- declaration is still marked unavailable at this release and clang refuses the call.
    add_deps("charon@swift-runtime", {alias = "swift-runtime", configs = {backports = true}})
    add_deps("charon@ld64", {alias = "ld64"})
    -- packaged: the libc++ this link names carries its install name under /usr/lib/charon/org.charon.libcxx-<hash>/, which is
    -- where the device has it (swift-runtime takes it the same way). Unpackaged, the dylib names the build host's own path,
    -- which is the rpath this link used to carry and a device does not have.
    add_deps("charon@libcxx", {alias = "libcxx", configs = {packaged = true}})
    add_deps("gn 20211117", {alias = "gn"})

    -- The submodules //src/lib:lib reads, at the commits the tag pins (read from the tag's own git objects, with
    -- `git submodule status`): the two nestlabs assert/logging headers under src/include, BoringSSL, pigweed's gni
    -- files, and - with chip_enable_all_clusters, which is what carries every cluster the SDK's Matter framework has -
    -- jsoncpp and uriparser. Nothing else is fetched: the tree this package builds does not read a byte of the rest.
    local submodules = {
        ["third_party/nlassert/repo"] = "c5892c5ae43830f939ed660ff8ac5f1b91d336d3",
        ["third_party/nlio/repo"] = "0e725502c2b17bb0a0c22ddd4bcaee9090c8fb5c",
        ["third_party/boringssl/repo/src"] = "9cac8a6b38c1cbd45c77aee108411d588da006fe",
        ["third_party/pigweed/repo"] = "8bc35d07baf8000f8db57674a23c5e06f7516d79",
        ["third_party/jsoncpp/repo"] = "8519b8381f3c741ad1421f88237b1deda0b11412",
        ["third_party/uriparser/repo"] = "04d8b8df5e0c6bf6c06e472540c015943a613bd2"
    }
    -- GN's spelling of each architecture the port builds.
    local cpus = {armv7 = "arm", armv7s = "arm", arm64 = "arm64"}

    -- What the runtime's port headers are, as a VFS overlay the compiler reads its headers through: the same flag
    -- rules/swift gives a port's own Swift, for the same reason and with the same file.
    local function port_headers(package)
        local runtime = package:dep("swift-runtime")
        if not runtime then
            return {}
        end
        local overlay = table.wrap((runtime:envs() or {}).CHARON_SWIFT_PORT_HEADERS)[1]
        if not overlay then
            raise("charon@swift-runtime at %s names no port headers; it was built without the backports, reinstall it", runtime:installdir())
        end
        return {"-ivfsoverlay", overlay}
    end

    on_install("iphoneos", function (package)
        local modules = path.join(package:scriptdir(), "..", "..", "..", "modules")
        local toolchain = import("apple.cmake", {rootdir = modules, anonymous = true}).toolchain(package)
        local sdk = assert(toolchain:config("sdkdir"), "the apple-ios toolchain names no SDK")
        local minimum = assert(toolchain:config("deployment"), "the apple-ios toolchain names no minimum release")
        local cpu = assert(cpus[package:arch()], "Matter builds armv7, armv7s and arm64, not %s", package:arch())

        -- The flags, taken from the toolchain rather than written out here, the way modules/apple/cmake.lua takes them:
        -- the release's own triple, sysroot and deployment target, and its own emulated-TLS flag, which is what an
        -- armv7 build below iOS 9 needs because that release's libSystem has no real __thread.
        local flags = table.join({"-target", package:arch() .. "-apple-ios", "-miphoneos-version-min=" .. minimum, "-isysroot", sdk},
                                 toolchain:config("linker_version") and {"-mlinker-version=" .. toolchain:config("linker_version")} or {})
        -- -Wno-incompatible-sysroot: clang's own warning that a sysroot newer than the deployment target is being
        -- used, which is every build on this port - the port compiles against a current SDK for a release far older -
        -- and GN compiles the tree with -Werror, so the warning would stop the build over the port's own arrangement.
        local compiled = table.join(flags, toolchain:config("emulated_tls") and {"-femulated-tls"} or {},
                                    {"-Wno-incompatible-sysroot"}, port_headers(package))

        for _, name in ipairs(table.orderkeys(submodules)) do
            os.vrunv("git", {"submodule", "update", "--init", "--depth", "1", name})
            assert(os.isdir(path.join(os.curdir(), name)), "the submodule %s is not there after git checked it out", name)
        end

        -- //build_overrides/pigweed.gni imports //build_overrides/pigweed_environment.gni, a file upstream's bootstrap
        -- step writes into the source tree and its .gitignore lists. This build has no pigweed environment at all - no
        -- CIPD toolchain, no pw_env_setup, a compiler and an archiver of the port's own passed to GN - so the file is
        -- written here, empty of declarations, which is what the generated one comes to for a build that has none of
        -- the variables it would declare: every one of them (pw_env_setup_CIPD_PIGWEED, pw_env_setup_CIPD_RUST and the
        -- rest) is read through defined() by the pigweed gni files that import this one.
        io.writefile(path.join(os.curdir(), "build_overrides", "pigweed_environment.gni"),
                     "# Written by charon@matter's install step in place of the file pigweed's bootstrap step generates.\n" ..
                     "# This build has no pigweed environment: no CIPD toolchain, no pw_env_setup, and a compiler and\n" ..
                     "# an archiver of the port's own passed to GN as target_cc, target_cxx and target_ar. Every variable\n" ..
                     "# the pigweed gni files read out of this one is read through defined(), and a build that has none of\n" ..
                     "# them set is what the declarations come to, so the file declares nothing.\n")

        local function quoted(values)
            local parts = {}
            for _, value in ipairs(values) do
                table.insert(parts, "\"" .. value:gsub("\\", "\\\\"):gsub("\"", "\\\"") .. "\"")
            end
            return table.concat(parts, ", ")
        end

        -- build_overrides/../gn_build.sh and the framework's own chip_xcode_build_connector.sh write this list; the
        -- two flags GN's own custom toolchain exists for are the port's compiler, archiver and flags, and everything
        -- else is the framework's own build configuration (the second import, //config/darwin/args.gni, is what makes
        -- the sources the darwin platform's and not a fake platform's).
        local args = {
            'import("//config/darwin/args.gni")',
            "default_configs_cosmetic=[]",
            "is_clang=true",
            "is_debug=false",
            'custom_toolchain="custom"',
            'target_os="ios"',
            'target_cpu="' .. cpu .. '"',
            "target_cc=" .. string.format("%q", assert(toolchain:tool("cc"), "the apple-ios toolchain names no compiler for %s", package:arch())),
            "target_cxx=" .. string.format("%q", assert(toolchain:tool("cxx"), "the apple-ios toolchain names no C++ compiler for %s", package:arch())),
            "target_ar=" .. string.format("%q", assert(toolchain:tool("ar"), "the apple-ios toolchain names no archiver")),
            "target_cflags=[" .. quoted(compiled) .. "]",
            "target_cflags_c=[]",
            "target_cflags_cc=[]",
            "target_ldflags=[" .. quoted(flags) .. "]",
            "target_defines=[]",
            "mac_target_arch=" .. string.format("%q", package:arch()),
            "mac_deployment_target=" .. string.format("%q", minimum),
            'chip_crypto="boringssl"',
            "chip_build_controller_dynamic_server=false",
            "chip_build_tools=false",
            "chip_build_tests=false",
            -- Every cluster, because the framework's zap-generated sources name every cluster's Objective-C class and
            -- each one is a C++ cluster below it; the SDK's own Matter framework has them all.
            "chip_enable_all_clusters=true",
            "chip_enable_wifi=false",
            "chip_enable_nfc_based_commissioning=true",
            "chip_enable_python_modules=false",
            "chip_device_config_enable_dynamic_mrp_config=true",
            "chip_log_message_max_size=4096",
            'chip_logging_backend="none"',
            "chip_disable_platform_kvs=true",
            "enable_fuzz_test_targets=false"
        }

        -- One build tree per configuration: the sources are one directory for every architecture and every release the
        -- port builds, so a shared tree would build the second one with the first one's flags.
        local out = path.absolute("out-" .. package:buildhash())
        os.mkdir(out)
        os.vrunv(path.join(package:dep("gn"):installdir("bin"), "gn"),
                 {"--root=" .. path.absolute(os.curdir()), "gen", out, "--args=" .. table.concat(args, " ")})
        os.vrunv("ninja", {"-C", out, "src/lib:lib"})
        os.cp(path.join(out, "lib", "libCHIP.a"), package:installdir("lib"))

        -- Stage 2: the framework's own Objective-C++ wrapper, compiled and linked as libMatterBackports.dylib.
        -- Its sources name each other as <Matter/...>, which is the framework's own include layout, so the headers
        -- are gathered into one Matter directory first - the same directory a port will import them from, and the
        -- one installed below.
        local framework = path.join(os.curdir(), "src", "darwin", "Framework", "CHIP")
        -- The framework's headers and sources are in four directories, and its sources name a header two ways:
        -- "MTRFoo.h", which is the including file's own directory, and <Matter/MTRFoo.h>, which is the framework's
        -- public include layout. None of the headers has an include guard, so a header reached under two names is read
        -- twice and every class in it is defined twice - which is what the first build of this said. The two names have
        -- to be one file, and a quoted include always resolves against the including file's own directory first, so
        -- the sources are staged into one directory named Matter and compiled from inside it: there, "MTRFoo.h" and
        -- <Matter/MTRFoo.h> are the same path. The files are the framework's own, byte for byte.
        local staged = path.join(out, "framework", "Matter")
        os.mkdir(staged)
        local flat, sources = {}, {}
        for _, directory in ipairs({framework, path.join(framework, "zap-generated"), path.join(framework, "ServerEndpoint"),
                                    path.join(framework, "XPC Protocol")}) do
            for _, kind in ipairs({"*.h", "*.mm"}) do
                for _, file in ipairs(os.files(path.join(directory, kind))) do
                    local name = path.filename(file)
                    assert(flat[name] == nil, "the framework carries %s twice, in %s and in %s", name, flat[name], file)
                    flat[name] = file
                    if name:endswith(".mm") then
                        table.insert(sources, path.relative(file, framework))
                    end
                end
            end
        end
        table.sort(sources)
        local names = {}
        for name in pairs(flat) do
            table.insert(names, name)
        end
        table.sort(names)
        assert(#sources > 0, "the framework at %s has no Objective-C++ source", framework)

        -- Each file keeps its own place under the framework, so a source's quoted include of "MTRFoo.h" resolves
        -- against its own directory as it does upstream, and "zap-generated/MTRFoo.h" resolves the same way. Each header
        -- is then also reachable under its bare name, which is the one <Matter/MTRFoo.h> asks for, by a link to that
        -- same file: not a copy, because a copy is a second file and this framework's headers carry no include guard,
        -- so a class of one of them would be defined twice.
        for _, name in ipairs(names) do
            local here = path.join(staged, path.relative(flat[name], framework))
            os.mkdir(path.directory(here))
            os.cp(flat[name], here)
            local bare = path.join(staged, name)
            if bare ~= here then
                os.vrunv("ln", {"-sf", here, bare})
            end
        end
        for _, name in ipairs(sources) do
            local here = path.join(staged, name)
            os.mkdir(path.directory(here))
            os.cp(flat[path.filename(here)], here)
        end
        -- The framework's Matter.xcodeproj writes git_commit_sha.h in a run-script phase before it compiles, and its
        -- Sources phase compiles MTRFrameworkDiagnostics.mm, which includes it. The header is the phase's own text, with
        -- the SHA the phase takes from `git rev-parse --short HEAD` in the checkout (the pinned commit, 3bcdd56b). It goes
        -- beside the sources, where a quoted include finds it, and is not a public header, so the install does not carry
        -- it. A failing git stops the build: a made-up SHA would be reported as the framework's own.
        local sha = os.iorunv("git", {"-C", os.curdir(), "rev-parse", "--short", "HEAD"}):trim()
        io.writefile(path.join(staged, "git_commit_sha.h"),
                     string.format("#ifndef GIT_COMMIT_SHA_H\n#define GIT_COMMIT_SHA_H\n\n#define GIT_COMMIT_SHA \"%s\"\n\n#endif /* GIT_COMMIT_SHA_H */\n", sha))

        local search = {path.join(out, "framework"), path.join(out, "gen", "include"),
                        path.join(os.curdir(), "src"), path.join(os.curdir(), "src", "include"),
                        path.join(os.curdir(), "zzz_generated"), path.join(os.curdir(), "zzz_generated", "app-common"),
                        path.join(os.curdir(), "third_party", "nlassert", "repo", "include"),
                        path.join(os.curdir(), "third_party", "nlio", "repo", "include")}
        -- -nostdinc++ with the port's own libc++ headers: the SDK carries the libc++ of iOS 6 in usr/include, which
        -- the SDK's own headers reach (usr/include/assert.h:44 pulls in c++/v1/stdlib.h), and those are written for the
        -- older compiler and break on this one - _LIBCPP_INLINE_VISIBILITY is a macro this compiler does not define.
        -- The framework's own build configuration, from src/darwin/Framework/Configs/Project.xcconfig:4, which is
        -- "MTR_NO_AVAILABILITY=1 MTR_ENABLE_PROVISIONAL=1 MTR_ENABLE_UNSTABLE_API=1". MTR_NO_AVAILABILITY makes
        -- MTR_AVAILABLE expand to nothing, and MTR_ENABLE_PROVISIONAL is what makes MTR_PROVISIONALLY_AVAILABLE the
        -- plain export instead of NS_UNAVAILABLE - which is the first thing a build of the framework has to have:
        -- without it every member zap-generated of a newer Matter release (MTRAttributePath's label and auxiliaryType,
        -- MTRDataTypeSemanticTagStruct in full) is declared NS_UNAVAILABLE by MTRDefines.h:75, and its own use of it is
        -- a hard error that no warning flag turns into a warning. These are the framework's own three switches, not
        -- this recipe's judgement: the same project compiles its own availability tests with
        -- "-UMTR_NO_AVAILABILITY -Wno-unguarded-availability-new", so the marks are off for the framework and on
        -- where they are the thing under test.
        local wrapper = table.join(compiled, {"-fobjc-arc", "-fno-c++-static-destructors",
                                             "-fmacro-prefix-map=" .. staged .. "/=",
                                             "-nostdinc++", "-isystem", path.join(package:dep("libcxx"):installdir("include"), "c++", "v1"),
                                             "-DMTR_NO_AVAILABILITY=1", "-DMTR_ENABLE_PROVISIONAL=1", "-DMTR_ENABLE_UNSTABLE_API=1",
                                             "-DCHIP_HAVE_CONFIG_H=1", "-DCHIP_CONFIG_SKIP_APP_SPECIFIC_GENERATED_HEADER_INCLUDES=1",
                                             "-DCHIP_CONFIG_GLOBALS_NO_DESTRUCT=1"})
        local objects = {}
        for _, name in ipairs(sources) do
            local object = path.absolute(path.join("framework", name .. ".o"))
            os.mkdir(path.directory(object))
            local arguments = table.join(wrapper, {"-I" .. staged})
            for _, directory in ipairs(search) do
                table.insert(arguments, "-I" .. directory)
            end
            os.vrunv(assert(toolchain:tool("mxx"), "the apple-ios toolchain names no Objective-C++ compiler for %s", package:arch()),
                     table.join(arguments, {"-c", path.join(staged, name), "-o", object}))
            table.insert(objects, object)
        end

        -- The framework's own target also compiles the app layer its server endpoint needs, as C++ of the project's own: the
        -- twenty-three names of its Sources phase that are not MTR* (Matter.xcodeproj, PBXNativeTarget "Matter"; the list is
        -- the one tools/matter-framework.sh reads). The wrapper calls emberAfSetDynamicEndpoint, emberAfEndpointFromIndex,
        -- MatterDescriptorClusterInitCallback and CodegenDataModelProviderInstance, and libCHIP.a does not define them: the
        -- link failed on exactly those (runs/matter-613/build.log). They are compiled as C++, without ARC or the wrapper's
        -- Objective-C++ switches, with the same target, sysroot and libc++.
        local appsources = {
            "src/app/server-cluster/AttributeListBuilder.cpp",
            "src/app/server-cluster/DefaultServerCluster.cpp",
            "src/app/server-cluster/ServerClusterInterface.cpp",
            "src/app/server-cluster/ServerClusterInterfaceRegistry.cpp",
            "src/app/server-cluster/SingleEndpointServerClusterRegistry.cpp",
            "src/app/persistence/AttributePersistenceProviderInstance.cpp",
            "src/app/persistence/DefaultAttributePersistenceProvider.cpp",
            "src/data-model-providers/codegen/ClusterIntegration.cpp",
            "src/data-model-providers/codegen/CodegenDataModelProvider.cpp",
            "src/data-model-providers/codegen/CodegenDataModelProvider_Read.cpp",
            "src/data-model-providers/codegen/CodegenDataModelProvider_Write.cpp",
            "src/data-model-providers/codegen/EmberAttributeDataBuffer.cpp",
            "src/data-model-providers/codegen/Instance.cpp",
            "src/app/clusters/descriptor/CodegenIntegration.cpp",
            "src/app/clusters/descriptor/DescriptorCluster.cpp",
            "src/app/clusters/ota-provider/OTAProviderCluster.cpp",
            "src/app/util/DataModelHandler.cpp",
            "src/app/util/attribute-storage.cpp",
            "src/app/util/ember-io-storage.cpp",
            "src/app/util/generic-callback-stubs.cpp",
            "src/app/util/util.cpp",
            "src/app/reporting/reporting.cpp",
            "zzz_generated/app-common/app-common/zap-generated/cluster-objects.cpp"
        }
        local cxxflags = table.join(compiled, {"-Os", "-nostdinc++", "-isystem", path.join(package:dep("libcxx"):installdir("include"), "c++", "v1"),
                                              "-DCHIP_HAVE_CONFIG_H=1", "-DCHIP_CONFIG_SKIP_APP_SPECIFIC_GENERATED_HEADER_INCLUDES=1",
                                              "-DCHIP_CONFIG_GLOBALS_NO_DESTRUCT=1", "-I" .. staged})
        for _, directory in ipairs(search) do
            table.insert(cxxflags, "-I" .. directory)
        end
        -- The framework's CHIP directory last: it carries app/PluginApplicationCallbacks.h, which util.cpp includes as
        -- <app/...>, and every other <app/...> is the source tree's own, found first.
        table.insert(cxxflags, "-I" .. framework)
        local cxx = assert(toolchain:tool("cxx"), "the apple-ios toolchain names no C++ compiler for %s", package:arch())
        for _, rel in ipairs(appsources) do
            local object = path.absolute(path.join("framework", rel .. ".o"))
            os.mkdir(path.directory(object))
            os.vrunv(cxx, table.join(cxxflags, {"-c", path.join(os.curdir(), rel), "-o", object}))
            table.insert(objects, object)
        end

        -- The install carries the framework's headers, flattened as <Matter/...> names them.
        local installed = path.join(package:installdir("include"), "Matter")
        os.mkdir(installed)
        for _, name in ipairs(names) do
            if name:endswith(".h") then
                os.cp(flat[name], installed)
            end
        end
        os.mkdir(path.join(installed, "Modules"))
        os.cp(path.join(framework, "Matter.modulemap"), path.join(installed, "Modules", "module.modulemap"))

        local libcxx = package:dep("libcxx"):installdir("lib")
        -- The framework's device browser asks Network for a connection (MTRDeviceConnectivityMonitor.mm), and iOS 6
        -- has no Network.framework, so the nw_* calls come from the backport that carries them over BSD sockets.
        local backports = package:dep("apple-backports"):installdir("lib")
        local output = path.join(package:installdir("lib"), "libMatterBackports.dylib")
        -- No -Wl,-no_implicit_dylibs. It was here to get past ld64 956.6 asserting in
        -- OutputFile::dylibToOrdinal - "it != _dylibToOrdinal.end()" - while encoding this symbol
        -- table, and packages/l/ld64 fixes that: the encoder now gives an ordinal to every dylib
        -- that owns an import proxy, so a second File for an install path the load list already
        -- holds - the SDK's usr/lib/libobjc.tbd beside usr/lib/libobjc.A.tbd - is no longer left
        -- without one, and that is the symbol that aborted. The flag did not fix that, it avoided
        -- it, and at a cost: with implicit dylibs off the ObjC runtime had no ordinal either, so
        -- _objc_getClass and _class_getSuperclass were bound to Foundation, which does not export
        -- them, in 5 load commands against the 7 this link now carries. packages/l/ld64/README.md
        -- has the measurement and the reduced reproducer.
        os.vrunv(assert(toolchain:tool("mxx"), "the apple-ios toolchain names no Objective-C++ compiler for %s", package:arch()),
                 table.join(flags, {"-fuse-ld=" .. path.join(package:dep("ld64"):installdir("bin"), "ld"),
                                    "-dynamiclib", "-install_name", "/usr/lib/charon/org.charon.apple-backports/libMatterBackports.dylib",
                                    "-o", output, path.join(out, "lib", "libCHIP.a")}, objects,
                           -- The backports come before the frameworks, so a symbol the release lacks binds to the backport and not to the
                           -- framework's absence: SecKeyCopyExternalRepresentation (Security), CCRandomGenerateBytes (CommonCrypto), nw_*, and
                           -- CBAdvertisementDataIsConnectable (CoreBluetooth), which the framework is linked after, so the backport answers first.
                           -- os_unfair_lock_lock and _unlock: libc++abi's dylib below is the process-wide provider (libcxx's
                           -- process-wide-compat.patch), and it is named before libapple-compat.a, so the archive's copy is not pulled.
                           {"-L" .. backports, "-lNetworkBackports", "-lFoundationBackports", "-lSecurityBackports", "-lCommonCryptoBackports", "-lCoreBluetoothBackports",
                            "-L" .. libcxx, "-lc++abi", "-lc++",
                            path.join(package:dep("apple-compat"):installdir("lib"), "libapple-compat.a"),
                            "-framework", "Foundation", "-framework", "Security", "-framework", "CoreData",
                            "-framework", "CoreBluetooth",
                            "-Wl,-rpath,@loader_path"}))

        package:add("links", "Matter")
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libCHIP.a")))
        assert(os.isfile(path.join(package:installdir("lib"), "libMatterBackports.dylib")))
    end)
