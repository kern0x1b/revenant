local layout = import("layout", {anonymous = true})
local tsv = import("tsv", {anonymous = true})
local files = import("files", {anonymous = true})
local decl = import("decl", {anonymous = true})
local order = import("order", {anonymous = true})
local headers = import("headers", {anonymous = true})
local members = import("members", {anonymous = true})
local tbd = import("tbd", {anonymous = true})
local digest = import("digest", {anonymous = true})
local json = import("core.base.json")

function frameworks(tree)
    local root = path.join(tree, layout.constants().SNAP_ROOT)
    local names = {}
    for _, pattern in ipairs({"*", "*/*"}) do
        for _, filepath in ipairs(files.glob(path.join(root, pattern, layout.constants().SHARD_FILE))) do
            table.insert(names, path.relative(path.directory(filepath), root))
        end
    end
    table.sort(names, order.less)
    return names
end

local function complete(r)
    for _, name in ipairs(layout.constants().SPEC_COLUMNS) do
        if r[name] == nil then
            r[name] = "-"
        end
    end
    return r
end

local function constant_rows(tree, fw)
    local out = {}
    local text = files.read_text(layout.constant_record_path(tree, fw))
    if text == nil then
        return out
    end
    for _, r in ipairs(tsv.records(text)) do
        if r.kind == "constant" then
            table.insert(out, complete(r))
        end
    end
    return out
end

local function shard_rows(tree, fw, sdk)
    local facts = headers.shard_facts(tree, fw)
    local classes = sdk and tbd.class_exports(sdk, fw) or nil
    return members.rows(facts.members, classes, fw), #facts.members
end

local last_key, last_rows = nil, nil

function forget()
    last_key, last_rows = nil, nil
end

function load(tree, fw, sdk)
    local key = tree .. "\n" .. fw .. "\n" .. (sdk or "")
    if key ~= last_key then
        last_rows = build(tree, fw, sdk)
        last_key = key
    end
    return last_rows
end

function build(tree, fw, sdk)
    local rows = shard_rows(tree, fw, sdk)
    for _, r in ipairs(constant_rows(tree, fw)) do
        table.insert(rows, r)
    end
    local count_of = {}
    for _, r in ipairs(rows) do
        count_of[r.key] = (count_of[r.key] or 0) + 1
    end
    for _, r in ipairs(rows) do
        if count_of[r.key] > 1 then
            r.key = r.key .. "_" .. string.sub(digest.digest("key", r.api), 1, 8)
        end
    end
    return rows
end

function member_rows(tree, fw)
    local out = {}
    for _, r in ipairs(load(tree, fw)) do
        if r.kind == "method" or r.kind == "property" then
            table.insert(out, r)
        end
    end
    return out
end

function table_text(rows)
    local lines = {}
    for _, r in ipairs(rows) do
        local cells = {}
        for _, name in ipairs(layout.constants().SPEC_COLUMNS) do
            table.insert(cells, r[name] or "-")
        end
        table.insert(lines, cells)
    end
    return tsv.table_text(layout.constants().SPEC_COLUMNS, lines)
end

function index(rows)
    local found = {}
    local function add(key, row)
        if found[key] == nil then
            found[key] = row
        end
    end
    for _, r in ipairs(rows) do
        add(r.api, r)
        if r.kind == "property" then
            local name = decl.member_name(r.api)
            add(r.cls .. "." .. name, r)
        end
    end
    return found
end

local OVERRIDE_KINDS = {method = true, property = true, class = true}

function overrides(tree, fw)
    local found, order_of = {}, {}
    for _, filepath in ipairs(files.glob(path.join(tree, layout.registry_dir(fw), "*.json"))) do
        local data = json.decode(files.read_text(filepath))
        local entries = data.entries or data
        for _, entry in ipairs(entries) do
            local owner = entry.owner or ""
            if entry.status == "implemented" and OVERRIDE_KINDS[entry.kind] and string.sub(owner, 1, 10) ~= "generator:" then
                if found[entry.api] == nil then
                    found[entry.api] = {registry = path.join(layout.registry_dir(fw), path.filename(filepath)), entry = entry}
                    table.insert(order_of, entry.api)
                end
            end
        end
    end
    return found, order_of
end

function pins(tree, fw)
    local text = files.read_text(layout.pins_path(tree, fw))
    if not text then
        return {}
    end
    return tsv.records(text)
end

function pins_text(list)
    local sorted = table.move(list, 1, #list, 1, {})
    table.sort(sorted, function(a, b) return order.less(a.key, b.key) end)
    local rows = {}
    for _, p in ipairs(sorted) do
        table.insert(rows, {p.api, p.key, p.pinned, p["pinned-by"], p.registry})
    end
    return tsv.table_text(layout.constants().PIN_COLUMNS, rows)
end

function refused(tree, fw)
    local current = {}
    for _, r in ipairs(member_rows(tree, fw)) do
        if current[r.key] == nil then
            current[r.key] = r
        end
    end
    local out = {}
    for _, p in ipairs(pins(tree, fw)) do
        local r = current[p.key]
        if r ~= nil and r.hash ~= p.pinned then
            table.insert(out, {key = p.key, api = p.api, old = p.pinned, new = r.hash, kind = "pinned"})
        end
    end
    table.sort(out, function(a, b) return order.less(a.key, b.key) end)
    return out
end
