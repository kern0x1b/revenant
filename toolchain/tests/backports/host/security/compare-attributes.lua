local tsv = import("tsv", {rootdir = os.scriptdir()})

local CODES = {rsa = "42", ec = "73"}

local EXPECTED_LITERAL = {
    {"rsa-1024", "%s/1024"},
    {"ec-256", "%s/256"},
    {"one-key-only", "%s/0"},
    {"not-a-dictionary", "NULL"},
}

local function expected_for(name, pattern)
    if not tsv.starts_with(pattern, "%s") then
        return pattern
    end
    local code = CODES.ec
    if tsv.starts_with(name, "rsa") or name == "one-key-only" then
        code = CODES.rsa
    end
    return code .. pattern:sub(3)
end

function main(...)
    local args = {...}
    if #args < 1 then
        io.stderr:write("compare-attributes.lua: pass the binary's output\n")
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
    for _, pair in ipairs(EXPECTED_LITERAL) do
        local name = pair[1]
        local want = expected_for(name, pair[2])
        local got = seen[name]
        if got ~= want then
            bad[#bad + 1] = name .. ": the shaping answered [" .. (got or "None") .. "] and the constants say [" .. want .. "]"
        end
    end
    for _, line in ipairs(bad) do
        print("DIFFERS " .. line)
    end
    if #bad > 0 then
        os.exit(1)
    end
    print("compared " .. #EXPECTED_LITERAL .. " answers: every one is what the key-type constants hold")
    os.exit(0)
end
