local json = import("core.base.json")

local function init_rows(registry)
    local rows = {}
    for _, entry in ipairs(json.decode(io.readfile(registry)).entries) do
        if entry.kind == "method" and entry.api:endswith(" init]") then
            table.insert(rows, entry.api)
        end
    end
    return rows
end

local function missing(registry, harness)
    local lines = {}
    for name in io.readfile(harness):gmatch('"(IN[%w_]+)"') do
        lines[name] = true
    end
    local want, names = {}, {}
    for _, api in ipairs(init_rows(registry)) do
        local name = api:sub(3, #api - 6)
        if not want[name] then
            want[name] = true
            table.insert(names, name)
        end
    end
    local out = {}
    for _, name in ipairs(names) do
        if not lines[name] then
            table.insert(out, name)
        end
    end
    table.sort(out)
    for _, name in ipairs(out) do
        print(name)
    end
end

function main(command, registry, harness)
    if command == "missing" then
        missing(registry, harness)
    elseif command == "count" then
        print(string.format("intents-11 init: %d -init rows, every one has a line in init11.m", #init_rows(registry)))
    else
        raise("usage: crosscheck-init11.lua missing <registry> <init11.m> | count <registry>")
    end
end
