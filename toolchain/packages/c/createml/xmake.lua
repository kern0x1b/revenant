package("createml")
    set_homepage("https://github.com/kern0x1b/revenant/tree/main/toolchain")
    set_description("CreateML and CreateMLComponents for the port's armv7 releases: on-device training of the tabular regressors and classifiers, over the device's own BLAS and LAPACK. The Swift modules - CoreML, the shaped-array overlay CreateML's linear models are constrained to; CreateMLComponents; and CreateML - built against the revenant@swift-runtime a port carries, so a program writes `import CreateML`. The linear algebra is the Accelerate of the release: cblas_dgemm, cblas_dsyrk, cblas_dgemv, cblas_ddot, dgesv_ and dpotrf_ are the armv7 dyld cache's own symbols from 4.3 up, and the package adds no matrix code of its own. The .mlmodel export is a protobuf writer over the published coremltools schema, in this package's own CoreML module, and the linear model writes through it; the five tree and classifier estimators are declared and refuse, because their kind of model is a TreeEnsembleRegressor or a NeuralNetworkClassifier and not a neural network")
    set_license("Apache-2.0")
    set_policy("package.strict_compatibility", true)

    local modules = {"TabularData", "CoreML", "CreateMLComponents", "CreateML"}
    local libraries = {"CreateMLComponents", "CreateML"}

    add_configs("shared", {description = "Compile against a shared swift-runtime and its packaged libc++, for a port that requires them so.", default = false, type = "boolean"})
    add_configs("backports", {description = "Compile against the swift-runtime built with the backports, for a port that requires it so.", default = false, type = "boolean"})
    add_configs("backports_uikit", {description = "With backports: the runtime whose UIKit overlay is linked to the UIKit backports.", default = false, type = "boolean"})

    local digested = {path.join(os.scriptdir(), "xmake.lua")}
    for _, file in ipairs(os.files(path.join(os.scriptdir(), "files", "**.swift"))) do
        table.insert(digested, file)
    end
    for _, file in ipairs(os.files(path.join(os.scriptdir(), "files", "**.h"))) do
        table.insert(digested, file)
    end
    table.sort(digested)
    local digests = {}
    for _, file in ipairs(digested) do
        table.insert(digests, path.relative(file, os.scriptdir()) .. "=" .. hash.sha256(file))
    end
    add_configs("recipe", {description = "The digest of this recipe, so a changed recipe is a different package.", default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    on_load("iphoneos", function (package)
        package:add("deps", "revenant@swift-runtime", {alias = "swift-runtime", configs = {shared = package:config("shared") or nil,
                    backports = package:config("backports") or nil, backports_uikit = package:config("backports_uikit") or nil}})
        package:add("deps", "revenant@apple-backports", {alias = "apple-backports"})
        for _, library in ipairs(libraries) do
            package:add("links", library)
        end
        package:add("frameworks", "Accelerate", "Foundation", "CoreFoundation")
    end)

    on_install("iphoneos", function (package)
        local modules_root = path.join(package:scriptdir(), "..", "..", "..", "modules")
        local swift = import("apple.swift", {rootdir = modules_root, anonymous = true})
        local toolchain = assert(package:toolchains(), "CreateML is built with the apple-ios toolchain")[1]
        toolchain:load()
        local runtime = assert(package:dep("swift-runtime"), "CreateML is compiled against revenant@swift-runtime")
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
        for index, module in ipairs(modules) do
            local folder = path.join(install, module .. ".swiftmodule")
            os.mkdir(folder)
            local header = module == "CoreML"
                          and {"-import-objc-header", path.join(package:scriptdir(), "files", "CoreML", "RevenantCoreML.h")}
                          or nil
            local argv = table.join(swift.runtime_flags({
                architecture = package:arch(), deployment = minimum, sdk = sdk,
                resources = path.join(runtime:installdir(), "lib", "swift"),
                plugins = table.wrap((runtime:envs() or {}).SWIFT_PLUGIN_PATH)[1],
                module = module, optimize = "fastest", prefix_map = os.curdir() .. "=/createml"}),
                header or {}, overlay, {"-I", install, "-emit-module", "-emit-module-path",
                 path.join(folder, package:arch() .. "-apple-ios.swiftmodule"), "-c"},
                os.files(sources[index]), {"-o", path.join(objects, module .. ".o")})
            os.vrunv(swiftc, argv)
            os.vrunv(toolchain:tool("ar"), {"-rcs", path.join(package:installdir(), "lib", "lib" .. module .. ".a"),
                         path.join(objects, module .. ".o")})
        end

        package:setenv("REVENANT_SWIFT_MODULES", install)
        os.cp(path.join(package:scriptdir(), "README.md"), package:installdir())
    end)

    on_test(function (package)
        local toolchain = assert(package:toolchains(), "CreateML is built with the apple-ios toolchain")[1]
        toolchain:load()
        local install = path.join(package:installdir(), "lib", "swift", "iphoneos")
        for _, module in ipairs(modules) do
            assert(os.isdir(path.join(install, module .. ".swiftmodule")),
                   "CreateML installs no " .. module .. " module")
            assert(os.isfile(path.join(package:installdir(), "lib", "lib" .. module .. ".a")),
                   "CreateML installs no lib" .. module .. ".a")
        end

        local exported = os.iorunv("xcrun", {"nm", "-u", path.join(package:installdir(), "lib", "libCreateMLComponents.a")})
        local required = {"_cblas_dgemm", "_cblas_dsyrk", "_cblas_dgemv", "_cblas_ddot", "_dgesv_", "_dpotrf_"}
        for _, symbol in ipairs(required) do
            assert(exported:find(symbol, 1, true),
                   "libCreateMLComponents.a no longer imports " .. symbol ..
                   ", so a kernel was added without a fact behind it")
        end
        local kernels = {}
        for _, symbol in ipairs(required) do
            kernels[symbol] = true
        end
        for symbol in exported:gmatch("\n%s+(_%a[%w_]*)") do
            if symbol:startswith("_cblas_") or symbol:match("^_[a-z]+_$") then
                assert(kernels[symbol], "libCreateMLComponents.a imports " .. symbol ..
                                         ", which is not one of the release's own kernels this package claims")
            end
        end
    end)
