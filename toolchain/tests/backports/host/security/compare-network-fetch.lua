local tsv = import("tsv", {rootdir = os.scriptdir()})

local EXPECTED = {
    {"made-trust", 0, nil, "SecTrustCreateWithCertificates on the fixture"},
    {"default", 0, 0, "read before anything was set: not allowed"},
    {"set-true", 0, nil, "the setter's own status"},
    {"after-true", 0, 1, "set true, so true must come back"},
    {"after-false", 0, 0, "set false, so false comes back - a flag, not a latch"},
    {"null-trust", -50, nil, "a NULL trust is errSecParam, not a crash"},
}

function main(...)
    local args = {...}
    if #args < 1 then
        io.stderr:write("compare-network-fetch.lua: pass the binary's output\n")
        os.exit(1)
    end
    local seen, wrong = {}, {}
    for _, line in ipairs(tsv.text_lines(tsv.read_text(args[1]))) do
        if tsv.starts_with(line, "WRONG\t") then
            wrong[#wrong + 1] = tsv.split_on(line, "\t", 1)[2]
        elseif line:find("\t", 1, true) then
            local parts = tsv.split_on(line, "\t")
            local status = tsv.py_int(parts[2] or "")
            local value = nil
            if #parts > 2 then
                value = tsv.py_int(parts[3])
            end
            if status == nil or (#parts > 2 and value == nil) then
                io.stderr:write("compare-network-fetch.lua: a row has a field that is not an integer: " .. line .. "\n")
                os.exit(1)
            end
            seen[parts[1]] = {status, value}
        end
    end
    local bad = {}
    for _, line in ipairs(wrong) do
        bad[#bad + 1] = line
    end
    for _, row in ipairs(EXPECTED) do
        local label, want_status, want_value, why = row[1], row[2], row[3], row[4]
        local got = seen[label]
        if got == nil then
            bad[#bad + 1] = label .. ": the case did not reach it (" .. why .. ")"
        elseif got[1] ~= want_status then
            bad[#bad + 1] = label .. ": status [" .. got[1] .. "] and the port claims [" .. want_status .. "] (" .. why .. ")"
        elseif want_value ~= nil and got[2] ~= want_value then
            if got[2] == nil then
                io.stderr:write("compare-network-fetch.lua: " .. label .. " read no value, and the port claims one\n")
                os.exit(1)
            end
            bad[#bad + 1] = label .. ": read back [" .. got[2] .. "] and the port claims [" .. want_value .. "] (" .. why .. ")"
        end
    end
    for _, line in ipairs(bad) do
        print("DIFFERS " .. line)
    end
    if #bad > 0 then
        os.exit(1)
    end
    print("compared " .. #EXPECTED .. " steps of the round trip, and 3 of them carry a value")
    os.exit(0)
end
