-- The driver (tools/gen.lua): a command that reads and writes a tree takes --tree from the checkout the script is in when none is
-- given (the error about a missing --tree is gone), and the usage text names the option and its default. The commands are run as
-- the user runs them, so the test shows what the driver prints. Run: xmake l tests/gen/driver_test.lua

local DRIVER = path.join(os.scriptdir(), "..", "..", "tools", "gen.lua")

-- The output (stdout and stderr) of one driver run.
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

    -- roundtrip reads its arguments in order: the tree is found (no default is needed to get past it), then the SDK is asked for
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
