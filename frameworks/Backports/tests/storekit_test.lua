local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local sources = path.join(backports, "src", "StoreKit", "AppStoreSubscriptions.swift")
local fixture = path.join(backports, "tests", "StoreKit", "main.swift")

local expected = table.concat({
    "url https://apps.apple.com/account/subscriptions",
    "scheme https",
    "host apps.apple.com",
    "path /account/subscriptions",
}, "\n") .. "\n"

function main()
    local out = workspace.run("backports-tests", "StoreKit")
    local binary = path.join(out, "subscriptions")
    os.vrunv("xcrun", {"swiftc", "-O", sources, fixture, "-o", binary})
    os.execv(binary, {}, {stdout = binary .. ".out"})
    local got = io.readfile(binary .. ".out")
    assert(got == expected, "the subscriptions URL differs from the App Store page: " .. got)
end
