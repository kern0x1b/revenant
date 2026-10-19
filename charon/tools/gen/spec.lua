-- The spec of a framework as the generator reads it, built in memory: the member rows from its declaration shard (members.rows over
-- headers.shard_facts, the same rows the members command reads), the constant rows from the constant record (layout.lua), the
-- hand-written overrides (registry rows the generator skips), and the pins that name the declaration each override was written
-- against. Nothing here writes a file: the spec table gen writes is derived under .gen and is never read back.

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

-- The frameworks of the tree that have a declaration shard, in byte order, nested frameworks included (spec/<F>/declarations.tsv
-- and spec/<Outer>/<Inner>/declarations.tsv, named "Outer/Inner").
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

-- A constant record row, with every spec column present ("-" where the record has none).
local function complete(r)
    for _, name in ipairs(layout.constants().SPEC_COLUMNS) do
        if r[name] == nil then
            r[name] = "-"
        end
    end
    return r
end

-- The rows of the constant record (constants.tsv: the measured constant rows, one record per framework, committed as data), or none.
-- An enumerator the shard declares is a found row with the shard's value (input writes it so; round 16).
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

-- The member rows of a framework's shard (method and property rows), and whether the framework has a shard file at all. The tbd
-- column is "-" unless the SDK is given: then each member's class is looked up in the classes the SDK's .tbd chain exports.
local function shard_rows(tree, fw, sdk)
    local facts = headers.shard_facts(tree, fw)
    local classes = sdk and tbd.class_exports(sdk, fw) or nil
    return members.rows(facts.members, classes, fw), #facts.members
end

-- The spec rows of a framework, in memory: its members from the shard, then its constants from the constant record. A framework with
-- no shard file and no members (a fixture of a test) keeps the member rows of its legacy spec file, so such a fixture reads its rows
-- as before. Two rows of one key get a digest of their api, as cmd_members does, so every key is one identifier.
-- The last framework built is kept (one slot): a command reads each framework's spec several times, and the shard is read once.
-- forget() drops it, and a command calls it first, so a change of the inputs between two runs in one process is seen.
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

-- The member rows (method and property) of a framework's spec, in the shard's order.
function member_rows(tree, fw)
    local out = {}
    for _, r in ipairs(load(tree, fw)) do
        if r.kind == "method" or r.kind == "property" then
            table.insert(out, r)
        end
    end
    return out
end

-- The spec table as the generator writes it under .gen: the header line of the spec columns, then one line per row.
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

-- Every spec row under its own api and, for a property, under the dotted name the registry uses (Class.name). The first row
-- of a key wins, as the oracle's setdefault does.
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

-- The hand-written registry rows of a framework that are implemented: api -> {registry = path, entry = row}, with the first row
-- of an api winning, and order = the apis in the order they were found (files sorted by name, rows in file order).
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

-- The pins of a framework, in the sidecar's order; none when no sidecar is committed.
function pins(tree, fw)
    local text = files.read_text(layout.pins_path(tree, fw))
    if not text then
        return {}
    end
    return tsv.records(text)
end

-- The pins as the sidecar holds them, sorted by key.
function pins_text(list)
    local sorted = table.move(list, 1, #list, 1, {})
    table.sort(sorted, function(a, b) return order.less(a.key, b.key) end)
    local rows = {}
    for _, p in ipairs(sorted) do
        table.insert(rows, {p.api, p.key, p.pinned, p["pinned-by"], p.registry})
    end
    return tsv.table_text(layout.constants().PIN_COLUMNS, rows)
end

-- The pinned members whose declaration changed since their pin: {key, api, old, new}, in key order. Only a pinned member is here: a
-- member with no pin has none, and regenerates from the shard, its change reviewed through the shard diff. gen refuses these unless
-- it re-records them (gen --record writes each new hash into its pin, pinned-by repin).
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
    -- The constant record has no refusal: it is input's output (input --all rewrites it from the ledger, the headers and the corpus),
    -- and the Python it ports kept no declaration hash per row to refuse on (round 15: the declhash column is gone with the owner's rule).
    table.sort(out, function(a, b) return order.less(a.key, b.key) end)
    return out
end
