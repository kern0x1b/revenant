local function occurrences(text, needle)
    local n, start = 0, 1
    while true do
        local s, e = text:find(needle, start, true)
        if not s then
            return n
        end
        n = n + 1
        start = e + 1
    end
end

function main(path, old, new)
    local handle = assert(io.open(path, "rb"))
    local text = handle:read("a")
    handle:close()
    local count = occurrences(text, old)
    if count ~= 1 then
        io.stderr:write(string.format("mutate.lua: %q appears %d times in %s, so the mutation would not be a mutation\n",
            old, count, path))
        os.exit(1)
    end
    local s, e = text:find(old, 1, true)
    handle = assert(io.open(path, "wb"))
    handle:write(text:sub(1, s - 1) .. new .. text:sub(e + 1))
    handle:close()
    local label = old:match("^%s*(.-)%s*$"):sub(1, 60)
    print("mutated: " .. label)
end
