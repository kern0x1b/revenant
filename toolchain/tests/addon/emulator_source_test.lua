import("fixtures")

function failures(opt)
    local repository = path.join(os.scriptdir(), "../../..")
    local port = path.join(repository, "packages", "e", "emulator", "port")
    local source = import("sources", {rootdir = port, anonymous = true})
    local found = {}
    local root = fixtures.scratch()
    os.mkdir(path.join(root, "emulator", "src"))
    io.writefile(path.join(root, "emulator", "src", "a.cpp"), "one\n")
    io.writefile(path.join(root, "emulator", "b.h"), "two\n")
    local first = source.requirement_configs(root).sources
    if first == nil then
        table.insert(found, "the sources of an emulator folder must give the emulator package a sources config")
    end
    io.writefile(path.join(root, "emulator", "src", "a.cpp"), "three\n")
    if source.requirement_configs(root).sources == first then
        table.insert(found, "a changed emulator source must change the emulator package's sources config, or xmake reuses the old emulator")
    end
    io.writefile(path.join(root, "emulator", "src", "a.cpp"), "one\n")
    if source.requirement_configs(root).sources ~= first then
        table.insert(found, "restoring an emulator source must restore the sources config")
    end
    local empty = fixtures.scratch()
    if source.requirement_configs(empty).sources ~= nil then
        table.insert(found, "a checkout without emulator sources must pass no sources config")
    end
    local module = io.readfile(path.join(port, "sources.lua"))
    if module:find("import(", 1, true) then
        table.insert(found, "sources.lua is included by the emulator recipe and the emulate addon, where import() is not allowed, so it must not import anything")
    end
    local recipe = io.readfile(path.join(port, "..", "xmake.lua"))
    if not recipe:find('"port", "sources.lua"', 1, true) or recipe:find("table.sort", 1, true) then
        table.insert(found, "the emulator recipe must take its default sources config from port/sources.lua, so a direct require gets the addon's key")
    end
    local launcher_test = fixtures.scratch()
    local launcher_source = path.join(repository, "emulator", "src", "guest", "revenant-sblaunch.c")
    local launcher_binary = path.join(launcher_test, "revenant-sblaunch")
    local launcher = io.readfile(launcher_source)
    if not launcher:find('if (dyld_statistics)\n        CFDictionarySetValue(environment, CFSTR("DYLD_PRINT_STATISTICS")', 1, true) then
        table.insert(found, "revenant-sblaunch must add DYLD_PRINT_STATISTICS to the launch environment only when requested")
    end
    os.vrunv("clang", {"-framework", "CoreFoundation", launcher_source, "-o", launcher_binary})
    local launch_error = fixtures.refusal(function ()
        os.vrunv(launcher_binary, {"--dyld-statistics", "org.example.probe"})
    end) or ""
    if not launch_error:find("SpringBoardServices", 1, true) then
        table.insert(found, "revenant-sblaunch must accept the optional dyld statistics flag and reach its launch service, said " .. launch_error)
    end
    os.tryrm(launcher_test)
    if not os.iorunv("locale", {"-a"}):find("de_DE.UTF-8", 1, true) then
        table.insert(found, "the locale check needs de_DE.UTF-8 installed on this host")
    end
    local probe = fixtures.scratch()
    local script = path.join(probe, "digest.lua")
    io.writefile(script, "local source = import(\"sources\", {rootdir = os.getenv(\"EMULATOR_SOURCE_PORT\")})\n"
                      .. "print(source.digest(os.getenv(\"EMULATOR_SOURCE_ROOT\")))\n")
    local digests = {}
    for _, locale in ipairs({"de_DE.UTF-8", "C"}) do
        local envs = table.join(os.getenvs(), {LC_ALL = locale, EMULATOR_SOURCE_PORT = port, EMULATOR_SOURCE_ROOT = repository})
        local output = os.iorunv(os.programfile(), {"lua", script}, {curdir = probe, envs = envs})
        for line in output:gmatch("[^\n]+") do
            if line:match("^%x+$") then
                digests[locale] = line
            end
        end
    end
    if digests["de_DE.UTF-8"] ~= digests["C"] or digests["C"] ~= source.digest(repository) then
        table.insert(found, "the emulator sources digest must not depend on the locale: de_DE.UTF-8 gave " .. tostring(digests["de_DE.UTF-8"]) .. ", C gave " .. tostring(digests["C"]))
    end
    for _, locale in ipairs({"de_DE.UTF-8", "C"}) do
        local envs = table.join(os.getenvs(), {LC_ALL = locale, REVENANT_REPO = repository})
        local output = os.iorunv("/bin/sh", {"-c", '"$0" "$@" 2>&1', os.programfile(), "require", "--info", "-P", repository, "emulator"},
                                 {curdir = probe, envs = envs})
        local default = output:gsub("\27%[[%d;]*m", ""):match("sources: The digest[^\n]*default: (%x+)")
        if default ~= source.digest(repository) then
            table.insert(found, "the emulator recipe's sources default must be the addon's digest under " .. locale .. ", got " .. tostring(default))
        end
    end
    os.tryrm(probe)
    local addon = io.readfile(path.join(os.scriptdir(), "../../includes/emulate/xmake.lua"))
    if not addon:find("requirement_configs", 1, true) then
        table.insert(found, "the emulate addon must give the emulator package its sources config from the checkout, so a changed source is a new package")
    end
    os.tryrm(root)
    os.tryrm(empty)
    return found
end
