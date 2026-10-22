package("swift-data")
    set_homepage("https://github.com/kern0x1b/revenant/tree/main/frameworks/Backports")
    set_description("SwiftData for the port's armv7 releases: Schema, ModelConfiguration, ModelContainer, ModelContext, FetchDescriptor and PersistentIdentifier over the device's own Core Data, built against the revenant@swift-runtime a port carries")
    set_license("Apache-2.0")
    set_policy("package.strict_compatibility", true)
    add_configs("apple_sdk", {description = "The iPhoneOS SDK the generated project names: the one the consumer installed, so the package is not built against a second SDK.", default = "16.4", type = "string"})

    includes(path.join(os.scriptdir(), "port", "digest.lua"))
    add_configs("recipe", {description = "The digest of this recipe and the SwiftData sources it builds, so a changed declaration is a different package.", default = swift_data_sources_digest, type = "string", readonly = true})

    on_load("iphoneos", function (package)
        local toolchain = assert(package:toolchains(), "swift-data is built with the apple-ios toolchain")[1]
        toolchain:load()
        raise("swift-data is not yet backported to iOS %s: DefaultStore.swift imports FoundationEssentials, which the iOS 6 SDK does not provide; see the open gaps in frameworks/Backports/README.md", toolchain:config("deployment"))
        package:add("deps", "revenant@swift-runtime", {alias = "swift-runtime"})
        package:add("links", "SwiftData")
        package:add("frameworks", "CoreData", "Foundation", "CoreFoundation")
    end)

    on_install("iphoneos", function (package)
        local root = path.translate(path.join(package:scriptdir(), "..", "..", ".."))
        import("@addon.revenant.apple.wrapper", {anonymous = true}).install(package, {root = root,
            includes = {path.join(root, "frameworks", "Backports", "src", "Swift")}, targets = {"SwiftData"}, modules = true})
    end)

    on_test(function (package)
        local root = path.translate(path.join(package:scriptdir(), "..", "..", ".."))
        local lib = path.join(package:installdir(), "lib")
        assert(os.isdir(path.join(lib, "swift", "iphoneos", "SwiftData.swiftmodule")), "SwiftData installs no SwiftData module")
        assert(os.isfile(path.join(lib, "libSwiftData.a")), "SwiftData installs no libSwiftData.a")
        local exported = os.iorunv("xcrun", {"nm", "-u", path.join(lib, "libSwiftData.a")})
        local required = {"_OBJC_CLASS_$_NSPersistentContainer", "_OBJC_CLASS_$_NSPersistentStoreDescription",
                          "_OBJC_CLASS_$_NSManagedObjectContext", "_OBJC_CLASS_$_NSFetchRequest", "_OBJC_CLASS_$_NSEntityDescription",
                          "_OBJC_CLASS_$_NSManagedObject", "_OBJC_CLASS_$_NSPersistentStoreCoordinator"}
        for _, symbol in ipairs(required) do
            assert(exported:find(symbol, 1, true), "libSwiftData.a no longer imports " .. symbol .. ", so a Core Data API was added without a fact behind it")
        end
        os.envs("REVENANT_SWIFTDATA_OBJECT", path.join(lib, "libSwiftData.a"))
        local symbols = import("symbols", {rootdir = path.join(root, "frameworks", "Backports", "tests", "SwiftData", "harness"), anonymous = true})
        local names = symbols.undefined_names(exported)
        local ok, why = symbols.check_pending(names)
        assert(ok, why)
    end)
