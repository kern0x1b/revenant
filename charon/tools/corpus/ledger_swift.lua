local HERE = os.scriptdir()
local byteorder = import("byteorder", {rootdir = path.join(HERE, "..", "..", "modules"), anonymous = true})
local ledger_json = import("ledger_json", {rootdir = HERE, anonymous = true})
local ledger_classify = import("ledger_classify", {rootdir = HERE, anonymous = true})
local repr = ledger_classify.repr

local TYPE_KINDS = {TypeNominal = true, TypeDecl = true, TypeAlias = true, TypeNameAlias = true}

local SWIFT_COMPATIBLE = {
    class = TYPE_KINDS,
    struct = TYPE_KINDS,
    enum = TYPE_KINDS,
    protocol = TYPE_KINDS,
    method = {Function = true, Constructor = true, TypeFunc = true, AccessorFunction = true, Subscript = true, OperatorDecl = true},
    property = {Var = true, AccessorSubscript = true},
    constant = {Var = true, TypeFunc = true, AccessorFunction = true, Macro = true},
    ["function"] = {Function = true, AccessorFunction = true, OperatorDecl = true, Macro = true},
    typealias = {TypeAlias = true, TypeNameAlias = true, TypeNominal = true, TypeDecl = true, AssociatedType = true, Macro = true},
}

local SYNTHESISED_OPERATORS = {["=="] = "Equatable", ["!="] = "Equatable", ["<"] = "Comparable", ["<="] = "Comparable",
                         [">"] = "Comparable", [">="] = "Comparable"}

function split_qualified(api)
    local depth = 0
    for index = #api, 1, -1 do
        local char = api:sub(index, index)
        if char == ")" or char == "]" or char == ">" then
            depth = depth + 1
        elseif char == "(" or char == "[" or char == "<" then
            depth = depth - 1
        elseif char == "." and depth == 0 then
            return api:sub(1, index - 1), api:sub(index + 1)
        end
    end
    return "", api
end

local function arguments(text)
    local _, count = text:gsub(":", "")
    local parts = {}
    for _ = 1, count do
        table.insert(parts, "_")
    end
    return "(" .. table.concat(parts, ":") .. (count > 0 and ":" or "") .. ")"
end

local function failable_init(text)
    local at = text:find("init?(", 1, true)
    if not at then
        return text
    end
    local last
    local from = at + 6
    while true do
        local close = text:find(")", from, true)
        if not close then
            break
        end
        last = close
        from = close + 1
    end
    if not last then
        return text
    end
    return text:sub(1, at - 1) .. "init(" .. text:sub(at + 6, last - 1) .. ")" .. text:sub(last + 1)
end

local function plain_replace(text, old, new)
    local out, from = {}, 1
    while true do
        local at = text:find(old, from, true)
        if not at then
            table.insert(out, text:sub(from))
            return table.concat(out)
        end
        table.insert(out, text:sub(from, at - 1))
        table.insert(out, new)
        from = at + #old
    end
end

local function generic_lists(text)
    local out, at, size = {}, 1, #text
    while at <= size do
        local start, open
        if text:sub(at, at + 1) == ":<" then
            start, open = at, at + 1
        elseif text:sub(at, at) == "<" then
            start, open = at, at
        end
        local close
        if start then
            local finish = open + 1
            while finish <= size do
                local char = text:sub(finish, finish)
                if char == "(" or char == ")" then
                    break
                end
                if char == ">" then
                    close = finish
                end
                finish = finish + 1
            end
        end
        if close then
            at = close + 1
        else
            table.insert(out, text:sub(at, at))
            at = at + 1
        end
    end
    return table.concat(out)
end

local SWIFT_MEMBER_RULES = {
    failable_init,
    function (s)
        return plain_replace(s, "subscript?(", "subscript(")
    end,
    function (s)
        if s:sub(1, 3) == "==(" and s:sub(-1) == ")" then
            return "==(_:_:)"
        end
        return s
    end,
    function (s)
        if s:sub(1, 2) == "~=" then
            return "~="
        end
        return s
    end,
    function (s)
        if s:sub(1, 10) == "subscript(" and s:sub(-1) == ")" and #s >= 11 then
            if s:sub(11, -2):find(":", 1, true) then
                return "subscript(_:)"
            end
        end
        return s
    end,
    generic_lists,
    function (s)
        return (s:gsub("%(([^()]*)%)", arguments))
    end,
}

local function space(char)
    return char == " " or char == "\t" or char == "\n" or char == "\r" or char == "\f" or char == "\v"
end

function strip_payload_case(api)
    local from = 1
    while true do
        local at = api:find(".(", from, true)
        if not at then
            return api
        end
        local blanks = at + 2
        while blanks <= #api and space(api:sub(blanks, blanks)) do
            blanks = blanks + 1
        end
        for stop = blanks, at + 2, -1 do
            local options = {stop}
            if api:sub(stop, stop) == ")" then
                options = {stop + 1, stop}
            end
            for _, start in ipairs(options) do
                local finish = start
                while finish <= #api and api:sub(finish, finish) ~= " " do
                    finish = finish + 1
                end
                if api:sub(finish, finish + 3) == " -> " then
                    return api:sub(1, at - 1)
                end
            end
        end
        from = at + 1
    end
end

local function unique(list)
    local seen, out = {}, {}
    for _, item in ipairs(list) do
        if not seen[item] then
            seen[item] = true
            table.insert(out, item)
        end
    end
    return out
end

function swift_forms(api)
    api = strip_payload_case(api)
    local forms = {api}
    for _ = 1, 4 do
        local before = #forms
        for _, normal in ipairs(SWIFT_MEMBER_RULES) do
            local snapshot = {}
            for index, text in ipairs(forms) do
                snapshot[index] = text
            end
            for _, text in ipairs(snapshot) do
                local part_owner, tail = split_qualified(text)
                local changed = normal(tail)
                if changed ~= tail then
                    if part_owner ~= "" and changed ~= "" then
                        table.insert(forms, part_owner .. "." .. changed)
                    else
                        table.insert(forms, part_owner ~= "" and part_owner or changed)
                    end
                end
            end
        end
        forms = unique(forms)
        if #forms == before then
            break
        end
    end
    return forms
end

local function sorted(list, less)
    table.sort(list, less or byteorder.less)
    return list
end

local function present(value)
    if ledger_json.is_null(value) then
        return nil
    end
    return value
end

function load_swift_modules(file)
    local index = ledger_json.decode(io.readfile(file))
    local names, counts, modules, seen = {}, {}, {}, {}
    local module_names = {}
    for module in pairs(present(index.modules) or {}) do
        table.insert(module_names, module)
    end
    byteorder.sort(module_names)
    for _, module in ipairs(module_names) do
        local declared = index.modules[module]
        local function is_map(value)
            return type(value) == "table" and not ledger_json.is_null(value) and not ledger_json.is_array(value)
        end
        if is_map(declared) and is_map(declared.names) then
            declared = declared.names
        end
        local good = is_map(declared)
        if good then
            for key, value in pairs(declared) do
                if type(key) ~= "string" or type(value) ~= "string" then
                    good = false
                    break
                end
            end
        end
        if not good then
            local what = type(declared) == "string" and "str" or type(declared) == "number" and (math.type(declared) == "integer" and "int" or "float")
                         or type(declared) == "boolean" and "bool" or ledger_json.is_null(declared) and "NoneType"
                         or ledger_json.is_array(declared) and "list" or "dict"
            raise("%s: the module %s is not a map of names to kinds, and not a versioned record either -- it is %s. The index was probably written by a run that died part way through; rebuild it with api-ledger-swift.lua.",
                  file, repr(module), what)
        end
        local count = 0
        for name, kind in pairs(declared) do
            count = count + 1
            names[name] = names[name] or {}
            if not seen[name .. "\n" .. module .. "\t" .. kind] then
                seen[name .. "\n" .. module .. "\t" .. kind] = true
                table.insert(names[name], {module, kind})
            end
        end
        counts[module] = count
        modules[module] = true
    end
    return {names = names, modules = modules, registries = {},
            conformances = present(index.conformances) or {},
            references = present(index.references) or {},
            digester = present(index.digester) or "",
            target = present(index.target) or "",
            sources = present(index.sources) or {},
            ["search-dirs"] = present(index["search-dirs"]) or {},
            ["extra-module-maps"] = present(index["extra-module-maps"]) or {},
            ["declaration-count"] = counts, ["matched-by-framework"] = {}}
end

function synthesised_operator(api, swift)
    local owner, member = split_qualified(api)
    if owner == "" or member == "" then
        return nil
    end
    local name = member:match("^[^(]*")
    local protocol = SYNTHESISED_OPERATORS[name]
    if not protocol then
        return nil
    end
    local listed = swift.conformances[owner] or {}
    local has = false
    for _, item in ipairs(listed) do
        if item == protocol then
            has = true
        end
    end
    if not has then
        return nil
    end
    return string.format("%s conforms to %s, so %s is synthesised for it: the digester prints no such member, and the conformance is the whole of the declaration",
                         owner, protocol, member)
end

local function pair_less(a, b)
    if a[1] ~= b[1] then
        return byteorder.less(a[1], b[1])
    end
    return byteorder.less(a[2], b[2])
end

local function first_of(list)
    return list[1]
end

function classify_swift(api, row, swift, matched)
    local found = nil
    for _, form in ipairs(swift_forms(api)) do
        found = swift.names[form]
        if found and ledger_classify.has_any(found) then
            break
        end
        found = nil
    end
    local wanted = SWIFT_COMPATIBLE[row.kind] or {}
    if not found and row.lang == "swift" then
        local synthesised = synthesised_operator(api, swift)
        if synthesised then
            return "implemented", synthesised, nil, nil
        end
        for _, form in ipairs(swift_forms(api)) do
            local declared = swift.registries[form]
            if declared and declared[1] == "implemented" then
                local reason = declared[3]
                if reason == nil or reason == "" then
                    reason = "no reason recorded"
                end
                return "declared", string.format("declared implemented in %s's own registry (%s), and no built armv7 module for it was found on this machine to check",
                                                 declared[2], reason), nil, "build"
            end
        end
    end
    if found then
        local agreeing, kinds = {}, {}
        for _, pair in pairs(found) do
            if wanted[pair[2]] then
                table.insert(agreeing, pair)
            end
            kinds[pair[2]] = true
        end
        sorted(agreeing, pair_less)
        if #agreeing > 0 then
            local where = {}
            for _, pair in ipairs(agreeing) do
                local source = swift.sources[pair[1]]
                local owner = type(source) == "table" and present(source.owner) or nil
                table.insert(where, string.format("%s (%s)", pair[1], owner or "?"))
            end
            sorted(where)
            local named = {}
            for kind in pairs(kinds) do
                if not wanted[kind] then
                    table.insert(named, kind)
                end
            end
            sorted(named)
            local reason = string.format("declared by the port's built %s module %s", swift.target, table.concat(where, ", "))
            if #named > 0 then
                reason = reason .. string.format(" (as %s, where the %s row's %s declares %s)", named[1], row.framework, row.kind,
                                                 wanted[named[1]] and "the same kind" or "another kind")
            end
            if matched ~= nil and swift.modules[row.framework] then
                for _, pair in ipairs(agreeing) do
                    if pair[1] == row.framework then
                        matched[row.framework] = (matched[row.framework] or 0) + 1
                        break
                    end
                end
            end
            return "implemented", reason, nil, nil
        end
        local all = {}
        for _, pair in pairs(found) do
            table.insert(all, pair[2])
        end
        sorted(all)
        return "undecided", string.format("a module declares %s as %s and the surface row says %s: two descriptions of one name that this tool will not choose between",
                                          api, first_of(all), row.kind), nil, "decide"
    end
    local reference = swift.references[row.framework]
    if reference then
        local targets = present(reference.targets) or {}
        local compilers = present(reference.compilers) or {}
        return "undecided", string.format("the only %s on this machine is a vendored reference interface (%s, %s), not a module this port builds for %s: nothing here can place this row",
                                          row.framework, targets[1] or "unknown", compilers[1] or "unknown compiler", swift.target), nil, "swift-module"
    end
    if swift.modules[row.framework] then
        local by_framework = swift["matched-by-framework"] or {}
        local counts = swift["declaration-count"] or {}
        if (by_framework[row.framework] or 0) == 0 then
            return "undecided", string.format("module read (%d declarations) and 0 of this framework's rows match it: coverage, not the matcher",
                                              counts[row.framework] or 0), nil, "swift-module"
        end
        return "missing", string.format("not declared by the port's built %s module %s, which declares %d names and %d of this framework's rows",
                                        swift.target, row.framework, counts[row.framework] or 0, by_framework[row.framework] or 0), nil, "code"
    end
    return "undecided", string.format("no module this port builds for %s stands for %s, so nothing here can place this row", swift.target, row.framework),
           nil, "swift-module"
end

function resolve_swift_coverage(results, swift, matched)
    local copy = {}
    for key, value in pairs(matched) do
        copy[key] = value
    end
    swift["matched-by-framework"] = copy
    local again = 0
    for index, result in ipairs(results) do
        local row = result[1]
        if result[2] == "undecided" and result[5] == "swift-module" and row.lang == "swift" and swift.modules[row.framework]
                and (matched[row.framework] or 0) ~= 0 then
            local status, reason, introduced, needs = classify_swift(row.api, row, swift)
            results[index] = {row, status, reason, introduced, needs}
            again = again + 1
        end
    end
    return again
end
