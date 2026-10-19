local tsv = import("tsv", {rootdir = os.scriptdir()})

function main(...)
    local args = {...}
    if #args < 1 then
        io.stderr:write("compare-trust-result.lua: pass the binary's output\n")
        os.exit(1)
    end
    local wrong, rows = tsv.case_rows(args[1])
    local bad = {}
    for _, line in ipairs(wrong) do
        bad[#bad + 1] = line
    end
    if tsv.first_field(rows, "host-symbols") ~= "both" then
        bad[#bad + 1] = "host-symbols: the host's own function was not found, so nothing was compared"
    end
    local v = rows["verdict"] or {}
    if #v < 4 then
        bad[#bad + 1] = "verdict: the case did not reach it"
    elseif v[1] ~= v[2] or v[3] ~= v[4] then
        bad[#bad + 1] = "verdict: port status " .. v[1] .. " result " .. v[3] .. ", and the host says status " .. v[2]
            .. " result " .. v[4]
    end
    for _, label in ipairs({"null-out", "null-trust"}) do
        local got = rows[label] or {}
        if #got < 2 then
            bad[#bad + 1] = label .. ": the case did not ask"
        elseif got[1] ~= got[2] or got[1] ~= "-50" then
            bad[#bad + 1] = label .. ": port [" .. got[1] .. "] host [" .. got[2] .. "], and both claim errSecParam (-50)"
        end
    end
    for _, line in ipairs(bad) do
        print("DIFFERS " .. line)
    end
    if #bad > 0 then
        os.exit(1)
    end
    print("compared the verdict as a status/result pair, and 2 refusals, against the host's own function")
    os.exit(0)
end
