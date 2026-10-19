-- compare-protocol-options-ciphersuite.lua - the ciphersuite list, read back, differences NAMED.
--
--    xmake l compare-protocol-options-ciphersuite.lua <the binary's output>

local tsv = import("tsv", {rootdir = os.scriptdir()})

-- In the order the values are named.
local VALUES = {
    {"count", 2}, {"first-as-given", 0x0001}, {"second-as-given", 0x002F}, {"past-end", 0},
    {"group-as-given", 1}, {"list-unchanged-by-group", 2}, {"first-unchanged-by-group", 0x0001},
    {"count-after-third", 3}, {"third-as-given", 0xC02F}, {"group-after-third", 1},
    {"count-after-growth", 23}, {"last-after-growth", 0x0100 + 19},
    {"null-options", 1}, {"alive-in-scope", 1}, {"deallocated-after-scope", 0},
}
local NOT_TRANSLATED = {{"first-not-translated", 1}, {"second-not-translated", 1}}

function main(...)
    local args = {...}
    if #args < 1 then
        io.stderr:write("compare-protocol-options-ciphersuite.lua: pass the binary's output\n")
        os.exit(1)
    end
    local wrong, rows = tsv.case_rows(args[1])
    local bad = {}
    for _, line in ipairs(wrong) do
        bad[#bad + 1] = line
    end
    if tsv.first_field(rows, "port-class") ~= "found" then
        bad[#bad + 1] = "port-class: the port's CharonSecProtocolCiphersuite was not found"
    end
    local all = {}
    for _, pair in ipairs(VALUES) do
        all[#all + 1] = pair
    end
    for _, pair in ipairs(NOT_TRANSLATED) do
        all[#all + 1] = pair
    end
    for _, pair in ipairs(all) do
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
    print("compared " .. #VALUES .. " values, 2 not-translated rows, and a list grown past its first capacity")
    os.exit(0)
end
