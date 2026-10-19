import("core.base.json")

local function byte_less(a, b)
    for i = 1, math.min(#a, #b) do
        local x, y = a:byte(i), b:byte(i)
        if x ~= y then
            return x < y
        end
    end
    return #a < #b
end

local function load(file)
    local handle = assert(io.open(file, "rb"))
    local records = json.decode(handle:read("a"))
    handle:close()
    return records
end

function main(command, first, second)
    if command == "count" then
        local n = 0
        for _ in pairs(load(first)) do
            n = n + 1
        end
        print(n)
    elseif command == "differing" then
        local a, b = load(first), load(second)
        local keys, seen = {}, {}
        for key in pairs(a) do
            seen[key] = true
            keys[#keys + 1] = key
        end
        for key in pairs(b) do
            if not seen[key] then
                keys[#keys + 1] = key
            end
        end
        table.sort(keys, byte_less)
        local differing = {}
        for _, key in ipairs(keys) do
            if a[key] ~= b[key] then
                differing[#differing + 1] = key
            end
        end
        print(table.concat(differing, " "))
    elseif command == "value" then
        local value = load(first)[second]
        print(value == nil and "None" or tostring(value))
    else
        raise("records.lua: count, differing or value, not " .. tostring(command))
    end
end
