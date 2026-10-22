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

function environment(bin, cargo_home, toolchain)
    local name = TRIPLE:gsub("-", "_")
    local flags = table.concat(cflags(toolchain), " ")
    return {
        PATH = bin .. path.envsep() .. os.getenv("PATH"),
        CARGO_HOME = cargo_home,
        SDKROOT = toolchain:config("sdkdir"),
        IPHONEOS_DEPLOYMENT_TARGET = toolchain:config("deployment"),
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

function sources(target)
    local folder = path.join(os.projectdir(), target:values("rust.crate") or "")
    local found = {}
    for _, name in ipairs({"Cargo.toml", "Cargo.lock", "build.rs"}) do
        local file = path.join(folder, name)
        if os.isfile(file) then
            table.insert(found, file)
        end
    end
    for _, file in ipairs(os.files(path.join(folder, "src", "**.rs"))) do
        table.insert(found, file)
    end
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
    local output = path.join(target:objectdir(), "cargo")
    local jobs = os.getenv("XMAKE_MAX_JOBS") or tostring(os.default_njob())
    os.vrunv(path.join(bin, "cargo"), {"build", "--release", "--manifest-path", manifest, "--target", spec(), "--target-dir", output,
                                       "-Zbuild-std=core,alloc,std,panic_abort", "-Zjson-target-spec", "-j", jobs},
             {envs = environment(bin, cargo_home, toolchain)})
    local built = path.join(output, TRIPLE, "release", library_file(target))
    if not os.isfile(built) then
        raise("target(%s) built no %s: the crate must name crate-type = [\"staticlib\"], and rust.library must name its [lib] name", target:name(), library_file(target))
    end
    os.mkdir(path.directory(target:targetfile()))
    os.cp(built, target:targetfile())
end
