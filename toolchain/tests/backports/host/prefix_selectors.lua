import("core.base.json")

local SCRIPT_DIR = os.scriptdir()
local RUNS = path.normalize(path.join(SCRIPT_DIR, "..", "..", "..", ".agent-work", "runs", "prefix-selectors"))
os.mkdir(RUNS)

local FAMILIES = {"mutableCopy", "copy", "init", "new", "alloc"}
local RUNTIME_HOOKS = {load = true, initialize = true}

local function ch(s, p)
    return s:sub(p + 1, p + 1)
end

local function slice(s, a, b)
    return s:sub(a + 1, b)
end

local function find0(s, needle, a)
    local p = s:find(needle, a + 1, true)
    return p and (p - 1) or nil
end

local function rfind0(s, needle, stop)
    local last, i = nil, 0
    while true do
        local p = s:find(needle, i + 1, true)
        if not p or (p - 1) + #needle > stop then
            break
        end
        last = p - 1
        i = p
    end
    return last
end

local function is_word(c)
    return c ~= "" and c:match("^[%w_]$") ~= nil
end

local function is_space(c)
    return c ~= "" and c:match("^%s$") ~= nil
end

local function strip(text)
    return (text:match("^%s*(.-)%s*$"))
end

local function replace_all(text, old, new)
    local out, i = {}, 1
    while true do
        local a, b = text:find(old, i, true)
        if not a then
            break
        end
        table.insert(out, text:sub(i, a - 1))
        table.insert(out, new)
        i = b + 1
    end
    table.insert(out, text:sub(i))
    return table.concat(out)
end

local function split(text, sep)
    local out, i = {}, 1
    while true do
        local a, b = text:find(sep, i, true)
        if not a then
            break
        end
        table.insert(out, text:sub(i, a - 1))
        i = b + 1
    end
    table.insert(out, text:sub(i))
    return out
end

local function starts(text, prefix)
    return text:sub(1, #prefix) == prefix
end

local function upper_first(text)
    return text:sub(1, 1):upper() .. text:sub(2)
end

local function set_of(list)
    local out = {}
    for _, item in ipairs(list) do
        out[item] = true
    end
    return out
end

local function sorted_keys(set)
    local out = {}
    for key in pairs(set) do
        table.insert(out, key)
    end
    table.sort(out)
    return out
end

local function same_set(a, b)
    for key in pairs(a) do
        if not b[key] then
            return false
        end
    end
    for key in pairs(b) do
        if not a[key] then
            return false
        end
    end
    return true
end

local function dig(node, ...)
    local value = node
    for _, key in ipairs({...}) do
        if type(value) ~= "table" then
            return nil
        end
        value = value[key]
    end
    return value
end

local function is_empty(tbl)
    for _ in pairs(tbl) do
        return false
    end
    return true
end

local function digest(text)
    local scratch = path.join(RUNS, "digest-key.txt")
    io.writefile(scratch, text)
    return hash.sha256(scratch)
end

local function join_key(words)
    return table.concat(words, "\\0")
end

local function object_end(text, open)
    local depth, pos = 0, open
    while true do
        local at = text:find('[{}"]', pos)
        if not at then
            return nil
        end
        if text:sub(at, at) == '"' then
            local p = at + 1
            while true do
                local q = text:find('["\\]', p)
                if not q then
                    return nil
                end
                if text:sub(q, q) == "\\" then
                    p = q + 2
                else
                    at = q
                    break
                end
            end
            pos = at + 1
        else
            depth = depth + (text:sub(at, at) == "{" and 1 or -1)
            if depth == 0 then
                return at
            end
            pos = at + 1
        end
    end
end

local function documents(text)
    local out, pos = {}, 1
    while true do
        local open = text:find("{", pos, true)
        if not open then
            return out
        end
        local stop = object_end(text, open)
        if not stop then
            return out
        end
        table.insert(out, json.decode(text:sub(open, stop)))
        pos = stop + 1
    end
end

local function cached_json(file)
    if not os.isfile(file) then
        return nil
    end
    return try { function () return json.decode(io.readfile(file)) end }
end

local function write_json(file, value)
    io.writefile(file, json.encode(value))
end

local function clang_dump(flags, source_path, filter)
    local args = {"clang"}
    for _, flag in ipairs(flags) do
        table.insert(args, flag)
    end
    for _, word in ipairs({"-fsyntax-only", "-w", "-Xclang", "-ast-dump=json"}) do
        table.insert(args, word)
    end
    if filter then
        table.insert(args, "-Xclang")
        table.insert(args, "-ast-dump-filter=haron")
    end
    table.insert(args, source_path)
    return os.iorunv("xcrun", args)
end

local function nm_lines(objects)
    local args = {"nm"}
    for _, object in ipairs(objects) do
        table.insert(args, object)
    end
    return os.iorunv("xcrun", args)
end

local function words_of(line)
    local out = {}
    for word in line:gmatch("%S+") do
        table.insert(out, word)
    end
    return out
end

local function ported_classes(objects)
    local classes = {}
    for line in nm_lines(objects):gmatch("[^\n]+") do
        local parts = words_of(line)
        if #parts == 3 and parts[2] ~= "U" and starts(parts[3], "_OBJC_CLASS_$_") then
            classes[parts[3]:sub(#"_OBJC_CLASS_$_" + 1)] = true
        end
    end
    return classes
end

local function revenant_members(text)
    local found = {}
    for at in text:gmatch("()[-+]%[") do
        local kind = text:sub(at, at)
        local owner = text:match("^([%w_]+)%(Revenant[%w_]*%) ", at + 2)
        local selector = text:match("^[%w_]+%(Revenant[%w_]*%) ([%w_:]+)%]", at + 2)
        if owner and selector then
            table.insert(found, {kind, owner, selector})
        end
    end
    return found
end

local function is_runtime_hook(kind, selector)
    return kind == "+" and RUNTIME_HOOKS[selector] == true
end

local function ported(objects)
    local names = nm_lines(objects)
    local own = ported_classes(objects)
    local found, seen = {}, {}
    for _, member in ipairs(revenant_members(names)) do
        local kind, owner, selector = member[1], member[2], member[3]
        if not own[owner] and not is_runtime_hook(kind, selector) then
            local key = kind .. "\0" .. owner .. "\0" .. selector
            if not seen[key] then
                seen[key] = true
                table.insert(found, member)
            end
        end
    end
    return found
end

local function strip_availability(text)
    local head = text:match("^API_[A-Z_]+") or text:match("^NS_[A-Z_]+")
    local at
    if head then
        at = #head
    elseif starts(text, "__attribute__") then
        at = #"__attribute__"
    else
        return text
    end
    local function skip_space(p)
        while p < #text and is_space(text:sub(p + 1, p + 1)) do
            p = p + 1
        end
        return p
    end
    local p = skip_space(at)
    while text:sub(p + 1, p + 1) == "(" do
        local depth, q, closed = 1, p + 2, false
        while q <= #text do
            local c = text:sub(q, q)
            if c == "(" then
                if depth == 2 then
                    break
                end
                depth = 2
            elseif c == ")" then
                if depth == 2 then
                    depth = 1
                else
                    closed = true
                    break
                end
            end
            q = q + 1
        end
        if not closed then
            break
        end
        p = skip_space(q)
    end
    return text:sub(p + 1)
end

local function bare(qualified)
    local text = qualified
    text = replace_all(text, "__kindof", "")
    text = replace_all(text, "_Nonnull", "")
    text = replace_all(text, "_Nullable", "")
    text = replace_all(text, "*", "")
    text = replace_all(text, "const", "")
    while true do
        local open = text:find("<", 1, true)
        local close = open and text:find(">", open + 1, true)
        if not close then
            break
        end
        text = text:sub(1, open - 1) .. text:sub(close + 1)
    end
    text = strip(text)
    while true do
        local stripped = strip(strip_availability(text))
        if stripped == text then
            return text
        end
        text = stripped
    end
end

local function named(qualified)
    local pos = 1
    while true do
        local open = qualified:find("<", pos, true)
        if not open then
            break
        end
        local close = qualified:find("[<>]", open + 1)
        if close and qualified:sub(close, close) == ">" and close > open + 1 then
            return strip(qualified:sub(open + 1, close - 1))
        end
        pos = open + 1
    end
    return bare(qualified)
end

local function prefixed(keyword, prefix)
    for _, family in ipairs(FAMILIES) do
        local rest = keyword:sub(#family + 1)
        if starts(keyword, family) and (rest == "" or rest:sub(1, 1):match("%u")) then
            local middle = prefix:sub(1, 1):upper() .. strip_trailing_underscores(prefix:sub(2))
            return family .. middle .. rest
        end
    end
    if prefix:sub(-1) == "_" then
        return prefix .. keyword
    end
    return prefix .. upper_first(keyword)
end

function strip_trailing_underscores(text)
    return (text:gsub("_+$", ""))
end

local function spelled(type_node)
    local qualified = type_node.qualType or ""
    if starts(qualified, "instancetype") then
        return qualified
    end
    return type_node.desugaredQualType or qualified
end

local QUALIFIERS = {_Nullable = true, _Nonnull = true, __nullable = true, __nonnull = true,
                    nullable = true, nonnull = true, null_unspecified = true}

local function declared(text)
    local word, rest = text:match("^(%S+)%s+(.*)$")
    if word and QUALIFIERS[word] then
        text = rest
    end
    if text:find("*", 1, true) then
        local base = strip(replace_all(text, "*", " ")):match("^[%w_]*")
        if starts(base, "Revenant") then
            return "id"
        end
    end
    return text
end

local function declaration(sign, node, prefix)
    local keywords = split(node.name, ":")
    local parameters = {}
    for _, item in ipairs(node.inner or {}) do
        if item.kind == "ParmVarDecl" then
            table.insert(parameters, item)
        end
    end
    local head = string.format("%s (%s)", sign, declared(spelled(node.returnType)))
    if #parameters == 0 then
        return head .. prefixed(node.name, prefix)
    end
    local parts = {}
    for index, parameter in ipairs(parameters) do
        local keyword = keywords[index]
        if index == 1 then
            keyword = prefixed(keyword, prefix)
        end
        local name = parameter.name or ("value" .. (index - 1))
        table.insert(parts, string.format("%s:(%s)%s", keyword, declared(spelled(parameter.type)), name))
    end
    return head .. table.concat(parts, " ")
end

local function framework_headers(flags)
    local roots, seen = {}, {}
    local function add(root)
        if not seen[root] then
            seen[root] = true
            table.insert(roots, root)
        end
    end
    for index, word in ipairs(flags) do
        if (word == "-iframework" or word == "-F") and flags[index + 1] then
            add(flags[index + 1])
        elseif word == "-isysroot" and flags[index + 1] then
            add(path.join(flags[index + 1], "System", "Library", "Frameworks"))
        end
    end
    table.sort(roots)
    local out = {}
    for _, root in ipairs(roots) do
        for _, framework in ipairs(os.dirs(path.join(root, "*"))) do
            for _, header in ipairs(os.files(path.join(framework, "Headers", "*.h"))) do
                table.insert(out, header)
            end
        end
    end
    return out
end

local function header_superclasses(flags)
    local unique = {}
    for index, word in ipairs(flags) do
        if (word == "-iframework" or word == "-F") and flags[index + 1] then
            unique[flags[index + 1]] = true
        end
    end
    local cache = path.join(RUNS, "revenant-prefix-superclasses-" .. digest(join_key(sorted_keys(unique))):sub(1, 16) .. ".json")
    local stored = cached_json(cache)
    if stored then
        return stored
    end
    local found = {}
    for _, header in ipairs(framework_headers(flags)) do
        local text = os.isfile(header) and io.readfile(header) or ""
        local pos = 1
        while true do
            local a, b, name, parent = text:find("@interface%s+([%a_][%w_]*)%s*:%s*([%a_][%w_]*)", pos)
            if not a then
                break
            end
            if not found[name] then
                found[name] = parent
            end
            pos = b + 1
        end
    end
    write_json(cache, found)
    return found
end

local function make_chain(declared_map)
    return {declared = declared_map, asked = {}, parent = {}}
end

local function chain_get(chain, name)
    if name == nil then
        return nil
    end
    if not chain.asked[name] then
        chain.asked[name] = true
        chain.parent[name] = chain.declared[name] or false
    end
    return chain.parent[name] or nil
end

local function chain_has(chain, name)
    return chain.asked[name] == true
end

local function header_conformers(flags, classes)
    local keyed = {}
    for _, flag in ipairs(flags) do
        if starts(flag, "-") then
            table.insert(keyed, flag)
        end
    end
    local wanted = sorted_keys(classes)
    for _, name in ipairs(wanted) do
        table.insert(keyed, name)
    end
    local cache = path.join(RUNS, "revenant-prefix-headers-" .. digest(join_key(keyed)):sub(1, 16) .. ".json")
    local stored = cached_json(cache)
    if stored then
        return stored
    end
    local found = {}
    for _, header in ipairs(framework_headers(flags)) do
        local text = os.isfile(header) and io.readfile(header) or ""
        for _, name in ipairs(wanted) do
            local pos = 1
            while true do
                local a = text:find("@interface%s+" .. name .. "%f[^%w_]", pos)
                if not a then
                    break
                end
                local stop = text:find("[@{;]", a + 1) or (#text + 1)
                local line = text:sub(a, stop - 1)
                pos = stop
                local opened = line:find("<", 1, true)
                if opened then
                    local close = line:find(">", opened, true)
                    local inside
                    if close then
                        inside = line:sub(opened + 1, close - 1)
                    else
                        inside = line:sub(opened + 1, -2)
                    end
                    for _, piece in ipairs(split(inside, ",")) do
                        local protocol = strip(piece)
                        if protocol ~= "" then
                            found[name] = found[name] or {}
                            table.insert(found[name], protocol)
                        end
                    end
                end
            end
        end
    end
    write_json(cache, found)
    return found
end

local function conformers(sources, flags, classes)
    local keyed = {}
    for _, source in ipairs(sources) do
        table.insert(keyed, source)
    end
    table.sort(keyed)
    for _, flag in ipairs(flags) do
        if starts(flag, "-") then
            table.insert(keyed, flag)
        end
    end
    for _, name in ipairs(sorted_keys(classes)) do
        table.insert(keyed, name)
    end
    local cache = path.join(RUNS, "revenant-prefix-conformers-" .. digest(join_key(keyed)):sub(1, 16) .. ".json")
    local stored = cached_json(cache)
    local owners = {}
    if stored then
        for protocol, members in pairs(stored) do
            owners[protocol] = set_of(members)
        end
        return owners
    end

    local function adopt(name, protocol)
        if name and protocol then
            local key = named(protocol)
            owners[key] = owners[key] or {}
            owners[key][name] = true
        end
    end

    for _, source in ipairs(sources) do
        local dump = clang_dump(flags, source, true)
        for _, document in ipairs(documents(dump)) do
            local visit
            visit = function(node)
                if type(node) ~= "table" then
                    return
                end
                if node.kind == "ObjCInterfaceDecl" or node.kind == "ObjCCategoryDecl" then
                    local name = node.kind == "ObjCInterfaceDecl" and node.name or dig(node, "interface", "name")
                    for _, protocol in ipairs(node.protocols or {}) do
                        adopt(name, protocol.name or protocol.qualType)
                    end
                end
                for _, value in pairs(node) do
                    visit(value)
                end
            end
            visit(document)
        end
    end
    for name, protocols in pairs(header_conformers(flags, classes)) do
        for _, protocol in ipairs(protocols) do
            adopt(name, protocol)
        end
    end
    local out = {}
    for protocol, members in pairs(owners) do
        out[protocol] = sorted_keys(members)
    end
    write_json(cache, out)
    return owners
end

local function carried_index(members)
    local index = {keys = {}, selectors = {}, list = members}
    for _, member in ipairs(members) do
        index.keys[member[1] .. "\0" .. member[2] .. "\0" .. member[3]] = true
        index.selectors[member[3]] = true
    end
    return index
end

local function carried_has(carried, kind, owner, selector)
    return carried.keys[kind .. "\0" .. owner .. "\0" .. selector] == true
end

local Rewriter = {}

local function new_rewriter(source, carried, superclasses, protocol_owners, ported_set, prefix, renames)
    local rewriter = {
        source = source,
        prefix = prefix,
        carried = carried,
        superclasses = superclasses,
        ported_classes = ported_set or {},
        renames = renames or {},
        protocol_owners = protocol_owners or {},
        inserts = {},
        unresolved = {},
        candidates = {},
        signatures = {},
        replacements = {},
    }
    for name, method in pairs(Rewriter) do
        rewriter[name] = method
    end
    return rewriter
end

function Rewriter:original(name)
    if name == nil then
        return nil
    end
    return self.renames[name] or name
end

function Rewriter:owns(kind, receiver, selector)
    while receiver and receiver ~= "" do
        if carried_has(self.carried, kind, receiver, selector) then
            return true
        end
        local conformers = self.protocol_owners[receiver]
        if conformers then
            local owners = {}
            for name in pairs(conformers) do
                if carried_has(self.carried, kind, name, selector) and not self.ported_classes[name] then
                    owners[name] = true
                end
            end
            if is_empty(owners) or not same_set(owners, conformers) then
                return false
            end
            return true
        end
        receiver = chain_get(self.superclasses, receiver)
    end
    return false
end

function Rewriter:keyword_after(offset)
    local p = offset
    while is_space(ch(self.source, p)) do
        p = p + 1
    end
    if ch(self.source, p):match("^[%a_]$") then
        return p
    end
    return nil
end

function Rewriter:class_token_end(start)
    local p = start
    while is_space(ch(self.source, p)) do
        p = p + 1
    end
    if not ch(self.source, p):match("^[%a_]$") then
        error("no class name after the bracket")
    end
    while ch(self.source, p):match("^[%w_]$") do
        p = p + 1
    end
    return p
end

function Rewriter:receiver_class(node, context)
    local kind = node.receiverKind
    if kind == "class" then
        return "+", self:original(bare(node.classType.qualType))
    end
    if kind == "super_instance" or kind == "super_class" or not node.inner or #node.inner == 0 then
        return nil, nil
    end
    local inner = node.inner[1]
    local qualified = self:original(named(inner.type.qualType))
    if self.protocol_owners[qualified] and not chain_has(self.superclasses, qualified) then
        return "-", qualified
    end
    if qualified == "instancetype" or qualified == "id" then
        local target = inner
        while (target.kind == "ImplicitCastExpr" or target.kind == "CStyleCastExpr") and target.inner do
            target = target.inner[1]
        end
        if context and target.kind == "DeclRefExpr" and dig(target, "referencedDecl", "name") == "self" then
            local sign = context[1] == "+" and "+" or "-"
            return sign, self:original(context[2])
        end
        if target.kind == "ObjCMessageExpr" and target.selector == "alloc" then
            local _, owner = self:receiver_class(target, context)
            if owner then
                return "-", self:original(owner)
            end
            return "-", owner
        end
        return "-", nil
    end
    if qualified == "Class" then
        if context then
            return "+", self:original(context[2])
        end
        return "+", nil
    end
    return "-", qualified
end

function Rewriter:word_between(word, begin, stop)
    local s = self.source
    local p = begin
    while p + #word <= stop do
        if slice(s, p, p + #word) == word then
            local before = p > 0 and ch(s, p - 1) or ""
            local after = ""
            if p + #word < stop then
                after = ch(s, p + #word)
            end
            if not is_word(before) and not is_word(after) then
                return p
            end
        end
        p = p + 1
    end
    return nil
end

local function stop_of(node)
    local stop = dig(node, "range", "end")
    return stop.offset + (stop.tokLen or 1)
end

function Rewriter:rename_instance_send(node, receiver, selector)
    local offset = node.range.begin.offset
    local begin
    if slice(self.source, offset, offset + 1) == "[" then
        begin = offset + 1
    else
        local opened = rfind0(self.source, "[", offset)
        begin = opened and (opened + 1) or offset
    end
    local first = split(selector, ":")[1]
    local stop = stop_of(node)
    local match = self:word_between(first, begin, stop)
    if not match then
        table.insert(self.unresolved, {offset, string.format("%s, whose first keyword the rewrite cannot find", selector)})
        return
    end
    local as_send = false
    if self.protocol_owners[receiver] and node.inner then
        local span = node.inner[1].range
        local start = span.begin.offset
        local receiver_end = start + (span["end"].tokLen or 1)
        if receiver_end < #self.source and ch(self.source, receiver_end) == "." then
            self.replacements[start] = {stop, string.format("[(id)(%s) %s]",
                                                           slice(self.source, start, receiver_end),
                                                           prefixed(selector, self.prefix))}
            as_send = true
        else
            self.replacements[start] = {receiver_end, string.format("((id)%s)", slice(self.source, start, receiver_end))}
        end
    end
    if not as_send then
        self.inserts[match] = true
    end
end

function Rewriter:walk(node, context)
    if type(node) ~= "table" then
        return
    end
    if node[1] ~= nil and node.kind == nil then
        for _, item in ipairs(node) do
            self:walk(item, context)
        end
        return
    end
    if dig(node, "range", "begin", "includedFrom") ~= nil then
        return
    end
    local kind = node.kind
    if kind == "ObjCCategoryImplDecl" or kind == "ObjCCategoryDecl" then
        local owner = self:original(dig(node, "interface", "name"))
        for _, item in ipairs(node.inner or {}) do
            self:walk(item, {"-", owner})
        end
        return
    end
    if kind == "ObjCImplementationDecl" then
        local owner = self:original(node.name)
        for _, item in ipairs(node.inner or {}) do
            self:walk(item, {"-", owner})
        end
        return
    end
    if kind == "ObjCSelectorExpr" and node.selector then
        local begin = dig(node, "range", "begin", "offset")
        if begin ~= nil and self.carried.selectors[node.selector] then
            local opened = find0(self.source, "(", begin)
            if not opened then
                error("no '(' after a selector expression")
            end
            self.inserts[opened + 1] = true
        end
    end
    if kind == "ObjCMethodDecl" and context and dig(node, "range", "begin", "offset") ~= nil then
        local sign = node.instance == false and "+" or "-"
        if carried_has(self.carried, sign, context[2], node.name) then
            local close = find0(self.source, "(", node.range.begin.offset)
            if not close then
                error("no '(' in a method declaration")
            end
            local depth = 0
            while true do
                local c = ch(self.source, close)
                if c == "(" then
                    depth = depth + 1
                elseif c == ")" then
                    depth = depth - 1
                end
                if depth == 0 then
                    break
                end
                close = close + 1
            end
            self.inserts[self:keyword_after(close + 1) or false] = true
            table.insert(self.signatures, {context[2], sign, node})
        end
        for _, item in ipairs(node.inner or {}) do
            self:walk(item, {sign, context[2]})
        end
        return
    end
    if kind == "ObjCMessageExpr" then
        local selector = node.selector
        local sign, receiver = self:receiver_class(node, context)
        if sign and receiver and self:owns(sign, receiver, selector) then
            if node.receiverKind == "class" then
                local start = find0(self.source, "[", node.range.begin.offset) + 1
                self.inserts[self:keyword_after(self:class_token_end(start)) or false] = true
            else
                self:rename_instance_send(node, receiver, selector)
            end
        elseif sign and not receiver and self.carried.selectors[selector] then
            local inner = node.inner and node.inner[1] and node.inner[1].range or nil
            local keyword = nil
            if inner then
                keyword = self:keyword_after(inner["end"].offset + inner["end"].tokLen)
            end
            if keyword ~= nil then
                table.insert(self.candidates, {keyword, selector})
            end
        end
    end
    if kind == "ObjCPropertyRefExpr" and dig(node, "property", "name") then
        local name = node.property.name
        local accessors = {}
        if node.isMessagingGetter then
            table.insert(accessors, name)
        end
        if node.isMessagingSetter then
            table.insert(accessors, "set" .. upper_first(name) .. ":")
        end
        local receiver_type = dig(node, "inner", 1, "type", "qualType") or ""
        local receiver
        if (bare(receiver_type) == "id" or bare(receiver_type) == "instancetype") and context then
            receiver = self:original(context[2])
        else
            receiver = self:original(bare(receiver_type))
        end
        local placed = false
        for _, accessor in ipairs(accessors) do
            if self:owns("-", receiver, accessor) then
                placed = true
            end
        end
        if placed then
            if node.isMessagingSetter then
                table.insert(self.unresolved, {node.range["end"].offset, string.format("a write to %s through dot syntax", name)})
            else
                self.inserts[node.range["end"].offset] = true
            end
        end
    end
    for _, value in pairs(node) do
        if type(value) == "table" then
            self:walk(value, context)
        end
    end
end

function Rewriter:result(prefix)
    local edits = {}
    for offset in pairs(self.inserts) do
        if offset then
            table.insert(edits, {offset, "rename"})
        end
    end
    for offset in pairs(self.replacements) do
        table.insert(edits, {offset, "literal"})
    end
    table.sort(edits, function(a, b)
        if a[1] ~= b[1] then
            return a[1] > b[1]
        end
        return a[2] > b[2]
    end)
    local text = self.source
    for _, edit in ipairs(edits) do
        local offset, kind = edit[1], edit[2]
        if kind == "literal" then
            local replacement = self.replacements[offset]
            text = text:sub(1, offset) .. replacement[2] .. text:sub(replacement[1] + 1)
        else
            local keyword = text:sub(offset + 1):match("^[%a_][%w_]*")
            if not keyword then
                error("no keyword at a rename offset")
            end
            text = text:sub(1, offset) .. prefixed(keyword, prefix) .. text:sub(offset + #keyword + 1)
        end
    end
    return text
end

local function collect(node, owner, owners)
    if type(node) ~= "table" then
        return
    end
    local kind = node.kind
    if kind == "ObjCInterfaceDecl" or kind == "ObjCCategoryDecl" or kind == "ObjCImplementationDecl"
        or kind == "ObjCCategoryImplDecl" or kind == "ObjCProtocolDecl" then
        local named_owner = dig(node, "interface", "name") or node.name
        for _, item in ipairs(node.inner or {}) do
            collect(item, named_owner, owners)
        end
        return
    end
    if kind == "ObjCMethodDecl" and owner and node.name then
        owners[node.name] = owners[node.name] or {}
        owners[node.name][owner] = true
    end
    if kind == "ObjCPropertyDecl" and owner and node.name then
        local name = node.name
        owners[name] = owners[name] or {}
        owners[name][owner] = true
        local setter = "set" .. upper_first(name) .. ":"
        owners[setter] = owners[setter] or {}
        owners[setter][owner] = true
    end
    for _, value in pairs(node) do
        if type(value) == "table" then
            collect(value, owner, owners)
        end
    end
end

local function sdk_key(flags)
    for index, flag in ipairs(flags) do
        if flag == "-isysroot" and flags[index + 1] then
            return flags[index + 1]
        end
    end
    return ""
end

local function sdk_owners(flags)
    local key = digest(sdk_key(flags)):sub(1, 16)
    local home = os.getenv("REVENANT_HOME") or path.join(os.getenv("HOME"), ".revenant")
    local folder = path.join(home, "cache")
    local cached = path.join(folder, "sdk-objc-owners-" .. key .. ".json")
    local stored = cached_json(cached)
    if stored then
        local owners = {}
        for name, classes in pairs(stored) do
            owners[name] = set_of(classes)
        end
        return owners
    end
    local work = path.join(RUNS, "sdk-owners-" .. key)
    os.mkdir(work)
    local empty = path.join(work, "sdk.m")
    io.writefile(empty, "#import <UIKit/UIKit.h>\n#import <Foundation/Foundation.h>\n")
    local dump = try { function () return clang_dump(flags, empty, false) end } or ""
    local owners = {}
    for _, document in ipairs(documents(dump)) do
        collect(document, nil, owners)
    end
    if is_empty(owners) then
        io.stderr:write(string.format("%s: the SDK's own declarations could not be read\n", sdk_key(flags)))
        os.exit(1)
    end
    os.mkdir(folder)
    local out = {}
    for name, classes in pairs(owners) do
        out[name] = sorted_keys(classes)
    end
    write_json(cached, out)
    local result = {}
    for name, classes in pairs(owners) do
        result[name] = set_of(sorted_keys(classes))
    end
    return result
end

local FIXTURE = [==[#import <Foundation/Foundation.h>
@protocol RevenantWidgetDelegate <NSObject>
- (void)widgetSaysHello;
- (NSString *)widgetGreeting;
@end
@interface RevenantWidget : NSObject <RevenantWidgetDelegate>
- (void)widgetSaysHello;
- (NSString *)widgetGreeting;
@end
@implementation RevenantWidget
- (void)widgetSaysHello
{
}
- (NSString *)widgetGreeting
{
    return @"hello";
}
- (void)greet:(id<RevenantWidgetDelegate>)delegate
{
    [delegate widgetSaysHello];
}
@end
@interface RevenantGreeting : NSObject
@end
@implementation RevenantGreeting
- (void)collect:(id<RevenantWidgetDelegate>)delegate into:(NSMutableArray *)out
{
    // The spelling that made this rewrite fail to compile, read off UITraitCollection.m: a property read
    // through a protocol-typed receiver. clang records it as a message expression whose range begins at the
    // ENCLOSING send, so neither the begin offset nor a search backwards for `[` finds this send's own
    // bracket - the receiver expression's own range is the only thing that does.
    [out addObject:delegate.widgetGreeting ?: @"none"];
}
@end
]==]

local function selftest()
    local work = path.join(RUNS, "selftest.m")
    io.writefile(work, FIXTURE)
    local dump = clang_dump({}, work, true)
    local carried = carried_index({
        {"-", "RevenantWidget", "widgetSaysHello"},
        {"-", "RevenantWidget", "widgetGreeting"},
    })
    local renamed = prefixed("widgetSaysHello", "revenantHost")

    local function rewrite(owners)
        local rewriter = new_rewriter(FIXTURE, carried, make_chain({}), owners, {}, "revenantHost", {})
        for _, document in ipairs(documents(dump)) do
            rewriter:walk(document, nil)
        end
        return rewriter:result("revenantHost")
    end

    local placed = rewrite({RevenantWidgetDelegate = {RevenantWidget = true}})
    print(string.format("ok   the send to id<RevenantWidgetDelegate> is placed: %s",
                        placed:find(renamed, 1, true) and "yes" or "NO -- the conformers did not place it"))
    local control = rewrite({})
    local as_written = "[delegate widgetSaysHello];"
    local quiet = control:find(as_written, 1, true) ~= nil and placed:find(as_written, 1, true) == nil
    print(string.format("%s   the same send with no conformer map is left exactly as written, which is what proves",
                        quiet and "ok  " or "FAIL"))
    print("     the first line is about the mechanism and not about the fixture")
    if not placed:find(renamed, 1, true) or not quiet then
        io.stderr:write("FAIL the protocol-typed send is not placed from its conformers, or the control placed it too\n")
        os.exit(1)
    end

    local as_send = "[(id)(delegate) revenantHostWidgetGreeting]"
    local spelled_ok = placed:find(as_send, 1, true) ~= nil and placed:find("[out addObject:delegate.widgetGreeting", 1, true) == nil
    print(string.format("%s   a protocol-typed property read is rewritten as the send it stands for: %s",
                        spelled_ok and "ok  " or "FAIL", spelled_ok and as_send or "<no addObject line>"))
    if not spelled_ok then
        io.stderr:write("FAIL the protocol-typed property read was not rewritten as a send on an id receiver\n")
        os.exit(1)
    end

    local rows = {
        {"RevenantListsMovement *", "id"},
        {"RevenantConfigurationHost *", "id"},
        {"_Nullable RevenantRows *", "id"},
        {"NSString *", "NSString *"},
        {"UIView *__strong", "UIView *__strong"},
        {"const char *", "const char *"},
        {"RevenantColour", "RevenantColour"},
        {"CGRect", "CGRect"},
        {"struct CGRect", "struct CGRect"},
        {"UISemanticContentAttribute", "UISemanticContentAttribute"},
        {"NSUInteger", "NSUInteger"},
        {"BOOL", "BOOL"},
    }
    local wrong = {}
    for _, row in ipairs(rows) do
        if declared(row[1]) ~= row[2] then
            table.insert(wrong, {row[1], declared(row[1]), row[2]})
        end
    end
    print(string.format("%s   declared() narrows a pointer to the port's own class and nothing else: %d of %d rows",
                        #wrong == 0 and "ok  " or "FAIL", #rows - #wrong, #rows))
    for _, item in ipairs(wrong) do
        print(string.format("       %s -> %s, and it must be %s", item[1], item[2], item[3]))
    end
    if #wrong > 0 then
        io.stderr:write("FAIL declared() does not hold to the one shape that needs a fallback\n")
        os.exit(1)
    end
end

local function main_rewrite(argv)
    local source_path, output_path, prefix = argv[1], argv[2], argv[3]
    local index = 4
    local declarations = nil
    if starts(argv[index] or "", "--declarations=") then
        declarations = argv[index]:sub(#"--declarations=" + 1)
        index = index + 1
    end
    local group_sources = nil
    if starts(argv[index] or "", "--sources=") then
        group_sources = {}
        for piece in argv[index]:sub(#"--sources=" + 1):gmatch("[^,]+") do
            table.insert(group_sources, piece)
        end
        index = index + 1
    end
    local separator = nil
    for at = index, #argv do
        if argv[at] == "--" then
            separator = at
            break
        end
    end
    if not separator then
        error("the flags are followed by -- and the port's objects")
    end
    local flags, objects = {}, {}
    for at = index, separator - 1 do
        table.insert(flags, argv[at])
    end
    for at = separator + 1, #argv do
        table.insert(objects, argv[at])
    end

    local carried = carried_index(ported(objects))
    local dump = clang_dump(flags, source_path, true)
    local superclasses = make_chain(header_superclasses(flags))
    local source = io.readfile(source_path)
    local classes = ported_classes(objects)
    local owners = {}
    if group_sources then
        owners = conformers(group_sources, flags, classes)
    end
    local rewriter = new_rewriter(source, carried, superclasses, owners, classes, prefix, group_renames(flags))
    for _, document in ipairs(documents(dump)) do
        rewriter:walk(document, nil)
    end

    if #rewriter.candidates > 0 then
        local seen, wanted = {}, {}
        for _, candidate in ipairs(rewriter.candidates) do
            local key = candidate[1] .. "\0" .. candidate[2]
            if not seen[key] then
                seen[key] = true
                table.insert(wanted, candidate)
            end
        end
        table.sort(wanted, function(a, b)
            if a[1] ~= b[1] then
                return a[1] < b[1]
            end
            return a[2] < b[2]
        end)
        local host_owners = sdk_owners(flags)
        local port = {}
        for _, member in ipairs(carried.list) do
            port[member[3]] = true
        end
        for _, candidate in ipairs(wanted) do
            local offset, selector = candidate[1], candidate[2]
            if selector ~= "" then
                local others = host_owners[selector] or {}
                local ours = {}
                for _, member in ipairs(carried.list) do
                    if member[3] == selector then
                        ours[member[2]] = true
                    end
                end
                local host_only = false
                for name in pairs(others) do
                    if not ours[name] then
                        host_only = true
                    end
                end
                if not port[selector] or host_only then
                    local listed = table.concat(sorted_keys(others), ", ")
                    if listed == "" then
                        listed = "headers"
                    end
                    table.insert(rewriter.unresolved, {offset, string.format("%s, which the host's %s declares", selector, listed)})
                else
                    local begin = rfind0(rewriter.source, "[", offset)
                    begin = begin and (begin + 1) or offset
                    local renamed_first = prefixed(split(selector, ":")[1], prefix)
                    local found = rewriter.source:find(renamed_first, begin + 1, true)
                    if found and (found - 1) < offset then
                        rewriter.replacements[begin] = {offset, "(id)(" .. strip(slice(rewriter.source, begin, offset)) .. ")"}
                    end
                    rewriter.inserts[offset] = true
                end
            end
        end
    end

    local printed = {}
    for _, item in ipairs(rewriter.unresolved) do
        table.insert(printed, item)
    end
    table.sort(printed, function(a, b)
        if a[1] ~= b[1] then
            return a[1] < b[1]
        end
        return a[2] < b[2]
    end)
    for _, item in ipairs(printed) do
        local _, newlines = slice(source, 0, item[1]):gsub("\n", "")
        io.stderr:write(string.format("%s:%d: a carried selector the rewrite cannot rename: %s\n", source_path, newlines + 1, item[2]))
    end
    if #rewriter.unresolved > 0 then
        os.exit(1)
    end
    io.writefile(output_path, rewriter:result(prefix))
    if declarations then
        local lines = {}
        for _, signature in ipairs(rewriter.signatures) do
            table.insert(lines, string.format("@interface %s ()\n%s;\n@end\n",
                                              signature[1], declaration(signature[2], signature[3], prefix)))
        end
        local existing = os.isfile(declarations) and io.readfile(declarations) or ""
        io.writefile(declarations, existing .. table.concat(lines))
    end
end

function group_renames(flags)
    local names = {}
    for _, flag in ipairs(flags) do
        local first, second = flag:match("^%-D([%a_][%w_]*)=([%a_][%w_]*)$")
        if first and second == "RevenantHost" .. first then
            names[second] = first
        end
    end
    return names
end

function main(...)
    local argv = {...}
    for _, word in ipairs(argv) do
        if word == "--selftest" then
            selftest()
            return
        end
    end
    main_rewrite(argv)
end
