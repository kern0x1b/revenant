import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})
import("aggregate", {rootdir = os.scriptdir()})

local EM, EN, ARROW, MINUS = "\u{2014}", "\u{2013}", "\u{2192}", "\u{2212}"
local CORPUS = aggregate.corpus_dir()
local store = aggregate.read_json(path.join(CORPUS, "store.json"))
local reg = aggregate.load_registry()
local built, built_canon = aggregate.load_built_exports()
local DROP = path.join(CORPUS, "absent")
local is_gap = aggregate.is_gap

local kata = {}
if os.isdir(DROP) then
    for _, file in ipairs(os.files(path.join(DROP, "*.absent.tsv"))) do
        local name = path.filename(file)
        local stem = name:sub(1, #name - #".absent.tsv")
        local app = stem:match("^(.-)%-ext%-") or stem
        kata[app] = kata[app] or {}
        for line in io.lines(file) do
            local kind, rest = line:match("^([^\t]*)\t(.*)$")
            if kind == "class" then
                kata[app][rest:match("^([^\t]*)")] = true
            end
        end
    end
end

local apps = byteorder.keys(store.apps)

local order, by_key = {}, {}
for _, app in ipairs(apps) do
    for _, r in ipairs(store.apps[app].demand) do
        if not aggregate.is_swift_mangled(r.name) then
            local cat = r.cat or "FRAMEWORK"
            local key = table.concat({cat, r.kind, r.name, r.framework, r.band}, "\1")
            local e = by_key[key]
            if e == nil then
                e = {cat = cat, kind = r.kind, name = r.name, framework = r.framework, band = r.band,
                     apps = {}, strong = {}, order = #order + 1}
                by_key[key] = e
                table.insert(order, e)
            end
            e.apps[app] = true
            if not r.weak then
                e.strong[app] = true
            end
        end
    end
end

local function count(set)
    local n = 0
    for _ in pairs(set) do n = n + 1 end
    return n
end

for _, e in ipairs(order) do
    e.status = aggregate.carried_status(reg, e.kind, e.name, e.framework)
    e.nstrong, e.napps = count(e.strong), count(e.apps)
end

local function band_tally(cat_filter)
    local gap, carried, na = {}, {}, {}
    for _, e in ipairs(order) do
        if e.cat == cat_filter then
            local bucket = gap
            if e.status == "n/a-A5" then
                bucket = na
            elseif not is_gap(e.status) then
                bucket = carried
            end
            bucket[e.band] = (bucket[e.band] or 0) + 1
        end
    end
    return gap, carried, na
end

local function load_cache_set(stem)
    local set = {}
    local file = path.join(CORPUS, "caches", stem .. ".tsv")
    if os.isfile(file) then
        for line in io.lines(file) do
            local sym = line:match("^([^\t]*)")
            if sym ~= "" then
                set[sym] = true
            end
        end
    end
    return set
end

local function full_symbol(kind, name)
    if kind == "class" then
        return "_OBJC_CLASS_$_" .. name
    end
    return name
end

local function ranked(rows, rank)
    local keyed = {}
    for _, row in ipairs(rows) do
        local key = string.format("%d\1%09d\1%09d\1%s\1%s\1%09d", rank(row), 999999999 - row.nstrong,
            999999999 - row.napps, row.framework, row.name, row.order)
        keyed[key] = row
    end
    local out = {}
    for _, key in ipairs(byteorder.keys(keyed)) do
        table.insert(out, keyed[key])
    end
    return out
end

local function write_band_files()
    local in16 = load_cache_set("16.0")
    local buckets, bucket_order = {}, {}
    for _, e in ipairs(order) do
        if e.cat == "FRAMEWORK" then
            local ob = e.band
            if e.band == "13+" then
                ob = in16[full_symbol(e.kind, e.name)] and "13-16" or "17-18"
            end
            if buckets[ob] == nil then
                buckets[ob] = {}
                table.insert(bucket_order, ob)
            end
            table.insert(buckets[ob], e)
        end
    end
    for _, ob in ipairs(bucket_order) do
        local rows = ranked(buckets[ob], function (row)
            if is_gap(row.status) then return 0 end
            if row.status == "n/a-A5" then return 2 end
            return 1
        end)
        local file = assert(io.open(path.join(CORPUS, "band-" .. ob .. ".tsv"), "w"))
        file:write("strong\tapps\tblocker\tcarried\tframework\tkind\tname\tapplist\n")
        for _, row in ipairs(rows) do
            local blocker = aggregate.launch_blocks(row.nstrong, row.status, row.kind, row.name, built) and "LAUNCH-BLOCK" or ""
            file:write(string.format("%d\t%d\t%s\t%s\t%s\t%s\t%s\t%s\n", row.nstrong, row.napps, blocker, row.status,
                row.framework, row.kind, row.name, table.concat(byteorder.keys(row.apps), ",")))
        end
        file:close()
    end
end

local function top_rows(bands, n)
    local rows = {}
    for _, e in ipairs(order) do
        if e.cat == "FRAMEWORK" and bands[e.band] and is_gap(e.status) then
            table.insert(rows, e)
        end
    end
    local keyed = {}
    for _, row in ipairs(rows) do
        local key = string.format("%09d\1%09d\1%s\1%s\1%s\1%09d", 999999999 - row.nstrong, 999999999 - row.napps,
            row.band, row.framework, row.name, row.order)
        keyed[key] = row
    end
    local out = {}
    for _, key in ipairs(byteorder.keys(keyed)) do
        if #out == n then break end
        table.insert(out, keyed[key])
    end
    return out
end

function main()
    write_band_files()
    local g7, c7, n7 = band_tally("FRAMEWORK")
    local R = path.join(CORPUS, "corpus-report.md")
    local lines = {}
    local function w(text)
        table.insert(lines, text)
    end
    
    local function sum(t, bands)
        local total = 0
        for _, b in ipairs(bands) do
            total = total + (t[b] or 0)
        end
        return total
    end
    
    local BANDS_7_12 = {"7", "8-10", "11-12"}
    local BAND_SET_7_12 = {["7"] = true, ["8-10"] = true, ["11-12"] = true}
    
    w("# App-corpus priority report v3 " .. EM .. " " .. #apps .. " OSS apps, demand vs stock iOS 6.0\n\n")
    w(string.format("**Corpus (%d apps, self-built OSS release IPAs, arm64, cryptid 0):** %s.\n\n", #apps, table.concat(apps, ", ")))
    w("**Method:** name-based (arch-independent). demand = {symbols imported across every Mach-O in the bundle, `nm -m`} "
        .. MINUS .. " {stock iOS 6.0 exports} " .. MINUS .. " {symbols the app's own bundle defines/exports}. The last term drops "
        .. "intra-app and bundled-3rd-party symbols even when a name collides with an Apple *private* class (e.g. Session bundles "
        .. "WebRTC.framework, so its RTC* are not counted as system). Each survivor is attributed to home framework + introduction band "
        .. "via a dyld cache ladder 6.0" .. ARROW .. "7.0.1" .. ARROW .. "10.3.4" .. ARROW .. "12.0" .. ARROW .. "18.0 (canonical `dyld.load()`); "
        .. "the 18.0 tier catches iOS13+ system demand (\"13+\", beyond current backports) so residual is now ~0. weak/strong from "
        .. "`nm -m`; carried-status from Backports 7-10's registry export.\n\n")
    w("**Scope:** classes + constants (link-time symbols). Methods/properties are runtime-dispatched (invisible to nm) " .. "\u{2192}"
        .. " covered by the recompiler's `sel` rows. Metal marked `n/a-A5` (A5 devices never ran Metal; `MTLCreateSystemDefaultDevice()` "
        .. "returns nil). SYSCALL/RUNTIME route to the recompiler.\n\n")
    w("## Actionable backport demand (bands 7" .. EN .. "12) " .. EM .. " distinct FRAMEWORK class+constant\n\n")
    w("| band | route | GAP | carried | n/a-A5 |\n| --- | --- | --- | --- | --- |\n")
    for _, b in ipairs(BANDS_7_12) do
        w(string.format("| %s | %s | %d | %d | %d |\n", b, aggregate.band_route(b), g7[b] or 0, c7[b] or 0, n7[b] or 0))
    end
    w(string.format("| **7" .. EN .. "12 total** | | **%d** | **%d** | **%d** |\n", sum(g7, BANDS_7_12), sum(c7, BANDS_7_12), sum(n7, BANDS_7_12)))
    local lb = {}
    for _, e in ipairs(order) do
        if e.cat == "FRAMEWORK" and BAND_SET_7_12[e.band] then
            if aggregate.launch_blocks(e.nstrong, e.status, e.kind, e.name, built) then
                lb[e.band] = (lb[e.band] or 0) + 1
            end
        end
    end
    w(string.format("\n**LAUNCH-BLOCKERS (strong/hard-linked imports the 6.1.3 band of canon %s does not export, bands 7" .. EN
        .. "12):** %d, beside %d gaps; a carried row the band does not export (an `ignored` decision with no symbol) counts too " .. EM
        .. " a missing hard-linked symbol aborts dyld before main, so the app never starts (proven: iSH won't launch without "
        .. "NSUserActivity). These are the load-gating set: apps stay dead until they exist (or the recompiler weak-binds them). The rest "
        .. "are `#available`-guarded and degrade to nil.\n", built_canon, sum(lb, BANDS_7_12), sum(g7, BANDS_7_12)))
    w(string.format("\n**Frontier (band 13+, beyond current backports):** %d distinct system class+constant demands introduced iOS 13" .. EN
        .. "18 " .. EM .. " real for the \"all apps\" goal but out of current 7" .. EN .. "12 scope.\n\n", g7["13+"] or 0))
    w("## Top gaps, bands 7" .. EN .. "12, most-apps-first\n")
    w("`LB` = LAUNCH-BLOCKER: a strong (hard-linked) gap " .. EM .. " if absent, dyld aborts before main and the app never starts "
        .. "(proven on iPad2: iSH won't launch without NSUserActivity). All-weak gaps (blank) degrade to nil gracefully. The recompiler is "
        .. "separately weak-binding uncovered classrefs so the long tail degrades instead of hard-failing.\n\n```\n")
    w(string.format("%-2s %3s %3s  %-11s %-6s %-22s %-6s name\n", "LB", "str", "app", "carried", "band", "framework", "kind"))
    for _, e in ipairs(top_rows(BAND_SET_7_12, 40)) do
        local flag = e.nstrong >= 1 and "LB" or "  "
        w(string.format("%-2s %3d %3d  %-11s %-6s %-22s %-6s %s\n", flag, e.nstrong, e.napps, e.status, e.band, e.framework,
            e.kind, e.name))
    end
    w("```\n\n## Cross-check vs the recompiler (class agreement)\n\n")
    w("| app | corpus classes | recompiler classes | agree |\n| --- | --- | --- | --- |\n")
    for _, app in ipairs(apps) do
        local mine = {}
        for _, r in ipairs(store.apps[app].demand) do
            if r.kind == "class" then mine[r.name] = true end
        end
        local k = kata[app] or {}
        local k_count = count(k)
        local both = 0
        for name in pairs(mine) do
            if k[name] then both = both + 1 end
        end
        w(string.format("| %s | %d | %s | %s |\n", app, count(mine), k_count > 0 and tostring(k_count) or "-",
            k_count > 0 and tostring(both) or "-"))
    end
    
    local file = assert(io.open(R, "w"))
    file:write(table.concat(lines))
    file:close()
    print("wrote " .. R)
    print(string.format("bands 7-12 gaps: %d  13+ frontier: %d", sum(g7, BANDS_7_12), g7["13+"] or 0))
end
