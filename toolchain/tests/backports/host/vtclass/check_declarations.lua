local V = import("vtlib", {rootdir = os.scriptdir()})

local function is_ws(b)
    return b == 32 or (b >= 9 and b <= 13) or (b >= 28 and b <= 31)
end

local function is_word(b)
    return (b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or b == 95
end

local function byte_at(s, i)
    if i > #s then
        return -1
    end
    return string.byte(s, i)
end

local function collapse(s)
    local out = {}
    for token in string.gmatch(s, "[^ \t\n\v\f\r\28\29\30\31]+") do
        out[#out + 1] = token
    end
    return table.concat(out, " ")
end

local function strip_py(s)
    local i, j = 1, #s
    while i <= j and is_ws(byte_at(s, i)) do
        i = i + 1
    end
    while j >= i and is_ws(byte_at(s, j)) do
        j = j - 1
    end
    return string.sub(s, i, j)
end

local LITERALS = {
    "NS_REFINED_FOR_SWIFT", "NS_SWIFT_NAME", "NS_SWIFT_UNAVAILABLE", "NS_SWIFT_SENDABLE",
    "API_DEPRECATED_WITH_REPLACEMENT", "NS_UNAVAILABLE", "NS_DESIGNATED_INITIALIZER",
}

local function alternative_end(d, q)
    if string.sub(d, q, q + 3) == "API_" then
        local r = q + 4
        while true do
            local b = byte_at(d, r)
            if (b >= 65 and b <= 90) or b == 95 then
                r = r + 1
            else
                break
            end
        end
        if r > q + 4 then
            return r
        end
    end
    for _, literal in ipairs(LITERALS) do
        if string.sub(d, q, q + #literal - 1) == literal then
            return q + #literal
        end
    end
    return nil
end

local function paren_end(d, w)
    local i = w + 1
    while true do
        local b = byte_at(d, i)
        if b == -1 then
            return nil
        end
        if b == 41 then
            return i + 1
        end
        if b == 40 then
            local j = i + 1
            while true do
                local c = byte_at(d, j)
                if c == -1 or c == 40 or c == 41 then
                    break
                end
                j = j + 1
            end
            if byte_at(d, j) ~= 41 then
                return nil
            end
            i = j + 1
        else
            i = i + 1
        end
    end
end

local function trailing_at(d, p)
    local q = p
    while is_ws(byte_at(d, q)) do
        q = q + 1
    end
    local r = alternative_end(d, q)
    if not r then
        return nil
    end
    local w = r
    while is_ws(byte_at(d, w)) do
        w = w + 1
    end
    if byte_at(d, w) == 40 then
        local stop = paren_end(d, w)
        if stop then
            return stop
        end
    end
    return w
end

local function find_trailing(d)
    for p = 1, #d do
        local stop = trailing_at(d, p)
        if stop then
            return p, stop
        end
    end
    return nil
end

local function strip(declaration)
    while true do
        local p, stop = find_trailing(declaration)
        if not p then
            break
        end
        declaration = string.sub(declaration, 1, p - 1) .. string.sub(declaration, stop)
    end
    return collapse(declaration)
end

local function normalise(type_name)
    type_name = type_name:gsub("%s*<%s*", "<"):gsub("%s*>", ">")
    local i = #type_name
    while i >= 1 do
        local b = byte_at(type_name, i)
        if is_ws(b) or b == 42 then
            i = i - 1
        else
            break
        end
    end
    local core = string.sub(type_name, 1, i)
    local run = string.sub(type_name, i + 1)
    local replacement = ""
    if string.find(run, "*", 1, true) then
        replacement = " *"
    end
    return strip_py(core .. replacement)
end

local function split_property(s)
    local n = #s
    local w0 = n + 1
    while w0 > 1 and is_word(byte_at(s, w0 - 1)) do
        w0 = w0 - 1
    end
    if w0 > n then
        return nil
    end
    local j, stars = w0, 0
    while j > 1 do
        local b = byte_at(s, j - 1)
        if is_ws(b) then
            j = j - 1
        elseif b == 42 and stars == 0 then
            stars = 1
            j = j - 1
        else
            break
        end
    end
    return string.sub(s, 1, j - 1), (stars == 1 and "*" or ""), string.sub(s, w0)
end

local function trailing_word(s)
    local e = #s
    while e >= 1 and is_ws(byte_at(s, e)) do
        e = e - 1
    end
    local w = e
    while w >= 1 and is_word(byte_at(s, w)) do
        w = w - 1
    end
    if w == e then
        return nil
    end
    return string.sub(s, w + 1, e)
end

local function property_decls(text)
    local out = {}
    local p = 1
    while true do
        local c = string.find(text, "@property", p, true)
        if not c then
            break
        end
        local q = c + 9
        while is_ws(byte_at(text, q)) do
            q = q + 1
        end
        local matched = false
        if byte_at(text, q) == 40 then
            local rp = string.find(text, ")", q + 1, true)
            if rp then
                local sp = string.find(text, ";", rp + 1, true)
                if sp then
                    out[#out + 1] = {attrs = string.sub(text, q + 1, rp - 1), decl = string.sub(text, rp + 1, sp - 1)}
                    p = sp + 1
                    matched = true
                end
            end
        end
        if not matched then
            p = c + 1
        end
    end
    return out
end

local function method_decls(text)
    local out = {}
    local p = 1
    while true do
        local c = string.find(text, "[%-%+]", p)
        if not c then
            break
        end
        local kind = string.sub(text, c, c)
        local q = c + 1
        while is_ws(byte_at(text, q)) do
            q = q + 1
        end
        local matched = false
        if byte_at(text, q) == 40 then
            local rp = string.find(text, ")", q + 1, true)
            if rp then
                local sp = string.find(text, ";", rp + 1, true)
                if sp then
                    out[#out + 1] = {kind = kind, decl = string.sub(text, rp + 1, sp - 1)}
                    p = sp + 1
                    matched = true
                end
            end
        end
        if not matched then
            p = c + 1
        end
    end
    return out
end

local function keyword_parts(cleaned)
    local out = {}
    local i = 1
    while i <= #cleaned do
        local j = i
        while is_word(byte_at(cleaned, j)) do
            j = j + 1
        end
        local advanced = false
        if j > i and byte_at(cleaned, j) == 58 then
            local q = j + 1
            while is_ws(byte_at(cleaned, q)) do
                q = q + 1
            end
            if byte_at(cleaned, q) == 40 then
                local rp = string.find(cleaned, ")", q + 1, true)
                if rp then
                    out[#out + 1] = {string.sub(cleaned, i, j - 1), string.sub(cleaned, q + 1, rp - 1)}
                    i = rp + 1
                    advanced = true
                end
            end
        end
        if not advanced then
            i = i + 1
        end
    end
    return out
end

local function protocol_blocks(text)
    local out = {}
    local p = 1
    while true do
        local c = string.find(text, "@protocol", p, true)
        if not c then
            break
        end
        local matched = false
        local q = c + 9
        local after_keyword = q
        while is_ws(byte_at(text, q)) do
            q = q + 1
        end
        if q > after_keyword and string.sub(text, q, q + 1) == "VT" then
            local r = q + 2
            while is_word(byte_at(text, r)) do
                r = r + 1
            end
            if r > q + 2 then
                local name = string.sub(text, q, r - 1)
                local s = r
                while is_ws(byte_at(text, s)) do
                    s = s + 1
                end
                local body, stop
                if byte_at(text, s) == 60 then
                    local gt = string.find(text, ">", s + 1, true)
                    if gt then
                        local e = string.find(text, "@end", gt + 1, true)
                        if e then
                            body, stop = string.sub(text, gt + 1, e - 1), e + 4
                        end
                    end
                end
                if not body then
                    local e = string.find(text, "@end", s, true)
                    if e then
                        body, stop = string.sub(text, s, e - 1), e + 4
                    end
                end
                if body then
                    out[#out + 1] = {name = name, body = body}
                    p = stop
                    matched = true
                end
            end
        end
        if not matched then
            p = c + 1
        end
    end
    return out
end

local function interface_blocks(text)
    local out = {}
    local p = 1
    while true do
        local c = string.find(text, "@interface", p, true)
        if not c then
            break
        end
        local matched = false
        local q = c + 10
        local after_keyword = q
        while is_ws(byte_at(text, q)) do
            q = q + 1
        end
        if q > after_keyword and string.sub(text, q, q + 1) == "VT" then
            local r = q + 2
            while is_word(byte_at(text, r)) do
                r = r + 1
            end
            if r > q + 2 then
                local name = string.sub(text, q, r - 1)
                local s = r
                while is_ws(byte_at(text, s)) do
                    s = s + 1
                end
                local angle, body, stop
                if byte_at(text, s) == 58 then
                    local t = s + 1
                    while is_ws(byte_at(text, t)) do
                        t = t + 1
                    end
                    local u = t
                    while is_word(byte_at(text, u)) do
                        u = u + 1
                    end
                    if u > t then
                        local v = u
                        while is_ws(byte_at(text, v)) do
                            v = v + 1
                        end
                        local group_end = v
                        if byte_at(text, v) == 60 then
                            local gt = string.find(text, ">", v + 1, true)
                            if gt then
                                group_end = gt + 1
                            end
                        end
                        local e = string.find(text, "@end", group_end, true)
                        if e then
                            angle, body, stop = string.sub(text, s, group_end - 1), string.sub(text, group_end, e - 1), e + 4
                        end
                    end
                end
                if not body then
                    local e = string.find(text, "@end", s, true)
                    if e then
                        angle, body, stop = "", string.sub(text, s, e - 1), e + 4
                    end
                end
                if body then
                    out[#out + 1] = {name = name, angle = angle, body = body}
                    p = stop
                    matched = true
                end
            end
        end
        if not matched then
            p = c + 1
        end
    end
    return out
end

local function split_commas(s)
    local out = {}
    local start = 1
    while true do
        local c = string.find(s, ",", start, true)
        if not c then
            out[#out + 1] = string.sub(s, start)
            break
        end
        out[#out + 1] = string.sub(s, start, c - 1)
        start = c + 1
    end
    return out
end

local function parse(text)
    local protocols = {}
    for _, block in ipairs(protocol_blocks(text)) do
        local entry = protocols[block.name]
        if not entry then
            entry = {properties = {}, instance = {}, class = {}}
            protocols[block.name] = entry
        end
        for _, d in ipairs(property_decls(block.body)) do
            local g1, g2, g3 = split_property(strip(d.decl))
            if g1 then
                entry.properties[g3] = strip_py(g1) .. (g2 == "*" and " *" or "")
            end
        end
    end

    local classes = {}
    for _, block in ipairs(interface_blocks(text)) do
        local name, body = block.name, block.body
        local entry = classes[name]
        if not entry then
            entry = {properties = {}, instance = {}, class = {}, unavailable = {}}
            classes[name] = entry
        end
        local conformances = {}
        local lt = string.find(block.angle, "<", 1, true)
        if lt then
            local gt = string.find(block.angle, ">", lt + 1, true)
            if gt then
                for _, piece in ipairs(split_commas(string.sub(block.angle, lt + 1, gt - 1))) do
                    conformances[#conformances + 1] = strip_py(piece)
                end
            end
        end

        for _, d in ipairs(property_decls(body)) do
            local unavailable = string.find(d.decl, "API_UNAVAILABLE(ios)", 1, true) ~= nil
            local g1, g2, g3 = split_property(strip(d.decl))
            if g1 then
                local type_name = strip_py(g1) .. (g2 == "*" and " *" or "")
                if unavailable then
                    entry.unavailable[g3] = true
                else
                    entry.properties[g3] = type_name
                end
            end
        end

        for _, proto in ipairs(conformances) do
            local protocol = protocols[proto]
            if protocol then
                for prop, type_name in pairs(protocol.properties) do
                    if entry.properties[prop] == nil then
                        entry.properties[prop] = type_name
                    end
                end
            end
        end

        for _, d in ipairs(method_decls(body)) do
            local kind, decl = d.kind, d.decl
            local unavailable = string.find(decl, "NS_UNAVAILABLE", 1, true) ~= nil
            local cleaned = strip(decl)
            local colon = string.find(cleaned, ":", 1, true)
            local return_type
            if colon then
                return_type = normalise(string.sub(cleaned, 1, colon - 1))
            else
                return_type = normalise(cleaned)
            end
            local parts = keyword_parts(cleaned)
            local selector, types
            if #parts > 0 then
                selector = ""
                types = {}
                for _, part in ipairs(parts) do
                    selector = selector .. part[1] .. ":"
                    types[#types + 1] = normalise(part[2])
                end
            else
                selector = trailing_word(cleaned)
                types = {}
            end
            if selector then
                local bucket = kind == "+" and entry.class or entry.instance
                bucket[selector] = {types = types, ret = return_type}
                if unavailable then
                    entry.unavailable_methods = entry.unavailable_methods or {}
                    entry.unavailable_methods[selector] = true
                end
            end
        end
    end
    return classes
end

local function list_repr(items)
    if #items == 0 then
        return "none"
    end
    local parts = {}
    for _, item in ipairs(items) do
        parts[#parts + 1] = V.py_repr(item)
    end
    return "[" .. table.concat(parts, ", ") .. "]"
end

local function same_types(a, b)
    if #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

local function first_part(selector)
    return string.match(selector, "^([^:]*)")
end

local function check_class(name, p, s, unavailable_methods, out)
    for _, prop in ipairs(V.sorted_keys(s.properties)) do
        if not s.unavailable[prop] then
            local type_name = s.properties[prop]
            local got = p.properties[prop]
            if got == nil then
                out.missing[#out.missing + 1] = string.format("%s.%s: a property SDK 26.2 declares, the port does not", name, prop)
            elseif got ~= type_name then
                out.mismatch[#out.mismatch + 1] = string.format("%s.%s: the port has %s and the SDK has %s",
                    name, prop, V.py_repr(got), V.py_repr(type_name))
            end
        end
    end
    for _, prop in ipairs(V.sorted_keys(p.properties)) do
        if s.properties[prop] == nil then
            out.extra[#out.extra + 1] = string.format("%s.%s: a property the port declares and the SDK does not", name, prop)
        end
    end
    for _, bucket in ipairs({"instance", "class"}) do
        local dash = bucket == "instance" and "-" or "+"
        for _, selector in ipairs(V.sorted_keys(s[bucket])) do
            local sdk_method = s[bucket][selector]
            if unavailable_methods[selector] then
                out.omitted[#out.omitted + 1] = string.format("%s %s%s: NS_UNAVAILABLE, so not carried, and the ledger has a row",
                    name, dash, selector)
            else
                local got = p[bucket][selector]
                if got ~= nil then
                    if not same_types(got.types, sdk_method.types) then
                        out.mismatch[#out.mismatch + 1] = string.format("%s %s%s: the port declares %d argument(s) %s and the SDK %d %s",
                            name, dash, selector, #got.types, list_repr(got.types), #sdk_method.types, list_repr(sdk_method.types))
                    elseif got.ret ~= sdk_method.ret then
                        out.mismatch[#out.mismatch + 1] = string.format("%s %s%s: the port returns %s and the SDK returns %s",
                            name, dash, selector, V.py_repr(got.ret), V.py_repr(sdk_method.ret))
                    end
                else
                    local getter_type = s.properties[first_part(selector)]
                    if not getter_type or getter_type == "" then
                        out.missing[#out.missing + 1] = string.format("%s %s%s: a method SDK 26.2 declares, the port does not",
                            name, dash, selector)
                    end
                end
            end
        end
        for _, selector in ipairs(V.sorted_keys(p[bucket])) do
            if s[bucket][selector] == nil and s.properties[first_part(selector)] == nil then
                out.extra[#out.extra + 1] = string.format("%s %s%s: a method the port declares and the SDK does not",
                    name, dash, selector)
            end
        end
    end
    for _, prop in ipairs(V.sorted_keys(s.unavailable)) do
        if s.properties[prop] ~= nil and p.properties[prop] == nil then
            out.omitted[#out.omitted + 1] = string.format("%s.%s: API_UNAVAILABLE(ios), so not carried, and the ledger has a row",
                name, prop)
        end
    end
end

local function read_or_fail(reader, path)
    local text
    try {
        function()
            text = reader(path)
        end,
        catch {
            function(err)
                V.fail("check_declarations.lua: cannot read " .. path .. ": " .. tostring(err))
            end
        }
    }
    return text
end

function main(...)
    local argv = {...}
    local quiet = false
    for _, a in ipairs(argv) do
        if a == "--quiet" then
            quiet = true
        end
    end
    local sdk
    if argv[1] ~= nil and string.sub(argv[1], 1, 1) ~= "-" then
        sdk = argv[1]
    else
        sdk = os.getenv("VT_SDK") or ""
    end
    if sdk == "" then
        V.fail("check_declarations.lua: pass an iPhoneOS*.sdk or set VT_SDK")
    end

    local headers = V.join_path(sdk, "System/Library/Frameworks/VideoToolbox.framework/Headers")
    local sdk_text = read_or_fail(V.header_text, headers)

    local port_header = os.scriptdir() .. "/../../../../packages/frameworks/apple-backports/VideoToolbox/RevenantVideoToolbox.h"
    local port = parse(read_or_fail(V.read_text, port_header))
    local sdk_classes = parse(sdk_text)

    local out = {mismatch = {}, missing = {}, extra = {}, omitted = {}}
    local union = {}
    for name in pairs(port) do
        union[name] = true
    end
    for name in pairs(sdk_classes) do
        union[name] = true
    end
    for _, name in ipairs(V.sorted_keys(union)) do
        local p, s = port[name], sdk_classes[name]
        local unavailable_methods = (s and s.unavailable_methods) or {}
        if p == nil then
            out.missing[#out.missing + 1] = name .. ": the port declares no such class"
        elseif s == nil then
            out.extra[#out.extra + 1] = name .. ": declared in the port and in no SDK header"
        else
            check_class(name, p, s, unavailable_methods, out)
        end
    end

    for _, group in ipairs({{"MISMATCH", out.mismatch}, {"EXTRA", out.extra}}) do
        for _, line in ipairs(group[2]) do
            print(group[1] .. " " .. line)
        end
    end
    if not quiet then
        for _, line in ipairs(out.missing) do
            print("NOT YET " .. line)
        end
    end
    if not quiet then
        for _, line in ipairs(out.omitted) do
            print("OMITTED " .. line)
        end
    end

    local members = 0
    for _, entry in pairs(port) do
        members = members + V.count_entries(entry.properties) + V.count_entries(entry.instance)
            + V.count_entries(entry.class)
    end
    print(string.format("check_declarations.lua: %d properties and methods over %d classes; %d MISMATCH, %d EXTRA "
        .. "(the two that fail it); %d declared by the SDK and not yet carried, %d omitted as "
        .. "unavailable on iOS",
        members, V.count_entries(port), #out.mismatch, #out.extra, #out.missing, #out.omitted))
    if #out.mismatch + #out.extra > 0 then
        print("the port's declarations do NOT match SDK 26.2's")
        os.exit(1)
    end
    print("the port's declarations match SDK 26.2's: every selector, every argument count, every type")
end
