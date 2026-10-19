-- The byte order of the generator's sorts (less, strings, keys). The one definition is modules/byteorder.lua, which the package's
-- own code sorts with too, and a copy of the modules alone carries it. This file re-exports it for tools/gen, so every sort of
-- a name in the generator still reads order.less.
local byteorder = import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})

less = byteorder.less

-- The strings of a list, sorted by bytes (a new list).
function strings(list)
    local out = table.move(list, 1, #list, 1, {})
    byteorder.sort(out)
    return out
end

keys = byteorder.keys
