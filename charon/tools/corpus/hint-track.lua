-- Ledger of how the decision hints compare with what the row owners later decided. Lua port of the former
-- hint-track.py.
--
-- Run right after a regeneration, with the PREVIOUS list still saved as crash-demand-prev.tsv:
-- for each row that was UNDECIDED in the previous list, the outcome is
--    carry   - the row left the list (the registry now implements it or carries it inert)
--    absent  - the row is still listed and its registry status became absent
--    pending - still undecided
-- Only decided outcomes are appended to corpus/hint-ledger.tsv (one line per API, never twice).
-- Then prints, per hint tag, how often the decision matched the hint.
--
-- A hint agrees with an outcome when: likely-carry -> carry, likely-absent -> absent.
-- The other tags (no-signal, class-undecided, protocol-owner, band-13+ unstarted) make no prediction; their
-- outcomes are recorded so the base rate is visible.
--
-- Run it on every batch: the previous list is overwritten by the next regeneration, and what was decided in
-- between cannot be reconstructed afterwards. It appends to the shared ledger: point CHARON_CORPUS_ROOT at a
-- scratch copy for a test run.
--
-- usage: xmake l tools/corpus/hint-track.lua [batch-label]     (default: today's date)
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})
local tsv = import("tsv", {rootdir = os.scriptdir()})
local aggregate = import("aggregate", {rootdir = os.scriptdir(), anonymous = true})

local CORPUS_ROOT = os.getenv("CHARON_CORPUS_ROOT") or path.join(os.getenv("HOME"), "Git", "projects", "ios", "coordination")
local C = path.join(CORPUS_ROOT, "corpus")
local EXPORT = aggregate.registry_export()

if not os.isdir(C) then
    raise("hint-track.lua: no corpus/ data directory found at %s. Set CHARON_CORPUS_ROOT to the directory that "
        .. "contains corpus/.", C)
end

-- The hint's tag: the hint without its parenthesised detail; "(none)" when there is no hint.
local function tag_of(hint)
    local tag = (hint or ""):gsub(" %(.*%)$", ""):match("^%s*(.-)%s*$")
    if tag == "" then
        return "(none)"
    end
    return tag
end

-- Every registry key a row's status may be recorded under (the same spellings crash-demand's status_one tries).
local function keys_for(api)
    api = (api:gsub(" %(%+%d+ owners%)$", ""))
    local keys = {api}
    local first = api:sub(1, 1)
    local method = first == "-" or first == "+"
    local dot = api:find(".", 1, true)
    local owner = api:match("^[+-]%[([%w_]+) ")
    if not owner and dot then
        owner = api:sub(1, dot - 1)
    end
    if dot and not method then
        local o, n = api:sub(1, dot - 1), api:sub(dot + 1)
        local up = n:sub(1, 1):upper() .. n:sub(2)
        for _, key in ipairs({"-[" .. o .. " " .. n .. "]", "-[" .. o .. " set" .. up .. ":]", "-[" .. o .. " is" .. up .. "]",
                              "+[" .. o .. " " .. n .. "]", "+[" .. o .. " set" .. up .. ":]"}) do
            table.insert(keys, key)
        end
    end
    if owner then
        table.insert(keys, owner)
    end
    -- link-time names: the registry stores a constant without the linker's leading underscore, and a C function as `name()`.
    if not method and not dot then
        if first == "_" then
            table.insert(keys, api:sub(2))
            table.insert(keys, api:sub(2) .. "()")
        end
        table.insert(keys, api .. "()")
    end
    return keys
end

-- api -> status for the registry file, the last row of an api winning (as the Python dict did).
local function load_registry(file)
    local reg = {}
    if os.isfile(file) then
        for line in io.lines(file) do
            local p = tsv.split(line)
            if #p >= 3 and p[1] ~= "framework" then
                reg[p[2]] = p[3]
            end
        end
    end
    return reg
end

-- The rows of a crash-demand list keyed by api (its column 3).
local function load_keyed(file)
    return tsv.keyed(tsv.body(file), 3)
end

local function api_set(file)
    local set = {}
    if os.isfile(file) then
        for _, row in ipairs(tsv.body(file)) do
            if row[2] == nil then
                raise("hint-track.lua: %s has a row with no api column", file)
            end
            set[row[2]] = true
        end
    end
    return set
end

-- Columns of crash-demand-top.tsv / -prev.tsv read here (1-based): 3 api, 4 kind, 6 band, 7 route, 9 apps,
-- 10 crash_apps, 15 registry status, 16 hint. The Python this replaced read 12 and 13 for those last two; in the
-- current layout those are class-confirmed counts, so its "undecided" test cannot match a current list.
function main(batch)
    batch = batch or os.date("%Y-%m-%d")
    -- A row counts as decided by an owner only if the REGISTRY's status for it (its own rows or its owner
    -- class) differs between the previous run's snapshot and now. A row can also leave the list because the
    -- rule changed; that is not a decision and must not enter the ledger.
    local last_path = path.join(C, "registry-last.tsv")
    local last = load_registry(last_path)
    local now = load_registry(EXPORT)
    local have_baseline = os.isfile(last_path)
    local function registry_changed(api)
        for _, key in ipairs(keys_for(api)) do
            if last[key] ~= now[key] then
                return true
            end
        end
        return false
    end
    local prev, prev_order = load_keyed(path.join(C, "crash-demand-prev.tsv"))
    local new = load_keyed(path.join(C, "crash-demand-top.tsv"))
    local ledger_p = path.join(C, "hint-ledger.tsv")
    local seen = api_set(ledger_p)
    local new_rows = {}
    for _, api in ipairs(prev_order) do
        local r = prev[api]
        local undecided = r[15]:sub(1, 9) == "undecided"
        if undecided and not seen[api] and r[4] == "selector" and have_baseline and registry_changed(api) then
            local outcome = nil
            if new[api] == nil then
                outcome = "carry"
            elseif new[api][15]:match("^([^(]*)") == "absent" then
                outcome = "absent"
            end
            if outcome then
                table.insert(new_rows, {batch, api, tag_of(r[16]), outcome, r[10], r[9], r[6]})
            end
        end
    end
    -- reversals: rows that were decided ABSENT in the previous list and have since left it (implemented or
    -- inert). Not a hint outcome (absent rows carry no hint) but the measure of how often an absent decision
    -- is later withdrawn.
    local rev_p = path.join(C, "absent-reversals.tsv")
    local rev_seen = api_set(rev_p)
    local reversed_now = {}
    for _, api in ipairs(prev_order) do
        local r = prev[api]
        if r[15]:match("^([^(]*)") == "absent" and new[api] == nil and not rev_seen[api] and have_baseline
                and registry_changed(api) then
            table.insert(reversed_now, {batch, api, r[10], r[9], r[6], r[7]})
        end
    end
    if #reversed_now > 0 then
        local head = not os.isfile(rev_p)
        local file = assert(io.open(rev_p, "a"))
        if head then
            file:write("batch\tapi\tunguarded_callers\tapps\tband\troute\n")
        end
        for _, row in ipairs(reversed_now) do
            file:write(table.concat(row, "\t") .. "\n")
        end
        file:close()
    end
    if not have_baseline then
        print("no registry baseline yet (registry-last.tsv): recording nothing this run")
    end
    print(string.format("absent decisions reversed this batch: %d", #reversed_now))
    local write_header = not os.isfile(ledger_p)
    local file = assert(io.open(ledger_p, "a"))
    if write_header then
        file:write("batch\tapi\thint\toutcome\tunguarded_callers\tapps\tband\n")
    end
    for _, row in ipairs(new_rows) do
        file:write(table.concat(row, "\t") .. "\n")
    end
    file:close()
    local rows = tsv.body(ledger_p)
    print(string.format("ledger: +%d decided this batch, %d in total", #new_rows, #rows))
    local tally = {}
    for _, row in ipairs(rows) do
        local tag, outcome = row[3], row[4]
        if outcome ~= "carry" and outcome ~= "absent" then
            raise("hint-track.lua: the ledger holds an outcome that is neither carry nor absent: %s", tostring(outcome))
        end
        tally[tag] = tally[tag] or {carry = 0, absent = 0}
        tally[tag][outcome] = tally[tag][outcome] + 1
    end
    local predicted = {["likely-carry"] = "carry", ["likely-absent"] = "absent"}
    for _, tag in ipairs(byteorder.keys(tally)) do
        local c = tally[tag]
        local n = c.carry + c.absent
        local pred = predicted[tag]
        local agree = pred and string.format("  agreed %d/%d", c[pred], n) or "  (makes no prediction)"
        print(string.format("  %-24s decided %3d  carry %3d  absent %3d%s", tag, n, c.carry, c.absent, agree))
    end
end
