import("core.base.json")
import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})
local text = import("objc_text", {rootdir = os.scriptdir()})
local aggregate = import("aggregate", {rootdir = os.scriptdir(), anonymous = true})

local EXPORT = aggregate.registry_export()
local CORPUS = aggregate.corpus_dir()
local CHARON = path.directory(path.directory(os.scriptdir()))

local TREE = nil
for _, candidate in ipairs({os.getenv("CHARON_TREE_DIR") or false,
                            path.join(CHARON, "packages", "a", "apple-backports")}) do
    if candidate and os.isdir(candidate) then
        TREE = candidate
        break
    end
end
if not TREE then
    raise("verify.lua: no tree directory found. Set CHARON_TREE_DIR to the current worktree's "
        .. "packages/a/apple-backports -- without it every check reports false positives.")
end

local function walk(dir, prune, out)
    for _, file in ipairs(os.files(path.join(dir, "*"))) do
        table.insert(out, file)
    end
    for _, sub in ipairs(os.dirs(path.join(dir, "*"))) do
        if not prune[path.filename(sub)] then
            walk(sub, prune, out)
        end
    end
    return out
end

local sources = {}
for _, file in ipairs(walk(TREE, {}, {})) do
    local extension = file:match("%.([^./]+)$")
    if extension == "m" or extension == "mm" or extension == "h" then
        table.insert(sources, file)
    end
end
byteorder.sort(sources)
local parts = {}
for _, file in ipairs(sources) do
    table.insert(parts, io.readfile(file))
end
local BLOB = table.concat(parts)
local IMPLS = text.implementations(BLOB)

local reg, reg_kinds = {}, {}
do
    local lines = io.lines(EXPORT)
    local header = lines() or ""
    local kind_column = nil
    local columns = {}
    for field in (header .. "\t"):gmatch("([^\t]*)\t") do
        table.insert(columns, field)
    end
    for index, field in ipairs(columns) do
        if field == "kind" then kind_column = index end
    end
    for line in lines do
        local p = {}
        for field in (line .. "\t"):gmatch("([^\t]*)\t") do
            table.insert(p, field)
        end
        if #p >= 3 and p[1] ~= "framework" then
            reg[p[2]] = p[3]
            if kind_column and #p >= kind_column and p[kind_column] ~= "" then
                reg_kinds[p[2]] = p[kind_column]
            end
        end
    end
end

local pkg_reg = {}
local SWIFT = {}
do
    local found = walk(TREE, {[".git"] = true, build = true, lib = true}, {})
    byteorder.sort(found)
    for _, file in ipairs(found) do
        local extension = file:match("%.([^./]+)$")
        if extension == "json" and path.filename(path.directory(file)) == "registry" then
            local held = json.decode(io.readfile(file))
            if held == nil then
                raise("verify.lua: %s is not readable JSON", file)
            end
            for _, entry in ipairs(type(held) == "table" and held.entries or {}) do
                local api, status = entry.api, entry.status
                if api and status then
                    if pkg_reg[api] == nil then pkg_reg[api] = status end
                    if entry.kind and reg_kinds[api] == nil then reg_kinds[api] = entry.kind end
                end
            end
        elseif extension == "swift" and file:find(path.sep() .. "files" .. path.sep(), 1, true) then
            table.insert(SWIFT, io.readfile(file))
        end
    end
end
local SWIFT_TEXT = table.concat(SWIFT, "\n") .. (#SWIFT > 0 and "\n" or "")

local PROTOCOLS = {}
for api, kind in pairs(reg_kinds) do
    if kind == "protocol" then PROTOCOLS[api] = true end
end

local ADOPTERS = {}
do
    local store_path = path.join(CORPUS, "store.json")
    if os.getenv("CHARON_TOOLS_DIR") and os.isfile(path.join(os.getenv("CHARON_TOOLS_DIR"), "store.json")) then
        store_path = path.join(os.getenv("CHARON_TOOLS_DIR"), "store.json")
    end
    if not os.isfile(store_path) then
        io.stderr:write(string.format("verify.lua: WARNING no store.json found (looked in %s) -- PROTOCOLS/ADOPTERS stay "
            .. "empty, every protocol-member row falls back to the flat tree scan. Set CHARON_TOOLS_DIR.\n", store_path))
    else
        local held = json.decode(io.readfile(store_path))
        if held == nil then
            raise("verify.lua: %s is not readable JSON", store_path)
        end
        local imported = {}
        for _, app in pairs(held.apps) do
            for _, r in ipairs(app.demand) do
                if r.kind == "class" then imported[r.name] = true end
            end
        end
        for protocol in pairs(PROTOCOLS) do
            ADOPTERS[protocol] = imported
        end
    end
end

local function strip_owners(api)
    return (api:gsub(" %(%+%d+ owners%)$", ""))
end

local function status(api)
    local a = strip_owners(api)
    local candidates = {a, a .. "()", (a:gsub("^_+", "")), (a:gsub("^_+", "")) .. "()",
                        (a:gsub("_OBJC_CLASS_%$_", ""))}
    if a:find(".", 1, true) and a:sub(1, 1) ~= "-" and a:sub(1, 1) ~= "+" and a:sub(1, 1) ~= "_" then
        local dot = a:find(".", 1, true)
        local owner, name = a:sub(1, dot - 1), a:sub(dot + 1)
        local up = name:sub(1, 1):upper() .. name:sub(2)
        for _, key in ipairs({"-[" .. owner .. " " .. name .. "]", "-[" .. owner .. " set" .. up .. ":]",
                              "-[" .. owner .. " is" .. up .. "]", "+[" .. owner .. " " .. name .. "]",
                              "+[" .. owner .. " set" .. up .. ":]"}) do
            table.insert(candidates, key)
        end
    end
    for _, key in ipairs(candidates) do
        if reg[key] ~= nil then return reg[key] end
    end
    for _, key in ipairs(candidates) do
        if pkg_reg[key] ~= nil then return pkg_reg[key] end
    end
    return "no row"
end

local function body_of(class)
    return table.concat(IMPLS[class] or {}, "\n")
end

local function in_tree(api, kind, owner)
    local a = strip_owners(api)
    if a:sub(1, 14) == "_OBJC_CLASS_$_" or kind == "class" then
        local class = a:gsub("_OBJC_CLASS_%$_", "")
        return IMPLS[class] ~= nil or BLOB:find("@interface " .. class, 1, true) ~= nil
    end
    local own, sel
    local method_owner, method_sel = a:match("^[+-]%[([%w_]+) ([%w_:]+)%]$")
    local dot = a:find(".", 1, true)
    if method_owner then
        own, sel = method_owner, method_sel
    elseif dot and a:sub(1, 1) ~= "_" then
        own, sel = a:sub(1, dot - 1), a:sub(dot + 1)
    else
        sel = (a:gsub("^_+", ""))
    end
    if owner and owner ~= "" then own = owner end
    if own ~= nil and SWIFT_TEXT ~= "" then
        local first = sel:match("^[^:]*")
        if first ~= "" and text.whole_word(SWIFT_TEXT, first) then
            return true
        end
    end
    local scope
    if own ~= nil then
        if IMPLS[own] == nil and PROTOCOLS[own] then
            local candidates = {}
            for class in pairs(IMPLS) do
                if ADOPTERS[own] and ADOPTERS[own][class] then
                    table.insert(candidates, class)
                end
            end
            byteorder.sort(candidates)
            local bodies = {}
            for _, class in ipairs(candidates) do
                table.insert(bodies, body_of(class))
            end
            scope = table.concat(bodies, "\n")
        elseif IMPLS[own] == nil then
            return false
        else
            scope = body_of(own)
        end
    else
        scope = BLOB
    end
    if sel:find(":", 1, true) then
        local keywords = {}
        for keyword in sel:gmatch("[^:]+") do
            table.insert(keywords, keyword)
        end
        return #keywords > 0 and text.declares_selector(scope, keywords)
    end
    local up = sel:sub(1, 1):upper() .. sel:sub(2)
    if text.declares(scope, sel) then return true end
    if text.declares_keyword(scope, "set" .. up) then return true end
    if text.directive_names(scope, "@dynamic", sel) then return false end
    if text.directive_names(scope, "@synthesize", sel) then return true end
    if own == nil and text.c_declares(BLOB, sel) then return true end
    return false
end

function check(name, rows)
    local real, carried, intree = {}, {}, {}
    for _, row in ipairs(rows) do
        local api, kind, extra = row[1], row[2], row[3]
        local st = status(api)
        if st == "implemented" or st == "inert" then
            table.insert(carried, {api, st, extra})
        elseif st == "absent" or st == "ignored" then
            table.insert(real, {api, st, extra})
        elseif in_tree(api, kind) then
            table.insert(intree, {api, st, extra})
        else
            table.insert(real, {api, st, extra})
        end
    end
    print(string.format("\n### %s: claimed %d -> REAL %d", name, #rows, #real))
    if #carried > 0 then
        print(string.format("   FALSE, the registry carries it (%d):", #carried))
        for _, r in ipairs(carried) do
            print(string.format("      %-12s %s", r[2], r[1]))
        end
    end
    if #intree > 0 then
        print(string.format("   FALSE, it is in the tree (%d):", #intree))
        for _, r in ipairs(intree) do
            print(string.format("      %-12s %s", r[2], r[1]))
        end
    end
    return real
end

function main(name, file)
    assert(name and file, "usage: verify.lua <name> <rows.tsv>   (api, kind, extra per line, tab-separated)")
    local rows = {}
    for line in io.lines(file) do
        local api, kind, extra = line:match("^([^\t]*)\t?([^\t]*)\t?(.*)$")
        if api ~= "" then
            table.insert(rows, {api, kind, extra})
        end
    end
    check(name, rows)
end
