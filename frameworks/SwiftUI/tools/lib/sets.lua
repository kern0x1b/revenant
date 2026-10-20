function sorted_keys(set)
    local keys = {}
    for k in pairs(set) do
        keys[#keys + 1] = k
    end
    table.sort(keys)
    return keys
end

function count_of(set)
    local n = 0
    for _ in pairs(set) do
        n = n + 1
    end
    return n
end
