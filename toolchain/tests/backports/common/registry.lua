local json = import("core.base.json")

local function files_of(source)
    if os.isfile(source) then
        return {source}
    end
    return os.files(path.join(source, "*.json"))
end

function names(source, header, kinds)
    local wanted = {}
    for kind in kinds:gmatch("[^,]+") do
        wanted[kind] = true
    end
    local found, seen = {}, {}
    for _, file in ipairs(files_of(source)) do
        for _, entry in ipairs(json.loadfile(file).entries) do
            if wanted[entry.kind] then
                local name = entry.api:gsub("%(%)", "")
                if not seen[name] then
                    seen[name] = true
                    table.insert(found, name)
                end
            end
        end
    end
    table.sort(found)
    local out = {}
    for _, name in ipairs(found) do
        table.insert(out, string.format("#define %s Revenant%s\n", name, name))
    end
    io.writefile(header, table.concat(out))
    return 0
end

function main(command, ...)
    if command == "names" then
        os.exit(names(...))
    end
    io.stderr:write("usage: registry.lua names <registry-dir-or-file> <rename.h> <kind>[,<kind>...]\n")
    os.exit(2)
end
