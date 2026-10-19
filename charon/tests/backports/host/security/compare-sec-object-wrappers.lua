local tsv = import("tsv", {rootdir = os.scriptdir()})

local BALANCE = {
    {"fixture-retain", 1}, {"after-create", 2}, {"after-copy", 3},
    {"after-copy-release", 2}, {"after-wrapper-scope", 1},
}
local TRUST = {{"trust-retain-before", 1}, {"trust-after-create", 2}, {"trust-after-copy", 3}}
local RELEASED = {{"certificate-released", 0}, {"trust-released", 0}}
local SAME = {"copy-ref-same", "trust-copy-ref-same"}
local NULLS = {"copy-ref-null", "copy-ref-trust-null"}

function main(...)
    local args = {...}
    if #args < 1 then
        io.stderr:write("compare-sec-object-wrappers.lua: pass the binary's output\n")
        os.exit(1)
    end
    local wrong, rows = tsv.case_rows(args[1])
    local bad = {}
    for _, line in ipairs(wrong) do
        bad[#bad + 1] = line
    end
    local all = {}
    for _, pair in ipairs(BALANCE) do
        all[#all + 1] = pair
    end
    for _, pair in ipairs(TRUST) do
        all[#all + 1] = pair
    end
    for _, pair in ipairs(RELEASED) do
        all[#all + 1] = pair
    end
    for _, pair in ipairs(all) do
        local label, expect = pair[1], pair[2]
        local got = tsv.first_field(rows, label)
        if got == nil then
            bad[#bad + 1] = label .. ": the case did not measure it"
        elseif got ~= tostring(expect) then
            bad[#bad + 1] = label .. ": got " .. got .. " and the balance says " .. expect
        end
    end
    for _, label in ipairs(SAME) do
        if tsv.first_field(rows, label) ~= "1" then
            bad[#bad + 1] = label .. ": the port did not answer the ref it was given, by pointer equality"
        end
    end
    for _, label in ipairs(NULLS) do
        if tsv.first_field(rows, label) ~= "NULL" then
            bad[#bad + 1] = label .. ": a NULL argument must be refused, not crash"
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
    print("compared " .. #BALANCE .. " certificate retain counts, " .. #TRUST .. " trust ones, 2 releases, 2 identities and 2 refusals")
    os.exit(0)
end
