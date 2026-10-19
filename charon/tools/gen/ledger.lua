local TAB = "\t"
local NO_VALUE = "-"

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

local SWIFT_EXPORTS = {"^_?swift_", "^_?%$[sS]", "^_?__swift", "^_Tt"}

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

function cache_of(tree, release)
    local dyld = import("apple.dyld", {rootdir = path.join(tree, "modules"), anonymous = true})
    return dyld.held_source(path.join(dyld.root(), release), "armv7")
end

local function reader(tree, script, file, arch)
    local args = {"l", path.join(tree, "tools", "corpus", script), file}
    if arch then
        table.insert(args, arch)
    end
    return os.iorunv("xmake", args, {envs = {CHARON_ROOT = tree}})
end

function read_release(tree, release)
    local cache = cache_of(tree, release)
    assert(cache, "the release " .. release .. " holds no armv7 dyld shared cache: nothing to read it against")
    local objc_text, export_text = reader(tree, "objc-inventory.lua", cache), reader(tree, "dump-cache.lua", cache)
    local images_text = reader(tree, "cache-images.lua", cache)
    return parse_facts(objc_text, export_text, images_text), cache, objc_text, export_text
end

local function nm_exports(binary)
    local out = {}
    for line in string.gmatch(os.iorunv("nm", {"-gU", binary}), "[^\n]+") do
        table.insert(out, string.match(line, "(%S+)$") .. "\t" .. binary)
    end
    return table.concat(out, "\n")
end

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

function read_built(tree, gate)
    local libs = os.files(path.join(gate, "lib*Backports.dylib"))
    assert(#libs > 0, "the gate folder " .. gate .. " holds no lib*Backports.dylib: run the gate first (its output is the built libraries)")
    local facts = {classes = {}, protocols = {}, exports = {}}
    for _, lib in ipairs(libs) do
        merge(facts, parse_facts(reader(tree, "objc-inventory.lua", lib, "armv7"), nm_exports(lib)))
    end
    return facts, #libs
end

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

local function enum_member(record)
    return record.usr ~= nil and string.match(record.usr, "^c:@E[^@]*@[^@]+@") ~= nil
end

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

local function cache_state(record, facts, extern)
    local verdict, reason = check(record, facts, extern)
    if verdict == "present" then
        return "implemented", "none", reason
    elseif verdict == "absent" then
        return "missing", "code", reason
    end
    return nil
end

function state_of(record, facts, extern, header)
    if record.lang == "swift" then
        if string.sub(record.usr or "", 1, 2) == "c:" then
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

function rows_of(records, facts, exported, header_of, twins)
    local seen, unique = {}, {}
    for _, record in ipairs(records) do
        local key = row_key(record)
        if not seen[key] then
            seen[key] = true
            table.insert(unique, record)
        end
    end
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

function twins_of(rows)
    local twins = {}
    for _, row in ipairs(rows) do
        if row.lang == "objc" and row.usr ~= nil and row.usr ~= "" and twins[row.usr] == nil then
            twins[row.usr] = row
        end
    end
    return twins
end

function row_key(record)
    return record.kind .. "\t" .. record.lang .. "\t" .. record.api
end

function rows_text(list)
    local lines = {"kind\tlang\tapi\tintroduced\theader-introduced\tstatus\tneeds\treason"}
    for _, row in ipairs(list) do
        table.insert(lines, table.concat({row.kind, row.lang, row.api, row.introduced, row.header_introduced, row.status, row.needs,
                                          row.reason}, TAB))
    end
    return table.concat(lines, "\n") .. "\n"
end
