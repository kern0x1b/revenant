-- compare.lua - holds the guest's answers to the host's, key by key.
--
--     CMP_EXPECT=<host-expectations.txt> CMP_GUEST=<guest output> xmake lua tests/backports/device/metal-probes/compare.lua
--
-- Each expectation is a line key=value and is Apple's answer, measured on the host. Each guest line key=value is the
-- port's answer to the same question, from the same probe source built for the port. A key the guest did not print is
-- NOT ANSWERED; a key with a different value is DIFFER. Both count as failures, and the exit status says so: a
-- divergence recorded in the expectations is still a divergence, and this file does not hide one.
--
-- Exit status: 0 every key is the same; 1 at least one key differs or was not answered.

local expect_path = os.getenv("CMP_EXPECT")
local guest_path = os.getenv("CMP_GUEST")

local function read_lines(p)
    local f = io.open(p, "r")
    if not f then
        print("compare: cannot read " .. p)
        os.exit(2)
    end
    local out = {}
    for line in f:lines() do out[#out + 1] = line end
    f:close()
    return out
end

-- key=value lines of a file: a comment (#) and a line without "=" are not answers.
local function answers(lines)
    local out, order = {}, {}
    for _, line in ipairs(lines) do
        if not line:match("^#") then
            local key, value = line:match("^([%w%._]+)=(.*)$")
            if key then
                if out[key] == nil then order[#order + 1] = key end
                out[key] = value
            end
        end
    end
    return out, order
end

local expected, order = answers(read_lines(expect_path))
local guest = answers(read_lines(guest_path))

local same, differ, missing = 0, 0, 0
for _, key in ipairs(order) do
    local want = expected[key]
    local got = guest[key]
    if got == nil then
        missing = missing + 1
        print(string.format("  NOT ANSWERED  %s  host=%s", key, want))
    elseif got == want then
        same = same + 1
    else
        differ = differ + 1
        print(string.format("  DIFFER        %s  host=%s  port=%s", key, want, got))
    end
end

print(string.format("compare: %d key(s), %d the same, %d differ, %d not answered", #order, same, differ, missing))
os.exit((differ > 0 or missing > 0) and 1 or 0)
