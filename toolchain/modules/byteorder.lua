function less(a, b)
    local shared = math.min(#a, #b)
    local index = 1
    while index + 7 <= shared and a:sub(index, index + 7) == b:sub(index, index + 7) do
        index = index + 8
    end
    for at = index, shared do
        local x, y = a:byte(at), b:byte(at)
        if x ~= y then
            return x < y
        end
    end
    return #a < #b
end

function sort(list)
    table.sort(list, less)
end

function keys(map)
    local out = {}
    for key in pairs(map) do
        table.insert(out, key)
    end
    sort(out)
    return out
end
