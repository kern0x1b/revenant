package("libsql")
    set_homepage("https://github.com/tursodatabase/libsql")
    set_description("libSQL is a fork of SQLite that is open source, open contribution, and open development. This package provides the Rust staticlib for armv7 iOS 6.")
    set_license("MIT")

    add_urls("https://github.com/tursodatabase/libsql.git")
    add_versions("0.5.0", "97652c12fe8bb215fe51b5370b46f27c0bc9d6e1")

    add_deps("rust nightly-2026-10-22", {alias = "rust"})
    add_deps("cmake", "ninja", {kind = "binary"})

    add_configs("crate", {description = "The libsql crate to build", default = "libsql", type = "string", readonly = true})
    add_configs("features", {description = "Cargo features to enable", default = "core", type = "string"})

    on_download(function (package, opt)
        local checkout = import("@addon.revenant.checkout", {anonymous = true})
        checkout.pinned(opt.sourcedir, {{url = opt.url, tag = "libsql-rs-v" .. package:version_str(),
                                         commit = "97652c12fe8bb215fe51b5370b46f27c0bc9d6e1",
                                         sparse = {"/*", "!/*/", "/libsql/", "/libsql-sys/", "/libsql-ffi/", "/libsql-hrana/", "/libsql-replication/", "/libsql-storage/", "/libsql-storage-server/", "/libsql-wal/", "/libsql-shell/", "/libsql-server/", "/libsql-sqlite3/", "/bindings/", "/bottomless/", "/bottomless-cli/", "/xtask/", "/tools/", "/vendored/", "/.cargo/", "/.config/", "/docker-compose/", "/docs/"}}})
    end)

    on_install("iphoneos", function (package)
        local TRIPLE = "armv7-apple-ios6"

        local function spec()
            return path.join(os.projectdir(), "toolchain", "src", "rust", TRIPLE .. ".json")
        end

        local function cflags(toolchain)
            local flags = {"-target", "armv7-apple-ios6.0", "-miphoneos-version-min=" .. toolchain:config("deployment"), "-isysroot", toolchain:config("sdkdir")}
            if toolchain:config("emulated_tls") then
                table.insert(flags, "-femulated-tls")
            end
            return flags
        end

        local function environment(bin, cargo_home, toolchain, rustflags)
            local name = TRIPLE:gsub("-", "_")
            local flags = table.concat(cflags(toolchain), " ")
            return {
                PATH = bin .. path.envsep() .. os.getenv("PATH"),
                CARGO_HOME = cargo_home,
                SDKROOT = toolchain:config("sdkdir"),
                IPHONEOS_DEPLOYMENT_TARGET = toolchain:config("deployment"),
                RUSTFLAGS = table.concat(table.join({"-Cembed-bitcode=no"}, rustflags), " "),
                ["CC_" .. name] = toolchain:tool("cc"),
                ["CXX_" .. name] = toolchain:tool("cxx"),
                ["AR_" .. name] = toolchain:tool("ar"),
                ["CFLAGS_" .. name] = flags,
                ["CXXFLAGS_" .. name] = flags
            }
        end

        local rust_pkg = package:dep("rust")
        local envs = rust_pkg:envs() or {}
        local bin = table.wrap(envs.REVENANT_RUST_BIN)[1] or raise("revenant@rust names no toolchain folder; reinstall it")
        local cargo_home = table.wrap(envs.REVENANT_RUST_CARGO_HOME)[1] or raise("revenant@rust names no cargo home; reinstall it")

        local crate_name = package:config("crate")
        local crate_path = path.join(os.curdir(), crate_name)
        local manifest = path.join(crate_path, "Cargo.toml")
        if not os.isfile(manifest) then
            raise("crate %s not found at %s", crate_name, crate_path)
        end

        if not os.isfile(path.join(os.curdir(), "Cargo.lock")) then
            raise("workspace has no Cargo.lock: the build is --locked")
        end

        local features = package:config("features")
        local feature_list = {}
        if features and features ~= "" then
            feature_list = features:split(",", {plain = true})
        end

        local output = path.absolute(path.join(package:builddir(), "cargo"))
        os.mkdir(output)

        local spec_path = spec()
        local args = {"rustc", "--lib", "--crate-type", "staticlib", "--release", "--locked", "--config", "profile.release.lto=false",
                      "--manifest-path", manifest, "--target", spec_path, "--target-dir", output,
                      "-Zbuild-std=core,alloc,std,panic_abort", "-Zjson-target-spec", "-j", os.getenv("XMAKE_MAX_JOBS") or tostring(os.default_njob())}
        if #feature_list > 0 then
            table.join2(args, {"--no-default-features", "--features", table.concat(feature_list, ",")})
        end

        local toolchains = package:toolchains()
        if not toolchains or #toolchains == 0 then
            raise("libsql package requires apple-ios toolchain")
        end
        local toolchain = toolchains[1]
        toolchain:load()
        if toolchain:config("deployment") ~= "6.0" or toolchain:arch() ~= "armv7" then
            raise("libsql package requires armv7 iOS 6.0 toolchain configuration")
        end

        local env = environment(bin, cargo_home, toolchain, {})
        os.vrunv(path.join(bin, "cargo"), args, {envs = env, curdir = crate_path})

        local built = path.join(output, TRIPLE, "release", "lib" .. crate_name:gsub("-", "_") .. ".a")
        if not os.isfile(built) then
            raise("crate %s built no %s", crate_name, built)
        end

        os.mkdir(path.join(package:installdir(), "lib"))
        os.cp(built, path.join(package:installdir(), "lib", path.filename(built)))

        os.cp(path.join(os.curdir(), "LICENSE.md"), package:installdir("licenses") .. "/")
    end)

    on_install("macosx", function (package)
        raise("libsql is for iOS armv7 only; configure the project for iOS before requiring it")
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "liblibsql.a")), "liblibsql.a not installed")
    end)