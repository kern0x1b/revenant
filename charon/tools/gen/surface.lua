-- The corpus the trace layer, the docs and the scope read beside the snapshot: the surface (computed from the model by
-- surface_model.lua, not read from a table), the ledgers of the release each band measured, the host oracle's defaults, and the
-- registry rows of a framework whatever their status. The corpus is the coordination folder's corpus/ directory, passed in by the
-- command (--coordination); the tree is --tree. Nothing here names a host path.

local layout = import("layout", {anonymous = true})
local sdk = import("sdk", {anonymous = true})
local tsv = import("tsv", {anonymous = true})
local files = import("files", {anonymous = true})
local order = import("order", {anonymous = true})
local surface_model = import("surface_model", {anonymous = true})
local json = import("core.base.json")

local surface_memo = {}

-- The key of a (kind, api) pair in the maps below.
function key(kind, api)
    return kind .. "\t" .. api
end

-- The key a member has in the trace layer's stub list: a property written 'Class.name' is '-[Class name]'.
function canonical_member(api, kind)
    if kind == "property" and string.sub(api, 1, 2) ~= "-[" and string.sub(api, 1, 2) ~= "+[" and string.find(api, ".", 1, true) then
        local cls, name = string.match(api, "^([^.]*)%.(.*)$")
        return "-[" .. cls .. " " .. name .. "]"
    end
    return api
end

-- The corpus folders of the two ledgers the generator reads: the 6.1.3 release (ledger-w45) and the 4.3 release.
local LEDGER_6_1_3 = "ledger-w45"
local LEDGER_4_3 = "ledger-w45-4.3"

function ledger_6_1_3()
    return LEDGER_6_1_3
end

function ledger_4_3()
    return LEDGER_4_3
end

-- The ledger file of a framework in a release folder. A nested framework (a name with a slash, such as include/AppleArchive) has its ledger as
-- include_AppleArchive.tsv: the slash of its name is an underscore in the file name, as the corpus writes it. Every reader of a
-- ledger goes through this one mapping. A release_dir that is an absolute path is the folder itself (the rows `gen.lua ledger --rows` wrote),
-- not a folder under the corpus.
function ledger_file(corpus, release_dir, fw)
    local folder = path.is_absolute(release_dir) and release_dir or path.join(corpus, release_dir)
    return path.join(folder, (string.gsub(fw, "/", "_")) .. ".tsv")
end

-- True when the release folder has a ledger for the framework (without one every member is considered).
function has_ledger(corpus, release_dir, fw)
    return os.isfile(ledger_file(corpus, release_dir, fw))
end

-- The frameworks absent from iOS 6.1.3, each with the reason the ledger gives: the verdict "absent" rows of
-- spec/framework-verdicts-6.1.3.tsv, committed and written by `gen.lua ledger` from the release's own cache (ledger.lua's absence rule). A
-- framework with no 6.1.3 ledger is either absent from the release (its rows are work) or not checked (no claim is made about it). Returns
-- name -> reason.
local absent_memo = {}
function absent_frameworks(tree)
    if absent_memo[tree] == nil then
        local file = path.join(tree, layout.constants().SNAP_ROOT, "framework-verdicts-6.1.3.tsv")
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

-- The state of a surface row the ledger of a release does not list: not checked at that release (6.1.3 when no release is given).
-- An unlisted row is never read as implemented.
function not_checked_state(release)
    return "not checked at " .. (release or "6.1.3")
end

-- The state of a 6.1.3 row the ledger does not list, by its framework: "absent at 6.1.3" when the framework is absent from the release
-- (absent_frameworks), else not_checked_state().
function unlisted_state(tree, fw)
    if absent_frameworks(tree)[fw] ~= nil then
        return "absent at 6.1.3"
    end
    return not_checked_state()
end

-- (kind, api) -> status for the framework's rows the ledger of a release lists. A row it does not list is not checked (not_checked_state).
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

-- The surface, read once from the model (surface_model.lua: the declaration and Swift shards of the tree, with the corpus's demand and
-- file lists): framework -> its rows, one per declaration (a usr is one row: surface_model.lua drops a usr its framework already holds),
-- in the surface's order; and the frameworks in the order the surface first names them. A (kind, api) key can name several rows (two
-- overloads, a class and an instance property of one name): each is its own row, and a reader that keys its output by api says how it
-- takes them (by_key, or its own dedupe).
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

-- The surface rows of one framework: one per declaration, in the surface's order.
function surface_rows(tree, corpus, release, fw)
    return surface(tree, corpus, release).rows[fw] or {}
end

-- The rows of a list by (kind, api), the first row of each key. For the readers that take a row's enrichment (the crash demand and the
-- implementation leads), which is computed from the kind and the api: every row of a key carries the same values, so the first stands
-- for them. A reader that takes the rows' own fields uses the list.
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

-- Every framework the surface names, in the order the surface first names them.
function surface_frameworks(tree, corpus, release)
    local known = surface(tree, corpus, release).order
    return table.move(known, 1, #known, 1, {})
end

-- Every row of the surface, by framework: {rows = fw -> the framework's rows in the surface's order, order = the frameworks in the
-- order the surface first names them}. The scope counts each row.
function all_rows(tree, corpus, release)
    local data = surface(tree, corpus, release)
    return {rows = data.rows, order = data.order}
end

-- class -> the list of {item, value_kind, value, build} from the host oracle capture, for one framework.
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

-- Every row of a framework's registry files, whatever its status, in the files' order (sorted by name): {registry = path, entry = row}.
function registry_rows(tree, fw)
    local out = {}
    local single = path.join(tree, layout.constants().REGISTRY, fw .. ".json")
    local candidates = files.glob(path.join(tree, layout.registry_dir(fw), "*.json"))
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

-- The registry rows of a framework, whatever their status: canonical key -> {registry = path, entry = row}, the first row of a
-- key winning over the files sorted by name.
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

-- The constants the registry names, by name, in any status: a row of any registry file, of kind constant, whose owner is not the
-- generator. The generator does not emit these: a name the registry holds is either defined by hand (an inert or implemented row
-- says so) or refused by the registry check, which names a generated row twice (registry() in modules/apple/backports.lua).
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
