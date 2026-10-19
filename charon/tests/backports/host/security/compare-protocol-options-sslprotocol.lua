-- compare-protocol-options-sslprotocol.lua - the SSL protocol range, read back, differences NAMED.
--
--    xmake l compare-protocol-options-sslprotocol.lua <the binary's output>

local tsv = import("tsv", {rootdir = os.scriptdir()})

local VALUES = {
    {"min-as-given", 4}, {"max-as-given", 8}, {"has-range", 1}, {"max-alone", 7}, {"min-untouched", 4},
    {"empty-has-no-range", 0}, {"null-options", 1}, {"alive-in-scope", 1}, {"deallocated-after-scope", 0},
}
local NOT_TRANSLATED = {{"min-not-translated", 1}, {"max-not-translated", 1}}

function main(...)
    local args = {...}
    if #args < 1 then
        io.stderr:write("compare-protocol-options-sslprotocol.lua: pass the binary's output\n")
        os.exit(1)
    end
    local wrong, rows = tsv.case_rows(args[1])
    local bad = {}
    for _, line in ipairs(wrong) do
        bad[#bad + 1] = line
    end
    if tsv.first_field(rows, "port-class") ~= "found" then
        bad[#bad + 1] = "port-class: the port's CharonSecProtocolSSLProtocol was not found"
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
    print("compared " .. #VALUES .. " values and 2 not-translated rows: the caller's own numbers come back")
    os.exit(0)
end
