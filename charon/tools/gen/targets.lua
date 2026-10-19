local files = import("files", {anonymous = true})
local order = import("order", {anonymous = true})
local headers = import("headers", {anonymous = true})
local json = import("core.base.json")

local function rows_of(filepath)
    local out = {}
    local text = files.read_text(filepath)
    if text == nil then
        return out
    end
    for line in string.gmatch(text, "[^\n]+") do
        if string.sub(line, 1, 1) ~= "#" then
            local cells = {}
            for cell in (line .. "\t"):gmatch("([^\t]*)\t") do
                table.insert(cells, cell)
            end
            table.insert(out, cells)
        end
    end
    return out
end

local function list_of(text)
    local out = {}
    if text == nil or text == "-" then
        return out
    end
    for item in string.gmatch(text, "[^,]+") do
        table.insert(out, item)
    end
    return out
end

function umbrellas(tree)
    local out = {}
    for _, cells in ipairs(rows_of(path.join(tree, "tools", "found", "no-shard.tsv"))) do
        out[cells[1]] = {class = cells[2], targets = list_of(cells[3])}
    end
    return out
end

function products(tree)
    local out = {}
    for _, cells in ipairs(rows_of(path.join(tree, "tools", "found", "config", "products.tsv"))) do
        out[cells[1]] = list_of(cells[2])
    end
    return out
end

local function sorted_keys(map)
    local names = {}
    for name in pairs(map) do
        table.insert(names, name)
    end
    table.sort(names, order.less)
    return names
end

function problems(tree)
    local out = {}
    local umbrellas_of = umbrellas(tree)
    for _, name in ipairs(sorted_keys(umbrellas_of)) do
        local targets_of = umbrellas_of[name].targets
        if #targets_of > 0 then
            local declared = {}
            for _, fw in ipairs(targets_of) do
                for _, r in ipairs(headers.shard_records(tree, fw)) do
                    local api = string.match(r.usr or "", "([^@]+)$")
                    if api ~= nil then
                        declared[api] = true
                    end
                end
            end
            for _, filepath in ipairs(os.files(path.join(tree, "packages", "a", "apple-backports", "registry", name, "*.json"))) do
                local doc = json.decode(io.readfile(filepath))
                for _, e in ipairs(doc.entries or doc) do
                    local api = string.gsub(e.api or "", "%(%)$", "")
                    if not declared[api] then
                        table.insert(out, name .. ": registry entry " .. api .. " is not declared by its nested targets (" ..
                                     table.concat(targets_of, ", ") .. ")")
                    end
                end
            end
        end
    end
    local members_of = products(tree)
    for _, name in ipairs(sorted_keys(members_of)) do
        for _, fw in ipairs(members_of[name]) do
            if #headers.shard_records(tree, fw) == 0 then
                table.insert(out, name .. ": member " .. fw .. " has no declaration shard")
            end
        end
    end
    return out
end
