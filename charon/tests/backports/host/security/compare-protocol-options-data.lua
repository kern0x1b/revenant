-- compare-protocol-options-data.lua - the data accessors, read back, differences NAMED.
--
--    xmake l compare-protocol-options-data.lua <the binary's output>

local tsv = import("tsv", {rootdir = os.scriptdir()})

-- label and the bytes it must read back, in the order they are named.
local BYTES = {
    {"dh-after-scope", "a finite-field group the caller chose"},
    {"psk-after-scope", "the pre-shared key bytes"},
    {"identity-after-scope", "the identity that names it"},
}
local VALUES = {
    {"pair-present", 1}, {"psk-count", 1}, {"after-half-pair", 1}, {"past-end", 0},
    {"null-options", 1}, {"alive-in-scope", 1}, {"deallocated-after-scope", 0},
}

function main(...)
    local args = {...}
    if #args < 1 then
        io.stderr:write("compare-protocol-options-data.lua: pass the binary's output\n")
        os.exit(1)
    end
    local wrong, rows = tsv.case_rows(args[1])
    local bad = {}
    for _, line in ipairs(wrong) do
        bad[#bad + 1] = line
    end
    if tsv.first_field(rows, "port-class") ~= "found" then
        bad[#bad + 1] = "port-class: the port's CharonSecProtocolData was not found"
    end
    for _, pair in ipairs(BYTES) do
        local label, expect = pair[1], pair[2]
        local got = tsv.first_field(rows, label)
        if got == nil then
            bad[#bad + 1] = label .. ": the case did not read it"
        elseif got ~= expect then
            bad[#bad + 1] = label .. ": read [" .. got .. "] and the port claims [" .. expect .. "]"
        end
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
    print("compared 3 byte values read after their scope ended, a whole pair, and a refused half pair")
    os.exit(0)
end
