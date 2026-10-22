local TRIPLE = "armv7-apple-ios6"

function triple()
    return TRIPLE
end

function spec()
    return path.join(os.scriptdir(), "..", "src", "rust", TRIPLE .. ".json")
end

function cflags(toolchain)
    local flags = {"-target", "armv7-apple-ios6.0", "-miphoneos-version-min=" .. toolchain:config("deployment"), "-isysroot", toolchain:config("sdkdir")}
    if toolchain:config("emulated_tls") then
        table.insert(flags, "-femulated-tls")
    end
    return flags
end

function environment(bin, cargo_home, toolchain, rustflags)
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

function library_name(target)
    return target:values("rust.library") or target:name():gsub("-", "_")
end

function crate_folder(target)
    return path.join(os.projectdir(), target:values("rust.crate") or "")
end

function sources(target)
    local folder = crate_folder(target)
    local found = {}
    local lock = path.join(folder, "Cargo.lock")
    if os.isfile(lock) then
        table.insert(found, lock)
    end
    for _, pattern in ipairs({"**.rs", "**.toml"}) do
        for _, file in ipairs(os.files(path.join(folder, pattern))) do
            table.insert(found, file)
        end
    end
    table.sort(found)
    return found
end

function stamp(target)
    local lines = {}
    for _, source in ipairs(sources(target)) do
        table.insert(lines, path.relative(source, os.projectdir()) .. " " .. hash.sha256(source))
    end
    local text = table.concat(lines, "\n") .. "\n"
    local file = path.join(target:objectdir(), "sources.toml")
    local current = os.isfile(file) and io.readfile(file) or nil
    if current ~= text then
        os.mkdir(path.directory(file))
        io.writefile(file, text)
    end
    return file
end

function library_file(target)
    return "lib" .. library_name(target) .. ".a"
end

function arguments(target, manifest, output)
    local args = {"rustc", "--lib", "--crate-type", "staticlib", "--release", "--locked", "--config", "profile.release.lto=false",
                  "--manifest-path", manifest, "--target", spec(), "--target-dir", output,
                  "-Zbuild-std=core,alloc,std,panic_abort", "-Zjson-target-spec", "-j", os.getenv("XMAKE_MAX_JOBS") or tostring(os.default_njob())}
    local package = target:values("rust.package")
    if package then
        table.join2(args, {"-p", package})
    end
    local features = table.wrap(target:values("rust.features"))
    if #features > 0 then
        table.join2(args, {"--no-default-features", "--features", table.concat(features, ",")})
    end
    return args
end

function build(target)
    local toolchain = target:toolchain("apple-ios") or raise("target(%s) is a Rust crate and needs the apple-ios toolchain", target:name())
    toolchain:load()
    if target:arch() ~= "armv7" or toolchain:config("deployment") ~= "6.0" then
        raise("target(%s) is a Rust crate for armv7 on iOS 6.0, the only triple %s has a spec for; it is built for %s on %s", target:name(), TRIPLE, target:arch(), toolchain:config("deployment"))
    end
    local rust = target:pkg("rust") or raise("target(%s) is a Rust crate and requires revenant@rust", target:name())
    local envs = rust:envs() or {}
    local bin = table.wrap(envs.REVENANT_RUST_BIN)[1] or raise("revenant@rust names no toolchain folder; reinstall it")
    local cargo_home = table.wrap(envs.REVENANT_RUST_CARGO_HOME)[1] or raise("revenant@rust names no cargo home; reinstall it")
    local folder = target:values("rust.crate") or raise("target(%s) is a Rust crate and names no rust.crate folder with its Cargo.toml", target:name())
    local manifest = path.join(os.projectdir(), folder, "Cargo.toml")
    if not os.isfile(manifest) then
        raise("target(%s) names %s, which has no Cargo.toml", target:name(), folder)
    end
    if not os.isfile(path.join(os.projectdir(), folder, "Cargo.lock")) then
        raise("target(%s) names %s, which has no Cargo.lock: the build is --locked, so the lock must be committed with the crate", target:name(), folder)
    end
    local output = path.join(target:objectdir(), "cargo")
    os.vrunv(path.join(bin, "cargo"), arguments(target, manifest, output),
             {envs = environment(bin, cargo_home, toolchain, table.wrap(target:values("rust.rustflags")))})
    local built = path.join(output, TRIPLE, "release", library_file(target))
    if not os.isfile(built) then
        raise("target(%s) built no %s: rust.library must name the crate's [lib] name", target:name(), library_file(target))
    end
    os.mkdir(path.directory(target:targetfile()))
    os.cp(built, target:targetfile())
end
