local tsv = import("tsv", {rootdir = os.scriptdir()})

local EXPECTED_CN = "charon-der-test"
local EXPECTED_MAIL = "charon-der-test@example.invalid"

function main(...)
    local args = {...}
    if #args < 1 then
        io.stderr:write("compare-certificate-fields.lua: pass the binary's output\n")
        os.exit(1)
    end
    local rows, wrong = {}, {}
    local port_mail, host_mail = {}, {}
    for _, line in ipairs(tsv.text_lines(tsv.read_text(args[1]))) do
        if tsv.starts_with(line, "WRONG\t") then
            wrong[#wrong + 1] = tsv.split_on(line, "\t", 1)[2]
        elseif line:find("\t", 1, true) then
            local parts = tsv.split_on(line, "\t")
            rows[parts[1]] = {table.unpack(parts, 2)}
            if tsv.starts_with(parts[1], "email-port-") then
                port_mail[#port_mail + 1] = parts[2] or ""
            elseif tsv.starts_with(parts[1], "email-host-") then
                host_mail[#host_mail + 1] = parts[2] or ""
            end
        end
    end
    local bad = {}
    for _, line in ipairs(wrong) do
        bad[#bad + 1] = line
    end
    local symbols = rows["host-symbols"]
    if symbols == nil or symbols[1] ~= "both" then
        bad[#bad + 1] = "host-symbols: the host's own accessors were not both found, so nothing was compared"
    end
    local cn = rows["common-name"] or {}
    if #cn < 2 then
        bad[#bad + 1] = "common-name: the case did not read it"
    elseif cn[1] ~= EXPECTED_CN or cn[2] ~= EXPECTED_CN then
        bad[#bad + 1] = "common-name: port [" .. cn[1] .. "] host [" .. cn[2] .. "] and the certificate's own CN is [" .. EXPECTED_CN .. "]"
    end
    local counts = rows["email-count"] or {}
    if #counts < 2 then
        bad[#bad + 1] = "email-count: the case did not read it"
    else
        if counts[1] ~= counts[2] then
            bad[#bad + 1] = "email-count: the port found " .. counts[1] .. " addresses and the host found " .. counts[2]
        end
        if not tsv.same_list(port_mail, host_mail) then
            bad[#bad + 1] = "email: the port's " .. tsv.py_list(port_mail) .. " are not the host's " .. tsv.py_list(host_mail)
        elseif not tsv.same_list(port_mail, {EXPECTED_MAIL}) then
            bad[#bad + 1] = "email: the fixture's rfc822Name is [" .. EXPECTED_MAIL .. "] and the port gave " .. tsv.py_list(port_mail)
        end
    end
    local null_out = rows["null-out"]
    if null_out == nil or null_out[1] ~= "-50" then
        bad[#bad + 1] = "null-out: a NULL out-parameter is errSecParam (-50)"
    end
    local null_cert = rows["null-cert"]
    if null_cert == nil or null_cert[1] ~= "-50" then
        bad[#bad + 1] = "null-cert: a NULL certificate is errSecParam (-50), not a crash"
    end
    for _, line in ipairs(bad) do
        print("DIFFERS " .. line)
    end
    if #bad > 0 then
        os.exit(1)
    end
    print("compared the common name and " .. #port_mail .. " address against the host's own accessors, and 2 refusals")
    os.exit(0)
end
