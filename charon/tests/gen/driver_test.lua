local DRIVER = path.join(os.scriptdir(), "..", "..", "tools", "gen.lua")

local function driver(args)
    return os.iorunv("/bin/sh", {"-c", string.format('xmake l "%s" %s 2>&1; true', DRIVER, args)})
end

function main()
    local failures = 0
    local function check(ok, label)
        if not ok then
            failures = failures + 1
            print("FAIL " .. label)
        end
    end

    local roundtrip = driver("roundtrip")
    check(string.find(roundtrip, "--tree is required", 1, true) == nil, "--tree is not required: the checkout is the default")
    check(string.find(roundtrip, "--sdk (the SDK folder) is required", 1, true) ~= nil,
          "the command reaches its own check once the tree is the default")

    local usage = driver("nosuchcommand")
    check(string.find(usage, "[--tree T]", 1, true) ~= nil, "the usage shows --tree as optional")
    check(string.find(usage, "default: the one this script is in", 1, true) ~= nil, "the usage names the default checkout")

    print("driver test: " .. (failures == 0 and "OK" or ("FAIL " .. failures)))
    if failures > 0 then
        os.exit(1)
    end
end
