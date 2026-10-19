local tsv = import("tsv", {rootdir = os.scriptdir()})

local DEFAULTS = {
    {"default-min-tls", 0x0301}, {"default-max-tls", 0x0303},
    {"default-min-dtls", 0xfeff}, {"default-max-dtls", 0xfeff},
}
local COMPARE = {
    {"both-empty-equal", 1}, {"same-range-equal", 1}, {"different-range", 0},
    {"same-object", 1}, {"null-a", 0}, {"null-both", 1},
    {"alive-in-scope", 1}, {"deallocated-after-scope", 0},
}
local NOT_HONOURED = {
    {"no-tls13", "TLSv13 0x0304, which 6.1.3 cannot negotiate"},
    {"no-dtls12", "DTLSv12 0xfefd, which 6.1.3 cannot negotiate"},
}

function main(...)
    local args = {...}
    if #args < 1 then
        io.stderr:write("compare-protocol-options.lua: pass the binary's output\n")
        os.exit(1)
    end
    local wrong, rows = tsv.case_rows(args[1])
    local bad = {}
    for _, line in ipairs(wrong) do
        bad[#bad + 1] = line
    end
    if tsv.first_field(rows, "port-class") ~= "found" then
        bad[#bad + 1] = "port-class: the port's CharonSecProtocolOptions was not found"
    end
    local all = {}
    for _, pair in ipairs(DEFAULTS) do
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
    for _, pair in ipairs(NOT_HONOURED) do
        local label, why = pair[1], pair[2]
        if tsv.first_field(rows, label) ~= "1" then
            bad[#bad + 1] = label .. ": a default answered " .. why
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
    print("compared " .. #DEFAULTS .. " defaults, " .. #COMPARE .. " comparisons and 2 version 6.1.3 cannot honour")
    os.exit(0)
end
