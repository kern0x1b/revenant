import("fixtures")
import("core.package.addon")

-- What a port reaches through @addon/charon is the addon, not the files of this checkout, so the rules of a port - the
-- toolchain, the checks after the link, the placement - are exercised only where a port is really built. The suites
-- around this one build objects and binaries by hand and never take that road, which is how a call in the checks after
-- the link went missing without a single test turning red.
--
-- The addon is installed the way a port installs one, from a repository, and the repository here is a copy of this
-- working tree rather than its history: a test must check the files as they are now, not as they were committed.

local MAIN = "int main(void) { return 0; }\n"

-- A release older than the call it makes: the checks after the link read the imports of the binary and name what carries
-- each one. os_unfair_lock_lock is one of the symbols a whole process shares, so the remedy for it is the C++ runtime,
-- which exports it once; dispatch_activate is an ordinary one, and apple-compat carries it per image.
local LOCKED = "extern void os_unfair_lock_lock(void *lock);\nstatic long word;\nint main(void) { os_unfair_lock_lock(&word); return 0; }\n"
local LATER = "extern void dispatch_activate(void *object);\nint main(void) { dispatch_activate(0); return 0; }\n"

-- A release mode (mode.release, mode.releasedbg) strips a target that sets no strip of its own, and on Apple platforms its
-- strip is -Wl,-x -Wl,-dead_strip: the checks after the link would find no function names for the rebased code pointer
-- below, and refuse the port as stripped. The rules keep the dead-code removal and leave the names to their own strip afterwards, so the
-- port builds and the function nothing references is gone; a debug build, which strips nothing, is the control that the
-- function is there to be removed. A target that asks for strip "all" itself still reaches the checks stripped.
local RELEASED = "int unreferenced_probe(void) { return 2; }\nstatic int answer(void) { return 1; }\n" ..
                 "int (*volatile hook)(void) = answer;\nint main(void) { return hook(); }\n"
local MODES = 'add_rules("mode.release", "mode.releasedbg", "mode.debug")'

local CONTROL = "Package: org.charon.porttest\nName: Port test\nArchitecture: iphoneos-arm\nDescription: a port the tests build\n"

local PROJECT = [[
add_repositories("charon %s")
add_addons("charon %s")
set_config("apple_minimum", "6.0")
includes("@addon/charon/apple-ios")
set_allowedplats("iphoneos")
set_allowedarchs("iphoneos|armv7")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")
%s
target("probe")
    add_rules("@addon/charon/daemon")
    add_files("main.c")
    set_values("charon.control", "control")
%s
]]

-- head goes before the target, body inside it.
local function port(folder, version, name, source, head, body)
    local at = path.join(folder, name)
    os.mkdir(at)
    io.writefile(path.join(at, "main.c"), source)
    io.writefile(path.join(at, "control"), CONTROL)
    io.writefile(path.join(at, "xmake.lua"), string.format(PROJECT, folder .. "/charon", version, head or "", body or ""))
    return at
end

function failures(opt)
    local found = {}
    local folder = fixtures.scratch()
    local copy, version = fixtures.repository(folder)

    -- A port that asks for nothing an old release lacks is built, placed and checked, and its binary is there.
    local plain = port(folder, version, "plain", MAIN)
    local refused = fixtures.refusal(function () fixtures.build(plain) end)
    if refused then
        table.insert(found, "a daemon port that calls nothing an old release lacks must build: " .. refused)
    elseif #os.files(path.join(plain, "build", "**", "probe")) == 0 then
        table.insert(found, "the daemon rule built no binary for the port")
    end

    -- The checks after the link answer with the library that carries the call, and the answer differs: a symbol one image
    -- may carry comes from apple-compat, and one the whole process shares comes from the C++ runtime that exports it once.
    for _, case in ipairs({{"later", LATER, "apple%-compat::dispatch_activate"},
                           {"locked", LOCKED, "charon@libcxx"}}) do
        local told = fixtures.refusal(function () fixtures.build(port(folder, version, case[1], case[2])) end)
        if not told then
            table.insert(found, string.format("a port calling %s must be refused at %s", case[1], "iOS 6.0"))
        elseif not told:find(case[3]) then
            table.insert(found, string.format("the refusal of the %s port must name %s: %s", case[1], case[3], told))
        end
    end
    -- A release mode's strip waits for the checks after the link, and its dead-code removal stays.
    -- The symbols of the port's binary in a mode, or nil when that build left no binary to read.
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

    -- The addon this installed is named after the tree it copied, so it is this run's and no other's; a test that leaves
    -- one behind would leave one for every run it ever made. Both halves go: the files, and the registry entry that
    -- names them - an entry whose files are gone is worse than the files, because the next install reads it and stops.
    addon.unregister("charon", version)
    os.tryrm(path.join(addon.installdir(), addon.dirname("charon"), version))
    os.tryrm(folder)
    return found
end
