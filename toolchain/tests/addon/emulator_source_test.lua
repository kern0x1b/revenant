import("fixtures")

function failures(opt)
    local source = import("emulator_source", {rootdir = opt.modules, anonymous = true})
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
    local module = io.readfile(path.join(opt.modules, "emulator_source.lua"))
    if module:find("import(", 1, true) then
        table.insert(found, "emulator_source is included by the emulate addon, where import() is not allowed, so it must not import anything")
    end
    local repository = path.join(os.scriptdir(), "../../..")
    local recipe = io.readfile(path.join(repository, "packages", "e", "emulator", "xmake.lua"))
    if not recipe:find("emulator_source.lua", 1, true) or recipe:find("table.sort", 1, true) then
        table.insert(found, "the emulator recipe must take its default sources config from emulator_source, so a direct require gets the addon's key")
    end
    if not os.iorunv("locale", {"-a"}):find("de_DE.UTF-8", 1, true) then
        table.insert(found, "the locale check needs de_DE.UTF-8 installed on this host")
    end
    local probe = fixtures.scratch()
    local script = path.join(probe, "digest.lua")
    io.writefile(script, "local source = import(\"emulator_source\", {rootdir = os.getenv(\"EMULATOR_SOURCE_MODULES\")})\n"
                      .. "print(source.digest(os.getenv(\"EMULATOR_SOURCE_ROOT\")))\n")
    local digests = {}
    for _, locale in ipairs({"de_DE.UTF-8", "C"}) do
        local envs = table.join(os.getenvs(), {LC_ALL = locale, EMULATOR_SOURCE_MODULES = opt.modules, EMULATOR_SOURCE_ROOT = repository})
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
