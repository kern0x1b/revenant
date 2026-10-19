package("swift-data")
    set_homepage("https://github.com/kern0x1b/revenant/tree/main/toolchain")
    set_description("SwiftData for the port's armv7 releases: Schema, ModelConfiguration, ModelContainer, ModelContext, FetchDescriptor and PersistentIdentifier over the device's own Core Data. The Swift module is built against the revenant@swift-runtime a port carries, so a program writes `import SwiftData`. The storage layer is the Core Data of the release: NSPersistentContainer and NSPersistentStoreDescription from iOS 6.0 are the substrate, and this package adds the SwiftData API as a layer on top.")
    set_license("Apache-2.0")
    set_policy("package.strict_compatibility", true)

    local modules = {"SwiftData"}

    add_configs("shared", {description = "Compile against a shared swift-runtime and its packaged libc++, for a port that requires them so.", default = false, type = "boolean"})
    add_configs("backports", {description = "Compile against the swift-runtime built with the backports, for a port that requires it so.", default = false, type = "boolean"})
    add_configs("backports_uikit", {description = "With backports: the runtime whose UIKit overlay is linked to the UIKit backports.", default = false, type = "boolean"})

    local digested = {"xmake.lua"}
    table.sort(digested)
    local digests = {}
    for _, name in ipairs(digested) do
        local file = path.join(os.scriptdir(), name)
        table.insert(digests, name .. "=" .. hash.sha256(file))
    end
    add_configs("recipe", {description = "The digest of this recipe, so a changed recipe is a different package.", default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    on_load("iphoneos", function (package)
        package:add("deps", "revenant@swift-runtime", {alias = "swift-runtime", configs = {shared = package:config("shared") or nil,
                    backports = package:config("backports") or nil, backports_uikit = package:config("backports_uikit") or nil}})
        package:add("frameworks", "CoreData", "Foundation", "CoreFoundation")
        package:add("deps", "revenant@swift-foundation", {alias = "swift-foundation"})
    end)

    on_install("iphoneos", function (package)
        local modules_root = path.join(package:scriptdir(), "..", "..", "..", "modules")
        local swift = import("apple.swift", {rootdir = modules_root, anonymous = true})
        local toolchain = assert(package:toolchains(), "SwiftData is built with the apple-ios toolchain")[1]
        toolchain:load()
        local runtime = assert(package:dep("swift-runtime"), "SwiftData is compiled against revenant@swift-runtime")
        local swiftc = assert(table.wrap((runtime:envs() or {}).SWIFT_EXEC)[1], "swift-runtime names no compiler; reinstall it")
        local minimum = toolchain:config("deployment")
        local triple = package:arch() .. "-apple-ios" .. minimum
        local sdk = toolchain:config("sdkdir")
        local install = path.join(package:installdir(), "lib", "swift", "iphoneos")
        local objects = path.absolute("objects")
        os.mkdir(objects)
        os.mkdir(install)

        local sources = {}
        for _, module in ipairs(modules) do
            table.insert(sources, path.join(package:scriptdir(), "files", module, "*.swift"))
        end

        local port_headers = table.wrap((runtime:envs() or {}).REVENANT_SWIFT_PORT_HEADERS)
        local overlay = #port_headers > 0 and {"-vfsoverlay", table.concat(port_headers, path.envsep())} or {}
        for _, module in ipairs(modules) do
            local folder = path.join(install, module .. ".swiftmodule")
            os.mkdir(folder)
            local argv = table.join(swift.runtime_flags({
                architecture = package:arch(), deployment = minimum, sdk = sdk,
                resources = path.join(runtime:installdir(), "lib", "swift"),
                plugins = table.wrap((runtime:envs() or {}).SWIFT_PLUGIN_PATH)[1],
                module = module, optimize = "fastest", prefix_map = os.curdir() .. "=/swift-data"}),
                overlay, {"-I", install, "-emit-module", "-emit-module-path",
                 path.join(folder, package:arch() .. "-apple-ios.swiftmodule"), "-c"},
                os.files(sources[1]), {"-o", path.join(objects, module .. ".o")})
            os.vrunv(swiftc, argv)
            os.vrunv(toolchain:tool("ar"), {"-rcs", path.join(package:installdir(), "lib", "lib" .. module .. ".a"),
                         path.join(objects, module .. ".o")})
        end

        package:setenv("REVENANT_SWIFT_MODULES", install)
        os.cp(path.join(package:scriptdir(), "README.md"), package:installdir())
    end)

    on_test(function (package)
        local toolchain = assert(package:toolchains(), "SwiftData is built with the apple-ios toolchain")[1]
        toolchain:load()
        local install = path.join(package:installdir(), "lib", "swift", "iphoneos")
        for _, module in ipairs(modules) do
            assert(os.isdir(path.join(install, module .. ".swiftmodule")),
                   "SwiftData installs no " .. module .. " module")
            assert(os.isfile(path.join(package:installdir(), "lib", "lib" .. module .. ".a")),
                   "SwiftData installs no lib" .. module .. ".a")
        end

        local exported = os.iorunv("xcrun", {"nm", "-u", path.join(package:installdir(), "lib", "libSwiftData.a")})
        local required = {
            "_OBJC_CLASS_$_NSPersistentContainer",
            "_OBJC_CLASS_$_NSPersistentStoreDescription",
            "_OBJC_CLASS_$_NSManagedObjectContext",
            "_OBJC_CLASS_$_NSFetchRequest",
            "_OBJC_CLASS_$_NSEntityDescription",
            "_OBJC_CLASS_$_NSManagedObject",
            "_OBJC_CLASS_$_NSPersistentStoreCoordinator"
        }
        for _, symbol in ipairs(required) do
            assert(exported:find(symbol, 1, true),
                   "libSwiftData.a no longer imports " .. symbol ..
                   ", so a Core Data API was added without a fact behind it")
        end

        os.envs("REVENANT_SWIFTDATA_OBJECT", path.join(package:installdir(), "lib", "libSwiftData.a"))
        import("@self.harness.symbols")
        local names = symbols.undefined_names(exported)
        local ok, why = symbols.check_pending(names)
        assert(ok, why)
        local counts, order = symbols.classify(names)
        print("SwiftData: %d undefined, %d defined; pending %d swift-foundation symbols",
              #names, #exported - #names, #symbols.pending)
        for _, owner in ipairs(order) do
            print("SwiftData: %5d  %s", counts[owner], owner)
        end
    end)
