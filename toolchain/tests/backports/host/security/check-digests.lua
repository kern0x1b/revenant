local tsv = import("tsv", {rootdir = os.scriptdir()})

local function digest_pairs(text)
    local found = {}
    local p = 1
    local n = #text
    while p <= n do
        local matched = false
        local ws = text:match("^%s+", p)
        if ws then
            local q = p + #ws
            local hex = text:sub(q, q + 63)
            if #hex == 64 and hex:match("^[0-9a-f]+$") then
                local gap = text:match("^%s+", q + 64)
                if gap then
                    local s = q + 64 + #gap
                    local token = text:match("^%S+", s)
                    if token then
                        local e = s + #token
                        local after = text:sub(e, e)
                        if after == "" or after == "\n" then
                            found[#found + 1] = {hex, token}
                            matched = true
                            p = e + 1
                        end
                    end
                end
            end
        end
        if not matched then
            local nl = text:find("\n", p, true)
            if not nl then
                break
            end
            p = nl + 1
        end
    end
    return found
end

local function fenced_blocks(text)
    local blocks = {}
    local pos = 1
    while true do
        local _, b = text:find("```", pos, true)
        if not b then
            break
        end
        local c, d = text:find("```", b + 1, true)
        if not c then
            break
        end
        blocks[#blocks + 1] = text:sub(b + 1, c - 1)
        pos = d + 1
    end
    return blocks
end

local function file_matches(token)
    local found = {}
    local pos = 1
    while true do
        local best_end = nil
        for d = #token - 1, pos + 1, -1 do
            if token:sub(d, d) == "." then
                local first = token:sub(d + 1, d + 1)
                if first == "m" or first == "c" or first == "h" then
                    best_end = d + 1
                elseif token:sub(d + 1, d + 2) == "py" then
                    best_end = d + 2
                elseif token:sub(d + 1, d + 3) == "lua" then
                    best_end = d + 3
                end
                if best_end then
                    break
                end
            end
        end
        if not best_end then
            break
        end
        found[#found + 1] = token:sub(pos, best_end)
        pos = best_end + 1
    end
    return found
end

local function sha256_of(path)
    if not os.isfile(path) then
        return nil, "cannot be opened"
    end
    return hash.sha256(path)
end

function main(...)
    local here = os.scriptdir()
    local root = here .. "/../../../.."
    local readme = here .. "/README.md"
    if not os.isfile(readme) then
        print("FAIL  " .. readme .. " does not exist - there is no README to check")
        os.exit(1)
    end

    local text = tsv.read_text(readme)
    local pairs_found = digest_pairs(text)
    if #pairs_found == 0 then
        print("NO DIGEST LINES in " .. readme .. " - the README cites nothing, so there is nothing to check")
        print("and that is a FAILURE, not a pass: this script exists to catch a README out of step with its files")
        os.exit(1)
    end

    local cited = {}
    for _, block in ipairs(fenced_blocks(text)) do
        if block:find("shasum -a 256", 1, true) then
            cited[#cited + 1] = block
        end
    end
    local wanted = {}
    if #cited > 0 then
        for token in table.concat(cited, " "):gmatch("%S+") do
            for _, file in ipairs(file_matches(token)) do
                wanted[#wanted + 1] = file
            end
        end
    end
    local listed = {}
    for _, pair in ipairs(pairs_found) do
        listed[pair[2]] = true
    end
    if #wanted > 0 then
        local missing = {}
        for _, w in ipairs(wanted) do
            if not listed[w] then
                missing[#missing + 1] = w
            end
        end
        if #missing > 0 then
            print("FAIL  " .. #missing .. " of the " .. #wanted .. " files the command block cites carry no digest: "
                .. table.concat(missing, ", "))
            os.exit(1)
        end
        print("the command block cites " .. #wanted .. " file(s) and " .. #pairs_found .. " carry a digest")
    end

    local bad = 0
    for _, pair in ipairs(pairs_found) do
        local digest, path = pair[1], pair[2]
        local actual, why = sha256_of(root .. "/" .. path)
        if actual == nil then
            print("FAIL  " .. path .. " " .. why)
            bad = bad + 1
        elseif actual == digest then
            print("OK       " .. path)
        else
            print("MISMATCH " .. path .. "  README " .. digest .. "  actual " .. actual)
            bad = bad + 1
        end
    end
    print(#pairs_found .. " file(s) checked, " .. bad .. " mismatch")
    os.exit(bad > 0 and 1 or 0)
end
