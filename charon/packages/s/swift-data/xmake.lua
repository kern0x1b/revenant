package("swift-data")
    set_homepage("https://github.com/kern0x1b/charon")
    set_description("SwiftData for the port's armv7 releases: Schema, ModelConfiguration, ModelContainer, ModelContext, FetchDescriptor and PersistentIdentifier over the device's own Core Data. The Swift module is built against the charon@swift-runtime a port carries, so a program writes `import SwiftData`. The storage layer is the Core Data of the release: NSPersistentContainer and NSPersistentStoreDescription from iOS 6.0 are the substrate, and this package adds the SwiftData API as a layer on top.")
    set_license("Apache-2.0")
    set_policy("package.strict_compatibility", true)

    -- One Swift module: SwiftData
    local modules = {"SwiftData"}

    add_configs("shared", {description = "Compile against a shared swift-runtime and its packaged libc++, for a port that requires them so.", default = false, type = "boolean"})
    add_configs("backports", {description = "Compile against the swift-runtime built with the backports, for a port that requires it so.", default = false, type = "boolean"})
    add_configs("backports_uikit", {description = "With backports: the runtime whose UIKit overlay is linked to the UIKit backports.", default = false, type = "boolean"})

    -- The recipe and the sources it builds, hashed: a changed file is a different package with its
    -- own install path, so a band changing a file here does not collide with a build of the old one
    -- in the shared store. A comment or a reordering is deliberately outside the digest.
    local digested = {"xmake.lua"}
    table.sort(digested)
    local digests = {}
    for _, name in ipairs(digested) do
        local file = path.join(os.scriptdir(), name)
        table.insert(digests, name .. "=" .. hash.sha256(file))
    end
    add_configs("recipe", {description = "The digest of this recipe, so a changed recipe is a different package.", default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    on_load("iphoneos", function (package)
        -- The runtime a port takes, and the one this is compiled against: the modules are read
        -- against that runtime's own resource directory, so the module and the program cannot
        -- disagree about which Swift they are.
        package:add("deps", "charon@swift-runtime", {alias = "swift-runtime", configs = {shared = package:config("shared") or nil,
                    backports = package:config("backports") or nil, backports_uikit = package:config("backports_uikit") or nil}})
        -- Core Data for the storage layer, Foundation for the model types
        package:add("frameworks", "CoreData", "Foundation", "CoreFoundation")
        -- `Predicate` and `SortOrder` are in FoundationEssentials and `SortDescriptor` in
        -- FoundationInternationalization, so FetchDescriptor's predicate and sortBy and
        -- HistoryDescriptor's are swift-foundation's own release types, taken from that package
        -- and not re-declared here. Its series has to land before this package builds.
        package:add("deps", "charon@swift-foundation", {alias = "swift-foundation"})
    end)

    on_install("iphoneos", function (package)
        local modules_root = path.join(package:scriptdir(), "..", "..", "..", "modules")
        local swift = import("apple.swift", {rootdir = modules_root, anonymous = true})
        local toolchain = assert(package:toolchains(), "SwiftData is built with the apple-ios toolchain")[1]
        toolchain:load()
        local runtime = assert(package:dep("swift-runtime"), "SwiftData is compiled against charon@swift-runtime")
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

        -- One module at a time. Availability checking stays on.
        local port_headers = table.wrap((runtime:envs() or {}).CHARON_SWIFT_PORT_HEADERS)
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
            -- A static archive rather than a dylib: the code is Swift with no ABI stability, it is
            -- linked into the program that uses it, and a dylib would be one more load command for
            -- a library that has exactly one caller per program.
            os.vrunv(toolchain:tool("ar"), {"-rcs", path.join(package:installdir(), "lib", "lib" .. module .. ".a"),
                         path.join(objects, module .. ".o")})
        end

        -- What a port needs to compile against this: the module folders, and nothing else. The
        -- archives are found through `links` above, the way every other library in a port is.
        package:setenv("CHARON_SWIFT_MODULES", install)
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

        -- Verify the Core Data symbols this package's Swift module will link against
        -- are present in the release's dyld cache. The Swift module uses:
        -- NSPersistentContainer, NSPersistentStoreDescription, NSManagedObjectContext,
        -- NSFetchRequest, NSEntityDescription, NSManagedObject, NSPersistentStoreCoordinator
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

        -- The ten symbols FetchDescriptor's predicate and sortBy, HistoryDescriptor's and
        -- DataStoreBatchDeleteRequest's are swift-foundation's, and while charon@swift-foundation
        -- is not in the store there is no library that declares them, so the link fails on exactly
        -- these and nothing else. The check is two-sided and in harness/symbols.lua: a NAMED symbol
        -- that is no longer undefined means the library landed or the code stopped using it, and an
        -- UNLISTED symbol of either of the two modules means a new one is used. The previous version
        -- counted the symbols not found and compared that to the number in the list, which is
        -- always true and so was a tautology - the review was right about it.
        os.envs("CHARON_SWIFTDATA_OBJECT", path.join(package:installdir(), "lib", "libSwiftData.a"))
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