-- compare-protocol-options-held.lua - the held settings and the held block, differences NAMED.
--
--    xmake l compare-protocol-options-held.lua <the binary's output>

local tsv = import("tsv", {rootdir = os.scriptdir()})

local HELD = {{"ciphersuites-held", 2}, {"groups-held", 1}, {"hint-set", 1}, {"held-block-present", 1},
    {"block-survives-dead-frame", 1}}
local COMPARE = {{"range-held-not-equal-yet", 0}, {"range-read-back-equal", 1}, {"range-differs", 0},
    {"alive-in-scope", 1}, {"deallocated-after-scope", 0}}

function main(...)
    local args = {...}
    if #args < 1 then
        io.stderr:write("compare-protocol-options-held.lua: pass the binary's output\n")
        os.exit(1)
    end
    local wrong, rows = tsv.case_rows(args[1])
    local bad = {}
    for _, line in ipairs(wrong) do
        bad[#bad + 1] = line
    end
    if tsv.first_field(rows, "port-class") ~= "found" then
        bad[#bad + 1] = "port-class: the port's CharonSecProtocolOptionsHeld was not found"
    end
    local all = {}
    for _, pair in ipairs(HELD) do
        all[#all + 1] = pair
    end
    for _, pair in ipairs(COMPARE) do
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
    print("compared " .. #HELD .. " held settings, " .. #COMPARE .. " read back through the comparator, and the held block called "
        .. "after its frame was gone")
    os.exit(0)
end
