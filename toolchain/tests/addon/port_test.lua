import("fixtures")
import("core.package.addon")

local MAIN = "int main(void) { return 0; }\n"

local LOCKED = "extern void os_unfair_lock_lock(void *lock);\nstatic long word;\nint main(void) { os_unfair_lock_lock(&word); return 0; }\n"
local LATER = "extern void dispatch_activate(void *object);\nint main(void) { dispatch_activate(0); return 0; }\n"

local RELEASED = "int unreferenced_probe(void) { return 2; }\nstatic int answer(void) { return 1; }\n" ..
                 "int (*volatile hook)(void) = answer;\nint main(void) { return hook(); }\n"
local MODES = 'add_rules("mode.release", "mode.releasedbg", "mode.debug")'

local CONTROL = "Package: org.revenant.porttest\nName: Port test\nArchitecture: iphoneos-arm\nDescription: a port the tests build\n"

local PROJECT = [[
add_repositories("revenant %s")
add_addons("revenant %s")
set_config("apple_minimum", "6.0")
includes("@addon/revenant/apple-ios")
set_allowedplats("iphoneos")
set_allowedarchs("iphoneos|armv7")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")
%s
target("probe")
    add_rules("@addon/revenant/daemon")
    add_files("main.c")
    set_values("revenant.control", "control")
%s
]]

local function port(folder, version, name, source, head, body)
    local at = path.join(folder, name)
    os.mkdir(at)
    io.writefile(path.join(at, "main.c"), source)
    io.writefile(path.join(at, "control"), CONTROL)
    io.writefile(path.join(at, "xmake.lua"), string.format(PROJECT, folder .. "/revenant", version, head or "", body or ""))
    return at
end

function failures(opt)
    local found = {}
    local folder = fixtures.scratch()
    local copy, version = fixtures.repository(folder)

    local plain = port(folder, version, "plain", MAIN)
    local refused = fixtures.refusal(function () fixtures.build(plain) end)
    if refused then
        table.insert(found, "a daemon port that calls nothing an old release lacks must build: " .. refused)
    elseif #os.files(path.join(plain, "build", "**", "probe")) == 0 then
        table.insert(found, "the daemon rule built no binary for the port")
    end

    for _, case in ipairs({{"later", LATER, "apple%-compat::dispatch_activate"},
                           {"locked", LOCKED, "revenant@libcxx"}}) do
        local told = fixtures.refusal(function () fixtures.build(port(folder, version, case[1], case[2])) end)
        if not told then
            table.insert(found, string.format("a port calling %s must be refused at %s", case[1], "iOS 6.0"))
        elseif not told:find(case[3]) then
            table.insert(found, string.format("the refusal of the %s port must name %s: %s", case[1], case[3], told))
        end
    end
    local names = function (at, mode)
        local binary = os.files(path.join(at, "build", "iphoneos", "armv7", mode, "probe"))[1]
        return binary and os.iorunv("nm", {binary})
    end
    local released = port(folder, version, "released", RELEASED, MODES)
    refused = fixtures.refusal(function () fixtures.build(released, "debug") end)
    local kept = not refused and names(released, "debug")
    if refused then
        table.insert(found, "the release-mode port must build in debug mode: " .. refused)
    elseif not kept then
        table.insert(found, "the debug build of the release-mode port left no binary")
    elseif not kept:find("_unreferenced_probe", 1, true) then
        table.insert(found, "a debug build must keep the function nothing references, the control for the release builds")
    else
        for _, mode in ipairs({"release", "releasedbg"}) do
            refused = fixtures.refusal(function () fixtures.build(released, mode) end)
            local symbols = not refused and names(released, mode)
            if refused then
                table.insert(found, string.format("a port that sets no strip must build in mode.%s: %s", mode, refused))
            elseif not symbols then
                table.insert(found, string.format("the mode.%s build of the port left no binary", mode))
            elseif symbols:find("_unreferenced_probe", 1, true) then
                table.insert(found, string.format("mode.%s must still link with -dead_strip: the function nothing references is in the binary", mode))
            end
        end
    end
    local told = fixtures.refusal(function () fixtures.build(port(folder, version, "stripped", RELEASED, MODES, '    set_strip("all")'), "release") end)
    if not told then
        table.insert(found, 'a port that sets strip "all" itself must be refused in mode.release')
    elseif not told:find("arrived stripped", 1, true) then
        table.insert(found, 'the refusal of a port that sets strip "all" must say it arrived stripped: ' .. told)
    end

    addon.unregister("revenant", version)
    os.tryrm(path.join(addon.installdir(), addon.dirname("revenant"), version))
    os.tryrm(folder)
    return found
end
