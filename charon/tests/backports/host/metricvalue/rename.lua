-- Writes the header that compiles the port's classes under names of their own, so a build that never links the real
-- Contacts.framework builds anyway, and the two builds are never confused for one another even though the Contacts and
-- AddressBook frameworks of the host load in both.
-- Usage: xmake l ./rename.lua <registry.json>... <out.h>

import("core.base.json")

-- Names are written in byte order, as Python's sorted writes them (see records.lua for why Lua's own order is not used).
local function byte_less(a, b)
    for i = 1, math.min(#a, #b) do
        local x, y = a:byte(i), b:byte(i)
        if x ~= y then
            return x < y
        end
    end
    return #a < #b
end

function main(...)
    local args = { ... }
    local out = args[#args]
    local names, seen = {}, {}
    for i = 1, #args - 1 do
        local handle = assert(io.open(args[i], "rb"))
        local document = json.decode(handle:read("a"))
        handle:close()
        if not document.entries then
            raise(args[i] .. ": no entries")
        end
        for _, entry in ipairs(document.entries) do
            if entry.kind == "class" or entry.kind == "constant" or entry.kind == "function" then
                local name = entry.api:gsub("%(%)", "")
                if not seen[name] then
                    seen[name] = true
                    names[#names + 1] = name
                end
            end
        end
    end
    table.sort(names, byte_less)
    local handle = assert(io.open(out, "wb"))
    for _, name in ipairs(names) do
        handle:write(string.format("#define %s Charon%s\n", name, name))
    end
    handle:close()
end
