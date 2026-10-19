-- compare-sec-identity.lua - the identity wrapper's ownership and handler rows, differences NAMED.
--
--    xmake l compare-sec-identity.lua <the binary's output>
--
-- copy-ref-retains is the COUNTED +1, not an inference from pointer equality: a mutation that drops the CFRetain in
-- sec_identity_copy_ref leaves every other row here untouched, so without it that mutation is invisible to this case.

local tsv = import("tsv", {rootdir = os.scriptdir()})

-- In the order the values are named.
local VALUES = {
    {"copy-ref-same", 1}, {"copy-ref-retains", 1}, {"create-present", 1}, {"certificates-copied", 1},
    {"copy-survives-source-change", 1}, {"access-true", 1}, {"handler-runs-per-certificate", 1},
    {"access-empty-true", 1}, {"handler-runs-on-empty", 0}, {"copy_ref-of-nil", 0},
    {"local-identity-holds", 1}, {"local-identity-present", 1},
}

function main(...)
    local args = {...}
    if #args < 1 then
        io.stderr:write("compare-sec-identity.lua: pass the binary's output\n")
        os.exit(1)
    end
    local wrong, rows = tsv.case_rows(args[1])
    local bad = {}
    for _, line in ipairs(wrong) do
        bad[#bad + 1] = line
    end
    -- holder-class prints found/MISSING rather than a number
    if tsv.first_field(rows, "holder-class") ~= "found" then
        bad[#bad + 1] = "holder-class: the port's options holder was not found"
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
    print("compared " .. #VALUES .. " ownership assertions on a STAND-IN ref; no keychain was touched")
    os.exit(0)
end
