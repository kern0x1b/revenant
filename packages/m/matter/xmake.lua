package("matter")
    set_homepage("https://github.com/project-chip/connectedhomeip")
    set_description("The Matter stack, built as the port builds it: connectedhomeip's own GN build of libCHIP for the release, and then the framework's own Objective-C++ wrapper over it")
    set_license("Apache-2.0")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/project-chip/connectedhomeip.git", {submodules = false})
    add_versions("v1.6.1.0", "3bcdd56ba54fb88b2afb4bfef575014671df7aa7")
    add_patches("v1.6.1.0", "patches/clock-alignment.patch", "5b7f86ccd71bb364f27568245937d71464af8f77c42a0db58a52453d83fc4aee")
    add_patches("v1.6.1.0", "patches/ble-connectable.patch", "67f3d5e8bac9fc8fe0e2a256db4efe93dcb5cfa72d95c809e384966220972b19")

    add_deps("revenant@apple-compat", {alias = "apple-compat"})
    add_deps("revenant@swift-runtime", {alias = "swift-runtime", configs = {backports = true}})
    add_deps("revenant@ld64", {alias = "ld64"})
    add_deps("revenant@libcxx", {alias = "libcxx", configs = {packaged = true}})
    add_deps("gn 20211117", {alias = "gn"})

    local submodules = {
        ["third_party/nlassert/repo"] = "c5892c5ae43830f939ed660ff8ac5f1b91d336d3",
        ["third_party/nlio/repo"] = "0e725502c2b17bb0a0c22ddd4bcaee9090c8fb5c",
        ["third_party/boringssl/repo/src"] = "9cac8a6b38c1cbd45c77aee108411d588da006fe",
        ["third_party/pigweed/repo"] = "8bc35d07baf8000f8db57674a23c5e06f7516d79",
        ["third_party/jsoncpp/repo"] = "8519b8381f3c741ad1421f88237b1deda0b11412",
        ["third_party/uriparser/repo"] = "04d8b8df5e0c6bf6c06e472540c015943a613bd2"
    }
    local cpus = {armv7 = "arm", armv7s = "arm", arm64 = "arm64"}

    local function port_headers(package)
        local runtime = package:dep("swift-runtime")
        if not runtime then
            return {}
        end
        local overlay = table.wrap((runtime:envs() or {}).REVENANT_SWIFT_PORT_HEADERS)[1]
        if not overlay then
            raise("revenant@swift-runtime at %s names no port headers; it was built without the backports, reinstall it", runtime:installdir())
        end
        return {"-ivfsoverlay", overlay}
    end

    on_install("iphoneos", function (package)
        local toolchain = import("@addon.revenant.apple.cmake", {anonymous = true}).toolchain(package)
        local sdk = assert(toolchain:config("sdkdir"), "the apple-ios toolchain names no SDK")
        local minimum = assert(toolchain:config("deployment"), "the apple-ios toolchain names no minimum release")
        local cpu = assert(cpus[package:arch()], "Matter builds armv7, armv7s and arm64, not %s", package:arch())

        local flags = table.join({"-target", package:arch() .. "-apple-ios", "-miphoneos-version-min=" .. minimum, "-isysroot", sdk},
                                 toolchain:config("linker_version") and {"-mlinker-version=" .. toolchain:config("linker_version")} or {})
        local compiled = table.join(flags, toolchain:config("emulated_tls") and {"-femulated-tls"} or {},
                                    {"-Wno-incompatible-sysroot"}, port_headers(package))

        for _, name in ipairs(table.orderkeys(submodules)) do
            os.vrunv("git", {"submodule", "update", "--init", "--depth", "1", name})
            assert(os.isdir(path.join(os.curdir(), name)), "the submodule %s is not there after git checked it out", name)
        end

        io.writefile(path.join(os.curdir(), "build_overrides", "pigweed_environment.gni"),
                     "# Written by revenant@matter's install step in place of the file pigweed's bootstrap step generates.\n" ..
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

        local out = path.absolute("out-" .. package:buildhash())
        os.mkdir(out)
        os.vrunv(path.join(package:dep("gn"):installdir("bin"), "gn"),
                 {"--root=" .. path.absolute(os.curdir()), "gen", out, "--args=" .. table.concat(args, " ")})
        os.vrunv("ninja", {"-C", out, "src/lib:lib"})
        os.cp(path.join(out, "lib", "libCHIP.a"), package:installdir("lib"))

        local framework = path.join(os.curdir(), "src", "darwin", "Framework", "CHIP")
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
        local sha = os.iorunv("git", {"-C", os.curdir(), "rev-parse", "--short", "HEAD"}):trim()
        io.writefile(path.join(staged, "git_commit_sha.h"),
                     string.format("#ifndef GIT_COMMIT_SHA_H\n#define GIT_COMMIT_SHA_H\n\n#define GIT_COMMIT_SHA \"%s\"\n\n#endif /* GIT_COMMIT_SHA_H */\n", sha))

        local search = {path.join(out, "framework"), path.join(out, "gen", "include"),
                        path.join(os.curdir(), "src"), path.join(os.curdir(), "src", "include"),
                        path.join(os.curdir(), "zzz_generated"), path.join(os.curdir(), "zzz_generated", "app-common"),
                        path.join(os.curdir(), "third_party", "nlassert", "repo", "include"),
                        path.join(os.curdir(), "third_party", "nlio", "repo", "include")}
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
        table.insert(cxxflags, "-I" .. framework)
        local cxx = assert(toolchain:tool("cxx"), "the apple-ios toolchain names no C++ compiler for %s", package:arch())
        for _, rel in ipairs(appsources) do
            local object = path.absolute(path.join("framework", rel .. ".o"))
            os.mkdir(path.directory(object))
            os.vrunv(cxx, table.join(cxxflags, {"-c", path.join(os.curdir(), rel), "-o", object}))
            table.insert(objects, object)
        end

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
        raise("matter links libMatterBackports against the Backports libraries, which are project targets a package cannot depend on yet; see docs/explanation/backports-loading.md")
        local output = path.join(package:installdir("lib"), "libMatterBackports.dylib")
        os.vrunv(assert(toolchain:tool("mxx"), "the apple-ios toolchain names no Objective-C++ compiler for %s", package:arch()),
                 table.join(flags, {"-fuse-ld=" .. path.join(package:dep("ld64"):installdir("bin"), "ld"),
                                    "-dynamiclib", "-install_name", "/usr/lib/revenant/org.revenant.backports/libMatterBackports.dylib",
                                    "-o", output, path.join(out, "lib", "libCHIP.a")}, objects,
                           {"-L" .. libcxx, "-lc++abi", "-lc++",
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
