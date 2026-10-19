local tsv = import("tsv", {rootdir = os.scriptdir()})

local EXPECTED = {
    {"pkcs1-sha1", 32770},
    {"pkcs1-sha224", 32771},
    {"pkcs1-sha256", 32772},
    {"pkcs1-sha384", 32773},
    {"pkcs1-sha512", 32774},
    {"ecdsa-sha256", 0},
}

function main(...)
    local args = {...}
    if #args < 1 then
        io.stderr:write("compare-padding.lua: pass the binary's output\n")
        os.exit(1)
    end
    local seen, wrong = {}, {}
    for _, line in ipairs(tsv.text_lines(tsv.read_text(args[1]))) do
        if tsv.starts_with(line, "WRONG\t") then
            wrong[#wrong + 1] = tsv.split_on(line, "\t", 1)[2]
        elseif line:find("\t", 1, true) then
            local parts = tsv.split_on(line, "\t", 1)
            seen[parts[1]] = parts[2]
        end
    end
    local bad = {}
    for _, line in ipairs(wrong) do
        bad[#bad + 1] = line
    end
    for _, pair in ipairs(EXPECTED) do
        local name, want = pair[1], pair[2]
        local got = seen[name]
        if got == nil or got ~= tostring(want) then
            bad[#bad + 1] = name .. ": answered [" .. (got or "None") .. "] and the header's enumerator is " .. want
        end
    end
    for _, line in ipairs(bad) do
        print("DIFFERS " .. line)
    end
    if #bad > 0 then
        os.exit(1)
    end
    print("compared " .. #EXPECTED .. " algorithm/padding pairs: every one is the header's own enumerator")
    os.exit(0)
end
