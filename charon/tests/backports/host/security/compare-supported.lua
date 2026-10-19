local tsv = import("tsv", {rootdir = os.scriptdir()})

local EXPECTED = {
    {"rsa-sign-sha256", "YES"},
    {"rsa-verify-sha256", "YES"},
    {"rsa-sign-sha1", "YES"},
    {"rsa-encrypt-oaep", "YES"},
    {"rsa-decrypt-pkcs1", "YES"},
    {"ec-sign-sha256", "YES"},
    {"rsa-keyexchange", "NO"},
    {"rsa-sign-unknown", "NO"},
}

function main(...)
    local args = {...}
    if #args < 1 then
        io.stderr:write("compare-supported.lua: pass the binary's output\n")
        os.exit(1)
    end
    local seen = {}
    for _, line in ipairs(tsv.text_lines(tsv.read_text(args[1]))) do
        if line:find("\t", 1, true) then
            local parts = tsv.split_on(line, "\t", 1)
            seen[parts[1]] = parts[2]
        end
    end
    local bad = {}
    for _, pair in ipairs(EXPECTED) do
        local name, want = pair[1], pair[2]
        local got = seen[name]
        if got ~= want then
            bad[#bad + 1] = name .. ": the table answered [" .. (got or "None") .. "] and the port claims [" .. want .. "]"
        end
    end
    for _, line in ipairs(bad) do
        print("DIFFERS " .. line)
    end
    if #bad > 0 then
        os.exit(1)
    end
    print("compared " .. #EXPECTED .. " operation/algorithm pairs: every one is what the port claims")
    os.exit(0)
end
