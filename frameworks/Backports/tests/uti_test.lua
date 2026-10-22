local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local src = path.join(backports, "src", "UniformTypeIdentifiers")
local fixture = path.join(backports, "tests", "UniformTypeIdentifiers", "main.swift")

local function swiftc(args)
    os.vrunv("xcrun", table.join({"swiftc", "-O"}, args))
end

function main()
    local out = workspace.run("backports-tests", "UniformTypeIdentifiers")
    local host = path.join(out, "host")
    local backport = path.join(out, "backport")
    swiftc({fixture, "-o", host})
    swiftc({"-D", "REVENANT_BACKPORT", path.join(src, "StandardTypes.swift"), path.join(src, "Constants.swift"),
            path.join(src, "UTType.swift"), path.join(src, "URL.swift"), fixture, "-o", backport})
    os.execv(host, {}, {stdout = host .. ".out"})
    os.execv(backport, {}, {stdout = backport .. ".out"})
    local expected, got = io.readfile(host .. ".out"), io.readfile(backport .. ".out")
    assert(#expected > 0, "the host UniformTypeIdentifiers program printed nothing")
    assert(expected == got, "the backport UniformTypeIdentifiers differs from the host in " .. out)
end
