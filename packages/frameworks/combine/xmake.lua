package("combine")
    set_homepage("https://github.com/kern0x1b/revenant/tree/main/frameworks/Combine")
    set_description("Combine, Combine for legacy Apple platforms: OpenCombine at a commit with our patches, its core, Dispatch and Foundation sources compiled against the revenant@swift-runtime a port carries as one module named Combine, a static library with its module, so a port writes `import Combine`. The URLSession data task publisher is declared from iOS 7, and the run loop timer's tolerance is read and set behind #available")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/OpenCombine/OpenCombine.git")
    add_versions("2026.10.19", "1c6f02c7ed8140c0ba7a783aaddb6e0685a0037b")

    local patches = {
        {"0001-Fold-the-Dispatch-and-Foundation-modules-into-one-mo.patch", "d9c559f1f0b9eb59ec4e2c485e12246b97824ef306c0afc58a6a7aa7c1b30a6f"},
        {"0002-Take-DispatchTime-distances-from-the-scheduler-s-own.patch", "2d785b3b5cb53c811a49c999bf69e0c5432eb231a63bed8c68db7f73f087237e"},
        {"0003-Read-and-set-the-run-loop-timer-s-tolerance-only-whe.patch", "e61b205dd485e3eb29972dd3436ebd7dd77a5c93f3a7cab1c434b79d141488c3"},
        {"0004-Declare-URLSession-s-data-task-publisher-at-Apple-s-.patch", "4c719cf0a907708cfc3c1c3439ab7b1848548c001b5106b75a9bf2e225d3978d"},
        {"0005-Add-Publishers.Merge-through-Merge8-and-MergeMany.patch", "03f8a9acbdaf06902808d9391c8df3fcde81228188f6c915eb7348b16abe1cc2"},
        {"0006-Add-Publishers.CombineLatest-CombineLatest3-and-Comb.patch", "1420d2bd07449bb7fe3638720547bab99a6cba6104308a88d7dec03a7cba6429"},
        {"0007-Add-Publishers.CollectByTime-and-collect-_-options.patch", "c66201096cc7726a1415209c6c18623749a657aa3243619500123d2821eb384c"},
        {"0008-Declare-the-equality-and-hashing-Apple-s-interface-d.patch", "13adba858fe05dbc7083f3a19adac2588b2367813cddc0e723a6e5dbec103ce2"},
        {"0009-Define-MapKeyPath-s-gyb-helpers-in-its-template.patch", "9372ec43676530f8a7476550e623a9b35eaff5852aad56a9f9df5e1dc3b2cc22"}}

    local digests = {"xmake.lua=" .. hash.sha256(path.join(os.scriptdir(), "xmake.lua"))}
    for _, patch in ipairs(patches) do
        local file = path.join(os.scriptdir(), "..", "..", "..", "..", "frameworks", "Combine", "patches", patch[1])
        add_patches("2026.10.19", file, patch[2])
        table.insert(digests, patch[1] .. "=" .. hash.sha256(file))
    end

    add_configs("shared", {description = "Compile against a shared swift-runtime and its packaged libc++, for a port that requires them so.", default = false, type = "boolean"})
    add_configs("backports", {description = "Compile against the swift-runtime built with the backports, for a port that requires it so.", default = false, type = "boolean"})
    add_configs("backports_uikit", {description = "With backports: the runtime whose UIKit overlay is linked to the UIKit backports.", default = false, type = "boolean"})
    add_configs("sources", {description = "Install only the patched sources, laid out as the one module (src/Combine, src/CombineHelpers) beside the upstream tests (src/Tests) and the gyb header (src/utils), for a project that compiles them itself.", default = false, type = "boolean"})
    add_configs("recipe", {description = "The digest of this recipe and the patches it applies, so a changed recipe is a different package.", default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    local libraries = {"Combine", "CombineHelpers"}

    on_load("iphoneos", function (package)
        if package:config("sources") then
            return
        end
        package:add("deps", "revenant@swift-runtime", {alias = "swift-runtime", configs = {shared = package:config("shared") or nil,
                    backports = package:config("backports") or nil, backports_uikit = package:config("backports_uikit") or nil}})
        package:add("deps", "revenant@libcxx", {alias = "libcxx", configs = {packaged = package:config("shared") or nil}})
        for _, library in ipairs(libraries) do
            package:add("links", library)
        end
        package:add("frameworks", "Foundation", "CoreFoundation")
    end)

    on_install("iphoneos", function (package)
        local src = path.join(package:installdir(), "src")
        local module = path.join(src, "Combine")
        os.cp(path.join("Sources", "OpenCombine"), module)
        os.cp(path.join("Sources", "OpenCombineDispatch"), path.join(module, "Schedulers"))
        os.cp(path.join("Sources", "OpenCombineFoundation"), path.join(module, "Foundation"))
        for _, file in ipairs(os.files(path.join(module, "Foundation", "Helpers", "*.swift"))) do
            if os.isfile(path.join(module, "Helpers", path.filename(file))) then
                os.rm(file)
            end
        end
        os.cp(path.join("Sources", "COpenCombineHelpers"), path.join(src, "CombineHelpers"))
        os.cp("Tests", path.join(src, "Tests"))
        os.cp(path.join("utils", "template_header.txt"), path.join(src, "utils") .. "/")
        os.cp("LICENSE", package:installdir("licenses") .. "/")
        if package:config("sources") then
            return
        end

        local modules = path.join(package:scriptdir(), "..", "..", "..", "modules")
        local swift = import("apple.swift", {rootdir = modules, anonymous = true})
        local toolchain = assert(package:toolchains(), "Combine is built with the apple-ios toolchain")[1]
        toolchain:load()
        local runtime = assert(package:dep("swift-runtime"), "Combine is compiled against revenant@swift-runtime")
        local libcxx = assert(package:dep("libcxx"), "Combine's C++ helper is compiled against revenant@libcxx")
        local swiftc = assert(table.wrap((runtime:envs() or {}).SWIFT_EXEC)[1], "swift-runtime names no compiler; reinstall it")
        local minimum = toolchain:config("deployment")
        local triple = package:arch() .. "-apple-ios" .. minimum
        local sdk = toolchain:config("sdkdir")
        local swiftdir = path.join(package:installdir("lib"), "swift", "iphoneos")
        local helpers = path.join(src, "CombineHelpers")
        local objects = path.absolute("objects")
        os.mkdir(objects)
        os.mkdir(swiftdir)

        os.vrunv(toolchain:tool("cxx"), {"-target", triple, "-isysroot", sdk, "-nostdinc++", "-isystem",
                 path.join(libcxx:installdir("include"), "c++", "v1"), "-std=c++17", "-O2", "-include", "exception",
                 "-I", path.join(helpers, "include"), "-c", path.join(helpers, "COpenCombineHelpers.cpp"),
                 "-o", path.join(objects, "CombineHelpers.o")})
        os.vrunv(toolchain:tool("ar"), {"-rcs", path.join(package:installdir("lib"), "libCombineHelpers.a"),
                 path.join(objects, "CombineHelpers.o")})
        os.cp(path.join(helpers, "include", "*"), path.join(package:installdir("include"), "CombineHelpers") .. "/")

        local swiftmodule = path.join(swiftdir, "Combine.swiftmodule")
        os.mkdir(swiftmodule)
        local argv = table.join(swift.runtime_flags({
            architecture = package:arch(), deployment = minimum, sdk = sdk,
            resources = path.join(runtime:installdir(), "lib", "swift"),
            plugins = table.wrap((runtime:envs() or {}).SWIFT_PLUGIN_PATH)[1],
            module = "Combine", optimize = "fastest", prefix_map = src .. "=/combine"}),
            {"-I", swiftdir, "-I", path.join(helpers, "include"), "-emit-module", "-emit-module-path",
             path.join(swiftmodule, package:arch() .. "-apple-ios.swiftmodule"), "-c"},
            os.files(path.join(module, "**.swift")), {"-o", path.join(objects, "Combine.o")})
        os.vrunv(swiftc, argv)
        os.vrunv(toolchain:tool("ar"), {"-rcs", path.join(package:installdir("lib"), "libCombine.a"), path.join(objects, "Combine.o")})

        package:setenv("REVENANT_SWIFT_MODULES", swiftdir, path.join(package:installdir("include"), "CombineHelpers"))
    end)
