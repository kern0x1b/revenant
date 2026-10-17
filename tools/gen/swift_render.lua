-- The Swift skeleton renderer: from the full model (swift_model.lua), the text of a module's declarations. Every line is built from
-- the model's own fields (kind, container, name, side, type, params, generic_sig, conformances, superclass, throwing, async,
-- mutating, attributes, accessors, storage, is_let, is_open, requirement, in_extension, owner_module, raw, availability); no
-- .swiftinterface is read, no comment of Apple's is copied and no layout of theirs is reproduced. A function body traps with the
-- member's name; a stored value is rendered as a computed property that traps, so the skeleton compiles without an initializer.

local order = import("order", {anonymous = true})
local swift_shard = import("swift_shard", {anonymous = true})
local swift_canonical = import("swift_canonical", {anonymous = true})

local NO_VALUE = "-"
-- The type the digester gives a declaration whose type it cannot give (the error type's printed name).
local UNTYPED = "_"
local TYPE_KINDS = {["class"] = true, ["struct"] = true, ["enum"] = true, ["protocol"] = true, ["typealias"] = true}
-- The surface kinds whose name is a whole declaration (a member name is the printedName, e.g. "moved(dx:)") for a member, and the
-- bare name for a type.
local MEMBER_KINDS = {method = true, property = true, constant = true, ["function"] = true, ["associatedtype"] = true}
-- The Swift keywords a declared name cannot take bare: the digester gives the bare name, so a declaration named one of them is
-- spelled between backticks (an identifier in backticks is always legal, so the list may be generous). Initializers are not named.
local KEYWORDS = {}
for word in string.gmatch("Any Self as await associatedtype break case catch class continue default defer deinit do else enum "
                          .. "extension fallthrough false fileprivate for func guard if import in inout internal is let nil open "
                          .. "operator private protocol public repeat rethrows return self static struct subscript super switch "
                          .. "throw throws true try typealias var where while", "%S+") do
    KEYWORDS[word] = true
end

-- The name of a declaration as Swift spells it: a keyword is wrapped in backticks.
local function ident(name)
    if KEYWORDS[name] then
        return "`" .. name .. "`"
    end
    return name
end

-- The pieces of a name: the leaf before the first "(" and the label of each parameter, read from the printedName ("moved(dx:)",
-- "init(locale:preset:)", "hash(into:)", "==(_:_:)"). A name with no parenthesis has no labels.
local function name_parts(name)
    local open = string.find(name, "(", 1, true)
    if open == nil then
        return name, {}
    end
    local leaf = string.sub(name, 1, open - 1)
    local labels = {}
    for label in string.gmatch(string.sub(name, open + 1), "([^:]*):") do
        table.insert(labels, label)
    end
    return leaf, labels
end

-- The dump spells builtin types with their module ("Swift.Int"), but `Any` is a keyword, not a member of Swift: `Swift.Any` does
-- not parse. The frontier keeps a name beginning with "Any" (AnyObject, ...) untouched. The dump pads some of its names with
-- spaces ("Locale ,"), so the text is trimmed as well.
local function spell(text)
    if text == nil then
        return text
    end
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return (string.gsub(text, "Swift%.Any%f[%A]", "Any"))
end

-- The cells of a " | " joined list ("-"), or an empty list.
local function pipe_list(text)
    if text == nil or text == NO_VALUE then
        return {}
    end
    local out = {}
    for item in string.gmatch(text, "[^|]+") do
        table.insert(out, spell(item))
    end
    return out
end

-- The module qualifier of a type name (the first dotted part when it is a name), or nil. `Self` is a keyword, not a module.
local function module_of(name)
    local head = string.match(name, "^([_%a][%w_]*)%.")
    if head == nil or head == "any" or head == "some" or head == "Self" then
        return nil
    end
    return head
end

-- Whether a list holds the value.
local function contains(list, value)
    for _, item in ipairs(list) do
        if item == value then
            return true
        end
    end
    return false
end

-- Whether a set has any key (xmake's Lua has no next).
local function has_keys(set)
    for _ in pairs(set) do
        return true
    end
    return false
end

-- The modules a row names: its owner (an extension's) and the module qualifiers of its type, parameters, conformances, superclass and
-- generic signature.
local function named_modules(row)
    local out = {}
    local function scan(text)
        if text == nil then
            return
        end
        for name in string.gmatch(text, "[%.%w_]*[%w_]+") do
            local module = module_of(name)
            if module then
                table.insert(out, module)
            end
        end
    end
    if row.owner_module ~= NO_VALUE then
        table.insert(out, row.owner_module)
    end
    scan(row.type)
    scan(row.params)
    scan(row.conformances)
    scan(row.superclass)
    scan(row.generic_sig)
    -- a typealias names its type in alias (RealityFoundation's Value = RealityKit.AudioResource), an enum its raw type in raw
    scan(row.alias)
    scan(row.raw)
    return out
end

-- Whether a row names a module that depends on this one (attributed: the set swift_model.dependents_of gives for the module). Its
-- declaration belongs to that module in the SDK (CoreFoundation's rows that name CoreGraphics are CoreGraphics's), so the skeleton
-- leaves it out and the round trip counts the SDK's row as attributed elsewhere (swift_roundtrip.compare).
function attributed_row(row, attributed)
    if attributed == nil then
        return false
    end
    for _, module in ipairs(named_modules(row)) do
        if attributed[module] then
            return true
        end
    end
    return false
end

-- The standard library's protocols a type may be named after (an enum Error conforms to Error): an unqualified conformance of that name is
-- spelled Swift.Error, since inside the type the name is the type itself (the compiler: "'Error' has a raw type that depends on itself").
local STDLIB_PROTOCOLS = {}
for word in string.gmatch("Error Copyable Escapable Sendable Equatable Hashable Comparable Codable Decodable Encodable Identifiable "
                          .. "CaseIterable CustomStringConvertible RawRepresentable Sequence Collection MutableCollection", "%S+") do
    STDLIB_PROTOCOLS[word] = true
end

-- The Foundation protocols a skeleton names bare in the model (AVAudioCompressedBuffer: "NSCopying" with no import of Foundation, and
-- LocalizedError in Messages): spelled Foundation.X, and Foundation is imported for them (imports_of).
local FOUNDATION_PROTOCOLS = {}
for word in string.gmatch("NSCopying NSMutableCopying NSSecureCoding LocalizedError", "%S+") do
    FOUNDATION_PROTOCOLS[word] = true
end

-- A conformance as the skeleton spells it: a standard library protocol qualified with its module, any other name as it is.
local function stdlib_qualified(conformance)
    if STDLIB_PROTOCOLS[conformance] then
        return "Swift." .. conformance
    end
    if FOUNDATION_PROTOCOLS[conformance] then
        return "Foundation." .. conformance
    end
    return conformance
end

-- The conformance list of a row as the skeleton spells it (stdlib_qualified on each item), for the imports: a Foundation protocol named
-- bare still needs Foundation imported.
local function qualified_conformances(text)
    if text == nil or text == NO_VALUE then
        return text
    end
    local items = {}
    for c in string.gmatch(text, "[^,]+") do
        table.insert(items, stdlib_qualified(c))
    end
    return table.concat(items, ",")
end

-- The imports a module needs: the module qualifiers of every type, conformance, superclass and generic signature that name a Swift
-- module of the SDK (known: the set of their names), less the module's own name and the Swift standard library (its declarations
-- are in scope without an import). A qualifier that is no module (a generic parameter such as T, the clang importer's C) is not
-- imported. public maps an implementation module to its public one: the compiler refuses an import of the first ("is an
-- implementation detail of"), and the public module re-exports its declarations, so the qualifier stays and only the import
-- changes.
local function imports_of(rows, framework, known, public, attributed)
    local seen, out = {}, {}
    local function import_of(module)
        return public[module] or module
    end
    -- a public name that is the framework itself is no import: RealityFoundation is RealityKit's implementation, so its public name
    -- RealityKit re-exports RealityFoundation and imports it back (a circular dependency); SwiftUICore's public name is SwiftUI likewise.
    -- A module that depends on this one is no import either: it is the cycle attributed_row leaves out the rows for
    local function add(module)
        if module ~= framework and not (attributed and attributed[module]) and seen[module] == nil then
            seen[module] = true
            table.insert(out, module)
        end
    end
    local function scan(text)
        if text == nil then
            return
        end
        for name in string.gmatch(text, "[%.%w_]*[%w_]+") do
            local module = module_of(name)
            if module and known[module] and module ~= framework and module ~= "Swift" then
                add(import_of(module))
            end
        end
    end
    for _, r in ipairs(rows) do
        -- an extension of another module's type needs that module imported even when no member names it
        local owner = r.owner_module
        if owner ~= NO_VALUE and owner ~= framework then
            add(import_of(owner))
        end
        scan(r.type)
        scan(r.params)
        scan(qualified_conformances(r.conformances))
        scan(r.superclass)
        scan(r.generic_sig)
    end
    table.sort(out, order.less)
    return out
end

-- The generic clause and where clause of a type from its generic signature. outer (a set of names, or nil) names the parameters the
-- enclosing type declares: a member's clause does not declare them. A signature over Self (a protocol) yields no angle
-- brackets; the caller turns the Self constraints into inheritance. Returns params (angle-bracket text or nil) and whereclause.
local function generic_clause(signature, outer)
    if signature == nil or signature == NO_VALUE then
        return nil, nil
    end
    signature = spell(signature)
    local body = string.match(signature, "^<(.*)>$")
    if body == nil then
        return nil, nil
    end
    local where_at = string.find(body, " where ", 1, true)
    local head = where_at and string.sub(body, 1, where_at - 1) or body
    local tail = where_at and string.sub(body, where_at + 7) or nil
    local terms = {}
    for term in string.gmatch(head, "[^,]+") do
        table.insert(terms, (string.gsub(term, "^%s+", "")))
    end
    local params = {}
    for _, term in ipairs(terms) do
        -- a parameter pack is "each T" in the signature, and the clause spells it so (the name alone would be "each")
        local pack, name = string.match(term, "^(each)%s+([%w_]+)")
        if name == nil then
            name = string.match(term, "^([%w_%.]+)")
        end
        if name and name ~= "Self" and not (outer and outer[name]) and string.find(term, ":") == nil
           and string.find(term, "==") == nil then
            table.insert(params, (pack and "each " or "") .. name)
        end
    end
    if #params == 0 then
        return nil, tail
    end
    return "<" .. table.concat(params, ", ") .. ">", tail
end

-- The constraints a protocol's generic signature puts on Self, as inheritance terms ("AnyObject", "Sendable").
local function protocol_self_inheritance(signature)
    if signature == nil or signature == NO_VALUE then
        return {}
    end
    local body = string.match(signature, "^<(.*)>$") or ""
    local out = {}
    for term in string.gmatch(body, "[^,]+") do
        term = (string.gsub(term, "^%s+", ""))
        local rest = string.match(term, "^Self%s*:%s*(.+)$")
        if rest then
            table.insert(out, (string.gsub(rest, "^%s+", "")))
        end
    end
    return out
end

-- The " : A, B" clause of a declaration from its superclass, its conformances (a list) and any extra terms.
local function inheritance_of(superclass, conformances, extra)
    local out = {}
    if superclass ~= nil and superclass ~= NO_VALUE then
        -- a class has one superclass: the cell lists the chain above the class, direct superclass first ("UIKit.UIView,
        -- UIKit.UIResponder, ..."), and the list is "multiple inheritance from classes" (502 errors in 37 modules of the coordinator's sdk run)
        table.insert(out, spell(string.match(superclass, "^[^,]+")))
    end
    for _, c in ipairs(extra or {}) do
        table.insert(out, spell(c))
    end
    for _, c in ipairs(conformances) do
        table.insert(out, spell(c))
    end
    if #out == 0 then
        return ""
    end
    return ": " .. table.concat(out, ", ")
end

-- The `@available` attribute a row's availability asks for, or nil. The platform names are the IR's (ios, macos, ...).
local function availability_of(row)
    if row.availability == nil or row.availability == NO_VALUE then
        return nil
    end
    local names = {ios = "iOS", macos = "macOS", tvos = "tvOS", watchos = "watchOS", xros = "visionOS",
                   maccatalyst = "macCatalyst"}
    local parts = {}
    for token in string.gmatch(row.availability, "[^,]+") do
        local platform, version = string.match(token, "^(.-)=(.+)$")
        if platform and version and names[platform] then
            table.insert(parts, names[platform] .. " " .. version)
        end
    end
    if #parts == 0 then
        return nil
    end
    return "@available(" .. table.concat(parts, ", ") .. ", *)"
end

-- A body that traps with the declaration's name: the stub of a method, a function or a computed property.
local function trap(label)
    return ' { fatalError("' .. label .. '") }'
end

-- The declaration of one member: a method, a function, a property, a constant or an associated type. indent spaces lead each line.
-- access is the modifier the enclosing declaration needs ("public ", "open ") so the digester sees the member again; a protocol
-- requirement carries none (it is public by nature), and neither does an enum case or an associated type, which take none.
-- The terms of a where text, split at the commas outside brackets and parentheses, each trimmed.
local function where_terms(gwhere)
    local out = {}
    if gwhere == nil then
        return out
    end
    local depth, start = 0, 1
    for i = 1, #gwhere do
        local ch = string.sub(gwhere, i, i)
        if ch == "<" or ch == "(" or ch == "[" then
            depth = depth + 1
        elseif ch == ">" or ch == ")" or ch == "]" then
            depth = depth - 1
        elseif ch == "," and depth == 0 then
            table.insert(out, (string.gsub(string.sub(gwhere, start, i - 1), "^%s+", "")))
            start = i + 1
        end
    end
    table.insert(out, (string.gsub(string.sub(gwhere, start), "^%s+", "")))
    return out
end

-- Whether a name occurs in a text as a whole identifier.
local function names_in(text, name)
    return string.find(text, "%f[%w_]" .. name .. "%f[^%w_]") ~= nil
end

-- The parameter types of a method with each `some C` replaced by a generic parameter the signature leaves unused, and the where text with
-- the constraint C on that parameter. A parameter spelled some X declares its own implicit parameter, so the explicit one is never used
-- and the compiler refuses the clause ("generic parameter 'W0' is not used in function signature": 820 errors in RegexBuilder's
-- buildPartialBlock<W0, W1, C1>(accumulated: some RegexComponent, next: some RegexComponent) -> Regex<...>). The unused parameters are
-- taken in order: the constraint the clause states for one of them (W0 : X) is kept, else the constraint is the parameter's own type (the
-- digester states none for the some parameters). Returns the types and the where text (either may be nil).
local function generic_for_some(types, gparams, gwhere, result)
    if gparams == nil then
        return types, gwhere
    end
    local body = string.match(gparams, "^<(.*)>$")
    local constraint_of = {}
    local terms = where_terms(gwhere)
    for _, term in ipairs(terms) do
        local name, bound = string.match(term, "^([%w_]+)%s*:%s*(.-)%s*$")
        if name then
            constraint_of[name] = bound
        end
    end
    local unused = {}
    for item in string.gmatch(body, "[^,]+") do
        local name = string.match(item, "([%w_]+)%s*$")
        local used = names_in(result, name)
        for _, t in ipairs(types) do
            if string.sub(t, 1, 5) ~= "some " and names_in(t, name) then
                used = true
            end
        end
        if not used then
            table.insert(unused, name)
        end
    end
    local out, extra = {}, {}
    for i, t in ipairs(types) do
        out[i] = t
        -- a parameter whose type ends in some X (X the rest of the type: "some X", or "() -> some X" for a closure's result)
        local head, bound = string.match(t, "^(.-)some ([^%s].-)$")
        if head ~= nil and not string.find(bound, "some ", 1, true) then
            for k, name in ipairs(unused) do
                if constraint_of[name] == nil or constraint_of[name] == bound then
                    out[i] = head .. name
                    if constraint_of[name] == nil then
                        table.insert(extra, name .. " : " .. bound)
                    end
                    table.remove(unused, k)
                    break
                end
            end
        end
    end
    if #extra == 0 then
        return out, gwhere
    end
    for _, e in ipairs(extra) do
        table.insert(terms, e)
    end
    return out, table.concat(terms, ", ")
end

local function render_member(row, indent, access)
    local pad = string.rep(" ", indent)
    local avail = availability_of(row)
    local lines = {}
    local label = (row.container ~= NO_VALUE and (row.container .. "." .. row.name) or row.name)
    access = access or ""

    if row.kind == "swift-associatedtype" then
        table.insert(lines, pad .. "associatedtype " .. ident(row.name))
        return lines
    end
    if row.kind == "swift-constant" and row.container ~= NO_VALUE then
        -- an enum case: the surface kind is constant and the container is the enum; its payload is its parameter types, unlabelled
        local payload = pipe_list(row.params)
        local types = #payload > 0 and ("(" .. table.concat(payload, ", ") .. ")") or ""
        table.insert(lines, pad .. "case " .. ident(row.name) .. types)
        return lines
    end
    -- a property, or a module-level constant (a variable with no container): a computed variable whose getter traps, since a
    -- constant needs its value and the skeleton has none
    if row.kind == "swift-property" or row.kind == "swift-constant" then
        local has_set = row.accessors ~= NO_VALUE and string.find(row.accessors, "set", 1, true)
        local override = row.overriding == "yes" and "override " or ""
        local head = pad .. access .. (row.side == "+" and "static " or "") .. override .. "var " .. ident(row.name) .. ": " .. spell(row.type)
        if avail then
            table.insert(lines, pad .. avail)
        end
        if access == "" then
            -- a protocol requirement has no body
            table.insert(lines, head .. (has_set and " { get set }" or " { get }"))
        elseif has_set then
            table.insert(lines, head .. " {")
            table.insert(lines, pad .. "    get" .. trap(label))
            table.insert(lines, pad .. "    set" .. trap(label))
            table.insert(lines, pad .. "}")
        else
            -- the shorthand getter, whose body traps
            table.insert(lines, head .. trap(label))
        end
        return lines
    end

    -- a method or a function
    local leaf, labels = name_parts(row.name)
    local types = pipe_list(row.params)
    local gparams, gwhere = generic_clause(row.generic_sig, row.outer_names)
    types, gwhere = generic_for_some(types, gparams, gwhere, row.type ~= NO_VALUE and spell(row.type) or "")
    local params = {}
    local first = leaf == "init" and 2 or 1
    for i = first, #types do
        local label_name = labels[i - first + 1]
        if label_name == nil or label_name == "" or label_name == "_" then
            table.insert(params, "_ p" .. (i - first) .. ": " .. types[i])
        else
            table.insert(params, label_name .. ": " .. types[i])
        end
    end
    local prefix = access
    if leaf ~= "init" and row.side == "+" then prefix = prefix .. "static " end
    if row.overriding == "yes" then prefix = prefix .. "override " end
    -- an initializer of a class: required when the dump says so, convenience when its init kind is (a protocol's has no access
    -- and takes neither)
    if leaf == "init" and access ~= "" then
        if string.find(row.attributes, "Required", 1, true) then prefix = prefix .. "required " end
        if row.init_kind == "Convenience" then prefix = prefix .. "convenience " end
    end
    if row.mutating == "Mutating" then prefix = prefix .. "mutating " end
    -- a subscript of a protocol states its accessors (get, or get and set): the compiler refuses one that does not
    local accessors = ""
    if leaf == "subscript" and access == "" then
        local has_set = row.accessors ~= NO_VALUE and string.find(row.accessors, "set", 1, true)
        accessors = has_set and " { get set }" or " { get }"
    end
    local signature
    if leaf == "init" then
        signature = "init" .. (gparams or "") .. "(" .. table.concat(params, ", ") .. ")"
    elseif leaf == "subscript" then
        signature = "subscript" .. (gparams or "") .. "(" .. table.concat(params, ", ") .. ")"
    else
        signature = "func " .. ident(leaf) .. (gparams or "") .. "(" .. table.concat(params, ", ") .. ")"
    end
    if row.async == "yes" then signature = signature .. " async" end
    if row.throwing == "yes" then signature = signature .. " throws" end
    if leaf ~= "init" and row.type ~= NO_VALUE then
        signature = signature .. " -> " .. spell(row.type)
    end
    if gparams and gwhere then signature = signature .. " where " .. gwhere end
    if avail then
        table.insert(lines, pad .. avail)
    end
    table.insert(lines, pad .. prefix .. signature .. (access == "" and accessors or trap(label)))
    return lines
end

-- The conformances of a class row as a list, less the Actor conformance: an actor is declared with its keyword, not with a
-- conformance. Returns the list and whether the class is an actor.
local function conformances_of_row(row)
    local out, actor = {}, false
    if row.conformances == NO_VALUE then
        return out, false
    end
    for c in string.gmatch(row.conformances, "[^,]+") do
        if row.kind == "swift-class" and string.match(c, "([^.]+)$") == "Actor" then
            actor = true
        else
            table.insert(out, stdlib_qualified(c))
        end
    end
    return out, actor
end

-- The conformances a class's superclass chain provides, as a set (name -> true): the conformances of each class above the class,
-- read from classes (the class rows of the SDK's modules keyed "Module.Api", swift_model.class_index). A superclass the index does
-- not hold provides none, and a chain that loops is cut where it meets itself.
local function chain_provides(superclass, classes)
    local provided, seen = {}, {}
    local function climb(names)
        if names == nil or names == NO_VALUE then
            return
        end
        for name in string.gmatch(names, "[^,]+") do
            local row = classes[name]
            if row ~= nil and not seen[name] then
                seen[name] = true
                for _, c in ipairs(conformances_of_row(row)) do
                    provided[c] = true
                end
                climb(row.superclass)
            end
        end
    end
    climb(superclass)
    return provided
end

-- The names of a generic signature's parameters, in order ("<T, each U>" gives {"T", "U"}; none when it has none).
local function parameter_names(signature)
    local names = {}
    local clause = generic_clause(signature)
    for term in string.gmatch(clause and string.match(clause, "^<(.*)>$") or "", "[^,]+") do
        table.insert(names, (string.gsub(string.gsub(term, "^%s+", ""), "^each ", "")))
    end
    return names
end

-- The inheritance of a type row: its raw type, superclass and conformances, plus any extra. provided (a set, or nil) names the
-- conformances the superclass chain already gives: Swift rejects a class that lists one of them again, so the class does not.
local function type_inheritance(row, extra, provided)
    local conformances = conformances_of_row(row)
    if row.raw ~= NO_VALUE and row.kind == "swift-enum" then
        table.insert(conformances, 1, row.raw)
    end
    if provided ~= nil then
        local kept = {}
        for _, c in ipairs(conformances) do
            if not provided[c] then
                table.insert(kept, c)
            end
        end
        conformances = kept
    end
    return inheritance_of(row.superclass, conformances, extra)
end

-- The inheritance an extension of another module's type declares. A protocol's extension declares none (Swift rejects it), and a
-- class's extension cannot name the superclass: the class declares its own, so the extension lists the conformances only.
local function extension_inheritance(row)
    if row.kind == "swift-protocol" then
        return ""
    end
    local plain = {}
    for k, v in pairs(row) do
        plain[k] = v
    end
    plain.superclass = NO_VALUE
    return type_inheritance(plain)
end

-- Marks the opaque typealiases of a node ("some P") that a rendered member witnesses: a member of the same opaque type (var body: some
-- View witnesses Body). The alias is not spelled, since a typealias cannot be opaque; Swift infers the associated type from the member,
-- so the skeleton declares it, and the alias's key is rendered. An alias with no such member stays unrendered.
local function mark_witnessed_opaque(node, rendered)
    for _, child in ipairs(node.children) do
        local alias = child.row.alias
        if child.row.kind == "swift-typealias" and alias ~= nil and string.find(alias, "^some ") then
            for _, member in ipairs(node.members) do
                if member.type == alias and rendered[swift_shard.key_of(member)] then
                    rendered[swift_shard.key_of(child.row)] = true
                    break
                end
            end
        end
    end
end

-- The members a conforming type must declare for an ObjC or Foundation protocol the model gives it none of. An ObjC protocol's requirements
-- are imported without Swift witnesses, so the skeleton's own conformance needs them declared: a class that adopts NSCopying without
-- copy(with:) fails to compile ("does not conform to protocol 'NSCopying'", the most frequent error of the coordinator's sdk run). name
-- is the member as the model names it, text its declaration (a "required " is dropped for a struct, which has no required initializer).
local WITNESSES = {
    NSCopying = {{name = "copy(with:)", text = "func copy(with zone: NSZone?) -> Any"}},
    NSCoding = {{name = "init(coder:)", text = "required init?(coder: Foundation.NSCoder)"},
                {name = "encode(with:)", text = "func encode(with coder: Foundation.NSCoder)"}},
    NSSecureCoding = {{name = "supportsSecureCoding", text = "static var supportsSecureCoding: Swift.Bool"}},
    NSItemProviderWriting = {{name = "writableTypeIdentifiersForItemProvider", text = "static var writableTypeIdentifiersForItemProvider: [Swift.String]"},
                             {name = "loadData(withTypeIdentifier:forItemProviderCompletionHandler:)",
                              text = "func loadData(withTypeIdentifier typeIdentifier: Swift.String, forItemProviderCompletionHandler completionHandler: @escaping (Foundation.Data?, Swift.Error?) -> Swift.Void) -> Foundation.Progress?"}},
    Decodable = {{name = "init(from:)", text = "required init(from decoder: Swift.Decoder) throws"}},
    Encodable = {{name = "encode(to:)", text = "func encode(to encoder: Swift.Encoder) throws"}},
    ContiguousBytes = {{name = "withUnsafeBytes(_:)", text = "func withUnsafeBytes<R>(_ body: (Swift.UnsafeRawBufferPointer) throws -> R) rethrows -> R"}},
}

-- The witness members of a type's own declaration, as lines indented by indent, for each conformance it declares (less those its
-- superclass chain provides: provided, a set or nil) that WITNESSES lists and the model gives no member of that name. Each one is
-- recorded in witnessed as "container<TAB>name" (the key the round trip reads: the member's container and name, the declaration's api).
local function witnesses_of(node, indent, access, provided, witnessed)
    local row = node.row
    local lines = {}
    local api = row.container ~= NO_VALUE and (row.container .. "." .. row.name) or row.name
    local have = {}
    for _, member in ipairs(node.members) do
        have[member.name] = true
    end
    for _, conformance in ipairs(conformances_of_row(row)) do
        local witnesses = WITNESSES[string.match(conformance, "([^.]+)$")]
        if witnesses ~= nil and not (provided and provided[conformance]) then
            for _, witness in ipairs(witnesses) do
                if not have[witness.name] then
                    have[witness.name] = true
                    local text = witness.text
                    if row.kind ~= "swift-class" then
                        text = string.gsub(text, "^required ", "")
                    end
                    table.insert(lines, string.rep(" ", indent) .. access .. text .. trap(api .. "." .. witness.name))
                    witnessed[api .. "\t" .. witness.name] = true
                end
            end
        end
    end
    return lines
end

-- Renders one node (a type row, its nested types and its members). Own types get a declaration; a type of another module gets an
-- extension, since its declaration belongs to its module. access is the modifier the enclosing declaration needs for a typealias
-- ("public ", or "" in a protocol, which refuses an access modifier on its members). hoisted (a list of lines) collects the extensions
-- of a nested type: Swift refuses an extension inside a type, so those are declared at file scope (render).
local function render_node(node, indent, framework, classes, rendered, access, hoisted, witnessed)
    local row = node.row
    local pad = string.rep(" ", indent)
    local lines = {}
    local avail = availability_of(row)

    if row.kind == "swift-typealias" then
        -- a typealias cannot spell an opaque type ("some P"): the digester gives a witness of that form as an alias, and none is
        -- spelled for it; its key is marked by its type's node when a member witnesses it (mark_witnessed_opaque)
        if string.find(row.alias, "^some ") then
            return lines
        end
        if avail then table.insert(lines, pad .. avail) end
        table.insert(lines, pad .. access .. "typealias " .. ident(row.name) .. " = " .. spell(row.alias))
        rendered[swift_shard.key_of(row)] = true
        return lines
    end
    rendered[swift_shard.key_of(row)] = true

    local external = row.owner_module ~= NO_VALUE
    local member_access = "public "
    if external then
        if avail then table.insert(lines, pad .. avail) end
        table.insert(lines, pad .. "extension " .. row.owner_module .. "." .. ident(row.name) .. extension_inheritance(row) .. " {")
    else
        local keyword = ({["swift-class"] = "class", ["swift-struct"] = "struct", ["swift-enum"] = "enum",
                          ["swift-protocol"] = "protocol"})[row.kind]
        local is_protocol = row.kind == "swift-protocol"
        local _, actor = conformances_of_row(row)
        local access = "public "
        if actor then
            -- an actor is final and cannot be open: its keyword replaces the class's
            keyword = "actor"
        elseif row.attributes ~= NO_VALUE and string.find(row.attributes, "Final", 1, true) then
            access = "public final "
        elseif row.is_open == "yes" then
            access = "open "
        end
        -- a protocol's own signature constrains Self to the protocol itself (spelled <Name>P); that is not an inheritance term
        local extra = {}
        if is_protocol then
            for _, term in ipairs(protocol_self_inheritance(row.generic_sig)) do
                local last = string.match(term, "([^.]+)$")
                if last ~= row.name and last ~= (row.name .. "P") then
                    table.insert(extra, term)
                end
            end
            member_access = ""
        end
        -- a nested type declares its own parameters only: its container's come with its generic signature, and are the outer ones
        local params, where = generic_clause(row.generic_sig, row.outer_names)
        if is_protocol then where = nil end
        local provided = nil
        if classes ~= nil and row.kind == "swift-class" then
            provided = chain_provides(row.superclass, classes)
        end
        local inheritance = type_inheritance(row, extra, provided)
        local head = access .. keyword .. " " .. ident(row.name) .. (params or "") .. inheritance
        if where then head = head .. " where " .. where end
        if avail then table.insert(lines, pad .. avail) end
        table.insert(lines, pad .. head .. " {")
    end

    local requirements, extensions = {}, {}
    local raw_enum = row.kind == "swift-enum" and row.raw ~= NO_VALUE
    for _, member in ipairs(node.members) do
        -- a raw-value enum synthesizes these two itself; declaring them again is a redeclaration. The skeleton still provides them
        -- through the raw type (measured: a Swift file declaring only the cases typechecks E(rawValue:) and E.a.rawValue), so they are
        -- rendered rows of the skeleton, not declared ones
        if raw_enum and (member.name == "rawValue" or member.name == "init(rawValue:)") then
            rendered[swift_shard.key_of(member)] = true
        elseif row.kind == "swift-protocol" and member.in_extension == "yes" then
            table.insert(extensions, member)
        else
            table.insert(requirements, member)
        end
    end
    for _, member in ipairs(requirements) do
        rendered[swift_shard.key_of(member)] = true
        for _, l in ipairs(render_member(member, indent + 4, member_access)) do
            table.insert(lines, l)
        end
    end
    if not external and row.kind ~= "swift-protocol" then
        local provided = classes ~= nil and row.kind == "swift-class" and chain_provides(row.superclass, classes) or nil
        for _, l in ipairs(witnesses_of(node, indent + 4, member_access, provided, witnessed)) do
            table.insert(lines, l)
        end
    end
    for _, child in ipairs(node.children) do
        for _, l in ipairs(render_node(child, indent + 4, framework, classes, rendered, member_access, hoisted, witnessed)) do
            table.insert(lines, l)
        end
    end
    table.insert(lines, pad .. "}")

    -- a protocol's extension members live in an extension of their own. A nested protocol's is declared at file scope, under the
    -- protocol's qualified name (the module, its containers, its name), since an extension inside a type is refused
    if #extensions > 0 then
        local name = external and (row.owner_module .. "." .. ident(row.name)) or ident(row.name)
        local block, ext_pad, ext_indent = lines, pad, indent + 4
        if indent > 0 and not external then
            name = framework .. "." .. (row.container ~= NO_VALUE and (row.container .. ".") or "") .. ident(row.name)
            block, ext_pad, ext_indent = hoisted, "", 4
        end
        table.insert(block, "")
        table.insert(block, ext_pad .. "extension " .. name .. " {")
        for _, member in ipairs(extensions) do
            rendered[swift_shard.key_of(member)] = true
            for _, l in ipairs(render_member(member, ext_indent, "public ")) do
                table.insert(block, l)
            end
        end
        table.insert(block, ext_pad .. "}")
    end
    mark_witnessed_opaque(node, rendered)
    -- an external type's extension nested in a type moves whole to file scope: its declaration belongs to its module, and the
    -- qualified name it has there is its own
    if indent > 0 and external then
        table.insert(hoisted, "")
        for _, l in ipairs(lines) do
            table.insert(hoisted, l)
        end
        return {}
    end
    return lines
end

-- Whether a declaration has no type the renderer can spell: the digester gives its type as the error type "_" (a C global the
-- importer could not type, so there is nothing to render from). Such a declaration is a model gap: render leaves it out and the
-- round trip counts it.
function untyped(row)
    return row.type == UNTYPED
end

-- Whether a declaration is a projected value: a property wrapper's `$name` (a Binding, a Parameter's $url). The compiler synthesizes it
-- from the wrapper, and refuses a declaration of it ("the '$' prefix is reserved for implicitly-synthesized declarations"), so render
-- leaves it out and the round trip counts the SDK's row as projected (swift_roundtrip.compare), not as missing.
function projected(row)
    return string.sub(row.name, 1, 1) == "$"
end

-- Groups the model rows into a tree: a type row becomes a node keyed by its api, its members and nested types attach to it, and a
-- declaration whose container is a type the model has no row for attaches to nothing (it is not rendered). Returns the top nodes and
-- the top-level members (functions, constants at module level).
function group(rows)
    local nodes, top, top_members = {}, {}, {}
    for _, row in ipairs(rows) do
        if TYPE_KINDS[string.match(row.kind, "^swift%-(.*)$")] then
            local api = row.container ~= NO_VALUE and (row.container .. "." .. row.name) or row.name
            local node = {row = row, members = {}, children = {}}
            nodes[api] = node
            local parent = row.container ~= NO_VALUE and nodes[row.container] or nil
            if parent then
                table.insert(parent.children, node)
            else
                table.insert(top, node)
            end
        else
            local parent = row.container ~= NO_VALUE and nodes[row.container] or nil
            if parent then
                table.insert(parent.members, row)
            elseif row.container == NO_VALUE then
                table.insert(top_members, row)
            end
        end
    end
    return top, top_members
end

-- The text of a module's Swift skeleton: a header, the imports, the module-level declarations and the types. known is the set of the
-- SDK's Swift module names (a set: name -> true). classes is the class index (swift_model.class_index) or nil: with it, a class lists
-- only the conformances its superclass chain does not already provide. public is the implementation modules' public modules
-- (swift_model.public_modules), or nil for none. Returns the text and the set of the keys (swift_shard.key_of) of the rows the text
-- declares: a row the renderer leaves out (an untyped one, an opaque typealias) is not in it. And the set of the witnesses it declares
-- for an ObjC or Foundation protocol ("container<TAB>name", WITNESSES): members the model does not give, which the round trip reads as
-- by design, not as extra.
function render(rows, framework, known, classes, public, attributed)
    local typed = {}
    for _, row in ipairs(rows) do
        if not untyped(row) and not projected(row) and not attributed_row(row, attributed) then
            table.insert(typed, row)
        end
    end
    rows = swift_canonical.rows(typed)
    local rendered, witnessed = {}, {}
    -- the body is rendered first: the imports come after it, since a witness may name Foundation, which the model's rows do not
    local body = {}
    local top, top_members = group(rows)
    for _, row in ipairs(top_members) do
        rendered[swift_shard.key_of(row)] = true
        table.insert(body, "")
        for _, l in ipairs(render_member(row, 0, "public ")) do
            table.insert(body, l)
        end
    end
    local hoisted = {}
    for _, node in ipairs(top) do
        -- a declaration that renders to nothing (an opaque typealias) leaves no blank line behind
        local block = render_node(node, 0, framework, classes, rendered, "public ", hoisted, witnessed)
        if #block > 0 then
            table.insert(body, "")
            for _, l in ipairs(block) do
                table.insert(body, l)
            end
        end
    end
    -- the extensions of nested types, at file scope (render_node)
    for _, l in ipairs(hoisted) do
        table.insert(body, l)
    end
    -- the imports: the modules the model names, and Foundation when a witness spells one of its types (the module itself excepted)
    local modules = imports_of(rows, framework, known, public or {}, attributed)
    local foundation_depends = attributed ~= nil and attributed["Foundation"]
    if has_keys(witnessed) and framework ~= "Foundation" and not foundation_depends and not contains(modules, "Foundation") then
        table.insert(modules, "Foundation")
        table.sort(modules, order.less)
    end
    local lines = {
        "// GENERATED by tools/gen.lua swiftcode. Do not edit.",
        "// The Swift skeleton of " .. framework .. ", rendered from the declaration model.",
    }
    for _, module in ipairs(modules) do
        table.insert(lines, "import " .. module)
    end
    for _, l in ipairs(body) do
        table.insert(lines, l)
    end
    return table.concat(lines, "\n") .. "\n", rendered, witnessed
end
