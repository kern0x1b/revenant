package("swift-system")
    set_homepage("https://github.com/apple/swift-system")
    set_description("swift-system 1.8.1, Apple's System module (FilePath, Errno, FileDescriptor and the calls under them): the release sources pinned by sha256, patched for the port, built for armv7 iOS 6.1.3 in Lua the way combine is, with the host differential against Apple's System. Apache-2.0 upstream")
    set_license("Apache-2.0")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/apple/swift-system/archive/refs/tags/$(version).tar.gz")
    add_versions("1.8.1", "5610bea8f1f390895137247e7e6aa6bf89a6cd108d75d3368aba5da3f06f0d7a")

    local digests = {}
    local inputs = {os.scriptdir() .. "/xmake.lua"}
    for _, patch in ipairs(os.files(os.scriptdir() .. "/patches/*.patch")) do
        table.insert(inputs, patch)
    end
    local compat = path.join(os.scriptdir(), "..", "..", "..", "toolchain", "src", "apple-compat")
    for _, name in ipairs({"openat", "unlinkat", "fdopendir", "fstatat"}) do
        table.insert(inputs, path.join(compat, "src", name .. ".c"))
    end
    for _, file in ipairs(os.files(path.join(compat, "include", "revenant", "*.h"))) do
        table.insert(inputs, file)
    end
    table.sort(inputs)
    for _, file in ipairs(inputs) do
        table.insert(digests, path.filename(file) .. "=" .. hash.sha256(file))
    end
    add_configs("sources", {description = "The digest of this recipe, its patches and the apple-compat calls it builds, so a changed step is a different package.",
                            default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    on_load("iphoneos", function (package)
        package:add("deps", "revenant@swift-runtime", {alias = "swift-runtime", configs = {backports = true}})
        package:add("deps", "revenant@apple-compat", {alias = "apple-compat"})
        package:add("deps", "revenant@ld64", {alias = "ld64"})
        package:add("links", "swiftSystem")
        package:add("linkdirs", "lib")
    end)

    on_install("iphoneos", function (package)
        local swift = import("@addon.revenant.apple.swift", {anonymous = true})
        local toolchain = assert(package:toolchains(), "swift-system is built with the apple-ios toolchain")[1]
        toolchain:load()
        local runtime = assert(package:dep("swift-runtime"), "swift-system is compiled against revenant@swift-runtime")
        local compat = import("@addon.revenant.data", {anonymous = true}).src("apple-compat")
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

        local availability = {"-enable-experimental-feature", "AvailabilityMacro=System 0.0.1:macOS 10.10, iOS 6.1.3"}
        for _, release in ipairs({"0.0.2", "0.0.3", "1.1.0", "1.1.1", "1.2.0", "1.2.1", "1.3.0", "1.3.1", "1.3.2", "1.4.0", "1.7.0", "199"}) do
            table.join2(availability, {"-enable-experimental-feature", "AvailabilityMacro=System " .. release .. ":macOS 10.10, iOS 6.1.3"})
        end
        local sources = {}
        for _, file in ipairs(os.files(path.join(tree, "Sources", "System", "**.swift"))) do
            if not file:find("/IORing/", 1, true) then
                table.insert(sources, file)
            end
        end
        table.sort(sources)
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
        local ld64 = path.join(package:dep("ld64"):installdir("bin"), "ld")
        os.vrunv(toolchain:tool("cc"), table.join({"-target", triple, "-isysroot", sdk, "-miphoneos-version-min=" .. minimum,
                 "-fuse-ld=" .. ld64, "-dynamiclib", "-install_name", "@rpath/libswiftSystem.dylib", "-o", lib}, os.files(path.join(objects, "*.o")),
                 {"-L", path.join(resources, "iphoneos"), "-lswiftCore", "-lswiftDarwin", "-lswiftObjectiveC", "-lswiftDispatch",
                  "-lswift_Concurrency"}))
        os.cp(lib, package:installdir("lib"))

        os.cp(path.join(os.scriptdir(), "tests", "differential"), package:installdir("share"))
        package:setenv("REVENANT_SWIFT_MODULES", path.join(package:installdir("lib"), "swift", "iphoneos"), path.join(tree, "Sources", "CSystem", "include"))
        print("%s: %s installed; libswiftSystem.dylib is in %s", package:name(), package:version_str(), package:installdir("lib"))
    end)

    on_test(function (package)
        local dyld = import("@addon.revenant.apple.dyld", {anonymous = true})
        local toolchain = assert(package:toolchains(), "swift-system is built with the apple-ios toolchain")[1]
        toolchain:load()
        local runtime = assert(package:dep("swift-runtime"), "swift-system is compiled against revenant@swift-runtime")
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
        local differs = import("@addon.revenant.apple.runtime_guards", {anonymous = true}).compare(found, {
            imports = read.imports, exported = read.exported, minimum = minimum, backports = true, exact = true})
        assert(#differs == 0, "libswiftSystem.dylib's weak imports and its guard rows differ at " .. minimum .. " with the backports:\n  " .. table.concat(differs, "\n  "))
    end)
