import("fixtures")

local SCANNED = {"packages", "toolchain", "frameworks", "emulator", "tools"}
local VERBS = {"f", "build", "install", "require"}

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
    return found
end
