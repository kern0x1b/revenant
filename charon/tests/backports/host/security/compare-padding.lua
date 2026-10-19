-- compare-padding.lua - the padding each algorithm must map to, and the broken pair NAMED on a difference.
--
--    xmake l compare-padding.lua <the binary's output>
--
-- The expectation is the SDK's OWN enumerator, read by the case at run time and compared here against the same enumerator - so
-- the numbers are the header's and not a spelling copied out of a document. The case also prints a WRONG line of its own, and a
-- run that produced one of those is a failure whatever this script says.

local tsv = import("tsv", {rootdir = os.scriptdir()})

-- In the order the algorithms are named, so the DIFFERS lines come out in that order.
local EXPECTED = {
    {"pkcs1-sha1", 32770},     -- 0x8002
    {"pkcs1-sha224", 32771},   -- 0x8003
    {"pkcs1-sha256", 32772},   -- 0x8004
    {"pkcs1-sha384", 32773},   -- 0x8005
    {"pkcs1-sha512", 32774},   -- 0x8006
    {"ecdsa-sha256", 0},       -- kSecPaddingNone: the release cannot carry it
}

function main(...)
    local args = {...}
    if #args < 1 then
        io.stderr:write("compare-padding.lua: pass the binary's output\n")
        os.exit(1)
    end
    local seen, wrong = {}, {}
    for _, line in ipairs(tsv.text_lines(tsv.read_text(args[1]))) do
        if tsv.starts_with(line, "WRONG\t") then
            wrong[#wrong + 1] = tsv.split_on(line, "\t", 1)[2]
        elseif line:find("\t", 1, true) then
            local parts = tsv.split_on(line, "\t", 1)
            seen[parts[1]] = parts[2]
        end
    end
    local bad = {}
    for _, line in ipairs(wrong) do
        bad[#bad + 1] = line
    end
    for _, pair in ipairs(EXPECTED) do
        local name, want = pair[1], pair[2]
        local got = seen[name]
        if got == nil or got ~= tostring(want) then
            bad[#bad + 1] = name .. ": answered [" .. (got or "None") .. "] and the header's enumerator is " .. want
        end
    end
    for _, line in ipairs(bad) do
        print("DIFFERS " .. line)
    end
    if #bad > 0 then
        os.exit(1)
    end
    print("compared " .. #EXPECTED .. " algorithm/padding pairs: every one is the header's own enumerator")
    os.exit(0)
end
