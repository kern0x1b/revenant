local workspace = import("@addon.revenant.workspace", {anonymous = true})
local lowered = import("@addon.revenant.apple.lowered", {anonymous = true})
local tools = path.absolute(path.join(os.scriptdir(), "..", "tools"))
local implemented = import("implemented", {rootdir = tools, anonymous = true})
local sdkfiles = import("sdk", {rootdir = tools, anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local sources = path.join(backports, "src", "StoreKit", "AppStoreSubscriptions.swift")
local fixture = path.join(backports, "tests", "StoreKit", "main.swift")

local expected = table.concat({
    "url https://apps.apple.com/account/subscriptions",
    "scheme https",
    "host apps.apple.com",
    "path /account/subscriptions",
}, "\n") .. "\n"

local MEMBERS = {
    "-[SKPayment applicationUsername]",
    "-[SKMutablePayment setApplicationUsername:]",
}

local function key_of(member)
    local sign, owner, selector = member:match("^([%+%-])%[(%S+) ([^%]]+)%]$")
    assert(sign, "not a member: " .. member)
    return (sign == "+" and "class method" or "instance method") .. "|" .. owner .. "|" .. selector
end

local function check_payment_members()
    local sdk = os.getenv("REVENANT_GEN_SDK")
    if not sdk or sdk == "" then
        sdk = sdkfiles.sdk_folder()
    end
    local root = path.join(workspace.scratch(), "storekit-test")
    os.tryrm(root)
    local object = path.join(root, "StoreKit", "src", "StoreKit", "SKPayment+ApplicationUsername.o")
    os.mkdir(path.directory(object))
    os.vrunv("clang", {"-target", "armv7-apple-ios" .. lowered.device_release(), "-isysroot", sdk, "-fobjc-arc", "-Os", "-w", "-c", "-o", object,
        path.join(backports, "src", "StoreKit", "SKPayment+ApplicationUsername.m")})
    local keys = implemented.from_objects(root).StoreKit or {}
    local missing = {}
    for _, member in ipairs(MEMBERS) do
        if not keys[key_of(member)] then
            table.insert(missing, member)
        end
    end
    assert(#missing == 0, "members not implemented by the compiled StoreKit objects:\n" .. table.concat(missing, "\n"))
    os.tryrm(root)
end

function main()
    check_payment_members()
    local out = workspace.run("backports-tests", "StoreKit")
    local binary = path.join(out, "subscriptions")
    os.vrunv("xcrun", {"swiftc", "-O", sources, fixture, "-o", binary})
    os.execv(binary, {}, {stdout = binary .. ".out"})
    local got = io.readfile(binary .. ".out")
    assert(got == expected, "the subscriptions URL differs from the App Store page: " .. got)
end
