package("network")
    set_homepage("https://github.com/kern0x1b/revenant/tree/main/frameworks/Backports")
    set_description("The Network framework's Swift module as one dylib a port writes `import Network` for, built against the revenant@swift-runtime a port carries: the endpoints, the path monitor, and connections over TCP and UDP sockets; TLS is not yet backported")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)
    add_configs("apple_sdk", {description = "The iPhoneOS SDK the generated project names: the one the consumer installed, so the package is not built against a second SDK.", type = "string"})

    includes(path.join(os.scriptdir(), "port", "digest.lua"))
    add_configs("sources", {description = "The digest of this recipe and the module's sources, so a changed declaration is a different package.", default = network_sources_digest, type = "string", readonly = true})

    add_configs("evolution", {description = "arm64 only: compile the path monitor of the module (NWPathMonitor, NWPath, NWInterface, NWEndpoint and the two IP address types) directly with swiftc and library evolution, against the swift-runtime built with it, and link libswiftNetwork.dylib on SystemConfiguration, so the symbols of the Network that a program compiled by the SDK's Swift binds to resolve (its enums and protocol requirements are resilient). Connections, listeners and the protocol options are not built, and no backports package is built.", default = false, type = "boolean"})

    local EVOLUTION_SOURCES = {"IPv4Address", "IPv6Address", "NWEndpoint", "NWInterface", "NWPathMonitor"}

    on_load("iphoneos", function (package)
        assert(not package:config("evolution") or package:is_arch("arm64"), "network with evolution is an arm64 guest build")
        package:add("deps", "revenant@swift-runtime", {alias = "swift-runtime", configs = {library_evolution = package:config("evolution") or nil}})
        if package:config("evolution") then
            package:add("deps", "revenant@ld64", {alias = "ld64"})
            package:add("linkdirs", "lib")
        end
        package:add("links", "swiftNetwork")
    end)

    on_install("iphoneos", function (package)
        local root = path.translate(path.join(package:scriptdir(), "..", "..", ".."))
        if package:config("evolution") then
            local swift = import("@addon.revenant.apple.swift", {anonymous = true})
            local toolchain = assert(package:toolchains(), "network is built with the apple-ios toolchain")[1]
            toolchain:load()
            local runtime = assert(package:dep("swift-runtime"), "network is compiled against revenant@swift-runtime")
            local swiftc = assert(table.wrap((runtime:envs() or {}).SWIFT_EXEC)[1], "swift-runtime names no compiler; reinstall it")
            local sdk = toolchain:config("sdkdir")
            local resources = path.join(runtime:installdir(), "lib", "swift")
            local triple = package:arch() .. "-apple-ios7.0"
            local common = {"-target", triple, "-isysroot", sdk, "-miphoneos-version-min=7.0"}
            local objects = package:installdir("objects", "network")
            os.mkdir(objects)
            local modules = path.join(package:installdir("lib"), "swift", "iphoneos")
            os.mkdir(path.join(modules, "Network.swiftmodule"))
            local sources = {}
            for _, name in ipairs(EVOLUTION_SOURCES) do
                table.insert(sources, path.join(root, "frameworks", "Backports", "src", "Network", name .. ".swift"))
            end
            local argv = swift.runtime_flags({architecture = package:arch(), deployment = "7.0", sdk = sdk, resources = resources, module = "Network"})
            table.join2(argv, {"-swift-version", "5", "-parse-as-library", "-O", "-wmo", "-c", "-enable-library-evolution",
                               "-module-name", "Network", "-I", path.join(resources, "iphoneos"),
                               "-module-cache-path", path.join(objects, "modulecache"),
                               "-emit-module", "-emit-module-path", path.join(modules, "Network.swiftmodule", package:arch() .. "-apple-ios.swiftmodule")},
                        sources, {"-o", path.join(objects, "Network.o")})
            os.vrunv(swiftc, argv)
            local markers = path.join(objects, "autolink_markers.c")
            io.writefile(markers, table.concat({
                "__attribute__((visibility(\"hidden\"))) const char _swift_FORCE_LOAD_$_swiftXPC = 0;",
                "__attribute__((visibility(\"hidden\"))) const char _swift_FORCE_LOAD_$_swift_Builtin_float = 0;",
                ""}, "\n"))
            os.vrunv(toolchain:tool("cc"), table.join(common, {"-Os", "-c", markers, "-o", path.join(objects, "autolink_markers.o")}))
            local ld64 = path.join(package:dep("ld64"):installdir("bin"), "ld")
            local lib = path.join(objects, "libswiftNetwork.dylib")
            os.vrunv(toolchain:tool("cc"), table.join(common, {"-fuse-ld=" .. ld64, "-dynamiclib", "-install_name", "@rpath/libswiftNetwork.dylib",
                     "-Wl,-dead_strip_dylibs", "-o", lib}, os.files(path.join(objects, "*.o")),
                     {"-L", path.join(resources, "iphoneos"),
                      "-lswiftCore", "-lswiftDarwin", "-lswiftObjectiveC", "-lswiftDispatch", "-lswift_Concurrency",
                      "-lswiftFoundation", "-framework", "SystemConfiguration"}))
            os.cp(lib, package:installdir("lib"))
            os.cp(path.join(objects, "Network.o"), path.join(package:installdir("lib"), "Network.o"))
            package:setenv("REVENANT_SWIFT_MODULES", modules)
            print("%s: libswiftNetwork.dylib is in %s", package:name(), package:installdir("lib"))
            return
        end
        import("@addon.revenant.apple.wrapper", {anonymous = true}).install(package, {root = root,
            includes = {path.join(root, "frameworks", "Backports", "src", "Swift")}, targets = {"swiftNetwork"}, modules = true})
        local modules = path.join(package:installdir("lib"), "swift", "iphoneos")
        local clang = path.join(root, "frameworks", "Backports", "src", "Network", "RevenantNetworkC")
        os.cp(path.join(clang, "module.modulemap"), modules)
        os.cp(path.join(clang, "RevenantNetworkC.h"), modules)
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libswiftNetwork.dylib")))
        assert(os.isdir(path.join(package:installdir("lib"), "swift", "iphoneos", "Network.swiftmodule")))
        if not package:config("evolution") then
            assert(os.isfile(path.join(package:installdir("lib"), "swift", "iphoneos", "module.modulemap")))
            assert(os.isfile(path.join(package:installdir("lib"), "swift", "iphoneos", "RevenantNetworkC.h")))
        end
    end)
