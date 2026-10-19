local function byte_less(a, b)
    for i = 1, math.min(#a, #b) do
        local x, y = a:byte(i), b:byte(i)
        if x ~= y then
            return x < y
        end
    end
    return #a < #b
end

local function rows(path, tag)
    local handle = assert(io.open(path, "rb"))
    local out = {}
    for line in handle:lines() do
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
