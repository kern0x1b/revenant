local tsv = import("tsv", {rootdir = os.scriptdir()})

local SAME = {{"issuer", 68}, {"subject", 68}}
local REFUSED = {"malformed-runs-out", "malformed-wrong-tag", "malformed-indefinite", "malformed-long-form", "malformed-short-tbs"}
local NULLS = {"null-cert", "null-subject"}

function main(...)
    local args = {...}
    if #args < 1 then
        io.stderr:write("compare-certificate-name.lua: pass the binary's output\n")
        os.exit(1)
    end
    local rows, wrong = {}, {}
    for _, line in ipairs(tsv.text_lines(tsv.read_text(args[1]))) do
        if tsv.starts_with(line, "WRONG\t") then
            wrong[#wrong + 1] = tsv.split_on(line, "\t", 1)[2]
        elseif line:find("\t", 1, true) then
            local parts = tsv.split_on(line, "\t")
            rows[parts[1]] = {table.unpack(parts, 2)}
        end
    end
    local bad = {}
    for _, line in ipairs(wrong) do
        bad[#bad + 1] = line
    end
    for _, pair in ipairs(SAME) do
        local label, want = pair[1], pair[2]
        local got = rows[label]
        if got == nil or #got < 3 then
            bad[#bad + 1] = label .. ": the case did not compare it"
        elseif got[3] ~= "same" then
            bad[#bad + 1] = label .. ": port " .. got[1] .. " bytes, host " .. got[2] .. " bytes, and the port claims the host's " .. want
        end
    end
    local selfsigned = rows["selfsigned-same"]
    if selfsigned == nil or selfsigned[1] ~= "yes" then
        bad[#bad + 1] = "selfsigned-same: this fixture is self-signed, so issuer and subject MUST match"
    end
    for _, label in ipairs(REFUSED) do
        local got = rows[label]
        if got == nil then
            bad[#bad + 1] = label .. ": the case did not ask"
        elseif got[1] ~= "refused" then
            bad[#bad + 1] = label .. ": the walk ACCEPTED bytes that are not a certificate"
        end
    end
    for _, label in ipairs(NULLS) do
        local got = rows[label]
        if got == nil or got[1] ~= "NULL" then
            bad[#bad + 1] = label .. ": a NULL certificate must answer NULL, not a crash"
        end
    end
    for _, line in ipairs(bad) do
        print("DIFFERS " .. line)
    end
    if #bad > 0 then
        os.exit(1)
    end
    print("compared " .. #SAME .. " Names against the host's own accessors, " .. #REFUSED .. " malformed shapes refused, " .. #NULLS .. " NULLs")
    os.exit(0)
end
