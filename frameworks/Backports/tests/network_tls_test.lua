local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local src = path.join(backports, "src", "Network")
local fixture = path.join(backports, "tests", "Network", "tls", "main.swift")
local identity = path.join(backports, "tests", "Network", "tls", "identity.p12")

local function swiftc(args)
    os.vrunv("xcrun", table.join({"swiftc", "-O"}, args))
end

function main()
    local out = workspace.run("backports-tests", "NetworkTLS")
    local host = path.join(out, "host")
    local backport = path.join(out, "backport")
    swiftc({fixture, "-o", host})
    swiftc(table.join({"-D", "REVENANT_BACKPORT"}, os.files(path.join(src, "*.swift")), {fixture, "-o", backport}))
    os.execv(host, {identity}, {stdout = host .. ".out"})
    os.execv(backport, {identity}, {stdout = backport .. ".out"})
    local expected, got = io.readfile(host .. ".out"), io.readfile(backport .. ".out")
    assert(#expected > 0, "the host Network TLS program printed nothing")
    assert(expected == got, "the backport Network TLS differs from the host in " .. out)
end
