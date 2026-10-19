package("swift-system")
    set_homepage("https://github.com/apple/swift-system")
    set_description("swift-system 1.8.1, Apple's System module (FilePath, Errno, FileDescriptor and the calls under them): the release sources pinned by sha256, patched for the port, built for armv7 iOS 6.1.3 in Lua the way styx is, with the host differential against Apple's System. Apache-2.0 upstream")
    set_license("Apache-2.0")
    set_policy("package.strict_compatibility", true)

    -- The release tarball of the tag 1.8.1 (the tag names commit 869129b7bf), pinned by its sha256 as the other recipes pin theirs.
    add_urls("https://github.com/apple/swift-system/archive/refs/tags/$(version).tar.gz")
    add_versions("1.8.1", "5610bea8f1f390895137247e7e6aa6bf89a6cd108d75d3368aba5da3f06f0d7a")

    -- The identity of this recipe: a changed recipe, patch or shim is a different package, so nothing has to be removed from
    -- the shared store. The apple-compat calls the module is compiled with are part of it: they are built from the charon tree.
    local digests = {}
    local inputs = {os.scriptdir() .. "/xmake.lua"}
    for _, patch in ipairs(os.files(os.scriptdir() .. "/patches/*.patch")) do
        table.insert(inputs, patch)
    end
    local compat = path.join(os.scriptdir(), "..", "..", "a", "apple-compat")
    for _, name in ipairs({"openat", "unlinkat", "fdopendir", "fstatat"}) do
        table.insert(inputs, path.join(compat, "src", name .. ".c"))
    end
    for _, file in ipairs(os.files(path.join(compat, "include", "charon", "*.h"))) do
        table.insert(inputs, file)
    end
    table.sort(inputs)
    for _, file in ipairs(inputs) do
        table.insert(digests, path.filename(file) .. "=" .. hash.sha256(file))
    end
    add_configs("sources", {description = "The digest of this recipe, its patches and the apple-compat calls it builds, so a changed step is a different package.",
                            default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    -- The module is compiled against the runtime a port carries, and against apple-compat's headers for the calls 6.1.3 lacks.
    on_load("iphoneos", function (package)
        -- The runtime with backports, the configuration of the runtime a program carries (a program links one build of it).
        package:add("deps", "charon@swift-runtime", {alias = "swift-runtime", configs = {backports = true}})
        package:add("deps", "charon@apple-compat", {alias = "apple-compat"})
        package:add("deps", "charon@ld64", {alias = "ld64"})
        -- What a consumer links: the dylib, found in the package's lib folder.
        package:add("links", "swiftSystem")
        package:add("linkdirs", "lib")
    end)

    -- Installs upstream's tree with this recipe's patches applied, the module compiled from it as objects with -c against the
    -- runtime's own resource dir and linked with the port's linker into libswiftSystem.dylib (the way styx and rules/swift build),
    -- and the host differential against Apple's System. The calls 6.1.3 lacks come from apple-compat (fstatat, unlinkat,
    -- fdopendir, through F_GETPATH); the mach port guards are weak references in csystem_port.c.
    on_install("iphoneos", function (package)
        local modules = path.join(package:scriptdir(), "..", "..", "..", "modules")
        local swift = import("apple.swift", {rootdir = modules, anonymous = true})
        local toolchain = assert(package:toolchains(), "swift-system is built with the apple-ios toolchain")[1]
        toolchain:load()
        local runtime = assert(package:dep("swift-runtime"), "swift-system is compiled against charon@swift-runtime")
        local compat = path.join(package:scriptdir(), "..", "..", "..", "packages", "a", "apple-compat")
        local swiftc = assert(table.wrap((runtime:envs() or {}).SWIFT_EXEC)[1], "swift-runtime names no compiler; reinstall it")
        local minimum = toolchain:config("deployment")
        local triple = package:arch() .. "-apple-ios" .. minimum
        local sdk = toolchain:config("sdkdir")
        local resources = path.join(runtime:installdir(), "lib", "swift")
        local tree = package:installdir("src")
        local objects = path.absolute("objects")
        os.mkdir(objects)

        os.cp(path.join(os.curdir(), "*"), tree)
        for _, patch in ipairs(os.files(path.join(os.scriptdir(), "patches", "*.patch"))) do
            os.vrunv("patch", {"-d", tree, "-p1", "-s", "-i", patch})
        end
        local csystem = path.join(tree, "Sources", "CSystem")
        local cflags = {"-target", triple, "-isysroot", sdk, "-miphoneos-version-min=" .. minimum,
                        "-I", path.join(csystem, "include"), "-I", path.join(compat, "include")}
        for _, file in ipairs(table.join(
                os.files(path.join(compat, "src", "openat.c")), os.files(path.join(compat, "src", "unlinkat.c")),
                os.files(path.join(compat, "src", "fdopendir.c")), os.files(path.join(compat, "src", "fstatat.c")),
                os.files(path.join(csystem, "shims.c")), os.files(path.join(csystem, "csystem_port.c")))) do
            os.vrunv(toolchain:tool("cc"), table.join(cflags, {"-c", file, "-o", path.join(objects, path.basename(file) .. ".o")}))
        end

        -- Availability: upstream's Package.swift asks for iOS 8.0 and up, but its own declarations (FilePath, Errno, CInterop)
        -- are used unannotated inside the module, so at a 6.1.3 target that is a compile error (measured: 13 SystemString.swift
        -- errors, and more); every release maps to iOS 6.1.3, and the libSystem import check says which calls 6.1.3 lacks.
        local availability = {"-enable-experimental-feature", "AvailabilityMacro=System 0.0.1:macOS 10.10, iOS 6.1.3"}
        for _, release in ipairs({"0.0.2", "0.0.3", "1.1.0", "1.1.1", "1.2.0", "1.2.1", "1.3.0", "1.3.1", "1.3.2", "1.4.0", "1.7.0", "199"}) do
            table.join2(availability, {"-enable-experimental-feature", "AvailabilityMacro=System " .. release .. ":macOS 10.10, iOS 6.1.3"})
        end
        -- The IORing sources are not part of the 1.8.1 module this package builds (they are excluded from the shell build too).
        local sources = {}
        for _, file in ipairs(os.files(path.join(tree, "Sources", "System", "**.swift"))) do
            if not file:find("/IORing/", 1, true) then
                table.insert(sources, file)
            end
        end
        table.sort(sources)
        -- The module carries upstream's target name, SystemPackage, which is what a consumer imports (Apple's System is the host's).
        local module = path.join(package:installdir("lib"), "swift", "iphoneos", "SystemPackage.swiftmodule")
        os.mkdir(module)
        local argv = swift.runtime_flags({architecture = package:arch(), deployment = minimum, sdk = sdk, resources = resources,
                                          module = "SystemPackage"})
        table.join2(argv, {"-swift-version", "6", "-enable-experimental-feature", "Lifetimes", "-D", "SYSTEM_PACKAGE_DARWIN",
                           "-D", "SYSTEM_PACKAGE", "-I", path.join(csystem, "include"), "-I", path.join(compat, "include"),
                           "-Xfrontend", "-disable-autolinking-runtime-compatibility-concurrency",
                           "-Xfrontend", "-disable-autolinking-runtime-compatibility-dynamic-replacements"}, availability,
                           {"-emit-module", "-emit-module-path", path.join(module, package:arch() .. "-apple-ios.swiftmodule"), "-c"},
                           sources, {"-o", path.join(objects, "SystemPackage.o")})
        os.vrunv(swiftc, argv)

        local lib = path.join(objects, "libswiftSystem.dylib")
        -- Linked through the clang driver with charon@ld64 as its linker, the way packages/m/matter links (-fuse-ld): the host ld
        -- rejects libswiftCore's immortal refcount layout ("vmOffset too large", revision 2 and the revision-4 install log).
        local ld64 = path.join(package:dep("ld64"):installdir("bin"), "ld")
        os.vrunv(toolchain:tool("cc"), table.join({"-target", triple, "-isysroot", sdk, "-miphoneos-version-min=" .. minimum,
                 "-fuse-ld=" .. ld64, "-dynamiclib", "-install_name", "@rpath/libswiftSystem.dylib", "-o", lib}, os.files(path.join(objects, "*.o")),
                 {"-L", path.join(resources, "iphoneos"), "-lswiftCore", "-lswiftDarwin", "-lswiftObjectiveC", "-lswiftDispatch",
                  "-lswift_Concurrency"}))
        os.cp(lib, package:installdir("lib"))

        os.cp(path.join(os.scriptdir(), "tests", "differential"), package:installdir("share"))
        -- What a program that imports SystemPackage compiles against: the module folder, and the folder of CSystem's module map
        -- (SystemPackage imports CSystem; measured: without it a consumer fails with "missing required module 'CSystem'").
        -- The map is the one the module was built with: its headers are guarded per platform.
        package:setenv("CHARON_SWIFT_MODULES", path.join(package:installdir("lib"), "swift", "iphoneos"), path.join(tree, "Sources", "CSystem", "include"))
        print("%s: %s installed; libswiftSystem.dylib is in %s", package:name(), package:version_str(), package:installdir("lib"))
    end)

    -- The library's weak imports and the rows apple.runtime_guards declares for it are one set, both ways: a weak import no row
    -- names is refused in a program that carries the library, and a row the build does not import records a guard it does not
    -- have. Read the way swift-runtime's on_test reads its own table, against the runtime it is linked with.
    on_test(function (package)
        local modules = path.join(package:scriptdir(), "..", "..", "..", "modules")
        local dyld = import("apple.dyld", {rootdir = modules, anonymous = true})
        local toolchain = assert(package:toolchains(), "swift-system is built with the apple-ios toolchain")[1]
        toolchain:load()
        local runtime = assert(package:dep("swift-runtime"), "swift-system is compiled against charon@swift-runtime")
        local installed = path.join(package:installdir("lib"), "libswiftSystem.dylib")
        local read = dyld.image_imports({installed}, os.files(path.join(runtime:installdir("lib"), "swift", "iphoneos", "*.dylib")), package:arch())
        local names = {}
        for symbol, weak in pairs(read.imports["libswiftSystem.dylib"]) do
            if weak and not read.exported[symbol] then
                names[symbol] = true
            end
        end
        local found = {["libswiftSystem.dylib"] = table.orderkeys(names)}
        local minimum = toolchain:config("deployment")
        local differs = import("apple.runtime_guards", {rootdir = modules, anonymous = true}).compare(found, {
            imports = read.imports, exported = read.exported, minimum = minimum, backports = true, exact = true})
        assert(#differs == 0, "libswiftSystem.dylib's weak imports and its guard rows differ at " .. minimum .. " with the backports:\n  " .. table.concat(differs, "\n  "))
    end)
