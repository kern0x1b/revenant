local tsv = import("tsv", {rootdir = os.scriptdir()})

local EXPECTED = {
    {"verify-rsa-sha256", true, 32772},
    {"verify-rsa-sha384", true, 32773},
    {"verify-ec-sha256", true, 0},
    {"verify-rsa-ecdsa", false, 0},
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
