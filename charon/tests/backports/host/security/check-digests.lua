-- check-digests.lua - checks that every file the README cites matches the digest the README states for it.
--
--    xmake l check-digests.lua
--
-- The paths the README cites are written from the repository root, and the README is read from this script's own directory, so the
-- two are resolved from the script's location and not from the working directory: run from here, from the repository root or from
-- anywhere else, and the result is the same.
--
-- EXITING 0 IS THE WHOLE POINT, and a check that finds nothing to check must NOT exit 0. Four ways this FAILS on purpose:
--
--   * the README carries no digest lines            -> exit 1
--   * fewer digest lines than files cited           -> exit 1
--   * any file whose sha256 does not match          -> exit 1
--   * the README or a cited file cannot be read     -> exit 1
--
-- The cited files are read out of the README's own shasum block, so the check and the thing being checked cannot disagree about what
-- is cited.

local tsv = import("tsv", {rootdir = os.scriptdir()})

-- Every "<64 lower-case hex><blanks><path>" line the README carries, as {digest, path} pairs in order. This is the regular
-- expression ^\s+([0-9a-f]{64})\s+(\S+)$ read in multiline mode: a match starts at the start of a line, takes its blanks (which may
-- run across lines), the 64 digits, more blanks, and a token that ends at the end of its line.
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

-- The text of each ``` fence pair, in order, as the non-greedy ```(.*?)``` reads them.
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

-- The matches of \S+\.(?:m|py|c|h|lua) inside one token: each runs from the token's start (or after the previous match) to the LAST
-- dot that is followed by one of those extensions, as the greedy \S+ backtracking finds it.
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

-- The text's sha256 as the README's own `shasum -a 256` computes it, or nil when the file cannot be read.
local function sha256_of(path)
    -- io.open raises on a missing file, so the existence check is the one that says it cannot be read
    if not os.isfile(path) then
        return nil, "cannot be opened"
    end
    return hash.sha256(path)
end

function main(...)
    local here = os.scriptdir()
    -- four levels up: this directory is tests/backports/host/security
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

    -- the command block names the files the digests are for; the two must be the same set ONLY INSIDE A CODE FENCE. The prose also
    -- contains the words "shasum -a 256" - a sentence about how the block was computed - and a match that starts there captures every
    -- path mentioned until the next fence, including this script's own name. The command block is what the digests are for, so only
    -- a fenced one counts.
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
