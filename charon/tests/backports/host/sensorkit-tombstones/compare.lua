-- compare.lua PORTFILE HOSTFILE - the port's answers against the host's, input by input.
--
--    xmake l ./compare.lua <port out> <host out>
--
-- Prints one DIFFERS line per input the two sides disagree on, then a summary that says how many pairs were compared. Exits 0
-- only when the two files hold the same answer for the same input and nothing is missing from either, so a run that compared
-- fewer pairs than the port printed cannot look green.
--
-- Unlike sensorkit-names' compare.lua there is no separate name list here: the INPUT is the case, so the inputs themselves are
-- what must agree, and a case the host never printed is a case nobody compared.

-- Names are sorted by their bytes, as Python sorts strings: the string comparison of Lua follows the locale's collation, which
-- puts "B.x" after "b.x" and "a_b" before "a.c", so it is not used.
local function byte_less(a, b)
    for i = 1, math.min(#a, #b) do
        local x, y = a:byte(i), b:byte(i)
        if x ~= y then
            return x < y
        end
    end
    return #a < #b
end

-- The rows of one side: the lines of three tab-separated fields whose first is the tag, keyed by the second.
local function rows(path, tag)
    local handle = assert(io.open(path, "rb"))
    local out = {}
    for line in handle:lines() do
        -- handle:lines() keeps the "\n" on each line, so it is taken off here, and the "\r" of a CRLF file with it.
        line = line:gsub("\n$", ""):gsub("\r$", "")
        local tab1 = line:find("\t", 1, true)
        local tab2 = tab1 and line:find("\t", tab1 + 1, true)
        if tab2 and line:find("\t", tab2 + 1, true) == nil and line:sub(1, tab1 - 1) == tag then
            out[line:sub(tab1 + 1, tab2 - 1)] = line:sub(tab2 + 1)
        end
    end
    handle:close()
    return out
end

-- Python's repr of an input, which the messages print: 'text' between single quotes.
local function repr(text)
    return "'" .. text .. "'"
end

local function count(set)
    local n = 0
    for _ in pairs(set) do
        n = n + 1
    end
    return n
end

function main(portFile, hostFile)
    if not portFile or not hostFile then
        raise("compare.lua: pass the port output and the host output")
    end
    local p, h = rows(portFile, "PORT"), rows(hostFile, "HOST")
    local union, names = {}, {}
    for name in pairs(p) do
        union[name] = true
    end
    for name in pairs(h) do
        union[name] = true
    end
    for name in pairs(union) do
        names[#names + 1] = name
    end
    table.sort(names, byte_less)
    local bad = {}
    local both = 0
    for _, name in ipairs(names) do
        if p[name] == nil then
            bad[#bad + 1] = repr(name) .. ": the port printed no row for it"
        elseif h[name] == nil then
            bad[#bad + 1] = repr(name) .. ": the host printed no row for it"
        elseif p[name] ~= h[name] then
            bad[#bad + 1] = string.format("%s: the port answers [%s] and the host answers [%s]", repr(name), p[name], h[name])
        end
        if p[name] ~= nil and h[name] ~= nil then
            both = both + 1
        end
    end
    for _, line in ipairs(bad) do
        print("DIFFERS " .. line)
    end
    print(string.format("sensorkit-tombstones: %d inputs compared, %d differing%s", both, #bad,
        (both > 0 and #bad == 0) and "" or "  <- SEE ABOVE"))
    if #bad > 0 or both ~= count(p) or both ~= count(h) then
        os.exit(1)
    end
end
