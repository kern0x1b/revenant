package("createml")
    set_homepage("https://github.com/kern0x1b/revenant/tree/main/frameworks/Backports")
    set_description("CreateML and CreateMLComponents for the port's armv7 releases: on-device training of the tabular regressors and classifiers, over the device's own BLAS and LAPACK, as the Swift modules TabularData, CoreML, CreateMLComponents and CreateML built against the revenant@swift-runtime a port carries")
    set_license("Apache-2.0")
    set_policy("package.strict_compatibility", true)
    add_configs("apple_sdk", {description = "The iPhoneOS SDK the generated project names: the one the consumer installed, so the package is not built against a second SDK.", type = "string"})

    includes(path.join(os.scriptdir(), "port", "digest.lua"))
    add_configs("recipe", {description = "The digest of this recipe and the Swift sources it builds, so a changed declaration is a different package.", default = createml_sources_digest, type = "string", readonly = true})

    on_load("iphoneos", function (package)
        local toolchain = assert(package:toolchains(), "createml is built with the apple-ios toolchain")[1]
        toolchain:load()
        raise("createml is not yet backported to iOS %s: it needs CoreML, an open gap; see the open gaps in frameworks/Backports/README.md", toolchain:config("deployment"))
        package:add("deps", "revenant@swift-runtime", {alias = "swift-runtime"})
        for _, library in ipairs({"TabularData", "CoreML", "CreateMLComponents", "CreateML"}) do
            package:add("links", library)
        end
        package:add("frameworks", "Accelerate", "Foundation", "CoreFoundation")
    end)

    on_install("iphoneos", function (package)
        local root = path.translate(path.join(package:scriptdir(), "..", "..", ".."))
        import("@addon.revenant.apple.wrapper", {anonymous = true}).install(package, {root = root,
            includes = {path.join(root, "frameworks", "Backports", "src", "Swift")},
            targets = {"TabularData", "CoreML", "CreateMLComponents", "CreateML"}, modules = true})
    end)

    on_test(function (package)
        local lib = path.join(package:installdir(), "lib")
        for _, module in ipairs({"TabularData", "CoreML", "CreateMLComponents", "CreateML"}) do
            assert(os.isdir(path.join(lib, "swift", "iphoneos", module .. ".swiftmodule")), "CreateML installs no " .. module .. " module")
            assert(os.isfile(path.join(lib, "lib" .. module .. ".a")), "CreateML installs no lib" .. module .. ".a")
        end
        local exported = os.iorunv("xcrun", {"nm", "-u", path.join(lib, "libCreateMLComponents.a")})
        local required = {"_cblas_dgemm", "_cblas_dsyrk", "_cblas_dgemv", "_cblas_ddot", "_dgesv_", "_dpotrf_"}
        for _, symbol in ipairs(required) do
            assert(exported:find(symbol, 1, true), "libCreateMLComponents.a no longer imports " .. symbol .. ", so a kernel was added without a fact behind it")
        end
        local kernels = {}
        for _, symbol in ipairs(required) do
            kernels[symbol] = true
        end
        for symbol in exported:gmatch("\n%s+(_%a[%w_]*)") do
            if symbol:startswith("_cblas_") or symbol:match("^_[a-z]+_$") then
                assert(kernels[symbol], "libCreateMLComponents.a imports " .. symbol .. ", which is not one of the release's own kernels this package claims")
            end
        end
    end)
