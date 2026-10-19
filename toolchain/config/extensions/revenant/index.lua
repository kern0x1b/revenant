function index_findings(root)
    local found = {}
    for _, folder in ipairs(os.dirs(path.join(root, "*", "*"))) do
        local name = path.basename(folder)
        local letter = path.basename(path.directory(folder))
        local lua = path.join(folder, "xmake.lua")
        if letter ~= name:sub(1, 1) then
            table.insert(found, string.format("%s is filed under %s, not under %s", name, letter, name:sub(1, 1)))
        end
        if not os.isfile(lua) then
            table.insert(found, string.format("%s has no xmake.lua, so the index serves no version of it", name))
        else
            local declared = string.match(io.readfile(lua), 'package%("([^"]*)"%)')
            if not declared then
                table.insert(found, string.format("%s declares no package(...)", name))
            elseif declared ~= name then
                table.insert(found, string.format("%s declares package(%s), not %s", name, declared, name))
            end
        end
    end
    table.sort(found)
    return found
end
