-- The 6.1.3 ledger's cache pass: what the release's own dyld shared cache says about each declaration of the model, and the absence
-- rule over it. The cache is read by name: the release (6.1.3) resolves through modules/apple/dyld.lua (held_source under root), and
-- the two charon readers run on the resolved file: tools/corpus/objc-inventory.lua (ObjC classes, protocols and their selectors) and
-- tools/corpus/dump-cache.lua (every exported symbol). Nothing under ~/.charon/dyld is opened here by hand.
--
-- A declaration is checkable when the cache can show it: an ObjC class or protocol, a method or property (its selector on its class),
-- a constant or a function (its linker symbol). An enum member has no symbol of its own, so it is not checkable, and neither is a type
-- (enum, struct, typealias) or a Swift declaration: the header pass and the Swift pass decide those.
--
-- The absence rule: a framework none of whose own declarations is in the cache is absent from the release, with the evidence of absence
-- being either an ObjC runtime name the cache lacks, or a C function or constant the cache lacks while a .tbd of the 26.2 SDK
-- exports it (any .tbd of the SDK, libraries included). A C declaration no SDK .tbd exports proves nothing: a static inline function has no symbol, so an iOS 6 header-only
-- framework would read as absent. A declaration the cache has is evidence of presence.

local TAB = "\t"
local NO_VALUE = "-"

-- The fields of a tab-separated line, empty ones included.
function split(line, sep)
    local out, from = {}, 1
    while true do
        local at = string.find(line, sep, from, true)
        if at == nil then
            table.insert(out, string.sub(line, from))
            return out
        end
        table.insert(out, string.sub(line, from, at - 1))
        from = at + #sep
    end
end

-- A set of the selectors a reader prints, comma-joined (an empty field is the empty set). objc-inventory writes each selector with a sign in
-- front ("-setFrame:"), which is not part of its name: the field's position says whether it is an instance or a class selector.
local function names_set(field)
    local set = {}
    if field == nil or field == "" then
        return set
    end
    for name in string.gmatch(field, "[^,]+") do
        set[(string.gsub(name, "^[-+]", ""))] = true
    end
    return set
end

-- The release's runtime names: classes and protocols with their instance and class selectors (objc-inventory.lua's lines), and the
-- exported symbols (dump-cache.lua's lines, "<symbol>\t<install name>", the symbol with its leading underscore). Returns a table
-- {classes = name -> {inst, cls}, protocols = name -> {inst, cls}, exports = symbol -> true}.
-- The export names of the Swift runtime and of Swift-compiled code: the Swift runtime's entry points, the mangled names of Swift 4 and later
-- ($s, $S), the Swift 1 to 3 names (__swift, _Tt for a Swift class). A C name in the cache matches none of them.
local SWIFT_EXPORTS = {"^_?swift_", "^_?%$[sS]", "^_?__swift", "^_Tt"}

-- The proof that a cache holds no Swift at all, read from its image list (cache-images.lua: install name and export count per image) and
-- its export names (dump-cache.lua). Every Swift declaration is then missing from the release: the cache has no image named libswift* and
-- no export a Swift compiler wrote, so no framework of the release has a Swift module. Returns the counts and the reason text the rows give.
local function swift_proof(images_text, export_names)
    local images, swift_images = 0, 0
    for line in string.gmatch(images_text, "[^\n]+") do
        local install = split(line, TAB)[1]
        images = images + 1
        if string.find(string.lower(path.filename(install)), "^libswift", 1) then
            swift_images = swift_images + 1
        end
    end
    local exports, swift_exports = 0, 0
    for _, symbol in ipairs(export_names) do
        exports = exports + 1
        for _, pattern in ipairs(SWIFT_EXPORTS) do
            if string.find(symbol, pattern) then
                swift_exports = swift_exports + 1
                break
            end
        end
    end
    local holds = swift_images == 0 and swift_exports == 0
    return {images = images, swift_images = swift_images, exports = exports, swift_exports = swift_exports, holds = holds,
            text = string.format("the 6.1.3 cache holds no Swift runtime: %d of %d images named libswift*, %d of %d exports Swift-compiled or a Swift runtime entry point",
                                 swift_images, images, swift_exports, exports)}
end

function parse_facts(objc_text, export_text, images_text)
    local facts = {classes = {}, protocols = {}, exports = {}, swift = nil}
    for line in string.gmatch(objc_text or "", "[^\n]+") do
        local f = split(line, TAB)
        local entry = {inst = names_set(f[5]), cls = names_set(f[6])}
        if f[1] == "class" then
            facts.classes[f[2]] = entry
        elseif f[1] == "protocol" then
            facts.protocols[f[2]] = entry
        end
    end
    local export_names = {}
    for line in string.gmatch(export_text or "", "[^\n]+") do
        local symbol = split(line, TAB)[1]
        if symbol ~= nil and symbol ~= "" then
            facts.exports[symbol] = true
            table.insert(export_names, symbol)
        end
    end
    if images_text ~= nil then
        facts.swift = swift_proof(images_text, export_names)
    end
    return facts
end

-- The release folder's cache file, resolved from the release name (dyld.held_source under dyld.root()). nil when the release holds no
-- armv7 cache.
function cache_of(tree, release)
    local dyld = import("apple.dyld", {rootdir = path.join(tree, "modules"), anonymous = true})
    return dyld.held_source(path.join(dyld.root(), release), "armv7")
end

-- Runs one charon reader over a file and returns its stdout: the cache, or with arch one built binary of that architecture. The reader is
-- an xmake script, run with the tree's own charon root.
local function reader(tree, script, file, arch)
    local args = {"l", path.join(tree, "tools", "corpus", script), file}
    if arch then
        table.insert(args, arch)
    end
    return os.iorunv("xmake", args, {envs = {CHARON_ROOT = tree}})
end

-- The release's facts, read through the two readers. Returns the facts, the cache file and the readers' raw text (for the dump).
function read_release(tree, release)
    local cache = cache_of(tree, release)
    assert(cache, "the release " .. release .. " holds no armv7 dyld shared cache: nothing to read it against")
    local objc_text, export_text = reader(tree, "objc-inventory.lua", cache), reader(tree, "dump-cache.lua", cache)
    local images_text = reader(tree, "cache-images.lua", cache)
    return parse_facts(objc_text, export_text, images_text), cache, objc_text, export_text
end

-- The symbols a binary exports, in dump-cache's line shape: nm -gU's last field, the symbol with its underscore.
local function nm_exports(binary)
    local out = {}
    for line in string.gmatch(os.iorunv("nm", {"-gU", binary}), "[^\n]+") do
        table.insert(out, string.match(line, "(%S+)$") .. "\t" .. binary)
    end
    return table.concat(out, "\n")
end

-- Adds the names of one entry (a class or a protocol) to the entry of facts of the same name: a name either carries is implemented.
local function union_entry(into, entry)
    if into == nil then
        return entry
    end
    for name in pairs(entry.inst) do
        into.inst[name] = true
    end
    for name in pairs(entry.cls) do
        into.cls[name] = true
    end
    return into
end

-- Adds the facts of other to facts, in place, and returns facts.
function merge(facts, other)
    for name, entry in pairs(other.classes) do
        facts.classes[name] = union_entry(facts.classes[name], entry)
    end
    for name, entry in pairs(other.protocols) do
        facts.protocols[name] = union_entry(facts.protocols[name], entry)
    end
    for symbol in pairs(other.exports) do
        facts.exports[symbol] = true
    end
    return facts
end

-- The names the release's built libraries carry: each lib*Backports.dylib of the gate's output folder, read as its armv7 binary through
-- the ObjC reader and through nm -gU. Returns the facts (parse_facts' shape) and the number of libraries read.
function read_built(tree, gate)
    local libs = os.files(path.join(gate, "lib*Backports.dylib"))
    assert(#libs > 0, "the gate folder " .. gate .. " holds no lib*Backports.dylib: run the gate first (its output is the built libraries)")
    local facts = {classes = {}, protocols = {}, exports = {}}
    for _, lib in ipairs(libs) do
        merge(facts, parse_facts(reader(tree, "objc-inventory.lua", lib, "armv7"), nm_exports(lib)))
    end
    return facts, #libs
end

-- The owner, selector and side of a method or property record: a method "-[Owner sel:]" is owner and sel: (class side when the sign is +),
-- and a property "Owner.name" is owner and its getter (or its name), either side. nil for an api the pattern does not read.
local function member_of(record)
    local sign, owner, sel = string.match(record.api, "^([-+])%[([%w_]+) (.+)%]$")
    if owner then
        return owner, sel, sign == "+"
    end
    owner, sel = string.match(record.api, "^([%w_]+)%.([%w_]+)$")
    if owner then
        local getter = record.getter
        if getter and getter ~= NO_VALUE and getter ~= "" then
            sel = getter
        end
        return owner, sel, nil
    end
    return nil
end

-- An enum member (c:@E<enum>@<member>): a constant of the enum, with no linker symbol of its own, so the cache cannot show it.
local function enum_member(record)
    return record.usr ~= nil and string.match(record.usr, "^c:@E[^@]*@[^@]+@") ~= nil
end

-- Whether the cache shows one declaration: "present" or "absent" with its reason, or nil when the cache cannot decide it. extern is the set
-- of symbols the SDK's .tbd files export (every one, libraries included; nil or empty when there is none): it decides a C declaration the
-- cache lacks.
function check(record, facts, extern)
    local kind, lang, api = record.kind, record.lang, record.api
    if lang ~= "objc" or enum_member(record) then
        return nil
    end
    if kind == "class" or kind == "protocol" then
        if facts.classes[api] or facts.protocols[api] then
            return "present", "a " .. kind .. " " .. api .. " in the 6.1.3 cache"
        end
        return "absent", "no class or protocol " .. api .. " in the 6.1.3 cache"
    elseif kind == "method" or kind == "property" then
        local owner, sel, class_side = member_of(record)
        if owner == nil then
            return nil
        end
        local entry = facts.classes[owner] or facts.protocols[owner]
        if entry == nil then
            return "absent", "no class or protocol " .. owner .. " in the 6.1.3 cache, for " .. api
        end
        local present
        if class_side == nil then
            present = entry.inst[sel] or entry.cls[sel]
        elseif class_side then
            present = entry.cls[sel]
        else
            present = entry.inst[sel]
        end
        if present then
            return "present", "selector " .. sel .. " of " .. owner .. " in the 6.1.3 cache"
        end
        return "absent", "no selector " .. sel .. " on " .. owner .. " in the 6.1.3 cache"
    elseif kind == "constant" or kind == "function" then
        local name = string.gsub(api, "%(%)$", "")
        if facts.exports["_" .. name] then
            return "present", "the symbol " .. name .. " is exported by the 6.1.3 cache"
        end
        if extern and extern[name] then
            return "absent", "no symbol " .. name .. " in the 6.1.3 cache, and the SDK's .tbd exports it"
        end
        return nil
    end
    return nil
end

-- The absence rule over the declarations of each framework: decls = framework -> its records (surface_model.declarations), each claimed by
-- a framework through claimed_by. exported(unit) returns the symbol set of the SDK's .tbd files (tbd.lua all_symbols; the unit is
-- not a test), and is asked only for a C declaration. Returns framework -> {verdict, checkable, present, reason}, verdict one of:
--   "present"    a declaration the framework owns is in the 6.1.3 cache (present counts them);
--   "absent"     none of its checkable declarations is in the cache, and it has at least one (checkable counts them): the framework is not in
--                the release, so every row is work;
--   "undecided"  the cache cannot say: its declarations are types, enum members, Swift, or C declarations no SDK .tbd exports.
-- A declaration counts for the framework that owns it (claimed_by), whichever framework's shard holds it. A nested shard
-- (MetalPerformanceShaders/MPSCore) is a unit of its own, named by its folder, as the trace and the input read it: its declarations
-- claimed by its outer framework count for it too, and its .tbd is its own.
function verdicts(decls, facts, exported)
    local extern_memo = {}
    local function extern_of(record)
        local unit = record.unit or record.claimed_by
        if extern_memo[unit] == nil then
            extern_memo[unit] = exported and exported(unit) or {}
        end
        return extern_memo[unit]
    end
    local tally = {}
    local function count(key, status, reason)
        tally[key] = tally[key] or {checkable = 0, present = 0, first_absent = nil}
        local t = tally[key]
        if status == "present" then
            t.checkable, t.present = t.checkable + 1, t.present + 1
        elseif status == "absent" then
            t.checkable = t.checkable + 1
            t.first_absent = t.first_absent or reason
        end
    end
    for fw in pairs(decls) do
        tally[fw] = {checkable = 0, present = 0, first_absent = nil}
    end
    for _, list in pairs(decls) do
        for _, record in ipairs(list) do
            if record.claimed_by and tally[record.claimed_by] then
                local status, reason = check(record, facts, extern_of(record))
                count(record.claimed_by, status, reason)
                if record.unit and record.unit ~= record.claimed_by and string.match(record.unit, "^([^/]+)") == record.claimed_by then
                    count(record.unit, status, reason)
                end
            end
        end
    end
    local out = {}
    for fw, t in pairs(tally) do
        local verdict, reason
        if t.present > 0 then
            verdict, reason = "present", t.present .. " own declarations are in the 6.1.3 cache"
        elseif t.first_absent ~= nil then
            verdict = "absent"
            reason = "none of its " .. t.checkable .. " checkable own declarations is in the 6.1.3 cache; e.g. " .. t.first_absent
        else
            verdict = "undecided"
            reason = "no own declaration the cache can decide: its declarations are types, Swift, or C declarations that no SDK .tbd of "
                     .. "its framework exports"
        end
        out[fw] = {verdict = verdict, checkable = t.checkable, present = t.present, reason = reason}
    end
    return out
end

-- The state the cache and the built libraries give one declaration: implemented (one of them carries it), missing (the cache says the
-- release lacks it, by its runtime names or a C symbol the SDK exports), or nil when they cannot show it.
local function cache_state(record, facts, extern)
    local verdict, reason = check(record, facts, extern)
    if verdict == "present" then
        return "implemented", "none", reason
    elseif verdict == "absent" then
        return "missing", "code", reason
    end
    return nil
end

-- The state of one declaration in the ledger: implemented, missing, or undecided with what decides it. The cache and the libraries first;
-- then, for an Objective-C declaration they cannot show, the lifted-header answer header (header_pass.lua's answer_of, or nil when the
-- headers did not name it); a Swift declaration the Swift pass decides. Returns the status, what it needs, the reason, and the iOS version
-- the headers introduce it in (nil when they give none).
function state_of(record, facts, extern, header)
    -- A Swift record is not looked up by name in the cache: a Swift name that matches an ObjC or C name there is another declaration.
    -- Its state is the Swift branch below: an import, the Swift proof, or undecided.
    if record.lang == "swift" then
        -- A Swift declaration exists in the release only as Swift code, so a cache with no Swift in it lacks every one (the proof is named
        -- in the row). The port's own build is not asked here: whether the port implements it is the gate's question, not the release's.
        if string.sub(record.usr or "", 1, 2) == "c:" then
            -- the usr says which declaration it imports; the model holds no row for a macro or a typedef (surface_model drops both), and
            -- no record of the import's ObjC or C twin was in the model for the rest
            local what
            if string.sub(record.usr, 1, 9) == "c:@macro@" then
                what = "a C macro: the model holds no row for macros"
            elseif string.sub(record.usr, 1, 4) == "c:@T" then
                what = "a typedef: the surface holds no typedef row"
            else
                what = "an ObjC or C declaration no row of the model holds (usr " .. record.usr .. ")"
            end
            return "undecided", "lift", "an import of " .. what .. ": the declaration's own row decides it, and there is none", nil
        end
        if facts.swift ~= nil and facts.swift.holds then
            return "missing", "code", "a Swift declaration of " .. record.framework .. ": " .. facts.swift.text, nil
        end
        return "undecided", "swift-module", "a Swift declaration the 6.1.3 cache cannot show, and no proof that the cache has no Swift", nil
    end
    local status, needs, reason = cache_state(record, facts, extern)
    if status then
        return status, needs, reason, nil
    end
    if header then
        return header.status, header.needs, header.reason, header.introduced
    end
    return "undecided", "lift", "a " .. record.kind .. " the cache and the built libraries cannot show, and the lifted headers do not name it",
           nil
end

-- The ledger rows of a unit's records (surface_model.declarations: the records whose unit is the unit, or of the nested units of an owner):
-- one row per kind, language and api, the first record of each (a usr shared by two declarations of one unit is one row). exported(unit)
-- gives the SDK's .tbd symbols as verdicts does. header_of(unit, records) gives the lifted-header answers of a unit's undecided Objective-C
-- records, key -> answer (nil: no lifted-header pass); it is asked once per unit, with all of that unit's undecided records. Sorted by kind,
-- then api. twins is the model's ObjC and C rows by usr (twins_of), which the Swift imports of records take their state from; nil when the
-- caller has none yet. Returns the rows as {kind, lang, api, introduced, header_introduced, status, needs, reason, usr}; usr is not written.
function rows_of(records, facts, exported, header_of, twins)
    local seen, unique = {}, {}
    for _, record in ipairs(records) do
        local key = row_key(record)
        if not seen[key] then
            seen[key] = true
            table.insert(unique, record)
        end
    end
    -- a unit's undecided records are all of its own (a shared key of two units is one row per file, but both units' records are asked)
    local pending, asked = {}, {}
    for _, record in ipairs(records) do
        local unit = record.unit or record.claimed_by
        local key = unit .. "\t" .. row_key(record)
        if record.lang == "objc" and not asked[key] and cache_state(record, facts, exported(unit)) == nil then
            asked[key] = true
            pending[unit] = pending[unit] or {}
            table.insert(pending[unit], record)
        end
    end
    local answers = {}
    if header_of then
        for unit, list in pairs(pending) do
            answers[unit] = header_of(unit, list)
        end
    end
    -- An import of an ObjC or C declaration (a Swift record whose usr is a clang usr) takes that declaration's row: twins is the model's
    -- ObjC and C rows by usr (rows_twins), so the declaration is decided once, in its own framework's row. An import with no twin in the
    -- model is undecided (state_of says so).
    local out = {}
    local imports = {}
    for _, record in ipairs(unique) do
        local twin = twins and record.usr and twins[record.usr]
        if record.lang == "swift" and string.sub(record.usr or "", 1, 2) == "c:" and twin then
            table.insert(imports, record)
        else
            local unit = record.unit or record.claimed_by
            local header = answers[unit] and answers[unit][row_key(record)]
            local status, needs, reason, introduced = state_of(record, facts, exported(unit), header)
            table.insert(out, {kind = record.kind, lang = record.lang, api = record.api, introduced = record.introduced or "",
                               header_introduced = introduced or "", status = status, needs = needs, reason = reason, usr = record.usr})
        end
    end
    for _, record in ipairs(imports) do
        local twin = twins[record.usr]
        table.insert(out, {kind = record.kind, lang = record.lang, api = record.api, introduced = record.introduced or "",
                           header_introduced = twin.header_introduced, status = twin.status, needs = twin.needs,
                           reason = "the import of " .. twin.kind .. " " .. twin.api .. ": " .. twin.reason, usr = record.usr})
    end
    table.sort(out, function(a, b)
        if a.kind ~= b.kind then
            return a.kind < b.kind
        end
        return a.api < b.api
    end)
    return out
end

-- The ObjC and C rows of the model by usr, from the rows of every unit (rows_of's output): the twins rows_of's imports take their state
-- from. A usr two rows share is the first one's.
function twins_of(rows)
    local twins = {}
    for _, row in ipairs(rows) do
        if row.lang == "objc" and row.usr ~= nil and row.usr ~= "" and twins[row.usr] == nil then
            twins[row.usr] = row
        end
    end
    return twins
end

-- The key a row is kept by in a unit: its kind, language and api (the header pass keys its answers the same way).
function row_key(record)
    return record.kind .. "\t" .. record.lang .. "\t" .. record.api
end

-- The ledger file's text for rows (rows_of's shape): the header of ledger-w45's columns, then one line per row. header-introduced is the
-- iOS version the lifted headers give the declaration, when they give one.
function rows_text(list)
    local lines = {"kind\tlang\tapi\tintroduced\theader-introduced\tstatus\tneeds\treason"}
    for _, row in ipairs(list) do
        table.insert(lines, table.concat({row.kind, row.lang, row.api, row.introduced, row.header_introduced, row.status, row.needs,
                                          row.reason}, TAB))
    end
    return table.concat(lines, "\n") .. "\n"
end
