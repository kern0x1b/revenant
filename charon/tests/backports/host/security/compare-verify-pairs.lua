-- compare-verify-pairs.lua - the (operation, algorithm) pairs the table claims for VERIFY, and the broken pair NAMED.
--
--    xmake l compare-verify-pairs.lua <the binary's output>
--
-- Four pairs, and they are the ones where verify could go wrong in a way signing would not: an RSA key asked to verify an ECDSA
-- signature, an EC key asked to sign anything at all, and the two digest paddings the release really does carry. The padding
-- column is there so a difference in the TABLE and a difference in the PADDING are reported separately - they are different
-- mistakes.

local tsv = import("tsv", {rootdir = os.scriptdir()})

-- label, whether the table carries it, the padding it must check with. In the order the pairs are named.
local EXPECTED = {
    {"verify-rsa-sha256", true, 32772},    -- 0x8004, the release carries it
    {"verify-rsa-sha384", true, 32773},    -- 0x8005
    -- CARRIED, for the same measured reason as compare-supported.lua's ec-sign-sha256: the release has an EC key type
    -- (kSecAttrKeyTypeEC, ios(4.0), SecItem.h:802-803) and SecKeyRawVerify takes it. The padding stays kSecPaddingNone, which is 0 -
    -- a curve has no padding scheme - and this pair is the one that says so.
    {"verify-ec-sha256", true, 0},
    {"verify-rsa-ecdsa", false, 0},        -- an ECDSA algorithm asked of an RSA key is not a thing
}

function main(...)
    local args = {...}
    if #args < 1 then
        io.stderr:write("compare-verify-pairs.lua: pass the binary's output\n")
        os.exit(1)
    end
    local seen, wrong = {}, {}
    for _, line in ipairs(tsv.text_lines(tsv.read_text(args[1]))) do
        if tsv.starts_with(line, "WRONG\t") then
            wrong[#wrong + 1] = tsv.split_on(line, "\t", 1)[2]
        elseif line:find("\t", 1, true) then
            local parts = tsv.split_on(line, "\t")
            if #parts < 3 then
                -- Python indexed parts[2] past the end here, and the run ended with a traceback and exit 1
                io.stderr:write("compare-verify-pairs.lua: a row has " .. #parts .. " fields, and the pair needs 3\n")
                os.exit(1)
            end
            seen[parts[1]] = {parts[2], parts[3]}
        end
    end
    local bad = {}
    for _, line in ipairs(wrong) do
        bad[#bad + 1] = line
    end
    for _, row in ipairs(EXPECTED) do
        local label, want_carry, want_pad = row[1], row[2], row[3]
        local got = seen[label]
        if got == nil then
            bad[#bad + 1] = label .. ": the case did not ask about it"
        elseif (got[1] == "1") ~= want_carry then
            local said = got[1] == "1" and "carries" or "cannot"
            local claims = want_carry and "carries" or "cannot"
            bad[#bad + 1] = label .. ": the table said [" .. said .. "] and the port claims [" .. claims .. "]"
        elseif got[2] ~= tostring(want_pad) then
            bad[#bad + 1] = label .. ": carried, but the padding is [" .. got[2] .. "] and the header's enumerator is " .. want_pad
        end
    end
    for _, line in ipairs(bad) do
        print("DIFFERS " .. line)
    end
    if #bad > 0 then
        os.exit(1)
    end
    print("compared " .. #EXPECTED .. " verify pairs, and the padding each carried one checks with")
    os.exit(0)
end
