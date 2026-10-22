local backports = path.absolute(path.join(os.scriptdir(), ".."))
local src = path.join(backports, "src", "CryptoKit")
local fixture = path.join(backports, "tests", "CryptoKit", "main.swift")
local out = path.join(backports, "..", "..", "build", "tests", "CryptoKit")

local function swiftc(args)
    os.vrunv("xcrun", table.join({"swiftc", "-O"}, args))
end

function main()
    os.mkdir(out)
    local host = path.join(out, "host")
    local backport = path.join(out, "backport")
    swiftc({fixture, "-o", host})
    swiftc({"-module-name", "CryptoKit", "-D", "REVENANT_BACKPORT", path.join(src, "Digests.swift"), path.join(src, "Authentication.swift"),
            path.join(src, "AESGCM.swift"), fixture, "-o", backport})
    os.execv(host, {}, {stdout = host .. ".out"})
    os.execv(backport, {}, {stdout = backport .. ".out"})
    local expected, got = io.readfile(host .. ".out"), io.readfile(backport .. ".out")
    assert(#expected > 0, "the host CryptoKit program printed nothing")
    assert(expected == got, "the backport CryptoKit differs from the host in " .. out)
end
