local FLAGS = {}

local function dependencies(file, dirs, found)
    for line in os.iorunv("otool", {"-L", file}):gmatch("[^\n]+") do
        local leaf = line:match("^%s+@rpath/(%S+)")
        if leaf and not found[leaf] then
            for _, dir in ipairs(dirs) do
                local candidate = path.join(dir, leaf)
                if os.isfile(candidate) then
                    found[leaf] = candidate
                    dependencies(candidate, dirs, found)
                    break
                end
            end
        end
    end
end

local function parse_entry(file)
    local entry = {}
    for line in io.readfile(file):gmatch("[^\r\n]+") do
        local key, value = line:match("^(%w+)=(.*)$")
        if key then
            entry[key] = value
        end
    end
    return entry
end

function main(out, ...)
    local scripts = path.join(os.scriptdir(), "..", "..", "tools")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local build = import("recaptcha_build", {rootdir = scripts, anonymous = true})
    local opt = corpus.options(...)
    local drop, execute, rounds, seconds = nil, false, "1", "60"
    local arguments = {...}
    for index, argument in ipairs(arguments) do
        if argument == "--drop" then
            drop = arguments[index + 1]
        elseif argument == "--execute" then
            execute = true
        elseif argument == "--rounds" then
            rounds = arguments[index + 1]
        elseif argument == "--seconds" then
            seconds = arguments[index + 1]
        end
    end
    local e
    e, out = corpus.setup("recaptchareal", out)
    local function o(file)
        return path.join(out, file)
    end

    local library, registry
    if drop then
        local entry = parse_entry(drop)
        library = path.join(entry.dir, entry.library)
        registry = path.join(entry.dir, entry.library:gsub("%.dylib$", "") .. "-classes.dylib")
        print("recaptchareal: library of the drop %s", drop)
    else
        local sdk = build.sdk_file()
        local libs = build.libraries_folder()
        if not sdk or not os.isfile(sdk) or not libs then
            print("skip: recaptchareal needs the real SDK (XL_RECAPTCHA_SDK, or telegram-build/.agent-work/recaptcha-sdk/RecaptchaEnterprise.dylib beside this checkout) and XL_SWIFTOBJC_LIBS")
            return
        end
        local xl = build.translate_sdk(e, out, sdk, libs)
        library = path.join(xl, "RecaptchaEnterprise.dylib")
        registry = path.join(xl, "RecaptchaEnterprise-classes.dylib")
    end
    if not os.isfile(library) or not os.isfile(registry) then
        raise("the library %s or its registry %s is missing", library, registry)
    end

    local here = os.scriptdir()
    local swift = corpus.swift()
    local runtime = corpus.swift_armv7()
    os.execv(path.join(swift, "bin", "swiftc"), {"-target", "armv7-apple-ios6.0", "-clang-target", "armv7-apple-ios6.0", "-sdk", e.sdk,
                                                 "-resource-dir", path.join(runtime, "lib", "swift"), "-I", path.join(runtime, "lib", "swift", "iphoneos"),
                                                 "-Xfrontend", "-bundled-swift-runtime", "-runtime-compatibility-version", "none",
                                                 "-plugin-path", path.join(swift, "lib", "swift", "host", "plugins"),
                                                 "-Xfrontend", "-disable-implicit-concurrency-module-import", "-Xfrontend", "-disable-implicit-string-processing-module-import",
                                                 "-parse-as-library", "-wmo", "-O", "-module-name", "RCHost", "-emit-object", "-o", o("hostswift.o"),
                                                 path.join(here, "hostswift.swift")})
    corpus.armv7(e, {"-O2", "-w", "-fobjc-arc", "-I", path.join(e.recompiler, "include"),
                     "-L", path.join(runtime, "lib", "swift", "iphoneos"), "-lswiftFoundation", "-lswiftCore", "-framework", "Foundation", "-Wl,-rpath,@executable_path", o("hostswift.o"),
                     path.join(here, "main.m"), path.join(e.recompiler, "src", "loader", "xl_loader.c"), "-o", o("rcsdk")})
    corpus.sign(e, o("rcsdk"))
    if opt.host_only then
        print("ok (host part)")
        return
    end

    local device = corpus.device()
    local remote = device.scratch .. "/xl-recaptchareal"
    device.run("rm -rf " .. remote .. " && mkdir -p " .. remote)
    device.copy(library, remote .. "/RecaptchaEnterprise.dylib")
    device.copy(registry, remote .. "/RecaptchaEnterprise-classes.dylib")
    device.copy(o("rcsdk"), remote .. "/rcsdk")
    local found = {}
    dependencies(o("rcsdk"), {path.join(runtime, "lib", "swift", "iphoneos"), corpus.libcxx_armv7()}, found)
    for leaf, file in pairs(found) do
        os.cp(file, o("runtime-" .. leaf))
        os.runv("chmod", {"u+w", o("runtime-" .. leaf)})
        corpus.sign(e, o("runtime-" .. leaf))
        device.copy(o("runtime-" .. leaf), remote .. "/" .. leaf)
    end
    local flags = {}
    for _, flag in ipairs(FLAGS) do
        table.insert(flags, "touch " .. flag)
    end
    local prefix = #flags > 0 and table.concat(flags, " && ") .. " && " or ""
    local command = string.format("chmod +x %s/rcsdk && %scd %s && DYLD_INSERT_LIBRARIES=/usr/lib/revenant/org.revenant.backports/libSystemBackports.dylib:/usr/lib/revenant/org.revenant.backports/libFoundationBackports.dylib DYLD_FALLBACK_LIBRARY_PATH=%s ./rcsdk %s/RecaptchaEnterprise.dylib - %s --rounds %s --seconds %s 2>&1; echo exit=$?",
                                  remote, prefix, remote, remote, remote, execute and "--execute" or "", rounds, seconds)
    local output = try { function ()
        return device.run(command)
    end } or ""
    for _, flag in ipairs(FLAGS) do
        try { function ()
            device.run("rm -f " .. flag)
        end }
    end
    io.writefile(o("run.txt"), output)
    device.run("rm -rf " .. remote)
    local text = "\n" .. output:gsub("\r", "")
    for _, step in ipairs({" reserve ", " load ", " find ", " fetched ", " done "}) do
        if not text:find(step, 1, true) then
            io.write(output)
            corpus.fail("the SDK run did not reach the step%sbefore it stopped", step)
        end
    end
    if text:find("NO ANSWER", 1, true) or not text:find("\nexit=0\n", 1, true) then
        io.write(output)
        corpus.fail("the SDK run did not answer or did not run to its end with exit 0")
    end
    print("ok: the real SDK loads, finds its classes, answers fetchClient offline with an error and runs %s round(s) to the end", rounds)
end
