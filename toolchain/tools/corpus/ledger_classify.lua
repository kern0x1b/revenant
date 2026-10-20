local HERE = os.scriptdir()
local byteorder = import("byteorder", {rootdir = path.join(HERE, "..", "..", "modules"), anonymous = true})
local surface_walk = import("surface_walk", {rootdir = HERE, anonymous = true})
local ledger_json = import("ledger_json", {rootdir = HERE, anonymous = true})

local TARGET = "armv7-apple-ios6.1.3"
local SWIFT_ONLY_PACKAGE = "packages/frameworks/apple-backports"
local DECIDED_STATUSES = {absent = true, inert = true, ignored = true}
local DIAGNOSTIC_LIMIT = 5
local RELEASE_NATIVE = "release-native: 6.1.3 dyld cache"

local PASSES = {["class\tobjc"] = "runtime", ["method\tobjc"] = "runtime", ["property\tobjc"] = "runtime",
                ["constant\tobjc"] = "symbol", ["function\tobjc"] = "symbol",
                ["enum\tobjc"] = "header", ["protocol\tobjc"] = "header", ["struct\tobjc"] = "header"}

function target()
    return TARGET
end

function has_any(map)
    for _ in pairs(map or {}) do
        return true
    end
    return false
end

function swift_only_package()
    return SWIFT_ONLY_PACKAGE
end

function is_decided(status)
    return status ~= nil and DECIDED_STATUSES[status] == true
end

function pass_of(kind, lang)
    return PASSES[kind .. "\t" .. lang]
end

local function truthy(value)
    return value ~= nil and value ~= false and value ~= ""
end

function repr(text)
    local quote = "'"
    if text:find("'", 1, true) and not text:find('"', 1, true) then
        quote = '"'
    end
    local out = {quote}
    for index = 1, #text do
        local char = text:sub(index, index)
        local byte = char:byte()
        if char == "\\" then
            table.insert(out, "\\\\")
        elseif char == quote then
            table.insert(out, "\\" .. quote)
        elseif char == "\n" then
            table.insert(out, "\\n")
        elseif char == "\r" then
            table.insert(out, "\\r")
        elseif char == "\t" then
            table.insert(out, "\\t")
        elseif byte < 32 or byte == 127 then
            table.insert(out, string.format("\\x%02x", byte))
        else
            table.insert(out, char)
        end
    end
    table.insert(out, quote)
    return table.concat(out)
end

function sorted_keys(set)
    local keys = {}
    for key in pairs(set) do
        table.insert(keys, key)
    end
    byteorder.sort(keys)
    return keys
end

function registry_keys_for(api)
    local keys, seen = {}, {}
    local function add(key)
        if not seen[key] then
            seen[key] = true
            table.insert(keys, key)
        end
    end
    add(api)
    add((api:gsub("%(%)", "")))
    local owner, prop = api:match("^([%w_]+)%.([%w_]+)$")
    if owner then
        add(string.format("-[%s %s]", owner, prop))
        add(string.format("-[%s set%s%s:]", owner, prop:sub(1, 1):upper(), prop:sub(2)))
        add(string.format("+[%s %s]", owner, prop))
    end
    return keys
end

function nearest_registry_keys(api, registries)
    local base = api:match("^[^(]*")
    local owner = api:match("^[^.]*")
    local near = {}
    for key in pairs(registries) do
        if key:match("^[^(]*") == base or key:match("^[^.]*") == owner then
            table.insert(near, key)
        end
    end
    byteorder.sort(near)
    local first = {}
    for index = 1, math.min(3, #near) do
        table.insert(first, near[index])
    end
    return first
end

function decide(row, registries, diagnostics)
    if row.lang ~= "objc" then
        return nil
    end
    local api = row.api
    for _, key in ipairs(registry_keys_for(api)) do
        local found = registries[key]
        if found and found[1] and DECIDED_STATUSES[found[1]] then
            local status, reason, package = found[1], found[2], found[3]
            return {"decided", string.format("%s in %s's registry: %s", status, package,
                                             truthy(reason) and reason or "no reason recorded"), nil, "none"}
        end
    end
    if #diagnostics < DIAGNOSTIC_LIMIT then
        table.insert(diagnostics, {api, nearest_registry_keys(api, registries)})
    end
    return nil
end

function built_why(entry, selector)
    local where = entry.where or {}
    return "built: " .. (selector and where[selector] or entry.library)
end

function classify_class(api, built_classes, built_protocols, release_classes, release_protocols)
    if built_classes[api] then
        return "implemented", "built: " .. built_classes[api].library
    end
    if release_classes[api] then
        return "implemented", "release-native: 6.1.3 dyld cache"
    end
    if built_protocols[api] then
        return "implemented", "built protocol: " .. built_protocols[api].library
    end
    if release_protocols[api] then
        return "implemented", "release-native: a protocol in the 6.1.3 dyld cache"
    end
    return "missing", string.format("no class or protocol %s in the built libraries or the 6.1.3 cache", api)
end

local function selector_present(entry, selector)
    return entry.instance[selector] or entry.class[selector]
end

function ancestors(owner, built_classes, release_classes, header)
    local chain, seen, current = {}, {[owner] = true}, owner
    while true do
        local built = built_classes[current]
        local entry = built or release_classes[current]
        if entry == nil then
            return chain, string.format(", and %s is in neither the built libraries nor the 6.1.3 cache, so the walk could not start", current)
        end
        local superclass = entry.superclass
        if not truthy(superclass) or seen[superclass] then
            return chain, ""
        end
        if built == nil and header ~= nil then
            local declared = header.supers[current]
            if declared and has_any(declared) and not declared[superclass] then
                return chain, string.format(", and the 6.1.3 cache's %s has superclass %s where %s's 26.2 header declares %s, so the class above it was not asked",
                                            current, superclass, header.framework, table.concat(sorted_keys(declared), " or "))
            end
        end
        seen[superclass] = true
        local entries = {}
        if built_classes[superclass] then
            table.insert(entries, {built_classes[superclass], true})
        end
        if release_classes[superclass] then
            table.insert(entries, {release_classes[superclass], false})
        end
        if #entries == 0 then
            return chain, string.format(", and the superclass %s above %s is in neither the built libraries nor the 6.1.3 cache, so nothing above it could answer",
                                        superclass, current)
        end
        table.insert(chain, {superclass, entries})
        current = superclass
    end
end

function held_note(unavailable, api, decided)
    if truthy(unavailable) then
        return ", and Apple's own header marks this row NS_UNAVAILABLE, so nothing answers it at run time and the class above it was not asked"
    end
    if decided and decided[api] then
        return ", and a registry has decided this row, so the class above it was not asked"
    end
    return ""
end

function parse_method(api)
    local sign, owner, selector = api:match("^([-+])%[([%w_]+)%([%w_]+%) (.+)%]$")
    if not sign then
        sign, owner, selector = api:match("^([-+])%[([%w_]+) (.+)%]$")
    end
    return sign, owner, selector
end

function classify_method(api, built_classes, release_classes, built_protocols, release_protocols, decided, unavailable, header)
    local sign, owner, selector = parse_method(api)
    if not sign then
        return "undecided", "method api does not parse as +/-[Class sel]: " .. repr(api)
    end
    built_protocols = built_protocols or {}
    release_protocols = release_protocols or {}
    local key = "-" .. selector
    local built = built_classes[owner]
    if built and selector_present(built, key) then
        return "implemented", built_why(built, key)
    end
    local released = release_classes[owner]
    if released and selector_present(released, key) then
        return "implemented", RELEASE_NATIVE
    end
    for _, pair in ipairs({{built_protocols, "built: "}, {release_protocols, RELEASE_NATIVE}}) do
        local entry = pair[1][owner]
        if entry and selector_present(entry, key) then
            local label = pair[2] .. (pair[2] == "built: " and (entry.library or "") or "")
            return "implemented", label .. string.format(" (the protocol %s declares it)", owner)
        end
    end
    if sign == "+" and selector == "new" and not (decided and decided[api]) and (built_classes[owner] or release_classes[owner]) then
        return "implemented", "+new is NSObject's and every class inherits it: the 6.1.3 cache's own NSObject declares it and 2 of its 11378 classes declare one of their own"
    end
    local held, stopped = held_note(unavailable, api, decided), ""
    if (built or released) and held == "" then
        local chain
        chain, stopped = ancestors(owner, built_classes, release_classes, header)
        for _, link in ipairs(chain) do
            for _, pair in ipairs(link[2]) do
                local entry, is_built = pair[1], pair[2]
                if selector_present(entry, key) then
                    local why = is_built and built_why(entry, key) or RELEASE_NATIVE
                    return "implemented", string.format("%s (inherited from %s)", why, link[1])
                end
            end
        end
    end
    if not built and not released and not built_protocols[owner] and not release_protocols[owner] then
        return "missing", string.format("owner %s is neither a class nor a protocol in the built libraries or the 6.1.3 cache", owner)
    end
    return "missing", string.format("%s is there, selector %s is not%s%s", owner, selector, held, stopped)
end

function classify_property(api, built_classes, release_classes, built_protocols, release_protocols, getter, setter, decided, unavailable, header)
    local owner, prop = api:match("^([%w_]+)%.([%w_]+)$")
    if not owner then
        return "undecided", "property api does not parse as Class.prop: " .. repr(api)
    end
    built_protocols = built_protocols or {}
    release_protocols = release_protocols or {}
    getter = truthy(getter) and ("-" .. getter) or ("-" .. prop)
    setter = truthy(setter) and ("-" .. setter) or ("-set" .. prop:sub(1, 1):upper() .. prop:sub(2) .. ":")
    local function carried_by(entry)
        for _, selector in ipairs({getter, setter}) do
            if entry.instance[selector] or entry.class[selector] then
                return selector
            end
        end
        return nil
    end
    local function class_note(entry)
        if entry.class[getter] and not entry.instance[getter] then
            return string.format(" (a class property: read through %s)", getter)
        end
        return ""
    end
    for _, pair in ipairs({{built_classes, nil}, {release_classes, RELEASE_NATIVE}}) do
        local entry = pair[1][owner]
        if entry then
            local carried = carried_by(entry)
            if carried then
                return "implemented", (pair[2] or built_why(entry, carried)) .. class_note(entry)
            end
        end
    end
    for _, pair in ipairs({{built_protocols, "built: "}, {release_protocols, RELEASE_NATIVE}}) do
        local entry = pair[1][owner]
        if entry and carried_by(entry) then
            local label = pair[2] .. (pair[2] == "built: " and (entry.library or "") or "")
            return "implemented", label .. string.format(" (the protocol %s declares it)", owner)
        end
    end
    local held, stopped = held_note(unavailable, api, decided), ""
    if (built_classes[owner] or release_classes[owner]) and held == "" then
        local chain
        chain, stopped = ancestors(owner, built_classes, release_classes, header)
        for _, link in ipairs(chain) do
            for _, pair in ipairs(link[2]) do
                local entry, is_built = pair[1], pair[2]
                local carried = carried_by(entry)
                if carried then
                    local why = is_built and built_why(entry, carried) or RELEASE_NATIVE
                    return "implemented", string.format("%s (inherited from %s)%s", why, link[1], class_note(entry))
                end
            end
        end
    end
    if not built_classes[owner] and not release_classes[owner] and not built_protocols[owner] and not release_protocols[owner] then
        return "missing", string.format("owner class %s not in the built libraries or the 6.1.3 cache", owner)
    end
    return "missing", string.format("%s is there, neither %s nor %s is an instance or a class selector%s%s", owner, getter, setter, held, stopped)
end

function bare_name(api)
    if api:sub(-2) == "()" then
        return api:sub(1, -3)
    end
    return api
end

function classify_symbol(api, built_exports, release_exports)
    local symbol = "_" .. bare_name(api)
    if built_exports[symbol] then
        return "implemented", "built: " .. built_exports[symbol]
    end
    if release_exports[symbol] then
        return "implemented", RELEASE_NATIVE
    end
    return nil, nil
end

function macro_target(expansion, macros, built_exports, release_exports, depth)
    depth = depth or 6
    local text = expansion:gsub("^%s+", ""):gsub("%s+$", "")
    while depth > 0 do
        local identifier = text:match("[A-Za-z_][A-Za-z0-9_]*") or ""
        if identifier == "" then
            return nil, "its replacement is not a name"
        end
        local symbol = "_" .. identifier
        if built_exports[symbol] then
            return symbol, "which the built library " .. built_exports[symbol] .. " exports"
        end
        if release_exports[symbol] then
            return symbol, "which the release's own cache exports"
        end
        if macros[identifier] ~= nil then
            text = macros[identifier]
            depth = depth - 1
        else
            return nil, "its replacement is " .. repr(identifier) .. ", which no built library or cache exports"
        end
    end
    return nil, "its replacement is a chain of macros more than six deep"
end

function classify_macro(api, index, built_exports, release_exports)
    local expansion = index.macros[api]
    if expansion == nil then
        return nil
    end
    local symbol, why = macro_target(expansion, index.macros, built_exports, release_exports)
    if symbol then
        return {"implemented", string.format("a macro for %s, %s: the name resolves to a value the release already has, and the availability above the declaration in the header does not gate it",
                                             expansion, why), nil, nil}
    end
    return {"header-ok", string.format("a macro: its value is in the header (%s), so no symbol is needed", expansion), nil, nil}
end

function classify_from_headers(api, row, index, release, built_exports, release_exports)
    release = release or "6.1.3"
    if index.error ~= nil then
        return "undecided", index.error, nil, nil
    end
    local compiled = index.compiled or {}
    local function named_ok(name)
        return compiled[name] ~= nil and not truthy(compiled[name])
    end
    local function why_not(name)
        return truthy(compiled[name]) and compiled[name] or "no error attributed to its line"
    end
    local bare = bare_name(api)
    local found = index.rows[api]
    if found == nil then
        return "undecided", string.format("no declaration of %s at %s, though the 26.2 headers have it (the surface row is the evidence): a version-gated #if in the header hides it at this target, so lowering an availability is not enough -- the port needs its own declaration (%d headers of this framework clang rejected)",
                                          api, TARGET, #(index.failed or {})), nil, "declare"
    end
    local function value(item)
        if ledger_json.is_null(item) then
            return nil
        end
        return item
    end
    local kind, introduced, unavailable = found[1], value(found[2]), value(found[3])
    if found[4] ~= nil and value(found[4]) then
        return "not-ios", "API_UNAVAILABLE(ios): the declaration is not an iOS API at all, so this row leaves the denominator", nil, "none"
    end
    if built_exports ~= nil and row.kind == "constant" then
        local macro = classify_macro(api, index, built_exports, release_exports)
        if macro then
            return macro[1], macro[2], macro[3], macro[4]
        end
    end
    if unavailable then
        return "missing", "NS_UNAVAILABLE in the lifted headers", introduced, nil
    end
    if row.kind ~= "constant" and row.kind ~= "function" then
        if named_ok(bare) then
            return "header-ok", string.format("%s declared in the lifted headers and the generated unit naming it compiles for %s", kind, release), introduced, nil
        end
        return "undecided", "declared in the lifted headers, but the generated unit naming it does not compile: " .. why_not(bare), introduced, nil
    end
    local flags = index.flags[bare]
    if flags == nil then
        if row.kind == "constant" then
            if named_ok(bare) then
                return "header-ok", "enum case in the lifted headers, no run-time symbol by construction", introduced, nil
            end
            return "undecided", "enum case, but the generated unit naming it does not compile: " .. why_not(bare), introduced, nil
        end
        return "undecided", string.format("%s is declared in the lifted headers but not at the top level, so its static/inline qualifiers are unknown", bare), introduced, nil
    end
    local is_extern, is_static = value(flags[1]), value(flags[2])
    if is_extern or not is_static then
        local how = is_extern and "extern " or ""
        return "missing", string.format("declared %sin the lifted headers and there is no such symbol in the built libraries or the %s cache -- the port has to export it",
                                        how, release), introduced, nil
    end
    if named_ok(bare) then
        return "header-ok", "static, in the header, no run-time symbol", introduced, nil
    end
    return "undecided", "static in the header, but the generated unit naming it does not compile: " .. why_not(bare), introduced, nil
end

function parse_version(text)
    return surface_walk.parse_version((tostring(text):gsub("_", ".")))
end

function show_introduced(introduced)
    if introduced == nil or #introduced == 0 then
        return ""
    end
    local parts = {}
    for _, part in ipairs(introduced) do
        table.insert(parts, string.format("%d", part))
    end
    return table.concat(parts, ".")
end

function what_this_row_needs(status, introduced, release, override)
    if status == "unmeasured" then
        return "swift-pass"
    end
    if override == "swift-module" then
        return "swift-module"
    end
    if status == "declared" then
        return override or "build"
    end
    if override then
        return override
    end
    if status == "undecided" then
        return "decide"
    end
    if introduced ~= nil and #introduced > 0 and surface_walk.compare(parse_version(show_introduced(introduced)), parse_version(release)) > 0 then
        return status == "missing" and "code+lift" or "lift"
    end
    local plain = {missing = "code", ["header-ok"] = "none", implemented = "none"}
    return plain[status] or "decide"
end
