local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local src = path.join(backports, "src", "Network")
local fixture = path.join(backports, "tests", "Network", "main.swift")

local function swiftc(args)
    os.vrunv("xcrun", table.join({"swiftc", "-O"}, args))
end

function main()
    local out = workspace.run("backports-tests", "Network")
    local host = path.join(out, "host")
    local backport = path.join(out, "backport")
    swiftc({fixture, "-o", host})
    swiftc(table.join({"-D", "REVENANT_BACKPORT"}, os.files(path.join(src, "*.swift")), {fixture, "-o", backport}))
    os.execv(host, {}, {stdout = host .. ".out"})
    os.execv(backport, {}, {stdout = backport .. ".out"})
    local expected, got = io.readfile(host .. ".out"), io.readfile(backport .. ".out")
    assert(#expected > 0, "the host Network program printed nothing")
    assert(expected == got, "the backport Network differs from the host in " .. out)
    local types = path.join(out, "interface-types")
    swiftc({path.join(src, "IPv4Address.swift"), path.join(src, "IPv6Address.swift"), path.join(src, "NWEndpoint.swift"),
            path.join(src, "NWInterface.swift"), path.join(src, "NWError.swift"), path.join(src, "NWPathMonitor.swift"),
            path.join(src, "NWConnection.swift"), path.join(backports, "tests", "Network", "types", "main.swift"), "-o", types})
    os.execv(types, {}, {stdout = types .. ".out"})
    assert(io.readfile(types .. ".out"):find("network interface types ok", 1, true),
           "the backport's interface types do not follow the reachability flags: " .. out)
end
