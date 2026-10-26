import("fixtures")

local SCANNED = {"packages", "toolchain", "frameworks", "emulator", "tools"}
local VERBS = {"f", "build", "install", "require"}

local COMPAT_NEEDS = {"iphoneos-sdk", "ld64", "llvm"}
local COMPAT_LISTING = [[
import("core.project.config")
import("core.project.project")

function main()
    config.load()
    local names = {}
    for name, _ in pairs(project.required_packages() or {}) do
        table.insert(names, name)
    end
    table.sort(names)
    for _, name in ipairs(names) do
        print("REQUIRE " .. name)
    end
end
]]

local function unscoped(file)
    local found = {}
    local number = 0
    for line in (io.readfile(file) .. "\n"):gmatch("([^\n]*)\n") do
        number = number + 1
        if line:find("os.programfile()", 1, true) and not line:find('"-P"', 1, true) then
            for _, verb in ipairs(VERBS) do
                if line:find('{"' .. verb .. '"', 1, true) then
                    table.insert(found, number)
                    break
                end
            end
        end
    end
    return found
end

function failures(opt)
    local found = {}
    local repository = path.join(os.scriptdir(), "../../..")
    for _, folder in ipairs(SCANNED) do
        for _, file in ipairs(os.files(path.join(repository, folder, "**.lua"))) do
            for _, number in ipairs(unscoped(file)) do
                table.insert(found, string.format("%s:%d runs xmake f, build, install or require without -P: the project then is the outermost xmake.lua above its folder, which is the checkout's root project, and that project requires packages a nested configure must not wait for inside a package install", path.relative(file, repository), number))
            end
        end
    end
    local root = fixtures.scratch()
    local nested = path.join(root, "outer", "nested")
    os.mkdir(nested)
    io.writefile(path.join(nested, "xmake.lua"), "set_project(\"nested-fixture\")\ntarget(\"nested-only\")\n    set_kind(\"phony\")\n")
    local probe = path.join(nested, "probe.lua")
    io.writefile(probe, "function main()\n    print(os.projectdir())\nend\n")
    local log = path.join(nested, "configure.log")
    local status = os.execv(os.programfile(), {"f", "-P", nested, "-y"}, {try = true, stdout = log, stderr = log, curdir = nested})
    if status ~= 0 then
        table.insert(found, "a nested project configured with -P must configure on its own, but xmake f -P exited with " .. tostring(status) .. ": " .. io.readfile(log))
    end
    local seen = os.iorunv(os.programfile(), {"l", "-P", nested, probe}):trim()
    if seen ~= nested then
        table.insert(found, string.format("xmake with -P %s must load that project, not the outermost xmake.lua above it: it loaded %s", nested, seen))
    end

    local compat = path.join(root, "compat")
    os.mkdir(compat)
    io.writefile(path.join(compat, "xmake.lua"), table.concat({
        "add_repositories(\"revenant " .. path.absolute(repository) .. "\")",
        "add_addons(\"revenant\", {sourcedir = \"" .. path.absolute(path.join(repository, "toolchain")) .. "\"})",
        "set_config(\"apple_minimum\", \"6.1.3\")",
        "set_config(\"apple_compat_only\", true)",
        "includes(\"@addon/revenant/apple-ios\")",
        "set_defaultplat(\"iphoneos\")",
        "set_defaultarchs(\"iphoneos|armv7\")",
        ""}, "\n"))
    local configure_log = path.join(compat, "configure.log")
    local envs = {XMAKE_CONFIGDIR = path.join(compat, "configdir")}
    local configured = os.execv(os.programfile(), {"f", "-P", compat, "-p", "iphoneos", "-a", "armv7", "-m", "release", "-y", "--require=n"},
                                {try = true, stdout = configure_log, stderr = configure_log, curdir = compat, envs = envs})
    if configured ~= 0 then
        table.insert(found, "the nested apple-compat project must configure without installing, but xmake f exited with " .. tostring(configured) .. ": " .. io.readfile(configure_log))
    end
    local listing = path.join(compat, "listing.lua")
    io.writefile(listing, COMPAT_LISTING)
    local listed = {}
    for line in os.iorunv(os.programfile(), {"l", "-P", compat, listing}, {curdir = compat, envs = envs}):gmatch("[^\n]+") do
        local name = line:match("^REQUIRE (.+)$")
        if name then
            table.insert(listed, name)
        end
    end
    table.sort(listed)
    for _, name in ipairs(COMPAT_NEEDS) do
        if not table.contains(listed, name) then
            table.insert(found, "the nested apple-compat project must require " .. name .. ", and it requires " .. table.concat(listed, ", "))
        end
    end
    for _, name in ipairs(listed) do
        if not table.contains(COMPAT_NEEDS, name) then
            table.insert(found, "the nested apple-compat project requires " .. name .. ", which apple-compat does not need: configuring it installs that package's dependencies inside a package install")
        end
    end
    os.tryrm(root)
    return found
end
