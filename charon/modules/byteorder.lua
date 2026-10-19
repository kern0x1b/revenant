-- The order of strings every module and tool writes, hashes or compares. Lua's `<` on strings goes through strcoll,
-- so it follows the machine's locale: under en_NZ "AB" sorts after "aa", under C before it, and the same tree wrote
-- different files on two machines. This compares bytes, which is the same order under every locale.

-- True when `a` comes before `b` in byte order: the first byte they differ at decides, and a string that is a
-- prefix of the other comes first.
function less(a, b)
    local shared = math.min(#a, #b)
    -- eight bytes at a time while they agree, which is most of a long path; then byte by byte where they first differ
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

-- Sorts a list of strings in place, in byte order.
function sort(list)
    table.sort(list, less)
end

-- The keys of a map, or the members of a set, sorted in byte order (a new list).
function keys(map)
    local out = {}
    for key in pairs(map) do
        table.insert(out, key)
    end
    sort(out)
    return out
end
