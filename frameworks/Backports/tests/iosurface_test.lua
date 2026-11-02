local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local folder = path.join(backports, "tests", "IOSurface")
local program = path.join(folder, "main.c")
local oracle = path.join(folder, "oracle.c")
local implementation = path.join(backports, "src", "IOSurface", "IOSurfaceCPU.m")

local function clang(args)
    os.vrunv("xcrun", table.join({"clang"}, args))
end

function main()
    local out = workspace.run("backports-tests", "IOSurface")
    local host = path.join(out, "host")
    local backport = path.join(out, "backport")
    local frameworks = {"-framework", "Foundation", "-framework", "CoreFoundation"}
    clang(table.join({program, oracle}, frameworks, {"-o", host}))
    clang(table.join({program, implementation}, frameworks, {"-o", backport}))
    os.execv(host, {}, {stdout = host .. ".out"})
    os.execv(backport, {}, {stdout = backport .. ".out"})
    local expected, got = io.readfile(host .. ".out"), io.readfile(backport .. ".out")
    assert(#expected > 0, "the host IOSurface program printed nothing")
    assert(expected == got, "the backport IOSurface results differ from the host in " .. out)
end
