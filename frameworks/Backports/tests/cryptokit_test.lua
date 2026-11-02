local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local fixture = path.join(backports, "tests", "CryptoKit", "main.swift")

function main()
    local out = workspace.run("backports-tests", "CryptoKit")
    local host = path.join(out, "host")
    os.vrunv("xcrun", {"swiftc", "-O", fixture, "-o", host})
    os.execv(host, {}, {stdout = host .. ".out"})
    local text = io.readfile(host .. ".out")
    assert(#text > 0, "the SDK CryptoKit program printed nothing")
    local ended = false
    for line in text:gmatch("[^\n]+") do
        if line == "all true" then
            ended = true
        else
            assert(line:find(" true$"), "an SDK CryptoKit vector fails: " .. line)
        end
    end
    assert(ended, "the SDK CryptoKit program did not reach its last line:\n" .. text)
end
