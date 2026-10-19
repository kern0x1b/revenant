-- compare.lua PORTFILE HOSTFILE NAMELIST - the port's values against the host's, name by name.
--
--    xmake l ./compare.lua <port out> <host out> <names.txt>
--
-- Three ways it must be red, and all three are run by run.sh: a value that differs, a name one side did not print, and an
-- input with no HOST rows at all - a comparison of nothing is not a comparison, and the summary line says how many pairs were
-- compared so a run that compared nothing cannot look green.

-- The rows of one side: the lines of three tab-separated fields whose first is the tag, keyed by the second. A later line
-- for the same name replaces an earlier one, as it did before.
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

-- The names of the list: each line of the C array, with the comment, declaration and closing brace lines left out, the
-- trailing comma and the quotes taken off. A closing brace ends the list.
local function names_of(path)
    local handle = assert(io.open(path, "rb"))
    local names = {}
    for line in handle:lines() do
        line = line:match("^%s*(.-)%s*$")
        if line == "" or line:sub(1, 2) == "//" or line:sub(1, 6) == "static" or line:sub(1, 1) == "}" then
            if line:sub(1, 1) == "}" then
                break
            end
        else
            local name = line:gsub(",$", ""):gsub('^"+', ""):gsub('"+$', "")
            names[#names + 1] = name
        end
    end
    handle:close()
    return names
end

function main(portFile, hostFile, namelist)
    if not portFile or not hostFile or not namelist then
        raise("compare.lua: pass the port output, the host output and the name list")
    end
    local names = names_of(namelist)
    local p, h = rows(portFile, "PORT"), rows(hostFile, "HOST")
    local bad = {}
    local compared = 0
    for _, name in ipairs(names) do
        if p[name] == nil then
            bad[#bad + 1] = name .. ": the port printed no row for it"
        end
        if h[name] == nil then
            bad[#bad + 1] = name .. ": the host's framework printed no row for it"
        end
        if p[name] ~= nil and h[name] ~= nil then
            compared = compared + 1
            if p[name] ~= h[name] then
                bad[#bad + 1] = string.format("%s: the port holds [%s] and the host holds [%s]", name, p[name], h[name])
            end
        end
    end
    for _, line in ipairs(bad) do
        print("DIFFERS " .. line)
    end
    print(string.format("sensorkit-names: %d names compared, %d differing%s", compared, #bad,
        compared == 0 and "  <- COMPARED NOTHING" or ""))
    if #bad > 0 or compared ~= #names then
        os.exit(1)
    end
end
