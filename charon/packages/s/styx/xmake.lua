package("styx")
    set_homepage("https://github.com/kern0x1b/styx")
    set_description("Styx, a Combine reimplementation for legacy Apple platforms, built against the charon@swift-runtime a port carries: one module named Combine (core, the Dispatch scheduler and the Foundation integration folded together) as a static library with its module, so a port writes `import Combine`. The URLSession publishers are not shipped (iOS 7, and they need a TLS stack); the iOS<7 run-loop-timer tolerance sits behind #available in the fork's own sources")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/kern0x1b/styx.git")
    -- The pin names the commit, and the licence it installs is the one at that commit: the upstream's
    -- MIT notice first, byte for byte, then what the fork adds. aea2b911 is 8793ca9 with only that.
    add_versions("2026.09.20", "aea2b9115261ddb201c3b6e50cf5a84060b87df3")

    -- Styx is compiled against the runtime a port takes, and the port links one build of it: what the port asks of the runtime
    -- it asks here too, and Styx passes it on, so that the modules are read against that runtime's own resource directory
    -- and the C++ helper is linked against the libc++ the runtime is. (charon@swift rule refuses a link with two builds.)
    add_configs("shared", {description = "Compile against a shared swift-runtime and its packaged libc++, for a port that requires them so.", default = false, type = "boolean"})
    add_configs("backports", {description = "Compile against the swift-runtime built with the backports, for a port that requires it so.", default = false, type = "boolean"})
    add_configs("backports_uikit", {description = "With backports: the runtime whose UIKit overlay is linked to the UIKit backports.", default = false, type = "boolean"})

    local digests = {}
    local sources = {path.join(os.scriptdir(), "xmake.lua"), path.join(os.scriptdir(), "files", "DispatchTimeDistance.swift")}
    for _, file in ipairs(sources) do
        table.insert(digests, path.filename(file) .. "=" .. hash.sha256(file))
    end
    -- files/CombineKit is the layer of our own that closes the gap between what the fork
    -- ships and what Apple's Combine declares; it is compiled into the same module, and
    -- every file of it is part of the recipe's digest, so a change to it is a different
    -- package with its own install path.
    for _, file in ipairs(os.files(path.join(os.scriptdir(), "files", "CombineKit", "**.swift"))) do
        table.insert(digests, path.filename(file) .. "=" .. hash.sha256(file))
    end
    add_configs("recipe", {description = "The digest of this recipe and the source it adds, so a changed recipe is a different package.", default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    local libraries = {"Combine", "CombineHelpers"}

    on_load("iphoneos", function (package)
        package:add("deps", "charon@swift-runtime", {alias = "swift-runtime", configs = {shared = package:config("shared") or nil,
                    backports = package:config("backports") or nil, backports_uikit = package:config("backports_uikit") or nil}})
        package:add("deps", "charon@libcxx", {alias = "libcxx", configs = {packaged = package:config("shared") or nil}})
        for _, library in ipairs(libraries) do
            package:add("links", library)
        end
        package:add("frameworks", "Foundation", "CoreFoundation")
    end)

    on_install("iphoneos", function (package)
        local modules = path.join(package:scriptdir(), "..", "..", "..", "modules")
        local swift = import("apple.swift", {rootdir = modules, anonymous = true})
        local toolchain = assert(package:toolchains(), "Styx is built with the apple-ios toolchain")[1]
        toolchain:load()
        local runtime = assert(package:dep("swift-runtime"), "Styx is compiled against charon@swift-runtime")
        local libcxx = assert(package:dep("libcxx"), "Styx's C++ helper is compiled against charon@libcxx")
        local swiftc = assert(table.wrap((runtime:envs() or {}).SWIFT_EXEC)[1], "swift-runtime names no compiler; reinstall it")
        local minimum = toolchain:config("deployment")
        local triple = package:arch() .. "-apple-ios" .. minimum
        local sdk = toolchain:config("sdkdir")
        local swiftdir = path.join(package:installdir("lib"), "swift", "iphoneos")
        local helpers = path.join("Sources", "CombineHelpers")
        local objects = path.absolute("objects")
        os.mkdir(objects)
        os.mkdir(swiftdir)

        -- The runtime's Dispatch overlay (Swift 5.4.3) has no DispatchTime.distance(to:);
        -- add it in the largest unit that fits an Int, as the scheduler needs it.
        os.cp(path.join(package:scriptdir(), "files", "DispatchTimeDistance.swift"), path.join("Sources", "Combine", "Schedulers"))

        -- The layer of our own, copied into the module tree so that it is compiled as part
        -- of the one `Combine` module and sees the fork's internal helpers.
        os.mkdir(path.join("Sources", "Combine", "CombineKit"))
        for _, file in ipairs(os.files(path.join(package:scriptdir(), "files", "CombineKit", "**.swift"))) do
            os.cp(file, path.join("Sources", "Combine", "CombineKit", path.filename(file)))
        end

        -- The C++ helper (locking primitives, combine-identifier counter).
        os.vrunv(toolchain:tool("cxx"), {"-target", triple, "-isysroot", sdk, "-nostdinc++", "-isystem",
                 path.join(libcxx:installdir("include"), "c++", "v1"), "-std=c++17", "-O2", "-include", "exception",
                 "-I", path.join(helpers, "include"), "-c", path.join(helpers, "CombineHelpers.cpp"),
                 "-o", path.join(objects, "CombineHelpers.o")})
        os.vrunv(toolchain:tool("ar"), {"-rcs", path.join(package:installdir("lib"), "libCombineHelpers.a"),
                 path.join(objects, "CombineHelpers.o")})
        os.cp(path.join(helpers, "include", "*"), path.join(package:installdir("include"), "CombineHelpers") .. "/")

        -- The single Combine module: core, the Dispatch scheduler and the Foundation
        -- integration in one compile. Availability checking stays on.
        local module = path.join(swiftdir, "Combine.swiftmodule")
        os.mkdir(module)
        local argv = table.join(swift.runtime_flags({
            architecture = package:arch(), deployment = minimum, sdk = sdk,
            resources = path.join(runtime:installdir(), "lib", "swift"),
            plugins = table.wrap((runtime:envs() or {}).SWIFT_PLUGIN_PATH)[1],
            module = "Combine", optimize = "fastest", prefix_map = os.curdir() .. "=/styx"}),
            {"-I", swiftdir, "-I", path.join(helpers, "include"), "-emit-module", "-emit-module-path",
             path.join(module, package:arch() .. "-apple-ios.swiftmodule"), "-c"},
            os.files(path.join("Sources", "Combine", "**.swift")), {"-o", path.join(objects, "Combine.o")})
        os.vrunv(swiftc, argv)
        os.vrunv(toolchain:tool("ar"), {"-rcs", path.join(package:installdir("lib"), "libCombine.a"), path.join(objects, "Combine.o")})

        package:setenv("CHARON_SWIFT_MODULES", swiftdir, path.join(package:installdir("include"), "CombineHelpers"))
        os.cp("LICENSE", package:installdir("licenses"))
    end)
