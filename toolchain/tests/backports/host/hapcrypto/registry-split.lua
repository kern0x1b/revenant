local json = import("core.base.json")
local byteorder = import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "..", "..", "modules"), anonymous = true})

local function write_names(file, names)
    local lines = {}
    for _, name in ipairs(names) do
        table.insert(lines, name .. "\n")
    end
    io.writefile(file, table.concat(lines))
end

function main(folder, classes_out, protocols_out)
    local files = os.files(path.join(folder, "*.json"))
    byteorder.sort(files)
    local kind = {}
    for _, file in ipairs(files) do
        local held = json.decode(io.readfile(file))
        for _, entry in ipairs(held.entries or {}) do
            if entry.status == "implemented" and (entry.kind == "class" or entry.kind == "protocol") then
                kind[entry.api] = entry.kind
            end
        end
    end
    local classes, protocols = {}, {}
    for name, value in pairs(kind) do
        if value == "class" then
            table.insert(classes, name)
        else
            table.insert(protocols, name)
        end
    end
    byteorder.sort(classes)
    byteorder.sort(protocols)
    write_names(classes_out, classes)
    write_names(protocols_out, protocols)
end
