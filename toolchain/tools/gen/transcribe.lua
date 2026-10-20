local stream = import("stream", {anonymous = true})
local strings = import("strings", {anonymous = true})
local files = import("files", {anonymous = true})
local order = import("order", {anonymous = true})
local json = import("core.base.json")
local sdk_info = import("sdk", {anonymous = true})
local sdk_imports = import("sdk_imports", {anonymous = true})

local BUILTIN = {}
for _, word in ipairs({"id", "SEL", "Class", "BOOL", "instancetype", "IMP", "NSInteger", "NSUInteger", "CGFloat", "double",
                       "float", "int", "unsigned", "long", "char", "void", "NSString", "NSData", "NSArray", "NSDictionary",
                       "NSError", "NSNumber", "NSTimeInterval", "CGRect", "CGPoint", "CGSize", "objc_AssociationPolicy",
                       "dispatch_queue_t", "CFStringRef", "CFTypeRef", "NSRange"}) do
    BUILTIN[word] = true
end

local KEYWORDS = {struct = true, enum = true, union = true, signed = true, short = true, bool = true, _Bool = true, const = true,
                  volatile = true, _Nullable_result = true}
local QUALIFIERS = {"_Nullable_result", "_Nullable", "_Nonnull", "_None", "_Null_unspecified", "_null_unspecified", "__kindof",
                    "__strong", "__weak", "__unsafe_unretained", "__autoreleasing"}
local ATTRIBUTES = {"class", "nonatomic", "atomic", "readonly", "readwrite", "copy", "strong", "weak", "assign", "retain",
                    "unsafe_unretained", "null_resettable"}
local SPACE_BYTES = {[9] = true, [10] = true, [11] = true, [12] = true, [13] = true, [28] = true, [29] = true, [30] = true,
                     [31] = true, [32] = true, [133] = true, [160] = true}
local KEYWORD_OF_KIND = {RecordDecl = "struct", EnumDecl = "enum"}

local MACRO_SPELLINGS = {API_AVAILABLE = true, NS_REFINED_FOR_SWIFT = true}

local function strip_comments(text)
    local out, last, at = {}, 1, 1
    while true do
        local s = string.find(text, "/", at, true)
        if s == nil then
            break
        end
        local two = string.sub(text, s, s + 1)
        local stop = nil
        if two == "//" then
            local newline = string.find(text, "\n", s, true)
            stop = (newline or #text + 1) - 1
        elseif two == "/*" then
            local close = string.find(text, "*/", s + 2, true)
            if close then
                stop = close + 1
            end
        end
        if stop then
            table.insert(out, string.sub(text, last, s - 1))
            table.insert(out, (string.gsub(string.sub(text, s, stop), "[^\n]", " ")))
            last = stop + 1
            at = stop + 1
        else
            at = s + 1
        end
    end
    table.insert(out, string.sub(text, last))
    return table.concat(out)
end

local function have_of(tree)
    local have = {}
    for _, filepath in ipairs(files.glob(path.join(tree, "packages", "**.h"))) do
        if not string.match(path.filename(filepath), "^Revenant[%w]+Protocols%.h$") then
            for line in string.gmatch(strings.universal(io.readfile(filepath)), "[^\n]*") do
                for name in string.gmatch(line, "@protocol%s+([%w_]+)") do
                    if have[name] == nil and string.find(line, "@protocol%s+" .. name .. "%s*;") == nil then
                        have[name] = filepath
                    end
                end
            end
        end
    end
    return have
end

local function annotate(text)
    local current = nil
    local annotated = string.gsub(text, '()"offset": (%d+)', function(at, digits)
        local ends = at + 9 + #digits
        local _, _, file = string.find(text, '^,\n%s*"file": ("[^"]*")', ends + 1)
        if file then
            current = file
        end
        if current == nil then
            return false
        end
        return '"_file": ' .. current .. ', "offset": ' .. digits
    end)
    return annotated
end

local function dump(clang, sdk, frameworks, target)
    local argv = {"-target", target, "-isysroot", sdk, "-fobjc-arc", "-w", "-fsyntax-only", "-Xclang", "-ast-dump=json"}
    for _, framework in ipairs(frameworks) do
        table.insert(argv, "-include")
        table.insert(argv, framework .. "/" .. framework .. ".h")
    end
    table.insert(argv, "-x")
    table.insert(argv, "objective-c")
    table.insert(argv, "/dev/null")
    local status, text, errors = stream.text(clang, argv)
    if not string.find(text, '"kind": "TranslationUnitDecl"', 1, true) then
        raise("no AST from " .. sdk .. " for " .. target .. ": " .. string.sub(errors, 1, 300))
    end
    local document, err = json.decode(annotate(text))
    if document == nil then
        raise("the AST of " .. target .. " does not decode: " .. tostring(err))
    end
    return document
end

local function gather(document)
    local protocols, classes, types = {}, {}, {}
    local function visit(node)
        local kind = node.kind
        if kind == "ObjCInterfaceDecl" and node.name then
            classes[node.name] = true
        elseif (kind == "TypedefDecl" or kind == "EnumDecl" or kind == "RecordDecl") and node.name then
            types[node.name] = types[node.name] or kind
        elseif kind == "ObjCProtocolDecl" and node.name and node.range then
            protocols[node.name] = protocols[node.name] or {}
            table.insert(protocols[node.name], node)
        end
    end
    local function walk(value)
        if value[1] ~= nil then
            for _, item in ipairs(value) do
                if type(item) == "table" then
                    walk(item)
                end
            end
            return
        end
        visit(value)
        for _, child in pairs(value) do
            if type(child) == "table" then
                walk(child)
            end
        end
    end
    walk(document)
    return protocols, classes, types
end

local function place(loc)
    loc = loc.expansionLoc or loc
    if loc._file == nil then
        raise("a location with no file: " .. json.encode(loc))
    end
    return loc._file, loc.offset or 0
end

local SOURCES = {}
local function source(file)
    if SOURCES[file] == nil then
        SOURCES[file] = strip_comments(io.readfile(file))
    end
    return SOURCES[file]
end

local function members_of(node)
    local out = {}
    for _, inner in ipairs(node.inner or {}) do
        if (inner.kind == "ObjCMethodDecl" and not inner.isImplicit) or inner.kind == "ObjCPropertyDecl" then
            table.insert(out, inner)
        end
    end
    return out
end

local function shape(node)
    local keys = {}
    for _, m in ipairs(members_of(node)) do
        table.insert(keys, m.kind .. "\1" .. (m.name or "") .. "\1" .. tostring(m.instance == true) .. "\1" .. tostring(m.class == true))
    end
    table.sort(keys, order.less)
    return table.concat(keys, "\2")
end

local function defines(node)
    if #members_of(node) > 0 then
        return true
    end
    local file, offset = place(node.loc)
    local after = string.sub(source(file), offset + 1 + #node.name)
    local start = 1
    while SPACE_BYTES[string.byte(after, start) or -1] do
        start = start + 1
    end
    local first = string.sub(after, start, start)
    return not (first == ";" or first == ",")
end

local function section_of(member, begin)
    local file, offset = place(member.loc)
    if file ~= begin[1] or offset < begin[2] then
        raise(string.format("%s is at %s:%d, outside the definition at %s:%d", tostring(member.name), file, offset, begin[1], begin[2]))
    end
    local found = "required"
    local between = string.sub(source(file), begin[2] + 1, offset)
    for at, word in string.gmatch(between, "()@(%a+)") do
        if word == "optional" or word == "required" then
            local after = string.sub(between, at + 1 + #word, at + 1 + #word)
            if after == "" or not string.find(after, "[%w_]") then
                found = word
            end
        end
    end
    return found
end

local function definition(name, nodes)
    local full = {}
    for _, node in ipairs(nodes) do
        if #members_of(node) > 0 then
            table.insert(full, node)
        end
    end
    local shapes, count = {}, 0
    for _, node in ipairs(full) do
        local key = shape(node)
        if not shapes[key] then
            shapes[key] = true
            count = count + 1
        end
    end
    if count > 1 then
        raise(string.format("%s: %d declarations with differing member sets", name, #full))
    end
    local chosen = full[1] or nodes[1]
    local bases = {}
    for _, b in ipairs(chosen.protocols or {}) do
        local base = (b.referencedDecl and b.referencedDecl.name) or b.name
        if base then
            table.insert(bases, base)
        end
    end
    local members = {}
    if #full > 0 then
        local file, offset = place(chosen.range.begin)
        local begin = {file, offset}
        for _, inner in ipairs(members_of(chosen)) do
            local section = section_of(inner, begin)
            if inner.kind == "ObjCPropertyDecl" and inner.control ~= nil and inner.control ~= section then
                raise(string.format("%s.%s: the header says @%s and clang says %s", name, inner.name, section, inner.control))
            end
            table.insert(members, {optional = section == "optional", node = inner})
        end
    end
    return bases, members
end

local function names_of(qual)
    local text = qual
    for _, word in ipairs(QUALIFIERS) do
        text = string.gsub(text, "%f[%w_]" .. word .. "%f[^%w_]", "")
    end
    text = string.gsub(text, "%f[%w_]id%s*<[^<>]*>", "id")
    local out = {}
    for name in string.gmatch(text, "[%a_][%w_]*") do
        if not KEYWORDS[name] and not MACRO_SPELLINGS[name] then
            table.insert(out, name)
        end
    end
    return out
end

local function types_of(member)
    local own
    if member.kind == "ObjCMethodDecl" then
        own = member.returnType or {}
    else
        own = member.type or {}
    end
    local out = {own.qualType or ""}
    for _, p in ipairs(member.inner or {}) do
        if p.kind == "ParmVarDecl" then
            table.insert(out, (p.type or {}).qualType or "")
        end
    end
    return out
end

local function protocols_of(member)
    local named = {}
    for _, qual in ipairs(types_of(member)) do
        for name in string.gmatch(qual, "%f[%w_]id%s*<%s*([%a_][%w_]*)") do
            named[name] = true
        end
    end
    return named
end

local function spelled_of(qual)
    return (string.gsub(qual, "%s*__[%w_]+", function (word)
        if string.match(word, "^%s*__kindof$") then
            return nil
        end
        return ""
    end))
end

local function declarator(qual, name)
    local spelled = spelled_of(qual)
    local at = nil
    for _, opener in ipairs({"(^", "(*"}) do
        local s = string.find(spelled, opener, 1, true)
        if s and (at == nil or s < at) then
            at = s
        end
    end
    if at == nil then
        if string.sub(spelled, -1) == "*" then
            return spelled .. name
        end
        return spelled .. " " .. name
    end
    local depth = 0
    for index = at, #spelled do
        local ch = string.sub(spelled, index, index)
        if ch == "(" then
            depth = depth + 1
        elseif ch == ")" then
            depth = depth - 1
        end
        if depth == 0 then
            return string.sub(spelled, 1, index - 1) .. name .. string.sub(spelled, index)
        end
    end
    raise(name .. ": no closing parenthesis in " .. qual)
end

local function render_property(member)
    local attributes = {}
    for _, key in ipairs(ATTRIBUTES) do
        if member[key] == true then
            table.insert(attributes, key)
        end
    end
    for _, key in ipairs({"getter", "setter"}) do
        if member[key] ~= nil then
            table.insert(attributes, key .. "=" .. member[key].name)
        end
    end
    return "@property (" .. table.concat(attributes, ", ") .. ") " .. declarator(member.type.qualType, member.name) .. ";"
end

local function render_method(member)
    local selector = member.name
    local params = {}
    for _, p in ipairs(member.inner or {}) do
        if p.kind == "ParmVarDecl" then
            table.insert(params, p)
        end
    end
    local text = selector
    if string.find(selector, ":", 1, true) then
        local keywords = {}
        for piece in string.gmatch(selector, "([^:]*):") do
            table.insert(keywords, piece)
        end
        if #keywords ~= #params then
            raise(string.format("%s: %d pieces and %d parameters", selector, #keywords, #params))
        end
        local pieces = {}
        for index, piece in ipairs(keywords) do
            local param = params[index]
            table.insert(pieces, piece .. ":(" .. spelled_of(param.type.qualType) .. ")" .. (param.name or ""))
        end
        text = table.concat(pieces, " ")
    end
    if member.variadic then
        text = text .. ", ..."
    end
    return (member.instance and "-" or "+") .. " (" .. spelled_of(member.returnType.qualType) .. ")" .. text .. ";"
end

local function availability_of(member)
    local introduced, unavailable, obsoleted = nil, false, false
    for _, inner in ipairs(member.inner or {}) do
        if inner.kind == "AvailabilityAttr" and inner.platform == "ios" then
            if inner.introduced ~= nil then
                introduced = inner.introduced
            end
            unavailable = unavailable or inner.unavailable == true
            obsoleted = obsoleted or inner.obsoleted ~= nil
        end
    end
    if obsoleted or (introduced and unavailable) then
        raise(string.format("%s: an iOS availability the transcriber does not write (introduced %s, obsoleted %s, unavailable %s)",
            tostring(member.name), tostring(introduced), tostring(obsoleted), tostring(unavailable)))
    end
    if introduced then
        return " API_AVAILABLE(ios(" .. introduced .. "))"
    end
    if unavailable then
        return " API_UNAVAILABLE(ios)"
    end
    return ""
end

local function render_member(member)
    local text
    if member.kind == "ObjCPropertyDecl" then
        text = render_property(member)
    else
        text = render_method(member)
    end
    return string.sub(text, 1, -2) .. availability_of(member) .. ";"
end

local function render(members)
    local lines, optional_now = {}, false
    for _, entry in ipairs(members) do
        if entry.optional ~= optional_now then
            table.insert(lines, entry.optional and "@optional" or "@required")
            optional_now = entry.optional
        end
        table.insert(lines, render_member(entry.node))
    end
    return lines
end

local function header_text(tree, sdk, framework, entries, defined16, have, protocols16)
    local wants_framework = false
    local transcribed = {}
    for _, entry in ipairs(entries) do
        transcribed[entry[1]] = true
        if #entry == 2 then
            wants_framework = true
        end
    end
    local lines = {"// Revenant" .. framework .. "Protocols.h \u{2014} the " .. framework .. " protocols the generated protocol sources name, written by",
                   "// xmake l tools/gen.lua protocols. One the SDK this package compiles against already defines, or a",
                   "// header of this folder does, is forward-declared and its body comes from that import; any other is",
                   "// transcribed from the SDK that declares it: the base list, each member with its kind and types,",
                   "// @required and @optional as sections, and API_AVAILABLE(ios(<introduced>)). Facts only.",
                   wants_framework
                       and ("// This file has a forward-declared protocol in it, so it imports <" .. framework .. "/" .. framework
                            .. ".h> for that body, and")
                       or ("// Every protocol in this file is transcribed here, so it imports no framework header: their members name classes "
                            .. "this header forward-declares. A file with a forward-declared protocol in it does import <" .. framework
                            .. "/" .. framework .. ".h>, for that one body."),
                   "#import <objc/NSObject.h>"}
    for _, line in ipairs(sdk_imports.umbrella_imports(sdk, framework, false)) do
        table.insert(lines, #lines, line)
    end
    if wants_framework then
        table.insert(lines, #lines - 1, "#import <" .. framework .. "/" .. framework .. ".h>")
    end
    local named = {}
    for _, entry in ipairs(entries) do
        if #entry > 2 then
            for one in pairs(entry[6]) do
                named[one] = true
            end
        end
    end
    local named_names = {}
    for one in pairs(named) do
        table.insert(named_names, one)
    end
    table.sort(named_names, order.less)
    for _, one in ipairs(named_names) do
        if protocols16[one] == nil and not transcribed[one] then
            table.insert(lines, "@protocol " .. one .. ";")
        end
    end
    local hand = {}
    for _, entry in ipairs(entries) do
        if #entry == 2 and not defined16[entry[1]] then
            table.insert(hand, have[entry[1]])
        end
    end
    table.sort(hand, order.less)
    local folder_path = path.absolute(path.join(tree, "packages", "frameworks", "apple-backports", framework))
    local seen = {}
    for _, header in ipairs(hand) do
        if not seen[header] then
            seen[header] = true
            if path.absolute(path.directory(header)) ~= folder_path then
                raise(header .. " defines a protocol of " .. framework .. " from outside its folder")
            end
            table.insert(lines, '#import "' .. path.filename(header) .. '"')
        end
    end
    table.insert(lines, "")
    for _, entry in ipairs(entries) do
        if #entry == 2 then
            table.insert(lines, "@protocol " .. entry[1] .. ";")
            table.insert(lines, "")
        else
            local typed = {}
            for one in pairs(entry[5]) do
                table.insert(typed, one)
            end
            table.sort(typed, order.less)
            for _, one in ipairs(typed) do
                local keyword = KEYWORD_OF_KIND[entry[7][one]]
                if keyword then
                    table.insert(lines, "typedef " .. keyword .. " " .. one .. " " .. one .. ";")
                else
                    table.insert(lines, "@class " .. one .. ";")
                end
            end
            table.insert(lines, "API_AVAILABLE(ios(" .. entry[2] .. "))")
            local bases = #entry[3] > 0 and table.concat(entry[3], ", ") or "NSObject"
            table.insert(lines, "@protocol " .. entry[1] .. " <" .. bases .. ">")
            for _, line in ipairs(render(entry[4])) do
                table.insert(lines, line)
            end
            table.insert(lines, "@end")
            table.insert(lines, "")
        end
    end
    return table.concat(lines, "\n")
end

local function facts_of(args, result)
    local out = {}
    for _, item in ipairs(args.wanted) do
        local name = item.name
        local reasons = {}
        for _, line in ipairs(result.lines) do
            if string.sub(line, 1, #name + 1) == name .. ":" or string.sub(line, 1, #name + 1) == name .. "." then
                table.insert(reasons, line)
            end
        end
        local status
        if result.defined16[name] then
            status = "sdk16 body"
        elseif result.transcribed[name] then
            status = "transcribed"
        elseif result.have[name] then
            status = "hand header"
        elseif #reasons > 0 then
            status = "refused"
        else
            status = "missing"
        end
        local record = {name = name, framework = item.framework, introduced = item.introduced, status = status, reasons = reasons}
        local decl = result.decls[name]
        if decl then
            record.bases = decl.bases
            record.members = {}
            for _, entry in ipairs(decl.members) do
                local node = entry.node
                local is_property = node.kind == "ObjCPropertyDecl"
                table.insert(record.members, {section = entry.optional and "optional" or "required",
                                              kind = is_property and "property" or "method", instance = node.instance == true,
                                              selector = node.name, decl = render_member(node)})
            end
        end
        if result.protocols16[name] then
            local any = false
            for _, node in ipairs(result.protocols16[name]) do
                if defines(node) then
                    any = true
                end
            end
            if any then
                local _, members = definition(name, result.protocols16[name])
                local names = {}
                for _, entry in ipairs(members) do
                    table.insert(names, entry.node.name)
                end
                table.sort(names, order.less)
                record.members16 = names
            end
        end
        table.insert(out, record)
    end
    return out
end

local function typed_kinds(typed, types26)
    local out = {}
    for one in pairs(typed) do
        out[one] = types26[one]
    end
    return out
end

function run(args)
    assert(args.clang, "the transcriber needs args.clang: the clang that dumps the SDK's ASTs (project.clang)")
    local sdk26 = sdk_info.discover(args.sdk26)
    local frameworks, seen = {}, {}
    for _, item in ipairs(args.wanted) do
        if not seen[item.framework] then
            seen[item.framework] = true
            table.insert(frameworks, item.framework)
        end
    end
    table.sort(frameworks, order.less)
    local have = have_of(args.tree)
    local protocols26, interfaces26, types26 = gather(dump(args.clang, args.sdk26, frameworks, "arm64-apple-ios" .. sdk26.deployment))
    local classes26 = {}
    for name in pairs(interfaces26) do
        classes26[name] = true
    end
    for name in pairs(types26) do
        classes26[name] = true
    end
    local decls = {}
    for name, nodes in pairs(protocols26) do
        local bases, members = definition(name, nodes)
        decls[name] = {bases = bases, members = members}
    end
    local protocols16, interfaces16, types16 = gather(dump(args.clang, args.sdk16, frameworks, "armv7-apple-ios6.1.3"))
    local classes16 = {}
    for name in pairs(interfaces16) do
        classes16[name] = true
    end
    for name in pairs(types16) do
        classes16[name] = true
    end
    local defined16 = {}
    for name, nodes in pairs(protocols16) do
        for _, node in ipairs(nodes) do
            if defines(node) then
                defined16[name] = true
                break
            end
        end
    end
    local sdk16_name = path.filename((string.gsub(args.sdk16, "/+$", "")))
    local missing, refusals = {}, {}
    local per_library = {}
    for _, item in ipairs(args.wanted) do
        local name, framework, introduced = item.name, item.framework, item.introduced
        if defined16[name] or have[name] then
            per_library[framework] = per_library[framework] or {}
            table.insert(per_library[framework], {name, introduced})
        elseif decls[name] == nil then
            table.insert(missing, name .. ": not in the " .. sdk26.version .. " AST; the SDK that declares it is not the one the build uses")
        else
            local adopted = {}
            for _, b in ipairs(decls[name].bases) do
                if protocols26[b] == nil and have[b] == nil then
                    table.insert(adopted, b)
                end
            end
            if #adopted > 0 then
                table.insert(missing, name .. ": adopts " .. table.concat(adopted, ", ") .. ", which the " .. sdk26.version .. " AST does not carry either")
            else
                local typed, refused = {}, {}
                local named = {}
                for _, m in ipairs(decls[name].members) do
                    for _, qual in ipairs(types_of(m.node)) do
                        for _, base in ipairs(names_of(qual)) do
                            if BUILTIN[base] or classes16[base] then
                            elseif classes26[base] then
                                typed[base] = true
                            else
                                table.insert(refused, string.format("%s.%s needs %s, which %s does not declare", name,
                                    m.node.name, base, sdk16_name))
                                break
                            end
                        end
                    end
                    if #refused > 0 then
                        break
                    end
                end
                if #refused > 0 then
                    for _, line in ipairs(refused) do
                        table.insert(refusals, line)
                    end
                else
                    for _, m in ipairs(decls[name].members) do
                        for one in pairs(protocols_of(m.node)) do
                            named[one] = true
                        end
                    end
                    per_library[framework] = per_library[framework] or {}
                    table.insert(per_library[framework], {name, introduced, decls[name].bases, decls[name].members, typed, named,
                                                          typed_kinds(typed, types26)})
                end
            end
        end
    end
    local transcribed = {}
    for _, entries in pairs(per_library) do
        for _, entry in ipairs(entries) do
            if #entry > 2 then
                transcribed[entry[1]] = true
            end
        end
    end
    local result = {defined16 = defined16, have = have, decls = decls, protocols16 = protocols16, transcribed = transcribed,
                    lines = {}}
    for _, line in ipairs(missing) do
        table.insert(result.lines, line)
    end
    for _, line in ipairs(refusals) do
        table.insert(result.lines, line)
    end
    local headers = {}
    for _, framework in ipairs(frameworks) do
        if per_library[framework] then
            headers[framework] = header_text(args.tree, args.sdk26, framework, per_library[framework], defined16, have, protocols16)
        end
    end
    local refusal_lines = {}
    for _, line in ipairs(missing) do
        table.insert(refusal_lines, line)
    end
    for _, line in ipairs(refusals) do
        table.insert(refusal_lines, line)
    end
    table.sort(refusal_lines, order.less)
    return {records = facts_of(args, result), headers = headers, refusals = refusal_lines}
end
