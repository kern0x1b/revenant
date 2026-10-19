local sha256 = import("sha256", {anonymous = true})

local COL = {framework = 1, kind = 2, usr = 3, container = 4, name = 5, side = 6, header = 7, line = 8, avail = 9,
             nullability = 10, type = 11, params = 12, attrs = 13, value = 14, declhash = 15, availhash = 16,
             typeparams = 19, anon = 20, category = 21}

local DECLARATOR = {n = "_Nonnull", l = "_Nullable", L = "_Nullable", u = "_Null_unspecified"}
local ATTRIBUTE = {n = "nonnull", l = "nullable", L = "nullable", u = "null_unspecified", r = "null_resettable"}

local SYSTEM_HEADER = "#pragma clang system_header"

local DEFINING = {interface = true, protocol = true, typedef = true, enum = true, struct = true, union = true}
local BOOKKEEPING = {census = true, ["census-file"] = true, unparsed = true, meta = true}
local KEYWORDS = {void = true, char = true, int = true, long = true, short = true, unsigned = true, signed = true, float = true,
                  double = true, const = true, volatile = true, _Bool = true, bool = true, id = true, Class = true, SEL = true,
                  instancetype = true, struct = true, union = true, enum = true, _Nullable = true, _Nonnull = true,
                  _Null_unspecified = true, _Nullable_result = true, __kindof = true}

local function split_cells(line, n)
    local cells, pos = {}, 1
    for i = 1, n do
        local tab = string.find(line, "\t", pos, true)
        if tab then
            cells[i] = string.sub(line, pos, tab - 1)
            pos = tab + 1
        else
            cells[i] = string.sub(line, pos)
            pos = #line + 2
        end
    end
    return cells
end

local function split(text, sep)
    local out, pos = {}, 1
    while true do
        local at = string.find(text, sep, pos, true)
        if not at then
            out[#out + 1] = string.sub(text, pos)
            return out
        end
        out[#out + 1] = string.sub(text, pos, at - 1)
        pos = at + #sep
    end
end

local function trim(text)
    return (string.gsub(string.gsub(text, "^%s+", ""), "%s+$", ""))
end

local function parameter(entry)
    entry = trim(entry)
    local name = string.match(entry, "([%a_][%w_]*)$")
    if name == nil or KEYWORDS[name] or name == entry then return entry, "" end
    return trim(string.sub(entry, 1, #entry - #name)), name
end

local function parameters_of(params, nullability)
    local out = {}
    if params == "-" then return out end
    local nulls = split(nullability, ",")
    for i, entry in ipairs(split(params, " | ")) do
        local ty, name = parameter(entry)
        out[i] = {type = ty, name = name, nullability = nulls[i] or "-"}
    end
    return out
end

local function split_suffix(ty)
    if string.sub(ty, -1) ~= ")" then return ty, "" end
    local depth = 0
    for i = #ty, 1, -1 do
        local ch = string.sub(ty, i, i)
        if ch == ")" then
            depth = depth + 1
        elseif ch == "(" then
            depth = depth - 1
            if depth == 0 then return trim(string.sub(ty, 1, i - 1)), string.sub(ty, i) end
        end
    end
    return ty, ""
end

local function declare(ty, name, nullability)
    local keyword = DECLARATOR[nullability]
    local s, e, mark, existing = string.find(ty, "%(([%^%*])%s*([_%a]*)%s*%)")
    local _, opened = string.gsub(string.sub(ty, 1, (s or 1) - 1), "<", "")
    local _, closed = string.gsub(string.sub(ty, 1, (s or 1) - 1), ">", "")
    if s and opened == closed then
        local kw = existing ~= "" and existing or keyword
        local inner = (kw and (" " .. kw) or "") .. (name ~= "" and ((kw and " " or "") .. name) or "")
        return string.sub(ty, 1, s) .. mark .. inner .. string.sub(ty, e)
    end
    local vector, attribute = string.match(ty, "^([^()]-)%s*(__attribute__%(%(.*%)%))$")
    if vector and vector ~= "" and name ~= "" then return vector .. " " .. name .. " " .. attribute end
    local result, parameters = split_suffix(ty)
    if parameters ~= "" and name ~= "" then return result .. " " .. name .. parameters end
    local dims = string.find(ty, "[", 1, true)
    if dims then
        local sized = string.sub(ty, dims)
        if keyword and string.find(sized, keyword, 1, true) == nil then
            local size = string.match(sized, "^%[(.+)%]$")
            sized = size and ("[" .. keyword .. " " .. size .. "]") or ("[" .. keyword .. "]")
        end
        return trim(string.sub(ty, 1, dims - 1)) .. " " .. name .. sized
    end
    local out = ty
    if keyword then out = out .. " " .. keyword end
    if name ~= "" then out = out .. " " .. name end
    return out
end

local function result_of(ty, nullability)
    if ty == "instancetype" and ATTRIBUTE[nullability] then return ATTRIBUTE[nullability] .. " instancetype" end
    return declare(ty, "", nullability)
end

local function availability(text)
    if text == "-" then return "" end
    local out = {}
    for token in string.gmatch(text, "[^,]+") do
        local star, rest = string.match(token, "^%*(%a+)%s*(.*)$")
        if star == "unavailable" or star == "deprecated" then
            out[#out + 1] = "__attribute__((" .. star .. "))"
            token = rest
        end
        if token ~= "" then
            local plat, intro, dep, obs, flag = string.match(token, "^([^=]+)=([^/]+)/([^/]+)/([^/]+)/(%d+)$")
            assert(plat, "availability token: " .. token)
            local parts = {}
            if flag == "1" then parts[#parts + 1] = "unavailable" end
            if intro ~= "-" then parts[#parts + 1] = "introduced=" .. intro end
            if dep ~= "-" then parts[#parts + 1] = "deprecated=" .. dep end
            if obs ~= "-" then parts[#parts + 1] = "obsoleted=" .. obs end
            if #parts > 0 then
                out[#out + 1] = "__attribute__((availability(" .. plat .. "," .. table.concat(parts, ",") .. ")))"
            end
        end
    end
    return table.concat(out, " ")
end

local function arity_of(text, open)
    local depth, count = 0, 1
    for i = open, #text do
        local c = string.sub(text, i, i)
        if c == "<" then
            depth = depth + 1
        elseif c == ">" then
            depth = depth - 1
            if depth == 0 then return count end
        elseif c == "," and depth == 1 then
            count = count + 1
        end
    end
    return count
end

local function defined_as(defs, name, kind)
    for _, def in ipairs(defs[name] or {}) do
        if def.kind == kind then return true end
    end
    return false
end

local function bounded_class(defs, name)
    for _, def in ipairs(defs[name] or {}) do
        if def.kind == "interface" and def.typeparams ~= nil and def.typeparams ~= "-" then
            for _, entry in ipairs(split(def.typeparams, " | ")) do
                if string.match(entry, "^[^:]+:(.*)$") ~= "id" then return true end
            end
        end
    end
    return false
end

local function type_names(text, out, defs)
    local bounded_use = false
    for name in string.gmatch(text, "([%a_][%w_]*)%s*<") do
        if bounded_class(defs, name) then bounded_use = true end
    end
    for start, word in string.gmatch(text, "()([%a_][%w_]*)") do
        if not KEYWORDS[word] then
            local before = string.match(string.sub(text, 1, start - 1), "(%S+)%s*$") or ""
            local after = string.match(text, "^%s*(.)", start + #word) or ""
            local owner = string.match(string.sub(text, 1, start - 1), "([%w_]+)%s*<[^<>]*$")
            local kind
            if before == "struct" or before == "union" or before == "enum" then
                kind = "def"
            elseif after == "<" then
                local open = string.find(text, "<", start + #word, true)
                local first = string.match(text, "^<%s*([%a_][%w_]*)", open)
                if first and defined_as(defs, first, "protocol") then
                    kind = "class"
                else
                    kind = "generic:" .. arity_of(text, open)
                end
            elseif after == "*" then
                kind = (bounded_use and owner ~= nil) and "def" or "class"
            elseif owner ~= nil then
                kind = (owner == "id" or defined_as(defs, word, "protocol")) and "protocol" or "def"
                if bounded_use and word ~= "id" then kind = "def" end
            else
                kind = "def"
            end
            if out[word] ~= "def" then out[word] = kind end
        end
    end
    return out
end

function defs_of(rows)
    local defs = {}
    local with_constants = {}
    for _, row in ipairs(rows) do
        if row[COL.kind] == "enumconst" then with_constants[row[COL.container]] = true end
    end
    for _, row in ipairs(rows) do
        local name = row[COL.name]
        local defines = DEFINING[row[COL.kind]] and (row[COL.kind] ~= "enum" or with_constants[name])
        if defines and row[COL.header] ~= "-" and name ~= "-" then
            local list = defs[name] or {}
            list[#list + 1] = {framework = row[COL.framework], header = row[COL.header], kind = row[COL.kind],
                typeparams = row[COL.typeparams], row = row}
            defs[name] = list
        end
    end
    return defs
end

local function pick(list, framework)
    if list == nil then return nil end
    for _, def in ipairs(list) do
        if def.framework == framework then return def end
    end
    return list[1]
end

local function pick_other(list, framework, header)
    local other = nil
    for _, def in ipairs(list or {}) do
        if def.framework ~= framework or def.header ~= header then
            if def.framework == framework then return def end
            other = other or def
        end
    end
    return other
end

local function generic_definition(defs, name, framework)
    local interfaces = {}
    for _, def in ipairs(defs[name] or {}) do
        if def.kind == "interface" then interfaces[#interfaces + 1] = def end
    end
    return pick(interfaces, framework)
end

local function module_name(framework)
    return string.match(framework, "([^/]+)$")
end

local function name_from(header, includer)
    local target, from = {}, {}
    for part in string.gmatch(header, "[^/]+") do target[#target + 1] = part end
    for part in string.gmatch(includer, "[^/]+") do from[#from + 1] = part end
    table.remove(from)
    local common = 0
    while common < #from and common + 1 < #target and from[common + 1] == target[common + 1] do common = common + 1 end
    local parts = {}
    for _ = common + 1, #from do parts[#parts + 1] = ".." end
    for i = common + 1, #target do parts[#parts + 1] = target[i] end
    return table.concat(parts, "/")
end

local function import_of(def, framework, header, usr_dirs)
    local dir = usr_dirs.prefix[def.framework]
    if dir and usr_dirs.exists(dir .. "/" .. def.header) then return "#import <" .. dir .. "/" .. def.header .. ">" end
    if usr_dirs.bare[def.framework] then return "#import <" .. def.header .. ">" end
    if string.sub(def.header, 1, 1) == "/" then
        local name, rest = string.match(def.header, "([^/]+)%.framework/Headers/(.+)$")
        if name then return "#import <" .. name .. "/" .. rest .. ">" end
        local public = string.match(def.header, "/include/__(%a+)_[^/]*%.h$")
        if public then return "#import <" .. public .. ".h>" end
        rest = string.match(def.header, "/usr/include/(.+)$")
        if rest then return "#import <" .. (usr_dirs.umbrella[string.match(rest, "^([^/]+)/") or ""] or usr_dirs.target(rest)) .. ">" end
        local stem = string.match(def.header, "/include/__(%a+)_[^/]+%.h$")
        if stem then return "#import <" .. stem .. ".h>" end
        return nil
    end
    if def.framework == framework then
        if def.header == header then return nil end
        return '#import "' .. name_from(def.header, header) .. '"'
    end
    local folder = usr_dirs.folder and usr_dirs.folder[def.header]
    if folder and not usr_dirs.sdk_framework(def.framework) then return "#import <" .. usr_dirs.target(folder .. "/" .. def.header) .. ">" end
    local public = usr_dirs.reexport and usr_dirs.reexport[def.framework]
    if public then return "#import <" .. public .. "/" .. public .. ".h>" end
    return "#import <" .. module_name(def.framework) .. "/" .. def.header .. ">"
end

local function swift_attribute(usr_dirs, framework, kind, name)
    local names = usr_dirs and usr_dirs.swift and usr_dirs.swift[framework] and usr_dirs.swift[framework][kind]
    local swift = names and names[name]
    if swift == nil then return "" end
    return '__attribute__((swift_name("' .. swift .. '")))\n'
end

local function owner_of(usr)
    local name = string.match(usr, "%(cs%)([^%(]+)")
    if name then return "cs:" .. name end
    name = string.match(usr, "%(pl%)([^%(]+)")
    if name then return "pl:" .. name end
    return nil
end

local function conformance_owner(usr)
    local name = string.match(usr, "%(cs%)([^%(]+)") or string.match(usr, "%(ext%)([^%(@]+)")
    if name then return "cs:" .. name end
    name = string.match(usr, "%(pl%)([^%(]+)")
    if name then return "pl:" .. name end
    return nil
end

local function class_of(usr)
    return string.match(usr, "%(cs%)([^%(]+)")
end

local function is_optional(row)
    for attr in string.gmatch(row[COL.attrs], "[^,]+") do
        if attr == "optional" then return true end
    end
    return false
end

local function getter_of(row)
    local head, property, name = string.match(row[COL.usr], "^(.*)%((c?py)%)([^()]*)$")
    assert(head, "a property's USR has no (py) or (cpy) selector: " .. row[COL.usr])
    local method = property == "cpy" and "(cm)" or "(im)"
    for attr in string.gmatch(row[COL.attrs], "[^,]+") do
        local selector = string.match(attr, "^getter=(.+)$")
        if selector then return head .. method .. selector end
    end
    return head .. method .. name
end

local function top_level_pointers(ty)
    local depth, count = 0, 0
    for i = 1, #ty do
        local c = string.sub(ty, i, i)
        if c == "<" then
            depth = depth + 1
        elseif c == ">" then
            depth = depth - 1
        elseif c == "*" and depth == 0 then
            count = count + 1
        end
    end
    return count
end

local function member_text(row)
    local avail = availability(row[COL.avail])
    local suffix = avail ~= "" and (" " .. avail) or ""
    if row[COL.kind] == "property" then
        local attrs, has_class, has_nsobject = {}, false, false
        for attr in string.gmatch(row[COL.attrs], "[^,]+") do
            if attr == "class" then has_class = true end
            if attr == "NSObject" then
                has_nsobject = true
            elseif attr ~= "optional" and attr ~= "-" then
                attrs[#attrs + 1] = attr
            end
        end
        local keyword = "-"
        if top_level_pointers(row[COL.type]) > 1 and DECLARATOR[row[COL.nullability]] then
            keyword = row[COL.nullability]
        elseif ATTRIBUTE[row[COL.nullability]] then
            attrs[#attrs + 1] = ATTRIBUTE[row[COL.nullability]]
        end
        if row[COL.side] == "+" and not has_class then attrs[#attrs + 1] = "class" end
        local head = #attrs > 0 and ("@property (" .. table.concat(attrs, ", ") .. ") ") or "@property "
        local name = has_nsobject and (row[COL.name] .. " __attribute__((NSObject))") or row[COL.name]
        return head .. declare(row[COL.type], name, keyword) .. suffix .. ";"
    end
    local sign = row[COL.side] == "+" and "+" or "-"
    local result_nullability, param_nullability = string.match(row[COL.nullability], "^([^|]*)|(.*)$")
    assert(result_nullability, "nullability column without |: " .. row[COL.nullability])
    local params = parameters_of(row[COL.params], param_nullability)
    local selector = row[COL.name]
    local result = "(" .. result_of(row[COL.type], result_nullability) .. ")"
    if #params == 0 then
        return sign .. " " .. result .. selector .. suffix .. ";"
    end
    local pieces = {}
    for piece in string.gmatch(selector, "[^:]*:") do pieces[#pieces + 1] = piece end
    assert(#pieces == #params, "selector " .. selector .. " has " .. #pieces .. " parts for " .. #params .. " parameters")
    local out = {sign .. " " .. result}
    for i, param in ipairs(params) do
        out[#out + 1] = pieces[i] .. "(" .. declare(param.type, "", param.nullability) .. ")" .. param.name
    end
    return table.concat(out, " ") .. suffix .. ";"
end

local function members_text(list)
    local required, optional = {}, {}
    for _, row in ipairs(list or {}) do
        local target = is_optional(row) and optional or required
        target[#target + 1] = "  " .. member_text(row)
    end
    local lines = required
    if #optional > 0 then
        lines[#lines + 1] = "@optional"
        for _, text in ipairs(optional) do lines[#lines + 1] = text end
    end
    return lines
end

local function suffix_of(attributes)
    return attributes ~= "" and (" " .. attributes) or ""
end

local function note(deps, name, use)
    if name == nil or KEYWORDS[name] then return end
    local entry = deps[name] or {}
    if use == "def" then
        entry.def = true
    elseif use == "class" or use == "protocol" then
        entry.forwards = entry.forwards or {}
        entry.forwards[use] = true
    elseif entry.forward == nil or string.sub(use, 1, 8) == "generic:" then
        entry.forward = use
    end
    deps[name] = entry
end

local function note_type(deps, defs, text)
    for name, use in pairs(type_names(text, {}, defs)) do note(deps, name, use) end
end

local function note_member(deps, defs, row)
    note_type(deps, defs, row[COL.type])
    if row[COL.kind] == "method" and row[COL.params] ~= "-" then
        for _, p in ipairs(parameters_of(row[COL.params], "-")) do note_type(deps, defs, p.type) end
    end
end

local function type_parameters_of(cell, deps, defs)
    local out = {}
    assert(cell, "an IR row with no typeparams cell: the full IR has 21 cells, an older one must be rebuilt")
    if cell == "-" then return out end
    for _, entry in ipairs(split(cell, " | ")) do
        local name, bound = string.match(entry, "^([^:]+):(.*)$")
        assert(name, "a type parameter with no bound: " .. entry)
        if bound == "id" then
            out[#out + 1] = name
        else
            note_type(deps, defs, bound)
            out[#out + 1] = name .. " : " .. bound
        end
    end
    return out
end

function render(framework, rows, defs, has_map, has_sdk_headers, usr_dirs)
    local counts = {declarations = {}, skipped = {}}
    local function count(kind, n)
        counts.declarations[kind] = (counts.declarations[kind] or 0) + (n or 1)
    end
    local function skip(reason)
        counts.skipped[reason] = (counts.skipped[reason] or 0) + 1
    end

    local getters, optional_getters = {}, {}
    for _, row in ipairs(rows) do
        if row[COL.kind] == "accessor" then
            getters[row[COL.usr]] = string.match(row[COL.nullability], "^([^|]*)")
            if string.find(row[COL.attrs], "optional", 1, true) then optional_getters[row[COL.usr]] = true end
        end
    end

    local usrs_of_name, overloads = {}, {}
    for _, row in ipairs(rows) do
        if row[COL.kind] == "function" then
            usrs_of_name[row[COL.name]] = usrs_of_name[row[COL.name]] or {}
            usrs_of_name[row[COL.name]][row[COL.usr]] = true
        end
    end
    for name, usrs in pairs(usrs_of_name) do
        local count = 0
        for _ in pairs(usrs) do count = count + 1 end
        if count > 1 then overloads[name] = true end
    end

    local enumconsts, anonymous_consts, fields, supers, conforms, members, cat_members, tops = {}, {}, {}, {}, {}, {}, {}, {}
    local category_conforms = {}
    local referenced, class_tags = {}, {}
    for _, row in ipairs(rows) do
        if row[COL.kind] == "field" and row[COL.anon] ~= "-" then referenced[row[COL.anon]] = true end
    end
    local function member_lines(list, indent, block)
        local out = {}
        for _, f in ipairs(list) do
            local attr = availability(f[COL.avail])
            local tail = attr ~= "" and (" " .. attr) or ""
            if f[COL.kind] == "struct" or f[COL.kind] == "union" then
                out[#out + 1] = indent .. f[COL.kind] .. " {"
                for _, line in ipairs(member_lines(fields["tag:" .. f[COL.usr]] or {}, indent .. "  ", block)) do out[#out + 1] = line end
                out[#out + 1] = indent .. "}" .. tail .. ";"
            elseif f[COL.anon] ~= "-" then
                local kind = string.match(f[COL.type], "^(%a+) %(unnamed")
                assert(kind == "struct" or kind == "union", "an anonymous member with no tag kind: " .. f[COL.type])
                out[#out + 1] = indent .. kind .. " {"
                for _, line in ipairs(member_lines(fields["tag:" .. f[COL.anon]] or {}, indent .. "  ", block)) do out[#out + 1] = line end
                out[#out + 1] = indent .. "} " .. f[COL.name] .. tail .. ";"
            else
                out[#out + 1] = indent .. declare(f[COL.type], f[COL.name], f[COL.nullability]) .. tail .. ";"
                note_type(block.deps, defs, f[COL.type])
            end
        end
        return out
    end
    for _, row in ipairs(rows) do
        local kind = row[COL.kind]
        if kind == "property" then
            local getter = getter_of(row)
            local resettable = row[COL.nullability] == "u" and getters[getter] == "n"
            local optional = optional_getters[getter] and not is_optional(row)
            if resettable or optional then
                row = {table.unpack(row, 1, 16)}
                if resettable then row[COL.nullability] = "r" end
                if optional then row[COL.attrs] = row[COL.attrs] == "-" and "optional" or (row[COL.attrs] .. ",optional") end
            end
        end
        if BOOKKEEPING[kind] then
            if kind ~= "meta" then skip(kind) end
        elseif kind == "accessor" then
            skip("accessor (synthesised by clang)")
        elseif kind == "enumconst" then
            local by, key = enumconsts, row[COL.container]
            if key == "-" then by, key = anonymous_consts, string.match(row[COL.usr], "^(.*)@[^@]+$") end
            local list = by[key] or {}
            list[#list + 1] = row
            by[key] = list
        elseif kind == "field" then
            local key = row[COL.container]
            if key == "-" then key = "tag:" .. string.match(row[COL.usr], "^(.*)@FI@[^@]*$") end
            local list = fields[key] or {}
            list[#list + 1] = row
            fields[key] = list
        elseif (kind == "struct" or kind == "union") and row[COL.name] == "-" then
            local class = string.match(row[COL.usr], "^c:objc%(cs%)([^@]+)@")
            local parent = string.match(row[COL.usr], "^(.*)@[SU]a$") or string.match(row[COL.usr], "^(.*)@[SU]@[^@]+@%d+$")
            if class and not referenced[row[COL.usr]] then
                local list = class_tags[class] or {}
                list[#list + 1] = row
                class_tags[class] = list
            elseif parent and not referenced[row[COL.usr]] and not string.find(parent, "^c:objc") then
                local named = string.match(parent, "^c:@[SU]@([^@]+)$")
                local key = named or ("tag:" .. parent)
                local list = fields[key] or {}
                list[#list + 1] = row
                fields[key] = list
            else
                skip("anonymous " .. kind)
            end
        elseif kind == "super" then
            supers[row[COL.container]] = supers[row[COL.container]] or row[COL.name]
        elseif kind == "conforms" then
            local by, key = conforms, conformance_owner(row[COL.usr])
            if row[COL.category] ~= "-" then by, key = category_conforms, row[COL.container] .. "@" .. row[COL.category] end
            assert(key, "a conformance with no class or protocol USR: " .. row[COL.usr])
            local list = by[key] or {}
            list[#list + 1] = row[COL.name]
            by[key] = list
        elseif kind == "method" or kind == "property" then
            if row[COL.container] == "-" then
                local owner = owner_of(row[COL.usr])
                if owner == nil then
                    skip("member without an owner")
                else
                    local list = members[owner] or {}
                    list[#list + 1] = row
                    members[owner] = list
                end
            else
                local key = (class_of(row[COL.usr]) or "?") .. "@" .. row[COL.container]
                local list = cat_members[key] or {}
                list[#list + 1] = row
                cat_members[key] = list
            end
        elseif row[COL.header] == "-" then
            skip("no header (" .. kind .. ")")
        elseif string.sub(row[COL.header], 1, 1) == "/" then
            skip("typedef from another SDK header (absolute path)")
        else
            tops[#tops + 1] = row
        end
    end

    local blocks, header_order = {}, {}
    local VALUE_KINDS = {typedef = true, enum = true, struct = true, union = true}
    local function block_of(header)
        if blocks[header] == nil then
            blocks[header] = {text = {}, early = {}, deps = {}, defined = {}}
            header_order[#header_order + 1] = header
        end
        return blocks[header]
    end

    local tags, emitted_tags, pending, anonymous_named = {}, {}, {}, {}
    local ANONYMOUS_USR = {enum = "@EA@", struct = "@SA@", union = "@UA@"}
    for _, row in ipairs(tops) do
        local kind = row[COL.kind]
        local anonymous = ANONYMOUS_USR[kind] ~= nil and row[COL.name] ~= "-" and string.find(row[COL.usr], ANONYMOUS_USR[kind], 1, true)
        if anonymous then
            anonymous_named[row[COL.name]] = true
        elseif kind == "enum" and row[COL.name] ~= "-" then
            tags[row[COL.name]] = row[COL.header]
        end
    end

    for _, row in ipairs(tops) do
        local kind = row[COL.kind]
        local block = block_of(row[COL.header])
        local name = row[COL.name]
        local avail = availability(row[COL.avail])
        local prefix = avail ~= "" and (avail .. "\n") or ""
        local text
        local declared_only = false
        if kind == "enum" then
            local consts = name == "-" and (anonymous_consts[row[COL.usr]] or {}) or (enumconsts[name] or {})
            if name == "-" and #consts == 0 then
                skip("anonymous enum without constants")
            elseif #consts == 0 and row[COL.type] == "-" then
                skip("enum without constants or fixed type")
            elseif #consts == 0 then
                declared_only = true
                note_type(block.deps, defs, row[COL.type])
                text = prefix .. "enum " .. name .. " : " .. row[COL.type] .. ";"
                count("enum forward", 1)
            else
                local base = row[COL.type]
                local anonymous = anonymous_named[name]
                local head = name == "-" and "enum" or (anonymous and "typedef enum" or ("enum " .. name))
                local lines = {prefix .. head .. (base ~= "-" and (" : " .. base) or "") .. " {"}
                if base ~= "-" then note_type(block.deps, defs, base) end
                for _, c in ipairs(consts) do
                    local attr = availability(c[COL.avail])
                    local value = c[COL.value] ~= "-" and (" = " .. c[COL.value]) or ""
                    lines[#lines + 1] = "  " .. c[COL.name] .. (attr ~= "" and (" " .. attr) or "") .. value .. ","
                end
                lines[#lines + 1] = anonymous and ("} " .. name .. ";") or "};"
                text = table.concat(lines, "\n")
                count("enumconst", #consts)
            end
        elseif kind == "typedef" then
            if anonymous_named[name] and (row[COL.type] == "struct " .. name or row[COL.type] == "union " .. name
                    or row[COL.type] == "enum " .. name) then
                skip("typedef written with its anonymous tag")
            elseif string.find(row[COL.type], "unnamed", 1, true) then
                skip("typedef of an anonymous tag")
            else
                text = "typedef " .. declare(row[COL.type], name, row[COL.nullability]) .. suffix_of(avail) .. ";"
                note_type(block.deps, defs, row[COL.type])
                local tag = string.match(row[COL.type], "^%a+ (%S+)$")
                if tag and tags[tag] == row[COL.header] and not emitted_tags[tag] then
                    pending[tag] = text
                    text = nil
                end
            end
        elseif kind == "struct" or kind == "union" then
            if name == "-" then
                skip("anonymous " .. kind)
            else
                local anonymous = anonymous_named[name]
                local head = anonymous and (prefix .. "typedef " .. kind .. " {") or (kind .. " " .. (avail ~= "" and (avail .. " ") or "") .. name .. " {")
                local lines = {head}
                for _, line in ipairs(member_lines(fields[name] or {}, "  ", block)) do lines[#lines + 1] = line end
                lines[#lines + 1] = anonymous and ("} " .. name .. ";") or "};"
                text = table.concat(lines, "\n")
                count("field", #(fields[name] or {}))
            end
        elseif kind == "function" then
            local result, suffix = split_suffix(row[COL.type])
            local result_nullability = string.match(row[COL.nullability], "^([^|]*)") or "-"
            local args = parameters_of(row[COL.params], string.match(row[COL.nullability], "|(.*)$") or "-")
            local decls = {}
            for i, a in ipairs(args) do
                decls[i] = declare(a.type, a.name, a.nullability)
                note_type(block.deps, defs, a.type)
            end
            if string.find(row[COL.attrs], "variadic", 1, true) then decls[#decls + 1] = "..." end
            note_type(block.deps, defs, result)
            local overloadable = overloads[name] and " __attribute__((overloadable))" or ""
            text = "extern " .. declare(result, "", result_nullability) .. " " .. name
                .. "(" .. (#decls > 0 and table.concat(decls, ", ") or "void") .. ")" .. overloadable .. suffix_of(avail) .. ";"
        elseif kind == "var" then
            text = "extern " .. declare(row[COL.type], name, row[COL.nullability]) .. suffix_of(avail) .. ";"
            note_type(block.deps, defs, row[COL.type])
        elseif kind == "interface" then
            local super = supers[name]
            local protocols, seen = {}, {}
            for _, p in ipairs(conforms["cs:" .. name] or {}) do
                if not seen[p] then
                    seen[p] = true
                    protocols[#protocols + 1] = p
                    note(block.deps, p, "protocol")
                end
            end
            local head = prefix
            if super == nil then head = head .. "__attribute__((objc_root_class))\n" end
            head = head .. swift_attribute(usr_dirs, framework, "interface", name)
            local parameters = type_parameters_of(row[COL.typeparams], block.deps, defs)
            head = head .. "@interface " .. name .. (#parameters > 0 and ("<" .. table.concat(parameters, ", ") .. ">") or "")
                .. (super and (" : " .. super) or "")
            if #protocols > 0 then head = head .. " <" .. table.concat(protocols, ", ") .. ">" end
            if super then note(block.deps, super, "def") end
            local lines = {head}
            local ivars = class_tags[name] or {}
            if #ivars > 0 then
                lines[1] = head .. " {"
                for _, tag in ipairs(ivars) do
                    lines[#lines + 1] = "  " .. tag[COL.kind] .. " {"
                    for _, line in ipairs(member_lines(fields["tag:" .. tag[COL.usr]] or {}, "    ", block)) do lines[#lines + 1] = line end
                    lines[#lines + 1] = "  };"
                    count("field", #(fields["tag:" .. tag[COL.usr]] or {}))
                end
                lines[#lines + 1] = "}"
            end
            for _, line in ipairs(members_text(members["cs:" .. name])) do lines[#lines + 1] = line end
            for _, m in ipairs(members["cs:" .. name] or {}) do note_member(block.deps, defs, m) end
            count("member", #(members["cs:" .. name] or {}))
            lines[#lines + 1] = "@end"
            text = table.concat(lines, "\n")
        elseif kind == "protocol" then
            local protocols = {}
            for _, p in ipairs(conforms["pl:" .. name] or {}) do
                protocols[#protocols + 1] = p
                note(block.deps, p, "protocol")
            end
            local head = prefix .. swift_attribute(usr_dirs, framework, "protocol", name) .. "@protocol " .. name
            if #protocols > 0 then head = head .. " <" .. table.concat(protocols, ", ") .. ">" end
            local lines = {head}
            for _, line in ipairs(members_text(members["pl:" .. name])) do lines[#lines + 1] = line end
            for _, m in ipairs(members["pl:" .. name] or {}) do note_member(block.deps, defs, m) end
            count("member", #(members["pl:" .. name] or {}))
            lines[#lines + 1] = "@end"
            text = table.concat(lines, "\n")
        elseif kind == "category" and name == "-" then
            local class = string.match(row[COL.usr], "%(ext%)(.+)$")
            assert(class, "extension USR without a class: " .. row[COL.usr])
            note(block.deps, class, "def")
            text = prefix .. "@interface " .. class .. " ()\n@end"
        elseif kind == "category" then
            local class = string.match(row[COL.usr], "%(cy%)([^@]+)@")
            assert(class, "category USR without a class: " .. row[COL.usr])
            note(block.deps, class, "def")
            local key = class .. "@" .. name
            local parameters = type_parameters_of(row[COL.typeparams], block.deps, defs)
            local protocols = {}
            for _, p in ipairs(category_conforms[key] or {}) do
                protocols[#protocols + 1] = p
                note(block.deps, p, "protocol")
            end
            local head = prefix .. "@interface " .. class .. (#parameters > 0 and ("<" .. table.concat(parameters, ", ") .. ">") or "")
                .. " (" .. name .. ")"
            if #protocols > 0 then head = head .. " <" .. table.concat(protocols, ", ") .. ">" end
            local lines = {head}
            for _, line in ipairs(members_text(cat_members[key])) do lines[#lines + 1] = line end
            for _, m in ipairs(cat_members[key] or {}) do note_member(block.deps, defs, m) end
            count("member", #(cat_members[key] or {}))
            lines[#lines + 1] = "@end"
            text = table.concat(lines, "\n")
        else
            skip("unknown kind " .. kind)
        end
        if text then
            local list = VALUE_KINDS[kind] and block.early or block.text
            list[#list + 1] = text
            count(kind)
            local own_tag = kind == "typedef" and string.match(row[COL.type], "^%a+ (%S+)$") == name
            if (DEFINING[kind] and not declared_only and not own_tag) or kind == "function" or kind == "var" then
                block.defined[name] = true
            end
            if kind == "enum" and name ~= "-" then
                emitted_tags[name] = true
                if pending[name] then
                    block.early[#block.early + 1] = pending[name]
                    pending[name] = nil
                    count("typedef")
                end
            end
        end
    end

    for tag in pairs(pending) do
        error("typedef of " .. tag .. " waits for a definition that was never emitted")
    end

    local file_local = {}
    for _, row in ipairs(tops) do
        if row[COL.kind] == "typedef" and string.match(row[COL.usr], "^c:([^@]+)@T@") == row[COL.header] then
            file_local[row[COL.header]] = true
        end
    end
    local files = {}
    local headers = {}
    for _, header in ipairs(header_order) do headers[#headers + 1] = header end
    table.sort(headers)
    local base = module_name(framework)
    local edges = {}
    for _, header in ipairs(headers) do
        edges[header] = {}
        for name in pairs(blocks[header].deps) do
            for _, def in ipairs(defs[name] or {}) do
                if def.framework == framework and def.header ~= header then edges[header][def.header] = true end
            end
        end
    end
    local function reaches(from, to)
        local seen, stack = {}, {from}
        while #stack > 0 do
            local h = table.remove(stack)
            if h == to then return true end
            if not seen[h] then
                seen[h] = true
                for nxt in pairs(edges[h] or {}) do stack[#stack + 1] = nxt end
            end
        end
        return false
    end
    local inlined = {}
    for _, header in ipairs(headers) do
        local block = blocks[header]
        local generic_uses = {}
        for name, entry in pairs(block.deps) do
            if entry.forward and string.sub(entry.forward, 1, 8) == "generic:" then generic_uses[#generic_uses + 1] = name end
        end
        for _, name in ipairs(generic_uses) do
            local def = generic_definition(defs, name, framework)
            if def then type_parameters_of(def.typeparams, block.deps, defs) end
        end
        local names = {}
        for name in pairs(block.deps) do names[#names + 1] = name end
        table.sort(names)
        local imports, forwards, generic_forwards = {}, {}, {}
        for _, name in ipairs(names) do
            local entry = block.deps[name]
            local value_name = false
            for _, def in ipairs(defs[name] or {}) do
                if def.kind ~= "interface" and def.kind ~= "protocol" then value_name = true end
            end
            if (entry.def or value_name) and not block.defined[name] then
                local def = pick_other(defs[name], framework, header)
                local tag_pointer = def and def.kind == "typedef" and string.match(def.row[COL.type], "^struct [^%s]+ %*$")
                if tag_pointer and def.framework == framework and reaches(def.header, header) then
                    if not inlined[header .. "|" .. name] then
                        inlined[header .. "|" .. name] = true
                        local avail_of = availability(def.row[COL.avail])
                        table.insert(block.early, 1, "typedef " .. declare(def.row[COL.type], name, def.row[COL.nullability])
                            .. suffix_of(avail_of) .. ";")
                    end
                else
                    local line = def and import_of(def, framework, header, usr_dirs)
                    if line then imports[#imports + 1] = line end
                end
            end
            local generic_use = entry.forward and string.sub(entry.forward, 1, 8) == "generic:"
            local forwarded = entry.forwards or {}
            if forwarded.class and not value_name and not generic_use then
                forwards[#forwards + 1] = "@class " .. name .. ";"
            end
            if forwarded.protocol and (not value_name or defined_as(defs, name, "protocol")) and not generic_use then
                forwards[#forwards + 1] = "@protocol " .. name .. ";"
            end
            if generic_use and not value_name then
                local def = generic_definition(defs, name, framework)
                assert(def and def.typeparams ~= "-", "a generic use of " .. name .. " with no generic definition in the IR")
                local params = type_parameters_of(def.typeparams, {}, defs)
                generic_forwards[#generic_forwards + 1] = "@class " .. name .. "<" .. table.concat(params, ", ") .. ">;"
            end
        end
        local head, seen = {}, {}
        for _, line in ipairs(imports) do
            if not seen[line] then
                seen[line] = true
                head[#head + 1] = line
            end
        end
        if #head > 0 and #forwards + #generic_forwards > 0 then head[#head + 1] = "" end
        for _, line in ipairs(forwards) do head[#head + 1] = line end
        for _, line in ipairs(generic_forwards) do head[#head + 1] = line end
        local parts = {}
        if #head > 0 then parts[#parts + 1] = table.concat(head, "\n") end
        local bodies = {}
        for _, text in ipairs(block.early) do bodies[#bodies + 1] = text end
        for _, text in ipairs(block.text) do bodies[#bodies + 1] = text end
        parts[#parts + 1] = table.concat(bodies, "\n\n")
        local lead = file_local[header] and "" or (SYSTEM_HEADER .. "\n")
        files["Headers/" .. header] = lead .. table.concat(parts, "\n\n") .. "\n"
    end

    if not has_map and #headers == 0 and has_sdk_headers then
        files["Headers/" .. base .. ".h"] = SYSTEM_HEADER .. "\n"
        counts.placeholder = true
    end
    if not has_map and files["Headers/" .. base .. ".h"] == nil then
        local nested = {}
        for _, header in ipairs(headers) do
            if string.find(header, "/", 1, true) then nested[#nested + 1] = '#import "' .. header .. '"' end
        end
        if #nested > 0 then
            files["Headers/" .. base .. ".h"] = SYSTEM_HEADER .. "\n" .. table.concat(nested, "\n") .. "\n"
            counts.generated_umbrella = true
        end
    end
    if has_map then
        local umbrella = base .. ".h"
        if files["Headers/" .. umbrella] == nil then
            local lines = {}
            for _, header in ipairs(headers) do lines[#lines + 1] = '#import "' .. header .. '"' end
            files["Headers/" .. umbrella] = SYSTEM_HEADER .. "\n" .. table.concat(lines, "\n") .. "\n"
            counts.generated_umbrella = true
        end
        local map = {"framework module " .. base .. " {", '  umbrella header "' .. umbrella .. '"', "  export *"}
        for _, header in ipairs(headers) do
            if header ~= umbrella then map[#map + 1] = '  header "' .. header .. '"' end
        end
        map[#map + 1] = "}"
        files["Modules/module.modulemap"] = table.concat(map, "\n") .. "\n"
    end
    counts.files = 0
    for path_name, text in pairs(files) do
        counts.files = counts.files + 1
        local _, newlines = string.gsub(text, "\n", "\n")
        counts.lines = (counts.lines or 0) + newlines
    end
    return {files = files, counts = counts}
end

local function location_free(usr)
    return (string.gsub(usr, "(@[US]@[^@]+)@%d+", "%1@*"))
end

local function key_of(row)
    return table.concat({row[COL.kind], location_free(row[COL.usr]), row[COL.container], row[COL.name], row[COL.side]}, "\t")
end

local HASHED = {COL.kind, COL.usr, COL.container, COL.name, COL.side, COL.type, COL.params, COL.nullability, COL.attrs, COL.value}
function declaration_hash(row)
    local parts = {}
    for _, c in ipairs(HASHED) do
        parts[#parts + 1] = (c == COL.usr and location_free(row[c]) or row[c]) .. "\31"
    end
    return string.sub(sha256.hex(table.concat(parts)), 1, 16)
end

local COMPARED = {{COL.avail, "availability"}, {COL.nullability, "nullability"}, {COL.type, "type"}, {COL.params, "params"},
                  {COL.attrs, "attrs"}, {COL.value, "value"}}
local function differing_column(a, b)
    for _, c in ipairs(COMPARED) do
        if a[c[1]] ~= b[c[1]] then return c[2] end
    end
    return "no column"
end

function compare(ir_rows, decl_rows)
    local expected = {}
    local report = {ir = 0, decls = 0, equal = 0, located = 0, causes = {}}
    local function cause(label)
        report.causes[label] = (report.causes[label] or 0) + 1
    end
    for _, row in ipairs(ir_rows) do
        if not BOOKKEEPING[row[COL.kind]] then
            report.ir = report.ir + 1
            local key = key_of(row)
            expected[key] = expected[key] or {}
            table.insert(expected[key], row)
        end
    end
    for _, row in ipairs(decl_rows) do
        if not BOOKKEEPING[row[COL.kind]] then
            report.decls = report.decls + 1
            local list = expected[key_of(row)]
            if list and #list > 0 then
                local ir = table.remove(list, 1)
                if declaration_hash(ir) == declaration_hash(row) then
                    report.equal = report.equal + 1
                    if location_free(row[COL.usr]) ~= row[COL.usr] then report.located = report.located + 1 end
                else
                    cause("declhash differs, " .. row[COL.kind] .. ": " .. differing_column(ir, row))
                end
            else
                cause("extra from decls, " .. row[COL.kind])
            end
        end
    end
    for _, list in pairs(expected) do
        for _, ir in ipairs(list) do cause("missing from decls, " .. ir[COL.kind]) end
    end
    return report
end

function rows_of(text)
    local rows = {}
    for line in string.gmatch(text, "[^\n]+") do
        local row = split_cells(line, 16)
        row[COL.typeparams], row[COL.anon], row[COL.category] = string.match(line, "\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
        rows[#rows + 1] = row
    end
    return rows
end
