local tsv = import("tsv", {rootdir = os.scriptdir()})

local NULLS = {"negotiated-protocol", "server-name", "peer-public-key", "create-secret", "create-secret-ctx",
    "early-data", "chain-access", "ocsp-access", "sigalg-access", "dn-access", "handler-calls"}
local ENUMS = {{"protocol-version", 0}, {"ciphersuite", 0}}
local COMPARE = {{"peers-same-object", 1}, {"peers-two-objects", 1}, {"peers-one-null", 0}, {"peers-both-null", 1},
    {"challenge-same", 1}, {"challenge-one-null", 0},
    {"alive-in-scope", 1}, {"deallocated-after-scope", 0}}

function main(...)
    local args = {...}
    if #args < 1 then
        io.stderr:write("compare-protocol-metadata-accessors.lua: pass the binary's output\n")
        os.exit(1)
    end
    local wrong, rows = tsv.case_rows(args[1])
    local bad = {}
    for _, line in ipairs(wrong) do
        bad[#bad + 1] = line
    end
    if tsv.first_field(rows, "port-class") ~= "found" then
        bad[#bad + 1] = "port-class: the port's RevenantSecProtocolMetadata was not found"
    end
    local all = {}
    for _, label in ipairs(NULLS) do
        all[#all + 1] = {label, 0}
    end
    for _, pair in ipairs(ENUMS) do
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
    print("compared " .. #all .. " answers, the two enums that have a none-member, and the handler count")
    os.exit(0)
end
