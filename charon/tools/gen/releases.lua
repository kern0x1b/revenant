function key(release)
    local out = {}
    for part in string.gmatch(release, "[^.]+") do
        table.insert(out, tonumber(part))
    end
    return out
end

function before(a, b)
    local x, y = key(a), key(b)
    for i = 1, math.min(#x, #y) do
        if x[i] ~= y[i] then
            return x[i] < y[i]
        end
    end
    return #x < #y
end

function sorted(releases)
    local out = table.move(releases, 1, #releases, 1, {})
    table.sort(out, before)
    return out
end
