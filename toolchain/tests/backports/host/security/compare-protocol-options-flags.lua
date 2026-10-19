local tsv = import("tsv", {rootdir = os.scriptdir()})

local NAMES = {"tickets", "fallback", "resumption", "falsestart", "ocsp", "sct", "reneg", "peerauth"}
local ALONE = 8 * 8
local CLEARED = {{"cleared-ocsp", 0}, {"neighbour-sct", 1}, {"neighbour-tickets", 1}, {"deallocated", 0}}

function main(...)
    local args = {...}
    if #args < 1 then
        io.stderr:write("compare-protocol-options-flags.lua: pass the binary's output\n")
        os.exit(1)
    end
    local wrong, rows = tsv.case_rows(args[1])
    local row_count = 0
    for _ in pairs(rows) do
        row_count = row_count + 1
    end
    local bad = {}
    for _, line in ipairs(wrong) do
        bad[#bad + 1] = line
    end
    if tsv.first_field(rows, "port-class") ~= "found" then
        bad[#bad + 1] = "port-class: the port's RevenantSecProtocolFlags was not found"
    end
    if #wrong == 0 and row_count < #NAMES + #CLEARED then
        bad[#bad + 1] = "the case printed only " .. row_count .. " rows, so the alone-pass did not run"
    end
    local all = {}
    for _, name in ipairs(NAMES) do
        all[#all + 1] = {"all-set-" .. name, 1}
    end
    for _, pair in ipairs(CLEARED) do
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
    print("compared " .. ALONE .. " alone-reads, " .. #NAMES .. " flags set together, and 3 neighbours of a cleared one")
    os.exit(0)
end
