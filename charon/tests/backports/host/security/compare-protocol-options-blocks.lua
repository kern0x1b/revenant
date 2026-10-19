local tsv = import("tsv", {rootdir = os.scriptdir()})

local VALUES = {
    {"key-update-alone", 1}, {"challenge-still-unset", 0}, {"verify-still-unset", 0},
    {"all-three-set", 3}, {"p-has-verify", 1}, {"p-has-no-key-update", 0}, {"p-has-no-challenge", 0},
    {"after-null-verify", 0}, {"neighbors-untouched", 2}, {"null-options", 1},
    {"alive-in-scope", 1}, {"deallocated-after-scope", 0},
}

function main(...)
    local args = {...}
    if #args < 1 then
        io.stderr:write("compare-protocol-options-blocks.lua: pass the binary's output\n")
        os.exit(1)
    end
    local wrong, rows = tsv.case_rows(args[1])
    local bad = {}
    for _, line in ipairs(wrong) do
        bad[#bad + 1] = line
    end
    if tsv.first_field(rows, "port-class") ~= "found" then
        bad[#bad + 1] = "port-class: the port's CharonSecProtocolBlocks was not found"
    end
    for _, pair in ipairs(VALUES) do
        local label, expect = pair[1], pair[2]
        local got = tsv.first_field(rows, label)
        if got == nil then
            bad[#bad + 1] = label .. ": the case did not measure it"
        elseif got ~= tostring(expect) then
            bad[#bad + 1] = label .. ": got " .. got .. " and the port claims " .. expect
        end
    end
    if tsv.first_field(rows, "failures") ~= "0" then
        bad[#bad + 1] = "the case reported " .. (tsv.first_field(rows, "failures") or "?") .. " failures"
    end
    for _, line in ipairs(bad) do
        print("DIFFERS " .. line)
    end
    if #bad > 0 then
        os.exit(1)
    end
    print("compared " .. #VALUES .. " values, each block set alone with its two neighbours read back")
    os.exit(0)
end
