-- Rank a real app's WEAK imports (Telegram UIStack build on the 4S) by what an absent symbol does.
-- Lua port of the former weak-imports.py.
--
-- A weak import does not stop dyld when the symbol is missing; the address resolves to NULL. What
-- happens next depends on the kind of symbol and on whether the code checks first:
--   constant (data)   read straight  -> load through a NULL address       -> CRASH-ON-USE
--   C function        called         -> call to NULL                      -> CRASH-ON-USE
--   ObjC class        messaged       -> message to nil, a silent no-op    -> SILENTLY DIFFERENT
--                                       (a crash only later, if the nil result is used as an object)
-- The list alone does not say whether each use is guarded (`if (&kSym)`, #available, respondsToSelector:),
-- so nothing here proves a crash. What it can do is: classify each symbol by kind through the SDK dump,
-- say whether it EXISTS now (registry status implemented/inert = present, not NULL), how new it is,
-- and how many corpus apps import it (a second, independent view of the same name).
--
-- usage: xmake l tools/corpus/weak-imports.lua <file, one symbol per line> [output-path]
-- Output: corpus/weak-imports-ranked.tsv (or argv[2] / $CHARON_WEAK_IMPORTS_OUT, to redirect a one-off or
-- test run away from the real file).
import("core.base.json")
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})
local tsv = import("tsv", {rootdir = os.scriptdir()})
local aggregate = import("aggregate", {rootdir = os.scriptdir(), anonymous = true})

-- corpus/ is DATA, in the durable location CHARON_CORPUS_ROOT addresses (default coordination/),
-- independent of this script's own location. See tools/corpus/README.md.
local CORPUS_ROOT = os.getenv("CHARON_CORPUS_ROOT") or path.join(os.getenv("HOME"), "Git", "projects", "ios", "coordination")
local CORPUS = path.join(CORPUS_ROOT, "corpus")
if not os.isdir(CORPUS) then
    raise("weak-imports.lua: no corpus/ data directory found at %s. Set CHARON_CORPUS_ROOT to the directory "
        .. "that contains corpus/.", CORPUS)
end
-- Coordinator regenerates the shared export after each merge; CHARON_REGISTRY_TSV lets a run read a
-- different one (e.g. regenerated straight from origin/main) WITHOUT touching the shared file.
local EXPORT = aggregate.registry_export()
-- Already caught in a real Telegram run on the device (read directly, absent -> NULL -> crash), per Coordinator.
local CAUGHT = {
    AVAudioSessionPortBluetoothLE = true,
    AVAudioSessionMediaServicesWereLostNotification = true,
    AVAudioSessionModeVideoChat = true,
}

local function starts(text, prefix)
    return text:sub(1, #prefix) == prefix
end

-- A version as a list of numbers, or nil when there is none (Python's ver(): empty text is None).
local function ver(text)
    if text == nil or text == "" then
        return nil
    end
    local parts = {}
    for piece in (text .. "."):gmatch("([^.]*)%.") do
        local n = tonumber(piece)
        if n == nil then
            raise("weak-imports.lua: %s is not a version", text)
        end
        table.insert(parts, n)
    end
    return parts
end

-- A version as a string that sorts in version order under byte comparison: each number padded to six digits.
local function version_key(text)
    local parts = ver(text)
    if parts == nil then
        parts = {99}
    end
    local out = {}
    for _, n in ipairs(parts) do
        table.insert(out, string.format("%06d", n))
    end
    return table.concat(out, ".")
end

-- A decimal count as a string that sorts the same way: larger first when the key is compared ascending.
local function descending(n)
    return string.format("%07d", 1000000 - n)
end

local function read_json(file)
    local held, err = json.decode(io.readfile(file))
    if held == nil then
        raise("weak-imports.lua: %s is not readable JSON: %s", file, tostring(err))
    end
    return held
end

-- api -> status and api -> introduced, last row winning (the Python dict did the same).
local function load_registry()
    local reg, intro = {}, {}
    if not os.isfile(EXPORT) then
        raise("weak-imports.lua: registry export not found at %s (CHARON_REGISTRY_TSV).", EXPORT)
    end
    for line in io.lines(EXPORT) do
        local p = tsv.split(line)
        if #p >= 3 and p[1] ~= "framework" then
            reg[p[2]] = p[3]
            if p[4] and p[4] ~= "" then
                intro[p[2]] = p[4]
            end
        end
    end
    return reg, intro
end

-- Provisional decisions handed down by Coordinator that the registry export does not carry yet. Marked
-- "(override)" everywhere they show, and only used when the registry has no row for the symbol.
local function load_overrides()
    local overrides = {}
    local op = path.join(CORPUS, "decision-overrides.tsv")
    if os.isfile(op) then
        local first = true
        for line in io.lines(op) do
            if first then
                first = false
            else
                local q = tsv.split(line)
                if #q >= 2 then
                    overrides[q[1]] = q[2]
                end
            end
        end
    end
    return overrides
end

-- A tally of keys. `ranked` lists them most frequent first, ties in first-seen order (Python's dict order,
-- which its stable sort kept); `alphabetical` lists them in byte order.
local function counter()
    local counts, order = {}, {}
    local tally = {}
    function tally.add(key)
        if counts[key] == nil then
            counts[key] = 0
            table.insert(order, key)
        end
        counts[key] = counts[key] + 1
    end
    function tally.get(key)
        return counts[key]
    end
    function tally.total()
        local sum = 0
        for _, key in ipairs(order) do
            sum = sum + counts[key]
        end
        return sum
    end
    function tally.ranked()
        local keyed = {}
        for index, key in ipairs(order) do
            keyed[descending(counts[key]) .. "\1" .. string.format("%07d", index)] = key
        end
        local out = {}
        for _, composite in ipairs(byteorder.keys(keyed)) do
            table.insert(out, keyed[composite])
        end
        return out
    end
    function tally.alphabetical()
        return byteorder.keys(counts)
    end
    return tally
end

local function present(row)
    return row.status == "implemented" or row.status == "inert"
end

local function tier_of(row)
    if row.caught then
        return "0 caught on device"
    end
    if (row.name:find("Metal", 1, true) or row.name:find("MTL", 1, true) or row.name:find("MTK", 1, true)) and not present(row) then
        return "6 Metal (not portable to A5)"
    end
    if present(row) then
        return "9 exists now"
    end
    if row.kind == "constant" or row.kind == "constant?" then
        return "1 NULL constant"
    end
    if row.kind == "function" or row.kind == "function?" then
        return "2 NULL function"
    end
    if row.kind == "class" or row.kind == "metaclass" then
        return "3 nil class"
    end
    if row.kind == "runtime" then
        return "5 compiler runtime (Katabasis)"
    end
    return "4 swift/c++ (other track)"
end

-- The symbol's kind, and the name it is looked up under (the SDK dump's and the registry's spelling).
local function kind_of(raw, sdk)
    if starts(raw, "_OBJC_CLASS_$_") then
        return "class", raw:sub(#"_OBJC_CLASS_$_" + 1)
    elseif starts(raw, "_OBJC_METACLASS_$_") then
        return "metaclass", raw:sub(#"_OBJC_METACLASS_$_" + 1)
    elseif starts(raw, "_$s") or starts(raw, "_$S") or starts(raw, "$s") or starts(raw, "$S") then
        return "swift", raw
    elseif starts(raw, "__Z") or starts(raw, "_Z") then
        return "c++", raw
    elseif starts(raw, "__") then
        return "runtime", raw
    end
    local name = starts(raw, "_") and raw:sub(2) or raw
    local fn = sdk[name .. "()"]
    local value = sdk[name]
    if fn ~= nil then
        return "function", name
    elseif type(value) == "table" and value[1] == "constant" then
        return "constant", name
    end
    -- no SDK row: Apple's k-prefix marks a constant; otherwise lowercase names are almost always
    -- functions and Capitalised ones constants
    if name:match("^k[A-Z]") then
        return "constant?", name
    elseif name:match("^[a-z]") then
        return "function?", name
    end
    return "constant?", name
end

function main(file, out_override)
    if not file then
        raise("usage: weak-imports.lua <file, one symbol per line> [output-path]")
    end
    local syms = {}
    for line in io.lines(file) do
        local raw = line:match("^%s*(.-)%s*$")
        if raw ~= "" then
            table.insert(syms, raw)
        end
    end
    local sdk = read_json(path.join(CORPUS, "sdk-introduced.json"))
    local reg, intro = load_registry()
    local overrides = load_overrides()
    local store = read_json(path.join(CORPUS, "store.json"))
    -- symbol -> { apps = set, strong = set }, over every app's demand records
    local corpus = {}
    for app, d in pairs(store.apps) do
        for _, r in ipairs(d.demand) do
            local e = corpus[r.name]
            if e == nil then
                e = {apps = {}, strong = {}}
                corpus[r.name] = e
            end
            e.apps[app] = true
            if not r.weak then
                e.strong[app] = true
            end
        end
    end
    local function count(set)
        local n = 0
        for _ in pairs(set) do
            n = n + 1
        end
        return n
    end

    local rows, keyed = {}, {}
    for index, raw in ipairs(syms) do
        local kind, name = kind_of(raw, sdk)
        -- the four spellings the registry may hold the symbol under (its base, the method form, the raw
        -- name and the raw name without the leading underscore)
        local keys = {name, name .. "()", raw, starts(raw, "_") and raw:sub(2) or raw}
        local status = nil
        for _, k in ipairs(keys) do
            if reg[k] ~= nil then
                status = reg[k]
                break
            end
        end
        if status == nil and overrides[raw] ~= nil then
            status = overrides[raw] .. " (override)"
        end
        if status == nil or status == "" then
            status = "no registry row"
        end
        local introduced = ""
        for _, k in ipairs(keys) do
            if intro[k] ~= nil then
                introduced = intro[k]
                break
            end
        end
        local srow = sdk[name] or sdk[name .. "()"]
        local framework = ""
        if type(srow) == "table" then
            if introduced == "" and type(srow[2]) == "string" then
                introduced = srow[2]
            end
            if type(srow[3]) == "string" then
                framework = srow[3]
            end
        end
        local c = corpus[raw] or corpus[name] or {apps = {}, strong = {}}
        local row = {
            raw = raw, name = name, kind = kind, status = status, introduced = introduced,
            framework = framework, apps = count(c.apps), strong = count(c.strong),
            caught = CAUGHT[name] == true, index = index,
        }
        row.tier = tier_of(row)
        table.insert(rows, row)
    end

    -- Sorted by tier, then most apps first, then the earliest version, then name; the row's position in the
    -- input breaks what is left, as Python's stable sort did.
    for _, row in ipairs(rows) do
        local key = table.concat({row.tier, descending(row.apps), version_key(row.introduced), row.name,
                                  string.format("%07d", row.index)}, "\1")
        keyed[key] = row
    end
    local sorted = {}
    for _, key in ipairs(byteorder.keys(keyed)) do
        table.insert(sorted, keyed[key])
    end
    rows = sorted

    local out = out_override or os.getenv("CHARON_WEAK_IMPORTS_OUT") or path.join(CORPUS, "weak-imports-ranked.tsv")
    local file_out = assert(io.open(out, "w"))
    file_out:write("tier\tsymbol\tkind\tframework\tintroduced\tregistry\tcorpus_apps_importing\tcorpus_strong\n")
    for _, row in ipairs(rows) do
        file_out:write(table.concat({row.tier, row.raw, row.kind, row.framework, row.introduced, row.status,
                                     tostring(row.apps), tostring(row.strong)}, "\t") .. "\n")
    end
    file_out:close()
    print(string.format("%d weak imports -> %s", #rows, out))

    -- per tier, the statuses it holds, most frequent first (ties in first-seen order)
    local tally = {}
    for _, row in ipairs(rows) do
        tally[row.tier] = tally[row.tier] or counter()
        tally[row.tier].add(row.status)
    end
    local tiers = {}
    for tier in pairs(tally) do
        table.insert(tiers, tier)
    end
    byteorder.sort(tiers)
    for _, tier in ipairs(tiers) do
        local t = tally[tier]
        local parts = {}
        for _, status in ipairs(t.ranked()) do
            table.insert(parts, string.format("%s %d", status, t.get(status)))
        end
        print(string.format("  %-28s %4d   %s", tier, t.total(), table.concat(parts, ", ")))
    end

    -- per framework, the rows that would be NULL or nil (tiers 0 to 3), the 14 largest
    local fw, fw_order = {}, {}
    for _, row in ipairs(rows) do
        if row.tier:match("^[0-3]") then
            local f = row.framework ~= "" and row.framework or "(not in my SDK dump)"
            if fw[f] == nil then
                fw[f] = counter()
                table.insert(fw_order, f)
            end
            fw[f].add(row.tier:sub(1, 1) .. ":" .. row.status)
        end
    end
    local fw_keyed = {}
    for index, f in ipairs(fw_order) do
        fw_keyed[descending(fw[f].total()) .. "\1" .. string.format("%07d", index)] = f
    end
    print("\nby framework (tiers 0-3 only: what would be NULL or nil), top 14:")
    local printed = 0
    for _, composite in ipairs(byteorder.keys(fw_keyed)) do
        if printed == 14 then
            break
        end
        printed = printed + 1
        local f = fw_keyed[composite]
        local parts = {}
        for _, key in ipairs(fw[f].alphabetical()) do
            table.insert(parts, string.format("%s x%d", key, fw[f].get(key)))
        end
        print(string.format("  %-26s %3d   %s", f, fw[f].total(), table.concat(parts, ", ")))
    end

    local telegram = store.apps.telegram
    local tg_names = {}
    if telegram then
        for _, r in ipairs(telegram.demand) do
            tg_names[r.name] = true
        end
    end
    local hit = 0
    for _, row in ipairs(rows) do
        if tg_names[row.raw] or tg_names[row.name] then
            hit = hit + 1
        end
    end
    print(string.format("\noverlap with the release Telegram in my corpus (a different, arm64 build): %d of %d weak symbols also appear in its imports", hit, #rows))
    return rows
end
