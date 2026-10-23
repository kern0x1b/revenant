local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local src = path.join(backports, "src", "Network")
local fixture = path.join(backports, "tests", "Network", "tlsserver", "main.swift")
local identity = path.join(backports, "tests", "Network", "tls", "identity.p12")

local function swiftc(args)
    os.vrunv("xcrun", table.join({"swiftc", "-O"}, args))
end

function main()
    local out = workspace.run("backports-tests", "NetworkTLSListener")
    local host = path.join(out, "host")
    local backport = path.join(out, "backport")
    swiftc({fixture, "-o", host})
    swiftc(table.join({"-D", "REVENANT_BACKPORT"}, os.files(path.join(src, "*.swift")), {fixture, "-o", backport}))
    os.execv(host, {identity}, {stdout = host .. ".out"})
    os.execv(backport, {identity}, {stdout = backport .. ".out"})
    local expected, got = io.readfile(host .. ".out"), io.readfile(backport .. ".out")
    assert(#expected > 0, "the host Network TLS listener program printed nothing")
    assert(expected:find("tls listener server negotiated h2", 1, true), "the host did not negotiate h2")
    local function withoutNegotiated(text)
        local kept = {}
        for line in text:gmatch("[^\n]+") do
            if not line:find("negotiated", 1, true) then
                table.insert(kept, line)
            end
        end
        return table.concat(kept, "\n")
    end
    assert(withoutNegotiated(expected) == withoutNegotiated(got), "the backport Network TLS differs from the host in " .. out)
end
