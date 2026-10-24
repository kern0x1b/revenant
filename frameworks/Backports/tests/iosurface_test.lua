local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local folder = path.join(backports, "tests", "IOSurface")
local program = path.join(folder, "main.c")
local oracle = path.join(folder, "oracle.c")
local wrapper = path.join(backports, "src", "IOSurface", "IOSurface11_0.m")

local MACOS = "/System/Library/Frameworks/IOSurface.framework/IOSurface"
local WRONG = "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation"

local function clang(args)
    os.vrunv("xcrun", table.join({"clang"}, args))
end

local function library(path_name)
    return "-DREVENANT_IOSURFACE_LIBRARY=\"" .. path_name .. "\""
end

function main()
    local out = workspace.run("backports-tests", "IOSurface")
    local host = path.join(out, "host")
    local backport = path.join(out, "backport")
    local broken = path.join(out, "broken")
    local frameworks = {"-framework", "Foundation", "-framework", "CoreFoundation"}
    clang(table.join({program, oracle}, frameworks, {"-o", host}))
    clang(table.join({library(MACOS), program, wrapper}, frameworks, {"-o", backport}))
    clang(table.join({library(WRONG), program, wrapper}, frameworks, {"-o", broken}))
    os.execv(host, {}, {stdout = host .. ".out"})
    os.execv(backport, {}, {stdout = backport .. ".out"})
    local expected, got = io.readfile(host .. ".out"), io.readfile(backport .. ".out")
    assert(#expected > 0, "the host IOSurface program printed nothing")
    assert(expected == got, "the backport IOSurface results differ from the host in " .. out)
    local code = os.execv(broken, {}, {try = true, stdout = broken .. ".out"})
    local seen = io.readfile(broken .. ".out")
    assert(code ~= 0 or seen ~= expected, "the negative control with a library that lacks IOSurface matched the host in " .. out)
end
