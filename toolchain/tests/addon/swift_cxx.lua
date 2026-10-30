import("fixtures")

local FIXTURES = path.join(os.scriptdir(), "..", "swift_cxx")
local ARCHITECTURES = {{"armv7", "6.0"}}

local function newest(pattern)
    local best
    for _, file in ipairs(os.files(pattern)) do
        if not best or os.mtime(file) > os.mtime(best) then
            best = file
        end
    end
    return best
end

local function installed()
    local packages = path.join(os.getenv("XMAKE_GLOBALDIR"), ".xmake", "packages")
    local runtime = newest(path.join(packages, "s", "swift-runtime", "6.4.0", "*", "lib", "swift", "iphoneos", "libswiftCxxStdlib.dylib"))
    local libcxx = newest(path.join(packages, "l", "libcxx", "23.1.1", "*", "include", "c++", "v1", "__config"))
    return runtime and path.directory(path.directory(runtime)),
           libcxx and path.directory(path.directory(path.directory(path.directory(libcxx))))
end

local function needs_emulated_tls(architecture, deployment)
    local native = architecture == "arm64" and "8.0" or "9.0"
    return semver.compare(deployment, native) < 0
end

local function build(folder, opt, swift, runtime, libcxx, fixture, architecture, deployment)
    local work = path.join(folder, fixture, architecture)
    os.mkdir(work)
    local source = path.join(FIXTURES, fixture)
    local binary = path.join(work, "probe")
    local argv = table.join(swift.runtime_flags({architecture = architecture, deployment = deployment, sdk = opt.sdk,
                                                 resources = runtime, module = "probe", has_main = true,
                                                 cxx_headers = path.join(libcxx, "include", "c++", "v1"),
                                                 emulated_tls = needs_emulated_tls(architecture, deployment)}),
                            {"-cxx-interoperability-mode=default",
                             "-tools-directory", path.directory(opt.clang), "-use-ld=" .. opt.ld64,
                             "-Xclang-linker", "-mlinker-version=" .. fixtures.linker_version(opt.ld64),
                             "-Xcc", "-fmodule-map-file=" .. path.join(source, "module.modulemap"),
                             "-L", path.join(runtime, "iphoneos"), "-L", path.join(libcxx, "lib"),
                             "-Xclang-linker", "-nostdlib++", "-lc++", "-lc++abi",
                             path.join(source, "main.swift"), "-o", binary})
    fixtures.run(work, path.join(opt.swift, "bin", "swiftc"), argv)
    return binary
end

local function symbols(folder, file, flag)
    local listed = {}
    for line in fixtures.run(folder, "xcrun", {"nm", flag, file}):gmatch("[^\n]+") do
        listed[line:match("(%S+)$")] = true
    end
    return listed
end

function failures(opt, fixture, needs, tls)
    local swift = import("apple.swift", {rootdir = opt.modules, anonymous = true})
    local dyld = import("apple.dyld", {rootdir = opt.modules, anonymous = true})
    local firmware = import("apple.firmware", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local runtime, libcxx = installed()
    if not runtime or not libcxx then
        table.insert(found, "swift-runtime and libcxx must be installed for iphoneos before this test runs; configure with "
                            .. "./xmakew f -p iphoneos -a armv7, then require revenant@swift-runtime and revenant@libcxx")
        return found
    end
    local folder = fixtures.scratch()
    local abi = path.join(libcxx, "lib", "libc++abi.1.dylib")
    for _, case in ipairs(ARCHITECTURES) do
        local architecture, deployment = case[1], case[2]
        local label = fixture .. " " .. architecture .. " iOS " .. deployment
        local errors = fixtures.refusal(function ()
            local binary = build(folder, opt, swift, runtime, libcxx, fixture, architecture, deployment)
            local version = fixtures.run(folder, "xcrun", {"otool", "-l", binary}):match("LC_VERSION_MIN_IPHONEOS.-version (%S+)")
            if version ~= deployment then
                table.insert(found, label .. ": the binary must record the release it was built for, not " .. tostring(version))
            end
            local loaded = {}
            for library in fixtures.run(folder, "xcrun", {"otool", "-L", binary}):gmatch("\n%s+(%S+)") do
                table.insert(loaded, library)
            end
            for _, library in ipairs(needs or {}) do
                if not table.contains(loaded, library) then
                    table.insert(found, label .. ": the binary must load " .. library .. ", not " .. table.concat(loaded, " "))
                end
            end
            if tls then
                local undefined = symbols(folder, binary, "-u")
                for _, symbol in ipairs(tls.emulated) do
                    if not undefined[symbol] then
                        table.insert(found, label .. ": the binary must import " .. symbol .. " for emulated TLS")
                    end
                end
                for _, symbol in ipairs(tls.native) do
                    if undefined[symbol] then
                        table.insert(found, label .. ": the binary imports " .. symbol .. ", native TLS that iOS " .. deployment .. " does not provide")
                    end
                end
                local exported = symbols(folder, abi, "-gU")
                for _, symbol in ipairs(tls.emulated) do
                    if not exported[symbol] then
                        table.insert(found, label .. ": " .. abi .. " must export " .. symbol)
                    end
                end
            end
            local cache, release = firmware.source(architecture, deployment)
            if not os.exists(cache) then
                table.insert(found, string.format("%s: the imports are checked against iOS %s, whose libraries are not held; run xmake firmware --arch=%s fetch %s", label, release, architecture, release))
            else
                local binaries = {binary}
                if tls then
                    table.insert(binaries, abi)
                end
                for _, missing in ipairs((dyld.missing_imports(cache, binaries))) do
                    table.insert(found, label .. ": " .. path.filename(missing[1]) .. " imports " .. missing[2] .. ", which iOS " .. release .. " lacks")
                end
            end
        end)
        if errors then
            table.insert(found, label .. ": " .. errors)
        end
    end
    os.tryrm(folder)
    return found
end
