local layout = import("layout", {anonymous = true})
local sdk = import("sdk", {anonymous = true})
local tsv = import("tsv", {anonymous = true})
local files = import("files", {anonymous = true})
local order = import("order", {anonymous = true})
local surface_model = import("surface_model", {anonymous = true})
local json = import("core.base.json")

local surface_memo = {}

function key(kind, api)
    return kind .. "\t" .. api
end

function canonical_member(api, kind)
    if kind == "property" and string.sub(api, 1, 2) ~= "-[" and string.sub(api, 1, 2) ~= "+[" and string.find(api, ".", 1, true) then
        local cls, name = string.match(api, "^([^.]*)%.(.*)$")
        return "-[" .. cls .. " " .. name .. "]"
    end
    return api
end

local LEDGER_6_1_3 = "ledger-w45"
local LEDGER_4_3 = "ledger-w45-4.3"

function ledger_6_1_3()
    return LEDGER_6_1_3
end

function ledger_4_3()
    return LEDGER_4_3
end

function ledger_file(corpus, release_dir, fw)
    local folder = path.is_absolute(release_dir) and release_dir or path.join(corpus, release_dir)
    return path.join(folder, (string.gsub(fw, "/", "_")) .. ".tsv")
end

function has_ledger(corpus, release_dir, fw)
    return os.isfile(ledger_file(corpus, release_dir, fw))
end

local absent_memo = {}
function absent_frameworks(tree)
    if absent_memo[tree] == nil then
        local file = path.join(tree, "..", layout.constants().SNAP_ROOT, "framework-verdicts-6.1.3.tsv")
        assert(os.isfile(file), "the 6.1.3 framework verdicts are not found: " .. file)
        local known = {}
        for _, row in ipairs(tsv.records(files.read_text(file))) do
            if row.verdict == "absent" then
                known[row.framework] = row.reason
            end
        end
        absent_memo[tree] = known
    end
    return absent_memo[tree]
end

function not_checked_state(release)
    return "not checked at " .. (release or "6.1.3")
end

function unlisted_state(tree, fw)
    if absent_frameworks(tree)[fw] ~= nil then
        return "absent at 6.1.3"
    end
    return not_checked_state()
end

function ledger_status(corpus, fw, release_dir)
    local out = {}
    local text = files.read_text(ledger_file(corpus, release_dir, fw))
    if not text then
        return out
    end
    for _, row in ipairs(tsv.records(text)) do
        if row.kind and row.kind ~= "" and row.api and row.api ~= "" then
            out[key(row.kind, row.api)] = row.status
        end
    end
    return out
end

local function surface(tree, corpus, release)
    local memo_key = tree .. "\t" .. corpus .. "\t" .. release
    if surface_memo[memo_key] then
        return surface_memo[memo_key]
    end
    local rows, order = {}, {}
    local list = surface_model.rows(tree, corpus, release)
    for _, row in ipairs(list) do
        if rows[row.framework] == nil then
            rows[row.framework] = {}
            table.insert(order, row.framework)
        end
        table.insert(rows[row.framework], row)
    end
    surface_memo[memo_key] = {rows = rows, order = order}
    return surface_memo[memo_key]
end

function surface_rows(tree, corpus, release, fw)
    return surface(tree, corpus, release).rows[fw] or {}
end

function by_key(list)
    local out = {}
    for _, row in ipairs(list) do
        local k = key(row.kind, row.api)
        if out[k] == nil then
            out[k] = row
        end
    end
    return out
end

function surface_frameworks(tree, corpus, release)
    local known = surface(tree, corpus, release).order
    return table.move(known, 1, #known, 1, {})
end

function all_rows(tree, corpus, release)
    local data = surface(tree, corpus, release)
    return {rows = data.rows, order = data.order}
end

function oracle_defaults(corpus, release, fw)
    local out = {}
    local text = files.read_text(path.join(corpus, sdk.names(release).oracle_defaults))
    if not text then
        return out
    end
    for _, row in ipairs(tsv.records(text)) do
        if row.framework == fw then
            out[row.class] = out[row.class] or {}
            table.insert(out[row.class], {row.item, row.value_kind, row.value, row.build})
        end
    end
    return out
end

function registry_rows(tree, fw)
    local out = {}
    local single = path.join(tree, "..", layout.constants().REGISTRY, fw .. ".json")
    local candidates = files.glob(path.join(tree, "..", layout.registry_dir(fw), "*.json"))
    if os.isfile(single) then
        table.insert(candidates, single)
    end
    table.sort(candidates, order.less)
    for _, filepath in ipairs(candidates) do
        local data = json.decode(files.read_text(filepath))
        local entries = data.entries or data
        local relative = path.join(layout.registry_dir(fw), path.filename(filepath))
        if filepath == single then
            relative = path.join(layout.constants().REGISTRY, fw .. ".json")
        end
        for _, entry in ipairs(entries) do
            table.insert(out, {registry = relative, entry = entry})
        end
    end
    return out
end

function registry_entries(tree, fw)
    local found = {}
    for _, row in ipairs(registry_rows(tree, fw)) do
        local canonical = canonical_member(row.entry.api, row.entry.kind or "method")
        if found[canonical] == nil then
            found[canonical] = row
        end
    end
    return found
end

function registry_constants(tree, fw)
    local names = {}
    for _, row in ipairs(registry_rows(tree, fw)) do
        local entry = row.entry
        if entry.kind == "constant" and string.sub(entry.owner or "", 1, 10) ~= "generator:" then
            names[entry.api] = true
        end
    end
    return names
end
