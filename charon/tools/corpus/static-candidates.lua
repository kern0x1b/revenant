-- Join surface-diff's static candidate list (undecided API, from Backports 7-10) with corpus demand. Lua port of the
-- former static-candidates.py.
--
-- Input: the file `surface-diff.py --release 6.0 --list` writes, path given as argument 1. Its lines are
-- `<version|?> <kind> <api>` under per-framework headers ("UIKit: N declared"). A version means the SDK gives the
-- member's availability; `?` means it has none recorded.
--
-- For every listed method/property, count the corpus apps that SEND its selector (bundle carries the string and does
-- not define it) and, from the app deployment targets, how many can call it without a guard. Output
-- corpus/static-candidates-demand.tsv (or argument 2 / $CHARON_STATIC_CANDIDATES_OUT, to redirect a one-off or test
-- run away from the real file), then compare with the crash-demand list, which is built by a different route (SDK
-- dump + registry join): the two should agree on the undecided rows that apps send, and where they differ one of the
-- two has a bug.
--
-- usage: xmake l tools/corpus/static-candidates.lua <surface-diff --list output> [output-path]
import("core.base.json")
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})
local aggregate = import("aggregate", {rootdir = os.scriptdir(), anonymous = true})
local tsv = import("tsv", {rootdir = os.scriptdir()})

-- The minimum deployment target of each corpus app, as the version tuple the candidate's version is compared with.
local MINOS = {ish = {11, 0}, ppsspp = {11, 0}, pojav = {12, 2}, provenance = {16, 0}, delta = {14, 0}, utm = {14, 0},
               aidoku = {15, 0}, yattee = {14, 0}, session = {15, 0}, telegram = {11, 0}}
local APP_ORDER = {"ish", "ppsspp", "pojav", "provenance", "delta", "utm", "aidoku", "yattee", "session", "telegram"}
local KINDS = {method = true, property = true, class = true, protocol = true, constant = true, ["function"] = true}

-- A version text as a list of numbers; nil for "?".
local function version_of(text)
    if text == "?" then
        return nil
    end
    local parts = {}
    for piece in (text .. "."):gmatch("([^.]*)%.") do
        table.insert(parts, tonumber(piece))
    end
    return parts
end

-- Python's tuple comparison a >= b: element by element, and a tuple that is a prefix of the other is the smaller.
local function at_least(a, b)
    for index = 1, math.max(#a, #b) do
        local x, y = a[index], b[index]
        if x == nil then
            return false
        end
        if y == nil then
            return true
        end
        if x ~= y then
            return x > y
        end
    end
    return true
end

-- The selector names an api line stands for: a method's selector, or a property's getter and setter pair.
local function selectors(api, kind)
    local name = api:match("^[-+]%[[%w_]+ (.+)%]$")
    if name then
        return {name}
    end
    if kind == "property" and api:find(".", 1, true) then
        local n = api:sub(api:find(".", 1, true) + 1)
        local up = n:sub(1, 1):upper() .. n:sub(2)
        return {n, "set" .. up .. ":", "is" .. up}
    end
    return {}
end

-- The crash-demand list, keyed by api. The rows name an api with a "(+N owners)" suffix when several classes share it;
-- the suffix is dropped for the key.
local function load_crash_list()
    local mine = {}
    for _, r in ipairs(tsv.body(path.join(aggregate.corpus_dir(), "crash-demand-top.tsv"))) do
        mine[(r[3]:gsub(" %(%+%d+ owners%)$", ""))] = r
    end
    return mine
end

-- The apps that send a selector: the caches the extract step wrote, minus what the app defines itself, minus what
-- the stock 6.0 universe already has (the same rule as the crash list).
local function sends_by_selector(universe)
    local sends = {}
    for _, app in ipairs(APP_ORDER) do
        local carried = json.decode(io.readfile(path.join(aggregate.corpus_dir(), "selcache", app .. ".json")))
        local defined = json.decode(io.readfile(path.join(aggregate.corpus_dir(), "defcache", app .. ".json")))
        if carried == nil or defined == nil then
            raise("static-candidates.lua: the selector caches of %s are not readable JSON", app)
        end
        local defined_set = {}
        for _, s in ipairs(defined) do
            defined_set[s] = true
        end
        for _, s in ipairs(carried) do
            if not defined_set[s] and not universe[s] then
                sends[s] = sends[s] or {}
                sends[s][app] = true
            end
        end
    end
    return sends
end

local function count_of(set)
    local n = 0
    for _ in pairs(set) do
        n = n + 1
    end
    return n
end

local function listed_candidates(list)
    local fw, cands = nil, {}
    for line in io.lines(list) do
        local header = line:match("^(%w+): %d+ declared")
        if header then
            fw = header
        else
            local v, kind, api = line:match("^%s+(%S+)%s+(%S+)%s+(.-)%s*$")
            if v and fw and KINDS[kind] and (v == "?" or v:match("^%d[%d%.]*$")) then
                table.insert(cands, {framework = fw, version = version_of(v), text = v, kind = kind, api = api})
            end
        end
    end
    return cands
end

function main(list, out_override)
    if not list then
        raise("usage: static-candidates.lua <surface-diff --list output> [output-path]")
    end
    local cands = listed_candidates(list)
    local universe = aggregate.selector_universe()
    local sends = sends_by_selector(universe)

    local rows = {}
    for _, cand in ipairs(cands) do
        if cand.kind == "method" or cand.kind == "property" then
            local apps = {}
            for _, s in ipairs(selectors(cand.api, cand.kind)) do
                local dotted = cand.kind == "property" and cand.api:find(".", 1, true) and cand.api:sub(cand.api:find(".", 1, true) + 1)
                -- a property whose name is only the getter of "is<Name>" in the stock universe is not its own selector
                local skip = dotted and s == dotted and universe["is" .. dotted:sub(1, 1):upper() .. dotted:sub(2)] and not universe[s]
                if not skip then
                    for app in pairs(sends[s] or {}) do
                        apps[app] = true
                    end
                end
            end
            if count_of(apps) > 0 then
                local crash = {}
                for app in pairs(apps) do
                    if cand.version ~= nil and at_least(MINOS[app], cand.version) then
                        table.insert(crash, app)
                    end
                end
                local senders = {}
                for app in pairs(apps) do
                    table.insert(senders, app)
                end
                byteorder.sort(senders)
                table.insert(rows, {crash = #crash, apps = #senders, framework = cand.framework, version = cand.text,
                                    kind = cand.kind, api = cand.api, senders = senders})
            end
        end
    end
    -- sorted by unguarded callers, then apps, then api: crash and apps are both below 100, so one number orders them
    local ordered = aggregate.ranked(rows, function (row) return row.crash * 100 + row.apps end,
                                     function (row) return row.api end)

    local dest = out_override or os.getenv("CHARON_STATIC_CANDIDATES_OUT")
        or path.join(aggregate.corpus_dir(), "static-candidates-demand.tsv")
    local file = assert(io.open(dest, "w"))
    file:write("unguarded_callers\tapps\tframework\tintroduced\tkind\tapi\tsenders\n")
    for _, row in ipairs(ordered) do
        file:write(string.format("%d\t%d\t%s\t%s\t%s\t%s\t%s\n", row.crash, row.apps, row.framework, row.version, row.kind,
                                 row.api, table.concat(row.senders, ",")))
    end
    file:close()

    local methods = 0
    for _, cand in ipairs(cands) do
        if cand.kind == "method" or cand.kind == "property" then
            methods = methods + 1
        end
    end
    local known, unversioned = 0, 0
    for _, row in ipairs(ordered) do
        if row.version ~= "?" then
            known = known + 1
        else
            unversioned = unversioned + 1
        end
    end
    print(string.format("listed candidates: %d (%d methods/properties); sent by >=1 corpus app: %d -> %s",
                        #cands, methods, #ordered, dest))
    print(string.format("  of those with a known version: %d; unversioned ('?'): %d", known, unversioned))

    -- compare with the crash-demand list (a different route to the same question). Its columns, 1-based here: 3 api,
    -- 4 kind, 5 framework, 9 apps, 10 crash_apps, 15 registry status.
    local mine = load_crash_list()
    local theirs = {}
    for _, row in ipairs(ordered) do
        theirs[row.api] = row
    end
    local my_undecided, my_count = {}, 0
    for api, r in pairs(mine) do
        if r[4] == "selector" and r[15]:sub(1, 9) == "undecided" and (r[5] == "UIKit" or r[5] == "Foundation") then
            my_undecided[api] = true
            my_count = my_count + 1
        end
    end
    local t_sent, t_sent_count, both = {}, 0, 0
    for api, row in pairs(theirs) do
        if row.crash >= 1 then
            t_sent[api] = true
            t_sent_count = t_sent_count + 1
            if my_undecided[api] then
                both = both + 1
            end
        end
    end
    print(string.format("\ncrash list: undecided selector rows %d; static list rows the corpus sends unguarded %d; in both %d",
                        my_count, t_sent_count, both))

    local only_theirs, only_mine = {}, {}
    for api in pairs(t_sent) do
        if not my_undecided[api] then
            table.insert(only_theirs, {api = api, crash = theirs[api].crash, apps = theirs[api].apps})
        end
    end
    for api in pairs(my_undecided) do
        if not theirs[api] then
            table.insert(only_mine, {api = api, crash = tonumber(mine[api][10]) or 0, apps = tonumber(mine[api][9]) or 0})
        end
    end
    only_theirs = aggregate.ranked(only_theirs, function (e) return e.crash * 100 + e.apps end, function (e) return e.api end)
    only_mine = aggregate.ranked(only_mine, function (e) return e.crash * 100 + e.apps end, function (e) return e.api end)
    print(string.format("  only in the static list (my list lacks them): %d", #only_theirs))
    for index = 1, math.min(12, #only_theirs) do
        local e = only_theirs[index]
        local status = mine[e.api] and mine[e.api][15] or "not in my list"
        print(string.format("     %d/%d %-5s %-14s %s", e.crash, e.apps, theirs[e.api].version, status:sub(1, 14), e.api:sub(1, 70)))
    end
    print(string.format("  only in my list (the static list does not call them undecided): %d", #only_mine))
    for index = 1, math.min(12, #only_mine) do
        local e = only_mine[index]
        local r = mine[e.api]
        print(string.format("     %d/%d %-5s %-22s %s", e.crash, e.apps, r[6], r[15]:sub(1, 22), e.api:sub(1, 64)))
    end
    return ordered
end
