local ROOT = path.absolute(path.join(os.scriptdir(), "..", "..", ".."))
local TOOLS = path.join(ROOT, "frameworks", "ReactNative", "tools")
local ENTITLEMENTS = path.join(TOOLS, "data", "rnhost.entitlements")

local host = import("host_install", {rootdir = TOOLS, anonymous = true})

local function expect(name, condition, detail)
    if not condition then
        raise("%s: %s", name, detail)
    end
    print(name .. ": passes")
end

function main()
    local value = os.iorunv("plutil", {"-extract", "aps-environment", "raw", "-o", "-", ENTITLEMENTS}):trim()
    expect("the host entitlements declare aps-environment", value == "development", "aps-environment is " .. value)

    local first = host.signing_arguments(ENTITLEMENTS, 1, "RNHost")
    expect("the executable is signed with the entitlements", first[1] == "-S" .. ENTITLEMENTS and first[2] == "RNHost" and #first == 2,
        "got " .. table.concat(first, " "))

    local other = host.signing_arguments(ENTITLEMENTS, 2, "libUIKitBackports.dylib")
    expect("a framework is signed without entitlements", other[1] == "-S" and other[2] == "libUIKitBackports.dylib" and #other == 2,
        "got " .. table.concat(other, " "))
end
