package("createml")
    set_homepage("https://github.com/kern0x1b/charon")
    set_description("CreateML and CreateMLComponents for the port's armv7 releases: on-device training of the tabular regressors and classifiers, over the device's own BLAS and LAPACK. The Swift modules - CoreML, the shaped-array overlay CreateML's linear models are constrained to; CreateMLComponents; and CreateML - built against the charon@swift-runtime a port carries, so a program writes `import CreateML`. The linear algebra is the Accelerate of the release: cblas_dgemm, cblas_dsyrk, cblas_dgemv, cblas_ddot, dgesv_ and dpotrf_ are the armv7 dyld cache's own symbols from 4.3 up, and the package adds no matrix code of its own. The .mlmodel export is a protobuf writer over the published coremltools schema, in this package's own CoreML module, and the linear model writes through it; the five tree and classifier estimators are declared and refuse, because their kind of model is a TreeEnsembleRegressor or a NeuralNetworkClassifier and not a neural network")
    set_license("Apache-2.0")
    set_policy("package.strict_compatibility", true)

    -- Four Swift modules, in dependency order, in one package, because they are four layers of one
    -- API: `TabularData` is the frame the tabular API is written against, `CoreML` the shaped-array
    -- overlay, `CreateMLComponents` the estimators, and `CreateML` the `MLDataTable` and the
    -- high-level types. The order is the build order and not a preference: `CreateMLComponents`
    -- imports the two under it. Splitting them into four packages would make every consumer depend
    -- on all four to get any one of them.
    --
    -- `CoreML` shares its name with the framework, which is the point: a caller writes `import
    -- CoreML` and gets the overlay. charon's swift-runtime already does this for Foundation, UIKit
    -- and CoreData, so the name is the mechanism and not a trick.
    local modules = {"TabularData", "CoreML", "CreateMLComponents", "CreateML"}
    local libraries = {"CreateMLComponents", "CreateML"}

    add_configs("shared", {description = "Compile against a shared swift-runtime and its packaged libc++, for a port that requires them so.", default = false, type = "boolean"})
    add_configs("backports", {description = "Compile against the swift-runtime built with the backports, for a port that requires it so.", default = false, type = "boolean"})
    add_configs("backports_uikit", {description = "With backports: the runtime whose UIKit overlay is linked to the UIKit backports.", default = false, type = "boolean"})

    -- The recipe and the sources it builds, hashed: a changed file is a different package with its
    -- own install path, so a band changing a file here does not collide with a build of the old one
    -- in the shared store. A comment or a reordering is deliberately outside the digest.
    -- The sources are part of it: a module's .swift and .h files are read by the compile, so a new or changed
    -- file under files/ must be a new package too. The digest names each file relative to this folder.
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
        -- The runtime a port takes, and the one this is compiled against: the modules are read
        -- against that runtime's own resource directory, so the module and the program cannot
        -- disagree about which Swift they are.
        package:add("deps", "charon@swift-runtime", {alias = "swift-runtime", configs = {shared = package:config("shared") or nil,
                    backports = package:config("backports") or nil, backports_uikit = package:config("backports_uikit") or nil}})
        -- The backports registry, as a direct dependency, and not only through swift-runtime. This
        -- build reads it: the runtime's port headers lower the SDK's marks for whatever the backports say
        -- is implemented, and `registry/CoreML/createml-shapedarray.json` is the row that makes
        -- `MLMultiArrayDataType` - a header-only NS_ENUM, no runtime presence, which Apple's header
        -- annotates ios(11.0) and so every release the port's armv7 can use is below - available at
        -- 6.1.3 instead. Reached only through the runtime, that row does not reach the port's headers: the
        -- runtime is a released package resolved by version, so the store keeps serving the
        -- apple-backports it was built against, the port's headers find no CoreML row to lower, the SDK's
        -- ios(11.0) mark stays, and this package's own `CoreML` module cannot see the type. Declaring the
        -- dependency is what puts the row in front of the port's headers.
        package:add("deps", "charon@apple-backports", {alias = "apple-backports"})
        for _, library in ipairs(libraries) do
            package:add("links", library)
        end
        -- Accelerate for the kernels, Foundation for the tables and the files. Both are the device's
        -- own; the packages here are a dylib and a module map, and what they export is the release's.
        package:add("frameworks", "Accelerate", "Foundation", "CoreFoundation")
    end)

    on_install("iphoneos", function (package)
        local modules_root = path.join(package:scriptdir(), "..", "..", "..", "modules")
        local swift = import("apple.swift", {rootdir = modules_root, anonymous = true})
        local toolchain = assert(package:toolchains(), "CreateML is built with the apple-ios toolchain")[1]
        toolchain:load()
        local runtime = assert(package:dep("swift-runtime"), "CreateML is compiled against charon@swift-runtime")
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

        -- One module at a time, in the order above: CoreML first, because the shaped-array
        -- overlay is what CreateMLComponents's linear models are constrained to, and
        -- CreateMLComponents before CreateML, because CreateML imports it. Availability checking stays
        -- on - nothing is built behind an `-disable-availability-checking` - and the whole compile is
        -- one `-wmo` unit per module, the way the runtime's own overlays are built.
        --
        -- The `CoreML` module needs the *port's* headers, and not only its own umbrella. The SDK
        -- marks `MLMultiArrayDataType` and the rest of `MLMultiArray.h` `ios(11.0)` and the port's
        -- release has no CoreML, so `registry/CoreML/createml-shapedarray.json` lowers it — and a
        -- lowered availability only reaches a compile through the VFS overlay of the port's headers, which
        -- the runtime that was built with the backports hands on in `CHARON_SWIFT_PORT_HEADERS`.
        -- Without it the compile fails with "cannot find type 'MLMultiArrayDataType' in scope", which
        -- is what the first build of this package did, and which is the whole reason that registry
        -- entry exists.
        local port_headers = table.wrap((runtime:envs() or {}).CHARON_SWIFT_PORT_HEADERS)
        local overlay = #port_headers > 0 and {"-vfsoverlay", table.concat(port_headers, path.envsep())} or {}
        for index, module in ipairs(modules) do
            local folder = path.join(install, module .. ".swiftmodule")
            os.mkdir(folder)
            -- The `CoreML` module is named after the framework and so is the SDK's CoreML as a clang
            -- module; two modules cannot share a name, and the Swift one wins. The header beside it
            -- includes the framework's and is imported into the module, which is how the overlay sees
            -- `MLMultiArrayDataType` at all — the same route charon's swift-runtime takes for
            -- `Foundation`, `UIKit` and `CoreData`.
            local header = module == "CoreML"
                          and {"-import-objc-header", path.join(package:scriptdir(), "files", "CoreML", "CharonCoreML.h")}
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
        local toolchain = assert(package:toolchains(), "CreateML is built with the apple-ios toolchain")[1]
        toolchain:load()
        local install = path.join(package:installdir(), "lib", "swift", "iphoneos")
        for _, module in ipairs(modules) do
            assert(os.isdir(path.join(install, module .. ".swiftmodule")),
                   "CreateML installs no " .. module .. " module")
            assert(os.isfile(path.join(package:installdir(), "lib", "lib" .. module .. ".a")),
                   "CreateML installs no lib" .. module .. ".a")
        end

        -- The claim this package is built on: the linear algebra is the release's own. Every kernel
        -- the archives import must be a symbol the armv7 release carries, because a port's linker
        -- resolves against the device's dyld shared cache and a symbol the cache does not hold is a
        -- link that fails on the device and not before it. The set is exact, so a kernel added
        -- without a fact behind it fails here rather than on a phone.
        local exported = os.iorunv("xcrun", {"nm", "-u", path.join(package:installdir(), "lib", "libCreateMLComponents.a")})
        local required = {"_cblas_dgemm", "_cblas_dsyrk", "_cblas_dgemv", "_cblas_ddot", "_dgesv_", "_dpotrf_"}
        for _, symbol in ipairs(required) do
            assert(exported:find(symbol, 1, true),
                   "libCreateMLComponents.a no longer imports " .. symbol ..
                   ", so a kernel was added without a fact behind it")
        end
        -- And nothing else from the linear algebra, checked by listing what the archive does import
        -- rather than by a pattern over the whole output: the set of kernel symbols here is short,
        -- and a pattern wide enough to catch a BLAS name would also catch one this package has no
        -- fact behind. A pattern that looks like `_[a-z]+_$` catches LAPACK's own `dgetrf_` as well
        -- as a symbol nothing has ever heard of, and the difference between those two is the fact.
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
