local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local fixture = path.join(backports, "tests", "Security", "shared_web", "main.c")
local source = path.join(backports, "src", "Security", "SharedWebCredentials8.m")

local function clang(args)
    os.vrunv("xcrun", table.join({"clang", "-Wno-deprecated-declarations", "-fblocks"}, args))
end

function main()
    local out = workspace.run("backports-tests", "SecuritySharedWeb")
    local host = path.join(out, "host")
    local backport = path.join(out, "backport")
    clang({"-o", host, fixture, "-framework", "CoreFoundation", "-framework", "Security"})
    clang({"-fobjc-arc", "-o", backport, fixture, source, "-framework", "Foundation", "-framework", "CoreFoundation",
        "-framework", "Security"})
    os.execv(host, {}, {stdout = host .. ".out"})
    os.execv(backport, {}, {stdout = backport .. ".out"})
    local expected, got = io.readfile(host .. ".out"), io.readfile(backport .. ".out")
    assert(#expected > 0, "the host shared web credential program printed nothing")
    assert(expected == got, "the backport shared web credentials differ from the host in " .. out)
end
