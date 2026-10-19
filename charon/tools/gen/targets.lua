-- The targets of the SDK entries that have no declaration shard of their own. no-shard.tsv (tools/found, computed by the extractor's
-- sweep from the frameworks' own headers) names, for a framework that declares nothing of its own, the nested frameworks whose shards
-- hold its declarations (Accelerate: Accelerate/vImage and Accelerate/vecLib), and products.tsv (tools/found/config, the foundation's
-- classification) names, for a product folder that is not an SDK framework, the SDK frameworks whose shards declare its identifiers
-- (Graphics). Nothing here is written.

local files = import("files", {anonymous = true})
local order = import("order", {anonymous = true})
local headers = import("headers", {anonymous = true})
local json = import("core.base.json")

-- The rows of a configuration file: tab-separated, one per line, without the comment lines (those starting with #).
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

-- The frameworks of the configuration folder's list named by a comma list (a "-" is none).
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

-- The frameworks with no shard of no-shard.tsv: name -> {class = ..., targets = {the nested frameworks}}.
function umbrellas(tree)
    local out = {}
    for _, cells in ipairs(rows_of(path.join(tree, "tools", "found", "no-shard.tsv"))) do
        out[cells[1]] = {class = cells[2], targets = list_of(cells[3])}
    end
    return out
end

-- The product folders of products.tsv: name -> the SDK frameworks whose shards declare its identifiers.
function products(tree)
    local out = {}
    for _, cells in ipairs(rows_of(path.join(tree, "tools", "found", "config", "products.tsv"))) do
        out[cells[1]] = list_of(cells[2])
    end
    return out
end

-- The names of a table's keys, in byte order.
local function sorted_keys(map)
    local names = {}
    for name in pairs(map) do
        table.insert(names, name)
    end
    table.sort(names, order.less)
    return names
end

-- The problems of the targets, one line each (check prints them as CHECK lines): every registry entry of an umbrella (its registry
-- folder, named by no-shard.tsv) is declared by a shard of one of its nested targets, and every member of a product (products.tsv) has
-- a shard of its own. A name is the api without its "()", the form the shards write a function's name in (its USR's last part). This
-- reads the committed shards and registry only. What it cannot read is the gate's half: that each nested target's built dylib exports
-- its entries is check_registry (modules/apple/backports.lua), which needs the dylibs of Accelerate's vImage and vecLib targets and of
-- the Graphics product (libGraphicsBackports) from a gate build, and is not run by check.
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
