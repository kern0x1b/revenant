import("fixtures")

local ccache = import("@addon.revenant.apple.ccache", {anonymous = true})

local function raises(action)
    local message
    try {
        action,
        catch {
            function (raised)
                message = tostring(raised)
            end
        }
    }
    return message
end

local function executable(file, text)
    os.mkdir(path.directory(file))
    io.writefile(file, text)
    os.vrunv("chmod", {"+x", file})
    return file
end

local function with_env(name, value, action)
    local saved = os.getenv(name)
    os.setenv(name, value)
    local failure = raises(action)
    os.setenv(name, saved or "")
    if failure then
        raise("%s", failure)
    end
end

local function stub(tools)
    local sets = {}
    local target = {sets = sets}
    function target:toolchains()
        return {{tool = function (_, kind) return tools[kind] end}}
    end
    function target:set(...)
        table.insert(sets, table.pack(...))
    end
    return target
end

local function setting(target, name, kind)
    for _, set in ipairs(target.sets) do
        if set[1] == name and (kind == nil or set[2] == kind) then
            return set[3] ~= nil and set[3] or set[2]
        end
    end
end

function failures(opt)
    local found = {}
    local root = fixtures.scratch()
    local log = path.join(root, "calls.log")
    local fake = executable(path.join(root, "bin", "ccache"), table.concat({
        "#!/bin/sh",
        "{ echo \"count: $#\"; for a in \"$@\"; do echo \"arg: $a\"; done; env | grep '^CCACHE_' | sort; } >> " .. log,
        "real=\"$1\"; shift; exec \"$real\" \"$@\"",
        ""}, "\n"))
    local clang = executable(path.join(root, "llvm", "bin", "clang"), "#!/bin/sh\necho \"clang ran with $# arguments\"\n")
    local clangxx = executable(path.join(root, "llvm", "bin", "clang++"), "#!/bin/sh\necho \"clang++ ran with $# arguments\"\n")
    local store = path.join(root, "store", "ccache")
    local settings = {program = fake, folder = store, basedir = root, gigabytes = 1.5}

    local shim = ccache.shim(clang, settings)
    if not shim or path.filename(shim) ~= "clang" or not os.isexec(shim) or not shim:startswith(path.join(store, "shim") .. "/") then
        table.insert(found, "the shim of a compiler is an executable named like it under <store>/ccache/shim/<key>/: " .. tostring(shim))
        os.tryrm(root)
        return found
    end
    local again = ccache.shim(clang, settings)
    if again ~= shim then
        table.insert(found, "the shim of the same compiler with the same settings is one file: " .. tostring(shim) .. " and " .. tostring(again))
    end
    local larger = ccache.shim(clang, {program = fake, folder = store, basedir = root, gigabytes = 2})
    local elsewhere = ccache.shim(clang, {program = fake, folder = store, basedir = path.join(root, "other"), gigabytes = 1.5})
    local plusplus = ccache.shim(clangxx, settings)
    if larger == shim or elsewhere == shim then
        table.insert(found, "another size or another base directory is another shim, or two builds would share a file and fight over its settings")
    end
    if not plusplus or path.filename(plusplus) ~= "clang++" then
        table.insert(found, "the shim of clang++ is named clang++, so that xmake still knows the compiler: " .. tostring(plusplus))
    end
    local config = path.join(store, "ccache.conf")
    if not os.isfile(config) or not io.readfile(config):find("Written by", 1, true) then
        table.insert(found, "the shim's own ccache.conf is written beside it, so that the user's is not read")
    end
    if #os.files(path.join(store, "**.tmp")) ~= 0 then
        table.insert(found, "the shim and the conf are written through a temporary file that is renamed, and none is left behind: " .. table.concat(os.files(path.join(store, "**.tmp")), ", "))
    end

    local output = os.iorunv(shim, {"-c", "a b.c", "$HOME", "it's"}):trim()
    if output ~= "clang ran with 4 arguments" then
        table.insert(found, "the shim runs the compiler through ccache with the arguments it was given, spaces and quotes included: " .. output)
    end
    local calls = io.readfile(log)
    local seen = {}
    for line in calls:gmatch("[^\n]+") do
        seen[line] = true
    end
    for _, line in ipairs({"count: 5", "arg: " .. clang, "arg: a b.c", "arg: $HOME", "arg: it's",
                           "CCACHE_BASEDIR=" .. root, "CCACHE_DIR=" .. path.join(store, "cache"), "CCACHE_MAXSIZE=1.5G", "CCACHE_NOHASHDIR=1",
                           "CCACHE_COMPILERCHECK=content", "CCACHE_CONFIGPATH=" .. config,
                           "CCACHE_SLOPPINESS=include_file_ctime,include_file_mtime"}) do
        if not seen[line] then
            table.insert(found, "ccache is called with " .. line .. ", and the log of its calls is:\n" .. calls)
        end
    end
    for _, forbidden in ipairs({"system_headers", "time_macros", "DEPEND"}) do
        if calls:find(forbidden, 1, true) then
            table.insert(found, "the shim must not set " .. forbidden .. ": system_headers would stop an edit of the repository's own -isystem headers from changing a result, time_macros would cache what changes with the clock")
        end
    end

    os.rm(log)
    local hostile = {CCACHE_IGNOREOPTIONS = "-D*", CCACHE_PREFIX = "distcc", CCACHE_EXTRAFILES = "/nonexistent", CCACHE_COMPILER = "gcc", CCACHE_NOCPP2 = "1",
                     CCACHE_SLOPPINESS = "system_headers,time_macros", CCACHE_LOGFILE = path.join(root, "ccache.log")}
    os.iorunv(shim, {"-c", "x.c"}, {envs = hostile})
    local scrubbed = {}
    for line in io.readfile(log):gmatch("[^\n]+") do
        scrubbed[line] = true
    end
    for name, _ in pairs(hostile) do
        if name ~= "CCACHE_LOGFILE" and name ~= "CCACHE_SLOPPINESS" and scrubbed[name .. "=" .. hostile[name]] then
            table.insert(found, name .. " of the invoking shell reaches ccache through the shim: it could take options out of the key, or run another compiler")
        end
    end
    if scrubbed["CCACHE_SLOPPINESS=system_headers,time_macros"] or not scrubbed["CCACHE_SLOPPINESS=include_file_ctime,include_file_mtime"] then
        table.insert(found, "the sloppiness of the shim is its own whatever the invoking shell sets")
    end
    if not scrubbed["CCACHE_LOGFILE=" .. hostile.CCACHE_LOGFILE] then
        table.insert(found, "CCACHE_LOGFILE of the invoking shell still reaches ccache, so that a build can be measured")
    end

    local real_ccache = ccache.program()
    if real_ccache then
        local host = os.iorunv("xcrun", {"-f", "clang"}):trim()
        local real_shim = ccache.shim(host, {folder = path.join(root, "real"), basedir = root, gigabytes = 0.1})
        local source = path.join(root, "real-source.c")
        io.writefile(source, "int value(void) { return V; }\n")
        local objects = {}
        for index, value in ipairs({"1", "2"}) do
            local object = path.join(root, "real-" .. index .. ".o")
            os.iorunv(real_shim, {"-c", "-DV=" .. value, source, "-o", object}, {envs = {CCACHE_IGNOREOPTIONS = "-D*"}, curdir = root})
            objects[index] = io.readfile(object, {encoding = "binary"})
        end
        if objects[1] == objects[2] then
            table.insert(found, "with CCACHE_IGNOREOPTIONS=-D* in the invoking shell, a compile with another -D was answered from the cache: the object for -DV=2 holds the code of -DV=1")
        end
    end

    local target = stub({cc = clang, cxx = clangxx, mm = clang, mxx = clangxx})
    if ccache.enter(target, settings) ~= true then
        table.insert(found, "a target whose toolchain has compilers is entered")
    end
    for kind, real in pairs({cc = clang, cxx = clangxx, mm = clang, mxx = clangxx}) do
        local set = setting(target, "toolset", kind)
        if not set or path.filename(set) ~= path.filename(real) or not set:find(path.join(store, "shim"), 1, true) then
            table.insert(found, "the " .. kind .. " compiler of an entered target is the shim of " .. real .. ": " .. tostring(set))
        end
    end
    if setting(target, "policy") ~= "build.ccache" or target.sets[#target.sets][3] ~= false then
        table.insert(found, "an entered target has xmake's builtin cache off, so that ccache is the only cache on its compiles")
    end
    local bare = stub({})
    if ccache.enter(bare, settings) ~= false or #bare.sets ~= 0 then
        table.insert(found, "a target whose toolchains have no compiler is left alone")
    end

    os.rm(log)
    local project = path.join(root, "project")
    os.mkdir(project)
    io.writefile(path.join(project, "a.c"), "int answer(void) { return 42; }\n")
    io.writefile(path.join(project, "xmake.lua"), table.concat({
        "add_addons(\"revenant\", {sourcedir = \"" .. path.absolute(path.join(os.scriptdir(), "..", "..")) .. "\"})",
        "rule(\"cached\")",
        "    on_config(function (target)",
        "        import(\"@addon.revenant.apple.ccache\", {anonymous = true}).enter(target, {program = \"" .. fake .. "\", folder = \"" .. store .. "\", basedir = \"" .. root .. "\"})",
        "    end)",
        "rule_end()",
        "target(\"t\")",
        "    set_kind(\"static\")",
        "    add_rules(\"cached\")",
        "    add_files(\"a.c\")",
        ""}, "\n"))
    local build_log = path.join(root, "build.log")
    for _, argv in ipairs({{"f", "-P", project, "-y"}, {"build", "-P", project, "-v", "-y"}}) do
        local status = os.execv(os.programfile(), argv, {try = true, curdir = project, stdout = build_log, stderr = build_log})
        if status ~= 0 then
            table.insert(found, "xmake " .. argv[1] .. " of a project whose target is entered exited with " .. tostring(status) .. ": " .. io.readfile(build_log))
            os.tryrm(root)
            return found
        end
    end
    local built = io.readfile(build_log):gsub("\27%[[%d;]*m", "")
    if not built:find(path.join(store, "shim") .. "/", 1, true) or built:find("cache compiling", 1, true) or not built:find("compiling.release a.c", 1, true) then
        table.insert(found, "the compile of an entered target runs the shim and not through xmake's builtin cache (no \"cache compiling\"): " .. built)
    end
    local entered = {}
    for line in (io.readfile(log) or ""):gmatch("[^\n]+") do
        entered[line] = true
    end
    if not entered["arg: -c"] then
        table.insert(found, "ccache is called for the compile of an entered target: " .. tostring(io.readfile(log)))
    end

    local empty = path.join(root, "empty")
    os.mkdir(empty)
    local unchanged = stub({cc = clang})
    with_env("PATH", empty, function ()
        if ccache.program() ~= nil or ccache.enter(unchanged) ~= false or #unchanged.sets ~= 0 then
            table.insert(found, "without ccache on PATH nothing is changed on a target, and xmake's builtin cache stays on")
        end
    end)
    with_env("PATH", path.join(root, "bin") .. ":" .. empty, function ()
        if ccache.program() ~= fake then
            table.insert(found, "the ccache of PATH is used: " .. tostring(ccache.program()))
        end
        with_env("REVENANT_CCACHE", "off", function ()
            if ccache.program() ~= nil then
                table.insert(found, "REVENANT_CCACHE=off turns the compile cache off")
            end
        end)
    end)
    with_env("REVENANT_CCACHE_GB", "", function ()
        if ccache.gigabytes() ~= 4 then
            table.insert(found, "the cache is capped at 4 GB by default: " .. tostring(ccache.gigabytes()))
        end
    end)
    with_env("REVENANT_CCACHE_GB", "0.5", function ()
        if ccache.gigabytes() ~= 0.5 then
            table.insert(found, "REVENANT_CCACHE_GB sets the cap in gigabytes: " .. tostring(ccache.gigabytes()))
        end
    end)
    with_env("REVENANT_CCACHE_GB", "lots", function ()
        local message = raises(ccache.gigabytes)
        if not message or not message:find("REVENANT_CCACHE_GB", 1, true) then
            table.insert(found, "a cap that is not a number is refused by name: " .. tostring(message))
        end
    end)

    os.tryrm(root)
    return found
end
