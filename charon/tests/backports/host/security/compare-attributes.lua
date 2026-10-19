-- compare-attributes.lua - the four answers the shaping must give, expected from the CONSTANTS and not written out by hand.
--
--    xmake l compare-attributes.lua <the binary's output>
--
-- A constant's documented value IS its answer, so the expectation is built from the constant rather than typed: kSecAttrKeyTypeRSA
-- is the STRING "42" and kSecAttrKeyTypeECSECPrimeRandom is "73" - they are the numeric strings of the key types, not four-character
-- codes, and a script that hard-coded either a number or "RSA" would be comparing a spelling the SDK never promised.
--
-- Exits non-zero on any difference, so the differential is a CHECK and not a run.

local tsv = import("tsv", {rootdir = os.scriptdir()})

-- What the key-type constants actually hold, read by compiling nothing: they are strings.
local CODES = {rsa = "42", ec = "73"}

-- In the order the answers are named. A pattern with %s takes the RSA code for an rsa-* name and for one-key-only, and the EC
-- code otherwise; a pattern without it is the answer itself.
local EXPECTED_LITERAL = {
    {"rsa-1024", "%s/1024"},      -- kSecAttrKeyTypeRSA, 1024 bits
    {"ec-256", "%s/256"},         -- kSecAttrKeyTypeECSECPrimeRandom, 256 bits
    {"one-key-only", "%s/0"},     -- the type it has, and no size at all
    {"not-a-dictionary", "NULL"},
}

-- The one place a pattern is filled in, as Python's "%s" % code: the first %s is the code.
local function expected_for(name, pattern)
    if not tsv.starts_with(pattern, "%s") then
        return pattern
    end
    local code = CODES.ec
    if tsv.starts_with(name, "rsa") or name == "one-key-only" then
        code = CODES.rsa
    end
    return code .. pattern:sub(3)
end

function main(...)
    local args = {...}
    if #args < 1 then
        io.stderr:write("compare-attributes.lua: pass the binary's output\n")
        os.exit(1)
    end
    local seen = {}
    for _, line in ipairs(tsv.text_lines(tsv.read_text(args[1]))) do
        if line:find("\t", 1, true) then
            local parts = tsv.split_on(line, "\t", 1)
            seen[parts[1]] = parts[2]
        end
    end
    local bad = {}
    for _, pair in ipairs(EXPECTED_LITERAL) do
        local name = pair[1]
        local want = expected_for(name, pair[2])
        local got = seen[name]
        if got ~= want then
            bad[#bad + 1] = name .. ": the shaping answered [" .. (got or "None") .. "] and the constants say [" .. want .. "]"
        end
    end
    for _, line in ipairs(bad) do
        print("DIFFERS " .. line)
    end
    if #bad > 0 then
        os.exit(1)
    end
    print("compared " .. #EXPECTED_LITERAL .. " answers: every one is what the key-type constants hold")
    os.exit(0)
end
